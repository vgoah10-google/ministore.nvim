# MiniStore.nvim

A high-performance, cross-platform asynchronous plugin manager for Neovim, specially designed for Windows environments.

## 🚀 自举式安装 (Bootstrap Installation)

将以下代码添加到您的 `init.lua` 顶部，实现真正的零配置安装。该脚本会自动检测 Lazy.nvim 的配置目录并注入插件配置：

```lua
-- 1. MiniStore 自举安装逻辑
local function bootstrap_ministore()
  -- 延迟执行以确保 lazy.nvim 已完全完成 setup 解析与加载
  vim.defer_fn(function()
    local ok, lazy_config = pcall(require, "lazy.core.config")
    if not ok then return end

    -- 检查插件是否已安装
    if lazy_config.plugins and lazy_config.plugins["ministore.nvim"] then return end

    -- 动态扫描 spec 中定义的 import 模块名称
    for _, mod_name in ipairs(lazy_config.spec.modules) do
      -- 将模块名转换为路径格式 (sandbox_plugins -> lua/sandbox_plugins)
      local rel_path = "lua/" .. mod_name:gsub("%.", "/")
      local paths = vim.api.nvim_get_runtime_file(rel_path, true)
      
      if #paths > 0 then
        local mod_dir = paths[1]
        local spec_path = mod_dir .. "/ministore.lua"
        
        -- 如果目标文件不存在，则在该目录下生成
        if vim.fn.filereadable(spec_path) == 0 then
          local f = io.open(spec_path, "w")
          if f then
            f:write([[return {
  "vgoah10-google/ministore.nvim",
  cmd = "MiniStore",
  keys = { { "<leader>ms", "<cmd>MiniStore<cr>", desc = "Open MiniStore" } },
}]])
            f:close()
            vim.notify("MiniStore: 已自动配置于 " .. mod_name .. "，请重启 Neovim", vim.log.levels.INFO)
          end
        end
        break -- 只在第一个有效目录生成
      end
    end
  end, 500)
end

-- 2. 使用 LazyDone 钩子，确保此时 spec 解析完成
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyDone",
  once = true,
  callback = bootstrap_ministore,
})

-- 3. 初始化 Lazy.nvim
require("lazy").setup({
  spec = { { import = "sandbox_plugins" } },
})
```

## ✨ 特性

- **零配置安装**：通过 Lazy API 自动检测 import 路径并注入配置，无需手动介入。
- **动态路径探测**：利用 Neovim 运行时 API 动态定位模块物理路径，兼容任何目录名。
- **自动管理**：生成标准的 Lua 配置后，由 Lazy.nvim 接管后续的安装与更新。
- **高性能**：延迟加载逻辑与 `LazyDone` 事件驱动，不阻塞 Neovim 的启动过程。

## 📖 使用方法

- `<leader>ms` - 打开插件商店
- `<CR>` - 选择插件进行安装
- `d` - 标记插件进行移除
- `<C-j>/<C-k>` - 在插件间导航
- `<Esc>` - 确认操作并关闭商店

## 📄 许可证

MIT