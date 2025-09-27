# Documentation Task: Development & Contributing Guide

You are an expert technical writer creating documentation for the `grove-nvim` Neovim plugin.

## Task
Create a guide for developers who want to contribute to `grove-nvim`. Summarize the key information from the `Makefile` and `CLAUDE.md`.

### Key Topics to Cover:

1.  **Building the Binary**:
    - Explain the primary `make build` command.
    - Mention the output directory is `./bin`.
    - Briefly describe `make dev` for a build with the race detector.
    - Mention `make build-all` for cross-compilation.

2.  **Running Checks and Tests**:
    - List the commands for formatting, linting, and running tests: `make fmt`, `make lint`, `make test`.
    - Explain how to run the end-to-end tests with `make test-e2e`. Mention that this builds a separate `tend-neogrove` binary.

3.  **Binary Management**:
    - Emphasize the instruction from `CLAUDE.md`: the `neogrove` binary should remain in the local `./bin` directory and is managed by the `grove` meta-tool. It should NOT be copied to the system `PATH`.

## Output Format
- Use clear headings for each topic.
- Use code blocks for commands.
- Be direct and provide actionable instructions for new developers.