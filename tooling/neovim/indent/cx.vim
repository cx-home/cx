" cx.vim — indent for the CX language (bracket-depth based).
"
" CX is uniformly bracket-structured (`[head …]`, `{k: v}` maps, `(a, b)`
" sequences), so indentation is a pure bracket-balance computation: a line
" whose unclosed opens exceed its closes indents the next line one
" shiftwidth; a line starting with a closer dedents itself. Strings and
" comment-only lines are handled below; `cx fmt` (the lossless canonical
" formatter) remains the authority — this indentexpr just keeps interactive
" typing close to what fmt will settle on.
if exists('b:did_indent') | finish | endif
let b:did_indent = 1

setlocal indentexpr=GetCxIndent()
setlocal indentkeys=o,O,0],0},0)
setlocal autoindent

let b:undo_indent = 'setlocal indentexpr< indentkeys< autoindent<'

if exists('*GetCxIndent') | finish | endif

" Strip quoted strings and `#` line-comment tails so brackets inside them
" don't count toward the balance.
function! s:StripLiterals(line) abort
  let l = a:line
  " quoted strings (no multi-line tracking — triple-quoted spans are rare in
  " hand-indented code and fmt owns the final layout)
  let l = substitute(l, '"[^"]*"', '""', 'g')
  let l = substitute(l, "'[^']*'", "''", 'g')
  " `#` line comment: only when at line start or after whitespace/`]`, and not
  " glued to a name-start char (that is an IdDecl, grammar.ebnf [51a])
  let l = substitute(l, '\%(^\|[ \t\]]\)\@<=#\%([A-Za-z_]\)\@!.*$', '', '')
  return l
endfunction

function! GetCxIndent() abort
  let lnum = prevnonblank(v:lnum - 1)
  if lnum == 0
    return 0
  endif

  let prev = s:StripLiterals(getline(lnum))
  let ind = indent(lnum)

  " Net opens on the previous line indent one level.
  let opens  = len(substitute(prev, '[^[({]', '', 'g'))
  let closes = len(substitute(prev, '[^\])}]', '', 'g'))
  if opens > closes
    let ind += shiftwidth()
  endif

  " A line that starts with a closer dedents itself one level.
  if getline(v:lnum) =~# '^\s*[\]})]'
    let ind -= shiftwidth()
  endif

  return max([ind, 0])
endfunction
