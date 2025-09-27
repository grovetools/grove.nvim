This guide explains how to install the `grove-nvim` plugin and its dependencies.

## Prerequisites

Before installing `grove-nvim`, ensure the following components are installed and configured correctly.

### 1. `neogrove` Binary

`grove-nvim` requires its companion binary, `neogrove`, to function. This binary is managed by the `grove` meta-tool. You can install it by running:

```bash
grove install grove-nvim
```

This command installs the `neogrove` binary into the Grove ecosystem, making it available to the Neovim plugin.

### 2. `grove-flow` Binary

The `neogrove` binary is a specialized wrapper that calls the `grove-flow` tool for most of its operations. Therefore, the `flow` binary must be installed and available in your system's `PATH`.

You can install it using the `grove` meta-tool:

```bash
grove install grove-flow
```

### 3. `snacks.nvim` UI Plugin

The plugin uses `snacks.nvim` to create user interfaces for features like the Plan picker and job creation forms. This Neovim plugin must be installed alongside `grove-nvim`.

## Installation

You can install `grove-nvim` using your preferred Neovim plugin manager. The following is an example using `lazy.nvim`.

Add the following plugin specification to your `lazy.nvim` configuration. Make sure to include the `snacks.nvim` dependency.

```lua
{
  "mattsolo1/grove-nvim",
  dependencies = { "mrjones2014/snacks.nvim" },
  config = function()
    -- The plugin sets up commands and default keybindings automatically.
    -- No additional setup is required.
  end,
}
```