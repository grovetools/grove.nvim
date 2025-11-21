-- lua/grove-nvim/sources/template.lua
-- Blink.cmp source for Grove job templates.

--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

local data = require('grove-nvim.data')

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}
  return self
end

-- Only enable in markdown files, which are used for Grove chats.
function source:enabled()
  return vim.bo.filetype == 'markdown'
end

-- Trigger on the quote character.
function source:get_trigger_characters()
  return { '"' }
end

function source:get_completions(ctx, callback)
  -- Get the current line up to the cursor.
  local bufnr = ctx.bufnr or vim.api.nvim_get_current_buf()
  local cursor = ctx.cursor or vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]

  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  local line_to_cursor = line:sub(1, col)

  -- Check if we are inside the value of a "template" key within a grove directive.
  -- e.g., <!-- grove: {"template": "..."} -->
  local is_template_context = line_to_cursor:match('.*<!%-%- grove:%s*{.-"template"%s*:%s*"[^"]*$')
  if not is_template_context then
    return callback({ items = {} })
  end

  -- Fetch templates and format them for the completion menu.
  data.get_templates(function(templates)
    local items = {}
    for _, template in ipairs(templates) do
      local name = template.name or template.Name -- Handle potential case differences
      local desc = template.description or template.Description or ""
      local source_info = template.source or template.Source or ""

      table.insert(items, {
        label = name,
        insertText = name,
        detail = " " .. source_info .. " " .. desc,
        kind = vim.lsp.protocol.CompletionItemKind.File, -- 'File' is a fitting kind for a template.
      })
    end

    callback({
      items = items,
      is_incomplete_backward = false,
      is_incomplete_forward = false,
    })
  end)
end

return source
