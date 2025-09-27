# Documentation Task: Configuration Guide

You are an expert technical writer creating documentation for the `grove-nvim` Neovim plugin.

## Task
Based on the provided codebase, document the available configuration options for `grove-nvim`.

1.  **Statusline Integration**:
    - Explain the `require('grove-nvim').status()` function, which is designed for statusline components.
    - Provide a concrete example of how to integrate this into a statusline configuration (e.g., for `lualine`). The function provides a spinner when a silent chat is running. This is implemented in `lua/grove-nvim/init.lua`.

2.  **No `setup()` function**:
    - Note that the plugin does not currently have a centralized `setup()` function and works out-of-the-box once the commands and keybindings are loaded.

## Output Format
- Provide clear code examples for the statusline integration.
- Keep the guide concise, as the configuration surface is currently small.