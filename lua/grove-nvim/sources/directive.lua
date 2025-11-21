-- lua/grove-nvim/sources/directive.lua
-- Blink.cmp source for Grove chat directive keys and values.

--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

local data = require('grove-nvim.data')

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}
  return self
end

function source:enabled()
  return vim.bo.filetype == 'markdown'
end

function source:get_trigger_characters()
  return { '"' }
end

function source:get_completions(ctx, callback)
  local bufnr = ctx.bufnr or vim.api.nvim_get_current_buf()
  local cursor = ctx.cursor or vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]

  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  local line_to_cursor = line:sub(1, col)

  -- Check if we are inside a grove directive: <!-- grove: { ... } -->
  local directive_match = line_to_cursor:match('<!%-%- grove:%s*{([^}]*)$')
  if not directive_match then
    return callback({ items = {} })
  end

  -- Case 1: Completing a key (after '{' or ',' with optional whitespace)
  if directive_match:match('[{,]%s*"?$') or directive_match:match('[{,]%s*$') then
    local items = {
      { label = 'template', insertText = '"template": "', kind = vim.lsp.protocol.CompletionItemKind.Property },
      { label = 'model', insertText = '"model": "', kind = vim.lsp.protocol.CompletionItemKind.Property },
      { label = 'id', insertText = '"id": "', kind = vim.lsp.protocol.CompletionItemKind.Property },
    }
    return callback({ items = items, is_incomplete_forward = true })
  end

  -- Case 2: Completing a value (after "key": ")
  local key_match = directive_match:match('"(%w+)"%s*:%s*"[^"]*$')
  if not key_match then
    return callback({ items = {} })
  end

  if key_match == "template" then
    -- Fetch templates and format them for the completion menu.
    data.get_templates(function(templates)
      local items = {}
      for _, template in ipairs(templates) do
        local name = template.name or template.Name
        local desc = template.description or template.Description or ""
        local source_info = template.source or template.Source or ""

        table.insert(items, {
          label = name,
          insertText = name,
          detail = " " .. source_info .. " " .. desc,
          kind = vim.lsp.protocol.CompletionItemKind.File,
        })
      end

      callback({
        items = items,
        is_incomplete_backward = false,
        is_incomplete_forward = false,
      })
    end)
  elseif key_match == "model" then
    data.get_models(function(models)
      local items = {}
      for _, model in ipairs(models) do
        local id = model.id
        -- Filter out invalid entries (headers, labels, separators)
        if id and id ~= "" and
           not id:match("^MODEL$") and
           not id:match("^[Uu]sage:?$") and
           not id:match("^model:$") and
           not id:match("^%-+$") then
          table.insert(items, {
            label = id,
            insertText = id,
            detail = "Provider: " .. (model.provider or "unknown"),
            kind = vim.lsp.protocol.CompletionItemKind.EnumMember,
          })
        end
      end
      callback({ items = items })
    end)
  elseif key_match == "id" then
    -- For ID, we don't provide suggestions (user-defined)
    callback({ items = {} })
  else
    callback({ items = {} })
  end
end

return source
