# CX Governance Specification

**Status:** Current

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

The first audit artifact is not yet present; `spec/binding_audit_YYYY.md`
lands at the first annual audit cycle. This section is informational
now and becomes enforcement (a release blocker if missing for a
given annual cycle) in a future cycle.

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

Currently ships without `spec/conformance_registry.md`; the registry file
is created when the first third-party binding submits a conformance
claim. This section is informational now and becomes enforcement
(a missing registry entry blocks a third-party "conformant" claim) in
a future cycle.

---

## 9 — Versioning policy

### 9.1 CX language version

Declared in `core/grammar.ebnf` header and in `[?cx version=X.Y]`
directives:

- **Major** (`X+1.0`): incompatible grammar changes. **Source** migration
  is tooling-assisted sweeps over the corpus (the shipped fmt-sweep lane —
  closed template set, loud residue, output oracle, fail-closed per file,
  never regex); **data** never migrates destructively — values, events,
  and stored docs evolve **additively** per
  [`schema_event_evolution.md`](../core/schema_event_evolution.md)
  (stream 21: identity is schema-independent; upcasters are read-side;
  migration is always additive — nothing a grammar major does can strand
  recorded history).
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

### 9.5b Content-address stability

**RULED: AD-3** (issue #1183, `ledger/rulings_2026_09_01_adoption_campaign.md`).

Tier-1 content addresses — and every pin derived from one: a package
manifest's `hash=`, an instance binding's `of=`, a `code:` address, an
adopter's stored references — are **stable across PATCH versions**.

- **Through 1.0**, a MINOR version MAY move addresses, but ONLY as a
  **declared canonicalization repair**. Silent movement is a defect, not a
  release note.
- **After 1.0**, moving an address requires a MAJOR version bump.

A canonicalization repair is a soundness fix and must stay cheap to ship;
what makes it safe is that it carries its own migration, mechanically:

1. **A machine-readable declaration in the release artifact** —
   `[address-migration release=X.Y.Z [class name=… detail=… ]…]`, one
   `[class]` per document class whose canonical bytes moved (for the
   v0.17.0 repair those were: documents carrying any of five operator <!-- version-literal-ok: names which document classes the historical v0.17.0 address repair covered, which is the worked example this clause generalizes -->
   heads, floats, or date/datetime attribute values). Naming the classes as
   DATA is what lets an adopter test their own corpus instead of reasoning
   about prose.
2. **A re-derivation command** — `cx address recheck`, which takes a set of
   stored pins plus the tree they point into and reports each as
   `resolved`, `moved to=<new address>`, or `unresolved`. Exit 0 when every
   pin resolves, 1 when any moved or is unresolved, 2 on usage/load
   failure — the `cx schema compat` convention.

The failure this closes is specific: a stale `of=` refuses with `CXER4879`,
which is the mechanism working, so an address that MOVED is indistinguishable
from a pin that is legitimately stale. The declaration plus the command are
what tell the two apart.

Conformance pairs a document in a moved class with one outside it, so the
class boundary is testable rather than described.

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
| `CXER0001–CXER0009` | Generic-core panic + core-internal failures (0001 = `CX_PANIC`, runtime `!`; 0003 = RE2 shim internal failure/OOM, shipped `vcx/cx/regex_re2.v`; rest reserved) | `spec/core/code.md` §9.2 / §9.4 |
| `CXER0100–CXER0299` | CX language core (directive errors) | `spec/core/code.md` §9.4 |
| `CXERLEX-*` (named suffix, non-numeric) | Lexical-layer rejects defined by the formal token grammar. Shipped: `CXERLEX-CODEPOINT` (a `\u`/`\U` escape or `&#…;` char-ref decoding to a surrogate or > U+10FFFF — lexicon [L32] / grammar [67]); `CXERLEX-RANGE` (sized `iN`/`uN` ascribed value out of range — grammar [55] / lexicon [L25d]). Registered at I1 stream 13; the sub-namespace is append-only and owned by the formal files (invariants 1–4 apply to the suffix names) | `spec/03-approved/formal/lexicon.ebnf` |
| `CXER1100–CXER1149` | `cx-stdlib/store` (sparse: 1100, 1101, 1110, 1113–1119, 1120, 1121, 1130–1132, 1140–1145) — the last three of the 1113 run = the stream-5 computation-cache admission refusals; the last two of the 1140 run = `E_STORE_SUBJECT_UNSUPPORTED` + `E_STORE_SHREDDED`, the erasure/compliance store surface shipped at I5 stream 20; the band's remaining tail stays reserved for that surface | `spec/std-lib/store.md` §13 |
| `CXER1200–CXER1205` | `cx-stdlib/ft` (full-text) | `spec/std-lib/ft.md` |
| `CXER1300–CXER1306` | `cx-stdlib/email` | `spec/std-lib/email.md` |
| `CXER1400–CXER1403` | `cx-stdlib/url` | `spec/std-lib/url.md` |
| `CXER1500, 1502–1504` | `cx-stdlib/csv` (1501 reserved) | `spec/std-lib/csv.md` §5 |
| `CXER1600–CXER1609` | `cx-stdlib/validate` (1600–1605 shipped earlier; 1606 `E_VALIDATE_NOT_AN_ENUM` added 2026-09-01 with `enum-values`, RULED: EN-3 #1156 — a resolved type carrying no `[enum …]` is a CATEGORY error, distinct from a malformed schema (1603, which would blame a well-formed one) and from an unknown `type=` (1601); the block was extended from 1605 to 1609 rather than reusing a code, since jsonschema starts at 1610 and the four spare numbers sit in validate's own neighborhood; 1607–1609 reserved) | `spec/std-lib/validate.md` §6 |
| `CXER1610–CXER1619` | `cx-stdlib/jsonschema` (1610 shipped; rest reserved) | `spec/std-lib/jsonschema.md` |
| `CXER1700–CXER1712` | CXStore Remote Protocol (CSRP) — `E_CSRP_*`. **RESERVED (retired, never reused) as of stream-4 S3 (2026-08-08, #676): the CSRP data plane is deleted; the store wire is the XSP store profile (`CXER50xx`) with the gRPC edge. The op contracts these codes named carried forward to the profile; the codes themselves are not reissued.** `CXER1704` was already a TOMBSTONE (I1 row 15 / audit M21): ref-conflict unifies on `CXER1114 E_STORE_REF_CONFLICT`. Historical: `spec/misc/cxstore-remote-protocol.md` (retired) | — |
| `CXER1720` | CSRP integrity mismatch (`E_CSRP_INTEGRITY_MISMATCH`) | `spec/misc/cxstore-remote-protocol.md` |
| `CXER1721` | CSRP not found (`E_CSRP_NOT_FOUND`) | `spec/misc/cxstore-remote-protocol.md` |
| `CXER1800–CXER1801` | `cx-stdlib/uuid` | `spec/std-lib/uuid.md` |
| `CXER1900–CXER1906` | `cx-stdlib/random` | `spec/std-lib/random.md` |
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
| `CXER3400–CXER3412` | `cx-stdlib/io` | `spec/std-lib/io.md` |
| `CXER3450–CXER3459` | `cx-stdlib/term` (3450–3451 shipped; rest reserved) | `spec/std-lib/term.md` |
| `CXER3500–CXER3504` | `cx-stdlib/locale` | `spec/std-lib/locale.md` |
| `CXER3600–CXER3605` | `cx-stdlib/geo` | `spec/std-lib/geo.md` |
| `CXER3700–CXER3721` | `cx-stdlib/crypto` (3700–3707 core primitives, 3702 reserved; 3708–3719 JWT/JWKS verify; 3720 `E_CRYPTO_DECRYPT_FAILED` — a CBC padding failure or an OAEP decode failure, registered 2026-09-11 with the XML-Encryption primitives, RULED: 1400-a. The `pkcs1-v1_5` decrypt arm NEVER raises it: a padding failure there answers a deterministic pseudo-random plaintext (RFC 8017 implicit rejection), because an error value is a Bleichenbacher oracle as surely as a timing difference is. A GCM tag failure stays 3704; 3721 `E_XML_SIGN_ARG_INVALID` — `xml-sign`'s caller-fault refusal, registered 2026-09-12 with the enveloped XML-DSig signer, RULED: 1394-b. The signer is `crypto`'s and not `saml`'s because what signs is a primitive handed key material, exactly as `rsa-sign` and `jwt-sign` are, and saml.md S-6's verify core stays a verify core. 3721 is ALWAYS the caller's own error — an `opts.id` naming no element or two of them, a document that is not well-formed, an unknown `key-info`, `:x509` with no readable certificate, `:key-name` with no name, an `after` no child carries, a schema whose signature position this module does not know — because this verb is handed a document the caller built and a placement the caller chose. A key it cannot sign with, and a `digest` off the roster (SHA-1 included: 1410-a's opt-in is verify-only and there is no signing counterpart), stay 3700, the code every other malformed-key path in the module answers; 3722–3799 reserved) | `spec/std-lib/crypto.md` |
| `CXER3800–CXER3805` | `cx-stdlib/i18n` | `spec/std-lib/i18n.md` |
| `CXER3900–CXER3902` | `cx-stdlib/html` | `spec/std-lib/html.md` |
| `CXER4000–CXER4013` | `cx-stdlib/process` | `spec/std-lib/process.md` |
| `CXER4100–CXER4119` | `module-cx` | `spec/modules/cx.md` |
| `CXER4200–CXER4209` | `module-sqlite` | `spec/modules/sqlite.md` |
| `CXER4300–CXER4309` | `module-tree-sitter` | `spec/modules/tree-sitter.md` |
| `CXER4400–CXER4409` | `cx-stdlib/fp` (functor/monad protocol; `CXER4400 E_NO_INSTANCE`) | `spec/std-lib/fp.md` |
| `CXER4500–CXER4524` | `cx-stdlib/net` (L4 networking — `E_NET_*`; allocated above fp's 4400-band) | `spec/03-approved/std-lib/net.md` |
| `CXER4525–CXER4589` | `cx-stdlib/http` (L7 HTTP/1.1 client + server — `E_HTTP_*`; allocated above net's 4500-band; 4544–4589 SSE/streaming) | `spec/03-approved/std-lib/http.md` |
| `CXER4600–CXER4649` | `cx-stdlib/journal` (append-only hash-chained event log + fold→state — `E_JOURNAL_*`; sub-partitioned 2026-08-05, amended at I5 stream-20 exit: 4617 `E_JOURNAL_RESUME_GAP` (U1 delivery) and 4618 `E_JOURNAL_TEMPORAL_INVALID` (stream 8) shipped post-sub-partition ahead of the erasure reservation, which now runs 4619–4639 — 4619 `E_ERASURE_NONCE_REQUIRED` / 4620 `E_ERASURE_HOLD_INVALID` / 4621 `E_ERASURE_HELD` / 4622 `E_ERASURE_RECORD_RESERVED` shipped I5 stream 20, 4623–4639 remain reserved for that surface; 4640 `E_JOURNAL_FOLD_ID_MISMATCH` shipped I5 stream 21, 4641–4649 remain reserved for schema/event evolution). **`CXER4604` is a TOMBSTONE (I1 row 15 / audit M21): retired in favor of `CXER1114 E_STORE_REF_CONFLICT` — every optimistic-concurrency conflict unifies on the one ref-conflict code (the CSRP `CXER1704` retired with it); neither is ever reassigned** | `spec/03-approved/std-lib/journal.md` |
| `CXER4650–CXER4699` | `cx-stdlib/bus` (in-process pub/sub, ordered dispatch — `E_BUS_*`) | `spec/03-approved/std-lib/bus.md` |
| `CXER4700–CXER4799` | `cx-stdlib/authz` (authorization / trust model — `E_AUTHZ_*`) | `spec/03-approved/std-lib/authz.md` |
| `CXER4800–CXER4849` | `cx-stdlib/session` (`(principal, tenant)` sessions — `E_SESSION_*`). `E_SESSION_REPLAY`, `E_SESSION_LINK_REFUSED` and `E_SESSION_REPLAY_OPTOUT_REFUSED` allocated 2026-09-12 inside this band (RULED: 1405-a, 1394-b; `ledger/rulings_2026_09_11_replay_defense_1405.md`, `ledger/rulings_2026_09_12_sso_enterprise_complete_1394b.md`) — the replay table's refusal and its configuration refusal, and the identity-link table's four refusals under one code. The band's tail stays unallocated | `spec/03-approved/std-lib/session.md` |
| `CXER4850–CXER4889` | `cx-xap` subsystem (`E_XAP_*`: xap host/runtime + compose surface 4850–4879; xap-dist 4880–4889). **4864 `E_XAP_VERB_NOT_OFFERED`** allocated 2026-09-01 (issue #1181, RULED: AD-1, `ledger/rulings_2026_09_01_adoption_campaign.md`) — ρ refuses a verb an instance binding's SELECT withdrew, carrying the authored `why=`; deliberately distinct from 4872 `E_XAP_VERB_UNKNOWN` because "this deployment does not offer it" and "no such verb" are different facts and only the first is authored to be shown. **4865–4869 are SPENT and the §4.9 sub-band is FULL.** `4865 E_XAP_RULE_REFUSED`, `4866 E_XAP_CARDINALITY`, `4867 E_XAP_FIELD_TYPE`, `4868 E_XAP_TRANSITION` allocated 2026-09-05 (issue #1301–#1304, RULED: 1308-CG-2/CG-3/CG-4, `ledger/rulings_2026_09_05_constraint_grammar_1308.md`) and **`4869 E_XAP_PARAM_UNDECLARED`** allocated 2026-09-08 (issue #1268, RULED: 1268-d, `ledger/rulings_2026_09_08_pump_ingest_fields_1268.md`) — the five grammar-declared refusals raised at the one pre-commit enforcement point, `4869` first in their evaluation order. The reserve `4869` held is therefore gone: the NEXT refusal class discovered at that point needs a **band decision** taken with knowledge of what it is for, because `4880–4889` are allocated to xap-dist and growing past `4879` would leave the registered allocation. Registered 2026-08-05 — xap.md §8's original 4850–4949 proposal is amended in place: 4890–4949 yielded (see the similar island and fabric rows below; audit C5) | `spec/03-approved/xap/xap.md` §8 |
| `CXER4890–CXER4899` | `cx-xap` distribution — the package schema-evolution seam (`E_XAP_PKG_SCHEMA_REINTERPRETS` 4890, `E_XAP_PKG_COVERAGE_GAP` 4891; RULED: SEA-1, `ledger/rulings_2026_08_20_schema_evolution_automation.md`; 4892 `E_XAP_PKG_CONTRACT_REINTERPRETS` (issue #1182, RULED: AD-2 — the CONTRACT half of the same seam: a `.feature.cxd` whose change REINTERPRETS what consumers compose against (a removal, a declared rename, a field type or cardinality change, a `[key]` whose `via=` moved, a verb whose `[intent]` parameter list changed) refuses the publish unless an authored `[contract-lineage]` claim covers the exact old→new pair. Sibling of 4890 and deliberately distinct from it: 4890 is the schema a consumer does not compose against, 4892 is the contract it does. Additive changes publish silently and narrowing ones publish classified, so only reinterpretation stops); 4893–4899 reserved for this seam). Registered 2026-08-20 (RULED: UOM-1 rider r3 — the codes shipped with SEA-1 without their registry row; this re-occupies the head of the 4890–4949 gap yielded 2026-08-05, below the similar island at 4900) | `spec/03-approved/xap/xap_feature_distribution_market.md` §9 error table |
| `CXER4900–CXER4901` | `cx-stdlib/similar` (island: shipped inside the pre-amendment xap proposal; regularized by the 2026-08-05 xap.md §8 yield — the 4900/4901 collision that triggered audit C5) | `spec/std-lib/similar.md` §7 |
| `CXER4902–CXER4919` | `cx-xap` subsystem — the served bridge's attribution surface (`E_XAP_SERVE_UNATTRIBUTED` 4902; 4903–4919 reserved for this surface). Registered 2026-09-12 (issue #1292, RULED: 1292-a, `ledger/rulings_2026_09_12_sessions_on_the_bridge_1292.md`) — the **band decision** the row above says the next xap refusal class needs, taken with knowledge of what it is for: `[$xap:serve]` gained a `session:` configuration and, with it, a BOOT refusal for a journal-bound runtime that nothing would attribute. It could not join `CXER4850–CXER4889`: `4850–4879` is spent (the §4.9 sub-band closed at 4869), `4880–4889` is xap-dist's, and `4885` is reserved unallocated for partial-consent semantics, so reusing any of them would make one code mean two failures the spec separates. This range is one the 2026-08-05 amendment returned to the unallocated pool, between the `similar` island at 4900–4901 and `fabric` at 4920 | `spec/03-approved/xap/xap.md` §8 |
| `CXER4920–CXER4949` | `cx-stdlib/fabric` (`E_FABRIC_*`) | `spec/std-lib/fabric.md` |
| `CXER4950–CXER4969` | cross-stream coordination — the choreography/escrow vocabulary (campaign stream 10, #682, `E_COORD_*`). `CXER4950` / `CXER4951` are the `[requires-at]` pin refusals: the stale-pin refusal at the admission read, and the unevaluated-pin fail-closed refusal on direct invocation of a pinned command. The band's TAIL, `CXER4952–CXER4969`, is occupied by **`cx-stdlib/flow`** — the general workflow module that retired stream 10's saga surface cutover-first (RULED: 789-WF-0); its per-code rows are listed in `std-lib/flow.md`, *Error codes*, not here. Registered 2026-08-12 before first use per this file's invariant; the tail's occupant named at `flow`'s W1 landing | `spec/03-approved/std-lib/flow.md`; `spec/_archived/cross_stream_coordination.md` §2/§5 |
| `CXER4970–CXER4989` | `cx-stdlib/sched` (scheduled events & timers — `E_SCHED_*`) | `spec/03-approved/std-lib/sched.md` |
| `CXER4990–CXER4999` | `cx-core/consistency` (campaign stream 7, #679 — the declare-and-verify guarantee vocabulary, `E_CONSISTENCY_*`: the unsatisfiable-declaration primary + the uncoverable-pin companion; the remainder of the band reserved for this vocabulary. Registered 2026-08-11; the sweep's original proposal inside the XAP band was corrected to this verified-free band at the S3 recording — L125) | `spec/03-approved/core/consistency_vocabulary.md` §5 (normative landing: `spec/03-approved/std-lib/journal.md` §4.4 first; store/fabric/xsp rows follow with their stream-7 waves) |
| `CXER5000–CXER5049` | XSP generic layer + store profile (campaign stream 4, L166; per-code rows LANDED with the W3 implementation per #717 — sub-block 5000–5009 = the generic frame/session layer, the numeric cutover of the retired symbolic `CXER-XSP-*` spellings; 5010–5021 = the store profile (5019–5021 landed with the W4 feed/authority implementation), 5022–5049 reserved for the W5 rows; the CSRP `17xx` band is marked Reserved/retired at CSRP retirement, never reused) | `spec/03-approved/xap/xsp_store_profile.md` §4.2 |
| `CXER5050–CXER5069` | store/journal sync — distributed store (campaign stream 9, #681, `E_SYNC_*`; the first three codes shipped with the W1 stream-ingestion implementation — the divergent-stream refusal, the invalid-chain refusal, the reserved-target refusal; the fourth with the W2 reconciliation engine — the enforcing reconcile's diverged raise, carrying every `[conflict]` value; the band's remaining tail stays reserved for the sync surface. Registered 2026-08-12 before first use per this file's invariant) | `spec/03-approved/std-lib/distributed_store.md` §8 |
| `CXER5070–CXER5089` | `cx-stdlib/live` — live modes / incremental evaluation (campaign stream 3, #675; relocated 2026-08-05 from the colliding 4902–4919 proposal — audit C5, band pre-registered per invariant "added here before being used"). Per-code rows live in the pack spec §9: 5070–5078 assigned; 5070–5078 ALL SHIPPED: 5070–5073 with the W1 `changes-since` implementation, 5074–5075 with the W2 `observe` implementation, 5076 with the W3 `materialize` implementation, 5077–5078 with the W4 adapter contract (#717 same-change discipline); 5079–5089 reserved. Reused, never duplicated: `CXER0120`/`CXER4700`/`CXER1114` | `spec/03-approved/std-lib/live.md` §9 (band claimed at `spec/_archived/live_modes.md` §2) |
| `CXER5090–CXER5109` | `cx-stdlib/supervise` — restart policies over monitored workers (`E_SUP_*`; issue #765, RULED: SUP-1 — registered 2026-08-20 with the graduation + implementation, next free block above live's `5070–5089`, band-scan confirmed). 5090 `E_SUP_ARG_INVALID` (malformed policy/child spec), 5091 `E_SUP_DUPLICATE_CHILD`, 5092 `E_SUP_UNKNOWN_CHILD` (RESERVED — v1 has no verb that requires a child: `stop-child` of an unknown name returns `false`, a value), 5093 `E_SUP_CLOSED` (ops on a stopped supervisor; `status` stays readable), 5094 `E_SUP_RESTART_INTENSITY` (the give-up terminal on the loop worker — the escalation carrier, observed by parents in the `CXER0220` panic's cause chain), 5095 `E_SUP_NO_SCHED` (issue #895, RULED: SPF-1 — `start` refuses AT COMPOSITION in a build with the `sched` local-effect pack excluded, naming the pack and what it is needed for: backoff delays, the intensity window and per-child attempt-reset. Argument validation runs FIRST and is profile-independent, so `5090`/`5091` remain the answer to a malformed policy or spec in every build); 5096–5109 reserved. Reused, never re-coded: a child's own `[err]` (any code) rides `[child-exited]` as `err-code=`; cancellation is `CXER0260`/`CXER0221`; a child's capability denial is `CXER0271` at the child's own effect point; the events-laggard gap is the channel contract's `CXER0218` | `spec/03-approved/std-lib/supervise.md` §8 |
| `CXER5200–CXER5299` | `cx-stdlib/zip` — zip archive codec over bytes (`E_ZIP_*`; issue #1078, RULED: Z-6 — registered 2026-08-28 with the graduation + implementation, next free hundred-block above supervise's `5090–5109`, band-scan confirmed). 5200 `E_ZIP_MALFORMED` (structural violation: bad signature, truncation, header disagreement, non-UTF-8 stored name), 5201 `E_ZIP_UNSUPPORTED` (encryption, compression method ∉ {store, deflate}, multi-disk, EOCD beyond the scan window — zip64 LEFT this list when #1095 stage 2 implemented it, RULED: Z-8.1), 5202 `E_ZIP_ENTRY_NOT_FOUND` (`extract` miss), 5203 `E_ZIP_ENTRY_INVALID` (pack entry shape / §2 name hygiene / duplicate name), 5204 `E_ZIP_CRC_MISMATCH` (payload fails its stored CRC-32), 5205 `E_ZIP_LENGTH_EXCEEDED` (pack output would exceed the bytes 2^32-1 ceiling; or decoding an entry whose uncompressed size exceeds it); 5206–5299 reserved | `spec/03-approved/std-lib/zip.md` §8 |
| `CXER5300–CXER5399` | `cx-stdlib/oidc` — the OpenID Connect relying party (`E_OIDC_*`; issue #1090, RULED: O-8 — registered 2026-08-29 with the graduation + implementation, next free hundred-block above zip's `5200–5299`, band-scan confirmed). Each ID-token check gets a DISTINCT code on purpose: an integration that cannot tell "wrong nonce" from "expired" cannot be debugged. 5300 `E_OIDC_DISCOVERY_FAILED` (non-2xx / transport fault / not a discovery document), 5301 `E_OIDC_ISSUER_MISMATCH` (the discovery document names a different issuer than was asked for — the mix-up check — or an ID token's `iss` differs from the provider's), 5302 `E_OIDC_CONFIG_INVALID` (missing client-id/redirect-uri, non-https endpoint without the loopback allowance, malformed provider), 5303 `E_OIDC_PROVIDER_ERROR` (the IdP's own `error`, surfaced verbatim from the callback or the token endpoint), 5304 `E_OIDC_CALLBACK_INVALID` (no `code`), 5305 `E_OIDC_BINDING_MISMATCH` (`state` or `nonce` disagrees with the `[auth-request]`), 5306 `E_OIDC_TOKEN_EXCHANGE_FAILED`, 5307 `E_OIDC_CLIENT_AUTH_INVALID`, 5308 `E_OIDC_CLAIM_INVALID` (`aud` / `azp` / `at_hash` / `auth_time`), 5309 `E_OIDC_LOGOUT_TOKEN_INVALID` (missing the logout event or `sub`/`sid`, or carrying a `nonce` — an ID token replayed as a logout token), 5310 `E_OIDC_ARG_INVALID`; 5311–5399 reserved. Reused, never re-coded: signature / expiry / `alg` answers stay `crypto`'s `CXER371x` and propagate UNCHANGED; a capability denial is `CXER0271` at the effect point | `spec/03-approved/std-lib/oidc.md` §7 |
| `CXER5400–CXER5499` | `cx-stdlib/saml` — the SAML 2.0 service-provider verify core (`E_SAML_*`; issue #1091, RULED: S-7 — reserved 2026-08-29 with the ruling, per-code rows registered 2026-09-04 ahead of the implementation, band-scan confirmed free at registration). Blame is split the #1100 way, three-handed as in `scim`: the IdP sent something broken, the IdP sent valid SAML this module declines, or the CX caller misused a verb. The refusals are deliberately FINE-GRAINED, because an integration that cannot tell "the signature did not verify" from "the signature verified a different element than the one you are about to read" cannot be debugged, and the second is the whole wrapping-attack class. 5400 `E_SAML_MALFORMED` (the IdP's fault: not well-formed XML — including XML 1.0 §3.1 duplicate attribute names, which this module refuses itself rather than inheriting the core parser's tolerance, RULED S-9 — or well-formed XML that is not a SAML `Response`/`Assertion`, which from 2026-09-12 by RULED: 1404-a INCLUDES a `@Version` that is absent or is not `"2.0"`. SAML Core §2.3.3 makes `Version` [Required] and fixes it at "2.0"; it is read on the DOCUMENT ELEMENT in `verify` step 1, before the signature search, so the answer is "this is not a SAML 2.0 document" and not a refusal about a signature inside one, and again on the `Assertion` in `assertion`, which is the element every later verb consumes. Two places because they are two different integration problems — an endpoint wired to a SAML 1.1 identity provider, and a document mixing versions, which no honest identity provider emits — and 5400 rather than a new code because §7's wording already covers exactly this), 5401 `E_SAML_SIGNATURE_MISSING` (no signature anywhere in the document, or a verified subtree that carries no `Assertion` to consume — an unsigned `Assertion` INSIDE a signed `Response` is covered, not missing: saml.md §4.2), 5402 `E_SAML_SIGNATURE_INVALID` (a signature in an admitted position does not verify against the supplied keys — and EVERY signature present must verify; a bad one beside a good one is 5402, never skipped), 5403 `E_SAML_REFERENCE_INVALID` (the wrapping class proper: a `Reference URI` resolving to no element, to MORE than one element because `ID` is duplicated, or to any element but the signature's own parent; a signature outside the two admitted positions; an `Assertion` left outside the verified subtree; more than one `Assertion` to choose from — RULED S-2/S-3 — and equally a DIGEST MISMATCH, which is the same statement in arithmetic: the content the reference names is not the content that was signed. Distinct from 5402 on purpose: 5403 means the content moved, 5402 means the key is wrong, and an integration that cannot tell them apart cannot be debugged — the first is an attack signal, the second is usually a rotation), 5404 `E_SAML_TRANSFORM_UNSUPPORTED` (valid XML-DSig this module declines: any transform beyond enveloped-signature + exclusive C14N — inclusive C14N, XPath, XSLT — refused loudly and never best-effort, RULED S-4), 5405 `E_SAML_ALGORITHM_REFUSED` (valid XML-DSig this module declines on policy: SHA-1 digests and signatures, and anything outside `crypto` §3.8's RSA PKCS#1 v1.5 / PSS and ECDSA P-256/384/521 with SHA-256/384/512 — a decision on the same footing as crypto's HS\* refusal, RULED S-5. The SHA-1 half gained a per-deployment escape 2026-09-11 by RULED: 1410-a: `xmldsig#rsa-sha1` and `xmldsig#sha1` are accepted under `opts.allow-sha1` and LOGGED AT EVERY USE, because ADFS tenants still emit them and the only other remedy is on the customer's side; `dsa-sha1` and `hmac-sha1` have no opt-in, and the enforcement stays structural — `crypto_digest_info` still has no `sha1` row, so the opt-in arm is the tree's only path to a SHA-1 signature), 5406 `E_SAML_CONDITIONS` (the assertion's own `Conditions` refuse it: outside `NotBefore`/`NotOnOrAfter`, or an `AudienceRestriction` the caller's `audience` does not satisfy — and, from 2026-09-12 by RULED: 1404-a, a `Conditions` CHILD OR ATTRIBUTE this module does not evaluate. SAML Core §2.5.1.1 rule 3 is a MUST: an element "not understood" makes the assertion Indeterminate and "an assertion that is determined to be Invalid or Indeterminate MUST be rejected by a relying party", so `Conditions` is read against an ALLOW-LIST — `AudienceRestriction`, `OneTimeUse`, `ProxyRestriction`, and the two attributes `NotBefore`/`NotOnOrAfter` — with an abstract `<saml:Condition xsi:type=…>` unrecognized BY CONSTRUCTION. Ungated by `opts.strict`, unlike the absence refusals 1397-a added: a lenient reading of a MUST is a reading of a different specification. `OneTimeUse` and `ProxyRestriction` are RECOGNIZED AND VALID rather than refused — the first constrains the relying party's caching and the second a relying party that re-issues, which this one never does — and `OneTimeUse` is SURFACED to `claims` instead, beside the `jti` 1405-a projects, because honouring it needs state this module does not hold), 5407 `E_SAML_SUBJECT_INVALID` (the binding to THIS request disagrees: `SubjectConfirmationData`'s `InResponseTo`/`Recipient`/its own expiry, or the `Response`'s `InResponseTo`/`Destination`), 5408 `E_SAML_ARG_INVALID` (the CX caller's fault, not the IdP's: a verb handed something that is not a SAML element, or an opts map missing what the check it asks for requires — `now` for `validate`), 5409 `E_SAML_STATUS` (the IdP's OWN refusal, surfaced verbatim: a `Response` whose `Status` is not `Success`, carrying the status code and `StatusMessage` — the counterpart of oidc's 5303), 5410 `E_SAML_ISSUER_MISMATCH` (the `Response` or `Assertion` `Issuer` is not the one the caller named — the counterpart of oidc's 5301), 5411 `E_SAML_UNSUPPORTED` (valid SAML this module declines and no narrower code names: a non-`bearer` subject confirmation method. Its XML-Encryption clause was DELETED 2026-09-11 by RULED: 1400-a — encryption is read now, and its own refusals are 5413 and 5405), 5412 `E_SAML_METADATA` (the metadata document cannot configure a deployment: it carries neither an `IDPSSODescriptor` nor an `SPSSODescriptor`, it is an `EntitiesDescriptor` holding more than one `EntityDescriptor` — picking one is how the wrong entity gets trusted — a `KeyDescriptor`'s `ds:X509Certificate` does not parse, or a signing certificate is outside its validity window at the caller's `opts.now`. Registered 2026-09-11 with the metadata surface, RULED: 1402-a. The CONFIGURATION-time expiry check lives here and only here: `verify` is handed key elements and never consults a certificate, RULED: 1410-b), 5413 `E_SAML_ENCRYPTED` (the document is encrypted and THIS CALL cannot read it: no `opts.decryption-keys` was supplied, no supplied key unwraps the `xenc:EncryptedKey`, or the content did not decrypt — the decryption analogue of 5402, "the key is wrong, or the ciphertext is not what was sent". Registered 2026-09-11 with XML Encryption, RULED: 1400-a / 1401-a. It is deliberately detected BEFORE the signature search: an unsigned `Response` carrying an encrypted, internally-signed assertion — the shape ADFS and Entra send — contains no visible `ds:Signature` and used to answer 5401, sending the operator to check an IdP signing configuration that was correct. An algorithm outside saml.md §6's accepted set stays 5405, as for signatures, and `saml-063` was re-recorded from 5411 to 5413 because the meaning changed by ruling), 5414 `E_SAML_LIMIT` (the document exceeds a READER BOUND the deployment set, not a syntax rule the document broke: `opts.max-bytes` (default 1 MiB), `opts.max-depth` (64), `opts.max-attributes` per element (256) or `opts.max-text-bytes` per text node (256 KiB), each enforced inside the reader BEFORE the allocation it governs and each refusal naming the bound it hit and the key that moves it. Registered 2026-09-11 with the bounds, RULED: 1410-c. Deliberately NOT 5400: this is the `smtp`/`imap` kind of limit — about the PEER'S BEHAVIOUR, not about one message's syntax — and the document that hits one is usually perfectly well-formed. An ACS endpoint is unauthenticated by construction, so the bound has to be the deployment's and not the sender's; a bound that is not a positive integer is the CX caller's own error, 5408), 5415 `E_SAML_BINDING` (the BINDING layer cannot read this message, registered 2026-09-11 with the bindings, RULED: 1402-b — a form body with no `SAMLResponse` or with TWO of them (parameter pollution: there is no rule that picks one), a payload that is not base64, a `RelayState` over the binding specification's 80 bytes, a query string carrying neither binding parameter or both, a payload that is not raw DEFLATE or that inflates past the deployment's `opts.max-bytes`, and an assertion-bearing `Response` arriving over HTTP-Redirect. That last one is a DECISION, not an omission: the Redirect binding signs the query string rather than the document, a placement saml.md §4.2's verify core cannot honour and no IdP in scope emits, so POST is a `Response`'s only binding and both directions refuse it. Deliberately NOT 5400: the octets never became a document, so nothing has been said about the document's syntax — and NOT 5414, which stays the reader's own bound refusal, the code `acs-decode` still answers when the encoded length says the document is bigger than this deployment reads), 5416 `E_SAML_LOGOUT` (what is specific to a LOGOUT message, registered 2026-09-11 with Single Logout, RULED: 1402-b — a document that is neither a `LogoutRequest` nor a `LogoutResponse`, an UNSIGNED one, a `LogoutRequest` that names no single `NameID`, a `LogoutResponse` with no `Status`, and an UNMATCHED one whose `InResponseTo` is not the request `opts.in-response-to` says this caller sent. The unsigned arm is a decision with no opt-in: an unsigned `LogoutRequest` is a forced logout of any user by anyone who learns a `NameID` — no credential, no trace at the IdP — and an unsigned `LogoutResponse` is the same failure with the states exchanged. The signature check is the SAME code `verify` runs, so its refusals keep their own codes: a bad signature is still 5402 and a signature in a position that is not admitted is still 5403; 5416 never absorbs them), 5417 `E_SAML_SIGN_REQUIRED` (a document this module KNOWS must be signed and was handed no key, registered 2026-09-12 with the signed emitters, RULED: 1394-b — an `AuthnRequest` emitted from an `[sp authn-requests-signed=true]`, whose own published metadata promises the IdP a signed request, and either logout message, which `logout-parse` refuses unsigned at the far end. Deliberately NOT 5408: the caller's arguments are all well formed and the verb can name exactly what is missing and why, which 5408's 'you handed this verb the wrong thing' does not say; and deliberately NOT 5416, which stays the READER's refusal over a message that arrived. The emitters PRODUCE no signature: `opts.sign` carries the SP's signing key to `crypto:xml-sign` (crypto.md §3.11) and saml.md S-6's verify core stays a verify core. A key this module cannot name is 5408; a malformed key crypto cannot use is crypto's own `CXER3700`, propagated unchanged); 5418–5499 reserved. Reused, never re-coded: every signature primitive answer stays `crypto`'s `CXER371x` and propagates UNCHANGED (RULED S-5), and a capability denial is `CXER0271` at the effect point — though the module still has no effects at all (RULED S-6: no bindings, no I/O; the metadata half of S-6's exclusion was lifted by RULED 1402-a and its three verbs are pure too) | `spec/03-approved/std-lib/saml.md` §7 |
| `CXER5500–CXER5599` | `cx-stdlib/tar` — the tar archive codec (`E_TAR_*`; issue #1084, RULED: T-9 — registered 2026-08-29 with the ruling, ahead of the implementation). Allocated around `5400–5499`, which the recorded SAML ruling (#1091, S-7) already reserves: allocating around a recorded reservation is cheaper than editing one. 5500 `E_TAR_MALFORMED` (the input is BROKEN — header checksum fails, a numeric field is not valid octal, a payload runs past the buffer, truncation, a malformed pax record), 5501 `E_TAR_UNSUPPORTED` (the input is VALID and this codec declines it — sparse entries, multi-volume, character/block device and FIFO entries), 5502 `E_TAR_ENTRY_NOT_FOUND` (`extract` miss), 5503 `E_TAR_ENTRY_INVALID` (pack entry shape, §2 name hygiene, duplicate name, or a link type with no `link-target`), 5504 `E_TAR_LENGTH_EXCEEDED` (pack output past the bytes 2^32-1 ceiling, or decoding an entry whose size exceeds it); 5505–5599 reserved. The 5500/5501 split is the #1100 rule — malformed vs unsupported tracks WHOSE FAULT it is — and every refusal in the module is classified by that test | `spec/03-approved/std-lib/tar.md` §6 |
| `CXER5600–CXER5699` | `cx-stdlib/scim` — the SCIM 2.0 provisioning semantics (`E_SCIM_*`; issue #1092, RULED: C-7 — registered 2026-08-29 with the ruling, ahead of the implementation, next free hundred-block above tar's `5500–5599`, band-scan confirmed; `5400–5499` stays the SAML reservation of #1091 S-7). The split follows the #1100 rule — malformed vs unsupported tracks WHOSE FAULT it is — and it is drawn a third way here, because SCIM has three distinct blamed parties: the IdP sent something broken, the IdP sent valid SCIM this module declines, or the CX caller passed the verb something that is not a SCIM value at all. 5600 `E_SCIM_INVALID_SYNTAX` (the IdP's fault: a body that is not a well-formed SCIM resource or PATCH request — a missing `schemas`, an `op` that is not add/replace/remove, a patch with no `Operations`), 5601 `E_SCIM_INVALID_FILTER` (a filter string that does not parse under RFC 7644 §3.4.2.2), 5602 `E_SCIM_INVALID_PATH` (a PATCH `path` that does not parse, or that addresses nothing addressable), 5603 `E_SCIM_NO_TARGET` (a path whose value filter selects no member where the operation requires one — the RFC's `noTarget`; NOT raised by `remove` of an absent attribute, which is a no-op per RULED C-3), 5604 `E_SCIM_INVALID_VALUE` (a value of the wrong type, outside an attribute's canonical values, or a required attribute absent), 5605 `E_SCIM_MUTABILITY` (a write to a `readOnly` attribute, or a change to an `immutable` one that already has a value), 5606 `E_SCIM_UNSUPPORTED` (valid SCIM this module declines: bulk operations, sorting, `/Me` — RULED C-2), 5607 `E_SCIM_ARG_INVALID` (the CX caller's fault, not the IdP's: a verb handed something that is not a resource, schema or patch value), 5608 `E_SCIM_PRECONDITION` (registered 2026-09-11 with #1406, RULED: 1406-b — an `If-Match` naming a version the resource does not carry: the RFC 7232 §3.1 strong comparison failed, so the resource changed since the writer read it. 412 at the mount, which is the one status in this band the RFC 7644 §3.12 table gives no `scimType`, so none is invented (#584). It is the IdP's fault in the #1100 split — the header came off the wire — and it is a REFUSAL rather than a last-write-wins, which is what makes `meta.version` a concurrency control rather than an advertisement); 5609–5699 reserved. Reused, never re-coded: bearer-token verification stays `crypto`'s `CXER371x` (RULED C-5) and a capability denial is `CXER0271` at the effect point. The wire-facing SCIM error object (`scimType`/`detail`/`status`, RULED C-8) is a **value this module returns**, not a competing code space: it crosses the wire, CXER codes do not | `spec/03-approved/std-lib/scim.md` §7 |
| `CXER5700–CXER5799` | `cx-stdlib/smtp` — ESMTP submission client and receive server core (`E_SMTP_*`; issue #1085, RULED: 1085-a/1085-b — registered 2026-09-11 WITH the implementation, the `oidc:client-credentials` precedent that a row ahead of the code reds `check-effect-alignment`. `smtp.md` §8's band scan returned nothing anywhere in the tree for `CXER57xx` — no spec, no `.v`, no `.cx`, no `.cxd`, no header — and `5700–5799` was the next free hundred-block above `scim`'s `5600–5699`). Blame is three-handed, the #1100 rule as `scim`, `saml` and `sasl` draw it: the peer sent something broken, the peer asked for something we decline on policy, or the CX caller misused a verb. 5700 `E_SMTP_GREETING_INVALID` (peer — the server's opening reply is not a 220, or is unparseable; carries the reply verbatim), 5701 `E_SMTP_SEQUENCE` (peer — a command out of state; the server answers `503 5.5.1`, and the ordering is checked BEFORE the argument is parsed so a malformed address before EHLO is a state error and not a disclosure of which addresses parse), 5702 `E_SMTP_SYNTAX` (peer — an unparseable command or reply, a malformed path, a syntax bound of §5.2, or a pipelining reply/command count mismatch: a group of five commands answered with four or six replies shifts every later reply onto the wrong command, which is a response-confusion vulnerability and not a performance bug), 5703 `E_SMTP_LINE_ENDING` (peer — a bare LF or bare CR, or a body terminated by anything but `CRLF.CRLF`. Its own code because it is the SMTP-smuggling class and an operator must be able to grep for it; refused in BOTH directions rather than normalized, because normalizing is precisely how a sender and a receiver come to disagree about where a message ends), 5704 `E_SMTP_REFUSED` (peer — a well-formed 4xx/5xx refusal of a command, surfaced verbatim with its code, enhanced status and text, the counterpart of oidc's 5303 and saml's 5409; `[reply]` rides the err, because `550 5.1.1` and `550 5.7.1` are the same three digits and completely different operational answers), 5705 `E_SMTP_CONNECTION_LOST` (peer — the connection closed mid-transaction; carries `net`'s own `[err]` as `[cause]`, never re-coded), 5706 `E_SMTP_TLS_REQUIRED` (declined — STARTTLS not advertised or not completed under `tls=:required`; AUTH attempted on an unprotected connection under ANY setting, because turning off the TLS requirement does not turn on cleartext passwords; buffered plaintext carried across an upgrade, the CVE-2011-0411 class), 5707 `E_SMTP_TLS_POLICY` (declined — an MTA-STS `:enforce` policy the peer's certificate does not satisfy; the policy is consumed as a value, because fetching it is DNS and HTTPS and this module is neither), 5708 `E_SMTP_AUTH_FAILED` (peer — the server rejected the credential; carries the reply so a caller can distinguish "bad password" from "token expired, refresh and retry", and carries `sasl`'s `CXER5903` as `[cause]` when the RFC 7628 error JSON said which), 5709 `E_SMTP_AUTH_UNAVAILABLE` (declined — no acceptable mechanism: AUTH unadvertised while a credential was supplied, a pinned mechanism unadvertised, a class mismatch, or a permanently-refused mechanism named. The registry's own refusal is `sasl`'s `CXER5901` and rides this one as `[cause]`, so the decision is made once for both transports rather than twice — never a silent fall-back, because a client that silently falls back from OAUTHBEARER to PLAIN has just sent a password where it meant to send a token), 5710 `E_SMTP_ARG_INVALID` (the CX caller — a verb handed the wrong element shape, a bind URL given to `submit`/`connect` or a client URL given to `serve`/`listen`, a submit with no envelope and no `envelope-from` (the envelope is NOT the headers: synthesizing one from the other leaks `Bcc`), no EHLO hostname, a second `respond` on one exchange), 5711 `E_SMTP_SIZE_EXCEEDED` (split by direction: client-side, the caller's message exceeds the advertised `SIZE` and is refused BEFORE transmission, because streaming 40 MB to a server that will answer 552 is a reputation event on a shared IP; server-side, the peer exceeded `max-message-bytes` / `max-header-bytes` / `max-headers`, counted against the octets AS RECEIVED because a `SIZE=` declaration is a claim by the sender and a claim is not a bound), 5712 `E_SMTP_UTF8_UNSUPPORTED` (declined — a UTF-8 envelope address or an 8-bit body toward a server advertising neither SMTPUTF8 nor 8BITMIME. Refused before sending rather than downgraded, because an unrequested RFC 6530 downgrade is a silent modification of a message that may be DKIM-signed), 5713 `E_SMTP_LIMIT` (declined — a rate or count bound: `max-rcpt`, `max-commands`, `max-errors`, `max-auth-attempts`, `max-null-commands`, `max-connections*`, the rate window. Distinct from 5711 because a size bound is about one message and a limit is about a peer's behavior, and only the second is a reputation signal; always answered TEMPORARILY, because a count bound is a statement about now), 5714 `E_SMTP_HANDLER_FAILED` (the CX caller — a `serve` handler returned an `[err]`, panicked, or returned a non-verdict; the peer sees `451 4.3.0` and the message is NOT delivered. Fail-closed to a TEMPORARY failure and never an accept: HTTP's equivalent synthesizes a 500, but a permanent mail failure destroys the message while a temporary one asks the sender to try again, and a handler crash is not evidence that the mail is undeliverable); 5715–5799 reserved. Reused, never re-coded: a capability denial is `CXER0271` at the effect point; every socket, DNS and TLS fault stays `net`'s `CXER45xx` and propagates as `[cause]` unchanged; a message that will not parse is `email`'s `CXER1300` and a DSN that is not one is `email`'s `CXER1306`; every SASL credential, framing and mechanism-selection fault stays `sasl`'s `CXER59xx` and rides 5708/5709 as `[cause]`. The `[smtp-reply]` is a value this module returns, not a competing code space — three-digit and enhanced codes cross the wire, CXER codes do not. **Where each code is measured** (RULED: 1085-c-5): nine — 5701, 5702, 5703, 5706, 5709, 5710, 5711, 5712, 5713 — are reachable OFFLINE and are graded by `conformance/stdlib/smtp.cxd` under no capability at all, which is what §2.1's purity split buys. The other six — 5700, 5704, 5705, 5707, 5708, 5714 — each need a PEER: they are `submit` reading a reply our own well-behaved server never sends (a `554` greeting, a `550` on a command, a close mid-transaction, a `535`), a certificate an MTA-STS policy refuses, or a `serve` handler failing. None has a pure verb that can raise it — `parse-reply` READS a `550` into an `[smtp-reply]` value and is right not to refuse it, because "the server said something unparseable" and "the server said 550" are different facts and only the second is the server's own refusal. They are therefore measured by `vcx/tests/smtp_real_socket_test.v` (our `serve` and our `submit` in two real processes over loopback, plus a scripted hostile server), cited here rather than left implicit, so a reader can see that all fifteen ARE measured and by whom | `spec/03-approved/std-lib/smtp.md` §8 |
| `CXER5800–CXER5899` | `cx-stdlib/imap` — IMAP4rev2 client and mailbox server core (`E_IMAP_*`; issue #1085, RULED: 1085-a/1085-b — registered 2026-09-11 WITH the implementation, the `oidc:client-credentials` precedent that a row ahead of the code reds `check-effect-alignment`. `imap.md` §8's band scan returned nothing anywhere in the tree for `CXER58xx` — no spec, no `.v`, no `.cx`, no `.cxd`, no header — and `5800–5899` was the next free hundred-block above `smtp`'s `5700–5799`). Blame is three-handed, the #1100 rule as `scim`, `saml`, `sasl` and `smtp` draw it: the peer sent something broken, the peer asked for something we decline on policy, or the CX caller misused a verb. 5800 `E_IMAP_GREETING_INVALID` (peer — the greeting is not `OK`/`PREAUTH`, or is unparseable; a `* PREAUTH` on an UNPROTECTED connection, which is an authentication the client never performed), 5801 `E_IMAP_SEQUENCE` (peer — a command in the wrong state, answered `BAD`, and the state is checked BEFORE the arguments are parsed, because a server that parses first tells an unauthenticated peer which of its mailbox names exist), 5802 `E_IMAP_SYNTAX` (peer — an unparseable command or response; a malformed sequence set, search key, mailbox name or flag; a §5.3 *syntax* bound; a CR, LF or NUL in a mailbox name, which is the CRLF-injection class and is refused where the value is ACCEPTED rather than where it is written, in BOTH directions), 5803 `E_IMAP_BODYSTRUCTURE_INVALID` (peer — a `BODYSTRUCTURE` that does not parse, or whose part numbering is inconsistent with its nesting. Its own code because it is the one response a client parses RECURSIVELY and therefore the one where depth and arity attacks land; the depth bound is checked on the way DOWN, because a parser that built the tree and then measured it has already paid for the attack), 5804 `E_IMAP_TAG_INVALID` (peer — an unknown tag, a re-used tag, a tagged response for a completed command, or a `+` continuation where none was expected. The tag-confusion class: a response mis-attributed to the wrong command is a `NO` read as an `OK`), 5805 `E_IMAP_REFUSED` (peer — a well-formed `NO`/`BAD`/`BYE`, surfaced verbatim with its response code (`[ALERT]`, `[TRYCREATE]`, `[OVERQUOTA]`, `[AUTHENTICATIONFAILED]`, …) and text. The counterpart of `smtp`'s 5704, oidc's 5303 and saml's 5409), 5806 `E_IMAP_TLS_REQUIRED` (declined — `STARTTLS` unadvertised or failed under `tls=:required`; credentials on an unprotected connection under EVERY `tls=` setting, because turning off the TLS requirement does not turn on cleartext credentials; buffered plaintext carried across the upgrade, the CVE-2011-0411 class), 5807 `E_IMAP_CONNECTION_LOST` (peer — closed mid-command; carries `net`'s `[err]` as `[cause]`, never re-coded), 5808 `E_IMAP_AUTH_FAILED` (peer — the credential was rejected; carries the server text and any RFC 7628 failure detail, because "token expired, refresh and retry" and "wrong scope, re-consent" are different answers and only the server knows which), 5809 `E_IMAP_AUTH_UNAVAILABLE` (declined — no acceptable mechanism, a pinned mechanism unadvertised, or a §1.2-refused mechanism named. The registry's own refusal is `sasl`'s `CXER5901` and rides this one as `[cause]`, so the decision is made once for both transports rather than twice — never a silent fall-back), 5810 `E_IMAP_CAPABILITY_MISSING` (declined — a rev2-**mandatory** capability with no rev1 equivalent the server offers: `MOVE` and `UIDPLUS` are the two that matter. NOT raised for a rev1-only server as such, because §5.6's shim speaks rev1. Distinct from 5805 because the server refused nothing — it simply cannot do this, and the caller's fix is a different server, not a retry), 5811 `E_IMAP_SIZE_EXCEEDED` (split by direction: a literal, fetch or command over a §5.3 *size* bound from the peer — validated AT the `{n}` announcement, before a byte is read or allocated, so `A001 LOGIN {4294967295}` costs one refusal and not four gigabytes — or, client-side, a caller's `append` over the server's announced limit, refused before transmission), 5812 `E_IMAP_LIMIT` (declined — a *count* or *rate* bound: `max-commands`, `max-errors`, `max-auth-attempts`, `max-connections*`, `max-untagged-queue`, the rate window. Distinct from 5811 for `smtp.md` §8's reason: a size bound is about one message, a limit is about a peer's behaviour. Answered `* BYE` and not a silent close, because a client that is told to back off does and a client that sees a TCP reset reconnects immediately), 5813 `E_IMAP_UIDVALIDITY_CHANGED` (peer — the mailbox's `UIDVALIDITY` differs from the `[sync-state]`'s, so every cached UID is meaningless. Its own code, and NOT an argument error, because it is a *normal* event a correct client must handle by discarding its cache and resynchronizing from scratch; `sync` returns no changes at all, and that refusal IS the safety property), 5814 `E_IMAP_HANDLER_FAILED` (the CX caller — a `serve` handler returned an `[err]`, panicked, or returned a non-result; the client sees a tagged `NO` and the operation was NOT performed — never a `BAD`, because `BAD` tells the client its command was malformed and invites it to retry differently, which is a lie when the fault is ours), 5815 `E_IMAP_ARG_INVALID` (the CX caller — a verb handed the wrong element shape, a `[search]` that is not one, a bind URL given to `connect` or a client URL given to `serve`/`listen`, a handle naming no live session, `respond` twice on one exchange); 5816–5899 reserved. Reused, never re-coded: a capability denial is `CXER0271` at the effect point; every socket and TLS fault stays `net`'s `CXER45xx` and propagates as `[cause]`; a body that will not parse as a message is `email`'s `CXER1300`; every SASL credential, framing and mechanism-selection fault stays `sasl`'s `CXER59xx` and rides 5808/5809 as `[cause]`. The wire-facing IMAP response code (`[TRYCREATE]`, `[OVERQUOTA]`, `[UNAVAILABLE]`, …) is a VALUE this module returns, not a competing code space. **Where each code is measured**: eleven — 5801, 5802, 5803, 5804, 5806, 5808, 5809, 5810, 5811, 5812, 5815 — are reachable OFFLINE and are graded by `conformance/stdlib/imap.cxd` under no capability at all, which is what §2.1's purity split buys. The other five — 5800, 5805, 5807, 5813, 5814 — each need a PEER: a `* BYE` or cleartext `* PREAUTH` greeting, a well-formed tagged `NO`, a close mid-command, a `sync` against a re-created mailbox, and a `serve` handler failing. None has a pure verb that can raise it — `parse-response` READS a `NO` into a value and is right not to refuse it, because "the server sent something unparseable" and "the server said NO" are different facts. They are therefore measured by `vcx/tests/imap_real_socket_test.v` (our `serve` and our client in two real processes over loopback, plus a scripted hostile server), cited here rather than left implicit, so a reader can see that all sixteen ARE measured and by whom | `spec/03-approved/std-lib/imap.md` §8 |
| `CXER5900–CXER5999` | `cx-stdlib/sasl` — the SASL mechanism registry and framing codec (`E_SASL_*`; issue #1085, RULED: 1085-a/1085-b — registered 2026-09-11 WITH the implementation, per the `oidc:client-credentials` precedent: a row ahead of the code reds `check-effect-alignment`. Next free hundred-block above `scim`'s `5600–5699`; `smtp.md` §8 proposes `5700–5799` and `imap.md` §8 proposes `5800–5899`, and a band scan at registration returned nothing anywhere in the tree — no spec, no `.v`, no `.cx`, no `.cxd`, no header). Blame is three-handed, the #1100 rule as `scim`, `saml`, `smtp` and `imap` draw it: the peer sent something broken, the peer asked for something we decline on policy, or the CX caller misused a verb. 5900 `E_SASL_CREDENTIAL_INVALID` (the CX caller — a `[sasl-auth]` this module cannot use: a NUL, CR or LF in `authcid`/`authzid`/`secret`; a `,`, `=` or `%x01` in an `authzid` reaching a gs2 header; both `secret=` and `token=`, or neither; `:oauthbearer` without `host=`/`port=`; a `token` outside the RFC 6750 §2.1 `b64token` grammar; a `mechanism=` that is not one of the four. The `[err]` NEVER echoes `secret` or `token` — it names the member, not the value, and sasl.cxd's secret-hygiene fold measures that over every refusal the module can raise rather than asserting it), 5901 `E_SASL_MECHANISM_UNAVAILABLE` (declined — no acceptable mechanism: a class mismatch between the credential and the advertised set, a pinned mechanism the server did not advertise, an empty advertised set, or a §5-refused mechanism named or offered alone. Carries BOTH lists — what was offered and what the credential supports — and, on the downgrade case, says which it refused to fall back to, because "no acceptable mechanism" with neither list in it is a report an operator cannot act on), 5902 `E_SASL_CHALLENGE_INVALID` (peer — a challenge this mechanism cannot be in a position to receive, or cannot read: a third `LOGIN` prompt, a challenge that is not valid UTF-8, an OAUTHBEARER or XOAUTH2 challenge that is not a JSON object, a continuation for a mechanism that expects none), 5903 `E_SASL_SERVER_ERROR` (peer — a token mechanism's OWN error JSON, surfaced verbatim as a `[server-error …]` child together with the `[continuation]` that mechanism requires the client to send next: RFC 7628 §3.2.2's `status`/`scope`/`openid-configuration` with a single-`%x01` continuation for `:oauthbearer`, and XOAUTH2's `status`/`schemes`/`scope` with an EMPTY continuation for `:xoauth2` — an empty continuation is not the absence of one. The counterpart of `oidc`'s 5303 and `saml`'s 5409: the peer's own refusal, carried rather than re-worded, which is what lets a caller tell "token expired, refresh and retry" from "wrong scope, re-consent"); 5904–5999 reserved. Reused, never re-coded: a malformed base64 challenge is `bytes`' `CXER2302` (`E_BYTES_INVALID_BASE64`) propagated UNCHANGED — `step` is handed already-decoded octets, so the refusal is the decoder's and this module adds no second answer for it. There is no capability code here at all, because every verb is pure and the module has no effect point (the `saml` v1 posture, RULED: S-6) | `spec/03-approved/std-lib/sasl.md` §6 |
| `CXER6000–CXER6099` | `cx-stdlib/sso` — the enterprise-SSO deployment surface: mountable handler verbs (`E_SSO_*`; issue #1394, RULED: 1394-a — registered 2026-09-11 WITH the implementation, per the `oidc:client-credentials` precedent that a row ahead of the code reds `check-effect-alignment`. Next free hundred-block above `sasl`'s `5900–5999`; `5800–5899` is [`imap.md`](../std-lib/imap.md) §8's reservation, and a band scan at registration returned nothing anywhere in the tree for `CXER60xx` — no spec, no `.v`, no `.cx`, no `.cxd`, no header). Blame is TWO-handed here rather than three, because this module has no peer to blame: either the request is not what the route serves, or the deployment configured the route so it can serve no request. 6000 `E_SSO_REQUEST_INVALID` (the request is not this route's shape — no `state` on the callback, no `SAMLResponse` on the ACS, no `logout_token` on the back channel, a non-string body, a method the route does not take), 6001 `E_SSO_STATE_NOT_PENDING` (the callback's `state` names no takeable pending row: never issued, already taken — the authorization-code replay — or past `pending-ttl`. ONE code for all three deliberately: a code per cause tells an attacker probing `state` values which of the three a guess hit, and the relying party does the same thing in all three cases), 6002 `E_SSO_RETURN_TO_REFUSED` (a `return-to` or `RelayState` outside `cfg.return-to-allow`, or carrying a scheme, an authority, a `//` prefix, a backslash or a control character — the open-redirect and response-splitting refusal, checked BEFORE the assertion is looked at so it does not depend on whether the document verifies), 6003 `E_SSO_BODY_TOO_LARGE` (a form body past `cfg.max-body-bytes`, refused before it is parsed or base64-decoded: an Assertion Consumer Service is unauthenticated by construction, so an oversized `SAMLResponse` must cost a length comparison and not a decode), 6004 `E_SSO_UNAUTHORIZED` (the constant-time bearer guard refused — no `Authorization: Bearer`, a token that does not match, or no `scim-token` configured at all, which is the fail-closed default; reaches a client as `[auth]`'s own `CXER0161`), 6005 `E_SSO_LOGOUT_UNBOUND` (a front- or back-channel logout whose `(iss, sid)` binds no session here), 6006 `E_SSO_CONFIG_INVALID` (the deployment's own defect — `config`, `sp`, `scim-token`, `directory` or `now` missing, named all at once, and RAISED rather than answered, because an operator must see it at the first request instead of as a `400` a tenant reports), 6007 `E_SSO_ROUTE_UNKNOWN` (the SCIM route set handed a method+path pair it does not serve). Extended 2026-09-12 with the enterprise surface (RULED: 1394-b; specified ahead of the implementation, which is that decision's phase 2): 6008 `E_SSO_TENANT_UNRESOLVED` (no selection rule matched and no default tenant is set, two rules selected different tenants, a returning credential's parked tenant disagrees with the request's, or an Entra `tid` outside the tenant's allowed list — or one whose substitution into the templated issuer `https://login.microsoftonline.com/{tenantid}/v2.0` does not equal the token's `iss`, which is the classic multi-tenant Entra breach), 6009 `E_SSO_METADATA_REFUSED` (an IdP metadata import or refresh that cannot be configured: an expired or not-yet-valid certificate per 1410-b, a changed `entityID`/`issuer` — the metadata-poisoning refusal — a document with no usable signing key, or a fetch the deployment did not configure; the previous configuration stands), 6010 `E_SSO_ROTATION_REFUSED` (a rotation with no overlap window on a value the deployment verifies against, one that would retire the last valid value, or one naming a value already past its deadline), 6011 `E_SSO_DEVICE_POLL_TOO_FAST` (a device-authorization poll inside the advertised interval — RFC 8628 `slow_down`, enforced at the route so the provider is not the one that has to), 6012 `E_SSO_IDENTITY_UNPROVISIONED` (a verified login whose identifier is in no link row at a tenant whose provisioning policy is SCIM-only, the default — a refusal and never a silent create, because a JIT default moves "who exists here" to whoever controls the IdP), 6013 `E_SSO_LINK_CONFLICT` (a link that would bind an already-bound identifier to a second principal, or a second identifier of one kind to a principal without the explicit multi-link opt — the link-table-takeover refusal), 6014 `E_SSO_BREAK_GLASS_REFUSED` (break-glass not configured, which is the default, outside its window, past its use bound, with no reason supplied, not granted by `authz`, or configured with an unbounded window or a plaintext credential); 6015–6099 reserved. Reused, never re-coded: every OIDC fault stays `oidc`'s `CXER53xx` and every SAML fault `saml`'s `CXER54xx`, both reaching a caller wrapped by `session` as `CXER4801` with the original verbatim in `[cause]`; an under-configured login is `session`'s `CXER4813`; every SCIM semantic fault stays `scim`'s `CXER56xx` and is rendered beside the wire SCIM error object; a malformed base64 `SAMLResponse` is `bytes`' `CXER2302`; a capability denial is the core `CXER0271` at the effect point | `spec/03-approved/std-lib/sso.md` §8 |

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

**The clean-room clause (stream 22, L74).** A change that pins or
alters EVALUATION-observable behavior additionally requires:

- the rule lands IN THE REGISTER (code.md §14.4) with a stable
  `EV-…` id — never as prose outside it;
- a witness that FAILS UNDER THE OPPOSITE CHOICE (a discriminator
  pair — a fixture both readings pass pins nothing);
- numeric limits ship WITH FLOORS, never bare numbers (the EV-BUDGET
  pattern: "implementations MUST accept ≥ N" — a bare limit is an
  implementation detail, a floor is a contract).

### 10.1a Implementability grades (stream 22, L71 — normative)

Every spec area carries a clean-room implementability grade; grade-D
areas are IMPLEMENTATION BLOCKERS for their areas (behavior-affecting;
the corpus cannot police them until pinned). Grades move only by spec
work (D→A via pin + witness), recorded here:

| Area | Grade | Basis |
|---|---|---|
| code.md §9.1.2 / §9.2 / §10.5.7 / §12.5 | A | clean-room implementable as written |
| code.md §14 evaluation core + EV register | A | stream 22 (pins + discriminator pairs; was D across §6.1/§8.5/§8.6/§6.4.1/§6.7/§10.5.1/§10.5.3) |
| code.md §6.7 iterators — EV-PULL engine conformance | D | pinned rule; engine lands with the runtime-representation stream (#710) — blocker for iterator-engine work until then |
| code.md §6.5.1 | C→A | the effect table moved to security.md §2.1 (stream 6; EV-EFFECT-SET) |
| code.md §11.4 gate protocols | C→B | partitioned reference-lane vs conformance-bar (L75) |
| security.md §4 | C | scope text still impl-anchored; move with the next security amendment |
| fp.md, jsonschema.md | A | de-anchored at I2 (#707) |
| conformance front door | A | #707 items 1–7 + the out-effects channel (stream 22 W1) |

Grades A (clean-room implementable) / B (implementable with corpus) /
C (impl-anchored — must move) / D (trap — specify or fixture before
implementation).

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
`[?zip]`, `[?enumerate]`, `[?chunks]`, `[?concat]`,
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
| `.cxbin` | CXCol binary wire format (formerly `.cxcol`; `.cxcol` is a deprecated alias, recognized read-only) |
| `.cxd` | Conformance fixture suite (the corpus format) |
| `.cxpack` | Registry pack bundle |
| `.cxlint` | Lint configuration |
| `.cxpath` | CXPath query file |

The former draft tokens `.cxsh`, `.cxl`, `.cxlib`, and `.cxdv` are
DELETED — never shipped, not reserved (stream 13 ruling 61; the phantom
`.cxsh` reference is removed from grammar.ebnf in the same change).

**Reserved filenames** (exact-name reservations, not extensions):

| Filename | Description |
|---|---|
| `cx.lock` | Package lockfile |
| `cx.pkg` | Package manifest |

Reservation means the CX project's CLIs, LSP, editors, and registry
metadata recognize the extension as CX-related. Third-party tooling
SHOULD NOT claim these extensions for unrelated purposes.

### 12.3 Reserved reference prefixes

Tagged reference prefixes are **domain separators for trust inputs**: a
prefixed address names WHAT KIND of artifact a hash addresses, so an
address minted in one trust domain can never be replayed into another
(the `code:` precedent). This registry is the single source of truth;
a new prefix adds a row here before first use. The prefixes are
append-only and never reassigned.

| Prefix | Addresses | Owner spec |
|---|---|---|
| `code:` | Tier-1 tagged content addresses of CX code / definition text (`code:sha2-256:<hex>`) | `spec/core/code-identity.md` |
| `computes-as:` | Tier-2 semantic fn-identity claims (`computes-as:<algo>:<hex>`) — dispatch-only, never an address; never a trust input | `spec/core/code-identity.md` |
| `cap:` | any **authority-artifact** value — `[capability …]`, `[delegation …]`, the C4 grant-set document (`cap:sha2-256:<hex>`); resolution is FAIL-CLOSED against the live authority registry (commands and effects, stream 6 — L114) | `spec/std-lib/authz.md` |

(`cx-err:` is a wire-code namespace, not a reference prefix — governed
at §9.6. The retired `cap:resource` grant-scope spelling collided with
the `cap:` prefix and was renamed to `cap=resource` — #713/L114; the
prefix is the one meaning.)

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
