" cx.vim — filetype plugin for the CX language (bracket matching).
"
" CX is bracket-structured — every form is `[head …]`, with `{k: v}` maps and
" `(a, b)` sequences. This ftplugin guarantees the built-in matchparen plugin
" highlights the twin of the bracket under the cursor, and gives matchit (`%`)
" the same pairs for jumping. Neovim's default `matchpairs` already includes
" these, but a global override (some distros/configs reset it) can drop them
" for a buffer — setting them locally here keeps CX buffers correct regardless.
if exists('b:did_ftplugin_cx') | finish | endif
let b:did_ftplugin_cx = 1

" Twin-highlight + `%`-jump for all three CX bracket kinds.
setlocal matchpairs=(:),{:},[:]

" matchit (`%` jumping) — CX uses the same delimiters; the square-bracket pair
" is the workhorse. (matchit reads b:match_words; harmless if matchit is off.)
let b:match_words = '\[:\],{:},(:)'

let b:undo_ftplugin = 'setlocal matchpairs< | unlet! b:match_words b:did_ftplugin_cx'
