-- lua/grove-nvim/chat_stats_ui.lua
-- Renders virtual text with token count for Grove chat files.

local M = {}
local api = vim.api
local utils = require("grove-nvim.utils")

local ns_id = api.nvim_create_namespace("grove_chat_stats_ui")
local debounced_update = nil

-- Formats a number into a compact string (e.g., 1234 -> 1.2k)
local function format_tokens(num)
	if not num then
		return "0"
	end
	if num < 1000 then
		return tostring(num)
	end
	if num < 1000000 then
		return string.format("%.1fk", num / 1000)
	end
	return string.format("%.1fM", num / 1000000)
end

-- Fetches stats and renders virtual text.
local function update(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	if not api.nvim_buf_is_valid(bufnr) or not vim.b[bufnr].grove_chat_stats_enabled then
		return
	end

	-- Clear old virtual text first
	api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- Find the line number of the last user turn (a grove directive with a "template" key)
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

	-- If no user turn directive found, this might be the first turn
	-- Place the virtual text at the end of the file or after frontmatter
	if last_user_turn_line_nr == -1 then
		-- Find the end of frontmatter (second "---")
		local frontmatter_end = -1
		local found_first_delimiter = false
		for i, line in ipairs(lines) do
			if line:match("^%-%-%-$") then
				if not found_first_delimiter then
					found_first_delimiter = true
				else
					frontmatter_end = i
					break
				end
			end
		end

		-- Place virtual text after frontmatter or at the end
		if frontmatter_end > 0 then
			last_user_turn_line_nr = frontmatter_end
		else
			-- No frontmatter found, use last line
			last_user_turn_line_nr = #lines
		end
	end

	local buf_path = api.nvim_buf_get_name(bufnr)
	if buf_path == "" then
		return
	end

	local cx_path = vim.fn.exepath("cx")
	if cx_path == "" then
		return
	end

	-- Call cx stats asynchronously
	local cmd = { cx_path, "stats", "--chat-file", buf_path }
	utils.run_command(cmd, function(stdout, stderr, exit_code)
		if exit_code ~= 0 or stdout == "" then
			-- Don't show error notifications for transient failures
			return
		end

		local ok, stats = pcall(vim.json.decode, stdout)
		if not ok or not stats then
			return
		end

		vim.schedule(function()
			if not api.nvim_buf_is_valid(bufnr) then
				return
			end
			local virt_text = { { "~" .. format_tokens(stats.total_tokens) .. " tokens", "Comment" } }
			api.nvim_buf_set_extmark(bufnr, ns_id, last_user_turn_line_nr - 1, 0, {
				virt_text = virt_text,
				virt_text_pos = "eol",
			})

			-- Check if this is a new/empty chat (no content after the directive)
			local has_content_after_directive = false
			local first_line_after_directive = last_user_turn_line_nr + 1
			for i = first_line_after_directive, #lines do
				if lines[i]:match("%S") then -- Check for non-whitespace
					has_content_after_directive = true
					break
				end
			end

			-- Add a helpful prompt if there's no content yet
			-- Use virt_text on the empty line (which is writable)
			if not has_content_after_directive and first_line_after_directive <= #lines then
				-- Check if we're not on that line (cursor position)
				local cursor_line = api.nvim_win_get_cursor(0)[1]
				if cursor_line ~= first_line_after_directive then
					api.nvim_buf_set_extmark(bufnr, ns_id, first_line_after_directive - 1, 0, {
						virt_text = { { "Start typing your question here...", "Comment" } },
						virt_text_pos = "overlay",
					})
				end
			end
		end)
	end)
end

--- Sets up autocommands and highlighting for the current buffer.
function M.setup(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()

	-- Check if already enabled for this buffer
	if vim.b[bufnr].grove_chat_stats_enabled then
		return
	end

	vim.b[bufnr].grove_chat_stats_enabled = true

	if not debounced_update then
		debounced_update = utils.debounce(500, update)
	end

	-- Create buffer-local autocommand group
	local group = api.nvim_create_augroup("GroveChatStatsUIRender_" .. bufnr, { clear = true })
	api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI", "CursorMoved", "CursorMovedI" }, {
		group = group,
		buffer = bufnr,
		callback = function()
			debounced_update(bufnr)
		end,
	})

	-- Initial render
	update(bufnr)
end

return M
