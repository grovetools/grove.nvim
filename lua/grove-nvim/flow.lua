-- lua/grove-nvim/flow.lua
-- Grove Flow (plan management) integration

local M = {}
local ui = require('grove-nvim.ui')
local utils = require('grove-nvim.utils')
local data = require('grove-nvim.data')

-- Initialize a new plan
function M.init()
  ui.input({ prompt = 'New Plan Name: ', title = 'Create New Plan' }, function(name)
    if not name or name == '' then
      vim.notify('Grove: Plan creation cancelled.', vim.log.levels.WARN)
      return
    end

    local plan_config = { name = name }

    -- This function will be called after all config has been gathered
    local function create_plan()
      vim.notify('Grove: Creating plan: ' .. plan_config.name, vim.log.levels.INFO)
      local neogrove_path = vim.fn.exepath('neogrove')
      if neogrove_path == '' then
        vim.notify("Grove: neogrove not found in PATH", vim.log.levels.ERROR)
        return
      end

      local init_args = { neogrove_path, 'plan', 'init', plan_config.name }
      if plan_config.model and plan_config.model ~= "" then
        table.insert(init_args, '--model')
        table.insert(init_args, plan_config.model)
      end
      if plan_config.worktree and plan_config.worktree ~= "" then
        table.insert(init_args, '--worktree')
        table.insert(init_args, plan_config.worktree)
      end
      if plan_config.container and plan_config.container ~= "" then
        table.insert(init_args, '--target-agent-container')
        table.insert(init_args, plan_config.container)
      end

      utils.run_command(init_args, function(stdout, stderr, exit_code)
        if exit_code == 0 then
          vim.notify('Grove: Plan "' .. plan_config.name .. '" created. Now add the first job.', vim.log.levels.INFO)
          vim.schedule(function()
            M.add_job_wizard(plan_config.name)
          end)
        else
          if stderr:match("already exists") or stderr:match("directory exists") then
            local has_snacks, snacks = pcall(require, 'snacks')
            if has_snacks and snacks.picker then
              local options = {
                { text = "➕ Add a job to existing plan", value = "add_job" },
                { text = "📋 View plan status", value = "view_status" },
                { text = "🔄 Overwrite plan (use --force)", value = "overwrite" },
                { text = "❌ Cancel", value = "cancel" },
              }
              snacks.picker({
                title = "Plan '" .. plan_config.name .. "' already exists",
                items = options,
                format = "text",
                layout = utils.centered_dropdown(50, #options + 4),
                confirm = function(picker, item)
                  picker:close()
                  if item then
                    if item.value == "add_job" then
                      vim.schedule(function() M.add_job_wizard(plan_config.name) end)
                    elseif item.value == "view_status" then
                      vim.schedule(function() M.status(plan_config.name) end)
                    elseif item.value == "overwrite" then
                      table.insert(init_args, '--force')
                      utils.run_command(init_args, function(stdout2, stderr2, exit_code2)
                        if exit_code2 == 0 then
                          vim.notify('Grove: Plan "' .. plan_config.name .. '" created (overwritten). Now add first job.', vim.log.levels.INFO)
                          vim.schedule(function() M.add_job_wizard(plan_config.name) end)
                        else
                          vim.notify('Grove: Failed to overwrite plan: ' .. stderr2, vim.log.levels.ERROR)
                        end
                      end)
                    else
                      vim.notify('Grove: Cancelled plan creation', vim.log.levels.INFO)
                    end
                  end
                end,
              })
            else
              ui.input({ prompt = 'Plan already exists. Add job? (y/N): ', title = 'Plan Exists', default = 'n' }, function(res)
                if res and (res:lower() == 'y' or res:lower() == 'yes') then
                  vim.schedule(function() M.add_job_wizard(plan_config.name) end)
                else
                  vim.notify('Grove: Using existing plan "' .. plan_config.name .. '"', vim.log.levels.INFO)
                end
              end)
            end
          else
            vim.notify('Grove: Failed to create plan: ' .. stderr, vim.log.levels.ERROR)
          end
        end
      end)
    end

    local function get_container_and_create()
      ui.input({ prompt = 'Default Agent Container (optional): ', title = 'Plan Config' }, function(container)
        if container == nil then
          return vim.notify('Grove: Plan creation cancelled.', vim.log.levels.WARN)
        end
        plan_config.container = container
        create_plan()
      end)
    end

    local function get_worktree_and_continue()
      ui.input({ prompt = 'Default Worktree (optional): ', title = 'Plan Config' }, function(worktree)
        if worktree == nil then
          return vim.notify('Grove: Plan creation cancelled.', vim.log.levels.WARN)
        end
        plan_config.worktree = worktree
        get_container_and_create()
      end)
    end

    -- Ask for default model
    data.get_models(function(models)
      local model_items = { { text = "🤖 Use system default model", value = "" } }
      for _, model in ipairs(models) do
        table.insert(model_items, { text = "└─ " .. model.id, value = model.id })
      end

      local has_snacks, snacks = pcall(require, 'snacks')
      if has_snacks and snacks.picker then
        snacks.picker({
          title = "Select Default Model for Plan",
          items = model_items,
          format = "text",
          layout = utils.centered_dropdown(60, math.min(#model_items + 4, 20)),
          confirm = function(picker_model, model_item)
            picker_model:close()
            plan_config.model = model_item and model_item.value or ""
            get_worktree_and_continue()
          end,
        })
      else
        ui.input({ prompt = 'Default Model (optional): ', title = 'Plan Config' }, function(model)
          if model == nil then
            return vim.notify('Grove: Plan creation cancelled.', vim.log.levels.WARN)
          end
          plan_config.model = model
          get_worktree_and_continue()
        end)
      end
    end)
  end)
end

-- Show plan status in a floating terminal
function M.status(plan_path)
  if not plan_path then
    vim.notify('Grove: No plan path provided.', vim.log.levels.ERROR)
    return
  end
  utils.run_in_float_term('neogrove plan status ' .. vim.fn.shellescape(plan_path))
end

-- Run a plan
function M.run(plan_path)
  if not plan_path then
    vim.notify('Grove: No plan path provided.', vim.log.levels.ERROR)
    return
  end
  vim.notify('Grove: Running plan ' .. plan_path .. '...', vim.log.levels.INFO)
  utils.run_in_float_term('neogrove plan run ' .. vim.fn.shellescape(plan_path))
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
    { text = "⚙️  Configure Plan", action = "config", desc = "View or edit plan configuration" },
    { text = "🔄 Refresh", action = "refresh", desc = "Refresh plan list" },
  }

  snacks.picker({
    title = "Plan Actions: " .. plan_name,
    items = actions,
    format = "text",
    layout = utils.centered_dropdown(50, #actions + 4),
    confirm = function(picker, item)
      picker:close()
      if item.action == "status" then
        M.status(plan_name)
      elseif item.action == "run" then
        M.run(plan_name)
      elseif item.action == "add" then
        M.add_job_form(plan_name)
      elseif item.action == "config" then
        M.show_config_actions(plan_name)
      elseif item.action == "refresh" then
        vim.schedule(function()
          M.picker()
        end)
      end
    end,
  })
end

-- Show plan configuration actions menu
function M.show_config_actions(plan_name)
  local has_snacks, snacks = pcall(require, 'snacks')
  if not (has_snacks and snacks.picker) then
    return vim.notify('Grove: snacks.nvim is required', vim.log.levels.ERROR)
  end

  local config_actions = {
    { text = "📄 View Configuration", action = "view" },
    { text = "🤖 Set Default Model", action = "set_model" },
    { text = "🌳 Set Default Worktree", action = "set_worktree" },
    { text = "📦 Set Default Agent Container", action = "set_container" },
    { text = "↩️  Back to Plan Actions", action = "back" },
  }

  local function handle_set(key)
    return function(value)
      if value == nil then
        return vim.notify("Grove: Action cancelled.", vim.log.levels.WARN)
      end
      local neogrove_path = vim.fn.exepath('neogrove')
      utils.run_command({ neogrove_path, 'plan', 'config', plan_name, '--set', key .. '=' .. value }, function(_, stderr, exit_code)
        if exit_code == 0 then
          vim.notify("Grove: Plan configuration updated.", vim.log.levels.INFO)
        else
          vim.notify("Grove: Failed to update config: " .. stderr, vim.log.levels.ERROR)
        end
      end)
    end
  end

  snacks.picker({
    title = "Configure Plan: " .. plan_name,
    items = config_actions,
    format = "text",
    layout = utils.centered_dropdown(50, #config_actions + 4),
    confirm = function(picker, item)
      picker:close()
      if not item then return end

      if item.action == "view" then
        utils.run_in_float_term('neogrove plan config ' .. vim.fn.shellescape(plan_name))
      elseif item.action == "set_model" then
        data.get_models(function(models)
          local model_items = {}
          for _, model in ipairs(models) do table.insert(model_items, { text = model.id, value = model.id }) end
          snacks.picker({
            title = "Select New Default Model",
            items = model_items,
            format = "text",
            layout = utils.centered_dropdown(60, math.min(#model_items + 4, 20)),
            confirm = function(p, i) p:close(); if i then handle_set('model')(i.value) end end,
          })
        end)
      elseif item.action == "set_worktree" then
        ui.input({ prompt = "New Worktree (leave empty to clear): " }, handle_set('worktree'))
      elseif item.action == "set_container" then
        ui.input({ prompt = "New Agent Container (leave empty to clear): " }, handle_set('target_agent_container'))
      elseif item.action == "back" then
        vim.schedule(function() M.show_plan_actions(plan_name) end)
      end
    end,
  })
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

  utils.run_command({ neogrove_path, 'plan', 'list', '--json' }, function(stdout, stderr, exit_code)
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
            utils.run_command(preview_cmd, function(preview_stdout, preview_stderr, preview_exit)
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

-- Extract content from current buffer and create a new plan
function M.extract_from_buffer()
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path == '' or buf_path == nil then
    vim.notify("Grove: No file name for the current buffer.", vim.log.levels.ERROR)
    return
  end

  -- Try to extract title from frontmatter
  local default_name = ""
  local lines = vim.api.nvim_buf_get_lines(0, 0, 20, false) -- Check first 20 lines for frontmatter
  local in_frontmatter = false
  local frontmatter_start = false

  for i, line in ipairs(lines) do
    if i == 1 and line:match("^---") then
      in_frontmatter = true
      frontmatter_start = true
    elseif in_frontmatter and line:match("^---") and frontmatter_start then
      break -- End of frontmatter
    elseif in_frontmatter then
      local title = line:match("^title:%s*(.+)$")
      if title then
        -- Clean up the title: remove quotes, convert spaces to hyphens, lowercase
        default_name = title:gsub('^"', ''):gsub('"$', ''):gsub("^'", ""):gsub("'$", "")
        default_name = default_name:gsub('%s+', '-'):gsub('_', '-'):lower()
        -- Remove any non-alphanumeric characters except hyphens
        default_name = default_name:gsub('[^%w%-]', '')
        break
      end
    end
  end

  -- Fallback to filename if no title found
  if default_name == "" then
    default_name = vim.fn.fnamemodify(buf_path, ':t:r')
    default_name = default_name:gsub('_', '-'):lower()
  end

  ui.input({ prompt = 'New Plan Name (from buffer): ', default = default_name }, function(name)
    if not name or name == '' then
      vim.notify('Grove: Plan creation cancelled.', vim.log.levels.WARN)
      return
    end

    -- Store the plan name and buffer path for use in nested callback
    local plan_name = name
    local extract_from = buf_path

    -- Schedule the worktree prompt to avoid callback issues
    vim.schedule(function()
      ui.input({ prompt = 'Create with worktree? (y/N): ' }, function(use_worktree)
        if use_worktree == nil then
          vim.notify('Grove: Plan creation cancelled.', vim.log.levels.WARN)
          return
        end

        local neogrove_path = vim.fn.exepath('neogrove')
        if neogrove_path == '' then
          vim.notify("Grove: neogrove not found in PATH", vim.log.levels.ERROR)
          return
        end

        local cmd_args = {
          neogrove_path, 'plan', 'init', plan_name,
          '--extract-all-from', extract_from,
        }

        -- Track if worktree is being created
        -- Handle the response more carefully
        local has_worktree = false
        if use_worktree and use_worktree ~= '' then
          local response = use_worktree:lower():match("^%s*(.-)%s*$") or use_worktree:lower()
          if response == 'y' or response == 'yes' then
            -- Use --with-worktree flag (boolean) to auto-create with plan name
            table.insert(cmd_args, '--with-worktree')
            has_worktree = true
            vim.notify('Grove: Creating plan with worktree (auto-named)...', vim.log.levels.INFO)
          else
            vim.notify('Grove: Creating plan without worktree...', vim.log.levels.INFO)
          end
        else
          -- Empty response means no worktree
          vim.notify('Grove: Creating plan without worktree...', vim.log.levels.INFO)
        end

        utils.run_command(cmd_args, function(stdout, stderr, exit_code)
          if exit_code == 0 then
            vim.notify('Grove: Plan "' .. plan_name .. '" created successfully.', vim.log.levels.INFO)
            -- Only ask about opening if worktree was created
            if has_worktree then
              vim.schedule(function()
                ui.input({ prompt = 'Open plan in tmux session? (y/N): ' }, function(open_plan)
                  if open_plan and open_plan ~= '' and (open_plan:lower() == 'y' or open_plan:lower() == 'yes') then
                    -- Run flow plan open command
                    local open_cmd = { 'flow', 'plan', 'open', plan_name }
                    utils.run_command(open_cmd, function(open_stdout, open_stderr, open_exit_code)
                      if open_exit_code == 0 then
                        vim.notify('Grove: Opened plan "' .. plan_name .. '" in tmux session.', vim.log.levels.INFO)
                      else
                        -- If opening fails, show status instead
                        vim.notify('Grove: Could not open tmux session. Showing status instead.', vim.log.levels.WARN)
                        M.status(plan_name)
                      end
                    end)
                  else
                    -- Show status if not opening
                    M.status(plan_name)
                  end
                end)
              end)
            else
              -- No worktree, just show status
              vim.schedule(function() M.status(plan_name) end)
            end
          else
            vim.notify('Grove: Failed to create plan: ' .. stderr, vim.log.levels.ERROR)
          end
        end)
      end)
    end)
  end)
end

-- Add job form - unified form interface
function M.add_job_form(plan_path)
  vim.notify("Grove: Loading job data...", vim.log.levels.INFO)

  -- Fetch all required data asynchronously before showing the form
  data.get_plan_defaults(plan_path, function(plan_defaults)
    data.get_templates(function(templates)
      data.get_dependencies(plan_path, function(dependencies)
        data.get_models(function(models)
        -- Prepare data for the form
        local job_types = {
          { text = "💬 Chat - Conversational interaction", value = "chat" },
          { text = "🤖 Interactive Agent - Agent that can interact with tools", value = "interactive_agent" },
          { text = "🧠 Agent - Standard agent job", value = "agent" },
          { text = "💻 Shell - Execute shell commands", value = "shell" },
          { text = "⚡ One Shot - Single execution job", value = "oneshot" },
        }

        local template_items = { { text = "✨ No template - Start from scratch", value = "" } }
        for _, t in ipairs(templates) do
          local name = t.name or t.Name or t.id
          local desc = t.description or t.Description
          table.insert(template_items, { text = ("📝 %s%s"):format(name, desc and " - " .. desc or ""), value = name })
        end

        -- Prepare model options
        local model_items = {}
        if plan_defaults.model ~= "" then
          table.insert(model_items, { text = "📋 Use plan default: " .. plan_defaults.model, value = "" })
        end
        for _, m in ipairs(models) do
          table.insert(model_items, { text = "🤖 " .. m.id, value = m.id })
        end

        -- Define the form structure
        local form_fields = {
          { name = 'title',      label = 'Title',         type = 'text',           value = "" },
          { name = 'type',       label = 'Job Type',      type = 'select',         value = "agent", options = job_types },
          { name = 'template',   label = 'Template',      type = 'select',         value = "",      options = template_items },
          { name = 'prompt',     label = 'Prompt',        type = 'text',           value = "",      help = "Additional prompt (optional with template)" },
          { name = 'depends_on', label = 'Dependencies',  type = 'multiselect',    value = {},      options = dependencies },
          { name = 'model',      label = 'Model',         type = 'select',         value = "",      options = model_items,
            condition = function(data) return data.type == "oneshot" end,
            help = "Model override for oneshot jobs" },
          { name = 'worktree',   label = 'Worktree',      type = 'text',           value = plan_defaults.worktree,
            help = "Git worktree (default: " .. (plan_defaults.worktree ~= "" and plan_defaults.worktree or "none") .. ")" },
        }

        ui.form({ title = "Create New Job in '" .. plan_path .. "'", fields = form_fields }, function(result)
          if not result then return vim.notify("Grove: Job creation cancelled.", vim.log.levels.WARN) end
          result.plan = plan_path
          M.create_job(result)
        end)
        end)
      end)
    end)
  end)
end

-- Create the job with the collected configuration
function M.create_job(config)
  local neogrove_path = vim.fn.exepath('neogrove')
  if neogrove_path == '' then
    vim.notify("Grove: neogrove not found in PATH", vim.log.levels.ERROR)
    return
  end

  local cmd_parts = {
    neogrove_path, 'plan', 'add', config.plan,
    '--title', config.title,
    '--type', config.type
  }

  if config.template and config.template ~= "" then
    table.insert(cmd_parts, '--template')
    table.insert(cmd_parts, config.template)
  end

  if config.prompt and config.prompt ~= "" then
    table.insert(cmd_parts, '--prompt')
    table.insert(cmd_parts, config.prompt)
  end

  if config.depends_on and #config.depends_on > 0 then
    for _, dep in ipairs(config.depends_on) do
      table.insert(cmd_parts, '--depends-on')
      table.insert(cmd_parts, dep)
    end
  end

  if config.model and config.model ~= "" then
    table.insert(cmd_parts, '--model')
    table.insert(cmd_parts, config.model)
  end

  if config.worktree and config.worktree ~= "" then
    table.insert(cmd_parts, '--worktree')
    table.insert(cmd_parts, config.worktree)
  end

  vim.notify('Grove: Creating job...', vim.log.levels.INFO)

  utils.run_command(cmd_parts, function(stdout, stderr, exit_code)
    if exit_code == 0 then
      vim.notify('Grove: Job "' .. config.title .. '" created successfully.', vim.log.levels.INFO)
    else
      vim.notify('Grove: Failed to create job: ' .. stderr, vim.log.levels.ERROR)
    end
  end)
end

-- Add job wizard - interactive job creation with form
function M.add_job_wizard(plan_path)
  M.add_job_form(plan_path)
end

-- Add job to active plan using form
function M.add_job_to_active_plan()
  local active_plan = data.get_active_plan()
  if not active_plan then
    vim.notify("Grove: No active plan found. Use 'flow plan set <plan>' to set one.", vim.log.levels.ERROR)
    return
  end

  M.add_job_form(active_plan)
end

-- Add job to plan using TUI
function M.add_job_tui(plan_path)
  if not plan_path then
    plan_path = data.get_active_plan()
    if not plan_path then
      vim.notify("Grove: No active plan found. Use 'flow plan set <plan>' to set one.", vim.log.levels.ERROR)
      return
    end
  end

  utils.run_in_float_term_tui('flow plan add -i ' .. vim.fn.shellescape(plan_path), 'Grove Add Job')
end

-- Open plan TUI (shows all plans)
function M.open_plan_tui()
  utils.run_in_float_term_tui('flow plan tui', 'Grove Plans')
end

-- Open plan status TUI for active plan
function M.open_status_tui(plan_path)
  if not plan_path then
    plan_path = data.get_active_plan()
    if not plan_path then
      vim.notify("Grove: No active plan found. Use 'flow plan set <plan>' to set one.", vim.log.levels.ERROR)
      return
    end
  end

  utils.run_in_float_term_tui('flow plan status -t ' .. vim.fn.shellescape(plan_path), 'Grove Plan Status')
end

return M
