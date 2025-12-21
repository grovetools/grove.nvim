local M = {}
local config = require("grove-nvim.config")
local provider = require("grove-nvim.status_provider")

local state = {
  win = nil,
  buf = nil,
}

--- Gets the current height of the status bar window if it's enabled and at the bottom.
function M.get_height()
  if not config.options.ui.status_bar.enable or config.options.ui.status_bar.position ~= 'bottom' then
    return 0
  end
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    return vim.api.nvim_win_get_height(state.win)
  end
  return 0
end

-- Helper to calculate row position accounting for statusline
local function calculate_row(position, height)
  height = height or 1
  if position == 'top' then
    return 0
  end
  local statusline_height = (vim.o.laststatus > 0) and 1 or 0
  return vim.o.lines - statusline_height - height
end

local function get_bar_content()
  local all_parts = {}
  local p_state = provider.state

  -- Plan status (show first - aggregate plan data)
  if p_state.plan_status and #p_state.plan_status > 0 then
    local plan_part_items = {}
    -- Format plan status with icon
    for _, stat in ipairs(p_state.plan_status) do
      table.insert(plan_part_items, stat.text)
    end
    local plan_part = "Plan: 󰠡 " .. table.concat(plan_part_items, " ")
    table.insert(all_parts, plan_part)
  end

  -- Git status
  if p_state.git_status and p_state.git_status.is_dirty then
    local git_parts = {}
    local status = p_state.git_status
    local is_main = status.branch == "main" or status.branch == "master"
    if not is_main and (status.ahead_main_count > 0 or status.behind_main_count > 0) then
      if status.ahead_main_count > 0 then table.insert(git_parts, "⇡" .. status.ahead_main_count) end
      if status.behind_main_count > 0 then table.insert(git_parts, "⇣" .. status.behind_main_count) end
    elseif status.has_upstream then
      if status.ahead_count > 0 then table.insert(git_parts, "↑" .. status.ahead_count) end
      if status.behind_count > 0 then table.insert(git_parts, "↓" .. status.behind_count) end
    end
    if status.modified_count > 0 then table.insert(git_parts, "M:" .. status.modified_count) end
    if status.staged_count > 0 then table.insert(git_parts, "S:" .. status.staged_count) end
    if status.untracked_count > 0 then table.insert(git_parts, "?:" .. status.untracked_count) end
    if status.lines_added > 0 then table.insert(git_parts, "+" .. status.lines_added) end
    if status.lines_deleted > 0 then table.insert(git_parts, "-" .. status.lines_deleted) end

    if #git_parts > 0 then
      local git_part = "Git: 󰊢 " .. table.concat(git_parts, " ")
      table.insert(all_parts, git_part)
    end
  end

  -- Current job filename and status
  if p_state.current_job_status then
    local job_part = "Job: "
    if p_state.current_job_status.filename ~= "" then
      -- Add job type icon before filename
      local type_icon = p_state.current_job_status.type_icon or ""
      if type_icon ~= "" then
        job_part = job_part .. type_icon .. " " .. p_state.current_job_status.filename .. " "
      else
        job_part = job_part .. p_state.current_job_status.filename .. " "
      end
    end
    job_part = job_part .. p_state.current_job_status.icon .. " " .. p_state.current_job_status.status

    -- Add model if present
    if p_state.current_job_status.model and p_state.current_job_status.model ~= "" then
      job_part = job_part .. " 󰚩 " .. p_state.current_job_status.model
    end

    table.insert(all_parts, job_part)
  end

  if p_state.context_size then
    -- Remove "cx:" prefix from display
    local ctx_display = p_state.context_size.display:gsub("^cx:", "")
    local ctx_part = "Context: 󰄨 " .. ctx_display
    -- Add rules file in parens if present
    if p_state.rules_file then
      ctx_part = ctx_part .. " (" .. p_state.rules_file .. ")"
    end
    table.insert(all_parts, ctx_part)
  end

  if #all_parts == 0 then
    return {}
  end

  local single_line = table.concat(all_parts, "  │  ")
  local total_width = vim.fn.strdisplaywidth(single_line)
  local max_width = vim.o.columns * 0.8

  if total_width > max_width and #all_parts > 1 then
    -- Smart split: Line 1 gets Plan + Git, Line 2 gets Job + Context
    -- This maintains logical grouping when we have all 4 components
    local split_at = 2 -- Split after 2nd component (Plan, Git)

    if #all_parts >= 4 then
      -- We have all 4 components: Plan, Git, Job, Context
      -- Format as: "Plan  │  Git" and "Job  │  Context"
      -- with the │ separators aligned vertically
      local line1_left = all_parts[1]  -- Plan
      local line1_right = all_parts[2] -- Git
      local line2_left = all_parts[3]  -- Job
      local line2_right = all_parts[4] -- Context

      -- Calculate widths
      local line1_left_width = vim.fn.strdisplaywidth(line1_left)
      local line2_left_width = vim.fn.strdisplaywidth(line2_left)
      local max_left_width = math.max(line1_left_width, line2_left_width)

      -- Pad left sections to align the │ separator
      local line1_left_padded = line1_left .. string.rep(" ", max_left_width - line1_left_width)
      local line2_left_padded = line2_left .. string.rep(" ", max_left_width - line2_left_width)

      return {
        line1_left_padded .. "  │  " .. line1_right,
        line2_left_padded .. "  │  " .. line2_right
      }
    else
      -- Fallback for fewer than 4 components
      local line1_parts = { table.unpack(all_parts, 1, math.min(split_at, #all_parts)) }
      local line2_parts = {}
      if #all_parts > split_at then
        line2_parts = { table.unpack(all_parts, split_at + 1) }
      end

      if #line2_parts > 0 then
        return { table.concat(line1_parts, "  │  "), table.concat(line2_parts, "  │  ") }
      else
        return { table.concat(line1_parts, "  │  ") }
      end
    end
  else
    return { single_line }
  end
end

local function do_refresh()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end

  local content_lines = get_bar_content()

  -- If content is empty, hide the window but don't delete it
  if #content_lines == 0 then
    vim.api.nvim_win_hide(state.win)
    return
  end

  -- Show the window if it was hidden
  if not vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_config(state.win, { hide = false })
  end

  -- Find max line width first
  local max_line_width = 0
  for _, line in ipairs(content_lines) do
    max_line_width = math.max(max_line_width, vim.fn.strdisplaywidth(line))
  end

  -- Pad all lines to max width and add left padding
  local padded_content_lines = {}
  for _, line in ipairs(content_lines) do
    local line_width = vim.fn.strdisplaywidth(line)
    local padding = string.rep(" ", max_line_width - line_width)
    table.insert(padded_content_lines, " " .. line .. padding)
  end

  vim.api.nvim_buf_set_option(state.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, padded_content_lines)
  vim.api.nvim_buf_set_option(state.buf, "modifiable", false)

  -- Update window size based on content display width
  local height = #content_lines
  local opts = config.options.ui.status_bar
  local row = calculate_row(opts.position, height)
  local width = max_line_width + 3 -- +2 for border, +1 for left padding
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

  -- Define italic label highlight and non-italic override
  vim.cmd("highlight default GroveStatusLabel gui=italic cterm=italic")
  vim.cmd("highlight default GroveStatusContent gui=NONE cterm=NONE")

  -- Define highlights for git status parts
  vim.cmd("highlight default GroveStatusGitAhead guifg=#61afef") -- Blue/Info
  vim.cmd("highlight default GroveStatusGitBehind guifg=#e06c75") -- Red/Error
  vim.cmd("highlight default GroveStatusGitModified guifg=#d19a66") -- Orange/Warn
  vim.cmd("highlight default GroveStatusGitStaged guifg=#61afef") -- Blue/Info
  vim.cmd("highlight default GroveStatusGitUntracked guifg=#e06c75") -- Red/Error
  vim.cmd("highlight default GroveStatusGitAdded guifg=#98c379") -- Green/Add
  vim.cmd("highlight default GroveStatusGitDeleted guifg=#e06c75") -- Red/Delete

  for line_idx, padded_content in ipairs(padded_content_lines) do
    local p_state = provider.state
    local current_line_num = line_idx - 1

    -- Highlight current job status icon only
    if p_state.current_job_status and vim.fn.stridx(padded_content, "Job:") >= 0 then
      local job_label_start = vim.fn.stridx(padded_content, "Job:")
      if job_label_start >= 0 then
        local icon = p_state.current_job_status.icon
        local search_start = job_label_start + #"Job:"
        local remaining_content = string.sub(padded_content, search_start + 1)
        local icon_pos = vim.fn.stridx(remaining_content, icon)
        if icon_pos >= 0 then
          local byte_start = search_start + icon_pos
          local byte_end = byte_start + #icon
          vim.api.nvim_buf_add_highlight(
            state.buf,
            0,
            p_state.current_job_status.icon_hl,
            current_line_num,
            byte_start,
            byte_end
          )
        end
      end
    end

    -- Highlight plan status parts
    if p_state.plan_status and #p_state.plan_status > 0 and vim.fn.stridx(padded_content, "Plan:") >= 0 then
      local plan_icon = "󰠡 "
      local plan_byte_start = vim.fn.stridx(padded_content, plan_icon)
      if plan_byte_start >= 0 then
        local byte_offset = plan_byte_start + #plan_icon
        for i, stat in ipairs(p_state.plan_status) do
          local text_byte_len = #stat.text
          vim.api.nvim_buf_add_highlight(state.buf, 0, stat.hl, current_line_num, byte_offset, byte_offset + text_byte_len)
          byte_offset = byte_offset + text_byte_len
          if i < #p_state.plan_status then
            byte_offset = byte_offset + 1
          end
        end
      end
    end

    -- Highlight context size
    if p_state.context_size and vim.fn.stridx(padded_content, "Context:") >= 0 then
      local ctx_pattern = p_state.context_size.display:gsub("^cx:", "")
      local ctx_byte_start = vim.fn.stridx(padded_content, ctx_pattern)
      if ctx_byte_start >= 0 then
        local ctx_byte_end = ctx_byte_start + #ctx_pattern
        vim.api.nvim_buf_add_highlight(
          state.buf,
          0,
          p_state.context_size.hl_group,
          current_line_num,
          ctx_byte_start,
          ctx_byte_end
        )
      end
      if p_state.rules_file then
        local rules_pattern = "(" .. p_state.rules_file .. ")"
        local rules_byte_start = vim.fn.stridx(padded_content, rules_pattern)
        if rules_byte_start >= 0 then
          local rules_byte_end = rules_byte_start + #rules_pattern
          vim.api.nvim_buf_add_highlight(state.buf, 0, "Comment", current_line_num, rules_byte_start, rules_byte_end)
        end
      end
    end

    -- Apply labels
    local labels = { "Plan:", "Job:", "Context:", "Git:" }
    for _, label in ipairs(labels) do
      local label_start = vim.fn.stridx(padded_content, label)
      if label_start >= 0 then
        vim.api.nvim_buf_add_highlight(state.buf, 0, "GroveStatusLabel", current_line_num, label_start, label_start + #label)
      end
    end

    -- Highlight git status parts
    if p_state.git_status and p_state.git_status.is_dirty and vim.fn.stridx(padded_content, "Git:") >= 0 then
      local status = p_state.git_status
      local git_highlights = {}
      local is_main = status.branch == "main" or status.branch == "master"
      if not is_main and (status.ahead_main_count > 0 or status.behind_main_count > 0) then
        if status.ahead_main_count > 0 then git_highlights["⇡" .. status.ahead_main_count] = "GroveStatusGitAhead" end
        if status.behind_main_count > 0 then git_highlights["⇣" .. status.behind_main_count] = "GroveStatusGitBehind" end
      elseif status.has_upstream then
        if status.ahead_count > 0 then git_highlights["↑" .. status.ahead_count] = "GroveStatusGitAhead" end
        if status.behind_count > 0 then git_highlights["↓" .. status.behind_count] = "GroveStatusGitBehind" end
      end
      if status.modified_count > 0 then git_highlights["M:" .. status.modified_count] = "GroveStatusGitModified" end
      if status.staged_count > 0 then git_highlights["S:" .. status.staged_count] = "GroveStatusGitStaged" end
      if status.untracked_count > 0 then git_highlights["?:" .. status.untracked_count] = "GroveStatusGitUntracked" end
      if status.lines_added > 0 then git_highlights["+" .. status.lines_added] = "GroveStatusGitAdded" end
      if status.lines_deleted > 0 then git_highlights["-" .. status.lines_deleted] = "GroveStatusGitDeleted" end

      for pattern, hl_group in pairs(git_highlights) do
        local start = vim.fn.stridx(padded_content, pattern)
        if start >= 0 then
          vim.api.nvim_buf_add_highlight(state.buf, 0, hl_group, current_line_num, start, start + #pattern)
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
  local content = get_bar_content()
  local width = 10
  local height = 1
  local row = calculate_row(opts.position, height)
  local col = math.max(0, vim.o.columns - width)

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

  -- Link border to a theme-aware group
  vim.cmd("highlight default link GroveStatusBarBorder Comment")
  vim.wo[state.win].winhighlight = "Normal:StatusLine,FloatBorder:GroveStatusBarBorder"

  -- Handle window resizing
  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      if state.win and vim.api.nvim_win_is_valid(state.win) then
        M.refresh()
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
