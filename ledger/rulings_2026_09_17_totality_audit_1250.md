# Audit record — #1250: the σ-placement totality audit over the FULL `[?for]` grammar (2026-09-17)

Decision: **RULED 1250-b** (`ledger/rulings_2026_09_17_integrator_decisions.md`).
Issue: cx-home/cx-private#1250. Predecessor record (1250-Q1, **withdrawn**):
`ledger/rulings_2026_09_05_comprehension_totality_1250.md`.
Spec read: `core/code.md` §7.2 (the late-filtered product and the err rule), §7.5
(generator patterns), `core/planar_algebra.md` L96 (the err rule).
Engine: `vcx/code/planar_rewrite.v` (`planar_place_filters`,
`planar_established_total`, `PlanarRewriteReport`), `vcx/code/planar_membership.v`
(`planar_generator_pattern_binds_ordered` — the #1150 walk), `vcx/code/eval.v`
(`eval_for_comp`).

## What the audit is, and why it exists

1250-Q1 ruled that the evaluator should reuse the planar σ-placement pass rather
than grow a second totality analysis. The implementation was written, measured,
and reverted the same day: `program-for-pattern-023-where-does-not-rescue`
answered `CXER0001: unbound variable $k` instead of its `CXER0100 … does not
match item 2`, because the pass under-approximated a generator's bound names on
a shape planar MEMBERS do not contain. The withdrawal's own instruction was:
audit the pass against the **full** `[?for]` grammar first, then decide.

This page is that audit, as data. It is **generated**, not written from memory:
`test_sigma_placement_audit_1250` in `vcx/tests/planar_umbrella_test.v` builds
one real program per cell, runs the pass over its clause list, prints the row,
and asserts the load-bearing property per cell —

> the rewritten clause list evaluates **byte-identically** to the original
> through the live engine, err text included.

That is L96's whole admissibility claim, checked rather than argued, 165 times.

## The axes, enumerated from the parser

**Generator pattern shapes** — every spelling `parse_for_comp_body` produces for
a `.generator` clause (`vcx/cx/program_parser.v`):

| id | shape | where the pattern lives | captures |
|---|---|---|---|
| P1 | anonymous source `[in SRC]` | — (`bind` = `_`) | `$_` |
| P2 | bind-only `[in $x SRC]` | `bind` | `$x` |
| P3 | typed bind `[in $x::T SRC]` | `expr` (`ProgramBinding`) | `$x` |
| P4 | wildcard `[in _ SRC]` | `expr` | none |
| P5 | scalar-literal pattern `[in 1 SRC]` | `expr` (`ProgramLiteral`) | none |
| P6 | element pattern in the slot `[in [row $x] SRC]` | `expr` (`ProgramPattern`) | `$x` |
| P7 | element pattern SHORTCUT `[row $x]` (grammar [129b1]) | **`source`** | `$x` |
| P8 | sequence destructuring `[in ($k, $v) SRC]` | `expr` (`sequence_lit`) | `$k $v` |
| P9 | array destructuring `[in [$a, $b] SRC]` | `expr` (`array_lit`) | `$a $b` |
| P10 | map destructuring `[in {k: $m} SRC]` | `expr` (`map_lit`) | `$m` |
| P11 | rest bind `[in ($h, *$r) SRC]` | `expr` | `$h $r` |

**Clause kinds** — every `ProgramForClauseKind` the parser produces
(`vcx/cx/program_ast.v`), plus the empty cell:
`K0` none · `K1` generator · `K2` filter · `K3` binding `[= …]` · `K4` order-by ·
`K5` group-by · `K6` limit · `K7` take · `K8` drop · `K9` take-while ·
`K10` drop-while · `K11` par · `K12` lazy · `K13` ordered · `K14` fail-fast.
(`[takewhile]`, `[dropwhile]`, `[stream]` and `[on-error]` are tombstoned
spellings — they parse to a refusal, never to a clause, so they are not cells.)

## What the audit found — four holes, all closed in the same branch

The pattern **bind collection** hole 1250-Q1 tripped over is closed by #1150's
walk (`planar_generator_pattern_binds_ordered`), which reads every [140a] kind
and which `planar_place_filters` already calls: P3, P6, P8, P9, P10 and P11
report their captures. **One implementation, never a second analysis.** Four
holes remain, and they are what this audit is for.

**A1 — the pass does not terminate (the `stdlib_docs_check.cx` hang, diagnosed).**
σ/σ commutation is admissible in BOTH directions when both predicates are
established total, and `planar_place_filters` took it whenever it was
admissible. Two adjacent total filters therefore swap forever. That is the
undiagnosed symptom the withdrawal recorded: `scripts/gen_guide/stdlib_docs_check.cx`
ran 63 minutes holding the `-j` jobserver, and its lines 194 and 216 carry
exactly that shape —

```cx
[?for [in $fd $fn-docs] [where [= $fd@name $nm]] [where [= $fd@purity $dpur]] [yield 1]]
```

`scripts/check_code_fixtures.cx` carries it too. **Admissible is not progress.**
Fixed by committing a σ/σ commutation only when it is part of reaching a slot
left of a NON-filter clause the σ actually crossed; a trailing run of
commutations is discarded, so filters keep their relative order when none of
them can move. Termination is then a potential argument: every accepted move
strictly lowers the count of non-filter clauses standing left of some σ.
Backstopped by a step budget that answers the INPUT order with a named decline
(`sigma-placement-budget`) rather than spinning — a placement pass that does not
terminate is a defect, and a silent hang is the worst refusal shape there is.

**A2 — the pattern-generator SHORTCUT carries its pattern in `source`.**
`[row $x]` (grammar [129b1]) is a `.generator` clause whose `expr` is EMPTY and
whose `source` is the `ProgramPattern`. A dependency check that reads binds off
`expr` sees none at all. Today it is saved only by the unrelated
`planar_established_total(source)` decline — an accident, not a guarantee.
Fixed by reading the same #1150 walk over `source` when it is a pattern.

**A3 — the anonymous generator `[in SRC]` binds `$_`.** `bind_for_item` calls
`env.bind_set(c.bind, item)` whenever the clause has no pattern, and `c.bind` is
`_` for `[in SRC]`. Both `planar_place_filters`'s bind set and
`planar_free_bindings` drop the name `_` as "no name", so a σ reading `$_` was
independent of the generator that binds it and hoisted above it. This is a live
defect on the shipped planar path — `[$store:query]` and `cx-stdlib/live` accept
the shape — not only on the evaluator's. Fixed: an anonymous generator
contributes its `bind` even when it is `_`.

**A4 — the implicit names the free-binding scan cannot see.**
`planar_free_bindings` drops `_position`, `_last`, `key`, `count` and `group`
from a predicate's free set, so the dependency check cannot vouch for a σ that
reads one. `[group-by]` is already a barrier, which covers `$key`/`$count`/`$group`
by position; `$_position` and `$_last` are bound at the yield boundary and have
no clause to floor against. Fixed fail-closed: a σ whose predicate reads any of
them does not move at all.

## The generated table

Columns: **binds collected** = what `planar_generator_pattern_binds_ordered`
(plus the anonymous `_` rule) returns for the generator; **predicate** =
`planar_established_total`'s verdict on the σ; **placement** = what
`planar_place_filters` did, with the applied rewrite kinds; **declined** = the
decline kinds named in the `PlanarRewriteReport`; **termination** = whether the
scan reached a fixed point inside its step budget.

Every row's CX-surface backing is a `conformance/code.cxd` case with the
`program-for-` prefix (registered for `level=core` in
`scripts/check_code_fixtures.cx`'s `PREFIX-MAP`):
`program-for-pattern-023-where-does-not-rescue` is row 1 — the 1250-Q1 failure,
still answering `CXER0100 … does not match item 2` — and
`program-for-sigma-001` … `-017` back the shape classes, the barrier classes and
the termination shape.

<!-- AUDIT-TABLE -->

## What this audit does NOT establish

- **Totality is not strengthened.** `planar_established_total` stays exactly as
  L96 left it: strict ordered comparison, arithmetic and the set operators are
  unproven without shape inference (stream 16), and a call is total only inside
  the closed allow-list. The audit measures the analysis; it does not widen it.
- **No new spec sentence.** Every rule the fixes restore is already written —
  §7.5's refusal, §7.2's late-filtered product, L96's err rule. A sentence the
  code turns out to need is a flag on the issue, not a spec edit.
- **The evaluator-side rewrite report has no CX-reachable surface** in this
  release. `store:query`'s explain path renders a `PlanarRewriteReport`; an
  ordinary `[?for]` has no such surface, and inventing one is new spec surface.
  The report is built and asserted in the test battery. Flagged, not written.
