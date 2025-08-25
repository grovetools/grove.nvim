# grove-nvim

Neovim plugin for grove

## Installation

```bash
grove install neogrove
```

## Usage

### Commands

- `:GroveChatRun [args...]` - Run Grove chat on the current markdown file
  - By default, opens in a vertical split terminal
  - Arguments can be combined, e.g., `:GroveChatRun silent`
  - Possible arguments:
    - `silent`: Run chat in background with statusline spinner
    - `vertical`: Open in a vertical split (default)
    - `horizontal`: Open in a horizontal split
    - `fullscreen`: Open in a new tab
- `:GroveSetTarget` - Set current file as target for text interactions
- `:GroveShowTarget` - Show the current target file
- `:GroveText` - (Visual mode) Capture selection and ask a question
- `:GroveTextRun` - (Visual mode) Capture, ask, and run chat immediately

### Keybindings

- `<leader>fc` - Run Grove chat
- `<leader>fq` - (Visual mode) Ask question about selection
- `<leader>fr` - (Visual mode) Ask question and run chat

### Statusline Integration

To show a spinner when Grove chat is running in the background:

#### For lualine.nvim

```lua
require('lualine').setup {
  sections = {
    lualine_x = {
      -- Your other components...
      {
        require('grove-nvim').status,
        color = { fg = '#7aa2f7' },
      },
    },
  },
}
```

#### For native vim statusline

```vim
" In your init.vim
set statusline+=%{luaeval('require("grove-nvim").status()')}
```

The status function returns an animated spinner when chat is running, empty string otherwise.

## Development

### Building

```bash
make build
```

### Testing

```bash
make test
make test-e2e
```

### Linting

```bash
make lint
```

## Contributing

This is a private repository. Please ensure all contributions follow the Grove ecosystem conventions.