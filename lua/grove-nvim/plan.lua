local M = {}

-- Helper to run a command and capture output
local function run_command(cmd_args, callback)
  local stdout_data = {}
  local stderr_data = {}
  
  local job_id = vim.fn.jobstart(cmd_args, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(stdout_data, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(stderr_data, data)
      end
    end,
    on_exit = function(_, exit_code)
      local stdout = table.concat(stdout_data, "\n")
      local stderr = table.concat(stderr_data, "\n")
      callback(stdout, stderr, exit_code)
    end,
  })
  
  if job_id <= 0 then
    callback("", "Failed to start command", -1)
  end
  
  return job_id
end

-- Helper to run a command in a floating terminal
local function run_in_float_term(command)
  -- Simple terminal split approach for now
  vim.cmd('new')
  vim.cmd('resize 20')
  vim.fn.termopen(command)
  vim.cmd('startinsert')
end

-- Initialize a new plan
function M.init()
  vim.ui.input({ prompt = 'New Plan Name: ' }, function(name)
    if not name or name == '' then
      vim.notify('Grove: Plan creation cancelled.', vim.log.levels.WARN)
      return
    end
    vim.notify('Grove: Creating plan in current project plans directory...', vim.log.levels.INFO)
    run_in_float_term('neogrove plan init ' .. vim.fn.shellescape(name))
  end)
end

-- Show plan status in a floating terminal
function M.status(plan_path)
  if not plan_path then
    vim.notify('Grove: No plan path provided.', vim.log.levels.ERROR)
    return
  end
  run_in_float_term('neogrove plan status ' .. vim.fn.shellescape(plan_path))
end

-- Run a plan
function M.run(plan_path)
  if not plan_path then
    vim.notify('Grove: No plan path provided.', vim.log.levels.ERROR)
    return
  end
  vim.notify('Grove: Running plan ' .. plan_path .. '...', vim.log.levels.INFO)
  run_in_float_term('neogrove plan run ' .. vim.fn.shellescape(plan_path))
end

-- Show plan actions menu
function M.show_plan_actions(plan_name, plan_data)
  local has_snacks, snacks = pcall(require, 'snacks')
  if not (has_snacks and snacks.picker) then
    vim.notify('Grove: snacks.nvim is required', vim.log.levels.ERROR)
    return
  end
  
  local actions = {
    { text = "📋 View Status", action = "status", desc = "Show detailed plan status" },
    { text = "▶️  Run Plan", action = "run", desc = "Execute the plan" },
    { text = "➕ Add Job", action = "add", desc = "Add a new job to the plan" },
    { text = "🔄 Refresh", action = "refresh", desc = "Refresh plan list" },
  }
  
  snacks.picker({
    title = "Plan Actions: " .. plan_name,
    items = actions,
    format = "text",
    layout = {
      preset = "dropdown",
      preview = false,
      layout = {
        width = 50,
        height = #actions + 4,
      },
    },
    confirm = function(picker, item)
      picker:close()
      if item.action == "status" then
        M.status(plan_name)
      elseif item.action == "run" then
        M.run(plan_name)
      elseif item.action == "add" then
        M.add_job_wizard(plan_name)
      elseif item.action == "refresh" then
        vim.schedule(function()
          M.picker()
        end)
      end
    end,
  })
end

-- Get available templates
function M.get_templates(callback)
  local neogrove_path = vim.fn.exepath('neogrove')
  if neogrove_path == '' then
    callback({})
    return
  end
  
  run_command({ neogrove_path, 'plan', 'template-list', '--json' }, function(stdout, stderr, exit_code)
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

-- Add job wizard with template selection
function M.add_job_wizard(plan_path)
  local has_snacks, snacks = pcall(require, 'snacks')
  if not (has_snacks and snacks.picker) then
    -- Fallback to simple input
    M.add_job_simple(plan_path)
    return
  end
  
  -- Job configuration
  local job_config = {
    plan = plan_path,
    title = "",
    type = "agent",
    template = "",
    prompt = "",
    source_files = {},
    depends_on = {},
  }
  
  -- Step 1: Get job title
  vim.ui.input({ prompt = 'Job Title: ' }, function(title)
    if not title or title == '' then
      vim.notify('Grove: Job creation cancelled.', vim.log.levels.WARN)
      return
    end
    job_config.title = title
    
    -- Step 2: Select job type
    local job_types = {
      { text = "🤖 Interactive Agent - Agent that can interact with tools", value = "interactive_agent" },
      { text = "🧠 Agent - Standard agent job", value = "agent" },
      { text = "💻 Shell - Execute shell commands", value = "shell" },
      { text = "⚡ One Shot - Single execution job", value = "oneshot" },
    }
    
    snacks.picker({
      title = "Select Job Type",
      items = job_types,
      format = "text",
      layout = {
        preset = "dropdown",
        preview = false,
        layout = {
          width = 60,
          height = #job_types + 4,
        },
      },
      confirm = function(picker, item)
        picker:close()
        if not item then
          vim.notify('Grove: Job creation cancelled.', vim.log.levels.WARN)
          return
        end
        job_config.type = item.value
        
        -- Step 3: Select template (optional)
        M.get_templates(function(templates)
          if #templates > 0 then
            -- Add "No template" option
            local template_items = {{ text = "✨ No template - Start from scratch", value = "" }}
            for _, template in ipairs(templates) do
              -- Handle both lowercase and uppercase field names
              local name = template.name or template.Name or template.id
              local description = template.description or template.Description
              local template_text = string.format("📝 %s", name)
              if description and description ~= "" then
                template_text = template_text .. " - " .. description
              end
              table.insert(template_items, {
                text = template_text,
                value = name,
              })
            end
            
            snacks.picker({
              title = "Select Template (Optional)",
              items = template_items,
              format = "text",
              layout = {
                preset = "dropdown",
                preview = false,
                layout = {
                  width = 60,
                  height = math.min(#template_items + 4, 20),
                },
              },
              confirm = function(picker2, template_item)
                picker2:close()
                if template_item and template_item.value ~= "" then
                  job_config.template = template_item.value
                end
                
                -- Step 4: Get prompt (if no template)
                if job_config.template == "" then
                  vim.ui.input({ prompt = 'Job Prompt: ', completion = "file" }, function(prompt)
                    if prompt then  -- Even if empty string, continue
                      job_config.prompt = prompt
                      -- Step 5: Select dependencies
                      M.select_dependencies(job_config)
                    else
                      -- User cancelled
                      vim.notify('Grove: Job creation cancelled.', vim.log.levels.WARN)
                    end
                  end)
                else
                  -- Step 5: Select dependencies
                  M.select_dependencies(job_config)
                end
              end,
            })
          else
            -- No templates available, get prompt
            vim.ui.input({ prompt = 'Job Prompt: ', completion = "file" }, function(prompt)
              if prompt then  -- Even if empty string, continue
                job_config.prompt = prompt
                -- Step 5: Select dependencies
                M.select_dependencies(job_config)
              else
                -- User cancelled
                vim.notify('Grove: Job creation cancelled.', vim.log.levels.WARN)
              end
            end)
          end
        end)
      end,
    })
  end)
end

-- Select dependencies for the job
function M.select_dependencies(job_config)
  local has_snacks, snacks = pcall(require, 'snacks')
  if not has_snacks then
    -- Skip dependency selection if snacks is not available
    M.create_job(job_config)
    return
  end
  
  -- Get existing jobs in the plan
  local neogrove_path = vim.fn.exepath('neogrove')
  if neogrove_path == '' then
    M.create_job(job_config)
    return
  end
  
  -- Get plan status to extract job list
  local cmd_args = { neogrove_path, 'plan', 'status', job_config.plan, '--json' }
  run_command(cmd_args, function(stdout, stderr, exit_code)
    if exit_code ~= 0 or stdout == "" then
      -- Error getting plan status or no output
      M.create_job(job_config)
      return
    end
    
    
    -- Parse JSON output
    local ok, plan_data = pcall(vim.json.decode, stdout)
    if not ok or not plan_data then
      -- Failed to parse JSON
      M.create_job(job_config)
      return
    end
    
    if not plan_data.jobs or #plan_data.jobs == 0 then
      -- No jobs to depend on
      M.create_job(job_config)
      return
    end
    
    -- Create items for dependency selection
    local job_items = {{ text = "➖ No dependencies - Start independently", value = nil }}
    for _, job in ipairs(plan_data.jobs) do
      local status_icon = "📋"  -- Default job icon
      if job.status == "completed" then
        status_icon = "✅"
      elseif job.status == "failed" then
        status_icon = "❌"
      elseif job.status == "running" then
        status_icon = "🏃"
      elseif job.status == "pending" then
        status_icon = "⏳"
      end
      
      local job_text = string.format("%s %s - %s", status_icon, job.filename or job.id, job.title or "Untitled")
      table.insert(job_items, {
        text = job_text,
        value = job.filename or job.id,
        selectable = true,
      })
    end
    
    vim.schedule(function()
      snacks.picker({
        title = "Select Dependencies (Space to toggle, Enter to confirm)",
        items = job_items,
        format = "text",
        layout = {
          preset = "dropdown",
          preview = false,
          layout = {
            width = 70,
            height = math.min(#job_items + 4, 20),
          },
        },
        confirm = function(picker, item)
          -- Get all selected items for multi-select
          local selected = picker:selected({ fallback = true })
          picker:close()
          
          if selected and #selected > 0 then
            job_config.depends_on = {}
            for _, sel_item in ipairs(selected) do
              if sel_item.value then  -- Skip "No dependencies" option
                table.insert(job_config.depends_on, sel_item.value)
              end
            end
          end
          M.create_job(job_config)
        end,
        win = {
          list = {
            keys = {
              ["<Space>"] = { "select", desc = "Toggle Selection" },
              ["<Tab>"] = { "select_and_next", desc = "Select and Next" },
              ["<S-Tab>"] = { "select_and_prev", desc = "Select and Previous" },
            },
          },
        },
      })
    end)
  end)
end

-- Create the job with the collected configuration
function M.create_job(config)
  local cmd_parts = {
    'neogrove', 'plan', 'add', vim.fn.shellescape(config.plan),
    '--title', vim.fn.shellescape(config.title),
    '--type', config.type
  }
  
  if config.template ~= "" then
    table.insert(cmd_parts, '--template')
    table.insert(cmd_parts, vim.fn.shellescape(config.template))
  end
  
  if config.prompt ~= "" then
    table.insert(cmd_parts, '--prompt')
    table.insert(cmd_parts, vim.fn.shellescape(config.prompt))
  end
  
  if config.depends_on and #config.depends_on > 0 then
    for _, dep in ipairs(config.depends_on) do
      table.insert(cmd_parts, '--depends-on')
      table.insert(cmd_parts, vim.fn.shellescape(dep))
    end
  end
  
  local cmd = table.concat(cmd_parts, ' ')
  vim.notify('Grove: Creating job...', vim.log.levels.INFO)
  run_in_float_term(cmd)
end

-- Simple add job (fallback)
function M.add_job_simple(plan_path)
  vim.ui.input({ prompt = 'Job Title: ' }, function(title)
    if not title or title == '' then
      vim.notify('Grove: Job creation cancelled.', vim.log.levels.WARN)
      return
    end
    
    vim.ui.input({ prompt = 'Job Prompt: ' }, function(prompt)
      if not prompt or prompt == '' then
        vim.notify('Grove: Job creation cancelled.', vim.log.levels.WARN)
        return
      end
      
      local cmd = string.format(
        'neogrove plan add %s --title %s --prompt %s',
        vim.fn.shellescape(plan_path),
        vim.fn.shellescape(title),
        vim.fn.shellescape(prompt)
      )
      
      run_in_float_term(cmd)
    end)
  end)
end

-- Create the plan picker with snacks.nvim
function M.picker()
  local has_snacks, snacks = pcall(require, 'snacks')
  if not (has_snacks and snacks.picker) then
    vim.notify('Grove: snacks.nvim is required for the plan picker', vim.log.levels.ERROR)
    return
  end
  
  -- Check if neogrove is available
  local neogrove_path = vim.fn.exepath('neogrove')
  if neogrove_path == '' then
    vim.notify("Grove: neogrove not found in PATH", vim.log.levels.ERROR)
    return
  end
  
  -- Fetch plan list
  vim.notify("Grove: Fetching plans...", vim.log.levels.INFO)
  
  run_command({ neogrove_path, 'plan', 'list', '--json' }, function(stdout, stderr, exit_code)
    if exit_code ~= 0 then
      vim.notify("Grove: Failed to list plans: " .. stderr, vim.log.levels.ERROR)
      return
    end
    
    if stdout == "" or stdout:match("^%s*$") then
      vim.notify("Grove: No plans found", vim.log.levels.INFO)
      return
    end
    
    -- Parse JSON output
    local ok, plans = pcall(vim.json.decode, stdout)
    if not ok or not plans then
      vim.notify("Grove: Failed to parse plan list", vim.log.levels.ERROR)
      return
    end
    
    -- Convert to picker items
    local items = {}
    for _, plan in ipairs(plans) do
      local display = string.format('%-25s %-15s %3d jobs', 
        plan.id or plan.name or "unknown",
        plan.status or "unknown",
        plan.job_count or 0
      )
      
      -- Extract just the plan name from the full path
      local plan_name = plan.id or plan.name
      if not plan_name and plan.path then
        -- Get the last component of the path
        plan_name = vim.fn.fnamemodify(plan.path, ':t')
      end
      
      table.insert(items, {
        text = display,
        value = plan,
        plan_id = plan_name,
        plan_path = plan_name,  -- Use just the plan name, not full path
      })
    end
    
    -- Sort by plan name
    table.sort(items, function(a, b)
      return (a.plan_id or "") < (b.plan_id or "")
    end)
    
    -- Create picker
    vim.schedule(function()
      snacks.picker({
        title = "Grove Plans",
        items = items,
        format = "text",
        layout = {
          layout = {
            box = "vertical",
            width = 0.8,
            height = 0.8,
            border = "rounded",
            title = "{title} {live} {flags}",
            {
              box = "vertical",
              { win = "input", height = 1, border = "bottom" },
              { win = "list", border = "none" },
            },
            { win = "preview", height = 0.5, border = "top" },
          },
        },
        preview = function(ctx)
          if ctx.item and ctx.item.plan_path then
            -- Run status command for preview
            local preview_cmd = { neogrove_path, 'plan', 'status', ctx.item.plan_path }
            run_command(preview_cmd, function(preview_stdout, preview_stderr, preview_exit)
              if preview_exit == 0 and preview_stdout ~= "" then
                local lines = vim.split(preview_stdout, '\n')
                vim.schedule(function()
                  ctx.preview:set_lines(lines)
                end)
              else
                vim.schedule(function()
                  ctx.preview:set_lines({ "Failed to load plan status", "", preview_stderr })
                end)
              end
            end)
          end
        end,
        confirm = function(picker, item)
          if item and item.plan_path then
            picker:close()
            M.show_plan_actions(item.plan_path, item.value)
          end
        end,
        actions = {
          create_new = function(picker)
            picker:close()
            M.init()
          end,
          refresh = function(picker)
            picker:close()
            vim.schedule(function()
              M.picker()
            end)
          end,
        },
        win = {
          input = {
            keys = {
              ["<C-n>"] = { "create_new", mode = { "n", "i" }, desc = "Create New Plan" },
              ["<C-r>"] = { "refresh", mode = { "n", "i" }, desc = "Refresh Plan List" },
            },
          },
          list = {
            keys = {
              ["<C-n>"] = { "create_new", desc = "Create New Plan" },
              ["<C-r>"] = { "refresh", desc = "Refresh Plan List" },
            },
          },
        },
      })
    end)
  end)
end

return M