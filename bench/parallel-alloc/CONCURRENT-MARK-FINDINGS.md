# Concurrent mark — findings (spec §7, Phase-2 2c)

V-runtime-only, CX-agnostic. Implements a concurrent tri-color mark behind the
`-d vgc_concurrent` build define, so alloc-heavy parallel workloads with a real
large live set stop paying a full stop-the-world (STW) mark pause per collection.
STW stays the default and remains byte-for-byte diff-able for soundness bisection.
Design rationale: `CONCURRENT-MARK-DESIGN.md`. Soundness prototype:
`cm_barrier_proto.c`. Multi-thread gate: `cm_stress.v` (clone root).

## What ships (behind `-d vgc_concurrent`)

* **Two brief STW points around a concurrent mark** (`vgc_gc_start_concurrent` in
  `vlib/builtin/vgc_gc_d_vgc.c.v`): (1) STW start — clear marks, snapshot roots,
  enable the barrier, alloc-black, resume; (2) concurrent mark — the collector
  drains the grey set while mutators run; (3) STW mark-termination — re-scan
  dirtied roots + dirty spans, final drain, disable barrier, sweep, resume.
  Gated by `$if vgc_concurrent ? { vgc_gc_start_concurrent(); return }` at the top
  of `vgc_gc_start`, so the default build is the proven full-STW collector,
  unchanged.
* **Card / dirty-span write barrier** (`vgc_wb_store`): marks the mutated object's
  span dirty (one idempotent atomic byte store), emitted IMMEDIATELY BEFORE the
  pointer store. The collector re-scans every dirty span at mark-termination
  (`vgc_rescan_dirty_spans`) — a superset of a Dijkstra insertion barrier.
* **Codegen emission** (`vlib/v/gen/c/assign.v`): `gen_cm_write_barrier` at the top
  of `assign_stmt` for heap-targeted pointer-bearing stores (selector-through-ptr,
  `*p`, `a[i]`), over-approximating, side-effect-free bases only.
* **Builtin bulk-mutator barriers**: `array.v` (push/push_many/ensure_cap/set/
  set_unsafe/insert_many/clone), `map.v` (set), and catch-alls in `vgc_realloc` +
  `vgc_memdup*` — these move pointers in bulk via `memcpy` with no codegen-visible
  store.
* **Alloc-black**: `vgc_alloc_black_hook` sets the mark bit at allocation during
  mark (atomic test_and_set), so objects born during the mark are not swept.

## Why a card/dirty-span barrier (not immediate shade) — the key soundness call

This collector stops mutators with **OS-level mach suspend, not cooperative
safepoints** — a mutator can be frozen MID-BARRIER. An immediate-shade barrier
that enqueues the new value to the mark queue can lose the enqueue (frozen between
the slot write and the count bump) → silent live reclamation. The dirty mark is a
single store, emitted BEFORE the pointer store, so a freeze either leaves the
store un-done (no hazard) or leaves the span dirty (re-scanned). The work queue
stays collector-exclusive (mutators only dirty spans), which removes the MPSC /
frozen-lock-holder hazards entirely.

`cm_barrier_proto.c` (precise model, deterministic interleaving) proves all three:
insertion barrier closes hide-white-behind-black; STW-termination root re-scan
closes load-to-root-then-unlink; and the dirty-span barrier is preemption-safe
**iff the dirty mark precedes the store** (`dirty-after`+freeze provably reclaims a
live object and its subtree).

## Gates — all green under `-d vgc_concurrent`

Clone (`vlang-v-latest`, compiler `v2_cm`):
* corpora `none == e -d vgc_concurrent` byte-identical (perceus / deep_free_hazard
  / uref / p2_reuse).
* `map_test` + `array_test` under `-gc e -d vgc_concurrent`.
* `g_churn 100 1 30 / 200 1 50 / 100 2 40` — 0 corruptions.
* `cm_stress.v` (4 threads, large long-lived set, deep-child drop-and-hide) —
  `none == e == concurrent`, 0 mismatches.
* `./v2_cm -o v3 cmd/v` self-hosts (default).
* default `-gc e` byte-identical (regression-clean).
* ASan: concurrent ≡ STW baseline — both hit the SAME pre-existing false positive
  (the conservative `vgc_scan_range` data-segment read around `IError_name_table`);
  no NEW findings from concurrent mark.

Fork (`third_party/v` @ cx-home/v-cx-patches) + cx:
* cx builds clean with the barrier compiler in BOTH modes — including
  `-gc e -d vgc_concurrent`, which validates the codegen barrier emits valid C
  across the entire cx interpreter (a large, diverse V codebase).
* cx default gate GREEN with the barrier-enabled fork: **test-vcx-suite 125/125 +
  conform exit 0** (the barrier is inert in the default build → no regression).

## A real soundness gap found + fixed

`cm_is_pure_lvalue` initially rejected an `InfixExpr` index, so `obj[i+k].field =
ptr` stores were emitted with NO barrier (a silent-reclamation gap). Fixed:
arithmetic on pure operands is side-effect-free, so the base is safe to re-emit.

## GC-assist — attempted, proven unsound, DEFERRED (documented)

Wiring a Go-style GC-assist (a mutator drains a proportional slice of the grey set
when it allocates during mark) is **unsound under this collector's preemptive
mach-suspend**: an assisting mutator that pops a grey object and is then frozen
MID-SCAN orphans it (off the queue → the collector never scans its referents →
swept while live). Enabling it corrupted g_churn (thousands of events) and
cm_stress and segfaulted; fully reverted. A sound assist needs cooperative
safepoints for the assist scan, or popped-object tracking — substantial, deferred.
Assist is perf-pacing, not correctness: without it the heap can overshoot the goal
during a long concurrent mark, **bounded by the existing span-exhaustion →
`vgc_collect_and_retry_span` force-collect safety net**.

## Honest teeth note

The deterministic teeth proof is `cm_barrier_proto.c` (precise model: barrier off →
reclaim, on → retained). `cm_stress.v` could NOT be made to exhibit V-level teeth
at a clean GC trigger: this collector scans **roots conservatively**, so the
victim pointer's value lingers in a stale register/stack slot and is
over-retained, masking a missing barrier; and a modest (~10 MB) live set marks in
well under a millisecond, leaving almost no concurrency window. A teeth knob
exists for testing only: `-d vgc_cm_nobarrier` no-ops `vgc_rescan_dirty_spans`.
(The "teeth" first seen at `VGC_NEXT_GC_MB=8` were a PRE-EXISTING vgc GC-storm bug
— pristine `v2_fresh -gc e` fails identically at an 8 MB trigger with a 20 MB live
set; clean at ≥32 MB — NOT the barrier.)

## Scaling — does `[par]` scale now?

**Clone `par_live.v`** (faithful #14 large-live-set, jobs=8, best-of-3):

| config | STW par | concurrent par | note |
|---|---|---|---|
| n=200k, default trigger | 422 ms (1.84× anti-scale vs serial 229) | **343 ms** (1.42×) | concurrent par **1.23× faster** |
| n=100k, default | 180 ms (1.19×) | **173 ms** (1.09× — near flat) | |
| n=200k, VGC_PACE | 342 ms | **299 ms** | |
| n=200k, trigger > live (GC rare) | 264 ms | 276 ms | barrier tax, no GC to overlap |

**cx #14** `[?to-sequence [?map (1..8) [using [?fn $x [?reduce [$range 0 400000]
+ ]]] [par]]]` (cx built `-gc e` ± `-d vgc_concurrent`, best-of-3, all correct =
`80000200000 ×8`):

| | serial | par | par/serial |
|---|---|---|---|
| STW (`cx_e`) | 1649 ms | 1531 ms | 0.93× |
| concurrent (`cx_cm`) | 1586 ms | **1268 ms** | **0.80×** |

Concurrent par is **1.21× faster** than STW par (on top of B17's interpreter
alloc fix), and par now runs well below serial. Serial barrier tax is negligible
(1649 → 1586, within noise).

**Interpretation.** Concurrent mark measurably improves the GC-heavy large-live-set
`[par]` regime — the residual STW-mark pause that B17 left. It is NOT full linear
scaling: STW start + termination (root + dirty-span re-scan) and the sweep are
still STW and scale with the live set, and there is no GC-assist (heap overshoots
during long marks). When GC rarely fires (trigger above the live set), only the
barrier tax remains, slightly net-negative. So concurrent mark is the right lever
for genuinely-large-live-set parallel workloads, complementary to B17 (which fixed
the interpreter's per-call over-allocation) and per-thread pacing (which fixes GC
frequency).

## Recommendation

* **Keep STW (`-gc boehm` default, `-gc e` opt-in) as the default; ship concurrent
  mark as `-gc e -d vgc_concurrent` opt-in.** It is correctness-validated (cx
  125/125 + conform, all clone gates, prototype proof) and a measurable `[par]`
  win, but its V-level teeth are masked by conservative scanning and it lacks a
  sound GC-assist.
* **Do NOT flip concurrent to default** until: (a) a sound GC-assist lands (or a
  cooperative-safepoint scan), so long marks can't overshoot; (b) the STW
  start/termination windows are profiled on a large real workload to confirm the
  pauses are acceptable; (c) ideally concurrent sweep too. The per-store barrier
  tax also argues for keeping it opt-in until the win is proven on the target
  workloads.
* **Push**: hold per the standing user directive (commits staged on the fork
  branch + cx-private gitlink bump, NOT pushed). Push when the user OKs, alongside
  the decision on default.
