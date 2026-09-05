# Ruling record — #1250: the σ-pushdown totality pass the evaluator was missing already exists — reuse it, do not write a second one (2026-09-05)

Issue: #1250 (design, perf, area:cx-lang, prio:medium, analytics campaign).
Spec: `core/planar_algebra.md` L96 ("the err rule"), `core/code.md` §7.2.
Engine: `vcx/code/planar_rewrite.v` (`planar_place_filters`, `planar_established_total`),
`vcx/code/eval.v` (`eval_for_comp`).

## Correcting the record that filed this

The issue says: "Today nothing proves it for a user predicate … There is no engine pass
that establishes a `[where]` predicate total." **That is true of the EVALUATOR and false of
the engine.** `planar_established_total` (planar_rewrite.v) is exactly the conservative
totality pass the deliverable describes — path navigation total (absent → empty), position
and equality-class attribute predicates total, strict ordered comparison / arithmetic / set
operators unproven, general expression predicates unproven — and `planar_place_filters`
already consumes it to place σ at its earliest admissible position, declining loudly and
reportably when the err rule forbids the move.

What is missing is its REACH. `planar_rewrite` runs for planar members only —
`[$store:query]` (L99) and `cx-stdlib/live` — so an ordinary in-evaluator
`[?for]` with two generators and a `[where]` never sees it, and runs as the
late-filtered Cartesian product `code.md` §7.2 denotes.

## 1250-Q1 — RULED (a): extend the EXISTING pass to the evaluator's `[?for]`

- **(a) RULED.** `eval_for_comp` runs `planar_place_filters` over its clause list, gated by
  the same `planar_established_total` and reporting through the same
  `PlanarRewriteReport`, before it expands frames. **DELETES:** nothing observable —
  the rewrite set is the L96 normative set, already ruled admissible, and every move it
  cannot prove it declines. It also deletes the possibility of the two paths drifting: one
  analysis, one placement rule, one report.
- (b) write the in-evaluator totality inference the issue describes, separately. Rejected:
  it is a SECOND implementation of a ruled analysis, and the failure mode is the worst kind
  — the planar path and the evaluator path disagreeing about whether one predicate is
  total, which is a soundness divergence dressed as a performance difference.
- (c) leave it: document that a multi-generator `[?for]` is the late-filtered product.
  Rejected: the optimization is already RULED admissible (L96) and the analysis is already
  written and gated; declining to reach it is leaving a ruled capability unreachable, which
  is what this issue is.

**Semantics are unchanged by construction, and this is the load-bearing claim.** Fail-loud
fidelity outranks optimizer freedom (L96): a σ moves only when its predicate is
*established* total and the clauses it crosses are established total, so no err observation
can be destroyed, created or reordered. Everything else stays late-filtered. The clause
kinds the planar subset does not admit are already barriers in the placement pass —
`[group-by]` is a γ barrier, a pattern-bind generator crossing is declined as unproven, a
nested source carrying `[limit]`/`[take]`/`[drop]` is the σ-across-λ decline — so an
evaluator comprehension carrying them keeps today's behavior exactly.

## Exit

- A two-generator join with a selective equality predicate at n=1k/4k/16k — the
  `bench/rowset` in-run scaling-ratio method, so the guard holds on any machine. Before:
  the product's O(n·m). After: linear in the surviving frames.
- Effect-count and err-order fixtures pin the admissibility boundary: a `[where]` calling
  an impure builtin is NOT hoisted (the effect count is identical to today's); a `[where]`
  doing strict ordered comparison over an unproven shape is NOT hoisted; a `[where]` whose
  err fires on a frame the hoisted σ would have dropped still fires.
- The rewrite report is reachable for an ordinary comprehension the same way it is for a
  planar one (the honest-reporting obligation, L96): a declined move names its reason.
