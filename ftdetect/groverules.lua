-- ftdetect/groverules.lua
-- Detects grove-context rules files and sets the 'groverules' filetype.

vim.api.nvim_create_autocmd({'BufNewFile', 'BufRead'}, {
  pattern = {'*/.grove/rules', '*.grovectx', '*.rules'},
  callback = function()
    vim.bo.filetype = 'groverules'
  end,
})
