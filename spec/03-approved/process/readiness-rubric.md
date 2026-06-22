# CX Readiness Rubric

**Status:** Current

This document is the gate criterion for CX releases. It catalogs the
capabilities a serious data/document format is expected to provide —
sourced from XML 1.0, JSON (RFC 8259 + JSON Schema + JSON
Pointer/Patch), YAML 1.2, TOML 1.0, MessagePack, CBOR, and Parquet —
plus the operational expectations (tooling, conformance, multi-language
ecosystem) that distinguish a usable format from a paper spec.

**Stability commitment.** From the current tag through 1.0, no
breaking changes to the public surface (C ABI, binding APIs, wire
formats, spec-normative grammar). Every ⚠ row is a release blocker;
the 1.0 release is a quality and audit milestone rather than a feature
milestone.

A release ships only after every row is either ✅ shipped, ❌
deliberate non-feature with rationale, or 📋 named in roadmap with a
target version. A row marked ⚠ is a release blocker — close it or move
it to the roadmap before tagging.

The rubric is the basis for each release's adoption review (under
`docs/adoption_review_<version>.md`), which evaluates the rubric
against the adoption persona set:

| Tier | Meaning |
|---|---|
| ⭐ **First choice** | Persona picks CX over its current default. v1.0 target. |
| ✅ **Adoptable** | Persona accepts CX if directed; no caveats. |
| ⚠ **Adoptable with caveats** | Persona adopts under specific conditions. |
| ❌ **Not yet adoptable** | Persona blocked by a missing capability. |

The rubric and the persona review are co-equal gates with the
friction-budget gate; all three must pass before tag.

---

## Legend

| Icon | Meaning |
|---|---|
| ✅ | shipped — capability is in the current release and tested |
| 🚧 | in progress — design committed, implementation in flight |
| 📋 | planned for a later release |
| ❌ | deliberate non-feature — rationale recorded |
| ⚠ | release blocker — must close or move to roadmap before tag |

Status reflects branch HEAD, not the latest released version.

---

## 1 — Syntactic foundations

| Capability | Status | Reference |
|---|---|---|
| Formal grammar (EBNF) | ✅ | `core/grammar.ebnf` |
| Block + line comments | ✅ | `core/grammar.ebnf` |
| Multi-line raw text | ✅ | `core/grammar.ebnf` |
| Whitespace normalization documented | ✅ | `core/grammar.ebnf` |
| Numeric literals (int, float, hex, underscored) | ✅ | `core/grammar.ebnf` |
| String literals (single, triple, escape rules) | ✅ | `core/grammar.ebnf` |
| UTF-8 encoding required | ✅ | `core/abi.md` §1.7, `core/conversions.md` §0.4 |
| BOM handling | ✅ | `core/conversions.md` §0.4, `core/code.md` §3.1 |
| Line-ending policy (CR / LF / CRLF) | ✅ | `core/conversions.md` §0.4, `core/canonical.md` §2.2 |
| Reserved-character escape table | ✅ | `core/grammar.ebnf` |

## 2 — Type system

| Capability | Status | Reference |
|---|---|---|
| Bool, null, string | ✅ | `core/cxdm.md` |
| Int + float | ✅ | `core/cxdm.md` |
| Sized integers / floats | ✅ | `core/cxdm.md` |
| `:decimal` arbitrary precision | ✅ | `core/cxdm.md` |
| `:bigint` arbitrary precision int | ✅ | `core/cxdm.md` |
| `:bytes` binary blob | ✅ | `core/cxdm.md` |
| Date / datetime / time | ✅ | `core/cxdm.md` |
| Atom scalar | ✅ | `core/cxdm.md` |
| Typed and mixed-type arrays | ✅ | `core/cxdm.md` |
| Type fidelity through round-trip | ✅ | `core/data-bin.md` |
| Null vs empty vs missing distinction | ✅ | `core/cxdm.md` |
| Schema-driven type narrowing | ✅ | `core/schema.md` |

## 3 — Structural primitives

| Capability | Status | Reference |
|---|---|---|
| Element / attribute distinction | ✅ | `core/cxdm.md` |
| Mixed content | ✅ | `core/cxdm.md` |
| Nesting with recursion limit | ✅ | `core/cxdm.md` |
| Multiple top-level documents | ✅ | `core/grammar.ebnf` |
| Tabular `:table` block | ✅ | `core/cxdm.md` |
| Public Table API per binding | ✅ | `misc/table-api.md` |
| Empty-element shorthand | ✅ | `core/grammar.ebnf` |

## 4 — References & composition

| Capability | Status | Reference |
|---|---|---|
| File includes | ✅ | `core/code.md` |
| Include resolution semantics | ✅ | `core/code.md` |
| ID / IDREF cross-document references | ✅ | `core/cxdm.md` |
| Element-by-path references (CXPath as value) | ✅ | `core/code.md` |
| Namespaces (XML xmlns equivalent) | ✅ | `core/cxdm.md`, `core/grammar.ebnf` |
| External-entity references | ❌ | by-design (security parity with JSON) |

## 5 — Schema & validation

| Capability | Status | Reference |
|---|---|---|
| Schema language (`.cxs`) | ✅ | `core/schema.md` |
| Schema validation engine | ✅ | `std-lib/validate.md` |
| Schema-driven defaults + coercion | ✅ | `core/schema.md` |
| Required vs optional attribute markers | ✅ | `core/schema.md` |
| Cardinality constraints | ✅ | `core/schema.md` |
| Enum / pattern / range constraints | ✅ | `core/schema.md` |
| Schema diagnostics (line/col, friendly errors) | ✅ | `core/schema.md` |
| Schema-aware editor support (LSP) | 📋 | planned |

## 6 — Conversion / interop

| Capability | Status | Reference |
|---|---|---|
| Lossless CX ↔ XML | ✅ | `core/conversions.md` |
| Lossless CX ↔ JSON | ✅ | `core/conversions.md` |
| Lossless CX ↔ YAML | ✅ | `core/conversions.md` |
| Lossless CX ↔ TOML | ✅ | `core/conversions.md` |
| Lossless CX ↔ Markdown | ✅ | `core/conversions.md` |
| Per-format caveats documented | ✅ | `core/conversions.md` |
| CX program evaluator (rendering / querying / transformation) | ✅ | `core/code.md` |
| Collection literals (Array / Map / Sequence) | ✅ | `core/cxdm.md` |
| Wire-format binary (CXCol) | ✅ | `core/data-bin.md` |
| Chunked-table format | ✅ | `core/data-bin.md` |
| Page-compression wrapper (zstd) | ✅ | `core/data-bin.md` |
| Schema-driven encoding | ✅ | `core/data-bin.md` |
| Streaming Table C ABI | ✅ | `core/abi.md` |
| Apache Arrow C-Data interop | ✅ | `core/abi.md` |
| Parquet bridge (via Arrow) | 📋 | planned |
| Binary AST format (`cx_ast_bin`) | ✅ | `core/ast-bin.md` |
| Data-bin one-shot loaders/dumpers | ✅ | `core/abi.md` |
| Delimited (CSV / TSV / PSV) | ✅ | `std-lib/csv.md`, `core/conversions.md` |
| Auto-typing on delimited → CX | ✅ | `std-lib/csv.md` |
| Protobuf / MessagePack | ❌ | deliberate non-feature |

## 7 — Internationalization

| Capability | Status | Reference |
|---|---|---|
| UTF-8 input/output | ✅ | `core/abi.md` |
| Unicode-correct identifier rules | ✅ | `core/grammar.ebnf` |
| Unicode normalization policy | ✅ | `core/canonical.md` |
| Bidirectional text handling | ✅ | `std-lib/i18n.md` |
| Language-tag attribute | ✅ | `std-lib/i18n.md` |
| Locale-independent number formatting | ✅ | `core/canonical.md` |

## 8 — Streaming & scale

| Capability | Status | Reference |
|---|---|---|
| Pull-based event stream parser | ✅ | `core/streaming.md` |
| Streaming write API | ✅ | `core/streaming.md` |
| Partial materialization | ✅ | `core/streaming.md` |
| Memory bounds documented | ✅ | `core/data-bin.md` §4 |
| Recursion-limit policy | ✅ | `core/data-bin.md` §4 |
| Maximum element / attribute count | ✅ | `core/data-bin.md` §4 |
| Large-file (multi-GB) handling | ✅ | `core/streaming.md` |

## 9 — Tooling

| Capability | Status | Reference |
|---|---|---|
| `cx` CLI | ✅ | `core/abi.md` |
| `cx fmt` (lossless canonical) | ✅ | `core/canonical.md` |
| `cx canonical` (strict canonical) | ✅ | `core/canonical.md` |
| `cx hash` (SHA-256 of strict canonical) | ✅ | `core/canonical.md` |
| `cx eq` (data equivalence) | ✅ | `core/cxdm.md` |
| `cx diff` | ✅ | `core/abi.md §2.17` |
| `cx lint` | ✅ | `core/abi.md §2.18` |
| Tree-sitter grammar | ✅ | `modules/tree-sitter.md` |
| Language Server Protocol (LSP) | ✅ | external (`tooling/lsp/`) |
| VSCode extension | ✅ | external (`tooling/vscode/`) |
| Neovim integration | ✅ | external (`tooling/neovim/`) |

## 10 — Documentation & specification

| Capability | Status | Reference |
|---|---|---|
| Normative grammar | ✅ | `core/grammar.ebnf` |
| Conversion contract per format pair | ✅ | `core/conversions.md` |
| C ABI surface documented | ✅ | `core/abi.md` |
| AST / data-binary wire format spec | ✅ | `core/ast.md`, `core/ast-bin.md`, `core/data-bin.md` |
| Type-mapping rules per binding language | ✅ | `misc/type-mapping.md` |
| Streaming API contract | ✅ | `core/streaming.md` |
| Governance / process rules | ✅ | `process/governance.md` |
| Versioning policy | ✅ | `process/governance.md` |
| Conformance suite documented | ✅ | `conformance/` |
| **`UNIFORM` orthogonality gate** — a feature newly admitted/materially changed carries a complete Applicability Matrix (domain × ✅/❌/—), every ❌/— justified in writing, cognate kinds covered same-pass; reviewer checklist item | ✅ | `process/spec-authoring-guide.md` §3 |
| **learnability guardrail** — the guide intro/quickstart show **Tier 1 only** and the *fun* path first; fp.md and the words "monad"/"functor"/"typeclass" never appear in beginner material; Tier 2/3 features carry an opt-in/advanced marker. A docs reviewer applies §4's three rules; the Tier-1-only constraint on the beginner sections is a **standing executable gate** | ✅ | `process/spec-authoring-guide.md` §4, `scripts/check_docs_tier1_guardrail.py` (wired into `make test`) |
| User tutorial | ✅ | `docs/guide/intro.html`, `docs/guide/quickstart.html`, `docs/guide/tour-data.html`, `docs/guide/tour-programs.html` |
| Cheatsheet | ✅ | `docs/guide/surfaces.html`, `docs/guide/code.html` |
| FAQ | ✅ | `docs/guide/faq.html` |
| Working examples | ✅ | `examples/` |

## 11 — Multi-language ecosystem

| Capability | Status | Reference |
|---|---|---|
| Reference V implementation | ✅ | `vcx/` |
| Python binding | ✅ | `lang/python/` |
| Go binding | ✅ | `lang/go/` |
| Rust binding | ✅ | `lang/rust/` |
| Native-V binding | ✅ | `lang/v/native/` |
| Per-binding parity matrix | ✅ | `misc/parity-matrix.md` |
| Per-binding strategy declaration | ✅ | each binding's README |
| Cross-binding determinism | ✅ | `process/governance.md` |
| C ABI version negotiation | ✅ | `process/governance.md` |
| Symbol stability policy | ✅ | `process/governance.md` |

## 12 — Security

| Capability | Status | Reference |
|---|---|---|
| Recursion-depth parser hardening | ✅ | `core/cxdm.md` |
| Element / attribute count caps | ✅ | `core/cxdm.md` |
| Varint validation in binary formats | ✅ | `core/data-bin.md` |
| External-entity / billion-laughs immune | ✅ | by-design |
| Vulnerability reporting policy | ✅ | `SECURITY.md` |
| Threat model document | ✅ | `process/threat-model.md` |
| Fuzz-testing harness | ✅ | `.github/workflows/fuzz.yml` (nightly 1h budget; `scripts/fuzz_cx.py` against parser + buffered eval + streaming eval + ABI-passthrough) |
| External security audit | 📋 | v1.0 |
| Reproducible builds | ✅ | `.github/workflows/reproducibility.yml` (per-tag + weekly double-build SHA-256 diff under fixed `SOURCE_DATE_EPOCH`) |

## 13 — Performance

| Capability | Status | Reference |
|---|---|---|
| Documented SLA budgets | ✅ | `process/governance.md` |
| Microbenchmark suite | ✅ | `bench/` |
| CI regression gate against SLA budgets | ✅ | `.github/workflows/perf.yml` |
| Comparative benchmarks vs text formats | 📋 | planned |
| Comparative benchmarks vs binary formats | 📋 | planned |
| Per-binding CI matrix | ✅ | `.github/workflows/ci.yml` |

## 14 — Governance & change management

| Capability | Status | Reference |
|---|---|---|
| Versioning policy | ✅ | `process/governance.md` |
| Deprecation policy | ✅ | `process/governance.md` |
| Spec-change workflow | ✅ | `process/governance.md` |
| Annual binding audit cadence | ✅ | `process/governance.md` |
| Release process documented | 🚧 | covered inline in `process/governance.md` §9 + §10.4; standalone `docs/RELEASE_PROCESS.md` planned |
| Adoption-review gate (this rubric) | ✅ | this document |
| Public roadmap | ✅ | `ROADMAP.md` |
| Third-party conformance certification | ✅ | `process/governance.md` |
| Public test corpus | ✅ | `conformance/` |

## 15 — Concurrency & parallelism

| Capability | Status | Reference |
|---|---|---|
| Thread-safety contract per public C ABI function | ✅ | `core/abi.md` |
| Thread-safety of converters | ✅ | `core/abi.md` |
| Handle thread-locality contract | ✅ | `core/abi.md` |
| Per-binding concurrency story | ✅ | each binding's README |
| Concurrent test suite | ✅ | `core/abi.md` |
| Parallel parse / emit scaling | 🚧 | `core/abi.md` |
| Lock-free internals | ✅ | `core/abi.md` |
| Memory model contract | ✅ | `core/abi.md` |

---

## How to use this rubric

**At release time.** Walk every row. For each, classify the current
state. Any ⚠ becomes a release-cycle decision: fix-in-scope or
move-to-roadmap-with-target-version. Then write the adoption review at
`docs/adoption_review_<version>.md`.

**Between releases.** When a capability ships, flip its row from
🚧 / 📋 to ✅ in the same commit that closes the work. When a new
capability becomes a known need, add a row marked ⚠ and address it in
the next release cycle.

**At spec change time.** Every change that adds, defers, or rejects a
capability updates the rubric row in the same PR.

The rubric is a living document; the gate is "no ⚠ at release tag."
