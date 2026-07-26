# Makefile for grove.nvim

BINARY_NAME=grove-nvim
E2E_BINARY_NAME=tend-grove-nvim
BIN_DIR=bin
VERSION_PKG=github.com/grovetools/core/version

# --- Versioning ---
# For dev builds, we construct a version string from git info.
# For release builds, VERSION is passed in by the CI/CD pipeline (e.g., VERSION=v1.2.3)
GIT_COMMIT ?= $(shell git rev-parse --short HEAD)
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
GIT_DIRTY  ?= $(shell test -n "`git status --porcelain`" && echo "-dirty")
BUILD_DATE ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

# If VERSION is not set, default to a dev version string
VERSION ?= $(GIT_BRANCH)-$(GIT_COMMIT)$(GIT_DIRTY)

# Go LDFLAGS to inject version info at compile time
LDFLAGS = -ldflags="\
-X '$(VERSION_PKG).Version=$(VERSION)' \
-X '$(VERSION_PKG).Commit=$(GIT_COMMIT)' \
-X '$(VERSION_PKG).Branch=$(GIT_BRANCH)' \
-X '$(VERSION_PKG).BuildDate=$(BUILD_DATE)'"

# --- Cross-compile contract (set by `grove build --target`) ---
# GROVE_BUILD_OUT redirects output so cross binaries never clobber native bin/.
# GROVE_TARGET_* are applied only to the final `go build`; codegen prereqs stay native.
ifneq ($(strip $(GROVE_BUILD_OUT)),)
BIN_DIR = $(GROVE_BUILD_OUT)
endif
ifneq ($(strip $(GROVE_TARGET_GOOS)),)
GO_CROSS_ENV = GOOS=$(GROVE_TARGET_GOOS) GOARCH=$(GROVE_TARGET_GOARCH) CGO_ENABLED=0
endif

.PHONY: all build test test-lua clean fmt vet lint run check dev build-all help

all: build

build:
	@mkdir -p $(BIN_DIR)
	@echo "Building $(BINARY_NAME) version $(VERSION)..."
	@$(GO_CROSS_ENV) go build $(LDFLAGS) -o $(BIN_DIR)/$(BINARY_NAME) github.com/grovetools/grove.nvim

test:
	@echo "Running tests..."
	@go test -v ./...

# Headless Neovim smoke tests for the Lua modules (theme engine, navigator).
test-lua:
	@echo "Running Lua smoke tests..."
	@env -u GROVE_THEME nvim --headless -u NONE -l tests/lua/theme_smoke.lua
	@env -u GROVE_TERMINAL -u TUIMUX_PTY -u GROVE_PTY nvim --headless -u NONE -l tests/lua/navigator_smoke.lua
	@nvim --headless -u NONE -l tests/lua/diff_view_lsp_smoke.lua

clean:
	@echo "Cleaning..."
	@go clean
	@rm -rf $(BIN_DIR)
	@rm -f $(BINARY_NAME)
	@rm -f $(E2E_BINARY_NAME)
	@rm -f coverage.out

fmt:
	@echo "Formatting code..."
	@go fmt ./...

vet:
	@echo "Running go vet..."
	@go vet ./...

lint:
	@echo "Running linter..."
	@if command -v golangci-lint > /dev/null; then \
		golangci-lint run; \
	else \
		echo "golangci-lint not installed. Install with: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; \
	fi

# Run the CLI
run: build
	@$(BIN_DIR)/$(BINARY_NAME) $(ARGS)

# Run all checks
check: fmt vet lint test

# Development build with race detector
dev:
	@mkdir -p $(BIN_DIR)
	@echo "Building $(BINARY_NAME) version $(VERSION) with race detector..."
	@go build -race $(LDFLAGS) -o $(BIN_DIR)/$(BINARY_NAME) github.com/grovetools/grove.nvim

# Cross-compilation targets
PLATFORMS ?= darwin/amd64 darwin/arm64 linux/amd64 linux/arm64
DIST_DIR ?= dist

build-all:
	@echo "Building for multiple platforms into $(DIST_DIR)..."
	@mkdir -p $(DIST_DIR)
	@for platform in $(PLATFORMS); do \
		os=$$(echo $$platform | cut -d'/' -f1); \
		arch=$$(echo $$platform | cut -d'/' -f2); \
		output_name="$(BINARY_NAME)-$${os}-$${arch}"; \
		echo "  -> Building $${output_name} version $(VERSION)"; \
		GOOS=$$os GOARCH=$$arch go build $(LDFLAGS) -o $(DIST_DIR)/$${output_name} github.com/grovetools/grove.nvim; \
	done

# --- E2E Testing ---
# Build the custom tend binary for grove-nvim E2E tests.
# Run E2E tests. Depends on the main 'grove-nvim' binary and the test runner.
# Pass arguments via ARGS, e.g., make test-e2e ARGS="run -i"
test-e2e: build
	@echo "Running E2E tests..."
	@go build -o $(BIN_DIR)/$(E2E_BINARY_NAME) ./tests/e2e/
	@GROVE_NVIM_BINARY=$(abspath $(BIN_DIR)/$(BINARY_NAME)) tend run -p $(ARGS)

# Show available targets
help:
	@echo "Available targets:"
	@echo "  make build       - Build the binary"
	@echo "  make test        - Run tests"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make fmt         - Format code"
	@echo "  make vet         - Run go vet"
	@echo "  make lint        - Run linter"
	@echo "  make run ARGS=.. - Run the CLI with arguments"
	@echo "  make check       - Run all checks"
	@echo "  make dev         - Build with race detector"
	@echo "  make build-all   - Build for multiple platforms"
	@echo "  make test-e2e ARGS=...- Run E2E test runner binary"
	@echo "  make test-e2e ARGS=...- Run E2E tests (e.g., ARGS=\"run -i grove-nvim-basic-generation\")"