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

vim.api.nvim_create_user_command(
  'GroveAddJob',
  function()
    require('grove-nvim.plan').add_job_to_active_plan()
  end,
  {
    nargs = 0,
    desc = 'Add a job to the active Grove Plan.'
  }
)

vim.api.nvim_create_user_command(
  'GroveAddJobTUI',
  function()
    require('grove-nvim.plan').add_job_tui()
  end,
  {
    nargs = 0,
    desc = 'Add a job to the active Grove Plan using TUI.'
  }
)

-- Keybindings
vim.keymap.set('n', '<leader>fp', '<cmd>GrovePlan<CR>', { desc = 'Grove Plans' })
vim.keymap.set('n', '<leader>fc', '<cmd>GroveChatRun<CR>', { desc = 'Grove Chat Run' })
vim.keymap.set('n', '<leader>jn', '<cmd>GroveAddJob<CR>', { desc = 'Grove Add Job (New)' })
vim.keymap.set('n', '<leader>ji', '<cmd>GroveAddJobTUI<CR>', { desc = 'Grove Add Job (TUI)' })