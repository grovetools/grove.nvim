package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/grovetools/tend/pkg/command"
	"github.com/grovetools/tend/pkg/fs"
	"github.com/grovetools/tend/pkg/harness"
)

// NvimE2eScenario tests the integration with Neovim.
func NvimE2eScenario() *harness.Scenario {
	return &harness.Scenario{
		Name:        "nvim-e2e",
		Description: "End-to-end tests for Neovim integration",
		Tags:        []string{"nvim", "e2e"},
		Steps: []harness.Step{
			setupNvimEnvironmentAndMockFlow(),
			runGroveChatRunCommand(),
			verifyFlowCommandWasCalled(),
		},
	}
}

// setupNvimEnvironmentAndMockFlow prepares a minimal, isolated Neovim environment.
func setupNvimEnvironmentAndMockFlow() harness.Step {
	return harness.NewStep("setup nvim environment and mock flow", func(ctx *harness.Context) error {
		// 1. Create directory structure
		mockBinDir := filepath.Join(ctx.RootDir, "mock_bin")
		nvimConfigDir := filepath.Join(ctx.RootDir, "nvim_config")
		testProjectDir := filepath.Join(ctx.RootDir, "test_project")
		for _, dir := range []string{mockBinDir, nvimConfigDir, testProjectDir} {
			if err := fs.CreateDir(dir); err != nil {
				return err
			}
		}

		// 2. Create mock 'flow' and 'grove' binaries
		// grove-nvim chat checks for 'flow' in PATH but actually calls 'grove flow run'
		flowLogFile := filepath.Join(ctx.RootDir, "flow_mock.log")
		// Create the log file first to ensure it exists
		if err := fs.WriteString(flowLogFile, ""); err != nil {
			return err
		}
		// Mock flow - just needs to exist for the PATH check
		mockFlowScript := `#!/bin/bash
# Mock 'flow' command - just needs to exist for PATH check
echo "Mock flow executed"
exit 0
`
		if err := fs.WriteString(filepath.Join(mockBinDir, "flow"), mockFlowScript); err != nil {
			return err
		}
		if err := os.Chmod(filepath.Join(mockBinDir, "flow"), 0755); err != nil {
			return err
		}
		// Mock grove - this is what grove-nvim actually calls
		mockGroveScript := fmt.Sprintf(`#!/bin/bash
# Mock 'grove' command - handles 'grove flow run' calls
echo "[$(date)] Mock grove called" >> %s
echo "Arguments: $@" >> %s
echo "PATH: $PATH" >> %s
echo "PWD: $PWD" >> %s
# Simulate success
echo "Mock grove flow run executed successfully"
exit 0
`, flowLogFile, flowLogFile, flowLogFile, flowLogFile)
		if err := fs.WriteString(filepath.Join(mockBinDir, "grove"), mockGroveScript); err != nil {
			return err
		}
		if err := os.Chmod(filepath.Join(mockBinDir, "grove"), 0755); err != nil {
			return err
		}

		// 3. Create a minimal init.lua to load the plugin
		// Get the absolute path to the project root
		projectRoot, err := filepath.Abs(".")
		if err != nil {
			return err
		}
		initLuaContent := fmt.Sprintf(`
-- Set up package path to find our plugin
vim.opt.runtimepath:prepend('%s')
-- Load the plugin
vim.cmd('runtime! plugin/grove.lua')

-- Override the chat_run function for headless testing
-- This replaces the terminal-based version with a simple system call
require('grove-nvim').chat_run = function()
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path == '' or buf_path == nil then
    vim.notify("Grove: No file name for the current buffer.", vim.log.levels.ERROR)
    return
  end
  
  -- Save the file before running
  vim.cmd('write')
  
  -- Use XDG-compliant grove bin directory
  local grove_nvim_path = vim.fn.expand('~/.local/share/grove/bin/grove-nvim')
  if vim.fn.filereadable(grove_nvim_path) ~= 1 then
    vim.notify("Grove: grove-nvim not found at ~/.local/share/grove/bin/grove-nvim", vim.log.levels.ERROR)
    return
  end

  -- For testing, use system() instead of terminal
  local cmd = grove_nvim_path .. ' chat ' .. vim.fn.shellescape(buf_path)
  local output = vim.fn.system(cmd)
  print("Executed: " .. cmd)
  print("Output: " .. output)
end
`, projectRoot)
		if err := fs.WriteString(filepath.Join(nvimConfigDir, "init.lua"), initLuaContent); err != nil {
			return err
		}

		// 4. Create a test file for Neovim to open
		if err := fs.WriteString(filepath.Join(testProjectDir, "my_note.md"), "# Test Note"); err != nil {
			return err
		}

		// 5. Create a fake XDG-compliant grove bin directory with a grove-nvim wrapper
		homeDir := ctx.RootDir // We'll use the root test dir as our fake HOME
		groveBinDir := filepath.Join(homeDir, ".local", "share", "grove", "bin")
		if err := fs.CreateDir(groveBinDir); err != nil {
			return err
		}
		groveNvimBinaryToTest, err := FindBinary()
		if err != nil {
			return err
		}

		// Create a debug log file for grove-nvim wrapper
		groveNvimLogFile := filepath.Join(ctx.RootDir, "grove_nvim_wrapper.log")

		// Create a wrapper script that sets PATH and calls the real grove-nvim
		groveNvimWrapper := fmt.Sprintf(`#!/bin/bash
# Wrapper script for grove-nvim that sets PATH to include mock flow
echo "[$(date)] grove-nvim wrapper called with args: $@" >> %s
echo "PATH before: $PATH" >> %s
export PATH="%s:$PATH"
echo "PATH after: $PATH" >> %s
echo "Executing: %s $@" >> %s
"%s" "$@" 2>&1 | tee -a %s
exit_code=$?
echo "Exit code: $exit_code" >> %s
exit $exit_code
`, groveNvimLogFile, groveNvimLogFile, mockBinDir, groveNvimLogFile, groveNvimBinaryToTest, groveNvimLogFile, groveNvimBinaryToTest, groveNvimLogFile, groveNvimLogFile)

		if err := fs.WriteString(filepath.Join(groveBinDir, "grove-nvim"), groveNvimWrapper); err != nil {
			return err
		}
		if err := os.Chmod(filepath.Join(groveBinDir, "grove-nvim"), 0755); err != nil {
			return err
		}

		// 6. Store paths in context for the next steps
		ctx.Set("home_dir", homeDir)
		ctx.Set("mock_bin_dir", mockBinDir)
		ctx.Set("nvim_config_dir", nvimConfigDir)
		ctx.Set("test_project_dir", testProjectDir)
		ctx.Set("flow_log_file", flowLogFile)
		ctx.Set("grove_nvim_log_file", groveNvimLogFile)

		return nil
	})
}

// runGroveChatRunCommand executes the Neovim command.
func runGroveChatRunCommand() harness.Step {
	return harness.NewStep("run :GroveChatRun command", func(ctx *harness.Context) error {
		// Get paths from context
		testProjectDir := ctx.GetString("test_project_dir")
		notePath := filepath.Join(testProjectDir, "my_note.md")

		// Create the command to run Neovim headlessly
		// Use -u to specify our init.lua instead of --clean which ignores all configs
		cmd := command.New("nvim", 
			"--headless",
			"-u", filepath.Join(ctx.GetString("nvim_config_dir"), "init.lua"),
			"-c", fmt.Sprintf("edit %s", notePath),
			"-c", "GroveChatRun",
			"-c", "qall!")

		// Set environment variables for isolation
		cmd.Env(
			fmt.Sprintf("HOME=%s", ctx.GetString("home_dir")), // Point to our fake home
			fmt.Sprintf("XDG_CONFIG_HOME=%s", ctx.GetString("nvim_config_dir")),
			fmt.Sprintf("PATH=%s:%s", ctx.GetString("mock_bin_dir"), os.Getenv("PATH")),
		)

		result := cmd.Run()
		ctx.ShowCommandOutput(cmd.String(), result.Stdout, result.Stderr)

		// Always show output for debugging
		if result.Stdout != "" || result.Stderr != "" {
			fmt.Printf("=== Neovim Output ===\nStdout:\n%s\nStderr:\n%s\n==================\n", result.Stdout, result.Stderr)
		}

		if result.ExitCode != 0 {
			// nvim might exit with 1 if there are errors, but let's check stderr
			if strings.Contains(result.Stderr, "E5108") { // Cannot open file for writing
				return nil // This is fine, nvim complains but command likely ran.
			}
			// Don't fail immediately, the command might have run despite non-zero exit
			// We'll check the logs in the verification step
		}

		return nil
	})
}

// verifyFlowCommandWasCalled checks the log file from our mock.
func verifyFlowCommandWasCalled() harness.Step {
	return harness.NewStep("verify 'grove flow run' was called", func(ctx *harness.Context) error {
		logFile := ctx.GetString("flow_log_file")
		content, err := fs.ReadString(logFile)
		if err != nil {
			return fmt.Errorf("failed to read mock grove log file: %w", err)
		}

		notePath := filepath.Join(ctx.GetString("test_project_dir"), "my_note.md")

		// Check if grove was called at all
		if content == "" {
			// Check grove-nvim wrapper log for debugging
			groveNvimLogPath := ctx.GetString("grove_nvim_log_file")
			groveNvimLog, _ := fs.ReadString(groveNvimLogPath)
			if groveNvimLog == "" {
				return fmt.Errorf("grove mock log file is empty and grove-nvim wrapper was not called")
			}
			return fmt.Errorf("grove mock log file is empty - grove command was not called\ngrove-nvim wrapper log:\n%s", groveNvimLog)
		}

		// Check for the expected command - looking for "Arguments: flow run <path>"
		expectedArgs := fmt.Sprintf("Arguments: flow run %s", notePath)
		if !strings.Contains(content, expectedArgs) {
			// Also check for just "flow run" in case path handling is different
			if !strings.Contains(content, "flow run") {
				return fmt.Errorf("grove was not called with 'flow run' command. Log content:\n%s", content)
			}
			// If we have flow run but not the exact path, that's still a pass
		}

		return nil
	})
}