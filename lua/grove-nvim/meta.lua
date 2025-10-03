-- lua/grove-nvim/meta.lua
-- Grove Meta (workspace management, release, config) integration

local M = {}
local utils = require('grove-nvim.utils')

-- Open grove workspace status
function M.workspace_status()
  utils.run_in_float_term_output('grove ws status --cols git,release')
end

-- Open grove workspace plans list
function M.workspace_plans_list()
  utils.run_in_float_term_output('grove ws plans list --table')
end

-- Open grove release TUI
function M.release_tui()
  utils.run_in_float_term_tui('grove release tui', 'Grove Release')
end

-- Open grove logs TUI
function M.logs_tui()
  utils.run_in_float_term_tui('grove logs -i', 'Grove Logs')
end

-- Open grove config analyze TUI
function M.config_analyze_tui()
  utils.run_in_float_term_tui('grove config analyze --tui', 'Grove Config Analyze')
end

return M
