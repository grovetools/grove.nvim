package cmd

import (
	"strconv"
	"strings"
	"testing"
)

func TestResolveThemeNameEnvPrecedence(t *testing.T) {
	t.Setenv("GROVE_THEME", " Gruvbox_Dark ")
	if got := resolveThemeName(); got != "gruvbox-dark" {
		t.Fatalf("resolveThemeName() = %q, want %q", got, "gruvbox-dark")
	}
}

func TestBuildThemePayloadHexFamily(t *testing.T) {
	payload, ok := buildThemePayload("kanagawa")
	if !ok {
		t.Fatal("buildThemePayload(kanagawa) not found")
	}
	if payload.Name != "kanagawa" || payload.Family != "kanagawa" {
		t.Fatalf("unexpected identity: name=%q family=%q", payload.Name, payload.Family)
	}
	if payload.Mode != "hex" {
		t.Fatalf("mode = %q, want hex", payload.Mode)
	}
	if payload.Dark == nil || payload.Light == nil {
		t.Fatalf("kanagawa family should carry both appearances: dark=%v light=%v", payload.Dark, payload.Light)
	}
	if payload.Dark.Appearance != "dark" || payload.Light.Appearance != "light" {
		t.Fatalf("slot appearances wrong: dark=%q light=%q", payload.Dark.Appearance, payload.Light.Appearance)
	}
	for role, v := range map[string]string{
		"bg":            payload.Dark.Bg,
		"fg":            payload.Dark.Fg,
		"comment":       payload.Dark.Comment,
		"git.add":       payload.Dark.Git.Add,
		"diag.error":    payload.Dark.Diagnostics.Error,
		"terminal.cyan": payload.Dark.Terminal.Cyan,
	} {
		if !strings.HasPrefix(v, "#") || len(v) != 7 {
			t.Errorf("dark.%s = %q, want #rrggbb hex", role, v)
		}
	}
}

func TestBuildThemePayloadVariantSlots(t *testing.T) {
	payload, ok := buildThemePayload("catppuccin-latte")
	if !ok {
		t.Fatal("buildThemePayload(catppuccin-latte) not found")
	}
	if payload.Light == nil || payload.Light.Name != "catppuccin-latte" {
		t.Fatalf("selected light variant should occupy the light slot, got %+v", payload.Light)
	}
	if payload.Dark == nil || payload.Dark.Appearance != "dark" {
		t.Fatalf("family default should fill the dark slot, got %+v", payload.Dark)
	}
}

func TestBuildThemePayloadANSI(t *testing.T) {
	payload, ok := buildThemePayload("terminal")
	if !ok {
		t.Fatal("buildThemePayload(terminal) not found")
	}
	if payload.Mode != "ansi" {
		t.Fatalf("mode = %q, want ansi", payload.Mode)
	}
	p := payload.Dark
	if p == nil {
		p = payload.Light
	}
	if p == nil {
		t.Fatal("terminal theme has no palette slot")
	}
	for role, v := range map[string]string{"bg": p.Bg, "fg": p.Fg, "red": p.Red} {
		if n, err := strconv.Atoi(v); err != nil || n < 0 || n > 255 {
			t.Errorf("ansi %s = %q, want ANSI index 0-255", role, v)
		}
	}
}

func TestBuildThemePayloadAlias(t *testing.T) {
	payload, ok := buildThemePayload("branded") // legacy alias for kanagawa
	if !ok {
		t.Fatal("buildThemePayload(branded) not found")
	}
	if payload.Family != "kanagawa" {
		t.Fatalf("family = %q, want kanagawa", payload.Family)
	}
}

func TestBuildThemePayloadUnknown(t *testing.T) {
	if _, ok := buildThemePayload("no-such-theme"); ok {
		t.Fatal("unknown theme should not resolve")
	}
}
