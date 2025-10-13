package cmd

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/mattsolo1/grove-core/pkg/workspace"
	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

// findWorkspaceByPath finds the best matching workspace for a given path,
// using case-insensitive matching on macOS/Windows.
func findWorkspaceByPath(provider *workspace.Provider, path string, discoveryResult *workspace.DiscoveryResult) *workspace.WorkspaceNode {
	// Try exact match first
	node := provider.FindByPath(path)
	if node != nil {
		return node
	}

	// On case-insensitive filesystems, try manual case-insensitive matching
	if runtime.GOOS != "darwin" && runtime.GOOS != "windows" {
		return nil
	}

	// Build a list of all workspace paths from discovered projects
	var bestMatchPath string
	var bestMatchLen int

	for _, proj := range discoveryResult.Projects {
		for _, ws := range proj.Workspaces {
			// Case-insensitive prefix check
			if len(ws.Path) > bestMatchLen &&
				strings.HasPrefix(strings.ToLower(path), strings.ToLower(ws.Path)) {
				// Verify it's a directory boundary
				if len(path) == len(ws.Path) || (len(path) > len(ws.Path) && path[len(ws.Path)] == '/') {
					bestMatchPath = ws.Path
					bestMatchLen = len(ws.Path)
				}
			}
		}
	}

	// If we found a match, look it up with the provider using its actual path
	if bestMatchPath != "" {
		return provider.FindByPath(bestMatchPath)
	}

	return nil
}

func newInternalCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:    "internal",
		Short:  "Internal commands for the Neovim plugin",
		Hidden: true, // Hide from standard help output
	}
	cmd.AddCommand(newResolveAliasesCmd())
	return cmd
}

func newResolveAliasesCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "resolve-aliases",
		Short: "Converts a list of absolute file paths to workspace-relative aliases",
		Long:  `Reads absolute file paths from stdin (one per line) and outputs a JSON map of original paths to their aliased versions.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			// Initialize workspace provider for fast lookups.
			// Suppress noisy discovery logs by redirecting logger output.
			logger := logrus.New()
			logger.SetOutput(io.Discard)
			discoveryService := workspace.NewDiscoveryService(logger)
			discoveryResult, err := discoveryService.DiscoverAll()
			if err != nil {
				return fmt.Errorf("failed to discover workspaces: %w", err)
			}
			provider := workspace.NewProvider(discoveryResult)

			// Read paths from stdin
			scanner := bufio.NewScanner(os.Stdin)
			results := make(map[string]string)

			for scanner.Scan() {
				path := scanner.Text()
				if path == "" {
					continue
				}

				// Find the most specific workspace containing this path
				// Use case-insensitive matching on macOS/Windows
				node := findWorkspaceByPath(provider, path, discoveryResult)

				if node != nil {
					// Found a containing workspace, create the alias
					// On case-insensitive filesystems, we need to use normalized paths for Rel
					// to work correctly when there are case differences
					basePathNormalized := node.Path
					filePathNormalized := path

					// On macOS/Windows, ensure both paths use the same case by keeping the workspace path case
					// and adjusting the file path to match
					if runtime.GOOS == "darwin" || runtime.GOOS == "windows" {
						// If the lowercased paths match on the prefix, use the workspace's actual case
						if strings.HasPrefix(strings.ToLower(path), strings.ToLower(node.Path)) {
							// Replace the matching prefix with the workspace's case
							filePathNormalized = node.Path + path[len(node.Path):]
						}
					}

					relativePath, err := filepath.Rel(basePathNormalized, filePathNormalized)
					if err != nil {
						// Fallback to absolute path on error
						results[path] = path
						continue
					}

					// Use the node's canonical identifier, replacing underscores with colons
					// to create a resolvable, namespaced alias.
					// e.g., "my-ecosystem_feature_sub-project" -> "my-ecosystem:feature:sub-project"
					aliasPart := strings.ReplaceAll(node.Identifier(), "_", ":")

					alias := fmt.Sprintf("@a:%s/%s", aliasPart, filepath.ToSlash(relativePath))
					results[path] = alias
				} else {
					// No containing workspace found, use the original absolute path
					results[path] = path
				}
			}

			if err := scanner.Err(); err != nil {
				return fmt.Errorf("error reading from stdin: %w", err)
			}

			// Output results as JSON
			jsonOutput, err := json.Marshal(results)
			if err != nil {
				return fmt.Errorf("failed to marshal results to JSON: %w", err)
			}
			fmt.Println(string(jsonOutput))

			return nil
		},
	}
}
