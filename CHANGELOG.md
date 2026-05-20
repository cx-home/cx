# Changelog

All notable changes to CX are recorded here. Per-release deep-dives
live in [`docs/releases/`](docs/releases/); migration instructions
live in [`docs/migrations/`](docs/migrations/).

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
plus the additional [`spec/governance.md §9` versioning rules](spec/governance.md#9-versioning)
for the multi-axis CX project (language version, ABI version, format
version, library version).

## [Unreleased]

## [0.7.0] — in development on `v0.7.0-dev`

Per [ADR 0022](spec/decisions/0022-cx-is-one-language-v0_7_0-scope.md),
v0.7.0 is the single-cut release that takes the cx evaluator from
the CXL 1.0 floor (v0.6.0) to **XQuery 4.0 / XPath 4.0 parity**.
The staged "CXL 3.1 → CXL 4.0" trajectory in the original ROADMAP
is collapsed into one tag.

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
  (`cxlib::parquet::{write_file, read_file}`) per ADR 0015 D11's
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
- **`cxl-version` attribute** → **`cx-eval-version`** with the
  former accepted as a deprecated alias.
- **Spec / file renames** (F row): `spec/cxl.md` → `spec/eval.md`,
  `examples/cxl/` → `examples/cx/`, `conformance/cxl.txt` →
  `conformance/eval.txt`.
- **`spec/decisions/0021-cxdb-as-database-direction.md`** renamed
  to `0021-cx-database-direction.md`. The `cxdb` / `.cxdb` binary
  file format keeps its name; the deferred engine direction is now
  called "CX database".
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

- `spec/v0_7_0_status.md` — per-row tracker for the 22-row v0.7.0
  scope (A through CC).
- `spec/xquery_40_parity.md` — per-feature inventory of the
  XQuery 4.0 surface vs cx's coverage.
- `spec/abi.md §2.11` — Arrow C Data Interface version-targeting
  policy (W8).
- `docs/reproducible_builds.md`, `docs/fuzzing.md`.

## [0.6.1] — in development

### Added
- **`cx_eval_cxl` wired into all 10 bindings** — Python, Go, Rust, Ruby, Java, Kotlin, C#, Swift gained idiomatic `eval_cxl` / `EvalCXL` wrappers (TypeScript and V already had it). CXL evaluation is now reachable from every binding.
- **CXL quickstart block** in all 9 per-binding READMEs — same fleet/svc example across languages.
- **`cx eval -e <expr> -d <data>`** — inline expression and inline data flags for one-liner CXL evaluation without files.

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
- **CXL 1.0 evaluator** (V reference; per-binding native rollout deferred to v0.7.0).
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
