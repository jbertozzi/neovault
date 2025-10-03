-- Lua module entry point for neovault.

local M = {}

-- default config
local config = {
  mount_point = "secret"
}

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
end

function M.get_config()
  return config
end

return M
