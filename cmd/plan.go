package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

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

	return planCmd
}

// runFlowCommand is a helper to execute `flow` with the given arguments.
func runFlowCommand(args ...string) error {
	if _, err := exec.LookPath("flow"); err != nil {
		return fmt.Errorf("'flow' command not found in PATH. Please ensure the grove-flow binary is installed and accessible")
	}

	flowCmd := exec.Command("flow", args...)
	flowCmd.Stdout = os.Stdout
	flowCmd.Stderr = os.Stderr
	flowCmd.Stdin = os.Stdin

	if err := flowCmd.Run(); err != nil {
		return fmt.Errorf("flow command failed")
	}
	return nil
}

// newPlanInitCmd wraps `flow plan init`.
func newPlanInitCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "init <directory-name>",
		Short: "Initialize a new plan directory",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return runFlowCommand("plan", "init", args[0])
		},
	}
}

// newPlanListCmd wraps `flow plan list`.
func newPlanListCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "List all available plans",
		Long:  "Passes any extra flags (like --json) directly to 'flow plan list'.",
		RunE: func(cmd *cobra.Command, args []string) error {
			// Construct args: `plan list` followed by any flags passed to neogrove.
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
func newPlanAddCmd() *cobra.Command {
	var (
		title       string
		jobType     string
		prompt      string
		promptFile  string
		template    string
		sourceFiles []string
		dependsOn   []string
	)

	cmd := &cobra.Command{
		Use:   "add <plan-name-or-directory>",
		Short: "Add a new job to a plan",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			planDir := args[0]
			flowArgs := []string{"plan", "add", planDir}

			if title != "" {
				flowArgs = append(flowArgs, "--title", title)
			}
			if jobType != "" {
				flowArgs = append(flowArgs, "--type", jobType)
			}
			if prompt != "" {
				flowArgs = append(flowArgs, "--prompt", prompt)
			}
			if promptFile != "" {
				flowArgs = append(flowArgs, "--prompt-file", promptFile)
			}
			if template != "" {
				flowArgs = append(flowArgs, "--template", template)
			}
			if len(sourceFiles) > 0 {
				flowArgs = append(flowArgs, "--source-files", strings.Join(sourceFiles, ","))
			}
			for _, dep := range dependsOn {
				flowArgs = append(flowArgs, "--depends-on", dep)
			}

			return runFlowCommand(flowArgs...)
		},
	}

	cmd.Flags().StringVar(&title, "title", "", "Job title")
	cmd.Flags().StringVar(&jobType, "type", "agent", "Job type (agent, oneshot, shell, etc.)")
	cmd.Flags().StringVarP(&prompt, "prompt", "p", "", "Inline prompt text")
	cmd.Flags().StringVarP(&promptFile, "prompt-file", "f", "", "File containing the prompt")
	cmd.Flags().StringVar(&template, "template", "", "Name of the job template to use")
	cmd.Flags().StringSliceVar(&sourceFiles, "source-files", nil, "Comma-separated list of source files for reference-based prompts")
	cmd.Flags().StringSliceVarP(&dependsOn, "depends-on", "d", nil, "Dependencies (job filenames)")

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
