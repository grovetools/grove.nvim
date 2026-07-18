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
    -- Grove theme engine: applies the grove-synced palette as a Neovim
    -- colorscheme and keeps it in sync with live theme changes from the
    -- daemon (theme_changed events). GROVE_THEME pins the theme and
    -- disables live updates for this process.
    theme = {
      enable = false,          -- Opt-in.
      live_updates = true,     -- Re-apply when the daemon broadcasts a theme change.
      transparent = false,     -- Don't paint the main background.
      terminal_colors = true,  -- Set vim.g.terminal_color_* from the palette.
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
        functions = {},
        variables = {},
        sidebars = "dark",     -- "dark", "transparent" or "normal"
        floats = "dark",       -- "dark", "transparent" or "normal"
      },
      plugins = {
        -- base + treesitter highlight sets always apply. Plugin sets:
        all = false,           -- Enable every supported plugin set.
        auto = true,           -- Auto-detect installed plugins via lazy.nvim.
        -- Per-set overrides, e.g.: telescope = true, ["neo-tree"] = false.
        -- Supported: gitsigns, neo-tree, blink, cmp, snacks, hop, trouble,
        -- telescope, which-key.
      },
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
  -- Reload open buffers when their files change on disk (agents, nb sync,
  -- flow jobs). Terminal nvim inside tuimux/treemux panes rarely receives
  -- FocusGained, so a repeating checktime timer backs up the autocmds.
  autoreload = {
    enable = true,
    interval_ms = 2000,   -- checktime poll interval
    notify = true,        -- announce externally reloaded buffers
  },
}

---Merges user options with the default configuration.
---@param opts table User-provided options.
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M
