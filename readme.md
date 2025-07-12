# FloatingClipboard - Neovim Clipboard History Plugin

A lightweight Neovim plugin to track and browse yank history using a floating window. Built with Lua, designed for multi-tab, multi-pane workflows — even across tmux splits.

## Features

- Automatically records every yank (`TextYankPost`) to a history file
- Opens a clean, read-only floating window (`:Cl`) to browse history
- Press `<CR>` to paste clipboard content back into your buffer
- Supports max history size (`hist_size`)
- Robust across tabs, splits, and tmux panes (file-based, non-blocking)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "hamzahshahbazkhan/floatingClipboard.nvim",
  config = function()
    require("floatingClipboard").setup({
      target_file = "~/.cache/nvim-clipboard.txt",
      -- hist_size = 2000,
    })
  end,
}
```

## Usage

- `:Cl` - opens the floatingClipboard
- `q` - quits the floatingClipboard
- vim keybindings to navigate
- `p` or `<CR>` to paste the block
- not editable in normal mode
- can edit clipboard in visual mode
