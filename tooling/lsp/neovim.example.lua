-- Neovim: cx language server registration via the built-in `vim.lsp`
-- client. Tested on Neovim 0.10+. Requires `cx` on PATH (override with
-- $CX_BIN if installed elsewhere).
--
-- Drop into ~/.config/nvim/lua/cx.lua and `require('cx').setup()` from
-- init.lua, or paste inline.

local M = {}

function M.setup(opts)
  opts = opts or {}
  local cx_bin = opts.cx_bin or vim.env.CX_BIN or 'cx'
  local server_args = opts.server_args or { 'lsp' }

  vim.filetype.add({
    extension = {
      cx = 'cx',
      cxs = 'cx',
      cxl = 'cx',
    },
  })

  local group = vim.api.nvim_create_augroup('cx_lsp', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = 'cx',
    callback = function()
      vim.lsp.start({
        name = 'cx',
        cmd = vim.list_extend({ cx_bin }, server_args),
        root_dir = vim.fs.dirname(
          vim.fs.find({ '.git', 'cx.yaml', 'cxlint.yaml' }, { upward = true })[1]
        ) or vim.fn.getcwd(),
        on_attach = function(client, bufnr)
          local kmap = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
          end

          -- ── Navigation ────────────────────────────────────────────
          kmap('n', 'gd', vim.lsp.buf.definition,       'CX: go to definition')
          kmap('n', 'gr', vim.lsp.buf.references,       'CX: find references')
          kmap('n', 'gO', vim.lsp.buf.document_symbol,  'CX: outline')

          -- ── Information ───────────────────────────────────────────
          kmap('n', 'K',         vim.lsp.buf.hover,          'CX: hover docs')
          kmap('n', '<C-k>',     vim.lsp.buf.signature_help, 'CX: signature help')
          kmap('i', '<C-k>',     vim.lsp.buf.signature_help, 'CX: signature help')

          -- ── Editing ───────────────────────────────────────────────
          kmap('n', '<leader>r', vim.lsp.buf.rename,         'CX: rename #id')
          kmap('n', '<leader>a', vim.lsp.buf.code_action,    'CX: code action')
          kmap('n', '<leader>f', function() vim.lsp.buf.format({ async = true }) end, 'CX: format buffer')
          kmap('i', '<C-Space>', vim.lsp.completion.get,     'CX: completion (snippet)')

          -- ── Diagnostics ───────────────────────────────────────────
          kmap('n', ']d', vim.diagnostic.goto_next, 'CX: next diagnostic')
          kmap('n', '[d', vim.diagnostic.goto_prev, 'CX: prev diagnostic')
          kmap('n', '<leader>d', vim.diagnostic.open_float, 'CX: show diagnostic')

          -- ── Inlay hints (LSP semanticTokens + inlayHint) ──────────
          if client.server_capabilities.inlayHintProvider
             and vim.lsp.inlay_hint then
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
          end

          -- ── Smart structural selection (selectionRange) ───────────
          -- Bind to <leader>v for "expand selection" — uses LSP
          -- selectionRange to grow from word → enclosing directive →
          -- parent element → … → document.
          kmap({'n', 'v'}, '<leader>v', function()
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
          end, 'CX: expand selection')

          -- ── Format on save (off by default; enable per project) ───
          -- Safe to enable: `cx fmt` is the lossless canonical formatter —
          -- it round-trips comments and is idempotent (`fmt(fmt(x)) ==
          -- fmt(x)`), so format-on-save normalises layout without losing
          -- data or oscillating between forms.
          if opts.format_on_save then
            vim.api.nvim_create_autocmd('BufWritePre', {
              buffer = bufnr,
              callback = function() vim.lsp.buf.format({ async = false }) end,
            })
          end
        end,
      })
    end,
  })
end

return M
