-- plugin/ministore.lua
-- 插件入口点：在加载时触发配置生成逻辑

-- 延迟执行配置生成，确保 lazy 已完全加载
vim.defer_fn(function()
  local status, bootstrap = pcall(require, "ministore.bootstrap")
  if status and bootstrap then
    bootstrap.setup()
  end
end, 100)

-- 显式定义命令，避免 lazy 加载顺序问题
local function define_commands()
  vim.api.nvim_create_user_command("MiniStore", function()
    require("ministore.ui").open()
  end, { desc = "打开 MiniStore 插件管理 UI" })

  vim.api.nvim_create_user_command("MiniStoreTest", function()
    local ok, mod = pcall(require, "ministore.tests.test_filter")
    if not ok then
      vim.notify("MiniStoreTest: 无法加载测试模块: " .. tostring(mod), vim.log.levels.ERROR)
      return
    end
    if type(mod.run_all_tests) ~= "function" then
      vim.notify("MiniStoreTest: 测试模块损坏，找不到 run_all_tests 函数", vim.log.levels.ERROR)
      return
    end
    mod.run_all_tests()
  end, { desc = "运行 MiniStore 过滤函数测试套件" })
end

define_commands()

-- 在 VimEnter 后再注册一次（用于 lazy.nvim 延迟加载场景）
vim.api.nvim_create_autocmd("VimEnter", {
  pattern = "*",
  callback = function()
    define_commands()
  end,
})

vim.keymap.set('n', '<leader>ms', '<cmd>MiniStore<CR>', { desc = 'Open MiniStore' })