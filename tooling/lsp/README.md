# `cx lsp` — Language Server for CX

Ships in `cx` itself. No tree-sitter dependency, no separate
binary. `cx lsp` reads JSON-RPC 2.0 over stdio per the [Language Server
Protocol spec](https://microsoft.github.io/language-server-protocol/).

## Capabilities

The table below mirrors the `initialize` response exactly —
[`tests/check_capabilities.py`](tests/check_capabilities.py) drives a
live `cx lsp` over stdio and fails when the server and this table
disagree (`python3 tooling/lsp/tests/check_capabilities.py [/path/to/cx]`).

| Feature                              | Status |
| ------------------------------------ | ------ |
| `textDocument/didOpen` / `didChange` (full sync) / `didClose` | ✅ |
| `textDocument/publishDiagnostics`    | ✅     |
| `textDocument/hover`                 | ✅     |
| `textDocument/completion`            | ✅     |
| `textDocument/semanticTokens/full`   | ✅     |
| `textDocument/formatting`            | ✅     |
| `textDocument/definition`            | ✅ (#id) |
| `textDocument/documentSymbol` (nested outline) | ✅ |
| `textDocument/foldingRange` (bracket-balanced) | ✅ |
| `textDocument/selectionRange` (innermost-out chain) | ✅ |
| `textDocument/references` (`#id` / `@id` uses) | ✅ |
| `textDocument/prepareRename` + `rename` (cross-document `#id`) | ✅ |
| `textDocument/codeLens` (§4.1 directive CodeLens) | ✅ |
| `textDocument/signatureHelp`         | ✅     |
| `textDocument/codeAction` (advertised; returns a well-formed empty list — recipes pending) | 🚧 |
| `textDocument/inlayHint` (advertised; returns a well-formed empty list — populated hints pending) | 🚧 |

## Diagnostic + completion surface

Seven diagnostic codes (`CXLS001`–`CXLS007`), a CXPath hover provider, and
a path-context completion provider are implemented (`CXLS008` is reserved,
not yet implemented). Codes and protocol slots are contracted in
[`diagnostics.md`](diagnostics.md).

## Editor integration

| Editor   | Config file                              |
| -------- | ---------------------------------------- |
| VS Code  | [`vscode.example.json`](vscode.example.json)   |
| Neovim   | [`neovim.example.lua`](neovim.example.lua)     |
| Helix    | [`helix.example.toml`](helix.example.toml)     |

All three configs assume `cx` is on `$PATH`. The server speaks JSON-RPC
over stdio — no port, no socket, no daemon.

## Debugging

Run with `--verbose` and pipe stderr to a file to trace incoming
methods:

```sh
cx lsp --verbose 2>/tmp/cx-lsp.log
```

Smoke test from a shell (manual JSON-RPC echo):

```sh
python3 - <<'EOF' | cx lsp
import sys, json
def msg(o):
    b = json.dumps(o)
    sys.stdout.write(f"Content-Length: {len(b)}\r\n\r\n{b}")
msg({"jsonrpc":"2.0","id":1,"method":"initialize","params":{}})
msg({"jsonrpc":"2.0","id":2,"method":"shutdown","params":None})
msg({"jsonrpc":"2.0","method":"exit","params":None})
EOF
```
