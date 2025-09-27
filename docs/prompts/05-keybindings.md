# Documentation Task: Keybindings Reference

You are an expert technical writer creating documentation for the `grove-nvim` Neovim plugin.

## Task
Create a clear and concise reference guide for the default keybindings set by the plugin.

- Extract all keymappings from `plugin/grove.lua`.
- Present them in a table format.

The table should have three columns:
- **Keybinding**: The key sequence (e.g., `<leader>fp`).
- **Mode**: The Neovim mode (e.g., Normal, Visual).
- **Description**: What the keybinding does (e.g., "Open Grove Plan picker").

## Keybindings to Document:
- `<leader>fp`
- `<leader>fpx`
- `<leader>fc`
- `<leader>jn`
- `<leader>ji`
- `<leader>fq` (Visual mode)
- `<leader>fr` (Visual mode)

## Output Format
- A single Markdown table.
- Ensure descriptions are clear and match the functionality of the associated commands.