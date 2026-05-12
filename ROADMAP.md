# CX Roadmap

This document is CX's living, public roadmap. It tracks what's
landing in the next release, what's planned for later, and what is
deliberately *not* on the roadmap.

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

- **`cx diff`** — semantic diff CLI subcommand. Design committed:
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
 lands.
### Format-completeness

- ✅ **Delimited (CSV / TSV / PSV / arbitrary single-char) —
 reasonable, well-defined conversion.** Closed at V core
 2026-05-08 (Phase 7.67):
 spec rewrite [`spec/conversions.md §8`](spec/conversions.md) (well-defined-not-lossless framing,
 shape-detected flattening D2 — `:table` / repeated-row /
 dotted-path; RFC 4180 default emit D3; multi-quote parse D4 —
 no/single/double quote with `""` / `''` doubling and six
 universal escape sequences; auto-typing D5 with per-column type
 narrowing; arbitrary single-char delimiters D6); V core impl
 `vcx/cx/delimited.v`; C ABI symbols
 `cx_to_delimited` / `cx_from_delimited` plus
 `cx_{to,from}_{csv,tsv,psv}` aliases plus data_bin one-shots
 `cx_{csv,tsv,psv}_to_data_bin` / `cx_data_bin_to_{csv,tsv,psv}`
 at capability bit 6 (cx_features now `0xd3ffff`); 14-case
 [conformance/delimited.txt](conformance/delimited.txt). 9-binding
 rollout shipped 2026-05-08 (Phase 7.68): each of Python, Go, Rust,
 TypeScript, Java, Kotlin, Swift, C#, Ruby exposes the 8 text-text
 entry points (`to_csv` / `from_csv` / `to_tsv` / `from_tsv` /
 `to_psv` / `from_psv` / `to_delimited(src, delim)` /
 `from_delimited(src, delim)` in language-idiomatic spelling) plus
 the 6 binary one-shots (`csv_to_data_bin` / `tsv_to_data_bin` /
 `psv_to_data_bin` / `data_bin_to_csv` / `data_bin_to_tsv` /
 `data_bin_to_psv`); 12-case delimited test per binding mirroring
 `vcx/tests/v34_delimited_test.v` byte-exact.
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
 
 and listed under "Next" below.
- **Comment-style consistency** across docs: `# line` for one-liners,
 `[- block ]` for multi-token or multi-line.

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

Schema design begins by weighing options: lifted-from-XSD,
JSON-Schema-compatible, hand-rolled minimal. The design choice is
recorded before implementation.

### CXL 1.0 — CX Language evaluator (release blocker, replaces shape engine)

- **CXL 1.0 evaluator** at V core (`vcx/cx/cxl.v`) per
 the CXL design and `spec/cxl.md`. Pulled into v0.6.0 (2026-05-10 amendment;
 was v0.7.0) when the shape engine was superseded — CXL is now the only
 output-shape mechanism. Seven EvalDirectives
 (`[?if]`, `[?for]`, `[?with]`, `[?cond]`, `[?include]`, `[?def]`,
 `[?use]`) plus `[?=EXPR]` interpolation, frozen filter set,
 target-aware auto-escape, `cx eval` / `cx render` subcommands.
- **Grammar v3.5 ast_bin wire format (v5 bump)** carrying
 `InterpolationNode`, `EvalDirectiveNode`, and `Attribute.body`
 tail — required for parsed CXL programs to round-trip across the
 C ABI. Tier 1 (V/Python/Go) gated; Tier 2/3 decoder rollout
 required in the same release.
- **C ABI surface** at capability bit 28 — `cx_eval_cxl`,
 `cx_eval_cxl_with_len`, `cx_eval_cxl_streaming` go from W012
 stubs to fully implemented. Per `spec/abi.md §2.16`.
- **Conformance fixtures** at `conformance/cxl.txt` — per-directive, composition, whitespace, escaping,
 error-path, schema-validated CXL.
- **Per-binding native evaluators** (9 bindings × ~2k LOC each)
 V is the reference; per-binding evaluators must
 produce byte-identical output for every conformance fixture.
- **`cx eval` / `cx render` CLI subcommands**.
- **Worked examples** at `examples/cxl/` covering the
 pattern set originally designed for (rename,
 reshape, lift, drop, alphabetize) plus CXL-native cases (HTML
 card render, Markdown report, CX-to-CX transform). Demonstrates
 that the use cases are served without a second engine.

Total: ~7 weeks focused work ( §Implementation notes),
parallelizable across the Tier-1 binding work. Replaces the ~2–3
month shape engine scope.

### Conversion shape control — superseded by CXL (2026-05-10)

 (declarative `.cxsh` shape engine) was originally targeted
here. As of 2026-05-10 it is **superseded by — CXL**;
CXL 1.0 covers the entire output-shape use case (CX → JSON / YAML /
TOML / XML / HTML / CSV / Markdown / arbitrary text) via a single
expression-language evaluator. CXL 1.0 lands in v0.6.0 (pulled
forward from v0.7.0) per the §Amendment 2026-05-10.

The original use cases (rename, reshape, lift, drop,
alphabetize) are served by canonical CXL idioms in `spec/cxl.md §8`
(worked examples) and `examples/cxl/`. Computation (filter, group,
aggregate, sort) — which could not do — is served by CXL
3.1's FLWOR + arrow operator at v0.9.0+.

CXL 1.0 itself is now a v0.6.0 scope item; see the "CXL 1.0
evaluator" entry under "Now — v0.6.0 scope" below.

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
 mechanism. V core v0 shipped 2026-05-08 (Phase 7.61): `[node #my-id ...]`
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
 order and `is_ref` values to track D7; lossless
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
- **Include resolution semantics formally specified.** User-facing
 spec [`spec/include.md`](spec/include.md) committed
 2026-05-08: caller-supplied include root, current-file-relative
 path resolution, URL-scheme + traversal-escape rejection,
 include-stack cycle detection, default `max_include_depth=8`,
 element-level splice (XMLDecl/DOCTYPE/other CXDirectives not
 inlined), parse → include → namespace → ID pass ordering, error
 chain reporting. Implementation lands six new C ABI entry points
 (`cx_<fmt>_to_data_bin_with_include_root` × 6), a
 depth-options variant, a new capability bit, a
 `cx --include-root=<dir>` CLI flag, and per-binding
 `include_root` parameters. Closes the include-time ID-merging
 pre-requisite that contracted (see
 [`spec/identity.md §2.1`](spec/identity.md)).
- ✅ **Namespaces (XML xmlns equivalent).** Closed 2026-05-08
 across Phases 7.57 (V core), 7.58 (9-binding accessors), 7.59
 (CXPath ns-aware + canonical-form D6 + MIGRATION). Spec
 [`spec/namespaces.md`](spec/namespaces.md);
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
 builds (currently flagged in the release process §6).
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

- **Tree-sitter grammar v0.6 update.** Audit confirms
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
 to `cx fmt`); update completion list to v0.6 types.
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
 env, post, vcore; 365 lines) all on v0.5-era patterns — zero
 v0.6 coverage. Scope: refresh existing files to v0.6 idioms
 where helpful; add new examples covering the missing shapes
 (sized types, numeric underscores, boolean sigils, `:table`
 block, logfmt mode, namespace bearer, leading-zero-now-string
 demo, line-comment usage). Every file in
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

### v0.6.1 — closure pass on v0.6.0 deferrals

Items deferred from v0.6.0 to v0.6.1:

- **Schema validator Tier 2/3 catchup** — native validate() wrappers
 in Rust / C# / Java / TypeScript / Kotlin / Swift / Ruby / V-cffi
 (Tier 1 ships at v0.6.0; Tier 2/3 access via C ABI today).
- **Streaming write JSON / YAML / TOML / MD emits** — pending output-
 shape decision; current bindings return W009 stub.
- **Streaming write Tier-3 binding fan-out** (CX + XML emits).
- **Include resolution** — V core `resolve_includes` pass + 6 C ABI
 entry points + `cx --include-root=<dir>` flag + per-binding
 `include_root` parameter + `conformance/include.txt`.
- **Null vs empty vs missing binding conformance** — per-binding
 equality conformance suite verifying the four-way distinction
 documented in `spec/policies.md §2.6`.
- **Tree-sitter / LSP / Neovim full closure** — parser.c regen +
 test corpus + URL-attribute parse fix; LSP hover + document
 symbols + semantic tokens; nvim-lspconfig PR submission.
- **Concurrent test suite** — N-worker × class-S symbol mix + race
 detection per `spec/abi.md §1.5.4`.
- **Microbenchmark SLA validation + CI regression gate** —
 `bench_report.py` validates against `spec/governance.md §6`
 budgets with 10% regression threshold.
- **Third-party conformance certification process + public test
 corpus** — `cx-conformance-v0.6.0.zip` packaged on release page;
 `governance.md §8` operational details documented.

CXL 1.0 fixes surfaced during v0.6.0 RC doc work (2026-05-12):

- **CXL `?for` iteration newlines** — body-slot whitespace handling
 collapses iteration boundaries; output of `[?for x :in seq :return
 row\n]` is concatenated on one line instead of one row per line.
 Workaround: emit explicit separators (`,`/`|`/`;`) and post-process,
 or use the per-binding `Table` API which emits CSV/TSV/PSV with
 proper row separators. Fix: extend the `[?-` / `-]` whitespace-control
 markers to iteration slot endings, and decide on a per-iteration
 default (preserve trailing newline vs. consume it).
- **CXL-substituted cells inside `:table` blocks** — the `:table`
 row validator runs at parse time over the slot text, so `[result
 :table[a b c] [?for x :in seq :return [?= x/a] [?= x/b] [?= x/c]
 ]]` parses as 1-cell-per-row (the unsubstituted `[?= …]` looks
 like one cell). Fix: defer table-row validation to post-evaluation
 when the row source contains CXL directives.
- **`?for` variable name `e` collides with scientific-notation
 parsing** — `[?for e :in //emp :return [?= e/@name]]` binds the
 variable but the CXPath lookup `e/@name` returns empty. Names that
 don't start with a single `e` work fine. Fix: CXPath name lexer
 needs to disambiguate `e` (identifier) from `1e10` (number)
 properly; an identifier followed by `/` or `[` is never scientific
 notation.

### v0.7.0 — depth + ecosystem

- **CXL per-binding native evaluators** — ~2k LOC × 9 bindings, byte-
 identical to V reference. Bindings access CXL via C ABI today;
 native evaluators are a performance optimization.
- **`cx:lang` formalization + inherited scope** — V core + 10
 bindings; design committed in `spec/i18n.md §1`.
- **Comparative benchmarks** vs JSON / YAML / TOML / XML (text) +
 MessagePack / CBOR (binary).
- **Reproducible builds** — independent SHA-256 match against
 published `dist/SHA256SUMS.txt`.
- **Fuzz-testing harness** — continuous fuzzing of V core parser
 and C ABI surfaces.
- **CXPath axes** — parent / ancestor / following-sibling /
 preceding-sibling (deferred in CXPath v1).

### v1.0 — quality + audit milestone

- **External security audit** — engagement scoped to V core parser,
 C ABI, and binding FFI shims. Anchors the format/API stability
 claim that v0.6.0 makes.
- **CXL 4.0** — XQuery 4.0 feature equivalence once XQuery 4.0
 stabilizes.

### Original "Later" items

- **Parquet import/export** for tabular data (depends on schema).
- **Schema-aware editor support** (LSP completion, hover docs from
 schema, error squigglies).
- **Annual binding audit (2027 edition)** — same shape as the 2026-05
 audit, applied to whatever evolved since. Cadence item, not a
 release blocker.
- **CXL 3.1 and 4.0 — post-v0.6.0** .
 CXL 1.0 ships in v0.6.0 (see "Next — v0.6.0" above); CXL 3.1 and
 4.0 are post-v0.6.0:
 - **CX release v0.8.0 — CXPath axes.** Adds parent / ancestor /
 following-sibling / preceding-sibling (deferred in CXPath v1).
 CXL picks up upward navigation automatically with no CXL version
 bump.
 - **CXL 3.1 — CX release v0.9.0+.** XQuery 3.1 feature equivalence.
 Adds `[?let]`, `[?fn]`, `[?match]`, `[?try]` EvalNames; full
 FLWOR on `[?for]` with `:let` / `:where` / `:order` / `:return`
 (XQuery 3.1-aligned `order` spelling); user-defined functions;
 maps and arrays as CXDM value kinds; arrow operator `=>`; aggregate
 filters; group-by; try/catch.
 - **CXL 4.0 — CX release v1.x+ (target).** XQuery 4.0 feature
 equivalence once XQuery 4.0 stabilizes — pipeline operator `|>`,
 partial function application, member maps, enhanced types,
 additional collection operations.

 The data-code symbiosis XML+XQuery have, in CX flavor: CXL queries
 CXL; programs inspect programs; one toolchain.

---

## Deliberate non-features

These are *not* on the roadmap. They are decisions, not gaps. Each
gets a one-paragraph summary below.

- **External entity references** (XML's `&foo;` resolved against
 DTD declarations or external resources). Rationale: this is the
 attack surface behind XXE and billion-laughs. CX's
 `[?cx include=...]` covers the legitimate use case (file inclusion)
 without the attack vectors.
- **`xml:space="preserve"` equivalent.** Rationale:
 token context in CX is unambiguous — quoted strings preserve,
 unquoted bodies normalize, raw-text blocks (`[# ... #]`) preserve
 verbatim. Adding a per-element override would create three ways
 to do the same thing.
- **Multiple character encodings** — see
 . Rationale: CX
 is UTF-8 only. The only encodings still used in greenfield
 deployments are UTF-8 and (rarely) UTF-16; the cost of multi-
 encoding parsers is large and the benefit is approximately zero.
- **MessagePack / CBOR / Protobuf as import-export targets** — see
 .
 Rationale: CXDB v1 binary already covers the "compact wire
 format" need, and adding three more binary formats explodes the
 conversion matrix without buying anything CXDB doesn't already
 give. Third parties can write codecs against `cx_to_data_bin` if
 they want them.
- **DOCTYPE-as-active-declaration** — see
 .
 Rationale: CX parses DOCTYPE for XML round-trip, but it has no
 semantic effect on parsing. Same family as external entities —
 DTD-driven validation is XML's legacy; schema validation will be
 the supported path.

---

## Updating this document

- When a "Now" or "Next" item ships, mark it ✅ and remove from this file.
- When a new capability becomes a known need, add a ROADMAP entry
 under the appropriate scope (Now / Next / Later).
- When a capability is rejected, add an entry under "Deliberate
 non-features" with rationale.

The roadmap is the surface adopters check to know what's coming. Keep
it honest; keep it short.
