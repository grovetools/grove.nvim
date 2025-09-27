# Documentation Task: Commands and Usage

You are an expert technical writer creating documentation for the `grove-nvim` Neovim plugin.

## Task
Document all user-facing commands defined in `plugin/grove.lua`. For each command, provide its name, a description of what it does, and any arguments it accepts. Organize the documentation into logical feature groups.

### Feature Groups & Commands to Document:

1.  **AI Chat**:
    - `:GroveChatRun [silent] [vertical|horizontal|fullscreen]`: Explain how it runs a chat on the current buffer. Detail the layout options and the "silent" mode with its statusline spinner. Reference `lua/grove-nvim/init.lua`.

2.  **Plan Management**:
    - `:GrovePlan`: Opens the plan picker UI. Describe the picker interface (powered by `snacks.nvim`) and the actions available (status, run, add job, etc.).
    - `:GrovePlanInit`: Initiates the creation of a new plan via a series of prompts.
    - `:GrovePlanExtract`: Creates a new plan by extracting content and frontmatter from the current buffer.
    - `:GroveAddJob`: Adds a new job to the currently active plan using a form UI.
    - `:GroveAddJobTUI`: Adds a job using the `flow` TUI in a floating terminal.

3.  **Text Interaction (Code-to-Chat)**:
    - Explain the concept of the "Target File" first.
    - `:GroveSetTarget`: Sets the current buffer as the target file for text interactions.
    - `:GroveShowTarget`: Displays the currently set target file.
    - `:'<,'>GroveText`: Captures visually selected text, appends it to the target file, and prompts for a question.
    - `:'<,'>GroveTextRun`: Does the same as `:GroveText`, but then automatically opens the target file and runs `:GroveChatRun silent`.

## Output Format
- Use a clear heading for each command.
- Use `<code>` formatting for command names and arguments.
- Provide brief, clear explanations for each command's function and arguments.
- Organize the commands under the feature group headings provided above.