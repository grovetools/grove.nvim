-- Ported from floraverse.nvim (groups/neo-tree.lua).
local M = {}
M.url = "https://github.com/nvim-neo-tree/neo-tree.nvim"

---@param c table derived ColorScheme
function M.get(c, opts)
  -- stylua: ignore
  return {
    NeoTreeNormal = { fg = c.fg_sidebar, bg = c.bg_sidebar },
    NeoTreeNormalNC = { fg = c.fg_sidebar, bg = c.bg_sidebar },
    NeoTreeDimText = { fg = c.fg_gutter },
    NeoTreeDirectoryIcon = { fg = c.blue },
    NeoTreeDirectoryName = { fg = c.blue },
    NeoTreeFileName = { fg = c.fg },
    NeoTreeFileIcon = { fg = c.fg_dark },
    NeoTreeGitAdded = { fg = c.git.add },
    NeoTreeGitDeleted = { fg = c.git.delete },
    NeoTreeGitModified = { fg = c.git.change },
    NeoTreeGitConflict = { fg = c.red },
    NeoTreeGitUntracked = { fg = c.fg_gutter },
    NeoTreeIndentMarker = { fg = c.fg_gutter },
    NeoTreeRootName = { fg = c.blue, bold = true },
    NeoTreeSymbolicLinkTarget = { fg = c.cyan },
  }
end

return M
