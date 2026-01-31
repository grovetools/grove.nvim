package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/grovetools/core/util/delegation"
	"github.com/spf13/cobra"
)

// newPlanCmd creates the main `plan` command and adds its subcommands.
func newPlanCmd() *cobra.Command {
	planCmd := &cobra.Command{
		Use:   "plan",
		Short: "Interact with grove-flow plans",
		Long:  "A wrapper for 'flow plan' commands, for use by the Neovim plugin.",
	}

	planCmd.AddCommand(newPlanInitCmd())
	planCmd.AddCommand(newPlanListCmd())
	planCmd.AddCommand(newPlanStatusCmd())
	planCmd.AddCommand(newPlanAddCmd())
	planCmd.AddCommand(newPlanRunCmd())
	planCmd.AddCommand(newPlanTemplateListCmd())
	planCmd.AddCommand(newPlanConfigCmd())

	return planCmd
}

// runFlowCommand is a helper to execute `flow` with the given arguments.
func runFlowCommand(args ...string) error {
	if _, err := exec.LookPath("flow"); err != nil {
		return fmt.Errorf("'flow' command not found in PATH. Please ensure the grove-flow binary is installed and accessible")
	}

	cmdArgs := append([]string{"flow"}, args...)
	flowCmd := delegation.Command(cmdArgs[0], cmdArgs[1:]...)
	flowCmd.Stdout = os.Stdout
	flowCmd.Stderr = os.Stderr
	flowCmd.Stdin = os.Stdin

	if err := flowCmd.Run(); err != nil {
		return fmt.Errorf("flow command failed")
	}
	return nil
}

// newPlanInitCmd wraps `flow plan init`.
// Most flags are removed as the interactive TUI handles them.
// Keep extract-all-from for the :GrovePlanExtract command.
func newPlanInitCmd() *cobra.Command {
	var extractAllFrom string

	cmd := &cobra.Command{
		Use:   "init [directory-name]",
		Short: "Initialize a new plan directory using an interactive wizard",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			flowArgs := []string{"plan", "init"}
			if len(args) > 0 {
				flowArgs = append(flowArgs, args[0])
			}

			if extractAllFrom != "" {
				flowArgs = append(flowArgs, "--extract-all-from", extractAllFrom)
			}

			// All other options are handled by the `flow plan init` TUI.
			return runFlowCommand(flowArgs...)
		},
	}

	cmd.Flags().StringVar(&extractAllFrom, "extract-all-from", "", "Path to a markdown file to extract all content from into an initial job")

	return cmd
}

// newPlanListCmd wraps `flow plan list`.
func newPlanListCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "List all available plans",
		Long:  "Passes any extra flags (like --json) directly to 'flow plan list'.",
		RunE: func(cmd *cobra.Command, args []string) error {
			// Construct args: `plan list` followed by any flags passed to grove-nvim.
			// We find the 'list' command in os.Args and take everything after it.
			flowArgs := []string{"plan", "list"}
			found := false
			for _, arg := range os.Args {
				if found {
					flowArgs = append(flowArgs, arg)
				}
				if arg == "list" {
					found = true
				}
			}
			return runFlowCommand(flowArgs...)
		},
	}
}

// newPlanStatusCmd wraps `flow plan status`.
func newPlanStatusCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "status <plan-name-or-directory>",
		Short: "Show the status of a plan",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			// Build flow command with plan name
			flowArgs := []string{"plan", "status", args[0]}

			// Pass through any additional flags
			found := false
			for _, arg := range os.Args {
				if found && strings.HasPrefix(arg, "-") {
					flowArgs = append(flowArgs, arg)
				}
				if arg == "status" {
					found = true
				}
			}

			return runFlowCommand(flowArgs...)
		},
	}
}

// newPlanAddCmd wraps `flow plan add`.
// All flags are removed as the interactive TUI handles job creation.
func newPlanAddCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "add <plan-name-or-directory>",
		Short: "Add a new job to a plan using an interactive wizard",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			planDir := args[0]
			// The `-i` flag launches the interactive TUI in `flow`.
			flowArgs := []string{"plan", "add", planDir, "-i"}

			return runFlowCommand(flowArgs...)
		},
	}

	return cmd
}

// newPlanRunCmd wraps `flow plan run`.
func newPlanRunCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "run <plan-name-or-directory>",
		Short: "Run a plan",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return runFlowCommand("plan", "run", args[0])
		},
	}
}

// newPlanTemplateListCmd wraps `flow plan templates list`.
func newPlanTemplateListCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "template-list",
		Short: "List available job templates",
		RunE: func(cmd *cobra.Command, args []string) error {
			// Pass through any flags
			flowArgs := []string{"plan", "templates", "list"}
			found := false
			for _, arg := range os.Args {
				if found {
					flowArgs = append(flowArgs, arg)
				}
				if arg == "template-list" {
					found = true
				}
			}
			return runFlowCommand(flowArgs...)
		},
	}
}
