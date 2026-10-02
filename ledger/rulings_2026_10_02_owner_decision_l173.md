# Owner decision 2026-10-02 ~21:1xZ — Letter 173 = (a): `[order-by]` takes its keys in one clause, each with its own direction, as a stable lexicographic sort; a second clause is refused by name

**Status: RULED (owner, 2026-10-02 ~21:1xZ, in session, "a", on the integrator's measurement posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 21:0xZ; recorded by the integrator the same hour).
SHIP-1, RS-38, VOCAB-1, QUAL-1; #1761; code.md §(the comprehension clauses, the grammar line
`([order-by EXPR (asc|desc)?])?`), docs/llm/primer.md §5 ("`[order-by]` sorts, and takes a direction and multiple keys").**

## The owner's words, verbatim

"In playground #24 the order-by works with 'desc' but not 'asc'. Needs fixing. Also, let's show one example in #24
where two fields are being used to order-by, one 'desc' and the other 'asc'. Multiple field sort definitions must be
fully supported." — "a"

## What was measured on the release cx `v0.18.0-pre.1-dev+2468144ed` (the primer's example)

`[order-by $u/@age desc]` → C B A; `[order-by $u/@age asc]` → A C B (ascending, ties in input order);
two clauses `[order-by $u/@age desc] [order-by $u/@name asc]` → A B C — the second clause silently REPLACES the
first (a composed sort answers B C A); two keys in one clause `[order-by $u/@age desc $u/@name asc]` →
`CXER0100: parse: expected ']' (closing [order-by …])`. The spec grammar grants one optional clause with one key;
the primer claims multiple keys and writes two clauses. The owner's `asc` failure is in the browser engine or
playground example 24 (the live site being the 09-29 build, #1758).

## ORDK-1 — the multi-key sort is one clause, keys in order, each with its own direction (L173 = (a))

The grammar becomes `[order-by KEY (asc|desc)? (KEY (asc|desc)?)*]`: the items are sorted by the first key, ties by
the second, and so on — a stable lexicographic sort, each key with its own direction, `asc` the default. A second
`[order-by]` clause in one `[?for]` is refused at parse time by name (today's silent replacement is the defect
the owner found). The spec sentence moves with the case ids (RS-38): the composed sort with mixed directions, the
default direction, a refused second clause, stability on ties; the primer's §5 sentence and example are trued to
the one form; playground #24 shows two fields, one `desc` and one `asc`, as the owner asked; the browser-engine
`asc` reproduction is fixed or filed by name. Rejected: (b) repeated clauses composing (a sort read across
clauses; the grammar's `?` to `*`); (c) both forms (two spellings for one thing, VOCAB-1's cost).
