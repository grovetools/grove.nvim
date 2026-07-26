-- lua/grove-nvim/lsp.lua
-- LSP configuration for automatic Grove schema detection

local M = {}

local suppression_installed = false

--- Return whether this Neovim instance was launched as a Grove diff viewer.
---
--- The marker is intentionally global and read during plugin initialization so a
--- host can set it with: --cmd "lua vim.g.grove_diff_view = 1"
--- @return boolean
function M.is_diff_view()
  return vim.g.grove_diff_view == 1 or vim.g.grove_diff_view == true
end

--- Prevent language servers from being started in pinned review/diff editors.
---
--- Diff editors are short-lived viewers and do not need project-wide language
--- servers. Guard all public Neovim start paths, stop clients that attached before
--- grove.nvim initialized, and retain an LspAttach fallback for integrations that
--- cached or bypassed those functions. Outside a marked diff view this is a no-op.
function M.setup_diff_view_guard()
  if suppression_installed or not M.is_diff_view() then
    return
  end
  suppression_installed = true

  local lsp = vim.lsp

  local original_enable = lsp.enable
  if original_enable then
    lsp.enable = function(name, enable)
      -- Disabling must remain available so configs and teardown can clean up.
      if enable == false then
        return original_enable(name, false)
      end
      return nil
    end
  end

  if lsp.start then
    lsp.start = function()
      return nil
    end
  end

  if lsp.start_client then
    lsp.start_client = function()
      return nil
    end
  end

  local function stop_client(client)
    if client then
      client:stop()
    end
  end

  -- The marker is normally set before init, but a user's config may have started
  -- an LSP before the plugin script was sourced. Shut those clients down as well.
  if lsp.get_clients then
    for _, client in ipairs(lsp.get_clients()) do
      stop_client(client)
    end
  elseif lsp.get_active_clients then
    for _, client in ipairs(lsp.get_active_clients()) do
      stop_client(client)
    end
  end

  local group = vim.api.nvim_create_augroup("GroveNvimDiffViewLspGuard", { clear = true })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = lsp.get_client_by_id(args.data.client_id)
      stop_client(client)
    end,
    desc = "grove: suppress LSP clients in diff views",
  })
end

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
