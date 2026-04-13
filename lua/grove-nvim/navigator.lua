-- grove-nvim.navigator
--
-- Spatial navigation for groveterm: Ctrl+h/j/k/l move between vim windows
-- normally, but when at a window edge inside GROVE_TERMINAL, emit an
-- OSC 777;navigate;{h,j,k,l} sequence so the terminal host can move focus
-- to an adjacent pane. Outside groveterm, falls back to plain wincmd.

local M = {}

local direction_map = {
  h = "h",
  j = "j",
  k = "k",
  l = "l",
}

--- Check if the current window is at the edge in the given direction.
---@param dir string one of h, j, k, l
---@return boolean
local function at_edge(dir)
  local cur = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. dir)
  local new = vim.api.nvim_get_current_win()
  if cur ~= new then
    -- Moved to a different window — go back, we're not at the edge.
    vim.cmd("wincmd " .. ({ h = "l", j = "k", k = "j", l = "h" })[dir])
    return false
  end
  return true
end

--- Emit an OSC 777 navigate sequence to stdout.
---@param dir string one of h, j, k, l
local function osc_navigate(dir)
  io.stdout:write("\x1b]777;navigate;" .. dir .. "\x1b\\")
  io.stdout:flush()
end

--- Navigate in the given direction, delegating to groveterm when at an edge.
---@param dir string one of h, j, k, l
local function navigate(dir)
  if at_edge(dir) and os.getenv("GROVE_TERMINAL") then
    osc_navigate(dir)
  else
    vim.cmd("wincmd " .. dir)
  end
end

function M.setup()
  -- Only install our keymaps inside groveterm. In tmux, let
  -- vim-tmux-navigator (or the user's own config) handle C-hjkl.
  if not os.getenv("GROVE_TERMINAL") then
    return
  end
  for dir, _ in pairs(direction_map) do
    vim.keymap.set("n", "<C-" .. dir .. ">", function()
      navigate(dir)
    end, { silent = true, desc = "Grove navigate " .. dir })
  end
end

return M
