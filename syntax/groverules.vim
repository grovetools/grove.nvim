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

" Ruleset import patterns
" Ruleset import (project::ruleset pattern)
" Captures the full @alias:project::ruleset or @a:project::ruleset
" Allows trailing whitespace
syntax match groveRulesRulesetImport "^\s*@\(alias\|a\):\s*\S\+::\S\+\s*$" contains=groveRulesAliasDirective,groveRulesRulesetComp1,groveRulesRulesetComp2,groveRulesRulesetDelimiter,groveRulesRulesetDelimiter2,groveRulesRulesetName

" Ruleset :: delimiter
syntax match groveRulesRulesetDelimiter "::" contained

" Single : delimiter in ruleset alias part (before ::)
syntax match groveRulesRulesetDelimiter2 "\(@\(alias\|a\):[^:]*\)\@<=:\ze[^:]" contained

" Ruleset component 1 (ecosystem) - first part before any : or ::
syntax match groveRulesRulesetComp1 "\(@\(alias\|a\):\s*\)\@<=[^/:]\+\ze:" contained

" Ruleset component 2 (repo) - second part after first : but before ::
syntax match groveRulesRulesetComp2 "\(@\(alias\|a\):\s*[^/:]\+:\)\@<=[^/:]\+\ze::" contained

" Ruleset name (the part after ::)
" Allows trailing whitespace
syntax match groveRulesRulesetName "\(::\)\@<=\S\+\ze\s*$" contained

" Simplified approach: Match specific alias patterns with captures
" NOTE: Order matters - most specific first, exclude :: (rulesets)
" Use \ze to stop before whitespace or end-of-line to allow inline directives

" Special case: git repos like @a:git:owner/repo/**/*.go
" The repo component includes slashes (owner/repo)
syntax match groveRulesAliasGitPattern "^\s*@\(alias\|a\):git:\S\+\ze\(\s\|$\)" contains=groveRulesAliasDirective,groveRulesAliasGitEco,groveRulesAliasGitDelim,groveRulesAliasGitRepo

" 3-component alias with path: @a:ecosystem:repo:worktree/path
syntax match groveRulesAlias3CompPath "^\s*@\(alias\|a\):[^/:]\+:[^/:]\+:[^/:]\+\(/\S*\)\?\ze\(\s\|$\)" contains=groveRulesAliasDirective,groveRulesAlias3Comp1,groveRulesAlias3Comp2,groveRulesAlias3Comp3,groveRulesAlias3Delim,groveRulesAlias3Path

" 2-component alias with path: @a:ecosystem:repo/path
syntax match groveRulesAlias2CompPath "^\s*@\(alias\|a\):[^/:]\+:[^/:]\+\(/\S*\)\?\ze\(\s\|$\)" contains=groveRulesAliasDirective,groveRulesAlias2Comp1,groveRulesAlias2Comp2,groveRulesAlias2Delim,groveRulesAlias2Path

" 1-component alias with path: @a:workspace/path
syntax match groveRulesAlias1CompPath "^\s*@\(alias\|a\):[^/:]\+\(/\S*\)\?\ze\(\s\|$\)" contains=groveRulesAliasDirective,groveRulesAlias1Comp,groveRulesAlias1Path

" Component matches for git repos
" Match 'git' as ecosystem
syntax match groveRulesAliasGitEco "\(@\(alias\|a\):\)\@<=git\ze:" contained
" Match the : delimiter after git
syntax match groveRulesAliasGitDelim "\(@\(alias\|a\):git\)\@<=:" contained
" Match everything after git: as the repo (entire GitHub path)
syntax match groveRulesAliasGitRepo "\(@\(alias\|a\):git:\)\@<=\S\+\ze\(\s\|$\)" contained

" Component matches for 3-component aliases
syntax match groveRulesAlias3Comp1 "\(@\(alias\|a\):\)\@<=[^/:[:space:]]\+\ze:" contained
syntax match groveRulesAlias3Comp2 "\(@\(alias\|a\):[^/:]\+:\)\@<=[^/:[:space:]]\+\ze:" contained
syntax match groveRulesAlias3Comp3 "\(@\(alias\|a\):[^/:]\+:[^/:]\+:\)\@<=[^/:[:space:]]\+\ze\(/\|$\|\s\)" contained
syntax match groveRulesAlias3Delim "\(@\(alias\|a\):[^/]*\)\@<=:" contained
syntax match groveRulesAlias3Path "\(@\(alias\|a\):[^/]\+\)\@<=/\S*" contained

" Component matches for 2-component aliases
syntax match groveRulesAlias2Comp1 "\(@\(alias\|a\):\)\@<=[^/:[:space:]]\+\ze:" contained
syntax match groveRulesAlias2Comp2 "\(@\(alias\|a\):[^/:]\+:\)\@<=[^/:[:space:]]\+\ze\(/\|$\|\s\)" contained
syntax match groveRulesAlias2Delim "\(@\(alias\|a\):[^/]*\)\@<=:" contained
syntax match groveRulesAlias2Path "\(@\(alias\|a\):[^/]\+\)\@<=/\S*" contained

" Component matches for 1-component aliases
syntax match groveRulesAlias1Comp "\(@\(alias\|a\):\)\@<=[^/:[:space:]]\+\ze\(/\|$\|\s\)" contained
syntax match groveRulesAlias1Path "\(@\(alias\|a\):[^/]\+\)\@<=/\S*" contained

" Keep old patterns for backwards compatibility with @view: etc
syntax match groveRulesAliasWorkspace "^\s*@\(alias\|a\):\s*\zs[^/:]\+\ze/" contained
syntax match groveRulesContainedAliasWorkspace "\(@\(alias\|a\):\s*\)\@<=[^/:]\+" contained

" Alias directive keyword (@alias: or @a:)
syntax match groveRulesAliasDirective "^\s*@\(alias\|a\):" contained

" View directive keyword (@view: or @v:)
syntax match groveRulesViewDirective "^\s*@\(view\|v\):" contained

" Alias directive within a @view: line
syntax match groveRulesViewAliasDirective "@\(alias\|a\):" contained

" Component patterns for aliases inside @view: directives
" For ruleset imports inside @view: (e.g., @view: @a:eco:repo::ruleset)
syntax match groveRulesViewRulesetComp1 "\(@view:\s*@\(alias\|a\):\)\@<=[^/:]\+\ze:" contained
syntax match groveRulesViewRulesetComp2 "\(@view:\s*@\(alias\|a\):[^/:]\+:\)\@<=[^/:]\+\ze::" contained
syntax match groveRulesViewRulesetDelim "::" contained
syntax match groveRulesViewRulesetName "\(::\)\@<=\S\+" contained

" For 2-component aliases inside @view: (e.g., @view: @a:eco:repo)
syntax match groveRulesViewAlias2Comp1 "\(@view:\s*@\(alias\|a\):\)\@<=[^/:]\+\ze:" contained
syntax match groveRulesViewAlias2Comp2 "\(@view:\s*@\(alias\|a\):[^/:]\+:\)\@<=[^/:]\+\ze\(\s\|$\)" contained

" Full view line with alias
syntax match groveRulesViewLine "^\s*@\(view\|v\):\s\+@\(alias\|a\):\S\+.*$" contains=groveRulesViewDirective,groveRulesViewAliasDirective,groveRulesViewRulesetComp1,groveRulesViewRulesetComp2,groveRulesViewRulesetDelim,groveRulesViewRulesetName,groveRulesViewAlias2Comp1,groveRulesViewAlias2Comp2,groveRulesInlineSearch

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
highlight default link groveRulesExclude      Error
highlight default link groveRulesGitUrl       String
highlight default link groveRulesAliasPattern Type
highlight default link groveRulesAliasValue   Type
highlight default link groveRulesAliasWorkspace Identifier
highlight default link groveRulesContainedAliasWorkspace Identifier
highlight default link groveRulesAliasDirective Keyword

" Alias component highlighting (for ecosystem:repo:worktree)
" Component1 (ecosystem) - Type (typically blue/cyan)
" Component2 (repo) - Constant (typically orange/red)
" Component3 (worktree) - Function (typically purple/violet)
highlight default link groveRulesAlias3Comp1    Type
highlight default link groveRulesAlias3Comp2    Constant
highlight default link groveRulesAlias3Comp3    Function
highlight default link groveRulesAlias3Delim    Operator
highlight default link groveRulesAlias3Path     Normal

highlight default link groveRulesAlias2Comp1    Type
highlight default link groveRulesAlias2Comp2    Constant
highlight default link groveRulesAlias2Delim    Operator
highlight default link groveRulesAlias2Path     Normal

highlight default link groveRulesAlias1Comp     Type
highlight default link groveRulesAlias1Path     Normal

" Git repo highlighting (special case for git:owner/repo patterns)
highlight default link groveRulesAliasGitEco        Type
highlight default link groveRulesAliasGitDelim      Operator
highlight default link groveRulesAliasGitRepo       Constant

" Ruleset import highlighting
highlight default link groveRulesRulesetComp1   Type
highlight default link groveRulesRulesetComp2   Constant
highlight default link groveRulesRulesetDelimiter Operator
highlight default link groveRulesRulesetDelimiter2 Operator
highlight default link groveRulesRulesetName    String

" View directive highlighting
highlight default link groveRulesViewDirective Keyword
highlight default link groveRulesViewAliasDirective Keyword
highlight default link groveRulesViewLine Normal

" View alias component highlighting (for @view: @a:eco:repo::ruleset)
highlight default link groveRulesViewRulesetComp1   Type
highlight default link groveRulesViewRulesetComp2   Constant
highlight default link groveRulesViewRulesetDelim   Operator
highlight default link groveRulesViewRulesetName    String
highlight default link groveRulesViewAlias2Comp1    Type
highlight default link groveRulesViewAlias2Comp2    Constant
highlight default link groveRulesCmdDirective Keyword
highlight default link groveRulesDirective    Keyword
highlight default link groveRulesFindDirective PreProc
highlight default link groveRulesGrepDirective PreProc
highlight default link groveRulesSearchQuery  String
highlight default link groveRulesInlineSearch Normal
highlight default link groveRulesStandaloneSearch Normal

" --- Finalization ---

let b:current_syntax = "groverules"
