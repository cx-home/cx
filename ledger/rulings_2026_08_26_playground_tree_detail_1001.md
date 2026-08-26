# Rulings — the Tree pane honours the Detail rung (#1001), 2026-08-26

Authorizing issue: **#1001** ("Playground Tree pane: detail-aware
element branch is inert (reads node.attrs/items, contract carries
children)"), filed as F1 in
`ledger/rulings_2026_08_26_playground_quality_992.md` and deliberately
left for its own authorization because it carries a trade-off. Branch
`wave9/1036-1037-1001-diagram`, off `release/0.17` @ `4a83b2361`.

---

## TD-1 — the defect, restated as measured

`renderNode`'s element specialization read `node.attrs` and
`node.items`. The `cxlib.tree()` contract (`vcx/cx/code_tree.v`) carries
`children`, with attributes as `{kind:'attribute', name, value, loc}`
entries INSIDE it, siblings of nested elements and of scalar / text
bodies. Neither `attrs` nor `items` exists on any node, so the branch
was dead code:

- the Tree drew the raw JSON walk at EVERY rung — `children: array(4)`,
  then `[0]: active (attribute)`, then `name:` and `value:` as two more
  rows: four lines per attribute;
- `Detail: min|compact|full` had no observable effect on the Tree at all,
  while the code comment above it described the effect it was supposed
  to have.

Playground example **[4]**,
`[user active=true verified=false admin=true blocked=false]`, drew
seventeen rows.

## TD-2 — the fix reads the contract THROUGH the function the tables already use

`splitElementChildren(node)` — the partition the instance-graph tables
consume (`instanceRows`, `instanceNodeHtml`) — is what the Tree branch
now calls. Not a copy of it, not a second projection with the same
intent: the same function, so a change to the contract lands on both
representations at once or on neither.

The rung means in the Tree exactly what it means in the Graph:

| rung | Tree | Graph (`instanceRows`) |
|---|---|---|
| `min` | names and nesting only | no table rows at all |
| `compact` | first `COMPACT_ATTR_CAP` attributes as chips + `(+K more attrs)`, lone scalar body ridden up | first `INSTANCE_ROW_CAP` rows + `(+N more)` |
| `full` | every attribute as a chip | every row |

**TD-2a — the lone-body rule is `instanceRows`' rule, verbatim.** A
single scalar / text body with no element siblings rides its element's
own row; several bodies are a LIST and stay rows, and an element with
element children of its own is not a leaf. The predicate is the same
one, on the same fields, for the same stated reason.

**TD-2b — the chip cap is 2 because a row is a LINE.** The Graph's box
can afford ten rows; a Tree row is one line, and the diagram spec's own
`compact` rung already spends exactly "first 2 attr chips + `(+K)`
overflow" on a line label (diagram.md §4, Detail rungs). The Tree row
and the `mermaid:compact` label now say the same thing at the same rung
rather than two different things.

**TD-2c — directives get the same treatment, spelled `?name`.** A
`[?let]` node is `{kind:'directive', name:'let', children:[…]}` and was
falling to the same raw JSON walk. It takes the element branch too, and
its caption is the instance graph's own spelling — `?` plus the name —
so the two representations read as one language rather than one saying
`let (directive)` and the other `?let`.

## TD-3 — the trade-off the issue raised is DECLINED, and paid for instead

The issue's reason for not fixing this in passing:

> the verbose form is what gives the source-to-tree bridge its
> granularity … Collapsing attributes into chips reclaims the vertical
> space and makes `Detail` meaningful, but costs that per-attribute
> click target unless the chips themselves carry locs and register.

**Ruled: the chips carry locs and register.** The cost is not accepted;
it is paid. Each chip carries TWO click targets — `data-loc` on the
`@name` half and another on the value half — computed by `attrSubLocs`,
which is the same loc-splitting the verbose `attribute` branch performed,
factored out and now shared by both. A ridden-up scalar body carries its
own loc for the same reason.

So `compact` and `full` reclaim the vertical space with NO loss of
granularity: clicking `@name` still selects exactly the name span in the
source pane, clicking the value still selects exactly the value span.
Accepting the loss would have been the cheaper edit and the worse
outcome — the bridge is the reason the Tree is worth having next to the
editor.

**TD-3a — what `min` does give up, honestly.** At `min` the attributes
are not drawn, so they are not click targets, and a cursor inside an
attribute highlights the enclosing element instead. That is the rung's
contract — `min` is names and nesting — and it is the same thing the
Graph's `min` does with its rows. It is recorded here rather than left
to be discovered.

## TD-4 — `Detail` moves back to the View pane header

#992's PQ-5 placed `Detail` inside the graph panel and said why:

> `Detail` is placed with the GRAPH, not in the header, because it is
> graph-only in fact … If F1 is ever fixed, `Detail` becomes an
> all-representations control and belongs in the header by this same
> rule.

F1 is fixed, so the control moves, by PQ-5's own rule and not by a new
one. The header now carries the three axes that apply to everything the
pane can draw: SUBJECT, DETAIL, REPRESENTATION. The graph bar keeps
`Auto | Instance` and the zoom buttons, which configure the graph and
nothing else.

**TD-4a — the option text is the bare rung, and that is measured.**
Moving the control up re-stacked the header into two ragged rows — the
exact surface complaint PQ-5 bought out. Measured in the pane at
1400×900, where the View pane's natural width is 467px: the header
holds ONE row only while this control is ≤85px wide.

| spelling | width | header |
|---|---|---|
| `DETAIL: COMPACT` (as moved) | 129px | 64px — two rows |
| same, no uppercase / no letter-spacing | 123px | two rows |
| same at 0.62rem with tight padding | 106px | two rows |
| `COMPACT` | 77px | 36px — ONE row |

So the long spelling does not fit at any type treatment, and the fix is
the text, not the typography. The bare rung is defensible on its own
terms rather than only as the thing that fits: the two groups beside it
(`Source | Output | Both`, `Tree | Graph`) are bare value sets too, the
rungs are the vocabulary the CLI already spells `--detail`, and the
control carries `aria-label="Detail level"` plus a `title` that names
it. Recorded with the numbers so that a future widening of the pane can
revisit it on evidence.

## TD-5 — a value LEAF is one row too

Found by the visual pass, and the same defect one node kind over. A
`{kind:'scalar'|'text'|'path', value, loc}` node has no `name`, so it
fell to the generic object walk and drew THREE rows — `scalar`, then
`kind: "scalar"`, then `value: "$orders"`. It is a leaf and it renders
as one row carrying its value, styled by the contract's own `kind`.
Nothing here parses the value; the kind is asked for, exactly as TD-2
asks for the child roles.

Measured on example [150] at `compact`: 36 rows → 24.

Also fixed in passing and visible on the same example: contained
children were labelled `''` rather than `null`, so `labelPart` drew a
bare `: ` separator in front of every contained row (`: =`, `: o-set`).

## TD-6 — the visual pass is part of the deliverable

Walked in the pane at 1400×900 by the #1031 method — layout MEASURED,
not eyeballed: page horizontal overflow, pane horizontal scroll at
natural zoom, zero-width spans, clipped rows
(`scrollWidth > clientWidth`), and the header's own height counted on
every case. Cases: the example #1001 names ([4], the seventeen-row one)
plus the attribute- and nesting-heavy neighbours ([3], [5], [7], [127],
[130]) and [150], at all three rungs, on the Tree — 21 cases.

**Result: 0 / 0 / 0 / 0 on every one, header 36px (one row) on every
one.** Example [4] went from seventeen rows to ONE at every rung, with
`Detail` finally observable on it: 0 chips at `min`, 2 + `(+2 more
attrs)` at `compact`, 4 at `full`.

**TD-6a — the bridge, verified in both directions.** Every one of the
eight click targets on [4] at `full` was clicked and its resulting
source selection read back: `@active`→`active`, its value→`true`,
`@verified`→`verified`, →`false`, and so on — each chip half selects
exactly its own span, and exactly one target carries the mark at a
time. Reverse: placing the caret inside `verified` in the source
highlights that chip's name half in the Tree. The granularity TD-3
refused to trade away is measured, not asserted.

**TD-6b — #1036 confirmed in the pane on the same pass.** Example [150]'s
`auto` graph now draws SIX nodes including both `lt1` and `lt2`; before
#1036 the second binding overwrote the first and one whole nested table
was missing. That is the symptom #1036 was filed over, seen fixed on the
example it was filed against.

## TD-7 — what holds it, and what does not

`make test-playground-mermaid` walks
`example × {auto, instance} × {source, output} × {min, compact, full}`
through `playground.js`'s own builder and the built wasm engine, so a
JS-level break in this file reddens it (2,070 diagrams). The playground
smoke lane serves the staged bundle and checks its assets.

Neither of them renders the TREE. That is stated rather than glossed:
the Tree's own rendering has no automated gate today, which is exactly
why F1 could sit inert through #992's whole quality package, and why
TD-6's measured pass is named as part of the deliverable rather than
offered as a courtesy. A browser-driven Tree gate is the honest
follow-on and is recorded here as open, not delivered.
