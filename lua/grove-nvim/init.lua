local M = {}

-- State for background job
local running_job = nil
local spinner_timer = nil

--- Opens a floating terminal and runs the `neogrove chat` command for the current buffer.
--- @param args table|nil The arguments object from `nvim_create_user_command`.
--- args.args can contain "silent", "vertical", "horizontal", "fullscreen".
function M.chat_run(args)
  args = args or {}
  local opts = {
    silent = false,
    layout = 'vertical', -- New default layout
  }

  -- Parse string arguments into the opts table
  if args.args and args.args ~= '' then
    for arg in string.gmatch(args.args, "%S+") do
      if arg == 'silent' then
        opts.silent = true
      elseif arg == 'vertical' or arg == 'horizontal' or arg == 'fullscreen' then
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
    if opts.layout == 'fullscreen' then
      vim.cmd('tabnew')
    elseif opts.layout == 'horizontal' then
      vim.cmd('new')
    else -- 'vertical' is the default
      vim.cmd('vnew')
    end
    vim.cmd('terminal ' .. neogrove_path .. ' chat ' .. vim.fn.shellescape(buf_path))
    vim.cmd('startinsert')
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

return M