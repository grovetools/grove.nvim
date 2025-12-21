local M = {}

M.state = {
  context_size = nil, -- Will become { display = "ctx:1.2k", hl_group = "GroveCtxTokens2", tokens = 1234 }
  rules_file = nil,
  plan_status = nil,
  chat_running = false,
}

local timers = {}
local last_md_buffer = nil  -- Track the last markdown buffer for context updates

local function notify_update()
  vim.api.nvim_exec_autocmds("User", { pattern = "GroveStatusUpdated", modeline = false })
end

-- Update context size cache
local function update_context_size()
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
          elseif tokens > 200000 then
            hl_group = "GroveCtxTokens5"
          elseif tokens > 100000 then
            hl_group = "GroveCtxTokens4"
          elseif tokens > 50000 then
            hl_group = "GroveCtxTokens3"
          elseif tokens > 20000 then
            hl_group = "GroveCtxTokens2"
          elseif tokens > 5000 then
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
  })
end

-- Update rules file cache
local function update_rules_file()
  local cx_path = vim.fn.exepath("cx")
  if cx_path == "" then
    return
  end

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
  })
end

-- Update chat running status
local function update_chat_status()
  local new_value = vim.g.grove_chat_running == true
  if new_value ~= M.state.chat_running then
    M.state.chat_running = new_value
    notify_update()
  end
end

-- Update plan status cache
local function update_plan_status()
  local flow_path = vim.fn.exepath("flow")
  if flow_path == "" then
    return
  end

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

          -- Add plan name first
          if plan_data.plan then
            table.insert(colored_stats, { text = plan_data.plan, hl = "DiagnosticInfo" })
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
  })
end

function M.start()
  if timers.context then return end -- Already running

  -- Initial fetch
  update_context_size()
  update_rules_file()
  update_plan_status()
  update_chat_status()

  -- Start timers
  timers.context = vim.fn.timer_start(5000, update_context_size, { ['repeat'] = -1 })
  timers.rules = vim.fn.timer_start(5000, update_rules_file, { ['repeat'] = -1 })
  timers.plan = vim.fn.timer_start(2000, update_plan_status, { ['repeat'] = -1 })
  timers.chat = vim.fn.timer_start(500, update_chat_status, { ['repeat'] = -1 })

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
    callback = update_context_size,
  })

  -- Update when GroveRules command is run
  vim.api.nvim_create_autocmd("User", {
    pattern = "GroveRulesChanged",
    callback = function()
      update_rules_file()
      vim.defer_fn(update_context_size, 100)
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
