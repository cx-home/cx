; ── Element tags ─────────────────────────────────────────────────────────────
(element name: (tag_name) @function)

; ── Prose elements (known MD/markup set) ──────────────────────────────────────
; Overrides @function for the built-in prose element names so authors can
; distinguish structural markup from domain-specific elements at a glance.
; Uses @markup.link (teal/cyan in most themes) — distinct from @function (blue).
((element name: (tag_name) @markup.link)
 (#any-of? @markup.link "p" "ul" "ol" "li" "table" "hr" "br" "a" "img" "doc" "article" "strong" "b" "em" "i" "del" "s" "u" "sub" "sup" "c"))

; ── Attributes ────────────────────────────────────────────────────────────────
(attribute name: (attr_name) @property)
(attribute "=" @operator)
(attribute value: (attr_value (quoted_string) @string))
(attribute value: (attr_value (unquoted_value) @string))
(attribute value: (attr_value (boolean) @boolean))
(attribute value: (attr_value (null_value) @constant.builtin))
(attribute value: (attr_value (number) @number))

; ── Type annotations ──────────────────────────────────────────────────────────
(type_annotation) @type

; ── Headings ──────────────────────────────────────────────────────────────────
((heading (heading_marker) @_m) @markup.heading.1
 (#eq? @_m "#"))

((heading (heading_marker) @_m) @markup.heading.2
 (#eq? @_m "##"))

((heading (heading_marker) @_m) @markup.heading.3
 (#eq? @_m "###"))

((heading (heading_marker) @_m) @markup.heading.4
 (#eq? @_m "####"))

((heading (heading_marker) @_m) @markup.heading.5
 (#eq? @_m "#####"))

((heading (heading_marker) @_m) @markup.heading.6
 (#eq? @_m "######"))

; The heading_marker punctuation itself
(heading (heading_marker) @punctuation.special)
(heading "[" @punctuation.special)
(heading "]" @punctuation.special)

; ── Inline markup ─────────────────────────────────────────────────────────────
(bold) @markup.strong
(bold "[" @punctuation.delimiter)
(bold "]" @punctuation.delimiter)

(italic) @markup.italic
(italic "[" @punctuation.delimiter)
(italic "]" @punctuation.delimiter)

(strike) @markup.strikethrough
(strike "[" @punctuation.delimiter)
(strike "]" @punctuation.delimiter)

(underline) @markup.underline
(underline "[" @punctuation.delimiter)
(underline "]" @punctuation.delimiter)

(subscript) @markup.italic
(subscript "[" @punctuation.delimiter)
(subscript "]" @punctuation.delimiter)

(superscript) @markup.italic
(superscript "[" @punctuation.delimiter)
(superscript "]" @punctuation.delimiter)

(inline_code) @markup.raw
(inline_code "[" @punctuation.delimiter)
(inline_code "]" @punctuation.delimiter)

(blockquote) @markup.quote
(blockquote "[" @punctuation.delimiter)
(blockquote "]" @punctuation.delimiter)

; ── Code blocks ───────────────────────────────────────────────────────────────
(code_block "[" @punctuation.special)
(code_block "```" @punctuation.special)
(code_block "]" @punctuation.special)
(lang_attr "lang" @keyword.directive)
(lang_attr ["=" ":"] @operator)
(lang_attr lang: (lang_name) @string.special)

; ── Block content and raw text ────────────────────────────────────────────────
; Highlight only the delimiters — injected language highlights the body.
(block_content "[" @punctuation.special)
(block_content "|]" @punctuation.special)
(raw_text) @markup.raw

; ── Comments ──────────────────────────────────────────────────────────────────
(comment_element) @comment
(comment_bracket) @comment
(comment_raw) @comment

; ── PI ────────────────────────────────────────────────────────────────────────
(pi) @keyword.directive

; ── Alias ─────────────────────────────────────────────────────────────────────
(alias) @variable.member

; ── Scalars ───────────────────────────────────────────────────────────────────
(number) @number
(boolean) @boolean
(null_value) @constant.builtin
(quoted_string) @string
(triple_quoted) @string
(entity_ref) @string.special

; ── Element bracket punctuation ───────────────────────────────────────────────
(element "[" @punctuation.bracket)
(element "]" @punctuation.bracket)

; ── v3.4 boolean sigil attributes  +name / -name ──────────────────────────────
(bool_sigil_attr) @property

; ── v3.4 line comment  # to EOL ───────────────────────────────────────────────
(line_comment) @comment

; ── v3.4 :table[<cols>] block ─────────────────────────────────────────────────
(table_block (table_open) @keyword.directive)
(table_block "]" @keyword.directive)
(table_column col_name: (word) @property)
(table_column ":" @operator)
(table_column col_type: (type_name) @type)

; ── Scope note (ADR 0025) ─────────────────────────────────────────────
;
; This grammar provides STRUCTURAL highlighting only — element names,
; attributes, scalars, code blocks, embedded-language injection. Eval
; directives `[?Name ...]` are rendered as opaque `(pi)` regions; the
; directive name, slot labels, and operator tokens inside the brackets
; are NOT individually tokenised.
;
; Per-directive coloring is the job of `cx lsp` (LSP semanticTokens,
; libcx-backed) and the TextMate grammar at tooling/syntax/. Both are
; the canonical highlighting paths. See ADR 0025 for the rationale —
; one parser (libcx), one source of truth, no parallel CFG to drift.
;
; Tree-sitter remains the recommended highlighter for
;   - structural CX (elements, attributes, prose markup, scalars)
;   - embedded-language injection in `[``` lang=X [| … |] ]` blocks
;     (see queries/injections.scm)
;
; Eval-directive interior coloring is a 1.0+ revisit, gated on the
; spec freezing + a grammar-from-EBNF generator landing.
