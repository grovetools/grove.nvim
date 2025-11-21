-- lua/grove-nvim/blink.lua
-- Unified blink.cmp integration for all Grove sources.

--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

local alias_source = require('grove-nvim.sources.alias')
local directive_source = require('grove-nvim.sources.directive')
local frontmatter_source = require('grove-nvim.sources.frontmatter')

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}

  -- Initialize individual sources
  self.alias = alias_source.new(opts)
  self.directive = directive_source.new(opts)
  self.frontmatter = frontmatter_source.new(opts)

  return self
end

-- Enable in both groverules (for alias) and markdown (for template) files
function source:enabled()
  local ft = vim.bo.filetype
  return ft == 'groverules' or ft == 'markdown'
end

-- Combine trigger characters from all sources
function source:get_trigger_characters()
  local triggers = {}
  local seen = {}

  -- Collect unique triggers from all sources
  for _, char in ipairs(self.alias:get_trigger_characters()) do
    if not seen[char] then
      table.insert(triggers, char)
      seen[char] = true
    end
  end

  for _, char in ipairs(self.directive:get_trigger_characters()) do
    if not seen[char] then
      table.insert(triggers, char)
      seen[char] = true
    end
  end

  for _, char in ipairs(self.frontmatter:get_trigger_characters()) do
    if not seen[char] then
      table.insert(triggers, char)
      seen[char] = true
    end
  end

  return triggers
end

function source:get_completions(ctx, callback)
  -- Route to the appropriate source based on context
  local ft = vim.bo.filetype

  if ft == 'groverules' and self.alias:enabled() then
    return self.alias:get_completions(ctx, callback)
  elseif ft == 'markdown' then
    -- In markdown, we need to decide which source to use based on context.
    -- We'll try frontmatter first, then directives.
    self.frontmatter:get_completions(ctx, function(frontmatter_result)
      if frontmatter_result and frontmatter_result.items and #frontmatter_result.items > 0 then
        callback(frontmatter_result)
      else
        self.directive:get_completions(ctx, callback)
      end
    end)
    return -- Important: return here as the callbacks are async.
  end

  -- No applicable source
  callback({ items = {} })
end

return source
