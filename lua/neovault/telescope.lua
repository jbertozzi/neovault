-- lua/neovault/telescope.lua
local utils = require('neovault.utils')
local M = {}

local pickers      = require('telescope.pickers')
local finders      = require('telescope.finders')
local previewers   = require('telescope.previewers')
local conf         = require('telescope.config').values
local actions      = require('telescope.actions')
local action_state = require('telescope.actions.state')
local Job          = require('plenary.job')

local neovault     = require('neovault')
local vault_cli    = require('neovault.vault_cli')

local cache = {}

-- get all paths
local function fetch_paths_with_rvault(mount_point, on_done)
  if cache[mount_point] and cache[mount_point].items then
    on_done(true, cache[mount_point].items)
    return
  end

  Job:new({
    command = 'rvault',
    args = { 'list', mount_point },
    on_exit = function(j, return_val)
      local ok = (return_val == 0)
      local result = j:result() or {}
      -- filter : keep only leafs
      local paths = {}
      for _, line in ipairs(result) do
        line = vim.trim(line)
        if line ~= '' and not line:match('/$') then
          table.insert(paths, line)
        end
      end
      cache[mount_point] = { items = paths }
      vim.schedule(function()
        on_done(ok, paths)
      end)
    end,
  }):start()
end

-- open secret in a editable buffer
local function open_secret_buffer(mount_point, full_path)
  local data = vault_cli.read_secret(mount_point, full_path)
  if not data then
    vim.notify("Could not read secret: " .. mount_point .. "/" .. full_path, vim.log.levels.ERROR)
    return
  end

  vim.cmd('enew')  -- new buffer
  local buf = 0

  local virt_name = string.format("neovault://%s/%s.yaml", mount_point, full_path)
  pcall(vim.api.nvim_buf_set_name, buf, virt_name)
  vim.b.neovault = true

  utils.set_yaml_buffer_opts(buf)

  -- content
  local yaml_content = utils.to_yaml_lines(data)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, yaml_content)

  utils.map_copy_value_cr(buf, {
    register = '+',
    notify = true,
    strip_quotes = true,
    strip_inline_comment = true,
  })

  -- Context
  vim.b.neovault_secret_path = full_path
  vim.b.neovault_mount       = mount_point

  -- Autocmd : :w -> vault kv put
  local grp = vim.api.nvim_create_augroup('neovault_write_' .. tostring(buf), { clear = true })
  vim.api.nvim_create_autocmd('BufWriteCmd', {
    group = grp,
    buffer = buf,
    callback = function(ev)
      local lines = vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false)
      -- parse très simple "clé: valeur" par ligne
      local out = {}
      for _, line in ipairs(lines) do
        if not line:match('^%s*$') and not line:match('^%s*#') then
          local key, value = line:match('^%s*(.-)%s*:%s*(.-)%s*$')
          if key and #key > 0 then out[key] = value or "" end
        end
      end
      local ok = select(1, vault_cli.write_secret(vim.b.neovault_mount, vim.b.neovault_secret_path, out))
      if ok then
        vim.notify("Secret updated successfully.", vim.log.levels.INFO)
        vim.bo[ev.buf].modified = false
      else
        vim.notify("Failed to update secret (see :messages).", vim.log.levels.ERROR)
      end
    end,
    desc = 'neovault: write secret to Vault',
  })
end

-- previewer : display secret content in preview window
local function make_secret_previewer(mount_point)
  return previewers.new_buffer_previewer({
    title = 'Secret Preview',
    define_preview = function(self, entry, _)
      local path = entry.value and entry.value.path or entry.value or entry
      if not path or path == '' then
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { '(no entry)' })
        return
      end

      Job:new({
        command = 'vault',
        args = { 'kv', 'get', '-format=json', string.format('%s/%s', mount_point, path) },
        on_exit = function(j, return_val)
          local lines = {}
          if return_val == 0 then
            local raw = table.concat(j:result(), '\n')
            local ok, json = pcall(vim.json.decode, raw)
            if ok and json and json.data and json.data.data then
              lines = utils.to_yaml_lines(json.data.data)
            else
              lines = { '# Error decoding secret JSON' }
            end
          else
            local err = j:stderr_result()
            lines = { '# Error fetching secret:', unpack(err) }
          end
          vim.schedule(function()
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
            vim.bo[self.state.bufnr].filetype = 'yaml'
          end)
        end,
      }):start()
    end,
  })
end

-- picker: result after 2 char
function M.search(opts)
  opts = opts or {}
  local config = neovault.get_config()
  local mount_point = opts.mount_point or config.mount_point or 'secret'
  mount_point = utils.ensure_trailing_slash(mount_point)

  if not vim.env.VAULT_ADDR or not vim.env.VAULT_TOKEN then
    vim.notify("VAULT_ADDR or VAULT_TOKEN environment variables are not set.", vim.log.levels.WARN)
    return
  end

  -- 1) load in cache all the paths
  fetch_paths_with_rvault(mount_point, function(ok, all_paths)
    if not ok then
      vim.notify("rvault list failed for mount '" .. mount_point .. "'", vim.log.levels.ERROR)
      return
    end

    -- 2) dynamic finder: not before 2 chars
    local dynamic_finder = finders.new_dynamic({
      fn = function(prompt)
        prompt = prompt or ''
        if #prompt < 2 then
          return {}
        end
        return all_paths
      end,
      entry_maker = function(line)
        return {
          value   = { mount = mount_point, path = line },
          display = line,
          ordinal = line,
        }
      end,
    })

    -- 3) previewer
    local previewer = make_secret_previewer(mount_point)

    -- 4) picker
    pickers.new(opts, {
      prompt_title = string.format("NeoVault (%s) — type at least two char", mount_point),
      finder       = dynamic_finder,
      sorter       = conf.generic_sorter(opts),
      previewer    = previewer,
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          if not entry or not entry.value then return end
          actions.close(prompt_bufnr)
          open_secret_buffer(entry.value.mount, entry.value.path)
        end)
        return true
      end,
    }):find()
  end)
end

return M
