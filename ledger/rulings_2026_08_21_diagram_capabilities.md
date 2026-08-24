# Rulings 2026-08-21 — the effect/capability graph, a new renderable kind (DGX-1)

## DGX-1 — a second VIEW of a CX program: what it can actually do

**Status:** RULED. Recorded BEFORE the work, per the standing rule that a
new renderable KIND is a spec surface addition and surface changes land
in this window rather than after (`feedback_no_spec_edits_during_impl`
inverts to: authorize first, then implement). The owner's ask that
occasions it: *"What other interesting kinds of things can we do now with
that? Add some that will be useful and impressive."* — posed after
`cx-stdlib/diagram` (#758 waves 1-2, #889 wave 3) moved BOTH renderers
into pure CX.

The premise this ruling acts on: CX's differentiator is that capabilities
are explicit and effects are declared, and **nothing in the tree shows a
reader what a program can actually do.** `security.md` §2 names nine
capabilities and §2.1 closes the effect-point set, but a reader holding a
CX source has no way to answer *"if I grant this program `net`, what does
it reach, and through which call path?"* short of reading every line and
every callee. That question is an auditor's question, it is answerable
statically from the program's own image, and — since #889 put a
source-text ingress and a structural program image in the module's own
hands — it is now cheap. It was not cheap while the renderers were 4,900
lines of V.

---

### The surface, as ruled

**One new renderable kind, spelled `effects`.**

| Where | Spelling |
|---|---|
| CX call | `[$diagram:effect-graph $src $level]` — `$level` = `min` \| `compact` \| `full`, default `compact` |
| CLI | `cx code-diagram --view=effects [--level=min\|compact\|full] [FILE\|-]` |
| Sealed table | `[$diagram:effect-rules]` → element (DATA, not behavior) |
| Table lookup | `[$diagram:effect-cap $prim]` → the capability a primitive charges, `""` for none |

`--view` defaults to `auto`, which is today's behavior BYTE FOR BYTE: the
ERD/CFG/SEQ auto-detection `cx code-diagram` has always performed. No
existing invocation changes.

**Why `--view` on `code-diagram` and not somewhere else.** The effect
graph is Mermaid, it takes source text, it has three detail rungs spelled
`min`/`compact`/`full`, and it is the same renderer family as the
playground emitter in every respect except its subject. `--view` is the
axis that was missing: the subcommand already picked its subject by
auto-detection, and this is the first subject that cannot be detected —
it is a deliberate question a reader asks, not a shape a source has.

**The alternatives, and why they were rejected:**

- **`cx diagram --format=effects`.** Rejected. `--format` on `cx diagram`
  names the OUTPUT ENCODING — `mermaid` \| `mermaid:<detail>` \| `dot` \|
  `svg` \| `png`. Putting a SUBJECT into that axis makes "the effect graph
  as SVG" inexpressible and collapses two orthogonal choices into one
  string; orthogonality of the surface is a standing CX design objective,
  and this would spend it for one character of typing.
- **`cx effect-graph FILE` as a new top-level subcommand.** Rejected. It
  re-plumbs `--level`, doubles the help surface, and asserts that the
  effect graph is a different TOOL when it is a different VIEW. If a third
  and fourth view arrive (they should — see the register at the end), the
  subcommand list grows linearly while `--view` does not.
- **Extending `of-source`'s `$format`.** Rejected for the same reason as
  the first: `of-source`'s format axis is the encoding axis.

**Deliberately NOT in this surface** (each named so it is a later ruling,
not drift):

- **No `dot`/`svg`/`png` for the `effects` view.** The reference
  renderer's DOT emitter walks the PROGRAM image; the effect graph is a
  derived graph, not a program image, so DOT would be a second emitter and
  graphviz a second capability question. Mermaid only, exactly as
  `code-diagram` is Mermaid only.
- **No new wasm/C ABI export.** `cx_code_diagram_with_level` keeps its
  signature (DRW3-5 stands); wiring the playground's view selector to the
  new kind needs an ABI addition and therefore an ABI re-bless (#888), so
  it is a separate landing. The CLI and the CX call are the two live
  consumers this surface ships with — a seam with no live consumer is a
  partial implementation, and this one has two.
- **No `[effects …]`-declaration conformance check.** Comparing what a
  `[?def]` DECLARES against what its body REACHES is a genuinely valuable
  linter and it is not a diagram; it is filed as a follow-up.

---

### DGX-1a — the effect table is READ LIVE from the engine, never copied

The §10.1.2 render-rules table is sealed CX data because it is a
RENDERING rule table: what each directive renders AS is the renderer's own
business (DR-4a). The primitive→capability map is not that. It is a fact
about the engine — `security.md` §2.1's normative closed set, mirrored by
`vcx/code/effect_alignment.v`'s `capability_gated_prims()`, with
`check-effect-alignment` asserting spec ↔ implementation equality in both
directions.

**Adjudication:** the module does NOT carry a copy. A new native
primitive, `[$diagram-effect-table]`, returns the LIVE map, so a
capability-gated effect point added to the engine appears in the next
render with no edit here. A stale copy could only ever fail in one
direction — silently omitting a newly-gated effect — and a capability
diagram that quietly under-reports is worse than none. Copying it would
also have created a THIRD mirror of a table the tree already keeps in
exact two-way agreement.

The module's own sealed table (`[$diagram:effect-rules]`, DGX-1b) carries
only what IS rendering policy.

### DGX-1b — the sealed `effect-rules` table, and its completeness gate

`[$diagram:effect-rules]` returns ONE data value with four row classes,
and the emitters READ it:

- `[cap name=… flag=… ]` — the nine-capability roster of `security.md` §2,
  in that order, each with the CLI grant flag it is requested by.
- `[dir directive=… cap=…]` — the capability a DIRECTIVE HEAD charges.
  §2.1 closes the *primitive* set; it does not enumerate the directive
  heads that charge, and five do (`[?eval]` → `eval`, `[?reveal]` →
  `secret-reveal`, `[?http-client]` / `[?http-service]` → `net`,
  `[?sleep]` → `clock`). These rows are rendering policy over a fact
  §2 states in prose, so they are the module's — and clause (ii) of the
  gate holds each against a live registry directive and a roster capability.
- `[arm carrier=… under=…]` — the branch/arm carriers that make a reached
  effect CONDITIONAL. An effect is conditional iff its path from the root
  passes through an arm carrier whose parent is a branch directive
  (`if` / `match` / `select` / `fallback`). The `under=` column is
  load-bearing: `cx:yield` is a match arm under `[?match]` and an
  iteration body under a for-comprehension, and only the first is a branch.
- `[opaque kind=…]` — the five in-image opacity sources that MUST render
  as an unknown edge (DGX-1c; the draft's sixth, `caps`, was removed at
  implementation and `ring2` added — see the execution record).

**The gate** (`vcx/tests/diagram_effect_completeness_gate_test.v`),
red-on-synthetic-drift, seven clauses (the seventh added at
implementation — see the execution record):

  (i) the `cap` rows are SET-EQUAL to the engine's `capability_names()`
      AND to the roster in `security.md` §2 — a capability added to the
      language and not to this table reddens, and vice versa;
 (ii) every `dir` row names a LIVE §4.1 registry directive and a
      capability in the roster;
(iii) every `arm` row's `carrier` and `under` name real image tags, and
      the emitter's conditionality verdict agrees with the table on a
      probe corpus;
 (iv) every `opaque` kind is produced by at least one corpus source —
      an opacity class that cannot be demonstrated is not a class;
  (v) every roster capability is REACHED by at least one corpus source,
      so no capability can lose its emitter silently;
 (vi) the tables in `std-lib/diagram.md` §12 and the module's
      `effect-rules` value are SET-EQUAL in both directions — the clause
      that caught wave 3's synthetic deletion, and the only one that
      stays red when a matched deletion keeps the emitters self-consistent.

### DGX-1c — honesty is normative: five opacity classes, always rendered

The deliverable's hard constraint: *a dynamic `[?eval]` or an indirect
call it cannot resolve must be shown as an unknown edge, never silently
omitted.* Ruled as a normative clause of the kind, at EVERY rung — `min`
does not get to be tidy at the cost of being wrong:

| kind | the site | rendered |
|---|---|---|
| `eval` | `[?eval]`, `[$cx:eval]`, `[$cx:eval-tree]` | unknown node; charges `eval`; fans to *any granted capability* |
| `call` | a callee that is neither a table primitive, nor a `[?def]` in this image, nor a resolvable module-qualified name | unknown node naming the callee |
| `dynamic` | a `<cx:expr>` source hatch in statement/callee position (a dynamic element name) | unknown node |
| `lib` | a `[?lib]` whose module body is not in the image (a file path, an https URL, any non-`cx-stdlib` resolver) | unknown node; an https resolver also charges `net` |
| `ring2` | a Ring-2 pack verb — its capability charge is made inside the pack and registered at runtime | unknown node naming the verb |

When ANY opacity source is present the render carries the `any granted
capability` sink, and a capability the walk did not reach is described as
**not statically reached**, never as *not reached*. When none is present
the graph says so — the useful and load-bearing case: *this program is
statically capability-free* is a claim worth being able to make, and the
`min` rung of a pure program makes it in one node.

### DGX-1d — the corpus is AUTHORED, then frozen

Waves 1-3 captured their goldens from a shipped V implementation before
cutting over; that instrument does not exist for a kind that never
shipped. **Adjudication:** the corpus
(`vcx/tests/testdata/diagram_effect_golden/`, sources × 3 rungs) is
authored — every byte read and reviewed at landing rather than captured
from an oracle — and then frozen under exactly the DR-8 rule that governs
the other three corpora: regenerating it afterwards is golden movement,
forbidden except under a mini-ruling recorded here first. The five
opacity classes and all nine capabilities are corpus-covered by gate
clauses (iv) and (v), so the corpus cannot quietly stop exercising them.

### DGX-1e — the ingress: a third image mode, not a fourth primitive

`[$diagram-program-image SRC MODE]` gains `MODE = "effects"`: the `"code"`
lowering (whose `[?def]` expansion this walk requires — DRW3-4) plus one
addition, a `<cx:lib-image module=… alias=… kind=…>` child on a `[?lib]`
directive, whose surface text the parser otherwise defers as a
`raw-source` string exactly as it defers a `[?def]` body. Without it an
aliased import (`[?lib 'cx-stdlib/io' as=fs]` then `[$fs:read-file …]`)
resolves to nothing and the read is MISSED — a silent under-report, which
DGX-1c forbids. `"ref"` and `"code"` are untouched, so no wave-1/2/3
golden can move. DR-7(a) holds: the renderer never parses; the engine
hands it the image.

### DGX-1f — what the effect graph cannot see, stated in the spec

Rendered opacity (DGX-1c) covers what the image knows it does not know.
These are the limits the image cannot even flag, and `std-lib/diagram.md`
§11.5 states them normatively rather than leaving a reader to assume
completeness:

1. **Reachability is syntactic, not semantic.** An effect behind a
   condition that is always false still appears. The graph answers *what
   is in the program*, never *what a run will do*.
2. **Resource scoping is invisible.** `security.md` §2 scopes `read` to
   path roots and `net` to host globs; the graph shows the CAPABILITY and
   never the resource. "It can read" — not "it reads `/etc/passwd`".
3. **Ring-2 pack verbs registered at runtime** are invisible to the
   static purity/alignment tables and therefore to this graph.
4. **A declared `[effects …]` clause is not checked against reach.** The
   graph reports what the body REACHES; a `[?def]` that declares less (or
   more) is not flagged. Filed as a follow-up linter.
5. **Ordering, frequency and data flow are absent.** It is a reachability
   graph, not a trace.

---

## DGX-2 — `cd-erd-full`'s DOCUMENT box is POPULATED, and loses one row

**Status:** RULED. #901 item 4, whose source is this module. The owner
posed (a) populate / (b) drop and recommended (a) if the box stays.

Shipped, every full-level ERD carries

```
  DOCUMENT {
    int node_count
    int type_count
    int max_depth
    string source_path
  }
```

— four stat FIELDS and never their VALUES: a schema of statistics rather
than the statistics, which is why it reads as noise. Real entities already
use the value slot (`int id "@ 1"`, `string note "appears 2× depth 1"`).

**Adjudication: (a), populate — with one row dropped.** The three
countable rows become

```
  DOCUMENT {
    int node_count "3"
    int type_count "2"
    int max_depth "1"
  }
```

computed from the stats the full-level walk ALREADY collects for the
occurrence badges (`node_count` = the sum of occurrence counts over every
element the walk reaches; `type_count` = the number of distinct element
names; `max_depth` = the greatest depth recorded). No new traversal.

`source_path` is **dropped**, not populated. The renderer's ingress is
source TEXT — `code-diagram` has never been handed a path, and the one
caller that has one (`cx code-diagram FILE`) does not pass it. Populating
it would require a new parameter on a frozen entry point in order to print
something the reader already knows (they named the file). A row that can
only ever be empty is the same defect at one quarter scale, so it goes.

**Golden movement, adjudicated.** This moves 20 `*.full.golden` files in
`code_diagram_golden` and 4 expected blocks in
`conformance/code_diagram.cxd`. That is deliberate, it is the point of the
issue, and this mini-ruling is the DR-8 authorization recorded before the
bytes move. Nothing outside the `DOCUMENT { … }` block changes; `min` and
`compact` are untouched (the box is a full-level artifact), and
`cd-erd-suppress` — which already decides when to omit the box entirely —
is unchanged.

---

## Register — what this pass turned up, and what it leaves open

- **F1.** `security.md` §2.1 closes the *primitive* effect-point set but
  no table anywhere closes the *directive* heads that charge a capability;
  §2 states four of them in prose (`[?eval]`, `[?cx include]`, `[?lib]`
  https, `[?sleep]`) and `eval.v` charges a fifth (`[?reveal]`) with no
  spec row at all. DGX-1b's `dir` rows are this module's local closure of
  that set and are gated against the registry, but the normative home for
  it is `security.md`. Filed.
- **F2.** `[?def … [effects …]]` is dropped by the `"code"`/`"effects"`
  image lift: the parser keeps the whole `[?def]` head as `raw-source` and
  the def-image carries only the BODY. The declared-vs-reached check
  (DGX-1f item 4) therefore needs the lift to carry the clause. Recorded,
  not worked around — the graph reports reach, which is the honest half.
- **F3.** Deliverable 2 of this pass's brief — the store object graph
  (the Merkle DAG, shared subtrees between two documents) — was assessed
  and NOT attempted here. Its machinery (`store_objgraph_*`) lives in
  `vcx/platform/`, a Ring-2 pack behind `-d cx_no_pack_*` compilation, and
  exposing it to a Ring-1 renderer is a ring-crossing question, not a
  rendering one. It is a real and good diagram; it needs its own ruling
  about which ring the reader stands in. Filed.
- **F4.** Views this makes cheap that nobody has asked for yet, recorded
  so they are chosen rather than accreted: a **purity boundary** view (the
  pure core / impure shell, from the same walk), a **module dependency**
  view (`[?lib]` closure), and a **grant diff** view (two capability sets,
  what the second unlocks). Each is a `--view` value under DGX-1's axis.

---

## Execution record (this session) — and three corrections to this ruling's own first draft

### What landed

**Engine (invocation and ingress only; zero diagram text).**
`vcx/code/stdlib_diagram.v` gains the second primitive
`[$diagram-effect-table]` (the live roster + `capability_gated_prims()` +
the §6.5.1 uncharged-impure set + the Ring-2 impure set + the frozen
`cx-stdlib/*` roster, all sorted so the value is deterministic) and the
`"effects"` image mode. `vcx/code/diagram_cx_seam.v` gains
`diagram_lower_effects`, `dgx_lib_image`, the `effect_graph_cx` driver
and the two gate probes. `vcx/code/ring_registry.v` gains
`ring2_impure_names()`. `vcx/code/code_diagram.v` gains
`effect_graph_with_level`. `vcx/cmd/` gains `--view`.

**Module.** `stdlib/diagram.cx` §11 (≈460 lines): the sealed table, the
live-table lookups, the two context pre-passes (def names, `[?lib]`
aliases), the walk, the two-set reachability fixpoint, and the three
rungs. Three new public defs — `effect-graph`, `effect-rules`,
`effect-cap` — each with an fn-doc whose example runs, backed by three
new cases in `conformance/stdlib/diagram.cxd` (21/21).

**Corpus.** `vcx/tests/testdata/diagram_effect_golden/` — 29 sources ×
3 rungs = 87 goldens, authored per DGX-1d, every byte read at landing;
regenerator `vcx/tools/regen_diagram_effect_golden`; byte gate
`vcx/tests/diagram_effect_golden_test.v`.

### DGX-1c amended: the `caps` opacity class is REMOVED (measured)

The first draft listed six opacity classes, the sixth being a
`[?with-caps]` whose `[deny …]` operand is not a literal. **It cannot
occur.** Measured live: `[?with-caps [deny $dyn] BODY]` is refused by the
PARSER (`cx-err:CXER0100: [?with-caps] [deny …] requires a capability
name`), so a `[?with-caps]` that reaches the image at all has a readable
deny list and the narrowing is always legible. The class is removed from
the ruling, from the module table, from the spec, and from the gate's
count — an opacity class that cannot be demonstrated is not a class, and
gate clause (iv) would have been unsatisfiable with it in.

Its place is taken by a class the first draft did NOT have and should
have: **`ring2`**. A Ring-2 pack verb (`[$journal:read …]`,
`[$store:put …]`) charges its capability inside the pack, at a
`cap_guard` the pack owns, registered into Ring 1 at init — so it is in
NO static table, including §2.1's. Classifying such a call as pure would
be precisely the silent under-report DGX-1c forbids, and classifying it
as *uncharged* would be a false claim that it needs no grant. It renders
as an unknown edge naming the verb. The engine side of this is the new
`ring2_impure_names()` accessor; the packs already declared the set for
the stream-10 anti-2PC guard, so nothing new is asserted, only exposed.

### DGX-1c amended: a fifth capability STATUS, `x`

The draft's `min` rung had four statuses (unconditional / conditional /
denied / absent). A fifth was needed, and finding it is the reason the
reachability closure is worth its cost: a program whose only
`[$process:run]` sits in a def NOTHING CALLS rendered as *"no
capability-charging effect reached"* — true of the entry, false of the
file, and exactly the kind of confident wrong answer this view must not
give. Such a capability now renders
`prog -.->|"charged only in a def nothing calls"| cap_X`. The
nothing-reached node is reserved for a source that charges nothing
anywhere.

### A silent under-report found and closed before landing: nested `[?def]`

`dgc_def_image` lowers a def body with `diagram_lower`, not with the
expanding walk, so a `[?def]` NESTED inside a def body kept its
`raw-source` string and never got a def-image — and an effect inside
that inner def was invisible to the walk. Found by reading the
`eff-nested-def` corpus render, not by a gate. The `"effects"` mode now
re-expands the def-image body (`"code"` mode is untouched, so no wave-3
golden moves). Corpus case `eff-nested-def` pins it.

### Drift-redness, proven and reverted

Two shapes, both exercised at landing:

- **Unmatched deletion** — the `[dir directive=sleep cap=clock]` row
  removed from the module table only: clause (ii) reddens
  (`dir rows: {…4 rows…}`) AND clause (vi) reddens
  (`charging directive heads: spec §12 rows with no module row:
  ['sleep']`).
- **Matched deletion** — the same row removed from the spec table TOO,
  which is the shape clauses (i)-(v) cannot see because the emitters
  read the table: the completeness gate's arity assertions catch the
  count, and the GOLDEN corpus catches the behavior
  (`eff-dir-sleep.{min,compact,full}.golden: BYTE DIVERGENCE`). Both
  gates red; both green after the revert.

### DGX-2 (the DOCUMENT box) — the movement, as adjudicated

20 `*.full.golden` files in `code_diagram_golden` and 4 expected blocks
in `conformance/code_diagram.cxd`. Verified line-by-line: the ENTIRE
diff is the four `DOCUMENT` rows — `-int node_count` / `-int type_count`
/ `-int max_depth` / `-string source_path` out, `int node_count "N"` /
`int type_count "N"` / `int max_depth "N"` in. Nothing outside the
`DOCUMENT { … }` block moved; `min` and `compact` are untouched. Spec
§10.5 is new and normative for the three rows and the dropped fourth.

### Engine findings banked (not blockers, worked around or recorded)

- **E1.** `[$str-format]`'s format grammar makes `{` a placeholder
  opener, so a format string containing literal Mermaid braces
  (`DOCUMENT {`) fails with a `concat` signature error far from the
  cause. `cd-erd-document` uses `[$concat]` instead. Worth a guide note:
  the error names the wrong primitive.
- **E2.** A def-body err VALUE from a missing callee (`no callable
  "cd-node-kind"`) propagated into an accumulator and rendered as an
  EMPTY graph rather than raising — the C9 class again, and the reason
  the first `min` render silently said "nothing reached". A renderer
  whose accumulator can absorb an err needs its accumulator type
  checked, or the class recurs.
- **E3.** `[?lib]` heads are captured as deferred `raw-source` text
  exactly as `[?def]` bodies are, and the §4 projection therefore
  carries no alias. This is why DGX-1e exists; the same gap would face
  any consumer that needs the import graph, so the `cx:lib-image`
  addition may be worth promoting out of the `"effects"` mode later.

### Gate results — every RC from the log

| Gate | RC |
|---|---|
| `make build-vcx-dev` | 0 |
| `diagram_mermaid_golden_test` | 0 |
| `diagram_vector_golden_test` | 0 |
| `diagram_completeness_gate_test` | 0 |
| `diagram_of_source_test` | 0 |
| `code_diagram_golden_test` | 0 (264/264 after the DGX-2 movement) |
| `code_diagram_completeness_gate_test` | 0 |
| `code_diagram_roundtrip_test` | 0 |
| `diagram_bench_gate_test` | 0 |
| `diagram_effect_golden_test` | 0 (87/87, new) |
| `diagram_effect_completeness_gate_test` | 0 (seven clauses, new) |
| `stdlib_umbrella_test` | 0 |
| `eval_semantics_umbrella_test` | 0 |
| `code_eval_fixtures_test` | 0 |
| `make test-code-diagram` | 0 (52/52) |
| `conformance/stdlib/diagram.cxd` | 0 (21/21, three new) |
| `make guide-check` | 0 (60 modules) |
| `make stdlib-catalog-gate` | 0 |
| `make verify-doc-blocks` | 0 |
| `make spec-freeze-gate` | 0 |
| `make libcx-abi-gate` | 0 (no export added — DRW3-5 stands) |
