local M = {}

M.state = {
  workspaces = {},  -- Map of path -> EnrichedWorkspace
  jobs = {},        -- Map of job_id -> JobInfo
  context_size = nil,
  rules_file = nil,
}

local stream_job_id = nil

-- A mapping from flow status strings to UI elements
-- Colors match grove-flow TUI theme (Success=green, Info=blue, Error=red, Warning=orange, Highlight=yellow, Muted=gray, Magenta=magenta)
local status_map = {
  completed = { icon = "󰄳", icon_hl = "DiagnosticOk" },        -- Success (green)
  running = { icon = "󰔟", icon_hl = "DiagnosticInfo" },         -- Info (blue)
  failed = { icon = "", icon_hl = "DiagnosticError" },          -- Error (red)
  pending = { icon = "󰄱", icon_hl = "DiagnosticWarn" },         -- Warning (yellow/orange)
  pending_user = { icon = "󰭻", icon_hl = "DiagnosticWarn" },    -- Warning (yellow/orange)
  pending_llm = { icon = "󰭻", icon_hl = "DiagnosticWarn" },     -- Warning (yellow/orange)
  blocked = { icon = "", icon_hl = "DiagnosticError" },         -- Error (red)
  needs_review = { icon = "", icon_hl = "DiagnosticInfo" },     -- Info (blue)
  hold = { icon = "󰏧", icon_hl = "DiagnosticWarn" },            -- Warning (orange)
  abandoned = { icon = "󰩹", icon_hl = "Comment" },              -- Muted (gray)
  interrupted = { icon = "", icon_hl = "Special" },             -- Magenta
  todo = { icon = "󰄱", icon_hl = "Comment" },                   -- Muted (gray)
}

-- A mapping from job type to icon (matches grove-flow)
local job_type_icons = {
  interactive_agent = "", -- fa-robot
  headless_agent = "󰭆", -- md-robot_industrial
  chat = "󰭹", -- md-chat
  oneshot = "", -- fa-bullseye
  shell = "", -- seti-shell
}

-- Expose status_map and job_type_icons for consumers (status_bar, lualine)
M.status_map = status_map
M.job_type_icons = job_type_icons

local function notify_update()
  vim.schedule(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "GroveStatusUpdated", modeline = false })
  end)
end

--- Find the workspace whose path is the longest prefix of the current buffer.
--- Also matches notebook plan paths (e.g., .../nb/workspaces/<project>/plans/<workspace>/...).
function M.get_current_workspace()
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path == "" then return nil end

  -- Direct path prefix match (buffer is inside the workspace directory)
  local best_match = nil
  local best_len = 0

  for ws_path, ws_data in pairs(M.state.workspaces) do
    if vim.startswith(buf_path, ws_path) and string.len(ws_path) > best_len then
      best_match = ws_data
      best_len = string.len(ws_path)
    end
  end

  if best_match then return best_match end

  -- Notebook plan path match: extract plan dir name from paths like
  -- .../plans/<plan-name>/file.md and match against workspace name or
  -- the last component of the workspace path.
  local plan_name = buf_path:match("/plans/([^/]+)/")
  if plan_name then
    for _, ws_data in pairs(M.state.workspaces) do
      local ws_leaf = ws_data.path and ws_data.path:match("([^/]+)$")
      if ws_leaf and ws_leaf == plan_name then
        return ws_data
      end
      if ws_data.name and ws_data.name == plan_name then
        return ws_data
      end
    end
  end

  return nil
end

--- Find job info for the current buffer by matching job_file to the buffer's filename.
function M.get_current_job()
  local buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
  if buf_name == "" then return nil end

  for _, job in pairs(M.state.jobs) do
    if job.job_file == buf_name then
      return job
    end
  end
  return nil
end

--- Format plan stats from a PlanStats object into the colored_stats array
--- used by the status bar and lualine components.
function M.format_plan_status(plan_stats)
  if not plan_stats then return nil end

  local colored_stats = {}

  -- Add plan name first
  if plan_stats.active_plan and plan_stats.active_plan ~= "" then
    table.insert(colored_stats, { text = plan_stats.active_plan, hl = "Normal" })
  end

  if plan_stats.completed and plan_stats.completed > 0 then
    table.insert(colored_stats, { text = "󰄳 " .. plan_stats.completed, hl = "DiagnosticOk" })
  end
  if plan_stats.running and plan_stats.running > 0 then
    table.insert(colored_stats, { text = "󰔟 " .. plan_stats.running, hl = "DiagnosticInfo" })
  end
  if plan_stats.pending and plan_stats.pending > 0 then
    table.insert(colored_stats, { text = "󰭻 " .. plan_stats.pending, hl = "Comment" })
  end
  if plan_stats.failed and plan_stats.failed > 0 then
    table.insert(colored_stats, { text = " " .. plan_stats.failed, hl = "DiagnosticError" })
  end

  if #colored_stats == 0 then return nil end
  return colored_stats
end

--- Format a job from daemon state into the current_job_status shape
--- used by the status bar and lualine components.
function M.format_job_status(job)
  if not job then return nil end

  local ui_info = status_map[job.status] or { icon = "", icon_hl = "Comment" }
  local type_icon = job_type_icons[job.type] or job_type_icons.chat

  return {
    icon = ui_info.icon,
    icon_hl = ui_info.icon_hl,
    status = job.status,
    filename = job.filename or job.job_file or "",
    type_icon = type_icon,
    model = job.model or "",
    template = job.template or "",
  }
end

--- Format CxStats into the context_size shape used by the status bar.
function M.format_context_size(cx_stats)
  if not cx_stats or not cx_stats.total_tokens then return nil end

  local tokens = cx_stats.total_tokens

  local formatted
  if tokens < 1000 then
    formatted = tostring(tokens)
  elseif tokens < 1000000 then
    formatted = string.format("%.1fk", tokens / 1000)
  else
    formatted = string.format("%.1fM", tokens / 1000000)
  end

  local hl_group = "GroveCtxTokens0"
  if tokens > 1000000 then
    hl_group = "GroveCtxTokensWarn"
  elseif tokens > 800000 then
    hl_group = "GroveCtxTokens5"
  elseif tokens > 400000 then
    hl_group = "GroveCtxTokens4"
  elseif tokens > 200000 then
    hl_group = "GroveCtxTokens3"
  elseif tokens > 100000 then
    hl_group = "GroveCtxTokens2"
  elseif tokens > 50000 then
    hl_group = "GroveCtxTokens1"
  end

  return {
    display = "cx:" .. formatted .. " tokens",
    hl_group = hl_group,
    tokens = tokens,
  }
end

--- Remove any running state directives from a buffer and save.
local function clean_running_directives(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i = #lines, 1, -1 do
    local json_str = lines[i]:match("%s*<!%-%- grove: (.-) %-%->%s*")
    if json_str then
      local parse_ok, data = pcall(vim.json.decode, json_str)
      if parse_ok and type(data) == "table" and data.state == "running" then
        local start_line = i - 1
        -- Also remove the blank line before it if present
        if start_line > 0 and lines[start_line]:match("^%s*$") then
          vim.api.nvim_buf_set_lines(bufnr, start_line - 1, i, false, {})
        else
          vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, {})
        end
      end
    end
  end
end

--- Reload buffer matching a completed/failed job, then clean running directives.
local function reload_job_buffer(job)
  if not job or not job.job_file then return end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      -- Match by filename since buffer may be opened via notebook path
      if vim.fn.fnamemodify(buf_name, ":t") == job.job_file then
        vim.api.nvim_buf_call(bufnr, function()
          vim.cmd('silent! checktime')
        end)
        -- After reload, clean up any running directives left in the file
        vim.defer_fn(function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            clean_running_directives(bufnr)
            vim.api.nvim_buf_call(bufnr, function()
              vim.cmd('silent! write')
            end)
          end
        end, 100)
        break
      end
    end
  end
end

function M._process_line(line)
  local ok, update = pcall(vim.json.decode, line)
  if not ok then return end
  if not update or not update.update_type then return end

  -- Workspace updates
  if update.workspaces then
    for _, ws in ipairs(update.workspaces) do
      if ws.path then
        M.state.workspaces[ws.path] = ws
      end
    end
    notify_update()
  end

  -- Job lifecycle events — track state and reload buffer on completion
  if vim.startswith(update.update_type, "job_") and update.payload then
    local job = update.payload
    if job and job.id then
      M.state.jobs[job.id] = job
      notify_update()

      if update.update_type == "job_completed"
        or update.update_type == "job_failed"
        or update.update_type == "job_pending_user" then
        vim.schedule(function()
          reload_job_buffer(job)
        end)
      end
    end
  end
end

function M.start()
  if stream_job_id then return end

  local utils = require('grove-nvim.utils')
  local grove_nvim_path = utils.get_grove_nvim_binary()
  if not grove_nvim_path then return end

  local partial_line = ""

  local cmd = {grove_nvim_path, 'internal', 'stream-state', vim.fn.getcwd()}

  stream_job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    on_stdout = function(_, data)
      if not data then return end

      -- Neovim delivers stdout as an array split on newlines.
      -- The last element is "" if the chunk ended with \n, or a partial line otherwise.
      -- We accumulate partials and process complete lines.
      for idx, chunk in ipairs(data) do
        if idx == 1 then
          -- Prepend leftover from previous callback
          partial_line = partial_line .. chunk
        elseif idx == #data then
          -- Last element: if non-empty it's a partial; if "" the previous element was complete
          if chunk ~= "" then
            -- Process the completed previous partial, start new partial
            local completed = partial_line
            partial_line = chunk
            if completed ~= "" then
              M._process_line(completed)
            end
          else
            -- Previous line was complete, process it
            if partial_line ~= "" then
              M._process_line(partial_line)
              partial_line = ""
            end
          end
        else
          -- Middle elements are always complete lines
          if partial_line ~= "" then
            M._process_line(partial_line)
            partial_line = ""
          end
          if chunk ~= "" then
            M._process_line(chunk)
          end
        end
      end
    end,
    on_exit = function()
      stream_job_id = nil
      -- Retry connection after a short delay if it died
      vim.defer_fn(M.start, 5000)
    end
  })
end

function M.stop()
  if stream_job_id then
    vim.fn.jobstop(stream_job_id)
    stream_job_id = nil
  end
end

return M
