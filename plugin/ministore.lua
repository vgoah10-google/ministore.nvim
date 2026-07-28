-- plugin/ministore.lua
-- 插件入口点：在加载时触发配置生成逻辑

-- 延迟执行配置生成，确保 lazy 已完全加载
vim.defer_fn(function()
  local status, bootstrap = pcall(require, "ministore.bootstrap")
  if status and bootstrap then
    bootstrap.setup()
  end
end, 100)

vim.api.nvim_create_user_command("MiniStore", function()
  require("ministore.ui").open()
end, {})

vim.api.nvim_create_user_command("MiniStoreTest", function()
  require("ministore.tests.test_filter").run_all_tests()
end, { desc = "运行 MiniStore 过滤函数测试套件" })

vim.keymap.set('n', '<leader>ms', '<cmd>MiniStore<CR>', { desc = 'Open MiniStore' })