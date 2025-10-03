-- lua/grove-nvim/gmux.lua
-- Grove Tmux (gmux) integration

local M = {}
local utils = require('grove-nvim.utils')

-- Open gmux sessionize TUI
function M.sessionize()
  utils.run_in_float_term_tui('gmux sz', 'Grove Sessionize')
end

-- Open gmux key manage TUI
function M.keymap()
  utils.run_in_float_term_tui('gmux km', 'Gmux Key Manage')
end

return M
