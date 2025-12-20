local M = {}
local config = require("grove-nvim.config")
local provider = require("grove-nvim.status_provider")

local state = {
  win = nil,
  buf = nil,
}

local function get_bar_content()
  local parts = {}
  local p_state = provider.state

  if p_state.plan_status and #p_state.plan_status > 0 then
    -- Format plan status
    local plan_parts = {}
    for _, stat in ipairs(p_state.plan_status) do
      table.insert(plan_parts, stat.text)
    end
    table.insert(parts, table.concat(plan_parts, " "))
  end

  if p_state.rules_file then
    table.insert(parts, p_state.rules_file)
  end

  if p_state.context_size then
    table.insert(parts, p_state.context_size.display)
  end

  return table.concat(parts, " | ")
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

  vim.api.nvim_buf_set_option(state.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { content })
  vim.api.nvim_buf_set_option(state.buf, "modifiable", false)

  -- Update window size based on content
  local opts = config.options.ui.status_bar
  local height = 1
  local row = opts.position == 'top' and 0 or (vim.o.lines - height - 1)
  local width = math.max(#content + 2, 10)  -- Minimum width of 10
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

  -- Apply highlights
  local p_state = provider.state
  local offset = 0

  -- Highlight plan status parts
  if p_state.plan_status and #p_state.plan_status > 0 then
    for i, stat in ipairs(p_state.plan_status) do
      local text_len = #stat.text
      vim.api.nvim_buf_add_highlight(state.buf, 0, stat.hl, 0, offset, offset + text_len)
      offset = offset + text_len
      if i < #p_state.plan_status then
        offset = offset + 1 -- space separator
      end
    end
    offset = offset + 3 -- " | "
  end

  -- Highlight rules file
  if p_state.rules_file then
    offset = offset + #p_state.rules_file + 3 -- + " | "
  end

  -- Highlight context size
  if p_state.context_size then
    local match_start = content:find(p_state.context_size.display, 1, true)
    if match_start then
      vim.api.nvim_buf_add_highlight(
        state.buf,
        0,
        p_state.context_size.hl_group,
        0,
        match_start - 1,
        match_start - 1 + #p_state.context_size.display
      )
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
  local height = 1
  local row = opts.position == 'top' and 0 or (vim.o.lines - height - 1)

  -- Calculate width and column based on content
  local content = get_bar_content()
  local width = math.max(#content + 2, 10)  -- Minimum width of 10
  local col = math.max(0, vim.o.columns - width)

  state.win = vim.api.nvim_open_win(state.buf, false, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    focusable = false,
    style = 'minimal',
    border = 'none',
    zindex = 50,
  })

  vim.wo[state.win].winhighlight = "Normal:StatusLine"

  -- Handle window resizing
  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      if state.win and vim.api.nvim_win_is_valid(state.win) then
        local new_opts = config.options.ui.status_bar
        local new_row = new_opts.position == 'top' and 0 or (vim.o.lines - height - 1)
        local new_content = get_bar_content()
        local new_width = math.max(#new_content + 2, 10)
        local new_col = math.max(0, vim.o.columns - new_width)
        vim.api.nvim_win_set_config(state.win, {
          relative = 'editor',
          width = new_width,
          height = height,
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
