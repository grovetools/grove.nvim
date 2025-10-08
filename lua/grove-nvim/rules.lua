-- lua/grove-nvim/rules.lua
-- Interactive features for groverules files.

local M = {}
local utils = require('grove-nvim.utils')

-- Parse an alias from a rule line
-- Returns: alias_part (e.g., "@a:grove-nvim"), base_path (the resolved absolute path)
local function parse_alias_from_line(line, cx_path)
  -- Check if line contains an alias directive
  local alias_match = line:match("@a:([^/]+)") or line:match("@alias:([^/]+)")
  if not alias_match then
    return nil, nil
  end

  -- Extract just the alias part (e.g., "@a:grove-nvim")
  local alias_prefix = line:match("(@a:[^/]+)") or line:match("(@alias:[^/]+)")

  -- Get the workspace list to find the resolved path
  local handle = io.popen(cx_path .. ' workspace list --json 2>/dev/null')
  if not handle then
    return alias_prefix, nil
  end

  local result = handle:read("*a")
  handle:close()

  if result == "" then
    return alias_prefix, nil
  end

  -- Parse JSON to find matching workspace
  local ok, workspaces = pcall(vim.json.decode, result)
  if not ok or not workspaces then
    return alias_prefix, nil
  end

  -- Split alias into components (e.g., "grove-nvim" or "grove-ecosystem:grove-nvim")
  local alias_parts = vim.split(alias_match, ":")

  -- Context-aware matching logic (mirrors the Go alias resolver)
  -- Get current working directory to determine context
  local cwd = vim.fn.getcwd()

  if #alias_parts == 1 then
    -- Single component alias (e.g., "grove-nvim")
    local name = alias_parts[1]
    local top_level_match = nil
    local any_match = nil

    for _, ws in ipairs(workspaces) do
      if ws.name == name and not ws.is_worktree then
        -- Check if we're in a worktree context
        local in_worktree = cwd:match("%.grove%-worktrees")

        if in_worktree and ws.worktree_name then
          -- Prefer siblings in same worktree
          if cwd:match(vim.pesc(ws.worktree_name)) then
            return alias_prefix, ws.path
          end
        end

        -- Prefer top-level projects (not in any worktree)
        if not ws.worktree_name then
          top_level_match = ws
        else
          any_match = ws
        end
      end
    end

    if top_level_match then
      return alias_prefix, top_level_match.path
    end
    if any_match then
      return alias_prefix, any_match.path
    end
  elseif #alias_parts == 2 then
    -- Two component alias (ecosystem:repo or repo:worktree)
    local first, second = alias_parts[1], alias_parts[2]

    -- Try ecosystem:repo match
    for _, ws in ipairs(workspaces) do
      if ws.parent_ecosystem_path then
        local eco_name = vim.fn.fnamemodify(ws.parent_ecosystem_path, ":t")
        if eco_name == first and ws.name == second and not ws.is_worktree and not ws.worktree_name then
          return alias_prefix, ws.path
        end
      end
    end

    -- Try repo:worktree match
    for _, ws in ipairs(workspaces) do
      if ws.is_worktree and ws.parent_path then
        local parent_name = vim.fn.fnamemodify(ws.parent_path, ":t")
        if parent_name == first and ws.name == second then
          return alias_prefix, ws.path
        end
      end
    end
  elseif #alias_parts == 3 then
    -- Three component alias (ecosystem:repo:worktree)
    local eco, repo, worktree = alias_parts[1], alias_parts[2], alias_parts[3]

    for _, ws in ipairs(workspaces) do
      if ws.is_worktree and ws.parent_ecosystem_path and ws.parent_path then
        local eco_name = vim.fn.fnamemodify(ws.parent_ecosystem_path, ":t")
        local parent_name = vim.fn.fnamemodify(ws.parent_path, ":t")
        if eco_name == eco and parent_name == repo and ws.name == worktree then
          return alias_prefix, ws.path
        end
      end
    end
  end

  return alias_prefix, nil
end

-- Make a path relative to a base path
local function make_relative(file_path, base_path)
  if not base_path then
    return file_path
  end

  -- Normalize paths
  local norm_file = vim.fn.fnamemodify(file_path, ':p')
  local norm_base = vim.fn.fnamemodify(base_path, ':p')

  -- Ensure base path ends with separator
  if not norm_base:match('/$') then
    norm_base = norm_base .. '/'
  end

  -- Check if file is under base path
  if norm_file:sub(1, #norm_base) == norm_base then
    return norm_file:sub(#norm_base + 1)
  end

  return file_path
end

---@async
function M.preview_rule_files()
  local line = vim.api.nvim_get_current_line()
  local trimmed_line = vim.trim(line)
  local original_buf = vim.api.nvim_get_current_buf()
  local original_line_nr = vim.api.nvim_win_get_cursor(0)[1]

  -- Ignore comments, separators, and empty lines.
  if trimmed_line == "" or trimmed_line:match("^#") or trimmed_line == "---" then
    vim.notify("Grove: No preview for comments, separators, or empty lines.", vim.log.levels.INFO)
    return
  end

  -- Check if this is an exclusion rule
  local is_exclusion = trimmed_line:match("^!")
  local rule_to_resolve = trimmed_line

  -- For exclusion rules, remove the ! prefix to resolve what would be excluded
  if is_exclusion then
    rule_to_resolve = trimmed_line:sub(2)
  end

  local cx_path = vim.fn.exepath('cx')
  if cx_path == '' then
    vim.notify("Grove: cx executable not found in PATH.", vim.log.levels.ERROR)
    return
  end

  -- Try to parse alias information from the line (use the rule without ! for parsing)
  local alias_prefix, alias_base_path = parse_alias_from_line(rule_to_resolve, cx_path)

  local msg = is_exclusion and "Grove: Resolving files that would be excluded..." or "Grove: Resolving files for rule..."
  vim.notify(msg, vim.log.levels.INFO)

  utils.run_command({ cx_path, 'resolve', rule_to_resolve }, function(stdout, stderr, exit_code)
    if exit_code ~= 0 then
      vim.notify("Grove: Failed to resolve files: " .. stderr, vim.log.levels.ERROR)
      return
    end

    if stdout == "" then
      vim.notify("Grove: No files found for this rule.", vim.log.levels.INFO)
      return
    end

    local files = vim.split(stdout, '\n', { trimempty = true })
    local items = {}
    for _, file in ipairs(files) do
      table.insert(items, { text = file })
    end

    local has_snacks, snacks = pcall(require, 'snacks')
    if not has_snacks then
      vim.notify("Grove: snacks.nvim is required for file preview.", vim.log.levels.ERROR)
      return
    end

    vim.schedule(function()
      local title = is_exclusion
        and "Files to exclude (Press <Tab> to select, <CR> to add as exclusions)"
        or "Files resolved by rule (Press <Tab> to select, <CR> to add selected to rules)"

      snacks.picker({
        title = title,
        items = items,
        format = "text",
        layout = utils.centered_dropdown(80, math.min(#items + 4, 30)),
        confirm = function(picker, item)
          -- Get all selected items (or just the current item if none selected)
          local selected = picker:selected()
          if #selected == 0 and item then
            selected = { item }
          end

          if #selected == 0 then
            vim.notify("Grove: No files selected.", vim.log.levels.INFO)
            return
          end

          -- Extract file paths from selected items
          local files_to_add = {}
          for _, sel_item in ipairs(selected) do
            local file_path = sel_item.text

            -- If we have an alias, make path relative and prepend alias
            if alias_prefix and alias_base_path then
              local rel_path = make_relative(file_path, alias_base_path)
              if rel_path ~= file_path then
                -- Successfully made relative, prepend alias
                file_path = alias_prefix .. "/" .. rel_path
              end
            end

            -- If this was an exclusion rule, prepend ! to the file path
            if is_exclusion then
              file_path = "!" .. file_path
            end

            table.insert(files_to_add, file_path)
          end

          -- Switch back to the original buffer
          vim.api.nvim_set_current_buf(original_buf)

          -- Add selected files as new rules after the current line
          local lines_to_insert = {}
          for _, file_path in ipairs(files_to_add) do
            table.insert(lines_to_insert, file_path)
          end

          -- Insert the new lines
          vim.api.nvim_buf_set_lines(original_buf, original_line_nr, original_line_nr, false, lines_to_insert)

          vim.notify(string.format("Grove: Added %d file(s) to rules", #files_to_add), vim.log.levels.INFO)
        end,
      })
    end)
  end)
end

return M
