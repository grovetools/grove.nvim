-- Ported from floraverse.nvim (groups/gitsigns.lua).
local M = {}
M.url = "https://github.com/lewis6991/gitsigns.nvim"

---@param c table derived ColorScheme
function M.get(c, opts)
  -- stylua: ignore
  return {
    GitSignsAdd = { fg = c.git.add },
    GitSignsChange = { fg = c.git.change },
    GitSignsDelete = { fg = c.git.delete },
    GitSignsAddNr = { fg = c.git.add },
    GitSignsChangeNr = { fg = c.git.change },
    GitSignsDeleteNr = { fg = c.git.delete },
    GitSignsAddLn = { bg = c.diff.add },
    GitSignsChangeLn = { bg = c.diff.change },
    GitSignsDeleteLn = { bg = c.diff.delete },
  }
end

return M
