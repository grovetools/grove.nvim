-- lua/grove-nvim/marks.lua
-- Manages marked files and synchronization with grove-context rules.

local M = {}

local MARKS_FILE = ".grove/marks"
local RULES_FILE = ".grove/rules"
local MARKS_MARKER_START = "# GROVE:MARKS:START - Managed by grove-nvim, do not edit."
local MARKS_MARKER_END = "# GROVE:MARKS:END"

local marks = {} -- In-memory cache of marked files

--- Reads and parses the .grove/marks file into the in-memory table.
-- @return table marks_table, boolean success
local function read_marks()
	local marks_path = vim.fn.getcwd() .. "/" .. MARKS_FILE
	if vim.fn.filereadable(marks_path) == 0 then
		marks = {}
		return {}, true
	end

	local lines = vim.fn.readfile(marks_path)
	local new_marks = {}
	for _, line in ipairs(lines) do
		local num, path = line:match("^@(%d+)%s+(.+)$")
		if num and path then
			new_marks[tonumber(num)] = path
		end
	end
	marks = new_marks
	return new_marks, true
end

--- Writes the in-memory marks table to the .grove/marks file.
local function write_marks()
	local marks_path = vim.fn.getcwd() .. "/" .. MARKS_FILE
	vim.fn.mkdir(vim.fn.fnamemodify(marks_path, ":h"), "p")

	local lines = {}
	local keys = {}
	for k in pairs(marks) do
		table.insert(keys, k)
	end
	table.sort(keys)

	for _, k in ipairs(keys) do
		table.insert(lines, string.format("@%d %s", k, marks[k]))
	end

	vim.fn.writefile(lines, marks_path)
end

--- Synchronizes the contents of .grove/marks into .grove/rules.
function M.sync_marks_to_rules()
	read_marks()
	local rules_path = vim.fn.getcwd() .. "/" .. RULES_FILE

	-- Read existing rules, creating the file if it doesn't exist.
	local rules_lines = {}
	if vim.fn.filereadable(rules_path) == 1 then
		rules_lines = vim.fn.readfile(rules_path)
	end

	-- Find and remove the existing managed block
	local new_rules_lines = {}
	local in_marks_block = false
	for _, line in ipairs(rules_lines) do
		if line == MARKS_MARKER_START then
			in_marks_block = true
		elseif line == MARKS_MARKER_END then
			in_marks_block = false
		elseif not in_marks_block then
			table.insert(new_rules_lines, line)
		end
	end

	-- Add the new managed block if there are marks
	if next(marks) ~= nil then
		table.insert(new_rules_lines, MARKS_MARKER_START)
		local keys = {}
		for k in pairs(marks) do
			table.insert(keys, k)
		end
		table.sort(keys)
		for _, k in ipairs(keys) do
			table.insert(new_rules_lines, marks[k])
		end
		table.insert(new_rules_lines, MARKS_MARKER_END)
	end

	vim.fn.writefile(new_rules_lines, rules_path)
	vim.api.nvim_exec_autocmds("User", { pattern = "GroveMarksChanged" })
end

--- Adds a file to the marks list.
-- @param path string The file path to add.
function M.add_file(path)
	read_marks()
	-- Check if already present
	for _, existing_path in pairs(marks) do
		if existing_path == path then
			vim.notify("Grove: File already marked.", vim.log.levels.INFO)
			return
		end
	end

	-- Find next available mark slot
	local next_key = 1
	while marks[next_key] do
		next_key = next_key + 1
	end

	marks[next_key] = path
	write_marks()
	M.sync_marks_to_rules()
	vim.notify(
		string.format("Grove: Marked '%s' at position %d", vim.fn.fnamemodify(path, ":t"), next_key),
		vim.log.levels.INFO
	)
end

--- Removes a file from the marks list.
-- @param path string The file path to remove.
function M.remove_file(path)
	read_marks()
	local key_to_remove = nil
	for k, v in pairs(marks) do
		if v == path then
			key_to_remove = k
			break
		end
	end

	if key_to_remove then
		marks[key_to_remove] = nil
		write_marks()
		M.sync_marks_to_rules()
		vim.notify("Grove: Unmarked file.", vim.log.levels.INFO)
	else
		vim.notify("Grove: File not marked.", vim.log.levels.WARN)
	end
end

--- Clears all marks.
function M.clear()
	marks = {}
	write_marks()
	M.sync_marks_to_rules()
	vim.notify("Grove: Cleared all marks.", vim.log.levels.INFO)
end

--- Opens the file associated with a mark.
-- @param num number The mark number.
function M.go_to(num)
	read_marks()
	local path = marks[num]
	if path then
		vim.cmd("edit " .. vim.fn.fnameescape(path))
	else
		vim.notify("Grove: No mark at position " .. num, vim.log.levels.WARN)
	end
end

--- Goes to the next file in the list.
function M.next()
	read_marks()
	local keys = {}
	for k in pairs(marks) do
		table.insert(keys, k)
	end
	if #keys == 0 then
		return
	end
	table.sort(keys)

	local current_path = vim.fn.expand("%:p")
	local current_idx = -1
	for i, k in ipairs(keys) do
		if vim.fn.expand("%:p") == vim.fn.fnamemodify(marks[k], ":p") then
			current_idx = i
			break
		end
	end

	local next_idx = (current_idx % #keys) + 1
	M.go_to(keys[next_idx])
end

--- Goes to the previous file in the list.
function M.previous()
	read_marks()
	local keys = {}
	for k in pairs(marks) do
		table.insert(keys, k)
	end
	if #keys == 0 then
		return
	end
	table.sort(keys)

	local current_path = vim.fn.expand("%:p")
	local current_idx = -1
	for i, k in ipairs(keys) do
		if vim.fn.expand("%:p") == vim.fn.fnamemodify(marks[k], ":p") then
			current_idx = i
			break
		end
	end

	local prev_idx = current_idx - 1
	if prev_idx < 1 then
		prev_idx = #keys
	end
	M.go_to(keys[prev_idx])
end

function M.get_marks()
	read_marks()
	return marks
end

--- Opens an editable menu for managing marks.
function M.open_menu()
	read_marks()
	local marks_path = vim.fn.getcwd() .. "/" .. MARKS_FILE

	-- Open the marks file in a floating window
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.6)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	-- Create a scratch buffer for editing
	local buf = vim.api.nvim_create_buf(false, true)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Grove Marks (line position = mark number) ",
		title_pos = "center",
	})

	-- Extract just the file paths in order
	local paths = {}
	local keys = {}
	for k in pairs(marks) do
		table.insert(keys, k)
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		table.insert(paths, marks[k])
	end

	-- Set buffer content (just paths, no @N prefix)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, paths)

	-- Set filetype for syntax highlighting
	vim.bo[buf].filetype = "groverules"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].buftype = "acwrite"

	-- Buffer-local keymaps
	vim.keymap.set("n", "<CR>", function()
		M.goto_from_menu(win, buf)
	end, { buffer = buf, silent = true, desc = "Go to marked file" })
	vim.keymap.set("n", "q", function()
		M.save_and_close_menu(buf, marks_path, win)
	end, { buffer = buf, silent = true, desc = "Save and close" })
	vim.keymap.set("n", "<Esc>", function()
		M.save_and_close_menu(buf, marks_path, win)
	end, { buffer = buf, silent = true, desc = "Save and close" })
	for i = 1, 9 do
		vim.keymap.set("n", tostring(i), function()
			M.go_to(i)
			vim.api.nvim_win_close(win, true)
		end, { buffer = buf, silent = true, desc = "Go to mark " .. i })
	end

	-- Autocommand to save on write
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		callback = function()
			M.save_menu_contents(buf, marks_path)
		end,
	})
end

--- Saves the menu contents, assigning mark numbers based on line position
function M.save_menu_contents(buf, marks_path)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	-- Filter out empty lines and build new marks table
	marks = {}
	local line_num = 1
	for _, line in ipairs(lines) do
		local trimmed = vim.trim(line)
		-- Remove @N prefix if user added it
		local path = trimmed:match("^@%d+%s+(.+)$") or trimmed
		if path ~= "" then
			marks[line_num] = path
			line_num = line_num + 1
		end
	end

	-- Write to .grove/marks file
	vim.fn.mkdir(vim.fn.fnamemodify(marks_path, ":h"), "p")
	write_marks()
	M.sync_marks_to_rules()
	vim.bo[buf].modified = false
	vim.notify("Grove: Marks saved", vim.log.levels.INFO)
end

--- Saves and closes the menu
function M.save_and_close_menu(buf, marks_path, win)
	M.save_menu_contents(buf, marks_path)
	if vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

--- Goes to the file on the current line in the marks menu.
function M.goto_from_menu(win, buf)
	local line = vim.api.nvim_get_current_line()
	local path = vim.trim(line)
	-- Remove @N prefix if present
	path = path:match("^@%d+%s+(.+)$") or path

	if path ~= "" then
		-- Save before going to file
		M.save_menu_contents(buf, vim.fn.getcwd() .. "/" .. MARKS_FILE)
		vim.api.nvim_win_close(win, true)
		vim.cmd("edit " .. vim.fn.fnameescape(path))
	end
end

return M
