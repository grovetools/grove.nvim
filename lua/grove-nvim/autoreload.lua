-- lua/grove-nvim/autoreload.lua
-- Keep open buffers in sync with external changes (agents, nb sync, flow jobs
-- rewriting files on disk). 'autoread' + checktime only fires on user events
-- like FocusGained, which terminal nvim inside tuimux/treemux panes rarely
-- receives, so a repeating timer polls checktime as well.

local M = {}

local uv = vim.uv or vim.loop
local config = require("grove-nvim.config")

local timer

local function checktime()
	-- checktime is disallowed while the cmdline is open (E11) and pointless
	-- in prompt/terminal-insert states; silent! swallows the rest (E523).
	local mode = vim.api.nvim_get_mode().mode
	if mode:match("^[ct]") or vim.fn.getcmdwintype() ~= "" then
		return
	end
	vim.cmd("silent! checktime")
end

function M.start()
	local opts = config.options.autoreload
	if not opts.enable or timer then
		return
	end

	vim.o.autoread = true

	local group = vim.api.nvim_create_augroup("GroveAutoreload", { clear = true })
	vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
		group = group,
		callback = checktime,
		desc = "grove: pick up external file changes",
	})
	if opts.notify then
		vim.api.nvim_create_autocmd("FileChangedShellPost", {
			group = group,
			callback = function(ev)
				vim.notify("Reloaded " .. vim.fn.fnamemodify(ev.file, ":~:."), vim.log.levels.INFO)
			end,
			desc = "grove: announce externally reloaded buffers",
		})
	end

	timer = uv.new_timer()
	timer:start(opts.interval_ms, opts.interval_ms, vim.schedule_wrap(checktime))
end

function M.stop()
	if timer then
		timer:stop()
		timer:close()
		timer = nil
	end
	pcall(vim.api.nvim_del_augroup_by_name, "GroveAutoreload")
end

vim.api.nvim_create_autocmd("VimEnter", {
	pattern = "*",
	callback = M.start,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
	pattern = "*",
	callback = M.stop,
})

return M
