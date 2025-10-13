-- lua/grove-nvim/watcher.lua
-- File watcher for automatic updates.

local M = {}
local utils = require("grove-nvim.utils")
local marks = require("grove-nvim.marks")
local marks_float = require("grove-nvim.marks_float")

local poll_handle

-- Debounced refresh function
local debounced_refresh = utils.debounce(200, function()
	marks.sync_marks_to_rules()
	marks_float.refresh()
end)

function M.start()
	local marks_path = vim.fn.getcwd() .. "/.grove/marks"

	-- Stop any existing watcher
	if poll_handle then
		poll_handle:stop()
		poll_handle = nil
	end

	-- Check if file exists before starting watcher
	if vim.fn.filereadable(marks_path) == 0 then
		-- Create the directory if it doesn't exist
		vim.fn.mkdir(vim.fn.fnamemodify(marks_path, ":h"), "p")
		-- Don't start polling yet, wait for file to be created
		return
	end

	-- Start polling the marks file
	poll_handle = vim.loop.new_fs_poll()
	poll_handle:start(
		marks_path,
		1000,
		vim.schedule_wrap(function(err, prev, curr)
			if err then
				return
			end
			-- On change, trigger debounced refresh
			if prev and curr and (prev.mtime.sec ~= curr.mtime.sec or prev.mtime.nsec ~= curr.mtime.nsec) then
				debounced_refresh()
			end
		end)
	)

	-- Create a custom User autocommand to centralize updates
	vim.api.nvim_create_autocmd("User", {
		pattern = "GroveMarksChanged",
		callback = function()
			marks_float.refresh()
		end,
	})
end

function M.stop()
	if poll_handle then
		poll_handle:stop()
		poll_handle = nil
	end
end

-- Setup autocommands to start/stop watcher on entering/leaving Neovim
vim.api.nvim_create_autocmd("VimEnter", {
	pattern = "*",
	callback = M.start,
})

vim.api.nvim_create_autocmd("VimLeave", {
	pattern = "*",
	callback = M.stop,
})

return M
