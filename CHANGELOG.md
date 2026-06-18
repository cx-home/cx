# Changelog

All notable changes to CX are recorded here. Per-release deep-dives
live in the top-level `RELEASE_NOTES_v*.md` files; migration
instructions live alongside each release-notes file (e.g.
[`RELEASE_NOTES_v0.8.0.md`](RELEASE_NOTES_v0.8.0.md)).

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
plus the additional [`spec/governance.md §9` versioning rules](spec/governance.md#9-versioning)
for the multi-axis CX project (language version, ABI version, format
version, library version).

## [Unreleased]

## [0.11.0] — 2026-06-18

The agentic-substrate release. Authoritative release-surface document:
[`RELEASE_NOTES_v0.11.0.md`](RELEASE_NOTES_v0.11.0.md). Backward-compatible.
(Changelog entries for 0.9.0–0.10.1 live in their `RELEASE_NOTES_v*.md`.)

### Added

- **`cx-x/` agentic tier** — the Runnable convention + combinators
  (`cx-x/run`), an LLM provider (`cx-x/llm`), MCP client + server
  (`cx-x/mcp`, `cx-x/mcp-server`), and A2A (`cx-x/a2a`, `cx-x/a2a-xap`:
  tasks→journal, messages→bus, DID/VC auth).
- **Stdlib modules** — `did` (`did:key` + `did:web`, base58btc), `vc`
  (verifiable credentials) + `session/attach-did`, `jsonrpc` (JSON-RPC 2.0),
  `jsonschema` (JSON Schema 2020-12, MCP subset).
- **XAP** — real authz-backed PEP; feature augmentation/overlay composition
  + coordination channel; XSP frame codec; DID/VC identity for all actors.

### Changed

- **Uniform lexical scoping (#19 / #22)** — callables resolve free names in
  their defining scope (imported module siblings call each other; `[?const]`
  in a `[?def]` body dereferences).
- **CX decoupled from the V fork** — transport vendored into `vcx/transport/`,
  dormant scope-region path retired; the patched-V fork is now CX-free
  (Bucket-1 only). No runtime-behavior change. See
  [`spec/03-approved/process/v-dependency-management.md`](spec/03-approved/process/v-dependency-management.md).

### Fixed

- **#45** — escaping/nested closures keep their environment (zero-arg def,
  module def, and re-capture cases).
- **#20** — module loader ignores `[?lib]`/`[?def]` inside `#` comments.
- **#42** — `cx fmt` accepts operator-head expressions.
- **#39** — namespaced `[$<codec>:parse]` / `:emit` accepted.
- **XAP** — `emit` routes by intent verb; `[?for]` view-closures survive loop scope.

## [0.8.0] — 2026-06-09

The "data + code" unification release. CXPath becomes a first-class
value kind; `[?match]` learns multi-arm dispatch; `[?modify]` introduces
pure-functional updates with structural sharing; a module system with
bundled stdlib lands; atom joins the scalar kinds. v0.7.6 was an
internal design pass (never released); its scope merged into v0.8.0.
Tier-1 bindings narrow to V / Python / Go / Rust under a two-layer
contract ([`spec/bindings.md`](spec/bindings.md)). Authoritative
release-surface document: [`RELEASE_NOTES_v0.8.0.md`](RELEASE_NOTES_v0.8.0.md).
Live gate state: [`spec/v0_8_0_status.md`](spec/v0_8_0_status.md).

### Added

- **CXPath as first-class value kind** — all 12 XPath 3.1 axes, `//` /
  `/` step prefixes, `@name` attribute selector, `[expr]` general
  predicates with `$_` / `$_position` / `$_last` context bindings,
  `:bind NAME` peer-modifier on path steps.
- **`[?match]` multi-arm dispatch** — heterogeneous arms (`:case` /
  `:when` / `:else`); first-match-wins; scalar literal + `_` wildcard
  patterns.
- **`[?modify]` pure-functional updates** — CXPath focus + 11-action
  vocabulary (`:set`, `:delete`, `:using`, `:rename`, `:set-attr`,
  `:delete-attr`, `:append`, `:prepend`, `:insert-before`,
  `:insert-after`, `:replace`); pipeline-composable via `|`; structural
  sharing (`< 1 KB` new heap per matched node on a 10 MB document).
- **Module system** — `[?def]` module-level functions (no closure / no
  overload / order-independent), `[?lib]` module loading (file /
  registered / HTTPS resolvers), `cx.lock` lockfile (SHA-384 / SHA-512
  SRI integrity, HTTPS-only transport), `[?const]` module-level
  constants, `:scope public` / `:scope private` visibility.
- **Bundled `cx-stdlib`** — 14 sub-packages: strings / json / http /
  re / time / math / io / bytes / format / path / log / hash / env /
  test. [`spec/stdlib.md`](spec/stdlib.md).
- **Atom scalar kind** — `:NAME` literals with type-strict
  name-equality and a disjoint hash domain.
- **`[expr]` general predicate body** + `:pure` / `:impure` modifier
  algebra (sound-but-incomplete inference; closed-list builtin
  classification).
- **Playground Tree View + Graph View** — ERD for data sources, CFG
  for code sources; per-pane toggle; bidirectional selection bridge
  via byte-offset `loc`.
- **`cx_code_diagram`** (Mermaid emit, ERD-or-CFG auto-detect) +
  **`cx_code_tree`** (JSON with `loc` byte offsets) C ABI exports.
- **`cast()` generic builtin** + **`exists()`** in [`spec/code.md §6.5`](spec/code.md).
- **ast_bin v8 wire format** with PathNode kind discriminator `0x13`
  (cap bit 36).
- **42 §11.6 release gates** — 16 v0.7.6 carryover + 14 new for the
  CXPath / `[?match]` / `[?modify]` / module-system surface + 12 new
  for the playground views.

### Changed

- **Internal `programs` → `code` rename** — `spec/programs.md` →
  `spec/code.md`; `vcx/programs/` → `vcx/code/`; `cx_program_eval*` →
  `cx_code_eval*`; `_cx_program_*` wasm exports → `_cx_code_*`;
  `in_cxl:` fixture header → `in_code:`.
- **Tier-1 bindings narrowed** to V / Python / Go / Rust under a
  two-layer contract (Layer 1 canonical 16 methods; Layer 2 host
  idiom packs).
- **Cap bits 31 + 32 re-purposed** — gate-17-era framings never
  shipped per backlog `d-2026-05-22-04`; now `cx_code_diagram` + `cx_code_tree`
  for the playground views.

### Removed

- **`[?find]` directive** — replaced by `[?for]` (pattern-generator
  form) and CXPath value-kind `//path`.
- **v0.7.0-era CXL POC evaluator surface** — `cx:` module, `log:`
  module, `inspect:`, `[?cx use-module=...]`, `[?cx pure-only]`.
- **v0.7.0-era `cx_eval_cxl_*` C ABI symbols.**
- **Six archived bindings** — TypeScript / Java / C# / Ruby / Kotlin /
  Swift moved to `lang/_archived/`. Restoration is post-v0.8.0.

### Migration

See [`RELEASE_NOTES_v0.8.0.md`](RELEASE_NOTES_v0.8.0.md) for the
breaking-change table. The mechanical renames (`programs → code`,
`cxdb → cxcol`, `cx_program_* → cx_code_*`) were applied across the
codebase as part of this release.

## [0.7.6] — in development on `v0.7.6-dev` (CX code — the headline release)

As of 2026-05-20, v0.7.6 ships **CX code** — a unified
pattern/query/transform language with full integration capabilities
(visualization, resilience, services, concurrency, async). CX code
replaces cxpath and cxquery; both are removed from the codebase as
part of this release.

This supersedes the v0.7.0 "CX is one language" scope —
the full XQuery 4.0 evaluator surface and the "v0.7.0 ships the
complete evaluator" goal. The v0.7.0–v0.7.5 line is **frozen as
proof-of-concept** — see the marker at the top of [0.7.0] below. The
v0.7.0 cxpath/cxquery implementation was incomplete, with falsified
tests (passed by reduction) and partial specs. Users who need
production-ready query/transform begin at v0.7.6.

Authoritative design reference:
[`spec/audits/code_design_v1.md`](spec/audits/code_design_v1.md)
(20 cxpath/cxquery → CX code side-by-side examples + complete §11
integration-capability specs). Normative spec
(`spec/code.md`) is in progress and is a §11.6 release gate.

### Added

**Core CX program surface** — patterns as literal CX with `$bindings`;
Scala-style for-yield comprehension; `[?find]` / `[?match]` /
`[?for]` / `[?if]` / `[?let]` / `[?fn]` / `[?def]` / `[?try]` /
`[?pipe]` directives; `|` pipe sugar; three path sigils `/` `@` `.`;
errors as `[err …]` CX values with `?` / `!` postfix; `:par` /
`[?par-map]` / `[?par-reduce]` parallelism.

**§11.1 Visualization commitment** — every directive renders to a
sequence/activity diagram per fixed rendering rules. `cx diagram`
CLI emits SVG/PNG/Mermaid; `<cx-diagram>` web component embeds in
docs/playgrounds; LSP CodeLens integration via the CX language
server.

**§11.2 Resilience directives** — `[?retry]` (with constant /
linear / exponential / fibonacci backoff and none / full / equal /
decorrelated jitter), `[?timeout]`, `[?circuit-breaker]`,
`[?fallback]`, `[?rate-limit]`, `[?bulkhead]`. Composable. Errors
in the `cx-err:CXER0140–CXER0159` range (error-namespace amendment
2026-05-21).

**§11.3 Services and clients** — `[?service :on http :port N]` with
`[resource :METHOD PATH]` children; `[?http-client :target URL]`
for outbound. Full HTTP/1.1 + HTTP/2 + TLS + streaming + multipart
+ WebSocket upgrade. Service / client error codes in the
`cx-err:CXER0160–CXER0199` range.

**§11.4 Concurrency** — `[?worker]`, `[?channel]`, `[?send]`,
`[?receive]`, `[?try-send]`, `[?try-receive]`, `[?close]`,
`[?select]`. CSP-style. FIFO per-pair ordering, locked close/drain
semantics. Channel / worker error codes in the
`cx-err:CXER0200–CXER0239` range.

**§11.5 Async / await** — `[?async]` returns `[future …]`;
`[?await]` / `[?await-all]` / `[?await-any]` / `[?await-race]`
barriers; `[?cancel]` with cooperative-cancellation contract;
`[?check-cancel]` for hot loops. Async error codes in the
`cx-err:CXER0240–CXER0279` range.

**Error code namespace expansion** — amended 2026-05-21
to reserve `cx-err:CXER0100–CXER0299` for Program runtime errors,
assigned by subsystem.

### Removed

- **cxpath** and **cxquery** implementations deleted from `vcx/`
  (replaced by CX code in `vcx/code/`).
- **XQuery 4.0 / XPath 4.0 parity scope** retired as part of the
  CX-code unification superseding the v0.7.0 scope.
- `spec/cxpath.md` and `spec/xquery_40_parity.md` retained as
  historical artifacts; `spec/code.md` is the normative spec going
  forward.

### Release gates

v0.7.6 cannot tag until all sixteen §11.6 conformance gates pass
across four categories (spec completeness, test coverage,
implementation completeness, performance floors). No exceptions, no
partial-ship fallback.

---

## [0.7.5] — 2026-05 (tagged, **proof-of-concept**)
## [0.7.0] — POC, superseded 2026-05-20

> **Status note (2026-05-20).** Everything in the [0.7.0] section
> below shipped through v0.7.5 as **proof-of-concept**. The CX code
> language work it describes (cxpath / cxquery / XQuery 4.0 parity)
> was structurally incomplete: specs carried TBD markers in
> normative positions, tests passed by reduction (covering only the
> implemented subset), and `cx:merge` shipped with material defects.
> With the CX-code unification, the entire query/transform surface is
> being replaced by CX code in
> v0.7.6. Users coming to CX for production query/transform begin
> there. Other v0.7.x deliverables (WASM build,
> `cx:`/`log:` modules) ship through their own
> trajectories and are not subject to the POC marker.

In the original v0.7.0 "CX is one language" framing,
v0.7.0 was the single-cut release that takes the
cx evaluator from the CX code 1.0 floor (v0.6.0) to **XQuery 4.0 /
XPath 4.0 parity**. That framing is now superseded.

### Added

**XQuery 4.0 expression surface (A row):**
- **`?let`** — let-binding directives in positional and labeled forms.
- **`?fn`** — inline function-value literals with closure capture.
- **`?focus`** — sugar for `[?fn :params [_] :body …]` (focus
  functions / XPath 4.0 §4.5.6.1).
- **`?match`** — pattern matching on value / type / wildcard.
- **`?try` with multi-catch** — `[?try [body, [pat1, h1], …]]` with
  literal / prefix-glob (`FOAR*`) / wildcard patterns; `err-code`,
  `err-description`, `err-value` bind in the matched handler.
- **`?fn-ref [name, arity]`** — named function references (XQuery
  3.0 §3.1.6).
- **`?partial [f, args…]`** — partial application supporting
  left-curry and middle-position `[?_]` placeholders.
- **`?str-template`** + **`?str`** — XPath 4.0 string templates and
  string constructor (directive forms).
- **FLWOR clauses on `?for`:** `:let`, `:where`, `:count`, `:while`,
  `:order-by`, `:group-by`. New `?for-tumbling` and `?for-sliding`
  windowing directives.
- **`?node-is` / `?node-before` / `?node-after`** — XPath 4.0
  §4.10.3 node comparisons.

**CXPath surface (B row):**
- **Full XPath 1.0 axis set** — `parent::`, `ancestor::`,
  `ancestor-or-self::`, `following-sibling::`, `preceding-sibling::`,
  `following::`, `preceding::`, `descendant-or-self::`, `self::`,
  plus the `..` abbreviated parent shortcut.

**Operator-token surface:**
- `xs |> f` (pipeline), `xs => f()` (arrow), `xs ! f` (simple-map),
  `'a' || 'b'` (string concat), `1 to N` (range).

**Standard fn library (C row):**
- 21 ISO-8601-backed date/time functions (current-date / time /
  dateTime, year/month/day/hours/minutes/seconds accessors,
  format-date / format-time / format-dateTime with a `YYYY MM DD
  HH mm ss` picture subset).
- Regex trio (`matches`, `tokenize`, `regex-replace`) routed through
  the libcx-vendored RE2 shim.
- Higher-order additions (`for-each-pair`, `scan-left`,
  `function-arity`, `function-name`, `function-lookup`,
  `function-identity`).
- SequenceType + casting (`instance-of`, `cast-as`, `castable-as`,
  `treat-as`, `intersect`, `except`, `otherwise`).
- JSON / XML serialize-parse (`parse-json`, `serialize-json`,
  `serialize-xml`, `parse-xml`).
- QName helpers (`prefix-from-QName`, `local-name-from-QName`,
  `namespace-uri-from-QName`).
- `doc` / `doc-available` I/O primitives.

**Map / Array runtime values (D row):**
- First-class `map:` / `array:` namespaces with the XPath 3.1
  function surface.

**Streaming evaluator (Y row):**
- `cx_eval_streaming` replaces the v0.6.0 W012 stub — pull-based
  incremental emit with a write-callback.
- Host-idiomatic streaming wrappers in Python, Go, Rust, and TypeScript.

**`cx:lang` formalization (Z row):**
- Inherited-scope resolution per `spec/i18n.md §1.3`. Every Element
  exposes the resolved BCP 47 tag via `.lang()` (V / Python / Go /
  Rust / TypeScript).

**HTMX examples (J row):**
- Five worked examples under `examples/htmx/` —
  click-to-edit, active-search, click-to-load, inline-validation,
  modal-dialog.

**Attribute-value interpolation (J0):**
- `attr=[?=expr]` parses as a single token; multiple interpolations
  per attribute are supported.

**Parquet (X row):**
- Read/write bridges in Python (`cxlib.parquet`), Go
  (`cxlib.ParquetWriteFile` / `ParquetReadFile`), and Rust
  (`cxlib::parquet::{write_file, read_file}`) per the
  no-Parquet-in-libcx policy.

**Conformance suite (L row):**
- `conformance/eval.txt` grows from 28 to 54 fixtures covering the
  v0.7.0 evaluator additions.
- Python / Go / Rust binding-side conformance runners consume the
  canonical `conformance/data_bin_arrow.txt` (14/14 each).

**Operational artifacts:**
- `scripts/reproduce_release.sh` + `docs/reproducible_builds.md`
  (BB row).
- `scripts/fuzz_cx.py` + `docs/fuzzing.md` (CC row).

### Changed

- **C ABI rename** (G row): `cx_eval_cxl` → `cx_eval`,
  `cx_eval_cxl_with_len` → `cx_eval_with_len`,
  `cx_eval_cxl_streaming` → `cx_eval_streaming`.
- **`cx-version` attribute** → **`cx-eval-version`** with the
  former accepted as a deprecated alias.
- **Spec / file renames** (F row): `spec/code.md` → `spec/eval.md`,
  `examples/cx/` → `examples/cx/`, `conformance/code.txt` →
  `conformance/eval.txt`.
- **CX-database direction record** renamed from
  `cxdb-as-database-direction` to `cx-database-direction`. The `cxdb` /
  `.cxdb` binary file format keeps its name; the deferred engine
  direction is now called "CX database".
- **Active-binding set** (D4 / H row): cut from 9 to 5 — V, Python,
  Go, Rust, TypeScript. The five frozen bindings live under
  `lang/<name>/frozen/`.
- **Strict xs: constructor parse** (U8): `xs:integer`,
  `xs:double`, `xs:decimal`, `xs:float`, `xs:nonNegativeInteger`,
  `xs:positiveInteger`, and `cast-as` now raise `cx-err:FORG0001`
  on unparseable string inputs. Pre-v0.7.0 they silently coerced
  to 0/0.0. Callers depending on the old fallback must add a
  `[?try]` wrapper or a `[?castable-as]` guard. Numeric-input
  truncation (`xs:integer(1.7) → 1`) is unchanged per
  XPath §19.1.2.

### Removed

- The W012 `cx_eval_streaming` stub is gone — replaced by the real
  streaming implementation.

### Documentation

- v0.7.0 status tracker (since deleted) — per-row tracker for
  the 22-row v0.7.0 scope (A through CC).
- `spec/xquery_40_parity.md` — per-feature inventory of the
  XQuery 4.0 surface vs cx's coverage.
- `spec/abi.md §2.11` — Arrow C Data Interface version-targeting
  policy (W8).
- `docs/reproducible_builds.md`, `docs/fuzzing.md`.

## [0.6.1] — in development

### Added
- **`cx_eval_cxl` wired into all 10 bindings** — Python, Go, Rust, Ruby, Java, Kotlin, C#, Swift gained idiomatic `eval_cxl` / `EvalCXL` wrappers (TypeScript and V already had it). program evaluation is now reachable from every binding.
- **CX code quickstart block** in all 9 per-binding READMEs — same fleet/svc example across languages.
- **`cx eval -e <expr> -d <data>`** — inline expression and inline data flags for one-liner program evaluation without files.

### Fixed
- **Parser preserves `#` line comments + block comments with commas/apostrophes** — array-literal misrouting at `[-` / `[!` / `[|` / `[#` brackets fixed; line-comment text now round-trips through `cx fmt`.
- **`tools/release-verify.sh`** — restored doc-presence checks for `RELEASE_PROCESS.md` / `EVALUATION_EXPERIENCE.md`, and fixed over-escaped `\.claude/`/`\.cache/` grep exclusions in working-tree-clean check.

## [0.6.0] — 2026-05 (planned)

The **API/format-stability boundary**. From 0.6.0 onward through
1.0, no breaking changes to the public surface (C ABI, binding APIs,
wire formats, spec-normative grammar).

### Added
- **17-member Public Table API** — shipping in all 10 bindings (V native, V-cffi, Python, Go, Rust, Java, TypeScript, C#, Kotlin, Swift, Ruby).
- **Collection literals** — first-class `seq[T]`, `arr[T]`, `map[K, V]` with cross-emitter parity.
- **`cx table` CLI subcommand** ( §D1) — `info` / `dump` / `load` verbs.
- **`cx demo` subcommand** — self-contained 60s-tier showcase per the evaluation-experience checklist.
- **`cx scaffold <kind>` subcommand** — typed, commented skeletons for config / data / doc / log / table.
- **CSV / TSV / PSV via `--csv` / `--tsv` / `--psv` CLI flags** — delimited conversion now CLI-accessible (was C-ABI-only).
- **Streaming-write event API** (capability bit 27) — Tier 1 + Tier 2 + CX/XML emits.
- **Schema validator** — 20/20 spec rules complete on Tier 1 (V core + Python + Go).
- **CX code 1.0 evaluator** (V reference; per-binding native rollout deferred to v0.7.0).
- **Parameterized templates** — `?def name :params [a b] :body ...`.
- **`the evaluation-experience checklist`** — friction-budget gate with 10 hard-fail conditions and 10 time-horizon checkpoints (10s → 1yr+).
- **CI matrix** (`.github/workflows/ci.yml`) — macOS-14 + ubuntu-22.04/24.04 × 10 bindings.
- **Release tooling** in `tools/` — bump-version, release-verify, smoke-eval, verify-* scripts.

### Changed
- **`columns` → `cols` rename** across the Table API surface.
- **`select` → `select_cols`** rename across bindings (avoids LINQ / Enumerable conflicts in .NET / Ruby; uniform for consistency).
- Migration docs restructured: per-version under [`docs/migrations/`](docs/migrations/) with an index README.
- Private docs (`CONTEXT.md`, `community/`) moved to [`docs/internal/`](docs/internal/); simplifies `.publishignore`.
- Internal grammar revisions during this cycle (v3.3 → v3.4 → v3.5 → v3.6) are now hidden from user-facing docs; users observe only the v0.5 → v0.6.0 transition.

### Fixed
- All five 2026-05 binding-audit findings (CB-1..CB-5) closed at V core and across all 9 FFI bindings; see the 2026-05 binding audit.
- Rust binding SIGABRT under Boehm GC threading — `cx_init` / `cx_thread_register` / `cx_thread_unregister` C ABI symbols added (cap bit 26).
- Parser quote+bracket fix — body-text tokenizer is now quote- and bracket-aware; closes the last two carried parser limits.

### Migration
- See [`docs/migrations/v0.5-to-v0.6.md`](docs/migrations/v0.5-to-v0.6.md) for the full upgrade guide.
- BREAKING: leading-zero integers are now strings (`02134` is a string, not int 2134).
- BREAKING: binding `loads()` / `dumps()` preserve integer/float distinction via CXDB v1 (was JSON-coerced in v0.5).

[Unreleased]: https://github.com/cx-home/cx/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/cx-home/cx/releases/tag/v0.6.0
