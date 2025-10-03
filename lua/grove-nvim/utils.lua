local M = {}

-- Helper function to create centered dropdown config
function M.centered_dropdown(width, height)
  return {
    preset = "dropdown",
    preview = false,
    layout = {
      width = width,
      height = height,
    },
    win = {
      position = {
        row = "50%",
        col = "50%",
      },
    },
  }
end

-- Helper to run a command and capture output
function M.run_command(cmd_args, callback)
  local stdout_data = {}
  local stderr_data = {}

  local job_id = vim.fn.jobstart(cmd_args, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(stdout_data, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(stderr_data, data)
      end
    end,
    on_exit = function(_, exit_code)
      local stdout = table.concat(stdout_data, "\n")
      local stderr = table.concat(stderr_data, "\n")
      callback(stdout, stderr, exit_code)
    end,
  })

  if job_id <= 0 then
    callback("", "Failed to start command", -1)
  end

  return job_id
end

-- Helper to run a command in a floating terminal
function M.run_in_float_term(command)
  -- Simple terminal split approach for now
  vim.cmd('new')
  vim.cmd('resize 20')
  vim.fn.termopen(command)
  vim.cmd('startinsert')
end

-- Helper to run a command in a floating terminal that shows output (non-interactive)
function M.run_in_float_term_output(command)
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.85)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create a buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Window options
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Grove Output ',
    title_pos = 'center',
  }

  -- Create the window
  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Configure window
  vim.wo[win].winblend = 0

  -- Open terminal - command stays open until user exits
  local job_id = vim.fn.termopen(command .. '; echo ""; echo "Press any key to close..."; read -n 1', {
    env = {
      TERM = 'xterm-256color',
      COLORTERM = 'truecolor',
    },
    on_exit = function()
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, {force = true})
        end
      end)
    end
  })

  -- Set buffer-local options for clean rendering
  vim.bo[buf].buflisted = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].foldcolumn = '0'
  vim.wo[win].scrolloff = 0
  vim.wo[win].sidescrolloff = 0

  -- Set up keymaps for the floating window
  vim.api.nvim_buf_set_keymap(buf, 't', '<Esc>', '<C-\\><C-n>:q<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':q<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', { noremap = true, silent = true })
end

-- Helper to run a command in a floating terminal
function M.run_in_float_term_tui(command, title)
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.85)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create a buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Window options
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. (title or 'Grove TUI') .. ' ',
    title_pos = 'center',
  }

  -- Create the window
  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Configure window
  vim.wo[win].winblend = 0

  -- Open terminal with proper environment for TUI
  vim.fn.termopen(command, {
    env = {
      TERM = 'xterm-256color',
      COLORTERM = 'truecolor',
      GROVE_NVIM_PLUGIN = 'true', -- Signal to TUI it's running inside nvim
    },
    on_exit = function()
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then return end

        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local output = table.concat(lines, "\n")

        -- Search for our edit protocol string
        local file_to_edit = output:match("EDIT_FILE:(.+)")

        -- Always close the window and buffer
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, {force = true}) end

        -- If a file was found, open it
        if file_to_edit then
          file_to_edit = vim.trim(file_to_edit)
          vim.notify("Grove: Opening " .. vim.fn.fnamemodify(file_to_edit, ':t'), vim.log.levels.INFO)
          vim.cmd('edit ' .. vim.fn.fnameescape(file_to_edit))
        end
      end)
    end
  })

  -- Enter terminal mode
  vim.cmd('startinsert')

  -- Set buffer-local options for clean rendering
  vim.bo[buf].buflisted = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].foldcolumn = '0'
  vim.wo[win].scrolloff = 0
  vim.wo[win].sidescrolloff = 0

  -- Set up keymaps for the floating window
  vim.api.nvim_buf_set_keymap(buf, 't', '<Esc>', '<C-\\><C-n>:q<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':q<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', { noremap = true, silent = true })
end

return M
