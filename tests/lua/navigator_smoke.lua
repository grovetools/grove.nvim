-- Headless smoke test for the grove-nvim spatial navigator.
--
-- Usage (from the repo root):
--   nvim --headless -u NONE -l tests/lua/navigator_smoke.lua
-- or: make test-lua
--
-- Verifies that the vim-tmux-navigator-style Ctrl+hjkl keymaps install inside a
-- grove terminal host (groveterm or tuimux/treemux), keyed on the host env
-- markers, and stay out of the way under bare tmux.

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

-- Fresh module instance so a re-require picks up env changes.
local function fresh_navigator()
  package.loaded["grove-nvim.navigator"] = nil
  return require("grove-nvim.navigator")
end

local function clear_env()
  for _, name in ipairs({ "GROVE_TERMINAL", "TUIMUX_PTY", "GROVE_PTY" }) do
    vim.fn.setenv(name, vim.NIL)
  end
end

local function has_ctrl_hjkl_maps()
  for _, key in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>" }) do
    if vim.fn.maparg(key, "n") == "" then
      return false
    end
  end
  return true
end

local function clear_ctrl_hjkl_maps()
  for _, key in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>" }) do
    pcall(vim.keymap.del, "n", key)
  end
end

-- 1. Outside any grove host, in_grove_host() is false and setup() installs
--    nothing (defers to vim-tmux-navigator under tmux).
clear_env()
clear_ctrl_hjkl_maps()
local nav = fresh_navigator()
ok(nav.in_grove_host() == false, "in_grove_host should be false with no markers")
nav.setup()
ok(not has_ctrl_hjkl_maps(), "setup() must not map C-hjkl outside a grove host")

-- 2. Inside tuimux/treemux (TUIMUX_PTY), setup() installs the C-hjkl keymaps.
clear_env()
clear_ctrl_hjkl_maps()
vim.fn.setenv("TUIMUX_PTY", "1")
nav = fresh_navigator()
ok(nav.in_grove_host() == true, "in_grove_host should be true under TUIMUX_PTY")
nav.setup()
ok(has_ctrl_hjkl_maps(), "setup() must map C-hjkl under TUIMUX_PTY")

-- 3. GROVE_TERMINAL (groveterm / agent panes) also activates.
clear_env()
clear_ctrl_hjkl_maps()
vim.fn.setenv("GROVE_TERMINAL", "1")
nav = fresh_navigator()
ok(nav.in_grove_host() == true, "in_grove_host should be true under GROVE_TERMINAL")

clear_env()

if failures > 0 then
  io.stderr:write(("navigator_smoke: %d failure(s)\n"):format(failures))
  os.exit(1)
end
print("navigator_smoke: OK")
os.exit(0)
