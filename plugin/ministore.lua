-- plugin/ministore.lua
-- 插件入口点：在加载时触发自举逻辑

local status, bootstrap = pcall(require, "ministore.bootstrap")

if not status then
  -- 如果模块未找到，可能是加载时机问题，忽略或提示
  return
end

-- 如果自举失败（插件未安装等），则不加载后续 UI
if not bootstrap.setup() then
  return
end

-- 自举成功，定义命令与快捷键
vim.api.nvim_create_user_command("MiniStore", function()
  require("ministore.ui").open()
end, {})

vim.keymap.set('n', '<leader>ms', '<cmd>MiniStore<CR>', { desc = 'Open MiniStore' })
