# CX Roadmap

This document is CX's living, public roadmap. It tracks what's
landing in the next release, what's planned for later, and what is
deliberately *not* on the roadmap.

**The next tag is v0.8.0.** v0.8.0 is the API/format-stability
boundary: from v0.8.0 onward through 1.0, no breaking changes to the
public surface (C ABI, binding APIs, wire formats, spec-normative
grammar). The "v0.8.0 — LOCKED" section below is the live scope.
"v0.9.0 — planned" and "v1.0" describe the post-v0.8.0 horizon.

**Released history (frozen):**

- **v0.6.0** — tagged. API/format-stability boundary originally drafted
  here; that role moved to v0.8.0 once the v0.7.x line shipped as
  proof-of-concept.
- **v0.7.0 → v0.7.5** — proof-of-concept (superseded 2026-05-20).
  The cxpath / cxquery / XQuery-4.0-parity surface specced for the
  v0.7.0 "CX is one language" scope
  turned out to be structurally incomplete: normative
  specs carried TBDs, tests passed by reduction (covering only the
  implemented subset), and `cx:merge` shipped with material defects.
  The cxpath / cxquery V implementation is deleted in v0.8.0; the
  specs remain as historical artifacts only.
- **v0.7.6** — skipped (per backlog `d-2026-05-22-04`). The unified
  pattern/query/transform scope drafted for the v0.7.6 line
  was absorbed into v0.8.0. Its design framing (CX as code,
  error-code namespace expansion, Tier-1 binding cut) carried
  forward; the §11.6 sixteen-gate framing was superseded by the
  v0.8.0 forty-two-gate release rubric in
  [`spec/v0_8_0_status.md`](spec/v0_8_0_status.md).

Headline v0.7.x scope (carried forward into v0.8.0 framing):

- collection literals (sequence / array / map).
- CX database direction (deferred lane).
- "CX is one language" v0.7.0 scope (POC-retired).
- self-host module + extension interface.
- WASM distribution target.
- unified pattern/query/transform language (carried into v0.8.0).

---

## v0.8.0 — LOCKED (in development)

Branch: `v0.8.0-dev`. v0.7.6 skipped per backlog `d-2026-05-22-04`. 42
§11.6 release gates block tag; see [`spec/v0_8_0_status.md`](spec/v0_8_0_status.md)
for live state. Drafted [`RELEASE_NOTES_v0.8.0.md`](RELEASE_NOTES_v0.8.0.md)
is the source of truth for shipped surface.

**Scope theme.** The "data + code" unification release: CXPath becomes
a first-class value kind, `[?match]` learns multi-arm dispatch,
`[?modify]` introduces pure-functional updates with structural
sharing, a module system (`[?lib]` / `[?def]` / `[?const]` / `cx.lock`)
lands with bundled `cx-stdlib`, atom joins the scalar kinds, and the
playground gets formal Tree + Graph views.

**Ratified surface (10 features):**

- CXPath as first-class value kind (XPath 3.1 aligned, 12 axes, sigil-only comparison).
- `[?match]` multi-arm dispatch (`:case` / `:when` / `:else`; first-match-wins; scalar literal + wildcard patterns).
- `[?modify]` pure-functional updates over CXPath focus + 11-action vocabulary; pipeline-composable.
- Structural sharing for `[?modify]` (spine-copy only; `O(depth)` heap; gate 30.5 perf basis).
- `programs` → `code` mechanical rename across spec / V module path / C ABI / fixtures / wasm exports.
- Atom scalar kind (`:NAME` literals, type-strict, name-equality, disjoint hash domain).
- `[?def]` module-level static functions (no closure, no overload, order-independent, optional type annotations + `:pure`/`:impure` modifier).
- `[?lib]` module loading (file / registered / HTTPS) + `cx.lock` lockfile (SHA-384/512 SRI) + `[?const]` + `:scope` visibility.
- `[expr]` general predicate with `$_` context binding, `$_position` / `$_last`, `:bind NAME` peer-modifier.
- Playground Tree View + Graph View (ERD for data, CFG for code; bidirectional selection bridge; new `cx_code_diagram` + `cx_code_tree` C ABI).

**Tier-1 bindings.** V / Python / Go / Rust. TypeScript / Java / C# /
Ruby / Kotlin / Swift archived to `lang/_archived/` per the module-loading
scope and backlog `d-2026-05-22-03`. Restoration is opt-in once Layer-1
stabilizes.

**Surface state.** Document selection uses `//path` (CXPath value) +
`[?for]` (pattern-generator). ABI identifiers follow the
`programs` → `code` rename (`cx_code_*`). Doc-view surface follows the
formal Tree + Graph views.

**Bundled stdlib.** `cx-stdlib` ships with the binary — 14 sub-packages:
strings / json / http / re / time / math / io / bytes / format / path /
log / hash / env / test.

**Effort estimate.** ~150–230 focused sessions to tag (per
[`spec/v0_8_0_status.md`](spec/v0_8_0_status.md) summary table).

---

## v0.9.0 — planned (post-v0.8.0 horizon)

The v0.9.0 tag follows v0.8.0 burn-in. Scope is provisional until
v0.8.0 ships; the items below are the load-bearing candidates that
already have committed design context.

- **Phase 2.x structural-graft completion** — finish the v0.8.0
  carry-overs tracked under task #71. The `[?def]` / `[?lib]` /
  `[?modify]` evaluators reached MVP for v0.8.0; the remaining
  Phase 2.16 structural-body migration (replace verbatim source
  with subtree) and the Phase 2.22 purity-checker AST-walk upgrade
  land here, plus module-loader integration of `check_all`.
- **CX database direction** — the OLAP / index / manifest lane
  (the deferred CX-database direction).
  v0.8.0 leaves CXCol as a hashable wire format; v0.9.0 either
  commits to DataFusion-wrap + Parquet + arena allocator or
  renames the surface. Decision required before any user-facing
  database vocabulary appears in the spec.
- **Function-module ecosystem extension** — `cx-stdlib` ships at
  v0.8.0 with 14 sub-packages. v0.9.0 opens the user-installable
  module trajectory documented under "Post-v0.8.0" below:
  `convert` / `random` / `csv` / `crypto` / `archive` / `validate`
  / `inspect` / `prof` / `html` / `dom`. Loader is governed by
  the `[?lib]` module-loading surface — no new ABI required.
- **Concurrency primitives** — `jobs:` (async / parallel evaluation),
  `proc:` (subprocess spawning), `web:` (optional HTTP server).
  Requires substantive design covering evaluator-state isolation
  and determinism. Pre-conditioned on the function-module loader
  being battle-tested.
- **Additional binding tiers** — restore TypeScript / Java / C# /
  Ruby / Kotlin / Swift bindings (archived in v0.8.0) once
  Layer-1/Layer-2 surface is stable. Tier-2 catch-up runs once;
  community-driven restoration acceptable.

## v1.0 — quality + audit horizon

- **External security audit** — third-party review of V core
  parser, C ABI, and binding FFI shims. Anchors the
  format/API stability claim.
- **CXStore database layer** (if v0.9.0 commits to that direction)
  — Database / Index / Full-text modules comparable to BaseX-as-
  a-database. Per the v1.0+ open question on CX-database direction.
- **CI matrix** — GitHub Actions running `make test` on multiple
  OS/arch combinations per PR with per-binding regression gating.

---

## Historical scope (v0.6.0 era — shipped or superseded)

> **Note:** The sections from here down are preserved as historical
> record of the v0.6.0 / v0.7.x roadmap. The live v0.8.0 scope is
> the "v0.8.0 — LOCKED" section above and
> [`spec/v0_8_0_status.md`](spec/v0_8_0_status.md). Many items here
> shipped during v0.6.0; others were superseded by later ADRs.

### Now — v0.6.0 era

Closing the audit, raising the bar to a level that survives external
review.

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
 `DataTable.cols`; spec [`table-api.md`](spec/misc/table-api.md) updated
 with new property names (`cols`, `col_count`, `iter_cols`); examples
 + CHEATSHEET + FAQ rewritten to use the actual `:table[<cols>]<rows>`
 grammar (the `[columns ...] [rows ...]` wrapper form they previously
 showed was never supported by the parser). Wire format unchanged.
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

### CX code 1.0 — CX Language evaluator (release blocker, replaces shape engine)

- **CX code 1.0 evaluator** at V core (`vcx/cx/cxl.v`) per
 the CX program design and `spec/eval.md`. Pulled into v0.6.0 (2026-05-10 amendment;
 was v0.7.0) when the shape engine was superseded — CX code is now the only
 output-shape mechanism. Seven EvalDirectives
 (`[?if]`, `[?for]`, `[?with]`, `[?cond]`, `[?include]`, `[?def]`,
 `[?use]`) plus `[?=EXPR]` interpolation, frozen filter set,
 target-aware auto-escape, `cx eval` / `cx render` subcommands.
- **Grammar v3.5 ast_bin wire format (v5 bump)** carrying
 `InterpolationNode`, `EvalDirectiveNode`, and `Attribute.body`
 tail — required for parsed CX code to round-trip across the
 C ABI. Tier 1 (V/Python/Go) gated; Tier 2/3 decoder rollout
 required in the same release.
- **C ABI surface** at capability bit 28 — `cx_code_eval`,
 `cx_code_eval_with_len`, `cx_code_eval_streaming` go from W012
 stubs to fully implemented. Per `spec/abi.md §2.16`.
- **Conformance fixtures** at `conformance/eval.txt` — per-directive, composition, whitespace, escaping,
 error-path, schema-validated CX code.
- **Per-binding native evaluators** (9 bindings × ~2k LOC each)
 V is the reference; per-binding evaluators must
 produce byte-identical output for every conformance fixture.
- **`cx eval` / `cx render` CLI subcommands**.
- **Worked examples** at `examples/cx/` covering the
 pattern set originally designed for (rename,
 reshape, lift, drop, alphabetize) plus CX code-native cases (HTML
 card render, Markdown report, CX-to-CX transform). Demonstrates
 that the use cases are served without a second engine.

Total: ~7 weeks focused work ( §Implementation notes),
parallelizable across the Tier-1 binding work. Replaces the ~2–3
month shape engine scope.

### Conversion shape control — superseded by CX code (2026-05-10)

 (declarative `.cxsh` shape engine) was originally targeted
here. As of 2026-05-10 it is **superseded by — CX code**;
CX code 1.0 covers the entire output-shape use case (CX → JSON / YAML /
TOML / XML / HTML / CSV / Markdown / arbitrary text) via a single
expression-language evaluator. CX code 1.0 lands in v0.6.0 (pulled
forward from v0.7.0) per the §Amendment 2026-05-10.

The original use cases (rename, reshape, lift, drop,
alphabetize) are served by canonical CX code idioms in `spec/eval.md §8`
(worked examples) and `examples/cx/`. Computation (filter, group,
aggregate, sort) — which could not do — is served by CX code
3.1's FLWOR + arrow operator at v0.9.0+.

CX code 1.0 itself is now a v0.6.0 scope item; see the "CX code 1.0
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
 (id-018..020). Include-time ID merging (D3) is contracted in
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
 `cx hash`. Strictly additive — no existing CX or wire format changes.

### Internationalization

- **`cx:lang` attribute** formalized as a first-class language tag
 (BCP 47 values), with documented inheritance rules through child
 elements (matches XML's `xml:lang` semantics).
- **Unicode normalization policy** documented (current implementation
 passes input through unchanged; we make that normative, or specify
 NFC).
- **Bidirectional text handling** rule documented.

### Tabular API surface

- **Public Table API across all 10 bindings.** `spec/misc/table-api.md`
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

### Post-v0.8.0 — function-module ecosystem (extending cx-stdlib)

v0.8.0 ships the `cx-stdlib` bundled package
with 14 sub-packages: **strings / json / http / re / time / math /
io / bytes / format / path / log / hash / env / test**. That
covers the load-bearing BaseX-class surface (file I/O via `io` +
`path`, HTTP client via `http`, JSON via `json`, hashing via
`hash`, etc.) as a single tag.

Post-v0.8.0 work extends the function-module ecosystem with
**user-installable modules** loaded through the same
`[?lib]`/`cx.lock` mechanism (no new ABI; the module-loading surface
governs the loader). Candidate modules in rough priority order:

1. **`convert`** — base64, hex, byte/string conversions
   (currently partially in `bytes`).
2. **`random`** — UUIDs, RNG distributions (gaussian, uniform).
3. **`csv`** — round-tripping the delimited surface as a module
   (v0.6.0 ships the C ABI; module wrap is the post-v0.8.0 piece).
4. **`crypto`** — encrypt / decrypt / sign / verify.
5. **`archive`** / **`zip`** / **`bin`** — file-format and
   binary-data manipulation.
6. **`validate`** — wrap CXS validation in module-namespaced API.
7. **`inspect`** — runtime introspection (program AST, captured
   bindings, evaluator state).
8. **`prof`** — profiling helpers (timers, allocation counters).
9. **`html`** — input parsing (cx already emits HTML via the
   conversion surface).
10. **`dom`** — DOM-ish helpers for HTML / XML tree walking
    layered on CXPath.
11. **`xslt`** — XSLT engine wrap, deferred until a concrete
    consumer surfaces.

These ship through their own ADRs as standalone modules rather
than a single-cut release tag — the v0.8.0 stability boundary
means new function-module surface lands additively without
breaking the bundled stdlib contract.

### v0.9.0+ — concurrency and parallel processing (separate ADR)

14. **`jobs:` module** — async / background / parallel evaluation.
    Load-bearing for the "large-scale highly parallel data processing
    systems" pitch. Requires substantive ADR covering evaluator-
    state isolation, result collection, error propagation,
    determinism / byte-identity preservation under parallelism.
15. **`proc:` module** — subprocess spawning.
16. **`web:` module** — possible HTTP server framework if cx grows
    that ambition (parallel to BaseX RESTXQ).

### v1.0+ — open question (CX-database direction)

17. **Cx-native database layer** — possible storage / indexing /
    query-optimization layer comparable to BaseX-as-a-database.
    Explicitly *possible but not committed*. Would unlock the
    Database / Index / Full-text modules from BaseX's catalog. Its
    own major design conversation.

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

CX code 1.0 fixes surfaced during v0.6.0 RC doc work (2026-05-12):

- **CX code `?for` iteration newlines** — body-slot whitespace handling
 collapses iteration boundaries; output of `[?for x :in seq :return
 row\n]` is concatenated on one line instead of one row per line.
 Workaround: emit explicit separators (`,`/`|`/`;`) and post-process,
 or use the per-binding `Table` API which emits CSV/TSV/PSV with
 proper row separators. Fix: extend the `[?-` / `-]` whitespace-control
 markers to iteration slot endings, and decide on a per-iteration
 default (preserve trailing newline vs. consume it).
- **CX code-substituted cells inside `:table` blocks** — the `:table`
 row validator runs at parse time over the slot text, so `[result
 :table[a b c] [?for x :in seq :return [?= x/a] [?= x/b] [?= x/c]
 ]]` parses as 1-cell-per-row (the unsubstituted `[?= …]` looks
 like one cell). Fix: defer table-row validation to post-evaluation
 when the row source contains directives.
- **`?for` variable name `e` collides with scientific-notation
 parsing** — `[?for e :in //emp :return [?= e/@name]]` binds the
 variable but the CXPath lookup `e/@name` returns empty. Names that
 don't start with a single `e` work fine. Fix: CXPath name lexer
 needs to disambiguate `e` (identifier) from `1e10` (number)
 properly; an identifier followed by `/` or `[` is never scientific
 notation.

### v0.7.0 — POC, superseded 2026-05-20

> **Status note.** The v0.7.0 scope below was originally specced by
> the "CX is one language" v0.7.0 scope
> and tracked in the v0.7.0 status doc (since deleted).
> As of 2026-05-20, with the unified pattern/query/transform scope,
> the cxpath / cxquery / XQuery-4.0-parity
> portion of that scope is **retired as proof-of-concept**: the
> implementation was structurally incomplete, tests passed by
> reduction, and `cx:merge` shipped with material defects.
> CX code replaces the entire surface at v0.7.6 (see top of this
> document). Items in the list below that are independent of
> cxpath/cxquery (Arrow+Parquet, reproducible builds, fuzz harness,
> `cx:lang`, comparative benchmarks) carry forward into v0.7.6 / v0.8.0
> on their own merits and are not POC.

Historical v0.7.0 scope (now superseded for the query/transform
items; carried forward for the rest):

- ~~**Full XQuery 4.0 / XPath 4.0 parity**~~ — superseded by CX code.
  The cxpath / cxquery V implementation is deleted as
  part of v0.7.6 work.
- ~~**CXPath axes**~~ — superseded; CX patterns replace axis syntax.
- **Arrow + Parquet** — carried forward to v0.7.6 with binding parity
  across the Tier-1 bindings (V + Python + Go).
- ~~**Streaming evaluator**~~ — superseded by CX code `[?for :stream]`
  comprehension.
- **`cx:lang` formalization + inherited scope** — carried forward.
- **Comparative benchmarks** — carried forward; CX code-shape workloads
  added.
- **Reproducible builds** — carried forward.
- **Fuzz-testing harness** — carried forward.

**Binding architecture note (revised 2026-05-20):** v0.7.6 keeps the
single-evaluator model. V is the reference implementation; Python and
Go are the Tier-1 bindings gating the §11.6 conformance suite. Rust
and TypeScript stay in scope but pass the suite asynchronously per
the v0.7.0 binding-tier cut.

### v0.7.5 — libcx-wasm + live playground (WASM distribution point release)

WASM as a v0.7.x point-release distribution target — additive
infrastructure, no language-semantics change. Single goal: replace
the playground's canned-corpus fallback with live in-browser
evaluation against a `libcx.wasm` build. Decisions locked for the
WASM distribution target:

- **Build path: V-emit-C → emcc** (not V's native `-b wasm`
  backend, which is experimental for the browser target).
- **Memory model: V `-prealloc` arena** (not Boehm WASM port).
  Default arena 64 MiB; `cxlib.setArenaSize` + `cxlib.reset`
  exposed for memory control. The "no free" trade-off is
  inapplicable to the per-call playground use case.
- **Regex: explicit error** at v0.7.5 (`cx-err:CXER0100
  regex-unavailable-in-wasm`). RE2 is C++ and not linked into
  the WASM build at this tag. JS RegExp shim filed as a
  follow-up if demand surfaces.
- **C ABI surface: subset.** 16 symbols (the playground-load-
  bearing set, including `cx_eval`, all CX-input format
  converters, `cx_canonical`, `cx_hash`, plus two new WASM-only
  symbols: `cx_wasm_set_arena_size`, `cx_wasm_reset`). Input-side
  format converters (`cx_xml_to_*` etc.), `cx_validate_*`,
  `cx_arrow_*`, streaming — all v0.7.x / v0.8.x follow-ups.
- **JS wrapper: hand-written, ~80 LOC, no runtime deps.**
  `dist/wasm/cxlib.js` exposes 11 public methods over linear-
  memory marshalling.
- **Playground wiring: same UI hook.** `refreshOutputs` routes
  through `cxlib.eval` when `window.cxlib` is present; canned-
  corpus path retained as offline fallback. Run button un-
  disabled; PLANNED notice replaced with a "Powered by
  libcx.wasm" footer.
- **`make build-wasm`** new top-level target. Opt-in: default
  `make build` does not require emscripten.
- **Parity contract: byte-identical to native `cx`** across the
  non-regex subset of the v0.7.0 conformance corpus (38/42
  fixtures).
- **Frozen-binding re-promotion runs in parallel.** C# / Java /
  Kotlin / Ruby / Swift catch-up is
  its own v0.7.x sequence on its own timeline; v0.7.5 does not
  bundle that work.
- **v0.8.0 BaseX-modules scope untouched.** v0.7.5 is additive
  infrastructure that lets v0.8.0 land as its planned single-cut
  capability tag without dilution.

### v0.7.x — perf + closure pass on v0.7.0 deferrals

Items deferred from v0.7.0 to a v0.7.x point release. Streaming-
evaluator perf work landed v0.7.0 at ~340 MB/s on the comparable
bench corpus — about 17% under the comparable JSON benchmark on
the same workload — crossing the 300 MB/s Y6 target; the 500 MB/s
stretch target is pushed here. See session memory
`project_y6_streaming_perf.md` for the current optimisation stack
and next-lever ordering.

- **Parse-once / eval-many API** — `cx_eval_streaming_from_ast_bin`
  (or equivalent on the V surface: `eval_code_from_doc(prog_doc,
  input_doc, sink)`) so callers can amortise parse cost across many
  evaluations. Today `eval_code_streaming(input, program, sink)`
  re-parses both inputs on every call (~1 ms per invocation on the
  medium fixture; `bin_to_doc` from ast_bin is ~2× faster than
  `parse` from CX text). On the streaming bench this is ~1.5% of
  total time at N≥5000 (parse is amortised), so it's a public-API
  shape win — not a headline-throughput win. The real payoff is
  server-style workloads with short evals where parse dominates,
  and as load-bearing infra for cached `CompiledProgram` reuse.
- **strings.Builder.str() bypass on flush** — `flush_stream`
  memdups the chunk via `memdup_noscan` even when the sink is a
  byte-level consumer. Either widen the V `CXLStreamSink` to a
  bytes variant or route flushes through `write_ptr`. Estimated
  5–10%.
- **`-prealloc` as an opt-in libcx build flag** — adds ~14% over
  Boehm on the medium fixture. Trade-off: no `free`, ever — suited
  to CLI / one-shot batch workloads, not long-running daemons.
  Ship as a build-time variant rather than the default.
- **ast_bin / bin_to_doc parse benchmark** — add to `vcx/bench/bench.v`
  alongside the existing `parse (CX → Document)` line so the
  parse-once value proposition is reproducibly measured at every
  release.
- **JIT-compile hot `?for` bodies** — the CompiledBody parallel-
  arrays form is bytecode-shaped already; a cranelift / V-codegen
  backend that emits native code for the inner emit loop would
  yield an estimated 3–5× on top of the current stack. Big project;
  warrants its own ADR.

### v1.0 — quality + audit milestone

- **External security audit** — engagement scoped to V core parser,
 C ABI, and binding FFI shims. Anchors the format/API stability
 claim that v0.6.0 makes.

### Original "Later" items

- **Parquet import/export** for tabular data (depends on schema).
- **Schema-aware editor support** (LSP completion, hover docs from
 schema, error squigglies).
- **Annual binding audit (2027 edition)** — same shape as the 2026-05
 audit, applied to whatever evolved since. Cadence item, not a
 release blocker.
- **`cx build` — single-binary embed-and-launch (v0.8.0 candidate).**
 Static-link libcx into a small V launcher that embeds the program
 source and calls `code.eval_code` at startup; emits a
 single self-contained executable. AST evaluator stays inside —
 perf == `cx eval`. No codegen, no static-CX-subset question, no
 new ABI; one CLI subcommand wrapping the existing C ABI. Fits
 v0.8.0's stability scope as a tooling win; falls back to v0.9.0
 if it doesn't land cleanly inside burn-in. Bigger AOT/JIT
 trajectories (whole-program codegen, per-function `.so` JIT,
 native LLVM codegen) are deferred — they need their own ADR
 defining the static CX subset and are unscoped for now.
- **Native module loader (V `-shared` + dlopen)** — split cx's own
 stdlib modules (`cx:`, `log:`, future `crypto:` / `regex:` /
 `http:` / ...) out of the libcx core into per-module `.so`s
 loaded on first use, behind a stable C ABI. Cx ships a slim
 core + opt-in module bundles; stdlib bugs can be hot-fixed
 without recompiling libcx; modules version independently. The
 same loader and ABI then host third-party function modules
 (see BaseX-class function-module ecosystem, v0.8.0 line), so
 the ecosystem inherits a *dogfooded* loader rather than one
 designed in the abstract. Open design questions: ABI versioning
 across cx releases, signing / capabilities for untrusted
 modules, per-platform build matrix (mac / linux / win × arch).
 Sub-uses unlocked by the same loader:
 - **Schema validators and lint rules as compiled `.so`** — CXLS
 rules + lint checks compiled V → `.so` and dlopened, faster
 than walking schema/lint AST at validate time; lets users ship
 custom lint plugins.
 - **`v -live` for `cx run --live foo.cx`** — once per-function
 `.so` JIT exists (a separate deferred trajectory beyond the
 `cx build` embed-and-launch entry above), V's `[live]`
 machinery gives free file-watcher hot reload: edit a `[?fn]`
 body, save, in-flight `[?service]` picks up the new code
 without restart. Tightens the playground / `cx diagram` dev
 loop. Design boundary is what counts as a live-able change
 (`[?fn]` body yes; `[?def]` of state no, prompts restart).
 - **WASM caveat** — wasm has no dlopen, so the design forks:
 desktop/server gets dynamic loading + slim core; wasm ships
 the full static cut. Module manifest needs a "wasm-safe" bit
 and the build pipeline produces both flavors.

> **The "CX code 3.1 / CX code 4.0" staging block previously in this section
> is superseded** by the "CX is one language" v0.7.0 scope
> (settled 2026-05-17). v0.7.0 ships XQuery 4.0 + XPath 4.0
> expression parity in a single cut (per
> [`spec/xquery_40_parity.md`](spec/xquery_40_parity.md)); v0.8.0
> ships the BaseX-class function-module ecosystem;
> v0.9.0+ adds concurrency primitives behind separate design work; v1.0+
> is the open question on cx-native database. The "CXPath axes at
> v0.8.0" line above is similarly superseded — axes move to v0.7.0.
> Historical text preserved below for provenance:

- **CX code 3.1 and 4.0 — post-v0.6.0** .
 CX code 1.0 ships in v0.6.0 (see "Next — v0.6.0" above); CX code 3.1 and
 4.0 are post-v0.6.0:
 - **CX release v0.8.0 — CXPath axes.** Adds parent / ancestor /
 following-sibling / preceding-sibling (deferred in CXPath v1).
 CX code picks up upward navigation automatically with no CX code version
 bump. **(Superseded — moves to v0.7.0.)**
 - **CX code 3.1 — CX release v0.9.0+.** XQuery 3.1 feature equivalence.
 Adds `[?let]`, `[?fn]`, `[?match]`, `[?try]` EvalNames; full
 FLWOR on `[?for]` with `:let` / `:where` / `:order` / `:return`
 (XQuery 3.1-aligned `order` spelling); user-defined functions;
 maps and arrays as CXDM value kinds; arrow operator `=>`; aggregate
 filters; group-by; try/catch. **(Superseded — folded into the v0.7.0
 single-cut.)**
 - **CX code 4.0 — CX release v1.x+ (target).** XQuery 4.0 feature
 equivalence once XQuery 4.0 stabilizes — pipeline operator `|>`,
 partial function application, member maps, enhanced types,
 additional collection operations.

 The data-code symbiosis XML+XQuery have, in CX flavor: CX code queries
 CX code; programs inspect programs; one toolchain.

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
 Rationale: CXCol v1 binary already covers the "compact wire
 format" need, and adding three more binary formats explodes the
 conversion matrix without buying anything CXCol doesn't already
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
