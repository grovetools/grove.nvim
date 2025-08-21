local M = {}

-- State for background job
local running_job = nil

--- Opens a floating terminal and runs the `neogrove chat` command for the current buffer.
--- @param opts table|nil Options table with optional 'silent' boolean
function M.chat_run(opts)
  opts = opts or {}
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path == '' or buf_path == nil then
    vim.notify("Grove: No file name for the current buffer.", vim.log.levels.ERROR)
    return
  end

  -- Save the file before running
  vim.cmd('write')

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
    vim.cmd('redrawstatus')
    
    -- Run in background
    running_job = vim.fn.jobstart({neogrove_path, 'chat', buf_path}, {
      on_exit = function(_, exit_code)
        vim.g.grove_chat_running = false
        vim.cmd('redrawstatus')
        if exit_code == 0 then
          -- Reload the buffer to show the updated content
          vim.cmd('checktime')
          vim.notify("Grove: Chat completed", vim.log.levels.INFO)
        else
          vim.notify("Grove: Chat failed with exit code " .. exit_code, vim.log.levels.ERROR)
        end
        running_job = nil
      end,
      on_stderr = function(_, data)
        -- Log errors but don't show them unless it's critical
        if data and #data > 0 and data[1] ~= '' then
          vim.notify("Grove: " .. table.concat(data, '\n'), vim.log.levels.WARN)
        end
      end,
    })
  else
    -- Original behavior - open in terminal split
    vim.cmd('new')
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