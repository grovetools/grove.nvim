local M = {}
local ui = require('grove-nvim.ui')

local state = {
  target_file = nil,
}

-- State file path
local state_file = vim.fn.expand('~/.grove/state.yml')

-- Load state from file
local function load_state()
  if vim.fn.filereadable(state_file) == 1 then
    local content = vim.fn.readfile(state_file)
    for _, line in ipairs(content) do
      local key, value = line:match("^(%w+):%s*(.+)$")
      if key == "target_file" and value then
        state.target_file = value
      end
    end
  end
end

-- Save state to file
local function save_state()
  -- Ensure .grove directory exists
  local grove_dir = vim.fn.expand('~/.grove')
  if vim.fn.isdirectory(grove_dir) == 0 then
    vim.fn.mkdir(grove_dir, 'p')
  end
  
  -- Write state file
  local lines = {}
  if state.target_file then
    table.insert(lines, "target_file: " .. state.target_file)
  end
  vim.fn.writefile(lines, state_file)
end

-- Load state on module load
load_state()

--- Set the target markdown file for text interactions.
function M.set_target_file()
  local current_file = vim.fn.expand('%:p')
  if current_file == '' then
    vim.notify('Grove: No file in current buffer', vim.log.levels.ERROR)
    return
  end
  
  state.target_file = current_file
  save_state()
  vim.notify('Grove: Target file set to ' .. vim.fn.fnamemodify(state.target_file, ':~:.'), vim.log.levels.INFO)
end

--- Get the current target file
function M.get_target_file()
  return state.target_file
end

--- Show the current target file
function M.show_target_file()
  if state.target_file then
    vim.notify('Grove: Target file is ' .. vim.fn.fnamemodify(state.target_file, ':~:.'), vim.log.levels.INFO)
  else
    vim.notify('Grove: No target file set. Use :GroveSetTarget to set one.', vim.log.levels.WARN)
  end
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

--- Capture visual selection, append to target file, ask a question, then switch to target and run chat.
function M.select_ask_and_run()
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
              -- Switch to the target file
              vim.cmd('silent edit ' .. vim.fn.fnameescape(state.target_file))
              -- Jump to the bottom of the file
              vim.cmd('silent normal! G')
              -- Run the chat command in silent mode
              require('grove-nvim').chat_run({ silent = true })
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