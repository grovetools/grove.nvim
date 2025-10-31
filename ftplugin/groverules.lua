-- ftplugin/groverules.lua
-- Activates features for the 'groverules' filetype.

-- Set comment string for commenting operations (gc)
vim.bo.commentstring = "# %s"

-- Include : and @ in filename characters for alias support (e.g., @a:ecosystem:repo/path)
vim.opt_local.isfname:append('@-@')
vim.opt_local.isfname:append(':')
vim.opt_local.isfname:append('{')

-- Enable virtual text for per-rule statistics.
require('grove-nvim.virtual_text').setup()

-- Keymap for previewing files resolved by the rule under the cursor.
vim.keymap.set('n', '<leader>f?', function()
  require('grove-nvim.grove').preview_rule_files()
end, { buffer = true, silent = true, desc = "Grove: Preview files for rule" })

-- Keymap for going to file under cursor (gf) with alias resolution.
vim.keymap.set('n', 'gf', function()
  require('grove-nvim.grove').goto_file_from_rule()
end, { buffer = true, noremap = true, silent = true, desc = "Grove: Go to file for rule" })
