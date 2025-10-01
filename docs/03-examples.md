# Examples

This document provides practical examples for using `grove-nvim`, demonstrating its main workflows for AI-assisted development within Neovim.

## Example 1: Interactive Chat and Plan Creation

This example demonstrates starting with an interactive session in a markdown file and converting it into a Grove plan.

1.  **Start an Interactive Chat Session**

    The `:GroveChatRun` command runs an interactive `flow chat` session on the current buffer.

    ```markdown
    ---
    title: "Implement a new caching layer"
    ---

    # Brainstorming: New Caching Layer

    Let's design a caching layer for our application. It should use Redis and have a clear API for getting, setting, and invalidating cache keys.
    ```

    Running `:GroveChatRun` opens a new terminal split within Neovim. The content of the markdown file is used as the initial context. After the session, the file is updated with the full transcript.

2.  **Convert the Chat into a Plan**

    The `:GrovePlanExtract` command creates a development plan from the current buffer's content. It prompts for a plan name, suggesting one based on the `title` field from the markdown frontmatter. If no title is found, it uses the buffer's filename as a fallback.

    ```
    New Plan Name (from buffer): implement-a-new-caching-layer
    ```

3.  **Resulting Behavior**

    After confirming the name, `grove-nvim` creates a new plan directory (e.g., `.grove/plans/implement-a-new-caching-layer/`). The content of the markdown file is used to create the first job in the plan, `010-implement-a-new-caching-layer.md`.

#### Mechanism

-   `:GroveChatRun` executes the `neogrove chat` command, which is a wrapper around the `grove-flow` tool's `flow chat run <file>` command.
-   `:GrovePlanExtract` calls `neogrove plan init --extract-all-from <file>`, which uses `grove-flow` to initialize a plan and populate the first job from the specified file's content.

---

## Example 2: Managing Plans and Jobs

This example covers viewing existing plans and adding new jobs.

1.  **Open the Plan Picker**

    The `:GrovePlan` command opens a picker that lists available plans, their status, and job counts. It includes a preview pane that shows the detailed status of the selected plan.

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

    The `:GroveAddJob` command opens a form in a floating window to define a new job for the currently active plan.

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

    The `:GroveAddJobTUI` command opens a floating terminal that runs `flow plan add -i <plan>`, which launches the interactive terminal UI for job creation from `grove-flow`.

#### Comparison of Methods

-   **Form UI (`:GroveAddJob`)**: Uses a Neovim-native UI to collect job details.
-   **Terminal TUI (`:GroveAddJobTUI`)**: Runs the underlying `grove-flow` tool directly in a terminal.

#### Mechanism

-   `:GrovePlan` calls `neogrove plan list --json` to populate the picker.
-   Adding a job via the form collects data and constructs a `neogrove plan add` command with the appropriate flags.
-   `:GroveAddJobTUI` directly invokes the `flow` TUI.

---

## Example 3: The "Target File" Code-to-Chat Workflow

This workflow is for sending code snippets and questions to a central markdown file for analysis or refactoring.

1.  **Set the Target File**

    Open a markdown file and run the `:GroveSetTarget` command. This designates the file as the "target" for the session. This setting is persisted in `~/.grove/state.yml`.

2.  **Select Code and Ask a Question**

    Navigate to a source code file and visually select a block of code.

    ```go
    // main.go
    func GetUser(id string) (*User, error) {
        // ... implementation ...  <-- visually select this function
    }
    ```

3.  **Run the Workflow**

    With the code selected, execute `:'<,'>GroveTextRun`. This performs the following actions:
    1.  A popup appears, prompting for a question about the selected code.
    2.  The selected code block and the question are appended to the target file.
    3.  Neovim switches focus to the target file buffer.
    4.  A silent `:GroveChatRun silent` command is initiated in the background.

4.  **Monitor the Background Job**

    While the AI processes the request, a spinner appears in the statusline, indicating that a job is running. This is enabled by adding `require('grove-nvim').status()` to a statusline configuration.

    *Statusline with running job:*
    ```
    ⠴ Grove | main.go | Go | UTF-8 | LF |  10:1
    ```

5.  **Check the Results**

    When the spinner disappears, the background job is complete. The target file is updated with the AI's response.

#### Use Cases

This workflow can be used for tasks such as:
-   Requesting an explanation of a function.
-   Pasting an error message and code to get debugging assistance.
-   Asking for suggestions to refactor a piece of code.
-   Generating documentation comments for a function or class.
-   Creating unit tests for a selected function.

#### Mechanism

This workflow uses `neogrove text select` and `neogrove text ask` to append content to the target file. It then triggers `neogrove chat`, which executes `flow chat run` on the updated target file. The background job and statusline integration are managed by the Lua plugin.
