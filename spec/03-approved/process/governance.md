# CX Governance Specification

**Status:** Current for v0.8.0

This document specifies normative governance rules for the CX project:
how implementations conform, how the binding ecosystem stays coherent,
how regressions are caught before release, and how the spec corpus
itself stays internally consistent. Conformance is a release gate.

---

## 1 — The native-implementation rule

> **No public function in any binding may call another public function
> of the same library and re-parse its string output. Bindings must
> either (a) call a C ABI symbol that does the operation in core,
> returning native bytes the binding deserializes once, or (b) walk an
> in-memory structure already held by the binding. String-format
> roundtrips are forbidden on hot paths.**

### 1.1 What "hot path" means

A hot path is any public function called by user code in the normal
course of consuming the library: `loads`, `dumps`, `parse`,
`to_<format>`, `select`, `select_all`, iteration over a `Stream`,
construction of a `Document`. Test fixtures, debug utilities, and
tooling code paths are exempt.

### 1.2 What "native bytes" means

The C ABI returns four shapes: text strings, binary buffers
(`[u32 LE: size][payload]`), booleans, and handles.

Binary buffers — `cx_to_data_bin`, `cx_to_ast_bin`, `cx_to_events_bin`,
and the symmetric `cx_*_to_ast_bin` / `cx_ast_bin_to_*` family — are
the native bytes path. A binding deserializes each buffer **once** into
native types.

Text strings are not native bytes. A binding must not chain a
text-string output of one C ABI symbol into a text-string input of
another C ABI symbol on a hot path.

### 1.3 Examples

**Allowed:**

```python
def loads(cx_str):
    bin = libcx.cx_to_data_bin(cx_str)   # one C ABI call
    return decode_data_bin(bin)          # one binary deserialization
```

**Forbidden:**

```python
def loads(cx_str):
    json_str = libcx.cx_to_json(cx_str)  # C ABI call
    return json.loads(json_str)          # second parser, host JSON
```

### 1.4 Enforcement

- Code review: every PR touching a binding's public API checks against
  this rule.
- Static check: a per-binding lint script greps for sibling-converter
  calls.
- Performance: `cx_to_data_bin` paths are measurably faster than
  format-roundtrip equivalents; CI enforces a perf budget per binding
  (§6).

---

## 2 — The parity matrix rule

> **Every public binding API must produce byte-identical canonical-form
> output as the V reference, on every fixture in the conformance suite.
> Drift is a release blocker.**

State of compliance — capability matrix, idiomatic-divergence table,
known gaps — is in
[`spec/misc/parity-matrix.md`](../misc/parity-matrix.md). This section
defines the rule; the matrix records the state.

### 2.1 Structure

Conformance fixtures live under `conformance/`. Each fixture is one
test case with input and expected canonical outputs across formats and
bindings; sections present in a fixture indicate which outputs are
tested. A binding may not skip a section that is present.

### 2.2 CI gate

For every PR:

1. The V reference produces canonical outputs and stores them as the
   fixture's expected values.
2. Each binding's CI runs every fixture through its public API and
   compares output bytes against the expected. Mismatch is a CI failure.
3. The CI report names the specific fixture, binding, and byte offset
   of disagreement.

### 2.3 Cross-binding determinism

All active bindings produce the same output byte sequence for the same
input. Exceptions are explicit per-fixture, per-binding, with rationale
recorded inline; adapter outputs (Arrow, pandas, polars) are not part
of the parity matrix.

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
| `eval_code` | `cx_code_eval_with_len` | |
| `Stream` | `cx_events_open` / `cx_events_next` / `cx_events_close` | |
| `Table` | `cx_to_data_bin` table tag | column-oriented |
```

When a PR changes this table, the new mechanism MUST conform to §1.
When a PR adds a public API without updating this table, the PR is
incomplete.

---

## 4 — V binding policy

The V binding ships as a single native module at `lang/v/native/`,
which imports `vcx.cx` directly via V's module system and skips libcx
on hot paths. Native `Document`, `Element`, `Table`, etc. types are the
V core's own types (or thin wrappers for ergonomics).

The V native binding runs the parity matrix and produces byte-identical
output to the FFI bindings. It may differ in performance but never in
correctness.

---

## 5 — Public ABI policy

See [`core/abi.md`](../core/abi.md) §1.1 for the symbol-prefix rule.
Additional governance:

- Frozen v1 symbols are never signature-changed. Future signature
  changes introduce v2 / v3 sibling symbols without removing earlier
  ones.
- Capability bits in `cx_features` are append-only. Removing a bit
  requires a major libcx version bump.
- Internal symbols are hidden from the dynamic symbol table.

### 5.1 ABI version negotiation

Every binding calls `cx_abi_version` on load:

- Major version equal: proceed.
- Major version higher: log a notice and proceed.
- Major version lower: fail to load with a clear error.

### 5.2 Symbol stability

The canonical list of exported `cx_*` symbols is the set declared in
`vcx/cx/cabi.v` (the V source of the C ABI) and surfaced through
`include/cx.h` (the C header). CI extracts the symbol set from
`vcx/cx/cabi.v` and lints the built `libcx` exports against it on every
PR; new symbols MUST be added to `vcx/cx/cabi.v` (with a matching
`include/cx.h` declaration) in the same PR that exports them, and
removed symbols cause CI failure unless the ABI major version is bumped
per §9.2.

### 5.3 Naming surface

The prose name is **CX** (the language; the evaluator is **cx-eval**);
the canonical source extension is `.cx`. C ABI symbols all share the
`cx_*` prefix, with per-area families (`cx_to_*` for conversions,
`cx_events_*` for streaming, `cx_table_*` for streaming tables,
`cx_arrow_*` for Arrow interop, `cx_validate*` for schema validation,
`cx_code_*` for the code-evaluator surface — see
[`core/abi.md §2`](../core/abi.md)). V module identifiers, binding
internal helpers, AST node types, and fixture filenames follow the
unified `code` vocabulary for the code-evaluator surface.

---

## 6 — Performance SLA policy

> **Each public binding API has a documented performance budget in the
> conformance suite. Regressions beyond a threshold (default 10%)
> versus the baseline are CI failures.**

### 6.1 Budgets

Baseline budgets for the C ABI are in [`core/abi.md`](../core/abi.md)
§4. Bindings inherit these plus their own deserialization overhead:

| Operation | Baseline (C ABI) | Per-binding cap |
|---|---|---|
| `loads(1 KB)` | < 50 µs | < 100 µs |
| `loads(1 MB)` | < 30 ms | < 60 ms |
| `loads(100 MB)` | < 3 s | < 6 s |
| `select(1 MB)` | < 60 ms | < 120 ms |

A binding that exceeds its cap is non-conformant for that operation.

### 6.2 Evaluator-feature budgets

The evaluator surface has tracked microbenches in
`vcx/tests/runners/eval_features_bench.v` whose key shows up under
`eval.*` in the JSON consumed by the perf gate
(`.github/workflows/perf.yml`). Per-feature budgets are **relative**:
the gate compares each `eval.*` key against the baseline JSON for the
same key, refusing PRs that regress beyond the configured threshold
(default 30%; tightened to 10% via `--strict`).

When a release adds a new evaluator directive or filter, the
implementing PR MUST add a bench case to `eval_features_bench.v`.

### 6.3 Regression gate

CI tracks per-binding latency on the fixture set. A PR that causes any
operation to exceed +10% versus the previous baseline (or breaks the
absolute cap) is blocked.

### 6.4 Comparative benchmarks

The `bench/` directory holds comparative benchmarks vs JSON, YAML,
TOML, CSV, Parquet, MessagePack, Protobuf. These are not pass/fail
gates but are published with each release for community scrutiny.

---

## 7 — Annual binding audit

> **Once per year, a designated reviewer audits every binding against
> §1, §2, §3, §5, and §6. Findings are documented in
> `spec/binding_audit_YYYY.md`.**

v0.8.0 ships without the first audit artifact; `spec/binding_audit_YYYY.md`
lands at the first annual audit cycle. This section is informational
at v0.8.0 and becomes enforcement (a release blocker if missing for a
given annual cycle) at v0.9.0.

### 7.1 Process

1. The reviewer reads each binding's public API surface.
2. For each binding, the reviewer identifies any function that:
   - Calls a sibling public function and re-parses output.
   - Re-implements logic that should be a C ABI call.
   - Diverges from the parity matrix.
   - Diverges from the implementation-strategy declaration in §3.
3. Findings are graded CRITICAL / SUBOPTIMAL / COSMETIC.
4. CRITICAL findings are tracked as release blockers for the next minor
   version.
5. The audit is published in `spec/binding_audit_YYYY.md`.

### 7.2 Anti-pattern checklist

A future audit specifically tests for each of:

1. **Re-emit detour.** A binding serializes a parsed Document back to
   CX text, then sends that text through libcx for a different output
   format. Correct path: `cx_ast_bin_to_<fmt>` family.
2. **JSON-AST re-parse.** A binding routes non-CX input through libcx
   as JSON-encoded AST text, then parses that JSON locally. Two parses
   for one input. Correct path: `cx_<fmt>_to_ast_bin`.
3. **String-detour data binding.** `loads` / `dumps` go through CX
   text and `cx_to_json` / `cx_json_to_cx`, dropping type fidelity.
   Correct path: `cx_to_data_bin` / `cx_from_data_bin`.
4. **Eager fake streaming.** `stream()` is named "streaming" but
   materializes the complete event list up-front. Correct path:
   handle-based pull API (`cx_events_open` / `_next` / `_close`).
5. **Host-language CXPath duplication.** Each binding ports the V
   reference CXPath parser/evaluator into its host language. Correct
   path: route through `cx_code_eval` (`core/abi.md §2.16.1`) with a
   path-value expression.

### 7.3 Cadence

Annual minimum. May be triggered ad hoc when a maintainer suspects
drift, or when a contributor reports a discrepancy.

---

## 8 — Conformance certification for third-party bindings

A third-party binding declares conformance by:

1. Cloning `conformance/` and running every fixture against its public
   API.
2. All fixtures passing byte-identically.
3. Documenting its implementation strategy per §3.
4. Adopting the versioning and capability conventions in §5.
5. A maintainer review of a one-line addition to
   `spec/conformance_registry.md`.

Conformance is not exclusive. A binding may be certified, drift, and be
de-listed in a future audit.

v0.8.0 ships without `spec/conformance_registry.md`; the registry file
is created when the first third-party binding submits a conformance
claim. This section is informational at v0.8.0 and becomes enforcement
(a missing registry entry blocks a third-party "conformant" claim) at
v0.9.0.

---

## 9 — Versioning policy

### 9.1 CX language version

Declared in `core/grammar.ebnf` header and in `[?cx version=X.Y]`
directives:

- **Major** (`X+1.0`): incompatible grammar changes (requires migration
  tooling).
- **Minor** (`X.Y+1`): additive grammar changes (backward-compatible).
- **Patch** (`X.Y.Z+1`): clarifications without grammar changes.

### 9.2 ABI version

Declared by `cx_abi_version`:

- **Major**: incompatible signature changes (requires v2/v3 sibling
  symbols).
- **Minor**: new symbols added.
- **Patch**: bug fixes; no symbol changes.

### 9.3 Format version

Declared in `cx_to_data_bin` header. Bumps follow the rules in
[`core/data-bin.md`](../core/data-bin.md).

### 9.4 Library version

Each `libcx` build has a SemVer version. Per-binding registry packages
are versioned together at the same major+minor (`X.Y`); patch versions
may drift for binding-specific fixes.

### 9.5 Deprecation

A symbol or feature is deprecated by adding a deprecation notice in the
relevant spec file, adding `@deprecated` annotations in source,
continuing to function for at least one minor version, and being
removed only on major version bumps.

### 9.5a Error-code stability

CXER wire codes (e.g., `CXER0205`) and their symbolic names (e.g.,
`E_LIB_NOT_FOUND`) are **stable through 1.0** within a major version.
Renumbering or renaming a CXER code requires a major version bump.
Schema codes (`S001–S020`), lint codes (`L001–L020`), and write-warning
codes (`W001–W009`) share this guarantee.

Error-message **strings** (the human-readable text after the code) are
NOT stable across patch versions — they may be tightened, translated,
or reworded for clarity without warning. Consumers MUST switch on the
CXER code (or its symbolic name), never on the message text. Diagnostic
position fields (`line`, `column`, `byte_offset`) are stable in shape
but not in exact numeric value when canonical formatting changes.

The CXER namespace allocations registry — the single source of truth
for which subsystem owns which range — lives at §9.6.

### 9.6 CXER namespace allocations (canonical registry)

The `cx-err:CXERnnnn` wire-code namespace is partitioned across the spec
corpus. This registry is the **single source of truth** for which
module owns which block; per-module error tables MUST cite codes only
from their own allocated range, and new allocations MUST be added here
before being used in a module's error table.

The CX core language reserves `CXER0001` (generic-core panic) and
`CXER0100–CXER0299` (CX-code directive errors); the full sub-block
allocation table inside that range lives in
[`spec/core/code.md §9.4`](../core/code.md#§9.4-cx-code-error-code-reservation)
and is not duplicated here.

| Range | Owner module / subsystem | Spec file |
|---|---|---|
| `CXER0001` | Generic-core panic (`CX_PANIC`, runtime `!`) | `spec/core/code.md` §9.2 / §9.4 |
| `CXER0100–CXER0299` | CX language core (directive errors) | `spec/core/code.md` §9.4 |
| `CXER1100–CXER1132` | `cx-stdlib/store` (sparse: 1100, 1101, 1110, 1120, 1121, 1130, 1131, 1132) | `spec/std-lib/store.md` §5 |
| `CXER1200–CXER1204` | `cx-stdlib/ft` (full-text) | `spec/std-lib/ft.md` |
| `CXER1300–CXER1306` | `cx-stdlib/email` | `spec/std-lib/email.md` |
| `CXER1400–CXER1403` | `cx-stdlib/url` | `spec/std-lib/url.md` |
| `CXER1500, 1502–1504` | `cx-stdlib/csv` (1501 reserved) | `spec/std-lib/csv.md` §5 |
| `CXER1600–CXER1605` | `cx-stdlib/validate` | `spec/std-lib/validate.md` §6 |
| `CXER1700–CXER1708` | CXStore Remote Protocol (CSRP) — `E_CSRP_*` only; distinct from `CXER11xx` `E_STORE_*` | `spec/misc/cxstore-remote-protocol.md` §3 |
| `CXER1720` | CSRP integrity mismatch (`E_CSRP_INTEGRITY_MISMATCH`) | `spec/misc/cxstore-remote-protocol.md` |
| `CXER1721` | CSRP not found (`E_CSRP_NOT_FOUND`) | `spec/misc/cxstore-remote-protocol.md` |
| `CXER1800–CXER1801` | `cx-stdlib/uuid` | `spec/std-lib/uuid.md` |
| `CXER1900–CXER1905` | `cx-stdlib/random` | `spec/std-lib/random.md` |
| `CXER2000–CXER2005` | `cx-stdlib/hash` | `spec/std-lib/hash.md` |
| `CXER2100–CXER2103` | `cx-stdlib/prof` | `spec/std-lib/prof.md` |
| `CXER2200–CXER2203` | `cx-stdlib/test` | `spec/std-lib/test.md` |
| `CXER2300–CXER2307` | `cx-stdlib/bytes` | `spec/std-lib/bytes.md` |
| `CXER2400–CXER2405` | `cx-stdlib/log` | `spec/std-lib/log.md` |
| `CXER2500–CXER2504` | `cx-stdlib/env` | `spec/std-lib/env.md` |
| `CXER2600–CXER2603` | `cx-stdlib/path` | `spec/std-lib/path.md` |
| `CXER2700–CXER2702` | `cx-stdlib/format` | `spec/std-lib/format.md` |
| `CXER2800–CXER2804` | `cx-stdlib/mime` | `spec/std-lib/mime.md` |
| `CXER2900–CXER2904` | `cx-stdlib/strings` | `spec/std-lib/strings.md` |
| `CXER3000–CXER3003` | `cx-stdlib/math` | `spec/std-lib/math.md` |
| `CXER3100–CXER3106` | `cx-stdlib/json` | `spec/std-lib/json.md` |
| `CXER3200–CXER3203` | `cx-stdlib/re` | `spec/std-lib/re.md` |
| `CXER3300–CXER3349` | `cx-stdlib/time` (3300–3305 core; 3320–3349 recurrence rules, 3306–3319 reserved) | `spec/std-lib/time.md` |
| `CXER3400–CXER3411` | `cx-stdlib/io` | `spec/std-lib/io.md` |
| `CXER3500–CXER3504` | `cx-stdlib/locale` | `spec/std-lib/locale.md` |
| `CXER3600–CXER3605` | `cx-stdlib/geo` | `spec/std-lib/geo.md` |
| `CXER3700–CXER3719` | `cx-stdlib/crypto` (3700–3707 core primitives, 3702 reserved; 3708–3719 JWT/JWKS verify) | `spec/std-lib/crypto.md` |
| `CXER3800–CXER3805` | `cx-stdlib/i18n` | `spec/std-lib/i18n.md` |
| `CXER3900–CXER3902` | `cx-stdlib/html` | `spec/std-lib/html.md` |
| `CXER4000–CXER4012` | `cx-stdlib/process` | `spec/std-lib/process.md` |
| `CXER4100–CXER4119` | `module-cx` | `spec/modules/cx.md` |
| `CXER4200–CXER4209` | `module-sqlite` | `spec/modules/sqlite.md` |
| `CXER4300–CXER4309` | `module-tree-sitter` | `spec/modules/tree-sitter.md` |
| `CXER4400–CXER4409` | `cx-stdlib/fp` (functor/monad protocol; `CXER4400 E_NO_INSTANCE`) | `spec/std-lib/fp.md` |
| `CXER4500–CXER4524` | `cx-stdlib/net` (L4 networking — `E_NET_*`; allocated above fp's 4400-band) | `spec/03-approved/std-lib/net.md` |
| `CXER4525–CXER4589` | `cx-stdlib/http` (L7 HTTP/1.1 client + server — `E_HTTP_*`; allocated above net's 4500-band; 4544–4589 SSE/streaming) | `spec/03-approved/std-lib/http.md` |
| `CXER4600–CXER4649` | `cx-stdlib/journal` (append-only hash-chained event log + fold→state — `E_JOURNAL_*`) | `spec/03-approved/std-lib/journal.md` |
| `CXER4650–CXER4699` | `cx-stdlib/bus` (in-process pub/sub, ordered dispatch — `E_BUS_*`) | `spec/03-approved/std-lib/bus.md` |
| `CXER4700–CXER4799` | `cx-stdlib/authz` (authorization / trust model — `E_AUTHZ_*`) | `spec/03-approved/std-lib/authz.md` |
| `CXER4800–CXER4849` | `cx-stdlib/session` (`(principal, tenant)` sessions — `E_SESSION_*`) | `spec/03-approved/std-lib/session.md` |
| `CXER4970–CXER4989` | `cx-stdlib/sched` (scheduled events & timers — `E_SCHED_*`) | `spec/03-approved/std-lib/sched.md` |

**Invariants:**

1. **1:1 symbolic ↔ wire.** Within a single module's allocation, every
   symbolic name maps to exactly one wire code and every wire code
   maps to exactly one symbolic name. Conformance gate (`code.md`
   §11.4.1 gate 2) enforces this across the corpus.
2. **No cross-module symbolic-name collisions on distinct wire codes.**
   If two distinct wire codes need similar semantics (e.g.
   `CXER1120 E_STORE_INTEGRITY_MISMATCH` vs CSRP's `CXER1720`), they
   MUST carry distinct symbolic-name prefixes (`E_STORE_*` vs
   `E_CSRP_*`).
3. **Append-only.** Allocated codes are never renumbered. A code may
   be marked Reserved in its owning module's error table when its
   slot is held for future use.
4. **Range ownership is exclusive.** A new module claiming a range
   adds a row here in the same PR that introduces its first code.

---

## 10 — Change-management workflow

### 10.1 Spec changes

A change to any spec under `spec/` requires:

- A PR that updates the spec text.
- Conformance fixture updates if behavior changes.
- Reviewer approval from at least one maintainer not authoring the PR.

### 10.2 Grammar changes

A change to `spec/core/grammar.ebnf` additionally requires:

- Updates to `tooling/tree-sitter-cx/grammar.js`.
- Tree-sitter parser tests in `tooling/tree-sitter-cx/test/`.
- LSP completion / hover updates for new keywords.
- A version bump per §9.1.

### 10.3 ABI changes

A change to `spec/core/abi.md` (and `vcx/cx/cabi.v` and `include/cx.h`)
additionally requires:

- The ABI symbol whitelist update.
- All active bindings updated in the same release cycle.
- Capability bit assignment per §5.

### 10.4 Major releases

A major release additionally requires:

- A pre-release / beta channel published to all active registries for
  at least 4 weeks.
- A community announcement at least 2 weeks before the stable release.

---

## 11 — Project hygiene

### 11.1 Tree-sitter, LSP, editor support

`tooling/tree-sitter-cx`, `tooling/lsp`, `tooling/vscode`, and
`tooling/neovim` are part of the project. A grammar change that does
not update the tree-sitter grammar is incomplete.

### 11.2 Documentation

Every public API in every binding has a docstring/doc-comment. The root
`README.md`, top-level `CONTEXT.md`, per-binding READMEs, and the docs
in `docs/` are kept in sync with the spec.

### 11.3 Examples

`examples/` holds working code in every supported binding. Examples are
CI-tested as part of the build.

---

## 12 — Reservations

### 12.1 Reserved CX directive names

Reserved directive names (the `[?Name …]` head position) are the
closed set fixed by [`core/code.md`](../core/code.md) §4.1 and
mirrored in `grammar.ebnf [127e]` ProgramDirName. Only the CX project
may extend this set; user `[?def]` MUST NOT shadow a reserved name,
and `[?<Name>]` with `Name` outside the closed set raises
`cx-err:CXER0100` (PARSE_ERROR) at parse time.

**Core control flow + bindings.** `[?match]`, `[?if]`, `[?else]`, `[?for]`,
`[?for-array]`, `[?for-map]`, `[?let]`, `[?fn]`, `[?def]`, `[?const]`,
`[?lib]`, `[?pipe]`, `[?map]`, `[?reduce]`, `[?modify]`,
`[?with-open]`, `[?with-scope]`, `[?str]`.

**Iterator combinators.** `[?filter]`, `[?take]`, `[?drop]`,
`[?zip]`, `[?enumerate]`, `[?chunks]`, `[?concat]`, `[?chain]`,
`[?cycle]`, `[?scan]`, `[?flatten]`, `[?partition]`, `[?group-by]`,
`[?to-sequence]`, `[?to-array]`, `[?to-map]`, `[?view]`, `[?views]`.

**Resilience.** `[?retry]`, `[?timeout]`, `[?circuit-breaker]`,
`[?fallback]`, `[?rate-limit]`, `[?bulkhead]`.

**Services + clients.** `[?http-service]`, `[?service-handle]`,
`[?http-client]`.

**Concurrency.** `[?worker]`, `[?worker-handle]`, `[?channel]`,
`[?send]`, `[?receive]`, `[?try-send]`, `[?try-receive]`, `[?close]`,
`[?select]`.

**Lifecycle (shared by services + concurrency).** `[?stop]`,
`[?wait-for]`.

**Async.** `[?async]`, `[?await]`, `[?await-all]`, `[?await-any]`,
`[?await-race]`, `[?cancel]`, `[?check-cancel]`, `[?sleep]`.

**Document-level CX directive family** (`[?cx <name> …]`, distinct
from the closed `[?<Name>]` set above and reserved as a two-token
head): `[?cx include=…]` ([`core/code.md`](../core/code.md) §13),
`[?cx max-eval-depth=…]` ([`modules/cx.md`](../modules/cx.md) §3),
plus the XML-declaration sibling `[?xml …]`
(`grammar.ebnf [33]`).

Authors of CX schemas and custom data formats may freely use `if`,
`for`, `match`, etc. as ordinary data element names — the `?` sigil
is not a NameStartChar, so the directive production cannot collide
with the element production. The reservation applies only to the
`[?Name …]` (and `[?cx <name> …]`) head positions.

The canonical source for this list is [`core/code.md`](../core/code.md)
§4.1; any directive added or removed there MUST be reflected here in
the same PR per §10.1.

### 12.2 Reserved file extensions

| Extension | Description |
|---|---|
| `.cx` | CX document |
| `.cxs` | CX schema |
| `.cxbin` | CXCol binary wire format (formerly `.cxcol`) |

Reservation means the CX project's CLIs, LSP, editors, and registry
metadata recognize the extension as CX-related. Third-party tooling
SHOULD NOT claim these extensions for unrelated purposes.

---

## 13 — Spec corpus governance

The spec corpus stays internally consistent by construction. Three
rules govern admission of new specs and amendments to existing ones.

### 13.1 Rule G1 — Mutual compatibility

A new spec file is admitted only when it is mutually compatible with
every spec already accepted in
`spec/{core,std-lib,modules,misc,process}/`. The accepted set is the
gate-keeper for every new admission.

- Admission order matters. The first admission defines substrate;
  subsequent admissions narrow, never widen.
- Conflict between a candidate and the accepted set: the candidate
  yields, or it opens a separate cycle to amend the accepted spec
  (which itself re-enters review against the rest).
- No "we'll reconcile later."

Drift between admitted specs is silent corruption — it never trips a
grep but compounds with each admission. Every admission MUST run the
directed drift audit:

1. **Section-citation audit.** For every `core/X.md §Y.Z` /
   `grammar.ebnf [NN]` / `ast.md §...` reference in the candidate,
   open the cited target and verify it contains what the citation
   claims.
2. **Shared-vocabulary audit.** Every node type, type name, axis name,
   error code, capability bit, directive name, namespace URI, or
   reserved-prefix URI mentioned in the candidate must exist in the
   admitted set with the same definition.
3. **Surface-form audit.** Every CX code example in the candidate must
   parse against admitted `core/grammar.ebnf`.
4. **Shared-topic contradiction audit.** For every topic the candidate
   covers that is also covered by an admitted spec, compare statements
   side-by-side.
5. **Open/closed-set audit.** Where the admitted set declares a set
   closed, the candidate matches the enumeration or updates it. Where
   open, the candidate may extend.
6. **Bidirectional impact.** If the candidate implies an admitted spec
   needs an update, the admitted spec is edited as part of the same
   admission. This is the only sanctioned way to amend an accepted
   spec.
7. **Self-consistency + concept inventory.** Every named symbol,
   function, capability bit, error code, mode, class, tag, or concept
   the candidate introduces is defined exactly once. Retired/legacy
   language about X agrees across the file. Every label referenced in
   prose appears in the corresponding table/section/registry.

Findings are classified:

- **Drift** — citation/pointer resolves to the wrong target after the
  target spec was reorganized. Mechanical fix; batch-reviewed.
- **Inconsistency** — two specs make contradictory normative claims
  about the same topic. Design call; per-case review.

### 13.2 Rule G2 — Concise, terse, clear

Specs are tight:

- Normative statements (MUST/SHALL/MAY): one sentence each, not
  paragraphs.
- Tables over prose where structure repeats.
- One example per concept.
- No history sections, no "Rationale:" sections, no version-evolution
  prose in the spec body.
- Cross-references over inline restatement.

A file that grows without need violates G2 and is bounced back for
shortening.

### 13.3 Rule G3 — User-only approval to graduate

The executor (any session, any model) submits a candidate file with a
G1 audit report, then stops. The user reviews and explicitly approves
the move to the destination directory. Without explicit approval, the
file remains in review.

The rule applies recursively: archiving an inline-source file is part
of the same approval gate as the target's graduation. (Batch
admissions may waive per-file approval under direct user instruction.)
