# `cx-stdlib/diagram` — the §10.1.2 reference diagram renderer, in CX

```cx
[module-meta name=diagram tier=A status=current]
```

**Status:** Current — ALL THREE waves of the RULED cutover are landed
(#758 waves 1-2, DR-1…DR-11 all at (a), owner "7b" 2026-08-20,
`ledger/rulings_2026_08_20_diagram_renderer.md`; #889 wave 3, owner
"a", `ledger/rulings_2026_08_20_diagram_wave3.md`). This module owns
BOTH renderers: the `code.md` §10.1 reference renderer (the Mermaid
target, DOT emission, the SVG/PNG metadata splices, the PNG CRC-32 and
chunk construction, both dot-less envelopes, and the reverse-parse
source extractors for all three formats) and the playground's
auto-detecting CFG/ERD/SEQ emitter (§10). Everything is pure CX except
one call — the graphviz hop, `[$process-run ["dot" "-T…"] …]` under the
`subprocess` capability (DR-2a). Neither `vcx/code/diagram.v` nor
`vcx/code/code_diagram.v` retains renderer logic; the V pair
`shell_dot` / `import_os_execute` is deleted rather than wrapped.

Normative companions: `spec/03-approved/core/code.md` §10.1 (the
commitment, the locked table, the completeness-gate clause);
`spec/02-working/diagram_renderer_cx.md` (the ruled design letter).

---

## §1. Placement and invocation

Ring 1 (DR-3a): pure CX over the evaluator; no platform pack, no
capability. The engine invokes the module at its diagram surfaces
(`cx diagram`, `cx eval --target=mermaid|svg|png`, the wasm
`cx_code_diagram` ABI) by injecting three context bindings, the
`[?eval]`-context (L99) pattern — no new public parse surface exists
(DR-7a):

- `$program` — the parsed program's **program-as-data image**: the
  `ast.md` §4 program-XML projection materialized as a CXDM element
  tree (mini-ruling DRW1-1: the E1 quote-image collapses
  for-comp/call/pattern nodes to the `<cx:expr>` source hatch, which a
  renderer must not re-parse; the §4 image is the structure-complete
  ruled alternative). The engine builds this tree directly
  (`vcx/code/diagram_cx_seam.v`) — the XML READER's cx-typed-scalar
  carry does not reproduce the projection node-for-node (consult
  finding C10), so the image is never round-tripped through XML text.
- `$source` — the verbatim source bytes (the round-trip payload).
- `$detail` — the DR-11 detail rung: `min` | `compact` | `full`.

**The err-literal rename (normative, #898 / DRW3-9, RULED: ISW-1).** A
source element named `err` is NOT lifted under its own name. `err` is
the error VALUE tag (`is_err_value` is `name == "err"`), so an image
element so named IS an error value to the evaluator: any consumer that
hands the node to a def, or reaches it through a dynamic-child
position, propagates railway-style instead of rendering. Measured
before the rename, `[?worker name="w" [err code="x"]]` refused the
whole render where the V emitter wrote `Note over w : [err]`, and
`[?if … [then [err code="x"]] …]` failed with `no member "exit"`.

So the image lifts such an element under the reserved tag
`cx-err-literal`, carrying its source name on the image-level
attribute `cx-renamed-from`. The tag is deliberately NOT `cx:`-
prefixed: in this projection the `cx:` locals are the §4 VALUE tags
and consumers classify on that prefix, while an `err` element is an
ordinary element literal that must keep behaving like one in every
walk — only its NAME is unusable. The carrier is an ATTRIBUTE because
a source element cannot forge one: source attributes become `cx:attr`
CHILDREN in this projection, so a lifted element has no attributes of
its own.

A consumer rendering a node's source name reads `@cx-renamed-from`
when present and the tag otherwise, so the rendered text is unchanged
(`[err]`). The rename is in the shared lift, so it holds for every
image mode and every consumer, not only this module. Pinned by
`pin-err-literal-*` in `vcx/tests/testdata/code_diagram_golden/`.

A fork of this module still runs under engine invocation for those
three bindings. Since #889 the module ALSO owns a source-text ingress
of its own — the native primitive `[$diagram-program-image SRC MODE]`
(mini-ruling DRW3-3), which parses and lifts inside the module and is
what makes `of-source` (§10.4) and `code-diagram` (§10.1) callable
from a CX program. DR-7a's load-bearing clause holds: the renderer
never parses; the engine hands it the image.

## §2. Public surface

| Function | Signature | Behavior |
|---|---|---|
| `render-mermaid` | `($program::element $source::string $detail::string) -> string \| err` | The §10.1.2 Mermaid reference renderer (§4 below). Top-level admission per §3; refusal = `[err code="cx-err:CXER0281" …]`. |
| `rules` | `() -> element` | The sealed render-rules table (§3) — DATA, not behavior. |
| `admitted` | `($local::string) -> bool` | Top-level admission verdict: rows ∪ aliases ∪ scaffolding. |
| `extract-mermaid` | `($rendered::string) -> string \| err` | Recover the embedded source from the `%%cx:<base64>%%` leading comment. |
| `extract-svg` | `($rendered::string) -> string \| err` | Recover the embedded source from the `<metadata><cx:source>` block. |
| `extract-png` | `($rendered::bytes) -> string \| err` | Recover the embedded source from the `tEXt` chunk keyed `cx-source`. |
| `render-dot` | `($program::element) -> string` | The DOT text handed to graphviz (§8.1). Pure. |
| `render-svg` | `($program::element $source::string) -> string \| err` | DOT → `dot -Tsvg` → metadata splice; the dot-less envelope when graphviz is unavailable; `CXER0271` when `subprocess` is withheld (§7). **Impure** (`subprocess`, REQUIRED). |
| `render-png` | `($program::element $source::string) -> bytes \| err` | DOT → `dot -Tpng` → tEXt-chunk splice; the dot-less envelope when graphviz is unavailable; `CXER0271` when `subprocess` is withheld (§7). **Impure** (`subprocess`, REQUIRED). |
| `svg-envelope` / `png-envelope` | `($source::string) -> string` / `-> bytes` | The dot-less forms (§6). Pure. |
| `inject-svg-metadata` / `inject-png-chunk` | `(…$source::string)` | The two metadata splices (§8.1). Pure. |
| `crc32` | `($b::bytes) -> int` | PNG CRC-32 (RFC 2083). Pure. |
| `of-source` | `($src::string $format::string $detail="min") -> string \| bytes \| err` | Render CX SOURCE TEXT in one call, lifting internally (§10.4). The CLI routes through this. **Impure** (`svg`/`png` reach the graphviz hop). |
| `code-diagram` | `($src::string $level::string) -> string \| err` | The playground renderer: auto-detect ERD / CFG / SEQ from source text and emit Mermaid at `min` \| `compact` \| `full` (§10). |
| `code-rules` | `() -> element` | The sealed wave-3 rule table (§10.2) — DATA, not behavior. |
| `code-class` | `($local::string) -> string` | The SEQ inner-dispatch class of a directive name (`generic` when untabled). |
| `effect-graph` | `($src::string $level::string) -> string \| err` | The EFFECT/CAPABILITY graph of CX source text (§11): which of `security.md` §2's nine capabilities the program reaches, through which call path, and which only under a branch. Mermaid at `min` \| `compact` \| `full`. |
| `effect-rules` | `() -> element` | The sealed effect-graph rule table (§12) — DATA, not behavior. |
| `effect-cap` | `($prim::string) -> string` | The capability a PRIMITIVE charges, read live from the engine's own closed effect-point table; `""` for none. |

Extraction failures are `cx-err:CXER0100` err values with the exact
messages the shipped V extractors carried (byte-preserved at the
cutover).

## §3. The sealed rules table (DR-4a) and the completeness gate (DR-5a)

`[$diagram:rules]` returns ONE data value with four row classes:

- `[row directive=… rule=…]` — the §10.1.2 locked table, one row per
  directive (26 rows; `pipe` per mini-ruling DRW1-3).
- `[alias directive=… of=…]` — grammar-registry aliases
  (`for-array`/`for-map` → `for`, DRW1-5).
- `[scaffold directive=…]` — admitted-but-structural top-level
  wrappers: `let`/`def`/`const`/`lib` (DRW1-6).
- `[nested directive=…]` — emitters WITHOUT top-level admission:
  `http-client`, `fn` (DRW1-4) — rendered when nested, refused
  (`CXER0281`) at top level.

The table is **sealed**: not runtime-overridable; user extension is a
fork (which stops claiming §10.1.1 conformance) or a future named
extension surface ruled only when a live consumer exists.

The top-level admission check is rows ∪ aliases ∪ scaffolding, and it
is **top-level only** (consult finding C4): a NESTED directive outside
the table renders as a generic `[?name]` rectangle (the shipped
contract; the nested-refusal question stays open with fixture
program-viz-022, gate=pending).

**Completeness gate** (`vcx/tests/diagram_completeness_gate_test.v`,
red on synthetic drift — drift-redness verified at landing): (i) the
code.md §10.1.2 directive set and the rows are SET-EQUAL; (ii) every
row is exercised by the golden corpus (directly or through its named
emitter twin — send/try-send, receive/try-receive, the await family);
(iii) a registry directive outside the table refuses `CXER0281` at
top level; (iv) the classification over the FULL §4.1 grammar registry
is total and disjoint, every table name is a live registry directive,
and the module's admission verdict equals the table exactly.

## §4. The Mermaid form — normative byte rules

The §10.1.2 prose does not determine the output bytes; this section
does (consult finding C3 — every rule below was recovered from the
captured golden corpus with the pre-cutover V source as tie-breaker,
and is now spec, not code archaeology). The corpus
`vcx/tests/testdata/diagram_mermaid_golden/` (40 sources × 3 rungs,
captured ONCE from the unmodified V renderer at the wave-1 head;
regenerator `vcx/tools/regen_diagram_golden`) is the byte oracle; the
gate `vcx/tests/diagram_mermaid_golden_test.v` asserts equality.
Regenerating the corpus after the cutover is golden movement —
forbidden except under a DR-8 mini-ruling recorded in the ledger
first.

- **Envelope.** Line 1: `%%cx:<base64(source)>%%` (standard padded
  RFC 4648). Line 2: the dialect — `flowchart TD` or
  `sequenceDiagram`. Lines are `\n`-joined with no trailing newline.
- **Dialect pick.** `sequenceDiagram` iff the TOP-LEVEL node is
  `http-service` / `worker` / `select`, peering through a top-level
  `[?let]`'s labeled `body=` only. Everything else is `flowchart TD`.
- **Node ids** mint as `n1`, `n2`, … in emitter call order —
  depth-first, exactly the shipped order: `n1` = `(["start"])`, `n2` =
  `(["result"])`, body from `n3`; then `n1 --> <body-exit>` and (when
  distinct) `<body-exit> --> n2`.
- **Shapes.** rect `id["l"]`, stadium `id(["l"])`, diamond `id{"l"}`,
  hexagon `id{{"l"}}`, subroutine `id[["l"]]`, channel `id[/"l"/]`;
  edges `a --> b` and `a -- "label" --> b`; every line indented four
  spaces.
- **Escape set** (labels and edge labels): `\` → `\\`, `"` → `\"`,
  newline → `\n`, applied in that order.
- **Expression labels** (the `expr_label` twins): strings `'…'`; ints,
  floats, durations, bools verbatim; atoms `:name`; sequences
  `(a, b)`; arrays `[a, b]`; blocks `…`; maps and the
  bigint/decimal/period/date/datetime scalars `<lit>`; bindings
  `$name` with compact path steps (`/x` `@x` `.x` `/*` `//x` `//*`
  `/..`, kind tests spelled `name()`, each predicate as `[…]`); calls
  `f(a, b)` (`f()` when empty; result steps not shown); patterns
  `[head]`; directives `[?name]`; for-comprehensions `[?for]`;
  wildcards `*`/`**`; slices `[slice]`; slice access `$b[…]`; the §4
  `<cx:expr>` hatch labels with its verbatim carried source (consult
  finding C5 — the one knowingly-divergent unreached edge). Bareword
  elements: `[name]`, `[name …]` when a body exists, plus attr chips
  per rung.
- **Detail rungs** (DR-11a): `min` — element name only, label cap 48;
  `compact` — first 2 attr chips ` @k=v` + ` (+K)` overflow, cap 72;
  `full` — all chips, cap 120. Bare `mermaid` maps to `min` (the
  pre-detail compatibility contract); the rung rides the format string
  as `mermaid[:detail]` (`cx diagram --format=mermaid:compact`) —
  §10.1.4's `--direction`/`--detail` flags remain unshipped, recorded
  (DRW1-8), not repaired in this wave. Labels over the cap truncate
  with `…`.
- **Per-family emitters.** Exactly the shipped forms, including their
  quirks — the bit-for-bit bar keeps them: `if`/`match` diamonds with
  a `[?if] result`/`[?match] result` join (an if without a labeled
  `else=` routes `false` straight to the join; positional `[then …]`
  children are NOT arms — only labeled slots are); `let` renders
  `value → $name → body` from labeled `bind=`/`value=`/`body=` slots
  only (the `[= …]` clause spelling renders as the `? → $` degenerate
  pair — shipped behavior); pipes chain `input → stage → …` with
  `[?fn]` stages as `fn(params) → body` capsules; iterations render
  `source → hexagon → :using → sink` (`collect`/`fold`; `:par`,
  `:init`, `preserve order` when par+ordered); for-comprehensions add
  the `binds $x`/`iter` edge label and the `:where` diamond;
  resilience wrappers are one subroutine badge `[?name]` + positional
  duration (timeout only) + at most 2 `:param v` chips + `…` overflow,
  with a labeled `:body` edge; `fallback` adds the `err` edge from
  body to recover-with; channels are lean nodes
  `channel "name" (buffer N)` registered by name (a `$var`
  send/receive target reuses the registered node or mints a
  `channel $var` placeholder); `select` is a diamond with `case N`
  edges; `async` is an `[?async] future` subroutine with a `spawn`
  edge; the await family is a barrier diamond fanning in sequence
  items; `cancel` points `cancel` edges at its operands;
  `http-service`/`worker` are subroutine capsules
  (`[?service] "name"` / `[?worker] "name"`) — worker with a labeled
  `:body` edge; nested `http-client` renders
  `[?http-client] METHOD url`. The sequenceDiagram path is the shipped
  stub: one `Note over Caller: [?name]` per directive, slot values
  recursed in order (DRW1-8 records the divergence from §10.1.2's
  swimlane prose; repairing it would move goldens and is deliberately
  not bundled with the port).

## §5. Round-trip identity posture (DR-8a)

The embedded payload is the VERBATIM source bytes — never
canonicalized, never addressed: no Tier-1/Tier-2 address, canonical
byte, or preimage participates (letter finding 5 / §6: the renderer is
BEHAVIOR/OUTPUT only, outside the identity epoch). Gate 9's contract
is `render → extract → parse ≡ structural AST equality`, all three
formats.

## §6. The dot-less envelope contract (DR-3a)

The dot-less behavior is NAMED NORMATIVE (replacing the false CXER0001
doc-comment the letter's finding 7 flagged). `svg`/`png` return the
round-trip-preserving envelopes — a 1×1 SVG viewport carrying
`<metadata><cx:source>`, and a 1×1 grayscale PNG carrying the
`cx-source` tEXt chunk — whenever a caller who HAS the `subprocess`
capability cannot get output from graphviz: `dot` absent from PATH, a
non-zero `dot` exit, a spawn failure, a timeout. The envelope is the
dot-less form of the contract; the graphviz diagram is the dot-ful
form; gate 9 passes on both and pins each under the condition that
actually produces it.

**A withheld `subprocess` capability is NOT one of those reasons**
(RULED: DSC-1c, `ledger/rulings_2026_08_20_diagram_svg_capability.md`,
superseding DRW2-1). It is a refusal, not a degradation — see §7.

The two conditions are told apart by the err code the effect point
returns: `CXER0271` is the capability denial and REFUSES; a `CXER40xx`
code or a `proc-result` with a non-zero exit takes the envelope road.
`[?fallback … [recover-with …]]` performs the inspection, so the
denial still never propagates railway-style out of the binding
(consult finding C14's requirement) — it arrives as a value the
renderer decides on.

## §7. The capability (DR-2a, DSC-1c)

The hop is `[$process-run ["dot" "-T…"] …]`, charged to `subprocess`.

- **The `svg` and `png` formats REQUIRE an explicit grant from the
  caller** (RULED: DSC-1c, superseding DRW2-1's "the subcommand grants
  it itself"). Without it `render-svg` / `render-png` return
  `cx-err:CXER0271` naming the capability and the flag. Silently
  substituting a 1×1 envelope for a caller who asked for a rendered
  diagram answers a question nobody asked; the envelope is the answer
  to *graphviz is unavailable*, which is a different condition.
- **The rule is the MODULE's, so every caller sees it identically** —
  `cx diagram`, `cx eval --target=svg|png`, the C ABI, an embedding
  host. On the CLI the grant is the ordinary `--allow-subprocess`
  (`--allow-common` / `--allow-all` also carry it); a misspelled
  `--allow-…` is a hard error naming the accepted set, per
  `misc/cli.md` §3.7.
- **Mermaid stays capability-free** — it is pure text.

`security.md` §2 specifies an *allowed executables* constraint for
this capability and the engine carries the field, but `cap_guard`
does not yet enforce it (consult finding C12): a grant is currently
all-or-nothing. When the constraint is wired, this module's grant
narrows to exactly `dot` with no change here — the argv is a literal
in the module.

## §8. Performance (DR-6a — measured at landing)

- **Dispatch discipline (normative implementation note):** per-node
  dispatch is a flat `[?if]`/`[=]` chain or a rules-map lookup — a
  wide per-node `[?match]` is refused at review (~20-45µs/arm measured
  vs ~2µs flat).
- **The asserted performance property is LINEARITY, not a wall time**
  (RULED: ISW-1, #893). Render work must be linear in program size:
  quadrupling the program's stages may cost at most ~4× the eval steps
  (the F4 evaluation budget's own work counter) and ~4× the output
  bytes, plus a fixed per-render slack. Eval steps are a property of
  the program and the module and of nothing else — identical on every
  machine under every load — so this bound is a real regression
  tripwire. Gate: `vcx/tests/diagram_bench_gate_test.v`.
- **Calibration note (a recorded measurement, NOT a gate criterion):**
  a 200-node Mermaid render is ≈ 12-18ms warm (measured 2026-08-20 at
  landing, best-of-5 on the reference machine; cold + module load ≈
  32ms — the engine seam caches the loaded module per process), and
  the DR-6a figure for it is 25ms. This was previously asserted, and
  #893 showed why it cannot be: on a build machine carrying five
  parallel compiles the SAME tree measured ≈ 55ms, and on a quiet one
  ≈ 9-17ms. The gate was reporting the load average. The figure stays
  recorded and the gate still PRINTS best/median/worst on every run so
  drift remains visible in the logs; it no longer votes on the exit
  code. (Re-measured 2026-08-21: eval steps 52381 at 99 stages and
  205336 at 396 — ratio 3.92 — bit-identical between load average 3
  and load average 90, while the wall-time spread over five samples
  widened from 9.6/11.6/24.0ms best/median/worst.)
- The letter's proposed ≤ 5s corpus-gate budget is DOMINATED by the
  graphviz process spawns, not by CX: the 20-fixture × 3-format
  round-trip lane runs ≈ 9s with `dot` on PATH and ≈ 0.6s without
  (20 SVG + 20 PNG `dot` invocations at ≈ 200ms each). The budget is
  therefore NOT asserted as a gate — it would be a graphviz
  benchmark, not a renderer one. The CX halves it does cover are
  gated above and in the vector lane.
- **PNG CRC-32 is O(8 bits × chunk bytes) of interpreted CX.** The
  chunk data is base64 of the source, so cost scales with program
  size: negligible for corpus-sized programs, ≈ 0.5s for a ~5 KB
  source. A table-driven or native CRC is the obvious lever if a
  large-program PNG ever matters; recorded rather than pre-optimized.

### §8.1 The DOT form — normative byte rules

As with Mermaid, the prose determined nothing; the pre-cutover corpus
`vcx/tests/testdata/diagram_vector_golden/` pins it (gate:
`vcx/tests/diagram_vector_golden_test.v`, hermetic — it never spawns
`dot`).

- Header: `digraph CX {`, `  rankdir=TB;`,
  `  node [shape=box,fontname="Helvetica"];`; footer `}`; `\n`-joined.
- One node line `  nIDX [label="…"];` per directive / for-comp, then
  (when it has a parent) one edge line `  nPARENT -> nIDX;`.
- **`IDX` is the emitter buffer's CURRENT LINE COUNT, not a counter** —
  so ids advance by 2 per node with an edge, starting at `n3`.
- **The root is emitted with parent 0**, so every diagram carries an
  edge from `n0`, a node that is never declared. Both quirks are
  shipped behavior preserved bit-for-bit under DR-8.
- Only directives and for-comprehensions produce nodes; a for-comp
  descends into its yield ONLY. Labeled slots are descended through
  with the parent unchanged; values produce nothing.
- Label escape is `"` → `\"` and nothing else.
- **SVG splice:** the metadata block is inserted immediately after the
  root `<svg …>` START TAG — i.e. as the root element's FIRST CHILD,
  the position SVG 1.1 §5.10 gives `metadata` (RULED: DSC-1a). The
  start-tag end is located quote-aware: a `>` inside a single- or
  double-quoted attribute value (XML 1.0 `AttValue`) does not end the
  tag. A self-closing root (`<svg …/>`) is opened into a container so
  the child has somewhere to live. A document with no `<svg` passes
  through unmodified.
  Until DSC-1a the block went after the FIRST `>` in the document,
  which on real graphviz output ends the `<?xml …?>` declaration — so
  it landed in the prolog, before the doctype and outside the root.
  XML 1.0 §2.1 admits neither (`document ::= prolog element Misc*`;
  `prolog ::= XMLDecl? Misc* (doctypedecl Misc*)?`), and every SVG the
  renderer emitted was malformed. Mini-ruling DRW2-2 preserved that
  bit-for-bit inside the #758 port; DSC-1 supersedes and fixes it, and
  the `splice.svg` golden moved with it. Validity is now GATED
  (`vcx/tests/diagram_vector_golden_test.v` case v, over the envelope,
  the fixed input, and a graphviz-shaped input). The round-trip is
  unaffected either way — the extractor scans for `<cx:source`
  anywhere.
- **PNG splice:** the `tEXt` chunk is inserted immediately after the
  IHDR chunk, located by reading IHDR's big-endian length at offset 8
  (`insert-at = 8 + 8 + len + 4`). A blob under 33 bytes, or an IHDR
  length that overruns the file, passes through unmodified. This is
  CORRECT as shipped and was checked for an SVG-analogous defect
  (DSC-1b): `tEXt` is an ancillary chunk RFC 2083 §4.2.3 admits
  anywhere between IHDR and IEND, the keyword `cx-source` is a legal
  1-79 byte Latin-1 keyword, and the CRC-32 verifies. Also gated
  (case vi of the same lane: signature, IHDR-first, IEND-last, exact
  chunk walk, every CRC, the keyword).

## §9. Errors

| Code | When |
|---|---|
| `cx-err:CXER0281` | Top-level directive outside the admission set (§3) — message names the directive and the §10.1.2 table. |
| `cx-err:CXER0100` | Unrecognized format string; extraction marker/metadata/chunk missing or malformed (messages byte-preserved from the shipped extractors). |
| `cx-err:CXER0271` | `render-svg` / `render-png` called without the `subprocess` capability (§7, DSC-1c) — `E_CAP_DENIED`, naming the capability and the `--allow-subprocess` flag. NOT the dot-less road. |

`CXER0280` remains retired-to-reserved (RULED 808-1a);
UNRENDERABLE_DIRECTIVE is the renderer's only refusal code.

## §10. The playground renderer — CFG / ERD / SEQ (wave 3, DR-1a)

**Status:** Current (#889, RULED DRW3-1 —
`ledger/rulings_2026_08_20_diagram_wave3.md`). The SECOND renderer —
the auto-detecting Mermaid emitter behind `cx code-diagram` and the
wasm export `cx_code_diagram_with_level` — is pure CX in this module;
`vcx/code/code_diagram.v` retains no emitter logic (DR-9a,
cutover-first). Its output is pinned byte-for-byte against the corpus
captured from the V emitter before the cutover
(`vcx/tests/testdata/code_diagram_golden/`, 88 sources × 3 levels).

### §10.1 Entry, ingress, and classification

`[$diagram:code-diagram $src $level]` takes SOURCE TEXT, not the
injected image: this renderer's contract brackets the parse on both
sides. In order:

1. `[?cx …]` processing instructions are stripped and the remainder
   trimmed; an empty remainder renders the placeholder `erDiagram`.
2. ONE source rewrite is applied: a bracket-shaped `[?match]` arm
   pattern (`[case [< 13] B]`) is quoted (`[case '< 13' B]`), which is
   what makes such a source parse at all. Re-measured 2026-08-21,
   `[?match 12 [case [< 13] "small"] [else "big"]]` is still refused
   (`CXER0100`, "expected pattern head"), so this one is still
   load-bearing; it retires the same way when the parser accepts a
   bracket-shaped arm pattern.

   DRW3-2's SECOND rewrite — a single-slash absolute path step `/Name`
   becoming `//Name` — is RETIRED (#899, RULED: ISW-1). It no longer
   affects parseability (`[?let [= $x /root/item] $x]` parses; it fails
   only at eval, for want of `$doc`) and it was output-visible in the
   wrong direction, labelling an absolute path as a descendant-anchored
   one. Labels now read as the source wrote them (`[= $x /root/item]`,
   `for $u :in /users`).

   One caveat the retirement measured and this clause records, because
   the rewrite was hiding it: `[?modify]` REQUIRES a `//`-rooted focus
   (`CXER0100: [?modify] focus slot must be a CXPath '//…'`). A
   `[?modify /users/user[1] …]` source does not parse, and the rewrite
   was silently turning it into a DIFFERENT, valid program and drawing
   a diagram of that. With the rewrite gone such a source falls back
   like any other unparseable one.
3. The patched text is lifted through the module's own ingress
   primitive (`[$diagram-program-image SRC "code"]`, mini-ruling
   DRW3-3); on refusal the UN-patched text is lifted. The primitive
   itself carries the run surface's guarded DATA fallback (RULED:
   D910-1, #910 — the eval_code contract, same guards): a source the
   PROGRAM reading refuses — but which is not unambiguous program
   intent (no unknown/retired directive, no program-committed syntax
   error, no registered `[?directive]` in its data reading) — and which
   the DATA reading accepts, lifts as the DATA tree in the same image
   vocabulary, so the data language's own documents (prose bodies, bare
   URLs and paths) are diagrammable. Only when BOTH readings refuse
   does the renderer classify on text alone — a top-level directive
   head in the sequence-trigger set yields `sequenceDiagram`, any other
   directive head yields `flowchart TD`, else `erDiagram`.
4. The `"code"` image is the §1 image plus two engine-side additions a
   pure renderer cannot compute for itself: a `<cx:def-image name=…>`
   child carrying the LOWERED body of a `[?def]` (whose structural
   parse the parser defers as `raw-source` text — DRW3-4), and a
   structural `<cx:path leading=… ><cx:pstep name=…/>…` node in place
   of the `<cx:expr>` source-text hatch for a CXPath expression, since
   this renderer's label for a path is the steps-joined form
   (DRW3-6).
5. Dispatch: a top-level sequence-trigger (peering through `[?let]`
   slot values) → SEQ; else any top-level directive or comprehension →
   CFG; else → ERD.

### §10.2 The sealed wave-3 rule table

`[$diagram:code-rules]` returns ONE data value; the emitters READ it,
so the sets below are the code, not a description of it. Four row
classes:

**Sequence triggers** — a top-level directive that routes the whole
program to SEQ:

| Directive | Render |
|---|---|
| `[?worker]` | Actor lane; body emitted inside an activate/deactivate frame |
| `[?channel]` | Channel lane; the `[?let]` binding aliases it |
| `[?http-service]` | Service lane plus the implicit `client` lane |
| `[?select]` | `alt`/`else` frame, one arm per case |
| `[?async]` | Detached `async-N` lane with a spawn arrow |

**Block breakers** — a directive that ends a CFG basic block:

| Directive | Render |
|---|---|
| `[?if]` | Diamond with true/false arm targets |
| `[?match]` | Dispatcher with one labeled edge per arm |
| `[?modify]` | Single update block: `modify @ FOCUS \| action \| …` |
| `[?def]` | Own subgraph with a trapezoid entry and stadium exit |
| `[?for]` | Loop box with a `binds $x` edge and a back-edge |
| `[?let]` | Binding-setup node feeding the body's control flow |

Every other directive composes into a basic block.

**SEQ inner-dispatch classes** — the class the emitter takes for a
directive inside a worker/async/select body. A directive with no row
takes the `generic` path: `Note over WORKER : [?name]`.

| Directive | Class |
|---|---|
| `[?send]` / `[?try-send]` | `send` |
| `[?receive]` / `[?try-receive]` | `receive` |
| `[?select]` | `select` |
| `[?async]` | `async` |
| `[?await]` / `[?await-all]` / `[?await-any]` / `[?await-race]` | `await` |
| `[?cancel]` | `cancel` |
| `[?retry]` / `[?timeout]` / `[?circuit-breaker]` / `[?rate-limit]` / `[?bulkhead]` / `[?fallback]` | `resilience` |
| `[?let]` | `let` |
| `[?if]` / `[?match]` / `[?modify]` | `branch` |
| `[?for]` | `for` |

**ERD scalar types** — the row type token for a scalar image tag; the
domain is exactly the scalar tags the §4 projection emits
(`int` `bigint` `decimal` `float` `bool` `str` `atom` `dur` `period`
`date` `datetime`), mapping to `int` `bigint` `decimal` `float` `bool`
`string` `atom` `duration` `period` `date` `datetime`. Anything else
is `string`.

### §10.3 The wave-3 completeness gate

`vcx/tests/code_diagram_completeness_gate_test.v` (red on synthetic
drift — verified by removing a row at landing), six clauses:

(i) every row names a LIVE §4.1 registry directive; (ii) the classes
the table declares are exactly the classes the emitter implements, and
the live dispatch is total over the registry; (iii) every row is
exercised by a source in the golden corpus (directly or through a
named emitter twin — the `await` family); (iv) the ERD type rows are
exactly the §4 scalar tags; (v) a directive outside the table takes
the declared generic paths; (vi) the tables in THIS section and the
module's `code-rules` value are SET-EQUAL in both directions — a row
added to one and not the other reddens.

### §10.4 The caller-facing entry (`of-source`)

`[$diagram:of-source $src $format $detail]` (format `mermaid` | `dot` |
`svg` | `png`; `detail` defaults to `min`, the DR-11 compatibility
rung) renders CX SOURCE TEXT in one call, performing the lift
internally through the same ingress primitive (`"ref"` mode — the
wave-1/2 image, unchanged). It is the module's answer to the finding
that a frozen stdlib module was in practice uncallable: every other
render verb demands the engine-injected image.

**One path, no twin (normative).** `render_diagram` — and therefore
`cx diagram`, `cx eval --target=mermaid|svg|png`, the wasm
`cx_code_diagram` export, and the gates — routes THROUGH `of-source`.
The bytes a CX caller receives for a source are the bytes the CLI
prints for the same source; the wave-1 golden corpus is rendered
through this path and is unmoved.

`of-source` is declared **impure**: `svg`/`png` reach the graphviz hop
(§7; the DRW2-1 grant posture is unchanged by this wave), while
`mermaid`/`dot` perform no effect. Those two arms call `dot` inline
rather than through `render-svg` / `render-png`: the engine's purity
classifier is one level deep, so an impure-declared def must reach the
gated primitive in its OWN body (the #788/#818 parity gate refuses the
mislabel otherwise). Only the hop repeats — admission, the DOT text,
the splices and the envelopes are the same shared code both entry
points use. A source BOTH readings refuse returns the ingress
primitive's `[err code="cx-err:CXER0100" …]` verbatim; a source only
the PROGRAM reading refuses takes the ingress's guarded DATA fallback
(§10.1 step 3, RULED: D910-1) and renders the data tree's diagram.

**The data-tree render** (RULED: D913-1, #913;
`ledger/rulings_2026_08_21_diagram_vector_data.md`). A document whose
image carries NO program structure — no `cx-node`-marked node anywhere
— but at least one real element renders its ELEMENT TREE in every
format: elements as nodes labeled on the same `min|compact|full`
ladder the flowchart labels use, containment as edges, in `mermaid`,
`dot`, `svg` and `png` alike. (The lift's single-child `item`/`entry`
wrappers are containers the walk descends through, never nodes.)
Before this ruling the DOT walk emitted nodes only for directive
images, so `cx diagram --format=svg` of every shipped data example
wrote an empty canvas with exit 0, and the flowchart collapsed the
document to the `start → … → result` envelope — the #910
silent-degradation class, one lane over. Two sibling extensions under
the same ruling: a multi-form program's `cx:block` DESCENDS in both
walks (each form chained, pipe-style, in the flowchart; the DOT walk
treats it as a wrapper), where it previously collapsed to one `…` leaf
in the flowchart and vanished from the DOT text entirely. Directive
renders are untouched by construction — any `cx-node` mark anywhere
keeps the shipped walks, and the full golden corpus pins them
byte-identically. The detail suffix reaches the DOT text through
`of-source`'s dot/svg/png arms; bare `render-dot` stays `min`.

### §10.5 The full-level ERD's DOCUMENT root

The `full` ERD rung prefixes the entity blocks with a synthetic
`DOCUMENT` entity — a whole-document summary — unless the compact
render is a single childless entity, in which case it is suppressed
entirely (that suppression rule is unchanged).

**The box carries VALUES, not field names** (RULED: DGX-2,
`ledger/rulings_2026_08_21_diagram_capabilities.md`; #901 item 4). It
shipped listing four stat FIELDS and never their values — a schema of
statistics rather than the statistics, while every entity beside it
already used the Mermaid comment slot for its own values (`int id
"@ 1"`). Three rows, in this order, read off the occurrence stats the
full-level walk already collects for the per-entity badges:

| Row | Value |
|---|---|
| `int node_count "N"` | the total number of elements the ERD walk reaches, scalar children included |
| `int type_count "N"` | the number of distinct element NAMES among them |
| `int max_depth "N"` | the greatest containment depth recorded, the root being depth 0 |

The shipped fourth row, `string source_path`, is **dropped**. This
renderer's ingress is source TEXT: `code-diagram` has never been handed
a path, and the one caller that has one (`cx code-diagram FILE`) does
not pass it. A row that can only ever be empty is the same defect at
one quarter scale.

## §11. The effect/capability graph — a second VIEW (`effects`)

**Status:** Current (RULED: DGX-1,
`ledger/rulings_2026_08_21_diagram_capabilities.md`). The THIRD
renderer in this module, and the first that renders something other
than the program's own shape: it renders **what the program can
actually do**.

CX's differentiator is that capabilities are explicit and effects are
declared. `core/security.md` §2 names nine capabilities and §2.1 closes
the effect-point set — but until this view, nothing showed a reader
holding a CX source which of them the program reaches, or through what.
That question is answerable statically from the program's own image,
and this module already holds a source-text ingress and a structural
image (§10.1), so it is answered here.

### §11.1 Entry and surface

| Where | Spelling |
|---|---|
| CX call | `[$diagram:effect-graph $src $level]` — `$level` = `min` / `compact` / `full` |
| CLI | `cx code-diagram --view=effects [--level=…] [FILE or -]` |
| Sealed table | `[$diagram:effect-rules]` → element (§12) |
| Table lookup | `[$diagram:effect-cap $prim]` → the capability a primitive charges, `""` for none |

`--view` defaults to `auto`, which is §10's ERD/CFG/SEQ
auto-detection unchanged byte for byte; an unknown `--view` is a hard
error naming the accepted set (the `misc/cli.md` §3.7 posture). The
`effects` view is Mermaid only — the DOT emitter walks the PROGRAM
image, and this is a derived graph, so `dot`/`svg`/`png` would be a
second emitter and a second capability question; both are deliberately
out of this surface.

Ingress is `[$diagram-program-image SRC "effects"]` — the §10.1 `"code"`
image plus a `<cx:lib-image module=… alias=… kind=…>` child on every
`[?lib]`, whose surface text the parser otherwise defers as
`raw-source` exactly as it defers a `[?def]` body. Without it an
aliased import resolves to nothing and its effects are MISSED, which
§11.4 forbids. The `"effects"` mode also re-expands a def-image body,
so a `[?def]` nested inside a `[?def]` gets its own image. `"ref"` and
`"code"` are untouched.

`[?cx …]` PIs are stripped and the remainder trimmed; an empty
remainder renders the §11.3 nothing-reached graph. A source the parser
REFUSES returns the ingress primitive's `[err code="cx-err:CXER0100"]`
verbatim — degrading to a placeholder would be a claim about a program
nobody has read.

### §11.2 Where the classification comes from (normative)

**The primitive→capability map is read LIVE from the engine and is
never copied into this module.** The native primitive
`[$diagram-effect-table]` returns `security.md` §2.1's closed set as the
engine holds it (`capability_gated_prims()`, held to the spec table in
both directions by `make check-effect-alignment`), together with the
capability roster, the §6.5.1 impure-without-capability exception set,
the Ring-2 verbs the packs declared impure, and the frozen
`cx-stdlib/*` roster. A stale copy of that map could only ever fail in
one direction — omitting a newly-gated effect point — and a capability
diagram that quietly under-reports is worse than none.

Callee resolution **mirrors the engine's own classifier**
(`purity_checker.v :: classify_callee`), in this order:

1. an unqualified name matching a `[?def]` in the image is a CALL edge
   (a local def shadows);
2. the name, alias-expanded and normalized (`prefix:local` →
   `prefix-local`, where the prefix is the frozen module's own last
   resolver segment), in the capability-gated map — it CHARGES that
   capability;
3. the same name in the impure-without-capability set — an UNCHARGED
   effect (shown at `full`);
4. the same name in the Ring-2 impure set — an OPACITY source (§11.4):
   a Ring-2 verb's charge is made inside the pack and registered at
   runtime, so no static table can name it;
5. a MODULE-QUALIFIED name whose prefix resolves to no frozen
   `cx-stdlib` module and no `[?lib]` alias — an OPACITY source;
6. anything else — **pure**, because that is what the engine itself
   classifies an unclassified name as.

A directive HEAD that charges takes its capability from the §12 `dir`
rows (§2.1 closes the *primitive* set; it does not enumerate directive
heads, and five charge).

### §11.3 The rendered form — normative byte rules

- **Envelope.** Line 1 `flowchart TD`; lines newline-joined, no trailing
  newline; two-space indent (the `code-diagram` family's, not the
  reference renderer's four). No `%%cx:%%` source marker — this
  renderer, like §10's, embeds none.
- **Node ids are DERIVED, not minted in emitter order**, so two renders
  of related sources are diffable — an auditor property: `prog` for the
  program, `cap_<C>` per capability, `def_<D>` per `[?def]`,
  `eff_<E>` per effect site, `unk_<N>` per opacity site (`unk_<kind>`
  at `min`, where sites of a kind collapse to one node), plus the fixed
  `any`, `nocap` and `nocharge` sinks. `<C>`/`<D>`/`<E>` are the
  §10-family id sanitizer's output.
- **Shapes** reuse the reference renderer's vocabulary: program
  `prog(["program"])` stadium; def `["def NAME"]` rect; effect site
  `[["NAME"]]` subroutine; capability `{{"NAME"}}` hexagon; opacity
  source `[/"…"/]` lean parallelogram.
- **Edges.** `-->` reached; `-.->` reached only under a branch arm;
  `==>` unknown; `--x` denied by a `[?with-caps]` narrowing. Call edges
  carry the label `|"call"|`.
- **Escape set** is §4's, unchanged.
- **Order** is fixed and total: the program node, def nodes in image
  order, effect nodes in first-appearance order, opacity nodes in
  appearance order, capability nodes in ROSTER order (`security.md`
  §2's, which is `capability_names()`'s), then the sinks; then call and
  effect edges in appearance order, capability edges, opacity edges,
  and at `full` the uncharged edges.

**Rungs.**

- `min` — the verdict. The program node and one hexagon per capability
  the source charges, each with its status: `-->` unconditional;
  `-.->` with `conditional` reached, but every path passes a branch
  arm; `-.->` with `charged only in a def nothing calls` charged, but
  no path from the program's entry reaches it; `--x` with
  `denied by [?with-caps]` every reaching site sits inside a narrowing
  that denies it. Plus one opacity node per KIND present, each fanning
  to `any`.
- `compact` (the default) — the paths: def nodes, per-primitive effect
  sites, per-site opacity nodes, and the whole `prog → def → effect →
  capability` chain. A def nothing calls appears with no incoming edge:
  visibly dead.
- `full` — compact plus the uncharged effects and their `nocharge`
  sink, `--x` on a denied edge, the four `classDef` colour classes and
  their per-node `class` assignments.

**Conditionality is a PATH property.** The two reachability sets —
reached-at-all, and reached-through-unconditional-edges-only — are
computed to a fixpoint over the call edges from `main`. An effect
written outside any branch, in a def that is only ever called from
inside one, is CONDITIONAL. An arm carrier makes what it holds
conditional only under a branch directive: `cx:yield` is a match arm
under `[?match]` and an iteration body under a for-comprehension, and
only the first is a branch (§12's `arm` rows carry the `under` column
for exactly this).

**Nothing reached is a first-class answer.** A source that charges no
capability renders three lines and one edge to
`nocap["no capability-charging effect reached"]`. *This source is
statically capability-free* is the claim the view exists to be able to
make, and it must be sayable at a glance.

### §11.4 Honesty is normative: the opacity classes

A dynamic `[?eval]`, or an indirect call the walk cannot resolve, MUST
render as an explicit unknown edge and MUST NOT be silently omitted, at
EVERY rung. When any opacity source is present the render carries the
`any granted capability` sink, and a capability the walk did not reach
is described as *not statically reached*, never as *not reached*.

| kind | the site |
|---|---|
| `eval` | `[?eval]`, `[$cx:eval]`, `[$cx:eval-tree]` — charges `eval` AND fans to `any`: the tree it executes is not in the image |
| `call` | a callee that is neither a table primitive, nor a `[?def]` in this image, nor a resolvable module-qualified name |
| `dynamic` | a `<cx:expr>` source-text hatch (a dynamic element name, an operator-with-attrs form) — its inner calls are text, not structure |
| `lib` | a `[?lib]` whose module body is not in the image: any resolver that is not a frozen `cx-stdlib/*` name. An `https` resolver additionally charges `net` |
| `ring2` | a Ring-2 pack verb — its capability charge is made inside the pack and registered at runtime, so no static table names it |

There is deliberately **no** class for an unreadable `[?with-caps]`
narrowing: the parser refuses a non-literal `[deny …]` operand outright,
so a `[?with-caps]` that reaches the image at all has a readable deny
list (measured at landing; the DGX-1c draft carried such a class and it
was removed).

### §11.5 What the effect graph cannot see

Stated normatively so a reader does not assume completeness. These are
the limits the image cannot flag for itself — §11.4 covers what it can.

1. **Reachability is syntactic, not semantic.** An effect behind a
   condition that is always false still appears. The graph answers
   *what is in the program*, never *what a run will do*.
2. **Resource scoping is invisible.** `security.md` §2 scopes `read` to
   path roots and `net` to host globs; this view shows the CAPABILITY
   and never the resource. *It can read* — not *it reads
   `/etc/passwd`*.
3. **Ring-2 pack verbs** are invisible to the static tables; they
   render as the `ring2` opacity class rather than as a charge.
4. **A frozen-module verb that COMPOSES primitives under a name of its
   own resolves as pure.** Resolution is by name — `cx-stdlib/io`'s
   `read-file` IS the primitive `io-read-file`, which is how the frozen
   modules are built — and a verb that instead composes several
   primitives resolves to none. Measured across all bundled modules at
   landing (2026-08-21) the set is small and known:
   `diagram:render-svg`, `diagram:render-png`, `diagram:of-source`
   (each reaching `process-run` under `subprocess`) and the six
   `supervise:*` verbs.
5. **A declared `[effects …]` clause is not checked against reach.**
   The `"effects"` image lift carries a `[?def]`'s BODY, not its head
   clause. The graph reports what the body reaches, which is the honest
   half; the declared-vs-reached comparison is a linter, filed as a
   follow-up.
6. **Ordering, frequency and data flow are absent.** It is a
   reachability graph, not a trace.
7. **Impure directives that charge nothing** — `[?send]`, `[?receive]`,
   `[?worker]`, `[?channel]`, `[?async]`, `[?modify]` and the rest of
   §6.5.0's set — are not rendered. They are concurrency and structure,
   which §10's SEQ view already draws; this view is about capabilities.

## §12. The sealed effect-rules table and its completeness gate

`[$diagram:effect-rules]` returns ONE data value with four row classes,
and the emitters READ it, so the sets below are the code. What is
RENDERING POLICY lives here; what is a fact about the engine (§11.2) is
read live and is deliberately absent.

**Capability roster** — `security.md` §2's nine, in that order, each
with the CLI flag that grants it:

| Capability | Grant flag |
|---|---|
| `read` | `--allow-read` |
| `write` | `--allow-write` |
| `net` | `--allow-net` |
| `env` | `--allow-env` |
| `clock` | `--allow-clock` |
| `random` | `--allow-random` |
| `subprocess` | `--allow-subprocess` |
| `eval` | `--allow-eval` |
| `secret-reveal` | `--allow-secret-reveal` |

**Charging directive heads** — the capability a DIRECTIVE charges.
§2.1 closes the *primitive* set and does not enumerate these:

| Directive | Capability |
|---|---|
| `[?eval]` | `eval` |
| `[?reveal]` | `secret-reveal` |
| `[?http-client]` | `net` |
| `[?http-service]` | `net` |
| `[?sleep]` | `clock` |

**Branch-arm carriers** — an effect is CONDITIONAL iff its path passes
an arm carrier whose parent is the named branch directive:

| Carrier | Under |
|---|---|
| `then` | `[?if]` |
| `else` | `[?if]` |
| `case` | `[?match]` |
| `else` | `[?match]` |
| `yield` | `[?match]` |
| `case` | `[?select]` |
| `default` | `[?select]` |
| `recover-with` | `[?fallback]` |

**Opacity classes** — the five of §11.4: `eval`, `call`, `dynamic`,
`lib`, `ring2`.

### §12.1 The completeness gate

`vcx/tests/diagram_effect_completeness_gate_test.v`, red on synthetic
drift (verified by injecting and reverting a row deletion at landing),
seven clauses:

(i) the roster rows are SET-EQUAL to the engine's `capability_names()`
— a capability added to the language and not to this table reddens, and
vice versa; (ii) every `dir` row names a LIVE §4.1 registry directive
and a capability in the roster; (iii) every `arm` row's `under` names a
live registry directive and its carrier is a real image tag; (iv) every
opacity class is produced by at least one source in the golden corpus —
a class that cannot be demonstrated is not a class; (v) every roster
capability is REACHED by at least one corpus source, so no capability
can lose its emitter silently; (vi) the tables in THIS section and the
module's `effect-rules` value are SET-EQUAL in both directions — the
clause that stays red under a matched deletion, because clauses (i)-(v)
go on agreeing with themselves when the emitters read the table;
(vii) the module's live `effect-cap` verdict equals the engine's own
map for every gated primitive, so the live read of §11.2 cannot
silently become a copy.
