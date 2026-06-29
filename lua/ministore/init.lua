-- MiniStore.nvim 快捷键映射

-- 打开插件商店
vim.keymap.set('n', '<leader>ms', require('ministore.ui').open, { desc = 'Open MiniStore' })
-- 测试命令
vim.keymap.set('n', '<leader>mt', function() require('ministore.test').run_test() end, { desc = 'Run MiniStore Test' })