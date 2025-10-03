-- lua/neovault/buf.lua
local M = {}

function M.set_explorer_buffer_opts(buf)
  vim.bo[buf].bufhidden  = 'hide'
  vim.bo[buf].buftype    = 'nofile'
  vim.bo[buf].filetype   = 'neovault-explorer'
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly   = true
  vim.bo[buf].swapfile   = false
end

function M.set_yaml_buffer_opts(buf)
  vim.bo[buf].bufhidden  = 'hide'
  vim.bo[buf].buflisted  = false
  vim.bo[buf].buftype    = 'acwrite'
  vim.bo[buf].filetype   = 'yaml'
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly   = false
  vim.bo[buf].swapfile   = false
end

return M
