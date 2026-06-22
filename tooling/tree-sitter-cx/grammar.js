/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

// All bracket constructs share "[" as their opening token.
// After "[", the next token discriminates (heading_marker vs tag_name vs "**" etc.)
// This avoids lexer ambiguity between "[" (element) and "[#" (heading).

module.exports = grammar({
  name: "cx",

  // Line comments (# to EOL) are extras (skipped wherever
  // whitespace is allowed). Distinct from heading_marker, which is
  // recognized only after "[" and uses /######|#####|####|###|##|#/
  // — those tokens never start a comment because they're guarded by
  // the preceding "[". A bare # at top-level / between attrs / etc.
  // is therefore unambiguously a line comment.
  extras: ($) => [/[ \t\r\n]/, $.line_comment],

  conflicts: ($) => [
    // `name` after a tag is either an attribute (`name=v` / `name::T=v`) or a
    // bare content word (optionally followed by a standalone `::T` annotation:
    // `name::T value`). GLR picks the interpretation on the `=` lookahead.
    [$.attribute, $._inline_node],
  ],

  rules: {
    document: ($) => repeat($._node),

    _node: ($) =>
      choice(
        $.element,
        $.call,
        $.operator,
        $.decl,
        $.block_content,
        $.comment_element,
        $._directive,
        $.raw_text,
        $.alias,
        $.entity_ref,
        $.triple_quoted,
        // top-level attributes (logfmt mode — bare key=value
        // sequences at document root, no enclosing element).
        $.attribute,
        $.program_binding,
        $.word,
        $.text,
        $.atom_literal,
        $.number,
        $.boolean,
        $.null_value
      ),

    // ── Directive PI  [?Name ...]  ────────────────────────────────────────────
    //
    // grammar.ebnf [127]; the bracket-clause directive surface. Phase 5.1
    // exposes structural sub-trees for the structured directives so editors can
    // color clause heads / modifier keywords / CXPath axes via tree-sitter
    // captures (queries/highlights.scm). The LSP remains the authoritative
    // highlighter; this grammar produces a best-effort structural tree, with
    // free-form ProgramExpr slots captured as opaque `directive_body` token
    // chunks (no expression-grammar mirror).
    //
    // Specific directives (match, modify, def, lib, const) use multi-char
    // open tokens (`[?match`, `[?modify`, …) with higher lexer precedence
    // than the generic `[?` open. Unknown directives fall through to
    // `unknown_directive` which preserves the opaque-token behaviour. A head
    // not in the code.md §4.1 / grammar.ebnf [127e] registry (e.g. the RETIRED
    // `[?try]`) is left to `unknown_directive` — never structured.
    _directive: ($) =>
      choice(
        $.match_directive,
        $.modify_directive,
        $.def_directive,
        $.lib_directive,
        $.const_directive,
        $.for_directive,
        $.if_directive,
        $.unknown_directive
      ),

    // Fallback for directives without a structured rule (e.g. `[?fn]`, `[?let]`,
    // `[?=]`, the iterator combinators, and the RETIRED `[?try]`). Because the
    // opaque body regex `[^\]]*` stops at the first `]`, this rule only fits
    // directives whose body contains NO nested brackets; bracket-bearing
    // directives need a structured rule (match/modify/def/for/if above) or
    // they fragment. A head not in the code.md §4.1 / grammar.ebnf [127e]
    // registry (e.g. `[?try]`) lands here too. Lower precedence than the
    // structured directive openings so those win on dispatch.
    //
    // STRUCTURED (not an opaque token) so bracket-bearing directives — `[?pipe]`
    // with `[tap …]` stages, `[?let [= $x E] …]`, `[?fn …]`, the iterator /
    // concurrency / with-* families — do NOT fragment on nested `]`. The head
    // `[?name` is one token; the rest is the balanced `directive_body` (which
    // recurses through predicate_expr / nested directives / generic clauses).
    unknown_directive: ($) =>
      seq(
        alias($._unknown_open, $.directive_head),
        optional($.directive_body),
        "]"
      ),
    _unknown_open: (_) =>
      token(prec(-1, seq("[?", /[a-zA-Z][a-zA-Z0-9_-]*/))),

    // ── [?for] / [?for-array] / [?for-map] comprehension (grammar.ebnf [129]) ──
    //
    //   [?for] ::= '[?' ('for'|'for-array'|'for-map') (S ForClause)+ S ForYield ']'
    //
    // Clauses are CLAUSE-CHILD elements: generators `[in $x SRC]` / `[in SRC]` /
    // `[in PATTERN SRC]`, filter `[where E]`, let `[= $x E]`, `[order-by E asc]`,
    // `[group-by E]`, `[limit E]`, `[take E]`, `[drop E]`, `[takewhile E]`,
    // `[dropwhile E]`, bare flags `[par]` / `[stream]` / `[ordered]` /
    // `[fail-fast]`, and the terminal `[yield E]` / `[yield-array E]` /
    // `[yield-map K V]`.
    for_directive: ($) =>
      seq(
        $._for_open,
        repeat($.for_clause),
        optional($.yield_clause),
        "]"
      ),
    _for_open: (_) => token(prec(5, /\[\?for(-array|-map)?[ \t\r\n]/)),

    for_clause: ($) =>
      seq(
        alias($._for_clause_open, $.clause_head),
        optional($.directive_body),
        "]"
      ),
    // All for-comp clause heads (except [yield…], which is the terminal). The
    // bare-flag forms ([par] etc.) carry no body. Longest-match within the
    // single alternation token settles e.g. `take`/`takewhile`.
    _for_clause_open: (_) =>
      token(prec(5, seq(
        "[",
        choice(
          "in", "where", "=", "order-by", "group-by",
          "limit", "takewhile", "take", "dropwhile", "drop",
          "par", "stream", "ordered", "fail-fast"
        ),
        /[ \t\r\n\]]/
      ))),

    // ── [?if COND [then E] [else E]?]  (code.md §8.4) ─────────────────────────
    // Clause-children `[then E]` and optional `[else E]`.
    if_directive: ($) =>
      seq(
        $._if_open,
        optional(field("cond", $.directive_body)),
        repeat($.then_clause),
        optional($.else_arm),
        "]"
      ),
    _if_open: (_) => token(prec(5, /\[\?if[ \t\r\n]/)),

    then_clause: ($) =>
      seq(alias($._then_open, $.clause_head), optional($.directive_body), "]"),
    _then_open: (_) => token(prec(5, /\[then[ \t\r\n]/)),

    // ── [?match] multi-arm dispatch  (code.md §8.2, grammar.ebnf [136]-[140]) ──
    //
    //   [?match] ::= '[?match' S ProgramExpr? S MatchArm+ S? ']'
    //   MatchArm ::= CaseArm | WhenArm | ElseArm
    //   CaseArm  ::= '[case' S MatchPattern (S '[where' S Expr S? ']')? S Expr S? ']'
    //   WhenArm  ::= '[when' S Expr S Expr S? ']'
    //   ElseArm  ::= '[else' S Expr S? ']'
    //   (single-arm form: '[?match' S Expr S MatchPattern S? '[yield' E ']' S? ']')
    //
    // Arms are CLAUSE-CHILD elements (`[case …]`, `[when …]`, `[else …]`),
    // NOT colon labels. The retired `:case`/`:when`/`:where`/`:else`/`:yield`
    // colon tokens are gone. Body slots (Pattern / Expr) are captured as
    // `directive_body` opaque runs — no expression-grammar mirror.
    match_directive: ($) =>
      seq(
        $._match_open,
        optional(field("scrutinee", $.directive_body)),
        repeat($.match_arm),
        optional($.yield_clause), // single-arm form: '[?match' Expr Pat '[yield E]'
        "]"
      ),
    // Open tokens REQUIRE a trailing whitespace (or close-`]` for the
    // edge case of a zero-arg directive). Without this guard, literal text
    // `[?match]` in prose would be mis-lexed as a structured open because
    // tree-sitter's `prec(N)` overrides max-munch — we'd never fall back
    // to `unknown_directive`. The trailing whitespace check keeps the
    // structured rules in their lane.
    _match_open: (_) => token(prec(5, /\[\?match[ \t\r\n]/)),

    match_arm: ($) =>
      choice($.case_arm, $.when_arm, $.else_arm),

    // '[case' MatchPattern ('[where' Guard ']')? Body ']'  (grammar.ebnf [138]).
    // The pattern and body are both opaque `directive_body` runs; tree-sitter
    // cannot distinguish the pattern/body boundary without an expression
    // grammar, so the arm content is modelled as directive_body runs around an
    // optional [where] guard clause. The LSP is authoritative for the split.
    case_arm: ($) =>
      seq(
        alias($._case_open, $.clause_head),
        optional($.directive_body),
        optional(seq($.where_clause, optional($.directive_body))),
        "]"
      ),
    _case_open: (_) => token(prec(5, /\[case[ \t\r\n]/)),

    // '[when' Guard Body ']'  (grammar.ebnf [139]). Guard + body are a single
    // opaque directive_body run — the boundary is not observable at this layer.
    when_arm: ($) =>
      seq(
        alias($._when_open, $.clause_head),
        optional($.directive_body),
        "]"
      ),
    _when_open: (_) => token(prec(5, /\[when[ \t\r\n]/)),

    // '[else' Body ']'  (grammar.ebnf [140]) — also reused by [?if] / [?for].
    else_arm: ($) =>
      seq(
        alias($._else_open, $.clause_head),
        field("body", optional($.directive_body)),
        "]"
      ),
    _else_open: (_) => token(prec(5, /\[else[ \t\r\n\]]/)),

    // '[where' Guard ']'  (grammar.ebnf [138] / [129c]) — guard sub-clause.
    where_clause: ($) =>
      seq(
        alias($._where_open, $.clause_head),
        field("guard", optional($.directive_body)),
        "]"
      ),
    _where_open: (_) => token(prec(5, /\[where[ \t\r\n]/)),

    // '[yield' E ']' (grammar.ebnf [129i]) — for-comp / single-arm-match terminal.
    yield_clause: ($) =>
      seq(
        alias($._yield_open, $.clause_head),
        field("body", optional($.directive_body)),
        "]"
      ),
    _yield_open: (_) => token(prec(5, /\[yield(-array|-map)?[ \t\r\n]/)),

    // ── [?modify] pure-functional updates  (code.md §8.10, grammar.ebnf [141]-[148e])
    //
    //   [?modify] ::= '[?modify' S ProgramExpr S PathExpr S ModifyAction+ S? ']'
    //   ModifyAction ::= '[set' E ']' | '[delete' ']' | '[using' E ']'
    //                  | '[rename' Name ']' | '[set-attr' Name E ']'
    //                  | '[delete-attr' Name ']' | '[append' E ']'
    //                  | '[prepend' E ']' | '[insert-before' E ']'
    //                  | '[insert-after' E ']' | '[replace' E ']'
    //
    // Actions are CLAUSE-CHILD elements, NOT colon labels. The doc + focus
    // PathExpr slots precede the first action as a `directive_body` run with
    // the focus PathExpr embedded inline. (Tree-sitter cannot reliably split
    // the doc/focus boundary without an expression grammar; the LSP is
    // authoritative.)
    modify_directive: ($) =>
      seq(
        $._modify_open,
        optional(field("head", $.directive_body)),
        repeat1($.modify_action),
        "]"
      ),
    _modify_open: (_) => token(prec(5, /\[\?modify[ \t\r\n]/)),

    modify_action: ($) =>
      seq(
        alias($._action_open, $.clause_head),
        optional($.directive_body),
        "]"
      ),
    // One token covers all 11 action heads. `[set-attr`/`[delete-attr` must win
    // over `[set`/`[delete` — longest-match handles this within a single
    // alternation token.
    _action_open: (_) =>
      token(prec(5, seq(
        "[",
        choice(
          "set-attr", "delete-attr",
          "set", "delete", "using", "rename",
          "append", "prepend", "insert-before", "insert-after", "replace"
        ),
        /[ \t\r\n\]]/
      ))),

    // ── [?def] module-level functions  (code.md §12.2, grammar.ebnf [152]-[153f]) ─
    //
    //   [?def] ::= '[?def' S Name (S DefModifier)* S ParamList S ProgramExpr S? ']'
    //   DefModifier ::= ScopeAttr | 'pure' | 'impure'
    //                 | '[returns' Type ']' | '[throws' Type ']'
    //
    // Modifiers: `scope=public|private` (attribute), bare `pure`/`impure`
    // barewords, and `[returns T]` / `[throws T]` clauses. ParamList + body
    // captured as opaque `directive_body` — typed-param parsing is not mirrored
    // in tree-sitter; the LSP / V parser is authoritative.
    def_directive: ($) =>
      seq(
        $._def_open,
        field("name", $.directive_name),
        repeat($.def_modifier),
        optional(field("body", $.directive_body)),
        "]"
      ),
    _def_open: (_) => token(prec(5, /\[\?def[ \t\r\n]/)),

    def_modifier: ($) =>
      choice(
        $.scope_attr,
        alias($._kw_pure, $.modifier_keyword),
        alias($._kw_impure, $.modifier_keyword),
        $.returns_clause,
        $.throws_clause
      ),

    // `[returns T]` / `[throws T]` clauses (grammar.ebnf [152b]/[152c]).
    returns_clause: ($) =>
      seq(alias($._returns_open, $.clause_head), optional($.directive_body), "]"),
    _returns_open: (_) => token(prec(5, /\[returns[ \t\r\n]/)),
    throws_clause: ($) =>
      seq(alias($._throws_open, $.clause_head), optional($.directive_body), "]"),
    _throws_open: (_) => token(prec(5, /\[throws[ \t\r\n]/)),

    _kw_pure: (_) => token(prec(4, "pure")),
    _kw_impure: (_) => token(prec(4, "impure")),

    // ── [?lib] module import  (code.md §12.1/§12.3, grammar.ebnf [149]-[151]) ───
    //
    //   [?lib] ::= '[?lib' S Resolver (S LibModifier)* S? ']'
    //   LibModifier ::= AsAttr | ScopeAttr | LibOnly | InMemoryAttr | VersionAttr
    //
    // Modifiers: `as=Name`, `scope=public|private`, `[only name…]` clause
    // (grammar.ebnf [151b]; the canonical scalar form is `only=(a b)`), bare
    // `in-memory`, `version='x'`. NOTE: the impl currently rejects `[only …]`
    // and accepts a legacy `:only` — a KNOWN spec⇄impl gap; the grammar follows
    // the SPEC ([151b]) and does NOT recognize `:only`.
    lib_directive: ($) =>
      seq(
        $._lib_open,
        field("resolver", $.directive_body),
        repeat($.lib_modifier),
        "]"
      ),
    _lib_open: (_) => token(prec(5, /\[\?lib[ \t\r\n]/)),

    lib_modifier: ($) =>
      choice(
        $.attribute, // as=Name, scope=…, version='x' (attribute surface)
        $.lib_alias, // ':as' Name — the keyword import-alias surface
        alias($._kw_in_memory, $.modifier_keyword),
        $.only_clause
      ),

    // `:as Name` import alias (e.g. `[?lib 'cx-stdlib/http' :as http]`) — the
    // keyword form alongside the `as=Name` attribute form. `:as` is lexed as a
    // dedicated higher-precedence keyword token so it is NOT absorbed into the
    // resolver `directive_body` as a generic `:atom` (which left the following
    // name with nowhere to attach and errored).
    lib_alias: ($) =>
      seq(
        alias($._kw_colon_as, $.modifier_keyword),
        field("alias", alias($.word, $.alias_name))
      ),
    _kw_colon_as: (_) => token(prec(6, ":as")),

    // '[only' OnlyItem+ ']'  (grammar.ebnf [151b]/[151b1]).
    only_clause: ($) =>
      seq(
        alias($._only_open, $.clause_head),
        repeat(choice($.only_item, $.directive_name)),
        "]"
      ),
    _only_open: (_) => token(prec(5, /\[only[ \t\r\n]/)),
    // '[' Name 'as' '=' Name ']'  rebind item.
    only_item: ($) =>
      seq("[", field("name", $.directive_name), $.attribute, "]"),

    _kw_in_memory: (_) => token(prec(4, "in-memory")),

    // ── [?const] module-level constants  (code.md §12.3, grammar.ebnf [154]) ────
    //
    //   [?const] ::= '[?const' (S ConstModifier)* S Name S ProgramExpr S? ']'
    //   ConstModifier ::= ScopeAttr | 'lazy'
    const_directive: ($) =>
      seq(
        $._const_open,
        repeat($.const_modifier),
        field("name", $.directive_name),
        optional(field("value", $.directive_body)),
        "]"
      ),
    _const_open: (_) => token(prec(5, /\[\?const[ \t\r\n]/)),

    const_modifier: ($) =>
      choice(
        $.scope_attr,
        alias($._kw_lazy, $.modifier_keyword)
      ),
    _kw_lazy: (_) => token(prec(4, "lazy")),

    // `scope=public|private` visibility attribute (grammar.ebnf [151a]).
    scope_attr: ($) =>
      seq(
        alias($._kw_scope, $.attr_name),
        "=",
        field("value", alias(choice("public", "private"), $.attr_value))
      ),
    _kw_scope: (_) => token(prec(4, "scope")),

    // ── Directive interior tokens ─────────────────────────────────────────────
    //
    // `directive_name` is a plain identifier that follows the directive
    // keyword (e.g. the function name in `[?def fname …]`).
    directive_name: (_) => token(/[a-zA-Z_][a-zA-Z0-9._-]*/),

    // `directive_body` is the opaque run that captures free-form ProgramExpr
    // slots inside a structured directive. It MUST stop at any clause-child
    // open token (`[case`, `[when`, `[else`, `[where`, `[yield`, `[set`, …),
    // at the modifier keywords, and at the closing `]` of the directive.
    //
    // The token excludes leading whitespace; the directive body is a sequence
    // of these chunks separated by other tokens (path expressions, reserved
    // bindings, predicate brackets, nested directives).
    directive_body: ($) =>
      prec.right(repeat1(choice(
        // A quoted string is ONE atomic unit — its content (incl. `/`, which is
        // otherwise the path-step separator) must never be re-lexed. Without
        // this, a `'…/…'` resolver path or a `"…13.5px/1.3…"` CSS const body got
        // split at `/` and the tail mis-parsed as a path step — erroring on a
        // following digit (`/1`) and silently mis-nesting on a letter (`/h`).
        // Listed first so it wins over _directive_chunk / path_expr.
        $.quoted_string,
        $.triple_quoted,
        // `name=value` attribute inside a directive (e.g. `[?retry max=3
        // backoff=exponential]`, `[?lib … as=x]`). MUST precede path_expr so a
        // bareword followed by `=` is an attribute, not a path step (GLR forks
        // on the `=` lookahead — see the [directive_attribute, path_step]
        // conflict).
        $.directive_attribute,
        $._directive_chunk,
        $.atom_literal,
        $.path_expr,
        $.reserved_binding,
        // Bare-bracket sub-expressions / predicates not attached to a path
        // step. The predicate body captures arbitrary content opaquely.
        $.predicate_expr,
        // Nested directives — e.g. `[?def f ($x) [?if $x [then 1] [else 0]]]`.
        $._directive
      ))),

    // A `name=value` (or `name::T=value`) attribute in directive-body position.
    // Reuses the `node_test` token for the name so it shares the bareword lexer
    // class with path steps (no competing `word` token); the parser, not the
    // lexer, disambiguates on the `=` that follows.
    directive_attribute: ($) =>
      seq(
        field("name", alias($.node_test, $.attr_name)),
        optional($.type_annotation),
        "=",
        field("value", $.attr_value)
      ),

    // A `_directive_chunk` is one run of non-special characters between
    // tree-sitter-recognized tokens. Stops at `/` (path step separator),
    // `]` (directive close), `[` (clause / predicate open), and whitespace.
    // Negative precedence lets the chunk lose to any structured token competing
    // for the same prefix (clause opens, atoms, reserved bindings, paths).
    _directive_chunk: (_) =>
      token(prec(-2, /[^\/\[\]\s][^\/\[\]\s]*/)),

    // ── PathExpr  (code.md §5.5, grammar.ebnf [130]-[135] + [160]/[160a]) ───────
    //
    //   PathExpr ::= '//' StepList | '/' StepList | StepList
    //   Step′    ::= (AxisSpecifier '::')? NodeTest BindAnnot? PredicateExpr*
    //   BindAnnot ::= '(' 'bind' S '$' NCName ')'
    //
    // Steps are joined by single `/`. The leading `//` form is
    // descendant-or-self::node()/step. The step-bind annotation is the
    // PARENTHESISED postfix `(bind $name)` (grammar.ebnf [160a]); the retired
    // `:bind NCName` colon form is gone.
    path_expr: ($) =>
      choice(
        seq($._slash_descendant, $._path_step_seq),
        seq($._slash, $._path_step_seq),
        $._path_step_seq
      ),

    _slash_descendant: (_) => token(prec(3, "//")),
    _slash: (_) => token(prec(2, "/")),

    _path_step_seq: ($) =>
      prec.right(seq($.path_step, repeat(seq($._slash, $.path_step)))),

    path_step: ($) =>
      prec.right(seq(
        optional(seq(field("axis", $.axis_specifier), $._axis_sep)),
        field("test", $.node_test),
        optional(field("bind", $.bind_annot)),
        repeat($.predicate_expr)
      )),

    _axis_sep: (_) => token("::"),

    axis_specifier: (_) =>
      token(choice(
        "child",
        "descendant-or-self",
        "descendant",
        "parent",
        "ancestor-or-self",
        "ancestor",
        "following-sibling",
        "preceding-sibling",
        "following",
        "preceding",
        "self",
        "attribute"
      )),

    // NodeTest covers: Name, '*', '*:Local', 'Prefix:*', kind tests, '@name'.
    node_test: (_) =>
      token(
        choice(
          "node()",
          "text()",
          "element()",
          "attribute()",
          // attribute step `@name` (kept compact at the lexer)
          seq("@", /[a-zA-Z_][a-zA-Z0-9._-]*/),
          // wildcards
          "*",
          seq("*:", /[a-zA-Z_][a-zA-Z0-9._-]*/),
          seq(/[a-zA-Z_][a-zA-Z0-9._-]*/, ":*"),
          // Plain Name / QName (QName resolution happens at the LSP layer).
          /[a-zA-Z_][a-zA-Z0-9._-]*/
        )
      ),

    // `(bind $name)` parenthesised postfix step annotation (grammar.ebnf [160a],
    // code.md §5.5.2). Captures the current step's match into a binding. The
    // retired `:bind NCName` colon form is gone. Reserved `$_` is rejected at
    // the runtime layer (CXER0232); the grammar admits any `$Name`.
    bind_annot: ($) =>
      seq("(", $._kw_bind, "$", field("name", $.bind_name), ")"),
    _kw_bind: (_) => token(prec(4, "bind")),
    bind_name: (_) => token(/[a-zA-Z_][a-zA-Z0-9._-]*/),

    // [expr] general predicate  (code.md §5.5.2, grammar.ebnf [159]).
    // Captures the predicate body as opaque text — expression grammar lives
    // in libcx / the LSP. The body BALANCES nested brackets (e.g.
    // `[> [count //x] 3]`, `[?match …]`) and may reference reserved bindings
    // $_ / $_position / $_last as well as generic `$name` program bindings.
    predicate_expr: ($) =>
      seq("[", optional($._predicate_body), "]"),

    _predicate_body: ($) =>
      repeat1(choice(
        $.reserved_binding,
        $.predicate_expr, // nested balanced brackets
        // Plain run, excluding `[` / `]` (bracket boundaries) and `$`
        // (reserved-binding / generic-binding prefix).
        alias(token(prec(-2, /[^\[\]\$]+/)), $.predicate_chunk),
        // Generic `$name` binding (not one of the three reserved names).
        alias(token(prec(1, /\$[a-zA-Z_][a-zA-Z0-9._-]*/)), $.predicate_chunk)
      )),

    // ── Reserved bindings ($_, $_position, $_last) ────────────────────────────
    // Distinct from generic `$name` program bindings (which appear inside
    // directive bodies as parts of `_directive_chunk`). The runtime binds these
    // three names inside predicates and certain expression contexts
    // (code.md §5.5.2).
    reserved_binding: (_) =>
      token(prec(2, choice("$_position", "$_last", "$_"))),

    // ── Element  [tagname attrs content] ─────────────────────────────────────
    element: ($) =>
      seq(
        "[",
        field("name", $.tag_name),
        // glued head type [port::u16 8080] + later positions are all handled
        // by this repeat (type_annotation appears at most once per grammar.ebnf
        // [51], but the grammar does not enforce that count — the V parser does).
        repeat(
          choice(
            $.type_annotation,
            $.attribute,
            $.id_decl,
            $.anchor_ref,
            $.merge_ref,
            $._inline_node
          )
        ),
        "]"
      ),

    // ── Call  [$name args…]  (program mode, lexicon [L83] / code.md §6.3) ─────
    // The `$`-sigil head-dispatch call. `[$` is a STRUCTURAL OPENER (binds
    // first) — an element head never starts with `$`, so there is no element
    // ambiguity. Covers word-named builtins (`[$upper $s]`), user fns, and
    // module members `[$prefix:local …]` (the `:local` is glued into the head).
    // Args are ordinary inline nodes (scalars, strings, `$name` bindings, nested
    // calls/elements/directives). Symbolic operator heads (`[+ …]`, `[= …]`,
    // `[* …]`, …) are NOT modelled here: `*` collides with the
    // `[*` alias structural opener and `=`/`/`/`<`/`>` collide
    // with attribute/path tokens — operator-head coloring is the LSP's job
    // (semanticTokens), consistent with this grammar's best-effort discipline.
    // The open token GLUES `[$` to the head Name (+ optional `:local` module
    // suffix), mirroring the structured-directive opens (`[?match`, …). A shared
    // bare `[` would not reliably dispatch to call vs element under GLR, so the
    // combined high-precedence token is the established pattern in this grammar.
    call: ($) =>
      seq(alias($._call_open, $.call_head), repeat($._call_arg), "]"),
    _call_open: (_) =>
      token(prec(5, seq("[$", /[a-zA-Z_][a-zA-Z0-9._-]*/,
        optional(seq(":", /[a-zA-Z_][a-zA-Z0-9._-]*/))))),

    // ── Operator head  [op …]  (code.md §6.5, the reserved bare operators) ────
    // N-ary prefix expression forms whose head is a CLOSED set of reserved
    // operator tokens (admitted bare — NOT data elements, NOT `$`-prefixed).
    // Modelled via a combined `[`-glued open token (same discipline as `call`),
    // so the head reliably dispatches under GLR and a trailing whitespace keeps
    // each token in its lane.
    //
    // The set here INCLUDES subtraction `[- …]`. The retired `[- …-]` block
    // comment is gone (the current comment is the asymmetric `[; …]`), so `[-`
    // followed by a space is now unambiguously the minus operator — there is no
    // longer a data↔program comment fork to guard against. `*` multiply is safe
    // too: the `[*name]` alias glues its Name with no space, so a space after
    // `*` disambiguates to the operator. The trailing whitespace requirement
    // keeps `[-` distinct from any `[name]` element open.
    operator: ($) =>
      seq(alias($._operator_open, $.operator_head), repeat($._call_arg), "]"),
    _operator_open: (_) =>
      token(prec(5, seq(
        "[",
        // Longest-match within the token settles `!=`/`<=`/`>=` over `<`/`>`/`=`.
        choice("!=", "<=", ">=", "+", "-", "*", "/", "=", "<", ">",
               "and", "or", "not", "cast"),
        /[ \t\r\n]/
      ))),

    // ── Program binding  $name  (code.md §3.6) ───────────────────────────────
    // A `$`-bound value reference in argument / content position (distinct from
    // a call head, which is the FIRST item after `[`). Reserved bindings
    // ($_ / $_position / $_last) win via their higher-precedence token.
    program_binding: (_) =>
      token(prec(1, seq("$", /[a-zA-Z_][a-zA-Z0-9._-]*/))),

    // ── Path argument  //step / /step  (call/operator argument position) ──────
    // A `/`- or `//`-led CXPath used as an argument value, e.g.
    // `[$count //user[@active=true]]`. Only the slash-led forms are admitted as
    // inline values — a BARE-name path would collide with element content words
    // — and it reuses the existing path_step machinery (predicates, axes,
    // bind-annot). Distinct rule name from `path_expr` (which stays the
    // directive-body form) to keep the two contexts separate.
    value_path: ($) =>
      prec.right(choice(
        seq($._slash_descendant, $._path_step_seq),
        seq($._slash, $._path_step_seq)
      )),

    // ── Declaration / doctype  [!…]  (lexicon [L83] structural opener) ────────
    // Opaque structural opener (e.g. `[!DOCTYPE …]`). Body captured as opaque
    // run with no nested-bracket support — mirrors `unknown_directive`. The
    // first body char MUST be a letter so `[!=` lexes as the not-equal operator
    // (code.md §6.5), not a declaration.
    decl: (_) => token(seq("[!", /[A-Za-z][^\]]*/, "]")),

    // ── Type annotations  (grammar.ebnf [26]) ───────────────────────────────
    // Glued DOUBLE-colon form `::T` in EVERY position: element head
    // (`[port::u16 8080]`), attribute (`port::u16=8080`), def param (`$x::int`),
    // table column (`name::int`). Plus `::T[]` (typed array) and `::[]`
    // (inferred-type array). The single-colon form is RETIRED — a single `:`
    // glued to a name is the namespace qualifier; a bare `:NAME` value is an
    // atom literal (grammar.ebnf [122b]).
    type_annotation: (_) =>
      token(
        choice(
          seq(
            "::",
            choice(
              "int", "float", "bool", "string", "null", "atom",
              "date", "datetime", "bytes",
              "decimal", "bigint",
              "i8", "i16", "i32", "i64",
              "u8", "u16", "u32", "u64",
              "f16", "f32", "f64",
              "duration", "instant", "secret"
            ),
            optional("[]")
          ),
          seq("::", "[]")  // ::[] — inferred-type array
        )
      ),

    // ── Atom literal  :NAME  (grammar.ebnf [122b]) ──────────────────────────
    // Tag-shaped scalar value. Single colon glued to a Name in value position.
    // Reserved :true / :false / :null are rejected at the runtime layer
    // (CXER0100); the grammar admits any Name. Negative precedence relative to
    // the `::` type_annotation token so `::T` always wins the longer match.
    atom_literal: (_) =>
      token(seq(":", /[a-zA-Z_][a-zA-Z0-9._-]*/)),

    // ── Line comment  # to EOL ──────────────────────────────────────────────
    // prec 1 so an EMPTY `#` line (`#`\n) lexes as a 1-char line_comment rather
    // than losing the maximal-munch race to `text` (which, excluding `\n` below,
    // can no longer cross the newline to swallow the next line's `#`).
    line_comment: (_) => token(prec(1, seq("#", /[^\n]*/))),

    // ── Raw text  [#…#]  (atomic, prec 1 — wins when content ends in #]) ──────
    //
    // CX has NO Markdown sigils (lexicon [L83]): `[#…#]` is RawText / CDATA
    // (grammar.ebnf [31]), NOT a heading. The retired heading (`[# …]` /
    // `[###### …]`), inline-markup (`[** …]`, `[* …]`, `[~~ …]`, `[~ …]`,
    // `[^ …]`, `[__ …]`, `[\` …]`, `[> …]`), and fenced code-block
    // (`[\`\`\` lang=X …]`) surfaces are GONE — `#`, `>`, `~`, `^`, the backtick
    // are ordinary content/operators, never element-head openers.
    // Structured (open / content / close) rather than one atomic token so the
    // inner `raw_content` is a capturable node — embedded-language injection
    // (queries/injections.scm) targets it directly, with no fragile delimiter
    // offset. `token.immediate` keeps the content/close glued right after `[#`
    // (no whitespace re-entry) and preserves the `#]` boundary: content is any
    // run where `#` is only allowed when NOT followed by `]`.
    raw_text: ($) =>
      seq($._raw_text_open, optional($.raw_content), $._raw_text_close),
    _raw_text_open: (_) => token(prec(1, "[#")),
    raw_content: (_) => token.immediate(prec(1, /([^#]|#[^\]])*/)),
    // prec ABOVE the `line_comment` extra: `#]` must close the raw text, not be
    // eaten as a `#…`-to-EOL comment (which would be the longer match).
    _raw_text_close: (_) => token.immediate(prec(2, "#]")),

    // ── Block content  [| … |] ────────────────────────────────────────────────
    block_content: ($) =>
      seq("[", "|", optional($.block_body), "|]"),

    block_body: ($) =>
      repeat1(choice($._inline_bracket, $.block_text, $.block_pipe)),

    _inline_bracket: ($) =>
      choice(
        $.element, $.call, $.decl, $.block_content,
        $.comment_element, $._directive, $.raw_text, $.alias
      ),

    block_text: (_) => /[^|\[]+/,
    block_pipe: (_) => "|",

    // ── Comment element  [; …]  (structural, handles nested elements) ─────────
    // Block comment: ASYMMETRIC — open `[;`, body, close on the matching
    // `]` (lexicon [L82]). The retired `[- …-]` / `[-- …--]` forms are NO LONGER
    // comments: `[- a b]` is ALWAYS the minus operator now. The open is a single
    // `[;`-glued token (prec 5, matching the structural-opener discipline used by
    // `call`/`operator`) so a bare `[` followed by `;` content can never be
    // mis-dispatched, and `[-` falls through to the `operator` / `element` path.
    comment_element: ($) =>
      seq($._comment_open, repeat($._comment_child), "]"),
    _comment_open: (_) => token(prec(5, "[;")),

    // `raw_text` is a comment child so a `[#…#]` mention INSIDE a block comment
    // (e.g. prose documenting the raw-text syntax) parses as one raw_text node.
    // Without it, `[#` lexes as the raw-text open token (prec 1, beats bare `[`)
    // and the following `#` then triggers the `line_comment` extra (`#`…EOL),
    // which crosses the comment's closing `]` and cascades to EOF. Letting
    // raw_text own the `[#…#]` span keeps the `#]` boundary intact.
    _comment_child: ($) =>
      choice($.comment_element, $.comment_bracket, $.raw_text, $.comment_raw),

    comment_bracket: ($) =>
      seq("[", repeat($._comment_child), "]"),

    comment_raw: (_) => /[^\[\]]+/,

    // ── Alias  [*name]  (atomic — wins over "[" "* …" italic via length) ──────
    alias: (_) =>
      token(seq("[*", /[a-zA-Z_][a-zA-Z0-9._-]*/, "]")),

    // ── Triple-quoted  ''' … ''' ──────────────────────────────────────────────
    triple_quoted: (_) =>
      token(seq("'''", /([^']|'[^']|''[^'])*/, "'''")),

    // ── Entity references ─────────────────────────────────────────────────────
    entity_ref: (_) =>
      token(
        choice(
          seq("&", /[a-zA-Z][a-zA-Z0-9]*/, ";"),
          seq("&#", /[0-9]+/, ";"),
          seq("&#x", /[0-9a-fA-F]+/, ";")
        )
      ),

    // ── Scalars ───────────────────────────────────────────────────────────────
    // Numeric literals allow `_` between digits as cosmetic separators
    // (e.g. `1_000_000`). Leading-zero integers other than bare `0` are NOT
    // matched here — they auto-type to string per grammar [20c].
    number: (_) => token(
      choice(
        /-?0[xX][0-9a-fA-F][0-9a-fA-F_]*/,
        /-?0[oO][0-7][0-7_]*/,
        /-?0[bB][01][01_]*/,
        /-?(0|[1-9][0-9_]*)(\.[0-9][0-9_]*)?([eE][+-]?[0-9][0-9_]*)?/
      )
    ),
    boolean: (_) => token(choice("true", "false")),
    null_value: (_) => token("null"),

    // ── Identifier word and non-word text ─────────────────────────────────────
    word: (_) => /[a-zA-Z_][a-zA-Z0-9._-]*/,
    // Excludes = so "=" literal token wins over text, allowing LR(1) attr detection.
    // ' is allowed — triple_quoted (3 chars, atomic) wins over text (1 char) via maximal munch.
    // Excludes `\n` (newline) so a prose run never crosses a line boundary: an
    // empty `#` comment line would otherwise let `text` swallow `#\n# …` (text
    // admits `#`), beating the 1-char `line_comment`. Newlines are whitespace
    // `extras` anyway, so dropping them from `text` only splits a multi-line
    // prose run into per-line text nodes — cosmetically identical for highlighting.
    text: (_) => /[^a-zA-Z_\[\]&`0-9=:\n]+/,

    // A lone `:` in content position — ordinary prose punctuation (`[p Inline
    // forms: bold]`). `text` excludes `:` so the longer `::T` type_annotation
    // and `:atom` atom_literal tokens can lex cleanly; without a home of its own
    // a standalone colon matched NO token and errored, cascading to EOF. This
    // length-1 token only matches when neither `::…` (≥3 chars) nor `:name`
    // (≥2 chars) applies — maximal munch always prefers those when they fit.
    solo_colon: (_) => token(prec(-1, ":")),

    // ── Attributes ────────────────────────────────────────────────────────────
    // Use word (same terminal as content) for the name — LR(1) lookahead on "="
    // resolves: word then "=" → attribute; word then other → content.
    // The optional glued `::T` annotation supports `port::u16=8080` (grammar.ebnf [26]).
    attribute: ($) =>
      seq(
        field("name", alias($.word, $.attr_name)),
        optional($.type_annotation),
        "=",
        field("value", $.attr_value)
      ),

    // In PROGRAM mode an attribute value is a full ProgramExpr (grammar.ebnf
    // [127c] `ProgramAttribute ::= ProgramAttrName '=' ProgramExpr`), so a
    // bracket-opened value — `total=[$count //user]`, `n=[+ $a $b]`,
    // `body=[span …]`, `x=$ref` — is an expression, not a scalar. Data-mode
    // attrs stay scalar-only (those forms simply don't appear there). The
    // bracket/`$` forms are listed first so they win over `unquoted_value`.
    attr_value: ($) =>
      choice(
        $.call, $.operator, $.element, $.program_binding,
        $.quoted_string, $.unquoted_value, $.boolean, $.null_value, $.number
      ),

    // Atomic single token: the whole "…" / '…' lexes as one unit so an
    // `extras` token (notably line_comment `#`…EOL) can never slip in after the
    // opening quote. Modelling it as seq('"', /…/, '"') let a `#` inside a
    // quoted ATTRIBUTE value (`href="#outro"`) be re-lexed as a line comment,
    // erroring the element and cascading to EOF.
    quoted_string: (_) =>
      token(
        choice(
          seq('"', /[^"\\]*(?:\\.[^"\\]*)*/, '"'),
          seq("'", /[^'\\]*(?:\\.[^'\\]*)*/, "'")
        )
      ),

    // Excludes `[` so a bracket-opened attribute value dispatches to the
    // expression forms above (call / operator / element) rather than being
    // swallowed as a bareword.
    unquoted_value: (_) => /[^\s\[\]"']+/,

    // ── Element sub-tokens ────────────────────────────────────────────────────
    tag_name: (_) => /[a-zA-Z_][a-zA-Z0-9._-]*/,
    // IdDecl (grammar.ebnf [51a]/[51b]): `#NAME` at ElementMeta position
    // declares the element's syntactic ID (data surface; cxdm.md §4). The
    // NAME-start char MUST be glued to `#` — `# comment` (hash + space) stays a
    // line comment, so the token requires a name-start byte immediately after
    // `#`. IdName excludes `:` (IDs are not namespace-qualified), matching the
    // anchor/merge name shape. Lexical prec(1) beats `line_comment` (`#`…EOL,
    // an `extras` token at default prec 0) which would otherwise win the glued
    // `#name run by longest-match; `# comment` (hash + space) does not match
    // this token, so it still lexes as a line comment.
    id_decl: (_) => token(prec(1, seq("#", /[a-zA-Z_][a-zA-Z0-9._-]*/))),
    anchor_ref: (_) => token(seq("&", /[a-zA-Z_][a-zA-Z0-9._-]*/)),
    merge_ref: (_) => token(seq("*", /[a-zA-Z_][a-zA-Z0-9._-]*/)),

    // ── Inline node set (used in element body and most markup) ────────────────
    _inline_node: ($) =>
      choice(
        $.element,
        $.call,
        $.operator,
        $.decl,
        $.block_content,
        $.raw_text,
        $.comment_element,
        $._directive,
        $.alias,
        $.entity_ref,
        $.triple_quoted,
        $.quoted_string,
        $.program_binding,
        $.atom_literal,
        $.number,
        $.boolean,
        $.null_value,
        $.word,
        $.text,
        $.solo_colon
      ),

    // Call / operator ARGUMENT set: every inline node PLUS a slash-led path
    // value (`[$count //user]`). value_path is scoped HERE (program-expression
    // position), NOT in element-body `_inline_node`, so a data value like
    // `https://example.com` keeps its `//` as text instead of a CXPath.
    _call_arg: ($) => choice($.value_path, $._inline_node),
  },
});
