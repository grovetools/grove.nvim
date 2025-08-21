# Statusline Integration

To show a spinner in your statusline when Grove chat is running in the background, you can add the Grove status to your statusline configuration.

## Example for lualine.nvim

```lua
require('lualine').setup {
  sections = {
    lualine_x = {
      -- Your other components...
      {
        function()
          return require('grove-nvim').status()
        end,
        color = { fg = '#7aa2f7' },
      },
    },
  },
}
```

## Example for native statusline

```vim
" In your init.vim or vimrc
set statusline+=%{luaeval('require("grove-nvim").status()')}
```

The status function returns:
- An animated spinner with "Grove" text when chat is running
- An empty string when nothing is running