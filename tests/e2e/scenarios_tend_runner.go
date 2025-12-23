package main

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/mattsolo1/grove-tend/pkg/command"
	"github.com/mattsolo1/grove-tend/pkg/fs"
	"github.com/mattsolo1/grove-tend/pkg/harness"
)

// LaunchTestUnderCursorHappyPath tests the basic functionality of running a test from its definition.
func LaunchTestUnderCursorHappyPath() *harness.Scenario {
	return &harness.Scenario{
		Name:        "launch-test-under-cursor-happy-path",
		Description: "Verifies a tend test can be launched from its definition under the cursor",
		Tags:        []string{"tend", "runner", "core"},
		Steps: []harness.Step{
			setupTestFileWithScenario(),
			openTestFileAndPositionCursorOnScenario(),
			executeGroveRunTestCommand(),
			verifyCommandOutputInLog(),
		},
	}
}

// LaunchTestWithCustomCommand verifies that custom command templates are respected.
func LaunchTestWithCustomCommand() *harness.Scenario {
	return &harness.Scenario{
		Name:        "launch-test-under-cursor-custom-command",
		Description: "Verifies that the test runner uses a custom command template from the user's config",
		Tags:        []string{"tend", "runner", "config"},
		Steps: []harness.Step{
			setupTestFileAndCustomConfig(),
			executeGroveRunTestCommandCustom(),
			verifyCustomCommandOutput(),
		},
	}
}

// LaunchTestInvalidCursorPosition tests graceful failure when cursor is not on a valid scenario name.
func LaunchTestInvalidCursorPosition() *harness.Scenario {
	return &harness.Scenario{
		Name:        "launch-test-under-cursor-invalid-position",
		Description: "Verifies graceful failure when the command is run with the cursor in an invalid position",
		Tags:        []string{"tend", "runner", "edge-case"},
		Steps: []harness.Step{
			setupTestFileWithScenario(),
			openTestFileAndPositionCursorOnEmptyLine(),
			executeGroveRunTestAndVerifyWarning(),
		},
	}
}

// LaunchTestVariousNameFormats tests that scenario names with hyphens and underscores are handled correctly.
func LaunchTestVariousNameFormats() *harness.Scenario {
	return &harness.Scenario{
		Name:        "launch-test-under-cursor-name-formats",
		Description: "Verifies that scenario names with hyphens and underscores are correctly identified",
		Tags:        []string{"tend", "runner", "core"},
		Steps: []harness.Step{
			setupTestFileWithVariousNames(),
			openFileAndRunTestOnHyphenatedName(),
			verifyHyphenatedNameCommandOutput(),
			openFileAndRunTestOnUnderscoredName(),
			verifyUnderscoredNameCommandOutput(),
		},
	}
}

// Helper functions for setting up test environments

func setupTestFileWithScenario() harness.Step {
	return harness.NewStep("setup test file with scenario", func(ctx *harness.Context) error {
		testDir := filepath.Join(ctx.RootDir, "test_project")
		if err := fs.CreateDir(testDir); err != nil {
			return err
		}

		// Create a test file with a tend scenario definition
		testContent := `package main

import (
	"github.com/mattsolo1/grove-tend/pkg/harness"
)

func MyTestScenario() *harness.Scenario {
	return &harness.Scenario{
		Name:        "my-test-scenario",
		Description: "A test scenario for testing",
		Tags:        []string{"test"},
		Steps:       []harness.Step{},
	}
}
`
		testFilePath := filepath.Join(testDir, "test_scenario.go")
		if err := fs.WriteString(testFilePath, testContent); err != nil {
			return err
		}

		ctx.Set("test_file_path", testFilePath)
		ctx.Set("test_dir", testDir)
		ctx.Set("scenario_name", "my-test-scenario")

		return nil
	})
}

func setupTestFileWithVariousNames() harness.Step {
	return harness.NewStep("setup test file with various scenario names", func(ctx *harness.Context) error {
		testDir := filepath.Join(ctx.RootDir, "test_project")
		if err := fs.CreateDir(testDir); err != nil {
			return err
		}

		// Create a test file with multiple scenario names
		testContent := `package main

import (
	"github.com/mattsolo1/grove-tend/pkg/harness"
)

func HyphenatedScenario() *harness.Scenario {
	return &harness.Scenario{
		Name:        "my-hyphenated-scenario",
		Description: "A test scenario with hyphens",
		Tags:        []string{"test"},
		Steps:       []harness.Step{},
	}
}

func UnderscoredScenario() *harness.Scenario {
	return &harness.Scenario{
		Name:        "my_underscored_scenario",
		Description: "A test scenario with underscores",
		Tags:        []string{"test"},
		Steps:       []harness.Step{},
	}
}
`
		testFilePath := filepath.Join(testDir, "test_scenarios.go")
		if err := fs.WriteString(testFilePath, testContent); err != nil {
			return err
		}

		ctx.Set("test_file_path", testFilePath)
		ctx.Set("test_dir", testDir)
		ctx.Set("hyphenated_name", "my-hyphenated-scenario")
		ctx.Set("underscored_name", "my_underscored_scenario")

		return nil
	})
}

func setupTestFileAndCustomConfig() harness.Step {
	return harness.NewStep("setup test file and custom nvim config", func(ctx *harness.Context) error {
		// First setup the test file
		testDir := filepath.Join(ctx.RootDir, "test_project")
		if err := fs.CreateDir(testDir); err != nil {
			return err
		}

		testContent := `package main

import (
	"github.com/mattsolo1/grove-tend/pkg/harness"
)

func CustomTestScenario() *harness.Scenario {
	return &harness.Scenario{
		Name:        "custom-test-scenario",
		Description: "A test scenario for custom command",
		Tags:        []string{"test"},
		Steps:       []harness.Step{},
	}
}
`
		testFilePath := filepath.Join(testDir, "test_scenario.go")
		if err := fs.WriteString(testFilePath, testContent); err != nil {
			return err
		}

		// Create a custom nvim config with modified command template
		nvimConfigDir := filepath.Join(ctx.RootDir, "nvim_config")
		if err := fs.CreateDir(nvimConfigDir); err != nil {
			return err
		}

		projectRoot, err := filepath.Abs(".")
		if err != nil {
			return err
		}

		// Create a log file to capture the command output
		logFile := filepath.Join(ctx.RootDir, "grove_command.log")
		ctx.Set("log_file", logFile)

		scenarioName := "custom-test-scenario"

		// Create a custom command that we can easily verify
		customInitLua := fmt.Sprintf(`
-- Set up package path to find our plugin
vim.opt.runtimepath:prepend('%s')
-- Load the plugin
vim.cmd('runtime! plugin/grove.lua')

-- Override the config with a custom command template
require('grove-nvim').setup({
  test_runner = {
    command_template = "echo 'CUSTOM: %%s'"
  }
})

-- Search for the scenario name WITH QUOTES (realistic Go code scenario)
vim.cmd('edit %s')
vim.fn.search('"%s"')  -- Search for the quoted version

-- Override utils.run_in_float_term_output to log instead of showing terminal
local original_run = require('grove-nvim.utils').run_in_float_term_output
require('grove-nvim.utils').run_in_float_term_output = function(cmd)
  local log_file = io.open('%s', 'w')
  if log_file then
    log_file:write('Command executed: ' .. cmd .. '\n')
    local handle = io.popen(cmd .. ' 2>&1')
    if handle then
      local result = handle:read('*a')
      handle:close()
      log_file:write('Output:\n' .. result .. '\n')
    end
    log_file:close()
  end
end

-- Run the command
vim.cmd('GroveRunTest')
`, projectRoot, testFilePath, scenarioName, logFile)

		if err := fs.WriteString(filepath.Join(nvimConfigDir, "init.lua"), customInitLua); err != nil {
			return err
		}

		ctx.Set("test_file_path", testFilePath)
		ctx.Set("test_dir", testDir)
		ctx.Set("nvim_config_dir", nvimConfigDir)
		ctx.Set("scenario_name", scenarioName)

		return nil
	})
}

// Helper functions for executing Neovim commands

func openTestFileAndPositionCursorOnScenario() harness.Step {
	return harness.NewStep("open test file and position cursor on scenario name", func(ctx *harness.Context) error {
		testFilePath := ctx.GetString("test_file_path")
		nvimConfigDir := setupDefaultNvimConfig(ctx)

		// Create a log file to capture the command output
		logFile := filepath.Join(ctx.RootDir, "grove_command.log")
		ctx.Set("log_file", logFile)

		// Get the absolute path to the project root
		projectRoot, err := filepath.Abs(".")
		if err != nil {
			return err
		}

		// Create a minimal init.lua that loads the plugin and runs the test
		scenarioName := ctx.GetString("scenario_name")
		initLuaContent := fmt.Sprintf(`
-- Set up package path to find our plugin
vim.opt.runtimepath:prepend('%s')
-- Load the plugin
vim.cmd('runtime! plugin/grove.lua')

-- Search for the scenario name WITH QUOTES (realistic Go code scenario)
vim.cmd('edit %s')
vim.fn.search('"%s"')  -- Search for the quoted version

-- Override utils.run_in_float_term_output to log instead of showing terminal
local original_run = require('grove-nvim.utils').run_in_float_term_output
require('grove-nvim.utils').run_in_float_term_output = function(cmd)
  -- Log the command that would be executed
  local log_file = io.open('%s', 'w')
  if log_file then
    log_file:write('Command executed: ' .. cmd .. '\n')
    -- Also run the command and capture output
    local handle = io.popen(cmd .. ' 2>&1')
    if handle then
      local result = handle:read('*a')
      handle:close()
      log_file:write('Output:\n' .. result .. '\n')
    end
    log_file:close()
  end
end

-- Run the command
vim.cmd('GroveRunTest')
`, projectRoot, testFilePath, scenarioName, logFile)

		if err := fs.WriteString(filepath.Join(nvimConfigDir, "init.lua"), initLuaContent); err != nil {
			return err
		}

		ctx.Set("nvim_config_dir", nvimConfigDir)

		return nil
	})
}

func openTestFileAndPositionCursorOnEmptyLine() harness.Step {
	return harness.NewStep("open test file and position cursor on empty line", func(ctx *harness.Context) error {
		testDir := ctx.GetString("test_dir")
		nvimConfigDir := setupDefaultNvimConfig(ctx)

		// Create a truly empty file to test on
		emptyFilePath := filepath.Join(testDir, "empty.txt")
		if err := fs.WriteString(emptyFilePath, "\n\n\n"); err != nil {
			return err
		}

		// Create a log file to capture notifications
		logFile := filepath.Join(ctx.RootDir, "grove_warning.log")
		ctx.Set("log_file", logFile)

		projectRoot, err := filepath.Abs(".")
		if err != nil {
			return err
		}

		// Position cursor on empty line
		initLuaContent := fmt.Sprintf(`
-- Set up package path to find our plugin
vim.opt.runtimepath:prepend('%s')
-- Load the plugin
vim.cmd('runtime! plugin/grove.lua')

-- Override vim.notify to capture warnings
local log_file = io.open('%s', 'w')
local original_notify = vim.notify
vim.notify = function(msg, level, opts)
  if log_file then
    log_file:write('Notification: ' .. msg .. '\n')
    if level then
      log_file:write('Level: ' .. tostring(level) .. '\n')
    end
    log_file:flush()
  end
  original_notify(msg, level, opts)
end

-- Open empty file and position on empty line
vim.cmd('edit %s')
vim.api.nvim_win_set_cursor(0, {2, 0})

-- Run the command
vim.cmd('GroveRunTest')

-- Close log file
if log_file then
  log_file:close()
end
`, projectRoot, logFile, emptyFilePath)

		if err := fs.WriteString(filepath.Join(nvimConfigDir, "init.lua"), initLuaContent); err != nil {
			return err
		}

		ctx.Set("nvim_config_dir", nvimConfigDir)

		return nil
	})
}

func openFileAndRunTestOnHyphenatedName() harness.Step {
	return harness.NewStep("open file and run test on hyphenated name", func(ctx *harness.Context) error {
		if err := setupTestForSpecificName(ctx, ctx.GetString("hyphenated_name"), "hyphenated_log.txt"); err != nil {
			return err
		}
		return runNvimWithConfig(ctx)
	})
}

func openFileAndRunTestOnUnderscoredName() harness.Step {
	return harness.NewStep("open file and run test on underscored name", func(ctx *harness.Context) error {
		if err := setupTestForSpecificName(ctx, ctx.GetString("underscored_name"), "underscored_log.txt"); err != nil {
			return err
		}
		return runNvimWithConfig(ctx)
	})
}

func setupTestForSpecificName(ctx *harness.Context, scenarioName, logFileName string) error {
	testFilePath := ctx.GetString("test_file_path")
	nvimConfigDir := ctx.GetString("nvim_config_dir")
	if nvimConfigDir == "" {
		nvimConfigDir = setupDefaultNvimConfig(ctx)
	}

	logFile := filepath.Join(ctx.RootDir, logFileName)
	ctx.Set("log_file", logFile)

	projectRoot, err := filepath.Abs(".")
	if err != nil {
		return err
	}

	initLuaContent := fmt.Sprintf(`
-- Set up package path to find our plugin
vim.opt.runtimepath:prepend('%s')
-- Load the plugin
vim.cmd('runtime! plugin/grove.lua')

-- Search for the scenario name WITH QUOTES (realistic Go code scenario)
vim.cmd('edit %s')
vim.fn.search('"%s"')  -- Search for the quoted version

-- Override utils.run_in_float_term_output to log instead of showing terminal
local original_run = require('grove-nvim.utils').run_in_float_term_output
require('grove-nvim.utils').run_in_float_term_output = function(cmd)
  local log_file = io.open('%s', 'w')
  if log_file then
    log_file:write('Command executed: ' .. cmd .. '\n')
    local handle = io.popen(cmd .. ' 2>&1')
    if handle then
      local result = handle:read('*a')
      handle:close()
      log_file:write('Output:\n' .. result .. '\n')
    end
    log_file:close()
  end
end

vim.cmd('GroveRunTest')
`, projectRoot, testFilePath, scenarioName, logFile)

	if err := fs.WriteString(filepath.Join(nvimConfigDir, "init.lua"), initLuaContent); err != nil {
		return err
	}

	ctx.Set("nvim_config_dir", nvimConfigDir)
	ctx.Set("current_scenario_name", scenarioName)

	return nil
}

func runNvimWithConfig(ctx *harness.Context) error {
	nvimConfigDir := ctx.GetString("nvim_config_dir")

	cmd := command.New("nvim",
		"--headless",
		"-u", filepath.Join(nvimConfigDir, "init.lua"),
		"-c", "qall!")

	cmd.Dir(ctx.GetString("test_dir"))

	result := cmd.Run()
	ctx.ShowCommandOutput(cmd.String(), result.Stdout, result.Stderr)

	return nil
}

func executeGroveRunTestCommand() harness.Step {
	return harness.NewStep("execute :GroveRunTest command", func(ctx *harness.Context) error {
		nvimConfigDir := ctx.GetString("nvim_config_dir")

		cmd := command.New("nvim",
			"--headless",
			"-u", filepath.Join(nvimConfigDir, "init.lua"),
			"-c", "qall!")

		cmd.Dir(ctx.GetString("test_dir"))

		result := cmd.Run()
		ctx.ShowCommandOutput(cmd.String(), result.Stdout, result.Stderr)

		// Store result for verification
		ctx.Set("nvim_stdout", result.Stdout)
		ctx.Set("nvim_stderr", result.Stderr)

		// Neovim may exit with non-zero code even on success
		// We'll verify the actual behavior in the next step
		return nil
	})
}

func executeGroveRunTestCommandCustom() harness.Step {
	return harness.NewStep("execute :GroveRunTest command with custom config", func(ctx *harness.Context) error {
		return executeGroveRunTestCommand().Func(ctx)
	})
}

func executeGroveRunTestAndVerifyWarning() harness.Step {
	return harness.NewStep("execute :GroveRunTest and verify warning notification", func(ctx *harness.Context) error {
		nvimConfigDir := ctx.GetString("nvim_config_dir")

		cmd := command.New("nvim",
			"--headless",
			"-u", filepath.Join(nvimConfigDir, "init.lua"),
			"-c", "qall!")

		cmd.Dir(ctx.GetString("test_dir"))

		result := cmd.Run()
		ctx.ShowCommandOutput(cmd.String(), result.Stdout, result.Stderr)

		// Read the log file to verify the warning
		logFile := ctx.GetString("log_file")
		content, err := fs.ReadString(logFile)
		if err != nil {
			return fmt.Errorf("failed to read log file: %w", err)
		}

		expectedWarning := "No scenario name under cursor"
		if !strings.Contains(content, expectedWarning) {
			return fmt.Errorf("expected warning '%s' not found in log. Content:\n%s", expectedWarning, content)
		}

		return nil
	})
}

// Helper functions for verifying test output

func verifyCommandOutputInLog() harness.Step {
	return harness.NewStep("verify command output in log", func(ctx *harness.Context) error {
		logFile := ctx.GetString("log_file")
		content, err := fs.ReadString(logFile)
		if err != nil {
			return fmt.Errorf("failed to read log file: %w", err)
		}

		scenarioName := ctx.GetString("scenario_name")

		// Check for the command
		if !strings.Contains(content, "tend run --debug-session") {
			return fmt.Errorf("expected command 'tend run --debug-session' not found in log. Content:\n%s", content)
		}

		// Check that the scenario name appears WITHOUT quotes or trailing comma
		// This ensures quote stripping is working
		if strings.Contains(content, fmt.Sprintf(`"%s"`, scenarioName)) {
			return fmt.Errorf("scenario name should not have quotes in command. Found quoted version in log. Content:\n%s", content)
		}
		if strings.Contains(content, scenarioName+",") {
			return fmt.Errorf("scenario name should not have trailing comma in command. Content:\n%s", content)
		}
		if !strings.Contains(content, scenarioName) {
			return fmt.Errorf("scenario name '%s' not found in log. Content:\n%s", scenarioName, content)
		}

		return nil
	})
}

func verifyCustomCommandOutput() harness.Step {
	return harness.NewStep("verify custom command output", func(ctx *harness.Context) error {
		logFile := ctx.GetString("log_file")
		content, err := fs.ReadString(logFile)
		if err != nil {
			return fmt.Errorf("failed to read log file: %w", err)
		}

		scenarioName := ctx.GetString("scenario_name")

		// Check that the custom command was used (contains "CUSTOM:") and includes the scenario name
		if !strings.Contains(content, "CUSTOM:") || !strings.Contains(content, scenarioName) {
			return fmt.Errorf("expected custom command with 'CUSTOM:' and scenario '%s' not found in log. Content:\n%s", scenarioName, content)
		}

		return nil
	})
}

func verifyHyphenatedNameCommandOutput() harness.Step {
	return harness.NewStep("verify hyphenated name command output", func(ctx *harness.Context) error {
		logFile := ctx.GetString("log_file")
		content, err := fs.ReadString(logFile)
		if err != nil {
			return fmt.Errorf("failed to read log file: %w", err)
		}

		scenarioName := ctx.GetString("hyphenated_name")

		// Check for the scenario name in the command, allowing for quotes
		if !strings.Contains(content, "tend run --debug-session") || !strings.Contains(content, scenarioName) {
			return fmt.Errorf("expected command 'tend run --debug-session' with scenario '%s' not found in log for hyphenated name. Content:\n%s", scenarioName, content)
		}

		return nil
	})
}

func verifyUnderscoredNameCommandOutput() harness.Step {
	return harness.NewStep("verify underscored name command output", func(ctx *harness.Context) error {
		logFile := ctx.GetString("log_file")
		content, err := fs.ReadString(logFile)
		if err != nil {
			return fmt.Errorf("failed to read log file: %w", err)
		}

		scenarioName := ctx.GetString("underscored_name")

		// Check for the scenario name in the command, allowing for quotes
		if !strings.Contains(content, "tend run --debug-session") || !strings.Contains(content, scenarioName) {
			return fmt.Errorf("expected command 'tend run --debug-session' with scenario '%s' not found in log for underscored name. Content:\n%s", scenarioName, content)
		}

		return nil
	})
}

// Utility functions

func setupDefaultNvimConfig(ctx *harness.Context) string {
	nvimConfigDir := filepath.Join(ctx.RootDir, "nvim_config")
	fs.CreateDir(nvimConfigDir)
	return nvimConfigDir
}
