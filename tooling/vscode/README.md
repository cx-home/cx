# CX Language — VS Code extension

Syntax highlighting + LSP (diagnostics, hover, completion, goto,
references, rename, formatting, outline, folding, smart selection,
signature help) + snippets for `.cx` / `.cxs` / `.cxl` files.

## Requirements

- VS Code ≥ 1.75
- `cx` binary v0.7.0+ on `$PATH` (or configure `cx.serverPath`)

Install `cx`:

```sh
brew install cx-home/tap/cx                 # macOS / Linuxbrew
cargo install --git https://github.com/cx-home/cx cx-cli   # from source
```

## What you get

| Feature | Source |
| --- | --- |
| Syntax highlighting | TextMate grammar (`syntaxes/cx.tmLanguage.json`) |
| Live diagnostics | LSP `publishDiagnostics` from libcx parse |
| Hover docs | LSP `textDocument/hover` |
| Completion | LSP `textDocument/completion` (snippet-flavoured) |
| Goto definition | LSP `textDocument/definition` (`#id` resolution) |
| Find references | LSP `textDocument/references` |
| Rename symbol (`F2`) | LSP `textDocument/rename` (cross-document `#id`) |
| Outline view | LSP `textDocument/documentSymbol` |
| Code folding | LSP `textDocument/foldingRange` |
| Smart selection | LSP `textDocument/selectionRange` (alt-shift-→) |
| Signature help | LSP `textDocument/signatureHelp` (directive params) |
| Formatting | LSP `textDocument/formatting` (wraps `cx fmt`) |
| Semantic colouring | LSP `textDocument/semanticTokens/full` |
| Snippets | `snippets/cx.json` (`?if`, `?for`, `?fn`, `?match`, `?try`, …) |

## Settings

| Key | Default | Effect |
| --- | --- | --- |
| `cx.serverPath` | `"cx"` | Binary to run for the language server |
| `cx.serverArgs` | `["lsp"]` | Arguments passed to the binary |
| `cx.trace.server` | `"off"` | LSP-protocol tracing (`off` / `messages` / `verbose`) |
| `cx.formatOnSave` | `false` | Run `cx fmt` on save |

## Commands

| Command | Effect |
| --- | --- |
| `CX: Restart Language Server` | Reload after editing settings |
| `CX: Show Server Version` | Confirm which `cx` is running |

## Build

```sh
cd tooling/vscode
npm install
npm run build
npm run package      # produces cx-language-0.7.0.vsix
code --install-extension cx-language-0.7.0.vsix
```

The build is intentionally vendored-free — the only dependency that
ships in the `.vsix` is `vscode-languageclient` (the LSP-client glue).
The language server itself is the `cx` binary, installed separately.

## Marketplace publication

This package is set up for publication under the `cx-home` publisher
ID. Per-tag publication runs from the v0.7.x release workflow.
