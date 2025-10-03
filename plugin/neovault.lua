-- Entry point for the neovault plugin.
-- Manages the user command, buffer state, and keymaps.

local neovault = require('neovault')
local vault_cli = require('neovault.vault_cli')

-- Plugin state management
local state = {
  current_path = "",
  mount_point = vim.g.vault_mount_point or "secret",
  history = {}
}

-- Refreshes the buffer with the given paths.
-- @param paths table A table of strings representing the paths.
local function update_buffer(paths)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
  if paths and #paths > 0 then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, paths)
  else
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '(empty)' })
  end
  vim.api.nvim_buf_set_option(0, 'filetype', 'neovault-explorer')
end

-- Function to follow a selected path (mapped to `<CR>`).
function _G.neovault_follow_path()
  local selected_line = vim.api.nvim_get_current_line()
  if selected_line == '(empty)' then return end
  
  local full_path = state.current_path .. selected_line
  
  -- Check if the path is a directory (ends with a slash)
  if selected_line:sub(-1) == '/' then
    -- It's a directory, list its contents
    local paths = vault_cli.list_paths(state.mount_point, full_path)
    if paths and #paths > 0 then
      state.current_path = full_path
      table.insert(state.history, state.current_path)
      update_buffer(paths)
    else
      vim.notify("Directory is empty or inaccessible.", vim.log.levels.INFO)
    end
  else
    -- It's a secret (leaf), read its content
    local secret_data = vault_cli.read_secret(state.mount_point, full_path)
    if secret_data then
      local yaml_content = ""
      for k, v in pairs(secret_data) do
        yaml_content = yaml_content .. string.format("%s: %s\n", k, tostring(v))
      end
      
      vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(yaml_content, '\n'))
      vim.api.nvim_buf_set_option(0, 'filetype', 'yaml')
      vim.api.nvim_buf_set_option(0, 'readonly', true)
    else
      vim.notify("Could not read secret or secret does not exist.", vim.log.levels.ERROR)
    end
  end
end

-- Function to go back to the parent path (mapped to `<BS>`).
function _G.neovault_go_back()
  if #state.history > 1 then
    table.remove(state.history)
    state.current_path = state.history[#state.history]
    local paths = vault_cli.list_paths(state.mount_point, state.current_path)
    update_buffer(paths)
  end
end

-- User command to start the vault explorer.
vim.api.nvim_create_user_command('VaultExplorer', function(opts)
  if not vim.env.VAULT_ADDR or not vim.env.VAULT_TOKEN then
    vim.notify("VAULT_ADDR or VAULT_TOKEN environment variables are not set.", vim.log.levels.WARN)
    return
  end

  vim.cmd('enew')
  vim.api.nvim_buf_set_option(0, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(0, 'swapfile', false)

  local config = neovault.get_config()

  -- Analyse de l'argument passé
  local arg = opts.fargs[1] or ""
  local mount_point, path = arg:match("([^/]+)/?(.*)")

  -- Si aucun argument, on utilise la config
  mount_point = mount_point or config.mount_point
  path = path or ""

  state.mount_point = mount_point
  state.current_path = path
  state.history = { state.current_path }

  local paths = vault_cli.list_paths(state.mount_point, state.current_path)
  update_buffer(paths)

  vim.api.nvim_buf_set_keymap(0, 'n', '<CR>', ':lua _G.neovault_handle_cr()<CR>', { silent = true, noremap = true })
  vim.api.nvim_buf_set_keymap(0, 'n', '<BS>', ':lua _G.neovault_handle_bs()<CR>', { silent = true, noremap = true })
end, {
  nargs = '?',
  complete = 'file',
  desc = 'Explore Vault secrets. Usage: :VaultExplorer [mount_point/path]',
})

-- Fonction principale pour gérer les keybindings en fonction du filetype
function _G.neovault_handle_cr()
  local filetype = vim.api.nvim_buf_get_option(0, 'filetype')
  if filetype == 'neovault-explorer' then
    _G.neovault_follow_path()
  elseif filetype == 'yaml' then
    local line = vim.api.nvim_get_current_line()
    local colon_pos = line:find(':')

    if colon_pos then
      -- Extract the substring after the colon and leading spaces
      local value = line:sub(colon_pos + 1):match('^%s*(.*%S)$')

      if value then
        -- Copy the extracted value to the system clipboard
        vim.fn.setreg('+', value)
        vim.notify("Value copied to system clipboard: " .. value, vim.log.levels.INFO)
      else
        vim.notify("No value found to copy.", vim.log.levels.WARN)
      end
    else
      vim.notify("Not a key-value line.", vim.log.levels.WARN)
    end
  end
end

-- Ajoutez cette fonction de gestion pour Backspace
function _G.neovault_handle_bs()
  _G.neovault_go_back()
end

