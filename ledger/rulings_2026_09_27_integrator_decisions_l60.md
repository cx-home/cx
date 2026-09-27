# Integrator decision 2026-09-27 (evening), under the owner's delegation — Letter 60: each `[yield]` contributes exactly one item (YIELD-1)

**Status: RULED by the integrator (2026-09-27 ~21:3xZ) under the owner's word of 15:2xZ on
[#1591](https://github.com/cx-home/cx-private/issues/1591) — "away for next 5-6hrs make the best long
term cx decisions and don't blow our usage credits" — on the letter posted there at 21:3xZ from
#1690's agent; reversible by the owner's word. 1509-a, CXF-8, FIX-1, #1690.**

## The delegation, verbatim

"away for next 5-6hrs make the best long term cx decisions and don't blow our usage credits"

## YIELD-1 — a `[yield]` inside `[?for]` contributes exactly one item, whatever its type (L60 = (a))

code.md §7.2 said "the default `[?for]` yields a flat sequence", and the evaluator spliced a yielded
sequence into the result — against cxdm.md §1 (a program keeps nesting), 1509-a ("`[?for]`
contributes one sibling per `[yield]`… not a value being auto-spliced") and the primer's "nothing
auto-splices in CX"; `stdlib/flow.cx` (about 40 sites) and the connector (3) were written to §7.2.
Ruled: each `[yield]` contributes exactly one item whatever its type — a tuple, a map, an array, a
sequence — and an empty yield contributes nothing; a flat-map is spelled with a nested generator,
`[in $y E] [yield $y]`, the Scala for-yield style §7 already cites; every site that relied on the
splice is rewritten in the same round; §7.2's sentence is replaced by this one with the case ids
(RS-38, inside this decision); the existing case that pinned the splice is re-blessed by name.
Rejected: (b) keeping the splice as §7.2's normative rule with a lint hint — a permanent exception
to the language's sequence rule; (c) a new explicit flat-map word first — vocabulary the nested
generator already covers. Left open, by name: the element-body reading of a yielded pair (one child
per yield) and `(…)`/array literals nesting a whole comprehension though 1509-a calls them
multi-sibling slots — filed as its own issue.
