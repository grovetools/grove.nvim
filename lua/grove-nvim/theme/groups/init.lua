-- Highlight group set assembly, ported from floraverse.nvim (groups/init.lua).
-- `base` and `treesitter` always apply; plugin sets are opt-in via
-- config.ui.theme.plugins (`all`, lazy.nvim auto-detection, or per-set flags).
local M = {}

-- Plugin name (as known to lazy.nvim) -> group module name.
M.plugins = {
  ["gitsigns.nvim"] = "gitsigns",
  ["neo-tree.nvim"] = "neo-tree",
  ["blink.cmp"] = "blink",
  ["snacks.nvim"] = "snacks",
  ["hop.nvim"] = "hop",
  ["trouble.nvim"] = "trouble",
  ["telescope.nvim"] = "telescope",
  ["nvim-cmp"] = "cmp",
  ["which-key.nvim"] = "which-key",
}

---@param name string group module name
---@param colors table
---@param opts table
function M.get(name, colors, opts)
  return require("grove-nvim.theme.groups." .. name).get(colors, opts)
end

---Assemble the merged highlight table for the enabled group sets.
---@param colors table derived ColorScheme
---@param opts table resolved ui.theme options
---@return table<string, table|string> groups, table<string, boolean> enabled
function M.setup(colors, opts)
  local groups = {
    base = true,
    treesitter = true,
  }

  local plugins = opts.plugins or {}

  -- Plugin integrations: everything, or lazy.nvim auto-detection.
  if plugins.all then
    for _, group in pairs(M.plugins) do
      groups[group] = true
    end
  elseif plugins.auto ~= false and package.loaded.lazy then
    local ok, lazy_config = pcall(require, "lazy.core.config")
    if ok and lazy_config.plugins then
      for plugin, group in pairs(M.plugins) do
        if lazy_config.plugins[plugin] then
          groups[group] = true
        end
      end
    end
  end

  -- Manual per-set overrides (by group name or plugin name).
  for plugin, group in pairs(M.plugins) do
    local use = plugins[group]
    if use == nil then
      use = plugins[plugin]
    end
    if use ~= nil then
      if type(use) == "table" then
        use = use.enabled
      end
      groups[group] = use or nil
    end
  end

  local ret = {}
  for group in pairs(groups) do
    for k, v in pairs(M.get(group, colors, opts)) do
      ret[k] = v
    end
  end

  require("grove-nvim.theme.util").resolve(ret)

  if type(opts.on_highlights) == "function" then
    opts.on_highlights(ret, colors)
  end

  return ret, groups
end

return M
