-- Builds the derived ColorScheme consumed by the highlight groups from a
-- grove theme wire palette (one appearance slot of the `internal theme` /
-- theme_changed payload). Ported from floraverse.nvim colors/init.lua, with
-- the hand-authored palette replaced by the grove-synced one.
local Util = require("grove-nvim.theme.util")

local M = {}

---Pick the palette slot matching the current 'background' option.
---Falls back to whichever appearance the family has.
---@param payload table theme payload {name, family, mode, dark?, light?}
---@return table|nil palette
function M.select_palette(payload)
  if type(payload) ~= "table" then
    return nil
  end
  if vim.o.background == "light" then
    return payload.light or payload.dark
  end
  return payload.dark or payload.light
end

---Derive the full ColorScheme from a wire palette (hex mode only).
---@param palette table wire palette (bg, fg, accents, git, diagnostics, terminal, ...)
---@param opts table resolved ui.theme options
---@return table colors
function M.setup(palette, opts)
  local c = vim.deepcopy(palette)

  Util.bg = c.bg
  Util.fg = c.fg

  c.none = "NONE"

  c.git = c.git or {}
  c.git.add = c.git.add or c.green
  c.git.change = c.git.change or c.blue
  c.git.delete = c.git.delete or c.red

  c.diff = {
    add = Util.blend_bg(c.git.add, 0.2),
    delete = Util.blend_bg(c.git.delete, 0.2),
    change = Util.blend_bg(c.git.change, 0.2),
    text = Util.blend_bg(c.git.change, 0.5),
  }

  c.bg_sidebar = opts.styles.sidebars == "transparent" and c.none
    or opts.styles.sidebars == "dark" and c.bg_dark
    or c.bg

  c.bg_float = opts.styles.floats == "transparent" and c.none
    or opts.styles.floats == "dark" and c.bg_dark
    or c.bg
  c.bg_popup = c.bg_dark
  c.bg_statusline = c.bg_dark

  c.fg_sidebar = c.fg_dark
  c.fg_float = c.fg

  local diagnostics = c.diagnostics or {}
  c.error = diagnostics.error or c.red
  c.warning = diagnostics.warning or c.yellow
  c.info = diagnostics.info or c.blue
  c.hint = diagnostics.hint or c.cyan

  if type(opts.on_colors) == "function" then
    opts.on_colors(c)
  end

  return c
end

return M
