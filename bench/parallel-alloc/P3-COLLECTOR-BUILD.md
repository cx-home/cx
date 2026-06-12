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
arg) is corrupted. the spawn-root registry cut the rate massively (min_wg 0→38/40)
but a residual hole remains at high GC frequency.

**PINPOINTED 2026-06-11 (PM) via `min_atomic3.v` — the residual is a COLLECTOR
LIVE-OBJECT RECLAMATION bug, NOT spawn-arg and NOT WaitGroup.** min_atomic3
instruments the stall with: `g_ran`++ at worker end, `g_attempts`++ right before the
per-wave `c.done` add, `g_wrong_c`++ if the worker's received `c` != the wave's
expected `c`. At a stall (`min_atomic3 4000 400`):
```
wave 526 STALL: c.done=2 ran_delta=4 attempts_delta=4 wrong_c=0 bad_c=0x0
```
⇒ all 4 workers ran (ran=4), all 4 reached the add (attempts=4), all 4 had the
CORRECT `c` pointer (wrong_c=0) — yet the per-wave HEAP `c.done` only reached 2.
Two `atomic_fetch_add` to a correct, stable address were LOST. An atomic add cannot
be lost unless the target memory is concurrently overwritten/reclaimed. The GLOBAL
counters (`g_ran`,`g_attempts`) NEVER lose an increment; only the HEAP object does.
**⇒ vgc reclaims the live, main-held per-wave heap object under heavy GC** (its span
is swept/`vgc_os_decommit`-and-reused while live → adds land on recycled/zeroed
memory). So a live object reachable from `main`'s stack/registers is NOT being
marked (or is marked then wrongly swept) at high collection frequency. This is a
**root-scan / mark / sweep correctness bug**, the genuine deeper wall — distinct
from the spawn-arg sweep (fixed) and unrelated to sync.WaitGroup (the waitgroup
panic was just g_churn's manifestation of the same reclaimed-counter).
**CONFIRMED via `vgc_is_allocated(c)` at the stall:** `wave 535 STALL: c.done=3
attempts_delta=4 wrong_c=0 alloc_status=0` — `alloc_status=0` means `vgc_find_span(c)`
returns NIL: c's span is no longer in the heap (freed/decommitted) **while main
still holds c and workers write to it**. So the live, main-held object was
RECLAIMED. Definitive: a collector root-scan/mark/sweep correctness bug that frees a
live object reachable from `main`.

**MECHANISM PINNED 2026-06-11 (PM) via the `vgc_watch` probe → it is a MARK / ROOT-SCAN
MISS (not a sweep race, not decommit-of-a-marked-object).** Added `vgc_set_watch(ptr)`
/ `vgc_watch_report()` (vgc_d_vgc.c.v) + per-span hooks in `vgc_sweep_span`
(marked = the watched obj's mark bit is set at sweep; swept = it was alloc&~mark and
freed) and `vgc_put_free_span` (decommit) and a cycle counter at `vgc_gc_start`.
(A first cut also hooked `vgc_shade` per-word but that perturbed the timing-sensitive
bug enough to mask it — 8/8 clean — so the shade hook was removed; marked/swept are
now derived once per span in sweep, near-zero overhead, and the bug reproduces.)
Stall: `wave 1332: c.done=2 alloc_status=0 watch=268` → `268=(1<<8)|12` ⇒
**cycles=1, marked=0, swept=1, decommit=1**: in ONE GC cycle the live, main-held `c`
was NOT marked → swept (allocated-but-unmarked) → span decommitted. So the collector
fails to MARK a live object that `main` (spin-waiting, holding `c`), the running
workers (hold `c` as a param), and the spawn-root'd args (arg→arg2=c) all reference.
**NEXT:** find WHICH root scan misses `c` — main's `[sp,stack_base]` + register
capture under the spin-loop (prime suspect: `c` is held only in a register and the
suspended-thread `vgc_thread_regs` capture / range is wrong, OR main's stack_base
from vgc_init is stale), the new-thread worker stacks (registered late?), or the
spawn-root drain (does shading the arg actually scan arg→arg2 to reach `c`?). Add a
log in `vgc_mark_roots`/`vgc_scan_suspended_roots` of whether `vgc_watch_addr` falls
in each scanned range and whether `vgc_shade(watch_addr)` is ever called this cycle. Suspects: the main thread's
`[sp,stack_base]` range or register capture under the spin-loop; the
mark-bits-vs-alloc-bits handoff in `vgc_sweep_span`; span decommit of a
still-referenced span. Reliable repros (all ~100% at high GC freq, `perl -e 'alarm
N; exec @ARGV'` for timeout): `min_atomic3 4000 400` (TIGHTEST — globals-vs-heap
control built in, NO WaitGroup), `min_atomic2 2000 400`, `g_churn 100 1 30` (with
WaitGroup). `min_atomic.v` (no steady driver, low GC) PASSES = low-frequency
control.

### ROOT-CAUSED + FIXED 2026-06-11 (PM) — `vgc_find_span` addr_map 1GB-chunk COLLISION drops a live object; NOT a root-scan miss

The "root-scan miss" framing above is **DISPROVEN**. New root-scan localizers
(`vgc_watch_in_stack`/`in_reg`/`in_spawn`/`rng_cov` in `vgc_d_vgc.c.v`, logged from
`vgc_mark_roots` / `vgc_scan_suspended_roots` / the spawn-root shade loop — all
bounded, OFF the per-word `vgc_shade` hot path) show that at every stall `c` IS
present in THREE scanned roots: `in_reg=1` (main's captured register, idx 0),
`in_stack=6|7` (a worker's stack), `in_spawn=2` (a spawn-arg object holds c). So
`vgc_shade(c)` is provably reachable. Yet `marked=0 → swept → decommit`.

A STAGED mark-probe (`vgc_watch_snapshot(stage)` at 7 points across `vgc_gc_start`,
recording per stage: bit0=span found / b1=in_use / b2=alloc / b3=mark /
b4=in_arena_bounds / b5=noscan, + `span.base`) pinned it exactly:
```
S0..S6 ALL = 16  (ONLY bit4 set)   ⇒ found=0 at EVERY stage, span.base=0x0
arena_lo=0x1057d8000 arena_hi=0x38d9b4000 c=0x1256c2fd0 c_in_bounds=true
```
`found=0` everywhere ⇒ **`vgc_find_span(c)` returns NIL for a live, in-bounds heap
object — from the very start of the cycle.** That is why `vgc_shade(c)` (which calls
`find_span` right after its bounds gate) returns early and never marks, while
`vgc_do_sweep` walks `allspans` **directly** (not via `find_span`) → finds the span
→ frees + decommits it. The find_span/sweep reachability asymmetry reclaims a live
object.

**MECHANISM:** `vgc_arena_size = 64 MB` (`vgc_d_vgc.c.v:69`) but the addr→arena map
`vgc_addr_map` (`vgc_platform.h`) is **1 GB-granular** (`VGC_ADDR_SHIFT = 30`) with a
**single `uint16` per chunk**. Up to **16 arenas share one 1 GB chunk**, and
`vgc_addr_map_register` **OVERWRITES** the chunk entry on each new arena. So
`vgc_addr_to_arena(addr)` resolves only the **newest** arena in a shared chunk; for
`c` in an OLDER arena of that chunk, `find_span` checks `addr` against the wrong
arena's `[base, base+64MB)`, fails, and returns nil. Frequency-dependent exactly as
observed: bites only when ≥2 arenas occupy one chunk (heavy allocation → many 64MB
arenas → ~100% on `g_churn`/`min_atomic3`; rare on low-alloc `min_wg`).

**FIX (`vgc_d_vgc.c.v` `vgc_find_span`):** keep the addr_map as an O(1) hint, but if
the hinted arena does not actually contain `addr`, fall back to a **linear scan over
all arenas** (`narenas <= vgc_max_arenas = 64`) so `find_span` is as complete as the
`allspans` sweep. Correctness-first; the scan runs only on a hint miss, and
collection is rare behind the Perceus front line. (`vgc_is_heap_ptr` has the same
latent collision but is dead code — no callers.) Diagnostic probes
(`vgc_watch_*`/`vgc_watch_snapshot`/roots+stage reports) left wired in the clone
working tree.

**PERF COROLLARY (found during validation, fixed):** the linear fallback was firing
on ~15/16 of all scanned heap-range words, because the 1GB addr_map chunk
(`VGC_ADDR_SHIFT=30`) maps to a SINGLE 64MB arena — so 15/16 of addresses in a
populated chunk resolve to the wrong arena → fallback. Heavy workloads crawled
(min_wg 0 60 took 161s). FIX: matched the map granularity to the arena size —
`VGC_ADDR_SHIFT 30→26` (64MB chunks) + `VGC_ADDR_MAP_SIZE 4096→65536` (keep 4TB
coverage), in `vgc_platform.h`. Now the O(1) hint is correct for the body of every
arena and the fallback only fires for the rare unaligned boundary chunk shared by
two adjacent arenas.

**VALIDATION (12-core M-series, darwin/arm64, `-gc vgc -prod`):**
- find_span fix correctness: **min_atomic3 4000 400 → 14 PASS / 0 STALL** (was
  ~1-in-2-3 STALL); **min_atomic2 2000 400 → 8/8 PASS**; **min_wg 0 60 2000 (light)
  → 3/3 PASS in <1s**. The live-object-reclamation bug is CLOSED.
- perf fix (shift 30→26): controls stay clean AND fast — **min_atomic3 4000 400
  → 4/4 PASS ~100s each, 0 STALL** (the ~100s is the two steady-allocator GC load,
  not find_span). min_wg 0 60 *heavy* (120000 iters) is ~130–150s by its own
  ~28.8M-alloc weight under single-threaded STW (NOT a find_span regression) and now
  reliably hits the residual thread-exit segv below.
- flag-off / non-vgc parity: my edits are confined to `vgc_*_d_vgc.c.v` (compiled
  only under `-gc vgc`) + `vgc_platform.h` (vgc-only) → `-gc none` / `-gc boehm`
  builds are byte-identical by construction; no rebuild needed.

### STILL OPEN — a DISTINCT residual: thread create/exit × STW segv (NOT find_span)

`g_churn 100 1 30` now passes ~8/10 (was ~0/12) but **still SIGSEGVs ~2/10**, and
`min_wg 0 60` (heavy) crashes the same way. The crash-dump trace shows the last
events are `MAYBEGC`/`PACE` for a wave thread's slot with **`heap_live` (~135MB) <
`next_gc` (256MB) — i.e. NO GC cycle firing** — immediately followed by `EXIT
slot=7` and the SIGSEGV. So this residual is in the **thread create/exit churn path**
(`vgc_thread_exit_cb` / slot reuse / mcache clear / V's spawn teardown), NOT a
collector mark/sweep reclamation (GC isn't even running at the crash). This is the
long-flagged thread-lifecycle×GC hard part, now isolated as the next bug to chase —
the find_span fix removed the GC-reclamation crashes that were masking it.

### BUG #2 (thread create/exit × STW segv) ROOT-CAUSED + FIXED 2026-06-12 — STW LOCK-STEAL breaks allocator mutual exclusion

After the find_span fix, `g_churn 100 1 30` still SIGSEGV'd ~2/10 and `min_wg 0 60`
(heavy) reliably. Disambiguation:
- **Not span exhaustion.** A GC-and-retry on `vgc_span_alloc` failure (force a
  collection + retry before returning nil; scan+noscan+large paths,
  `vgc_collect_and_retry_span`) was added — a legitimate robustness fix, KEPT —
  but its exhaustion-dump never fired, so malloc was not returning nil. Span-alloc
  failure (the earlier "tag 93" flood) was a *downstream symptom* of the corruption
  below, not the cause.
- **Not WaitGroup.** `min_atomic 60 120000` (own atomic counter, NO WaitGroup, NO
  steady threads) crashes identically → WaitGroup was a red herring.
- **Not the worker's heavy alloc loop.** `min_atomic3` (atomic, +2 steady threads)
  PASSES even at iters=50000 — because its long-lived **steady threads dominate
  allocation and act as the collector**, so the wave workers are only ever
  *scanned*. The crash needs a **churning wave-worker to BE the collector**
  (min_wg/min_atomic have no steady threads → the allocating, create/exiting wave
  workers trigger GC themselves).

**Exact fault (lldb, current binary):** `_platform_memset(dest, 0, len=4)` at
`vgc_central_get_span+468` (the inlined `vgc_span_init` bitmap memset) ←
`vgc_cache_get_span` ← `vgc_malloc_typed_opts` ← worker; `dest` is a page-aligned
**unmapped** address — the span's `alloc_bits`/`base` is garbage. The allocator's
own metadata was corrupted.

**ROOT CAUSE:** `vgc_gc_start`, after mach-suspending all mutators, **stole (zeroed)
every allocator spinlock** — `vgc_heap.lock`, all `central[].lock`,
`free_spans_lock`, `work_lock` — "so the collector cannot deadlock on a frozen
owner." But `vgc_heap.lock` and `central[].lock` are **mutator-only** (the collector
never acquires them — verified: acquisitions only in `vgc_span_alloc`/`vgc_alloc_large`/
`vgc_central_get_span`/`vgc_central_return_span`). Zeroing a lock held by a mutator
that was suspended **mid-`vgc_span_alloc`** means that on resume the lock reads 0,
so a second allocator enters the critical section concurrently → two threads bump
the same arena `used` → overlapping span bases → a span gets a garbage
`base`/`alloc_bits` → `vgc_span_init`'s memset writes to an unmapped page → SIGSEGV.
Frequency matches the churning-collector regime exactly (many GCs triggered by
allocating wave workers racing each other on resume).

**FIX (`vgc_gc_d_vgc.c.v` `vgc_gc_start`):** stop stealing `vgc_heap.lock` and the
136 `central[].lock`s. A frozen owner keeps its lock → mutual exclusion is
preserved on resume, and the collector never blocks (it never acquires them). Only
`free_spans_lock` and `work_lock` are still stolen — the two locks the collector
genuinely re-enters (`vgc_put_free_span` in sweep / `vgc_work_put|get` in mark);
those remain a *narrower* latent issue (a frozen mutator mid-`vgc_get_free_span`
can leak/race a free-span entry on resume — a leak, not the observed memset crash;
banked as a follow-on, proper fix = acquire-before-suspend + non-locking put).

**SECOND VECTOR (free_spans_lock) — same class, fixed 2026-06-12.** After the
vgc_heap.lock/central fix, min_atomic stopped SIGSEGV-ing but min_wg still crashed;
the fault MOVED to `vgc_malloc_typed_opts+284` (the object zero-fill `memset(ptr,0,n)`)
with `ptr` in a span whose base was garbage — a **recycled span from a corrupted
free-span list**, because `free_spans_lock` was *still* being stolen (the collector
re-enters it via `vgc_put_free_span` in sweep, so it couldn't simply be left held by
a frozen owner). FIX: the collector takes `free_spans_lock` ONCE at the very top of
`vgc_gc_start` — **before** the world is stopped, so no mutator is ever frozen
mid-`vgc_get_free_span` holding it — holds it across the whole cycle, and
`vgc_put_free_span` (collector-only) is now lock-free; released right after sweep,
before resume. Lock order free_spans_lock→cache_lock is deadlock-free (no mutator
holds free_spans_lock then waits on cache_lock). `work_lock` is the only lock still
zeroed (no mutator holds it under full-STW).

**VALIDATION (12-core M-series, `-gc vgc -prod`):**
- **`g_churn 100 1 30` (the CANONICAL wall): 10/10 PASS** (was ~0/12 originally,
  8/10 after find_span). Heavier configs being confirmed.
- min_atomic2 8/8, min_atomic3 14/0 (controls, find_span); g_churn steady `20000 6 0`
  byte-identical to `-gc none`.
- **OPEN residual: `min_wg 0 60` (heavy, 120000 iters) still SIGSEGVs.** This is the
  most extreme case — NO long-lived thread, so the collector is ALWAYS a churning,
  about-to-exit wave worker (g_churn/min_atomic3 have long-lived anchor/steady
  threads that act as collector, sparing the wave workers). Same memset-wild
  signature (recycled/fresh span with a bad base). Suspected remaining vector: the
  weak-memory half-built `allspans`/`arenas[]` read by the collector while a mutator
  is frozen mid-`vgc_span_alloc` (lock-free reads in find_span/sweep), maximal when
  every thread is a heavy allocator. Chasing.

## Reproduce

```
cd /Users/ep/git-repos/cx/vlang-v-latest
./v -gc none -prod -o g_churn_none g_churn.v   # oracle
./v -gc vgc  -prod -o g_churn_vgc  g_churn.v   # subject (minimal collector + both fixes)
./g_churn_vgc 20000 6 0   # steady  → PASS (GC now fires non-vacuously)
./g_churn_vgc 100 1 30    # churn   → spawn-arg crash FIXED, but STILL fails ~100% on the
                          #           residual extra-done() (the open 2nd bug)
# isolation harnesses (bench/parallel-alloc/): min_wg.v (WaitGroup, mode 0 heap /
# 1 stack), min_atomic.v / min_atomic2.v / min_atomic3.v (own atomic-counter
# controls; min_atomic3 has the vgc_is_allocated + vgc_watch probes wired).
# TIMEOUT: macOS ships no coreutils `timeout`/`gtimeout`. Use the committed shim
# `bench/parallel-alloc/timeout` (a perl-alarm wrapper): `timeout 60 ./bin args`.
# Exit codes: 0=clean 142=timed-out(hang) 139=SIGSEGV 1=panic/exit(1).
# Do NOT use `( ./bin ) & kill $!` — it kills only the SUBSHELL, not the child
# (false "fails"); always wrap the binary directly with the shim.
```
