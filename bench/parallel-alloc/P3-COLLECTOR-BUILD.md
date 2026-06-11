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

### Race-window hypotheses to discriminate next (in priority order)

1. **Suspend-set TOCTOU vs the registration barrier.** The collector snapshots the
   registered set under `cache_lock`, then suspends. A wave thread that flips
   `registered=true` *after* the snapshot but whose alloc proceeds (barrier sees
   `gc_phase` transitioning) runs concurrently with mark/sweep → its mcache spans
   get swept under it → a later `&Node{}` returns null/garbage → `last=null`.
   *Check:* is the registration barrier ordered strictly before `gc_phase` is set,
   and is the suspend-set re-derived after the barrier closes?
2. **Exit-during-stop slot reuse.** `vgc_thread_exit_cb` frees the slot mid-cycle;
   if the collector already holds that slot's `mach_port`/stack range and a *new*
   wave thread reuses the slot concurrently, the collector may suspend/scan the
   wrong thread or a stale range.
3. **Collector-as-mutator self-scan gap.** The triggering churn thread runs the
   cycle via `vgc_run_gc_spilled`; if its *own* `last` lives past the spilled
   frame (inlining/-prod), the spill range may miss it. (Less likely — crash is in
   a *different* thread #5, and reproduces in `-g` too.)

### Next diagnostic step (instrument, don't guess)

Add cheap, ring-buffered event logging to the collector (compile-time gated, no
perf cost when off): timestamp + thread-slot + event for {register, barrier-enter,
barrier-exit, suspend-begin/end, scan-thread, mark-begin, sweep-begin/end, resume,
exit-cb}. Reproduce the line-104 crash, dump the ring buffer at the fault, and
read off whether the faulting thread (#5) was suspended+scanned for the cycle that
ran during its loop, or slipped the snapshot. That converts hypothesis 1/2 into a
fact and points at the exact ordering fix. This is deliberate GC/codegen work, not
race-whacking — the multi-week part the spec and prior sessions flagged.

## Reproduce

```
cd /Users/ep/git-repos/cx/vlang-v-latest
./v -gc none -prod -o g_churn_none g_churn.v   # oracle
./v -gc vgc  -prod -o g_churn_vgc  g_churn.v   # subject (minimal collector)
./g_churn_vgc 20000 6 0   # steady  → PASS
./g_churn_vgc 100 1 30    # churn   → SIGSEGV (the wall)
./v -gc vgc -g -o g_churn_dbg g_churn.v        # debug, then: lldb -b -o 'run 100 1 30' -o 'bt' -- ./g_churn_dbg
```
