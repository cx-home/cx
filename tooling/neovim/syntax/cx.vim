" cx.vim — Vim/Neovim syntax for the CX language
"
" CX has NO Markdown sigils (lexicon [L83]): the retired heading
" (`[# …]`), inline-markup (`[** …]`, `[* …]`, `[~~ …]`, `[~ …]`, `[^ …]`,
" `[__ …]`, `[` …]`, `[> …]`), and fenced code-block (`[``` lang=X …]`)
" surfaces are gone. `#`, `>`, `~`, `^`, the backtick are ordinary
" content/operators, never element-head openers. `[#…#]` is RawText / CDATA.
if exists("b:current_syntax") | finish | endif

syn case match

" ── Comments  [; … ]  (asymmetric — open `[;`, close on the matching `]`) ──────
" matchgroup on BOTH regions is load-bearing: without it, the contained
" cxCommentBracket rule may start on the `[` of the region's own start match,
" consume the comment's closing `]` as its own, and leave the outer region
" unterminated — everything after the first `[; …]` rendered as comment.
" Brackets inside comment prose BALANCE (grammar.ebnf [30a], #312).
syn region cxComment matchgroup=cxComment start=/\[;/ end=/\]/
  \ contains=cxComment,cxCommentBracket
syn region cxCommentBracket matchgroup=cxCommentBracket start=/\[/ end=/\]/
  \ contains=cxComment,cxCommentBracket contained

" ── Line comment  # to EOL  (grammar.ebnf [30b], lexicon [L2]) ─────────────────
" `#` starts a line comment only at input start or after whitespace / `]`, and
" only when NOT glued to a name-start char — glued `#name` is an IdDecl
" (grammar.ebnf [51a]), mirroring the tree-sitter grammar's token split.
syn match cxLineComment /\%(^\|[ \t\]]\)\@<=#\%([A-Za-z_]\)\@!.*$/

" ── Raw text  [# … #]  (CDATA, grammar.ebnf [31]) ─────────────────────────────
syn region cxRawText start=/\[#/ end=/#\]/

" ── Block content  [| … |] ────────────────────────────────────────────────────
syn region cxBlockContent start=/\[|/ end=/|\]/

" ── Triple-quoted  ''' … ''' ──────────────────────────────────────────────────
syn region cxTripleQuoted start=/'''/ end=/'''/

" ── PI  [? … ] ────────────────────────────────────────────────────────────────
" Directive interior is opaque at the Vim syntax layer (same
" structural-only discipline as tree-sitter). Per-directive interior
" coloring (modify action clauses, match arm clauses, CXPath axes) is
" delivered by `cx lsp` semanticTokens. Directives recognised:
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
" The `=` head alternative is the `[?=…]` interpolation (grammar.ebnf [58]):
" opaque CXPath body with balanced internal brackets — the contained rules
" (paths, predicates via nested regions) keep the bracket count honest.
syn region cxPI matchgroup=cxPIHead
  \ start=/\[?\%([a-z][a-z0-9-]*\|=\)/ matchgroup=cxBracket end=/\]/
  \ transparent
  \ contains=cxComment,cxLineComment,cxRawText,cxBlockContent,cxTripleQuoted,
  \   cxPI,cxDecl,cxCall,cxOperator,cxAlias,cxElement,cxCXPathPrefix,
  \   cxCXPathAxis,cxRefId,cxProgramBinding,cxAttribute,cxTypeAnnotation,
  \   cxAtom,cxFloat,cxInteger,cxBoolean,cxNull,cxString,cxEntityRef

" ── Declaration / doctype  [!…]  (lexicon [L83] structural opener) ─────────────
syn match cxDecl /\[![^\]]*\]/

" ── Call  [$name …] / module member [$prefix:local …]  (code.md §6.3) ─────────
" The `[$` structural opener glues to the head Name. The head colors as a
" function; the body is transparent so arguments keep their own highlighting.
" Symbolic operator heads ([+ …], [= …], [- …], [* …], …) are NOT modelled here —
" `*` collides with the [* alias and `=`/`<`/`>` with attr/path; that
" coloring is `cx lsp`'s job.
syn region cxCall matchgroup=cxCallHead
  \ start=/\[\$[a-zA-Z_][a-zA-Z0-9._:-]*/ matchgroup=cxBracket end=/\]/
  \ transparent
  \ contains=cxComment,cxLineComment,cxRawText,cxBlockContent,cxTripleQuoted,
  \   cxPI,cxDecl,cxCall,cxOperator,cxAlias,cxElement,cxCXPathPrefix,
  \   cxCXPathAxis,cxRefId,cxProgramBinding,cxAttribute,cxTypeAnnotation,
  \   cxAtom,cxFloat,cxInteger,cxBoolean,cxNull,cxString,cxEntityRef

" ── Operator head  [op …]  (code.md §6.5 reserved bare operators) ─────────────
" `+ - * / = != < <= > >= and or not cast`. A trailing space after the op keeps
" `[* …]` multiply distinct from the `[*name]` alias and `[- …]` subtraction
" distinct from any `[name]` element open. The retired `[- …-]` block comment is
" gone (the current comment is the asymmetric `[; …]`), so `[- ` is now plainly
" the minus operator.
syn region cxOperator matchgroup=cxOperatorHead
  \ start=/\[\(!=\|<=\|>=\|+\|-\|\*\|\/\|=\|<\|>\|and\|or\|not\|cast\)\ze\s/ matchgroup=cxBracket end=/\]/
  \ transparent
  \ contains=cxComment,cxLineComment,cxRawText,cxBlockContent,cxTripleQuoted,
  \   cxPI,cxDecl,cxCall,cxOperator,cxAlias,cxElement,cxCXPathPrefix,
  \   cxCXPathAxis,cxRefId,cxProgramBinding,cxAttribute,cxTypeAnnotation,
  \   cxAtom,cxFloat,cxInteger,cxBoolean,cxNull,cxString,cxEntityRef

" ── CXPath value expressions (code.md §5.5) ──────────────────────────────────────
" Top-level `//descendant` / `/child` selectors. Match-fragment only —
" tree-sitter / LSP semanticTokens handle interior detail.
syn match cxCXPathPrefix /\v\/\/?\ze[A-Za-z_*@]/
syn match cxCXPathAxis /\v(child|descendant-or-self|descendant|parent|ancestor-or-self|ancestor|following-sibling|preceding-sibling|following|preceding|self|attribute)::/

" ── Code bindings  $name (spec/code.md §3.6) ─────────────────────────────────
syn match cxProgramBinding /\$[a-zA-Z_][a-zA-Z0-9_-]*/

" ── Alias  [*name] ────────────────────────────────────────────────────────────
syn match cxAlias /\[\*[a-zA-Z_][a-zA-Z0-9._-]*\]/

" ── Type annotations  ::int  ::string[]  ::[]  (glued, grammar.ebnf [26]) ─────
" Single-colon `:name` is an atom literal (code.md §3.6), never a type.
syn match cxTypeAnnotation /::\([A-Za-z][A-Za-z0-9_-]*\)\(\[\]\)\?/
syn match cxTypeAnnotation /::\(\[\]\)/
" Atom (lexicon [L40]): ':' Ident ('.' Ident)* — dotted segments join into ONE
" hierarchical atom name (`:order.placed`), plus the terminal `.*` prefix-glob
" (bus.md topic patterns, `:order.*`). One token, one color.
syn match cxAtom /\(:\)\@<!:[A-Za-z_][A-Za-z0-9_-]*\%(\.[A-Za-z_][A-Za-z0-9_-]*\)*\%(\.\*\)\?/

" ── Scalar values ─────────────────────────────────────────────────────────────
" `\<`/`\>` word boundaries — NOT `\b`, which in a Vim pattern is a literal
" backspace and can never match (numbers silently never highlighted).
" Shapes follow lexicon/grammar [20]: `_` digit separators, hex/octal/binary
" radix forms, trailing-dot mantissa (`1.`), and exponent-only floats (`1e5`).
" Integers first; cxFloat is defined AFTER so it wins at the same start.
syn match   cxInteger /-\?\<0[xX][0-9a-fA-F][0-9a-fA-F_]*\>/
syn match   cxInteger /-\?\<0[oO][0-7][0-7_]*\>/
syn match   cxInteger /-\?\<0[bB][01][01_]*\>/
syn match   cxInteger /-\?\<\%(0\|[1-9][0-9_]*\)\>/
syn match   cxFloat   /-\?\<\%(0\|[1-9][0-9_]*\)\%(\.[0-9_]*\%([eE][+-]\?[0-9][0-9_]*\)\?\|[eE][+-]\?[0-9][0-9_]*\)/
syn keyword cxBoolean true false
syn keyword cxNull    null
syn region  cxString  start=/"/ skip=/\\./ end=/"/ contains=cxEscape
syn region  cxString  start=/'/ skip=/\\./ end=/'/ contains=cxEscape
syn match   cxEscape  /\\./ contained

" ── Element meta sigils (grammar.ebnf [51]): &anchor  *merge  #id ─────────────
" AnchorDef [60] `&Name` (no trailing `;` — that is an EntityRef), MergeRef [61]
" `*Name`, IdDecl [51a] `#Name` (glued; `# comment` stays a line comment), plus
" the `@IdName` IDREF (cxdm §4.2 — attr-value position and `[ref @id]` body).
syn match cxAnchorRef /&[A-Za-z_][A-Za-z0-9._-]*/
syn match cxMergeRef  /\*[A-Za-z_][A-Za-z0-9._-]*/
syn match cxIdDecl    /#[A-Za-z_][A-Za-z0-9._-]*/
syn match cxRefId     /@[A-Za-z_][A-Za-z0-9._-]*/

" ── Entity references ─────────────────────────────────────────────────────────
" Defined AFTER cxAnchorRef so the `;`-terminated entity wins at the same `&`.
syn match cxEntityRef /&[a-zA-Z][a-zA-Z0-9]*;\|&#[0-9]\+;\|&#x[0-9a-fA-F]\+;/

" ── Attributes  name=value  name="quoted value" ───────────────────────────────
" The unquoted-value class is [^ \t\r\n[\]"'=] — spelled out, NOT `[^\s\]]`
" (inside a bracket class `\s` is a literal backslash + `s`, which swallowed
" values across spaces). The value is anchored to just after the `=` so
" `lang=sql` colors `sql` (never an empty match drifting to the next word).
syn match cxAttrName  /[a-zA-Z_][a-zA-Z0-9._-]*\ze\s*=/ contained
syn match cxAttrEq    /=/ contained
syn match cxAttrValue /\%(=\s*\)\@<=\%("[^"]*"\|'[^']*'\|[^ \t\r\n[\]"'=]\+\)/ contained
syn match cxAttribute
  \ /[a-zA-Z_][a-zA-Z0-9._-]*\%(::[A-Za-z][A-Za-z0-9_-]*\%(\[\]\)\?\|::\[\]\)\?\s*=\s*\%("[^"]*"\|'[^']*'\|[^ \t\r\n[\]"'=]\+\)\?/
  \ contains=cxAttrName,cxAttrEq,cxAttrValue,cxTypeAnnotation,cxRefIdValue
" `@IdName` IDREF in attribute-value position (to=@u1). Defined after
" cxAttrValue so it wins the same start position.
syn match cxRefIdValue /@[A-Za-z_][A-Za-z0-9._-]*/ contained

" ── Element regions ───────────────────────────────────────────────────────────
" Bracket de-emphasis (HIGHLIGHTING.md, approved 2026-06-02): the `[` / `]`
" delimiters carry the cxBracket group (quiet scaffolding); the head name is a
" contained cxTag match so it keeps the loud @function color. `\ze` in the
" start pattern keeps the matchgroup to just the `[`.
" Known cosmetic edge: an element head spelled exactly `true` / `false` /
" `null` colors as the keyword group (Vim keywords beat contained matches);
" real documents don't name elements after scalar literals.
" Listed order of contains determines priority at the same start position.
syn region cxElement matchgroup=cxBracket
  \ start=/\[\ze[a-zA-Z_][a-zA-Z0-9._-]*/ end=/\]/
  \ transparent
  \ contains=cxTag,cxComment,cxLineComment,cxRawText,cxBlockContent,cxTripleQuoted,
  \   cxPI,cxDecl,cxCall,cxOperator,cxAlias,cxElement,cxCXPathPrefix,
  \   cxCXPathAxis,cxAnchorRef,cxMergeRef,cxIdDecl,cxRefId,cxProgramBinding,
  \   cxAttribute,cxTypeAnnotation,cxAtom,cxFloat,cxInteger,cxBoolean,cxNull,
  \   cxString,cxEntityRef
" Head name, glued to the region's opening `[` (bracket itself is cxBracket).
syn match cxTag /\%(\[\)\@<=[a-zA-Z_][a-zA-Z0-9._-]*/ contained

" ── Highlight links ───────────────────────────────────────────────────────────
" Use treesitter @* groups on Neovim (picked up by modern colorschemes);
" fall back to classic Vim groups elsewhere.
"   @function → element names / call heads
"   @property → attr names
"   @type     → type annotations
"   @operator → =

if has('nvim')
  " CXPath highlights
  hi def link cxCXPathPrefix   @keyword.operator
  hi def link cxCXPathAxis     @keyword.coroutine

  " comments, strings, scalars
  hi def link cxComment        @comment
  hi def link cxCommentBracket @comment
  hi def link cxLineComment    @comment
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

  " element meta sigils + references (same @label family as tree-sitter)
  hi def link cxIdDecl         @label
  hi def link cxAnchorRef      @label
  hi def link cxMergeRef       @label
  hi def link cxRefId          @label
  hi def link cxRefIdValue     @label

  " attributes
  hi def link cxAttrName       @property
  hi def link cxAttrEq         @operator
  hi def link cxAttrValue      @string

  " type annotations + atoms
  hi def link cxTypeAnnotation @type
  hi def link cxAtom           @constant

  " bracket de-emphasis (HIGHLIGHTING.md): quiet structural delimiters.
  " Users dim further via
  "   vim.api.nvim_set_hl(0, "cxBracket", { fg = "#ab9434" })
  hi def link cxBracket        @punctuation.bracket
else
  hi def link cxCXPathPrefix   Operator
  hi def link cxCXPathAxis     Statement
  hi def link cxComment        Comment
  hi def link cxCommentBracket Comment
  hi def link cxLineComment    Comment
  hi def link cxIdDecl         Label
  hi def link cxAnchorRef      Label
  hi def link cxMergeRef       Label
  hi def link cxRefId          Label
  hi def link cxRefIdValue     Label
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
  hi def link cxBracket        Delimiter
endif

let b:current_syntax = "cx"
