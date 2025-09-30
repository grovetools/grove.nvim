This document provides practical examples for using `grove-nvim`, demonstrating its main workflows for AI-assisted development within Neovim.

## Example 1: Interactive Chat and Plan Creation

This example demonstrates the workflow of starting with an interactive brainstorming session in a markdown file and converting it into a structured Grove plan.

1.  **Start an Interactive Chat Session**

    Begin by creating a new markdown file, for instance, `new-feature-idea.md`. This file will serve as your scratchpad. To start a chat, use the `:GroveChatRun` command.

    ```markdown
    ---
    title: "Implement a new caching layer"
    ---

    # Brainstorming: New Caching Layer

    Let's design a caching layer for our application. It should use Redis and have a clear API for getting, setting, and invalidating cache keys.
    ```

    Running `:GroveChatRun` will open a new terminal split within Neovim, running an interactive `flow chat` session. The content of your markdown file is used as the initial context. After your conversation with the AI, the file will be updated with the full transcript.

2.  **Convert the Chat into a Plan**

    Once the chat contains a solid outline for the work, you can convert it directly into a development plan using the `:GrovePlanExtract` command.

    When you run this command, `grove-nvim` will prompt you for a name for the new plan.

    ```
    New Plan Name (from buffer): implement-a-new-caching-layer
    ```

    The plugin intelligently suggests a plan name. It prioritizes the `title` field from the markdown file's frontmatter. If no title is found, it uses the buffer's filename as a fallback.

3.  **Expected Behavior**

    After confirming the name, `grove-nvim` creates a new plan directory (e.g., `.grove/plans/implement-a-new-caching-layer/`). The entire content of your `new-feature-idea.md` file is used to create the first job in the plan, `010-implement-a-new-caching-layer.md`, providing a complete context for the initial development task. You can then add more jobs to break down the work further.

#### Context Integration

-   `:GroveChatRun` executes the `neogrove chat` command, which is a wrapper around the `grove-flow` tool's `flow chat run <file>` command.
-   `:GrovePlanExtract` calls `neogrove plan init --extract-all-from <file>`, which uses `grove-flow` to initialize a plan and populate the first job from the specified file's content. The `neogrove` binary acts as a bridge between Neovim and the underlying Grove tools.

---

## Example 2: Managing Plans and Jobs

This example covers how to view existing plans and add new jobs using the different UI options provided by `grove-nvim`.

1.  **Open the Plan Picker**

    To see all available plans in your project, use the `:GrovePlan` command. This opens an interactive plan picker, which displays a list of plans, their current status, and the number of jobs in each. The picker also features a preview pane that shows the detailed status of the selected plan.

    *Text representation of the plan picker:*
    ```
    ┌────────────────────────── Grove Plans ──────────────────────────┐
    │ > 🔍                                                            │
    ├─────────────────────────────────────────────────────────────────┤
    │   implement-a-new-caching-layer pending           1 jobs        │
    │   refactor-user-api             completed        12 jobs        │
    │   setup-ci-pipeline             in-progress       5 jobs        │
    │                                                                 │
    ├─────────────────────────────────────────────────────────────────┤
    │ Plan: refactor-user-api                                         │
    │ Status: completed                                               │
    │ Jobs: 12/12 completed                                           │
    │                                                                 │
    │ ✅ 010-map-out-api-endpoints.md                                  │
    │ ✅ 020-update-auth-middleware.md                                 │
    │ ...                                                             │
    └─────────────────────────────────────────────────────────────────┘
    ```

2.  **Add a Job with the Form UI**

    After selecting a plan from the picker, an actions menu appears. Choose "Add Job", or use the command `:GroveAddJob` directly to add a job to the currently active plan. This opens a form in a floating window, providing a structured way to define the new job.

    *Text representation of the "Add Job" form:*
    ```
    ┌────────────────── Create New Job in 'refactor-user-api' ──────────────────┐
    │ Title:              Add rate limiting to endpoints                        │
    │ Job Type:           agent                                                 │
    │ Template:           [No template]                                         │
    │ Prompt:             Use the new middleware to...                          │
    │ Dependencies:       [020-update-auth-middleware.md]                       │
    │ Model:              [Use plan default: claude-3-5-sonnet]                 │
    │ Worktree:           feature/api-rate-limiting                           │
    │                                                                           │
    │ ───────────────────────────────────────────────────────────────────────── │
    │         [ Create Job ]            [ Cancel ]                              │
    └───────────────────────────────────────────────────────────────────────────┘
    ```

3.  **Add a Job with the Floating Terminal TUI**

    For users who prefer the native command-line interface of `grove-flow`, `grove-nvim` provides an alternative. The `:GroveAddJobTUI` command opens a floating terminal that runs `flow plan add -i <plan>`, launching the interactive terminal-based UI for job creation.

#### Difference Between Methods

-   **Form UI (`:GroveAddJob`)**: Offers a Neovim-native editing experience. It is ideal for quickly filling out job details without leaving the editor's UI paradigm.
-   **Terminal TUI (`:GroveAddJobTUI`)**: Provides the full, unfiltered experience of the underlying `grove-flow` tool. It is suited for users who are already familiar with the `flow` command and its features.

#### Context Integration

The plan management features rely heavily on `neogrove` as an intermediary. `:GrovePlan` calls `neogrove plan list --json` to populate the picker. Adding a job via the form collects the data and constructs a `neogrove plan add` command with the appropriate flags. `:GroveAddJobTUI` directly invokes the underlying `flow` TUI for a native experience.

---

## Example 3: The "Target File" Code-to-Chat Workflow

This workflow is designed for sending code snippets and questions to a central "chat" file for analysis, refactoring, or documentation without leaving your current code buffer.

1.  **Set the Target File**

    First, open or create a markdown file that will serve as the log for your conversation (e.g., `api-refactor-session.md`). In this buffer, run the `:GroveSetTarget` command. A notification will confirm that the target file has been set. This setting is persisted across Neovim sessions.

2.  **Select Code and Ask a Question**

    Navigate to a source code file. Visually select a block of code you want to discuss.

    ```go
    // main.go
    func GetUser(id string) (*User, error) {
        // ... implementation ...  <-- visually select this function
    }
    ```

3.  **Run the Workflow**

    With the code selected, execute the command `:'<,'>GroveTextRun`. This triggers a sequence of events:
    1.  A popup appears, prompting you to enter a question about the selected code (e.g., "How can I add error handling and logging to this function?").
    2.  The selected code block (formatted with its filetype) and your question are appended to the target file (`api-refactor-session.md`).
    3.  Neovim automatically switches focus to the target file buffer.
    4.  A silent `:GroveChatRun silent` command is initiated in the background.

4.  **Monitor the Background Job**

    While the AI processes your request, a spinner will appear in your statusline, indicating that a Grove job is running. This feedback is enabled by adding `require('grove-nvim').status()` to your statusline configuration.

    *Statusline with running job:*
    ```
    ⠴ Grove | main.go | Go | UTF-8 | LF |  10:1
    ```

5.  **Check the Results**

    When the spinner disappears, the background job is complete. The target file is automatically updated with the AI's response directly below your question, allowing you to review the suggestion, make edits, and continue the conversation by running `:GroveChatRun` again.

#### Practical Use Cases

This workflow is highly effective for tasks such as:
-   **Code Explanation**: Getting a detailed explanation of a complex function.
-   **Debugging**: Pasting an error message and a block of code to get debugging help.
-   **Refactoring**: Asking for suggestions to improve or refactor a piece of code.
-   **Documentation**: Generating documentation comments for a function or class.
-   **Test Generation**: Creating unit tests for a selected function.

#### Context Integration

This workflow orchestrates several components. `:'<,'>GroveTextRun` uses the `neogrove text select` and `neogrove text ask` commands to append content to the target file. It then triggers `neogrove chat`, which executes `flow chat run` on the now-updated target file. The background job and statusline integration are managed by the Lua plugin, showcasing a seamless link between the Neovim frontend, the `neogrove` command-line bridge, and the `grove-flow` engine.