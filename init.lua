local vault_client = require('mon_plugin.vault_client')
local M = {}

function M.list_vault_paths(mount_point, path)
  if not vault_client.base_url or not vault_client.token then
    print("Erreur : Les variables d'environnement VAULT_ADDR ou VAULT_TOKEN ne sont pas définies.")
    return {}
  end
  return vault_client.get_path(mount_point, path) or {}
end

function M.show_vault_secret(mount_point, path)
  if not vault_client.base_url or not vault_client.token then
    print("Erreur : Les variables d'environnement VAULT_ADDR ou VAULT_TOKEN ne sont pas définies.")
    return
  end
  
  local secret_data = vault_client.get_secret(mount_point, path)
  if not secret_data then
    return
  end
  
  -- Afficher le contenu en YAML
  local yaml_content = ""
  for k, v in pairs(secret_data) do
    if type(v) == 'table' then
      -- Gérer les tables imbriquées
      -- Pour simplifier, nous allons juste afficher la table telle quelle
      yaml_content = yaml_content .. string.format("%s: %s\n", k, vim.inspect(v))
    else
      yaml_content = yaml_content .. string.format("%s: %s\n", k, tostring(v))
    end
  end

  -- Réinitialiser le buffer
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(yaml_content, '\n'))
  vim.api.nvim_buf_set_option(0, 'filetype', 'yaml')
  vim.api.nvim_buf_set_option(0, 'readonly', true)
end

-- Fonction pour suivre un chemin
function M.follow_path(mount_point, current_path)
  local selected_line = vim.api.nvim_get_current_line()
  local new_path = current_path .. selected_line
  
  local paths = M.list_vault_paths(mount_point, new_path)
  
  if next(paths) == nil then
    -- C'est un secret, on l'affiche
    M.show_vault_secret(mount_point, new_path)
  else
    -- C'est un dossier, on affiche les nouveaux chemins
    vim.api.nvim_buf_set_lines(0, 0, -1, false, paths)
  end
end

return M
