# CX Roadmap

This document is CX's living, public roadmap. It tracks what's
landing in the next release, what's planned for later, and what is
deliberately *not* on the roadmap.

The release gate for any tagged version is the [readiness
rubric](spec/readiness_rubric.md): no `⚠` entries at tag time. Each
release ships with an adoption review (`docs/adoption_review_<version>.md`)
that records how every row of the rubric was classified for that
version and where the gaps are tracked.

**The next tag is v0.6.0.** v0.6.0 is the API/format-stability
boundary: from v0.6.0 onward through 1.0, no breaking changes to the
public surface (C ABI, binding APIs, wire formats, spec-normative
grammar). The "Now" and "Next" scopes below both feed v0.6.0 — Now is
the work in flight on the active branch, Next is the larger scope that
follows but ships under the same v0.6.0 tag. "Later" is post-v0.6.0
work targeting subsequent releases.

---

## Now — current branch (toward v0.6.0)

Closing the audit, raising the bar to a level that survives external
review. Items here are in flight or imminent on the active branch.

### Tooling completion

- **`cx diff`** — semantic diff CLI subcommand. Design committed in
  [`spec/decisions/0012-cx-diff.md`](spec/decisions/0012-cx-diff.md):
  unified / json / summary output formats; exit codes 0 (equivalent)
  / 1 (differs) / 2 (error) aligned with `diff(1)`; walks the strict
  canonical form (`spec/canonical.md §1.2`) so reformat / comment /
  attribute-order / anchor-expansion changes produce empty diff;
  JSON output uses CXPath for the `path` field. C ABI bit 14.
  Remaining: spec section, V core impl, CLI subcommand, 9-binding
  rollout, conformance fixtures, microbench (~5–6 weeks).
- ✅ **`cx lint`** — style + correctness warnings. Closed
  2026-05-08 across Phases 7.49 (V core + CLI), 7.50 (9-binding
  wrappers), 7.52 (LSP diagnostics), 7.54 (initial 9 conformance
  fixtures), 7.60 (L001/L002 source-text passes, `[?cx lint-disable
  =...]` / `lint-enable=...` directive scoping, `.cxlint.cx`
  config discovery + severity overrides, 12 additional fixtures).
  All 5 check IDs implemented (L001 comment-style, L002 type-
  annotation form, L003 unused-anchor, L004 dangling-alias, L005
  leading-zero-pattern). Distinct from `cx fmt` (lint warns, fmt
  fixes). Schema-violation checks will layer on once schema
  (ADR 0009) lands. ADR:
  [`spec/decisions/0013-cx-lint.md`](spec/decisions/0013-cx-lint.md).

### Format-completeness

- **Delimited (CSV / TSV / PSV / …) — reasonable, well-defined
  conversion.** Spec at `spec/conversions.md §8` exists but is too
  narrow for real use, and was framed as "lossless within `:table`
  scope" which isn't recoverable: delimited fields are inherently
  string-typed, and type metadata can't be carried in-band without
  breaking plain-CSV consumers. Scope, in order:

  - **ADR** at [`spec/decisions/0001-delimited-conversion.md`](spec/decisions/0001-delimited-conversion.md)
    — landed 2026-05-07. Records the framing change, shape-detected
    flattening (repeated-row + dotted-path + `:table`), RFC 4180
    default emit, multi-style quote parsing on input, escape
    handling, and type recovery via caller-schema → auto-type →
    string fallback.
  - **Spec rewrite of §8** against the ADR. Includes the normative
    tables for emit defaults, parse accept-set, escape sequences,
    lossy properties, and shape-detection rules.
  - **Implementation** at V core (`vcx/cx/csv*.v`), C ABI
    (`cx_to_csv` / `cx_from_csv` already declared in `spec/abi.md`),
    threaded through all 9 bindings with parity-matrix update and
    conformance fixtures.
- ✅ **`columns` → `cols` rename** in the Table API field name —
  landed 2026-05-08 (Phase 7.46). V core `TableData.cols` /
  `DataTable.cols`; spec [`table_api.md`](spec/table_api.md) updated
  with new property names (`cols`, `col_count`, `iter_cols`); examples
  + CHEATSHEET + FAQ rewritten to use the actual `:table[<cols>]<rows>`
  grammar (the `[columns ...] [rows ...]` wrapper form they previously
  showed was never supported by the parser). Migration recorded in
  [`MIGRATION.md §2.5`](MIGRATION.md). Wire format unchanged.
- **Document `[?cx include=...]`** in cheatsheet + tutorial; it
  exists in the parser but is undocumented user-facing.
- **Document anchors / aliases honestly** as merge-only (YAML-style),
  not cross-document references. ID/IDREF is the cross-document
  reference mechanism, designed in
  [`spec/decisions/0003-id-idref.md`](spec/decisions/0003-id-idref.md)
  and listed under "Next" below.
- **Comment-style consistency** across docs: `# line` for one-liners,
  `[- block ]` for multi-token or multi-line.

### Process artifacts (one-time setup, then ongoing)

- **`spec/readiness_rubric.md`** — release gate criterion. Landed.
- **`ROADMAP.md`** — this document. Landed.
- **`docs/adoption_review_<version>.md`** — the version-specific
  review against the rubric. Six-persona evaluation: API integrator,
  config author, data-format engineer, library implementer, docs
  reader, security reviewer. New review per release.
- **`spec/decisions/`** — Architectural Decision Records. One per
  spec-affecting decision (which capabilities are deliberately not
  features, what the include-vs-transclude semantics are, etc.).
  Backfill a starter set as part of the next release.
- **`docs/RELEASE_PROCESS.md` §0.7 gate** — "adoption review for this
  version is committed and signed off."

### Release-hygiene docs (landed 2026-05-08)

- ✅ [`CONTRIBUTING.md`](CONTRIBUTING.md), [`SECURITY.md`](SECURITY.md),
  [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md),
  [`docs/FAQ.md`](docs/FAQ.md), [`LICENSE`](LICENSE) (Apache-2.0).
  Superseded `docs/cx.md` removed.

---

## Next — v0.6.0 production-hardening scope

The capabilities a serious format is expected to provide that CX
doesn't ship yet. These close the largest open gaps from the rubric
and ship as part of v0.6.0 — the API/format-stability boundary.
Scope is intentionally large; v0.6.0 is the release that earns the
"production-ready" framing.

### Schema language and validation (release blocker — largest single item)

Three adoption personas (API integrator, config author at-scale, data-
format engineer) are blocked on this capability. The directive
`[?cx schema=path.cxs]` is already reserved in the grammar at
`spec/grammar.ebnf §418`; existing files using it remain forward-
compatible. Scope:

- **`.cxs` schema language** — minimum-viable schema covering
  element shapes, attribute presence + types, cardinality, basic
  range/enum/pattern constraints. Specified in
  `spec/schema.md` (to be written) before implementation begins.
- **Validation engine in libcx** with diagnostics that include line +
  column and a friendly reason.
- **Schema-driven defaults and coercion** (a missing optional attribute
  with a default fills in; a string-typed value with `:int` schema
  position errors loudly).
- **Per-binding `validate(doc, schema)` API** with consistent
  signatures across all 9 bindings (parity-matrix entry).
- **Schema-aware LSP diagnostics** in `tooling/lsp/`.

Schema design begins with an ADR in `spec/decisions/` weighing
options: lifted-from-XSD, JSON-Schema-compatible, hand-rolled
minimal. The ADR is the gate; implementation follows once the design
choice is recorded and reviewed.

### Conversion shape control

- **CX → JSON output shape directives** so a CX document can specify
  how it serializes to JSON (e.g., to match an external API
  contract). Likely shape: a `[?cx json-shape=...]` directive plus a
  `cx --json --shape <spec>` CLI flag. The exact mechanism needs a
  design doc in `spec/decisions/` before implementation.
- **CX → YAML / TOML / XML shape control** on the same mechanism.
- **Reverse direction** — shape-aware import (JSON → CX with a
  declared shape rather than the deterministic default mapping).

### Data-bin one-shot loaders/dumpers

- **`cx_<fmt>_to_data_bin` × 5** (xml / json / yaml / toml / md)
  and **`cx_data_bin_to_<fmt>` × 5** at the C ABI. Spec
  `abi.md §2.4–2.5` marks these v2-required; V core
  `cabi.v:47` feature-bitmask comment explicitly admits "Not yet
  implemented: bit 5 (data_bin one-shots)." Each is a thin
  composition of existing pieces (`cx_<fmt>_to_ast_bin` +
  AST→data-bin, and the symmetric direction); rollout includes
  binding wrappers and bitmask flip.

### Reference and composition primitives

- ✅ **ID / IDREF cross-document references.** Anchors/aliases
  solve intra-document merge; ID/IDREF is the cross-document
  mechanism. Design ADR
  [`spec/decisions/0003-id-idref.md`](spec/decisions/0003-id-idref.md);
  V core v0 shipped 2026-05-08 (Phase 7.61): `[node #my-id ...]`
  declarations, `attr=@my-id` references at attribute-value
  position, two-pass parse with duplicate-ID and unresolved-
  reference diagnostics, `Document.resolve_id()` and
  `elements_by_id()` public API, CXPath `[#id]` predicate, 9-case
  [`conformance/identity.txt`](conformance/identity.txt). 9-binding
  rollout shipped 2026-05-08 (Phase 7.62): `Element.id` + `Attr.is_ref`
  (language-idiomatic spelling), `Document.resolve_id()` /
  `Document.elements_by_id()` accessors, CX-text emitter for `#id` and
  `name=@id`, ast_bin wire format v2 carries the new fields verbatim
  across V↔binding round-trip, 9-case identity test per binding (all
  9 bindings). XML round-trip shipped 2026-05-08 (Phase 7.63): CX
  `#id` ↔ XML `xml:id` attribute (XML built-in URI ns); `is_ref` attrs
  emit as plain `name="<id>"` on XML output; XML→CX import marks
  matching values as `is_ref`. 5 new conformance cases at
  [`conformance/identity.txt`](conformance/identity.txt) (id-010..014).
  Canonical-form ID renaming shipped 2026-05-08 (Phase 7.64):
  `cx_text_canonical` rewrites declarations to `id-N` in document
  order and `is_ref` values to track per ADR 0003 D7; lossless
  `cx fmt` preserves source spellings. 3 new conformance fixtures
  (id-015..017). C ABI surface shipped 2026-05-08 (Phase 7.65):
  `cx_id_lookup` / `cx_resolve_ref` / `cx_node_id` at capability
  bit 20 (cx_features now `0xd3ffbf`); thin per-binding wrappers
  across all 9 bindings with 3–4-case test per binding;
  `Element.id` and `Attribute.isRef` now serialized in AST-JSON
  output so the symbols return useful payloads. Body-position
  `[ref @id]` form (D1) and MIGRATION entry shipped 2026-05-08
  (Phase 7.66): `Element.body_ref ?string` + parser + emitter +
  validator participation; v0 limitation (V-core only — ast_bin
  wire format does not yet carry it) documented in
  [`spec/identity.md §1.2a`](spec/identity.md). 3 new fixtures
  (id-018..020). [`MIGRATION.md §2.6`](MIGRATION.md) covers all of
  Phases 7.61–7.66. Include-time ID merging (D3) is contracted in
  [`spec/identity.md §2.1`](spec/identity.md) but pending its
  prerequisite — include resolution itself isn't yet implemented;
  tracked separately as the §4 "Include resolution formal spec"
  row.
- **Include resolution semantics formally specified** — what a
  cycle does, what relative paths resolve against, what happens
  to comments and PIs in the included document.
- ✅ **Namespaces (XML xmlns equivalent).** Closed 2026-05-08
  across Phases 7.57 (V core), 7.58 (9-binding accessors), 7.59
  (CXPath ns-aware + canonical-form D6 + MIGRATION). Spec
  [`spec/namespaces.md`](spec/namespaces.md); ADR
  [`spec/decisions/0002-namespaces.md`](spec/decisions/0002-namespaces.md);
  16-case V conformance suite
  [`conformance/namespaces.txt`](conformance/namespaces.txt) (12
  parse/emit + 4 canonical-form); 11-case per-binding namespace
  test in each of the 9 bindings; 9-case CXPath ns suite
  `vcx/tests/ns_cxpath/cxpath_test.v`. CXPath gains namespace-
  aware name tests (prefixed queries resolve via the document's
  xmlns map, first-occurrence wins) plus `local-name()` and
  `namespace-uri()` predicate functions for cross-prefix queries.
  `cx canonical` now sorts xmlns declarations and rewrites prefix
  usage to the lex-smallest in-scope prefix per URI, so
  semantically-equal namespaced documents hash identically under
  `cx hash`. Migration entry at
  [`MIGRATION.md §2.4`](MIGRATION.md). Strictly additive — no
  existing CX or wire format changes.

### Internationalization

- **`cx:lang` attribute** formalized as a first-class language tag
  (BCP 47 values), with documented inheritance rules through child
  elements (matches XML's `xml:lang` semantics).
- **Unicode normalization policy** documented (current implementation
  passes input through unchanged; we make that normative, or specify
  NFC).
- **Bidirectional text handling** rule documented.

### Tabular API surface

- **Public Table API across all 10 bindings.** `spec/table_api.md`
  defines a 17-member API (4 properties + 13 methods spanning
  row/column/cell access, slicing, iteration, and 5 conversions).
  None of it is implemented yet — the internal `TableData` struct
  at `vcx/cx/ast.v:60–79` is not exported through the C ABI, and
  no binding has a `Table` class. Largest single doc-vs-reality
  gap surfaced in the 2026-05 audit. Scope: design the C ABI
  surface (likely a handle-based table object similar to events
  streaming); implement at V core; thread through all 9 bindings
  with parity-matrix entries and conformance fixtures.

### Streaming + scale

- **Streaming write API** — pull-based event stream consumer for
  emit. The read-side `cx_events_open/next/close` API is in place;
  the symmetric write side is the gap. `spec/streaming.md:289–294`
  currently marks it "Deferred" — the deferral is what's being
  closed here. Likely shape: `cx_events_writer_open` /
  `cx_events_writer_emit_<event>` (one per event type) /
  `cx_events_writer_close_get_bytes`.
- **Large-file (multi-GB) benchmark** with documented numbers in
  `spec/governance.md §6`.

### Security + verification

- **Fuzz-testing harness** — both grammar fuzzing (random valid CX
  in, no parser crashes) and roundtrip fuzzing (random CX → format
  → CX preserves data).
- **Comparative benchmarks** vs JSON / YAML / TOML / XML for text,
  vs MessagePack / CBOR for binary. Published in
  `spec/governance.md §6.3`.
- **Microbenchmark suite measuring against published SLA budgets.**
  Audit confirms `bench_report.py` extracts metrics
  (`parse=X.XXX` / `stream=X.XXX` at lines 178–182) but does not
  validate against `governance.md §6` budgets (`loads(1KB) <
  100µs`, `loads(1MB) < 60ms`, `loads(100MB) < 6s`,
  `select(1MB) < 120ms`) and does not enforce the 10% regression
  threshold the spec mandates. Scope: move bench fixtures
  public; add §6-budget validators with pass/fail per binding;
  commit baseline numbers; document measurement methodology
  (host, build flags, warmup, samples, percentiles).
- **CI regression gate against SLA budgets.** Per `governance.md
  §6` the CI gate runs the microbenchmark suite per binding per
  PR; a 10% regression vs baseline blocks merge. Implementation
  follows the public bench fixtures and committed baselines
  above.
- **Reproducible libcx builds** so SHA-256s match across independent
  builds (currently flagged in `docs/RELEASE_PROCESS.md §6`).
  Toolchain pinning, deterministic timestamps, embedded-path
  scrubbing.
- **External security audit.** Engagement with a third-party
  security review firm; scoped to V core parser, C ABI, and the
  binding FFI shims. Findings are addressed in a patch release
  before the audit report is published. Required by 1.0 for the
  production-positioned framing.
- **CI matrix.** GitHub Actions running `make test` on macOS-13,
  macOS-14, ubuntu-22.04, ubuntu-24.04 for every PR. Per-binding
  regression gate so a Python/Rust/etc. failure blocks merge.

### Concurrency & parallelism

- **Thread-safety contract documented per public C ABI function**
  in `spec/abi.md`. Three classes: thread-safe (top-level
  converters like `cx_to_data_bin`), thread-local (handle objects
  like `cx_events_*`), and inherently single-threaded (rare —
  ideally none).
- **Concurrent test suite** at the V core and per binding. Worker-
  pool stress test calling parse/emit on independent inputs;
  race-detector integration where the toolchain supports it
  (Go race, ThreadSanitizer for V/C builds).
- **Per-binding concurrency story** documented in each binding's
  README — Python GIL implications, Go goroutine safety, Rust
  `Send`/`Sync` bounds, Java/Kotlin JVM monitor model, Swift
  actor isolation, C# task safety, Ruby GVL implications.
- **Memory-model contract.** Whether libcx relies on the host
  language's memory model or imposes its own. Likely the former
  (libcx is a stateless converter for top-level calls; handles
  are owned by the caller's thread). Make it normative.
- **Parallel parse / emit benchmarks** showing scaling with
  cores. Required to claim CX scales for production workloads.

### Tooling and ecosystem (1.0 expectations)

- **Tree-sitter grammar v3.4 update.** Audit confirms
  `grammar.js:156–169` lists only v3.3 types and the number lexer
  has no underscore support. Scope: full grammar.js rewrite for
  v3.4 (sized int/float types, `:decimal`, `:bigint`, numeric
  underscores, boolean attribute sigils, line comments, logfmt
  mode, `:table` block, leading-zero-now-string change);
  regenerate `parser.c`; refresh `highlights.scm` for the new
  constructs; smoke-test against GitHub Linguist and Neovim
  consumers. Tree-sitter is the substrate every code editor's
  syntax highlighting flows through; staleness here means every
  adopter sees broken highlighting.
- **LSP minimum capability set.** Audit confirms current LSP
  (`tooling/lsp/out/server.js` v0.1.0) advertises completion only
  and the completion list shows v3.3 types — substantially less
  than a usable minimum. Scope: implement diagnostics (parse
  errors with line/col from `cx` output), hover (type info from
  `:type` annotations and known reserved-attribute descriptions),
  document symbols (element tree as outline), formatting (proxy
  to `cx fmt`); update completion list to v3.4 types.
  Schema-aware completions and validate-on-save layer in once
  schema lands.
- **VSCode extension.** Audit confirms `package.json:9`
  `activationEvents` is empty — extension may not auto-activate.
  Scope: wire `onLanguage:cx` activation; launch LSP on `.cx`
  files; ship installable `.vsix` from VS Code Marketplace; bind
  the v3.4 tree-sitter grammar for default-out-of-the-box
  highlighting.
- **Neovim integration.** Audit confirms `cx.lua:20–26` uses a
  hardcoded LSP path requiring manual install. Scope: replace
  with the standard nvim-lspconfig pattern; provide an example
  `init.lua` snippet adopters drop into their config; resolve
  the LSP binary by `$PATH` lookup or registered server name.
- **Working examples in `examples/`.** Audit confirms 9 .cx
  files (article, books, chapter, config, doc, embedding_test,
  env, post, vcore; 365 lines) all on v3.3-era patterns — zero
  v3.4 coverage. Scope: refresh existing files to v3.4 idioms
  where helpful; add new examples covering the missing shapes
  (sized types, numeric underscores, boolean sigils, `:table`
  block, logfmt mode, namespace bearer post-ADR-0002, leading-
  zero-now-string demo, line-comment usage). Every file in
  `examples/` exits 0 through `cx <file>`. First-impression-
  critical: a clone-and-try adopter who hits a parse error or
  who looks for `:table` and finds no example walks away.

### Third-party conformance

- **Conformance certification process** with operational details:
  the exact command a third party runs against their binding, the
  pass criterion, the version they certify against, the artifact
  they publish. `spec/governance.md §8` outlines the policy; the
  ops detail is the gap.
- **Public test corpus for third-party binding compliance.** A
  packaged subset of `vcx/tests/conformance/` that adopters can
  vendor and run against their own implementation. Format: a
  versioned tarball with input CX files, expected outputs per
  format, and a runner script.

### Format hygiene

- **BOM handling rule** documented and tested.
- **Line-ending policy** documented (CR / LF / CRLF — what's
  preserved, what's normalized, where).
- **Null vs empty vs missing** semantics formalized — what
  `[name]` vs `[name :string]` vs `[name :string '']` vs
  `[name :null]` means.

---

## Later — post-v0.6.0

Capabilities that are real, planned, but not blocking v0.6.0.

- **Parquet import/export** for tabular data (depends on schema).
- **Schema-aware editor support** (LSP completion, hover docs from
  schema, error squigglies).
- **Annual binding audit (2027 edition)** — same shape as the 2026-05
  audit, applied to whatever evolved since. Cadence item, not a
  release blocker.

---

## Deliberate non-features

These are *not* on the roadmap. They are decisions, not gaps. Each
has a full ADR in `spec/decisions/`; the rationale below is a one-
paragraph summary cross-linked to the ADR.

- **External entity references** (XML's `&foo;` resolved against
  DTD declarations or external resources) — see
  [ADR 0004](spec/decisions/0004-external-entity-references.md).
  Rationale: this is the attack surface behind XXE and billion-
  laughs. CX's `[?cx include=...]` covers the legitimate use case
  (file inclusion) without the attack vectors.
- **`xml:space="preserve"` equivalent** — see
  [ADR 0005](spec/decisions/0005-xml-space-preserve.md). Rationale:
  token context in CX is unambiguous — quoted strings preserve,
  unquoted bodies normalize, raw-text blocks (`[# ... #]`) preserve
  verbatim. Adding a per-element override would create three ways
  to do the same thing.
- **Multiple character encodings** — see
  [ADR 0006](spec/decisions/0006-multi-encoding.md). Rationale: CX
  is UTF-8 only. The only encodings still used in greenfield
  deployments are UTF-8 and (rarely) UTF-16; the cost of multi-
  encoding parsers is large and the benefit is approximately zero.
- **MessagePack / CBOR / Protobuf as import-export targets** — see
  [ADR 0007](spec/decisions/0007-binary-format-imports.md).
  Rationale: CXDB v1 binary already covers the "compact wire
  format" need, and adding three more binary formats explodes the
  conversion matrix without buying anything CXDB doesn't already
  give. Third parties can write codecs against `cx_to_data_bin` if
  they want them.
- **DOCTYPE-as-active-declaration** — see
  [ADR 0008](spec/decisions/0008-doctype-as-active-declaration.md).
  Rationale: CX parses DOCTYPE for XML round-trip, but it has no
  semantic effect on parsing. Same family as external entities —
  DTD-driven validation is XML's legacy; schema validation will be
  the supported path.

---

## Updating this document

- When a "Now" item ships, move its row to the rubric (`spec/readiness_rubric.md`) and flip the status to ✅. Remove it from this file.
- When a "Next" item ships, do the same.
- When a new capability becomes a known need, add it to the rubric
  with status `⚠` (release blocker) or `📋` (planned), and add a
  ROADMAP entry under the appropriate scope.
- When a capability is rejected, write an ADR in `spec/decisions/`
  and add an entry under "Deliberate non-features."

The roadmap is the surface adopters check to know what's coming. Keep
it honest; keep it short; keep it tied to the rubric.
