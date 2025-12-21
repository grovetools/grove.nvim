-- lua/grove-nvim/chat_prompt_ui.lua
-- Renders a virtual text prompt for new user turns in Grove chat files.

local M = {}
local api = vim.api
local utils = require("grove-nvim.utils")
local config = require("grove-nvim.config")

local ns_id = api.nvim_create_namespace("grove_chat_prompt_ui")
local debounced_update = nil

-- Renders virtual text prompt for empty user turns.
local function update(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	if not api.nvim_buf_is_valid(bufnr) or not vim.b[bufnr].grove_chat_prompt_enabled then
		return
	end

	-- Check if chat placeholder is disabled in config
	if not config.options.ui.chat_placeholder.enable then
		return
	end

	api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- Find the line number of the last user turn
	local last_user_turn_line_nr = -1
	for i = #lines, 1, -1 do
		local line = lines[i]
		local json_str = line:match("%s*<!%-%- grove: (.-) %-%->%s*")
		if json_str then
			local ok, data = pcall(vim.json.decode, json_str)
			if ok and type(data) == "table" and data.template then
				last_user_turn_line_nr = i
				break
			end
		end
	end

	if last_user_turn_line_nr == -1 then
		return -- No user turn, nothing to do.
	end

	-- Check for content after the directive
	local has_content_after_directive = false
	local prompt_line = last_user_turn_line_nr + 2

	for i = prompt_line, #lines do
		if lines[i]:match("%S") then -- Check for non-whitespace
			has_content_after_directive = true
			break
		end
	end

	-- Add a helpful prompt if there's no content yet
	if not has_content_after_directive and prompt_line <= #lines then
		local cursor_line = api.nvim_win_get_cursor(0)[1]
		local in_insert_mode = vim.fn.mode():match("^[iR]") ~= nil
		-- Only hide the prompt when actively typing on that line
		if not (in_insert_mode and cursor_line == prompt_line) then
			api.nvim_buf_set_extmark(bufnr, ns_id, prompt_line - 1, 0, {
				virt_text = { { "Start typing here...", "Comment" } },
				virt_text_pos = "overlay",
			})
		end
	end
end

--- Sets up autocommands and highlighting for the current buffer.
function M.setup(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()

	-- Check if already enabled for this buffer
	if vim.b[bufnr].grove_chat_prompt_enabled then
		return
	end

	vim.b[bufnr].grove_chat_prompt_enabled = true

	if not debounced_update then
		debounced_update = utils.debounce(500, update)
	end

	-- Create buffer-local autocommand group
	local group = api.nvim_create_augroup("GroveChatPromptUIRender_" .. bufnr, { clear = true })
	api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI", "CursorMoved", "CursorMovedI" }, {
		group = group,
		buffer = bufnr,
		callback = function()
			debounced_update(bufnr)
		end,
	})

	-- Immediate update on InsertEnter to hide prompt instantly when starting to type
	api.nvim_create_autocmd("InsertEnter", {
		group = group,
		buffer = bufnr,
		callback = function()
			update(bufnr)
		end,
	})

	-- Initial render
	update(bufnr)
end

return M
