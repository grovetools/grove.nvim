vim.api.nvim_create_user_command(
  'GroveChatRun',
  function()
    require('grove-nvim').chat_run()
  end,
  {
    nargs = 0,
    desc = "Run 'flow chat run' on the current note."
  }
)

-- Plan Commands
vim.api.nvim_create_user_command(
  'GrovePlan',
  function()
    require('grove-nvim.plan').picker()
  end,
  {
    nargs = 0,
    desc = 'Open the Grove Plan picker.'
  }
)

vim.api.nvim_create_user_command(
  'GrovePlanInit',
  function()
    require('grove-nvim.plan').init()
  end,
  {
    nargs = 0,
    desc = 'Initialize a new Grove Plan.'
  }
)

-- Keybindings
vim.keymap.set('n', '<leader>fp', '<cmd>GrovePlan<CR>', { desc = 'Grove Plans' })
vim.keymap.set('n', '<leader>fc', '<cmd>GroveChatRun<CR>', { desc = 'Grove Chat Run' })