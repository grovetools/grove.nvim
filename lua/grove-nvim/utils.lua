local M = {}

-- Get the Grove bin directory following XDG spec.
-- Resolution order:
-- 1. GROVE_BIN env var (explicit override)
-- 2. GROVE_HOME env var → $GROVE_HOME/data/bin
-- 3. XDG_DATA_HOME env var → $XDG_DATA_HOME/grove/bin
-- 4. Fall back to ~/.local/share/grove/bin
function M.get_grove_bin_dir()
  local grove_bin = os.getenv('GROVE_BIN')
  if grove_bin and grove_bin ~= '' then
    return grove_bin
  end

  local grove_home = os.getenv('GROVE_HOME')
  if grove_home and grove_home ~= '' then
    return grove_home .. '/data/bin'
  end

  local xdg_data_home = os.getenv('XDG_DATA_HOME')
  if xdg_data_home and xdg_data_home ~= '' then
    return xdg_data_home .. '/grove/bin'
  end

  return vim.fn.expand('~/.local/share/grove/bin')
end

-- Get the path to the grove-nvim binary.
-- First tries the grove bin directory, then falls back to exepath.
function M.get_grove_nvim_binary()
  local bin_dir = M.get_grove_bin_dir()
  local binary_path = bin_dir .. '/grove-nvim'

  if vim.fn.filereadable(binary_path) == 1 then
    return binary_path
  end

  -- Fall back to checking PATH
  local path_binary = vim.fn.exepath('grove-nvim')
  if path_binary ~= '' then
    return path_binary
  end

  return nil
end

-- Format bytes into human-readable format
function M.format_bytes(bytes)
	if bytes < 1024 then
		return string.format("%dB", bytes)
	elseif bytes < 1024 * 1024 then
		return string.format("%.1fKB", bytes / 1024)
	else
		return string.format("%.1fMB", bytes / (1024 * 1024))
	end
end

-- Debounce function to limit how often a function is called
function M.debounce(ms, fn)
  local timer = vim.loop.new_timer()
  return function(...)
    local argv = {...}
    timer:start(ms, 0, function()
      timer:stop()
      vim.schedule_wrap(fn)(unpack(argv))
    end)
  end
end

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
function M.run_in_float_term_tui(command, title, on_exit_callback)
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

        -- Search for EDIT_FILE in lines directly
        local file_to_edit = nil
        for _, line in ipairs(lines) do
          if line:match("^EDIT_FILE:") then
            file_to_edit = line:match("^EDIT_FILE:(.+)$")
            break
          end
        end

        -- Always close the window and buffer
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, {force = true}) end

        -- If a file was found, open it
        if file_to_edit then
          -- Strip ANSI escape codes and trim whitespace
          file_to_edit = file_to_edit:gsub('\27%[[0-9;]*m', ''):gsub('%s+$', '')
          vim.notify("Grove: Opening " .. vim.fn.fnamemodify(file_to_edit, ':t'), vim.log.levels.INFO)
          vim.cmd('edit ' .. vim.fn.fnameescape(file_to_edit))
        end

        -- Call custom on_exit callback if provided
        if on_exit_callback then
          on_exit_callback()
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

-- Helper to run a command in a side terminal (vertical split)
function M.run_in_side_term_tui(command, title, width)
  -- Default to 1/3 of screen width if not specified
  width = width or math.floor(vim.o.columns / 3)

  -- Store the original window to return focus later
  local original_win = vim.api.nvim_get_current_win()

  -- Create a vertical split on the left
  vim.cmd('topleft vnew')
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()

  -- Resize the new window
  vim.api.nvim_win_set_width(win, width)

  -- Variables for file watching
  local timer
  local temp_file

  -- Generate a unique session ID for this TUI instance
  local session_id = string.format('%d-%d', vim.fn.getpid(), math.random(10000, 99999))
  temp_file = string.format('%s/grove-nb-edit-%s', os.getenv('TMPDIR') and os.getenv('TMPDIR'):gsub('/$', '') or '/tmp', session_id)

  -- Open terminal with proper environment for TUI
  local job_id = vim.fn.termopen(command, {
    env = {
      TERM = 'xterm-256color',
      COLORTERM = 'truecolor',
      GROVE_NVIM_PLUGIN = 'true', -- Signal to TUI it's running inside nvim
      GROVE_NVIM_SESSION_ID = session_id, -- Pass session ID to TUI
    },
    on_exit = function()
      vim.schedule(function()
        -- Stop the file watcher timer
        if timer then
          timer:stop()
          timer:close()
        end

        -- Clean up temp file
        if temp_file and vim.loop.fs_stat(temp_file) then
          vim.loop.fs_unlink(temp_file)
        end

        -- Close the terminal window and buffer when TUI exits
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, {force = true}) end

        -- Return focus to the original window
        if vim.api.nvim_win_is_valid(original_win) then
          vim.api.nvim_set_current_win(original_win)
        end
      end)
    end
  })

  vim.notify("Grove: Watching for file at " .. temp_file, vim.log.levels.INFO)

  -- Watch the temp file for changes
  timer = vim.loop.new_timer()
  local last_mtime = nil

  timer:start(100, 100, vim.schedule_wrap(function()
    local stat = vim.loop.fs_stat(temp_file)
    if stat and (not last_mtime or stat.mtime.sec > last_mtime) then
      last_mtime = stat.mtime.sec

      -- Read the file
      local file = io.open(temp_file, 'r')
      if file then
        local file_to_edit = file:read('*l')
        file:close()

        if file_to_edit and file_to_edit ~= '' then
          -- Check if this is a preview or open action
          local action = 'OPEN'
          local file_path = file_to_edit
          if file_to_edit:match('^PREVIEW:') then
            action = 'PREVIEW'
            file_path = file_to_edit:match('^PREVIEW:(.+)$')
          elseif file_to_edit:match('^OPEN:') then
            file_path = file_to_edit:match('^OPEN:(.+)$')
          end

          -- Return focus to the original window
          if vim.api.nvim_win_is_valid(original_win) then
            vim.api.nvim_set_current_win(original_win)
          end

          vim.notify("Grove: Opening " .. vim.fn.fnamemodify(file_path, ':t'), vim.log.levels.INFO)
          vim.cmd('edit ' .. vim.fn.fnameescape(file_path))

          -- For preview mode, return focus to TUI; for open, stay on buffer
          if action == 'PREVIEW' then
            if vim.api.nvim_win_is_valid(win) then
              vim.api.nvim_set_current_win(win)
            end
          end

          -- Clear the file contents
          os.remove(temp_file)
        end
      end
    end
  end))

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

  -- Set up keymaps for the side window
  vim.api.nvim_buf_set_keymap(buf, 't', '<Esc>', '<C-\\><C-n>:q<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':q<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', { noremap = true, silent = true })

  -- Add window navigation keymaps in terminal mode
  vim.api.nvim_buf_set_keymap(buf, 't', '<C-h>', '<C-\\><C-n><C-w>h', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 't', '<C-j>', '<C-\\><C-n><C-w>j', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 't', '<C-k>', '<C-\\><C-n><C-w>k', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 't', '<C-l>', '<C-\\><C-n><C-w>l', { noremap = true, silent = true })

  -- Automatically enter terminal mode when focusing this terminal buffer
  vim.api.nvim_create_autocmd({'BufEnter', 'WinEnter'}, {
    buffer = buf,
    callback = function()
      if vim.api.nvim_get_current_buf() == buf and vim.bo[buf].buftype == 'terminal' then
        vim.cmd('startinsert')
      end
    end
  })
end

-- Helper to show a list of files in a picker and execute a callback on selection
function M.show_file_picker(title, files, on_confirm)
  local has_snacks, snacks = pcall(require, 'snacks')
  if not (has_snacks and snacks.picker) then
    vim.notify('Grove: snacks.nvim is required for file selection', vim.log.levels.ERROR)
    if on_confirm then on_confirm(nil) end
    return
  end

  -- Convert file paths to picker items
  local items = {}
  for _, file in ipairs(files) do
    table.insert(items, { text = file })
  end

  vim.schedule(function()
    snacks.picker({
      title = title,
      items = items,
      format = "text",
      layout = M.centered_dropdown(120, math.min(#items + 4, 30)),
      confirm = function(picker, item)
        picker:close()
        if on_confirm then
          if item and item.text then
            on_confirm(item.text)
          else
            on_confirm(nil)
          end
        end
      end,
    })
  end)
end

return M
