`grove.nvim` is a Neovim plugin that integrates the Grove CLI ecosystem into the editor. It provides a Lua interface for orchestrating AI workflows, managing context, and navigating workspaces by wrapping the underlying `grove` binaries.

## Core Mechanisms

**Hybrid Architecture**: The plugin consists of a Lua frontend and a Go binary. The Lua layer handles UI elements (floating windows, virtual text, inputs), while the Go binary acts as a bridge, constructing and executing commands for `flow`, `cx`, and `tend`.

**Terminal Wrapping**: Interactive CLI tools (like `flow plan tui`, `cx view`, `nb tui`) are executed inside Neovim floating windows or splits. This allows usage of the full TUI capabilities without leaving the editor context.

**Tool Status**: The plugin polls metadata from `flow plan status --json` and `cx stats` to render real-time feedback via a native status bar or Lualine components.

**Internal Discovery**: The embedded Go binary utilizes `grove core` libraries directly to perform workspace discovery and alias resolution (`resolve-aliases`), ensuring consistent path handling with the rest of the ecosystem.

## Features

### Flow Orchestration
*   **Chat Execution**: `:GroveChatRun` executes `flow run` on the current Markdown buffer. It pipes output to a terminal window or handles headless execution with status indicators.
*   **Plan Management**: `:GrovePlan` opens a picker (via `snacks.nvim`) to browse, filter, and manage plans. `:GroveAddJob` provides a form-based UI for appending jobs to the active plan.
*   **Visual Indicators**: Renders virtual text in Markdown files to distinguish user turns, LLM responses, and running states.

### Context Management
*   **Rule Editing**: Provides syntax highlighting and virtual text statistics for `.grove/rules` files. It executes `cx stats --per-line` to display token counts and file matches next to each rule.
*   **Alias Resolution**: The rules editor supports `gf` (go to file) on `@alias` directives by resolving them via `cx resolve`.
*   **Autocompletion**: Integrates with `blink.cmp` to provide completions for:
    *   **Aliases**: `@alias:` paths resolved from the workspace via `cx workspace list`.
    *   **Git Repos**: Remote repository paths for `git:` aliases via `cx repo list`.
    *   **Templates**: Available job templates via `flow plan templates list`.

### File Marking
The `:GroveMarkFile` command adds the current buffer to a persistent `.grove/marks` list. The plugin automatically syncs this list into the `.grove/rules` file using aliases, allowing rapid context manipulation without manual rule editing.

### Testing Integration
`:GroveRunTest` executes the `tend` test scenario defined under the cursor. It extracts the scenario name from the Go file and runs `tend run --debug-session <name>` in a floating window.

### Text Interaction
`:GroveText` captures visually selected text and prompts for a user question. It appends both to a target chat file and optionally executes the run immediately (`:GroveTextRun`), facilitating "ask about code" workflows.

## Integrations

`grove.nvim` serves as the editor layer for the following tools:

*   **`flow`**: Manages the lifecycle of chat sessions and plans. The plugin reads job statuses via JSON output and executes plan modifications.
*   **`cx`**: Used for context analysis. The plugin visualizes `cx stats` data, uses `cx resolve` for navigation, and `cx workspace list` for autocompletion.
*   **`tend`**: Executes specific test scenarios identified by the cursor position in Go test files.
*   **`nav`** / **`gmux`**: `:GroveSessionize` wraps `gmux sz` to switch tmux sessions from within Neovim.
*   **`hooks`**: `:GroveHooksSessions` displays the active session history TUI.
*   **`nb`**: `:GroveNBBrowse` opens the notebook TUI for knowledge base navigation.
*   **`grove`**: Wraps the `release` and `logs` TUIs for ecosystem management.
*   **`core`**: The plugin's binary imports `grove-core` packages to replicate workspace discovery logic for internal operations.
