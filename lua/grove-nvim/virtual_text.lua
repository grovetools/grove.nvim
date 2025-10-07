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
  local buf_path = api.nvim_buf_get_name(bufnr)
  if buf_path == '' then return end

  local cx_path = vim.fn.exepath('cx')
  if cx_path == '' then return end

  -- Use shell to redirect stderr since cx logs to stderr
  local cmd = string.format('%s stats --per-line %s 2>/dev/null',
    vim.fn.shellescape(cx_path),
    vim.fn.shellescape(buf_path))

  utils.run_command({ 'sh', '-c', cmd }, function(stdout, stderr, exit_code)
    if exit_code ~= 0 then
      vim.notify("Grove: cx stats failed with exit code " .. exit_code, vim.log.levels.DEBUG)
      api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      return
    end

    if stdout == "" then
      vim.notify("Grove: cx stats returned empty output", vim.log.levels.DEBUG)
      api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      return
    end

    local ok, stats = pcall(vim.json.decode, stdout)
    if not ok then
      vim.notify("Grove: Failed to parse stats JSON: " .. tostring(stats), vim.log.levels.DEBUG)
      return
    end

    if not stats then
      vim.notify("Grove: stats is nil", vim.log.levels.DEBUG)
      return
    end

    vim.notify("Grove: Got " .. #stats .. " line stats", vim.log.levels.DEBUG)

    vim.schedule(function()
      if not api.nvim_buf_is_valid(bufnr) then
        vim.notify("Grove: buffer became invalid", vim.log.levels.DEBUG)
        return
      end

      api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

      local extmark_count = 0
      for _, stat in ipairs(stats) do
        local line = stat.lineNumber - 1
        if line >= 0 then
          local virt_text = {}

          -- Token count
          table.insert(virt_text, { ' ~' .. format_compact(stat.totalTokens) .. ' tokens', 'GroveVirtualTextTokens' })

          -- File count or single path
          if stat.fileCount > 0 then
            local path_text
            if stat.fileCount == 1 and stat.resolvedPaths and #stat.resolvedPaths > 0 then
              path_text = ' (' .. vim.fn.fnamemodify(stat.resolvedPaths[1], ':t') .. ')'
            else
              path_text = ' (' .. stat.fileCount .. ' files)'
            end
            table.insert(virt_text, { path_text, 'GroveVirtualTextPath' })
          end

          local ok, err = pcall(api.nvim_buf_set_extmark, bufnr, ns_id, line, 0, {
            virt_text = virt_text,
            virt_text_pos = 'eol',
          })

          if ok then
            extmark_count = extmark_count + 1
          else
            vim.notify("Grove: Failed to set extmark on line " .. line .. ": " .. tostring(err), vim.log.levels.DEBUG)
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
  api.nvim_create_autocmd('TextChanged', {
    group = group,
    buffer = bufnr,
    callback = function() debounced_update(bufnr) end,
  })

  -- Initial update
  update(bufnr)
end

return M
