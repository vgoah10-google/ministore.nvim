# MiniStore.nvim

A high-performance, cross-platform asynchronous plugin manager and online app store for Neovim, specially designed for Windows environments.

## 🌟 Features

- **Asynchronous Architecture**: Fully non-blocking UI thread with background retry mechanisms
- **Windows Optimized**: Uses `vim.system` with Windows built-in `curl` to bypass firewall issues
- **NeovimCraft Integration**: Accurate metadata retrieval using dictionary traversal
- **Hot Installation**: No restart required with `packadd` based hot-swapping
- **Intuitive UI**: Floating windows with real-time fuzzy search

## 🚀 Installation

### Bootstrap Installation (Recommended)

Add this code to your `init.lua` to automatically install Lazy.nvim (if not already installed) and configure MiniStore.nvim:

```lua
-- MiniStore.nvim 自举安装脚本
local function bootstrap_ministore()
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  
  -- 检查 lazy.nvim 是否已安装
  if not vim.loop.fs_stat(lazypath) then
    -- 自动安装 lazy.nvim
    vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable",
      lazypath
    })
  end
  
  -- 将 lazy.nvim 添加到 runtimepath
  vim.opt.rtp:prepend(lazypath)
  
  -- 配置并启动 lazy.nvim，包含 ministore 插件
  require("lazy").setup({
    {
      "your-username/ministore.nvim",  -- 替换为您的实际 GitHub 用户名
      lazy = true,
      cmd = "MiniStore",
      keys = {
        { "<leader>ms", "<cmd>MiniStore<cr>", desc = "Open MiniStore" },
      },
    },
    -- 在此处添加其他插件配置
  }, {
    -- Lazy.nvim 配置选项
    install = {
      missing = true,  -- 自动安装缺失的插件
    },
    checker = {
      enabled = true,  -- 自动检查插件更新
      notify = false,  -- 不显示通知
    },
  })
end

-- 执行自举安装
bootstrap_ministore()
```

Replace `your-username` with your actual GitHub username where you host the ministore.nvim repository.

### Using Lazy.nvim (Manual Setup)

```lua
{
  "your-username/ministore.nvim",
  lazy = true,
  cmd = "MiniStore",
  keys = {
    { "<leader>ms", "<cmd>MiniStore<cr>", desc = "Open MiniStore" },
  },
}
```

### Manual Installation

1. Clone this repository:
```bash
git clone https://github.com/your-username/ministore.nvim.git ~/.local/share/nvim/site/pack/ministore/start/ministore.nvim
```

2. Add to your `init.lua`:
```lua
vim.keymap.set('n', '<leader>ms', require('ministore.ui').open, { desc = 'Open MiniStore' })
```

## 📖 Usage

- `<leader>ms` - Open the plugin store
- `<CR>` - Select a plugin for installation
- `d` - Mark a plugin for removal
- `<C-j>/<C-k>` - Navigate through plugins
- `<Esc>` - Confirm actions and close the store

## ⚙️ Configuration

MiniStore.nvim works out of the box with default settings. It automatically detects your Lazy plugin directory.

## 🧪 Testing

Run the integrated test suite:
```vim
:lua require('ministore.test').run_test()
```

## 📄 License

MIT