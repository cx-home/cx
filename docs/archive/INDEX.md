# CX documentation index

Start here. Every CX document is one of five kinds — pick the one
that matches your task.

## 🚀 Start here

Just landed on the project? In order:

1. [README.md](../README.md) — what CX is, in 60 seconds.
2. `cx demo` — run the in-binary showcase.
3. [docs/TUTORIAL.md](TUTORIAL.md) — write your first `.cx` file.
4. [docs/CHEATSHEET.md](CHEATSHEET.md) — keep this open while you write.
5. [docs/CXL.md](CXL.md) — CXL, the CX Language, for templating + querying.
6. [docs/COMPARISON.md](COMPARISON.md) — CX vs JSON / YAML / TOML / XML / MD.
7. [docs/FAQ.md](FAQ.md) — the 10 most-asked questions.

## 📘 User documentation (`docs/`)

Day-to-day reference for evaluators, adopters, and contributors.

| Doc | When to read |
| --- | ------------ |
| [TUTORIAL.md](TUTORIAL.md) | First hour with CX — guided walkthrough |
| [CHEATSHEET.md](CHEATSHEET.md) | One-page CX syntax reference |
| [CXL.md](CXL.md) | **CXL — the CX Language**: templating, querying, transformation |
| [COMPARISON.md](COMPARISON.md) | Feature comparison vs alternatives + conversion-loss matrix |
| [FAQ.md](FAQ.md) | Common questions, format-design rationale |
| [migrations/](migrations/) | Per-version upgrade guides |
| [releases/](releases/) | Per-version release notes |

## 📐 Normative spec (`spec/`)

The contract — what implementations must do. Read this if you're
writing a binding, integrating CX into your tool, or evaluating
correctness.

| Doc | What it covers |
| --- | -------------- |
| [SPEC_BRIEF.md](../spec/SPEC_BRIEF.md) | Entry point — orient before the deep dives |
| [grammar.ebnf](../spec/grammar.ebnf) | Normative grammar |
| [architecture.md](../spec/architecture.md) | System-level architecture overview |
| [abi.md](../spec/abi.md) | C ABI surface — every public symbol |
| [api.md](../spec/api.md) | Public binding API surface |
| [ast.md](../spec/ast.md) | AST shape |
| [ast_bin.md](../spec/ast_bin.md) | AST binary wire format |
| [data_bin.md](../spec/data_bin.md) | CXDB v1 binary wire format |
| [canonical.md](../spec/canonical.md) | Canonical-form rules + content-hash contract |
| [conversions.md](../spec/conversions.md) | Per-format pair conversion contract |
| [cxdm.md](../spec/cxdm.md) | CX Data Model (semantic shape) |
| [cxl.md](../spec/eval.md) | CXL language reference |
| [cxpath.md](../spec/cxpath.md) | CXPath selector language |
| [schema.md](../spec/schema.md) | Schema language (`.cxs`) |
| [streaming.md](../spec/streaming.md) | Streaming-read + streaming-write API |
| [namespaces.md](../spec/namespaces.md) | XML-namespace equivalent |
| [identity.md](../spec/identity.md) | ID / IDREF cross-document references |
| [include.md](../spec/include.md) | File-include resolution semantics |
| [i18n.md](../spec/i18n.md) | Internationalization rules |
| [policies.md](../spec/policies.md) | Recursion limits, count caps, null/empty/missing |
| [type_mapping.md](../spec/type_mapping.md) | Per-binding host-type mapping |
| [parity_matrix.md](../spec/parity_matrix.md) | Per-binding capability matrix |
| [governance.md](../spec/governance.md) | Versioning, process, deprecation, audits |
| [threat_model.md](../spec/threat_model.md) | Threat model |

## 🧰 Per-binding documentation (`lang/`)

| Binding | Location |
| ------- | -------- |
| V native | [`vcx/README.md`](../vcx/README.md) |
| V FFI binding | [`lang/v/README.md`](../lang/v/README.md) |
| Python | [`lang/python/cxlib/README.md`](../lang/python/cxlib/README.md) |
| Go | [`lang/go/cxlib/README.md`](../lang/go/cxlib/README.md) |
| Rust | [`lang/rust/cxlib/README.md`](../lang/rust/cxlib/README.md) |
| TypeScript | [`lang/typescript/cxlib/README.md`](../lang/typescript/cxlib/README.md) |
| Java | [`lang/java/cxlib/README.md`](../lang/java/cxlib/README.md) |
| Kotlin | [`lang/kotlin/cxlib/README.md`](../lang/kotlin/cxlib/README.md) |
| Swift | [`lang/swift/cxlib/README.md`](../lang/swift/cxlib/README.md) |
| C# | [`lang/csharp/cxlib/README.md`](../lang/csharp/cxlib/README.md) |
| Ruby | [`lang/ruby/cxlib/README.md`](../lang/ruby/cxlib/README.md) |

Each per-binding README contains a 30-second quickstart block plus a
Table API quickstart.

## 🔧 Editor / tooling (`tooling/`)

| Tool | Location |
| ---- | -------- |
| LSP server | [`tooling/lsp/`](../tooling/lsp/) |
| VS Code extension | [`tooling/vscode/`](../tooling/vscode/) |
| Tree-sitter grammar | [`tooling/tree-sitter-cx/`](../tooling/tree-sitter-cx/) |
| Neovim setup | [`tooling/neovim/`](../tooling/neovim/) |

## 🏗 Project meta

| Doc | What it covers |
| --- | -------------- |
| [README.md](../README.md) | Project entry |
| [CHANGELOG.md](../CHANGELOG.md) | Rolling changelog |
| [MIGRATION.md](../MIGRATION.md) | Redirect to docs/migrations/ |
| [ROADMAP.md](../ROADMAP.md) | Now / Next / Later |
| [CONTRIBUTING.md](../CONTRIBUTING.md) | How to contribute |
| [SECURITY.md](../SECURITY.md) | Reporting vulnerabilities |
| [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md) | Community standards |
| [LICENSE](../LICENSE) | MIT |
