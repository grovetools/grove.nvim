-- lua/grove-nvim/marks_float.lua
-- Manages the persistent floating window for Grove marks.

local M = {}
local api = vim.api
local utils = require("grove-nvim.utils")
local marks = require("grove-nvim.marks")

local state = {
	win = nil,
	buf = nil,
	is_visible = false,
}

local function get_marks_stats()
	local marked_files = marks.get_marks()
	local count = 0
	local total_tokens = 0

	-- Quick token estimation: ~4 chars per token
	for _, path in pairs(marked_files) do
		count = count + 1
		local size = vim.fn.getfsize(path)
		if size > 0 then
			-- Rough estimate: divide bytes by 4 for tokens
			total_tokens = total_tokens + math.floor(size / 4)
		end
	end
	return count, total_tokens
end

local function render()
	if not state.buf or not api.nvim_buf_is_valid(state.buf) then
		return
	end

	local marked_files = marks.get_marks()
	local lines = {}
	local max_line_length = 0
	local max_display = 7

	local keys = {}
	for k in pairs(marked_files) do
		table.insert(keys, k)
	end
	table.sort(keys)

	for i, key in ipairs(keys) do
		if i > max_display then
			break
		end
		local path = marked_files[key]
		local filename = vim.fn.fnamemodify(path, ":t")
		local line = string.format("%d %s", key, filename)
		table.insert(lines, line)
		max_line_length = math.max(max_line_length, #line)
	end

	if #keys > max_display then
		table.insert(lines, string.format("... and %d more", #keys - max_display))
	end

	local mark_count, total_tokens = get_marks_stats()
	if mark_count > 0 then
		table.insert(lines, "")
		-- Format tokens with k/M suffix
		local token_str
		if total_tokens < 1000 then
			token_str = string.format("%d", total_tokens)
		elseif total_tokens < 1000000 then
			token_str = string.format("%.1fk", total_tokens / 1000)
		else
			token_str = string.format("%.1fM", total_tokens / 1000000)
		end
		local stats_line = string.format("%s tokens • %d", token_str, mark_count)
		table.insert(lines, stats_line)
		max_line_length = math.max(max_line_length, #stats_line)
	end

	api.nvim_buf_set_option(state.buf, "modifiable", true)
	api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	api.nvim_buf_set_option(state.buf, "modifiable", false)

	-- Resize window based on content
	local width = math.max(max_line_length + 2, 15)
	local height = math.max(#lines, 1) -- Ensure height is at least 1
	if state.win and api.nvim_win_is_valid(state.win) then
		-- Get offset accounting for statusline and status bar
		local status_bar = require("grove-nvim.status_bar")
		local bottom_offset = status_bar.get_bottom_offset()

		api.nvim_win_set_config(state.win, {
			relative = "editor",
			width = width,
			height = height,
			col = vim.o.columns - width - 2,
			row = vim.o.lines - height - bottom_offset - 2,
		})
	end
end

function M.show()
	if state.win and api.nvim_win_is_valid(state.win) then
		render()
		return
	end

	state.buf = api.nvim_create_buf(false, true)
	api.nvim_buf_set_name(state.buf, "GroveMarksFloat")

	-- Get offset accounting for statusline and status bar
	local status_bar = require("grove-nvim.status_bar")
	local bottom_offset = status_bar.get_bottom_offset()

	local width, height = 20, 5
	state.win = api.nvim_open_win(state.buf, false, {
		relative = "editor",
		width = width,
		height = height,
		col = vim.o.columns - width - 2,
		row = vim.o.lines - height - bottom_offset - 2,
		style = "minimal",
		border = "rounded",
		focusable = false,
		title = " Grove Marks ",
		title_pos = "center",
	})

	vim.wo[state.win].winhighlight = "Normal:Normal,FloatBorder:FloatBorder"
	state.is_visible = true
	render()
end

function M.hide()
	if state.win and api.nvim_win_is_valid(state.win) then
		api.nvim_win_close(state.win, true)
	end
	if state.buf and api.nvim_buf_is_valid(state.buf) then
		api.nvim_buf_delete(state.buf, { force = true })
	end
	state.win, state.buf, state.is_visible = nil, nil, false
end

function M.toggle()
	if state.is_visible then
		M.hide()
	else
		M.show()
	end
end

function M.refresh()
	if state.is_visible then
		render()
	end
end

return M
