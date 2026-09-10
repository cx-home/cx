# RULED: 1192-a — `[?else]` does not coalesce E_NO_CALLABLE; every other failure and absence still does

**Fable, 2026-09-10 06:55Z, under the owner's delegation:** item 1 of the
issue, NARROWED to the one code that is unambiguously a program defect —
`CXER0136 E_NO_CALLABLE`, a call head that named nothing. Refused item 2 (a
strict `[?else-value]` twin): two spellings of one coalesce is the dual-accept
class, and the census says nothing needs the lenient one — 21 `[?else [$…`
sites in stdlib/ and x/, every head a resolvable callable. Refused item 3 alone
(a lint): a lint at authoring time is worth having later, but the runtime is
where the silence lives, and a lint cannot see a callable that resolves in one
ring and not another. Refused widening to "every resolution failure": an arity
mismatch is CXER0100 today, the same code as a hundred data faults, and
`CXER0001` "no member" is the code §8.13's own example (`[?else $m.$k
DEFAULT]`) RELIES on coalescing — so the class cannot be drawn by code beyond
the one that is its own class.

## The principle

`[?else]` unifies the absence and failure channels for DATA conditions: a
missing key, an out-of-range read, a computation that refused. A program that
names a function which does not exist is not in a data condition; no default
is a correct answer to it, and coalescing it produced a document that parses,
loads, composes and serves while returning `''` for every field. The model is
§8.9.2's `[tap]`: `CXER0001` (CX_PANIC) and `CXER0260` (cancellation) pass
through a tap that discards every other error, for the same reason.

## What changed

- `eval_else` (eval.v): an `[err code=cx-err:CXER0136]` value — or a thrown
  EvalError with that code — passes through; every other `[err]` and absence
  takes DEFAULT as before (`else_propagates_code`).
- code.md §8.13 truth table: the one exception row, with the token.
- Fixtures `code.cxd` `program-else-001-no-callable-propagates` (RED before:
  `'FELL'`) and `program-else-002-value-conditions-still-coalesce` (division
  by zero, absence, missing member, present null — unchanged).
