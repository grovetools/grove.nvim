-- Ported from floraverse.nvim (groups/cmp.lua).
local M = {}
M.url = "https://github.com/hrsh7th/nvim-cmp"

---@param c table derived ColorScheme
function M.get(c, opts)
  -- stylua: ignore
  local ret = {
    CmpItemAbbrDeprecated = { fg = c.fg_gutter, bg = c.none, strikethrough = true },
    CmpItemAbbrMatch = { fg = c.blue, bg = c.none, bold = true },
    CmpItemAbbrMatchFuzzy = { fg = c.blue, bg = c.none, bold = true },
    CmpItemMenu = { fg = c.comment, bg = c.none },
    CmpItemKindDefault = { fg = c.fg_dark, bg = c.none },
  }

  require("grove-nvim.theme.groups.kinds").kinds(ret, "CmpItemKind%s")
  return ret
end

return M
