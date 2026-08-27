# `cx lsp` — Language Server for CX

Ships in `cx` itself. No tree-sitter dependency, no separate
binary. `cx lsp` reads JSON-RPC 2.0 over stdio per the [Language Server
Protocol spec](https://microsoft.github.io/language-server-protocol/).

## Capabilities

The table below mirrors the `initialize` response exactly. What holds it
to that is `vcx/tests/lint_lsp_umbrella_test.v` (#996), which drives a live
`cx lsp` over real stdio framing and pins the advertised capability roster
in both directions — a key the server stops advertising and a key it starts
advertising both fail — plus the shapes clients branch on, and a request per
advertised capability so that advertising something with no handler behind it
fails too. It runs in `make test-vcx-suite`, so this table cannot drift
quietly.

There is no separate capability-check script. `tests/check_capabilities.cx`
was one until #1003: it duplicated the roster, could not actually compare
itself against this table (its expectations were a second hardcoded copy),
hung forever whenever the server it spawned said more than 64 KiB on stderr,
and was wired into no make target. The one assertion it carried that the
harness did not — what the list-returning providers put on the wire — now
lives in the harness.

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
| `textDocument/inlayHint` (declared `[?pipe]`-stage return-type hints) | ✅ |

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

Smoke test from a shell (manual JSON-RPC echo). Note the redirections: the
server's response to a single request can run to six figures of bytes
(`textDocument/completion` answers with ~159 KB on the fixtures in
`tests/`), so drive it through **files**, never an interactive pipe you are
not draining — a full 64 KiB pipe wedges the server mid-write (#1003).

```sh
frame() { printf 'Content-Length: %s\r\n\r\n%s' "$(printf %s "$1" | wc -c)" "$1"; }
{
  frame '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
  frame '{"jsonrpc":"2.0","id":2,"method":"shutdown","params":null}'
  frame '{"jsonrpc":"2.0","method":"exit"}'
} > /tmp/cx-lsp-in.bin

cx lsp < /tmp/cx-lsp-in.bin > /tmp/cx-lsp-out.bin 2> /tmp/cx-lsp-err.log
```

For anything past a smoke test, use [`tests/probe.cx`](tests/probe.cx) — it
drives a whole session for one file and position, on the same bounded
file-fed shape.
