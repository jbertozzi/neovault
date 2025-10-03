-- Lua module to interface with the `vault` CLI client.

local M = {}

--- Runs a `vault` command and returns the JSON output.
--- @param args string The arguments for the vault command.
--- @return table|nil Returns a Lua table representing the JSON output, or nil on error.
local function run_vault_command(args)
    local command = 'vault ' .. args
    print("executing raw command: ", command)
    local stdout = vim.fn.system(command)
    print("raw output: ", stdout)
    if vim.v.shell_error ~= 0 then
        vim.notify('Vault CLI error: ' .. stdout, vim.log.levels.ERROR)
        return nil
    end

    local success, result = pcall(vim.json.decode, stdout)
    if not success then
        -- This may happen for non-JSON output or errors.
        return nil
    end

    return result
end

--- Lists paths under a given mount point and path.
--- @param mount_point string The mount point (e.g., 'secret').
--- @param path string The path to explore.
--- @return table|nil A table of paths, or nil on error.
function M.list_paths(mount_point, path)
    local args = string.format("kv list -format=json %s/%s", mount_point, path)
    local result = run_vault_command(args)
    if type(result) == 'table' and result[1] ~=  nil then
        return result
    end
    return nil
end

--- Reads a secret at a given path.
--- @param mount_point string The mount point.
--- @param path string The path to the secret.
--- @return table|nil A table containing the secret data, or nil on error.
function M.read_secret(mount_point, path)
    local args = string.format("kv get -format=json %s/%s", mount_point, path)
    local result = run_vault_command(args)

    if type(result) == 'table' and result.data and result.data.data then
        return result.data.data
    end
    return nil
end

return M
