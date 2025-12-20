local M = {}

M.options = {
  ui = {
    -- A native status bar for users not using lualine.
    status_bar = {
      enable = false,     -- Disabled by default.
      position = 'top', -- 'top' or 'bottom'.
    },
  },
}

---Merges user options with the default configuration.
---@param opts table User-provided options.
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M
