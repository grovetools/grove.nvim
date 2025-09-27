# Development & Contributing

This guide provides essential information for developers who want to contribute to `grove-nvim` or build the project from source.

## Building the Binary

The `grove-nvim` project includes a comprehensive Makefile for building the `neogrove` binary that powers the Neovim plugin.

### Primary Build Command

```bash
make build
```

This command builds the `neogrove` binary and places it in the `./bin` directory. The build process automatically injects version information including the git commit, branch, and build date.

### Development Build

For development purposes, you can build with the race detector enabled:

```bash
make dev
```

This creates a debug-enabled binary that helps identify race conditions during development.

### Cross-Platform Builds

To build binaries for multiple platforms:

```bash
make build-all
```

This generates binaries for:
- Darwin (macOS) AMD64 and ARM64
- Linux AMD64 and ARM64

The cross-compiled binaries are placed in the `dist/` directory with platform-specific naming.

## Running Checks and Tests

### Code Formatting

Ensure your code follows Go formatting standards:

```bash
make fmt
```

### Linting

Run the linter to check for code quality issues:

```bash
make lint
```

Note: This requires `golangci-lint` to be installed. If not present, the Makefile will provide installation instructions.

### Unit Tests

Run the standard test suite:

```bash
make test
```

### End-to-End Tests

The project includes comprehensive end-to-end tests that validate the integration between the binary and Neovim:

```bash
make test-e2e
```

This command:
1. Builds the main `neogrove` binary
2. Builds a specialized `tend-neogrove` test runner
3. Executes the end-to-end test suite

You can pass additional arguments to the test runner:

```bash
make test-e2e ARGS="run -i"
```

### Run All Checks

To run all quality checks (formatting, vetting, linting, and tests) in one command:

```bash
make check
```

## Binary Management

### Important: Local Binary Usage

The `neogrove` binary should **always** remain in the local `./bin` directory. This is a critical architectural decision:

- The binary is managed by the `grove` meta-tool
- It should **NOT** be copied to the system `PATH`
- The `grove` ecosystem handles binary discovery and versioning

### Checking Active Binaries

To see which Grove binaries are currently active across the ecosystem:

```bash
grove list
```

### Clean Build

To remove all build artifacts and start fresh:

```bash
make clean
```

## Project Structure

Understanding the project structure helps when contributing:

- `cmd/`: Command-line interface implementation
- `lua/grove-nvim/`: Neovim plugin Lua code
- `plugin/`: Neovim plugin entry point and command definitions
- `tests/e2e/`: End-to-end test suite
- `bin/`: Build output directory (git-ignored)
- `docs/`: Project documentation

## Contribution Guidelines

When contributing to `grove-nvim`:

1. **Follow the existing code style**: The project uses standard Go formatting and established Lua patterns
2. **Write tests**: Add appropriate unit or end-to-end tests for new functionality
3. **Update documentation**: Keep docs in sync with code changes
4. **Use semantic commits**: Follow conventional commit message formats
5. **Run checks before submitting**: Use `make check` to ensure code quality

## Development Workflow

A typical development workflow:

1. Make your changes in a feature branch
2. Run `make fmt` to format your code
3. Run `make check` to validate all tests pass
4. Build with `make dev` for testing with race detection
5. Test integration with Neovim manually
6. Run `make test-e2e` to verify end-to-end functionality
7. Submit a pull request with a clear description of changes

## Debugging Tips

- Use `make dev` for race condition detection
- Check `grove` logs for meta-tool integration issues
- Use Neovim's `:messages` to see plugin error output
- The `neogrove` binary supports standard Go debugging tools

Remember: The `grove-nvim` plugin is part of the larger Grove ecosystem. Changes should maintain compatibility with the `grove` meta-tool and `grove-flow` workflow engine.