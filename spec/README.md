# CX Specification (v0.8.0)

**Status:** Current for v0.8.0

The CX language and its companion specifications, organised into five directories. Read in the order listed; each later layer depends on the earlier ones.

## `core/` — language foundation (12 files)

| File | Purpose |
|---|---|
| `cxdm.md` | CX Data Model — values, kinds, equality, EBV, identity, namespaces. |
| `grammar.ebnf` | Concrete syntax (EBNF). |
| `ast.md` | Parse-AST node shapes. |
| `canonical.md` | Canonical forms (lossless and strict). |
| `code.md` | Program language: patterns, queries, transforms, module system, `[?cx include]`. |
| `schema.md` | `.cxs` schema language. |
| `conversions.md` | Format conversions (CX ↔ XML / JSON / YAML / TOML / CSV / MD). |
| `abi.md` | C ABI for language bindings. |
| `ast_bin.md` | Binary AST wire format. |
| `data_bin.md` | Binary value wire format (CXCol v1). |
| `lockfile.md` | `cx.lock` format for `[?lib]` module pinning. |
| `streaming.md` | Streaming event protocol (read + write). |

## `std_lib/` — standard library (29 modules + README)

The `cx-stdlib` module specs. See [`std_lib/README.md`](std_lib/README.md) for the per-module index.

## `modules/` — external-system integrations (3 files)

| File | Purpose |
|---|---|
| `cx.md` | `cx:` self-host introspection module. |
| `sqlite.md` | SQLite external integration. |
| `tree-sitter.md` | tree-sitter external integration. |

## `misc/` — host APIs + wire formats (6 files)

| File | Purpose |
|---|---|
| `api.md` | Public document API surface. |
| `bindings.md` | Per-binding language surface (V / Python / Go / Rust). |
| `table_api.md` | Streaming table reader/writer API. |
| `type_mapping.md` | CX ↔ host-language type mapping. |
| `cxstore_remote_protocol.md` | cx-store remote wire protocol. |
| `parity_matrix.md` | Per-binding parity matrix. |

## `process/` — governance + operational (4 files)

| File | Purpose |
|---|---|
| `governance.md` | Project governance, release gating, spec-corpus rules (G1 / G2 / G3). |
| `readiness_rubric.md` | Release-readiness gates. |
| `spec_authoring_guide.md` | Authoring conventions for spec authors. |
| `threat_model.md` | Security threat model. |

## `_archive/` — historical (read-only)

Read-only archive of ADRs, design audits, cross-reference guides, and superseded drafts. **No active spec cites `_archive/`** — the v0.8.0 corpus stands alone without ADR archaeology.
