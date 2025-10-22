-- lua/grove-nvim/lsp.lua
-- LSP configuration for automatic Grove schema detection

local M = {}

--- Finds the Grove root by searching upward for .grove/ directory
--- @param start_path string The path to start searching from
--- @return string|nil The grove root path, or nil if not found
local function find_grove_root(start_path)
  if not start_path or start_path == '' then
    return nil
  end

  local dir = start_path
  -- Handle file paths by getting the directory
  if vim.fn.isdirectory(dir) == 0 then
    dir = vim.fn.fnamemodify(dir, ':h')
  end

  -- Walk up the directory tree
  local max_depth = 20
  local depth = 0

  while depth < max_depth do
    local grove_dir = dir .. '/.grove'
    if vim.fn.isdirectory(grove_dir) == 1 then
      return dir
    end

    -- Go up one directory
    local parent = vim.fn.fnamemodify(dir, ':h')
    if parent == dir then
      -- Reached root
      break
    end
    dir = parent
    depth = depth + 1
  end

  return nil
end

--- Get yamlls settings with Grove schema auto-detection
--- @return table Settings table to use in yamlls setup
function M.get_yamlls_config()
  -- Find schemas for common locations
  local schemas = {}

  -- Check for global schema
  local home_dir = vim.fn.expand('~')
  local global_schema = home_dir .. '/.grove/grove.schema.json'

  if vim.fn.filereadable(global_schema) == 1 then
    schemas[global_schema] = 'grove.yml'
  end

  -- Check for workspace schema
  local cwd = vim.fn.getcwd()
  local grove_root = find_grove_root(cwd)

  if grove_root then
    local local_schema = grove_root .. '/.grove/grove.schema.json'
    if vim.fn.filereadable(local_schema) == 1 then
      schemas[local_schema] = 'grove.yml'
    end
  end

  -- Fallback to hosted schema
  if vim.tbl_isempty(schemas) then
    schemas['https://www.grove-llm.dev/schemas/grove.schema.json'] = 'grove.yml'
  end

  return {
    yaml = {
      schemas = schemas
    }
  }
end

return M
