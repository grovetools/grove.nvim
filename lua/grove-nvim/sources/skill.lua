-- lua/grove-nvim/sources/skill.lua
-- Blink.cmp source for Grove ecosystem skill names.
-- Triggered by `/` anywhere in a markdown buffer (body AND frontmatter), it
-- completes skill names (e.g. `/grove-skill-guide`) from `skills list --json`.

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
  -- Fire in any markdown buffer. The body-vs-frontmatter distinction is handled
  -- by the /token scan below, not here -- which is what lets it fire in both.
  return vim.bo.filetype == 'markdown'
end

function source:get_trigger_characters()
  return { '/' }
end

-- Return true if the cursor at (row) sits inside a fenced code block, detected
-- by an odd number of ``` fences on the lines above it.
local function in_fenced_code_block(bufnr, row)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, row - 1, false)
  local fences = 0
  for _, line in ipairs(lines) do
    if line:match('^%s*```') then
      fences = fences + 1
    end
  end
  return (fences % 2) == 1
end

function source:get_completions(ctx, callback)
  local bufnr = ctx.bufnr or vim.api.nvim_get_current_buf()
  local cursor = ctx.cursor or vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]

  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  local line_to_cursor = line:sub(1, col)

  -- Cheap check first: detect a /skill token on the current line only. This
  -- runs on every completion request in a markdown buffer, so the common
  -- no-token case must bail before any whole-buffer work (the fenced-code scan
  -- below). Token = a `/` at start-of-line or after whitespace, followed by
  -- word/hyphen chars, ending at the cursor. The boundary anchor rejects
  -- relative paths (a/b, ./x, ../x, ~/x) for free.
  local token = line_to_cursor:match('^/([%w%-]*)$')
  if not token then
    token = line_to_cursor:match('%s/([%w%-]*)$')
  end
  if not token then
    return callback({ items = {} })
  end

  -- Suppression (only reached once we have a /token, i.e. rarely):
  -- never fire inside a grove directive -- that region belongs to directive.lua.
  if line_to_cursor:match('<!%-%- grove:') then
    return callback({ items = {} })
  end
  -- ...nor for URLs like https://... (the boundary anchor already rejects
  -- `://`, but reject explicitly too).
  if line_to_cursor:match('%w+://%S*$') then
    return callback({ items = {} })
  end
  -- ...nor inside fenced code blocks (e.g. `ls /etc`). This is the only
  -- whole-buffer scan, now gated behind the token match above.
  if in_fenced_code_block(bufnr, row) then
    return callback({ items = {} })
  end

  data.get_skills(function(skills)
    local items = {}
    for _, skill in ipairs(skills) do
      local name = skill.name
      if name and name ~= "" then
        table.insert(items, {
          label = name,
          insertText = name,
          detail = skill.source or "",
          -- Value (not Function): Function/Method trigger blink's auto_brackets,
          -- which would append `()` to the accepted skill name.
          kind = vim.lsp.protocol.CompletionItemKind.Value,
        })
      end
    end
    callback({ items = items })
  end)
end

return source
