# Rulings 2026-08-20 — diagram renderer moves to CX (#758, letter DR)

## DR-1 … DR-11 — the design letter's eleven sub-rulings

**Status:** RULED (owner "7b", 2026-08-20: all eleven at their
recommended options; implementation starts NOW, in-cut for v0.16.0).
The design letter is `spec/02-working/diagram_renderer_cx.md`; its §7
status flips to RULED with this file as the ruling store entry.

| Ruling | Option | One-line effect |
|---|---|---|
| DR-1 | (a) | Both renderers, sequenced: `diagram.v` (the §10.1.2/gate-9 reference) first; `code_diagram.v` (playground) as a later wave. |
| DR-2 | (a) | Cut line at letter finding 3; the effect seam is `cx-stdlib/process` under `subprocess(dot)`; `shell_dot`/`import_os_execute` are deleted, not wrapped (wave 2). |
| DR-3 | (a) | `cx-stdlib/diagram`, a Ring 1 pack; SVG/PNG are its only impure entry points (wave 2); the dot-less fallback envelope becomes the NAMED normative contract. |
| DR-4 | (a) | The §10.1.2 table is a sealed CX data value inside the module — authored as data, gated by DR-5, not runtime-overridable. |
| DR-5 | (a) | Normative bidirectional completeness gate, red-on-synthetic, landing in the SAME wave as the first cutover: table↔rules↔fixtures↔grammar-registry. |
| DR-6 | (a) | Dispatch discipline (map lookup + closure call / flat `[?if]` chain — never a wide per-node `[?match]`, ~20-45µs/arm measured) + measured budget (~25ms / 200-node render) + bench gate. |
| DR-7 | (a) | Engine-injected program-as-data tree + verbatim source bytes in the `[?eval]`-context (L99) pattern; no new public parse surface this wave. |
| DR-8 | (a) | Bit-for-bit preservation; every spec-reality divergence adjudicated as a named mini-ruling BEFORE cutover; zero golden movement is the expected verdict. |
| DR-9 | (a) | Format-by-format cutover, V deleted per format in the same landing: wave 1 Mermaid + embed/extract for all three formats; wave 2 DOT/SVG/PNG + process seam; wave 3 playground emitter. |
| DR-10 | (a) | The port runs as a spec-sufficiency probe under the stream-22 bar; every V-source consult is a logged "the spec did not determine this" finding (register below). |
| DR-11 | (a) | Detail rungs ratified and documented: `min` legacy floor, `compact` interactive, `full`; bare `mermaid` defaults to `min`. |

---

## Wave-1 execution record (this session)

Scope per DR-9(a): the MERMAID target of `render_diagram` moves to
`cx-stdlib/diagram` (pure CX); the reverse-parse extractors for ALL
THREE formats move (shared pure code); the V mermaid emitters and
extractors are DELETED in the same landing. SVG/PNG rendering and the
`shell_dot` pair remain V until wave 2 (a scheduled remainder with a
named landing — the wave-2 tracker issue — not a deferral).

**Bit-for-bit instrument.** The shipped tree carries NO byte-golden
mermaid files (gate 9 is a behavioral round-trip; the gate-12 golden
directory `web/cx-diagram/golden/` cited at code.md §11.x does not
exist on disk — consult finding C1 below). The wave therefore FIRST
captures the V renderer's mermaid output for all 20 supported
`program-viz-*` fixtures at all three detail rungs into a committed
golden corpus (`vcx/tests/testdata/diagram_mermaid_golden/`), from the
UNMODIFIED V renderer at this head — capturing shipped behavior is not
golden movement; it is the DR-8 instrument. The CX port must then
match those bytes exactly, and the corpus stays as the permanent
regression net.

### Mini-rulings (DR-8 adjudications — each recorded BEFORE any behavior moves)

**DRW1-1 — the renderer ingress tree image.** DR-7(a) names "the
E1-lowered program tree". Measured against the shipped lift
(`program_node_to_data_q`), the E1 image collapses `ProgramForComp`,
`ProgramCall`, `ProgramPattern`, `ProgramPathExpr`, slices and
wildcards to the `<cx:expr>` SOURCE-TEXT hatch, and bare bindings to
hole nodes — structure the mermaid emitters' labels and the for-comp
walk require (`mmd_for_comp_flow`, `expr_label_raw`). Rendering from
the E1 image bit-for-bit would therefore need a parse surface inside
the renderer — DR-7(c) by the back door, refused by the ruling itself.
**Adjudication:** the engine injects the program's **program-XML
structural image** (spec/ast.md's bijective §4 projection,
`program_to_xml` — the image the E1 lift's own tag convention
"mirrors"), materialized as a CXDM data tree (engine-side XML parse of
the codec's own emission — no user-facing parse surface, no new
public spelling). DR-7(a)'s load-bearing clauses all hold: engine
injection, `[?eval]`-context bindings, zero new public ingress.
Identity is untouched (letter §6: renderer is BEHAVIOR/OUTPUT only).
Logged as consult finding C2.

**DRW1-2 — the `try` drift (letter finding 6) resolves by DELETION.**
`[?try]` was RETIRED from the directive registry (SAP C3c, code.md
§8.8 tombstone; program_tokens.v registry comment) — a `[?try …]` head
no longer parses. `renderable_directives`' `'try'` entry and the
`mmd_try` emitter are dead code behind a parse refusal. Adjudication:
delete both with the port; no spec row, no behavior change (shipped
behavior for `[?try]` input is a PARSE error, which is preserved).
The §10.1.2 table is NOT amended for `try`.

**DRW1-3 — the `pipe` drift: shipped behavior wins; the table gains
its row.** `[?pipe]` is a live registry directive with a dedicated
emitter (`mmd_pipe`: IN → stage → … → result) and sits in the
renderable set (mislabeled "scaffolding" in the const's comment), so a
top-level `[?pipe]` RENDERS today. Bit-for-bit default: keep
rendering. The §10.1.2 locked table gains the row
`[?pipe]` → "Pipeline stages: input → stage₁ → … → result" under this
token (a truing of the table to nine-months-shipped behavior, not a
new rendering rule).

**DRW1-4 — the `http-client` drift: top-level refusal stands; the
nested emitter is a named composed-rendering rule.** `[?http-client]`
is NOT in the renderable set — a top-level `[?http-client]` refuses
CXER0281 today — while its dedicated emitter (`mmd_http_client`)
renders it NESTED inside renderable compositions (fixture
program-viz-020). Bit-for-bit default: preserve both halves exactly.
The module's rules value records `http-client` (with `fn`) in a
`nested` rule class: not a table row, not scaffolding, top-level
refused, nested rendered. The completeness gate's clause (iv)
classification carries this class explicitly.

**DRW1-5 — `for-array` / `for-map` are registry aliases of the
`[?for]` row; bare `map`/`reduce` are covered by their table rows.**
The registry names `for-array`/`for-map` (parse-time `[?for]`
variants) sit in the renderable set; the §10.1.2 rows
`[?for]`/`[?map]`/`[?reduce]` (sequential + `[par]`) cover the
sequential and parallel shapes of all of them. The module table
records the aliases explicitly so clause (iv) classifies every
registry name without a silent bucket.

**DRW1-6 — scaffolding set ratified as data.** `let`/`def`/`const`/
`lib` are the admitted-but-structural top-level wrappers
(diagram.v:44-47's concept). Shipped: admitted top-level; `let` has a
structural emitter; `def`/`const`/`lib` render as generic
`[?name]` rects. Preserved exactly; the module table's `scaffolding`
class IS this set.

**DRW1-7 — `conformance/code.txt` name trued.** §10.1.1's gate-9
sentence names `conformance/code.txt`; the corpus lives at
`conformance/code.cxd` (the round-trip harness reads it there). The
spec sentence is trued to the real path (letter finding 1 flagged it;
stale name, zero behavior).

**DRW1-8 — §10.1.4 flag divergence and the sequenceDiagram stub are
RECORDED, not repaired, this wave.** (Measured precisely at the wave-2
close: the `mermaid:<detail>` suffix is NOT reachable from the CLI at
all — `render.v`'s output-target validation rejects `mermaid:compact`
as an unknown target before `render_diagram` ever sees it, so the
detail rungs are an ABI/wasm-only surface today. Pre-existing, verified
unchanged across both waves; it makes §10.1.4's missing `--detail`
flag a sharper gap than the letter's finding 7 stated.) Shipped CLI = `--format`/`-o`
only (no `--direction`/`--detail`); detail rides the
`mermaid[:detail]` format suffix; the sequenceDiagram emitter is a
note-per-directive stub chosen only for top-level
service/worker/select. Bit-for-bit bar: the CX port reproduces all of
it exactly. The spec-side truing of §10.1.4 to the shipped flag
surface rides the module spec (std-lib/diagram.md §CLI); a default or
flag CHANGE would move goldens and is deliberately not bundled (same
posture as DR-11's default).

### DR-10 consult log (spec-sufficiency probe register)

Each entry = a place the spec + corpus did NOT determine the byte, so
the V source (or its captured output) had to be consulted. Filed under
the stream-22 bar; findings 6 and 7 of the letter are entries C0a/C0b,
banked before the port.

- **C0a/C0b** — the letter's findings 6 (table↔code drift ungated) and
  7 (§10.1.4 flags, seq stub, detail suffix, CXER0001-vs-envelope,
  code.txt name): banked pre-port.
- **C1** — gate 12 names `web/cx-diagram/golden/` as the golden set;
  the directory does not exist in the tree. The bit-for-bit corpus had
  to be freshly captured from the shipped binary (see instrument note
  above). Spec gap: gate 12's golden inputs are unmaterialized.
- **C2** — §10.1.2 does not name the renderer's INPUT image at all;
  DR-7's E1 image loses for-comp/call/pattern structure to the
  `<cx:expr>` hatch (DRW1-1). Spec gap: the renderable data image is
  determined by no normative sentence; DRW1-1 + the module spec now
  pin it (the ast.md §4 projection).
- **C3** — NOTHING in §10.1.2 determines: node-id minting order
  (`n1`, `n2`, … in emitter call order), node shapes per family
  (stadium/rect/diamond/hexagon/subroutine/lean-parallelogram), edge
  label spellings (`true`/`false`, `:using`, `iter`, `case N`,
  `recv`, `err`, `binds $x`, `spawn`, `cancel`), the label grammar
  (`expr_label_raw` per node kind), truncation caps (48/72/120 by
  detail rung + `…`), the attr-chip cap (2 at compact, `(+K)`
  overflow), the mermaid escape set (`"`→`\"`, `\`→`\\`, newline→`\n`),
  the marker syntax (`%%cx:<base64>%%` leading line), the dialect
  heuristic (top-level http-service/worker/select, peering through
  top-level `[?let]` bodies only), the `[?if]`-without-else false-edge
  join, the resilience-band 2-param cap + `…`, or the fn-capsule
  `fn(params) → body` form. ALL of these were recovered from the
  captured golden corpus (shipped output) with the V source as the
  tie-breaker; every one is now WRITTEN into
  spec/03-approved/std-lib/diagram.md so a second implementation reads
  them from spec, not from V.
- **C4** — the §10.1.2 sentence "a directive not listed below SHALL
  raise CXER0281" is shipped as a TOP-LEVEL-ONLY check; a nested
  unlisted directive renders as a generic `[?name]` rect (fixture 022
  is gate=pending on exactly this). Spec gap: the sentence does not
  say "top-level"; the module spec now does; the pending fixture's
  decision stays open (unchanged).
- **C5** — expression labels for `ProgramPathExpr` (bare CXPath
  values) and dynamic-name elements: V renders a terse steps-joined
  form the XML projection hatches to source text. No fixture reaches
  either shape (verified against the golden corpus). The CX port
  labels the `<cx:expr>` hatch with its verbatim source text —
  recorded as the ONE knowingly-divergent unreached edge (would differ
  from V only for a top-level-reachable path-expr label, which no
  admitted top-level shape produces under the renderable set).
- **C6** — `[?fn]` param-list extraction tolerates positional-first /
  labeled `params=`/`body=` shapes (fn_extract) — determined by no
  spec sentence; reproduced from source + pinned by the goldens.
- **C7** — the roundtrip harness compares durations by `str_val` while
  duration literals carry `dur_val` — i.e. duration VALUES are not
  compared by the gate-9 AST equality (a V-side test-walk detail, not
  a spec sentence). No action this wave; noted for the gate-9 harness
  owner.
- **C8** — the program-XML projection CANNOT distinguish a labeled
  directive slot from a same-named positional directive child
  (`<cx:timeout>` = label `timeout=` OR a nested `[?timeout]`;
  `<cx:else>`, `<cx:name>` likewise). The V renderer distinguished by
  `slot.kind`, which the projection erases. The module's reading rule
  (now spec, diagram.md §4): per-emitter SOUGHT labels match a
  single-element-child `cx:L` wrap; resilience-param collection
  excludes ruled/nested/scaffold directive names and value tags (with
  the shipped `name` exception). Reproduces every golden; the
  divergence class (a labeled slot whose label collides with a ruled
  directive name, e.g. `[?retry timeout=1s body=…]`) is unreached by
  any fixture/pin and recorded here.
- **C9** — TWO CX-semantics findings the spec corpus does not teach an
  implementer: (a) `[$exists]` on an EMPTY ELEMENT is false (absence
  conflation), so found-tests over slot values need a non-empty
  wrapper (`[hit V]`) — a bare `[pos]` then-arm read as "absent"; and
  (b) `[and]`/`[or]` operands evaluate EAGERLY (no short-circuit), so
  a guard like `[and [$exists $w] [= [$name [$lab-val $w]] …]]` errs
  on the absent side and the err VALUE rides into member reads as
  `no member "id"` far from the cause. Both cost real debugging; both
  now have explicit guide-worthy shapes in the module (nested `[?if]`
  guards; the `hit` wrapper). Candidate guide/spec notes filed with
  this register.
- **C10** — the XML READER's cx-carry absorbs `<cx:int>`/`<cx:bool>`
  typed-scalar children into typed TEXT content (`[cx:max 3]`, not
  `[cx:max [cx:int 3]]`), so materializing the §4 projection by
  round-tripping its TEXT through `[$xml:parse]` does not reproduce
  the projection tree. The seam therefore BUILDS the tree directly
  (diagram_cx_seam.v `diagram_lower`, tag-for-tag the program_to_xml
  image; the for-comp filter wrapper renamed `cx:expr-clause` to keep
  the `cx:expr` hatch tag unambiguous). Spec gap: ast.md defines the
  XML text image; no normative sentence defines its CXDM
  materialization.
- **C11** — engine finds banked for the tracker (not blockers, worked
  around): (i) `[?def]` / callable names refuse a `?` suffix
  (predicate-style names like `admitted?` do not parse) — surprising
  vs the guide's naming freedom, undocumented; (ii) module-lane
  debugging of data trees carrying `cx:*` names is hampered by the
  E210 authoring refusal (correct for authored source, but there is no
  blessed way to CONSTRUCT such a test fixture in pure CX).
- **C12** (wave 2) — `security.md` §2 specifies an *allowed
  executables* constraint for the `subprocess` capability and
  `CapSet` carries the `exec_allow` field, but nothing populates or
  enforces it: `main.v` parses a `=`-scope only for `net`, and
  `cap_guard('subprocess', name)` checks the boolean alone. So
  DR-2a's "executable allowlist `["dot"]`, the constraint field used
  as designed" is HALF available today — the capability is
  all-or-nothing. Recorded, not worked around: the module's argv is a
  literal `"dot"`, so wiring the constraint later narrows the grant
  with no change to the renderer. Spec-vs-engine gap, follow-up filed.
- **C13** (wave 2) — the ast.md §4 projection CONFLATES a directive
  with a same-named value image: `<cx:str>` is emitted both for a
  string literal and for a `[?str]` directive, `<cx:map>` for both a
  map literal and `[?map]`. A consumer that must know which (the DOT
  walk does — V emitted a node for the directive and nothing for the
  literal) cannot recover it from the tag, and asking the grammar
  registry gets it WRONG: `str` is a registry name, so every string
  literal rendered as a spurious `[?str]` node. Caught by the
  pre-cutover DOT goldens. Fixed structurally rather than by
  heuristic: the seam marks directive/for-comp elements `cx-node=` on
  the INJECTED image (not on the §4 wire projection), which also let
  the registry injection be removed entirely. The §4 projection's own
  ambiguity stands as a spec finding.
- **C14** (wave 2) — a capability denial is an err VALUE, and binding
  it in a `[?let]` PROPAGATES railway-style (#853). The dot-less
  envelope was therefore unreachable by construction: withholding
  `subprocess` blew up the render instead of degrading it. Gate 9,
  which runs with no capabilities granted, caught it. The hop is now
  coalesced with `[?else]` to an internal sentinel before binding.
  Generalizable lesson for any "try an effect, fall back" shape in CX:
  `[?let]` is the wrong instrument; coalesce first.

---

## Wave-2 execution record (this session)

Scope per DR-9a: DOT emission, the SVG/PNG metadata splices, the PNG
CRC-32 and chunk construction, both dot-less envelopes, and the
graphviz hop move to CX; `shell_dot` / `import_os_execute` are
DELETED. `vcx/code/diagram.v` now holds no renderer logic at all —
only the format-string surface and dispatch to the seam — and no
longer imports `os`.

### Mini-rulings (DR-8 adjudications)

**DRW2-1 — `cx diagram --format=svg|png` grants `subprocess` itself.**
After DR-2a the graphviz hop is capability-charged, but the `cx
diagram` subcommand parses no capability flags, so the shipped
behavior (`--format=svg` produces a real graphviz SVG on a machine
with `dot`) would have silently become the 1×1 envelope. DR-8's
default-winner rule forbids that inside a port. Adjudication: the
subcommand exists to produce a rendered diagram, so requesting a
graphviz format IS the request to run `dot`; the grant is made at that
surface. Mermaid stays capability-free. Every OTHER caller must grant
explicitly and otherwise gets the envelope. The alternative — demand a
second `--allow-subprocess` flag — is a deliberate UX change and is
named here so it can be flipped by ruling rather than by drift.

**DRW2-2 — the malformed-SVG splice is PRESERVED.**
`inject_svg_metadata` splices after the FIRST `>` in the document. On
real graphviz output that is the end of the `<?xml …?>` declaration,
so the metadata block lands before the `<!DOCTYPE>` and outside the
root element: the shipped SVG is not well-formed XML. Verified live
against graphviz 14.1.3. The bit-for-bit bar keeps it (the port
reproduces it exactly, byte-verified); the defect is recorded here
with a follow-up rather than repaired inside a port that must show
zero movement. Round-trip is unaffected — the extractor scans for
`<cx:source` anywhere.

### The wave-2 instrument

graphviz's own output is version- and font-dependent and is NOT
goldenable across machines, so the corpus
`vcx/tests/testdata/diagram_vector_golden/` pins the DETERMINISTIC
halves, captured from the unmodified V code BEFORE the cutover: the
DOT text for all 20 supported fixtures, both dot-less envelopes, and
both splices applied to FIXED inputs. `diagram_vector_golden_test.v`
is hermetic (never spawns `dot`, needs no capability) and adds
known-vector pins for the CX CRC-32. The live end-to-end graphviz hop
stays gate 9's job, and gate 9 now pins BOTH roads explicitly: the
graphviz path (capability granted in the harness, so the lane keeps
the coverage it always had) and the dot-less path (capability
withheld — the envelope must still round-trip).

Verified live beyond the goldens: the CX SVG for viz-020 is
byte-identical to the V algorithm applied to the same graphviz output,
and the CX PNG carries a valid `tEXt` chunk after IHDR with a
zlib-verified CRC whose payload round-trips to the exact source.

### Gate results (wave 2)

diagram_vector_golden OK · diagram_mermaid_golden OK (120/120, still
bit-for-bit after the cutover) · diagram_completeness_gate OK ·
diagram_bench_gate OK · code_diagram_roundtrip OK (both roads) ·
stdlib_umbrella OK · eval_semantics_umbrella OK — the last one caught
`render-svg`/`render-png` declaring `impure` while reaching no
engine-classified impure callee (the `run-dot` indirection hid
`process-run` from the one-level classifier); fixed by inlining the
gated call into both entry points, which is also the honest shape.

---

## Wave-1 implementation record (landed this session)

**What moved to CX** (`stdlib/diagram.cx`, bundled as
`cx-stdlib/diagram`, 45th frozen module): the whole Mermaid reference
path — admission (CXER0281), dialect pick, the sequenceDiagram stub,
all per-family flowchart emitters with functional state threading
(id counter + channel registry as an element accumulator), the
expr-label twins with detail rungs/attr chips/truncation, the escape
set, the `%%cx:%%` marker — plus the reverse-parse extractors for ALL
THREE formats (Mermaid marker, SVG `<cx:source>`, PNG tEXt chunk walk
over `cx-stdlib/bytes`). The sealed DR-4a rules table is
`[$diagram:rules]`.

**What V was deleted** (`vcx/code/diagram.v`, 1,661 → ~390 lines):
`render_mermaid`/`render_mermaid_with_detail`, `MermaidState` and all
node/edge builders, `pick_mermaid_dialect`/`is_top_level_temporal`/
`uses_temporal_directive`, every `mmd_*` emitter, `expr_label`/
`expr_label_raw`/`attr_chips`/`fn_capsule_label`/`fn_extract`/
`fn_param_names`/`channel_node_for`, `mmd_sequence`, and all three
`extract_*_source` extractors; `renderable_directives` lost its dead
`try` entry (DRW1-2) and now feeds ONLY the not-yet-cut SVG/PNG
admission (deleted at wave 2). What remains V: DOT emit, `shell_dot`/
`import_os_execute`, envelopes, SVG/PNG splice — the named wave-2
remainder.

**New V (invocation seam only, zero text production):**
`vcx/code/diagram_cx_seam.v` — the direct §4-image lift
(`diagram_lower`, per DRW1-1 + C10), the `[?eval]`-context-style
driver with a per-process cached module env (mutex-guarded, the
error_hooks voidptr-global pattern), err-value → EvalError mapping,
and the completeness gate's two probes (`diagram_rules_value`,
`diagram_admitted`).

**The DR-8 instrument:** `vcx/tools/regen_diagram_golden` captured
120 goldens (20 supported program-viz fixtures + 20 synthetic pins,
× 3 detail rungs) from the UNMODIFIED V renderer BEFORE the cutover;
`vcx/tests/diagram_mermaid_golden_test.v` asserts byte equality —
**120/120 bit-for-bit** on the CX renderer. ZERO golden movement:
gate-9 round-trip (mermaid+svg+png, 20 fixtures each) green, the
CXER0281 error fixture green, playground gate untouched.

**DR-5 gate:** `vcx/tests/diagram_completeness_gate_test.v` — all four
clauses green; red-on-synthetic-drift PROVEN at landing (pipe row
removed from the spec table → clause (i) red naming `pipe`; restored →
green).

**DR-6 gate + measurements (2026-08-20, reference machine):**
`vcx/tests/diagram_bench_gate_test.v` asserts a 200-node Mermaid
render ≤ 25ms warm; measured best-of-5 ≈ 12-18ms (cold ≈ 32ms incl.
module load; small render ≈ 0.6ms). The letter's proposed ≤ 5s
corpus budget is dominated by the graphviz spawns of the un-cut
SVG/PNG half (≈ 10s with `dot` on PATH) — re-posed at wave 2 with the
`subprocess(dot)` seam (recorded in diagram.md §7), not asserted
against a number the port does not control.

**Spec:** `spec/03-approved/std-lib/diagram.md` NEW (module surface,
sealed table, completeness clauses, the §4 normative byte rules from
consult finding C3, envelope contract, DR-11 rungs, identity posture,
measured budgets); code.md §10.1.1 trued (renderer-as-CX sentence now
names the module; `code.txt`→`code.cxd` per DRW1-7; completeness-gate
cross-reference per DR-5) + §10.1.2 pipe row (DRW1-3); std-lib README
§3 row; stdlib umbrella canary 44→45. DRW1-4's nested class carries
`fn` beside `http-client` (same shipped contract: emitter without
top-level admission).
