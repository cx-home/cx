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
