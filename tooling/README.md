# CX editor tooling

Editor integration for `.cx` / `.cxs` / `.cxl` files. Since v0.7.0 the
language server is built into the `cx` binary — `cx lsp` speaks
JSON-RPC 2.0 over stdio. No npm toolchain, no separate server process.

```
tooling/
  lsp/             cx-lsp editor configs (VS Code / Neovim / Helix)
  completions/     bash / zsh / fish shell completions for `cx <verb>`
  syntax/          TextMate grammar (cx.tmLanguage.json) for VS Code
  neovim/          Standalone Vim-regex highlighter + lspconfig glue
  tree-sitter-cx/  tree-sitter grammar (structural highlighting +
                   embedded-language injection; not tracked against
                   the v0.7.0 directive surface — see ADR 0025)
  binding_native_status.json   v0.7.0 parity dashboard
```

## Quick start

### `cx` on $PATH

All editor integration assumes `cx` is callable. Install via your
package manager, or build from source:

```sh
make build-vcx                     # produces vcx/target/cx
export PATH="$PWD/vcx/target:$PATH"
cx --version                       # → cx 0.7.0
```

### Editor wiring

| Editor | Config |
| --- | --- |
| VS Code | [`lsp/vscode.example.json`](lsp/vscode.example.json) |
| Neovim | [`neovim/cx.lua`](neovim/cx.lua) (lspconfig) or [`lsp/neovim.example.lua`](lsp/neovim.example.lua) (vanilla `vim.lsp.start`) |
| Helix | [`lsp/helix.example.toml`](lsp/helix.example.toml) |

All three just run `cx lsp` and let the binary do the work. See
[`lsp/README.md`](lsp/README.md) for capability table and smoke-test
instructions.

### Shell completions

| Shell | File |
| --- | --- |
| bash | [`completions/cx.bash`](completions/cx.bash) |
| zsh | [`completions/_cx.zsh`](completions/_cx.zsh) |
| fish | [`completions/cx.fish`](completions/cx.fish) |

Cover the full subcommand list (`fmt`, `canonical`, `hash`, `eq`,
`diff`, `lint`, `validate`, `table`, `demo`, `scaffold`, `eval`,
`select`, `upgrade-config`, `lsp`), per-subcommand flags, and file
extension completion for `.cx` / `.cxs` / `.cxl` / `.xml` / `.json` /
`.md` / `.yaml` / `.toml` / `.arrow` / `.parquet`.

## Capabilities (`cx lsp`)

| Feature | Status |
| --- | --- |
| `textDocument/didOpen` / `didChange` (Full sync) / `didClose` | ✅ |
| `textDocument/publishDiagnostics` (libcx parse errors) | ✅ |
| `textDocument/hover` (directive + module-fn docstrings) | ✅ |
| `textDocument/completion` (snippet-flavoured directive skeletons) | ✅ |
| `textDocument/semanticTokens/full` (10-type legend) | ✅ |
| `textDocument/formatting` (wraps `cx fmt`) | ✅ |
| `textDocument/definition` (`#id` resolution) | ✅ |
| `textDocument/documentSymbol` (nested outline) | ✅ |
| `textDocument/foldingRange` (bracket-balanced) | ✅ |
| `textDocument/selectionRange` (innermost-out chain) | ✅ |
| `textDocument/references` (`#id` / `@id` uses) | ✅ |
| `textDocument/prepareRename` + `rename` (cross-document `#id`) | ✅ |
| `textDocument/signatureHelp` (directive param hints) | ✅ |
| `textDocument/codeAction` (well-formed empty list — Phase 2 wires recipes) | 🚧 |
| `textDocument/inlayHint` (well-formed empty list — wired with cx-eval inference at v0.7.x) | 🚧 |

Incremental sync, populated codeActions, populated inlayHints → v0.7.x.

## Highlighting architecture (ADR 0025)

The canonical highlighters are **`cx lsp`** (LSP semanticTokens, for
editors that speak LSP) and **TextMate** (for VS Code without LSP,
GitHub web view, Shiki, docs sites). Both track the v0.7.0 directive
surface directly — `cx lsp` via libcx parse, TextMate via the curated
keyword set in [`syntax/cx.tmLanguage.json`](syntax/cx.tmLanguage.json).

The tree-sitter grammar at [`tree-sitter-cx/`](tree-sitter-cx/) is
**structural-only**: it tokenises element names, attributes, scalars,
code blocks, prose markup, and provides embedded-language injection
for `[``` lang=X [\| … \|] ]` blocks. Eval-directive interiors render
as opaque `(pi)` regions on purpose — see ADR 0025 for why we don't
maintain a parallel CFG-shaped parser against libcx.
