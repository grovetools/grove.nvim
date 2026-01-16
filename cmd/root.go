package cmd

import (
	"github.com/grovetools/core/cli"
	"github.com/spf13/cobra"
)

var rootCmd *cobra.Command

func init() {
	rootCmd = cli.NewStandardCommand("neogrove", "Neovim plugin for grove")

	// Add commands
	rootCmd.AddCommand(newVersionCmd())
	rootCmd.AddCommand(newChatCmd())
	rootCmd.AddCommand(newPlanCmd())
	rootCmd.AddCommand(newModelsCmd())
	rootCmd.AddCommand(newTextCmd())
	rootCmd.AddCommand(newInternalCmd())
}

func Execute() error {
	return rootCmd.Execute()
}
