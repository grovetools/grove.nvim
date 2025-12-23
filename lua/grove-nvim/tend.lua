-- lua/grove-nvim/tend.lua
-- Logic for running tend tests from Neovim.

local M = {}
local utils = require("grove-nvim.utils")
local config = require("grove-nvim.config")

--- Runs the tend test for the scenario name under the cursor.
function M.run_test_under_cursor()
	-- Use <cWORD> to correctly capture names with hyphens.
	local scenario_name = vim.fn.expand("<cWORD>")

	if scenario_name == "" then
		vim.notify("Grove: No scenario name under cursor.", vim.log.levels.WARN)
		return
	end

	-- Strip surrounding quotes and trailing punctuation (e.g., "name", or 'name',)
	-- This handles Go string literals like Name: "scenario-name",
	scenario_name = scenario_name:gsub('^["\']', ''):gsub('["\']%s*,?%s*$', '')

	if scenario_name == "" then
		vim.notify("Grove: No scenario name under cursor.", vim.log.levels.WARN)
		return
	end

	-- Retrieve the command template from the configuration.
	local command_template = config.options.test_runner.command_template
	local final_command = string.format(command_template, scenario_name)

	vim.notify("Grove: Running test: " .. final_command, vim.log.levels.INFO)

	-- Execute in a floating output window. `tend run --debug-session` is not
	-- interactive; it prints setup information and exits. This utility will
	-- display that output and wait for a keypress before closing.
	utils.run_in_float_term_output(final_command)
end

return M
