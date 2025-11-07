-- Initialize the jump file watcher
require("grove-nvim.watcher")

vim.api.nvim_create_user_command("GroveChatRun", function(args)
	require("grove-nvim").chat_run(args)
end, {
	nargs = "*",
	desc = "Run Grove chat on the current note. Args: [silent] [vertical|horizontal|fullscreen]",
})

-- Plan Commands
vim.api.nvim_create_user_command("GrovePlan", function()
	require("grove-nvim.grove").picker()
end, {
	nargs = 0,
	desc = "Open the Grove Plan picker.",
})

vim.api.nvim_create_user_command("GrovePlanInit", function()
	require("grove-nvim.grove").init()
end, {
	nargs = 0,
	desc = "Initialize a new Grove Plan.",
})

vim.api.nvim_create_user_command("GrovePlanExtract", function()
	require("grove-nvim.grove").extract_from_buffer()
end, {
	nargs = 0,
	desc = "Initialize a Grove Plan, extracting content from the current buffer.",
})

vim.api.nvim_create_user_command("GroveAddJob", function()
	require("grove-nvim.grove").add_job_to_active_plan()
end, {
	nargs = 0,
	desc = "Add a job to the active Grove Plan.",
})

vim.api.nvim_create_user_command("GroveAddJobTUI", function()
	require("grove-nvim.grove").add_job_tui()
end, {
	nargs = 0,
	desc = "Add a job to the active Grove Plan using TUI.",
})

vim.api.nvim_create_user_command("GrovePlanTUI", function()
	require("grove-nvim.grove").open_plan_tui()
end, {
	nargs = 0,
	desc = "Open the Grove Plan TUI (all plans).",
})

vim.api.nvim_create_user_command("GrovePlanStatusTUI", function()
	require("grove-nvim.grove").open_status_tui()
end, {
	nargs = 0,
	desc = "Open the Grove Plan Status TUI for active plan.",
})

vim.api.nvim_create_user_command("GroveSessionize", function()
	require("grove-nvim.grove").open_gmux_sessionize()
end, {
	nargs = 0,
	desc = "Open Grove Sessionize (gmux sz) TUI.",
})

vim.api.nvim_create_user_command("GroveContextView", function()
	require("grove-nvim.grove").open_cx_view()
end, {
	nargs = 0,
	desc = "Open Grove Context View (cx view) TUI.",
})

vim.api.nvim_create_user_command("GroveWorkspaceStatus", function()
	require("grove-nvim.grove").open_workspace_status()
end, {
	nargs = 0,
	desc = "Open Grove Workspace Status (grove ws status).",
})

vim.api.nvim_create_user_command("GroveWorkspacePlansList", function()
	require("grove-nvim.grove").open_workspace_plans_list()
end, {
	nargs = 0,
	desc = "Open Grove Workspace Plans List (grove ws plans list --table).",
})

vim.api.nvim_create_user_command("GroveReleaseTUI", function()
	require("grove-nvim.grove").open_release_tui()
end, {
	nargs = 0,
	desc = "Open Grove Release TUI (grove release tui).",
})

vim.api.nvim_create_user_command("GroveLogsTUI", function()
	require("grove-nvim.grove").open_logs_tui()
end, {
	nargs = 0,
	desc = "Open Grove Logs TUI (grove logs -i).",
})

vim.api.nvim_create_user_command("GroveConfigAnalyzeTUI", function()
	require("grove-nvim.grove").open_config_analyze_tui()
end, {
	nargs = 0,
	desc = "Open Grove Config Analyze TUI (grove config analyze --tui).",
})

vim.api.nvim_create_user_command("GroveNBManage", function()
	require("grove-nvim.grove").open_nb_manage()
end, {
	nargs = 0,
	desc = "Open NB Manage TUI (nb manage).",
})

vim.api.nvim_create_user_command("GroveNBBrowse", function()
	require("grove-nvim.grove").open_nb_browse()
end, {
	nargs = 0,
	desc = "Open Notebook Browser TUI in a side panel (nb tui).",
})

vim.api.nvim_create_user_command("GroveHooksSessions", function()
	require("grove-nvim.grove").open_hooks_sessions_browse()
end, {
	nargs = 0,
	desc = "Open Grove Hooks Sessions Browse TUI (grove-hooks sessions browse).",
})

vim.api.nvim_create_user_command("GroveGmuxKeymap", function()
	require("grove-nvim.grove").open_gmux_keymap()
end, {
	nargs = 0,
	desc = "Open Gmux Key Manage TUI (gmux km).",
})

-- Context Commands
vim.api.nvim_create_user_command("GroveEditContext", function()
	require("grove-nvim").edit_context_rules()
end, {
	nargs = 0,
	desc = "Edit context rules (job-specific if in frontmatter, otherwise .grove/rules)",
})

vim.api.nvim_create_user_command("GroveCopyRulesWithVirtualText", function()
	require("grove-nvim.virtual_text").copy_rules_with_virtual_text()
end, {
	nargs = 0,
	desc = "Copy rules file content with virtual text to clipboard",
})

vim.api.nvim_create_user_command("GroveRules", function()
	require("grove-nvim.cx").rules()
end, {
	nargs = 0,
	desc = "Open Grove Rules selector (cx rules)",
})

vim.api.nvim_create_user_command("GroveSetContextFile", function()
	require("grove-nvim.grove").set_context_current_file()
end, {
	nargs = 0,
	desc = "Set plan context to current file (!flow plan context set %)",
})

-- Text Commands
vim.api.nvim_create_user_command("GroveSetTarget", function()
	require("grove-nvim.text").set_target_file()
end, {
	nargs = 0,
	desc = "Set the target markdown file for text interactions.",
})

vim.api.nvim_create_user_command("GroveShowTarget", function()
	require("grove-nvim.text").show_target_file()
end, {
	nargs = 0,
	desc = "Show the current target markdown file.",
})

vim.api.nvim_create_user_command("GroveText", function()
	require("grove-nvim.text").select_and_ask()
end, {
	nargs = 0,
	range = true, -- Important for visual selection
	desc = "Capture selected text and ask a question about it.",
})

vim.api.nvim_create_user_command("GroveTextRun", function()
	require("grove-nvim.text").select_ask_and_run()
end, {
	nargs = 0,
	range = true, -- Important for visual selection
	desc = "Capture selected text, ask a question, switch to target file and run chat.",
})

-- Keybindings
vim.keymap.set("n", "<leader>fp", "<cmd>GrovePlanTUI<CR>", { desc = "Grove Plan TUI" })
vim.keymap.set("n", "<leader>fpx", "<cmd>GrovePlanExtract<CR>", { desc = "Grove Plan (Extract from buffer)" })
vim.keymap.set("n", "<leader>fpp", "<cmd>GrovePlan<CR>", { desc = "Grove Plans (Picker)" })
vim.keymap.set("n", "<leader>fpl", "<cmd>GroveWorkspacePlansList<CR>", { desc = "Grove Workspace Plans List" })
vim.keymap.set("n", "<leader>fc", "<cmd>GroveChatRun<CR>", { desc = "Grove Chat Run" })
vim.keymap.set("n", "<leader>fC", "<cmd>GroveConfigAnalyzeTUI<CR>", { desc = "Grove Config Analyze TUI" })
vim.keymap.set("n", "<leader>fe", "<cmd>GroveEditContext<CR>", { desc = "Grove Edit Context Rules" })
vim.keymap.set("n", "<leader>fR", "<cmd>GroveRules<CR>", { desc = "Grove Rules Selector" })
vim.keymap.set("n", "<leader>fx", function()
	require("grove-nvim.grove").set_context_current_file(vim.fn.expand("%:p"))
end, { desc = "Grove Set Context to Current File" })
vim.keymap.set("n", "<leader>fs", "<cmd>GrovePlanStatusTUI<CR>", { desc = "Grove Plan Status TUI" })
vim.keymap.set("n", "<leader>fz", "<cmd>GroveSessionize<CR>", { desc = "Grove Sessionize" })
vim.keymap.set("n", "<leader>fk", "<cmd>GroveGmuxKeymap<CR>", { desc = "Gmux Keymap" })
vim.keymap.set("n", "<leader>fh", "<cmd>GroveHooksSessions<CR>", { desc = "Grove Hooks Sessions" })
vim.keymap.set("n", "<leader>fv", "<cmd>GroveContextView<CR>", { desc = "Grove Context View" })
vim.keymap.set("n", "<leader>fw", "<cmd>GroveWorkspaceStatus<CR>", { desc = "Grove Workspace Status" })
vim.keymap.set("n", "<leader>fl", "<cmd>GroveLogsTUI<CR>", { desc = "Grove Logs TUI" })
vim.keymap.set("n", "<leader>fn", "<cmd>GroveNBManage<CR>", { desc = "NB Manage" })
vim.keymap.set("n", "<leader>fb", "<cmd>GroveNBBrowse<CR>", { desc = "NB Browse" })
vim.keymap.set("n", "<leader>frl", "<cmd>GroveReleaseTUI<CR>", { desc = "Grove Release TUI" })
vim.keymap.set("n", "<leader>jn", "<cmd>GroveAddJob<CR>", { desc = "Grove Add Job (New)" })
vim.keymap.set("n", "<leader>ji", "<cmd>GroveAddJobTUI<CR>", { desc = "Grove Add Job (TUI)" })
vim.keymap.set("v", "<leader>fq", "<cmd>GroveText<CR>", { desc = "Grove Ask Question (Flow)" })
vim.keymap.set("v", "<leader>fr", "<cmd>GroveTextRun<CR>", { desc = "Grove Ask & Run (Flow)" })

-- Marks Commands
vim.api.nvim_create_user_command("GroveMarkFile", function()
	require("grove-nvim.marks").add_file(vim.fn.expand("%:p"))
end, {
	nargs = 0,
	desc = "Mark the current file for quick access.",
})

vim.api.nvim_create_user_command("GroveUnmarkFile", function()
	require("grove-nvim.marks").remove_file(vim.fn.expand("%:p"))
end, {
	nargs = 0,
	desc = "Unmark the current file.",
})

vim.api.nvim_create_user_command("GroveClearMarks", function()
	require("grove-nvim.marks").clear()
end, {
	nargs = 0,
	desc = "Clear all Grove marks.",
})

vim.api.nvim_create_user_command("GroveMarksMenu", function()
	require("grove-nvim.marks").open_menu()
end, {
	nargs = 0,
	desc = "Open the Grove marks menu.",
})

vim.api.nvim_create_user_command("GroveToggleMarksWindow", function()
	require("grove-nvim.marks_float").toggle()
end, {
	nargs = 0,
	desc = "Toggle the persistent Grove marks window.",
})

-- Keybindings for Marks
vim.keymap.set("n", "<leader>ja", "<cmd>GroveMarkFile<CR>", { desc = "Grove Mark: Add file" })
vim.keymap.set("n", "<leader>js", "<cmd>GroveMarksMenu<CR>", { desc = "Grove Mark: Show menu" })
vim.keymap.set("n", "<leader>jj", "<cmd>GroveToggleMarksWindow<CR>", { desc = "Grove Mark: Toggle window" })
vim.keymap.set("n", "<leader>jN", function()
	require("grove-nvim.marks").next()
end, { desc = "Grove Mark: Next file" })
vim.keymap.set("n", "<leader>jP", function()
	require("grove-nvim.marks").previous()
end, { desc = "Grove Mark: Previous file" })

-- Create mark shortcuts for 1-9
for i = 1, 9 do
	vim.keymap.set("n", "<leader>" .. i, function()
		require("grove-nvim.marks").go_to(i)
	end, { desc = "Grove: Go to mark " .. i })
end

