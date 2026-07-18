-- grove-nvim.navigator
--
-- Spatial navigation for grove terminal hosts: Ctrl+h/j/k/l move between vim
-- windows normally, but when at a window edge inside a host that understands the
-- OSC 777 navigate protocol (groveterm AND tuimux/treemux), emit an
-- OSC 777;navigate;{h,j,k,l} sequence so the host can move focus to an adjacent
-- pane. Outside such a host, falls back to plain wincmd (and lets
-- vim-tmux-navigator own C-hjkl under tmux).

local M = {}

local direction_map = {
  h = "h",
  j = "j",
  k = "k",
  l = "l",
}

-- Environment markers set by grove terminal hosts. Any of these means the host
-- parses OSC 777 navigate sequences out of the pane's output stream:
--   GROVE_TERMINAL — groveterm and daemon-spawned agent panes
--   TUIMUX_PTY     — every tuimux/treemux PTY pane (daemon- and locally-backed)
--   GROVE_PTY      — daemon-owned PTY panes
local host_markers = { "GROVE_TERMINAL", "TUIMUX_PTY", "GROVE_PTY" }

--- Report whether we are running inside a grove terminal host that understands
--- the OSC 777 navigate protocol.
---@return boolean
local function in_grove_host()
  for _, name in ipairs(host_markers) do
    if os.getenv(name) then
      return true
    end
  end
  return false
end

M.in_grove_host = in_grove_host

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
  if at_edge(dir) and in_grove_host() then
    osc_navigate(dir)
  else
    vim.cmd("wincmd " .. dir)
  end
end

function M.setup()
  -- Only install our keymaps inside a grove terminal host (groveterm or
  -- tuimux/treemux). Under tmux, let vim-tmux-navigator (or the user's own
  -- config) own C-hjkl.
  if not in_grove_host() then
    return
  end
  for dir, _ in pairs(direction_map) do
    vim.keymap.set("n", "<C-" .. dir .. ">", function()
      navigate(dir)
    end, { silent = true, desc = "Grove navigate " .. dir })
  end
end

return M
