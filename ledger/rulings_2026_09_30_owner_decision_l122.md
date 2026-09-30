# Owner decision 2026-09-30 — Letter 122: the binding form stays `[?let [= $x E]… BODY]`; #1719's lighter forms are refused on the measurements

**Status: RULED (owner, 2026-09-30 ~03:2xZ, in session, "l122c", on Letters 122–124 posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 03:0xZ with the design evaluation of
[#1719](https://github.com/cx-home/cx-private/issues/1719), after the owner's two follow-up questions in
session — the `[= $a 5, $b 4]` and `[? $a 5, $b 4]` forms, then `[? ($a 5, $b 4)]` — were answered with
further probes). EV-LET-SEQ, 1537-a, 1175-b, 1170-c, CXF-5, PS-1, CXF-8.**

## The owner's words, verbatim

"l122c"

## BIND-1 — the binding form is not changed; #1719 closes on this evaluation as its record (L122 = (c))

The owner asked (09-29) why the total bind needs the word `let` and a bracket per row, sketched
`[? $a 5, $b abc, $c [expression]]` with commas for many, and set the test: the program text must be a
valid document that round-trips through the data reading unchanged, and the evaluator must see the tree
`--ast` shows. Measured on `release/0.18` = `9efbfd0a2` with the release cx: a comma inside brackets is
sugar the canonical form un-sugars for every head (`[x $a 5, $b 6]` → `[x [($a, '5'), ($b, '6')]]`, the
numbers typed as text), so every comma form — `[= $a 5, $b 6]`, `[? $a 5, $b 6, …]`, `[?let $a 5, $b 6, …]`
— is not its own identity text and would need the language's first head-specific rule inside the canonical
form; a binding "into the enclosing body" has no body to enter (`?fn`/`?def` take exactly one body, `?do`
discards every value and yields `null` by #550's ruling, `?for` ends in one `[yield]`; only the module level
sequences, where `?const NAME` already binds); a map cannot carry a sequential binding set (`cx canonical`
sorts keys and a duplicate key refuses, so neither order nor shadowing survives); the pair forms that pass
the test as they stand — `[= $a 5]`, the bare-name row `[a 5]`, the sequence `($a, 5)` — are one bracket
pair each and save nothing but the head's three characters; the row `[= $x E]` is one clause shape read by
four binders (`?let`, `?for`, `?with-open`, `?loop`) through one function, so lightening it in the total bind
alone puts two spellings of the row in the language. The corpus carries a `?let` in 4,140 of 9,338 cases.
Ruled: `[?let [= $x E]… BODY]` stays as code.md §8.5 and §6.1 state it; #1719 closes on the owner's word
with the evaluation as its record; Letters 123 (how) and 124 (when) are moot. Rejected: (a) the sketched form
as the identity form — the head-specific canonical rule, a non-NCName head in the six encodings and every
editor surface, two row spellings and a one-time rewrite of the corpus, the tree and the docs; (b) bare-name
rows `[?let [a 5] …]` — no Ring-0 cost, but the bind site loses its `$` and the row still has two spellings
against `?for`'s clause; (d) `?` as `let`'s short name only — a Ring-0 name rule for three characters and the
loss of the self-describing name in the form a reader meets first.

## What lands instead — the three drifts the evaluation measured, filed as issues for after the cut

1. The let-cascade lint of 1170-c does not fire on a two-deep cascade (`cx lint`, `--fail-on=info`: exit 0,
   `[]`).
2. The LSP hover for `?let` says nested single-binding staircases are "a lint finding (L003)"; `cx lint`'s
   `CX-L003` is "unused anchor".
3. code.md §9.2 specifies the postfix `?` propagator; the program parser refuses it (`$e?` → `CXER0100
   unexpected token '?'`) and the corpus never uses it — a tombstone or an implementation, a letter of its
   own after the cut.
