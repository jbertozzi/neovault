-- Lua module entry point for neovault.
local utils = require('neovault.utils')
local M = {}

-- default config
local config = {
  mount_point = "secret"
}

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
  config.mount_point = utils.ensure_trailing_slash(config.mount_point)
end

function M.get_config()
  return config
end

return M
