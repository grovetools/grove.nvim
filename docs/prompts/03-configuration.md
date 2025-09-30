# Documentation Task: Configuration and Keybindings Guide

You are an expert technical writer creating documentation for the `grove-nvim` Neovim plugin.

## Task
Create a comprehensive "Configuration and Keybindings" document that includes three sections:

### 1. Installation
- Brief section pointing to the `grove install` command
- Explain how to add the plugin to Neovim configuration (lazy.nvim, packer, etc.)
- Note any prerequisites (Grove ecosystem installation)

### 2. Configuration

#### Statusline Integration
- Document the `require('grove-nvim').status()` function for statusline components
- Explain that it provides a spinner/indicator when silent chat jobs are running
- Provide complete example integrations for popular statuslines:
  - lualine configuration example
  - Other statusline examples if applicable
- Note that the status function is implemented in `lua/grove-nvim/init.lua`

#### Plugin Setup
- Clearly state that the plugin has NO `setup()` function
- Explain that it works out-of-the-box once loaded
- Configuration is minimal by design

### 3. Keybindings

Generate a comprehensive Markdown table of ALL default keybindings by parsing `plugin/grove.lua`. The table should include:
- **Keybinding** column: The actual key combination
- **Command** column: The Vim command executed
- **Description** column: What the keybinding does
- **Mode** column: Normal/Visual/Insert mode applicability

Include ALL keybindings found in the plugin, organized by category:
- Plan management keybindings
- Chat keybindings
- Target file workflow keybindings
- Any other keybindings

Note: Parse the actual `plugin/grove.lua` file to ensure all keybindings are documented accurately.

## Output Format
- Use clear headings and subheadings
- Provide complete, copy-pasteable code examples
- Use tables for keybinding documentation
- Keep explanations concise but complete