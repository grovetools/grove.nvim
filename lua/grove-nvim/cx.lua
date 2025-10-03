-- lua/grove-nvim/cx.lua
-- Grove Context (cx) integration

local M = {}
local utils = require('grove-nvim.utils')

-- Open cx view TUI
function M.view()
  utils.run_in_float_term_tui('cx view', 'Grove Context View')
end

return M
