# Configuration

The `grove-nvim` plugin is designed to work with minimal configuration, acting as a direct interface to the underlying `grove-flow` tool.

## General Configuration

This plugin does not have a centralized `setup()` function. It works out-of-the-box once the commands and keybindings are loaded by Neovim. Most configuration, such as defining AI models or setting plan defaults, is handled by the `flow` CLI itself.

## Statusline Integration

The plugin provides a function to display the status of background AI chat jobs, which is useful for integration with statusline plugins like `lualine`.

### `require('grove-nvim').status()`

This function returns a status indicator for active jobs initiated by the `:GroveChatRun silent` command.

-   When a silent chat is running, it returns an animated spinner icon and the text "Grove".
-   When no job is active, it returns an empty string, so it will not appear in your statusline.

#### Example: `lualine` Integration

You can add the status component to your `lualine` configuration. The following example adds it to the `lualine_x` section.

```lua
-- Example configuration for lualine.nvim
require('lualine').setup {
  options = {
    -- ... your other options
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {{'filename', path = 1}},
    lualine_x = {
      -- Add the grove-nvim status component here
      'require("grove-nvim").status',
      'encoding',
      'fileformat',
      'filetype'
    },
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  -- ... other configuration
}
```

When you run `:GroveChatRun silent`, a spinner will appear in your statusline, indicating that the AI is processing your request in the background.