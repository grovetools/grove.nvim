Generate an overview section for grove-nvim.

## Requirements
Create a comprehensive overview that includes:

1. **High-level description**: What grove-nvim is and its purpose as a Neovim plugin for Grove integration
2. **Animated GIF placeholder**: Include `<!-- placeholder for animated gif -->`
3. **Key features**: Document these specific features:
   - In-editor AI Chat (`:GroveChatRun`) for interactive conversations
   - Plan Management with interactive picker (`:GrovePlan`), plan creation (`:GrovePlanInit`), and plan extraction from buffers (`:GrovePlanExtract`)
   - "Code-to-Chat" workflow using Target Files (`:GroveSetTarget`, `:'<,'>GroveTextRun`)
   - Integration with grove-flow plans and job management
4. **How it works**: Provide a more technical description and exactly what happens under the hood
5. **Installation**: Include brief installation instructions using the standard `grove install grove-nvim` method

## Installation Format
Include this condensed installation section at the bottom:

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

## Context
Grove-nvim is a Neovim plugin that integrates the Grove AI development ecosystem directly into your editor, enabling seamless access to Grove tools and workflows.
