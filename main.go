package main

import (
	"os"

	"github.com/mattsolo1/grove-nvim/cmd"
)

func main() {
	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
