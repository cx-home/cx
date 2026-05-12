# CX Format Conversion Semantics
# Version: 1.1
# Date: 2026-05-11

This document specifies the semantics of all 30 conversion paths between the 6
supported formats: CX, XML, JSON, YAML, TOML, and Markdown. Self-to-self paths
are covered in §1 (normalization). All 30 cross-format paths are specified in §2
through §7.

### What's new in v1.1 (2026-05-11)

Per — Collection literals + CXL 1.0 refactor:

- **Collection literals** — CXDM v1.1 Array, Map, and Sequence-as-Item
 values now have per-format emit rules in every CX → target section
 (§2.1–§2.5) §D12.
- **`:type[]` element-prefix annotations are deprecated at v0.6.0**
 (per D19). They remain syntactically valid; the parser **desugars
 them on read into collection-literal Array Items**. AST round-trip
 emits canonical Array-literal form, not the original `:type[]`.
 One-way migration; see §0.2 below.
- **JSON edge cases** (null vs missing, empty `{}` vs empty element)
 are clarified for collection-typed values (§2.2 + §4.1).
- **JSON / YAML / TOML / MD streaming-write stubs (W009)** are
 implementable once §2.2–§2.5 land — the JSON-shape decision
 formerly blocking them is mostly resolved by the 1:1 collection-
 literal mapping (per cascade notes F2).
- **CSV / TSV / PSV** gain a rule for cells containing collection
 literals (§8.4 lossy-properties row).

v1.1 is **additive**: every conversion path defined in v1.0 produces
the same output for v1.0 inputs. v1.1 only adds output rules for
inputs that use the new CXDM Item kinds.

---

## Conventions

**Lossless** — a round-trip through the target format and back to CX recovers the
original CX document with identical content and structure.

**Lossy** — some information in the source is not representable in the target format.
When this document says a conversion is lossy, it names the specific information lost.
A binding MUST NOT silently discard information that could be encoded; it drops only
what the target format cannot represent.

**Error** — the source document contains features that are not only non-representable
in the target but cause the conversion to fail. All format errors are communicated
via the calling convention's error mechanism (see `spec/architecture.md §2`).

---

## 0 — Collection literals across formats *(v1.1)*

Per 
§D12 and [`spec/cxdm.md` §2.4–§2.6](cxdm.md), CXDM v1.1 introduces
three container Item kinds — **Array** `[a, b, c]`, **Map** `{k: v}`,
and **Sequence-as-Item** (a Sequence boxed into a single Item slot).
Each format has a canonical emit rule and a parse rule covered in
the following sections; this section gives the cross-format
overview.

### 0.1 Per-format collection-literal correspondence

| Format | Array `[a, b, c]` | Map `{k: v}` | Sequence (top-level) | Sequence-as-Item |
|---|---|---|---|---|
| CX (canonical) | `[a, b, c]` (§D14) | `{k: v}` keys sorted (§D14) | `(a, b, c)` | `(a, b, c)` preserved inside Array/Map slot |
| XML | `<cx:arr><item>a</item>…</cx:arr>` | `<cx:map><entry key="k">v</entry>…</cx:map>` | `<cx:seq><item>a</item>…</cx:seq>` | `<cx:seq>…</cx:seq>` inline at the item slot |
| JSON | `[a, b, c]` (JSON array) | `{"k": v}` (JSON object) | `[a, b, c]` (sequence flattens first) | `[a, b, c]` (boxed Sequence emits as nested JSON array) |
| YAML | block sequence `- item` | block map `k: v` | block sequence (after flatten) | block sequence at the item slot |
| TOML | inline `[a, b, c]` | inline `{k = v}` or `[k]` section | inline `[a, b, c]` (post-flatten) | inline array at the slot |
| MD | bulleted list | definition list (`k\n: v`) | bulleted list (post-flatten) | bulleted list at the slot |

Format-specific rules — escaping, empty-value handling, nested
container behavior, round-trip fidelity — are normative in the
respective §2.x section. JSON / XML round-trip is **lossless for
Arrays / Maps** but **lossy for Sequence vs Array** at the JSON
boundary (a JSON array of arrays round-trips as a CX array of
arrays, not a sequence of arrays). YAML / TOML / MD inherit
JSON-like behavior since none of these formats distinguish flat
sequences from nested arrays at the syntactic level.

The wrapping element names `cx:arr`, `cx:map`, `cx:seq` are
**reserved** by R2
and warning code **W015** flags collisions. The names align with
the file-wide `cx:` namespace convention (per §2.1).

### 0.2 `:type[]` element-prefix annotation — deprecated, desugaring rule *(v1.1)*

Per §D19,
the v1.0 `:type[]` element-prefix annotation (e.g.,
`[tags :string[] core internal]`) is **deprecated at v0.6.0** but
remains syntactically valid. The parser **desugars it on read**
into a top-level collection-literal Array Item. AST round-trip
emits canonical Array-literal form per §D14, **not** the original
`:type[]` form. One-way migration.

**Desugaring rule (normative).** An element of the form

```
[NAME :TYPE[] CHILD1 CHILD2 … CHILDN]
```

where every child is a scalar literal or auto-typed token of type
`TYPE`, desugars to a CXDM Element Node `NAME` whose body is a
single Array Item:

```
Element(NAME, body = [Array([Scalar1, Scalar2, …, ScalarN])])
```

The Array's element type is `TYPE` (informational; CXDM Arrays are
heterogeneous, but the parse-time annotation records the originating
type for round-trip purposes).

**Conditions for desugaring:**

1. The element has exactly one `:type[]` annotation at the prefix
 position (no other type annotation).
2. Children are all scalar tokens or scalar literals — no nested
 elements, no mixed content, no collection literals.
3. The `TYPE` is a recognized CX scalar type (`string`, `int`,
 `float`, `bool`, `date`, `datetime`, `bytes`).

When any condition fails, the element parses as a regular Element
with the `:type[]` annotation preserved on its `data_type` field
(legacy behavior, no Array semantics).

**Migration path:**

- v0.6.0 — `:type[]` desugars on parse; canonical emit produces
 Array literals. Existing CX documents continue to parse without
 change; their AST round-trips to canonical Array form. Tooling
 (formatters, linters) may flag `:type[]` as a v0.7.0+ removal
 candidate.
- v0.7.0+ — `:type[]` form **may be removed** entirely if no
 adopters depend on it. Deprecation timeline tracked under the
 format-stability lock.

**Why deprecated rather than removed.** ratifies one
canonical form for collection-typed values: the Array literal.
Keeping `:type[]` as a parse-only sugar lets v0.5.x → v0.6.0
migration be mechanical (no document rewrites required) while
eliminating the dual-canonical-form risk identified in the
cascade audit.

### 0.3 Streaming-write impact *(v1.1, informational)*

defines the event-stream interface for incremental output emission.
Per cascade-notes F2: collection literals **decompose
into existing event types** at the streaming layer; no new event
types are required. Arrays and Maps emit as start-container /
contents / end-container sequences using the same event vocabulary
that already handles Elements. Sequence-as-Item emits as a nested
collection event-sequence at the item slot. W009 stubs in the
JSON / YAML / TOML / MD streaming-write paths become implementable
once this section's per-format rules land, with no streaming-API
changes required. will be amended with an informational
note pointing here once that section ratifies.

---

## 1 — Self-to-self (normalization)

Self-to-self conversions normalize the source. They are not format conversions.

| Path | Effect |
|------|--------|
| `cx_to_cx` | Canonical CX: consistent indentation, normalized whitespace, attributes in document order |
| `cx_to_cx_compact` | CX with all optional whitespace removed (one-line form) |
| `xml_to_xml` | Round-tripped through the CX AST — normalizes whitespace and attribute ordering |
| `json_to_json` | Round-tripped through the CX semantic model — normalizes key ordering |
| `yaml_to_yaml` | Round-tripped — normalizes YAML style |
| `toml_to_toml` | Round-tripped — normalizes TOML table ordering |
| `md_to_md` | Round-tripped — normalizes Markdown whitespace |

---

## 2 — CX as input

CX is the most expressive format. Converting from CX to any other format is the
primary lossy direction. CX features that have no equivalent in the target format
are handled as described below.

### 2.1 — CX → XML

**Function:** `cx_to_xml`

CX → XML is **round-trip preserving**: all CX features are encoded in the output
using the `cx:` namespace. A round-trip `cx_to_xml` → `xml_to_cx` recovers the
original CX document.

**cx: namespace elements and attributes:**

| CX feature | XML encoding |
|------------|--------------|
| Element anchor (`&name`) | `cx:anchor="name"` attribute |
| Element merge (`<<name`) | `cx:merge="name"` attribute |
| Element type annotation (`:type`) | `cx:type="type"` attribute |
| AliasNode (`*name`) | `<cx:alias name="name"/>` element |
| BlockContent node | `<cx:block>...</cx:block>` element |
| CX namespace attrs (`ns:prefix`) | Converted to `xmlns:prefix="..."` |

The `cx:` namespace prefix is used whenever a CX feature has no XML equivalent.
It is absent from XML output that contains no CX-specific features.

**Arrays, Maps, Sequences (collection literals, v1.1):**

CXDM v1.1 container Items emit as `cx:`-namespaced wrapper elements
(per §D12 + §R2; warning code W015 reserves the names):

| CXDM Item | XML emission |
|---|---|
| Array `[a, b, c]` | `<cx:arr><cx:item>a</cx:item><cx:item>b</cx:item>…</cx:arr>` |
| Map `{k: v, k2: v2}` | `<cx:map><cx:entry cx:key="k">v</cx:entry><cx:entry cx:key="k2">v2</cx:entry>…</cx:map>` |
| Sequence (top-level) | items emitted in order with no wrapping |
| Sequence-as-Item (inside Array / Map) | `<cx:seq><cx:item>a</cx:item>…</cx:seq>` at the item slot |
| Empty Array `[]` | `<cx:arr/>` |
| Empty Map `{}` | `<cx:map/>` |
| Nested containers | wrappers nest naturally |

Keys in `<cx:entry cx:key="…">` carry the key's canonical-form
serialization (per [`spec/canonical.md`](canonical.md) §D14). Non-
string keys (int, date, etc.) are serialized via the canonical
form; round-trip preserves the type via the `cx:key-type` attribute
when the key is non-string. Example:

```cx
[stats {servers: 12, errors: 0, uptime: 1980-01-01}]
```

```xml
<stats>
 <cx:map>
 <cx:entry cx:key="errors">0</cx:entry>
 <cx:entry cx:key="servers">12</cx:entry>
 <cx:entry cx:key="uptime" cx:key-type="date">1980-01-01</cx:entry>
 </cx:map>
</stats>
```

The map-entry order in XML output follows canonical-form key
ordering (lexicographic Unicode order per §D14) regardless of
runtime insertion order. This makes XML output content-addressable.

**`:type[]` legacy form (deprecated, see §0.2):**

The v1.0 `:type[]` element-prefix annotation desugars to an Array
on parse (per §0.2). The XML emit for an element previously written
as

```cx
[tags :string[] core internal]
```

now goes through the collection-literal AST:

```xml
<tags>
 <cx:arr>
 <cx:item>core</cx:item>
 <cx:item>internal</cx:item>
 </cx:arr>
</tags>
```

The legacy emission shape `<tags cx:type="string[]"><item>…</item></tags>`
is **removed at v0.6.0**. The `cx:type` attribute is reserved for
scalar type annotations on element bodies; array-typing now lives
inside the `<cx:arr>` wrapper element.

**CDATA split rule:**

RawText nodes are emitted as XML CDATA sections. The sequence `]]>` cannot appear
inside a CDATA section. Occurrences of `]]>` in RawText are split:

```
]]> → ]]><![CDATA[>
```

The result is two adjacent CDATA sections whose concatenated content equals the
original.

**Mixed content:**

Elements whose body contains both text/scalars and child elements are emitted
inline (opening and closing tag on one line). Elements whose body contains only
child elements are emitted with indented children on separate lines.

**Text and scalar content:**

TextNodes are XML-escaped (`&` → `&amp;`, `<` → `&lt;`, `>` → `&gt;`).
ScalarNodes are emitted as their string representation (typed values round-trip
via `cx:type`).

**Comments, PIs, XMLDecl:**

CommentNodes → `<!-- ... -->`. PINodes → `<?target data?>`. XMLDeclNode →
`<?xml version="1.0" ...?>`. These are all preserved.

**EntityRef:**

EntityRefNodes are emitted as XML entity references: `&name;`.

**What is NOT lossless:**

When the output is used by a non-CX consumer and the `cx:` attributes are
stripped, the following are lost: anchors, merges, aliases, type annotations,
BlockContent structure. The XML elements and their content remain correct.

**Canonical example (v1.1):**

```cx
[config &srv
 [server host=localhost port=8080 :int]
 [tags [web, api]]
]
```

```xml
<config cx:anchor="srv">
 <server cx:type="int" host="localhost" port="8080"/>
 <tags>
 <cx:arr>
 <cx:item>web</cx:item>
 <cx:item>api</cx:item>
 </cx:arr>
 </tags>
</config>
```

The pre-v0.6.0 form `[tags :string[] web api]` parses unchanged and
desugars to the same canonical Array AST per §0.2 — its XML emit is
identical to the v1.1 form above.

---

### 2.2 — CX → JSON (semantic)

**Function:** `cx_to_json`

Produces **semantic JSON**: a data-oriented representation that resolves typed
values to native JSON types. This is distinct from AST JSON (`cx_to_ast`), which
encodes the full parse tree.

**Conversion rules:**

| CX element form | JSON output |
|-----------------|-------------|
| Element with attrs only | JSON object with attr names as keys |
| Element with text only (no attrs, no child elements) | JSON string |
| Element with a single scalar (no attrs, no children) | JSON native value |
| Element with multiple scalars only (array form) | JSON array |
| Element with attrs + body text | JSON object with attr keys + `"_"` for body |
| Element with child elements | JSON object with child element names as keys |
| Multiple same-named children | JSON array under that key |
| Empty element (no attrs, no body) | JSON null |

**Typed scalar to JSON:**

| CX scalar type | JSON output |
|----------------|-------------|
| int | JSON number (no decimal point) |
| float | JSON number (with decimal point or `e` notation) |
| bool | JSON boolean |
| null | JSON null |
| string | JSON string |
| date | JSON string (ISO 8601) |
| datetime | JSON string (ISO 8601) |
| bytes | JSON string (base64, no padding-stripping per [`spec/canonical.md`](canonical.md)) |

**Collection-literal Items to JSON (v1.1, §D12):**

| CXDM Item | JSON output |
|---|---|
| Array `[a, b, c]` | JSON array `[a, b, c]` — items emitted recursively |
| Map `{k: v}` | JSON object `{"k": v}` — keys serialized as JSON strings (see edge case below) |
| Sequence (top-level or in element body) | JSON array `[a, b, c]` — sequence flattens before emit (per §1.2 CXDM sequence-flat rule) |
| Sequence-as-Item (inside Array / Map value) | JSON array — preserved nesting |
| Empty Array `[]` | JSON `[]` |
| Empty Map `{}` | JSON `{}` |

**JSON edge cases (v1.1):**

| CX form | JSON output | Round-trips back to |
|---|---|---|
| `[items []]` (empty Array body) | `{"items": []}` | empty Array (not empty element) |
| `[items {}]` (empty Map body) | `{"items": {}}` | empty Map (not empty element) |
| `[items]` (empty element, no body) | `{"items": null}` | empty element |
| `[items null]` (explicit null) | `{"items": null}` | scalar `null` body (round-trip-ambiguous with empty-element; see below) |
| `[items missing]` (no key in JSON output) | n/a — CX always emits the key | (parse asymmetry: JSON `missing` doesn't occur from CX emit; on JSON → CX parse, missing keys mean the element is absent) |

**Round-trip ambiguity.** `[items]` (empty element) and `[items null]`
(element with single null scalar) both serialize to `{"items": null}`
on JSON emit and parse back as `[items]` (per §4.1's "JSON null →
empty Element" rule). This is a documented one-bit loss in the
CX-element-vs-CX-null distinction at the JSON boundary.
Workaround: callers requiring round-trip fidelity through JSON
should use the AST JSON path (`cx_to_ast`) rather than semantic
JSON.

**Non-string map keys.** JSON requires object keys to be strings.
CX Maps with non-string keys (int, float, date, etc., per
[`spec/cxdm.md` §2.5](cxdm.md)) **coerce keys to strings on emit**:

| CX key type | JSON key |
|---|---|
| `string` | quoted as-is |
| `int` / `float` | numeric canonical form, quoted |
| `bool` | `"true"` / `"false"` |
| `date` / `datetime` | ISO 8601 string, quoted |
| `bytes` | base64 string, quoted |

This is **lossy** for round-trip: `{1: 'a'}` emits as `{"1": "a"}`
and parses back as `{"1": "a"}` (string key `"1"`, not int key
`1`). Callers requiring typed-key round-trip should use AST JSON
or CX-native serialization.

**Map key ordering on JSON emit.** Per
[`spec/canonical.md`](canonical.md) §D14 and §D14, Map
keys serialize in **lexicographic Unicode order** of their
canonical-string form on the JSON output side, regardless of
runtime insertion order. This makes JSON output content-hashable.

**Mixed content** (element has both text and child elements):

The text is captured under the key `"_"`. Child elements are emitted as their
named keys. If multiple text segments exist, they are concatenated.

**Multiple documents:**

A multi-document stream produces a JSON array, one object per document.

**What is lost** (semantic JSON is always lossy from CX):

- Comments (dropped)
- Processing instructions (dropped)
- Entity refs (resolved to their character equivalents for standard XML entities:
 `&amp;` → `&`, `&lt;` → `<`, `&gt;` → `>`, `&apos;` → `'`, `&quot;` → `"`;
 unrecognised entity refs emitted as `&name;`)
- Type annotations on elements (dropped; value type is inferred in the output)
- Anchors, merges, aliases (dropped)
- BlockContent structure (content inlined)
- Attribute type information (int and float both become JSON numbers; a consumer
 cannot distinguish `int` from `float` without the source)
- Element structure for pure-text elements (collapsed to string)

**AST JSON vs semantic JSON:**

`cx_to_ast` produces the **full parse tree** as JSON, including all node types,
type metadata, anchors, and aliases. It is used for tooling (debuggers, tree-sitter,
external processors). Language bindings use `cx_to_ast_bin` instead.

`cx_to_json` produces **data-oriented JSON** that erases CX structure. Use it
for data binding (`loads`/`dumps`-style) when the caller wants native types.

**Canonical example (v1.1):**

```cx
[server host=localhost port=8080 debug=false]
[tags [web, api]]
[metadata {region: us-west, replicas: 3}]
```

```json
{
 "server": {
 "host": "localhost",
 "port": 8080,
 "debug": false
 },
 "tags": ["web", "api"],
 "metadata": {
 "region": "us-west",
 "replicas": 3
 }
}
```

The pre-v0.6.0 form `[tags :string[] web api]` parses unchanged and
produces the same JSON output per §0.2 desugaring.

---

### 2.3 — CX → YAML

**Function:** `cx_to_yaml`

CX → YAML maps the document to a YAML mapping. The conversion is **lossy**.

**Conversion rules:**

| CX construct | YAML output |
|--------------|-------------|
| Element with attrs only | YAML mapping |
| Element with scalar body only | YAML scalar |
| Element with text body only | YAML string |
| Child elements | Nested YAML mappings |
| Multiple same-named children | YAML sequence |
| Array element (`:type[]`) | YAML sequence *(legacy; desugars to Array per §0.2)* |

**Collection-literal Items to YAML (v1.1, §D12):**

| CXDM Item | YAML output |
|---|---|
| Array `[a, b, c]` | Block sequence: `- a\n- b\n- c` |
| Map `{k: v, k2: v2}` | Block map: `k: v\nk2: v2` (keys lexicographically ordered) |
| Sequence (top-level or in body) | Block sequence (post-flatten) |
| Sequence-as-Item (inside Array / Map value) | Nested block sequence at the slot |
| Empty Array `[]` | YAML flow sequence `[]` |
| Empty Map `{}` | YAML flow map `{}` |
| Nested containers | YAML block-style nests via indentation |

**Sequence vs Array distinction.** YAML has only one list type. Both
CXDM Sequence and Array emit as YAML sequences. The CX → YAML →
CX round-trip **loses the Sequence/Array distinction**: parsing the
YAML produces an Array per §5.1 (default to structural-preservation).
Round-trip is lossless for nested Arrays-of-Arrays; lossy only at
the top-level Sequence-vs-Array discrimination.

**Non-string map keys.** YAML supports atomic scalar keys natively
(int, float, bool, date, datetime) when emitted in flow form or
block-implicit form. Non-string CX Map keys emit with their typed
YAML form:

```cx
[stats {servers: 12, errors: 0, uptime: 1980-01-01}]
```

```yaml
stats:
 errors: 0
 servers: 12
 uptime: 1980-01-01
```

(Map-key ordering follows canonical-form lexicographic order
regardless of insertion order — same rule as JSON; see §2.2.)

**What is lost:**

- Comments (dropped)
- Processing instructions (dropped)
- Entity refs (resolved)
- Anchors and merges (YAML has its own anchor/alias mechanism; CX anchors are dropped,
 not converted to YAML anchors)
- Type annotations (YAML auto-infers from value; collection-literal
 Array element-type annotation per §0.2 is informational and not
 encoded in YAML output)
- BlockContent (content inlined)
- Element names for children (they become YAML mapping keys; if multiple elements
 share the same name they become a sequence, but the element name itself is
 preserved as the key)
- Sequence-vs-Array distinction at the top-level value position
 (both map to YAML sequences; nested Arrays preserve)

---

### 2.4 — CX → TOML

**Function:** `cx_to_toml`

CX → TOML maps elements to TOML tables and attributes to TOML key-value pairs.
The conversion is **lossy**.

**Conversion rules:**

| CX construct | TOML output |
|--------------|-------------|
| Top-level element | TOML `[table]` |
| Element attrs | TOML key = value pairs |
| Nested element | Nested TOML `[parent.child]` table |
| Multiple same-named children | TOML `[[array of tables]]` |
| Scalar values | TOML integer, float, boolean, string, datetime as appropriate |

**Collection-literal Items to TOML (v1.1, §D12):**

| CXDM Item | TOML output |
|---|---|
| Array of scalars `[a, b, c]` | TOML inline array `[a, b, c]` |
| Array of objects/maps | TOML `[[array-of-tables]]` (under the enclosing key) |
| Array of mixed types | TOML inline array (mixed-type arrays valid since TOML 1.0) |
| Map (all scalar values, no nesting) | TOML inline table `{k = v, k2 = v2}` |
| Map (with nested table values) | TOML `[parent.key]` section |
| Sequence | inline array (post-flatten) |
| Sequence-as-Item inside an array | nested inline array `[[…], …]` |
| Empty Array `[]` | inline `[]` |
| Empty Map `{}` | inline `{}` |

**Awkward cases (TOML limitations):**

- **Maps with nested Array values**: TOML inline tables cannot
 contain newlines, and `[[arrays-of-tables]]` only work at the
 section level. A Map like `{name: 'svc', ports: [80, 443]}`
 emits as inline `{name = "svc", ports = [80, 443]}` if it fits;
 if too long for a one-line inline table, it promotes to a
 `[section]` form, which requires a key name from the enclosing
 scope. This means **anonymous nested Maps in Array positions
 may not round-trip cleanly through TOML** — they emit as inline
 tables and may exceed TOML inline-table size limits in practice.
 Documented limitation; callers should use JSON or YAML for such
 cases.
- **Heterogeneous arrays at the top level** are TOML-compatible
 (TOML 1.0+) but some legacy TOML readers reject them. CX always
 emits the v1.0 form.

**What is lost:**

- Comments (TOML has comments but CX comments are not mapped)
- Processing instructions (dropped)
- Entity refs (resolved)
- Anchors, merges, aliases (dropped)
- Text body content without attrs (no equivalent in TOML key-value model)
- Mixed content (text + elements) (text dropped when children present)
- BlockContent (dropped)
- Type annotations (TOML infers from value)
- Sequence-vs-Array distinction (both emit as TOML arrays; nested
 Array structure preserved)

**Constraint:** TOML cannot represent arbitrary nesting of elements with both
attributes and child text. Elements that mix attrs and text body produce TOML
tables where the body text is dropped.

---

### 2.5 — CX → Markdown

**Function:** `cx_to_md`

CX → Markdown maps CX element names to Markdown constructs based on a semantic
mapping of common element names. The conversion is **lossy**.

**Element name to Markdown mapping:**

| CX element name | Markdown output |
|-----------------|----------------|
| `h1` | `# text` |
| `h2` | `## text` |
| `h3` | `### text` |
| `h4` | `#### text` |
| `h5` | `##### text` |
| `h6` | `###### text` |
| `p` | paragraph (plain text + blank line) |
| `ul` | unordered list |
| `ol` | ordered list |
| `li` | list item (`- text`) |
| `pre`, `code` | fenced code block (` ``` `) |
| `em`, `i` | `*text*` |
| `strong`, `b` | `**text**` |
| `a` | `[text](href)` (uses `href` attr) |
| `img` | `![alt](src)` (uses `alt` and `src` attrs) |
| `blockquote` | `> text` |
| `hr` | `---` |
| other elements | omitted or rendered as plain text |

**Collection-literal Items to Markdown (v1.1, §D12):**

| CXDM Item | Markdown output |
|---|---|
| Array `[a, b, c]` | Bulleted list: `- a\n- b\n- c` |
| Map `{k: v}` | Definition list (GFM extension): `k\n: v\n` per entry |
| Sequence (top-level or in body) | Bulleted list (post-flatten) |
| Sequence-as-Item inside Array/Map | Nested bulleted list (indented) |
| Empty Array `[]` | (no output — empty list omitted) |
| Empty Map `{}` | (no output — empty list omitted) |

**Definition-list portability.** Definition lists are a GitHub-
Flavored-Markdown extension and not part of CommonMark. Markdown
consumers that don't recognize them render the output as plain
text with one paragraph per `k\n: v` block. CX → Markdown → CX
round-trip through a non-GFM Markdown processor loses the Map
structure.

**Nested-list indentation.** Markdown bulleted lists nest via
two-space (or four-space) indentation. CX Arrays of Arrays emit
as nested bulleted lists. Deeply nested CX collections may exceed
Markdown's practical indentation budget; documented limitation.

**What is lost:**

- Attributes (except `href` for `a`, `src`/`alt` for `img`)
- Comments
- Processing instructions
- Entity refs (resolved)
- Anchors, merges, aliases
- Type annotations
- Elements with no Markdown equivalent (rendered as their text content or dropped)
- Structural nesting beyond what Markdown supports
- Sequence-vs-Array distinction (both emit as Markdown lists)
- Map structure (definition lists only on GFM-aware consumers)

---

## 3 — XML as input

### 3.1 — XML → CX

**Function:** `cx_xml_to_cx`

XML → CX is the inverse of CX → XML. Round-tripping `cx_to_xml` → `xml_to_cx`
recovers the original CX document. Direct XML → CX (from non-CX-originated XML)
maps XML constructs to CX as follows:

**Conversion rules:**

| XML construct | CX output |
|---------------|-----------|
| XML element | CX Element |
| XML attribute | CX Attr |
| Namespace declaration `xmlns:prefix="uri"` | CX Attr `ns:prefix=uri` |
| Default namespace declaration `xmlns="uri"` | CX Attr `ns:default=uri` |
| Text content | TextNode |
| CDATA section | RawTextNode |
| Comment `<!-- ... -->` | CommentNode |
| Processing instruction `<?target data?>` | PINode |
| XML declaration `<?xml ...?>` | XMLDeclNode |
| DOCTYPE declaration | DoctypeDecl |
| Entity references `&name;` | EntityRefNode |
| `cx:anchor` attribute | Sets Element `anchor` field; attribute removed |
| `cx:merge` attribute | Sets Element `merge` field; attribute removed |
| `cx:type` attribute | Sets Element `data_type` field; attribute removed |
| `<cx:alias name="..."/>` element | AliasNode |
| `<cx:block>...</cx:block>` | BlockContentNode |

**CDATA → RawText:** CDATA sections become RawTextNode values. Adjacent CDATA
sections that were split by the CDATA split rule (see §2.1) are merged back into
a single RawTextNode.

**Namespace attributes:** XML namespace declarations are preserved as CX attrs
with the `ns:` prefix convention. This allows round-tripping namespace-aware XML
through CX without loss.

---

### 3.2 — XML → JSON

**Function:** `cx_xml_to_json`

XML → CX → semantic JSON. The same rules as CX → JSON (§2.2) apply, after the
XML is first parsed to a CX Document. What is lost is the union of losses in
XML → CX (none, since that is lossless) and CX → JSON (lossy; see §2.2).

In practice: namespace declarations, PIs, comments, and CDATA are all dropped.
Element attrs become JSON keys. Namespace URIs from `xmlns:` declarations are
dropped.

---

### 3.3 — XML → YAML

**Function:** `cx_xml_to_yaml`

XML → CX → YAML. Same rules as §2.3 after XML→CX parse.

---

### 3.4 — XML → TOML

**Function:** `cx_xml_to_toml`

XML → CX → TOML. Same rules as §2.4 after XML→CX parse.

---

### 3.5 — XML → Markdown

**Function:** `cx_xml_to_md`

XML → CX → Markdown. Same rules as §2.5 after XML→CX parse.

---

## 4 — JSON as input

### 4.1 — JSON → CX

**Function:** `cx_json_to_cx`

JSON → CX maps JSON values to CX elements and scalars. This is the **inverse** of
the semantic JSON emitter (§2.2).

**Conversion rules (v1.1):**

| JSON value | CX output |
|------------|-----------|
| Top-level JSON object | Document with one Element per top-level key |
| Nested JSON object | Element whose name is the enclosing key; each key becomes a child element or attr depending on depth (**when the parent context expects element structure**) — see "Element vs Map" below |
| JSON object as the value of a key | **CXDM Map Item** in the element body (collection-literal form, v1.1) when the object is data-shaped (no nested objects + keyed values are scalars or arrays) |
| JSON string value under a key | Element containing a TextNode or Attr value |
| JSON number (integer) | ScalarNode with `int` type |
| JSON number (floating-point) | ScalarNode with `float` type |
| JSON boolean | ScalarNode with `bool` type |
| JSON null | Empty Element (no attrs, no body) |
| JSON array (any contents, v1.1) | **CXDM Array Item** in the element body (collection-literal form) |
| JSON array of objects | CXDM Array of Map Items (collection-literal form) **OR** repeated child Elements (legacy form) depending on parse mode |

**Root element name:**

When the top-level JSON is an object, each key becomes a top-level Element in the
CX Document. There is no unnamed wrapper element. For a JSON object with a single
key, the document has a single root element with that name.

Example: `{"server": {"host": "localhost", "port": 8080}}` →
```cx
[server
 [host localhost]
 [port 8080]
]
```

The `host` and `port` values become child elements (since they were nested JSON
object values). If the JSON representation uses the `cx_to_json` convention of
placing scalar attrs as object keys at the same level, those round-trip correctly:

`{"server": {"host": "localhost", "port": 8080}}` →
```cx
[server
 [host localhost]
 [port 8080]
]
```

Note: JSON → CX does not reconstruct attribute-bearing elements from semantic JSON.
A JSON object `{"port": 8080}` under key `server` becomes a nested `[server [port 8080]]`
tree, not `[server port=8080]`. Full attribute reconstruction from semantic JSON would
require schema knowledge not available at conversion time.

**Arrays (v1.1, §D12):**

A JSON array maps to a CXDM Array Item in the parent element's
body — the new canonical form replaces the v1.0 `:type[]` shape:

```json
{"tags": ["web", "api"]}
```
```cx
[tags [web, api]]
```

The body of `[tags]` is a single Array Item containing two string
scalars. Array items preserve their JSON types via auto-typing per
[`spec/cxdm.md` §2.4](cxdm.md).

A JSON array of objects:
```json
{"services": [{"name": "auth"}, {"name": "api"}]}
```
```cx
[services [{name: 'auth'}, {name: 'api'}]]
```

The Array contains two Map Items. This is the **default v1.1 form**.

**Legacy parse mode (`json-to-cx-elements`).** A binding flag
`semantic-arrays-as-elements=true` (CLI: `--legacy-array-shape`)
restores the v1.0 shape: arrays of scalars produce `:type[]`
elements; arrays of objects produce repeated child elements. Off
by default at v0.6.0; provided for migration of consumers that
depend on the element-tree shape. Removed at v0.7.0+.

**Element vs Map disambiguation.** Both `[server [port 8080]]` and
`[server {port: 8080}]` are valid CX. JSON → CX produces the
**element-tree shape** for nested objects by default (preserves
v1.0 behavior). A binding flag `objects-as-maps=true` (CLI:
`--objects-as-maps`) switches to the Map shape:

| Mode | JSON `{"server": {"port": 8080}}` → CX |
|---|---|
| default | `[server [port 8080]]` (element-tree, v1.0-compatible) |
| `--objects-as-maps` | `[server {port: 8080}]` (Map Item in body) |

The Map-shape mode is useful for round-tripping JSON-originated
data where the object structure is semantically a string-keyed
record rather than a hierarchical document.

**JSON edge cases (v1.1, parse direction):**

| JSON form | CX output |
|---|---|
| `{"items": []}` | `[items []]` (empty Array Item) |
| `{"items": {}}` | `[items {}]` (empty Map Item, `--objects-as-maps` mode) or `[items]` (default; element-tree of empty map = empty element) |
| `{"items": null}` | `[items]` (empty element) |
| missing key | element absent from output |
| `{"_": "text", "k": "v"}` | element with text body `text` and child element `[k v]` (mixed-content mode per §2.2) |

**What is lossless:** JSON scalars, strings, booleans, null, and numbers
round-trip correctly. JSON arrays round-trip via collection-literal
Array Items (v1.1) or `:type[]` element trees (legacy mode).

**What is added:** Element structure that was not in the source JSON (CX always
requires named elements; JSON values are wrapped under their key as a
CX Element name).

---

### 4.2 — JSON → XML

**Function:** `cx_json_to_xml`

JSON → CX → XML. Applies §4.1 then §2.1 (XML round-trip emitter).

---

### 4.3 — JSON → YAML

**Function:** `cx_json_to_yaml`

JSON → CX → YAML. Applies §4.1 then §2.3.

---

### 4.4 — JSON → TOML

**Function:** `cx_json_to_toml`

JSON → CX → TOML. Applies §4.1 then §2.4.

---

### 4.5 — JSON → Markdown

**Function:** `cx_json_to_md`

JSON → CX → Markdown. Applies §4.1 then §2.5. Generally not meaningful unless
the JSON models a document structure with semantic element names.

---

## 5 — YAML as input

### 5.1 — YAML → CX

**Function:** `cx_yaml_to_cx`

YAML → CX maps YAML structures to CX elements, attrs, and scalars.

**Conversion rules:**

| YAML construct | CX output |
|----------------|-----------|
| YAML mapping (data-shaped value) | **CXDM Map Item** (v1.1) in element body |
| YAML mapping (document-shaped) | Element with child elements per key (legacy / `--legacy-shape`) |
| YAML scalar string | TextNode or ScalarNode depending on auto-typing |
| YAML integer | ScalarNode with `int` type |
| YAML float | ScalarNode with `float` type |
| YAML boolean (`true`/`false`) | ScalarNode with `bool` type |
| YAML null (`~`, `null`) | ScalarNode with `null` type |
| YAML date / datetime | ScalarNode with `date` / `datetime` type |
| YAML sequence (v1.1) | **CXDM Array Item** in element body |
| YAML sequence (legacy) | Repeated same-named child elements (`--legacy-shape`) |
| YAML anchor (`&name`) | Not encoded in CX (YAML anchors are resolved before CX output) |
| YAML alias (`*name`) | Resolved before CX output (inline expansion) |
| YAML comments | Dropped |
| YAML multi-document (`---`) | CX multi-document stream |

**Mode flag (v1.1).** YAML → CX defaults to the **v1.1 collection-
literal shape**: YAML sequences → CXDM Array Items; YAML maps →
CXDM Map Items when context-appropriate (terminal-position values
without further nesting heuristics). The `--legacy-shape` flag
restores the v1.0 element-tree behavior for callers depending on
it. Removed at v0.7.0+.

**Non-string YAML keys.** YAML's full key-type generality (int,
float, bool, date) maps directly onto CXDM Map keys per
[`spec/cxdm.md` §2.5](cxdm.md). Round-trip CX → YAML → CX
preserves typed keys when both sides operate in v1.1 mode.

**Note:** YAML anchors and aliases are resolved (expanded) during parsing. The
resulting CX does not contain CX anchors, merges, or aliases. A YAML → CX → YAML
round-trip recovers the data but not the YAML anchor/alias structure.

---

### 5.2 — YAML → XML, JSON, TOML, Markdown

**Functions:** `cx_yaml_to_xml`, `cx_yaml_to_json`, `cx_yaml_to_toml`, `cx_yaml_to_md`

All apply §5.1 (YAML → CX) then the appropriate CX → target conversion.

---

## 6 — TOML as input

### 6.1 — TOML → CX

**Function:** `cx_toml_to_cx`

TOML → CX maps TOML tables to CX elements and TOML key-value pairs to CX attrs
and child elements.

**Conversion rules:**

| TOML construct | CX output |
|----------------|-----------|
| Top-level key = scalar | Child element of document root |
| `[table]` | CX Element |
| `[[array of tables]]` | Repeated same-named CX Elements (legacy) or CXDM Array of Map Items (v1.1 collection-literal mode) |
| TOML integer | ScalarNode with `int` type |
| TOML float | ScalarNode with `float` type |
| TOML boolean | ScalarNode with `bool` type |
| TOML string | TextNode or ScalarNode |
| TOML datetime | ScalarNode with `datetime` type |
| TOML date | ScalarNode with `date` type |
| TOML inline array (v1.1) | **CXDM Array Item** in element body |
| TOML inline array (legacy) | Element with `:type[]` annotation when homogeneous (`--legacy-shape`) |
| TOML inline table (v1.1) | **CXDM Map Item** in element body |
| TOML inline table (legacy) | Nested Element (`--legacy-shape`) |
| TOML comments | Dropped |

**Mode flag.** Same `--legacy-shape` flag as §5.1 applies to TOML →
CX. v1.1 default emits collection literals; legacy emits element
trees with `:type[]` annotations.

---

### 6.2 — TOML → XML, JSON, YAML, Markdown

**Functions:** `cx_toml_to_xml`, `cx_toml_to_json`, `cx_toml_to_yaml`, `cx_toml_to_md`

All apply §6.1 (TOML → CX) then the appropriate CX → target conversion.

---

## 7 — Markdown as input

### 7.1 — Markdown → CX

**Function:** `cx_md_to_cx`

Markdown → CX maps Markdown block and inline constructs to CX elements.

**Conversion rules:**

| Markdown construct | CX output |
|-------------------|-----------|
| `# Heading` | `[h1 Heading]` |
| `## Heading` | `[h2 Heading]` |
| `### Heading` to `######` | `[h3]` … `[h6]` |
| Paragraph | `[p text]` |
| `- item` or `* item` | `[ul [li item]]` |
| `1. item` | `[ol [li item]]` |
| `> quote` | `[blockquote text]` |
| ` ```lang\ncode\n``` ` | `[pre [code text]]` (with optional `lang` attr) |
| `` `inline code` `` | `[code text]` |
| `**bold**` or `__bold__` | `[strong text]` |
| `*italic*` or `_italic_` | `[em text]` |
| `[text](url)` | `[a href=url text]` |
| `![alt](src)` | `[img src=src alt=alt]` |
| `---` or `***` | `[hr]` |
| HTML inline tags | Passed through as-is (not parsed) |
| YAML frontmatter (`---...\n---`) | `[-meta ...]` element with YAML keys as attrs |

**Multi-document:** Markdown documents separated by `---` on its own line produce
a CX multi-document stream.

**What is lost:**

- Markdown table structure (not yet supported; tables become text)
- Inline HTML (passed through as text, not parsed into CX elements)
- Markdown-specific formatting details (exact blank line counts, list nesting
 beyond two levels)

---

### 7.2 — Markdown → XML, JSON, YAML, TOML

**Functions:** `cx_md_to_xml`, `cx_md_to_json`, `cx_md_to_yaml`, `cx_md_to_toml`

All apply §7.1 (Markdown → CX) then the appropriate CX → target conversion.

---

## 8 — Delimited (CSV / TSV / PSV / arbitrary single-char)

CSV and its delimiter variants are tabular text formats with no type
system or hierarchy. CX integrates with them via dedicated convertor
functions; the design is recorded in

, which this section implements.

The conversion is **well-defined and reasonable, not lossless**.
Delimited fields are inherently string-typed; type metadata cannot
be carried in-band without breaking plain-CSV consumers (Excel,
pandas, BigQuery, etc.). Lossy properties are enumerated in §8.5.

### 8.1 — CX → delimited (emit)

**C ABI:** `cx_to_delimited(input, delim, err_out)` plus the named
aliases `cx_to_csv`, `cx_to_tsv`, `cx_to_psv` and the data-bin
companions `cx_csv_to_data_bin` / `cx_tsv_to_data_bin` /
`cx_psv_to_data_bin` (§8.6).

**Delimiters (D6).** Any single byte except `\r`, `\n`, `"`, `'`, or
`\\`. The convenience names CSV, TSV, PSV map to `,`, `\t`, `|`.

**Shape detection (D2).** Input shape is auto-detected:

| input shape | flattening |
|-------------|------------|
| `:table` block | declared columns drive output directly |
| `<root>` containing 2+ same-named child siblings | repeated-row mode |
| `<root>` with one-of-each child elements | dotted-path mode (single row) |
| mixed (some repeated + some unique siblings) | **error** in v0 |

**Repeated-row mode.** Each repeated sibling becomes a row; columns
are the union of the siblings' attribute names in first-occurrence
order.

```cx
[users
 [user id=1 name=alice +admin]
 [user id=2 name=bob]
 [user id=3 name=carol +admin]
]
```

```csv
id,name,admin
1,alice,true
2,bob,
3,carol,true
```

**Dotted-path mode.** Each leaf attribute becomes a column at
`<child>.<...>.<attr>`. The root element name is not in the path.
Output is one row.

```cx
[config
 [server host=localhost port=8080 +tls]
 [logging level=info format=json]
]
```

```csv
server.host,server.port,server.tls,logging.level,logging.format
localhost,8080,true,info,json
```

**Default emit conventions (D3):**

| property | default | configurable via |
|----------|---------|------------------|
| field separator | comma (or whichever single byte was passed) | `delim` argument |
| quote style | RFC 4180 double-quote with `""` doubling | `EmitOptions.quote_style` |
| quoting trigger | field contains delim, `"`, `\r`, or `\n` | (always conservative) |
| line terminator | `\r\n` (RFC 4180) | `EmitOptions.line_ending` |
| BOM | never emitted | (not configurable) |

This default makes CX-emitted files consumable by Excel, pandas,
BigQuery, and every RFC-4180-respecting tool without configuration.

### 8.2 — Delimited → CX (parse)

**C ABI:** `cx_from_delimited(input, delim, err_out)` plus the named
aliases `cx_from_csv`, `cx_from_tsv`, `cx_from_psv` and the data-bin
companions `cx_data_bin_to_csv` / `cx_data_bin_to_tsv` /
`cx_data_bin_to_psv` (§8.6).

The first row is parsed as the header. Subsequent rows are data. The
result is a CX `Document` containing one `:table`-shaped Element
named `table` (override via the binding-side `table_name` parse
option). Auto-typing (D5) infers per-column types where it can.

**Quote-style accept-set (D4).** Each field may be:

| leading char | rule |
|--------------|------|
| `"` | RFC 4180 double-quote with `""` doubling |
| `'` | single-quote with `''` doubling |
| anything else | bare — runs to next delimiter or row terminator |

**Escape sequences honored in any context (D4).** Six universal
escapes in both quoted and bare fields:

| escape | meaning |
|--------|---------|
| `\\\\` | backslash |
| `\\n` | newline |
| `\\t` | tab |
| `\\r` | carriage return |
| `\\"` | double quote |
| `\\'` | single quote |

Any other `\\X` sequence is a parse error — be liberal in what is
accepted, strict in what an error means.

**Type recovery (D5).** Precedence:

1. Caller-supplied schema (CLI `--schema='name:string age:int
 active:bool'` or binding parameter). Highest priority; auto-typing
 skipped on covered columns. *(Schema integration tracks ;
 v0 of this spec covers the auto-typing path only.)*
2. Auto-typing per `spec/grammar.ebnf §25`. A field that matches the
 integer / float / bool / null / date / datetime patterns is parsed
 as that type; else it remains a string. Identical to the auto-
 typing CX itself does for unquoted element-body tokens.
3. String fallback for anything not covered by schema and not
 auto-typed.

**Quoted fields are forced to `:string`** regardless of pattern —
quoting is the explicit "this is a string" signal.

**Column type narrowing.** When every value in a column auto-types
to the same scalar type (with `null` not constraining the type), the
emitted `:table` header annotates that column with the inferred
type. Mixed columns stay untyped (`:string` default).

**Empty cell.** An unquoted empty cell parses as the null literal
`null`. A quoted empty cell (`""` or `''`) is the empty string.

**Example:**

```csv
name,age,active
alice,30,true
bob,,false
```

```cx
[table :table[name age:int active:bool]
 alice 30 true
 bob null false
]
```

### 8.3 — Empty input

An empty document emits an empty string. An empty input to
`cx_from_delimited` returns a parse error ("empty input"); a header
row with zero data rows is valid and produces a `:table` block with
no rows.

### 8.4 — Comments / anchors / mixed shapes

The lossy-properties table (D7, extended in v1.1 with cell-collection rule):

| CX construct | delimited treatment |
|--------------|---------------------|
| Comments (line + block) | stripped |
| Anchors / aliases / merges | resolved at conversion time |
| Multi-document (`---`) | first document only; subsequent error |
| Mixed content (text + child elements in body) | not representable; error |
| Processing instructions | stripped |
| Raw-text blocks (`[# ... #]`) | content emitted as a string field, with delimiters/newlines escaped |
| Sized integer / decimal / bigint types | numeric form per `spec/canonical.md`; type metadata lost |
| Array cell `[a, b, c]` *(v1.1)* | emitted as a **JSON-encoded string field** (quoted): `"[\"a\",\"b\",\"c\"]"` — type metadata lost; round-trip via schema |
| Map cell `{k: v}` *(v1.1)* | emitted as a **JSON-encoded string field** (quoted): `"{\"k\":\"v\"}"` — keys coerced to strings per §2.2 rule |
| Sequence cell (top-level position) | **error** — delimited cells are scalars or container-as-JSON-string only |
| Nested collection (Array of Maps, etc.) *(v1.1)* | recursive JSON encoding inside the string field |

**Why JSON-encoded strings for collection cells.** Delimited
formats (CSV / TSV / PSV) are inherently flat. CX collections
in cells need a portable in-band representation; JSON is the
universal escape hatch that every downstream tool (pandas,
Excel via Power Query, BigQuery via `JSON_EXTRACT`) can decode.
The cell remains a string from the CSV consumer's perspective;
collection-aware consumers can parse the JSON.

**Parse direction.** A cell whose value parses as valid JSON
**does not** auto-promote to an Array or Map on `cx_from_delimited`
by default — JSON-shaped strings remain strings (the consumer
can't disambiguate JSON-encoded data from accidentally-JSON-shaped
text). The caller-supplied schema (per D5 type recovery) is the
opt-in: a column typed `arr[T]` or `map[K, V]` triggers JSON
decoding on parse.

### 8.5 — Lossiness

Per: the round-trip CX → delimited → CX is **not
lossless**:

- Type metadata is lost on emit (delimited fields are strings).
 Recovery on parse is via schema or auto-typing.
- Hierarchy depth beyond what flattening recovers is lost.
- CX-only constructs are stripped: comments, anchors / aliases /
 merges, multi-document separators, mixed content, processing
 instructions, raw-text blocks.
- Element names (`<root>`, repeated-sibling tag) are lost on parse

Delimited → CX → delimited is lossless within the parsed-shape's
expressive range when the original is well-formed and the schema
matches. Auto-typing introduces a documented inference step that
may diverge from the original producer's intent (use a schema flag
for deterministic typing).

### 8.6 — One-shot loaders / dumpers

The C ABI (`spec/abi.md` §2.4–§2.5) exposes one-shot symbols that
combine delimited ↔ data_bin in a single call:

```
cx_csv_to_data_bin(input, err_out) → data_bin
cx_tsv_to_data_bin(input, err_out) → data_bin
cx_psv_to_data_bin(input, err_out) → data_bin

cx_data_bin_to_csv(data_bin, err_out) → CSV text
cx_data_bin_to_tsv(data_bin, err_out) → TSV text
cx_data_bin_to_psv(data_bin, err_out) → PSV text
```

These match the bindings' `loads_csv` / `dumps_csv` API surfaces.
Arbitrary-delimiter callers compose `cx_to_delimited` /
`cx_from_delimited` with `cx_to_data_bin` / `cx_from_data_bin`.

---

## 9 — Lossiness summary

| From \ To | CX | XML | JSON | YAML | TOML | MD | CSV† |
|-----------|------------|--------------|--------------|--------------|--------------|--------------|------------|
| **CX** | lossless | lossless‡ | lossy◊ | lossy◊ | lossy◊ | lossy◊ | lossy§ |
| **XML** | lossless | lossless | lossy◊ | lossy◊ | lossy◊ | lossy | lossy§ |
| **JSON** | adds struct| adds struct | lossless¶ | lossless¶ | lossless¶ | lossy | lossy§ |
| **YAML** | lossy* | lossy* | lossless¶ | lossless¶ | lossless¶ | lossy | lossy§ |
| **TOML** | lossless** | lossless** | lossless¶ | lossless¶ | lossless¶ | lossy | lossy§ |
| **MD** | lossy | lossy | lossy | lossy | lossy | lossless | lossy§ |
| **CSV** | lossy§ | lossy§ | lossy§ | lossy§ | lossy§ | lossy§ | lossless |

‡ cx→xml is lossless when consumers preserve the `cx:` namespace attributes.
 Consumers that strip `cx:` attributes lose CX-specific metadata.

¶ lossless within the expressive range of that format.

† CSV column abbreviated for table width; full rules in §8.

§ Delimited (CSV/TSV/PSV/arbitrary single-char) is well-defined and
 reasonable, not lossless. Per / §8.5: type metadata is lost
 on emit; comments, anchors, multi-document, mixed content, and PIs
 are stripped or error; element names are lost on parse. Auto-typing
 recovers `:int` / `:float` / `:bool` / etc. patterns where possible
 (D5); use a caller-supplied schema for deterministic typing. Mixed
 shapes (some repeated + some unique siblings under one root) error
 in v0. CSV → CX → other-format is well-defined but inherits all the
 CSV-side losses.

\* YAML anchors and aliases are resolved (expanded) on parse; not reconstructed
 in CX output. Data content is preserved.

** TOML has no mixed content or comments, so the CX output contains only what
 TOML can express; no loss within TOML's range.

◊ *(v1.1)* CX → JSON / YAML / TOML / MD with CXDM v1.1 container Items
 (Array, Map, Sequence-as-Item): non-string Map keys
 are coerced to strings on JSON emit (lossy); Sequence-vs-Array
 distinction is preserved on JSON output (both have native JSON
 forms) but lost on YAML / TOML / MD output (none distinguish flat
 sequences from nested arrays). XML round-trip is lossless when
 consumers preserve the `cx:arr` / `cx:map` / `cx:seq` wrapper
 elements per §2.1.
