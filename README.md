# MiniStore.nvim

A high-performance, cross-platform asynchronous plugin manager for Neovim, specially designed for Windows environments.

## 🚀 Installation (Lazy.nvim)

Add this to your `init.lua` inside your Lazy.nvim configuration:

```lua
{
  "vgoah10-google/ministore.nvim",
  cmd = "MiniStore",
  keys = {
    { "<leader>ms", "<cmd>MiniStore<cr>", desc = "Open MiniStore" },
  },
}
```

## 🛠️ 自举式安装检查 (添加到 init.lua 顶部)

为了确保插件环境完整并自动初始化配置，请在 `init.lua` 最上方加入此段代码：

```lua
-- MiniStore 自举检测
local function bootstrap_ministore()
  local lazy_root = vim.fn.stdpath("data") .. "/lazy"
  local ministore_path = lazy_root .. "/ministore.nvim"
  
  if vim.fn.isdirectory(ministore_path) == 1 then
    -- 如果插件已安装，加载 bootstrap 模块
    require("ministore.bootstrap").setup()
  else
    -- 如果插件未安装，仅弹出一次告警
    vim.schedule(function()
      vim.notify("MiniStore 插件未在 lazy 目录中找到，请确保已安装！", vim.log.levels.WARN)
    end)
  end
end

bootstrap_ministore()
```

## ✨ Features

- **Auto-Config Generation**: Automatically generates a user-specific configuration file in the plugin directory upon first use.
- **Lazy Loading**: Fully respects Lazy.nvim loading triggers.
- **Async & Fast**: Non-blocking architecture optimized for Windows.

## ⚙️ Configuration

On the first time the plugin is successfully initialized, it will automatically generate a default configuration file at:
`[lazy_root]/ministore.nvim/lua/ministore_user_config.lua`.

You can edit this file to customize your `api_url` and `timeout` settings.

## 📖 Usage

- `<leader>ms` - Open the plugin store
- `<CR>` - Select a plugin for installation
- `d` - Mark a plugin for removal
- `<C-j>/<C-k>` - Navigate through plugins
- `<Esc>` - Confirm actions and close the store
