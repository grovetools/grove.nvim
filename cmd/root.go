package cmd

import (
	"github.com/mattsolo1/grove-core/cli"
	"github.com/spf13/cobra"
)

var rootCmd *cobra.Command

func init() {
	rootCmd = cli.NewStandardCommand("neogrove", "A helper binary for the grove-nvim Neovim plugin.")

	// Add commands
	rootCmd.AddCommand(newVersionCmd())
	rootCmd.AddCommand(newChatCmd())
	rootCmd.AddCommand(newPlanCmd())
}

func Execute() error {
	return rootCmd.Execute()
}
