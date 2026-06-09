" cx.vim — Vim/Neovim syntax for the CX language (v0.8.0 surface)
"
" v0.8.0 has NO Markdown sigils (lexicon [L83]): the retired heading
" (`[# …]`), inline-markup (`[** …]`, `[* …]`, `[~~ …]`, `[~ …]`, `[^ …]`,
" `[__ …]`, `[` …]`, `[> …]`), and fenced code-block (`[``` lang=X …]`)
" surfaces are gone. `#`, `>`, `~`, `^`, the backtick are ordinary
" content/operators, never element-head openers. `[#…#]` is RawText / CDATA.
if exists("b:current_syntax") | finish | endif

syn case match

" ── Comments  [- … ] ──────────────────────────────────────────────────────────
syn region cxComment       start=/\[-/ end=/\]/ contains=cxComment,cxCommentBracket
syn region cxCommentBracket start=/\[/  end=/\]/ contains=cxComment,cxCommentBracket contained

" ── Raw text  [# … #]  (CDATA, grammar.ebnf [31]) ─────────────────────────────
syn region cxRawText start=/\[#/ end=/#\]/

" ── Block content  [| … |] ────────────────────────────────────────────────────
syn region cxBlockContent start=/\[|/ end=/|\]/

" ── Triple-quoted  ''' … ''' ──────────────────────────────────────────────────
syn region cxTripleQuoted start=/'''/ end=/'''/

" ── PI  [? … ] ────────────────────────────────────────────────────────────────
" v0.8.0: directive interior is opaque at the Vim syntax layer (same
" structural-only discipline as tree-sitter). Per-directive interior
" coloring (modify action clauses, match arm clauses, CXPath axes) is
" delivered by `cx lsp` semanticTokens. Directives recognised at v0.8.0:
"   * [?modify] (code.md §8.10 — [set] / [delete] / [using] / [rename] /
"     [set-attr] / [delete-attr] / [append] / [prepend] / [insert-before] /
"     [insert-after] / [replace])
"   * [?match]  (code.md §8.2 — multi-arm with [case] / [when] / [else] /
"     [where] clause-children; wildcard _)
"   * [?for] / [?for-array] / [?for-map] / [?let] / [?fn] / [?if] /
"     [?def] / [?lib] / [?const] / [?pipe] / iterator stdlib /
"     resilience / services / concurrency / async / with-* family
"     (full registry per code.md §4.1; `find`, `try`, `par-map`,
"     `par-reduce` are retired and not in the registry).
" A REGION (not a single match) so bracket-bearing directives ([?pipe] with
" [tap …], [?let [= $x E] …], [?fn …], iterator/concurrency/with-* families)
" don't fragment on nested `]`: nested bracket items are contained and consume
" their own `]`, so the outer directive continues. The head `[?name` colors as
" the directive; the body is transparent so children keep their own colors.
syn region cxPI matchgroup=cxPIHead
  \ start=/\[?[a-z][a-z0-9-]*/ end=/\]/
  \ transparent
  \ contains=cxComment,cxRawText,cxBlockContent,cxTripleQuoted,cxPI,cxDecl,
  \   cxCall,cxOperator,cxAlias,cxElement,cxCXPathPrefix,cxCXPathAxis,
  \   cxProgramBinding,cxAttribute,cxTypeAnnotation,cxAtom,cxFloat,cxInteger,
  \   cxBoolean,cxNull,cxString,cxEntityRef

" ── Declaration / doctype  [!…]  (lexicon [L83] structural opener) ─────────────
syn match cxDecl /\[![^\]]*\]/

" ── Call  [$name …] / module member [$prefix:local …]  (code.md §6.3) ─────────
" The `[$` structural opener glues to the head Name. The head colors as a
" function; the body is transparent so arguments keep their own highlighting.
" Symbolic operator heads ([+ …], [= …], [- …], [* …], …) are NOT modelled —
" `-`/`*` collide with [- comment / [* alias, `=`/`<`/`>` with attr/path; that
" coloring is `cx lsp`'s job.
syn region cxCall matchgroup=cxCallHead
  \ start=/\[\$[a-zA-Z_][a-zA-Z0-9._:-]*/ end=/\]/
  \ transparent
  \ contains=cxComment,cxRawText,cxBlockContent,cxTripleQuoted,cxPI,cxDecl,
  \   cxCall,cxOperator,cxAlias,cxElement,cxProgramBinding,cxAttribute,
  \   cxTypeAnnotation,cxAtom,cxFloat,cxInteger,cxBoolean,cxNull,cxString,cxEntityRef

" ── Operator head  [op …]  (code.md §6.5 reserved bare operators) ─────────────
" `+ * / = != < <= > >= and or not cast`. A trailing space after the op keeps
" `[* …]` multiply distinct from the `[*name]` alias. Subtraction `[- …]` is the
" by-design data↔program comment/operator fork — left as a comment (cxComment),
" coloring deferred to `cx lsp`.
syn region cxOperator matchgroup=cxOperatorHead
  \ start=/\[\(!=\|<=\|>=\|+\|\*\|\/\|=\|<\|>\|and\|or\|not\|cast\)\ze\s/ end=/\]/
  \ transparent
  \ contains=cxComment,cxRawText,cxBlockContent,cxTripleQuoted,cxPI,cxDecl,
  \   cxCall,cxOperator,cxAlias,cxElement,cxProgramBinding,cxAttribute,
  \   cxTypeAnnotation,cxAtom,cxFloat,cxInteger,cxBoolean,cxNull,cxString,cxEntityRef

" ── CXPath value expressions (code.md §5.5) ──────────────────────────────────────
" Top-level `//descendant` / `/child` selectors. Match-fragment only —
" tree-sitter / LSP semanticTokens handle interior detail.
syn match cxCXPathPrefix /\v\/\/?\ze[A-Za-z_*@]/
syn match cxCXPathAxis /\v(child|descendant-or-self|descendant|parent|ancestor-or-self|ancestor|following-sibling|preceding-sibling|following|preceding|self|attribute)::/

" ── v0.8.0 code bindings  $name (spec/code.md §3.6) ──────────────────────────
syn match cxProgramBinding /\$[a-zA-Z_][a-zA-Z0-9_-]*/

" ── Alias  [*name] ────────────────────────────────────────────────────────────
syn match cxAlias /\[\*[a-zA-Z_][a-zA-Z0-9._-]*\]/

" ── Type annotations  ::int  ::string[]  ::[]  (glued, grammar.ebnf [26]) ─────
" Single-colon `:name` is an atom literal (code.md §3.6), never a type.
syn match cxTypeAnnotation /::\([A-Za-z][A-Za-z0-9_-]*\)\(\[\]\)\?/
syn match cxTypeAnnotation /::\(\[\]\)/
syn match cxAtom /\(:\)\@<!:[A-Za-z_][A-Za-z0-9_-]*/

" ── Scalar values ─────────────────────────────────────────────────────────────
syn match   cxFloat   /-\?\b[0-9]\+\.[0-9]\+\([eE][+-]\?[0-9]\+\)\?\b/
syn match   cxInteger /-\?\b[0-9]\+\b/
syn keyword cxBoolean true false
syn keyword cxNull    null
syn region  cxString  start=/"/ skip=/\\./ end=/"/ contains=cxEscape
syn region  cxString  start=/'/ skip=/\\./ end=/'/ contains=cxEscape
syn match   cxEscape  /\\./ contained

" ── Entity references ─────────────────────────────────────────────────────────
syn match cxEntityRef /&[a-zA-Z][a-zA-Z0-9]*;\|&#[0-9]\+;\|&#x[0-9a-fA-F]\+;/

" ── Attributes  name=value  name="quoted value" ───────────────────────────────
syn match cxAttrName  /[a-zA-Z_][a-zA-Z0-9._-]*\ze\s*=/ contained
syn match cxAttrEq    /=/ contained
syn match cxAttrValue /\("[^"]*"\|'[^']*'\|[^\s\]]\+\)/ contained
syn match cxAttribute
  \ /[a-zA-Z_][a-zA-Z0-9._-]*\s*=\s*\("[^"]*"\|'[^']*'\|[^\s\]]*\)/
  \ contains=cxAttrName,cxAttrEq,cxAttrValue

" ── Element regions ───────────────────────────────────────────────────────────
" matchgroup highlights [tagname … and … ] with cxTag; content is transparent.
" Listed order of contains determines priority at the same start position.
syn region cxElement matchgroup=cxTag
  \ start=/\[[a-zA-Z_][a-zA-Z0-9._-]*/ end=/\]/
  \ transparent
  \ contains=cxComment,cxRawText,cxBlockContent,cxTripleQuoted,cxPI,cxDecl,
  \   cxCall,cxOperator,cxAlias,cxElement,cxProgramBinding,cxAttribute,
  \   cxTypeAnnotation,cxAtom,cxFloat,cxInteger,cxBoolean,cxNull,cxString,cxEntityRef

" ── Highlight links ───────────────────────────────────────────────────────────
" Use treesitter @* groups on Neovim (picked up by modern colorschemes);
" fall back to classic Vim groups elsewhere.
"   @function → element names / call heads
"   @property → attr names
"   @type     → type annotations
"   @operator → =

if has('nvim')
  " v0.8.0 CXPath highlights
  hi def link cxCXPathPrefix   @keyword.operator
  hi def link cxCXPathAxis     @keyword.coroutine

  " comments, strings, scalars
  hi def link cxComment        @comment
  hi def link cxString         @string
  hi def link cxTripleQuoted   @string
  hi def link cxEscape         @character.special
  hi def link cxFloat          @number.float
  hi def link cxInteger        @number
  hi def link cxBoolean        @boolean
  hi def link cxNull           @constant.builtin
  hi def link cxEntityRef      @string.special

  " raw text / block content — opaque literal payloads
  hi def link cxRawText        @string.special
  hi def link cxBlockContent   @string

  " elements + calls — @function (blue) not @tag (magenta/pink-purple)
  hi def link cxTag            @function
  hi def link cxCallHead       @function.call
  hi def link cxOperatorHead   @operator
  hi def link cxPIHead         @keyword.directive
  hi def link cxPI             @keyword.directive
  hi def link cxDecl           @keyword.directive
  hi def link cxAlias          @variable.member
  hi def link cxProgramBinding @variable.parameter

  " attributes
  hi def link cxAttrName       @property
  hi def link cxAttrEq         @operator
  hi def link cxAttrValue      @string

  " type annotations + atoms
  hi def link cxTypeAnnotation @type
  hi def link cxAtom           @constant
else
  hi def link cxCXPathPrefix   Operator
  hi def link cxCXPathAxis     Statement
  hi def link cxComment        Comment
  hi def link cxString         String
  hi def link cxTripleQuoted   String
  hi def link cxEscape         SpecialChar
  hi def link cxFloat          Float
  hi def link cxInteger        Number
  hi def link cxBoolean        Boolean
  hi def link cxNull           Constant
  hi def link cxEntityRef      Special
  hi def link cxRawText        String
  hi def link cxBlockContent   String
  hi def link cxTag            Function
  hi def link cxCallHead       Function
  hi def link cxOperatorHead   Operator
  hi def link cxPIHead         PreProc
  hi def link cxPI             PreProc
  hi def link cxDecl           PreProc
  hi def link cxAlias          Identifier
  hi def link cxProgramBinding Identifier
  hi def link cxAttrName       Identifier
  hi def link cxAttrEq         Operator
  hi def link cxAttrValue      String
  hi def link cxTypeAnnotation Type
  hi def link cxAtom           Constant
endif

let b:current_syntax = "cx"
