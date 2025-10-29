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

" Ruleset import delimiter (::)
syntax match groveRulesRulesetDelimiter "::" contained

" Ruleset name (the part after ::)
" Allows trailing whitespace
syntax match groveRulesRulesetName "\(::\)\@<=\S\+\ze\s*$" contained

" Alias part of a ruleset import (e.g., project in project::ruleset)
syntax match groveRulesRulesetAlias "@\(alias\|a\):\s*\zs\S\+\ze::" contained

" Ruleset import (project::ruleset pattern)
" Captures the full @alias:project::ruleset or @a:project::ruleset
" Allows trailing whitespace
syntax match groveRulesRulesetImport "^\s*@\(alias\|a\):\s*\S\+::\S\+\s*$" contains=groveRulesAliasDirective,groveRulesRulesetAlias,groveRulesRulesetDelimiter,groveRulesRulesetName

" Alias workspace/repo identifier (the part before / in @alias:)
" This captures workspace like "grove-core" in "@alias:grove-core/pkg/**"
syntax match groveRulesAliasWorkspace "^\s*@\(alias\|a\):\s*\zs[^/:]\+\ze/" contained

" Alias pattern (full line for regular aliases, not ruleset imports)
" Uses negative lookahead to exclude lines containing ::
" Uses \ze to stop before whitespace to allow inline directives like @find:
syntax match groveRulesAliasPattern "^\s*@\(alias\|a\):\s*\(\S\+::\)\@!\S\+\ze\(\s\|$\)" contains=groveRulesAliasDirective,groveRulesAliasValue,groveRulesAliasWorkspace

" Alias value (the part after @alias: or @a:) - but not ruleset imports
" Uses \zs to start the match after the prefix.
" Stops at whitespace or end of line to allow inline directives
syntax match groveRulesAliasValue   "@\(alias\|a\):\s*\zs\S\+\ze\(\s\|$\)" contained contains=groveRulesAliasWorkspace

" Alias directive keyword (@alias: or @a:)
syntax match groveRulesAliasDirective "^\s*@\(alias\|a\):" contained

" View directive keyword (@view: or @v:)
syntax match groveRulesViewDirective "^\s*@\(view\|v\):"

" Command directive (@cmd:)
syntax match groveRulesCmdDirective "^\s*@cmd:"

" Search directives (@find:, @grep:) - both standalone and inline
syntax match groveRulesFindDirective "@find:" contained
syntax match groveRulesGrepDirective "@grep:" contained

" Search query (quoted string after @find: or @grep:)
syntax region groveRulesSearchQuery start=+"+ end=+"+ contained

" Inline search directive pattern (pattern @find: "query" or pattern @grep: "query")
syntax match groveRulesInlineSearch "\s@\(find\|grep\):.*" contains=groveRulesFindDirective,groveRulesGrepDirective,groveRulesSearchQuery

" Standalone search directive (line starting with @find: or @grep:)
syntax match groveRulesStandaloneSearch "^\s*@\(find\|grep\):.*" contains=groveRulesFindDirective,groveRulesGrepDirective,groveRulesSearchQuery

" Other directives (@default, etc.)
syntax match groveRulesDirective    "^\s*@\(default\|freeze-cache\|no-expire\|disable-cache\|expire-time\)\(:\)\?"

" --- Highlight Linking ---

" Link our custom syntax groups to standard highlight groups.
highlight default link groveRulesComment      Comment
highlight default link groveRulesSeparator    Statement
highlight default link groveRulesExclude      Exception
highlight default link groveRulesGitUrl       String
highlight default link groveRulesAliasPattern Type
highlight default link groveRulesAliasValue   Type
highlight default link groveRulesAliasWorkspace Identifier
highlight default link groveRulesAliasDirective Keyword
highlight default link groveRulesRulesetAlias   Type
highlight default link groveRulesRulesetImport Type
highlight default link groveRulesRulesetDelimiter Operator
highlight default link groveRulesRulesetName String
highlight default link groveRulesViewDirective Constant
highlight default link groveRulesCmdDirective Keyword
highlight default link groveRulesDirective    Keyword
highlight default link groveRulesFindDirective Function
highlight default link groveRulesGrepDirective Function
highlight default link groveRulesSearchQuery  String
highlight default link groveRulesInlineSearch Normal
highlight default link groveRulesStandaloneSearch Normal

" --- Finalization ---

let b:current_syntax = "groverules"
