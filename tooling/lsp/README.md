# `cx lsp` — Language Server for CX

Ships in `cx` itself (v0.7.6). No tree-sitter dependency, no separate
binary. `cx lsp` reads JSON-RPC 2.0 over stdio per the [Language Server
Protocol spec](https://microsoft.github.io/language-server-protocol/).

## Capabilities (v0.7.6)

| Feature                              | Status |
| ------------------------------------ | ------ |
| `textDocument/didOpen`               | ✅     |
| `textDocument/didChange` (full sync) | ✅     |
| `textDocument/didClose`              | ✅     |
| `textDocument/publishDiagnostics`    | ✅     |
| `textDocument/hover`                 | ✅     |
| `textDocument/completion`            | ✅     |
| `textDocument/semanticTokens/full`   | ✅     |
| `textDocument/formatting`            | ✅     |
| `textDocument/definition`            | ✅ (#id) |
| `textDocument/codeLens` (v0.7.6 §4.1 directive CodeLens) | ✅ |

Incremental sync, signature help, code actions, and rename arrive in
v0.7.x.

## v0.8.0 diagnostic + completion surface

The v0.8.0 surface (ADRs 0028 / 0029 / 0030) reserves four new
diagnostic codes (`CXLS001`–`CXLS004`), a CXPath hover provider, and
a path-context completion provider. Codes and protocol slots are
contracted in
[`v0_8_0_diagnostics.md`](v0_8_0_diagnostics.md); the V
implementation is tracked in Phase 5.5 of the v0.8.0 session.

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
