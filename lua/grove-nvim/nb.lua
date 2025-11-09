-- lua/grove-nvim/nb.lua
-- Grove Notebook (nb) integration

local M = {}
local utils = require("grove-nvim.utils")

-- Open nb browser TUI in a side panel
function M.browse()
	utils.run_in_side_term_tui("nb tui", "Notebook Browser")
end

return M
