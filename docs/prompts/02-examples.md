Generate practical examples for grove-nvim that demonstrate the key workflows:

## Requirements
Create three distinct examples showing how to use grove-nvim plugin:

### Example 1: Interactive Chat and Plan Creation
Demonstrate the full workflow from chat to plan:
1. Show running an interactive chat session on a markdown file using `:GroveChatRun`
2. Demonstrate converting that chat into a structured plan using `:GrovePlanExtract`
3. Explain how the plan name is derived from the buffer's frontmatter or filename
4. Include sample output and expected behavior

### Example 2: Managing Plans and Jobs
Show plan and job management capabilities:
1. Demonstrate opening the plan picker with `:GrovePlan` to view existing plans
2. Show adding a new job to a plan using the form-based UI with `:GroveAddJob`
3. Show the alternative method using the floating terminal TUI with `:GroveAddJobTUI`
4. Explain the difference between the two job creation methods
5. Include screenshots or text representations of the UIs

### Example 3: The "Target File" Code-to-Chat Workflow
Demonstrate the powerful code-to-chat workflow:
1. Start by setting a target file with `:GroveSetTarget` (explain what happens in the statusline)
2. Show visually selecting a code block in another buffer
3. Use `:'<,'>GroveTextRun` to append the selection and a question to the target file, then automatically run a silent chat session
4. Explain how the statusline indicator provides feedback on the background job
5. Show how to check the results and iterate on the conversation
6. Include practical use cases (e.g., getting code explanations, debugging help, refactoring suggestions)

## Context Integration
For each example, explain how grove-nvim integrates with the broader Grove ecosystem, particularly the relationship between the Neovim commands, the neogrove binary, and grove-flow plans.