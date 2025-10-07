" Vim syntax file
" Language: Grove Context Rules
" Filetype: groverules
" Maintainer: You

" Prevent loading multiple times
if exists("b:current_syntax")
  finish
endif

" --- Syntax Definitions ---

" Comments (lines starting with #)
syntax match groveRulesComment      "^\s*#.*$"

" Separator (---) for hot/cold context
syntax match groveRulesSeparator    "^---\s*$"

" Exclusion patterns (lines starting with !)
syntax match groveRulesExclude      "^\s*!.*$"

" Git URLs (lines starting with git@ or http(s)://)
syntax match groveRulesGitUrl       "^\s*\(git@\|https\?:\/\/\)\S\+"

" Alias value (the part after @alias: or @a:)
" Uses \zs to start the match after the prefix.
syntax match groveRulesAliasValue   "^\s*@\(alias\|a\):\s*\zs\S\+"

" Alias directive keyword (@alias: or @a:)
syntax match groveRulesAliasDirective "^\s*@\(alias\|a\):"

" Other directives (@view, @default, etc.)
syntax match groveRulesDirective    "^\s*@\(view\|v\|default\|freeze-cache\|no-expire\|disable-cache\|expire-time\)\(:\)\?"

" --- Highlight Linking ---

" Link our custom syntax groups to standard highlight groups.
highlight default link groveRulesComment      Comment
highlight default link groveRulesSeparator    Statement
highlight default link groveRulesExclude      Error
highlight default link groveRulesGitUrl       String
highlight default link groveRulesAliasValue   Identifier
highlight default link groveRulesAliasDirective PreProc
highlight default link groveRulesDirective    PreProc

" --- Finalization ---

let b:current_syntax = "groverules"
