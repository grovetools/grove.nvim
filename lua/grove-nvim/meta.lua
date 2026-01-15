-- lua/grove-nvim/meta.lua
-- Grove Meta (release, logs) integration

local M = {}
local utils = require('grove-nvim.utils')

-- Open grove release TUI
function M.release_tui()
  utils.run_in_float_term_tui('grove release tui', 'Grove Release')
end

-- Open grove logs TUI
function M.logs_tui()
  utils.run_in_float_term_tui('grove logs -i', 'Grove Logs')
end

return M
