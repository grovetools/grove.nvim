-- Headless smoke test for diff-view LSP suppression.
--
-- Usage (from the repo root):
--   nvim --headless -u NONE -l tests/lua/diff_view_lsp_smoke.lua

local script = (arg and arg[0]) or debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(script, ":p:h:h:h")
vim.opt.runtimepath:prepend(root)

local failures = 0
local function ok(cond, msg)
  if not cond then
    failures = failures + 1
    io.stderr:write("FAIL: " .. msg .. "\n")
  end
end

local calls = { enable = 0, start = 0, start_client = 0, stop = 0 }
local original_enable = function(_, _)
  calls.enable = calls.enable + 1
end
local original_start = function()
  calls.start = calls.start + 1
  return 101
end
local original_start_client = function()
  calls.start_client = calls.start_client + 1
  return 102
end
local existing_client = {
  stop = function()
    calls.stop = calls.stop + 1
  end,
}

vim.lsp.enable = original_enable
vim.lsp.start = original_start
vim.lsp.start_client = original_start_client
vim.lsp.get_clients = function()
  return { existing_client }
end

-- Normal editing is untouched.
vim.g.grove_diff_view = nil
local guard = require("grove-nvim.lsp")
guard.setup_diff_view_guard()
ok(vim.lsp.enable == original_enable, "normal view must not wrap vim.lsp.enable")
ok(vim.lsp.start == original_start, "normal view must not wrap vim.lsp.start")
ok(vim.lsp.start_client == original_start_client, "normal view must not wrap vim.lsp.start_client")

-- Simulate the host's --cmd marker, set before plugin initialization.
vim.g.grove_diff_view = 1
vim.cmd("runtime plugin/grove.lua")

ok(vim.lsp.enable ~= original_enable, "marked view should wrap vim.lsp.enable")
ok(vim.lsp.start ~= original_start, "marked view should wrap vim.lsp.start")
ok(vim.lsp.start_client ~= original_start_client, "marked view should wrap vim.lsp.start_client")
ok(calls.stop == 1, "a client started before plugin init should be stopped")

ok(vim.lsp.start({}) == nil and calls.start == 0, "vim.lsp.start should be suppressed")
ok(vim.lsp.start_client({}) == nil and calls.start_client == 0, "vim.lsp.start_client should be suppressed")
vim.lsp.enable("gopls")
ok(calls.enable == 0, "vim.lsp.enable should be suppressed")
vim.lsp.enable("gopls", false)
ok(calls.enable == 1, "vim.lsp.enable(..., false) should remain available")

local autocmds = vim.api.nvim_get_autocmds({ group = "GroveNvimDiffViewLspGuard" })
ok(#autocmds == 1, "an LspAttach fallback should be installed")

local wrapped_start = vim.lsp.start
guard.setup_diff_view_guard()
ok(vim.lsp.start == wrapped_start, "guard setup should be idempotent")

if failures > 0 then
  io.stderr:write(("diff_view_lsp_smoke: %d failure(s)\n"):format(failures))
  os.exit(1)
end
print("diff_view_lsp_smoke: OK")
os.exit(0)
