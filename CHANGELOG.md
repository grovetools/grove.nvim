## v0.1.1-nightly.9de9a75 (2025-10-03)

## v0.1.0 (2025-10-01)

A new plan extraction workflow has been introduced, allowing for the creation of Grove plans directly from the content of the current Neovim buffer (2f89605). The plan name is now intelligently suggested by parsing the title from Markdown frontmatter (5fdc52c) or falling back to the buffer's filename (c997880). After creating a plan with an associated worktree, there is now an option to open it directly in a new tmux session, streamlining the transition from planning to execution (a6bae99).

The handling of Git worktree creation during plan initialization has been significantly improved through a series of fixes. The `--worktree` and `--with-worktree` flags are now correctly aligned with the underlying `flow` tool's behavior, ensuring more reliable auto-naming and flag handling (1bbe1c0, d3518b5, d9975a6). The user dialog flow for these options has been made more robust (4048562, 750e503), resolving issues with nested callbacks (97407ba) and display artifacts in prompts (b596680).

The project's documentation has been completely restructured and expanded. It is now organized into three focused sections: Overview, Configuration, and Examples (3d6daa7), with new content covering key features and workflows (44e8acf, 491fe98). The documentation generation process itself has been enhanced with automatic Table of Contents generation and more standardized configurations (d52bee5, 9e61764). Additionally, the release workflow has been updated to extract release notes directly from `CHANGELOG.md`, ensuring consistency between the repository and GitHub releases (7be96de).

### Features

- make docs succinct, edit docs.rules, add stripines (d5ef5b4)
- add TOC generation and docgen configuration updates (d52bee5)
- update release workflow to use CHANGELOG.md (7be96de)
- add option to open plan in tmux session after creation (a6bae99)
- extract plan name from markdown frontmatter title (5fdc52c)
- use buffer filename as default plan name (c997880)
- add plan extraction from current buffer (2f89605)

### Bug Fixes

- update CI workflow to use none branches instead of commenting (5803e45)
- use --with-worktree boolean flag for auto-naming (d9975a6)
- use --worktree flag without value for auto-naming (d3518b5)
- pass plan name as value to --worktree flag (239135b)
- align worktree flag handling with flow command (1bbe1c0)
- make worktree response handling more robust (4048562)
- improve worktree flag handling and tmux session logic (750e503)
- remove default values from yes/no prompts to avoid display issue (b596680)
- resolve dialog flow issue in extract_from_buffer (97407ba)

### Code Refactoring

- standardize docgen.config.yml key order and settings (9e61764)

### Documentation

- update docgen configuration and README templates (94a6e02)
- streamline grove-nvim documentation to 3 focused sections (3d6daa7)
- rename Introduction sections to Overview (491fe98)
- simplify installation to point to main Grove guide (bb01d66)
- initial documentation structure (44e8acf)
- update CHANGELOG.md for v0.0.4 (7138972)
- update CHANGELOG.md for v0.0.4 (9e96b48)
- update CHANGELOG.md for v0.0.4 (5bf2316)
- update CHANGELOG.md for v0.0.4 (d8751f5)

### Chores

- temporarily disable CI workflow (642b0f7)
- update .gitignore rules (9d1fea8)
- bump dependencies (3b98c41)
- update Grove dependencies to latest versions (573c7e0)

### Continuous Integration

- remove redundant tests from release workflow (0ac2a5c)

### File Changes

```
 .github/workflows/ci.yml            |   4 +-
 .github/workflows/release.yml       |  13 +-
 .gitignore                          |   3 +
 CHANGELOG.md                        |  30 ++
 CLAUDE.md                           |  30 ++
 README.md                           |  98 ++--
 cmd/plan.go                         |  21 +
 docs/01-overview.md                 |  46 ++
 docs/02-configuration.md            |  92 ++++
 docs/03-examples.md                 | 160 +++++++
 docs/README.md.tpl                  |   6 +
 docs/docgen.config.yml              |  35 ++
 docs/docs.rules                     |   1 +
 docs/images/grove-neovim-readme.svg | 906 ++++++++++++++++++++++++++++++++++++
 docs/prompts/01-overview.md         |  34 ++
 docs/prompts/02-examples.md         |  31 ++
 docs/prompts/03-configuration.md    |  48 ++
 go.mod                              |  24 +-
 go.sum                              | 127 +----
 lua/grove-nvim/plan.lua             | 129 +++++
 pkg/docs/docs.json                  |  61 +++
 plugin/grove.lua                    |  12 +
 22 files changed, 1700 insertions(+), 211 deletions(-)
```

## v0.0.4 (2025-09-17)

### Features

* add option to open plan in tmux session after creation
* extract plan name from markdown frontmatter title
* use buffer filename as default plan name
* add plan extraction from current buffer

### Bug Fixes

* use --worktree flag without value for auto-naming
* pass plan name as value to --worktree flag
* align worktree flag handling with flow command
* make worktree response handling more robust
* improve worktree flag handling and tmux session logic
* remove default values from yes/no prompts to avoid display issue
* resolve dialog flow issue in extract_from_buffer

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
