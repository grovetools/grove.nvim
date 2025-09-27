# Documentation Task: Core Concepts

You are an expert technical writer creating documentation for the `grove-nvim` Neovim plugin.

## Task
Explain the core concepts that a user must understand to use `grove-nvim` effectively. This expands on the generic prompt that existed previously.

### Concepts to Explain:

1.  **The `neogrove` and `flow` Relationship**:
    - Clarify that `neogrove` is a specialized wrapper around the more general `grove-flow` (`flow`) tool. Its purpose is to provide a stable, editor-focused API. The Neovim plugin calls `neogrove`, which in turn calls `flow`.

2.  **Grove Plans**:
    - Describe what a "Plan" is in the Grove ecosystem: a directory containing a series of AI jobs (defined as markdown files) that can have dependencies on each other.
    - Explain that Plans are the primary mechanism for orchestrating complex, multi-step AI tasks.
    - Reference the `plan` subcommands in `cmd/plan.go` to understand the scope of plan interactions.

3.  **The "Target File" Workflow**:
    - Explain the concept of the "Target File" used by the text interaction commands.
    - Describe the workflow: 1. Set a target file (`:GroveSetTarget`). 2. Visually select code (`:'<,'>GroveText`). 3. The code and a question are appended to the target file. 4. The target file becomes a complete prompt that can be run with `:GroveChatRun`. This is based on `lua/grove-nvim/text.lua`.

## Output Format
- Use a clear heading (`##`) for each concept.
- Explain each concept clearly and concisely.