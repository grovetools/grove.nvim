package main

import (
	"fmt"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/grovetools/tend/pkg/fs"
	"github.com/grovetools/tend/pkg/harness"
	"github.com/grovetools/tend/pkg/tui"
)

// LaunchTestUnderCursorTUI tests the feature using TUI interaction (treating Neovim as a TUI).
// This is a thought experiment showing how we can drive Neovim like any other TUI application
// using tend's TUI testing framework instead of headless mode.
func LaunchTestUnderCursorTUI() *harness.Scenario {
	return &harness.Scenario{
		Name:        "launch-test-under-cursor-tui",
		Description: "Verifies test launching using TUI interactions with Neovim",
		Tags:        []string{"tend", "runner", "tui", "experimental"},
		Steps: []harness.Step{
			setupNvimTUIEnvironment(),
			launchNvimTUI(),
			openTestFileInTUI(),
			positionCursorOnScenarioName(),
			executeGroveRunTestViaTUI(),
			verifyFloatingWindowAppears(),
			closeFloatingWindow(),
			quitNvim(),
		},
	}
}

func setupNvimTUIEnvironment() harness.Step {
	return harness.NewStep("setup nvim TUI environment", func(ctx *harness.Context) error {
		// Create a test directory with a Go test file
		testDir := filepath.Join(ctx.RootDir, "test_project")
		if err := fs.CreateDir(testDir); err != nil {
			return err
		}

		// Create a test file with a scenario name that we'll interact with
		testContent := `package main

import (
	"github.com/grovetools/tend/pkg/harness"
)

// This is a test scenario we'll launch from Neovim
func ExampleScenario() *harness.Scenario {
	return &harness.Scenario{
		Name:        "example-test-scenario",
		Description: "An example test",
		Tags:        []string{"example"},
		Steps:       []harness.Step{},
	}
}
`
		testFilePath := filepath.Join(testDir, "example_test.go")
		if err := fs.WriteString(testFilePath, testContent); err != nil {
			return err
		}

		// Get absolute path to the grove-nvim plugin
		projectRoot, err := filepath.Abs(".")
		if err != nil {
			return err
		}

		// Create a minimal init.lua for Neovim
		nvimConfigDir := filepath.Join(ctx.RootDir, "nvim_config")
		if err := fs.CreateDir(nvimConfigDir); err != nil {
			return err
		}

		initLuaContent := fmt.Sprintf(`
-- Minimal Neovim config for TUI testing
vim.opt.number = true
vim.opt.relativenumber = false

-- Load the grove-nvim plugin
vim.opt.runtimepath:prepend('%s')
vim.cmd('runtime! plugin/grove.lua')

-- Disable swap files for cleaner testing
vim.opt.swapfile = false

-- Set a simple status line to see what's happening
vim.opt.laststatus = 2
vim.opt.statusline = '%%f %%m'
`, projectRoot)

		if err := fs.WriteString(filepath.Join(nvimConfigDir, "init.lua"), initLuaContent); err != nil {
			return err
		}

		// Store paths in context
		ctx.Set("test_file_path", testFilePath)
		ctx.Set("test_dir", testDir)
		ctx.Set("nvim_config_dir", nvimConfigDir)

		return nil
	})
}

func launchNvimTUI() harness.Step {
	return harness.NewStep("launch nvim TUI", func(ctx *harness.Context) error {
		testFilePath := ctx.GetString("test_file_path")
		nvimConfigDir := ctx.GetString("nvim_config_dir")

		// Find nvim in PATH
		nvimPath, err := exec.LookPath("nvim")
		if err != nil {
			return fmt.Errorf("nvim not found in PATH: %w", err)
		}

		// Launch Neovim as a TUI application
		session, err := ctx.StartTUI(nvimPath, []string{
			"-u", filepath.Join(nvimConfigDir, "init.lua"),
			testFilePath,
		})
		if err != nil {
			return err
		}

		// Store the TUI session for later steps
		ctx.Set("nvim_session", session)

		// Wait a bit for Neovim to fully load and render
		// Neovim needs time to initialize, load the plugin, and render the file
		time.Sleep(2 * time.Second)

		// Verify Neovim loaded by checking if we see any content
		content, err := session.Capture()
		if err != nil {
			return fmt.Errorf("failed to capture nvim TUI: %w", err)
		}

		// Neovim should show something - either the file content or at least the UI
		if len(content) < 10 {
			return fmt.Errorf("nvim TUI appears empty (only %d chars). Content:\n%s", len(content), content)
		}

		return nil
	})
}

func openTestFileInTUI() harness.Step {
	return harness.NewStep("verify test file is open in TUI", func(ctx *harness.Context) error {
		session := ctx.Get("nvim_session").(*tui.Session)

		// Capture the TUI state
		content, err := session.Capture()
		if err != nil {
			return err
		}

		// Verify the test file content is visible
		if !containsAll(content, []string{
			"ExampleScenario",
			"example-test-scenario",
			"harness.Scenario",
		}) {
			return fmt.Errorf("test file content not visible in TUI. Content:\n%s", content)
		}

		return nil
	})
}

func positionCursorOnScenarioName() harness.Step {
	return harness.NewStep("position cursor on scenario name", func(ctx *harness.Context) error {
		session := ctx.Get("nvim_session").(*tui.Session)

		// Use Vim's search command to find and position cursor on the scenario name
		// In Vim, we can use / to search
		if err := session.SendKeys("/"); err != nil {
			return err
		}
		time.Sleep(100 * time.Millisecond)

		// Type the search pattern for the quoted scenario name
		if err := session.SendKeys(`"example-test-scenario"`); err != nil {
			return err
		}
		time.Sleep(100 * time.Millisecond)

		// Press Enter to execute the search
		if err := session.SendKeys("Enter"); err != nil {
			return err
		}
		time.Sleep(100 * time.Millisecond)

		// Verify cursor is positioned (we should see search highlight or cursor on the line)
		content, err := session.Capture()
		if err != nil {
			return err
		}

		// In Neovim, after search, the cursor should be on the found text
		// We can verify by checking the content still shows the scenario name
		if !containsText(content, "example-test-scenario") {
			return fmt.Errorf("cursor not positioned on scenario name. Content:\n%s", content)
		}

		return nil
	})
}

func executeGroveRunTestViaTUI() harness.Step {
	return harness.NewStep("execute GroveRunTest via TUI keymap", func(ctx *harness.Context) error {
		session := ctx.Get("nvim_session").(*tui.Session)

		// Execute the GroveRunTest command via the keymap <leader>ftr
		// Default leader in Vim is \, so we send \ followed by ftr
		// First, press Escape to ensure we're in normal mode
		if err := session.SendKeys("Escape"); err != nil {
			return err
		}
		time.Sleep(100 * time.Millisecond)

		// Now send the leader key sequence: <leader>ftr
		// Note: We can also use :GroveRunTest command instead
		if err := session.SendKeys(":"); err != nil {
			return err
		}
		time.Sleep(50 * time.Millisecond)

		if err := session.SendKeys("GroveRunTest"); err != nil {
			return err
		}
		time.Sleep(50 * time.Millisecond)

		if err := session.SendKeys("Enter"); err != nil {
			return err
		}

		// Wait a bit for the command to execute
		time.Sleep(500 * time.Millisecond)

		return nil
	})
}

func verifyFloatingWindowAppears() harness.Step {
	return harness.NewStep("verify floating terminal window appears", func(ctx *harness.Context) error {
		session := ctx.Get("nvim_session").(*tui.Session)

		// After executing GroveRunTest, a floating terminal should appear
		// We should see:
		// 1. The Grove Output window
		// 2. A message about pressing a key to close
		content, err := session.Capture()
		if err != nil {
			return err
		}

		// Check for expected content in the floating window
		// Note: ANSI codes make exact matching hard, so we check for key indicators
		expectedTexts := []string{
			"Grove Output",          // The floating window title
			"tend run",               // Part of the command
			"Press any key to close", // The prompt to close
		}

		for _, text := range expectedTexts {
			if !containsText(content, text) {
				return fmt.Errorf("expected text '%s' not found in floating window. Content:\n%s", text, content)
			}
		}

		// Also verify we see EITHER the full scenario name OR that tend ran
		// (might be truncated in the display due to ANSI codes)
		if !containsText(content, "example-test") && !containsText(content, "debug-session") {
			return fmt.Errorf("neither scenario name nor debug-session flag found in output. Content:\n%s", content)
		}

		return nil
	})
}

func closeFloatingWindow() harness.Step {
	return harness.NewStep("close floating terminal window", func(ctx *harness.Context) error {
		session := ctx.Get("nvim_session").(*tui.Session)

		// Press any key to close the floating window
		if err := session.SendKeys("q"); err != nil {
			return err
		}
		time.Sleep(200 * time.Millisecond)

		// Verify we're back to the normal editor view
		content, err := session.Capture()
		if err != nil {
			return err
		}

		// We should see the original test file content again
		if !containsText(content, "ExampleScenario") {
			return fmt.Errorf("did not return to editor after closing window. Content:\n%s", content)
		}

		return nil
	})
}

func quitNvim() harness.Step {
	return harness.NewStep("quit nvim", func(ctx *harness.Context) error {
		session := ctx.Get("nvim_session").(*tui.Session)

		// Quit Neovim with :q!
		if err := session.SendKeys(":"); err != nil {
			return err
		}
		time.Sleep(50 * time.Millisecond)

		if err := session.SendKeys("q!"); err != nil {
			return err
		}
		time.Sleep(50 * time.Millisecond)

		if err := session.SendKeys("Enter"); err != nil {
			return err
		}

		// Wait for Neovim to exit
		time.Sleep(200 * time.Millisecond)

		return nil
	})
}

// Helper function to check if content contains all expected strings
func containsAll(content string, expectedTexts []string) bool {
	for _, text := range expectedTexts {
		if !containsText(content, text) {
			return false
		}
	}
	return true
}

// Helper function to check if content contains a specific string
func containsText(content, text string) bool {
	return len(content) > 0 && len(text) > 0 &&
		(content == text ||
		 len(content) >= len(text) &&
		 findSubstring(content, text))
}

// Simple substring search
func findSubstring(haystack, needle string) bool {
	if len(needle) == 0 {
		return true
	}
	if len(haystack) < len(needle) {
		return false
	}
	for i := 0; i <= len(haystack)-len(needle); i++ {
		if haystack[i:i+len(needle)] == needle {
			return true
		}
	}
	return false
}
