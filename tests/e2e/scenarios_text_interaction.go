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

// TextInteractionScenario tests the text interaction feature.
func TextInteractionScenario() *harness.Scenario {
	return &harness.Scenario{
		Name:        "text-interaction",
		Description: "Tests text selection and question asking feature",
		Tags:        []string{"nvim", "text", "e2e"},
		Steps: []harness.Step{
			setupTextInteractionEnvironment(),
			testTextSelectionHappyPath(),
			testTextSelectionNoTargetFile(),
		},
	}
}

// setupTextInteractionEnvironment creates the test environment.
func setupTextInteractionEnvironment() harness.Step {
	return harness.NewStep("setup text interaction environment", func(ctx *harness.Context) error {
		// Create directory structure
		mockBinDir := filepath.Join(ctx.RootDir, "mock_bin")
		nvimConfigDir := filepath.Join(ctx.RootDir, "nvim_config")
		testProjectDir := filepath.Join(ctx.RootDir, "test_project")
		for _, dir := range []string{mockBinDir, nvimConfigDir, testProjectDir} {
			if err := fs.CreateDir(dir); err != nil {
				return err
			}
		}

		// Create a test Go file
		mainGoPath := filepath.Join(testProjectDir, "main.go")
		mainGoContent := `package main

import "fmt"

func main() {
	fmt.Println("Hello, World!")
}
`
		if err := fs.WriteString(mainGoPath, mainGoContent); err != nil {
			return err
		}

		// Create an initial chat file
		chatMdPath := filepath.Join(testProjectDir, "chat.md")
		chatMdContent := `---
id: e2e-test
---
# E2E Test Chat
`
		if err := fs.WriteString(chatMdPath, chatMdContent); err != nil {
			return err
		}

		// Store paths in context
		ctx.Set("main_go_path", mainGoPath)
		ctx.Set("chat_md_path", chatMdPath)
		ctx.Set("test_project_dir", testProjectDir)
		ctx.Set("nvim_config_dir", nvimConfigDir)

		// Create minimal Neovim config
		initVimPath := filepath.Join(nvimConfigDir, "init.vim")
		initVimContent := fmt.Sprintf(`
set runtimepath^=%s
let g:grove_mock_bin_dir = '%s'
`, ctx.RootDir, mockBinDir)
		if err := fs.WriteString(initVimPath, initVimContent); err != nil {
			return err
		}

		// Find the grove-nvim binary
		groveNvimBinary, err := FindBinary()
		if err != nil {
			return err
		}

		// Copy grove-nvim to mock bin
		mockGroveNvimPath := filepath.Join(mockBinDir, "grove-nvim")
		cpCmd := command.New("cp", groveNvimBinary, mockGroveNvimPath)
		cpResult := cpCmd.Run()
		if cpResult.ExitCode != 0 {
			return fmt.Errorf("failed to copy grove-nvim: %s", cpResult.Stderr)
		}

		// Update PATH to include mock bin
		os.Setenv("PATH", mockBinDir+":"+os.Getenv("PATH"))

		return nil
	})
}

// testTextSelectionHappyPath tests the full workflow.
func testTextSelectionHappyPath() harness.Step {
	return harness.NewStep("test text selection happy path", func(ctx *harness.Context) error {
		chatMdPath := ctx.Get("chat_md_path").(string)
		testProjectDir := ctx.Get("test_project_dir").(string)

		// For this test, we'll simulate the workflow by directly calling the grove-nvim commands
		// since automating visual selection and UI input in headless Neovim is complex

		// 1. Append a code snippet
		snippet := `func main() {
	fmt.Println("Hello, World!")
}`
		selectCmd := command.New(filepath.Join(testProjectDir, "..", "mock_bin", "grove-nvim"),
			"text", "select", "--file", chatMdPath, "--lang", "go")
		selectCmd.Stdin(strings.NewReader(snippet))
		selectResult := selectCmd.Run()
		if selectResult.ExitCode != 0 {
			return fmt.Errorf("failed to append selection: %s", selectResult.Stderr)
		}

		// 2. Append a question
		question := "What does this main function do?"
		askCmd := command.New(filepath.Join(testProjectDir, "..", "mock_bin", "grove-nvim"),
			"text", "ask", "--file", chatMdPath, question)
		askResult := askCmd.Run()
		if askResult.ExitCode != 0 {
			return fmt.Errorf("failed to append question: %s", askResult.Stderr)
		}

		// Read and verify the chat file
		content, err := os.ReadFile(chatMdPath)
		if err != nil {
			return fmt.Errorf("failed to read chat file: %w", err)
		}

		// Check for the code snippet
		if !strings.Contains(string(content), "```go") {
			return fmt.Errorf("chat file does not contain Go code block")
		}

		// Check for the main function
		if !strings.Contains(string(content), "func main()") {
			return fmt.Errorf("chat file does not contain main function")
		}

		// Check for the question
		if !strings.Contains(string(content), "What does this main function do?") {
			return fmt.Errorf("chat file does not contain the question")
		}

		return nil
	})
}

// testTextSelectionNoTargetFile tests error handling.
func testTextSelectionNoTargetFile() harness.Step {
	return harness.NewStep("test text selection with missing file", func(ctx *harness.Context) error {
		testProjectDir := ctx.Get("test_project_dir").(string)

		// Test that the command fails when required --file flag is missing
		selectCmd := command.New(filepath.Join(testProjectDir, "..", "mock_bin", "grove-nvim"),
			"text", "select", "--lang", "go")
		selectCmd.Stdin(strings.NewReader("some code"))
		selectResult := selectCmd.Run()
		
		// Should fail due to missing --file flag
		if selectResult.ExitCode == 0 {
			return fmt.Errorf("expected command to fail without --file flag, but it succeeded")
		}
		
		if !strings.Contains(selectResult.Stderr, "required flag(s) \"file\" not set") {
			return fmt.Errorf("expected error about missing file flag, got: %s", selectResult.Stderr)
		}

		return nil
	})
}