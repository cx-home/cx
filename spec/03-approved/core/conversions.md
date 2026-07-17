# CX Format Conversion Semantics

**Status:** Current.

This document specifies the semantics of all conversion paths between the 5
supported formats: CX, XML, JSON, YAML, and TOML. Self-to-self paths
are covered in §1 (normalization). The cross-format paths are specified in §2
through §6.

> **Markdown is a codec, not a CX format (ruling D-B, refined).** CX has **no
> markdown syntax** — the parser has zero markdown awareness, and markdown is
> carried as opaque payload inside a `[#…#]` raw-text node. The markdown sigils
> (`[** ]`/`[# ]`/`` [`] ``/`[> ]`) remain removed. What exists is a CX↔Markdown
> **codec** — a `bytes ⇄ CX tree` converter on equal footing with the json/csv/
> xml codecs (`cx --md`, `cx --from=md`, `[$markdown:parse]`/`[$markdown:emit]`).
> Because markdown is prose, not structured data, the codec is best-effort/lossy
> (data-shaped elements flatten to inline text) and is **not** one of the five
> lossless data formats this document specifies. See `codec.md` for the codec
> contract and `codec_architecture.md` for the model.

---

## Conventions

**Lossless** — a round-trip through the target format and back to CX recovers the
original CX document with identical content and structure.

**Lossy** — some information in the source is not representable in the target format.
When this document says a conversion is lossy, it names the specific information lost.
A binding MUST NOT silently discard information that could be encoded; it drops only
what the target format cannot represent.

**Secret values** (`cxdm.md` §12) are redacted to `'‹redacted›'` at every
conversion boundary unless declassified (`[?reveal]`, gated by `secret-reveal`).
This redaction is **lossy by design** — the information dropped is the secret's
value (its type and presence are retained) — and intentionally overrides the
lossless guarantee for those values.

**Error** — the source document contains features that are not only non-representable
in the target but cause the conversion to fail. All format errors are communicated
via the calling convention's error mechanism (see `../misc/parity-matrix.md`).

---

## 0 — Collection literals across formats

Per
[`cxdm.md` §2.5–§2.7](cxdm.md), CXDM introduces
three container Item kinds — **Array** `[a, b, c]`, **Map** `{k: v}`,
and **Sequence-as-Item** (a Sequence boxed into a single Item position).
Each format has a canonical emit rule and a parse rule covered in
the following sections; this section gives the cross-format
overview.

### 0.1 Per-format collection-literal correspondence

| Format | Array `[a, b, c]` | Map `{k: v}` | Sequence (top-level) | Sequence-as-Item |
|---|---|---|---|---|
| CX (canonical) | `[a, b, c]` | `{k: v}` keys sorted | `(a, b, c)` | `(a, b, c)` preserved inside Array/Map position |
| XML | `<cx:arr><cx:item>a</cx:item>…</cx:arr>` | `<cx:map><cx:entry cx:key="k">v</cx:entry>…</cx:map>` | `<cx:seq><cx:item>a</cx:item>…</cx:seq>` | `<cx:seq>…</cx:seq>` inline at the item position |
| JSON | `[a, b, c]` (JSON array) | `{"k": v}` (JSON object) | `[a, b, c]` (sequence flattens first) | `[a, b, c]` (boxed Sequence emits as nested JSON array) |
| YAML | block sequence `- item` | block map `k: v` | block sequence (after flatten) | block sequence at the item position |
| TOML | inline `[a, b, c]` | inline `{k = v}` or `[k]` section | inline `[a, b, c]` (post-flatten) | inline array at the container position |
| MD | bulleted list | definition list (`k\n: v`) | bulleted list (post-flatten) | bulleted list at the container position |

Format-specific rules — escaping, empty-value handling, nested
container behavior, round-trip fidelity — are normative in the
respective §2.x section. JSON / XML round-trip is **lossless for
Arrays / Maps** but **lossy for Sequence vs Array** at the JSON
boundary (a JSON array of arrays round-trips as a CX array of
arrays, not a sequence of arrays). YAML / TOML inherit
JSON-like behavior since none of these formats distinguish flat
sequences from nested arrays at the syntactic level.

The wrapping element names `cx:arr`, `cx:map`, `cx:seq` are
**reserved**; a source document that uses one of these `cx:`-prefixed
names for non-collection content is a conversion warning (the `cx:`
namespace is reserved). The names align with the file-wide `cx:`
namespace convention (per §2.1).

### 0.2 Type handling across formats

CX values carry types from the closed kind set in `cxdm.md §2.3`
(9 semantic kinds) plus storage-precision refinements in
`grammar.ebnf [26a]` (14 additional: `decimal`, `bigint`, sized
`i8..i64` / `u8..u64`, `f16/f32/f64`, `duration`, `instant`). The 6
target formats vary
widely in their native type expressiveness. The matrix below
defines, per-type per-format, three behaviors:

- **Default** (lossy idiomatic): how the value emits when the caller
  asks for clean, idiomatic output. Type metadata may be lost.
- **Lossless** (opt-in via `--lossless` flag / `lossless=true` API
  parameter): how the value emits to enable byte-identical CX→fmt→CX
  recovery — "byte-identical" meaning the recovered document's
  **strict-canonical** form (`canonical.md`, the `cx eq` relation)
  equals the original's. May use format-native extensions, sidecar
  metadata, or — for element documents on the JSON / YAML lanes — the
  `$tag` structure envelope (§2.2.1 / §2.3.1). The recovery domain is
  the **document/data model**: program directives (`[?…]` forms) are
  outside every conversion lane's lossless domain (they are dropped on
  emit, on the XML lane too); programs interchange as CX text or
  `ast`-bin.
- **Schema-aware** (preferred for production): if the consumer
  reconstructs CX with a `.cxs` schema present, the type is
  recovered from the schema; no wire-format metadata is needed.

| CX type | JSON default | JSON lossless | YAML default | YAML lossless | TOML default | XML default | XML lossless | MD |
|---|---|---|---|---|---|---|---|---|
| `bool` | JSON bool | (same) | YAML bool | (same) | TOML bool | text | `cx:type="bool"` | text |
| `int` | JSON number | (same) | YAML int | (same) | TOML int | text | `cx:type="int"` | text |
| `float` | JSON number | (same) | YAML float | (same) | TOML float | text | `cx:type="float"` | text |
| `string` | JSON string | (same) | YAML string | (same) | TOML string | text | (default) | text |
| `null` | JSON `null` | (same) | YAML `null` | (same) | omitted | empty element | (same) | (lossy) |
| `date` | string | + `cx:type` sidecar | YAML date | (same — native) | TOML date | text | `cx:type="date"` | text |
| `datetime` | string | + `cx:type` sidecar | YAML datetime | (same — native) | TOML datetime | text | `cx:type="datetime"` | text |
| `bytes` | string (base64) | + `cx:type` sidecar | string with `!!binary` tag | (same) | string (base64) | text | `cx:type="bytes"` | text (base64) |
| `atom` | string `":NAME"` | + `cx:type` sidecar | string with `!!cx:atom` tag | (same) | string | text | `cx:type="atom"` | text |
| `decimal` | string | + `cx:type` sidecar | string with `!!cx:decimal` tag | (same) | string | text | `cx:type="decimal"` | text |
| `bigint` | string | + `cx:type` sidecar | string with `!!cx:bigint` tag | (same) | string | text | `cx:type="bigint"` | text |
| sized `i8..i64` / `u8..u64` | JSON number | + `cx:type` sidecar (sized name preserved) | YAML int | + `!!cx:i32` etc. | TOML int | text | `cx:type="i32"` etc. | text |
| sized `f16/f32/f64` | JSON number | + `cx:type` sidecar | YAML float | + `!!cx:f32` etc. | TOML float | text | `cx:type="f32"` etc. | text |

**JSON `cx:type` sidecar protocol (lossless mode).** When `lossless=true`,
typed values whose JSON representation loses type metadata emit
alongside a sibling `cx:type` object that maps field-name → CX type
name. Example:

```json
{
  "score": "3.14",
  "id": "99999999999999999999",
  "status": ":ok",
  "cx:type": {"score": "decimal", "id": "bigint", "status": "atom"}
}
```

CX import reads the `cx:type` sidecar (unconditionally — `cx:` is
CX's reserved protocol namespace at every conversion boundary) and
reconstructs typed scalars; clients that don't know the convention
treat the values as plain strings and the `cx:type` object as
metadata.

**JSON per-item carrier (array positions, lossless mode).** The
sidecar keys by field name, so it cannot cover typed values in JSON
**array** positions. In lossless mode a typed scalar at an array /
sequence-item position instead emits as a reserved single-key carrier
object — `{"cx:T": payload}`, the JSON image of the XML `<cx:T>`
per-item carrier:

```json
["a", {"cx:decimal": "3.14"}, {"cx:duration": "1h30m"}, {"cx:u16": 8080}]
```

Payloads use the same per-type images as the sidecar protocol: sized
numerics ride their native JSON number; `bytes` rides base64; `atom`
rides the bare name (the carrier key names the type, so no `:` prefix);
every other kind rides its verbatim canonical text. Import consumes the
carrier unconditionally (reserved `cx:` shape) and reconstructs the
typed scalar. Together the sidecar (map positions) and the per-item
carrier (array positions) make typed values position-independent on the
lossless JSON lane. YAML needs no carrier: `!!cx:T` tags are
position-independent natively.

**Non-string map keys (`cx:key-type`, lossless mode).** JSON object
keys are strings, so a CX Map with non-string keys (int / float / bool
/ date / datetime / bytes, `cxdm.md` §2.6) is key-lossy by default
(§2.2). In lossless mode the object additionally carries a reserved
`cx:key-type` sidecar — serialized-key → key-type-name for exactly the
non-string keys — and import re-types those entry keys. The same
object rides the YAML lossless lane (one envelope, two renderings).

**`#485` ruling — typed collection values and the CX text lane.** The
lossless carrier lanes (XML `<cx:T>` / JSON sidecar + per-item carrier
/ YAML tags) are the designated round-trip spelling for `decimal` /
`bytes` / sized-numeric values in Map-value and Array-item positions.
CX **text** deliberately defines no additional spelling for them: the
canonical text image of such a value stays the bare payload
(`{score: 3.14}`) and re-imports per its lexical shape — the
typed-lossy contract the `conv-006` conformance case pins. Producers
needing those types to survive a **text** round-trip route through a
carrier lane or `data-bin`.

**YAML native tags (lossless mode).** YAML's tag system natively
supports the lossless case via `!!cx:T` tags (e.g.,
`score: !!cx:decimal "3.14"`). YAML readers that don't know the
tag preserve it verbatim; readers that do reconstruct the typed
scalar.

**TOML and MD have no extension protocol.** TOML's grammar admits no
tag syntax; MD has no type system. Lossless mode for these formats
is **not supported**; the default lossy emit is the only mode.
Producers needing roundtrip stability through TOML/MD must round
through CX or XML instead.

**Flag surface (fail-loud).** A lossless request (`--lossless` /
`lossless=true`) against a target whose emitter does not honor it
MUST be rejected with an error — never accepted as a silent no-op.
The lossless-capable targets are `cx` (inherently lossless), `xml`
(`cx:` carriers, §2.1), `json` (`cx:type` sidecar + per-item carrier
+ the `$tag` structure envelope, §2.2.1) and `yaml` (`!!cx:T` tags +
the same envelope, §2.3.1); TOML and MD are rejected per the
no-extension-protocol rule above.

**XML lossless per-value carrier (`<cx:T>`).** The `cx:type="T"` form in the
table above is the image of an element-level *annotation* (`[x::int 1]` →
`<x cx:type="int">1</x>`, §2.1). An *auto-typed* scalar body (`[x 1]`, no
annotation) instead carries its type as a per-value `<cx:T>` child carrier in
lossless mode — `[x 1]` → `<x><cx:int>1</cx:int></x>`, `[x :ok]` →
`<x><cx:atom>ok</cx:atom></x>` — because an element attribute would re-read as an
annotation and change the node shape, whereas the carrier round-trips the body
verbatim. This is the same per-item carrier used for a typed list (`[x 1 2]` →
`<x><cx:int>1</cx:int><cx:int>2</cx:int></x>`, default + lossless). In lossless
mode adjacent STRING items also take a `<cx:string>` carrier so they keep their
boundary (`[x "a" "b"]` → `<x><cx:string>a</cx:string><cx:string>b</cx:string></x>`);
the idiomatic form collapses them to `<x>ab</x>`. A SINGLE string body stays bare
in both modes (it re-infers as a string).

**Schema-aware roundtrip (preferred for production).** When a `.cxs`
schema is available at decode time (per `schema.md`), JSON / YAML /
TOML / MD producers emit clean idiomatic output (no `cx:type`
sidecar, no native tags), and the importer reconstructs CX types
from the schema. Example: a target document `{"port": 8080}` parses
to CX `[port::u16 8080]` when the schema declares
`[attr port::u16]`. This is the recommended pattern for production
systems exchanging CX-shaped data through other formats.

### 0.3 Streaming-write impact

`streaming.md` defines the event-stream interface for incremental
output emission. Collection literals **decompose into existing event
types** at the streaming layer; no new event types are required.
Arrays and Maps emit as start-container / contents / end-container
sequences using the same event vocabulary that already handles
Elements. Sequence-as-Item emits as a nested collection
event-sequence at the item position.

### 0.4 CX source-file encoding policy

The byte-level encoding contract for `.cx`, `.cxs`, and every other
CX source file the parser ingests. The policy is normative for every
binding's `loads` / `parse` / `from_*` surface, the CLI, and the
streaming-read API; emit-side rules cite back to
`canonical.md §2.2`.

**Encoding.** Source files MUST be valid UTF-8. Invalid UTF-8 in
any input is a parse error (`cx-err:CXER0100 PARSE_ERROR`, consistent
with `abi.md §1.7`). UTF-16 and UTF-32 are not accepted; a leading
UTF-16 BOM (`FE FF` / `FF FE`) or UTF-32 BOM (`00 00 FE FF` /
`FF FE 00 00`) MUST be rejected as a parse error because the rest
of the byte stream is not UTF-8.

**Byte-order mark.** A UTF-8 BOM (`EF BB BF`) at the very start of
a file is **tolerated on parse** — the parser consumes and discards
the three bytes silently before scanning the first token. A BOM
appearing anywhere other than file start MUST be rejected as a parse
error (`abi.md §1.7`; `code.md §3.1`). The canonical emit surface
**never writes a UTF-8 BOM** under any mode; downstream tooling that
wants one prepends it after `cx fmt` / `cx canonical`.

**Line endings.** All of LF (`\n`, `U+000A`), CRLF (`\r\n`,
`U+000D U+000A`), and bare CR (`\r`, `U+000D`) are tolerated on parse
as line terminators. Mixed line endings within a single file are
tolerated (the parser does not require consistency).

**Canonical emit normalises line endings to LF.** Per
`canonical.md §2.2`, lossless canonical preserves source line
endings inside preserved blocks but every newline the emitter
**generates** is an LF; strict canonical normalises every line
ending in the output to LF regardless of source. `cx fmt` and
`cx canonical` therefore produce LF-only output.

**Final newline.** Parse accepts files with or without a trailing
newline. Canonical emit produces exactly one trailing LF
(`canonical.md §2.2`, "Trailing newline at file end").

**Delimited-format emit (CSV / TSV / PSV).** The `cx_from_*`
delimited family follows RFC 4180 and emits `\r\n` line terminators
by default (configurable per `§8.1`); this is the format-specific
emit rule for delimited output and is distinct from the source-file
policy above.

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

**Serialization idempotency (string-scalar bijection).** `cx_to_cx` is
*idempotent on values*: for any CX source `s`, `parse(emit(parse(s))) ≡
parse(s)`, and the canonical text is a fixed point (`emit` after the first pass
reproduces it byte-for-byte). This holds regardless of how many text stages a
pipeline interposes (e.g. render-to-text → re-parse → emit), so a multi-stage
path can never silently mutate a value. The non-obvious case is a string scalar
whose bytes contain a backslash — including one read from a *verbatim*
triple-quoted literal (`"""a\"b"""`, whose value is the four bytes `a \ " b`,
since triple-quoted content is raw per `canonical.md` §2.10.1). The canonical
single-/double-quoted serialization re-escapes that backslash minimally
(`canonical.md` §2.4) — here to `'a\\"b'` — so the re-parse recovers the same
four bytes rather than decoding `\"` back to a bare `"`. Verbatim
pass-through backslashes (regex `'\d+'`, `'\.'`) are left undoubled and are
themselves fixed points. Emitters MUST satisfy this invariant on every text
boundary.

---

## 1.1 — ID / IDREF references across formats

CX's syntactic ID/IDREF mechanism (per `cxdm.md §4`) carries through
the cross-format conversion matrix as follows:

| Format | ID declaration | IDREF reference |
|---|---|---|
| CX | `[el #id-1 …]` (grammar [51a] IdDecl) | `attr=@id-1` (per `cxdm.md §4.2`) |
| XML | `<el xml:id="id-1" …>` | `attr="id-1"` with XSD-typed IDREF attribute |
| JSON / YAML / TOML / MD (semantic emit) | `{"id": "id-1", …}` — ID becomes an ordinary `id` field | `{"$ref": "id-1"}` (JSON-Pointer-style; lossy — these formats have no syntactic IDREF primitive) |

Cross-format-import (JSON / YAML / TOML / MD → CX) does NOT round-trip
the `$ref` shape back to `attr=@id` automatically — the semantic-emit
direction is operator-facing (humans recognize `$ref` as a reference)
rather than machine-round-trip-authoritative. The canonical round-trip
happens through CX or XML.

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
| Element merge (`*name`) | `cx:merge="name"` attribute |
| Element type annotation (`::type`) | `cx:type="type"` attribute |
| Attribute type annotations (`name::type=…`) | `cx:attr-types="name=type …"` attribute (sidecar) |
| Value annotation (`[?meta {…} FORM]`, code.md §4.2) | `<cx:meta><cx:map>…</cx:map>INNER</cx:meta>` element |
| AliasNode (`[*name]`) | `<cx:alias name="name"/>` element |
| BlockContent node | `<cx:block>...</cx:block>` element |
| CX namespace attrs (`xmlns:prefix`) | Round-trip identity to `xmlns:prefix="..."` |

The `cx:` namespace prefix is used whenever a CX feature has no XML equivalent.
It is absent from XML output that contains no CX-specific features.

**Attributes are scalar-only (D2).** Every attribute value is a single scalar
(`lexicon.ebnf` §10, `ast.md` §Attribute), so every attribute emits as an
ordinary XML attribute (string per the auto-type rule) — there is no
`<cx:attr>` node-valued encoding. Rich / nested data lives in a CHILD ELEMENT,
which already round-trips losslessly to XML as a normal child.

**Typed attributes — the `cx:attr-types` sidecar (D3).** A typed scalar
attribute (`count::u16=5`, `score::decimal=1.5`, `tag::atom=urgent`) emits its
value as an ordinary XML attribute, with its CX type carried in one reserved
element attribute, `cx:attr-types` — a space-separated `name=type` map listing
**only** the attributes whose type the XML→CX importer cannot recover from the
bare lexical form:

```cx
[event count::u16=5 score::decimal=1.5 tag::atom=urgent host=db-1]
```
```xml
<event count="5" score="1.5" tag="urgent" host="db-1"
       cx:attr-types="count=u16 score=decimal tag=atom"/>
```

- The auto-recoverable types `int` / `float` / `bool` / `null` / `date` /
  `datetime` are **omitted** — XML→CX auto-typing reconstructs them from the
  value alone (see §3.1). Only the sized numerics (`u8`..`u64`, `i8`..`i64`,
  `f16`/`f32`/`f64`), `decimal`, `bigint`, `bytes`, and `atom` need listing.
- An explicit-string value that would otherwise auto-type to a scalar
  (`code="007"`) is pinned with a `name=string` entry so it re-imports as a
  string, not an int.
- `cx:attr-types` is reserved (it parallels the element-type carrier `cx:type`
  and the JSON `cx:type` sidecar object); it is absent when no attribute needs
  it. The map order follows source attribute order.

**Value annotations — `<cx:meta>` (D5).** A `[?meta {…} FORM]` annotation
(`code.md` §4.2) serializes to a reserved `<cx:meta>` element wrapping the
annotation map (as a `<cx:map>`) followed by the annotated value:

```
[?meta {pii: true} [user name=ann]]   →   <cx:meta><cx:map><cx:entry cx:key="pii">true</cx:entry></cx:map><user name="ann"/></cx:meta>
[?meta {unit: :years} 331]            →   <cx:meta><cx:map><cx:entry cx:key="unit">years</cx:entry></cx:map>331</cx:meta>
```

The wrapper is uniform for any inner value (element, scalar, or collection),
so the encoding is bijective and `<cx:meta>` round-trips losslessly XML↔XML.
XML is the only structured target that preserves the inert annotation; JSON /
YAML / TOML drop it and serialize the inner value (the annotation
has no native equivalent there, matching how other `cx:` features degrade).

**Identity structures (ID / reference emit):**

The cross-format overview in §1.1 is non-authoritative; the emit
rules below are the normative XML mapping for CX's ID/IDREF
mechanism (per `cxdm.md §4`):

| CX identity construct | XML emission |
|---|---|
| ID declaration (`[el #id …]`, grammar [51a] IdDecl) | `xml:id="id"` attribute on `<el>` |
| Reference attribute (`attr=@id`) | plain `attr="id"` attribute (the `@` is dropped; XML defers IDREF disambiguation to schema validation) |
| Body-position reference (`[ref @id]`) | `<ref cx:body-ref="id"/>` element |

An ID declaration MUST emit as the built-in `xml:id` attribute, a
reference attribute MUST emit as a plain attribute carrying the bare
id value (no `@`), and a body-position reference MUST emit as a
`<ref>` element carrying the `cx:body-ref` attribute.

**Arrays, Maps, Sequences (collection literals, ):**

CXDM container Items emit as `cx:`-namespaced wrapper elements
(the names are reserved — see §0.x above):

| CXDM Item | XML emission |
|---|---|
| Array `[a, b, c]` | `<cx:arr><cx:item>a</cx:item><cx:item>b</cx:item>…</cx:arr>` |
| Map `{k: v, k2: v2}` | `<cx:map><cx:entry cx:key="k">v</cx:entry><cx:entry cx:key="k2">v2</cx:entry>…</cx:map>` |
| Sequence (top-level) | items emitted in order with no wrapping |
| Sequence-as-Item (inside Array / Map) | `<cx:seq><cx:item>a</cx:item>…</cx:seq>` at the item position |
| Empty Array `[]` | `<cx:arr/>` |
| Empty Map `{}` | `<cx:map/>` |
| Nested containers | wrappers nest naturally |

Keys in `<cx:entry cx:key="…">` carry the key's canonical-form
serialization (per `canonical.md`). Non-string keys (int, date, etc.) are serialized via the canonical
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
ordering (lexicographic Unicode order) regardless of
runtime insertion order. This makes XML output content-addressable.

**XML → CX import (reserved `cx:` markers).** The wrapper elements
above are **reserved**; on `xml_to_cx` they reconstruct CXDM
collections — they are NOT imported as ordinary elements named
`cx:arr` / `cx:item` / etc. This is the exact inverse of the emit
table, so `cx_to_xml` → `xml_to_cx` round-trips (§ round-trip
guarantee above):

| XML | CX |
|---|---|
| `<cx:arr>…</cx:arr>` | Array of the contained `<cx:item>` values |
| `<cx:item>v</cx:item>` | one Array / Sequence item `v` — valid **only** as a direct child of `<cx:arr>` or `<cx:seq>`; an orphan `<cx:item>` elsewhere is an import error (reserved `cx:`) |
| `<cx:map>…</cx:map>` | Map of the contained `<cx:entry>` entries |
| `<cx:entry cx:key="K" [cx:key-type="T"]>v</cx:entry>` | Map entry `K → v` (key typed per `cx:key-type`) |
| `<cx:seq>…</cx:seq>` | Sequence of the contained items |
| `<cx:arr/>` / `<cx:map/>` | empty Array / empty Map |
| `<cx:row><cx:cell>…</cx:cell>…</cx:row>` | one `[table]` data row — valid **only** as a direct child of an element carrying `cx:type="table"` + `cx:cols` (§2.1 `[table]` blocks); elsewhere it is an import error (reserved `cx:`) |

A `cx:`-namespaced element in any **other** shape (not one of these
markers) is an import error — the `cx:` namespace is reserved.

A bracket in element-body position has three distinct readings
(grammar [56b]); each maps to a distinct XML shape and round-trips
exactly — note in particular that a one-item Array does **not**
collapse to text:

| CX | XML |
|---|---|
| `[header 'x y']` (text body) | `<header>x y</header>` |
| `[header [x y]]` (child element `x`, body `y`) | `<header><x>y</x></header>` |
| `[header ['x y']]` (one-item Array) | `<header><cx:arr><cx:item>x y</cx:item></cx:arr></header>` |

**Typed-array elements:**

A typed-array element `[name::T[] a b c]` MUST emit as an element
`<name>` carrying a `cx:type="T[]"` attribute whose value is the
array type (element type plus the `[]` suffix), with each array item
wrapped in a `<cx:item>` child element in source order.

| CX form | XML emission |
|---|---|
| `[xs::int[] 1 2 3]` | `<xs cx:type="int[]"><cx:item>1</cx:item><cx:item>2</cx:item><cx:item>3</cx:item></xs>` |
| `[tags::string[] admin user]` | `<tags cx:type="string[]"><cx:item>admin</cx:item><cx:item>user</cx:item></tags>` |

The per-item wrapper is the reserved `<cx:item>` element — the same
wrapper used inside the `cx:arr` / `cx:seq` collection containers
above. The `cx:` namespace marks every CX-structural wrapper so XML →
CX round-trips unambiguously: a bare `<item>` would collide with a
user element named `item`, breaking the lossless-bijection guarantee.

**`[table]` blocks:**

A table-bearing element (grammar `[table[ ... ]` block) MUST emit its
declared columns in the reserved `cx:cols` attribute — space-separated
`name::type` tokens in declaration order, exactly the canonical CX
header text; an untyped column is the bare name — and each data row as
a reserved `<cx:row>` element whose children are `<cx:cell>` elements,
one per column in column order. The element keeps its `cx:type="table"`
annotation. A header-only table (zero rows, valid per §8.3) emits as a
self-closing element carrying both attributes.

Cell emission:

| cell value | XML emission |
|---|---|
| scalar whose bare text re-imports (per the column's declared type) to the same value | `<cx:cell>` escaped text `</cx:cell>` |
| scalar the column-driven recovery would mis-type (a string cell under a non-string column, the literal string `null`, whitespace-only strings, a variant disagreeing with the declared column type) | `<cx:cell><cx:TYPE>` text `</cx:TYPE></cx:cell>` — the same per-item carrier as typed-list items |
| null cell | `<cx:cell><cx:null/></cx:cell>` |
| empty string | `<cx:cell/>` |
| Array / Map / Sequence cell | the `cx:arr` / `cx:map` / `cx:seq` carriers of this section, inside `<cx:cell>` |

On `xml_to_cx`, an element carrying `cx:type="table"` **and** a
non-empty `cx:cols` reconstructs the table payload: every
non-whitespace child MUST be a `<cx:row>` of `<cx:cell>` children
matching the declared column count (anything else is a reserved-shape
import error); bare cell text is typed by its column exactly as the CX
parser types a bare cell (the literal token `null` is the null cell in
any column; a string-family column keeps the text verbatim). An
element with `cx:type="table"` but **no** `cx:cols` keeps the plain
reading: a `::table`-annotated element with no payload. This emission
applies in both the idiomatic and lossless modes — the rows are data,
not type metadata.

Example:

```cx
[users [table[name::string age::int active::bool]]
  alice 30 true
  bob 25 false
]
```

```xml
<users cx:type="table" cx:cols="name::string age::int active::bool">
  <cx:row><cx:cell>alice</cx:cell><cx:cell>30</cx:cell><cx:cell>true</cx:cell></cx:row>
  <cx:row><cx:cell>bob</cx:cell><cx:cell>25</cx:cell><cx:cell>false</cx:cell></cx:row>
</users>
```

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

**Canonical example :**

```cx
[config &srv
 [server host=localhost port=8080 :int]
 [tags ["web", "api"]]
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
| bytes | JSON string (base64, no padding-stripping per `canonical.md`) |

**Collection-literal Items to JSON :**

| CXDM Item | JSON output |
|---|---|
| Array `[a, b, c]` | JSON array `[a, b, c]` — items emitted recursively |
| Map `{k: v}` | JSON object `{"k": v}` — keys serialized as JSON strings (see edge case below) |
| Sequence (top-level or in element body) | JSON array `[a, b, c]` — sequence flattens before emit (per §1.2 CXDM sequence-flat rule) |
| Sequence-as-Item (inside Array / Map value) | JSON array — preserved nesting |
| Empty Array `[]` | JSON `[]` |
| Empty Map `{}` | JSON `{}` |

**JSON edge cases :**

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
CX-element-vs-CX-null distinction at the JSON boundary — in the
**default** lane. The lossless `$tag` envelope (§2.2.1) keeps the
distinction; callers requiring round-trip fidelity use `--lossless`
(or the AST JSON path, `cx_to_ast`).

**Non-string map keys.** JSON requires object keys to be strings.
CX Maps with non-string keys (int, float, date, etc., per
[`cxdm.md` §2.6](cxdm.md)) **coerce keys to strings on emit**:

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

**Map key ordering on JSON emit.** Per `canonical.md`, Map-literal
keys serialize in **lexicographic Unicode order** of their
canonical-string form on the JSON output side, regardless of runtime
insertion order. This makes Map-literal JSON output content-hashable.
This sort applies to **Map literals only**: a Map is a logically
*unordered* key-set (canonical.md §2.11.1 sorts it for stable
hashing), whereas an element is *ordered* — hence element-derived
objects preserve source order (next paragraph). The asymmetry is
intentional and reflects the two kinds' value semantics, not an
inconsistency.

**Element-derived object key ordering on JSON emit.** A JSON object
derived from a CX element (attribute names, then child-element names)
MUST preserve CX document/source order — attributes in source order
followed by children in source order — and MUST NOT be sorted (this
rule governs element-derived objects only; the lexicographic-sort
rule above applies solely to Map literals `{k: v}`). CX is
order-preserving (attribute source order is preserved per
`canonical.md`), so source order is the canonical element-object key
order.

**Mixed content** (element has both text and child elements):

The text is captured under the key `"_"`. Child elements are emitted as their
named keys. If multiple text segments exist, they are concatenated.

**Attributed table elements** (#478): an element carrying both
attributes and a `[table[…]]` block (grammar [29]) projects as an
object — attribute keys in source order, then the row array under
`"_"` (the same `_`-body convention as mixed content and
attrs-plus-scalar bodies). An attribute-free table element stays the
bare array of column-keyed row objects. The same shape applies to the
YAML and TOML semantic lanes, which share this projection.

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

**Canonical example :**

```cx
[server host=localhost port=8080 debug=false]
[tags ["web", "api"]]
[metadata {region: "us-west", replicas: 3}]
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

The pre-form `[tags :string[] web api]` parses unchanged and
produces the same JSON output per §0.2 desugaring.

#### 2.2.1 — Lossless structure encoding: the `$tag` envelope (`--lossless`)

The semantic mapping above is **structure-lossy** for elements: the
element-vs-map shape, the attr-vs-child distinction, mixed-content
order, and element metadata all collapse. Under `--lossless` /
`lossless=true`, an **element** instead emits as a `$tag`
**envelope** — a JSON object over a reserved key set, extending the
`$tag` / `$attrs` / `$children` `named` encoding of `json.md` §2 to
full document fidelity. The default lane is untouched — the envelope
exists only in lossless mode. A `--lossless` CX→json→CX round-trip
recovers an element document byte-identically at the strict-canonical
level (§0.2), which the conformance suite pins over the `examples/`
corpus.

**Reserved envelope keys** (emit order fixed as listed; every key
except `$tag` is omitted when empty/absent):

| Key | Value | CX feature |
|---|---|---|
| `$tag` | string — element name (prefix included) | Element name |
| `$anchor` | string | `&name` anchor |
| `$merge` | string | `*name` merge |
| `$id` | string | `#id` IdDecl (grammar [51a]) |
| `$type` | string — the annotation name verbatim (`int`, `u16`, `string[]`, `table`, …) | `::type` element annotation |
| `$ref` | string — target id | body-position reference `[ref @id]` |
| `$attrs` | object — attr name → value, **source order** | attributes |
| `$attr-types` | object — attr name → CX type name | typed / ref attributes (the JSON image of XML's `cx:attr-types`, D3) |
| `$children` | array — body items, **source order** | element body |
| `$cols` | array of strings — canonical header tokens (`name` / `name::type`), declaration order | `[table[…]]` columns |
| `$rows` | array of arrays — cell values, row/column order | `[table[…]]` data rows |

A top-level document with a **single element root** emits the
envelope directly; **multiple roots** emit as a reserved
`{"$doc": [image, …]}` wrapper, one image per root in source order.
Value-model documents (Map / Array / scalar root) are untouched —
they emit as §2.2/§4.1 already define, sidecar rules included.

**`$attrs` values.** JSON's native types carry the base scalar kinds
directly: `int` / `float` / `bool` / `null` emit as JSON numbers /
booleans / null, and a string attribute emits as a JSON string — no
`name=string` pinning is needed (unlike XML, JSON strings are typed
natively). An attribute whose CX type JSON cannot express lists its
type in `$attr-types` and emits the idiomatic payload image: sized
numerics ride the native JSON number; `bytes` rides base64; `atom`
rides the bare name; `decimal` / `bigint` / `date` / `datetime` /
`duration` / `period` ride their verbatim canonical text. A reference
attribute (`assigned=@u-1`) emits the bare id (`"u-1"`) with the
pseudo-type entry `"assigned": "ref"`.

**`$children` items** map 1:1, in source order:

| body item | JSON image |
|---|---|
| child Element | nested envelope |
| TextNode / plain string scalar | JSON string (import reads it back as body text; the two are strict-canonical-equivalent — except under a `$type` annotation, where import keeps string children as string *scalars* so the `::string` / `::T[]` pinning canonicalizes bare, exactly as the CX parser reads them) |
| `int` / `float` / `bool` / `null` scalar | native JSON scalar |
| typed scalar (`atom` / `date` / `datetime` / `bytes` / `decimal` / `bigint` / `duration` / `period`) | per-item carrier `{"cx:T": payload}` (§0.2) |
| Array item | JSON array (items recurse; typed items take the per-item carrier) |
| Map item | JSON object (§2.2 rules + `cx:type` / `cx:key-type` sidecars; reserved-looking keys escape, below) |
| Sequence-as-item | `{"cx:seq": [ … ]}` (the JSON image of XML's `<cx:seq>`) |
| RawTextNode (`[#…#]`) | `{"cx:raw": "verbatim text"}` |
| EntityRefNode | `{"cx:entity": "name"}` |
| BlockContent (`[\|…\|]`) | dissolved into its text / element runs (the strict-canonical reading) |
| comments / PIs / XML decl / program directives (`[?…]`) | dropped (comments and PIs are outside strict canonical; directives are outside every lane's lossless domain, §0.2) |

**Tables.** A table-bearing element emits `$cols` (the canonical
header tokens, exactly the CX header text per column) and `$rows`.
Cell values are JSON-native (`int` / `float` / `bool` / `string` /
`null` map directly — a JSON string cell is unambiguous, so no
carrier is needed); collection cells use the collection images above.
An attributed table element carries `$attrs` alongside `$cols` /
`$rows` (#478). A header-only table emits `$cols` with `$rows: []`
omitted.

**Reserved-key escaping (non-collision).** The envelope must never
be forged by user data. On lossless emit, a user Map key or attribute
name that starts with `$` or `cx:` emits with the reserved escape
prefix **`cx:k:`**; import strips one `cx:k:` prefix from every
object key, unconditionally. Import reconstruction itself fires only
on the exact reserved shapes — an object is an envelope only when
`$tag` is present **and** every key is reserved; a carrier only as a
single-key object with a recognized `cx:` key — so escaped keys
(which no longer look reserved) round-trip as ordinary map keys.
Under the **default** (non-lossless) emit no escaping happens; user
keys in the `cx:` / `$tag` shapes are in CX's reserved conversion
namespace and may be consumed on re-import (same contract as the
reserved `cx:` XML namespace, §2.1).

**Import (JSON → CX) is unconditional** — the envelope, the per-item
carrier, the sidecars, and the `cx:k:` escape are reserved protocol
shapes recognized on every JSON→CX read (no import-side flag),
exactly like the XML importer's reserved `cx:` markers. The encoding
is self-describing: no schema is needed to reconstruct the document.

**Worked example:**

```cx
[event &e1 kind=:click count::u16=5
  'seen ' [em twice] ' today'
  [total::decimal 19.99]
]
```

```json
{
  "$tag": "event",
  "$anchor": "e1",
  "$attrs": {"kind": "click", "count": 5},
  "$attr-types": {"kind": "atom", "count": "u16"},
  "$children": [
    "seen ",
    {"$tag": "em", "$children": ["twice"]},
    " today",
    {"$tag": "total", "$type": "decimal", "$children": [{"cx:decimal": "19.99"}]}
  ]
}
```

`cx --from=json --to=cx` over that output recovers the original
document (strict-canonical eq — the anchor is carried and resolves
identically on both sides).

**Fidelity note (`§2.2` ambiguities resolved).** Under the envelope,
the `[items]`-vs-`[items null]` ambiguity of §2.2 disappears
(`{"$tag":"items"}` vs `{"$tag":"items","$children":[null]}`), mixed
content keeps its run order (no `"_"` concatenation), same-named
children stay positional (no array folding), and non-string map keys
recover via `cx:key-type` (§0.2). What remains lossy even here:
comments and processing instructions (outside strict canonical) and
program directives (§0.2 domain note).

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

**Collection-literal Items to YAML :**

| CXDM Item | YAML output |
|---|---|
| Array `[a, b, c]` | Block sequence: `- a\n- b\n- c` |
| Map `{k: v, k2: v2}` | Block map: `k: v\nk2: v2` (keys lexicographically ordered) |
| Sequence (top-level or in body) | Block sequence (post-flatten) |
| Sequence-as-Item (inside Array / Map value) | Nested block sequence at the container position |
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

Everything in this list except comments / PIs is recovered by the
lossless structure encoding below.

#### 2.3.1 — YAML lossless structure encoding (`--lossless`)

The YAML lossless lane mirrors the JSON `$tag` envelope (§2.2.1) —
**one envelope, two renderings**. An element emits as a YAML mapping
over the same reserved key set (`$tag`, `$anchor`, `$merge`, `$id`,
`$type`, `$ref`, `$attrs`, `$attr-types`, `$children`, `$cols`,
`$rows`; multi-root documents under `$doc`), with the same emit
order, the same `$attrs` / `$attr-types` protocol, the same
`$children` item mapping, the same table encoding, and the same
`cx:k:` reserved-key escaping. The differences are exactly YAML's
native strengths:

- **Typed scalars need no carrier objects**: a typed value in any
  position (map value, array item, `$children` item) rides its
  `!!cx:T` / `!!binary` tag or native date form per the §0.2 YAML
  rows. `{"cx:decimal": "3.14"}` in JSON is `!!cx:decimal "3.14"`
  in YAML.
- **Strings that would re-read as another type** stay protected by
  the standing YAML quoting rules (a plain `1h30m` string quotes; a
  genuine duration tags in lossless mode).
- The structural carriers that are not scalars keep their reserved
  single-key mapping shape from §2.2.1 (`cx:seq`, `cx:raw`,
  `cx:entity`, `cx:key-type`), rendered as ordinary YAML mappings.

Import is unconditional and shared with the JSON inverse: the YAML
reader materializes the value tree (tags → typed scalars), then the
same envelope / carrier / escape reconstruction recovers the element
document. `--lossless` CX→yaml→CX round-trips element documents
strict-canonical-identically (pinned over `examples/` alongside the
JSON lane).

Worked example (the §2.2.1 document):

```yaml
$tag: event
$anchor: e1
$attrs:
  kind: click
  count: 5
$attr-types:
  kind: atom
  count: u16
$children:
  - "seen "
  - $tag: em
    $children:
      - twice
  - " today"
  - $tag: total
    $type: decimal
    $children:
      - !!cx:decimal "19.99"
```

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

**Collection-literal Items to TOML :**

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
 emits the pre-cutover form.

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
| XML attribute | CX Attr (auto-typed from the value, or per `cx:attr-types`) |
| Namespace declaration `xmlns:prefix="uri"` | CX Attr `xmlns:prefix=uri` |
| Default namespace declaration `xmlns="uri"` | CX Attr `xmlns=uri` |
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
| `cx:attr-types` attribute | Re-types the named sibling attributes (D3); attribute removed |
| `<cx:alias name="..."/>` element | AliasNode |
| `<cx:block>...</cx:block>` | BlockContentNode |

**Attribute typing (D3).** Each imported attribute is typed as follows, in
priority order:

1. If the element carries `cx:attr-types` and the attribute is named in it, the
   listed type is applied (the value is coerced to it). A `name=string` entry
   pins the value to a string, suppressing auto-typing.
2. Otherwise the attribute is **auto-typed from its bare value**, exactly as a
   CX-source bare attribute value is (`lexicon.ebnf` §10 / [L25a]): a value that
   reads as `int` / `float` / `bool` / `null` / `date` / `datetime` takes that
   type; anything else stays a string. Atom shapes are never auto-detected on
   import — atoms arrive only via `cx:attr-types`.

This mirrors the CX-side attribute auto-typer, so `cx_to_xml → xml_to_cx`
round-trips typed attributes losslessly, and direct (non-CX) XML imports with
numeric / boolean / date-shaped attribute values yield the corresponding typed
CX scalars.

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

## 4 — JSON as input

### 4.1 — JSON → CX

**Function:** `cx_json_to_cx`

JSON → CX is the **lossless read**: each JSON value maps to the
corresponding CXDM value (Map / Array / scalar) — the inverse of the
semantic JSON emitter (§2.2). It does **not** synthesise named CX elements
from object keys; that earlier element-tree shape was a lossy invention and
is retired. JSON → CX, the CLI `--from=json`, and the in-program
`[$json:parse]` (json.md §2) all perform the same read.

**Conversion rules:**

| JSON value | CX output |
|------------|-----------|
| JSON object | CXDM **Map** — `{key: value, …}`, keys in source order |
| JSON array | CXDM **Array** — `[a, b, c]` (nesting preserved) |
| JSON string | `string` scalar |
| JSON number (integer) | `int` scalar |
| JSON number (floating-point) | `float` scalar |
| JSON boolean | `bool` scalar |
| JSON null | `null` scalar |

Nested objects/arrays nest as nested Maps/Arrays. The top-level JSON value
becomes the document's single value — there is no synthetic wrapper element.

Examples:

`{"a": 1}` → `{a: 1}`

`{"server": {"host": "localhost", "port": 8080}}` →
`{server: {host: localhost, port: 8080}}`

`{"tags": ["web", "api"]}` → `{tags: ['web', 'api']}`

A top-level array or scalar reads directly: `[1, 2, 3]` → `[1, 2, 3]` ·
`42` → `42` · `"hi"` → `hi`.

**Lossless element round-trip (`$tag` envelope).** The semantic emitter
(§2.2) is lossy for CX elements (tag/attrs/children collapse to a plain
object). Emitting an element with `lossless=true` uses the reserved
`$tag` envelope instead — the full structure encoding of §2.2.1,
extending the `named` `$tag` / `$attrs` / `$children` encoding of
json.md §2. JSON → CX recognises every reserved protocol shape
**unconditionally** — the envelope, the per-item `{"cx:T": …}`
carrier, the `cx:type` / `cx:key-type` sidecars, the `cx:seq` /
`cx:raw` / `cx:entity` carriers, and the `cx:k:` key escape — and
reconstructs the original document, so a lossless emit re-imports
byte-identically (strict-canonical eq, §0.2). The in-program
`[$json:parse]` module surface reconstructs the `named` three-key
subset per json.md §2; the extended envelope keys are a
conversion-lane protocol.

**Strict parse.** JSON → CX is a strict reader (json.md §3): malformed
input, duplicate object keys, depth / byte-limit overruns, and out-of-range
numbers raise `CXER3100`–`CXER3106` rather than producing a best-effort tree.

**Edge cases:**

| JSON form | CX output |
|---|---|
| `{}` | `{}` (empty Map) |
| `[]` | `[]` (empty Array) |
| `{"items": []}` | `{items: []}` |
| `{"items": {}}` | `{items: {}}` |
| `{"items": null}` | `{items: null}` |

**What is lossless:** all JSON scalars, strings, booleans, null, numbers,
objects and arrays round-trip exactly. CX elements round-trip only via the
`$tag` envelope above; under the default semantic emit they degrade
to plain objects (§2.2).

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

## 5 — YAML as input

### 5.1 — YAML → CX

**Function:** `cx_yaml_to_cx`

YAML → CX maps YAML structures to CX elements, attrs, and scalars.

**Conversion rules:**

| YAML construct | CX output |
|----------------|-----------|
| YAML mapping (data-shaped value) | **CXDM Map Item** in element body |
| YAML scalar string | TextNode or ScalarNode depending on auto-typing |
| YAML integer | ScalarNode with `int` type |
| YAML float | ScalarNode with `float` type |
| YAML boolean (`true`/`false`) | ScalarNode with `bool` type |
| YAML null (`~`, `null`) | ScalarNode with `null` type |
| YAML date / datetime | ScalarNode with `date` / `datetime` type |
| YAML sequence | **CXDM Array Item** in element body |
| YAML anchor (`&name`) | Not encoded in CX (YAML anchors are resolved before CX output) |
| YAML alias (`*name`) | Resolved before CX output (inline expansion) |
| YAML comments | Dropped |
| YAML multi-document (`---`) | CX multi-document stream |

YAML sequences map to CXDM Array Items; YAML maps map to CXDM
Map Items when context-appropriate.
**Non-string YAML keys.** YAML's full key-type generality (int,
float, bool, date) maps directly onto CXDM Map keys per
[`cxdm.md` §2.6](cxdm.md). Round-trip CX → YAML → CX preserves typed keys.

**Note:** YAML anchors and aliases are resolved (expanded) during parsing. The
resulting CX does not contain CX anchors, merges, or aliases. A YAML → CX → YAML
round-trip recovers the data but not the YAML anchor/alias structure.

**Lossless structure import.** After the value tree materializes
(tags → typed scalars per the table above), the reader applies the
same unconditional reserved-shape reconstruction as the JSON importer
(§4.1): `$tag` envelopes rebuild elements, `$doc` rebuilds multi-root
documents, the `cx:seq` / `cx:raw` / `cx:entity` / `cx:key-type`
carriers rebuild their nodes, and `cx:k:` key escapes strip. This is
the import inverse of §2.3.1, closing the `--lossless` CX→yaml→CX
round-trip.

---

### 5.2 — YAML → XML, JSON, TOML

**Functions:** `cx_yaml_to_xml`, `cx_yaml_to_json`, `cx_yaml_to_toml`

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
| `[[array of tables]]` | CXDM Array of Map Items |
| TOML integer | ScalarNode with `int` type |
| TOML float | ScalarNode with `float` type |
| TOML boolean | ScalarNode with `bool` type |
| TOML string | TextNode or ScalarNode |
| TOML datetime | ScalarNode with `datetime` type |
| TOML date | ScalarNode with `date` type |
| TOML inline array | **CXDM Array Item** in element body |
| TOML inline table | **CXDM Map Item** in element body |
| TOML comments | Dropped |

TOML inline arrays emit as Array Items; TOML inline tables emit as Map Items.
---

### 6.2 — TOML → XML, JSON, YAML

**Functions:** `cx_toml_to_xml`, `cx_toml_to_json`, `cx_toml_to_yaml`

All apply §6.1 (TOML → CX) then the appropriate CX → target conversion.

---

## 7 — Markdown (codec only — ruling D-B, refined)

Markdown is **not** a CX conversion format (it is not one of the five
lossless data formats this document specifies). CX has no markdown syntax:
the parser is markdown-unaware, and markdown embedded IN a CX document —
like any other source language — is carried verbatim as opaque payload
inside a `[#…#]` raw-text node and round-trips byte-for-byte through any
CX⇄XML/JSON/YAML/TOML path.

What exists is the markdown **codec** (see the header note and
[`codec.md` §4](codec.md)): `cx --md` / `cx --from=md --to=md` /
`[$markdown:emit]`, a best-effort, **typed-lossy** projection — prose
emit, no lossless mode, no round-trip guarantee. The element→markdown
images (headings, lists, emphasis, code fences, links, images) are pinned
by the `md` conformance suite. One image is data-bearing enough to fix
normatively here:

**`[table[…]]` blocks → pipe table (emit).** An element carrying a
`[table[…]]` block (grammar [29]; payload in the pooled TableData field,
not in body items) emits as a GFM pipe table — never dropped:

- header row from the declared column **names** in header order, then a
  `---` separator row, then one row per data row with cells in column
  order;
- column **types**, the wrapper element **name**, and the wrapper's
  **attributes** (#478) are dropped (typed-lossy, same convention as
  the collection-literal wrapper);
- a null cell emits as the empty cell (null and the empty string coincide
  in markdown); booleans as `true`/`false`; numbers in canonical form;
- cell text is neutralized for the pipe-table grammar: `\` → `\\`,
  `|` → `\|`, newline → `<br>`;
- collection cells (array / map / sequence) use the inline collection
  rendering (`[a, b]` / `{k: v}` / `[a, b]`), then the same escaping;
- a header-only table emits the header + separator rows only.

```
[formats [table[format::string input::bool]]     | format | input |
  CX  true                              →        | --- | --- |
  XML true                                       | CX | true |
]                                                | XML | true |
```

No import inverse is required: markdown is typed-lossy by ruling, and
`--lossless --to=md` remains a hard error (§0.2).

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
 [user id=1 name=alice admin=true]
 [user id=2 name=bob]
 [user id=3 name=carol admin=true]
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

A flattening that yields **zero columns** — no `[table]` block, no
attribute-bearing repeated children, no leaf attributes anywhere —
is an **error**: delimited emit never produces blank output for a
document that carries no tabular content.

```cx
[config
 [server host=localhost port=8080 tls=true]
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
2. Auto-typing per `grammar.ebnf [25]`. A field that matches the
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
[table [table[name age::int active::bool]]
  alice 30 true
  bob null false
]
```

(The element is named `table` by the delimited importer; its head is
closed by the glued `[table[…]]` clause-child — grammar [29]. The
`name` column stays untyped: every value is a plain string, the
`::string` default.)

### 8.3 — Empty input

An empty document emits an empty string. An empty input to
`cx_from_delimited` returns a parse error ("empty input"); a header
row with zero data rows is valid and produces a `:table` block with
no rows.

### 8.4 — Comments / anchors / mixed shapes

The lossy-properties table (D7, extended in with cell-collection rule):

| CX construct | delimited treatment |
|--------------|---------------------|
| Comments (line + block) | stripped |
| Anchors / aliases / merges | resolved at conversion time |
| Multi-document (`---`) | first document only; subsequent error |
| Mixed content (text + child elements in body) | not representable; error |
| Processing instructions | stripped |
| Raw-text blocks (`[# ... #]`) | content emitted as a string field, with delimiters/newlines escaped |
| Sized integer / decimal / bigint types | numeric form per `canonical.md`; type metadata lost |
| Array cell `[a, b, c]` | emitted as a **JSON-encoded string field** (quoted): `"[\"a\",\"b\",\"c\"]"` — type metadata lost; round-trip via schema |
| Map cell `{k: v}` | emitted as a **JSON-encoded string field** (quoted): `"{\"k\":\"v\"}"` — keys coerced to strings per §2.2 rule |
| Sequence cell (top-level position) | **error** — delimited cells are scalars or container-as-JSON-string only |
| Nested collection (Array of Maps, etc.) | recursive JSON encoding inside the string field |

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

The C ABI (`abi.md` §2.4–§2.5) exposes one-shot symbols that
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
| **CX** | lossless | lossless‡ | lossy◊ / lossless▣ | lossy◊ / lossless▣ | lossy◊ | lossy◊ | lossy§ |
| **XML** | lossless | lossless | lossy◊ | lossy◊ | lossy◊ | lossy | lossy§ |
| **JSON** | adds struct| adds struct | lossless¶ | lossless¶ | lossless¶ | lossy | lossy§ |
| **YAML** | lossy* | lossy* | lossless¶ | lossless¶ | lossless¶ | lossy | lossy§ |
| **TOML** | lossless** | lossless** | lossless¶ | lossless¶ | lossless¶ | lossy | lossy§ |
| **MD** | lossy | lossy | lossy | lossy | lossy | lossless | lossy§ |
| **CSV** | lossy§ | lossy§ | lossy§ | lossy§ | lossy§ | lossy§ | lossless |

‡ cx→xml is lossless when consumers preserve the `cx:` namespace attributes.
 Consumers that strip `cx:` attributes lose CX-specific metadata.

▣ under `--lossless`: the `$tag` structure envelope (§2.2.1 / §2.3.1)
 plus the §0.2 value carriers recover element documents
 byte-identically (strict-canonical eq). The default lane keeps the ◊
 losses. Program directives stay outside the lossless domain on every
 lane (§0.2).

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

◊ CX → JSON / YAML / TOML / MD with CXDM container Items
 (Array, Map, Sequence-as-Item): non-string Map keys
 are coerced to strings on JSON emit (lossy); the Sequence-vs-Array
 distinction is **lost** on JSON output (both emit as a JSON array,
 so the two cannot be told apart), as well as on YAML / TOML / MD
 output (none distinguish flat sequences from nested arrays). This
 matches the §0 statement that JSON is lossy for Sequence vs Array. XML round-trip is lossless when
 consumers preserve the `cx:arr` / `cx:map` / `cx:seq` wrapper
 elements per §2.1.
