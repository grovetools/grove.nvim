local M = {}

M.options = {
  ui = {
    -- A native status bar for users not using lualine.
    status_bar = {
      enable = false,     -- Disabled by default.
      position = 'top', -- 'top' or 'bottom'.
    },
    -- Chat placeholder settings
    chat_placeholder = {
      enable = true,      -- Show "Start typing here..." placeholder in empty chat turns
    },
    -- Lualine component display options (when status_bar.enable = false)
    lualine = {
      plan = {
        show_name = false,        -- Show plan name
        show_stats = true,        -- Show completion stats (󰄳 5 󰔟 2)
      },
      job = {
        show_filename = false,    -- Show job filename
        show_type_icon = true,    -- Show job type icon (󰭹)
        show_status = true,       -- Show status icon (󰔟)
        show_model = false,       -- Show model name
        show_template = false,    -- Show template name
      },
      context = {
        show_label = false,       -- Show "Context:" label
        show_size = true,         -- Show size (61.7k)
      },
      git = {
        show_label = false,       -- Show "Git:" label
      },
      rules = {
        show = false,             -- Show rules file indicator
        show_filename = false,    -- Show full filename (vs just icon)
      },
    },
  },
  test_runner = {
    -- %s will be replaced with the scenario name under the cursor
    command_template = "tend run --debug-session %s",
  },
}

---Merges user options with the default configuration.
---@param opts table User-provided options.
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M
