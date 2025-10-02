local M = {}

--- Exécute une commande `vault` et retourne la sortie ou nil en cas d'erreur.
---@param args string Les arguments de la commande vault, sans le binaire.
---@return table|nil
local function run_vault_command(args)
    local command = 'vault ' .. args
    local stdout = vim.fn.system(command)
    
    if vim.v.shell_error ~= 0 then
        -- En cas d'erreur, afficher le message et retourner nil.
        vim.notify('Erreur lors de l\'exécution de la commande vault : ' .. stdout, vim.log.levels.ERROR)
        return nil
    end

    local success, result = pcall(vim.json.decode, stdout)
    if not success then
        -- La sortie n'est pas un JSON valide, cela peut arriver pour des messages d'erreurs ou des sorties non-JSON.
        return stdout
    end

    return result
end

--- Liste les chemins sous un point de montage et un chemin donnés.
---@param mount_point string Le point de montage (ex: 'secret').
---@param path string Le chemin à explorer.
---@return table|nil Une table de chemins, ou nil si une erreur se produit.
function M.list_paths(mount_point, path)
    local args = string.format("list -format=json %s/%s", mount_point, path)
    local result = run_vault_command(args)
    
    if type(result) == 'table' then
        return result.data.keys
    end
    return nil
end

--- Lit un secret à un chemin donné.
---@param mount_point string Le point de montage.
---@param path string Le chemin du secret.
---@return table|nil Une table contenant les données du secret, ou nil en cas d'erreur.
function M.read_secret(mount_point, path)
    local args = string.format("read -format=json %s/%s", mount_point, path)
    local result = run_vault_command(args)

    if type(result) == 'table' then
        return result.data.data
    end
    return nil
end

return M
