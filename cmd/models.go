package cmd

import (
	"os"

	"github.com/spf13/cobra"
)

func newModelsCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "models",
		Short: "Interact with AI models",
		Long:  "A wrapper for 'flow models' commands.",
	}
	cmd.AddCommand(newModelsListCmd())
	return cmd
}

func newModelsListCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "List available models",
		RunE: func(cmd *cobra.Command, args []string) error {
			// Pass through any flags to `flow models`
			flowArgs := []string{"models"}
			found := false
			for _, arg := range os.Args {
				// Pass through flags like --json
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