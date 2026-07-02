-- Treesitter + LSP semantic token groups, ported from floraverse.nvim
-- (groups/treesitter.lua).
local M = {}

---@param c table derived ColorScheme
---@param opts table resolved ui.theme options
function M.get(c, opts)
  -- stylua: ignore
  return {
    ["@annotation"]        = { fg = c.cyan },
    ["@attribute"]         = { fg = c.yellow },
    ["@boolean"]           = "Boolean",
    ["@character"]         = "Character",
    ["@comment"]           = "Comment",
    ["@comment.error"]     = { fg = c.error },
    ["@comment.todo"]      = { fg = c.bg, bg = c.yellow },
    ["@comment.warning"]   = { fg = c.warning },
    ["@constant"]          = "Constant",
    ["@constant.builtin"]  = { fg = c.orange, italic = true },
    ["@constant.macro"]    = "Macro",
    ["@constructor"]       = { fg = c.magenta },
    ["@function"]          = "Function",
    ["@function.builtin"]  = { fg = c.blue, italic = true },
    ["@function.macro"]    = "Macro",
    ["@keyword"]           = "Keyword",
    ["@keyword.function"]  = { fg = c.purple, style = opts.styles.functions },
    ["@keyword.operator"]  = "Operator",
    ["@label"]             = { fg = c.blue },
    ["@markup.strong"]     = { bold = true },
    ["@markup.italic"]     = { italic = true },
    ["@markup.underline"]  = { underline = true },
    ["@markup.heading"]    = "Title",
    ["@markup.link.url"]   = { fg = c.cyan, underline = true },
    ["@module"]            = "Include",
    ["@number"]            = "Number",
    ["@operator"]          = "Operator",
    ["@property"]          = { fg = c.fg },
    ["@punctuation.bracket"] = { fg = c.fg_dark },
    ["@punctuation.delimiter"] = { fg = c.fg_dark },
    ["@punctuation.special"] = { fg = c.magenta },
    ["@string"]            = "String",
    ["@string.escape"]     = { fg = c.magenta },
    ["@string.regexp"]     = { fg = c.red },
    ["@tag"]               = "Tag",
    ["@tag.attribute"]     = { fg = c.yellow, style = opts.styles.variables },
    ["@tag.delimiter"]     = { fg = c.fg_dark },
    ["@type"]              = "Type",
    ["@type.builtin"]      = { fg = c.blue, italic = true },
    ["@variable"]          = { fg = c.fg, style = opts.styles.variables },
    ["@variable.builtin"]  = { fg = c.red, italic = true },
    ["@variable.parameter"] = { fg = c.yellow, italic = true },

    -- LSP Semantic Tokens
    ["@lsp.type.function"] = "@function",
    ["@lsp.type.method"]   = "@function",
    ["@lsp.type.keyword"]  = "@keyword",
    ["@lsp.type.type"]     = "@type",
    ["@lsp.type.parameter"] = "@variable.parameter",
    ["@lsp.type.variable"] = "@variable",
    ["@lsp.type.property"] = "@property",
  }
end

return M
