/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

// All bracket constructs share "[" as their opening token.
// After "[", the next token discriminates (heading_marker vs tag_name vs "**" etc.)
// This avoids lexer ambiguity between "[" (element) and "[#" (heading).

module.exports = grammar({
  name: "cx",

  // v3.4: line comments (# to EOL) are extras (skipped wherever
  // whitespace is allowed). Distinct from heading_marker, which is
  // recognized only after "[" and uses /######|#####|####|###|##|#/
  // — those tokens never start a comment because they're guarded by
  // the preceding "[". A bare # at top-level / between attrs / etc.
  // is therefore unambiguously a line comment.
  extras: ($) => [/[ \t\r\n]/, $.line_comment],

  conflicts: ($) => [
    [$.attribute, $.word],
  ],

  rules: {
    document: ($) => repeat($._node),

    _node: ($) =>
      choice(
        $.element,
        $.heading,
        $.bold,
        $.italic,
        $.strike,
        $.subscript,
        $.superscript,
        $.underline,
        $.inline_code,
        $.blockquote,
        $.code_block,
        $.block_content,
        $.comment_element,
        $.pi,
        $.raw_text,
        $.alias,
        $.entity_ref,
        $.triple_quoted,
        // v3.4: top-level attributes (logfmt mode — bare key=value
        // sequences at document root, no enclosing element).
        $.attribute,
        $.word,
        $.text,
        $.number,
        $.boolean,
        $.null_value
      ),

    // ── Element  [tagname attrs content] ─────────────────────────────────────
    element: ($) =>
      seq(
        "[",
        field("name", $.tag_name),
        repeat(
          choice(
            $.table_block,
            $.type_annotation,
            $.attribute,
            $.bool_sigil_attr,
            $.anchor_ref,
            $.merge_ref,
            $._inline_node
          )
        ),
        "]"
      ),

    // ── v3.4 :table[<cols>]<rows> block ──────────────────────────────────────
    // Inline form: `:table[name1:type1 name2:type2]` followed by
    // whitespace-separated row cells until the enclosing element's `]`.
    // Tree-sitter sees the header but treats the rows as ordinary
    // inline content; emitter-level row parsing happens in the V core.
    table_block: ($) =>
      seq($.table_open, repeat($.table_column), "]"),

    table_open: (_) => token(":table["),

    table_column: ($) =>
      seq(
        field("col_name", $.word),
        optional(seq(":", field("col_type", $.type_name)))
      ),

    type_name: (_) =>
      choice(
        "string", "int", "float", "bool", "null", "date", "datetime", "bytes",
        // v3.4 sized + arbitrary-precision types
        "decimal", "bigint",
        "i8", "i16", "i32", "i64",
        "u8", "u16", "u32", "u64",
        "f16", "f32", "f64",
        // short aliases
        "i", "f", "b", "s", "d", "dt"
      ),

    // ── v3.4 boolean sigil attribute  +name / -name ──────────────────────────
    // Atomic token so a leading `-` doesn't conflict with negative
    // numbers: `-2.5` matches the number regex (4 chars) over the
    // bool_sigil regex (which needs an identifier name after).
    bool_sigil_attr: (_) =>
      token(seq(choice("+", "-"), /[a-zA-Z_][a-zA-Z0-9._-]*/)),

    // ── v3.4 line comment  # to EOL ──────────────────────────────────────────
    // Recognized as an "extra" — skipped wherever whitespace is allowed.
    // Distinct from heading_marker, which is anchored after "[".
    line_comment: (_) => token(seq("#", /[^\n]*/)),

    // ── Headings  [# …] through [###### …] ───────────────────────────────────
    // All start with "[" then heading_marker — same "[" token as element,
    // discriminated by heading_marker vs tag_name (disjoint patterns).
    heading: ($) =>
      seq("[", $.heading_marker, repeat($._inline_node), "]"),

    heading_marker: (_) =>
      token(choice("######", "#####", "####", "###", "##", "#")),

    // ── Raw text  [#…#]  (atomic, prec 1 — wins when content ends in #]) ──────
    raw_text: (_) =>
      token(prec(1, seq("[#", /([^#]|#[^\]])*/,"#]"))),

    // ── Inline markup (all split "[" + discriminator) ─────────────────────────
    bold: ($) =>       seq("[", "**",  repeat($._inline_node), "]"),
    italic: ($) =>     seq("[", "*",   repeat($._inline_node), "]"),
    strike: ($) =>     seq("[", "~~",  repeat($._inline_node), "]"),
    subscript: ($) =>  seq("[", "~",   repeat($._inline_node), "]"),
    superscript: ($) => seq("[", "^",  repeat($._inline_node), "]"),
    underline: ($) =>  seq("[", "__",  repeat($._inline_node), "]"),
    inline_code: ($) => seq("[", "`",  repeat(choice($.word, $.text, $.number)), "]"),
    blockquote: ($) => seq("[", ">",   repeat($._inline_node), "]"),

    // ── Code block  [``` lang=X [| … |] ] ────────────────────────────────────
    code_block: ($) =>
      seq("[", "```", optional($.lang_attr), repeat(choice($.attribute, $.block_content)), "]"),

    lang_attr: ($) =>
      seq("lang", choice("=", ":"), field("lang", $.lang_name)),
    lang_name: (_) => /[a-zA-Z][a-zA-Z0-9_+-]*/,

    // ── Block content  [| … |] ────────────────────────────────────────────────
    block_content: ($) =>
      seq("[", "|", optional($.block_body), "|]"),

    // Inner content only — used as injection target (excludes [| and |] delimiters).
    // repeat1 (not repeat) because tree-sitter rejects named rules that match empty.
    // block_content uses optional(block_body) to allow empty [| |] blocks.
    block_body: ($) =>
      repeat1(choice($._inline_bracket, $.block_text, $.block_pipe)),

    _inline_bracket: ($) =>
      choice(
        $.element, $.heading, $.bold, $.italic, $.strike,
        $.subscript, $.superscript, $.underline, $.inline_code,
        $.blockquote, $.code_block, $.block_content,
        $.comment_element, $.pi, $.raw_text, $.alias
      ),

    block_text: (_) => /[^|\[]+/,
    // Standalone | inside block content (e.g. markdown table pipes).
    // "|]" (2 chars) wins over "|" (1 char) at block end — maximal munch.
    block_pipe: (_) => "|",

    // ── Comment element  [-…]  (structural, handles nested elements) ──────────
    // "[" then "-" discriminates from element (tag_name starts with [a-zA-Z_]).
    // Uses dedicated internal node types (comment_bracket, comment_raw) so that
    // ALL content inside a comment highlights as @comment with no bleed-through
    // from inner element/word/etc. captures.
    comment_element: ($) =>
      seq("[", "-", repeat($._comment_child), "]"),

    _comment_child: ($) =>
      choice($.comment_element, $.comment_bracket, $.comment_raw),

    comment_bracket: ($) =>
      seq("[", repeat($._comment_child), "]"),

    comment_raw: (_) => /[^\[\]]+/,

    // ── PI  [?…]  (atomic) ────────────────────────────────────────────────────
    pi: (_) => token(seq("[?", /[^\]]*/, "]")),

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

    // ── Type annotations ──────────────────────────────────────────────────────
    // v3.4: adds sized variants (:i8/:i16/:i32/:i64/:u8/:u16/:u32/:u64/
    // :f16/:f32/:f64), arbitrary-precision (:decimal, :bigint), and
    // short aliases (:i, :f, :b, :s, :d, :dt).
    type_annotation: (_) =>
      token(
        choice(
          seq(
            ":",
            choice(
              "int", "float", "bool", "string", "null", "date", "datetime", "bytes",
              "decimal", "bigint",
              "i8", "i16", "i32", "i64",
              "u8", "u16", "u32", "u64",
              "f16", "f32", "f64",
              "i", "f", "b", "s", "d", "dt"
            ),
            optional("[]")
          ),
          seq(":", "[]")  // :[] — inferred-type array
        )
      ),

    // ── Scalars ───────────────────────────────────────────────────────────────
    // v3.4: numeric literals allow `_` between digits as cosmetic
    // separators (e.g. `1_000_000`). Leading-zero integers other than
    // bare `0` are NOT matched here — they auto-type to string per
    // v3.4 grammar [20c]. (`0`, `0.5`, `0xCAFE` still match.)
    number: (_) => token(
      choice(
        // Hex / octal / binary — v3.4 leaves these alone.
        /-?0[xX][0-9a-fA-F][0-9a-fA-F_]*/,
        /-?0[oO][0-7][0-7_]*/,
        /-?0[bB][01][01_]*/,
        // Float / int with optional underscores. Disallow leading zero
        // in the integer part (`0`, `0.5`, `0e10` ok; `02134` rejected).
        /-?(0|[1-9][0-9_]*)(\.[0-9][0-9_]*)?([eE][+-]?[0-9][0-9_]*)?/
      )
    ),
    boolean: (_) => token(choice("true", "false")),
    null_value: (_) => token("null"),

    // ── Identifier word and non-word text ─────────────────────────────────────
    word: (_) => /[a-zA-Z_][a-zA-Z0-9._-]*/,
    // Excludes = so "=" literal token wins over text, allowing LR(1) attr detection.
    // ' is allowed — triple_quoted (3 chars, atomic) wins over text (1 char) via maximal munch.
    text: (_) => /[^a-zA-Z_\[\]&`0-9=]+/,

    // ── Attributes ────────────────────────────────────────────────────────────
    // Use word (same terminal as content) for the name — LR(1) lookahead on "="
    // resolves: word then "=" → attribute; word then other → content.
    attribute: ($) =>
      seq(field("name", alias($.word, $.attr_name)), "=", field("value", $.attr_value)),

    attr_value: ($) =>
      choice($.quoted_string, $.unquoted_value, $.boolean, $.null_value, $.number),

    quoted_string: (_) =>
      choice(
        seq('"', /[^"\\]*(?:\\.[^"\\]*)*/, '"'),
        seq("'", /[^'\\]*(?:\\.[^'\\]*)*/, "'")
      ),

    unquoted_value: (_) => /[^\s\]"']+/,

    // ── Element sub-tokens ────────────────────────────────────────────────────
    tag_name: (_) => /[a-zA-Z_][a-zA-Z0-9._-]*/,
    anchor_ref: (_) => token(seq("&", /[a-zA-Z_][a-zA-Z0-9._-]*/)),
    merge_ref: (_) => token(seq("*", /[a-zA-Z_][a-zA-Z0-9._-]*/)),

    // ── Inline node set (used in element body and most markup) ────────────────
    _inline_node: ($) =>
      choice(
        $.element,
        $.heading,
        $.bold,
        $.italic,
        $.strike,
        $.subscript,
        $.superscript,
        $.underline,
        $.inline_code,
        $.blockquote,
        $.code_block,
        $.block_content,
        $.raw_text,
        $.comment_element,
        $.pi,
        $.alias,
        $.entity_ref,
        $.triple_quoted,
        $.number,
        $.boolean,
        $.null_value,
        $.word,
        $.text
      ),
  },
});
