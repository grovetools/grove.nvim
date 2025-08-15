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