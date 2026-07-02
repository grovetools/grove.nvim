-- Ported from floraverse.nvim (groups/which-key.lua).
local M = {}
M.url = "https://github.com/folke/which-key.nvim"

---@param c table derived ColorScheme
function M.get(c, opts)
  -- stylua: ignore
  return {
    WhichKey          = { fg = c.cyan },
    WhichKeyGroup     = { fg = c.blue },
    WhichKeyDesc      = { fg = c.magenta },
    WhichKeySeparator = { fg = c.comment },
    WhichKeyNormal    = { bg = c.bg_sidebar },
    WhichKeyValue     = { fg = c.fg_dark },
  }
end

return M
