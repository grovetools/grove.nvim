# Configuration and Keybindings

This document provides instructions for installing, configuring, and using the keybindings for `grove-nvim`.

## 1. Installation

The `grove-nvim` plugin requires the Grove ecosystem to be installed and available in your `PATH`.

1.  **Install the plugin binary** using the Grove meta-tool:
    ```bash
    grove install grove-nvim
    ```

2.  **Add the plugin to your Neovim configuration.**

    For `lazy.nvim`:
    ```lua
    { "mattsolo1/grove-nvim" }
    ```

The plugin will be loaded automatically on startup.

## 2. Configuration

### Plugin Setup

The `grove-nvim` plugin is designed to work after installation with no extra setup. It does not have or require a `setup()` function. Once loaded by your plugin manager, all commands and keybindings are available.

### Statusline Integration

The plugin provides a status function to indicate when a background chat job is active. This is used for the `:GroveChatRun silent` command, which runs a job in the background and displays a spinner in the statusline instead of opening a terminal.

The function `require('grove-nvim').status()` returns a string containing a spinner animation and the text "Grove" when a job is running, and an empty string otherwise. It is implemented in `lua/grove-nvim/init.lua`.

#### Lualine Example

To integrate with `lualine.nvim`, add the component to your configuration.

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

The following tables document the default keybindings provided by `grove-nvim`, sourced from `plugin/grove.lua`.

### Plan Management

| Keybinding       | Command                      | Description                               | Mode   |
| ---------------- | ---------------------------- | ----------------------------------------- | ------ |
| `<leader>fp`     | `:GrovePlan`                 | Open the Grove Plan picker                | Normal |
| `<leader>fpx`    | `:GrovePlanExtract`          | Extract a new plan from the buffer        | Normal |
| `<leader>fpt`    | `:GrovePlanTUI`              | Open flow plan TUI (all plans)            | Normal |
| `<leader>fps`    | `:GrovePlanStatusTUI`        | Open flow plan status TUI (active plan)   | Normal |
| `<leader>fpl`    | `:GroveWorkspacePlansList`   | Show all workspace plans in table         | Normal |
| `<leader>jn`     | `:GroveAddJob`               | Add job to active plan (Form UI)          | Normal |
| `<leader>ji`     | `:GroveAddJobTUI`            | Add job to active plan (TUI)              | Normal |

### Chat & Flow

| Keybinding       | Command                  | Description                        | Mode   |
| ---------------- | ------------------------ | ---------------------------------- | ------ |
| `<leader>fc`     | `:GroveChatRun`          | Run an interactive chat session    | Normal |

### Context & Configuration

| Keybinding       | Command                      | Description                        | Mode   |
| ---------------- | ---------------------------- | ---------------------------------- | ------ |
| `<leader>fe`     | `:GroveEditContext`          | Edit context rules                 | Normal |
| `<leader>fv`     | `:GroveContextView`          | Open cx view TUI                   | Normal |
| `<leader>fC`     | `:GroveConfigAnalyzeTUI`     | Open config analyze TUI            | Normal |

### Sessions & Navigation

| Keybinding       | Command                  | Description                        | Mode   |
| ---------------- | ------------------------ | ---------------------------------- | ------ |
| `<leader>fs`     | `:GroveSessionize`       | Open gmux sessionize TUI           | Normal |
| `<leader>fk`     | `:GroveGmuxKeymap`       | Open gmux keymap manager TUI       | Normal |
| `<leader>fh`     | `:GroveHooksSessions`    | Browse grove-hooks sessions        | Normal |

### Workspace & Monitoring

| Keybinding       | Command                  | Description                        | Mode   |
| ---------------- | ------------------------ | ---------------------------------- | ------ |
| `<leader>fw`     | `:GroveWorkspaceStatus`  | Show workspace status table        | Normal |
| `<leader>fl`     | `:GroveLogsTUI`          | Open grove logs TUI                | Normal |
| `<leader>fn`     | `:GroveNBManage`         | Open notebook manager TUI          | Normal |

### Release Management

| Keybinding       | Command                  | Description                        | Mode   |
| ---------------- | ------------------------ | ---------------------------------- | ------ |
| `<leader>frl`    | `:GroveReleaseTUI`       | Open grove release TUI             | Normal |

### Target File Workflow

These keybindings operate on visually selected text and require a target file to be set with `:GroveSetTarget`.

| Keybinding       | Command                  | Description                               | Mode   |
| ---------------- | ------------------------ | ----------------------------------------- | ------ |
| `<leader>fq`     | `:'<,'>GroveText`        | Append selection and ask a question       | Visual |
| `<leader>fr`     | `:'<,'>GroveTextRun`     | Append selection, ask, and run chat       | Visual |