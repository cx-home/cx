# `cx-stdlib/html` — HTML parse / sanitize / serialize

```cx
[module-meta name=html tier=A status=current
  [standard ref='WHATWG HTML' title='Parse/serialize']]
```

**Status:** Current

Normative reference for the `cx-stdlib/html` sub-package: function-level surface, safe-default sanitizer policy, and policy-element shape.

---

## §1. Scope

`cx-stdlib/html` makes HTML a first-class document format in CX:

- **Parse** — lenient WHATWG HTML5 parsing of real-world tag soup into a CXDM element tree.
- **Sanitize** — remove dangerous markup before rendering attacker-controlled HTML, via a conservative built-in policy or a customizable allowlist.
- **Serialize** — emit a CXDM tree back to HTML5 (or XHTML).
- **Extract text** — strip tags + decode entities for previews / search indexing.

The single load-bearing design property:

> **`[$html:parse]` returns an ordinary CXDM element tree.** Query it with CXPath ([`spec/core/code.md`](../core/code.md) §5.5) and transform it with `[?modify]` ([`spec/core/code.md`](../core/code.md) §8.11). `cx-stdlib/html` defines NO HTML-specific selector or transform functions.

### §1.1. Inbound-HTML sanitization

The driver is XSS sanitization for inbound email. [`cx-stdlib/email`](email.md)'s `html-body` accessor returns the raw `text/html` body part of a message — attacker-controlled HTML carrying `<script>`, `onerror=`, `javascript:` hrefs, `data:` URIs, CSS `expression(...)`, and SVG/MathML script vectors. The canonical pipeline:

```cx
[?let [= $raw  [$email:html-body $msg]]
      [= $safe [$html:sanitize $raw]]
  $safe]
```

Boundary against [`cx-stdlib/strings`](strings.md): `[$strings:escape-html]` / `[$strings:unescape-html]` are character-level entity codecs; `cx-stdlib/html` is the document-level parse/sanitize/serialize layer above them.

## §2. Conceptual model

### §2.1. Lenient parsing

`[$html:parse]` runs the WHATWG HTML5 parsing algorithm: it accepts malformed markup browsers accept and applies the same recovery. It supplies implied `<html>` / `<head>` / `<body>`, closes unclosed tags, repairs mis-nested elements, accepts unquoted attribute values, tolerates stray text. It does not raise on malformed input; only input that cannot be recovered to any tree at all (non-string input) raises.

### §2.2. CXDM element tree

`[$html:parse]` returns an ordinary CXDM element tree: HTML elements become CXDM elements, attributes become CXDM attributes, character data becomes text nodes. The full CX query/transform surface applies:

```cx
# query with CXPath
[?let [= $tree  [$html:parse $raw]]
      [= $links $tree//a/@href]
  $links]

# transform with [?modify]: rewrite every img src through the proxy
[?modify [$html:parse $raw] //img
  [set-attr src [$proxy-url $_@src]]]
```

`parse-fragment` returns a `[sequence element]` of the fragment's top-level nodes with no implied document wrapper.

### §2.3. Policy-driven tree transform

`sanitize-tree` is internally a `[?modify]`-shaped walk that applies a policy: keep allowlisted elements/attributes, drop everything else, neutralize dangerous URL schemes and inline CSS. It adds no capability over `[?modify]` — only a vetted ready-made security policy.

### §2.4. Observable purity

`parse`, `parse-fragment`, `serialize`, `serialize-xhtml`, `extract-text`, `sanitize`, `sanitize-with-policy`, `sanitize-tree`, and `sanitize-tree-with-policy` are all `pure` — same input always yields the same output. The parsed tree is an immutable CXDM value.

## §3. Public function surface

All names are flat kebab-case within the module.

### §3.1. Parse

```
[?def parse          scope=public pure [returns element]            ($html::string) ...]
[?def parse-fragment scope=public pure [returns [sequence element]] ($html::string) ...]
```

Both are lenient. Non-string input raises `CXER3900 E_HTML_PARSE_FAILED`.

### §3.2. Sanitize

```
[?def sanitize                  scope=public pure [returns string]  ($html::string) ...]
[?def sanitize-with-policy      scope=public pure [returns string]  ($html::string $policy::element) ...]
[?def sanitize-tree             scope=public pure [returns element] ($tree::element) ...]
[?def sanitize-tree-with-policy scope=public pure [returns element] ($tree::element $policy::element) ...]
```

`sanitize` = `parse` + safe-default policy + `serialize`. `*-with-policy` variants take a `[html-policy …]` element (§3.2.2); a malformed policy raises `CXER3901 E_HTML_POLICY_INVALID`. `sanitize-tree*` operate on an already-parsed tree.

#### §3.2.1. Built-in safe-default policy

Allowlist (an unrecognized tag, including a future browser vector, is dropped).

**Allowed tags:**

```
a abbr address b blockquote br caption cite code col colgroup dd del dfn div dl dt
em figcaption figure h1 h2 h3 h4 h5 h6 hr i img ins kbd li mark ol p pre q s samp
small span strong sub sup table tbody td tfoot th thead time tr u ul var wbr
```

**Allowed attributes:**

```
href title (on a)   src alt width height (on img)   colspan rowspan (on td/th)
cite (on blockquote/q/del/ins)   datetime (on time/del/ins)
class id lang dir   (global)
```

**Always dropped:**

- `<script>` / `<style>` elements **and their text content**.
- All `on*` event-handler attributes (matched by `on` prefix; future handlers caught).
- `javascript:` URL scheme on URL-bearing attributes — always dropped. Only `http`, `https`, `mailto`, and protocol-relative / relative URLs survive by default.
- `data:` URLs are restricted to a `data:image/*` allowlist: `image/png` / `image/jpeg` / `image/gif` / `image/webp` survive by default. `data:text/html` and `data:image/svg+xml` are always denied. Customizable via `[allow-data-mime …]`.
- `<svg>` / `<math>` and their content (not on allowlist).
- Comments, processing instructions, `<!DOCTYPE>`.

**Inline-CSS property allowlist** (when `style` is kept):

The sanitizer parses the inline `style` declaration list and keeps only declarations whose property is allowlisted **and** whose value passes validation. Allowed properties:

```
color  background-color
font-family  font-size  font-weight  font-style  font-variant
text-align  text-decoration  line-height  letter-spacing  white-space
margin  margin-top  margin-right  margin-bottom  margin-left
padding  padding-top  padding-right  padding-bottom  padding-left
border  border-top  border-right  border-bottom  border-left
  border-color  border-width  border-style  border-radius
width  height  max-width  max-height
display  vertical-align  list-style  list-style-type  list-style-position
```

Value-side: `url(...)` targets must use a safe scheme; `expression(...)` dropped; `behavior` / `-moz-binding` dropped; `position: fixed` / `position: sticky` dropped; values containing `<` or malformed constructs dropped.

Surviving declarations are serialized in a canonical form: the property name is lowercased, the property and value are joined by a single `:` with no surrounding whitespace (`color:red`), and the kept declarations are joined by `;` with no trailing semicolon. Declaration order follows the source order of the surviving declarations.

#### §3.2.2. Policy element shape

`sanitize-with-policy` takes an `[html-policy …]` element. Additive/subtractive against the safe default.

```cx
[html-policy
  [allow-tags table thead tbody tr td th]
  [deny-tags img]
  [allow-attributes class id data-id]
  [deny-attributes title]
  [allow-url-schemes https mailto]
  [allow-data-mime image/png image/gif]
  [allow-css false]]
```

- Each clause is optional. Empty `[html-policy]` equals the safe default.
- `allow-*` adds; `deny-*` removes; deny wins over allow within a single policy.
- `allow-data-mime` replaces the default `data:` MIME allowlist. Empty arg list denies all `data:` URLs. `text/html` and `image/svg+xml` can never be allowed (listing them raises `CXER3901`).
- `allow-css` toggles inline-CSS: `true` (default) keeps `style` with property allowlist; `false` drops `style` entirely.
- `on*` handlers and the `<script>`/`<style>` drops are never overridable; an attempt raises `CXER3901`.

### §3.3. Serialize

```
[?def serialize       scope=public pure [returns string] ($tree::element) ...]
[?def serialize-xhtml scope=public pure [returns string] ($tree::element) ...]
```

`serialize` emits HTML5; `serialize-xhtml` emits XHTML-well-formed output. `serialize(parse(html))` re-parses to an equal tree.

`serialize` follows the WHATWG HTML serialization algorithm — the normative counterpart to the parsing algorithm that already governs `parse` (§2.1). Two consequences are pinned: void elements (e.g. `br`, `img`, `hr`) are emitted as a start tag with no trailing slash (`<br>`, not `<br/>`); attribute values are emitted double-quoted (`src="x"`). `serialize-xhtml` instead emits XML-well-formed output: void elements self-close (`<br/>`) and all attributes are double-quoted.

### §3.4. Extract text

```
[?def extract-text scope=public pure [returns string] ($html::string) ...]
```

Parse, strip all tags, decode named and numeric entities, skip `<script>`/`<style>` content, collapse inter-element whitespace.

## §4. Edge cases

- **Tag soup** — `parse("<p>a<p>b<li>c")` recovers a valid tree; never raises on malformability.
- **Empty input** — `parse("")` returns an empty document tree; `parse-fragment("")` returns an empty sequence.
- **Idempotent sanitize** — `sanitize(sanitize(html)) == sanitize(html)`.
- **Script content** — `sanitize("<script>alert(1)</script><p>hi</p>")` → `"<p>hi</p>"`.
- **`javascript:` href** — dropped.
- **`data:` URI** — `data:image/png` survives; `data:text/html` and `data:image/svg+xml` dropped.
- **`on*` handler** — `<img src="x" onerror="alert(1)">` → `<img src="x">`.
- **Inline CSS** — `width:expression(...)` dropped; `color:red` survives.
- **SVG / MathML** — dropped.
- **Invalid policy** — re-allowing `script` raises `CXER3901`.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER3900` | `E_HTML_PARSE_FAILED` | `parse` / `parse-fragment` on input that cannot be recovered to any tree |
| `CXER3901` | `E_HTML_POLICY_INVALID` | `sanitize-*-with-policy` with a malformed `[html-policy …]`, an attempt to allow an unconditionally-forbidden surface, or a malformed `[allow-data-mime …]` token |
| `CXER3902` | `E_HTML_SERIALIZE_FAILED` | `serialize` / `serialize-xhtml` on a value that is not a well-formed CXDM element tree |

## §6. Conformance fixtures

Under `conformance/stdlib/html.cxd`:

- Real-world tag soup parses to a well-formed CXDM tree; the tree is queryable via CXPath `//a/@href` and transformable via `[?modify]`.
- `parse-fragment` returns a `[sequence element]` with no implied wrapper.
- Known-XSS-vector corpus — default policy neutralizes `<script>`, `onerror`, `javascript:`, `data:text/html`, `data:image/svg+xml`, `expression(...)`, SVG/MathML; `data:image/png` survives; `color:red` survives while `width:expression(...)` is dropped.
- Custom allow / deny clauses: `[allow-tags table tr td]`, `[deny-tags img]`, `[allow-data-mime image/png]`, `[allow-data-mime]` (denies all), and structurally malformed policies raise `CXER3901`.
- `sanitize-tree-with-policy` matches `sanitize-with-policy` on equivalent string.
- Round-trip and idempotence — `serialize(parse(html))` re-parses equal; `parse∘serialize∘parse` idempotent.
- `extract-text` strips tags, decodes entities, skips `<script>`/`<style>`.
- Email pipeline — `[$email:html-body]` then `[$html:sanitize]` is XSS-free.

## §7. Cross-references

- [`spec/core/code.md`](../core/code.md) §5.5 — CXPath, the query surface for parsed HTML.
- [`spec/core/code.md`](../core/code.md) §8.11 — `[?modify]`, the transform surface.
- [`spec/std-lib/email.md`](email.md) — driving consumer; `[$email:html-body]` returns raw HTML.
- [`spec/std-lib/strings.md`](strings.md) — lower-level `escape-html` / `unescape-html` character codecs.
