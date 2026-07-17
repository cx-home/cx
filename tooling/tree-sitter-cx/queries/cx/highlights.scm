; ── Element tags ─────────────────────────────────────────────────────────────
(element name: (tag_name) @function)

; Syntactic ID declaration `#name` (grammar.ebnf [51a]; data surface, cxdm §4),
; plus the anchor/merge meta sigils. Distinct label color, not comment-dim.
(id_decl) @label
(anchor_ref) @label
(merge_ref) @label

; ── Call  [$name …] / module member [$prefix:local …]  (code.md §6.3) ─────────
; The `$`-sigil head-dispatch call. The glued open head (`[$name`) colors as a
; function; arguments highlight via their own node rules.
(call (call_head) @function.call)

; ── Operator head  [op …]  (code.md §6.5 reserved bare operators) ─────────────
; `+ - * / = != < <= > >= and or not cast` (subtraction `[- …]` is a plain
; operator now — the retired `[- …-]` block comment is gone; the current
; comment is the asymmetric `[; …]`).
(operator (operator_head) @operator)

; ── Program binding  $name  (code.md §3.6) ───────────────────────────────────
(program_binding) @variable

; ── Path argument  //step  inside a call/operator (e.g. [$count //user]) ──────
(value_path) @keyword.operator

; ── Declaration / doctype  [!…]  (lexicon [L83] structural opener) ────────────
(decl) @keyword.directive

; ── Attributes ────────────────────────────────────────────────────────────────
(attribute name: (attr_name) @property)
(attribute "=" @operator)
(attribute value: (attr_value (quoted_string) @string))
(attribute value: (attr_value (unquoted_value) @string))
(attribute value: (attr_value (boolean) @boolean))
(attribute value: (attr_value (null_value) @constant.builtin))
(attribute value: (attr_value (number) @number))

; ── Directive-body attributes (e.g. [?retry max=3 backoff=exponential]) ───────
; Same coloring as element attributes; the unquoted value needs its own capture
; (number/boolean/null/quoted are covered by the general scalar captures below).
(directive_attribute (attr_name) @property)
(directive_attribute "=" @operator)
(directive_attribute (attr_value (unquoted_value) @string))

; ── Type annotations (grammar.ebnf [26], glued `::T`) ──────────────────────────
(type_annotation) @type

; ── Atom literals (grammar.ebnf [122b], `:NAME`) ───────────────────────────────
(atom_literal) @constant

; ── Block content [| … |] and raw text [#…#] (CDATA) ──────────────────────────
; CX has NO Markdown surface (lexicon [L83]); `[#…#]` is RawText/CDATA, not a
; heading, and there is no inline markup or fenced code block.
(block_content "[" @punctuation.special)
(block_content "|]" @punctuation.special)
(raw_text) @string.special

; ── Comments ──────────────────────────────────────────────────────────────────
(comment_element) @comment
(comment_bracket) @comment
(comment_raw) @comment

; ── Directives ──────────────────────────────────────────────────────────────
;
; Bracket-clause surface (grammar.ebnf [127]): the structured directives
; (match / modify / def / lib / const) expose sub-trees so editors can color
; clause heads / modifier keywords / CXPath axes. Non-structured directives
; ([?for], [?fn], [?if], [?let], [?=], …) — and any head not in the §4.1
; registry, such as the RETIRED [?try] — fall to `unknown_directive`, now a
; STRUCTURED rule (head `[?name` + balanced `directive_body`) so bracket-bearing
; directives ([?pipe]/[?let]/[?fn]/iterator/concurrency/with-*) don't fragment.
; Color only the head so body children keep their own captures.
(unknown_directive (directive_head) @keyword.directive)

; `[?=…]` value interpolation (grammar.ebnf [58]) — head colors as a directive;
; the opaque CXPath body highlights via its own path/predicate captures.
(interpolation (directive_head) @keyword.directive)

; Structured directive openings — the opening token (`[?match`, `[?modify`,
; `[?def`, `[?lib`, `[?const`, including the trailing whitespace) colors
; identically to the legacy directive tag.
(match_directive)  @keyword.directive
(modify_directive) @keyword.directive
(def_directive)    @keyword.directive
(lib_directive)    @keyword.directive
(const_directive)  @keyword.directive

; ── CXPath structure inside directive bodies (code.md §5.5 + §5.5.2) ───────────
(path_expr) @keyword.operator
(axis_specifier) @keyword
(node_test) @tag

; ── Reserved bindings $_ / $_position / $_last (code.md §5.5.2) ──────────────
(reserved_binding) @variable.builtin

; ── `(bind $name)` path-step annotation (grammar.ebnf [160a], code.md §5.5.2) ──
(bind_annot "bind" @keyword.modifier)
(bind_annot name: (bind_name) @variable)

; ── Clause-child heads (case/when/else/where/yield + modify actions + returns/
;    throws/only). Every structured clause opens with `[head ` aliased to
;    `clause_head` (grammar.ebnf [129i], [138]-[140], [142], [151b], [152b]). ─
(clause_head) @keyword

; ── Match arms (code.md §8.2, grammar.ebnf [137]-[140]) ────────────────────────
(match_arm) @keyword

; ── Modify actions (code.md §8.10, grammar.ebnf [142]-[148e]) ──────────────────
(modify_action) @keyword

; ── Def / Const / Lib modifiers (code.md §12.2 + §12.1/§12.3) ──────────────────
; bare `pure` / `impure` / `lazy` / `in-memory` barewords + `scope=` attribute.
(modifier_keyword) @keyword.modifier
(scope_attr (attr_name) @property)
(scope_attr (attr_value) @constant.builtin)

; ── [expr] general predicate (code.md §5.5.2, grammar.ebnf [159]) ──────────────
(predicate_expr) @punctuation.bracket
(predicate_chunk) @variable

; ── Directive name (e.g. function name in [?def NAME …]) ─────────────────────
(directive_name) @function

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

; ── Line comment  # to EOL ────────────────────────────────────────────────────
(line_comment) @comment

; ── Scope note ───────────────────────────────────────────────────────
;
; This grammar provides STRUCTURAL highlighting only — element names, the
; `[$…]` call surface, the reserved operator heads, attributes, scalars, raw
; text / block content, plus a best-effort structural tree for the
; bracket-clause directive surface (match / modify / def / lib / const + path /
; predicate / bind-annot).
;
; NOT modelled here (left to `cx lsp` semanticTokens, the authoritative
; highlighter): a BARE-name path or a
; `//`-path in element-BODY position (vs inside a call/operator, which IS
; handled) — admitting it would mis-color data URLs like `https://…` as CXPath;
; and any per-directive SEMANTIC coloring (e.g. `[returns int]` vs
; `[returns Elem]`). One parser (libcx) is the source of truth; tree-sitter is
; best-effort.
