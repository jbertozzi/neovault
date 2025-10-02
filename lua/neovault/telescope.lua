-- Telescope extension for neovault.
-- Allows searching all Vault secrets via the Telescope picker.

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local vault_cli = require('neovault.vault_cli')

local M = {}

-- Recursively lists all secret paths.
local function list_all_secrets(mount_point, path)
    local secrets = {}
    local function recurse(p)
        local paths = vault_cli.list_paths(mount_point, p) or {}
        for _, sub_path in ipairs(paths) do
            if sub_path:sub(-1) == '/' then
                -- It's a directory, recurse
                recurse(p .. sub_path)
            else
                -- It's a secret
                table.insert(secrets, p .. sub_path)
            end
        end
    end
    recurse(path)
    return secrets
end

-- Telescope picker for Vault secrets.
function M.vault_secrets(opts)
    opts = opts or {}
    local mount_point = opts.mount_point or vim.g.vault_mount_point or "secret"
    
    pickers.new(opts, {
        prompt_title = "Vault Secrets",
        finder = finders.new_table({
            results = list_all_secrets(mount_point, opts.path or ""),
        }),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            local action_state = require('telescope.actions.state')
            local actions = require('telescope.actions')
            
            map('n', '<CR>', function(prompt_bufnr)
                local entry = action_state.get_selected_entry()
                if entry then
                    local secret_data = vault_cli.read_secret(mount_point, entry.value)
                    if secret_data then
                        local yaml_content = ""
                        for k, v in pairs(secret_data) do
                            yaml_content = yaml_content .. string.format("%s: %s\n", k, tostring(v))
                        end
                        vim.cmd('enew')
                        vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(yaml_content, '\n'))
                        vim.api.nvim_buf_set_option(0, 'filetype', 'yaml')
                        vim.api.nvim_buf_set_option(0, 'readonly', true)
                    end
                end
                actions.close(prompt_bufnr)
            end)
            return true
        end,
    }):find()
end

return M
