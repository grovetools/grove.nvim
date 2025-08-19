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

--- Creates a form in a floating window.
-- @param opts Table of options:
--   - title (string): The title of the form.
--   - fields (table): An array of field definitions. Each field is a table with:
--     - name (string): The key for the result table.
--     - label (string): The display label for the field.
--     - type (string): 'text', 'select', 'multiselect', 'multiline_text'.
--     - value: The initial value.
--     - options (table, optional): For 'select'/'multiselect', a list of items for snacks.picker.
--     - condition (function, optional): A function that takes the current form data and returns true if the field should be shown.
--     - help (string, optional): Help text shown in the statusline for the field.
-- @param on_confirm function(data): Callback with the form data on submission.
function M.form(opts, on_confirm)
  local state = {
    fields = {}, -- a filtered list of visible fields
    values = {},
    current_field = 1,
    total_items = 0, -- fields + buttons
  }

  local function get_visible_fields()
    local visible_fields = {}
    for _, field in ipairs(opts.fields) do
      if not field.condition or field.condition(state.values) then
        table.insert(visible_fields, field)
      end
    end
    return visible_fields
  end

  -- Initialize values
  for _, field in ipairs(opts.fields) do
    state.values[field.name] = field.value
  end
  state.fields = get_visible_fields()
  state.total_items = #state.fields + 2  -- fields + 2 buttons

  -- Create UI
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines
  local width = math.floor(math.min(100, editor_width * 0.8))
  local height = #state.fields + 4
  local row = math.floor((editor_height - height) / 2)
  local col = math.floor((editor_width - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. (opts.title or 'Grove Form') .. ' ',
    title_pos = 'center',
  })

  vim.api.nvim_win_set_option(win, 'winhl', 'Normal:Normal,FloatBorder:FloatBorder')
  vim.api.nvim_win_set_option(win, 'cursorline', true)

  local function render()
    state.fields = get_visible_fields()
    state.total_items = #state.fields + 2  -- fields + 2 buttons
    height = state.total_items + 5  -- Add space for separator and buttons
    vim.api.nvim_win_set_config(win, { height = height })

    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    local lines = {}
    
    -- Render fields
    for i, field in ipairs(state.fields) do
      local value = state.values[field.name]
      local value_str = ""
      if field.type == 'multiselect' then
        value_str = string.format("[%s]", table.concat(value, ", "))
      elseif type(value) == 'table' then
        value_str = vim.json.encode(value)
      else
        value_str = tostring(value)
      end
      -- Truncate long values for display
      if #value_str > width - 25 then
        value_str = string.sub(value_str, 1, width - 28) .. "..."
      end
      table.insert(lines, string.format("%-20s %s", field.label .. ":", value_str))
    end
    
    -- Add separator
    table.insert(lines, "")
    table.insert(lines, string.rep("─", width - 2))
    
    -- Add buttons
    local button_line = "        [ Create Job ]            [ Cancel ]"
    table.insert(lines, button_line)
    
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    
    -- Adjust cursor bounds
    if state.current_field > state.total_items then state.current_field = state.total_items end
    if state.current_field < 1 then state.current_field = 1 end
    
    -- Position cursor
    if state.current_field <= #state.fields then
      -- On a field - position at value column
      vim.api.nvim_win_set_cursor(win, { state.current_field, 21 })
    else
      -- On a button - buttons are on the last line
      local button_line = #state.fields + 3  -- fields + empty line + separator + button line
      local button_idx = state.current_field - #state.fields
      if button_idx == 1 then
        -- Create button
        vim.api.nvim_win_set_cursor(win, { button_line, 9 })  -- Position on [
      else
        -- Cancel button
        vim.api.nvim_win_set_cursor(win, { button_line, 35 })  -- Position on [
      end
    end

    -- Update statusline with help text
    local help_text = ""
    if state.current_field <= #state.fields then
      help_text = state.fields[state.current_field].help or "<Enter> or i to edit | <C-s> to save | <Esc> or q to cancel"
    else
      help_text = "<Enter> to activate | <C-s> to save | <Esc> or q to cancel"
    end
    vim.api.nvim_win_set_option(win, 'statusline', " " .. help_text .. " ")
  end

  local function close_window(result)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    on_confirm(result)
  end

  local function edit_field()
    -- Check if we're on a button
    if state.current_field > #state.fields then
      local button_idx = state.current_field - #state.fields
      if button_idx == 1 then
        -- Create button
        close_window(state.values)
      else
        -- Cancel button
        close_window(nil)
      end
      return
    end
    
    local field = state.fields[state.current_field]
    local current_value = state.values[field.name]

    local handler = function(new_value)
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_set_current_win(win)
        end
        if new_value ~= nil then
          state.values[field.name] = new_value
          render()
        end
      end)
    end

    if field.type == 'text' then
      M.input({ prompt = field.label .. ': ', default = current_value, title = field.label }, handler)
    elseif field.type == 'multiline_text' then
      M.multiline_input({ title = field.label, default_lines = vim.split(current_value, '\n') }, handler)
    elseif field.type == 'select' or field.type == 'multiselect' then
      local has_snacks, snacks = pcall(require, 'snacks')
      if not has_snacks then return vim.notify("snacks.nvim is required", vim.log.levels.ERROR) end

      local picker_opts = {
        title = "Select " .. field.label,
        items = field.options,
        format = "text",
        layout = { 
          preset = "dropdown", 
          preview = false, 
          layout = {
            width = 70,
            height = math.min(#field.options + 4, 25),
          },
          win = {
            position = {
              row = "50%",
              col = "50%",
            },
          },
        },
        confirm = function(picker, item)
          picker:close()
          -- Always return to form window even on cancel
          vim.schedule(function()
            if vim.api.nvim_win_is_valid(win) then
              vim.api.nvim_set_current_win(win)
              if field.type == 'multiselect' then
                local selected = picker:selected({ fallback = true })
                local values = {}
                for _, sel in ipairs(selected) do if sel.value then table.insert(values, sel.value) end end
                state.values[field.name] = values
                render()
              elseif item then
                state.values[field.name] = item.value
                render()
              end
            end
          end)
        end,
        on_close = function()
          -- Ensure we return to form window when picker closes
          vim.schedule(function()
            if vim.api.nvim_win_is_valid(win) then
              vim.api.nvim_set_current_win(win)
            end
          end)
        end,
      }

      if field.type == 'multiselect' then
        picker_opts.win = { list = { keys = { ["<Space>"] = { "select" } } } }
      end

      snacks.picker(picker_opts)
    end
  end

  -- Keymaps
  vim.keymap.set('n', 'q', function() close_window(nil) end, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', function() close_window(nil) end, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<C-s>', function() close_window(state.values) end, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<CR>', edit_field, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'i', edit_field, { buffer = buf, nowait = true })  -- Vim users expect 'i' to edit

  local function move(delta)
    state.current_field = state.current_field + delta
    if state.current_field > state.total_items then state.current_field = 1 end
    if state.current_field < 1 then state.current_field = state.total_items end
    render()
  end

  vim.keymap.set('n', 'j', function() move(1) end, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Down>', function() move(1) end, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Tab>', function() move(1) end, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'k', function() move(-1) end, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Up>', function() move(-1) end, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<S-Tab>', function() move(-1) end, { buffer = buf, nowait = true })

  -- Initial render
  render()
end

return M