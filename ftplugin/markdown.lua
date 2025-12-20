-- ftplugin/markdown.lua
-- Activates features for markdown files.

-- Enable virtual text for grove chat UI.
require('grove-nvim.chat_ui').setup()

-- Enable virtual text for chat file token stats.
require('grove-nvim.chat_stats_ui').setup()
