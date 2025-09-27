# Core Concepts

To use `grove-nvim` effectively, it's important to understand several key concepts that form the foundation of the plugin's architecture and workflow.

## The `neogrove` and `flow` Relationship

`grove-nvim` operates through a carefully designed architecture that separates concerns across multiple components:

- **`neogrove`**: A specialized Go binary that acts as a stable, editor-focused wrapper around the more general `grove-flow` tool. It provides a consistent API specifically designed for editor integration, handling the complexity of translating editor actions into flow commands.

- **`grove-flow` (invoked as `flow`)**: The underlying AI workflow engine that performs the actual work. It handles plan execution, job management, and AI interactions.

- **The Plugin Layer**: The Neovim Lua plugin calls `neogrove`, which in turn invokes `flow` commands. This layered approach ensures stability and maintainability while providing a seamless user experience.

This architecture means that while you interact with simple Neovim commands, sophisticated AI workflows are being orchestrated behind the scenes through this chain of components.

## Grove Plans

A "Plan" is the fundamental unit of complex AI workflow orchestration in the Grove ecosystem. Understanding Plans is crucial for leveraging the full power of `grove-nvim`.

### What is a Plan?

A Plan is a directory structure containing a series of AI jobs, each defined as a markdown file with YAML frontmatter. These jobs can:
- Execute independently or depend on the output of other jobs
- Run different types of AI tasks (chat, code generation, analysis, etc.)
- Be managed through a dependency graph that ensures proper execution order

### Plan Structure

Each Plan consists of:
- Individual job files (`.md` files) containing prompts and configuration
- Dependencies defined in the frontmatter specifying job relationships
- Status tracking to monitor progress and completion
- Output artifacts from completed jobs

### Working with Plans

Plans are the primary mechanism for orchestrating multi-step AI tasks that would be too complex for a single prompt. Through the `grove-nvim` commands, you can:
- Create new plans from templates or scratch
- Add jobs incrementally as your workflow evolves
- Execute plans partially or completely
- Monitor status and review outputs

The plan system transforms complex, multi-phase AI workflows into manageable, repeatable processes that can be version-controlled and shared.

## The "Target File" Workflow

The Target File concept provides a powerful bridge between your code and AI assistance, enabling a streamlined workflow for getting contextual help on specific code sections.

### Understanding the Target File

The Target File acts as a staging area for AI interactions. It's a designated file where code snippets and questions are accumulated before being processed by the AI. This approach offers several advantages:

- **Context Accumulation**: Build up relevant context by adding multiple code sections
- **Question Refinement**: Iterate on your questions before submitting
- **Persistent Reference**: Maintain a record of your AI interactions

### The Workflow Process

The Target File workflow follows these steps:

1. **Set a Target File**: Use `:GroveSetTarget` to designate any buffer as your target file. This file becomes the destination for code snippets and questions.

2. **Capture Code**: Visually select code in any buffer and use `:'<,'>GroveText` to append it to the target file along with a question or comment.

3. **Build Context**: Continue adding relevant code sections and questions to build comprehensive context for the AI.

4. **Execute the Query**: The target file, now containing all your code and questions, can be processed with `:GroveChatRun` to get AI assistance.

### Silent Execution

The `:'<,'>GroveTextRun` command combines steps 2-4, automatically:
- Appending selected code to the target file
- Prompting for a question
- Opening the target file
- Running the chat in silent mode

This workflow is particularly powerful for iterative development, where you need to query the AI about multiple related code sections while maintaining context across questions.