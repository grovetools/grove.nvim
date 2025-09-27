This document provides a reference for all user-facing commands available in `grove-nvim`.

## AI Chat

This group of commands facilitates direct interaction with the AI chat features of `grove-flow`.

### `:GroveChatRun [silent] [vertical|horizontal|fullscreen]`

Executes a `grove-flow` chat session on the contents of the current buffer. The file is automatically saved before the command is run.

-   **Arguments**:
    -   `silent`: (Optional) Runs the chat session as a background job instead of opening a terminal window. A spinner will appear in the statusline to indicate that the job is running. Upon completion, the buffer is reloaded with the chat response, and a confirmation message is displayed.
    -   `vertical|horizontal|fullscreen`: (Optional) Specifies the layout for the terminal window where the chat runs. If omitted, `vertical` is used as the default. `fullscreen` opens the chat in a new tab.

## Plan Management

Grove Plans are the primary mechanism for orchestrating complex, multi-step AI tasks. These commands provide an interface to create and manage plans directly within Neovim.

### `:GrovePlan`

Opens an interactive plan picker in a floating window, powered by `snacks.nvim`. This interface lists all available Grove Plans and allows you to select one to perform actions on, such as:
-   Viewing the plan's status.
-   Running the entire plan.
-   Adding a new job to the plan.
-   Configuring plan settings.

The picker includes a preview pane that shows the detailed status of the currently highlighted plan.

### `:GrovePlanInit`

Initiates an interactive workflow to create a new Grove Plan. It presents a series of prompts to configure the new plan, including its name, default AI model, and other settings.

### `:GrovePlanExtract`

Creates a new Grove Plan by extracting content from the current buffer. It uses the Markdown frontmatter `title` field (or the buffer's filename as a fallback) to suggest a name for the new plan. The entire content of the buffer is used to create the initial job within the plan.

### `:GroveAddJob`

Opens a form in a floating window to add a new job to the currently active Grove Plan. The form allows you to specify the job's title, type, dependencies, and other configuration details.

### `:GroveAddJobTUI`

Adds a new job to the active plan by opening the `flow` command's native Text-based User Interface (TUI) in a floating terminal. This provides an alternative, interactive way to define a new job.

## Text Interaction (Code-to-Chat)

These commands streamline the process of using code selections as context for AI chat. They rely on the concept of a "Target File," which is a designated Markdown file where code snippets and questions are collected before running a chat session.

### `:GroveSetTarget`

Sets the current buffer as the "Target File" for subsequent text interactions. This target is persisted across Neovim sessions.

### `:GroveShowTarget`

Displays the path of the currently configured target file.

### `:'<,'>GroveText`

This is a visual-mode command. It captures the visually selected text, formats it as a code block, and appends it to the target file. It then prompts you to enter a question, which is also appended to the file. This prepares the target file to be used as a complete prompt for `:GroveChatRun`.

### `:'<,'>GroveTextRun`

This visual-mode command provides a complete end-to-end workflow. It performs the same actions as `:GroveText` (captures selection, appends it, and prompts for a question), but then it automatically:
1.  Opens the target file in the current window.
2.  Jumps to the end of the file.
3.  Executes `:GroveChatRun silent` to start the AI chat session in the background.