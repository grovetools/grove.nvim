-- lua/grove-nvim/sources/frontmatter.lua
-- Blink.cmp source for Grove job frontmatter.

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
  -- Enable in markdown, but completions will check context.
  return vim.bo.filetype == 'markdown'
end

function source:get_trigger_characters()
  return { '-', ':', ' ' }
end

-- Helper function to check if we're in the YAML frontmatter block
local function in_frontmatter(bufnr, row)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, row, false)
  if #lines < 2 or lines[1] ~= '---' then
    return false
  end

  -- Check if we've seen a closing '---'
  for i = 2, #lines do
    if lines[i] == '---' then
      return false -- We've exited the frontmatter
    end
  end

  return true
end

-- Helper function to find the current YAML key context
local function find_yaml_key_context(lines, row)
  -- Start from current line and go backwards to find the key we're under
  for i = row, 1, -1 do
    local line = lines[i]
    if not line then break end

    -- Check if this is a top-level key (no leading spaces before key)
    local key = line:match('^([%w_]+)%s*:')
    if key then
      return key
    end
    -- If we hit a line that's a top-level key but different, we're not in a nested context
    if line:match('^[%w_]+%s*:') then
      return nil
    end
    -- Stop at document separator or end of frontmatter
    if line:match('^%-%-%-$') then
      return nil
    end
  end
  return nil
end

function source:get_completions(ctx, callback)
  local bufnr = ctx.bufnr or vim.api.nvim_get_current_buf()
  local cursor = ctx.cursor or vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]

  -- Check if we are in the YAML frontmatter block.
  if not in_frontmatter(bufnr, row) then
    return callback({ items = {} })
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, row + 1, false)
  local current_line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""

  -- Find which key context we're in (check from current line and above)
  local key_context = find_yaml_key_context(lines, row)

  -- Case 1: Completing depends_on values
  if key_context == 'depends_on' then
    -- Check if the current line is a list item or looks like it could be
    -- Matches: '  - ', '  -', '  - foo', or even just whitespace after depends_on
    local looks_like_list_item = current_line:match('^%s*-') or
                                  current_line:match('^%s*$') or
                                  (current_line:match('^%s+') and not current_line:match('^%s*%w+:'))

    -- Debug logging
    vim.schedule(function()
      print(string.format("[frontmatter] key_context=%s, looks_like_list=%s, line='%s'",
        key_context or "nil",
        tostring(looks_like_list_item),
        current_line))
    end)

    if looks_like_list_item then
      -- Fetch dependencies for the current plan.
      local plan_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':h')
      vim.schedule(function()
        print(string.format("[frontmatter] Fetching dependencies from: %s", plan_path))
      end)

      data.get_dependencies(plan_path, function(jobs)
        vim.schedule(function()
          print(string.format("[frontmatter] Got %d dependencies", #jobs))
        end)
        local items = {}
        for _, job in ipairs(jobs) do
          table.insert(items, {
            label = job.value, -- e.g., '01-research.md'
            insertText = job.value,
            detail = job.text, -- e.g., '✅ 01-research.md - Initial Research'
            kind = vim.lsp.protocol.CompletionItemKind.File,
          })
        end
        callback({ items = items })
      end)
      return
    end
  end

  -- Case 2: Completing model values
  if key_context == 'model' or current_line:match('^model:%s*$') then
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
    return
  end

  -- Case 3: Completing template values
  if key_context == 'template' or current_line:match('^template:%s*$') then
    data.get_templates(function(templates)
      local items = {}
      for _, template in ipairs(templates) do
        local name = template.name or template.Name
        local desc = template.description or template.Description or ""
        local source_info = template.source or template.Source or ""

        table.insert(items, {
          label = name,
          insertText = name,
          detail = source_info .. " " .. desc,
          kind = vim.lsp.protocol.CompletionItemKind.File,
        })
      end
      callback({ items = items })
    end)
    return
  end

  -- No applicable completion
  callback({ items = {} })
end

return source
