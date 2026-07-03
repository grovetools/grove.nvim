local M = {}
local utils = require('grove-nvim.utils')

-- Get available templates
function M.get_templates(callback)
  local grove_nvim_path = vim.fn.exepath('grove-nvim')
  if grove_nvim_path == '' then
    callback({})
    return
  end

  utils.run_command({ grove_nvim_path, 'plan', 'template-list', '--json' }, function(stdout, stderr, exit_code)
    if exit_code ~= 0 or stdout == "" then
      callback({})
      return
    end

    local ok, templates = pcall(vim.json.decode, stdout)
    if ok and templates then
      callback(templates)
    else
      -- Fallback: parse text output
      local template_list = {}
      local lines = vim.split(stdout, '\n')
      for i, line in ipairs(lines) do
        if i > 1 and line:match('%S') then  -- Skip header and empty lines
          -- More flexible parsing to handle various spacing
          local parts = vim.split(line, '%s+', { trimempty = true })
          if #parts >= 2 then
            local name = parts[1]
            local source = parts[2]
            -- Join remaining parts as description
            local desc = ""
            if #parts > 2 then
              local desc_parts = {}
              for j = 3, #parts do
                table.insert(desc_parts, parts[j])
              end
              desc = table.concat(desc_parts, " ")
            end
            table.insert(template_list, {
              name = name,
              source = source,
              description = desc
            })
          end
        end
      end
      callback(template_list)
    end
  end)
end

-- Get available ecosystem skills.
-- The skill set is stable per nvim session, so the decoded list is cached in
-- M._skills_cache and short-circuited on subsequent calls. To bust the cache
-- without restarting nvim, run :GroveSkillsRefresh (registered in the plugin)
-- or `:lua require('grove-nvim.data')._skills_cache = nil`.
M._skills_cache = nil
function M.get_skills(callback)
  if M._skills_cache then
    callback(M._skills_cache)
    return
  end

  -- `skills` is grove-managed and may not be on $PATH, so prefer the grove bin
  -- directory and fall back to exepath for bare-nvim launches.
  local skills_path = utils.get_grove_bin_dir() .. '/skills'
  if vim.fn.filereadable(skills_path) == 0 then
    skills_path = vim.fn.exepath('skills')
  end
  if skills_path == '' then
    callback({})
    return
  end

  utils.run_command({ skills_path, 'list', '--json' }, function(stdout, stderr, exit_code)
    if exit_code ~= 0 or stdout == "" then
      callback({})
      return
    end

    local list = {}
    local ok, arr = pcall(vim.json.decode, stdout)
    if ok and type(arr) == 'table' then
      for _, s in ipairs(arr) do
        if s.name then
          table.insert(list, { name = s.name, source = s.source, configured = s.configured })
        end
      end
    else
      -- Fallback: parse the tabwriter table. The legacy (non-workspace) header
      -- is `SKILL  SOURCE`; the workspace header is `SKILL  CONFIGURED  SOURCE`.
      -- In both, column 1 is the skill name, so that parse works either way.
      local lines = vim.split(stdout, '\n')
      for i, line in ipairs(lines) do
        if i > 1 and line:match('%S') then  -- Skip header and empty lines
          local name = line:match('^(%S+)')
          if name then
            table.insert(list, { name = name })
          end
        end
      end
    end

    M._skills_cache = list
    callback(list)
  end)
end

-- Get available models
function M.get_models(callback)
  local grove_nvim_path = vim.fn.exepath('grove-nvim')
  if grove_nvim_path == '' then
    callback({})
    return
  end

  utils.run_command({ grove_nvim_path, 'models', 'list', '--json' }, function(stdout, stderr, exit_code)
    if exit_code ~= 0 or stdout == "" then
      vim.notify("Grove: Could not fetch models. " .. stderr, vim.log.levels.WARN)
      callback({})
      return
    end

    local ok, data = pcall(vim.json.decode, stdout)
    if ok and data and data.models then
      callback(data.models)
    else
      -- Fallback: try parsing without --json flag
      utils.run_command({ grove_nvim_path, 'models', 'list' }, function(stdout2, stderr2, exit_code2)
        if exit_code2 == 0 and stdout2 ~= "" then
          local model_list = {}
          for line in stdout2:gmatch("[^\n]+") do
            if not line:match("^ID") and line:match("%S") then -- Skip header and empty
              local id = line:match("^%s*([^%s]+)")
              if id then
                table.insert(model_list, { id = id, provider = "unknown" })
              end
            end
          end
          callback(model_list)
        else
          callback({})
        end
      end)
    end
  end)
end

-- Get dependencies helper function
function M.get_dependencies(plan_path, callback)
  -- Use flow directly instead of grove-nvim as it has the --format flag
  local flow_path = vim.fn.exepath('flow')
  if flow_path == '' then
    callback({})
    return
  end

  local cmd_args = { flow_path, 'plan', 'status', plan_path, '--format', 'json' }
  utils.run_command(cmd_args, function(stdout, stderr, exit_code)
    if exit_code ~= 0 or stdout == "" then
      callback({})
      return
    end

    local ok, plan_data = pcall(vim.json.decode, stdout)
    if not ok or not plan_data or not plan_data.jobs or #plan_data.jobs == 0 then
      callback({})
      return
    end

    local job_items = {}
    for _, job in ipairs(plan_data.jobs) do
      local status_icon = "📋" -- Default job icon
      if job.status == "completed" then status_icon = "✅"
      elseif job.status == "failed" then status_icon = "❌"
      elseif job.status == "running" then status_icon = "🏃"
      elseif job.status == "pending" then status_icon = "⏳"
      end

      local job_text = string.format("%s %s - %s", status_icon, job.filename or job.id, job.title or "Untitled")
      table.insert(job_items, {
        text = job_text,
        value = job.filename or job.id,
      })
    end
    callback(job_items)
  end)
end

-- Get the active plan from .grove/state.yml
function M.get_active_plan()
  local state_file = vim.fn.getcwd() .. '/.grove/state.yml'
  if vim.fn.filereadable(state_file) == 0 then
    return nil
  end

  local lines = vim.fn.readfile(state_file)
  for _, line in ipairs(lines) do
    -- Check for new format: flow.active_plan:
    local plan = line:match("^flow%.active_plan:%s*(.+)%s*$")
    if plan then
      return plan
    end
    -- Fallback to old format: active_plan:
    plan = line:match("^active_plan:%s*(.+)%s*$")
    if plan then
      return plan
    end
  end

  return nil
end

-- Get git repository shorthands for completion
function M.get_git_repo_shorthands(callback)
  local cx_path = vim.fn.exepath('cx')
  if cx_path == '' then
    callback({})
    return
  end

  utils.run_command({ cx_path, 'repo', 'list', '--json' }, function(stdout, stderr, exit_code)
    if exit_code ~= 0 or stdout == "" then
      callback({})
      return
    end

    -- Parse JSON output
    local ok, repos = pcall(vim.json.decode, stdout)
    if not ok or not repos then
      callback({})
      return
    end

    -- Extract shorthands from the shorthand field
    local shorthands = {}
    for _, repo in ipairs(repos) do
      if repo.shorthand and repo.shorthand ~= "" then
        table.insert(shorthands, repo.shorthand)
      end
    end

    callback(shorthands)
  end)
end

return M
