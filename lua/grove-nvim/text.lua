local M = {}
local ui = require('grove-nvim.ui')

local state = {
  target_file = nil,
}

--- Set the target markdown file for text interactions.
function M.set_target_file()
  ui.input({
    prompt = 'Target Markdown File: ',
    default = state.target_file or vim.fn.expand('%:p'),
    completion = 'file',
    title = 'Set Chat Target File',
  }, function(file_path)
    if file_path and file_path ~= '' then
      state.target_file = file_path
      vim.notify('Grove: Target file set to ' .. state.target_file, vim.log.levels.INFO)
    else
      vim.notify('Grove: Target file selection cancelled.', vim.log.levels.WARN)
    end
  end)
end

-- Helper to get visually selected text
local function get_visual_selection()
  local start_line, start_col = unpack(vim.api.nvim_buf_get_mark(0, '<'))
  local end_line, end_col = unpack(vim.api.nvim_buf_get_mark(0, '>'))
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  
  if #lines == 0 then return '' end
  
  if #lines == 1 then
    return string.sub(lines[1], start_col + 1, end_col + 1)
  end
  
  -- Multi-line selection
  lines[1] = string.sub(lines[1], start_col + 1)
  lines[#lines] = string.sub(lines[#lines], 1, end_col + 1)
  
  return table.concat(lines, '\n')
end


--- Capture visual selection, append to target file, and ask a question.
function M.select_and_ask()
  if not state.target_file then
    vim.notify("Grove: No target file set. Use :GroveSetTarget to set one.", vim.log.levels.ERROR)
    return
  end

  local selection = get_visual_selection()
  if selection == '' then
    vim.notify("Grove: No text selected.", vim.log.levels.WARN)
    return
  end

  local lang = vim.bo.filetype
  local neogrove_path = vim.fn.exepath('neogrove')
  if neogrove_path == '' then
    vim.notify("Grove: neogrove executable not found in PATH.", vim.log.levels.ERROR)
    return
  end

  -- 1. Append the code snippet
  local select_cmd = { neogrove_path, 'text', 'select', '--file', state.target_file, '--lang', lang }
  
  local job_id = vim.fn.jobstart(select_cmd, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.notify("Grove: Failed to append selection.", vim.log.levels.ERROR)
        return
      end

      -- 2. Prompt for a question
      ui.input({ prompt = 'Your Question: ', title = 'Ask About Selection' }, function(question)
        if not question or question == '' then
          vim.notify("Grove: Question cancelled.", vim.log.levels.WARN)
          return
        end

        -- 3. Append the question
        local ask_cmd = { neogrove_path, 'text', 'ask', '--file', state.target_file }
        local ask_job_id = vim.fn.jobstart(ask_cmd, {
          on_exit = function(_, ask_exit_code)
            if ask_exit_code == 0 then
              vim.notify('Grove: Snippet and question added to ' .. vim.fn.fnamemodify(state.target_file, ":t") .. '. Run :GroveChatRun to get a response.', vim.log.levels.INFO)
            else
              vim.notify("Grove: Failed to append question.", vim.log.levels.ERROR)
            end
          end,
        })
        vim.fn.jobsend(ask_job_id, question)
        vim.fn.chanclose(ask_job_id, 'stdin')
      end)
    end,
  })

  -- Send the selected text to the command's stdin
  vim.fn.jobsend(job_id, selection)
  vim.fn.chanclose(job_id, 'stdin')
end

return M