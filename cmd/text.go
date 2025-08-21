package cmd

import (
	"fmt"
	"io"
	"os"

	"github.com/spf13/cobra"
)

func newTextCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "text",
		Short: "Interact with text selections from Neovim",
		Long:  "Provides subcommands for handling visually selected text and questions.",
	}
	cmd.AddCommand(newTextSelectCmd())
	cmd.AddCommand(newTextAskCmd())
	return cmd
}

func newTextSelectCmd() *cobra.Command {
	var (
		targetFile string
		language   string
	)

	cmd := &cobra.Command{
		Use:   "select",
		Short: "Append a selected code block to a target file",
		Long:  "Reads text from stdin and appends it as a formatted code block to the specified target markdown file.",
		RunE: func(cmd *cobra.Command, args []string) error {
			if targetFile == "" {
				return fmt.Errorf("target file must be specified with --file")
			}

			// Read text from stdin
			stdin, err := io.ReadAll(os.Stdin)
			if err != nil {
				return fmt.Errorf("failed to read from stdin: %w", err)
			}
			codeBlock := string(stdin)

			// Open the target file for appending
			f, err := os.OpenFile(targetFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
			if err != nil {
				return fmt.Errorf("failed to open target file %s: %w", targetFile, err)
			}
			defer f.Close()

			// Write the formatted code block
			// Use two newlines to ensure separation from previous content
			formattedSnippet := fmt.Sprintf("\n\n```%s\n%s\n```\n", language, codeBlock)
			if _, err := f.WriteString(formattedSnippet); err != nil {
				return fmt.Errorf("failed to write to target file: %w", err)
			}

			fmt.Fprintf(os.Stderr, "Appended selection to %s\n", targetFile)
			return nil
		},
	}

	cmd.Flags().StringVarP(&targetFile, "file", "f", "", "Target markdown file to append to (required)")
	cmd.Flags().StringVarP(&language, "lang", "l", "", "Language of the code snippet (e.g., go, lua)")
	_ = cmd.MarkFlagRequired("file")

	return cmd
}

func newTextAskCmd() *cobra.Command {
	var targetFile string

	cmd := &cobra.Command{
		Use:   "ask [question]",
		Short: "Append a question to the target file",
		Long:  "Reads a question from stdin or args and appends it to the target file.",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if targetFile == "" {
				return fmt.Errorf("target file must be specified with --file")
			}

			var question string
			if len(args) > 0 {
				question = args[0]
			} else {
				// Read question from stdin
				stdin, err := io.ReadAll(os.Stdin)
				if err != nil {
					return fmt.Errorf("failed to read from stdin: %w", err)
				}
				question = string(stdin)
			}

			// Open the target file for appending
			f, err := os.OpenFile(targetFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
			if err != nil {
				return fmt.Errorf("failed to open target file %s: %w", targetFile, err)
			}
			defer f.Close()

			// Append the question
			// Use two newlines to ensure separation
			formattedQuestion := fmt.Sprintf("\n\n%s\n", question)
			if _, err := f.WriteString(formattedQuestion); err != nil {
				return fmt.Errorf("failed to write question to target file: %w", err)
			}
			fmt.Fprintf(os.Stderr, "Appended question to %s\n", targetFile)

			return nil
		},
	}

	cmd.Flags().StringVarP(&targetFile, "file", "f", "", "Target markdown file to append to (required)")
	_ = cmd.MarkFlagRequired("file")

	return cmd
}