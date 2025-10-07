-- lua/grove-nvim/sources/alias.lua
-- Blink.cmp source for Grove context aliases.

--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

local utils = require('grove-nvim.utils')

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}
  return self
end

-- Only enable in groverules files
function source:enabled()
  return vim.bo.filetype == 'groverules'
end

-- Trigger on colon after @alias or @a
function source:get_trigger_characters()
  return { ':' }
end

function source:get_completions(ctx, callback)
  -- Get the current line from the buffer
  local bufnr = ctx.bufnr or vim.api.nvim_get_current_buf()
  local cursor = ctx.cursor or vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]

  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  local line_to_cursor = line:sub(1, col)

  -- Check if we're in an @alias: or @a: context
  if not line_to_cursor:match("@a:") and not line_to_cursor:match("@alias:") then
    return callback({ items = {} })
  end

  local cx_path = vim.fn.exepath('cx')
  if cx_path == '' then
    return callback({ items = {} })
  end

  -- Use shell to redirect stderr since cx logs to stderr
  local cmd = string.format('%s workspace list --json 2>/dev/null', vim.fn.shellescape(cx_path))

  utils.run_command({ 'sh', '-c', cmd }, function(stdout, stderr, exit_code)
    if exit_code ~= 0 then
      vim.notify("Grove: cx workspace list failed with exit code " .. exit_code, vim.log.levels.DEBUG)
      return callback({ items = {} })
    end

    if stdout == "" then
      vim.notify("Grove: cx workspace list returned empty stdout", vim.log.levels.DEBUG)
      return callback({ items = {} })
    end

    local ok, projects = pcall(vim.json.decode, stdout)
    if not ok then
      vim.notify("Grove: Failed to parse JSON: " .. tostring(projects), vim.log.levels.DEBUG)
      return callback({ items = {} })
    end

    if not projects then
      vim.notify("Grove: projects is nil after JSON decode", vim.log.levels.DEBUG)
      return callback({ items = {} })
    end

    local items = {}
    for _, project in ipairs(projects) do
      if project.identifier then
        table.insert(items, {
          label = project.identifier,
          detail = project.Path,
          kind = vim.lsp.protocol.CompletionItemKind.Folder,
        })
      end
    end

    vim.notify("Grove: Returning " .. #items .. " completion items", vim.log.levels.DEBUG)

    callback({
      items = items,
      is_incomplete_backward = false,
      is_incomplete_forward = false,
    })
  end)
end

return source
