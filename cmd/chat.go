package cmd

import (
	"context"
	"fmt"
	"os"
	"os/exec"

	"github.com/grovetools/core/logging"
	"github.com/grovetools/core/util/delegation"
	"github.com/spf13/cobra"
)

var chatLog = logging.NewUnifiedLogger("grove-nvim.chat")

func newChatCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "chat [file_path]",
		Short: "Run 'flow run' on the specified file",
		Long:  "A helper command for the Neovim plugin to execute 'flow run' on the currently open note.",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := context.Background()
			filePath := args[0]

			chatLog.Debug("Starting chat run").
				Field("file_path", filePath).
				Log(ctx)

			// Verify the 'flow' command exists
			if _, err := exec.LookPath("flow"); err != nil {
				chatLog.Error("'flow' command not found in PATH").
					Err(err).
					Log(ctx)
				return fmt.Errorf("'flow' command not found in PATH. Please ensure the grove-flow binary is installed and accessible")
			}

			// Construct the command to run: `flow run <file_path>`
			// #nosec G204 -- filePath comes from validated user input
			flowCmd := delegation.Command("flow", "run", filePath)

			chatLog.Debug("Executing flow run").
				Field("command", "flow").
				Field("file_path", filePath).
				Log(ctx)

			// Pipe the stdout and stderr directly to the parent process (Neovim)
			// This allows Neovim's terminal to display the output in real-time.
			flowCmd.Stdout = os.Stdout
			flowCmd.Stderr = os.Stderr
			flowCmd.Stdin = os.Stdin // Pipe stdin for any potential interactivity

			// Run the command
			err := flowCmd.Run()
			if err != nil {
				chatLog.Error("grove flow run command failed").
					Err(err).
					Field("file_path", filePath).
					Log(ctx)
				// The error message from the command will be printed to stderr,
				// so we just need to return an error to indicate failure.
				return fmt.Errorf("flow command failed: %w", err)
			}

			chatLog.Debug("Chat run completed successfully").
				Field("file_path", filePath).
				Log(ctx)

			return nil
		},
	}
	return cmd
}
