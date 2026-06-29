-- MiniStore.nvim - Asynchronous plugin manager and app store for Neovim
-- Author: Your Name
-- License: MIT

if vim.g.loaded_ministore then
  return
end

vim.g.loaded_ministore = true

-- Define the command to open the store
vim.api.nvim_create_user_command("MiniStore", function()
  require("ministore.ui").open()
end, {})

-- Set up default keymap
vim.keymap.set('n', '<leader>ms', '<cmd>MiniStore<CR>', { desc = 'Open MiniStore' })