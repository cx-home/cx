# CX v0.7.0 — Release Notes
# Date: TBD (target: v0.7.0-dev → main merge + tag)
# Branch: v0.7.0-dev (merged → main)

The single-cut release that takes the cx evaluator from the CXL 1.0
floor (v0.6.0) to **XQuery 4.0 / XPath 4.0 parity**. Per
[ADR 0022](spec/decisions/0022-cx-is-one-language-v0_7_0-scope.md),
the originally-staged "CXL 3.1 → CXL 4.0" trajectory is collapsed
into one tag.

## Headline

- **Full XQuery 4.0 expression surface in directive form**: `?fn`,
  `?let`, `?match`, `?try` with multi-catch, FLWOR with `:let` /
  `:where` / `:count` / `:while` / `:order-by` / `:group-by`,
  tumbling and sliding windows, and the partial-application
  family.
- **XPath 4.0 axes in CXPath** — parent, ancestor, sibling,
  following, preceding all land. `..` shortcut included.
- **Operator-token surface** — `|>`, `=>`, `!`, `||`, `to` parse at
  expression top level.
- **Standard fn library** ships ~80+ entries covering numerics,
  strings, regex, dates/times, sequences, higher-order, JSON / XML
  serialize-parse, QName helpers, math, boolean, and
  SequenceType machinery.
- **Map and array runtime values** with the XPath 3.1 `map:` /
  `array:` namespaces.
- **Streaming evaluator** replaces the v0.6.0 W012 stub —
  pull-based incremental emit with a write-callback. Host-idiomatic
  streaming wrappers in all four active bindings.
- **`cx:lang` formalization** — inherited-scope resolution per
  `spec/i18n.md §1.3`. Every Element exposes the resolved BCP 47
  tag via `.lang()`.
- **HTMX-component examples** — five worked examples under
  `examples/htmx/` (click-to-edit, active-search, click-to-load,
  inline-validation, modal-dialog) demonstrate the cx-as-template
  pattern.
- **Parquet bridges** in Python, Go, and Rust per ADR 0015 D11's
  no-Parquet-in-libcx policy.

## Breaking changes

- **C ABI rename** (G row):
  - `cx_eval_cxl` → `cx_eval`
  - `cx_eval_cxl_with_len` → `cx_eval_with_len`
  - `cx_eval_cxl_streaming` → `cx_eval_streaming`

  The v0.6.0 names are retained as aliases for one transition
  release. Direct C-ABI consumers should adopt the new names; the
  active binding wrappers (Python, Go, Rust, TypeScript) handle
  the rename internally.

- **`cxl-version` attribute** → **`cx-eval-version`**. The former
  is accepted as a deprecated alias during the v0.6.0 → v0.7.0
  migration window; `cx upgrade-config` (see Migration below) does
  the rename automatically.

- **Spec / file renames** (F row):
  - `spec/cxl.md` → `spec/eval.md`
  - `examples/cxl/` → `examples/cx/`
  - `conformance/cxl.txt` → `conformance/eval.txt`

  Anchor links to the old paths break; `cx upgrade-config` migrates
  user-side config references.

- **Active binding set cut** (D4 / H row): the conformance and
  test-corpus matrix narrows from nine bindings to five — V (the
  reference), Python, Go, Rust, TypeScript. The previously-active
  C# / Java / Kotlin / Ruby / Swift bindings move to
  `lang/<name>/frozen/`. They keep their v0.6.0 surface but are not
  required to track v0.7.0 features.

- **W012 stub for `cx_eval_streaming` is gone** — replaced by the
  real streaming implementation. Consumers that previously caught
  the W012 error path need to handle the streaming result instead.

## What's new — per row

The per-row tracker in
[`spec/v0_7_0_status.md`](spec/v0_7_0_status.md) carries the
authoritative state. Quick links:

| Row | Theme | Highlights |
|---|---|---|
| A | XQuery 4.0 expression surface | inline functions, FLWOR clauses + windowing, `?match`, `?try` multi-catch, `?partial` with `[?_]` placeholder |
| B | CXPath axes | full XPath 1.0 axis set + `..` shortcut |
| C | Standard fn library | ~80+ fns across numerics, strings, regex, date/time, sequences, higher-order, JSON, QName |
| D | Map / array runtime | first-class map: / array: namespaces |
| E | Error namespace | cx-err:CXER / FORG / FOAR encoding; `[?error]` raises; `?try` catches with err-* bindings |
| F | Spec/file renames | cxl.md → eval.md (+ companion paths) |
| G | C ABI rename | cx_eval_cxl* → cx_eval* |
| H | Five-binding parity | V + Python + Go + Rust + TS active |
| J | HTMX examples + J0 | attribute-value interpolation + 5 worked examples |
| W | Arrow | RE2-backed conformance runners in 3 active bindings; ABI version-targeting policy |
| X | Parquet | Python / Go / Rust read/write bridges |
| Y | Streaming evaluator | W012 stub replaced; 4 binding wrappers |
| Z | cx:lang | inherited-scope resolution across all 5 bindings |
| L | Conformance | eval.txt 28 → 54 fixtures |
| BB | Reproducible builds | scripts/reproduce_release.sh + docs/reproducible_builds.md |
| CC | Fuzz harness | scripts/fuzz_cx.py + docs/fuzzing.md |

## Migration

`cx upgrade-config <path>` (per the I row migration tool) handles:

- `cxl-version` → `cx-eval-version` attribute rename in user config
  documents.
- Documented path renames (e.g., `spec/cxl.md` references →
  `spec/eval.md`).
- Existing `.cxl` files round-trip without changes — the extension
  remains a tooling-only convention.

Programs that depended on the W012 `cx_eval_streaming` stub error
need to be updated — the real streaming entry point is now in
effect.

## Known limitations carried forward

- **Native binding evaluators are not in scope.** Per the
  binding-architecture note in ROADMAP §v0.7.0, the V reference is
  the single evaluator; bindings call it through the C ABI.
  Byte-identical output across bindings is automatic because every
  binding routes through the same V code path.
- **TS Arrow / Parquet (W7 / X6)** are deferred — the C Data
  Interface bridge isn't feasible from V8, and adopting Arrow IPC
  bytes at the C ABI for TS consumption is post-v0.7.0 work.
- **Nested Arrow types (W1)** — struct, list, dictionary-encoded,
  fixed-size-list, decimal still error with a `not yet supported`
  message at the V Arrow layer. Scalar types (the full v0.6.0 set
  plus timestamp[ns, UTC]) work cross-binding.
- **`<<` / `>>` document-order node comparison (A44)** — partial:
  works when both operands are reachable from the current
  evaluation context's root. Strict reference identity awaits the
  parent-pointer / element-id work in a future arc.
- **Locale-sensitive fn library (Z3)** — `format-number`,
  `format-date`, `compare`, `sort` do not yet honour `cx:lang`.
  The accessor is in place; the wiring through the fn library is
  post-v0.7.0.

See [`spec/v0_7_0_status.md`](spec/v0_7_0_status.md) for the
authoritative status of every row item.

## Acknowledgments

The single-cut model from CXL 1.0 → XQuery 4.0 parity is the
biggest scope expansion the v0.x line has shipped. Authors,
reviewers, and downstream adopters who exercised the surface
during the v0.7.0-dev arc made the parity claim verifiable rather
than aspirational. The conformance corpus (`conformance/eval.txt`)
is the durable proof.
