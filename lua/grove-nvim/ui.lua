local M = {}

-- Create a centered popup input
function M.input(opts, on_confirm)
  opts = opts or {}
  local prompt = opts.prompt or "Input: "
  local default = opts.default or ""
  local completion = opts.completion
  
  -- Calculate window dimensions
  local width = math.max(50, #prompt + 20)
  local height = 3
  
  -- Get editor dimensions
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines
  
  -- Calculate centered position
  local row = math.floor((editor_height - height) / 2)
  local col = math.floor((editor_width - width) / 2)
  
  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- Window options
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. (opts.title or 'Grove Input') .. ' ',
    title_pos = 'center',
  }
  
  -- Create window
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'buftype', 'prompt')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  
  -- Set prompt
  vim.fn.prompt_setprompt(buf, prompt)
  
  -- Set default value
  if default ~= "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {default})
    -- Move cursor to end of line
    vim.api.nvim_win_set_cursor(win, {1, #default})
  end
  
  -- Set up completion if provided
  if completion then
    vim.api.nvim_buf_set_option(buf, 'omnifunc', 'v:lua.vim.fn.' .. completion)
  end
  
  -- Function to close window and cleanup
  local function close_window(result)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if on_confirm then
      on_confirm(result)
    end
  end
  
  -- Set up keymaps
  local function setup_keymaps()
    -- Confirm on Enter
    vim.keymap.set('i', '<CR>', function()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local input = lines[1] or ""
      -- Remove prompt from input
      input = input:gsub("^" .. vim.pesc(prompt), "")
      close_window(input)
    end, { buffer = buf })
    
    -- Cancel on Escape
    vim.keymap.set('i', '<Esc>', function()
      close_window(nil)
    end, { buffer = buf })
    
    -- Cancel on Ctrl-C
    vim.keymap.set('i', '<C-c>', function()
      close_window(nil)
    end, { buffer = buf })
    
    -- Clear input on Ctrl-U
    vim.keymap.set('i', '<C-u>', function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {""})
    end, { buffer = buf })
  end
  
  setup_keymaps()
  
  -- Start insert mode
  vim.cmd('startinsert!')
  
  -- Set window options for better appearance
  vim.api.nvim_win_set_option(win, 'winhl', 'Normal:Normal,FloatBorder:FloatBorder')
  vim.api.nvim_win_set_option(win, 'cursorline', false)
  
  -- Auto-close on buffer leave
  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = buf,
    once = true,
    callback = function()
      close_window(nil)
    end,
  })
  
  return win, buf
end

-- Create a multi-line input popup
function M.multiline_input(opts, on_confirm)
  opts = opts or {}
  local title = opts.title or "Grove Input"
  local default_lines = opts.default_lines or {""}
  local height = opts.height or 10
  local width = opts.width or 60
  
  -- Get editor dimensions
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines
  
  -- Calculate centered position
  local row = math.floor((editor_height - height) / 2)
  local col = math.floor((editor_width - width) / 2)
  
  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- Set default content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, default_lines)
  
  -- Window options
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. title .. ' ',
    title_pos = 'center',
  }
  
  -- Create window
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  
  -- Set buffer options - don't set buftype to allow :w to work
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_option(buf, 'modified', false)
  
  -- Set a temporary filename to allow :w to work
  vim.api.nvim_buf_set_name(buf, 'grove-prompt-' .. vim.fn.tempname())
  
  -- Function to close window and cleanup
  local function close_window(result)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if on_confirm then
      on_confirm(result)
    end
  end
  
  -- Set up keymaps
  local function setup_keymaps()
    -- Confirm on Ctrl-S or :w
    vim.keymap.set('n', '<C-s>', function()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      close_window(table.concat(lines, "\n"))
    end, { buffer = buf })
    
    -- Intercept write commands using BufWriteCmd
    vim.api.nvim_create_autocmd('BufWriteCmd', {
      buffer = buf,
      callback = function()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        close_window(table.concat(lines, "\n"))
      end,
    })
    
    -- Use uppercase commands as fallback
    vim.api.nvim_buf_create_user_command(buf, 'W', function()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      close_window(table.concat(lines, "\n"))
    end, {})
    
    vim.api.nvim_buf_create_user_command(buf, 'Wq', function()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      close_window(table.concat(lines, "\n"))
    end, {})
    
    -- Intercept :q command
    vim.api.nvim_buf_create_user_command(buf, 'Q', function()
      close_window(nil)
    end, {})
    
    -- Also handle :q! and :wq with keymaps
    vim.keymap.set('c', 'q<CR>', function()
      if vim.fn.getcmdline() == 'q' then
        close_window(nil)
        return '<C-u><Esc>'
      end
      return 'q<CR>'
    end, { buffer = buf, expr = true })
    
    vim.keymap.set('c', 'wq<CR>', function()
      if vim.fn.getcmdline() == 'wq' then
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        close_window(table.concat(lines, "\n"))
        return '<C-u><Esc>'
      end
      return 'wq<CR>'
    end, { buffer = buf, expr = true })
    
    -- Cancel on Escape in normal mode
    vim.keymap.set('n', '<Esc>', function()
      close_window(nil)
    end, { buffer = buf })
  end
  
  setup_keymaps()
  
  -- Add help text at the bottom
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_win_set_option(win, 'statusline', ' :w, :wq or Ctrl-S to save | :q or Esc to cancel ')
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  
  return win, buf
end

return M