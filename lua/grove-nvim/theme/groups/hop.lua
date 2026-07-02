-- Ported from floraverse.nvim (groups/hop.lua).
local Util = require("grove-nvim.theme.util")
local M = {}
M.url = "https://github.com/phaazon/hop.nvim"

---@param c table derived ColorScheme
function M.get(c, opts)
  -- stylua: ignore
  return {
    HopNextKey    = { fg = c.magenta, bold = true },
    HopNextKey1   = { fg = c.blue, bold = true },
    HopNextKey2   = { fg = Util.blend_bg(c.blue, 0.6) },
    HopUnmatched  = { fg = c.fg_gutter },
  }
end

return M
