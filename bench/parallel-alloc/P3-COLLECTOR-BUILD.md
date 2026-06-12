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
underflow/corruption. Next: re-run the trace (GC cycles should now appear once a
run survives long enough), and determine whether B is (i) a GC issue (the
waitgroup or its backing struct collected/corrupted) or (ii) a V `sync.WaitGroup`
race independent of the collector (test under `-gc none`/`-gc boehm` churn). The
earlier `df8943dc` framing ("remove the clobber") is superseded by this: the clobber
is real but unremovable at source; the fix is the `cmain.v` ordering.

## Reproduce

```
cd /Users/ep/git-repos/cx/vlang-v-latest
./v -gc none -prod -o g_churn_none g_churn.v   # oracle
./v -gc vgc  -prod -o g_churn_vgc  g_churn.v   # subject (minimal collector)
./g_churn_vgc 20000 6 0   # steady  → PASS
./g_churn_vgc 100 1 30    # churn   → SIGSEGV (the wall)
./v -gc vgc -g -o g_churn_dbg g_churn.v        # debug, then: lldb -b -o 'run 100 1 30' -o 'bt' -- ./g_churn_dbg
```
