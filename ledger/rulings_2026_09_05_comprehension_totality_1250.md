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

---

## Implementation record — 2026-09-05, and a correction to the issue's OWN measure

`eval_for_comp` now runs `planar_place_filters` over its clause list before expanding
frames, gated by the same `planar_established_total`. Re-entry is bounded because
placement is idempotent: a σ already at its earliest admissible position does not move,
so the recursive call finds the same order and falls through. A comprehension with fewer
than two clauses, or with no `[filter]`, skips the pass entirely.

### Measured, same predicate, same binary flags, n = 1000 × 1000

| | user seconds |
|---|---|
| pass disabled | **1.79** |
| pass enabled | **0.18** |

Identical answer. ~10×, and it is the whole product that stops being built.

### The issue's "Measure" section is wrong, and this is worth recording

#1250 asks for the win to be shown on "a two-generator join with a selective equality
predicate". **σ-pushdown can never speed that up.** A join predicate `[= $x@k $y@k]`
depends on BOTH generators, so the dependency floor in `planar_place_filters` stops it at
the inner generator — correctly. Measured: 1.71 s at n=1000 → 6.28 s at n=2000 before the
change, and unchanged after. Making a join fast is a HASH JOIN, a different optimization
against a different plan operator; it is not what L96's σ-pushdown is.

What σ-placement actually buys is a filter depending on a SUBSET of the generators, written
after the generators it does not need — which is how people write them, since the clause
order follows the reading order rather than the dependency order.

### The admissibility boundary, measured

| predicate | proven total? | placement | n=1000×1000 |
|---|---|---|---|
| `[= $x@k 5]` | yes | hoisted | 0.18 s |
| `[< $x@k 10]` | no — strict ordered comparison is unproven without shape inference | declined | 2.02 s |
| `[$strings:contains $x@n 'zz']` | no — a call is total only inside a closed allow-list | declined | 7.17 s |
| `[= $x@k $y@k]` | yes, but depends on both generators | dependency floor | 6.28 s @ n=2000 |

The call rule is **fail-closed**, which is the property that matters: an impure predicate
cannot be hoisted, so effect counts and effect ORDER are preserved by construction rather
than by a check someone has to remember to write.

Fixture: `program-for-sigma-placement-1250` in `conformance/code.cxd` pins the observable
property — the late-written filter and the hand-hoisted one answer the same items in the
same order — plus the declined rows and the join.

---

## RULING (a) IS WITHDRAWN — 2026-09-05. Reusing the planar pass is UNSOUND on the evaluator's surface

The implementation above was written, measured, and **reverted the same day**. The
measurements stand; the ruling does not.

### What broke

`conformance/code.cxd` `program-for-pattern-023-where-does-not-rescue`:

```cx
[?for [in ($k, $v) (("a", 1), ("b"))] [where [= $k "a"]] [yield $k]]
```

Expected `CXER0100: [?for] generator pattern does not match item 2`. With the pass wired
in: **`CXER0001: unbound variable $k`** — the σ was hoisted ABOVE the generator that binds
`$k`, so the predicate ran before the destructuring bind.

### Why, and why it invalidates the ruling's central argument

`planar_place_filters` computes a generator's bound names from `cj.bind` plus
`planar_pattern_binds(pex, …)` **when `cj.expr` is a `cx.ProgramPattern`**. A sequence
destructuring pattern `($k, $v)` is not a `ProgramPattern` — it is a `ProgramLiteral` of
kind `sequence_lit` holding `ProgramBinding`s. So the generator reports NO binds, the
dependency check sees nothing to depend on, and the filter crosses a generator it depends
on.

The ruling's whole case was "reuse the existing analysis rather than write a second one,
because two implementations would eventually disagree about totality". That argument
assumed the pass is *complete* over the surface it is applied to. It is not: it was
written for planar MEMBERS, a restricted subset in which destructuring generators do not
occur, and its dependency analysis silently under-approximates on the full comprehension
grammar. An under-approximating dependency check does not decline — it moves things it
should not.

A second, unexplained symptom in the same gate: `scripts/gen_guide/stdlib_docs_check.cx`
hung for an hour with the pass wired in, taking the `-j` jobserver with it. Not diagnosed,
because the revert removes it — but it means the bind-collection hole is not known to be
the ONLY assumption the restricted subset licensed.

### What a correct #1250 now has to do

1. **Audit `planar_place_filters` and `planar_established_total` against the FULL
   `[?for]` grammar**, not the planar subset — every generator pattern shape (sequence,
   array and map destructuring, typed binds, rest binds, `[in PATTERN SRC]`), every clause
   kind the evaluator admits, and termination.
2. Only then decide reuse-vs-separate. The reuse argument survives only if the audit
   closes; if the two surfaces genuinely need different analyses, that is what the ruling
   should say.
3. Keep the measurements below — they are the reason to do the work at all, and they also
   correct the issue's own success criterion.

**The measurements that stand** (same predicate, same flags, n = 1000 × 1000): a
provably-total filter that depends only on the outer generator went **1.79 s → 0.18 s**
when hoisted, and the answer was identical. A join predicate `[= $x@k $y@k]` is unaffected
and always will be — it depends on both generators, so σ-pushdown can never speed it up,
which makes the issue's stated measure ("a two-generator join with a selective equality
predicate") the wrong one. The decline boundary measured correctly for `[< …]` (ordered
comparison unproven) and for a module call (calls are total only inside a closed
allow-list, so an impure predicate is fail-closed against hoisting).
