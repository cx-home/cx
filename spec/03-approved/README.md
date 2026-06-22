# CX Specification

**Status:** Current

The CX language and its companion specifications, organised into five directories. Read in the order listed; each later layer depends on the earlier ones.

## `core/` — language foundation (14 files)

| File | Purpose |
|---|---|
| `cxdm.md` | CX Data Model — values, kinds, equality, EBV, identity, namespaces. |
| `grammar.ebnf` | Concrete syntax (EBNF). |
| `ast.md` | Parse-AST node shapes. |
| `canonical.md` | Canonical forms (lossless and strict). |
| `formatting.md` | Declarative formatting profiles (axes, built-ins, `cx-format.cx`). |
| `code.md` | Program language: patterns, queries, transforms, module system, `[?cx include]`. |
| `security.md` | Capability-based, deny-by-default security model (`[?with-caps]`, `E_CAP_DENIED`). |
| `schema.md` | `.cxs` schema language. |
| `conversions.md` | Format conversions (CX ↔ XML / JSON / YAML / TOML / CSV / MD). |
| `abi.md` | C ABI for language bindings. |
| `ast-bin.md` | Binary AST wire format. |
| `data-bin.md` | Binary value wire format (CXCol v1). |
| `lockfile.md` | `cx.lock` format for `[?lib]` module pinning. |
| `streaming.md` | Streaming event protocol (read + write). |

## `std-lib/` — standard library (29 modules + README)

The `cx-stdlib` module specs. See [`std-lib/README.md`](std-lib/README.md) for the per-module index.

## `modules/` — external-system integrations (3 files)

| File | Purpose |
|---|---|
| `cx.md` | `cx:` self-host introspection module. |
| `sqlite.md` | SQLite external integration. |
| `tree-sitter.md` | tree-sitter external integration. |

## `misc/` — host APIs + wire formats (8 files)

| File | Purpose |
|---|---|
| `api.md` | Public document API surface. |
| `bindings.md` | Per-binding language surface (V / Python / Go / Rust); wire-format negotiation. |
| `cli.md` | `cx` command-line interface — subcommands, exit codes, env vars. |
| `debug.md` | Debugging surface (local + remote): breakpoints, stepping, DAP adapter, record-replay. |
| `table-api.md` | Streaming table reader/writer API. |
| `type-mapping.md` | CX ↔ host-language type mapping. |
| `cxstore-remote-protocol.md` | cx-store remote wire protocol. |
| `parity-matrix.md` | Per-binding parity matrix. |

## `process/` — governance + operational (4 files)

| File | Purpose |
|---|---|
| `governance.md` | Project governance, release gating, spec-corpus rules (G1 / G2 / G3). |
| `readiness-rubric.md` | Release-readiness gates. |
| `spec-authoring-guide.md` | Authoring conventions for spec authors. |
| `threat-model.md` | Security threat model. |

## `_archive/` — historical (read-only)

Read-only archive of ADRs, design audits, cross-reference guides, and superseded drafts. **No active spec cites `_archive/`** — the current corpus stands alone without ADR archaeology.
