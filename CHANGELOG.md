## v0.0.4 (2025-09-17)

### Bug Fixes

* improve worktree flag handling and tmux session logic
* remove default values from yes/no prompts to avoid display issue
* resolve dialog flow issue in extract_from_buffer

### Documentation

* **changelog:** update CHANGELOG.md for v0.0.4
* **changelog:** update CHANGELOG.md for v0.0.4

### Chores

* bump dependencies
* update Grove dependencies to latest versions

### Features

* add option to open plan in tmux session after creation
* extract plan name from markdown frontmatter title
* use buffer filename as default plan name
* add plan extraction from current buffer

## v0.0.4 (2025-09-17)

### Features

* add option to open plan in tmux session after creation
* extract plan name from markdown frontmatter title
* use buffer filename as default plan name
* add plan extraction from current buffer

### Bug Fixes

* improve worktree flag handling and tmux session logic
* remove default values from yes/no prompts to avoid display issue
* resolve dialog flow issue in extract_from_buffer

### Documentation

* **changelog:** update CHANGELOG.md for v0.0.4

### Chores

* bump dependencies
* update Grove dependencies to latest versions

## v0.0.4 (2025-09-13)

### Chores

* update Grove dependencies to latest versions

## v0.0.3 (2025-08-25)

### Features

* add layout options to GroveChatRun command
* persist target file state across sessions
* add silent mode for GroveChatRun with statusline spinner
* make GroveTextRun jump to bottom of target file
* add GroveTextRun command for streamlined workflow
* add inline chat text selection feature
* add tend tests for neovim
* add floating terminal TUI for job creation
* add plan configuration support and improve UX

### Code Refactoring

* simplify GroveSetTarget to use current buffer

### Tests

* add simplified text interaction E2E test

### Bug Fixes

* don't run e2e in ci
* disable lfs and go linting
* eliminate "Press ENTER" prompts in silent mode

### Documentation

* add statusline integration to README and improve spinner

### Continuous Integration

* add Git LFS disable to release workflow

### Chores

* bump dependencies

## v0.0.2 (2025-08-15)

### Features

* add Grove Plan support with multi-select dependencies
* implement GroveChatRun command for Neovim

### Bug Fixes

* update root command
* lint
* update gitignore

### Chores

* **deps:** bump dependencies
* bump deps

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial implementation of grove-nvim
- Basic command structure
- E2E test framework