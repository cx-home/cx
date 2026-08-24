-- Auto-setup when tooling/neovim is loaded as a plugin (lazy.nvim
-- `{ dir = … }`, or rtp:append in a plain init.lua). A config that
-- wants custom opts sets `vim.g.cx_no_auto_setup = true` and calls
-- require('cx').setup{…} itself.
if vim.g.loaded_cx_plugin or vim.g.cx_no_auto_setup then
  return
end
vim.g.loaded_cx_plugin = true
require('cx').setup()
