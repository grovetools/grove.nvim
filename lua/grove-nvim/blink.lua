-- lua/grove-nvim/blink.lua
-- Unified blink.cmp integration for all Grove sources.

--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

local alias_source = require('grove-nvim.sources.alias')
local template_source = require('grove-nvim.sources.template')

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}

  -- Initialize individual sources
  self.alias = alias_source.new(opts)
  self.template = template_source.new(opts)

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

  for _, char in ipairs(self.template:get_trigger_characters()) do
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
  elseif ft == 'markdown' and self.template:enabled() then
    return self.template:get_completions(ctx, callback)
  end

  -- No applicable source
  callback({ items = {} })
end

return source
