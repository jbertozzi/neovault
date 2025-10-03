-- lua/neovault/vault_cli.lua

local M = {}

-- Exécute "vault ..." et tente de décoder du JSON (kv list/get).
local function run_vault_command(args)
  local command = 'vault ' .. args
  local stdout = vim.fn.system(command)
  if vim.v.shell_error ~= 0 then
    vim.notify('Vault CLI error: ' .. command .. ': ' .. stdout, vim.log.levels.ERROR)
    return nil
  end
  local ok, result = pcall(vim.json.decode, stdout)
  if not ok then return nil end
  return result
end

-- Exécute sans passer par le shell (liste argv) — utile pour kv put (pas besoin de JSON).
local function run_vault_argv(argv)
  local stdout = vim.fn.system(argv)  -- argv = {'vault','kv','put',...}
  local ok = (vim.v.shell_error == 0)
  return ok, stdout
end

function M.list_paths(mount_point, path)
  local args = string.format("kv list -format=json %s/%s", mount_point, path)
  local result = run_vault_command(args)
  if type(result) == 'table' and result[1] ~= nil then
    return result
  end
  return nil
end

function M.read_secret(mount_point, path)
  local args = string.format("kv get -format=json %s/%s", mount_point, path)
  local result = run_vault_command(args)
  if type(result) == 'table' and result.data and result.data.data then
    return result.data.data
  end
  return nil
end

--- Écrit un secret (kv put) au chemin donné avec les paires k/v (table Lua).
--- Retourne (ok:boolean, stdout:string)
function M.write_secret(mount_point, path, data_tbl)
  local target = string.format("%s/%s", mount_point, path)
  local argv = { 'vault', 'kv', 'put', target }

  -- Important : on passe par argv pour éviter les problèmes de quoting.
  for k, v in pairs(data_tbl or {}) do
    table.insert(argv, string.format("%s=%s", tostring(k), tostring(v)))
  end

  local ok, out = run_vault_argv(argv)
  if not ok then
    vim.notify('Vault CLI put failed: ' .. table.concat(argv, ' ' ) .. '\n' .. out, vim.log.levels.ERROR)
  end
  return ok, out
end

return M

