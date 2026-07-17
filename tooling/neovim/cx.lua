-- CX language support for Neovim 0.11+ (LazyVim / lazy.nvim path).
--
-- The language server is built into the `cx` binary —
-- `cx lsp` speaks JSON-RPC 2.0 over stdio (vcx/cmd/lsp.v). No npm
-- toolchain, no separate server.js. Just `cx` on $PATH.
--
-- SETUP:
--   1. (Optional) Install the tree-sitter grammar for structural
--      highlighting + embedded-language injection into a block wrapped
--      by a language-named element ([python [| ... |]], [json [# ... #]])
--      or an explicit [code lang=X [| ... |]]:
--        cd tooling/tree-sitter-cx && make install-nvim
--   2. Ensure `cx` is on $PATH (or set $CX_BIN to an absolute path).
--   3. Drop this file into your plugin directory.
--      LazyVim / lazy.nvim: place at lua/plugins/cx.lua
--      Plain init.lua: require() it directly
--
-- Requires: Neovim 0.11+.

vim.filetype.add({ extension = { cx = 'cx', cxd = 'cx', cxs = 'cx' } })
vim.treesitter.language.register('cx', 'cx')

-- START tree-sitter highlighting for cx buffers. `language.register` above only
-- maps filetype→parser; it does NOT turn highlighting on. Without this, cx
-- buffers get only the (sparse) LSP semantic tokens and most structural tokens
-- (element names, attribute names, clause heads, …) render uncolored. This runs
-- the installed parser + queries/cx/highlights.scm; LSP semantic tokens then
-- layer on top (higher priority) for scope-aware refinements.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'cx',
  callback = function(ev)
    pcall(vim.treesitter.start, ev.buf, 'cx')
  end,
})

local function find_cx_bin()
  local override = vim.env.CX_BIN
  if override and override ~= '' and vim.fn.executable(override) == 1 then
    return override
  end
  if vim.fn.executable('cx') == 1 then
    return 'cx'
  end
  return nil
end

-- on_attach wires the full LSP capability surface to keybindings.
-- Surface covered: structured directives ([?match] / [?modify] /
-- [?def] / [?lib] / [?const]); CXPath value expressions with 12 axes +
-- reserved sigils ($_ / $_position / $_last) + (bind $name) step
-- annotation; bare pure / impure def modifiers. Lifted out of the
-- lazy spec so user configs can reuse it directly.
local function cx_on_attach(client, bufnr)
  local kmap = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
  end


  -- Format-on-save is ENABLED for CX buffers. `cx fmt` is the lossless
  -- canonical formatter: it round-trips comments and is idempotent
  -- (`fmt(fmt(x)) == fmt(x)`), so running it unattended on every save is
  -- safe — it normalises layout without losing data or oscillating.
  -- (It was previously disabled while `cx fmt` dropped comments and was
  -- non-idempotent on comma-arrays; both defects are fixed.) Manual
  -- `<leader>f` is also wired below.
  vim.b[bufnr].autoformat = true

  -- Navigation
  kmap('n', 'gd', vim.lsp.buf.definition,      'CX: go to definition')
  kmap('n', 'gr', vim.lsp.buf.references,      'CX: find references')
  kmap('n', 'gO', vim.lsp.buf.document_symbol, 'CX: outline')

  -- Information
  kmap('n', 'K',     vim.lsp.buf.hover,          'CX: hover docs')
  kmap('n', '<C-k>', vim.lsp.buf.signature_help, 'CX: signature help')
  kmap('i', '<C-k>', vim.lsp.buf.signature_help, 'CX: signature help')

  -- Editing
  kmap('n', '<leader>r', vim.lsp.buf.rename,      'CX: rename #id')
  kmap('n', '<leader>a', vim.lsp.buf.code_action, 'CX: code action')
  kmap('n', '<leader>f', function() vim.lsp.buf.format({ async = true }) end, 'CX: format buffer')
  kmap('i', '<C-Space>', vim.lsp.completion.get,  'CX: completion (snippet)')

  -- Diagnostics
  kmap('n', ']d',       vim.diagnostic.goto_next,  'CX: next diagnostic')
  kmap('n', '[d',       vim.diagnostic.goto_prev,  'CX: prev diagnostic')
  kmap('n', '<leader>d', vim.diagnostic.open_float, 'CX: show diagnostic')

  -- Inlay hints (placeholder; populated inlayHints pending)
  if client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end

  -- Smart structural selection (selectionRange)
  vim.keymap.set({ 'n', 'v' }, '<leader>v', function()
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.lsp.buf_request(bufnr, 'textDocument/selectionRange', {
      textDocument = vim.lsp.util.make_text_document_params(),
      positions = { { line = pos[1] - 1, character = pos[2] } },
    }, function(_, result)
      if not result or not result[1] then return end
      local r = result[1].range
      vim.api.nvim_buf_set_mark(bufnr, '<', r.start.line + 1, r.start.character, {})
      vim.api.nvim_buf_set_mark(bufnr, '>', r['end'].line + 1, r['end'].character, {})
      vim.cmd('normal! gv')
    end)
  end, { buffer = bufnr, desc = 'CX: expand selection' })
end

return {
  {
    'neovim/nvim-lspconfig',
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      local cx_bin = find_cx_bin()
      if not cx_bin then
        vim.notify(
          'CX: `cx` binary not found on $PATH. Build it from source ' ..
          '(`make build-vcx` in the cx repo produces vcx/target/cx — see ' ..
          'tooling/README.md), then add it to $PATH or set $CX_BIN to an ' ..
          'absolute path.',
          vim.log.levels.WARN
        )
        return
      end

      opts.servers.cx_ls = {
        cmd              = { cx_bin, 'lsp' },
        filetypes        = { 'cx' },
        root_markers     = { '.cxlint.cx', 'v.mod', '.git' },
        single_file_support = true,
        mason            = false,
        on_attach        = cx_on_attach,
      }
    end,
  },
}
