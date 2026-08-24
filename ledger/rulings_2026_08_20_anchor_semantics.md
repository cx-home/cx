# Ruling ANC-1 (2026-08-20) — the Resolved AST is the semantic reading (#877, owner "3a")

The conflict: ast.md's two-AST model says XML emission works from the
Resolved AST (aliases expanded, merges applied); the shipped engine and
conversions.md carry anchors/merges through every lane instead — and the
lanes disagree with each other (XML carries `cx:merge=`, JSON silently
drops the alias, CXPath sees nothing). Meanwhile STRICT CANONICAL already
expands anchors — the document's ADDRESS is computed over the resolved
form — so identity said "the alias IS the copy" while query said "the
alias is nothing". Hash and query disagreed about meaning.

RULED (owner, 3a): **resolution is the semantic reading.** The evaluator,
CXPath, validation, and the LOSSY projections (JSON/YAML/TOML/MD/CSV)
operate on the Resolved AST; the LOSSLESS lanes (`cx fmt`, `--lossless`,
CX round-trip) preserve authored anchors/merges as presentation, and
conversions.md's `cx:merge=` carry is re-scoped to those lanes. ast.md
stands as written and gains the evaluator/lossy-projection rows plus an
implementation-status note. The engine gap (resolve pass before eval and
lossy projection) is #877's re-scoped implementation — post-cut, with
fixtures, real golden movement expected. Docs continue stating shipped
behavior (carried-not-resolved, per the audit landing) until it lands.

## ANC-1 implementation record + ANC-1a (XML lane), 2026-08-20 (#877 landing)

**Landed.** The resolve pass reuses strict canonical's resolver
(`resolve_anchors_doc`, now public as `cx.resolve_document`) at the document
seams:
- `convert_by_name` (vcx/cx/codec.v): every lossy text projection —
  `json`/`yaml`/`toml`/`md` without `--lossless` — resolves after parse,
  before emit (single- and multi-doc).
- `to_delimited` (vcx/cx/delimited.v): csv/tsv/psv always resolve (always
  lossy). conversions.md's delimited table already said "resolved at
  conversion time" — the spec was ahead of the engine; now true.
- `parse_input_doc` (vcx/code/api.v): `$doc` is the semantic reading —
  CXPath over the input counts an alias as its referent and reads
  merge-inherited attrs.
- The pure-data run surface funnels through `convert_by_name` (the eval
  data-fallback), so `cx doc.cx --json` and `--from=cx --to=json` agree.

**ANC-1a — XML is the lossless carry twin.** ast.md's flat "when emitting
XML, the emitter MUST work from the Resolved AST" contradicted
conversions.md's documented `cx:anchor`/`cx:alias`/`cx:merge` carry, and the
implementation matched conversions.md. Ruled toward the bijection pillar
(serialization bijective; atomization-vs-serialization ruling): default XML
emission carries the authored sharing so XML round-trips to the same CX;
*Semantic XML* (ast.md's §Semantic XML flavor) is the resolved rendering for
consumers with no CX reader. ast.md amended accordingly; this trues ast.md to
the OTHER approved spec and the bijection, not to an implementation
shortfall — the lossy lanes got the resolve pass the same day.

**Preserved lanes:** default CX output, XML carry, `--lossless` sidecar
modes, `[$cx:parse]` (the in-program data reading stays structural — it is
the round-trip tool seam; guide_build depends on it).

**Dangling refs:** a dangling alias (and any cycle) REFUSES on lossy lanes —
same contract as strict canonical (no resolved form exists). A dangling
merge is a no-op strip (lint L003 warn), unchanged.

**Gate:** vcx/tests/resolved_projection_test.v (8 cases: three lossy lanes
resolve, three lossless lanes preserve, $doc semantic, dangling-alias
refusal). Specs trued: ast.md (status note now states the landing),
conversions.md (three "dropped" claims → resolved-with-content-preserved),
guide 14-tour §47/48/50 + 03-surfaces §3.3.3/summary-table + 02 §2.5.1 —
every claim live-verified before commit.
