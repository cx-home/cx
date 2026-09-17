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

| row | pattern shape | clause between | binds collected | predicate | placement | declined | termination |
|---|---|---|---|---|---|---|---|
| P1×K0 | anonymous source `[in SRC]` (binds `$_`) | none (σ directly after the generator) | `_` | total | kept at 1 (—) | — | fixed point |
| P1×K1 | anonymous source `[in SRC]` (binds `$_`) | generator `[in $y SRC]` | `_` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P1×K2 | anonymous source `[in SRC]` (binds `$_`) | filter `[where …]` | `_` | total | kept at 2 (sigma-placement) | — | fixed point |
| P1×K3 | anonymous source `[in SRC]` (binds `$_`) | binding `[= $z …]` | `_` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P1×K4 | anonymous source `[in SRC]` (binds `$_`) | order-by `[order-by …]` | `_` | total | moved 2 → 1 (sigma-pushdown-below-tau) | — | fixed point |
| P1×K5 | anonymous source `[in SRC]` (binds `$_`) | group-by `[group-by …]` | `_` | total | kept at 2 (—) | — | fixed point |
| P1×K6 | anonymous source `[in SRC]` (binds `$_`) | limit `[limit N]` | `_` | total | moved 2 → 1 (—) | — | fixed point |
| P1×K7 | anonymous source `[in SRC]` (binds `$_`) | take `[take N]` | `_` | total | moved 2 → 1 (—) | — | fixed point |
| P1×K8 | anonymous source `[in SRC]` (binds `$_`) | drop `[drop N]` | `_` | total | moved 2 → 1 (—) | — | fixed point |
| P1×K9 | anonymous source `[in SRC]` (binds `$_`) | take-while `[take-while P]` | `_` | total | kept at 2 (—) | — | fixed point |
| P1×K10 | anonymous source `[in SRC]` (binds `$_`) | drop-while `[drop-while P]` | `_` | total | kept at 2 (—) | — | fixed point |
| P1×K11 | anonymous source `[in SRC]` (binds `$_`) | par `[par]` | `_` | total | moved 2 → 1 (—) | — | fixed point |
| P1×K12 | anonymous source `[in SRC]` (binds `$_`) | lazy `[lazy]` | `_` | total | moved 2 → 1 (—) | — | fixed point |
| P1×K13 | anonymous source `[in SRC]` (binds `$_`) | ordered `[ordered]` | `_` | total | moved 2 → 1 (—) | — | fixed point |
| P1×K14 | anonymous source `[in SRC]` (binds `$_`) | fail-fast `[fail-fast]` | `_` | total | kept at 2 (—) | — | fixed point |
| P2×K0 | bind-only `[in $x SRC]` | none (σ directly after the generator) | `x` | total | kept at 1 (—) | — | fixed point |
| P2×K1 | bind-only `[in $x SRC]` | generator `[in $y SRC]` | `x` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P2×K2 | bind-only `[in $x SRC]` | filter `[where …]` | `x` | total | kept at 2 (sigma-placement) | — | fixed point |
| P2×K3 | bind-only `[in $x SRC]` | binding `[= $z …]` | `x` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P2×K4 | bind-only `[in $x SRC]` | order-by `[order-by …]` | `x` | total | moved 2 → 1 (sigma-pushdown-below-tau) | — | fixed point |
| P2×K5 | bind-only `[in $x SRC]` | group-by `[group-by …]` | `x` | total | kept at 2 (—) | — | fixed point |
| P2×K6 | bind-only `[in $x SRC]` | limit `[limit N]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P2×K7 | bind-only `[in $x SRC]` | take `[take N]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P2×K8 | bind-only `[in $x SRC]` | drop `[drop N]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P2×K9 | bind-only `[in $x SRC]` | take-while `[take-while P]` | `x` | total | kept at 2 (—) | — | fixed point |
| P2×K10 | bind-only `[in $x SRC]` | drop-while `[drop-while P]` | `x` | total | kept at 2 (—) | — | fixed point |
| P2×K11 | bind-only `[in $x SRC]` | par `[par]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P2×K12 | bind-only `[in $x SRC]` | lazy `[lazy]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P2×K13 | bind-only `[in $x SRC]` | ordered `[ordered]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P2×K14 | bind-only `[in $x SRC]` | fail-fast `[fail-fast]` | `x` | total | kept at 2 (—) | — | fixed point |
| P3×K0 | typed bind `[in $x::int SRC]` | none (σ directly after the generator) | `x` | total | kept at 1 (—) | — | fixed point |
| P3×K1 | typed bind `[in $x::int SRC]` | generator `[in $y SRC]` | `x` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P3×K2 | typed bind `[in $x::int SRC]` | filter `[where …]` | `x` | total | kept at 2 (—) | sigma-placement | fixed point |
| P3×K3 | typed bind `[in $x::int SRC]` | binding `[= $z …]` | `x` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P3×K4 | typed bind `[in $x::int SRC]` | order-by `[order-by …]` | `x` | total | moved 2 → 1 (sigma-pushdown-below-tau) | — | fixed point |
| P3×K5 | typed bind `[in $x::int SRC]` | group-by `[group-by …]` | `x` | total | kept at 2 (—) | — | fixed point |
| P3×K6 | typed bind `[in $x::int SRC]` | limit `[limit N]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P3×K7 | typed bind `[in $x::int SRC]` | take `[take N]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P3×K8 | typed bind `[in $x::int SRC]` | drop `[drop N]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P3×K9 | typed bind `[in $x::int SRC]` | take-while `[take-while P]` | `x` | total | kept at 2 (—) | — | fixed point |
| P3×K10 | typed bind `[in $x::int SRC]` | drop-while `[drop-while P]` | `x` | total | kept at 2 (—) | — | fixed point |
| P3×K11 | typed bind `[in $x::int SRC]` | par `[par]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P3×K12 | typed bind `[in $x::int SRC]` | lazy `[lazy]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P3×K13 | typed bind `[in $x::int SRC]` | ordered `[ordered]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P3×K14 | typed bind `[in $x::int SRC]` | fail-fast `[fail-fast]` | `x` | total | kept at 2 (—) | — | fixed point |
| P4×K0 | wildcard `[in _ SRC]` | none (σ directly after the generator) | `— (none)` | total | kept at 1 (—) | sigma-placement | fixed point |
| P4×K1 | wildcard `[in _ SRC]` | generator `[in $y SRC]` | `— (none)` | total | moved 2 → 1 (sigma-placement) | sigma-placement | fixed point |
| P4×K2 | wildcard `[in _ SRC]` | filter `[where …]` | `— (none)` | total | kept at 2 (—) | sigma-placement | fixed point |
| P4×K3 | wildcard `[in _ SRC]` | binding `[= $z …]` | `— (none)` | total | moved 2 → 1 (sigma-placement) | sigma-placement | fixed point |
| P4×K4 | wildcard `[in _ SRC]` | order-by `[order-by …]` | `— (none)` | total | moved 2 → 1 (sigma-pushdown-below-tau) | sigma-placement | fixed point |
| P4×K5 | wildcard `[in _ SRC]` | group-by `[group-by …]` | `— (none)` | total | kept at 2 (—) | — | fixed point |
| P4×K6 | wildcard `[in _ SRC]` | limit `[limit N]` | `— (none)` | total | moved 2 → 1 (—) | sigma-placement | fixed point |
| P4×K7 | wildcard `[in _ SRC]` | take `[take N]` | `— (none)` | total | moved 2 → 1 (—) | sigma-placement | fixed point |
| P4×K8 | wildcard `[in _ SRC]` | drop `[drop N]` | `— (none)` | total | moved 2 → 1 (—) | sigma-placement | fixed point |
| P4×K9 | wildcard `[in _ SRC]` | take-while `[take-while P]` | `— (none)` | total | kept at 2 (—) | — | fixed point |
| P4×K10 | wildcard `[in _ SRC]` | drop-while `[drop-while P]` | `— (none)` | total | kept at 2 (—) | — | fixed point |
| P4×K11 | wildcard `[in _ SRC]` | par `[par]` | `— (none)` | total | moved 2 → 1 (—) | sigma-placement | fixed point |
| P4×K12 | wildcard `[in _ SRC]` | lazy `[lazy]` | `— (none)` | total | moved 2 → 1 (—) | sigma-placement | fixed point |
| P4×K13 | wildcard `[in _ SRC]` | ordered `[ordered]` | `— (none)` | total | moved 2 → 1 (—) | sigma-placement | fixed point |
| P4×K14 | wildcard `[in _ SRC]` | fail-fast `[fail-fast]` | `— (none)` | total | kept at 2 (—) | — | fixed point |
| P5×K0 | scalar-literal pattern `[in 1 SRC]` | none (σ directly after the generator) | `— (none)` | total | kept at 1 (—) | sigma-placement | fixed point |
| P5×K1 | scalar-literal pattern `[in 1 SRC]` | generator `[in $y SRC]` | `— (none)` | total | moved 2 → 1 (sigma-placement) | sigma-placement | fixed point |
| P5×K2 | scalar-literal pattern `[in 1 SRC]` | filter `[where …]` | `— (none)` | total | kept at 2 (—) | sigma-placement | fixed point |
| P5×K3 | scalar-literal pattern `[in 1 SRC]` | binding `[= $z …]` | `— (none)` | total | moved 2 → 1 (sigma-placement) | sigma-placement | fixed point |
| P5×K4 | scalar-literal pattern `[in 1 SRC]` | order-by `[order-by …]` | `— (none)` | total | moved 2 → 1 (sigma-pushdown-below-tau) | sigma-placement | fixed point |
| P5×K5 | scalar-literal pattern `[in 1 SRC]` | group-by `[group-by …]` | `— (none)` | total | kept at 2 (—) | — | fixed point |
| P5×K6 | scalar-literal pattern `[in 1 SRC]` | limit `[limit N]` | `— (none)` | total | moved 2 → 1 (—) | sigma-placement | fixed point |
| P5×K7 | scalar-literal pattern `[in 1 SRC]` | take `[take N]` | `— (none)` | total | moved 2 → 1 (—) | sigma-placement | fixed point |
| P5×K8 | scalar-literal pattern `[in 1 SRC]` | drop `[drop N]` | `— (none)` | total | moved 2 → 1 (—) | sigma-placement | fixed point |
| P5×K9 | scalar-literal pattern `[in 1 SRC]` | take-while `[take-while P]` | `— (none)` | total | kept at 2 (—) | — | fixed point |
| P5×K10 | scalar-literal pattern `[in 1 SRC]` | drop-while `[drop-while P]` | `— (none)` | total | kept at 2 (—) | — | fixed point |
| P5×K11 | scalar-literal pattern `[in 1 SRC]` | par `[par]` | `— (none)` | total | moved 2 → 1 (—) | sigma-placement | fixed point |
| P5×K12 | scalar-literal pattern `[in 1 SRC]` | lazy `[lazy]` | `— (none)` | total | moved 2 → 1 (—) | sigma-placement | fixed point |
| P5×K13 | scalar-literal pattern `[in 1 SRC]` | ordered `[ordered]` | `— (none)` | total | moved 2 → 1 (—) | sigma-placement | fixed point |
| P5×K14 | scalar-literal pattern `[in 1 SRC]` | fail-fast `[fail-fast]` | `— (none)` | total | kept at 2 (—) | — | fixed point |
| P6×K0 | element pattern in the slot `[in [row $x] SRC]` | none (σ directly after the generator) | `x` | total | kept at 1 (—) | — | fixed point |
| P6×K1 | element pattern in the slot `[in [row $x] SRC]` | generator `[in $y SRC]` | `x` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P6×K2 | element pattern in the slot `[in [row $x] SRC]` | filter `[where …]` | `x` | total | kept at 2 (—) | sigma-placement | fixed point |
| P6×K3 | element pattern in the slot `[in [row $x] SRC]` | binding `[= $z …]` | `x` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P6×K4 | element pattern in the slot `[in [row $x] SRC]` | order-by `[order-by …]` | `x` | total | moved 2 → 1 (sigma-pushdown-below-tau) | — | fixed point |
| P6×K5 | element pattern in the slot `[in [row $x] SRC]` | group-by `[group-by …]` | `x` | total | kept at 2 (—) | — | fixed point |
| P6×K6 | element pattern in the slot `[in [row $x] SRC]` | limit `[limit N]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P6×K7 | element pattern in the slot `[in [row $x] SRC]` | take `[take N]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P6×K8 | element pattern in the slot `[in [row $x] SRC]` | drop `[drop N]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P6×K9 | element pattern in the slot `[in [row $x] SRC]` | take-while `[take-while P]` | `x` | total | kept at 2 (—) | — | fixed point |
| P6×K10 | element pattern in the slot `[in [row $x] SRC]` | drop-while `[drop-while P]` | `x` | total | kept at 2 (—) | — | fixed point |
| P6×K11 | element pattern in the slot `[in [row $x] SRC]` | par `[par]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P6×K12 | element pattern in the slot `[in [row $x] SRC]` | lazy `[lazy]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P6×K13 | element pattern in the slot `[in [row $x] SRC]` | ordered `[ordered]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P6×K14 | element pattern in the slot `[in [row $x] SRC]` | fail-fast `[fail-fast]` | `x` | total | kept at 2 (—) | — | fixed point |
| P7×K0 | element pattern SHORTCUT `[row $x]` (the pattern is the SOURCE) | none (σ directly after the generator) | `x` | total | kept at 1 (—) | — | fixed point |
| P7×K1 | element pattern SHORTCUT `[row $x]` (the pattern is the SOURCE) | generator `[in $y SRC]` | `x` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P7×K2 | element pattern SHORTCUT `[row $x]` (the pattern is the SOURCE) | filter `[where …]` | `x` | total | kept at 2 (—) | sigma-placement | fixed point |
| P7×K3 | element pattern SHORTCUT `[row $x]` (the pattern is the SOURCE) | binding `[= $z …]` | `x` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P7×K4 | element pattern SHORTCUT `[row $x]` (the pattern is the SOURCE) | order-by `[order-by …]` | `x` | total | moved 2 → 1 (sigma-pushdown-below-tau) | — | fixed point |
| P7×K5 | element pattern SHORTCUT `[row $x]` (the pattern is the SOURCE) | group-by `[group-by …]` | `x` | total | kept at 2 (—) | — | fixed point |
| P7×K6 | element pattern SHORTCUT `[row $x]` (the pattern is the SOURCE) | limit `[limit N]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P7×K7 | element pattern SHORTCUT `[row $x]` (the pattern is the SOURCE) | take `[take N]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P7×K8 | element pattern SHORTCUT `[row $x]` (the pattern is the SOURCE) | drop `[drop N]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P7×K9 | element pattern SHORTCUT `[row $x]` (the pattern is the SOURCE) | take-while `[take-while P]` | `x` | total | kept at 2 (—) | — | fixed point |
| P7×K10 | element pattern SHORTCUT `[row $x]` (the pattern is the SOURCE) | drop-while `[drop-while P]` | `x` | total | kept at 2 (—) | — | fixed point |
| P7×K11 | element pattern SHORTCUT `[row $x]` (the pattern is the SOURCE) | par `[par]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P7×K12 | element pattern SHORTCUT `[row $x]` (the pattern is the SOURCE) | lazy `[lazy]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P7×K13 | element pattern SHORTCUT `[row $x]` (the pattern is the SOURCE) | ordered `[ordered]` | `x` | total | moved 2 → 1 (—) | — | fixed point |
| P7×K14 | element pattern SHORTCUT `[row $x]` (the pattern is the SOURCE) | fail-fast `[fail-fast]` | `x` | total | kept at 2 (—) | — | fixed point |
| P8×K0 | sequence destructuring `[in ($k, $v) SRC]` | none (σ directly after the generator) | `k v` | total | kept at 1 (—) | — | fixed point |
| P8×K1 | sequence destructuring `[in ($k, $v) SRC]` | generator `[in $y SRC]` | `k v` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P8×K2 | sequence destructuring `[in ($k, $v) SRC]` | filter `[where …]` | `k v` | total | kept at 2 (—) | sigma-placement | fixed point |
| P8×K3 | sequence destructuring `[in ($k, $v) SRC]` | binding `[= $z …]` | `k v` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P8×K4 | sequence destructuring `[in ($k, $v) SRC]` | order-by `[order-by …]` | `k v` | total | moved 2 → 1 (sigma-pushdown-below-tau) | — | fixed point |
| P8×K5 | sequence destructuring `[in ($k, $v) SRC]` | group-by `[group-by …]` | `k v` | total | kept at 2 (—) | — | fixed point |
| P8×K6 | sequence destructuring `[in ($k, $v) SRC]` | limit `[limit N]` | `k v` | total | moved 2 → 1 (—) | — | fixed point |
| P8×K7 | sequence destructuring `[in ($k, $v) SRC]` | take `[take N]` | `k v` | total | moved 2 → 1 (—) | — | fixed point |
| P8×K8 | sequence destructuring `[in ($k, $v) SRC]` | drop `[drop N]` | `k v` | total | moved 2 → 1 (—) | — | fixed point |
| P8×K9 | sequence destructuring `[in ($k, $v) SRC]` | take-while `[take-while P]` | `k v` | total | kept at 2 (—) | — | fixed point |
| P8×K10 | sequence destructuring `[in ($k, $v) SRC]` | drop-while `[drop-while P]` | `k v` | total | kept at 2 (—) | — | fixed point |
| P8×K11 | sequence destructuring `[in ($k, $v) SRC]` | par `[par]` | `k v` | total | moved 2 → 1 (—) | — | fixed point |
| P8×K12 | sequence destructuring `[in ($k, $v) SRC]` | lazy `[lazy]` | `k v` | total | moved 2 → 1 (—) | — | fixed point |
| P8×K13 | sequence destructuring `[in ($k, $v) SRC]` | ordered `[ordered]` | `k v` | total | moved 2 → 1 (—) | — | fixed point |
| P8×K14 | sequence destructuring `[in ($k, $v) SRC]` | fail-fast `[fail-fast]` | `k v` | total | kept at 2 (—) | — | fixed point |
| P9×K0 | array destructuring `[in [$a, $b] SRC]` | none (σ directly after the generator) | `a b` | total | kept at 1 (—) | — | fixed point |
| P9×K1 | array destructuring `[in [$a, $b] SRC]` | generator `[in $y SRC]` | `a b` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P9×K2 | array destructuring `[in [$a, $b] SRC]` | filter `[where …]` | `a b` | total | kept at 2 (—) | sigma-placement | fixed point |
| P9×K3 | array destructuring `[in [$a, $b] SRC]` | binding `[= $z …]` | `a b` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P9×K4 | array destructuring `[in [$a, $b] SRC]` | order-by `[order-by …]` | `a b` | total | moved 2 → 1 (sigma-pushdown-below-tau) | — | fixed point |
| P9×K5 | array destructuring `[in [$a, $b] SRC]` | group-by `[group-by …]` | `a b` | total | kept at 2 (—) | — | fixed point |
| P9×K6 | array destructuring `[in [$a, $b] SRC]` | limit `[limit N]` | `a b` | total | moved 2 → 1 (—) | — | fixed point |
| P9×K7 | array destructuring `[in [$a, $b] SRC]` | take `[take N]` | `a b` | total | moved 2 → 1 (—) | — | fixed point |
| P9×K8 | array destructuring `[in [$a, $b] SRC]` | drop `[drop N]` | `a b` | total | moved 2 → 1 (—) | — | fixed point |
| P9×K9 | array destructuring `[in [$a, $b] SRC]` | take-while `[take-while P]` | `a b` | total | kept at 2 (—) | — | fixed point |
| P9×K10 | array destructuring `[in [$a, $b] SRC]` | drop-while `[drop-while P]` | `a b` | total | kept at 2 (—) | — | fixed point |
| P9×K11 | array destructuring `[in [$a, $b] SRC]` | par `[par]` | `a b` | total | moved 2 → 1 (—) | — | fixed point |
| P9×K12 | array destructuring `[in [$a, $b] SRC]` | lazy `[lazy]` | `a b` | total | moved 2 → 1 (—) | — | fixed point |
| P9×K13 | array destructuring `[in [$a, $b] SRC]` | ordered `[ordered]` | `a b` | total | moved 2 → 1 (—) | — | fixed point |
| P9×K14 | array destructuring `[in [$a, $b] SRC]` | fail-fast `[fail-fast]` | `a b` | total | kept at 2 (—) | — | fixed point |
| P10×K0 | map destructuring `[in {k: $m} SRC]` | none (σ directly after the generator) | `m` | total | kept at 1 (—) | — | fixed point |
| P10×K1 | map destructuring `[in {k: $m} SRC]` | generator `[in $y SRC]` | `m` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P10×K2 | map destructuring `[in {k: $m} SRC]` | filter `[where …]` | `m` | total | kept at 2 (—) | sigma-placement | fixed point |
| P10×K3 | map destructuring `[in {k: $m} SRC]` | binding `[= $z …]` | `m` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P10×K4 | map destructuring `[in {k: $m} SRC]` | order-by `[order-by …]` | `m` | total | moved 2 → 1 (sigma-pushdown-below-tau) | — | fixed point |
| P10×K5 | map destructuring `[in {k: $m} SRC]` | group-by `[group-by …]` | `m` | total | kept at 2 (—) | — | fixed point |
| P10×K6 | map destructuring `[in {k: $m} SRC]` | limit `[limit N]` | `m` | total | moved 2 → 1 (—) | — | fixed point |
| P10×K7 | map destructuring `[in {k: $m} SRC]` | take `[take N]` | `m` | total | moved 2 → 1 (—) | — | fixed point |
| P10×K8 | map destructuring `[in {k: $m} SRC]` | drop `[drop N]` | `m` | total | moved 2 → 1 (—) | — | fixed point |
| P10×K9 | map destructuring `[in {k: $m} SRC]` | take-while `[take-while P]` | `m` | total | kept at 2 (—) | — | fixed point |
| P10×K10 | map destructuring `[in {k: $m} SRC]` | drop-while `[drop-while P]` | `m` | total | kept at 2 (—) | — | fixed point |
| P10×K11 | map destructuring `[in {k: $m} SRC]` | par `[par]` | `m` | total | moved 2 → 1 (—) | — | fixed point |
| P10×K12 | map destructuring `[in {k: $m} SRC]` | lazy `[lazy]` | `m` | total | moved 2 → 1 (—) | — | fixed point |
| P10×K13 | map destructuring `[in {k: $m} SRC]` | ordered `[ordered]` | `m` | total | moved 2 → 1 (—) | — | fixed point |
| P10×K14 | map destructuring `[in {k: $m} SRC]` | fail-fast `[fail-fast]` | `m` | total | kept at 2 (—) | — | fixed point |
| P11×K0 | rest bind `[in ($h, *$r) SRC]` | none (σ directly after the generator) | `h r` | total | kept at 1 (—) | — | fixed point |
| P11×K1 | rest bind `[in ($h, *$r) SRC]` | generator `[in $y SRC]` | `h r` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P11×K2 | rest bind `[in ($h, *$r) SRC]` | filter `[where …]` | `h r` | total | kept at 2 (—) | sigma-placement | fixed point |
| P11×K3 | rest bind `[in ($h, *$r) SRC]` | binding `[= $z …]` | `h r` | total | moved 2 → 1 (sigma-placement) | — | fixed point |
| P11×K4 | rest bind `[in ($h, *$r) SRC]` | order-by `[order-by …]` | `h r` | total | moved 2 → 1 (sigma-pushdown-below-tau) | — | fixed point |
| P11×K5 | rest bind `[in ($h, *$r) SRC]` | group-by `[group-by …]` | `h r` | total | kept at 2 (—) | — | fixed point |
| P11×K6 | rest bind `[in ($h, *$r) SRC]` | limit `[limit N]` | `h r` | total | moved 2 → 1 (—) | — | fixed point |
| P11×K7 | rest bind `[in ($h, *$r) SRC]` | take `[take N]` | `h r` | total | moved 2 → 1 (—) | — | fixed point |
| P11×K8 | rest bind `[in ($h, *$r) SRC]` | drop `[drop N]` | `h r` | total | moved 2 → 1 (—) | — | fixed point |
| P11×K9 | rest bind `[in ($h, *$r) SRC]` | take-while `[take-while P]` | `h r` | total | kept at 2 (—) | — | fixed point |
| P11×K10 | rest bind `[in ($h, *$r) SRC]` | drop-while `[drop-while P]` | `h r` | total | kept at 2 (—) | — | fixed point |
| P11×K11 | rest bind `[in ($h, *$r) SRC]` | par `[par]` | `h r` | total | moved 2 → 1 (—) | — | fixed point |
| P11×K12 | rest bind `[in ($h, *$r) SRC]` | lazy `[lazy]` | `h r` | total | moved 2 → 1 (—) | — | fixed point |
| P11×K13 | rest bind `[in ($h, *$r) SRC]` | ordered `[ordered]` | `h r` | total | moved 2 → 1 (—) | — | fixed point |
| P11×K14 | rest bind `[in ($h, *$r) SRC]` | fail-fast `[fail-fast]` | `h r` | total | kept at 2 (—) | — | fixed point |

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
