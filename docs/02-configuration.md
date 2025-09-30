# Configuration and Keybindings

This document provides instructions for installing, configuring, and using the keybindings for `grove-nvim`.

## 1. Installation

`grove-nvim` requires the Grove ecosystem to be installed and available in your `PATH`.

1.  **Install the plugin binary** using the Grove meta-tool:
    ```bash
    grove install grove-nvim
    ```

2.  **Add the plugin to your Neovim configuration.**

    For `lazy.nvim`:
    ```lua
    { "mattsolo1/grove-nvim" }
    ```
    ``

The plugin will be loaded automatically on startup.

## 2. Configuration

### Plugin Setup

The `grove-nvim` plugin is designed to work out-of-the-box with minimal setup. It does not have or require a `setup()` function. Once installed and loaded by your plugin manager, all commands and keybindings are immediately available.

### Statusline Integration

The plugin provides a status function to indicate when a background chat job is active. This is primarily used for the `:GroveChatRun silent` command, which displays a spinner in the statusline instead of opening a terminal.

The function `require('grove-nvim').status()` returns a string containing a spinner animation and the text "Grove" when a job is running, and an empty string otherwise. It is implemented in `lua/grove-nvim/init.lua`.

#### Lualine Example

To integrate with `lualine.nvim`, add the component to your `lualine_x` or `lualine_y` sections.

```lua
-- ~/.config/nvim/lua/plugins/lualine.lua

require('lualine').setup {
  options = {
    -- ... your other options
  },
  sections = {
    -- ... other sections
    lualine_x = {
      -- Other components...
      {
        require('grove-nvim').status,
        cond = function()
          -- Only show the component when it's active
          return require('grove-nvim').status() ~= ''
        end,
      },
      'filetype',
    },
    -- ... other sections
  },
}
```

This configuration ensures the Grove component only appears in the statusline when a background chat job is active.

## 3. Keybindings

The following tables document all default keybindings provided by `grove-nvim`, sourced from `plugin/grove.lua`.

### Plan Management

| Keybinding       | Command                  | Description                        | Mode   |
| ---------------- | ------------------------ | ---------------------------------- | ------ |
| `<leader>fp`     | `:GrovePlan`             | Open the Grove Plan picker         | Normal |
| `<leader>fpx`    | `:GrovePlanExtract`      | Extract a new plan from the buffer | Normal |
| `<leader>jn`     | `:GroveAddJob`           | Add job to active plan (Form UI)   | Normal |
| `<leader>ji`     | `:GroveAddJobTUI`        | Add job to active plan (TUI)       | Normal |

### Chat

| Keybinding       | Command                  | Description                        | Mode   |
| ---------------- | ------------------------ | ---------------------------------- | ------ |
| `<leader>fc`     | `:GroveChatRun`          | Run an interactive chat session    | Normal |

### Target File Workflow

These keybindings operate on visually selected text and require a target file to be set with `:GroveSetTarget`.

| Keybinding       | Command                  | Description                               | Mode   |
| ---------------- | ------------------------ | ----------------------------------------- | ------ |
| `<leader>fq`     | `:'<,'>GroveText`        | Append selection and ask a question       | Visual |
| `<leader>fr`     | `:'<,'>GroveTextRun`     | Append selection, ask, and run chat       | Visual |
