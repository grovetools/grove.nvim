local M = {}

M.state = {
  context_size = nil, -- Will become { display = "ctx:1.2k", hl_group = "GroveCtxTokens2", tokens = 1234 }
  rules_file = nil,
  plan_status = nil,
  current_job_status = nil, -- New: { text = "󰔟 running", hl = "DiagnosticInfo" }
  git_status = nil,
}

local timers = {}

-- Track which polling jobs are currently executing to prevent overlapping spawns
local active_jobs = {
  context = false,
  rules = false,
  plan = false,
  current_job = false,
  git = false,
}
local last_md_buffer = nil  -- Track the last markdown buffer for context updates

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
  interactive_agent = "", -- fa-robot
  headless_agent = "󰭆", -- md-robot_industrial
  chat = "󰭹", -- md-chat
  oneshot = "", -- fa-bullseye
  shell = "", -- seti-shell
}

local function notify_update()
  vim.api.nvim_exec_autocmds("User", { pattern = "GroveStatusUpdated", modeline = false })
end

-- Update context size cache
local function update_context_size()
  if active_jobs.context then return end

  local cx_path = vim.fn.exepath("cx")
  if cx_path == "" then
    return
  end

  -- Get current buffer path to check if it's a chat file
  local buf_path = vim.api.nvim_buf_get_name(0)

  -- If current buffer is markdown, use it and save it
  if buf_path ~= "" and buf_path:match("%.md$") then
    last_md_buffer = buf_path
  -- Otherwise, use the last known markdown buffer
  elseif last_md_buffer then
    buf_path = last_md_buffer
  else
    -- No markdown buffer to work with
    return
  end

  active_jobs.context = true

  -- Run cx stats asynchronously
  vim.fn.jobstart({ cx_path, "stats", "--chat-file", buf_path }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        local stdout = table.concat(data, "\n")
        local ok, stats = pcall(vim.json.decode, stdout)
        if ok and stats and stats.context_tokens then
          local tokens = stats.context_tokens

          -- Format the number (e.g., 13.5k)
          local formatted
          if tokens < 1000 then
            formatted = tostring(tokens)
          elseif tokens < 1000000 then
            formatted = string.format("%.1fk", tokens / 1000)
          else
            formatted = string.format("%.1fM", tokens / 1000000)
          end

          -- Determine highlight group based on token count
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

          local new_data = {
            display = "cx:" .. formatted .. " tokens",
            hl_group = hl_group,
            tokens = tokens,
          }

          -- Only notify if data changed
          local old_data = M.state.context_size
          local has_changed = not old_data or
                              old_data.display ~= new_data.display or
                              old_data.hl_group ~= new_data.hl_group

          M.state.context_size = new_data
          if has_changed then
            notify_update()
          end
        end
      end
    end,
    on_exit = function()
      active_jobs.context = false
    end,
  })
end

-- Update rules file cache
local function update_rules_file()
  if active_jobs.rules then return end

  local cx_path = vim.fn.exepath("cx")
  if cx_path == "" then
    return
  end

  active_jobs.rules = true

  -- Run cx rules print-path to get active rules file path
  vim.fn.jobstart({ cx_path, "rules", "print-path" }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        local stdout = table.concat(data, "\n"):gsub("%s+$", "") -- trim whitespace
        if stdout ~= "" then
          -- Extract directory and filename (e.g., ".grove/rules" or ".cx/default.rules")
          local dir_and_file = stdout:match("([^/]+/[^/]+)$")
          local new_value = nil

          if dir_and_file then
            new_value = dir_and_file
          else
            -- Fallback to just filename if pattern doesn't match
            local filename = stdout:match("([^/]+)$")
            if filename then
              new_value = filename
            end
          end

          -- Only notify if value changed
          if new_value then
            local has_changed = new_value ~= M.state.rules_file
            M.state.rules_file = new_value
            if has_changed then
              notify_update()
            end
          end
        end
      end
    end,
    on_exit = function()
      active_jobs.rules = false
    end,
  })
end

-- Update status of the currently focused job file
local function update_current_job_status()
  if active_jobs.current_job then return end

  local flow_path = vim.fn.exepath("flow")
  if flow_path == "" then
    return
  end

  local current_buf_path = vim.api.nvim_buf_get_name(0)
  if not current_buf_path or not current_buf_path:match("%.md$") then
    if M.state.current_job_status then
      M.state.current_job_status = nil
      notify_update()
    end
    return
  end
  current_buf_path = vim.fn.fnamemodify(current_buf_path, ":p")

  active_jobs.current_job = true

  vim.fn.jobstart({ flow_path, "plan", "status", "--json" }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local stdout = table.concat(data or {}, "\n")
      if stdout:match("^%s*$") then
        if M.state.current_job_status then
          M.state.current_job_status = nil
          notify_update()
        end
        return
      end

      local ok, plan_data = pcall(vim.json.decode, stdout)
      if not ok or not plan_data or not plan_data.jobs then
        return
      end

      local found_job = nil
      for _, job in ipairs(plan_data.jobs) do
        if job.file_path and vim.fn.fnamemodify(job.file_path, ":p") == current_buf_path then
          found_job = job
          break
        end
      end

      local new_status = nil
      if found_job then
        local ui_info = status_map[found_job.status] or { icon = "", icon_hl = "Comment" }
        local type_icon = job_type_icons[found_job.type] or job_type_icons.chat
        new_status = {
          icon = ui_info.icon,
          icon_hl = ui_info.icon_hl,
          status = found_job.status,
          filename = found_job.filename or "",
          type_icon = type_icon,
          model = found_job.model or "",
          template = found_job.template or "",
        }
      end

      local has_changed = vim.json.encode(new_status) ~= vim.json.encode(M.state.current_job_status)
      M.state.current_job_status = new_status
      if has_changed then
        notify_update()
      end
    end,
    on_stderr = function()
      -- Don't clear status on error, prevents flickering if no active plan
    end,
    on_exit = function()
      active_jobs.current_job = false
    end,
  })
end

-- Update plan status cache
local function update_plan_status()
  if active_jobs.plan then return end

  local flow_path = vim.fn.exepath("flow")
  if flow_path == "" then
    return
  end

  active_jobs.plan = true

  -- Simply call flow plan status --json (works from any directory if plan is set)
  vim.fn.jobstart({ flow_path, "plan", "status", "--json" }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        local stdout = table.concat(data, "\n")

        -- Empty output means no plan - clear the status
        if stdout:match("^%s*$") then
          if M.state.plan_status ~= nil then
            M.state.plan_status = nil
            notify_update()
          end
          return
        end

        local ok, plan_data = pcall(vim.json.decode, stdout)

        if ok and plan_data and plan_data.jobs then
          -- Calculate statistics
          local completed = 0
          local running = 0
          local pending = 0
          local failed = 0

          for _, job in ipairs(plan_data.jobs) do
            if job.status == "completed" then
              completed = completed + 1
            elseif job.status == "running" then
              running = running + 1
            elseif job.status == "pending" or job.status == "pending_user" or job.status == "pending_llm" then
              pending = pending + 1
            elseif job.status == "failed" then
              failed = failed + 1
            end
          end

          -- Build stats array with color information
          local colored_stats = {}

          -- Add plan name first (no color)
          if plan_data.plan then
            table.insert(colored_stats, { text = plan_data.plan, hl = "Normal" })
          end

          -- Check if any job is in a worktree (will be shown in git section)
          M.state.has_worktree = false
          for _, job in ipairs(plan_data.jobs) do
            if job.worktree and job.worktree ~= "" then
              M.state.has_worktree = true
              break
            end
          end

          -- Check if all jobs have the same model (plan-level model)
          M.state.plan_model = nil
          if #plan_data.jobs > 0 then
            local first_model = plan_data.jobs[1].model
            local all_same = true
            for _, job in ipairs(plan_data.jobs) do
              if job.model ~= first_model then
                all_same = false
                break
              end
            end
            if all_same and first_model and first_model ~= "" then
              M.state.plan_model = first_model
            end
          end

          if completed > 0 then
            table.insert(colored_stats, { text = "󰄳 " .. completed, hl = "DiagnosticOk" })
          end
          if running > 0 then
            table.insert(colored_stats, { text = "󰔟 " .. running, hl = "DiagnosticInfo" })
          end
          if pending > 0 then
            table.insert(colored_stats, { text = "󰭻 " .. pending, hl = "Comment" })
          end
          if failed > 0 then
            table.insert(colored_stats, { text = " " .. failed, hl = "DiagnosticError" })
          end

          -- Only notify if the data has actually changed
          local old_status = M.state.plan_status
          local has_changed = false

          if #colored_stats > 0 then
            -- Check if anything changed
            if not old_status or #old_status ~= #colored_stats then
              has_changed = true
            else
              for i, stat in ipairs(colored_stats) do
                if not old_status[i] or old_status[i].text ~= stat.text or old_status[i].hl ~= stat.hl then
                  has_changed = true
                  break
                end
              end
            end

            -- Always update state but only notify if changed
            M.state.plan_status = colored_stats
            if has_changed then
              notify_update()
            end
          else
            if old_status ~= nil then
              M.state.plan_status = nil
              notify_update()
            end
          end
        else
          -- No active plan or error parsing - but don't clear if we had data
          -- Keep the old data to prevent flashing
        end
      end
    end,
    on_stderr = function(_, data)
      -- Don't clear on stderr - the command might just not have an active plan
      -- Keep existing data to prevent flashing
    end,
    on_exit = function()
      active_jobs.plan = false
    end,
  })
end

-- Update git status cache
local function update_git_status()
  if active_jobs.git then return end

  local grove_nvim_path = vim.fn.exepath("grove-nvim")
  if grove_nvim_path == "" then
    return
  end

  local cwd = vim.fn.getcwd()

  active_jobs.git = true

  -- Run grove-nvim internal git-status asynchronously
  vim.fn.jobstart({ grove_nvim_path, "internal", "git-status", cwd }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        local stdout = table.concat(data, "\n")
        local ok, status = pcall(vim.json.decode, stdout)

        if ok and status then
          -- Check if status object is empty (not a git repo)
          if vim.tbl_isempty(status) then
            if M.state.git_status ~= nil then
              M.state.git_status = nil
              notify_update()
            end
            return
          end

          local has_changed = vim.json.encode(status) ~= vim.json.encode(M.state.git_status)
          M.state.git_status = status
          if has_changed then
            notify_update()
          end
        end
      end
    end,
    on_stderr = function()
      -- Silently ignore stderr
    end,
    on_exit = function()
      active_jobs.git = false
    end,
  })
end

function M.start()
  if timers.context then return end -- Already running

  -- Initial fetch
  update_context_size()
  update_rules_file()
  update_plan_status()
  update_current_job_status()
  update_git_status()

  -- Start timers
  timers.context = vim.fn.timer_start(5000, update_context_size, { ['repeat'] = -1 })
  timers.rules = vim.fn.timer_start(5000, update_rules_file, { ['repeat'] = -1 })
  timers.plan = vim.fn.timer_start(2000, update_plan_status, { ['repeat'] = -1 })
  timers.job = vim.fn.timer_start(3000, update_current_job_status, { ['repeat'] = -1 })
  timers.git = vim.fn.timer_start(3000, update_git_status, { ['repeat'] = -1 })

  -- Update context size when rules file is written
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = { "*/rules", "*.rules" },
    callback = function()
      -- Delay slightly to let cx process the new rules
      vim.defer_fn(function()
        update_rules_file()
        update_context_size()
      end, 100)
    end,
  })

  -- Update context when switching buffers
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    pattern = "*.md",
    callback = function()
      update_context_size()
      update_current_job_status()
    end,
  })

  -- Update when GroveRules command is run
  vim.api.nvim_create_autocmd("User", {
    pattern = "GroveRulesChanged",
    callback = function()
      update_rules_file()
      vim.defer_fn(update_context_size, 100)
    end,
  })

  -- Update git status on directory changes
  vim.api.nvim_create_autocmd({ "DirChanged", "BufEnter" }, {
    callback = function()
      update_git_status()
    end,
  })
end

function M.stop()
  for _, timer in pairs(timers) do
    if timer then vim.fn.timer_stop(timer) end
  end
  timers = {}
end

return M
