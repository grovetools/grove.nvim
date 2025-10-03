-- lua/grove-nvim/nb.lua
-- Grove Notebook (nb) integration

local M = {}
local utils = require('grove-nvim.utils')

-- Open nb manage TUI
function M.manage()
  utils.run_in_float_term_tui('nb manage', 'NB Manage')
end

return M
