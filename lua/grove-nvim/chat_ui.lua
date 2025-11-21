-- lua/grove-nvim/chat_ui.lua
-- Renders virtual dividers for Grove chat directives in markdown.

local M = {}
local api = vim.api
local utils = require("grove-nvim.utils")

local ns_id = api.nvim_create_namespace("grove_chat_ui")
local debounced_update = nil

-- Icon constants (matching grove-core/tui/theme/icons.go)
local NERD_ICON_CHAT_QUESTION = "󱜸" -- md-chat_question (U+F1738)
local NERD_ICON_ROBOT = "󰚩" -- md-robot (U+F06A9)

local ASCII_ICON_CHAT_QUESTION = "[?]"
local ASCII_ICON_ROBOT = "[R]"

-- Detect which icon set to use
local function get_icons()
	-- Check environment variable first
	if os.getenv("GROVE_ICONS") == "ascii" then
		return {
			user = ASCII_ICON_CHAT_QUESTION,
			llm = ASCII_ICON_ROBOT,
		}
	end

	-- Check if nerd font is available (common Neovim convention)
	if vim.g.have_nerd_font == false then
		return {
			user = ASCII_ICON_CHAT_QUESTION,
			llm = ASCII_ICON_ROBOT,
		}
	end

	-- Default to nerd font icons
	return {
		user = NERD_ICON_CHAT_QUESTION,
		llm = NERD_ICON_ROBOT,
	}
end

--- Fetches chat directives and renders virtual dividers.
local function update(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	-- Only run if buffer is valid and the feature is enabled for it
	if not api.nvim_buf_is_valid(bufnr) or not vim.b[bufnr].grove_chat_ui_enabled then
		return
	end

	-- Clear old dividers before redrawing
	api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local win_width = api.nvim_win_get_width(0) -- Use current window width for sizing
	local icons = get_icons()

	for i, line in ipairs(lines) do
		-- Capture the JSON content inside the grove directive
		local json_str = line:match("%s*<!%-%- grove: (.-) %-%->%s*")
		if json_str then
			local ok, data = pcall(vim.json.decode, json_str)
			if ok and type(data) == "table" then
				local virt_line = {}
				local title = ""
				local hl_group = "GroveChatDivider"
				local icon = ""

				if data.template then
					title = "User Turn"
					icon = icons.user
					hl_group = "GroveChatUserTurn"
				elseif data.id then
					title = "LLM Response"
					icon = icons.llm
					hl_group = "GroveChatLLMTurn"
				end

				if title ~= "" then
					local display_text = " " .. icon .. " " .. title .. " "
					local text_width = vim.fn.strdisplaywidth(display_text)
					local total_padding = win_width - text_width
					local padding_char = "─"

					-- Ensure padding is not negative if window is too small
					if total_padding > 0 then
						local left_padding_len = math.floor(total_padding / 2)
						local right_padding_len = total_padding - left_padding_len

						local left_padding = string.rep(padding_char, left_padding_len)
						local right_padding = string.rep(padding_char, right_padding_len)

						virt_line = {
							{ left_padding, "GroveChatDivider" },
							{ display_text, hl_group },
							{ right_padding, "GroveChatDivider" },
						}
					else
						-- Fallback for very narrow windows
						virt_line = { { display_text, hl_group } }
					end

					-- Set the extmark to hide the original line and display our virtual line above it
					api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
						virt_lines = { virt_line },
						virt_lines_above = true,
						virt_text_hide = true,
					})
				end
			end
		end
	end
end

--- Sets up autocommands and highlighting for the current buffer.
function M.setup(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	vim.b[bufnr].grove_chat_ui_enabled = true

	-- Define highlight groups, linking to standard groups for theme compatibility
	vim.cmd("highlight default link GroveChatDivider Comment")
	vim.cmd("highlight default link GroveChatUserTurn Title")
	vim.cmd("highlight default link GroveChatLLMTurn Constant")

	if not debounced_update then
		debounced_update = utils.debounce(200, update)
	end

	-- Create autocommands to redraw dividers on changes
	local group = api.nvim_create_augroup("GroveChatUIRender", { clear = true })
	api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI", "WinResized" }, {
		group = group,
		buffer = bufnr,
		callback = function()
			debounced_update(bufnr)
		end,
	})

	-- Initial render
	update(bufnr)
end

--- Clears virtual text and autocommands for the buffer.
function M.clear(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	vim.b[bufnr].grove_chat_ui_enabled = false
	api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
	pcall(api.nvim_del_augroup_by_name, "GroveChatUIRender") -- Use pcall for safety
	vim.notify("Grove Chat UI disabled for this buffer.", vim.log.levels.INFO)
end

--- Toggles the chat UI display on or off for the current buffer.
function M.toggle(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	if vim.b[bufnr].grove_chat_ui_enabled then
		M.clear(bufnr)
	else
		M.setup(bufnr)
		vim.notify("Grove Chat UI enabled for this buffer.", vim.log.levels.INFO)
	end
end

return M
