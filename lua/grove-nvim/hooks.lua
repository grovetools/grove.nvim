-- lua/grove-nvim/hooks.lua
-- Grove Hooks integration

local M = {}
local utils = require('grove-nvim.utils')

-- Open grove-hooks sessions browse TUI
function M.sessions_browse()
  utils.run_in_float_term_tui('grove-hooks sessions browse', 'Grove Hooks Sessions')
end

return M
