# Rulings — playground quality package (#992), 2026-08-26

Authorizing issue: **#992** (owner-reported, with screenshots). Branch
`wave4/992-playground-quality`, off `release/0.17` @ `a36063e81`.

The issue's acceptance list is the authorization for everything below:
fresh wasm reporting the current version or a named gated blocker;
`build-playground` refusing/rebuilding on stale wasm, never silent reuse;
every example × (auto, instance) × (source, output) emitting mermaid that
PARSES, gated; instance nodes rendering as entity tables; auto/ERD
comments carrying meaning (an example value), never `"@"`; one coherent
control model where no visible control is inapplicable; graph-parse
failure falling back to the tree quietly.

---

## PQ-1 — the ERD row comment carries a VALUE, and the `@` sigil is retired

**The defect.** `[pizza size=large]` rendered `string size "@"`. The one
comment slot an erDiagram row admits held the CX attribute sigil and
nothing else — no value, no example, no information. At `full` it read
`"@ 'large'"`: the value arrived, still wearing the sigil.

**Ruled.** The comment slot carries the observed VALUE.

- `compact` — `e.g. <value>`, one observed example, the value's `cd-label`
  image with a surrounding `'…'` pair stripped (the row's type column
  already says `string`, so the quotes carry nothing there).
- `full` — the enumeration of every DISTINCT value that row takes across
  the document's occurrences, unprefixed. This is the one thing `full`
  can say that `compact` cannot: an ERD entity is one box per element
  NAME, so `[item qty=1] [item qty=7]` is a single `item` box whose `qty`
  genuinely ranges.
- The `e.g. ` prefix is also the marker the full rung uses to find the
  rows it may enrich, replacing the bare `"@"` that used to serve that
  purpose. Unlike the sigil, this marker is legible to a reader.

**PQ-1a — which rows carry a comment.** By whether the row HAS a value,
not by whether it came from an attribute. An attribute, a scalar child
and an undeclared map entry all name a concrete value and all show one; a
table COLUMN and a DECLARED map entry name a type and show none. Before
this, scalar-child rows left the slot empty, which rendered as a blank
third column beside the rows that had one. `cd-erd-stats` now collects
scalar-child values too, so the full rung can enrich every row it
prefixed — without that, `full` showed an enumeration on the attribute
rows and a leftover `e.g. …` on the scalar-child rows.

**PQ-1b — a value's comment is escaped and capped.** Mermaid 10 accepts
neither `\"` nor `""` inside a quoted comment (measured, 10.9.8), so
double quotes FOLD to single rather than being backslash-escaped. This
also fixes a live defect: `cd-value-enum` wrote `\"`, so every full-level
ERD of a quote-carrying value was already unparseable. Newlines and tabs
flatten to a space; the run is capped at 40 characters with an ellipsis.

## PQ-2 — every ERD column token is forced to a valid ATTRIBUTE_WORD

Mermaid 10's erDiagram attribute columns accept
`[A-Za-z_][A-Za-z0-9_\-\[\]()]*` and there is NO quoted spelling to fall
back on — an entity name may be quoted, an attribute name may not
(measured, 10.9.8). The 0.13-era emitter wrote the CX `@` sigil into that
column and every ERD of an attribute-carrying document failed to render;
that is the parse error in the issue's screenshot. HEAD had stopped
emitting the sigil but nothing PREVENTED it, and a namespaced attribute
(`cx:kind`) or a dotted map key still reached the column verbatim.

**Ruled.** Every token entering either column goes through
`cd-erd-attrword`, which maps any other character to `_` and prefixes a
non-leading-letter name. An invalid spelling can no longer be emitted at
all, so this class cannot return.

## PQ-3 — golden movement, adjudicated (DR-8)

PQ-1 and PQ-2 move golden bytes. `vcx/tests/testdata/code_diagram_golden/`
is frozen under DR-8: regeneration after the wave-3 capture is golden
movement, forbidden except under a mini-ruling recorded here BEFORE the
bytes move. **This is that authorization**, recorded before regeneration.

Movement, measured on the pre-regeneration lane run:

- 14 `conformance/code_diagram.cxd` expected blocks — every one an ERD
  case, every diff of the form `"@"` → `"e.g. <value>"` (compact),
  `"@ 1"` → `"1"` (full), or an empty slot gaining a value
  (`erd-004-scalar-children-only`).
- the corresponding `code_diagram_golden/*.{min,compact,full}.golden`
  entries.

Nothing outside the ERD row-comment column changes. CFG and SEQ emitters
are untouched, `min` entity boxes are untouched (they carry no rows), and
no entity name, relationship, cardinality, occurrence badge or
`row_count` row moves. That the ERD comment column moves IS the point of
#992.

## PQ-4 — the instance view is an HTML table, not erDiagram rows

The issue asks for an occurrence box that is an entity TABLE: one
attribute per row, name and value as two columns. Three mermaid forms
were measured against the bundled major rather than argued from docs:

- **erDiagram rows** — the shape that looks right, and what `auto`
  already uses. Both unquoted columns are ATTRIBUTE_WORDs, so `42`, `-5`,
  `99.5`, `:ok` and `can't` — the values of playground examples [3], [4]
  and [5] — cannot be spelled in either. Putting values there means
  rendering `min=-5` as `min __5`, the same class of defect as the `"@"`
  comment. **Disqualified on the values, not on taste.**
- **classDiagram members** — permissive, but mermaid routes any member
  containing `(` into the METHODS compartment, so a paren-carrying value
  leaves document order for the other half of the box.
- **flowchart node + HTML label** — mermaid renders the label in a
  foreignObject under `htmlLabels`, giving aligned columns, a header row,
  and CSS control from `playground.css`. Values are HTML-escaped, so no
  value can break the diagram.

**Ruled:** the third. `htmlLabels` and `securityLevel` are set explicitly
at `mermaid.initialize()` so the form the labels are written for is the
form that renders.

**PQ-4a — a lone body earns a row; many do not.** `cxlib.tree()` reports
a sequence literal's PUNCTUATION as scalar children — `(1, 2, 3)` arrives
as seven scalars, `(`, 1, `,`, 2, `,`, 3, `)`. Rowing all of them turns a
five-element sequence into an eleven-row box of commas. One body is
content; many are syntax. This mirrors the rule the Tree pane already
applies when it rides a single scalar onto its element's line. The
underlying contract defect is recorded as F2 below, not worked around
further.

## PQ-5 — the control model: pane header = what applies to everything

**Ruled.** The View pane header carries only the axes that apply to
every representation it can draw — the SUBJECT (`Source | Output | Both`)
and the REPRESENTATION (`Tree | Graph`). Everything that configures ONE
representation moves inside that representation's own panel, so a control
is on screen exactly when it does something.

Concretely: `Auto | Instance`, `Detail`, and the zoom buttons now sit in
a bar inside the graph panel, which the existing `.is-active` rule
already hides whenever the Tree is showing. This also un-stacks the
header, which wrapped to two rows and was the surface complaint.

`Detail` is placed with the GRAPH, not in the header, because it is
graph-only in fact: the Tree's detail-aware branch reads `node.attrs` /
`node.items`, which the `cxlib.tree()` contract does not carry, so that
branch never fires (F1 below). If F1 is ever fixed, `Detail` becomes an
all-representations control and belongs in the header by this same rule.

**PQ-5a — every View control persists.** `vizSubject`, `graphView` and
`detailLevel` already did; `vizMode` (Tree/Graph) did not, so a reload
dropped you on Tree while your other choices survived and the graph
controls looked like they had forgotten too. It now persists like the
rest.

## PQ-6 — a graph that cannot render says one line, not a wall

**Ruled.** When mermaid cannot parse or render a shape, the pane shows
one quiet line naming the Tree tab. The mermaid source and the error go
to `console.debug` — they are developer facts, not reader facts. Dumping
raw mermaid plus a parser error at someone learning CX tells them nothing
about their program and reads as if they broke something.

An absent `window.mermaid` is now distinguished from an unrenderable
shape: the CDN script not having landed yet is a LOADING state and says
so, rather than falling through to the raw-source dump.

## PQ-7 — the engine staleness gate

**Ruled.** `scripts/wasm/check_wasm_fresh.sh` gates on two independent
signals, because either alone has a blind spot: an artifact older than
`vcx/` + `stdlib/` + `VERSION` + the build script (catches an unbuilt
edit), and an artifact whose own `cx_version()` export disagrees with
`VERSION` (catches artifacts copied from another checkout or built before
a version bump, which mtime cannot see). The version half is probed by
actually loading the module, so it reports what the ENGINE says about
itself.

`build-playground` runs it as a hard post-condition. `guide` — which
copies `dist/wasm/` through without rebuilding, deliberately, and is how
a 0.13.0 engine reached a v0.17 playground — runs it in `--warn` mode:
the reuse stays, the silence does not.

## PQ-8 — diagram validity is a gate, driven from the shipped files

**Ruled.** `scripts/test_playground_mermaid.mjs` parses the full cross
product — example × {auto, instance} × {source, output} × {min, compact,
full} — under the same mermaid MAJOR the page loads from its CDN. The
`auto` graphs come from the built wasm engine and the `instance` graphs
from `playground.js`'s own builder, reached through a named read-only
seam (`window.cxPlaygroundInternals`). Neither is reimplemented: a
reimplementation would verify a copy and let the shipped one rot.

The gate SHARDS across child processes. One wasm module instance cannot
survive all 182 examples — the arena is spent around example 130, after
which emscripten `abort()`s and every later call throws, turning one
resource limit into ~150 false diagram failures (measured; `cxlib.reset()`
does not reclaim enough to matter). A fresh engine per slice is also the
honest model of how the page is used: a visitor meets one example at a
time on a fresh page.

Both preconditions — the built bundle and the npm dev-deps — FAIL LOUD
(exit 2) rather than skipping, so this lane cannot report a vacuous pass.
It is deliberately NOT in `TEST_TARGETS`, which must not require emcc or
a network fetch; it belongs with `scripts/test_playground_smoke.sh` as
the playground release lane.

---

## PQ-9 — an operator-headed element's NAME is its head (owner feedback)

**The defect** (owner screenshot, example [26], instance graph at
`Detail: full`): `[?let [= $score 87]]` and `[?if [>= $score 80]]` drew
as boxes labelled `_`. Neither the operator nor its operands appeared, at
any rung.

**Root cause.** `vcx/cx/code_tree.v` parses an element name with the
identifier production. Twelve of the ruled 18 operator heads (#976) are
GLYPHS — `+ * - / % = != < <= > >= ~` — which that production cannot
spell, so the walker fell through to its anonymous-element arm. That arm
does two things: it names the node `_`, and it skips `p.pos` to `end + 1`.
So the head was lost AND every operand with it: `[= $score 87]` arrived
as a CHILDLESS node called `_`.

**Fixed at the honest layer, because the narrower fix did not exist.**
The owner offered building the label in the graph emitter from head +
children as an acceptable fallback if `code_tree`'s naming contract had
consumers that could not be moved. It has none — no test, no binding
(`lang/{go,python,rust}`), and no gate asserts on `_` — and, decisively,
the fallback was not available anyway: the ARGUMENTS were never emitted
either, so there was nothing downstream to build a label FROM. The walker
now consults `cx.operator_head_len` (vcx/cx/lexical.v), which is already
the single home of the alphabet and of #976's delimitation rule, and
takes the head as the name. `_` remains for genuinely nameless shapes. No
second copy of the operator alphabet was created.

**PQ-9a — how the instance view renders one.** An operator-headed
element has no attributes, only an ORDER, so the name│value table is the
wrong shape for it. It renders as `head arg arg …` on the box caption,
styled as a keyword rather than an element name so expressions and
records stay distinguishable at a glance in a graph that mixes them. Per
the owner's detail semantics:

- `min` — the bare head (`=`, `>=`).
- `compact` — head plus the first 4 args, remainder as `(+N)`.
- `full` — head plus every arg, scalars verbatim.

A `$ref` argument renders BARE: quoting it would dress `$score` as the
literal string `'$score'`, which is a different program. An ELEMENT
argument (a nested sub-expression, `[= $t [+ 1 2 3]]`) renders in place
as `[+]` and is still drawn as its own box below — without the
placeholder the caption would read `= $t`, silently losing an operand and
misreporting the arity.

**Detection is DERIVED, not enumerated.** A glyph head is precisely a
name the identifier production cannot spell, so the presentation test
covers any glyph head the evaluator gains without playground.js being
told. Only the six WORD heads (`and or not union intersect except`) need
listing, and those are the stable half.

---

## Register — turned up in passing, NOT fixed here

- **F1 — the Tree pane's detail branch is inert.** `renderNode`'s element
  specialization reads `node.attrs` / `node.items`; the `cxlib.tree()`
  contract carries `children` with `{kind:'attribute'|…}` entries. The
  attr-chip and inline-scalar paths therefore never fire, so the Tree
  renders the raw JSON walk (`children: array(4)`, `[0]: active
  (attribute)`, then `name:` and `value:` as separate rows) at every
  detail rung. Not fixed here: the verbose form is what gives the
  source↔tree bridge its per-attribute click granularity, so collapsing
  it to chips is a real design tradeoff and wants the owner's call, not a
  late edit inside a different issue. Filed as **#1001**. Note the
  placement consequence recorded under PQ-5: fixing F1 makes `Detail` an
  all-representations control and moves it back to the pane header.
  **CLOSED 2026-08-26** —
  `ledger/rulings_2026_08_26_playground_tree_detail_1001.md` (TD-1..TD-6).
  The trade-off this entry parked is DECLINED rather than accepted: the
  chips carry their own locs and register, so the per-attribute click
  granularity survives the collapse. `Detail` moved to the header, by
  PQ-5's own rule.
- **F2 — `cx_code_tree` mis-parses a triple-quoted attribute value.**
  `[doc body='''line 1\nline 2\nline 3''']` emits `attribute body` with
  `value: ""` plus two sibling `text` nodes carrying the content. The
  value is lost from the attribute it belongs to. Visible in playground
  example [7] as a `body ''` row. Filed as **#999**.
- **F3 — `cx_code_tree` reports sequence punctuation as scalar
  children.** `(1, 2, 3)` emits seven scalars including `(`, `,`, `)`.
  PQ-4a bounds the damage in the instance view; the contract itself is
  unchanged. Filed as **#1000**.
- **F4 — two gate harnesses report spurious `$process` timeouts.** Five
  `full-code-cfg-*` fixtures in `make test-code-diagram` report
  "timeout: 10s emitter budget exceeded", and
  `make verify-playground-examples` reported "TIMEOUT after 20s" on
  example [168] when run concurrently with `test-vcx-code`. Neither is a
  regression and neither is the work being slow: the CFG source renders
  in 0.086s (release) / 0.138s (dev), example [168] evaluates in 0.090s,
  and the five diagram fixtures error IDENTICALLY on `a36063e81` with
  this issue's emitter change stashed (measured: `33 passed, 14 failed,
  5 errored` before the fixture updates, `47 passed, 0 failed, 5 errored`
  after — the same five). The time is going somewhere other than the
  work, most likely the `$process` spawn path under load. Filed as
  **#1002**.
