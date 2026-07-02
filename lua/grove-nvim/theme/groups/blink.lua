-- Ported from floraverse.nvim (groups/blink.lua).
local M = {}
M.url = "https://github.com/Saghen/blink.cmp"

---@param c table derived ColorScheme
function M.get(c, opts)
  -- stylua: ignore
  local ret = {
    BlinkCmpDoc                 = { fg = c.fg, bg = c.bg_float },
    BlinkCmpDocBorder           = { fg = c.border, bg = c.bg_float },
    BlinkCmpGhostText           = { fg = c.comment },
    BlinkCmpKindDefault         = { fg = c.fg_dark, bg = c.none },
    BlinkCmpLabel               = { fg = c.fg, bg = c.none },
    BlinkCmpLabelDeprecated     = { fg = c.fg_gutter, bg = c.none, strikethrough = true },
    BlinkCmpLabelMatch          = { fg = c.blue, bg = c.none, bold = true },
    BlinkCmpMenu                = { fg = c.fg, bg = c.bg_float },
    BlinkCmpMenuBorder          = { fg = c.border, bg = c.bg_float },
    BlinkCmpSignatureHelp       = { fg = c.fg, bg = c.bg_float },
    BlinkCmpSignatureHelpBorder = { fg = c.border, bg = c.bg_float },
  }

  require("grove-nvim.theme.groups.kinds").kinds(ret, "BlinkCmpKind%s")
  return ret
end

return M
