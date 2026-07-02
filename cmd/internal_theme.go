package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	coredaemon "github.com/grovetools/core/pkg/daemon"
	"github.com/grovetools/core/tui/theme"
	"github.com/spf13/cobra"
)

// resolveThemeName resolves the theme selection with core's precedence:
// GROVE_THEME env var first, then the resolved config's tui.theme, then the
// default (theme.CurrentName wraps exactly that chain).
func resolveThemeName() string {
	return theme.CurrentName()
}

// buildThemePayload assembles the same wire shape the daemon broadcasts for
// theme_changed events (and stamps on initial snapshots), so the Lua side
// parses ONE payload shape for both the initial synchronous load and live
// SSE updates. The single shared implementation lives in core
// (coredaemon.BuildThemePayload); this is a thin local alias.
func buildThemePayload(name string) (*coredaemon.ThemeChangedPayload, bool) {
	return coredaemon.BuildThemePayload(name)
}

func newThemeCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "theme",
		Short: "Print the resolved current theme as JSON (both appearances)",
		Long: `Resolves the current grove theme (GROVE_THEME env var, then config
tui.theme, then the default) and prints its fully derived palettes for both
appearances as a single JSON object. The shape is identical to the daemon's
theme_changed SSE payload so consumers parse one shape everywhere.`,
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			name := resolveThemeName()
			payload, ok := buildThemePayload(name)
			if !ok {
				// Unknown/renamed theme in config: fall back to the default,
				// matching core's resolveThemeColors behavior.
				payload, ok = buildThemePayload(theme.DefaultThemeName)
			}
			if !ok {
				return fmt.Errorf("theme registry has no palette for %q", name)
			}
			return json.NewEncoder(os.Stdout).Encode(payload)
		},
	}
}
