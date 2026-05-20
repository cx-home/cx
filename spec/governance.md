# CX Governance Specification
# Version: 1.0
# Date: 2026-05-06

This document specifies governance rules for the CX project: how
implementations conform, how the binding ecosystem stays coherent, how
quality regressions are caught before release, and how the project
prevents the kinds of systemic shortcuts that the 2026-05 audit
surfaced (see the 2026-05 binding audit).

These rules are normative. Conformance to them is a release gate.

---

## 1 — The native-implementation rule

> **No public function in any binding may call another public function
> of the same library and re-parse its string output. Bindings must
> either (a) call a C ABI symbol that does the operation in core,
> returning native bytes (binary AST or data) the binding deserializes
> once, or (b) walk an in-memory structure already held by the binding.
> String-format roundtrips are forbidden on hot paths.**

This rule exists because the 2026-05 audit found five systemic shortcut
patterns (CB-1..CB-5) all sharing the same root: bindings calling
sibling format converters and re-parsing the output. The pattern was
present in every binding, in multiple functions per binding, and was
both lossy and slow.

### 1.1 What "hot path" means

A hot path is any public function called by user code in the normal
course of consuming the library. This includes: `loads`, `dumps`,
`parse`, `to_<format>`, `select`, `select_all`, iteration over a
`Stream`, construction of a `Document`, and similar.

Test fixtures, debug utilities, and tooling code paths are exempt;
they may use convenient round-trips for clarity over performance.

### 1.2 What "native bytes" means

The C ABI returns four shapes:

- Text strings (UTF-8 NUL-terminated).
- Binary buffers (`[u32 LE: size][payload]` framing).
- Booleans (`"0"`/`"1"`).
- Handles (opaque pointers).

Binary buffers — specifically `cx_to_data_bin`, `cx_to_ast_bin`,
`cx_to_events_bin`, and the symmetric binary AST family
(`cx_*_to_ast_bin` / `cx_ast_bin_to_*`) — are the native bytes path.
A binding deserializes the binary buffer **once** into native types.

Text strings are not native bytes. A binding must not chain a text-string
output of one C ABI symbol into a text-string input of another C ABI
symbol on a hot path.

### 1.3 Examples

**Allowed:**

```python
def loads(cx_str):
 bin = libcx.cx_to_data_bin(cx_str) # one C ABI call
 return decode_data_bin(bin) # one binary deserialization
```

**Forbidden (audit found this in every binding):**

```python
def loads(cx_str):
 json_str = libcx.cx_to_json(cx_str) # C ABI call
 return json.loads(json_str) # second parser, host JSON
```

**Forbidden:**

```python
def parse_xml(xml_str):
 cx_str = libcx.cx_xml_to_cx(xml_str) # C ABI call
 return parse_cx(cx_str) # another C ABI call + re-parse
```

**Allowed:**

```python
def parse_xml(xml_str):
 bin = libcx.cx_xml_to_ast_bin(xml_str) # symmetric binary AST
 return decode_ast_bin(bin) # single decode
```

### 1.4 Enforcement

- **Code review**: every PR touching a binding's public API or its core
 internal functions checks against this rule. PR template includes a
 checkbox.
- **Static check**: a per-binding lint script (in `tooling/lints/`)
 greps for sibling-converter calls and flags them. False positives are
 silenced via comment markers.
- **Performance regression**: the `cx_to_data_bin` path should be
 measurably faster than the v1 `cx_to_json` + host JSON path. CI
 enforces a perf budget per binding (see §6).

---

## 2 — The parity matrix rule

> **Every public binding API must produce byte-identical canonical-form
> output as the V reference, on every fixture in the conformance
> suite. Drift is a release blocker.**

The current state of compliance — capability matrix across all 10
bindings, capability-bit assignments, idiomatic-divergence table,
known gaps — is in [`spec/parity_matrix.md`](parity_matrix.md). This
section defines the rule; the matrix records the state.

### 2.1 Structure

Conformance fixtures live under `conformance/` (extending the existing
flat-text format, see `conformance/README.md`). Each fixture is one
test case with input and expected canonical outputs:

```
=== test: NNN-name
level: core | extended | data | table | csv | binary | canonical | strict
tags: tag1 tag2
--- in_cx
<source CX>
--- out_canonical_cx
<lossless canonical CX (cx fmt output)>
--- out_strict_canonical_cx
<strict canonical CX (cx canonical output)>
--- out_canonical_json
<canonical JSON (cx --to-json --canonical output)>
--- out_data_bin_hex
<hex-encoded data_bin bytes>
--- out_csv
<canonical CSV (when input is :table-shaped)>
--- out_xml_c14n
<canonical XML per C14N 1.1>
--- out_md
<canonical Markdown>
--- loads_python
<expected Python repr of loads(input)>
--- loads_go
<expected Go repr of Loads(input)>
--- ... (one section per binding)
```

Sections present in a fixture indicate which outputs are tested. A
binding may not skip a section that's present.

### 2.2 CI gate

For every PR:

1. The V reference produces canonical outputs and stores them as the
 fixture's expected values. If the V reference disagrees with the
 committed fixture, the PR rebuilds the fixtures (with reviewer
 approval).
2. Each binding's CI runs every fixture through its public API and
 compares output bytes against the expected. Mismatch is a CI failure.
3. The CI report names the specific fixture, binding, and byte offset
 of disagreement.

### 2.3 Cross-binding determinism

The parity matrix asserts that **all 10 bindings** produce the same
output byte sequence for the same input. This is the only way "no major
gaps" is mechanically verifiable.

Exceptions are explicit per-fixture, per-binding, with rationale:

- Type-mapping divergence allowed where the host language genuinely
 cannot represent the value (e.g., JS bigint outside safe range).
 Tagged `lang_specific: js` and tested separately.
- Adapter outputs (Arrow, pandas, polars) are not part of the parity
 matrix.

---

## 3 — Implementation-strategy declaration

> **Every binding's `cxlib/README.md` declares which CX core APIs each
> public function calls. Changes to this declaration require review.**

Each binding maintains a section in its README:

```markdown
## Implementation strategy

| Public API | Core mechanism | Notes |
|---|---|---|
| `loads` | `cx_to_data_bin` (one call, binary decode) | |
| `dumps` | `cx_from_data_bin` (one call, binary encode) | |
| `parse_cx` | `cx_to_ast_bin` (binary decode) | |
| `parse_xml` | `cx_xml_to_ast_bin` (binary decode) | |
| `Document.to_xml` | builder → `cx_ast_bin_to_xml` | one call |
| `select` | `cx_select` | |
| `Stream` | `cx_events_open` / `cx_events_next` / `cx_events_close` | |
| `Table` | `cx_to_data_bin` table tag | column-oriented |
```

Reviewer responsibility: when a PR changes this table, check that the
new mechanism conforms to §1 (no roundtrips). When a PR doesn't change
this table but adds a public API, the PR is incomplete.

---

## 4 — V module split policy

The V binding directory is split into two modules:

```
lang/v/cffi/ C ABI wrapper (existing, renamed from lang/v/cxlib)
lang/v/native/ Native binding (NEW; imports vcx.cx directly)
```

### 4.1 `lang/v/cffi/`

- Wraps `libcx` via the V `C.cx_*` extern declarations.
- Identical FFI surface to the other 9 bindings.
- Useful for users who want a small binary (no V runtime) and don't
 need the absolute lowest latency.
- Maintained for compatibility.

### 4.2 `lang/v/native/`

- Imports `vcx.cx` directly via V's module system.
- Skips libcx entirely; no FFI on hot paths.
- Native `Document`, `Element`, `Table`, etc. types are the V core's
 own types (or thin wrappers for ergonomics).
- The single fastest path on the V VM/platform.

### 4.3 Default

The `cx.cxlib` module name (alias path used by importers) resolves to
the **native** binding. Users opt into the FFI wrapper by importing
`cx.cffi` explicitly. This makes the high-performance path the default,
matching the project's positioning.

### 4.4 Conformance

Both V variants run the parity matrix independently and must produce
byte-identical output. They may differ in performance but never in
correctness. The `cffi` variant runs the same CI as the 9 other FFI
bindings; the `native` variant runs an additional CI that verifies
cross-checks against `cffi` for every fixture.

---

## 5 — Public ABI policy

See `spec/abi.md` §1.1 for the symbol-prefix rule. Additional governance:

- ABI v1 symbols are frozen (no signature changes ever).
- ABI v2 symbols are frozen as of this branch's release. Future
 signature changes introduce v3 symbols (e.g.,
 `cx_to_data_bin_v3`) without removing v2.
- Capability bits in `cx_features` are append-only. Removing a bit
 requires a major libcx version bump.
- Internal symbols are hidden from the dynamic symbol table. Bindings
 that depend on hidden symbols are non-conformant.

### 5.1 ABI version negotiation

Every binding calls `cx_abi_version` on load. The expected behavior:

- If the major version of the loaded library equals the major version
 the binding was built for: proceed.
- If the major version is higher: log a notice and proceed (later libcx
 is backward-compatible).
- If the major version is lower: fail to load with a clear error.

### 5.2 Symbol stability

The set of exported symbols is part of the ABI contract. CI lints the
list of exported symbols against a whitelist
(`tooling/abi/v2_symbols.txt`). New symbols are added to the whitelist
in the same PR. Removed symbols cause CI failure unless the major
version is bumped.

### 5.3 Source-code identifier vs. prose-name divergence (v0.7.0)

Per [ADR 0022 §D5](decisions/0022-cx-is-one-language-v0_7_0-scope.md),
the v0.7.0 release retires the "CXL" name in prose (specs, docs,
release notes, and user-facing surfaces — see ROADMAP P1) but retains
historical identifiers in source code where they appear in ABI-visible
or fixture-visible positions. This is a deliberate divergence; it
keeps the v0.6.0 → v0.7.0 break narrow to a single mechanical pass
applied by `cx upgrade-config` (§D6) rather than a full source-tree
identifier sweep that would force every downstream code reader to
relearn names.

**Identifiers retained verbatim in source:**

- V module identifiers — `eval_cxl`, `eval_cxl_streaming`,
  `eval_cxl_with_len`, `CXLEnv`, `CXLValue`, `CXLFunction`, `CXLScalar`
  (the historical `cxl_*` symbol set in `vcx/cx/`).
- Binding-internal symbols mirroring the V identifiers
  (`cxlib.eval_cxl` in Python / Go / Rust / TS — none of which is
  user-visible as a public API name; user-facing wrappers are
  `eval` / `evaluate` per binding idiom).
- AST node types where the `CXL` prefix designates evaluator-stage
  nodes vs. data-stage nodes (`CXLEvalDirective`, `CXLInterpolation`,
  etc) — disambiguates evaluator semantics from regular Element
  parsing in the V source.
- Fixture filenames and category labels inside
  `vcx/tests/cxl_test.v` and similar — predates v0.7.0 and changing
  these forces a git-blame rewrite of every test history line.

**Identifiers renamed in source AND prose:**

- C ABI symbols: `cx_eval_cxl*` → `cx_eval*` per §D5 epoch break.
  This is the **only** ABI rename at v0.7.0; preserving it would
  lock the historical "cxl" name into every external binding's
  generated FFI bindings forever.
- File renames: `spec/cxl.md` → `spec/eval.md`; `docs/CXL.md`
  retained at v0.7.0 transition (R1 rewrites it; see ROADMAP P1).

**Why the divergence works:**

- ABI-visible names (C symbols, capability-bit labels, the `cx-eval-version`
  attribute) carry the new "cx-eval" naming so external consumers see
  the consistent v0.7.0 vocabulary.
- Source-internal names retain "cxl" because their cost is paid
  only by maintainers of the V source — a much smaller audience
  than external binding consumers — and changing them adds zero
  signal to that audience (they read code, not prose).
- The divergence is documented here, in `RELEASE_NOTES_v0.7.0.md`,
  and in ADR 0022 §D5, so the discrepancy never becomes folklore.

**Forward path:** at the next major break (v1.0.0 or whichever
release re-opens the ABI envelope), the source-internal "cxl"
identifiers MAY be renamed in a mechanical sweep without breaking
public ABI consumers. Until then, the divergence is the cost-
correct deployment.

---

## 6 — Performance SLA policy

> **Each public binding API has a documented performance budget in the
> conformance suite. Regressions beyond a threshold (default 10%)
> versus the baseline are CI failures.**

### 6.1 Budgets

Per `spec/abi.md` §4, baseline budgets exist for the C ABI. Bindings
inherit these budgets plus their own deserialization overhead, capped
at:

| Operation | Baseline (C ABI) | Per-binding cap |
|---|---|---|
| `loads(1 KB)` | < 50 µs | < 100 µs |
| `loads(1 MB)` | < 30 ms | < 60 ms |
| `loads(100 MB)` | < 3 s | < 6 s |
| `select(1 MB)` | < 60 ms | < 120 ms |

Per-binding caps account for native deserialization. A binding that
exceeds its cap is non-conformant for that operation.

#### 6.1.1 Evaluator-feature budgets (v0.7.0)

The v0.7.0 evaluator surface adds FLWOR clauses, first-class
functions, partial application, operator-token forms, pattern
matching, and the RE2-backed regex family. Each gets a tracked
microbench in `vcx/tests/runners/eval_features_bench.v` whose key
shows up under `eval.*` in the JSON consumed by the V7 perf gate
(`.github/workflows/perf.yml`).

Per-feature budgets are **relative** rather than absolute — the V7
gate compares each `eval.*` key against the baseline JSON for the
same key, refusing PRs that regress by more than the configured
threshold (default 30% per `spec/v0_7_0_status.md §T7`; tightened to
10% by passing `--strict` to `scripts/compare_bench.py` once cross-
machine variance is bounded). Absolute µs/ms values are tracked but
not gated; the relative-regression model survives runner-image swaps
and cross-OS bench drift.

| Bench key | Feature | Notes |
|---|---|---|
| `eval.flwor.where` | A8 — FLWOR `:where` clause | Per-iteration predicate; should not exceed simple `?for` baseline by more than ~10–15% |
| `eval.flwor.count` | A11 — FLWOR `:count` clause | Position-binding overhead; bounded by simple `?for` + an integer slot per iteration |
| `eval.flwor.order_by` | A26 — `:order-by` clause | Materialising (per `spec/eval.md §8.4.2`); cost dominated by sort, not iteration. Budget = `O(n log n)` proportionality to input length |
| `eval.flwor.group_by` | A26 — `:group-by` clause | Group-collection phase buffered, result emission streams. Budget = `O(n)` collection + `O(g)` emission (g = group count) |
| `eval.flwor.tumbling` | A26 — `?for-tumbling` | Constant-overhead per chunk; budget tracks the chunk-formation cost not exceeding the underlying `?for` baseline + chunk-emit |
| `eval.fn.call_x500` | A20 — `?fn` calling protocol (500 invocations) | High-frequency invocation; budget tracks per-call dispatch cost (no run-away allocation per call) |
| `eval.partial.invoke_x500` | A23 — partial application (500 invocations) | Pre-bound slot rebinding; budget at most ~1.5× the equivalent direct-call cost |
| `eval.op.pipeline` | A27 — `=>` arrow operator | Low-precedence pre-pass; per-stage cost equivalent to direct nested call form |
| `eval.op.arrow` | A27 — `=>` operator chained | Per-stage cost — chained pipelines should track linear in stage count |
| `eval.op.to_range_10k` | A41 — `1 to N` range materialisation (10 000-element) | Bounded by U3/U4 sequence-length cap (default 1M); throughput per item tracked |
| `eval.match.string` | A14 — `?match` pattern dispatch | Per-arm trial cost; budget tracks arm count, not arm body cost (the latter is independently measured) |
| `eval.regex.matches_x500` | C5 — `fn:matches` over 500 calls | RE2 backend; linear-time guaranteed by construction. Budget tracks per-call regex compile-and-discard overhead (separate from regex-execution cost on long inputs) |

**Adding a new feature.** When v0.7.x lands a new evaluator
directive or filter, the implementing PR MUST add a corresponding
bench case to `eval_features_bench.v` and a row to the table above
(or update an existing row's notes). The V7 baseline regenerates
automatically on `workflow_dispatch publish-baseline`; the per-PR
gate then catches future regressions on the new key.

**Cross-binding budgets.** v0.7.0 bindings (Python / Go / Rust / TS)
inherit these budgets via the C ABI passthrough — none has a native
re-implementation at v0.7.0 (per `spec/v0_7_0_status.md §V4`). Per-
binding parity tracking lands as T3 in v0.7.x.

### 6.2 Regression gate

CI tracks per-binding latency on the fixture set. A PR that causes any
operation to exceed +10% versus the previous baseline (or breaks the
absolute cap) is blocked. The PR author chooses to optimize, justify
(e.g., new feature with documented cost), or rebase.

### 6.3 Comparative benchmarks

The `bench/` directory holds comparative benchmarks: CX vs JSON, YAML,
TOML, CSV, Parquet, MessagePack, Protobuf. These are not pass/fail
gates but are published with each release for community scrutiny.

---

## 7 — Annual binding audit

> **Once per year, a designated reviewer audits every binding against
> §1, §2, §3, §5, and §6. Findings are documented in
> `spec/binding_audit_YYYY.md`.**

### 7.1 Process

1. The reviewer (any project maintainer) reads each binding's
 public API surface — the same scope as the 2026-05 audit.
2. For each binding, the reviewer identifies any function that:
 - Calls a sibling public function and re-parses output.
 - Re-implements logic that should be a C ABI call.
 - Diverges from the parity matrix.
 - Diverges from the implementation-strategy declaration in §3.
3. Findings are graded CRITICAL / SUBOPTIMAL / COSMETIC, same as the
 2026-05 audit.
4. CRITICAL findings are tracked as release blockers for the next minor
 version.
5. The audit is published in `spec/binding_audit_YYYY.md` with date,
 reviewer name, scope, findings, and recommended fixes.

### 7.2 Cadence

Annual minimum. May be triggered ad hoc when a binding maintainer
suspects drift, or when a contributor reports a discrepancy. Audits do
not block normal PR work; their output feeds into the next planned
release.

### 7.3 First audit

The 2026-05 audit (in the 2026-05 binding audit) is retroactively
the first formal audit under this rule. Subsequent audits follow the
same template.

---

## 8 — Conformance certification for third-party bindings

The project allows third-party bindings (e.g., Zig, Elixir, Lua) to
declare conformance:

1. The binding clones `conformance/` and runs every fixture against
 its public API.
2. All fixtures pass byte-identically.
3. The binding documents its implementation strategy per §3.
4. The binding adopts the same versioning and capability conventions
 as in §5.
5. A maintainer reviews and merges a one-line addition to
 `spec/conformance_registry.md` listing the binding, its repository,
 and certification date.

Conformance is not exclusive. A binding may be certified, drift, and be
de-listed in a future audit.

---

## 9 — Versioning policy

### 9.1 CX language version

Declared in grammar.ebnf header and in `[?cx version=X.Y]` directives.
Semver-like:

- **Major** (`X+1.0`): incompatible grammar changes (rare, requires
 strong reason). Requires migration tooling.
- **Minor** (`X.Y+1`): additive grammar changes (new syntax, new types,
 new directives). Backward-compatible: a parser at version X.Y+1
 accepts all version X.Y input.
- **Patch** (`X.Y.Z+1`): clarifications to the spec without grammar
 changes.

The current branch bumps language version from 3.3 to 3.4 due to
additive grammar changes (`:table`, `:decimal`, `:f16`, numeric
underscores, boolean sigils, line comments, logfmt mode).

### 9.2 ABI version

Declared by `cx_abi_version`. Bumps:

- **Major**: incompatible signature changes to existing v1+ symbols.
 Requires v2/v3 sibling symbols.
- **Minor**: new symbols added; existing symbols unchanged.
- **Patch**: bug fixes; no symbol changes.

The current branch ships ABI v2.0 (major bump from v1).

### 9.3 Format version

Declared in `cx_to_data_bin` header. CXDB v1 is the initial release.
Bumps follow the rules in `spec/data_bin.md` §7.

### 9.4 Library version

Each `libcx` build has a SemVer version (e.g., `2.0.0`). A binding's
SemVer is independent but should track libcx's major version.

Per-binding registry packages (`cargo`, `pip`, etc.) are versioned
together: a coordinated release publishes all 10 bindings at the same
major+minor (`X.Y`), with patch versions allowed to drift if a
binding-specific fix is needed between minors.

### 9.5 Deprecation

A symbol or feature is deprecated by:

1. Adding a deprecation notice in the relevant spec file.
2. Adding `@deprecated` annotations in source.
3. Continuing to function for at least one minor version.
4. Removed only on major version bumps.

---

## 10 — Change-management workflow

### 10.1 Spec changes

A change to any spec under `spec/` requires:

- A PR that updates the spec text.
- An update to `MIGRATION.md` describing user-visible impact.
- Conformance fixture updates if behavior changes.
- Reviewer approval from at least one maintainer not authoring the PR.

### 10.2 Grammar changes

A change to `spec/grammar.ebnf` additionally requires:

- Updates to `tooling/tree-sitter-cx/grammar.js` to match.
- Tree-sitter parser tests in `tooling/tree-sitter-cx/test/`.
- LSP completion / hover updates if the change introduces new keywords.
- A version bump per §9.1.

### 10.3 ABI changes

A change to `spec/abi.md` (and its companion `vcx/cx/cabi.v` and
`include/cx.h`) additionally requires:

- The ABI symbol whitelist update (`tooling/abi/vN_symbols.txt`).
- All 10 bindings updated in the same release cycle.
- Capability bit assignment (if new feature) per §5.

### 10.4 Major releases

A major release additionally requires:

- A migration guide section in `MIGRATION.md` written before the
 release.
- A pre-release / beta channel published to all 10 registries for at
 least 4 weeks.
- A community announcement (blog post, Discord, release notes) at
 least 2 weeks before the stable release.

---

## 11 — Project hygiene

### 11.1 Tree-sitter, LSP, editor support

These tools (`tooling/tree-sitter-cx`, `tooling/lsp`,
`tooling/vscode`, `tooling/neovim`) are part of the project, not
optional add-ons. A grammar change that doesn't update the tree-sitter
grammar is incomplete. Editor users see immediate breakage when the
two diverge.

### 11.2 Documentation

Every public API in every binding has a docstring / doc-comment
explaining behavior, parameters, return values, errors. This is
checked at PR time by per-binding doc-coverage tools.

The root `README.md`, top-level `CONTEXT.md`, per-binding READMEs, and
the analysis docs in `docs/` are kept in sync with the spec. A spec
change that doesn't update these is incomplete.

### 11.3 Examples

The `examples/` directory holds working code in every supported binding.
Examples are CI-tested as part of the build. An API change that breaks
an example fails CI.

---

## 12 — Reservations

The format-stability lock at v0.6.0 reserves a set of names and file
extensions for future expansion. These reservations exist so that
post-v0.6.0 capabilities can land additively without breaking
existing documents or tooling.

### 12.1 Reserved CXL EvalNames (`?`-prefixed directive forms)

The following names are reserved by

as **EvalNames** in CXL evaluation-directive forms (`[?Name ...]`,
grammar production [59]). They are recognized only inside the
`?`-prefixed directive family; the same words used as ordinary
data-element names (`[if]`, `[for]`, etc., without the `?` sigil)
remain valid data elements forever and never collide with CXL.

Plus the special interpolation form `[?=EXPR]` (grammar [58]).

| EvalName | Reserved at (CX release) | Available in (CXL version) | Semantics |
|--------------|--------------------------|----------------------------|-------------------------------------|
| `=` (interp) | v0.6.0 | CXL 1.0 | Evaluate EXPR as CXPath, emit value |
| `if` | v0.6.0 | CXL 1.0 | Conditional emission |
| `for` | v0.6.0 | CXL 1.0 | Iterate over a sequence |
| `with` | v0.6.0 | CXL 1.0 | Scope shift |
| `cond` | v0.6.0 | CXL 1.0 | Multi-way branch |
| `include` | v0.6.0 | CXL 1.0 | Partial inclusion |
| `def` | v0.6.0 | CXL 1.0 | Define reusable block |
| `use` | v0.6.0 | CXL 1.0 | Invoke a defined block |
| `let` | v0.6.0 | CXL 3.1+ | Local binding |
| `fn` | v0.6.0 | CXL 3.1+ | User-defined function |
| `match` | v0.6.0 | CXL 3.1+ | Pattern-match dispatch |
| `try` | v0.6.0 | CXL 3.1+ | Structured error handling |

CXL spec versions track XQuery's version numbers; CXL 1.0 mirrors
XQuery 1.0 capability (subset focused on templating), CXL 3.1
mirrors XQuery 3.1 (FLWOR + maps + arrays + arrow operator), CXL 4.0
is the long-term target mirroring XQuery 4.0.

Plus the CXL 1.0 built-in filter names (`upper`, `lower`, `trim`,
`length`, `concat`, `join`, `replace`, `abs`, `round`,
`format-decimal`, `format-percent`, `empty`, `first`, `last`,
`rest`, `take`, `drop`, `reverse`, `distinct`, `where`,
`format-date`, `format-datetime`, `type-of`, `default`,
`escape-html`, `escape-url`, `raw`) — also reserved as EvalNames in
the `?`-prefixed family per [`spec/eval.md §4`](cxl.md).

**Why `?`-prefix.** The sigil makes CXL directive forms visually
distinct from data elements at every read site, and the grammar
production for EvalDirective ([59]) cannot collide with the
production for Element ([50]) because `?` is not a NameStartChar.
Authors of CX schemas and custom data formats may freely use `if`,
`for`, `match`, etc. as ordinary data element names without
conflict.

The reservation list is closed for v0.6.0. Additions in future
minor versions require a recorded decision and a minor-version bump (§9.1).

### 12.2 Reserved `[?cx …]` directive attributes (CXL configuration)

The following `[?cx …]` directive attribute names are reserved for
CXL evaluator configuration. They are stripped from rendered output.
Pure-data documents using these directives parse but have no effect.

| Attribute | Reserved at (CX release) | Used in | Purpose |
|-----------------|--------------------------|-------------|--------------------------------------|
| `output-target` | v0.6.0 | CXL 1.0+ | Declare output format (`html`, `markdown`, `csv`, `cx`, `json`, `yaml`, `toml`, `xml`, `text`) — the only output-shape mechanism ( superseded by , 2026-05-10) |
| `output-strict` | v0.6.0 | CXL 1.0+ | Enable strict mode (frozen filter set, no implicit coercion) |
| `cxl-version` | v0.6.0 | CXL 1.0+ | Pin program to a specific CXL spec version (`1.0`, `3.1`, `4.0`) |

This extends the v3.4 CXDirective vocabulary (`include`, `schema`,
`version`) per [`spec/ast.md` §CXDirective](ast.md). Unknown
`[?cx …]` attributes continue to round-trip as data per the
existing rule.

### 12.3 Reserved file extensions

| Extension | Reserved at | Used in | Description |
|-----------|-------------|----------------|---------------------------------------|
| `.cx` | v0.1.0 | core | CX document |
| `.cxs` | v0.6.0 | | CX schema |
| ~~`.cxsh`~~ | ~~v0.6.0~~ | ~~~~ | **Removed 2026-05-10:** superseded by ; no `.cxsh` shape engine ships. The extension is released back to the public extension namespace. |
| `.cxl` | v0.6.0 | / CXL 1.0+ | CX Language program (rendering / querying / transformation) |
| `.cxdb` | v0.6.0 | data_bin.md | CXDB binary wire format |

Reservation means: the CX project's CLIs, LSP, editors, and registry
metadata recognize the extension as CX-related. Third-party tooling
SHOULD NOT claim these extensions for unrelated purposes. The
reservation is documentary; no enforcement mechanism exists outside
project-controlled tooling.

CXL programs use one extension regardless of use case (templating,
querying, transformation). The use case is determined by the
program's `[?cx output-target=…]` configuration directive (§12.2) and
the invocation mode (`cx eval` / `cx render`), not by file extension.

---

## 13 — Out of scope (for v2)

The following governance items are designed-for-later:

- **Funded conformance certification**: a paid third-party that
 independently verifies binding conformance. Useful for enterprise
 adoption; not required at v2.
- **Reproducible-build attestation**: SLSA-style provenance for
 binary releases. Worth doing; defer to a security-focused later
 release.
- **CVE process**: when CX has its first published CVE, the project
 will adopt a security disclosure policy. Until then, security issues
 are reported via a private channel documented in `SECURITY.md`
 (which is itself a follow-up artifact).
