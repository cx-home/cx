# CX — Neovim Setup

LSP-driven highlighting + diagnostics + hover + completion + goto
for `.cx` files. The language server is built into the `cx` binary —
`cx lsp` speaks JSON-RPC 2.0 over stdio.

**Requirements:** Neovim ≥ 0.11, `cx` on `$PATH` (or `CX_BIN` env var).

**Highlighting architecture.** `cx lsp` semanticTokens are
the source of truth for directive interiors — the full
directive registry per spec/code.md §4.1, including the structured
additions `[?def]` / `[?lib]` / `[?const]` (code.md §12.2 / code.md §12.1/§12.3),
multi-arm `[?match]` with `[case]` / `[when]` / `[where]` / `[else]`
clause-children (code.md §8.2), `[?modify]` with the eleven action
clauses (`[set]` / `[delete]` / `[using]` / `[rename]` / `[set-attr]` /
`[delete-attr]` / `[append]` / `[prepend]` / `[insert-before]` /
`[insert-after]` / `[replace]`, code.md §8.10), CXPath value
expressions with 12 axes + reserved sigils `$_` / `$_position` /
`$_last` + `(bind $name)` step annotation (code.md §5.5 + code.md §5.5.2), and
`pure` / `impure` def modifiers (code.md §12.2).
Tree-sitter is structural plus the structured directives
(`match_directive` / `modify_directive` / `def_directive` /
`lib_directive` / `const_directive`); legacy directives fall through
to opaque `unknown_directive` regions. Embedded-language injection — into a
block wrapped by a language-named element (`[python [\| … \|] ]`,
`[json [# … #]]`) or an explicit `[code lang=X [\| … \|] ]` — works for both.
**You want both** — LSP for full directive content, tree-sitter for embedded
JSON / Python / SQL / etc. inside those blocks and structural fallback when
LSP is off.

---

## 1 — Install the tree-sitter parser (optional)

```sh
cd tooling/tree-sitter-cx
make install-nvim
```

This compiles the grammar (pinned at ABI 14) and installs into
`~/.local/share/nvim/site/`:

| File | Installed to |
| --- | --- |
| parser | `~/.local/share/nvim/site/parser/cx.so` |
| highlight/injection queries | `~/.local/share/nvim/site/queries/cx/*.scm` |
| ftplugin (brackets, comments) | `~/.local/share/nvim/site/ftplugin/cx.vim` |
| indent | `~/.local/share/nvim/site/indent/cx.vim` |

Re-run after any grammar change.

---

## 2 — Install the Neovim plugin

`tooling/neovim/` IS a plugin root (`lua/` module + `plugin/` +
the standard ftdetect/ftplugin/indent/syntax rtp dirs), so point your
plugin manager straight at it — no file copying. The LSP registers
through Neovim 0.11's native `vim.lsp.config`, so there is no
nvim-lspconfig dependency.

**lazy.nvim / LazyVim** — one spec entry naming your cx checkout:
```lua
-- ~/.config/nvim/lua/plugins/cx.lua
return {
  { dir = '/path/to/cx/tooling/neovim' },
}
```

**Plain init.lua:**
```lua
vim.opt.rtp:append('/path/to/cx/tooling/neovim')
require('cx').setup()
```

Custom keymaps / binary path: set `vim.g.cx_no_auto_setup = true` and
call `require('cx').setup({ cx_bin = …, on_attach = … })` yourself
(`require('cx').on_attach` is exported for extension).

(The old copy-`cx.lua`-into-your-config flow is retired; a previously
copied file keeps working but no longer receives updates — switch to
the `dir =` spec.)

---

## 3 — Confirm `cx` is on $PATH

```sh
which cx          # → /usr/local/bin/cx (or wherever)
cx --version      # → prints the cx version
```

If `cx` lives somewhere non-standard, set `CX_BIN=/abs/path/to/cx` in
your shell init.

---

## What you get

| Feature | Source |
| --- | --- |
| Syntax highlighting | Tree-sitter when installed; LSP semanticTokens otherwise |
| Embedded languages | JSON / YAML / Python / Bash / JS / TS / Rust / Go / SQL / CSS / HTML / XML / … inside a block wrapped by a language-named element — `[python [\| … \|] ]`, `[json [# … #]]` — or an explicit `[code lang=X [\| … \|] ]` (tree-sitter only; the injected parser must be installed) |
| Diagnostics | Live, on every change (`publishDiagnostics` from libcx parse) |
| Hover | Directive docs + module-function docstrings |
| Completion | Snippet-flavoured directive skeletons + module surface |
| Goto definition | `#id` declaration sites (`gd`) |
| Find references | All `#id`/`@id` uses (`gr`) |
| Rename symbol | Cross-document `#id` rename (`<leader>r`) |
| Outline view | Document symbols (`gO`) |
| Code folding | LSP `foldingRange` (every multi-line `[...]`) |
| Smart selection | Expand to enclosing directive / element / doc (`<leader>v`) |
| Signature help | Param hints inside `[?fn ...]` / `[?def ...]` bodies (`<C-k>`) |
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
cp -r tooling/neovim/ftplugin ~/.config/nvim/
cp -r tooling/neovim/indent   ~/.config/nvim/
```

---

## Folding without the LSP

With the LSP attached, folding comes from `foldingRange` (every
multi-line `[...]`). Without it, use one of:

**Tree-sitter folds** (parser installed via `make install-nvim`):
```lua
vim.opt.foldmethod = 'expr'
vim.opt.foldexpr   = 'v:lua.vim.treesitter.foldexpr()'
vim.opt.foldlevel  = 99   -- open all folds by default
```

**Pure-Vim indent folds** (no parser needed; pairs with the bundled
indent file, since CX indentation tracks bracket depth):
```vim
setlocal foldmethod=indent
setlocal foldlevel=99
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
