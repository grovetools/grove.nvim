-- lua/grove-nvim/grove.lua
-- Public facade module for Grove ecosystem tools

local flow = require('grove-nvim.flow')
local cx = require('grove-nvim.cx')
local gmux = require('grove-nvim.gmux')
local meta = require('grove-nvim.meta')
local nb = require('grove-nvim.nb')
local hooks = require('grove-nvim.hooks')
local data = require('grove-nvim.data')
local rules = require('grove-nvim.rules')

local M = {}

-- Flow (plan management) functions
M.picker = flow.picker
M.init = flow.init
M.extract_from_buffer = flow.extract_from_buffer
M.status = flow.status
M.run = flow.run
M.show_plan_actions = flow.show_plan_actions
M.show_config_actions = flow.show_config_actions
M.add_job_to_active_plan = flow.add_job_to_active_plan
M.add_job_form = flow.add_job_form
M.add_job_wizard = flow.add_job_wizard
M.create_job = flow.create_job
M.add_job_tui = flow.add_job_tui
M.open_plan_tui = flow.open_plan_tui
M.open_status_tui = flow.open_status_tui

-- Context (cx) functions
M.open_cx_view = cx.view
M.set_context_current_file = cx.set_current_file

-- Gmux functions
M.open_gmux_sessionize = gmux.sessionize
M.open_gmux_keymap = gmux.keymap

-- Meta (workspace, release, config, logs) functions
M.open_workspace_status = meta.workspace_status
M.open_workspace_plans_list = meta.workspace_plans_list
M.open_release_tui = meta.release_tui
M.open_logs_tui = meta.logs_tui
M.open_config_analyze_tui = meta.config_analyze_tui

-- Notebook functions
M.open_nb_manage = nb.manage

-- Hooks functions
M.open_hooks_sessions_browse = hooks.sessions_browse

-- Data functions (for backwards compatibility)
M.get_templates = data.get_templates
M.get_models = data.get_models
M.get_active_plan = data.get_active_plan

-- Rules functions
M.preview_rule_files = rules.preview_rule_files

return M
