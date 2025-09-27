# Grove-Nvim: Neovim Integration for Grove AI Ecosystem

The `grove-nvim` repository provides a Neovim plugin that integrates the Grove AI development ecosystem directly into the editor. It acts as a bridge to `grove-flow` and other Grove tools, creating a seamless development environment where Grove tasks can be performed without leaving the editor.

## Core Philosophy: Editor-Native AI Integration

Grove-Nvim is built on the principle that AI-assisted development should feel native to the editor environment. Instead of forcing developers to switch between different tools and contexts, it brings the full power of the Grove ecosystem directly into Neovim, creating tight feedback loops between code and AI assistance.

The plugin serves developers who use Neovim and want to incorporate sophisticated AI-driven tasks into their daily workflow while maintaining their preferred editing environment.

## Dual Role: Interface Bridge and Workflow Enhancer

The `grove-nvim` plugin serves as both a bridge to Grove's AI tools and a workflow enhancer that transforms how developers interact with AI assistance in their daily coding tasks.

Key features include:

*   **In-Editor AI Chat**: Run AI chat sessions on the contents of the current buffer. The chat can be opened in various terminal layouts (vertical, horizontal, fullscreen) for interactive sessions or run silently in the background with a statusline indicator for non-blocking workflows.

*   **Plan Management**: Interact with Grove "Plans," which are structured directories containing a series of dependent AI jobs. The plugin provides a user interface to list, view the status of, and add new jobs to these plans, facilitating the orchestration of complex tasks directly from Neovim.

*   **Code-to-Chat Workflows**: A streamlined process for using code as context for AI queries. Users can visually select a block of code, append it to a designated "target" markdown file, add a follow-up question, and then initiate a chat session on that file. This creates a tight feedback loop for code analysis, refactoring, and documentation.
