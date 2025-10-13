-- lua/grove-nvim/workspace.lua
-- Utilities for interacting with Grove workspaces.

local M = {}
local utils = require('grove-nvim.utils')

--- Converts a list of absolute paths to @a: aliases by calling the neogrove binary.
-- @param paths table A list of absolute paths to convert.
-- @param callback function(path_map) Called with a map of { original_path = aliased_path }.
function M.get_aliases_for_paths(paths, callback)
  if not paths or #paths == 0 then
    vim.schedule(function()
      callback({})
    end)
    return
  end

  local neogrove_path = vim.fn.exepath('neogrove')
  if neogrove_path == '' then
    vim.notify("Grove: neogrove executable not found in PATH.", vim.log.levels.ERROR)
    callback(nil)
    return
  end

  local input_string = table.concat(paths, "\n")
  local stdout_data = {}
  local stderr_data = {}

  local job_id = vim.fn.jobstart({ neogrove_path, 'internal', 'resolve-aliases' }, {
    on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          table.insert(stdout_data, line)
        end
      end
    end,
    on_stderr = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          table.insert(stderr_data, line)
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      if exit_code ~= 0 then
        local stderr = table.concat(stderr_data, "\n")
        vim.notify("Grove: Failed to resolve aliases: " .. stderr, vim.log.levels.WARN)
        callback(nil)
        return
      end

      local stdout = table.concat(stdout_data, "")
      local ok, path_map = pcall(vim.json.decode, stdout)

      if ok and type(path_map) == "table" then
        callback(path_map)
      else
        vim.notify("Grove: Failed to parse alias resolution output.", vim.log.levels.ERROR)
        callback(nil)
      end
    end,
  })

  -- Send the paths to the command's stdin
  vim.fn.jobsend(job_id, input_string)
  vim.fn.chanclose(job_id, 'stdin')
end

return M
