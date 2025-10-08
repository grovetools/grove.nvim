-- lua/grove-nvim/sources/alias.lua
-- Blink.cmp source for Grove context aliases.

--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

local utils = require('grove-nvim.utils')

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}
  return self
end

-- Only enable in groverules files
function source:enabled()
  return vim.bo.filetype == 'groverules'
end

-- Trigger on colon after @alias or @a
function source:get_trigger_characters()
  return { ':' }
end

function source:get_completions(ctx, callback)
  -- Get the current line from the buffer
  local bufnr = ctx.bufnr or vim.api.nvim_get_current_buf()
  local cursor = ctx.cursor or vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]

  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  local line_to_cursor = line:sub(1, col)

  -- Check if we're in an @alias: or @a: context
  local alias_start = line_to_cursor:match(".*(@a:)") or line_to_cursor:match(".*(@alias:)")
  if not alias_start then
    return callback({ items = {} })
  end

  -- Extract what's been typed after @a: or @alias:
  local after_directive = line_to_cursor:match("@a:([^%s]*)$") or line_to_cursor:match("@alias:([^%s]*)$") or ""

  -- Check if this is a ruleset import (contains ::)
  local is_ruleset_import = after_directive:find("::", 1, true) ~= nil

  if is_ruleset_import then
    -- Handle ruleset completion
    local before_double_colon = after_directive:match("^(.*)::") or ""
    local after_double_colon = after_directive:match("::(.*)$") or ""

    -- Use cx to resolve the project alias
    local resolve_cmd = string.format('%s resolve %s --json 2>/dev/null',
      vim.fn.shellescape(cx_path),
      vim.fn.shellescape(before_double_colon))

    utils.run_command({ 'sh', '-c', resolve_cmd }, function(stdout, stderr, exit_code)
      if exit_code ~= 0 or stdout == "" then
        return callback({ items = {} })
      end

      local ok, project = pcall(vim.json.decode, stdout)
      if not ok or not project or not project.path then
        return callback({ items = {} })
      end

      -- List .cx/*.rules files in the resolved project
      local cx_dir = project.path .. '/.cx'
      local rules_pattern = cx_dir .. '/*.rules'
      local glob_results = vim.fn.glob(rules_pattern, false, true)

      local items = {}
      for _, file_path in ipairs(glob_results) do
        local filename = vim.fn.fnamemodify(file_path, ':t')
        local ruleset_name = filename:match("^(.*)%.rules$")
        if ruleset_name then
          table.insert(items, {
            label = ruleset_name,
            insertText = ruleset_name,
            detail = file_path,
            kind = vim.lsp.protocol.CompletionItemKind.File,
          })
        end
      end

      callback({
        items = items,
        is_incomplete_backward = false,
        is_incomplete_forward = false,
      })
    end)

    return
  end

  -- Regular alias completion (not ruleset import)
  local parts = vim.split(after_directive, ":", { plain = true })
  local num_parts = #parts

  local cx_path = vim.fn.exepath('cx')
  if cx_path == '' then
    return callback({ items = {} })
  end

  -- Use shell to redirect stderr since cx logs to stderr
  local cmd = string.format('%s workspace list --json 2>/dev/null', vim.fn.shellescape(cx_path))

  utils.run_command({ 'sh', '-c', cmd }, function(stdout, stderr, exit_code)
    if exit_code ~= 0 then
      vim.notify("Grove: cx workspace list failed with exit code " .. exit_code, vim.log.levels.DEBUG)
      return callback({ items = {} })
    end

    if stdout == "" then
      vim.notify("Grove: cx workspace list returned empty stdout", vim.log.levels.DEBUG)
      return callback({ items = {} })
    end

    local ok, projects = pcall(vim.json.decode, stdout)
    if not ok then
      vim.notify("Grove: Failed to parse JSON: " .. tostring(projects), vim.log.levels.DEBUG)
      return callback({ items = {} })
    end

    if not projects then
      vim.notify("Grove: projects is nil after JSON decode", vim.log.levels.DEBUG)
      return callback({ items = {} })
    end

    local items = {}
    local seen_suggestions = {}

    for _, project in ipairs(projects) do
      if project.identifier then
        local suggestion, insert_text, label, detail

        if num_parts == 1 then
          -- User typed: @a:g or @a:grove
          -- Suggest single-component aliases (just the name)
          -- Allow ecosystem worktrees (is_worktree AND is_ecosystem) but not regular repo worktrees
          local should_include = not project.is_worktree or project.is_ecosystem

          if should_include then
            suggestion = project.name
            insert_text = project.name
            label = project.name

            -- Add context indicator
            if project.is_worktree and project.is_ecosystem then
              label = label .. ' (ecosystem worktree)'
            elseif project.parent_ecosystem_path then
              local eco_name = vim.fn.fnamemodify(project.parent_ecosystem_path, ':t')
              label = label .. ' (in ' .. eco_name .. ')'
            end

            detail = project.path
          end

        elseif num_parts == 2 then
          -- User typed: @a:grove-ecosystem: or @a:grove-ecosystem:c
          local first_part = parts[1]

          -- Option 1: ecosystem:repo completion (top-level repos in ecosystem)
          -- MUST have parent_ecosystem_path and NO worktree_name
          if project.parent_ecosystem_path and project.parent_ecosystem_path ~= ""
             and not project.is_worktree and not project.worktree_name then
            local eco_name = vim.fn.fnamemodify(project.parent_ecosystem_path, ':t')
            if eco_name and eco_name ~= "" and eco_name == first_part then
              suggestion = first_part .. ':' .. project.name
              insert_text = first_part .. ':' .. project.name
              label = eco_name .. ' > ' .. project.name
              detail = project.path
            end
          end

          -- Option 2: ecosystem-worktree:repo completion (repos in ecosystem worktree)
          -- MUST have worktree_name that matches first_part and NOT be a worktree itself
          if project.worktree_name and project.worktree_name ~= ""
             and not project.is_worktree and not project.is_ecosystem then
            if project.worktree_name == first_part then
              suggestion = first_part .. ':' .. project.name
              insert_text = first_part .. ':' .. project.name
              label = first_part .. ' > ' .. project.name .. ' (in ecosystem worktree)'
              detail = project.path
            end
          end

          -- Option 3: repo:worktree completion (worktrees of a repo)
          -- MUST have parent_path and it must match first_part
          if project.is_worktree and project.parent_path and project.parent_path ~= "" then
            local parent_name = vim.fn.fnamemodify(project.parent_path, ':t')
            if parent_name and parent_name ~= "" and parent_name == first_part then
              suggestion = first_part .. ':' .. project.name
              insert_text = first_part .. ':' .. project.name
              label = parent_name .. ' > ' .. project.name .. ' (worktree)'
              detail = project.path
            end
          end

        elseif num_parts == 3 then
          -- User typed: @a:grove-ecosystem:grove-core: or @a:grove-ecosystem:grove-core:f
          local first_part = parts[1]
          local second_part = parts[2]

          -- ecosystem:repo:worktree completion
          -- MUST have both parent_ecosystem_path AND parent_path, and both must match
          if project.is_worktree
             and project.parent_ecosystem_path and project.parent_ecosystem_path ~= ""
             and project.parent_path and project.parent_path ~= "" then
            local eco_name = vim.fn.fnamemodify(project.parent_ecosystem_path, ':t')
            local parent_name = vim.fn.fnamemodify(project.parent_path, ':t')
            if eco_name and eco_name ~= "" and eco_name == first_part
               and parent_name and parent_name ~= "" and parent_name == second_part then
              suggestion = first_part .. ':' .. second_part .. ':' .. project.name
              insert_text = first_part .. ':' .. second_part .. ':' .. project.name
              label = eco_name .. ' > ' .. parent_name .. ' > ' .. project.name .. ' (worktree)'
              detail = project.path
            end
          end
        end

        -- Add unique suggestions
        if suggestion and not seen_suggestions[suggestion] then
          seen_suggestions[suggestion] = true
          table.insert(items, {
            label = label,
            insertText = insert_text,
            detail = detail,
            kind = vim.lsp.protocol.CompletionItemKind.Folder,
          })
        end
      end
    end

    vim.notify("Grove: Returning " .. #items .. " completion items", vim.log.levels.DEBUG)

    callback({
      items = items,
      is_incomplete_backward = false,
      is_incomplete_forward = false,
    })
  end)
end

return source
