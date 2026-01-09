package cmd

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"

	"github.com/mattsolo1/grove-core/config"
	"github.com/mattsolo1/grove-core/git"
	grovelogging "github.com/mattsolo1/grove-core/logging"
	"github.com/mattsolo1/grove-core/util/pathutil"
	"github.com/mattsolo1/grove-core/pkg/workspace"
	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

var ulog = grovelogging.NewUnifiedLogger("grove-nvim.internal")

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

	normalizedPath, err := pathutil.NormalizeForLookup(path)
	if err != nil {
		normalizedPath = path
	}

	for _, proj := range discoveryResult.Projects {
		for _, ws := range proj.Workspaces {
			normalizedWsPath, err := pathutil.NormalizeForLookup(ws.Path)
			if err != nil {
				normalizedWsPath = ws.Path
			}

			// Normalized prefix check
			if len(ws.Path) > bestMatchLen &&
				strings.HasPrefix(normalizedPath, normalizedWsPath) {
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
	cmd.AddCommand(newGitStatusCmd())
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

			// --- Start Notebook Alias Generation Logic ---
			coreCfg, err := config.LoadDefault()
			if err != nil {
	ulog.Warn("Could not load grove config for notebook aliases").
					Err(err).
					Emit()
			}

			type processedNotebook struct {
				Name    string
				RootDir string
			}
			var processedNotebooks []processedNotebook
			if coreCfg != nil && coreCfg.Notebooks != nil && coreCfg.Notebooks.Definitions != nil {
				for name, nbConfig := range coreCfg.Notebooks.Definitions {
					if nbConfig.RootDir != "" {
						expandedRoot, err := pathutil.Expand(nbConfig.RootDir)
						if err == nil {
							processedNotebooks = append(processedNotebooks, processedNotebook{Name: name, RootDir: expandedRoot})
						}
					}
				}
				// Sort by root dir length descending to match the most specific (longest) path first.
				sort.Slice(processedNotebooks, func(i, j int) bool {
					return len(processedNotebooks[i].RootDir) > len(processedNotebooks[j].RootDir)
				})
			}
			// --- End Notebook Alias Generation Logic ---

			for scanner.Scan() {
				path := scanner.Text()
				if path == "" {
					continue
				}

				// Check if this path is inside a notebook root
				aliasGenerated := false
				if len(processedNotebooks) > 0 {
					for _, nb := range processedNotebooks {
						// Check if the file path is within this notebook's root dir.
						if strings.HasPrefix(path, nb.RootDir) {
							// Ensure it's a directory boundary to prevent partial matches (e.g., /path/to/nb vs /path/to/nb-plus).
							if len(path) == len(nb.RootDir) || (len(path) > len(nb.RootDir) && path[len(nb.RootDir)] == os.PathSeparator) {
								relPath, err := filepath.Rel(nb.RootDir, path)
								if err == nil {
									var alias string
									// For the "default" notebook, omit the name for a cleaner alias and backward compatibility.
									if nb.Name == "default" {
										alias = fmt.Sprintf("@a:nb:%s", filepath.ToSlash(relPath))
									} else {
										alias = fmt.Sprintf("@a:nb:%s:%s", nb.Name, filepath.ToSlash(relPath))
									}
									results[path] = alias
									aliasGenerated = true
									break // Found the best match, stop iterating notebooks.
								}
							}
						}
					}
				}
				if aliasGenerated {
					continue // Go to the next file path.
				}

				// Find the most specific workspace containing this path
				// Use case-insensitive matching on macOS/Windows
				node := findWorkspaceByPath(provider, path, discoveryResult)

				if node != nil {
					// Found a containing workspace, create the alias
					// On case-insensitive filesystems, normalize paths for consistent comparison
					basePathNormalized, err := pathutil.NormalizeForLookup(node.Path)
					if err != nil {
						basePathNormalized = node.Path
					}
					filePathNormalized, err := pathutil.NormalizeForLookup(path)
					if err != nil {
						filePathNormalized = path
					}

					// If paths match on the normalized prefix, use the workspace's actual case
					// to maintain consistency
					if strings.HasPrefix(filePathNormalized, basePathNormalized) {
						// Replace the matching prefix with the workspace's case
						filePathNormalized = node.Path + path[len(node.Path):]
					}

					relativePath, err := filepath.Rel(node.Path, filePathNormalized)
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

func newGitStatusCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "git-status [path]",
		Short: "Get extended git status for a path",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			path := ""
			if len(args) > 0 {
				path = args[0]
			} else {
				var err error
				path, err = os.Getwd()
				if err != nil {
					// On error, print empty JSON and exit cleanly
					fmt.Println("{}")
					return nil
				}
			}

			status, err := git.GetExtendedStatus(path)
			if err != nil {
				// Not a git repo or other error, print empty JSON and exit cleanly
				fmt.Println("{}")
				return nil
			}

			jsonOutput, err := json.Marshal(status)
			if err != nil {
				// Should not happen, but handle gracefully
				fmt.Println("{}")
				return nil
			}
			fmt.Println(string(jsonOutput))
			return nil
		},
	}
}
