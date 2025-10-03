# neovault

Browse and edit password stored in Hashicorp vault.

Requires [vault](https://github.com/hashicorp/vault) and [rvault](https://github.com/kir4h/rvault) binaries.

## installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```
{
  'jbertozzi/neovault',
  dependencies = { 
    'nvim-telescope/telescope.nvim'
    'nvim-lua/plenary.nvim'
  },
}
```

## configuration

```
require('neovault').setup({
  mount_point = "apps"
})
```

## mapping

```
vim.keymap.set('n', '<leader>v', ':NeoVaultSearch secret<CR>', { noremap = true, silent = true, desc = 'Search Vault secrets', })
```
