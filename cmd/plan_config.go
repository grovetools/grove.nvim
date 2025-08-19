package cmd

import (
	"github.com/spf13/cobra"
)

// newPlanConfigCmd wraps `flow plan config`.
func newPlanConfigCmd() *cobra.Command {
	var (
		get string
		set []string
	)

	cmd := &cobra.Command{
		Use:   "config <plan-name-or-directory>",
		Short: "View or edit plan configuration",
		Long:  "A wrapper for 'flow plan config'. Use --get to read a value, or --set key=value to write.",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			flowArgs := []string{"plan", "config", args[0]}

			if get != "" {
				flowArgs = append(flowArgs, "--get", get)
			}
			for _, s := range set {
				flowArgs = append(flowArgs, "--set", s)
			}

			return runFlowCommand(flowArgs...)
		},
	}

	cmd.Flags().StringVar(&get, "get", "", "Get a specific configuration value (e.g., model)")
	cmd.Flags().StringSliceVar(&set, "set", nil, "Set a configuration value (e.g., model=gemini-2.0-flash)")

	return cmd
}