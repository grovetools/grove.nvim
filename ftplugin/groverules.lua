-- ftplugin/groverules.lua
-- Activates features for the 'groverules' filetype.

-- Set comment string for commenting operations (gc)
vim.bo.commentstring = "# %s"

-- Enable virtual text for per-rule statistics.
require('grove-nvim.virtual_text').setup()

-- Keymap for previewing files resolved by the rule under the cursor.
vim.keymap.set('n', '<leader>f?', function()
  require('grove-nvim.grove').preview_rule_files()
end, { buffer = true, silent = true, desc = "Grove: Preview files for rule" })
