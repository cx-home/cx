# Multi-line text forms in CX

Reference for the v0.7.0 multi-line-text symmetry pass. One rule
governs every form: **any non-bare value form is valid in every value
position**.

## The five forms (named)

| Sigil | Name | Behaviour |
| --- | --- | --- |
| `"…"` | **dquote** | scalar value; escapes; bracket-aware |
| `'…'` | **squote** | scalar value; escapes; bracket-aware |
| `'''…'''` | **triquote** | multi-line scalar; layout-aware dedent; one leading/trailing newline stripped |
| `[\| … \|]` | **pipe-block** | multi-line structured body; inner CX parsed; newlines preserved as data |
| `[# … #]` | **hash-raw** | multi-line opaque literal; no inner parsing; brackets are content |

Companions in the bracket-sigil family:

| Sigil | Name | Behaviour |
| --- | --- | --- |
| `[- … ]` | **dash-comment** | comment; round-trips to `<!--…-->`; stripped from canonical / hash |
| `# … \n` | **line-comment** | line comment to EOL; emitter may omit on pretty-print |
| `[name … ]` | element | named structural node; bracket-counted body |

## Position-validity matrix

✅ valid · ⚠ requires `[[…]]` BracketBody wrap · — n/a in this position

| Form | doc top | element body | attribute value | CXL slot body | table cell¹ | collection item¹ |
| --- | --- | --- | --- | --- | --- | --- |
| dquote | ✅ scalar-doc | ✅ | ✅ | ✅ | ✅ | ✅ |
| squote | ✅ scalar-doc | ✅ | ✅ | ✅ | ✅ | ✅ |
| triquote | ✅ scalar-doc | ✅ | ✅ | ✅ | ✅ | ✅ |
| pipe-block | ✅ block-doc | ✅ | ✅ | ✅ | ✅ | ✅ |
| hash-raw | ✅ raw-doc | ✅ | ✅ | ✅ | ✅ | ✅ |
| dash-comment | ✅ | ✅ | ⚠ wrap | ⚠ wrap | row-level | ⚠ wrap |
| line-comment | ✅ | ✅ outside body | — | — | row-level | — |
| element `[name …]` | ✅ | ✅ | — (use BracketBody) | ✅ | — | — |
| typed scalar `:type val` | ✅ | ✅ | — (use bare / quoted) | ✅ | ✅ | ✅ |
| **bare text** | ✅ verbatim Text node | ✅ prose (normalised) | BareValue only (no WS) | per body-item rules | BareValue only | BareValue only |

¹ Cells and collection-literal items have a declared type. Bracket-shaped value forms (pipe-block, hash-raw, triquote) are valid when the declared type accepts strings (`:string`, untyped). Numeric / bool types take scalar-value forms only.

## Decision chart

```
Need to embed multi-line text? Two questions:

1. Is it a VALUE (one scalar) or a NODE (body content with AST identity)?
   ├─ Value (attr / cell / collection item):  quoted forms or hash-raw
   └─ Node (body content):                    any bracket-shaped form

2. What's the parsing budget for the content?
   - inline prose, WS → single space      →  bare body
   - single-line scalar with whitespace   →  "…" / '…'
   - multi-line scalar with layout/dedent →  '''…'''
   - structured CX with newline-data      →  [| … |]
   - literal where ] is content           →  [# … #]
   - stripped from output                 →  [- … ]
```

## Doc-top rule

**At document top, if the input doesn't start with a bracket-sigil or a quote, the whole bare text is ONE Text node — verbatim, byte-for-byte (minus one trailing newline by editor convention).**

```cx
a                    → Text("a")
1 2 3                → Text("1 2 3")
1\n2\n3              → Text("1\n2\n3")    -- newlines preserved
hello world          → Text("hello world")
"hello"              → Scalar(string="hello")
'''multi\nline'''    → Scalar(string="multi\nline")  -- with dedent
:int 42              → Scalar(int=42)
[name body]          → Element
```

No auto-typing at top. To get a typed scalar at doc top, write the type
explicitly: `:int 42` produces a `Scalar(int)` document.

## Canonical-form invariance

`cx canonical` / `cx hash` normalise within the scalar-string family
(dquote / squote / triquote producing the same byte sequence collapse
to one canonical form, hashing identically).

The bracket-shaped node forms (pipe-block, hash-raw) are semantically
distinct — they round-trip to different XML constructs (`<cx:block>…</cx:block>`
vs `<![CDATA[…]]>`) and produce different hashes even when their content
is byte-identical. This is intentional: the AST distinction is meaningful.

```sh
# Same value via different scalar forms — same hash
$ cx hash <(echo '[m v="x"]')
$ cx hash <(echo "[m v='x']")
$ cx hash <(echo "[m v='''x''']")
all three identical

# Different node types — different hashes (correct)
$ cx hash <(echo '[m v=[# x #]]')      # RawText
$ cx hash <(echo '[m v=[| x |]]')      # BlockContent
$ cx hash <(echo "[m v='x']")          # scalar string
all three distinct
```

## CXL-side semantics

Every body-item position in CXL slot bodies (`:body`, `:then`, `:else`,
`:return`, `:where`, etc.) accepts every body-item form. Specifically:

- `[?if cond :then '''multi\nline''' :else fallback]` — triquote in slot body ✅
- `[?def msg :body [# raw literal #]]` followed by `[?use msg]` — hash-raw renders to literal text ✅
- `[?def msg :body [| structured |]]` followed by `[?use msg]` — pipe-block renders to text ✅
- `[?let v :be '''content''' :return [?=v]]` — triquote as bound value ✅

See `conformance/eval.txt` fixtures `cxl-056` through `cxl-060` for
the full eval-side verification.

## See also

- [examples/cx-tour.cx](../examples/cx-tour.cx) — CX format tour (every structural feature)
- [examples/cxl-tour.cxl](../examples/cxl-tour.cxl) — CXL directive tour (every eval directive)
- [examples/multi-line-text-tour.cx](../examples/multi-line-text-tour.cx) — every multi-line form in every position
- [spec/grammar.ebnf](../spec/grammar.ebnf) — normative rules [2], [10b], [29e], [55a]
- [conformance/extended.txt](../conformance/extended.txt) — fixtures 035–043 (parser-level)
- [conformance/eval.txt](../conformance/eval.txt) — fixtures cxl-056..060 (eval-level)
