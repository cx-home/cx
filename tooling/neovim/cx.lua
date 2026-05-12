-- CX language support for Neovim 0.11+
--
-- SETUP:
--   1. Install the tree-sitter grammar:
--        cd tooling/tree-sitter-cx && make install-nvim
--   2. Install the language server somewhere discoverable:
--        cd tooling/lsp && npm install && npm run build
--      Then either:
--        - Set the CX_LSP_PATH env var to the server.js absolute path, OR
--        - Symlink to one of the searched paths (see find_lsp_server below)
--   3. Drop this file into your plugin directory.
--      LazyVim / lazy.nvim: place at lua/plugins/cx.lua
--      Plain init.lua: require() it directly
--
-- Requires: Neovim 0.11+, Node.js >= 18 (for LSP).

vim.filetype.add({ extension = { cx = "cx" } })
vim.treesitter.language.register("cx", "cx")

-- Resolve the LSP server.js path. Searches (in order):
--   1. CX_LSP_PATH env var (explicit override)
--   2. Standard install locations
local function find_lsp_server()
  local override = vim.env.CX_LSP_PATH
  if override and override ~= "" and vim.fn.filereadable(override) == 1 then
    return override
  end

  local candidates = {
    vim.fn.expand("~/.local/share/cx-lsp/out/server.js"),
    "/usr/local/share/cx-lsp/out/server.js",
    "/opt/homebrew/share/cx-lsp/out/server.js",
  }
  for _, c in ipairs(candidates) do
    if vim.fn.filereadable(c) == 1 then
      return c
    end
  end

  return nil
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      local server_path = find_lsp_server()
      if not server_path then
        vim.notify(
          "CX: language server not found. Install tooling/lsp/ and either " ..
          "symlink to ~/.local/share/cx-lsp/, set CX_LSP_PATH, or override " ..
          "opts.servers.cx_ls.cmd in your config.",
          vim.log.levels.WARN
        )
        return
      end

      opts.servers.cx_ls = {
        cmd = { "node", server_path, "--stdio" },
        filetypes = { "cx" },
        root_markers = { "v.mod", ".git" },
        single_file_support = true,
        mason = false,
      }
    end,
  },
}
