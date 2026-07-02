-- Grove theme engine for Neovim, ported from floraverse.nvim with the
-- hand-authored Lua palettes replaced by grove's Go-served theme registry.
--
-- The palette arrives as a single payload shape from two sources:
--   * initial load: synchronous `grove-nvim internal theme` call
--   * live updates: daemon `theme_changed` SSE events (and the theme field
--     on `initial` snapshots) relayed by status_provider, which fires the
--     `User GroveThemeChanged` autocmd.
--
-- Payload: {name, family, mode = "hex"|"ansi", dark = {...}, light = {...}}
-- where each appearance slot carries fully resolved role colors. ANSI-mode
-- payloads (the `terminal` passthrough theme) carry index strings, not hex,
-- so the engine skips applying them.
local M = {}

M.state = {
  payload = nil, -- last theme payload seen (CLI fetch or SSE)
  applied = nil, -- concrete palette name currently applied by the engine
  fetched = false, -- whether the synchronous CLI fetch has been attempted
}

-- Fallback UI colors used by apply_ui_highlights when no palette has been
-- synced (daemon offline, theming unavailable). These are the historic
-- hardcoded values from status_bar.lua and init.lua.
local FALLBACK_UI = {
  muted = "#5c6370",
  separator = "#3b4048",
  info = "#61afef",
  error = "#e06c75",
  warn = "#d19a66",
  add = "#98c379",
  delete = "#e06c75",
}

local function opts()
  return require("grove-nvim.config").options.ui.theme
end

--- True when GROVE_THEME pins the theme for this Neovim process. The
--- initial `internal theme` call already reflects the env var; live
--- theme_changed events are ignored while pinned (env always wins, matching
--- the other grove consumers).
function M.pinned()
  local v = os.getenv("GROVE_THEME")
  return v ~= nil and v ~= ""
end

--- Synchronously fetch the resolved current theme from the Go side.
---@return table|nil payload
function M.fetch()
  local utils = require("grove-nvim.utils")
  local bin = utils.get_grove_nvim_binary()
  if not bin then
    return nil
  end
  local out = vim.fn.system({ bin, "internal", "theme" })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  local ok, payload = pcall(vim.json.decode, out)
  if ok and type(payload) == "table" and payload.name then
    return payload
  end
  return nil
end

--- The freshest theme payload available: while pinned, the CLI fetch (which
--- honors GROVE_THEME); otherwise the payload synced from the daemon stream,
--- falling back to the last CLI fetch.
---@return table|nil payload
function M.current_payload()
  if M.pinned() then
    if not M.state.payload and not M.state.fetched then
      M.state.fetched = true
      M.state.payload = M.fetch()
    end
    return M.state.payload
  end
  local provider = require("grove-nvim.status_provider")
  return provider.state.theme or M.state.payload
end

--- Semantic UI colors for grove.nvim's own chrome (status bar, lualine git
--- component), read from the synced palette with the historic hex values as
--- fallback. Works regardless of whether the full engine is enabled.
---@return table {muted, separator, info, error, warn, add, delete}
function M.ui_colors()
  local payload = M.current_payload()
  local palette = nil
  if payload and payload.mode ~= "ansi" then
    palette = require("grove-nvim.theme.colors").select_palette(payload)
  end
  if not palette then
    return vim.deepcopy(FALLBACK_UI)
  end
  local git = palette.git or {}
  local diagnostics = palette.diagnostics or {}
  return {
    muted = palette.comment or FALLBACK_UI.muted,
    separator = palette.fg_gutter or FALLBACK_UI.separator,
    info = diagnostics.info or palette.blue or FALLBACK_UI.info,
    error = diagnostics.error or palette.red or FALLBACK_UI.error,
    warn = palette.orange or FALLBACK_UI.warn,
    add = git.add or palette.green or FALLBACK_UI.add,
    delete = git.delete or palette.red or FALLBACK_UI.delete,
  }
end

--- (Re)define the shared Grove* UI highlight groups from the current
--- palette. Called by the status bar on refresh and on GroveThemeChanged so
--- the chrome follows live theme changes even when the engine is disabled.
function M.apply_ui_highlights()
  local c = M.ui_colors()
  local set = vim.api.nvim_set_hl
  set(0, "GroveStatusLabel", { fg = c.muted, italic = true, ctermfg = 243, cterm = { italic = true } })
  set(0, "GroveStatusContent", {})
  set(0, "GroveStatusSeparator", { fg = c.separator, ctermfg = 237 })
  set(0, "GroveStatusMuted", { fg = c.muted, italic = true, ctermfg = 243, cterm = { italic = true } })
  set(0, "GroveStatusBarBorder", { fg = c.separator, ctermfg = 237 })
  set(0, "GroveStatusGitAhead", { fg = c.info })
  set(0, "GroveStatusGitBehind", { fg = c.error })
  set(0, "GroveStatusGitModified", { fg = c.warn })
  set(0, "GroveStatusGitStaged", { fg = c.info })
  set(0, "GroveStatusGitUntracked", { fg = c.error })
  set(0, "GroveStatusGitAdded", { fg = c.add })
  set(0, "GroveStatusGitDeleted", { fg = c.delete })
  set(0, "GroveGitAdded", { fg = c.add, ctermfg = 2 })
  set(0, "GroveGitDeleted", { fg = c.delete, ctermfg = 1 })
end

--- Set the built-in :terminal palette from the theme's 16 terminal slots.
---@param c table derived ColorScheme
function M.terminal(c)
  local t = c.terminal or {}
  vim.g.terminal_color_0 = t.black
  vim.g.terminal_color_1 = t.red
  vim.g.terminal_color_2 = t.green
  vim.g.terminal_color_3 = t.yellow
  vim.g.terminal_color_4 = t.blue
  vim.g.terminal_color_5 = t.magenta
  vim.g.terminal_color_6 = t.cyan
  vim.g.terminal_color_7 = t.white
  vim.g.terminal_color_8 = t.black_bright
  vim.g.terminal_color_9 = t.red_bright
  vim.g.terminal_color_10 = t.green_bright
  vim.g.terminal_color_11 = t.yellow_bright
  vim.g.terminal_color_12 = t.blue_bright
  vim.g.terminal_color_13 = t.magenta_bright
  vim.g.terminal_color_14 = t.cyan_bright
  vim.g.terminal_color_15 = t.white_bright
end

--- Apply a theme payload as the active colorscheme.
---@param payload table|nil defaults to the freshest available payload
---@return boolean applied
function M.apply(payload)
  payload = payload or M.current_payload()
  if not payload then
    return false
  end
  if payload.mode == "ansi" then
    -- The `terminal` passthrough theme carries ANSI indices, not hex; the
    -- terminal emulator already renders the right colors, so leave the
    -- active colorscheme alone.
    return false
  end

  local o = opts()
  local colors_mod = require("grove-nvim.theme.colors")
  local palette = colors_mod.select_palette(payload)
  if not palette then
    return false
  end

  local c = colors_mod.setup(palette, o)
  local groups = require("grove-nvim.theme.groups").setup(c, o)

  if vim.g.colors_name then
    vim.cmd("hi clear")
  end

  vim.o.termguicolors = true
  vim.g.colors_name = "grove-" .. (palette.name or payload.name)

  for group, hl in pairs(groups) do
    hl = type(hl) == "string" and { link = hl } or hl
    vim.api.nvim_set_hl(0, group, hl)
  end

  if o.terminal_colors ~= false then
    M.terminal(c)
  end

  M.state.payload = payload
  M.state.applied = palette.name or payload.name

  -- Let colorscheme-reactive plugins (and grove.nvim's own chrome) refresh.
  M.apply_ui_highlights()
  vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })

  return true
end

--- Engine setup: initial synchronous apply plus live-update subscriptions.
--- No-op unless config.ui.theme.enable is set.
function M.setup()
  if not opts().enable then
    return
  end

  M.state.fetched = true
  M.state.payload = M.fetch()
  if M.state.payload then
    M.apply(M.state.payload)
  end

  local aug = vim.api.nvim_create_augroup("GroveTheme", { clear = true })

  -- Live updates from the daemon stream (theme_changed events and initial
  -- snapshots stored by status_provider). Skipped while GROVE_THEME pins
  -- the process theme.
  vim.api.nvim_create_autocmd("User", {
    group = aug,
    pattern = "GroveThemeChanged",
    callback = function()
      if M.pinned() or opts().live_updates == false then
        return
      end
      local payload = require("grove-nvim.status_provider").state.theme
      if not payload then
        return
      end
      local palette = require("grove-nvim.theme.colors").select_palette(payload)
      -- Re-apply only when the effective concrete palette changed.
      if palette and palette.name ~= M.state.applied then
        M.apply(payload)
      end
    end,
  })

  -- Re-pick the dark/light slot when 'background' changes.
  vim.api.nvim_create_autocmd("OptionSet", {
    group = aug,
    pattern = "background",
    callback = function()
      local payload = M.current_payload()
      if not payload then
        return
      end
      local palette = require("grove-nvim.theme.colors").select_palette(payload)
      if palette and palette.name ~= M.state.applied then
        M.apply(payload)
      end
    end,
  })
end

return M
