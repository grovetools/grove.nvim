package cmd

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestTextSelectCmd(t *testing.T) {
	// Create a temporary file to act as the target
	tempDir := t.TempDir()
	targetFile := filepath.Join(tempDir, "test.md")

	// The code snippet to be "selected"
	snippet := `func main() {
	fmt.Println("Hello")
}`
	language := "go"

	// Simulate running the command
	var out bytes.Buffer
	rootCmd.SetOut(&out)
	rootCmd.SetErr(&out)
	rootCmd.SetArgs([]string{"text", "select", "--file", targetFile, "--lang", language})

	// Pipe the snippet to the command's stdin
	oldStdin := os.Stdin
	defer func() { os.Stdin = oldStdin }()
	r, w, _ := os.Pipe()
	os.Stdin = r
	_, _ = w.WriteString(snippet)
	_ = w.Close()

	// Execute
	err := rootCmd.Execute()
	require.NoError(t, err)

	// Verify the file content
	content, err := os.ReadFile(targetFile)
	require.NoError(t, err)

	expectedContent := "```go\n" + snippet + "\n```"
	assert.Contains(t, string(content), expectedContent)
}

func TestTextAskCmd(t *testing.T) {
	// Create a temporary file to act as the target
	tempDir := t.TempDir()
	targetFile := filepath.Join(tempDir, "test.md")
	// Pre-populate the file
	initialContent := "# My Chat\n"
	err := os.WriteFile(targetFile, []byte(initialContent), 0644)
	require.NoError(t, err)


	question := "What does this function do?"

	// Simulate running the command
	var out bytes.Buffer
	rootCmd.SetOut(&out)
	rootCmd.SetErr(&out)
	rootCmd.SetArgs([]string{"text", "ask", "--file", targetFile, question})

	// Execute
	err = rootCmd.Execute()
	require.NoError(t, err)

	// Verify the file content
	content, err := os.ReadFile(targetFile)
	require.NoError(t, err)

	expectedContent := initialContent + "\n\n" + question + "\n"
	assert.Equal(t, expectedContent, string(content))
}

func TestTextAskCmd_Stdin(t *testing.T) {
	tempDir := t.TempDir()
	targetFile := filepath.Join(tempDir, "test.md")
	question := "What about via stdin?"

	var out bytes.Buffer
	rootCmd.SetOut(&out)
	rootCmd.SetErr(&out)
	rootCmd.SetArgs([]string{"text", "ask", "--file", targetFile})

	// Pipe the question to the command's stdin
	oldStdin := os.Stdin
	defer func() { os.Stdin = oldStdin }()
	r, w, _ := os.Pipe()
	os.Stdin = r
	_, _ = w.WriteString(question)
	_ = w.Close()

	err := rootCmd.Execute()
	require.NoError(t, err)

	content, err := os.ReadFile(targetFile)
	require.NoError(t, err)
	assert.Contains(t, string(content), question)
}