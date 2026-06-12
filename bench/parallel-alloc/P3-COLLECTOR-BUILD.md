# P3 — minimal STW mark-region collector: build plan + live baseline

Spec: `spec/02-working/v_runtime_memory_management.md` §4.3, §5.3 (resolved → (c)),
§6 Phase 3, §7 gates. Design: `MINIMAL-COLLECTOR-DESIGN.md`. This file tracks the
*build* (the multi-week work) — its baseline, the wall, and the diagnostic plan.

All §5 cruxes are resolved: §5.1 → thread-local-handoff RC (`G-R2s-RC-FINDINGS.md`),
§5.2 → cycles via the backstop, §5.3 → (c) minimal STW collector in V/C. The
collector build is what remains for the Phase-3 gate (R2 + correctness battery
byte-identical to `-gc none` under thread churn + GC pressure).

## Substrate

Upstream clone `/Users/ep/git-repos/cx/vlang-v-latest` @ vlang/v `a83aabb`
(master). The collector lives behind `-gc vgc` (we reuse the `vgc` mode slot; the
*coordination* has been replaced). Working tree carries two file-disjoint,
uncommitted efforts, both verified canonical:
- the collector — 3 vgc files == `bench/parallel-alloc/minimal-collector.patch`
  (byte-confirmed 2026-06-11);
- the Perceus emission — `array.v`/`autofree.v`/`cgen.v`/`fn.v` (gated `-autofree
  -d perceus`, off by default → orthogonal to a `-gc vgc` build).

The minimal collector = **vgc-minus-concurrency-plus-validated-STW**: keep vgc's
sound mcache allocator / `ptrmap` precise scan / bitmap sweep; delete the
cooperative safepoint, `ncaches`-counting, timeout-proceed, concurrent+parallel
mark; wire in mach OS-suspend STW (`suspend_world.c`) + register/stack root
capture (`stw_root_scan.c`). Coordination model (read from the patch):
- The allocating thread that crosses `next_gc` *becomes the collector* for that
  cycle (`vgc_maybe_gc` → `vgc_run_gc_spilled`, which spills its own callee-saved
  regs so a root like `last` held only in a register is scanned).
- It mach-suspends every *currently-registered live* mutator, `thread_get_state`s
  each for registers + conservative `[sp, stack_base)`, marks precisely, sweeps,
  resumes. Single-threaded mark (no `work_lock`), world fully stopped (no barrier).
- Thread registry: `vgc_register_thread` (slot reuse via `free_slots`;
  `mach_port` captured; **registration barrier** = spin until `gc_phase==off`
  before first alloc, so a thread born mid-cycle can't make unscanned white
  objects); `vgc_thread_exit_cb` (pthread-key destructor; `registered=false`,
  `live_threads--`, slot freed; collector's wait target recomputes from
  `live_threads` each iteration so an exiting thread drops out, never miscounted).

## Bring-up stages (each G-CHURN-gated; `MINIMAL-COLLECTOR-DESIGN.md` §5)

1. allocator + no collection (NoGC-equiv) — proves object model + alloc. ✅ (vgc base)
2. + STW + roots + mark + sweep, single/steady mutators — proves the cycle.
   **✅ MILESTONE (B2): steady G-CHURN passes** (below).
3. + multi-mutator under thread **create/exit churn** — the real G-CHURN bar.
   **◄ THE WALL — currently FAILS** (below).
4. (optional, later) parallel mark / generational — only with G-CHURN green.

## Live baseline (2026-06-11, 12-core M-series, darwin/arm64)

Built in the clone: `./v -gc {none|vgc} -prod -o g_churn_{none|vgc} g_churn.v`.

| workload | args | `-gc none` (oracle) | `-gc vgc` (minimal collector) |
|---|---|---|---|
| **steady** (no thread churn) | `20000 6 0` | PASS, 0 corruptions | **PASS, 0 corruptions** — byte-identical ✅ |
| **thread-churn** (waves) | `100 1 30` | PASS, 0 corruptions | **SIGSEGV (rc=139)** ◄ the wall |

Stage 2 holds: with a fixed thread set, OS-suspend STW + register/stack roots +
precise mark/sweep is correct (the case the original cooperative-safepoint vgc
could not even do). Stage 3 is the open wall.

## The wall — precise crash signature (debug build, lldb, attempt 1/1)

```
thread #5, EXC_BAD_ACCESS (code=1, address=0x8)
  frame #0: main__churn(iters=120000, wg=0x…b40) at g_churn.v:104:12   // `if last.id == 0xdeadbeef`
```

`last` is a `&Node` local; `Node.id` is at offset +8. `address=0x8` ⇒ **`last`
itself is NULL** at line 104 — *after* a loop (`for i in 0..iters { b := &Node{…};
last = b }`) that can only ever assign `last` a freshly-allocated non-null Node.
So between the loop body and the next read, a wave churn thread's live local was
zeroed under collection. Args (`iters`, `wg`) are intact ⇒ this is **not**
spawn-arg corruption per se; it is a **root-tracking / allocator-coherence failure
for threads racing the STW snapshot** during create/exit churn. (Same canonical
line-104 tell as the original unsound vgc — the minimal collector fixed *steady*
but not *churn*.)

### ROOT CAUSE — instrumented, found 2026-06-11 (the wall was TWO stacked bugs)

A ring-buffered, async-signal-safe collector event log (REG/BAR/EXIT/GC_BEG/
SUSP?/SUSP!/SCAN/SWEEP/RESUME/GC_END + a `vgc_maybe_gc` pacer probe + a SIGSEGV/
SIGBUS dump handler, installed from the test's `main()` so it wins over V's own
runtime handler) was added to the clone working tree and the crash reproduced.
**Surprise: the trace contained ZERO GC cycles** (GC_BEG=0 across every run, debug
and -prod), and max RSS at crash = **6.6 GB**. So the crash is **not** the
collector sweeping live data — it is an out-of-memory: the heap grows unbounded
and an allocation returns NULL (`last`/spawn-arg = null → the EXC_BAD_ACCESS).

**Bug A (root cause, PROVEN) — GC is disabled for the entire program by a startup
ordering bug.** The pacer probe showed `vgc_maybe_gc` is called (34k+×) but
`gc_enabled` reads **0**. `gc_enabled` is only ever *set to 1*, in `vgc_init`
(`vgc_d_vgc.c.v:228`) — never to 0. The generated `main()` is:
```c
builtin__vgc_init();    // sets vgc_heap.gc_enabled=1, next_gc=256MB, registers main thread
_vinit(___argc, ...);   // runs global init: vgc_heap = (VGC_Heap){...}  ← re-ZEROES the struct
main__main();
```
`cmain.v:210` emits `builtin__vgc_init()` *before* `_vinit()`, but `_vinit`
executes the V global initializer `vgc_heap = (VGC_Heap){.lock=0, .arenas={…}, …}`
(generated-C line ~13940) which resets `gc_enabled→0` and `next_gc→0`. ⇒ the
collector's `if gc_enabled != 0` gate is always false ⇒ GC never runs ⇒ heap grows
to OOM. **The "steady G-CHURN pass" (Stage-2 milestone) was VACUOUS** — it passed
only because it stays under the OOM ceiling; the OS-suspend STW collector was never
actually exercised. (vgc was likely *always* run with GC effectively off.)

*Verification:* re-arming the pacer lazily (`if next_gc==0 { next_gc=256MB;
gc_enabled=1 }`) made GC fire and dropped RSS **6.6GB → 2.06GB** — confirming bug A
is the OOM cause.

**Bug B (was MASKED by A, now isolated).** With GC actually firing, the failure
*changed* from a null-alloc SIGSEGV to `V panic: Negative number of jobs in
waitgroup` in `main__churn+408` — a thread-churn waitgroup-counter corruption.
This is the genuine thread-lifecycle×GC issue (or a V `sync.WaitGroup` race under
heavy spawn/done churn); it only surfaces once bug A is fixed and GC runs.

### Next steps (in order)

1. **Fix bug A properly** (not the lazy self-heal). Options: (a) move
   `builtin__vgc_init()` to *after* `_vinit()` in `cmain.v` — but verify `_vinit`
   does not allocate through vgc before init; (b) stop emitting a clobbering global
   initializer for `vgc_heap` (mark it no-init), so `vgc_init`'s settings survive;
   (c) make `vgc_init` run as the last step of `_vinit`/first allocation, idempotent.
   Then re-run the FULL G-CHURN matrix — steady must pass *with GC observably
   firing* (GC_BEG>0), proving Stage 2 non-vacuously.
2. **Then attack bug B** with the same trace (now GC cycles appear): correlate the
   waitgroup panic with suspend/scan of the faulting thread's slot — the original
   suspend-set-TOCTOU / slot-reuse hypotheses become testable against real cycles.

The diagnostic instrumentation lives uncommitted in the clone working tree
(`thirdparty/vgc/vgc_platform.h` trace ring + handler; `vgc_d_vgc.c.v` /
`vgc_gc_d_vgc.c.v` trace calls; `g_churn.v` `vgc_trace_init()` in main).
Reproduce: `./v -gc vgc -prod -o g_churn_trace g_churn.v && ./g_churn_trace 100 1 30`.

### UPDATE — bug A pinned exactly + FIXED; bug B now active (2026-06-11)

An immediate (non-ring) probe `vgc_say(tag, gc_enabled)` settled the mechanism:
`tag=1` (right after `vgc_init` sets it) = **1**; `tag=2` (first allocation's
pacer call) = **0**. So `vgc_init`'s write is fine, but something between init and
`main__main` zeroes it — **`_vinit()`**. Crucially, V emits the global
zero-initializer for `vgc_heap` *regardless of the source initializer*: with
`__global vgc_heap = VGC_Heap{}` it's `vgc_heap = (VGC_Heap){…}`; with a no-init
`__global` it's `vgc_heap = *(VGC_Heap*)&((VGC_Heap[]){{…}}[0])` — **either way a
full zeroing assignment runs inside `_vinit`** (this is why proposed fix (b),
"remove the initializer", CANNOT work — you can't stop V zero-initing a global in
`_vinit`).

**Fix (a), applied + verified:** move `builtin__vgc_init()` to *after* `_vinit()`
in `cmain.v` (all three main variants — normal, sokol/android, tests). Patch:
`bench/parallel-alloc/vgc-init-ordering-fix.patch`. After rebuilding the compiler,
the generated `main()` is `_vinit(); builtin__vgc_init(); main__main();`, RSS drops
**6.6GB → 2.05GB**, and the failure mode advances to **bug B** (the waitgroup
panic) — i.e. GC is no longer disabled. *Caveat:* `_vinit` itself allocates once
before `vgc_init` now (the `tag=2`-before-`tag=1` ordering), so those early allocs
run pre-allocator-init (degraded to the large-alloc path; harmless here). A
cleaner refinement is to split `vgc_init` into an **early** part (size tables +
allocator + main-thread registration, before `_vinit`) and a **late** part
(`gc_enabled`/`next_gc`/`gc_phase`, after `_vinit` so they survive the zero-init).

**Bug B (now the active failure):** `V panic: Negative number of jobs in
waitgroup` (`main__churn+408`) under thread churn — a `sync.WaitGroup` counter
underflow/corruption. The earlier `df8943dc` framing ("remove the clobber") is
superseded: the clobber is real but unremovable at source; the fix is the
`cmain.v` ordering.

### Bug B PARTITIONED 2026-06-11 — it's the vgc allocator/registration, NOT the STW collector

12-run churn (`100 1 30`) matrix with bug A fixed:

| mode | PASS | waitgroup-panic | other crash | hang | GC cycles fired |
|---|---|---|---|---|---|
| `-gc none`  | **12** | 0 | 0 | 0 | — |
| `-gc boehm` | **12** | 0 | 0 | 0 | — |
| `-gc vgc`   | 0 | **10** | 1 | 1 | **0 / 12** |

Two conclusions: (1) the panic is **`-gc vgc`-specific** — `none`/`boehm` are
clean, so it is **not** a V `sync.WaitGroup` stdlib race, it is ours. (2) it fires
with **zero GC cycles** (GC_BEG=0 every run) → it is **not** the STW mark/sweep
collector; it is the vgc **allocator / per-thread-mcache / thread-registration**
path corrupting the heap-allocated, wave-shared `WaitGroup` under create/exit
churn (the counter goes negative because the object's memory is clobbered/aliased,
not because add/done are mismatched). **Next:** narrow within the allocator —
suspect slot-reuse on thread exit/register (`free_slots` reuse + the mcache clear)
handing two live threads overlapping spans, or the `vgc_ensure_registered` lazy
path racing. A targeted repro: shrink to the `sync.new_waitgroup()` object alone
under wave churn, watch its address + counter across register/exit events via the
trace. This is a bounded allocator-correctness bug, not the open-ended STW race
the "wall" was feared to be.

### Bug B ROOT-CAUSED 2026-06-11 (PM) — SPAWN-ARG NOT GC-ROOTED ACROSS HANDOFF (the "PARTITIONED" allocator hypothesis above is DISPROVEN)

The "allocator slot-reuse / overlapping spans, zero GC cycles" conclusion above was
a **measurement error** (the trace ring buffer wrapped and did not capture the
`GC_BEG` events; the steady churn thread alone allocates 2M×256B ≫ 256MB, so GC
*does* fire). A controlled experiment series re-partitioned bug B:

| experiment | result | inference |
|---|---|---|
| stack-allocated WaitGroup (cannot be swept/aliased) | still fails | not allocator slot-reuse / WaitGroup sweep |
| `vgc_free` → no-op (kills cross-thread free race) | still fails | not the cross-thread free race |
| own `stdatomic` counter, same 4-worker wave churn | passes 17/18 | not general thread/memory corruption |
| `-gc none` ×40, `-gc boehm` ×40 | **0 fail** | vgc-specific; NOT a latent `sync.WaitGroup` race |
| **GC disabled (`next_gc=64 GB`)** | **passes 12/12** | **GC running is REQUIRED → collector sweeps a live object** |
| **`malloc` the thread-arg struct (uncollectable)** | **≈ all pass** (was 0) | **the swept live object is the spawn thread-arg struct** |

**Root cause:** `spawn f(...)` heap-allocates the thread-argument struct with
`builtin___v_malloc` (a GC object — `spawn_and_go.v`), fills it, and hands it to
`pthread_create`. Between create and the child reading it, that struct is reachable
from **no scanned root**: the spawning thread has dropped its local, and the child
is **not yet vgc-registered** (it registers lazily on its first allocation, which
happens *inside* the spawned fn — *after* the generated wrapper has already
dereferenced `arg->fn`/`arg->argN`, the crash site `…_thread_wrapper+32`). A
collection in that window sweeps the live arg struct → the wrapper reads
freed/reused memory → either a `Negative number of jobs in waitgroup` panic (the
`wg` field read as garbage / the counter clobbered) or a deadlock hang (lost
semaphore post). This is exactly the long-flagged "spawn-arg not rooted across
handoff" hazard — now proven to BE bug B, and it is the COLLECTOR/rooting after
all (not the allocator). `-gc none` never frees it; `-gc boehm` intercepts
`pthread_create` + conservatively scans, so it stays alive; only the precise-ish
vgc scan drops it.

**FIX (implemented; gated `-gc vgc`):** a spawn-arg root registry in vgc —
`vgc_spawn_root_add(arg)` (emitted before `pthread_create`) / `vgc_spawn_root_remove(arg)`
(emitted in the wrapper before the arg is freed); the collector shades every
registered spawn root each STW cycle (after `vgc_mark_roots`, before
`vgc_parallel_mark`), so the arg struct AND its referents survive the handoff.
Files: `vlib/builtin/vgc_d_vgc.c.v` (`vgc_spawn_roots`/add/remove),
`vlib/builtin/vgc_gc_d_vgc.c.v` (shade loop), `vlib/v/gen/c/spawn_and_go.v`
(add/remove emission, gated on `g.pref.gc_mode == .vgc` → non-vgc byte-identical;
verified 0 refs in a `-gc boehm` build). Result: min_wg (heap & stack WaitGroup)
0/15 → 14/15 under vgc (isolation harness min_wg.v). **HONEST SCOPE: the spawn-arg
fix is NECESSARY BUT NOT SUFFICIENT — it does NOT close the canonical wall.** With
BOTH fixes (spawn-arg root + registration-lock), `min_wg 100 1 30`-equivalent is
~38/40 but the real `g_churn 100 1 30` STILL fails ~12/12, and disabling GC
(next_gc=64GB) still passes — so a SECOND residual remains.

### Residual (2026-06-11 PM) — a DISTINCT 2nd bug: extra `done()` on a CLEAN WaitGroup

With both fixes applied, `g_churn 100 1 30` fails with `Negative number of jobs in
waitgroup`. Instrumenting `WaitGroup.add()` at the panic shows, every time:
`old=0x0 delta=-1 old_jobs=0 waiters=0` → the WaitGroup state is a **clean 0**, NOT
garbage. So it is **NOT** memory corruption / a swept-or-aliased WaitGroup — it is a
genuine **extra `done()`** (a 5th done against a 4-add wave, on a WaitGroup whose
cycle already completed and reset to 0). Ruled OUT by controlled test (all with both
fixes, g_churn ~100% repro, `perl -e 'alarm N; exec @ARGV'` for timeout since
`timeout` is absent on this mac):
- arg-struct sweep — FIXED (spawn-root registry); min_wg 0→38/40, but g_churn still fails.
- registration-vs-STW race — FIXED (cache_lock held thru setup); neutral on residual.
- cross-thread `vgc_free` bitmap race — `vgc_free`→no-op does NOT fix g_churn (10/10 still fail).
- memory clobber / WaitGroup sweep — DISPROVEN (state is a clean 0 at the panic).
GC-frequency-driven: min_wg (~400 allocs/worker) hits it ~5%; g_churn (2M-alloc
steady churn → far more collections/run) hits it ~100%.

**LOCALIZED 2026-06-11 (PM) — the residual is NOT WaitGroup-specific; it is per-wave
HEAP-ARGUMENT corruption under heavy GC (same class as the dominant spawn-arg bug;
the spawn-root fix reduced but did not eliminate it).** `min_atomic2.v` removes
sync.WaitGroup entirely (each wave: a fresh heap `Counter`; 4 workers each do
`atomic_add(&g_ran,1)` THEN `atomic_add(&c.done,1)` on adjacent lines; main
spin-waits `c.done==4`) and adds 2 steady background allocators to drive GC to
g_churn levels. It FAILS: `wave 1859: done=1 ran_delta=4` — the GLOBAL `g_ran` got
all 4 increments but the PER-WAVE heap `c.done` got only 1. So 3 workers executed
the global add but their adjacent add to the per-wave heap object was lost — i.e.
3 workers' `c` pointer (delivered via the spawn arg) was wrong/stale, or those
threads died between two adjacent statements, under heavy collection. The global
(not passed via the arg) is unaffected; the per-wave heap object (passed via the
arg) is corrupted. This is the SAME spawn-arg/per-thread-heap-arg-under-GC class as
the dominant bug — the spawn-root registry cut the rate massively (min_wg 0→38/40)
but a residual hole remains at high GC frequency. **NEXT:** find why the per-wave
heap arg is still occasionally not preserved across the handoff under heavy GC
(audit the spawn-root add/remove window vs the wrapper's arg deref; check whether
`c`/the arg can be reclaimed or the arg's pointer fields corrupted during a
collection that fires in the create→consume window despite the registry). Reliable
repros: `g_churn 100 1 30` (~100%, with WaitGroup) and `min_atomic2 2000 400`
(~100% under its 2 steady drivers, NO WaitGroup — cleaner). min_atomic.v (no steady
driver, low GC) passes = the low-frequency control.

## Reproduce

```
cd /Users/ep/git-repos/cx/vlang-v-latest
./v -gc none -prod -o g_churn_none g_churn.v   # oracle
./v -gc vgc  -prod -o g_churn_vgc  g_churn.v   # subject (minimal collector + both fixes)
./g_churn_vgc 20000 6 0   # steady  → PASS (GC now fires non-vacuously)
./g_churn_vgc 100 1 30    # churn   → spawn-arg crash FIXED, but STILL fails ~100% on the
                          #           residual extra-done() (the open 2nd bug)
# isolation harnesses (this session, bench/parallel-alloc/): min_wg.v (WaitGroup,
# mode 0 heap / 1 stack), min_atomic.v (own atomic-counter control).
# `timeout` is NOT installed on this macOS → use `perl -e 'alarm 30; exec @ARGV' ./bin …`.
# A subshell `( ./bin ) & kill $!` only kills the SUBSHELL not the child → false fails;
# use the perl-alarm form for reliable hang/segv classification.
```
