-- lua/grove-nvim/virtual_text.lua
-- Manages virtual text for grove-context rules files.

local M = {}

local utils = require('grove-nvim.utils')
local api = vim.api

local ns_id = api.nvim_create_namespace('grove_rules_stats')
local debounced_update = nil

-- Formats a number into a compact string (e.g., 1234 -> 1.2k)
local function format_compact(num)
  if num < 1000 then return tostring(num) end
  if num < 1000000 then return string.format("%.1fk", num / 1000) end
  return string.format("%.1fM", num / 1000000)
end

-- Fetches stats and renders virtual text.
local function update(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  -- Check if buffer is still valid before accessing it
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  local buf_path = api.nvim_buf_get_name(bufnr)
  if buf_path == '' then return end

  local cx_path = vim.fn.exepath('cx')
  if cx_path == '' then return end

  -- Get buffer contents and write to a temporary file
  -- This ensures we analyze the current buffer state, not what's on disk
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local temp_file = vim.fn.tempname()
  local f = io.open(temp_file, 'w')
  if not f then
    vim.notify("Grove: Failed to create temp file", vim.log.levels.ERROR)
    return
  end
  f:write(table.concat(lines, '\n'))
  f:close()

  -- Use shell to redirect stderr since cx logs to stderr
  local cmd = string.format('%s stats --per-line %s 2>/dev/null',
    vim.fn.shellescape(cx_path),
    vim.fn.shellescape(temp_file))

  utils.run_command({ 'sh', '-c', cmd }, function(stdout, stderr, exit_code)
    -- Clean up temp file
    vim.fn.delete(temp_file)

    -- Check if buffer is still valid before processing results
    if not api.nvim_buf_is_valid(bufnr) then
      return
    end

    if exit_code ~= 0 then
      vim.notify("Grove: cx stats failed with exit code " .. exit_code, vim.log.levels.DEBUG)
      if api.nvim_buf_is_valid(bufnr) then
        api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      end
      return
    end

    if stdout == "" then
      vim.notify("Grove: cx stats returned empty output", vim.log.levels.DEBUG)
      if api.nvim_buf_is_valid(bufnr) then
        api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      end
      return
    end

    local ok, stats = pcall(vim.json.decode, stdout)
    if not ok then
      vim.notify("Grove: Failed to parse stats JSON: " .. tostring(stats), vim.log.levels.DEBUG)
      if api.nvim_buf_is_valid(bufnr) then
        api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      end
      return
    end

    -- Handle vim.NIL (JSON null) and empty results
    if not stats or stats == vim.NIL then
      vim.notify("Grove: cx stats returned null (no stats available)", vim.log.levels.DEBUG)
      if api.nvim_buf_is_valid(bufnr) then
        api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      end
      return
    end

    -- Convert userdata (vim.empty_dict) to empty table
    if type(stats) == "userdata" then
      stats = {}
    end

    if type(stats) ~= "table" then
      vim.notify("Grove: stats is not a table (got " .. type(stats) .. ")", vim.log.levels.DEBUG)
      if api.nvim_buf_is_valid(bufnr) then
        api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      end
      return
    end

    vim.notify("Grove: Got " .. #stats .. " line stats", vim.log.levels.DEBUG)

    vim.schedule(function()
      if not api.nvim_buf_is_valid(bufnr) then
        vim.notify("Grove: buffer became invalid", vim.log.levels.DEBUG)
        return
      end

      api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

      -- Build a map of line numbers that have stats
      local stats_by_line = {}
      for _, stat in ipairs(stats) do
        stats_by_line[stat.lineNumber] = stat
      end

      -- Check all lines in the buffer to find rules without stats
      local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local extmark_count = 0

      for line_idx, line_text in ipairs(lines) do
        local line_num = line_idx -- line numbers are 1-indexed in stats
        local line_text_trimmed = vim.trim(line_text)

        -- Check if this is a rule line (not comment, not separator, not config directive, not empty)
        -- @alias: lines are rule lines and should get virtual text
        -- @view: lines are config directives and don't contribute files directly
        local is_rule_line = line_text_trimmed ~= ""
          and not line_text_trimmed:match("^#")
          and not line_text_trimmed:match("^%-%-%-")
          and not line_text_trimmed:match("^@view:")
          and not line_text_trimmed:match("^@v:")
          and not line_text_trimmed:match("^@default")
          and not line_text_trimmed:match("^@freeze%-cache")
          and not line_text_trimmed:match("^@no%-expire")
          and not line_text_trimmed:match("^@disable%-cache")
          and not line_text_trimmed:match("^@expire%-time")

        if is_rule_line then
          local stat = stats_by_line[line_num]
          local virt_text = {}

          if stat then
            -- First check if this has Git info - if so, show it
            if stat.gitInfo then
              -- Display Git repository information
              -- Status indicator with color
              if stat.gitInfo.status then
                local status = stat.gitInfo.status
                local status_hl = 'GroveVirtualTextGitStatus'
                if status == 'audited' or status == 'approved' then
                  status_hl = 'GroveVirtualTextGitApproved'
                elseif status == 'not_audited' then
                  status_hl = 'GroveVirtualTextGitNotAudited'
                end
                table.insert(virt_text, { ' [' .. status, status_hl })
              end

              -- Version
              if stat.gitInfo.version and stat.gitInfo.version ~= '' then
                table.insert(virt_text, { ' | ' .. stat.gitInfo.version, 'GroveVirtualTextGitVersion' })
              end

              -- Commit
              if stat.gitInfo.commit then
                table.insert(virt_text, { ' | ' .. stat.gitInfo.commit, 'GroveVirtualTextGitCommit' })
              end

              -- Close bracket
              table.insert(virt_text, { ']', 'GroveVirtualTextGitStatus' })
            end

            -- Now show file/token counts (works for both git repos and regular patterns)
            -- For ruleset imports (::), skip showing exclusions since they apply to the source project
            local is_ruleset_import = stat.rule and stat.rule:match('::')

            if stat.excludedFileCount and stat.excludedFileCount > 0 and not is_ruleset_import then
              -- Has exclusions (only show for local rules, not imported rulesets)
              local excluded_text = ' -' .. stat.excludedFileCount .. ' file'
              if stat.excludedFileCount ~= 1 then
                excluded_text = excluded_text .. 's'
              end
              table.insert(virt_text, { excluded_text, 'GroveVirtualTextExcluded' })

              if stat.excludedTokens and stat.excludedTokens > 0 then
                table.insert(virt_text, { ', -' .. format_compact(stat.excludedTokens) .. ' tokens', 'GroveVirtualTextExcluded' })
              end
            end

            -- Show inclusion counts
            if stat.fileCount and stat.fileCount > 0 and stat.totalTokens and stat.totalTokens > 0 then
              -- Has matches
              table.insert(virt_text, { ' ~' .. format_compact(stat.totalTokens) .. ' tokens', 'GroveVirtualTextTokens' })

              local path_text
              if stat.fileCount == 1 and stat.resolvedPaths and #stat.resolvedPaths > 0 then
                path_text = ' (' .. vim.fn.fnamemodify(stat.resolvedPaths[1], ':t') .. ')'
              else
                path_text = ' (' .. stat.fileCount .. ' files)'
              end
              table.insert(virt_text, { path_text, 'GroveVirtualTextPath' })

              -- Show filtered files info (files that matched base pattern but were filtered by directive)
              if stat.filteredByLine and #stat.filteredByLine > 0 then
                local total_filtered = 0
                local line_refs = {}
                for _, filtered_group in ipairs(stat.filteredByLine) do
                  total_filtered = total_filtered + filtered_group.count
                  table.insert(line_refs, filtered_group.lineNumber)
                end
                local filtered_text = ' +' .. total_filtered .. ' included by line ' .. table.concat(line_refs, ', ')
                table.insert(virt_text, { filtered_text, 'GroveVirtualTextFiltered' })
              end
            elseif stat.fileCount == 0 and not stat.gitInfo then
              -- Has stats but no matches (for inclusion rules)
              -- Check if there are filtered files that matched another rule
              if stat.filteredByLine and #stat.filteredByLine > 0 then
                -- Show which lines included the files that would have matched
                local total_filtered = 0
                local line_refs = {}
                for _, filtered_group in ipairs(stat.filteredByLine) do
                  total_filtered = total_filtered + filtered_group.count
                  table.insert(line_refs, 'line ' .. filtered_group.lineNumber)
                end
                local filtered_text = ' ' .. total_filtered .. ' included by ' .. table.concat(line_refs, ', ')
                table.insert(virt_text, { filtered_text, 'GroveVirtualTextFiltered' })
              else
                table.insert(virt_text, { ' ⚠ no matches', 'GroveVirtualTextNoMatch' })
              end
            end
          else
            -- No stats for this rule line - invalid or not processed
            table.insert(virt_text, { ' ⚠ no matches', 'GroveVirtualTextNoMatch' })
          end

          if #virt_text > 0 then
            local ok, err = pcall(api.nvim_buf_set_extmark, bufnr, ns_id, line_idx - 1, 0, {
              virt_text = virt_text,
              virt_text_pos = 'eol',
            })

            if ok then
              extmark_count = extmark_count + 1
            else
              vim.notify("Grove: Failed to set extmark on line " .. (line_idx - 1) .. ": " .. tostring(err), vim.log.levels.DEBUG)
            end
          end
        end
      end

      vim.notify("Grove: Set " .. extmark_count .. " extmarks", vim.log.levels.DEBUG)
    end)
  end)
end

-- Sets up autocommands and highlighting for the current buffer.
function M.setup(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  -- Define highlight groups with more visible colors for testing
  vim.cmd('highlight default GroveVirtualTextTokens guifg=#888888 ctermfg=244')
  vim.cmd('highlight default GroveVirtualTextPath guifg=#666666 ctermfg=242')
  vim.cmd('highlight default GroveVirtualTextNoMatch guifg=#e06c75 ctermfg=red')
  vim.cmd('highlight default GroveVirtualTextExcluded guifg=#888888 ctermfg=244')
  vim.cmd('highlight default GroveVirtualTextFiltered guifg=#d19a66 ctermfg=yellow')

  -- Git repository info highlight groups
  vim.cmd('highlight default GroveVirtualTextGitStatus guifg=#888888 ctermfg=244')
  vim.cmd('highlight default GroveVirtualTextGitApproved guifg=#98c379 ctermfg=green')
  vim.cmd('highlight default GroveVirtualTextGitNotAudited guifg=#d19a66 ctermfg=yellow')
  vim.cmd('highlight default GroveVirtualTextGitVersion guifg=#61afef ctermfg=blue')
  vim.cmd('highlight default GroveVirtualTextGitCommit guifg=#888888 ctermfg=244')

  -- Debounce the update function to avoid excessive calls
  if not debounced_update then
    debounced_update = utils.debounce(300, update)
  end

  local group = api.nvim_create_augroup('GroveRulesVirtualText', { clear = true })
  api.nvim_create_autocmd({'BufWritePost', 'BufEnter'}, {
    group = group,
    buffer = bufnr,
    callback = function() update(bufnr) end,
  })
  api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
    group = group,
    buffer = bufnr,
    callback = function() debounced_update(bufnr) end,
  })

  -- Initial update
  update(bufnr)
end

return M
