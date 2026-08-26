# Rulings — Auto/CFG nested value tables (#1031), 2026-08-26

Authorizing issue: **#1031** (owner-requested design, reported with a
screenshot over playground example [130] and "many similar"). Branch
`wave8/1031-nested-tables`, off `release/0.17` @ `ab7f9b6d9`.

The issue's own text is the authorization for everything below: a CFG
node carrying a nested element VALUE renders as NESTED TABLES — head as
the table header, element children as inner tables of name│value rows,
sequence / array items as rows — reusing #992's flowchart HTML-label
machinery; Detail governs depth and cells; every emitted diagram parses
under the vendored mermaid; values HTML-escaped; total cells per node
capped with loud elision; no page-layout overflow.

---

## NT-1 — the defect, and why `cd-label` was not the place to fix it

`[= $doc [post [title "On X"] [author "Alice"] [body "..."] [tags "T1" "T2"]]]`
rendered as one box holding one line:

```
lt["[= $doc [post [title 'On X'] [author 'Alice'] [body '...'] [tags 'T1' 'T2']]]"]
```

`cd-label` is a SUMMARY function and it is the right function for a
diamond's condition and a loop header. A document is not a summary — it
has structure, and a line cannot carry structure. So `cd-label` is left
exactly as it is, and a second, table-shaped spelling is added beside it
(§9.4b, `cd-nl`) for the node kinds that carry values.

## NT-2 — the form is a flowchart HTML label; #992's measurement is not re-litigated

#992 measured the three mermaid forms that could carry a name│value
table against the bundled renderer and disqualified two of them. That
finding stands and is REUSED, not re-argued:

- **erDiagram rows — disqualified ON THE VALUES.** Both unquoted ER
  columns are `ATTRIBUTE_WORD`s, `[A-Za-z_][A-Za-z0-9_\-\[\]()]*`, so
  `42`, `-5`, `99.5`, `:ok` and `can't` cannot be spelled in either
  column at all; putting them there means rendering `min=-5` as
  `min __5`. Independently, an ERD has one entity per element NAME,
  which is the wrong cardinality for a document that repeats a name
  (`[users [user …] [user …] [user …]]`).
- **classDiagram members — disqualified on ORDER.** mermaid routes any
  member containing `(` into the methods compartment, so a
  paren-carrying value leaves document order.
- **flowchart node + HTML label — adopted.** Real aligned columns, a
  header row, genuine nesting, CSS from `playground.css`, and every
  value HTML-escaped so no value can break the diagram.

Both mermaid initialisations in the tree (`playground.js` and
`scripts/test_playground_mermaid.mjs`) already set `htmlLabels: true`
and `securityLevel: 'loose'`, and mermaid's own flowchart default for
`htmlLabels` is on — so the form the labels are written for is the form
that renders, in the page and in the gate.

## NT-3 — the nesting model

A value renders in one of three forms.

- **Line** — no attributes and no element children: `cd-label`,
  unchanged. This is the majority of nodes and the reason the golden
  movement is two files (NT-7).
- **Row** — a LEAF element inside a parent table: one row, keyed by the
  element name, whose cell is its value bodies joined (`title │ 'On X'`,
  `tags │ 'T1', 'T2'`). A leaf child is a ROW, not a box; this
  compaction is what makes the outer table readable.
- **Table** — an element with at least one attribute or element child,
  or a sequence / array with at least one structured item. Two columns.
  The header row carries the head; rows follow in DOCUMENT ORDER —
  attributes as `@name`, nested elements by name, value bodies keyed by
  KIND (#992's rule for a body with no name of its own), sequence and
  array items keyed by ORDINAL (an item list has an order, not names).

**NT-3a — an inner table carries no header.** The parent row's key
already names it; repeating the name is noise. Depth reads from a left
rule and one step down in type size, never from margins — the whole
label is one `<foreignObject>` and compounding indentation at depth 4
would push the node past the pane.

**NT-3b — a binding keeps its target in the header.** `[= $target VALUE]`
renders as one table headed `$doc = post`, naming both the binding the
reader is scanning for and the head of the document beneath it. A line
could only do that by spending its width on punctuation.

**NT-3c — a sequence of plain scalars stays inline.** `(1, 2, 3)` needs
no grid. Inside a cell it spells its items rather than falling to
`cd-label`'s `<lit>`, which carried nothing. This is cell-local: it does
not move `cd-label`, and therefore moves no golden outside a table node.

## NT-4 — what is deliberately NOT converted

- **Diamonds and hexagons** — `if`, `match`, loop headers, `modify`.
  These carry a CONDITION, not a document, and mermaid draws a table
  inside a diamond badly.
- **`min`** — untouched at every level. `cd-cfg-min` emits one box per
  top-level def plus `main` and never reaches a value label, so the
  issue's "min = head only (today's line)" is satisfied by changing
  nothing. Every `min` golden is byte-identical.
- **`cd-synth-block`** — the multi-item clause wrapper §9.5 synthesises.
  Excluded BY NAME, for the same reason `cd-label` singles it out: its
  tag is not something anyone wrote and must never reach a table header.
  A multi-statement `[then …]` body keeps today's `<lit>`; it is not one
  of the three shapes #1031 names.
- **The `cd-if-arm-emit` / `cd-match-emit` escape asymmetry.** The arm
  label has never run through `cd-esc` in the `if` emitter and always
  has in the `match` emitter. That asymmetry is carried faithfully
  (`cd-nl-one`'s `$esc` parameter) rather than tidied: closing it would
  move golden bytes #1031 did not authorize. Named here so it is a known
  open question (NT-9), not a silent inconsistency.

## NT-5 — the rung's cuts, and the caps

The detail rung rides the threaded CFG state as a seventh field (`cst.dt`)
rather than becoming a parameter on twenty emitters. It has to be
threaded rather than recovered downstream because `cd-cfg-full` layers
over compact's TEXT — the rung is not visible in the lines.

| | depth | rows/table | data rows/node | data cells/node | items/cell | chars/cell |
|---|---|---|---|---|---|---|
| `min` | — | — | — | — | — | — |
| `compact` | 1 | 8 | 24 | 48 | 4 | 48 |
| `full` | 4 | 12 | 60 | 120 | 8 | 48 |

Cells are two per row. The node budget counts DATA rows and is spent
ACROSS every table in the node, threaded through the recursion, so a
wide-and-deep document cannot balloon the box even though each
individual table is inside its own per-table cap. Header rows and
`(+N more)` notes are NOT charged against it — a cap must not be able to
hide the notice that it fired.

Measured on a 12 × 6-attribute document at `full`: 63 `<tr>` = 1 header
+ 60 data + 2 elision notes. The budget is exact.

Whichever cap bites first, the remainder becomes one `(+N more)` row —
the established elision idiom, and loud by contract: a table that
quietly stopped is this issue's defect one level down.

**NT-5c — a single-child chain is a PATH, and spends no depth.**
MEASURED IN THE PANE, example [127] at `full`.
`[root [a [b [c [d marker=hit]]]] [x [y marker=miss]]]` nested one table
per level renders as a HORIZONTAL CASCADE of one-row tables —
`a │ b │ c │ d │ @marker='hit'` — which reads as four SIBLINGS. That is
WORSE than the flat line this issue is fixing, because it does not
merely under-inform, it actively misinforms about the shape.

So a level that carries nothing of its own — no attributes, no value
bodies, exactly one element child — folds into its child, and the row is
keyed by the CX path `a/b/c/d`: the spelling the rest of the diagram
already uses for this exact shape, so a reader learns nothing new to
read it. Folding spends no depth and no budget on levels that say
nothing, which is why `compact` gains from it too — `a/b/c/d │
@marker='hit'` where it would otherwise have said `[a (+1 more)]`.

**NT-5d — the nesting boundary is drawn, not implied.** Also measured: a
1px hairline in `--border-soft` is invisible against the node fill at
these sizes, and with no visible boundary a nested table reads as
another COLUMN of its parent rather than as content inside one cell. The
inset rule is 2px in the element-name accent, with a faint wash on the
cell.

**NT-5a — an unopened child is SUMMARISED, not merely counted.**
Measured on the very examples #1031 was filed over. A one-level
`compact` that elides every structured child renders
`[users [user id=1 …] [user id=2 …] [user id=3 …] [user id=4 …]]` as four
identical rows all reading `[user (+3 more)]` — structurally honest and
almost informationless, which is this issue's defect wearing a different
hat. So a child the rung will not open shows its attributes and leaf
children as chips in the value cell (`@id=1 @name='Alice' @banned=false`),
and only what genuinely cannot be flattened — a grandchild with structure
of its own — is counted into the trailing `(+N more)`. `compact` stays at
ONE LEVEL OF TABLE, which is the contract; the level it draws is worth
reading. The chip spelling is §2's `chips-upto` spelling, so the two
rungs read as one language. This is also what a depth-capped or
budget-capped cell falls back to at `full`, so a capped cell is never
less informative than a compact one.

**NT-5b — only the note half of a summary cell is dimmed.** The withheld
count sits in its own `cxp-vtbl-more` span. Dimming the whole cell would
misreport `@id=1 @name='Alice'` as a note about the diagram rather than
as the document's own content.

## NT-6 — structure is ASKED FOR, never parsed

Every child role comes from the §4 program image — `cx:attr` children,
the value tags, the `cx-node` mark, `cd-is-eq-clause` for the binding
shape, `cd-src-name` for a renamed element (#898 / DRW3-9). Nothing in
§9.4b splits a string. This is the contract #999, #1000, #1020 and #1025
were fixed to report honestly, and reading it is the whole reason the
tables can be trusted.

Values are escaped with NAMED HTML entities and `#` last, because `#` is
mermaid's own entity introducer and a numeric `&#40;` would be rewritten
before the browser saw it. Order is `&` first, `#` last.

## NT-7 — golden movement, adjudicated (DR-8)

`vcx/tests/testdata/code_diagram_golden/` is frozen under DR-8:
regeneration after the wave-3 capture is golden movement, forbidden
except under a mini-ruling recorded here BEFORE the bytes move. **This is
that authorization**, recorded before regeneration.

Movement, MEASURED over all 92 sources × 3 levels = 276 goldens with the
new emitter in place and nothing regenerated:

- **UNCHANGED: 274.**
- **MOVED: 2** — `pin-err-literal-cfg-branch.compact` and
  `pin-err-literal-cfg-branch.full`, one line each, the same line in
  both:

  ```
  -   t["[err]"]
  +   t["<table class='cxp-itbl cxp-vtbl'>…<td>@code</td><td>'x'</td>…</table>"]
  ```

  Source: `[?if [= 1 1] [then [err code="x"]] [else [ping]]]`.

The old label was LOSSY: `cd-element-label` excludes `cx:attr` from
items, so `[err code="x"]` printed as `[err]` and the attribute — the
only content the element had — appeared nowhere. The new cell shows it.
A single-row table is accepted here rather than special-cased into a
line, on #992's precedent: the instance view already draws a one-row
table for a one-attribute element, and two spellings for the same shape
would be the worse outcome.

Nothing else moves. Every `min` golden, every ERD golden, every SEQ
golden, every node id, every edge, every subgraph and every basic-block
`(+K more)` row is byte-identical. `test-code-diagram` compares node-SETS
and edge-SETS, not label bytes, so it is unaffected by construction.

## NT-8 — the validity gate is the floor, and it grows to cover the new shapes

`make test-playground-mermaid` walks
`example × {auto, instance} × {source, output} × {min, compact, full}`
against the vendored `mermaid.min.js` the page itself loads. The new
tables are emitted into the `auto` half of that cross product from the
built wasm engine, so the gate covers them WITHOUT a new enumeration:
the same 2,070 diagrams now include the table-bearing ones, and the
requirement is unchanged — zero failures.

## NT-9 — open questions, recorded not decided

Three, all found while doing this work, none of them this issue's to
close. Each moves golden bytes or needs a change outside §9.4b, so each
belongs to its own issue with its own authorization.

**NT-9a — the `cd-esc` asymmetry.** `cd-if-arm-emit` has never run its
arm label through `cd-esc`; `cd-match-emit` always has (NT-4). One of
the two is wrong: an unescaped arm label emits unparseable mermaid for
any value carrying a `"`.

**NT-9b — nested `[?let]` mints a DUPLICATE node id.** PRE-EXISTING and
verified against the committed golden at `HEAD`:
`pin-cfg-nested-let.compact.golden` already contains two nodes both
named `lt` and a self-edge `lt --> lt`. Mermaid keeps the last
definition, so the outer binding is not drawn at all. #1031 does not
cause this and does not change id minting — but it makes the consequence
LOUDER, because what silently disappears is now a whole table rather
than a short line (seen in the pane on example [150], which has two
nested lets and draws one of them).

**NT-9c — a `[?element]` body is out of reach, honestly.** The §4 image
hands the emitter an OPAQUE EXPRESSION carrying the verbatim source text
for `[?element …]`, not a tree: `[?element "wrapper" [inner a=1 [deep
b=2]]]` arrives as that string. §9.4b therefore cannot table it, and
must not try — NT-6 forbids parsing text to recover structure. The
honest fix is upstream, in the image, on the same lane #999/#1000/#1020
and #1025 travelled; once the structure is carried, §9.4b picks it up
with no change here. Recorded because the issue's parenthetical names
`?element` bodies among the shapes that carry nested element values, and
this is why that one is not delivered.

## NT-10 — the visual pass is part of the deliverable

Walked in the pane at 1400×900 over the reported example plus nine more
binding-heavy ones, at all three rungs, with layout MEASURED rather than
eyeballed: page horizontal overflow, pane horizontal scroll at natural
zoom, zero-width cells, and clipped cells (`scrollWidth > clientWidth`)
all zero on every one of the thirty cases. Two defects were found this
way and fixed before landing — NT-5a (compact eliding into
informationlessness) and NT-5c (the chain cascade reading as siblings).
Neither was visible in the emitted text; both were obvious on screen.
That is the argument for the pass, not just its result.
