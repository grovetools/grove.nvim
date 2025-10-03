local M = {}

-- State for background job
local running_job = nil
local spinner_timer = nil

--- Opens a floating terminal and runs the `neogrove chat` command for the current buffer.
--- @param args table|nil The arguments object from `nvim_create_user_command`.
--- args.args can contain "silent", "vertical", "horizontal", "fullscreen", "float".
function M.chat_run(args)
  args = args or {}
  local opts = {
    silent = false,
    layout = 'float', -- New default layout: floating window
  }

  -- Parse string arguments into the opts table
  if args.args and args.args ~= '' then
    for arg in string.gmatch(args.args, "%S+") do
      if arg == 'silent' then
        opts.silent = true
      elseif arg == 'vertical' or arg == 'horizontal' or arg == 'fullscreen' or arg == 'float' then
        opts.layout = arg
      end
    end
  end

  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path == '' or buf_path == nil then
    vim.notify("Grove: No file name for the current buffer.", vim.log.levels.ERROR)
    return
  end

  -- Save the file before running
  vim.cmd('silent write')

  -- Use grove bin directory
  local neogrove_path = vim.fn.expand('~/.grove/bin/neogrove')
  if vim.fn.filereadable(neogrove_path) ~= 1 then
    vim.notify("Grove: neogrove not found at ~/.grove/bin/neogrove", vim.log.levels.ERROR)
    return
  end

  if opts.silent then
    -- Kill any existing job
    if running_job and vim.fn.jobstatus(running_job) == 'run' then
      vim.fn.jobstop(running_job)
    end
    
    -- Show spinner in statusline
    vim.g.grove_chat_running = true
    vim.cmd('silent! redrawstatus')
    
    -- Start spinner animation timer
    if spinner_timer then
      vim.fn.timer_stop(spinner_timer)
    end
    spinner_timer = vim.fn.timer_start(100, function()
      vim.cmd('silent! redrawstatus')
    end, {['repeat'] = -1})
    
    -- Run in background
    running_job = vim.fn.jobstart({neogrove_path, 'chat', buf_path}, {
      on_exit = function(_, exit_code)
        vim.g.grove_chat_running = false
        -- Stop the spinner timer
        if spinner_timer then
          vim.fn.timer_stop(spinner_timer)
          spinner_timer = nil
        end
        vim.cmd('silent! redrawstatus')
        if exit_code == 0 then
          -- Reload the buffer to show the updated content
          vim.cmd('silent! checktime')
          -- Use echo instead of notify to avoid press ENTER prompt
          vim.api.nvim_echo({{"Grove: Chat completed", "Normal"}}, false, {})
        else
          vim.api.nvim_echo({{"Grove: Chat failed with exit code " .. exit_code, "ErrorMsg"}}, false, {})
        end
        running_job = nil
      end,
      on_stderr = function(_, data)
        -- Silently ignore stderr unless debugging
      end,
    })
  else
    -- Open chat in a terminal with specified layout
    if opts.layout == 'float' then
      -- Create floating window
      local width = math.floor(vim.o.columns * 0.9)
      local height = math.floor(vim.o.lines * 0.85)
      local row = math.floor((vim.o.lines - height) / 2)
      local col = math.floor((vim.o.columns - width) / 2)

      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = ' Grove Chat ',
        title_pos = 'center',
      })

      vim.wo[win].winblend = 0
      vim.bo[buf].buflisted = false
      vim.wo[win].number = false
      vim.wo[win].relativenumber = false
      vim.wo[win].signcolumn = 'no'

      vim.fn.termopen(neogrove_path .. ' chat ' .. vim.fn.shellescape(buf_path), {
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

      vim.api.nvim_buf_set_keymap(buf, 't', '<Esc>', '<C-\\><C-n>:q<CR>', { noremap = true, silent = true })
      vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', { noremap = true, silent = true })
      vim.cmd('startinsert')
    elseif opts.layout == 'fullscreen' then
      vim.cmd('tabnew')
      vim.cmd('terminal ' .. neogrove_path .. ' chat ' .. vim.fn.shellescape(buf_path))
      vim.cmd('startinsert')
    elseif opts.layout == 'horizontal' then
      vim.cmd('new')
      vim.cmd('terminal ' .. neogrove_path .. ' chat ' .. vim.fn.shellescape(buf_path))
      vim.cmd('startinsert')
    else -- 'vertical'
      vim.cmd('vnew')
      vim.cmd('terminal ' .. neogrove_path .. ' chat ' .. vim.fn.shellescape(buf_path))
      vim.cmd('startinsert')
    end
  end
end

--- Get status for statusline integration
--- @return string Status string, empty if not running
function M.status()
  if vim.g.grove_chat_running then
    -- Simple spinner animation
    local spinners = {'⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'}
    local ms = vim.loop.hrtime() / 1000000
    local frame = math.floor(ms / 100) % #spinners
    return spinners[frame + 1] .. ' Grove'
  end
  return ''
end

--- Parse YAML frontmatter from current buffer
--- @return table|nil Frontmatter data or nil if not found
local function parse_frontmatter()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Check if file starts with ---
  if #lines < 3 or lines[1] ~= '---' then
    return nil
  end

  -- Find the closing ---
  local end_line = nil
  for i = 2, #lines do
    if lines[i] == '---' then
      end_line = i
      break
    end
  end

  if not end_line then
    return nil
  end

  -- Parse YAML frontmatter (simple key: value parsing)
  local frontmatter = {}
  for i = 2, end_line - 1 do
    local line = lines[i]
    local key, value = line:match('^([%w_]+):%s*(.+)$')
    if key and value then
      -- Remove quotes from value if present
      value = value:gsub('^["\'](.+)["\']$', '%1')
      frontmatter[key] = value
    end
  end

  return frontmatter
end

--- Edit context rules - either job-specific or default .grove/rules
function M.edit_context_rules()
  local buf_path = vim.api.nvim_buf_get_name(0)

  -- Try to parse frontmatter to check for rules_file
  local frontmatter = parse_frontmatter()
  local rules_file = nil

  if frontmatter and frontmatter.rules_file then
    -- Job has a custom rules file
    rules_file = frontmatter.rules_file

    -- Resolve the path relative to the current file's directory
    local current_dir = vim.fn.fnamemodify(buf_path, ':h')
    local rules_path = vim.fn.simplify(current_dir .. '/' .. rules_file)

    -- Check if the rules file exists
    if vim.fn.filereadable(rules_path) == 1 then
      vim.cmd('edit ' .. vim.fn.fnameescape(rules_path))
      vim.notify('Grove: Editing job-specific rules: ' .. rules_file, vim.log.levels.INFO)
      return
    else
      -- Rules file doesn't exist, ask if user wants to create it
      local choice = vim.fn.confirm(
        'Job-specific rules file not found: ' .. rules_file .. '\nCreate it?',
        '&Yes\n&No\n&Edit .grove/rules instead',
        1
      )

      if choice == 1 then
        -- Create the rules directory if needed
        local rules_dir = vim.fn.fnamemodify(rules_path, ':h')
        vim.fn.mkdir(rules_dir, 'p')

        -- Create the file with a template
        local template = {
          '# Context rules for job: ' .. vim.fn.fnamemodify(buf_path, ':t'),
          '# Add patterns to include files, one per line',
          '# Use ! prefix to exclude',
          '',
          '# Examples:',
          '#   *.go',
          '#   !*_test.go',
          '#   src/**/*.js',
          '',
        }
        vim.fn.writefile(template, rules_path)
        vim.cmd('edit ' .. vim.fn.fnameescape(rules_path))
        vim.notify('Grove: Created job-specific rules file', vim.log.levels.INFO)
        return
      elseif choice == 3 then
        -- Fall through to edit .grove/rules
      else
        -- User cancelled
        return
      end
    end
  end

  -- No job-specific rules, or user chose to edit .grove/rules
  -- Find .grove/rules by walking up the directory tree
  local current_dir = vim.fn.expand('%:p:h')
  local max_depth = 10
  local depth = 0

  while depth < max_depth do
    local rules_path = current_dir .. '/.grove/rules'
    if vim.fn.filereadable(rules_path) == 1 then
      vim.cmd('edit ' .. vim.fn.fnameescape(rules_path))
      vim.notify('Grove: Editing .grove/rules', vim.log.levels.INFO)
      return
    end

    -- Go up one directory
    local parent = vim.fn.fnamemodify(current_dir, ':h')
    if parent == current_dir then
      -- Reached root
      break
    end
    current_dir = parent
    depth = depth + 1
  end

  -- .grove/rules not found, run cx edit
  local cx_path = vim.fn.expand('~/.grove/bin/cx')
  if vim.fn.executable(cx_path) == 1 then
    vim.cmd('terminal ' .. cx_path .. ' edit')
    vim.notify('Grove: Running cx edit', vim.log.levels.INFO)
  else
    vim.notify('Grove: .grove/rules not found and cx not available', vim.log.levels.ERROR)
  end
end

return M