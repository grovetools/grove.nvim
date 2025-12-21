local M = {}
local config = require("grove-nvim.config")
local provider = require("grove-nvim.status_provider")

local state = {
  win = nil,
  buf = nil,
}

-- Helper to get the reserved space at bottom (statusline + status bar)
local function get_bottom_offset()
  local has_statusline = vim.o.laststatus > 0
  local statusline_offset = has_statusline and 1 or 0

  -- Add 1 more line if our status bar is enabled at bottom
  local status_bar_enabled = config.options.ui.status_bar.enable
  local status_bar_at_bottom = config.options.ui.status_bar.position == 'bottom'
  local status_bar_offset = (status_bar_enabled and status_bar_at_bottom) and 1 or 0

  return statusline_offset + status_bar_offset + 1
end

-- Expose for other modules to use
M.get_bottom_offset = get_bottom_offset

-- Helper to calculate row position accounting for statusline
local function calculate_row(position)
  if position == 'top' then
    return 0
  end

  return vim.o.lines - get_bottom_offset()
end

local function get_bar_content()
  local parts = {}
  local p_state = provider.state

  -- Chat running status (show first if active)
  if p_state.chat_running then
    -- Use hourglass icon for running chat (matches grove-flow status icons)
    table.insert(parts, "󰔟 chat")
  end

  if p_state.plan_status and #p_state.plan_status > 0 then
    -- Format plan status with icon
    local plan_parts = {}
    for _, stat in ipairs(p_state.plan_status) do
      table.insert(plan_parts, stat.text)
    end
    table.insert(parts, "󰠡 " .. table.concat(plan_parts, " "))
  end

  if p_state.context_size then
    local ctx_part = "󰄨 " .. p_state.context_size.display
    -- Add rules file in parens if present
    if p_state.rules_file then
      ctx_part = ctx_part .. " (" .. p_state.rules_file .. ")"
    end
    table.insert(parts, ctx_part)
  end

  return table.concat(parts, "  ")
end

local function do_refresh()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end

  local content = get_bar_content()

  -- If content is empty, hide the window but don't delete it
  if content == "" then
    vim.api.nvim_win_hide(state.win)
    return
  end

  -- Show the window if it was hidden
  if not vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_config(state.win, { hide = false })
  end

  -- Add left padding
  local padded_content = " " .. content

  vim.api.nvim_buf_set_option(state.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { padded_content })
  vim.api.nvim_buf_set_option(state.buf, "modifiable", false)

  -- Update window size based on content display width
  local opts = config.options.ui.status_bar
  local row = calculate_row(opts.position)
  local content_display_width = vim.fn.strdisplaywidth(content)
  local width = math.max(content_display_width + 3, 10)  -- +2 for border, +1 for left padding
  local col = math.max(0, vim.o.columns - width)

  vim.api.nvim_win_set_config(state.win, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
  })

  -- Clear previous highlights
  vim.api.nvim_buf_clear_namespace(state.buf, 0, 0, -1)

  -- Apply highlights using byte positions (accounting for left padding)
  local p_state = provider.state

  -- Highlight chat status
  if p_state.chat_running then
    local chat_text = " chat"
    local chat_start = content:find(chat_text, 1, true)
    if chat_start then
      -- Highlight entire chat section (spinner + " chat") in DiagnosticInfo color
      local padded_start = 1  -- Starts at beginning after left padding space
      local padded_end = chat_start + #chat_text
      vim.api.nvim_buf_add_highlight(
        state.buf,
        0,
        "DiagnosticInfo",
        0,
        padded_start,
        padded_end
      )
    end
  end

  -- Highlight plan status parts
  if p_state.plan_status and #p_state.plan_status > 0 then
    -- Find where plan status starts in content
    local plan_icon = "󰠡 "
    local plan_start = content:find(plan_icon, 1, true)
    if plan_start then
      local byte_offset = plan_start + 1 + #plan_icon - 1  -- +1 for left padding

      for i, stat in ipairs(p_state.plan_status) do
        local text_byte_len = #stat.text
        vim.api.nvim_buf_add_highlight(state.buf, 0, stat.hl, 0, byte_offset, byte_offset + text_byte_len)
        byte_offset = byte_offset + text_byte_len
        if i < #p_state.plan_status then
          byte_offset = byte_offset + 1 -- space separator
        end
      end
    end
  end

  -- Highlight context size (find it in the content string)
  if p_state.context_size then
    local ctx_pattern = p_state.context_size.display
    local ctx_start = content:find(ctx_pattern, 1, true)
    if ctx_start then
      -- Add 1 to account for left padding
      local padded_ctx_start = ctx_start + 1
      vim.api.nvim_buf_add_highlight(
        state.buf,
        0,
        p_state.context_size.hl_group,
        0,
        padded_ctx_start - 1,
        padded_ctx_start - 1 + #ctx_pattern
      )

      -- Highlight rules file in parens (muted & italic)
      if p_state.rules_file then
        local rules_pattern = "(" .. p_state.rules_file .. ")"
        local rules_start = content:find(rules_pattern, ctx_start, true)
        if rules_start then
          -- Add 1 to account for left padding
          local padded_rules_start = rules_start + 1
          vim.api.nvim_buf_add_highlight(
            state.buf,
            0,
            "Comment",
            0,
            padded_rules_start - 1,
            padded_rules_start - 1 + #rules_pattern
          )
        end
      end
    end
  end
end

function M.refresh()
  vim.schedule(do_refresh)
end

function M.show()
  if state.win and vim.api.nvim_win_is_valid(state.win) then return end

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(state.buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(state.buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(state.buf, "swapfile", false)
  vim.api.nvim_buf_set_option(state.buf, "modifiable", false)

  local opts = config.options.ui.status_bar
  local row = calculate_row(opts.position)

  -- Calculate width and column based on content
  local content = get_bar_content()
  local content_display_width = vim.fn.strdisplaywidth(content)
  local width = math.max(content_display_width + 2, 10)  -- +2 for border
  local col = math.max(0, vim.o.columns - width)
  local height = 1

  state.win = vim.api.nvim_open_win(state.buf, false, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    focusable = false,
    style = 'minimal',
    border = 'single',
    zindex = 50,
  })

  -- Create a custom dark gray border highlight
  vim.cmd("highlight GroveStatusBarBorder guifg=#3c3c3c ctermfg=237")
  vim.wo[state.win].winhighlight = "Normal:StatusLine,FloatBorder:GroveStatusBarBorder"

  -- Handle window resizing
  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      if state.win and vim.api.nvim_win_is_valid(state.win) then
        local new_opts = config.options.ui.status_bar
        local new_row = calculate_row(new_opts.position)
        local new_content = get_bar_content()
        local new_width = math.max(#new_content + 2, 10)
        local new_col = math.max(0, vim.o.columns - new_width)
        vim.api.nvim_win_set_config(state.win, {
          relative = 'editor',
          width = new_width,
          height = 1,
          row = new_row,
          col = new_col,
        })
      end
    end,
  })

  -- Listen for status updates
  vim.api.nvim_create_autocmd("User", {
    pattern = "GroveStatusUpdated",
    callback = M.refresh,
  })

  M.refresh()
end

function M.hide()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win, state.buf = nil, nil
end

function M.toggle()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    M.hide()
  else
    M.show()
  end
end

return M
