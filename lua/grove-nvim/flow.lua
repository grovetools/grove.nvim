-- lua/grove-nvim/flow.lua
-- Grove Flow (plan management) integration

local M = {}
local utils = require('grove-nvim.utils')
local data = require('grove-nvim.data')

-- Initialize a new plan
function M.init()
  -- The `flow plan init` command now provides an interactive TUI for all options.
  utils.run_in_float_term_tui('flow plan init', 'Initialize New Plan')
end

-- Show plan status in a floating terminal
function M.status(plan_path)
  if not plan_path then
    vim.notify('Grove: No plan path provided.', vim.log.levels.ERROR)
    return
  end
  utils.run_in_float_term('grove-nvim plan status ' .. vim.fn.shellescape(plan_path))
end

-- Run a plan
function M.run(plan_path)
  if not plan_path then
    vim.notify('Grove: No plan path provided.', vim.log.levels.ERROR)
    return
  end
  vim.notify('Grove: Running plan ' .. plan_path .. '...', vim.log.levels.INFO)
  utils.run_in_float_term('grove-nvim plan run ' .. vim.fn.shellescape(plan_path))
end

-- Create the plan picker by launching the flow TUI
function M.picker()
  -- The `flow plan tui` command provides the canonical plan picker.
  M.open_plan_tui()
end

-- Extract content from current buffer and create a new plan
function M.extract_from_buffer()
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path == '' or buf_path == nil then
    vim.notify("Grove: No file name for the current buffer.", vim.log.levels.ERROR)
    return
  end

  -- The `flow plan init` TUI handles extraction.
  local cmd = 'grove-nvim plan init --extract-all-from ' .. vim.fn.shellescape(buf_path)
  utils.run_in_float_term_tui(cmd, 'Initialize Plan from Buffer')
end

-- Add job wizard - interactive job creation with TUI
function M.add_job_wizard(plan_path)
  M.add_job_tui(plan_path)
end

-- Add job to active plan using TUI
function M.add_job_to_active_plan()
  local active_plan = data.get_active_plan()
  if not active_plan then
    vim.notify("Grove: No active plan found. Use 'flow plan set <plan>' to set one.", vim.log.levels.ERROR)
    return
  end

  M.add_job_tui(active_plan)
end

-- Add job to plan using TUI
function M.add_job_tui(plan_path)
  if not plan_path then
    plan_path = data.get_active_plan()
    if not plan_path then
      vim.notify("Grove: No active plan found. Use 'flow plan set <plan>' to set one.", vim.log.levels.ERROR)
      return
    end
  end

  utils.run_in_float_term_tui('grove-nvim plan add ' .. vim.fn.shellescape(plan_path), 'Grove Add Job')
end

-- Open plan TUI (shows all plans)
function M.open_plan_tui()
  utils.run_in_float_term_tui('flow plan tui', 'Grove Plans')
end

-- Open plan status TUI for active plan
function M.open_status_tui(plan_path)
  if not plan_path then
    plan_path = data.get_active_plan()
    if not plan_path then
      vim.notify("Grove: No active plan found. Use 'flow plan set <plan>' to set one.", vim.log.levels.ERROR)
      return
    end
  end

  utils.run_in_float_term_tui('flow plan status -t ' .. vim.fn.shellescape(plan_path), 'Grove Plan Status')
end

return M
