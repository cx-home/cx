# B13 — `[par]` / #14 payoff under `-gc e` in cx: BLOCKED by a vgc collector
# correctness bug on cx's real allocation graph

Goal (the headline E payoff): measure the original #14 workload —
`[?to-sequence [?map (1..8) [using [?fn $x [?reduce [$range 0 400000] [+]]]]]]`
serial vs `[par]` — under `-gc e` vs `-gc boehm` in cx. E was built to turn
this from "1.3× slower than serial" (Boehm alloc-lock) into a real MP win.

## STATUS: cannot measure the payoff yet — E miscomputes the workload.

`-gc e` (and bare `-gc vgc`) produce WRONG results on the **serial** map-reduce:

| binary (build flags)                     | serial result |
|------------------------------------------|---------------|
| `cx_boehm` (`-gc boehm -Os`)             | `(80000200000 ×8)`  ✅ correct |
| `cx_vgc`   (`-gc vgc -Os`)               | `(0, 8e10, 0, 5.6e9, 0, 0, 8e10, 8e10)` ❌ |
| `cx_vgc_dbg` (`-gc vgc`, no `-Os`)       | `(0, 8e10, 0, 7.4e10, 0, 8e10, 8e10, 8e10)` ❌ |
| `cx_e`     (`-gc e -Os`)                 | `(0, 8e10, 52032315345, 7864440, 0, 0, 8e10, 8e10)` ❌ |

Correct answer is `80000200000` (= Σ 0..400000) for all 8 items.

## Diagnosis (solid)
**The vgc tracing backstop reclaims LIVE cx-interpreter heap objects when a GC
fires during the deeply-recursive serial workload.** Established by:

1. **GC-driven.** A small workload (`[$range 0 1000]`, well under the 256 MB GC
   trigger → GC never fires) is CORRECT under `-gc vgc` (`(500500 ×4)`). Only the
   large workload (millions of `cx.Node` allocs → GC fires) corrupts.
2. **It is the COLLECTOR, not Perceus.** `cx_vgc` (bare backstop, NO `perceus`
   define → no Perceus drops, no deep-free, no generated free-methods) is
   corrupt too. So the front line is not implicated.
3. **Not an optimizer/register-capture artifact.** The unoptimized `cx_vgc_dbg`
   is corrupt as well (so it is not `-Os` keeping a live pointer out of a
   GC-visible slot / defeating the `setjmp` spill in `vgc_run_gc_spilled`).
4. **Pre-existing in the forward-ported fork**, orthogonal to today's changes:
   bare `-gc vgc` doesn't run any of the free-method codegen I touched.
5. **Pattern.** Items 2, 7, 8 (allocated most recently, after the last GC) tend
   to survive; earlier items (1,3,4,5,6) that lived across an intervening GC get
   reclaimed → garbage. Classic live-object-reclaimed-by-GC signature, on the
   accumulating result structure / in-flight reduce accumulators reachable from
   the main eval stack.

6. **SERIAL corrupt, PARALLEL correct** (robust, both `cx_e` and `cx_vgc`,
   `[par]` = `(8e10 ×8)` every run). This asymmetry is the sharpest clue: in
   SERIAL the sole (main) thread triggers GC and captures its OWN roots via the
   self-path — `vgc_run_gc_spilled` (`setjmp` register spill) + the *pre-recorded*
   self stack range; in PARALLEL a worker triggers GC and the result-holding
   thread is captured via the VALIDATED mach-suspend + `thread_get_state` path
   (`vgc_scan_suspended_roots`, proven in stw_root_scan.c). So the prime suspect
   is the **self-triggering-thread root capture** (its stack range and/or the
   setjmp spill), NOT the mark/sweep core and NOT the suspended-thread path.
   (Failing at both `-Os` and `-O0` argues the stack RANGE — e.g. a stale/too-high
   self `stack_lo`, or `stack_base` not covering the deep recursion — over the
   setjmp register spill specifically.)

## Why the standalone gate missed it (the gate gap)
`-gc vgc` passed g_churn 190/190 + bench_mp R2 + corpus G-DIFF. Those exercise
thread-churn and flat alloc loops. They do NOT exercise cx's pattern: deep
recursion (large live stack), `cx.Node` **sum-type** payloads boxed via memdup,
and live results accumulated in nested collections (`[]cx.Node`, maps) across
many GC cycles. The conservative root-scan→mark→trace chain breaks somewhere in
that graph (prime suspects: a `vgc_find_span` resolution miss at cx's arena
scale — cf. the earlier addr_map-collision class, now with more/larger arenas —
or the main thread's deep-stack range / a trace step that drops a live subtree).

## Reconciliation (build/measure changes REVERTED; one real V bug salvaged)
The cx-side edits I made only to LINK+RUN cx under `-gc e` were a process error
— no CX code belongs in the V effort — and were **reverted**: `vcx/cx/cabi.v`
restored, the two `gc_thread_shim_{d,notd}_gcboehm` files removed, the throwaway
`cx_{boehm,vgc,vgc_dbg,e}` binaries deleted. The fork (`third_party/v`) was
restored to committed `4e858f57c` and its `v` rebuilt from clean source.

**One genuine, CX-agnostic V bug was found and SALVAGED to the clone** (V's
canonical tree), captured standalone as `vlang-v-latest/option-free-methods-fix.patch`
(verified CX-token-free): in `vlib/v/gen/c/auto_free_methods.v`,
`gen_free_for_sumtype` / `gen_free_for_array` ignored the `.option` flag and
emitted sum-type/array member accesses (`it->_typ` / `it->len`) on the
`_option_*` wrapper struct → a C compile error for ANY V program with a
`?SumType` / `?[]T` field whose free-method is generated (autofree / perceus
deep-free). The fix mirrors the existing option handling in `gen_free_for_map` /
`gen_free_for_struct`; it is a pure no-op for non-option types (early-return only
on `.option`), and the clone's `v2` self-hosts cleanly with it. Independently
upstreamable; unrelated to the collector bug below (which reproduces under bare
`-gc vgc` with no free-methods at all). A minimal standalone repro that forces V
to *emit* `_option_<sumtype>_free` proved finicky (the deep-free analysis is
conservative; synthetic shapes either don't trigger it or trip a SEPARATE
pre-existing V bug — an option-typed struct field initialized by an if-expr
returning a sumtype mis-types the payload compound literal as the ENCLOSING
struct, `main__Box[]` vs `main__Shape[]`). Fix is proven on the real trigger and
by self-host; standalone repro + a regression gate case are a follow-up.

## Pure-V repro hunt (2026-06-12) — NOT yet reproduced; trigger still unknown
Five CX-free V programs in the clone, each built `-gc vgc -cc cc` vs `-gc boehm`,
all **correct under vgc** (bad=0/8) even though GC is firing (vgc ~3× boehm wall):
1. flat accumulator loop (`acc=&Acc{acc.sum+i}` × 2M, garbage each iter);
2. long live heap-linked list built while allocating garbage, validated by full
   traversal (heap-trace through pointers);
3. big live `[]Val` array of `@[heap]` sum-type values (boxed payloads) folded
   while allocating per-iter sum-type garbage, ×8;
4–5. + heap `map[string]&Node` scope per step, varied-length strings (diverse
   size classes/arenas → find_span stress), multi-variant sum type.
So the trigger is NOT: simple live-root-across-GC, heap-pointer tracing, sum-type
array scanning, map/string/diverse-size allocation, or GC frequency alone. cx
triggers it 100% on the serial fold; the distinguishing factor is still
unidentified (candidates not yet isolated: real eval recursion DEPTH; the `!`
Result-propagation temp where `acc = invoke_closure(...)!` lands; the large
`mut MatchEnv` struct threaded by-ref; the `-prod -Os`/thread_local-globals build
shape). Reproducers kept at /tmp/reclaim{,2,3,5}.v (move the winner into
bench/parallel-alloc/ once it reproduces).

## ✅ ROOT-CAUSED + FIXED 2026-06-12 — unsound per-span precise `ptrmap` scanning
Bisection on the live collector (cx as the microscope; all instrumentation/fix
CX-free, in V): (1) widening the self-thread stack scan to the FULL true pthread
stack did NOT fix it → NOT a root-range miss; (2) forcing FULL CONSERVATIVE
tracing (ignore `noscan`/`ptrmap`) → CLEAN; (3) restoring the `noscan` skip but
keeping conservative drain → still CLEAN → the bug is the **precise `ptrmap`
path**, not `noscan`, not roots.

ROOT CAUSE: `has_ptrmap`/`ptrmap` is a **per-SPAN** property set by the *first*
typed allocation (`vgc_malloc_typed_opts`, "first typed allocation wins") and
applied to every object in that span — but a span serves one size CLASS, and
real workloads pack many different TYPES (and conservative `ptrmap==0`
allocations) into the same size class. Objects whose real pointer layout differs
from the span's recorded ptrmap have live child pointers SKIPPED during mark →
reclaimed-while-reachable (the corrupted reduce results). `noscan` is reliable
(codegen sets it only for genuinely pointer-free types).

FIX (CX-free, canonical in the clone; patch `vlang-v-latest/vgc-conservative-mark-fix.patch`):
the backstop mark phase now scans every scannable (non-`noscan`) span
CONSERVATIVELY — the unsound per-span precise ptrmap path is removed
(`vgc_drain_mark_work`), and `vgc_malloc_typed_opts` no longer records a per-span
ptrmap. Conservative scanning finds every pointer (may over-retain, never
under-retains); the backstop runs rarely behind the Perceus front line, so the
mark-cost is negligible. VALIDATED: cx serial 5/5 correct + `[par]` correct;
g_churn 100 1 30 = 6/6 (fork) / 4/4 (clone), 0 corruptions; reclaim repros clean.

A standalone CX-free unit repro that deterministically re-triggers the per-span
ptrmap mismatch is still TODO (my same-size-two-types attempt didn't collide as
modeled — allocation ordering / size-class placement); the fix is proven on the
real workload + churn gate, and conservative scanning is sound against ANY
precise-ptrmap miss. The standalone gate addition is a follow-up.

## (historical) Next: root-cause the collector reclamation — V-ONLY, in the clone
The collector bug is a pure V-runtime bug; cx merely surfaced it. Reproduce it as
a **CX-free pure-V program** in the clone (deep recursion + sum-type heap nodes +
nested collections, GC firing; SELF-triggered serial vs worker-triggered parallel
— the asymmetry that points at self-thread root capture, `vgc_run_gc_spilled` +
the pre-recorded self stack range, NOT the validated mach-suspend path). Then use
the in-tree `vgc_watch_*` / `vgc_watch_snapshot` localizers to pin which step
drops the live object: (a) in a scanned root range? (b) marked? (c) swept/
decommitted? Fix in the clone, re-validate g_churn + the new repro, add it to the
standalone gate (it is exactly the gate gap), then forward-port. No CX anywhere.
