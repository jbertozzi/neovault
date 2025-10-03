-- plugin/neovault.lua

local neovault = require('neovault')
local vault_cli = require('neovault.vault_cli')
local utils = require('neovault.utils')

-- plugin state
local state = {
  current_path = "",
  mount_point = vim.g.vault_mount_point or "secret",
  history = {},
  open_secret_path = nil, -- current secet path (for :w)
}

-- parse YAML "key: value"
local function parse_simple_yaml(lines)
  local t = {}
  for _, line in ipairs(lines) do
    -- ignore empty and comment
    if line:match('^%s*$') or line:match('^%s*#') then
      -- skip
    else
      local key, value = line:match("^%s*(.-)%s*:%s*(.-)%s*$")
      if key and #key > 0 then
        t[key] = value or ""
      end
    end
  end
  return t
end

-- update buffer
local function update_buffer(paths)
  local buf = 0
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  if paths and #paths > 0 then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, paths)
  else
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '(empty)' })
  end
  utils.set_explorer_buffer_opts(buf)
end

-- follow the path (<CR> when exploring)
function _G.neovault_follow_path()
  local selected_line = vim.api.nvim_get_current_line()
  if selected_line == '(empty)' then return end

  local full_path = state.current_path .. selected_line

  if selected_line:sub(-1) == '/' then
    -- folder -> list
    local paths = vault_cli.list_paths(state.mount_point, full_path)
    if paths and #paths > 0 then
      state.current_path = full_path
      table.insert(state.history, state.current_path)
      update_buffer(paths)
    else
      vim.notify("Directory is empty or inaccessible.", vim.log.levels.INFO)
    end
  else
    -- secret -> read and display
    local secret_data = vault_cli.read_secret(state.mount_point, full_path)
    if secret_data then
      local yaml_content = {}
      for k, v in pairs(secret_data) do
        table.insert(yaml_content, string.format("%s: %s", k, tostring(v)))
      end

      local buf = 0

      local virt_name = string.format("neovault://%s/%s.yaml", state.mount_point, full_path)
      pcall(vim.api.nvim_buf_set_name, buf, virt_name)
      vim.bo[buf].buflisted = false


      set_yaml_buffer_opts(buf)

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, yaml_content)
      utils.map_copy_value_cr(buf, {
        register = '+',
        notify = true,
        strip_quotes = true,
        strip_inline_comment = true,
    })

      -- context
      vim.b.neovault = true
      vim.b.neovault_secret_path = full_path
      vim.b.neovault_mount       = state.mount_point
      state.open_secret_path     = full_path

      -- autocmd
      local grp = vim.api.nvim_create_augroup('neovault_write_' .. tostring(buf), { clear = true })

      vim.api.nvim_create_autocmd('BufWriteCmd', {
        group = grp,
        buffer = buf,
        callback = function(ev)
          local lines = vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false)
          local data  = parse_simple_yaml(lines)

          if not vim.b.neovault_secret_path or not vim.b.neovault_mount then
            vim.notify("Missing secret path/mount in buffer.", vim.log.levels.ERROR)
            return
          end

          local ok = select(1, vault_cli.write_secret(vim.b.neovault_mount, vim.b.neovault_secret_path, data))

          if ok then
            vim.notify("Secret updated successfully.", vim.log.levels.INFO)
            vim.api.nvim_buf_set_option(ev.buf, 'modified', false)
          else
            vim.notify("Failed to update secret (see :messages).", vim.log.levels.ERROR)
          end
        end,
        desc = 'neovault: write secret to Vault',
      })
    else
      vim.notify("Could not read secret or secret does not exist.", vim.log.levels.ERROR)
    end
  end
end

-- go back to parent folder (<BS>)
function _G.neovault_go_back()
  if #state.history > 1 then
    table.remove(state.history)
    state.current_path = state.history[#state.history]
    local paths = vault_cli.list_paths(state.mount_point, state.current_path)
    update_buffer(paths)
  end
end

-- user command
vim.api.nvim_create_user_command('NeoVault', function(opts)
  if not vim.env.VAULT_ADDR or not vim.env.VAULT_TOKEN then
    vim.notify("VAULT_ADDR or VAULT_TOKEN environment variables are not set.", vim.log.levels.WARN)
    return
  end

  vim.cmd('enew')
  local buf = 0
  vim.bo[buf].swapfile = false

  local config = neovault.get_config()

  -- argument : "mount path"
  local arg = opts.fargs[1] or ""
  local mount_point, path = arg:match("([^/]+)/?(.*)")
  mount_point = mount_point or config.mount_point
  path = path or ""

  state.mount_point = mount_point
  state.current_path = path
  state.history = { state.current_path }
  state.open_secret_path = nil

  local paths = vault_cli.list_paths(state.mount_point, state.current_path)
  update_buffer(paths)

  -- Keymaps buffer‑local
  vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', ':lua _G.neovault_handle_cr()<CR>', { silent = true, noremap = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<BS>', ':lua _G.neovault_handle_bs()<CR>', { silent = true, noremap = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':bd!<CR>', { silent = true, noremap = true })
end, {
  nargs = '?',
  complete = 'file',
  desc = 'Explore Vault secrets. Usage: :NeoVault [mount_point/path]',
})

-- <CR> management depending filetype
function _G.neovault_handle_cr()
  local filetype = vim.api.nvim_buf_get_option(0, 'filetype')
  if filetype == 'neovault-explorer' then
    _G.neovault_follow_path()
  elseif filetype == 'yaml' then
    local line = vim.api.nvim_get_current_line()
    local colon_pos = line:find(':')
    if colon_pos then
      local value = line:sub(colon_pos + 1):match('^%s*(.*%S)$')
      if value then
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

function _G.neovault_handle_bs()
  _G.neovault_go_back()
end

vim.api.nvim_create_user_command('NeoVaultSearch', function(opts)
  local arg = opts.fargs[1]
  local mount = arg or require('neovault').get_config().mount_point
  require('neovault.telescope').search({ mount_point = mount })
end, {
  nargs = '?',
  complete = 'file', -- permet "secret/" etc.
  desc = 'Search Vault secrets via Telescope. Usage: :NeoVaultSearch [mount_point]',
})
