; Embedded-language injection for CX.
;
; CX has NO fenced code-block surface ([``` lang=X …] was the removed
; Markdown feature). The language signal is instead the WRAPPING ELEMENT:
;
;   [python [| def f(): return 1 |]]      ← element name names the language
;   [json   [# {"a": 1} #]]               ← also works for [#…#] raw text
;   [sql    [| select * from users |]]
;   [code lang=javascript [| let x = 1 |]]  ← explicit lang= override
;
; The element name (or a `lang=` attribute) is matched against a known language
; set and used as `@injection.language`; the block body / raw-text content is
; `@injection.content`. An unknown language (no parser installed) injects
; nothing — silently, no error. Block content captures `block_body` (delimiters
; `[|` / `|]` excluded); raw text trims its `[#` / `#]` via #offset!.

; ── Element-name-as-language: block content  [lang [| … |]] ───────────────────
((element
   name: (tag_name) @injection.language
   (block_content (block_body) @injection.content))
 (#any-of? @injection.language
   "json" "javascript" "js" "typescript" "ts" "tsx" "jsx" "python" "py"
   "xml" "html" "css" "scss" "sass" "less" "sql" "yaml" "yml" "toml"
   "bash" "sh" "shell" "zsh" "fish" "rust" "rs" "go" "c" "cpp" "java"
   "ruby" "rb" "lua" "graphql" "dockerfile" "markdown" "md" "ini" "make"
   "cmake" "php" "kotlin" "swift" "scala" "haskell" "elixir" "erlang"
   "clojure" "regex" "jsonc" "proto" "diff" "csv"))

; ── Element-name-as-language: raw text  [lang [# … #]] ────────────────────────
; Captures the inner `raw_content` node — delimiters `[#` / `#]` are excluded.
((element
   name: (tag_name) @injection.language
   (raw_text (raw_content) @injection.content))
 (#any-of? @injection.language
   "json" "javascript" "js" "typescript" "ts" "tsx" "jsx" "python" "py"
   "xml" "html" "css" "scss" "sass" "less" "sql" "yaml" "yml" "toml"
   "bash" "sh" "shell" "zsh" "fish" "rust" "rs" "go" "c" "cpp" "java"
   "ruby" "rb" "lua" "graphql" "dockerfile" "markdown" "md" "ini" "make"
   "cmake" "php" "kotlin" "swift" "scala" "haskell" "elixir" "erlang"
   "clojure" "regex" "jsonc" "proto" "diff" "csv"))

; ── Explicit `lang=` override: [code lang=python [| … |]] ─────────────────────
; Wins when present (a `[code]`/`[pre]`/etc. wrapper whose name is NOT itself a
; language). The value is the unquoted attribute text.
((element
   (attribute
     name: (attr_name) @_k
     value: (attr_value (unquoted_value) @injection.language))
   (block_content (block_body) @injection.content))
 (#eq? @_k "lang"))

((element
   (attribute
     name: (attr_name) @_k
     value: (attr_value (unquoted_value) @injection.language))
   (raw_text (raw_content) @injection.content))
 (#eq? @_k "lang"))
