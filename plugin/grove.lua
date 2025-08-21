vim.api.nvim_create_user_command(
  'GroveChatRun',
  function(args)
    local opts = {}
    if args.args == 'silent' then
      opts.silent = true
    end
    require('grove-nvim').chat_run(opts)
  end,
  {
    nargs = '?',
    desc = "Run 'flow chat run' on the current note. Use 'silent' to run in background."
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

-- Text Commands
vim.api.nvim_create_user_command(
  'GroveSetTarget',
  function()
    require('grove-nvim.text').set_target_file()
  end,
  {
    nargs = 0,
    desc = 'Set the target markdown file for text interactions.'
  }
)

vim.api.nvim_create_user_command(
  'GroveShowTarget',
  function()
    require('grove-nvim.text').show_target_file()
  end,
  {
    nargs = 0,
    desc = 'Show the current target markdown file.'
  }
)

vim.api.nvim_create_user_command(
  'GroveText',
  function()
    require('grove-nvim.text').select_and_ask()
  end,
  {
    nargs = 0,
    range = true, -- Important for visual selection
    desc = 'Capture selected text and ask a question about it.'
  }
)

vim.api.nvim_create_user_command(
  'GroveTextRun',
  function()
    require('grove-nvim.text').select_ask_and_run()
  end,
  {
    nargs = 0,
    range = true, -- Important for visual selection
    desc = 'Capture selected text, ask a question, switch to target file and run chat.'
  }
)

-- Keybindings
vim.keymap.set('n', '<leader>fp', '<cmd>GrovePlan<CR>', { desc = 'Grove Plans' })
vim.keymap.set('n', '<leader>fc', '<cmd>GroveChatRun<CR>', { desc = 'Grove Chat Run' })
vim.keymap.set('n', '<leader>jn', '<cmd>GroveAddJob<CR>', { desc = 'Grove Add Job (New)' })
vim.keymap.set('n', '<leader>ji', '<cmd>GroveAddJobTUI<CR>', { desc = 'Grove Add Job (TUI)' })
vim.keymap.set('v', '<leader>fq', '<cmd>GroveText<CR>', { desc = 'Grove Ask Question (Flow)' })
vim.keymap.set('v', '<leader>fr', '<cmd>GroveTextRun<CR>', { desc = 'Grove Ask & Run (Flow)' })