package cmd

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/grovetools/core/logging"
	"github.com/grovetools/core/pkg/daemon"
	"github.com/grovetools/core/pkg/models"
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

			// Try to submit via daemon first. The daemon path is fire-and-forget.
			// This is ideal for the Neovim silent mode.
			if err := submitViaDaemon(ctx, filePath); err != nil {
				chatLog.Debug("Daemon submission failed, falling back to flow run").
					Err(err).
					Log(ctx)
			} else {
				return nil
			}

			// Fallback: run via flow CLI subprocess
			if _, err := exec.LookPath("flow"); err != nil {
				chatLog.Error("'flow' command not found in PATH").
					Err(err).
					Log(ctx)
				return fmt.Errorf("'flow' command not found in PATH. Please ensure the grove-flow binary is installed and accessible")
			}

			// #nosec G204 -- filePath comes from validated user input
			flowCmd := delegation.Command("flow", "run", filePath)

			chatLog.Debug("Executing flow run").
				Field("command", "flow").
				Field("file_path", filePath).
				Log(ctx)

			flowCmd.Stdout = os.Stdout
			flowCmd.Stderr = os.Stderr
			flowCmd.Stdin = os.Stdin

			err := flowCmd.Run()
			if err != nil {
				chatLog.Error("grove flow run command failed").
					Err(err).
					Field("file_path", filePath).
					Log(ctx)
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

// submitViaDaemon submits a job to the grove daemon's job runner.
// The daemon handles execution in the background — this returns immediately.
func submitViaDaemon(ctx context.Context, filePath string) error {
	client := daemon.New()
	defer func() { _ = client.Close() }()

	if !client.IsRunning() {
		return fmt.Errorf("daemon is not running")
	}

	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return fmt.Errorf("resolve path: %w", err)
	}

	planDir := filepath.Dir(absPath)
	jobFile := filepath.Base(absPath)

	info, err := client.SubmitJob(ctx, models.JobSubmitRequest{
		PlanDir: planDir,
		JobFile: jobFile,
	})
	if err != nil {
		return fmt.Errorf("submit job: %w", err)
	}

	chatLog.Info("Job submitted to daemon").
		Field("job_id", info.ID).
		Field("status", info.Status).
		Field("plan_dir", planDir).
		Field("job_file", jobFile).
		Log(ctx)

	fmt.Fprintf(os.Stderr, "Job submitted to daemon: %s (status: %s)\n", info.ID, info.Status)
	return nil
}
