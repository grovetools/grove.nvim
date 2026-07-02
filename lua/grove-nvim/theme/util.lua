-- Color derivation helpers, ported from floraverse.nvim (util.lua).
-- Palettes arrive fully resolved from grove's Go registry; these helpers
-- only fill editor-specific slots (diff backgrounds, dimmed accents) the
-- wire payload doesn't carry.
local M = {}

-- Default anchors, overwritten by colors.setup with the active palette.
M.bg = "#000000"
M.fg = "#ffffff"

---@param c string hex color "#rrggbb"
local function rgb(c)
  c = string.lower(c)
  return { tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16) }
end

---Blend a foreground color onto a background color.
---@param foreground string foreground color
---@param alpha number|string number between 0 and 1. 0 results in bg, 1 results in fg
---@param background string background color
function M.blend(foreground, alpha, background)
  alpha = type(alpha) == "string" and (tonumber(alpha, 16) / 0xff) or alpha
  local bg = rgb(background)
  local fg = rgb(foreground)

  local blendChannel = function(i)
    local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
    return math.floor(math.min(math.max(0, ret), 255) + 0.5)
  end

  return string.format("#%02x%02x%02x", blendChannel(1), blendChannel(2), blendChannel(3))
end

---Blend toward the palette background (darken on dark themes).
function M.blend_bg(hex, amount, bg)
  return M.blend(hex, amount, bg or M.bg)
end
M.darken = M.blend_bg

---Blend toward the palette foreground (lighten on dark themes).
function M.blend_fg(hex, amount, fg)
  return M.blend(hex, amount, fg or M.fg)
end
M.lighten = M.blend_fg

---Flatten `style = {...}` shorthands in a highlight group table into the
---keys nvim_set_hl expects.
---@param groups table<string, table>
---@return table<string, vim.api.keyset.highlight>
function M.resolve(groups)
  for _, hl in pairs(groups) do
    if type(hl) == "table" and type(hl.style) == "table" then
      for k, v in pairs(hl.style) do
        hl[k] = v
      end
      hl.style = nil
    end
  end
  return groups
end

return M
