package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/grovetools/core/config"
	coredaemon "github.com/grovetools/core/pkg/daemon"
	"github.com/grovetools/core/tui/theme"
	"github.com/spf13/cobra"
)

// defaultThemeName mirrors the unexported default in core/tui/theme: the
// theme in effect when neither GROVE_THEME nor config sets one.
const defaultThemeName = "kanagawa"

// normalizeThemeName mirrors core/tui/theme's unexported normalizeThemeName
// so the emitted name matches what theme.SetTheme and the daemon broadcast.
func normalizeThemeName(name string) string {
	normalized := strings.ToLower(strings.TrimSpace(name))
	normalized = strings.ReplaceAll(normalized, " ", "-")
	normalized = strings.ReplaceAll(normalized, "_", "-")
	return normalized
}

// resolveThemeName mirrors core/tui/theme's unexported getThemeName
// precedence: GROVE_THEME env var first, then the resolved config's
// tui.theme, then the default.
func resolveThemeName() string {
	if name := normalizeThemeName(os.Getenv("GROVE_THEME")); name != "" {
		return name
	}
	cfg, err := config.LoadDefault()
	if err == nil && cfg != nil && cfg.TUI != nil {
		if name := normalizeThemeName(cfg.TUI.Theme); name != "" {
			return name
		}
	}
	return defaultThemeName
}

// buildThemePayload assembles the same wire shape the daemon broadcasts for
// theme_changed events (and stamps on initial snapshots), so the Lua side
// parses ONE payload shape for both the initial synchronous load and live
// SSE updates. The selected variant occupies its own appearance slot; the
// family's default variant for the opposite appearance fills the other slot
// when the family has one. This mirrors daemon/internal/daemon/theming.
func buildThemePayload(name string) (*coredaemon.ThemeChangedPayload, bool) {
	selected, ok := theme.Lookup(name)
	if !ok {
		return nil, false
	}

	dark, light := themeFamilyDefaults(selected.Meta.Family)
	if selected.Meta.Appearance == "light" {
		light = &selected
	} else {
		dark = &selected
	}

	mode := "hex"
	if selected.Meta.ANSI {
		mode = "ansi"
	}

	return &coredaemon.ThemeChangedPayload{
		Name:   normalizeThemeName(name),
		Family: selected.Meta.Family,
		Mode:   mode,
		Dark:   themeWirePalette(dark),
		Light:  themeWirePalette(light),
	}, true
}

// themeFamilyDefaults finds the family's default palette per appearance,
// replicating the registry's rule (first variant by name wins unless a later
// one is flagged default). Lookup resolves legacy aliases before exact
// names, so a variant whose name is shadowed by an alias resolves elsewhere;
// such slots are dropped rather than filled with the wrong appearance.
func themeFamilyDefaults(family string) (dark, light *theme.Palette) {
	for _, meta := range theme.List() {
		if meta.Family != family {
			continue
		}
		p, ok := theme.Lookup(meta.Name)
		if !ok || p.Meta.Name != meta.Name || p.Meta.Appearance != meta.Appearance {
			continue // alias-shadowed name; skip rather than mis-slot
		}
		switch meta.Appearance {
		case "dark":
			if dark == nil || (meta.Default && !dark.Meta.Default) {
				dark = &p
			}
		case "light":
			if light == nil || (meta.Default && !light.Meta.Default) {
				light = &p
			}
		}
	}
	return dark, light
}

// themeWirePalette maps a fully derived theme.Palette onto the JSON wire
// struct.
func themeWirePalette(p *theme.Palette) *coredaemon.ThemePalette {
	if p == nil {
		return nil
	}
	c := p.Colors
	t := p.Terminal
	return &coredaemon.ThemePalette{
		Name:       p.Meta.Name,
		Variant:    p.Meta.Variant,
		Appearance: p.Meta.Appearance,

		Bg:          c.Bg,
		BgDark:      c.BgDark,
		BgHighlight: c.BgHighlight,
		BgVisual:    c.BgVisual,

		Fg:        c.Fg,
		FgDark:    c.FgDark,
		FgGutter:  c.FgGutter,
		FgInverse: c.FgInverse,
		Comment:   c.Comment,
		Border:    c.Border,

		Red:     c.Red,
		Green:   c.Green,
		Yellow:  c.Yellow,
		Blue:    c.Blue,
		Magenta: c.Magenta,
		Cyan:    c.Cyan,
		Orange:  c.Orange,
		Purple:  c.Purple,

		Git: coredaemon.ThemeGitColors{
			Add:    c.Git.Add,
			Change: c.Git.Change,
			Delete: c.Git.Delete,
		},
		Diagnostics: coredaemon.ThemeDiagnosticColors{
			Error:   c.Diagnostics.Error,
			Warning: c.Diagnostics.Warning,
			Info:    c.Diagnostics.Info,
			Hint:    c.Diagnostics.Hint,
		},
		Terminal: coredaemon.ThemeTerminalColors{
			Black:         t.Black,
			Red:           t.Red,
			Green:         t.Green,
			Yellow:        t.Yellow,
			Blue:          t.Blue,
			Magenta:       t.Magenta,
			Cyan:          t.Cyan,
			White:         t.White,
			BlackBright:   t.BlackBright,
			RedBright:     t.RedBright,
			GreenBright:   t.GreenBright,
			YellowBright:  t.YellowBright,
			BlueBright:    t.BlueBright,
			MagentaBright: t.MagentaBright,
			CyanBright:    t.CyanBright,
			WhiteBright:   t.WhiteBright,
		},
	}
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
				payload, ok = buildThemePayload(defaultThemeName)
			}
			if !ok {
				return fmt.Errorf("theme registry has no palette for %q", name)
			}
			return json.NewEncoder(os.Stdout).Encode(payload)
		},
	}
}
