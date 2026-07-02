-- Ported from floraverse.nvim (groups/telescope.lua).
local M = {}
M.url = "https://github.com/nvim-telescope/telescope.nvim"

---@param c table derived ColorScheme
function M.get(c, opts)
  -- stylua: ignore
  return {
    TelescopeBorder         = { fg = c.border, bg = c.bg_float },
    TelescopeNormal         = { fg = c.fg, bg = c.bg_float },
    TelescopePromptBorder   = { fg = c.orange, bg = c.bg_float },
    TelescopePromptTitle    = { fg = c.orange, bg = c.bg_float },
    TelescopeResultsTitle   = { fg = c.fg, bg = c.bg_float },
    TelescopePreviewTitle   = { fg = c.fg, bg = c.bg_float },
    TelescopeMatching       = { fg = c.blue, bold = true },
    TelescopeSelection      = { bg = c.bg_highlight },
  }
end

return M
