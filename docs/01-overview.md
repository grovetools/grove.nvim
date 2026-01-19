Grove-nvim is a Neovim plugin that provides commands and workflows to interact with Grove tools, such as `grove-flow`. The plugin connects Neovim's text editing capabilities with Grove's plan management and code generation features.

<!-- placeholder for animated gif -->

## Key Features

-   **In-Editor AI Chat**: Run interactive AI chat sessions directly on the current buffer using the `:GroveChatRun` command.

-   **Plan Management**: Interact with `grove-flow` plans through a UI integrated into Neovim.
    -   `:GrovePlan`: Opens an interactive picker to browse, preview, and manage existing plans.
    -   `:GrovePlanInit`: Initializes a new plan directory with guided prompts for configuration.
    -   `:GrovePlanExtract`: Creates a new plan by extracting content from the current markdown buffer, using its frontmatter or filename to suggest a plan name.

-   **"Code-to-Chat" Workflow**: A process for using code snippets in AI conversations.
    -   `:GroveSetTarget`: Designates a markdown file as the "target" for the current session.
    -   `:'<,'>GroveTextRun`: Appends a visually selected block of code and a user prompt to the target file, then runs a silent chat session on that file.

-   **Job Management**: Add jobs to plans using either a form-based UI (`:GroveAddJob`) for guided creation or a floating terminal TUI (`:GroveAddJobTUI`) for a more direct `flow` experience.

## How It Works

The plugin consists of two main components: a Lua plugin for Neovim and a Go command-line application named `neogrove`.

1.  **Lua Plugin (`lua/` files)**: This component runs inside Neovim. It defines user commands (e.g., `:GrovePlan`, `:GroveChatRun`) and keybindings. It is responsible for creating the user interface elements, such as input prompts and pickers, and managing editor state.

2.  **Go Binary (`neogrove`)**: When a user invokes a command, the Lua code executes the `neogrove` binary with appropriate arguments. This Go application serves as an interface and wrapper.

3.  **Flow Execution**: The `neogrove` binary constructs and executes commands for the `flow` tool from the `grove-flow` project. It pipes standard input, output, and error streams between the `flow` process and the Neovim terminal or background job.

### Installation

Install grove-nvim using the Grove meta-tool:
```bash
grove install grove-nvim
```

Then add to your Neovim configuration. For example, with lazy.nvim:
```lua
{ "mattsolo1/grove-nvim" }
```

Grove-nvim requires the Grove ecosystem. See the [Grove Installation Guide](https://github.com/mattsolo1/grove-meta/blob/main/docs/02-installation.md) for setup instructions.
