# Rulings 2026-08-20 — diagram port WAVE 3 + the caller-facing entry (#889)

## DRW3-1 — the wave-3 scope, as ruled

**Status:** RULED (owner "a", 2026-08-20, on issue #889's scope-addition
comment). This file is the ruling-store entry for the third and final
wave of the DR port (`spec/02-working/diagram_renderer_cx.md`, DR-1…DR-11
all at (a), ledger/rulings_2026_08_20_diagram_renderer.md). Waves 1 and 2
are recorded there; nothing here reopens them.

Two deliverables, both pre-cut:

**A. The playground renderer moves to CX.** DR-1(a) named
`vcx/code/code_diagram.v` — the CFG / ERD / SEQ emitter behind
`cx code-diagram` and the wasm export `cx_code_diagram_with_level` — as
the second renderer and the third wave. DR-9(a) is cutover-first: the CX
implementation becomes THE implementation in the landing that introduces
it and the V emitter is DELETED in the same landing. No permanent twin.
DR-8(a) governs: bit-for-bit against the shipped output, every
spec-reality divergence adjudicated as a named mini-ruling BEFORE the
cutover, zero golden movement the expected verdict. DR-5(a)'s
bidirectional completeness gate extends to this renderer's rule table.

**B. The caller-facing entry point.** Quoting the owner's scope addition
verbatim:

> SCOPE ADDITION (owner ruling 2026-08-20, 'a'): this pass also gives
> cx-stdlib/diagram a CALLER-FACING entry point. […] the module ships
> twelve public functions, but render-mermaid/render-dot expect the
> engine-injected program image (DRW1-1 ingress), and neither [$cx:parse]
> nor [$cx:ast] produces it — both fail live with a shape error. So a
> frozen stdlib module is, in practice, uncallable from a CX program.
> DR-7 deliberately deferred a public parse surface 'until a live
> consumer appears' — the owner asking for it IS that consumer.
> Add: [$diagram:of-source $src $format] (format = mermaid|dot|svg|png;
> detail per DR-11) doing the program lift internally, so one call
> renders a diagram of CX source. It must produce byte-identical output
> to the CLI path for the same input (pin it), and the CLI should route
> through it rather than keeping a second lift — one path, no twin.

The gap is verified live at this head before any work
(`[?lib 'cx-stdlib/diagram' as=dg]` + `[$dg:render-mermaid [$cx:parse $src] $src "compact"]`
→ `[err code=cx-err:CXER0100 message='name(): expected single element
argument, got empty or multi-item sequence']`).

Out of scope by the same ruling: the SVG/PNG capability posture stays
exactly as DRW2-1 left it (where `subprocess` is granted is #890's open
question, not this wave's).

---

## Mini-rulings (DR-8 adjudications — recorded BEFORE the behavior moves)

**DRW3-2 — the parser-workaround text patches are PORTED, not retired.**
DR-1(a)'s prose hoped the playground emitter's source-text rewrites
(`patch_paths`, `patch_match_arms`, letter finding 7) could be "retired
against the then-current parser instead of ported". Measured at this
head, both halves of that hope fail:

- the bracket-shaped match-arm pattern is STILL refused —
  `[?match 12 [case [< 13] "small"] [else "big"]]` →
  `CXER0100: parse: expected pattern head (Name, *, **, :Type, or $bind),
  got '<'`. The `[case [< 13] …]` → `[case '< 13' …]` rewrite is still
  load-bearing: without it the whole source sinks to the text-level
  `flowchart TD` placeholder.
- the absolute-path rewrite is no longer needed for PARSEABILITY
  (`[?let [= $x /root/item] $x]` parses today; it fails later at eval for
  want of `$doc`), but it is OUTPUT-VISIBLE: the shipped diagram labels
  the binding `[= $x //root/item]`, with the doubled slash the rewrite
  introduced. Retiring it would move a golden inside a port whose bar is
  zero movement.

**Adjudication:** both patches move to CX verbatim (pure text→text work,
which is the port's proper subject) and the shipped bytes are preserved.
Retiring the path rewrite is a deliberate, output-moving change; it is
named here so it can be flipped by a ruling rather than by drift, and
filed as a follow-up.

**DRW3-3 — the wave-3 ingress: one native primitive, two image modes.**
This renderer's ingress is NOT the wave-1 one. `code_diagram_with_level`
takes SOURCE TEXT, strips `[?cx …]` PIs, applies the DRW3-2 patches,
parses, and falls back to a text-level classification when the parse
fails — i.e. the text work brackets the parse on BOTH sides. Keeping the
pre-parse text work in V would leave the port half-done (it is pure
text→text, exactly what DR-2a's cut line assigns to CX); doing it in CX
requires CX to reach a parse.

**Adjudication:** the engine contributes ONE native stdlib primitive,
`[$diagram-program-image $src $mode]` (`vcx/code/stdlib_diagram.v`,
chained into `stdlib_builtin` like every other module primitive), which
parses source text and returns the lifted program image, or an `[err]`
value the CX side coalesces with `[?else]` (the C14 lesson). Two modes:

- `"ref"` — the DRW1-1 image exactly as the wave-1/2 seam builds it
  (`diagram_lower`), for the reference renderer and for `of-source`;
- `"code"` — the same image plus the DRW3-4 `[?def]` expansion, for the
  playground renderer.

This is DR-7(a)'s engine-injected image with the injection point moved
from the seam to a primitive the module itself calls — the load-bearing
clause ("the renderer does not re-parse; the engine hands it the image")
is preserved, and it is what makes the owner's `of-source` possible at
all. The primitive produces no diagram text.

**DRW3-4 — `[?def]` raw-source is expanded ENGINE-SIDE.** The parser
captures `[?def …]` as a single labeled `raw-source` STRING slot and
defers the structural parse to eval time (`cx.parse_def`); the V emitter
therefore called `cx.parse_def` + `cx.parse_program` from inside the
renderer. A pure CX renderer cannot. **Adjudication:** the `"code"`
image mode expands the def in the lift — the directive gains a
`<cx:def-image name="NAME">` child carrying the lowered body — so the
renderer reads structure, never text. The `"ref"` mode is untouched, so
no wave-1/2 golden can move.

**DRW3-5 — `cx_code_diagram_with_level` keeps its ABI shape.** The
playground reaches this renderer through the wasm export
`cx_code_diagram_with_level(source, source_len, level) → &char`
(cabi.v). The port changes what the export computes with, not its
signature, its level encoding, or its error-string prefixes. No re-cut,
no ABI-surface re-bless (`tools/libcx-abi-gate.sh`, #888).

**DRW3-6 — the structural path node.** The §4 projection hatches a bare
CXPath expression to its SOURCE TEXT (`<cx:expr>`), but this renderer's
label for a path is the steps-joined form its
`render_path_or_fallback` produced: leading marker + step NAMES, with
axes and predicates dropped (`/users/user[1]`, after the DRW3-2 rewrite
`//users/user[1]`, labels as `//users/user` — fixture
cfg-009-modify-three-actions). Text cannot become that label without
re-parsing, and the renderer must not parse. **Adjudication:** the
`"code"` image lift re-reads the hatch's own text with the engine's
parser (bytes the engine itself emitted) and, when it IS a path
expression, replaces the hatch with
`<cx:path leading=…><cx:pstep name=…/>…`. Anything else the hatch
covers (dynamic element names, operator-with-attrs) keeps the text
form. Engine-side, `"code"` mode only; the `"ref"` image is untouched.

**DRW3-7 — `of-source` is declared IMPURE.** Two of its four formats
(`svg`, `png`) reach the graphviz hop, which is capability-charged
(DR-2a); `mermaid` and `dot` perform no effect. A split surface (a pure
entry for the text formats, an impure one for the vector formats) was
considered and refused: the owner asked for ONE call taking a format,
and a caller that wants a provably-pure render can still reach
`render-mermaid` / `render-dot` with an image. The conservative
annotation is honest — the purity checker accepts `impure`
unconditionally and it is the callers of the vector formats who must be
impure anyway.

**DRW3-8 — the frozen public surface, and why the wave-2 internals stay
public.** `guide-check` requires an `[fn-doc]` with a runnable example
for every `scope=public` def, which put the question "what is actually
this module's API?" on the table. Ruled: the public surface is the two
entry points (`of-source`, `code-diagram`), the render verbs
(`render-mermaid` / `render-dot` / `render-svg` / `render-png`), the
three extractors, the two sealed tables and their lookups (`rules`,
`admitted`, `code-rules`, `code-class`), the two dot-less envelopes,
the two metadata splices, and `crc32` — eighteen functions, each now
carrying an fn-doc whose example runs. The five that read as internals
(the envelopes, the splices, `crc32`) are NOT privatised: each is a
NAMED normative clause of this module's spec (§6 envelope contract,
§8.1 splices) and each is a probe of the wave-2 hermetic vector gate
(`diagram_vector_golden_test.v` reaches them through the seam, which
can only call public defs). Privatising them would have bought a
smaller surface by deleting gate coverage — refused. Everything else in
the module (≈240 defs) is module-private.

**DRW3-9 — `[err]`-named image elements: recorded, not papered over.**
A CX source containing an `[err …]` element (e.g.
`[?select [case [timeout 50ms] [err code="timeout"]]]`) lifts to an
image element NAMED `err` — which the evaluator treats as an error
VALUE, so handing that node to any def or reading it in a dynamic-child
position propagates instead of rendering. The SEQ port hardened the
readers the corpus reaches (child navigation, `[?let]` binding,
sequence membership and splices are safe; calls and dynamic children
are not), which is what makes fixture seq-004 byte-identical.
**Residual, unreached by any golden and NOT worked around:** an `err`
element in a position where an emitter must hand it to a def (e.g.
`[?worker name="w" [err code="x"]]`, which V rendered as
`Note over w : [err]`) still propagates. The honest fixes are a
sequence-carrier convention for every node parameter (~40 defs) or an
engine-side rename in the injected image; both are surface decisions,
so they are POSED rather than invented here — see the owner question in
the wave-3 report. The CFG half has the same exposure.

**DRW3-10 — the CLI's refusal text is preserved.** `code_diagram_with_level`
surfaces a module `[err …]` as a PLAIN V error carrying the module's
message verbatim, not as an `EvalError` (whose `msg()` would prefix a
wire code). `cx code-diagram` therefore still prints
`cx code-diagram: [?def] parse: …` exactly as the V emitter's
`error('[?def] parse: …')` did. The wasm export's own parse-error wire
strings are likewise unchanged: `cx_code_diagram` keeps its diagnostic
parse (the lift now happens inside the module), so its
`CXER0100:parse: …` text is byte-identical.

---

## Wave-3 execution record (this session)

### The DR-8 instrument

`vcx/tools/regen_code_diagram_golden` captured **264 goldens** — 88
sources × 3 levels — from the UNMODIFIED V emitter BEFORE the cutover:
the 46 graph-view fixtures of `conformance/code_diagram.cxd` plus 42
synthetic pins chosen by reading the emitter's arms (every SEQ inner
directive including the whole await family and all six resilience
policies; the CFG shapes the fixtures skip — nested `[?let]`, an
over-cap basic block, a >30-char match arm, an unnamed `[?for]`,
`[?if]` without else, cross-def calls; the ERD edges — every scalar
kind, non-identifier entity names, FK inference, deep name collisions,
the DOCUMENT suppression step-back; and the parse-failure fallbacks
including both DRW3-2 patches). The conformance runner compares
node-SETS and edge-SETS, so it cannot see line order, node-id minting
order, or label bytes; this corpus does. Each id carries its
`<id>.source` sidecar (this renderer embeds no source marker).
`vcx/tests/code_diagram_golden_test.v` asserts byte equality:
**264/264 bit-for-bit** on the CX renderer, through the shipped
`code.code_diagram_with_level` entry.

Zero movement elsewhere: the wave-1 mermaid corpus is 120/120
unchanged, and it now renders THROUGH the new `of-source` path (the
byte-identity proof for deliverable B).

### What moved to CX

`stdlib/diagram.cx` §9 (≈1,950 lines added): the pre-parse text layer
(`strip_cx_pis` + both DRW3-2 patches, scanning by structural jumps
rather than per-codepoint — the CX per-character cost makes a byte loop
untenable, and every delimiter is ASCII so the jump is observationally
identical); the image readers and the auto-detect classification
(including the text-level fallbacks); the `short_label` twin; the whole
CFG family (basic blocks with the 10-line cap, `[?if]`/`[?match]`/
`[?for]`/`[?modify]`/`[?let]` emitters, def sub-graphs with their id
scopes and self-recursion back-edges, min and full layers with the
twelve colour classes, cross-def call edges, yield sentinels and
binding circles); the whole ERD family (containment walk, cardinality
promotion, row dedup, min, and the full level's DOCUMENT root, FK
inference, value enumeration and occurrence badges); and the whole SEQ
family (actor lanes, activation-depth arrow minting, channel aliasing,
`alt`/`else` frames, resilience notes, async lanes, the full level's
INPUT/OUTPUT lanes and binding notes). The two sealed tables (§1 for
the reference renderer, §9.0 for this one) are the only classification
sets in the module.

### What V was deleted

`vcx/code/code_diagram.v`: **3,219 → 69 lines**. Gone: `patch_paths`,
`patch_match_arms`, `rewrite_match_inner`, `split_case_head`,
`find_matching_close`, `strip_cx_pis`, `debug_patch_for_diagram_parse`,
both text-level classifiers, `program_is_code` /
`program_is_sequence_shape` / `node_is_sequence_trigger` /
`is_data_statement` / `top_level_statements`, `CFGState` and every CFG
emitter, `def_name_and_body` / `def_name_min_extract`, the ERD structs
and walker with `erd_entity_name` / `scalar_type_str` /
`is_scalar_child`, `short_label` / `render_path_or_fallback`,
`SeqState` and every SEQ emitter, `collect_callees` / `collect_yields`
/ `collect_binding_intros`, `sanitize_id`, and `mermaid_escape`. What
remains is the level vocabulary and three thin entry points.

New V (invocation and ingress only, zero text production):
`vcx/code/stdlib_diagram.v` (the `diagram-program-image` primitive,
chained into `stdlib_builtin`) and, in `diagram_cx_seam.v`,
`diagram_lower_code` + `dgc_def_image` + `dgc_path_image` (the DRW3-4 /
DRW3-6 image additions), the `code_diagram_cx` driver, the
`render_of_source_cx` driver, and the two completeness-gate probes.

### One path, no twin (deliverable B)

`render_diagram` lost its redundant `prog` parameter and now routes
through `[$diagram:of-source]`, so `cx diagram`, `cx eval --target=…`,
the wasm `cx_code_diagram` export, the golden gates and the bench gate
all enter the module through the caller-facing entry. Verified live:
`[$diagram:of-source SRC "mermaid"]` and
`cx diagram --format=mermaid FILE` produce the same bytes, and the
120-golden wave-1 corpus is unmoved through the new route.

### The DR-5 gate, extended

`vcx/tests/code_diagram_completeness_gate_test.v` — six clauses over
the wave-3 table (§10.2 of the module spec is the independent side):
every row is a live registry directive; the declared classes are
exactly the classes the emitter implements and the live dispatch is
total over the registry; every row is corpus-exercised (with the await
family's named emitter twins); the ERD type rows are exactly the §4
scalar tags; an untabled directive takes the declared generic paths;
and the spec tables ↔ the module table are SET-EQUAL both ways.

**Drift-redness PROVEN at landing:** deleting the
`[seq directive=cancel class=cancel …]` row reddened clause (vi)
(`spec §10.2 rows with no module row: ['cancel']`) AND moved the
`pin-seq-cancel` goldens (`Note over w : [?cancel]` instead of
`w -x job : cancel`); restoring it returned both to green. Note which
clause caught it: clauses (i)-(v) stay self-consistent under a matched
deletion precisely BECAUSE the emitters read the table, which is why
the spec side of clause (vi) is load-bearing.

### The two guide breaks (fixed in this pass, same token)

1. **`guide-check`** was red: twelve public defs had no `[fn-doc]`.
   Ruled per DRW3-8 and fixed by documenting the real surface — every
   public def now carries an fn-doc with an example that runs, and the
   examples are BACKED by a new conformance corpus,
   `conformance/stdlib/diagram.cxd` (18 cases, generated FROM the
   fn-docs so they cannot drift, green in the stdlib fixture lane).
   `guide-check` → OK, 60 modules.
2. **`make guide`** was red: `guide_build.cx` data-parsed each stdlib
   module whole (`[$cx:parse]`) to find its doc blocks, and
   `diagram.cx` is the first module using program-only syntax the data
   reader is RIGHT to refuse (a bare singleton sequence in
   call-argument position; a node-valued attribute — E211/D2). The
   module was not contorted. The SCANNER was fixed: `module-docs` now
   reads the verbatim doc SPANS out of `[$cx:ast]` and parses each span
   on its own — the technique the sibling gate
   `scripts/gen_guide/stdlib_docs_check.cx` already used, so the two
   cannot disagree about a module. `guide_build` → RC 0, and
   `docs/guide/lib-diagram.html` renders all eighteen functions.
   Regression fence: `stdlib_docs_check.cx` gained clause (6) — every
   bundled module must project at least one doc span, so module #47
   fails at the gate rather than silently taking the guide down.
