local M = {}

--- Opens a floating terminal and runs the `neogrove chat` command for the current buffer.
function M.chat_run()
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

  -- Simple terminal in a new split
  vim.cmd('new')
  vim.cmd('terminal ' .. neogrove_path .. ' chat ' .. vim.fn.shellescape(buf_path))
  vim.cmd('startinsert')
end

return M