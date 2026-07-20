# MiniStore.nvim

A high-performance, cross-platform asynchronous plugin manager for Neovim, specially designed for Windows environments.

## 🚀 自举式安装 (Bootstrap Installation)

将以下代码添加到您的 `init.lua` 顶部，实现真正的零配置安装。该脚本会自动检测 Lazy.nvim 环境，并在后台静默完成安装，无需重启 Neovim 即可使用：

```lua
-- 1. MiniStore 自举安装逻辑
local function bootstrap_ministore()
  vim.defer_fn(function()
    local ok, lazy = pcall(require, "lazy")
    if not ok then return end
    
    local config = require("lazy.core.config")
    -- 检查插件是否已安装
    if config.plugins and config.plugins["ministore.nvim"] then return end

    -- 后台静默安装
    lazy.install({
      { "vgoah10-google/ministore.nvim", show = false }
    })
    
    -- 动态生成配置，确保持久化
    for _, mod_name in ipairs(config.spec.modules) do
      local rel_path = "lua/" .. mod_name:gsub("%.", "/")
      local paths = vim.api.nvim_get_runtime_file(rel_path, true)
      if #paths > 0 then
        local spec_path = paths[1] .. "/ministore.lua"
        if vim.fn.filereadable(spec_path) == 0 then
          local f = io.open(spec_path, "w")
          if f then
            f:write([[return {
  "vgoah10-google/ministore.nvim",
  cmd = "MiniStore",
  keys = { { "<leader>ms", "<cmd>MiniStore<cr>", desc = "Open MiniStore" } },
}]])
            f:close()
            vim.notify("MiniStore: 自动安装完成，配置已生成", vim.log.levels.INFO)
          end
        end
        break
      end
    end
  end, 500)
end

-- 2. 使用 LazyDone 钩子确保环境就绪
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

- **零配置安装**：通过 Lazy API 自动检测 import 路径并注入配置。
- **即装即用**：利用 `{ show = false }` 实现静默安装，无需重启 Neovim。
- **动态路径探测**：利用 Neovim 运行时 API 动态定位模块物理路径，兼容任何目录名。
- **高性能**：延迟加载逻辑与 `LazyDone` 事件驱动，不阻塞启动过程。

## 📖 使用方法

- `<leader>ms` - 打开插件商店
- `<CR>` - 选择插件进行安装
- `d` - 标记插件进行移除
- `<C-j>/<C-k>` - 在插件间导航
- `<Esc>` - 确认操作并关闭商店

## 📄 许可证

MIT