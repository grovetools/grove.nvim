-- Headless smoke test for the grove theme engine.
--
-- Usage (from the repo root):
--   env -u GROVE_THEME nvim --headless -u NONE -l tests/lua/theme_smoke.lua
-- or: make test-lua
--
-- Loads the theme module with a fixture payload (the `internal theme` /
-- theme_changed wire shape) and asserts key highlight groups are set.

local script = (arg and arg[0]) or debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(script, ":p:h:h:h")
vim.opt.runtimepath:prepend(root)

local failures = 0
local function ok(cond, msg)
  if not cond then
    failures = failures + 1
    io.stderr:write("FAIL: " .. msg .. "\n")
  end
end

local function hex(s)
  return tonumber(s:sub(2), 16)
end

-- Fixture: kanagawa-flavored payload in the exact wire shape emitted by
-- `grove-nvim internal theme` and daemon theme_changed events.
local function palette(name, appearance, bg, fg)
  return {
    name = name,
    variant = appearance,
    appearance = appearance,
    bg = bg,
    bg_dark = "#16161d",
    bg_highlight = "#2a2a37",
    bg_visual = "#223249",
    fg = fg,
    fg_dark = "#c8c093",
    fg_gutter = "#54546d",
    fg_inverse = "#16161d",
    comment = "#727169",
    border = "#54546d",
    red = "#e82424",
    green = "#98bb6c",
    yellow = "#e6c384",
    blue = "#7e9cd8",
    magenta = "#d27e99",
    cyan = "#6a9589",
    orange = "#ffa066",
    purple = "#957fb8",
    git = { add = "#76946a", change = "#dca561", delete = "#c34043" },
    diagnostics = { error = "#e82424", warning = "#ff9e3b", info = "#658594", hint = "#6a9589" },
    terminal = {
      black = "#090618", red = "#c34043", green = "#76946a", yellow = "#c0a36e",
      blue = "#7e9cd8", magenta = "#957fb8", cyan = "#6a9589", white = "#c8c093",
      black_bright = "#727169", red_bright = "#e82424", green_bright = "#98bb6c",
      yellow_bright = "#e6c384", blue_bright = "#7fb4ca", magenta_bright = "#938aa9",
      cyan_bright = "#7aa89f", white_bright = "#dcd7ba",
    },
  }
end

local fixture = {
  name = "test-theme",
  family = "test",
  mode = "hex",
  dark = palette("test-dark", "dark", "#1f1f28", "#dcd7ba"),
  light = palette("test-light", "light", "#f2ecbc", "#545464"),
}

require("grove-nvim.config").setup({
  ui = { theme = { enable = true, plugins = { all = true } } },
})
local theme = require("grove-nvim.theme")

-- 1. Dark apply: base + treesitter + plugin groups, terminal colors.
vim.o.background = "dark"
ok(theme.apply(fixture), "apply(dark fixture) returned false")
ok(vim.g.colors_name == "grove-test-dark", "colors_name = " .. tostring(vim.g.colors_name))

local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
ok(normal.fg == hex("#dcd7ba"), "Normal.fg wrong: " .. tostring(normal.fg))
ok(normal.bg == hex("#1f1f28"), "Normal.bg wrong: " .. tostring(normal.bg))

local comment = vim.api.nvim_get_hl(0, { name = "Comment" })
ok(comment.fg == hex("#727169"), "Comment.fg wrong")
ok(comment.italic == true, "Comment should be italic (styles.comments)")

ok(vim.api.nvim_get_hl(0, { name = "CursorLine" }).bg == hex("#2a2a37"), "CursorLine.bg wrong")
ok(vim.api.nvim_get_hl(0, { name = "DiagnosticError" }).fg == hex("#e82424"), "DiagnosticError.fg wrong")
ok(vim.api.nvim_get_hl(0, { name = "DiffAdd" }).bg ~= nil, "DiffAdd.bg missing (diff derivation)")

local var_builtin = vim.api.nvim_get_hl(0, { name = "@variable.builtin" })
ok(var_builtin.fg == hex("#e82424"), "@variable.builtin.fg wrong (treesitter group)")

ok(vim.api.nvim_get_hl(0, { name = "TelescopeBorder" }).fg ~= nil, "TelescopeBorder missing (plugins.all)")
ok(vim.api.nvim_get_hl(0, { name = "GitSignsAdd" }).fg == hex("#76946a"), "GitSignsAdd.fg wrong")
ok(vim.g.terminal_color_2 == "#76946a", "terminal_color_2 wrong: " .. tostring(vim.g.terminal_color_2))

-- 2. UI chrome highlights read the synced palette.
require("grove-nvim.status_provider").state.theme = fixture
theme.apply_ui_highlights()
local added = vim.api.nvim_get_hl(0, { name = "GroveGitAdded" })
ok(added.fg == hex("#76946a"), "GroveGitAdded.fg should come from git.add")
local label = vim.api.nvim_get_hl(0, { name = "GroveStatusLabel" })
ok(label.fg == hex("#727169") and label.italic == true, "GroveStatusLabel wrong")

-- 3. Light appearance picks the light slot.
vim.o.background = "light"
ok(theme.apply(fixture), "apply(light fixture) returned false")
ok(vim.g.colors_name == "grove-test-light", "light colors_name = " .. tostring(vim.g.colors_name))
ok(vim.api.nvim_get_hl(0, { name = "Normal" }).bg == hex("#f2ecbc"), "light Normal.bg wrong")

-- 4. ANSI-mode payloads are skipped gracefully.
local before = vim.g.colors_name
local ansi = { name = "terminal", family = "terminal", mode = "ansi", dark = { name = "terminal", bg = "0", fg = "7" } }
ok(theme.apply(ansi) == false, "ansi payload should not apply")
ok(vim.g.colors_name == before, "ansi payload must not change colors_name")

-- 5. ui_colors falls back to the historic values without a palette.
require("grove-nvim.status_provider").state.theme = nil
theme.state.payload = nil
theme.state.fetched = true -- suppress CLI fetch in the test environment
local fallback = theme.ui_colors()
ok(fallback.muted == "#5c6370", "ui_colors fallback muted wrong")
ok(fallback.add == "#98c379", "ui_colors fallback add wrong")

-- 6. A colorscheme loaded after grove.nvim setup cannot permanently replace
--    an enabled Grove theme (the common plugin-manager startup order).
theme.fetch = function()
  return fixture
end
theme.setup()
vim.cmd.colorscheme("default")
ok(vim.g.colors_name == "default", "external colorscheme should apply before the scheduled repair")
ok(vim.wait(1000, function()
  return vim.g.colors_name == "grove-test-light"
end), "enabled Grove theme was not restored after an external ColorScheme event")
ok(vim.api.nvim_get_hl(0, { name = "Normal" }).bg == hex("#f2ecbc"), "restored Grove Normal.bg wrong")

if failures > 0 then
  io.stderr:write(("theme_smoke: %d failure(s)\n"):format(failures))
  os.exit(1)
end
print("theme_smoke: OK")
os.exit(0)
