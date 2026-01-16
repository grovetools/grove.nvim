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

// TextInteractionSimpleScenario tests the text interaction feature using the real binary.
func TextInteractionSimpleScenario() *harness.Scenario {
	return &harness.Scenario{
		Name:        "text-interaction-simple",
		Description: "Tests text selection and question asking feature with real binary",
		Tags:        []string{"text", "simple"},
		Steps: []harness.Step{
			setupSimpleEnvironment(),
			testRealBinaryHappyPath(),
			testRealBinaryErrorHandling(),
		},
	}
}

func setupSimpleEnvironment() harness.Step {
	return harness.NewStep("setup simple test environment", func(ctx *harness.Context) error {
		// Create test project directory
		testProjectDir := filepath.Join(ctx.RootDir, "test_project")
		if err := fs.CreateDir(testProjectDir); err != nil {
			return err
		}

		// Create test files
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
		ctx.Set("chat_md_path", chatMdPath)
		ctx.Set("test_project_dir", testProjectDir)

		return nil
	})
}

func testRealBinaryHappyPath() harness.Step {
	return harness.NewStep("test with real neogrove binary", func(ctx *harness.Context) error {
		chatMdPath := ctx.Get("chat_md_path").(string)
		
		// Find the real neogrove binary
		neogroveBinary, err := FindBinary()
		if err != nil {
			return err
		}

		// 1. Append a code snippet using the real binary
		snippet := `func main() {
	fmt.Println("Hello, World!")
}`
		selectCmd := command.New(neogroveBinary, "text", "select", "--file", chatMdPath, "--lang", "go")
		selectCmd.Stdin(strings.NewReader(snippet))
		selectResult := selectCmd.Run()
		if selectResult.ExitCode != 0 {
			return fmt.Errorf("failed to append selection: %s", selectResult.Stderr)
		}

		// 2. Append a question
		question := "What does this main function do?"
		askCmd := command.New(neogroveBinary, "text", "ask", "--file", chatMdPath, question)
		askResult := askCmd.Run()
		if askResult.ExitCode != 0 {
			return fmt.Errorf("failed to append question: %s", askResult.Stderr)
		}

		// 3. Verify the file contents
		content, err := os.ReadFile(chatMdPath)
		if err != nil {
			return fmt.Errorf("failed to read chat file: %w", err)
		}

		// Check for the code snippet
		if !strings.Contains(string(content), "```go") {
			return fmt.Errorf("chat file does not contain Go code block")
		}

		if !strings.Contains(string(content), "func main()") {
			return fmt.Errorf("chat file does not contain main function")
		}

		if !strings.Contains(string(content), question) {
			return fmt.Errorf("chat file does not contain the question")
		}

		return nil
	})
}

func testRealBinaryErrorHandling() harness.Step {
	return harness.NewStep("test error handling with real binary", func(ctx *harness.Context) error {
		neogroveBinary, err := FindBinary()
		if err != nil {
			return err
		}

		// Test missing required flag
		selectCmd := command.New(neogroveBinary, "text", "select", "--lang", "go")
		selectCmd.Stdin(strings.NewReader("some code"))
		selectResult := selectCmd.Run()
		
		if selectResult.ExitCode == 0 {
			return fmt.Errorf("expected command to fail without --file flag, but it succeeded")
		}
		
		if !strings.Contains(selectResult.Stderr, "required flag(s) \"file\" not set") {
			return fmt.Errorf("expected error about missing file flag, got: %s", selectResult.Stderr)
		}

		return nil
	})
}