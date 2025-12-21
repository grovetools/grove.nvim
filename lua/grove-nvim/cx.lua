-- lua/grove-nvim/cx.lua
-- Grove Context (cx) integration

local M = {}
local utils = require('grove-nvim.utils')

-- Open cx view TUI
function M.view()
  utils.run_in_float_term_tui('cx view', 'Grove Context View')
end

-- Set context to current file (!flow plan context set %)
function M.set_current_file(file_path)
  local current_file = file_path or vim.fn.expand('%:p')
  if current_file == '' then
    vim.notify('Grove: No file in current buffer', vim.log.levels.ERROR)
    return
  end

  -- Debug: show the full path being used
  vim.notify('Grove: Setting context for: ' .. current_file, vim.log.levels.INFO)

  utils.run_in_float_term_tui('flow plan context set ' .. vim.fn.shellescape(current_file), 'Grove Set Context')
end

-- Open cx rules TUI selector
function M.rules()
  utils.run_in_float_term_tui('cx rules', 'Grove Rules', function()
    -- Update status bar after cx rules completes
    -- Add delay to allow cx to finish writing its state
    vim.defer_fn(function()
      vim.api.nvim_exec_autocmds('User', { pattern = 'GroveRulesChanged', modeline = false })
    end, 500)
  end)
end

return M
