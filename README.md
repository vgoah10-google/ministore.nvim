# MiniStore.nvim

A high-performance, cross-platform asynchronous plugin manager and online app store for Neovim, specially designed for Windows environments.

## 🌟 Features

- **Asynchronous Architecture**: Fully non-blocking UI thread with background retry mechanisms
- **Windows Optimized**: Uses `vim.system` with Windows built-in `curl` to bypass firewall issues
- **NeovimCraft Integration**: Accurate metadata retrieval using dictionary traversal
- **Hot Installation**: No restart required with `packadd` based hot-swapping
- **Intuitive UI**: Floating windows with real-time fuzzy search

## 🚀 Installation

### Using Lazy.nvim (Recommended)

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