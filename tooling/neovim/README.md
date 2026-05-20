# CX — Neovim Setup

LSP-driven highlighting + diagnostics + hover + completion + goto
for `.cx` files. Since v0.7.0 the language server is built into the
`cx` binary — `cx lsp` speaks JSON-RPC 2.0 over stdio.

**Requirements:** Neovim ≥ 0.11, `cx` on `$PATH` (or `CX_BIN` env var).

**Highlighting architecture (ADR 0025).** `cx lsp` semanticTokens are
the source of truth for v0.7.0+ directive interiors (`?if`/`?for`/
`?fn`/`?match`/`?let`/FLWOR slots/operator tokens). Tree-sitter is
structural-only: it tokenises element names, attributes, scalars,
prose markup, code blocks, and provides embedded-language injection
for `[``` lang=X [\| … \|] ]` blocks. **You want both** — LSP for
directive content, tree-sitter for embedded JSON/Python/SQL/etc.
inside code blocks.

---

## 1 — Install the tree-sitter parser (optional)

```sh
cd tooling/tree-sitter-cx
make install-nvim
```

This compiles the grammar and copies the parser + query files to
`~/.local/share/nvim/site/`. Re-run after any grammar change.

---

## 2 — Install the Neovim plugin

Copy [`cx.lua`](cx.lua) into your Neovim plugin directory:

**lazy.nvim / LazyVim:**
```sh
cp tooling/neovim/cx.lua ~/.config/nvim/lua/plugins/cx.lua
```

**Plain init.lua:**
```lua
dofile('/path/to/cx-repo/tooling/neovim/cx.lua')
```

---

## 3 — Confirm `cx` is on $PATH

```sh
which cx          # → /usr/local/bin/cx (or wherever)
cx --version      # → cx 0.7.0
```

If `cx` lives somewhere non-standard, set `CX_BIN=/abs/path/to/cx` in
your shell init.

---

## What you get

| Feature | Source |
| --- | --- |
| Syntax highlighting | Tree-sitter when installed; LSP semanticTokens otherwise |
| Embedded languages | JSON / YAML / Python / Bash / JS / TS / Rust / Go / SQL / CSS / HTML / XML inside `[``` lang=X [\| … \|] ]` blocks (tree-sitter only) |
| Diagnostics | Live, on every change (`publishDiagnostics` from libcx parse) |
| Hover | Directive docs + module-function docstrings |
| Completion | Snippet-flavoured directive skeletons + module surface |
| Goto definition | `#id` declaration sites (`gd`) |
| Find references | All `#id`/`@id` uses (`gr`) |
| Rename symbol | Cross-document `#id` rename (`<leader>r`) |
| Outline view | Document symbols (`gO`) |
| Code folding | LSP `foldingRange` (every multi-line `[...]`) |
| Smart selection | Expand to enclosing directive / element / doc (`<leader>v`) |
| Signature help | Param hints inside `[?fn ...]` bodies (`<C-k>`) |
| Code action | Quick fixes from diagnostics (`<leader>a`) |
| Format | Buffer-format wraps `cx fmt` (`<leader>f`) |

## Default keymaps

The bundled `cx.lua` plugin wires the following on LSP attach:

| Key | Mode | Action |
| --- | --- | --- |
| `K`         | n   | Hover docs |
| `gd`        | n   | Go to definition |
| `gr`        | n   | Find references |
| `gO`        | n   | Outline (document symbols) |
| `<C-k>`     | n/i | Signature help |
| `<leader>r` | n   | Rename `#id` |
| `<leader>a` | n   | Code action |
| `<leader>f` | n   | Format buffer |
| `<leader>v` | n/v | Expand selection (LSP selectionRange) |
| `<leader>d` | n   | Show diagnostic at cursor |
| `]d` / `[d` | n   | Next / previous diagnostic |
| `<C-Space>` | i   | Trigger completion |

Override any of these by passing a custom `on_attach` via the
lazy.nvim opts.

---

## Fallback: Vim-regex highlighting (no tree-sitter, no LSP)

Useful as a minimal config when the binary isn't available yet.

```sh
cp -r tooling/neovim/syntax   ~/.config/nvim/
cp -r tooling/neovim/ftdetect ~/.config/nvim/
```

---

## Troubleshooting

**No highlighting after install:**
Restart Neovim. Run `:lua print(vim.treesitter.language.inspect("cx"))` —
if it errors, the parser isn't installed. Re-run `make install-nvim`.

**LSP not starting:**
```vim
:LspInfo
:lua =vim.fn.executable("cx")
```
Expected: `cx_ls` attached, `vim.fn.executable("cx")` returns 1.

**Verbose LSP trace:**
Set `cmd = { cx_bin, "lsp", "--verbose" }` and watch `:LspLog`.

**Highlighting broke after grammar change:**
Re-run `make install-nvim` and restart Neovim.
