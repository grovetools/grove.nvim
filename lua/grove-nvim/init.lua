local M = {}

local config = require("grove-nvim.config")
local provider = require("grove-nvim.status_provider")

-- State for background job
local running_job = nil
local spinner_timer = nil

-- Highlight groups setup
local highlights_defined = false
local function setup_highlights()
  if highlights_defined then return end
  vim.cmd("highlight default link GroveCtxTokens0 Normal")
  vim.cmd("highlight default link GroveCtxTokens1 Comment")
  vim.cmd("highlight default link GroveCtxTokens2 DiagnosticInfo")
  vim.cmd("highlight default link GroveCtxTokens3 String")
  vim.cmd("highlight default link GroveCtxTokens4 DiagnosticWarn")
  vim.cmd("highlight default link GroveCtxTokens5 DiagnosticError")
  vim.cmd("highlight default link GroveCtxTokensWarn ErrorMsg")
  highlights_defined = true
end

--- Main setup function for the plugin
function M.setup(opts)
  config.setup(opts)
  setup_highlights()

  -- Start the data fetching timers
  provider.start()

  -- Show status bar after UI is ready
  if config.options.ui.status_bar.enable then
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function()
        vim.defer_fn(function()
          require("grove-nvim.status_bar").show()
        end, 50)
      end,
    })
  end
end

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

  local bufnr = vim.api.nvim_get_current_buf()
  local buf_path = vim.api.nvim_buf_get_name(bufnr)
  if buf_path == '' or buf_path == nil then
    vim.notify("Grove: No file name for the current buffer.", vim.log.levels.ERROR)
    return
  end

  -- Enable chat UI if not already enabled
  local chat_ui = require("grove-nvim.chat_ui")
  if not vim.b[bufnr].grove_chat_ui_enabled then
    chat_ui.setup(bufnr)
  end

  -- Before running, find the last user turn and insert a "running" state marker
  -- if there isn't an LLM response there already.
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local last_user_turn_line = -1

  for i = #lines, 1, -1 do
    if lines[i]:match('grove:.*"template"') then
      last_user_turn_line = i
      break
    end
  end

  if last_user_turn_line ~= -1 then
    local has_response = false
    -- Check if there's already an LLM response (a grove directive with an id but no template)
    for i = last_user_turn_line + 1, #lines do
      local line = lines[i]
      local json_str = line:match("%s*<!%-%- grove: (.-) %-%->%s*")
      if json_str then
        local ok, data = pcall(vim.json.decode, json_str)
        -- If we found a grove directive with an id (response or running state), don't insert
        if ok and type(data) == "table" and data.id then
          has_response = true
          break
        end
      end
    end

    if not has_response then
      -- Insert a placeholder "running" directive at the end of the buffer
      local directive = string.format('<!-- grove: {"id": "pending-%d", "state": "running"} -->', os.time())
      local line_count = vim.api.nvim_buf_line_count(bufnr)
      vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, {"", directive})
    end
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

        vim.schedule(function()
          if exit_code == 0 then
            -- Reload the buffer to show the updated content
            vim.cmd('silent! checktime')

            -- Remove any orphaned running directives
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            for i = #lines, 1, -1 do
              local json_str = lines[i]:match("%s*<!%-%- grove: (.-) %-%->%s*")
              if json_str then
                local ok, data = pcall(vim.json.decode, json_str)
                if ok and type(data) == "table" and data.state == "running" then
                  -- Remove the running directive and any blank line before it
                  local start_line = i - 1
                  if start_line > 0 and lines[start_line]:match("^%s*$") then
                    -- Remove blank line + directive
                    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, i, false, {})
                  else
                    -- Just remove the directive
                    vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, {})
                  end
                  -- Save after cleanup
                  vim.cmd('silent write')
                  break
                end
              end
            end

            -- Use echo instead of notify to avoid press ENTER prompt
            vim.api.nvim_echo({{"Grove: Chat completed", "Normal"}}, false, {})
          else
            vim.api.nvim_echo({{"Grove: Chat failed with exit code " .. exit_code, "ErrorMsg"}}, false, {})
          end
        end)
        running_job = nil
      end,
      on_stderr = function(_, data)
        -- Silently ignore stderr unless debugging
      end,
    })
  else
    -- Store the original buffer to refresh it later
    local orig_buf = vim.api.nvim_get_current_buf()

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
            -- Refresh the original buffer
            if vim.api.nvim_buf_is_valid(orig_buf) then
              vim.api.nvim_buf_call(orig_buf, function()
                vim.cmd('checktime')
              end)
            end
          end)
        end
      })

      vim.api.nvim_buf_set_keymap(buf, 't', '<Esc>', '<C-\\><C-n>:q<CR>', { noremap = true, silent = true })
      vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', { noremap = true, silent = true })
      vim.cmd('startinsert')
    elseif opts.layout == 'fullscreen' then
      vim.cmd('tabnew')
      vim.fn.termopen(neogrove_path .. ' chat ' .. vim.fn.shellescape(buf_path), {
        on_exit = function()
          vim.schedule(function()
            -- Refresh the original buffer
            if vim.api.nvim_buf_is_valid(orig_buf) then
              vim.api.nvim_buf_call(orig_buf, function()
                vim.cmd('checktime')
              end)
            end
          end)
        end
      })
      vim.cmd('startinsert')
    elseif opts.layout == 'horizontal' then
      vim.cmd('new')
      vim.fn.termopen(neogrove_path .. ' chat ' .. vim.fn.shellescape(buf_path), {
        on_exit = function()
          vim.schedule(function()
            -- Refresh the original buffer
            if vim.api.nvim_buf_is_valid(orig_buf) then
              vim.api.nvim_buf_call(orig_buf, function()
                vim.cmd('checktime')
              end)
            end
          end)
        end
      })
      vim.cmd('startinsert')
    else -- 'vertical'
      vim.cmd('vnew')
      vim.fn.termopen(neogrove_path .. ' chat ' .. vim.fn.shellescape(buf_path), {
        on_exit = function()
          vim.schedule(function()
            -- Refresh the original buffer
            if vim.api.nvim_buf_is_valid(orig_buf) then
              vim.api.nvim_buf_call(orig_buf, function()
                vim.cmd('checktime')
              end)
            end
          end)
        end
      })
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
    return spinners[frame + 1] .. ' Running chat'
  end
  return ''
end

--- Get lualine component for current job status
--- @return table Lualine component configuration
function M.current_job_status_component()
  return {
    function()
      local status = provider.state.current_job_status
      if not status then return "" end
      -- Highlight only the icon, leave status text in default color
      return string.format("%%#%s#%s%%* %s", status.icon_hl, status.icon, status.status)
    end,
    cond = function()
      -- Hide if native status bar is enabled
      if config.options.ui.status_bar.enable then return false end
      return provider.state.current_job_status ~= nil
    end,
  }
end

--- Get lualine component for context size
--- @return table Lualine component configuration
function M.context_size_component()
  setup_highlights()

  return {
    function()
      local cache = provider.state.context_size
      if type(cache) == "table" and cache.display then
        -- Use lualine's inline highlighting format
        return string.format("%%#%s#%s%%*", cache.hl_group, cache.display)
      end
      return ""
    end,
    cond = function()
      -- Hide if native status bar is enabled
      if config.options.ui.status_bar.enable then return false end
      return vim.bo.filetype == 'markdown'
    end,
  }
end

--- Get lualine component for active rules file
--- @return table Lualine component configuration
function M.rules_file_component()
  return {
    function()
      return provider.state.rules_file or ""
    end,
    cond = function()
      -- Hide if native status bar is enabled
      if config.options.ui.status_bar.enable then return false end
      return vim.bo.filetype == 'markdown'
    end,
  }
end

--- Get lualine component for plan status
--- @return table Lualine component configuration
function M.plan_status_component()
  return {
    function()
      local stats = provider.state.plan_status
      if not stats or type(stats) ~= "table" then
        return ""
      end

      -- Build colored string parts for lualine
      local parts = {}
      for i, stat in ipairs(stats) do
        if i > 1 then
          table.insert(parts, " ")
        end
        -- Use %#HlGroup# syntax for inline highlighting
        table.insert(parts, "%#" .. stat.hl .. "#" .. stat.text .. "%*")
      end

      return table.concat(parts)
    end,
    cond = function()
      -- Hide if native status bar is enabled
      if config.options.ui.status_bar.enable then return false end
      -- Only show when there's active plan status
      local stats = provider.state.plan_status
      return stats and type(stats) == "table" and #stats > 0
    end,
  }
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
      vim.api.nvim_echo({{'Grove: Editing job-specific rules: ' .. rules_file, 'Normal'}}, false, {})
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
        vim.api.nvim_echo({{'Grove: Created job-specific rules file', 'Normal'}}, false, {})
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
  -- First, check if there's an active rule set in state
  local current_dir = vim.fn.getcwd()

  -- Try to read the state to find active rules source
  -- Walk up directories to find .grove/state.yml
  local search_dir = current_dir
  local state_file = nil
  local project_root = nil
  local max_depth = 10
  local depth = 0

  while depth < max_depth do
    local candidate_state = search_dir .. '/.grove/state.yml'
    if vim.fn.filereadable(candidate_state) == 1 then
      state_file = candidate_state
      project_root = search_dir
      break
    end

    -- Go up one directory
    local parent = vim.fn.fnamemodify(search_dir, ':h')
    if parent == search_dir then
      -- Reached root
      break
    end
    search_dir = parent
    depth = depth + 1
  end

  local active_rules_source = nil

  if state_file then
    -- Read state file and look for context.active_rules_source
    local state_lines = vim.fn.readfile(state_file)
    for _, line in ipairs(state_lines) do
      local source = line:match('context%.active_rules_source:%s*"?([^"]+)"?')
      if source then
        active_rules_source = source
        break
      end
    end
  end

  -- If we found an active rules source in state, use that
  if active_rules_source and project_root then
    local rules_path = project_root .. '/' .. active_rules_source
    if vim.fn.filereadable(rules_path) == 1 then
      vim.cmd('edit ' .. vim.fn.fnameescape(rules_path))
      vim.api.nvim_echo({{'Grove: Editing active rules: ' .. active_rules_source, 'Normal'}}, false, {})
      return
    end
  end

  -- Otherwise, find .grove/rules by walking up from the working directory
  local max_depth = 10
  local depth = 0

  while depth < max_depth do
    local rules_path = current_dir .. '/.grove/rules'
    if vim.fn.filereadable(rules_path) == 1 then
      vim.cmd('edit ' .. vim.fn.fnameescape(rules_path))
      vim.api.nvim_echo({{'Grove: Editing .grove/rules', 'Normal'}}, false, {})
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
    vim.api.nvim_echo({{'Grove: Running cx edit', 'Normal'}}, false, {})
  else
    vim.api.nvim_echo({{'Grove: .grove/rules not found and cx not available', 'ErrorMsg'}}, false, {})
  end
end

return M