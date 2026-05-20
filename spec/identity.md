# CX Identity (ID / IDREF)

**Version:** 1.0 — 2026-05-08 (updated 2026-05-18 for v0.7.0 close-out)
**Status:** v0.7.0 (full surface shipped). V-core declarations + attribute-value references (Phase 7.61), 9-binding rollout (7.62), XML round-trip (7.63), canonical-form ID renaming (7.64), C ABI symbols at capability bit 20 (7.65), `[ref @id]` body-position form (7.66), ast_bin v3 round-trip for `body_ref` across all 9 bindings (7.70). Cross-include ID merging (§2.1 / D3 second paragraph) becomes live at v0.7.0 GG1 — `vcx/cx/include.v` runs the spec/include.md §1-§8 resolver as a distinct pass between parse and ID-resolve, so the merge participates automatically.

CX adopts a syntactic ID/IDREF mechanism for stable cross-element
references, distinct from anchors/aliases (which are intra-document
merge) and from CXPath (which is positional). This spec records the
syntax, the resolution rules, the v0 API, and the deferred items.

---

## 1. Syntax

### 1.1 ID declaration

```cx
[user #u-1 name=alice +admin]
```

`#name` immediately after the element name (and after any
`AnchorDef` / `MergeRef`) declares this element's syntactic ID. Per
[`spec/grammar.ebnf [51]`](grammar.ebnf), the meta order is
`AnchorDef? MergeRef? IdDecl? TypeAnnotation? (Attribute |
BoolSigilAttr)*`.

The `#name` token is **not** an attribute. It cannot be `=value`-
assigned. It is a separate grammar production with the same name
character set as element names, restricted to exclude `:` (which is
reserved for namespace prefixes).

### 1.2 Attribute-value reference

```cx
[reviewer assigned-to=@u-1]
```

A bare `@name` token at attribute-value position is a syntactic
reference. The bare form (no quotes) parses with `Attribute.is_ref =
true`; the value carries the bare ID string `u-1` (no `@` prefix).

A quoted `'@literal'` is a string value, not a reference. The
emitter quotes any string-valued attribute starting with `@` to
preserve the round-trip distinction.

### 1.2a Body-position reference (`[ref @id]`)

```cx
[para See [ref @section-3] for the rationale.]
```

`[ref @<Name>]` at body position is a syntactic reference node:
an Element named `ref` whose body is exactly a single bare `@name`
token. Parsed into `Element.body_ref = "<Name>"` with empty `attrs`
and empty `items`; emitted back as `[ref @<body_ref>]`.

The reserved-name rule of applies only to elements
matching this exact shape. An Element named `ref` with attributes,
multiple body items, or a non-`@`-prefixed body token is left as a
regular element (back-compat for v0 — the design's strict reservation
will tighten in a future phase once the migration window is clear).

Body-position refs participate in the same resolution and
canonical-form rewriting as attribute-value refs.

The `body_ref` field is exposed across the binding boundary via
the ast_bin wire format. Phase 7.70 (2026-05-09) bumped the wire
format from v2 to v3 to carry `optstr:body_ref` after `optstr:id`
on the Element node-type; every binding's Element type now exposes
`body_ref` (or the language-idiomatic spelling), and the binding's
local CX-text emitter renders the body-position ref form.

### 1.3 Reserved characters

Names follow `Name` per `spec/grammar.ebnf` (letter or `_` to start;
letter / digit / `_` / `-` / `.` thereafter), with the additional
constraint that an ID does **not** contain a `:` (used for
namespace prefixes).

---

## 2. Resolution model

CX resolves IDs at parse time. After the document has been fully
parsed (and namespaces resolved), `resolve_ids(doc)` runs:

1. **Collection pass.** Walks every Element, registering each
 `#name` declaration in the document-scope ID table. A duplicate
 `#name` is a parse error.
2. **Validation pass.** Walks every Attribute with `is_ref = true`,
 confirming that the referenced name was declared somewhere in the
 document. An unresolved reference is a parse error.

Forward references (a `@name` appearing before its `#name` in
source order) are valid — collection precedes validation, so the
target need not be in scope at the reference site.

### 2.1 Scope (v0)

Document-scope only. The `[?cx include=other.cx]` directive is
recognized at the grammar level (preserved as a CXDirectiveNode)
but include resolution itself — reading the referenced file,
inlining its content, and merging its ID space — is **not yet
implemented**. Include resolution is fully specified in
[`spec/include.md`](include.md) ;
implementation is the v0.6.0-blocking remainder for the row.

When include resolution lands, ID-space merging follows 
D3 second paragraph and runs as the ID-resolution pass over the
already-spliced merged AST (per
 D6):

- The included document's IDs join the including document's ID
 space at include resolution time (after parse, before the
 ID-resolution pass).
- A duplicate ID across the include boundary is a parse error
 with both source locations reported (caller-supplied
 `?cx include=` directive site plus the duplicate-declaration
 site in the included file).
- Include-resolution participates in the same two-pass shape
 `resolve_ids` already uses — collection across the merged
 document, validation against the merged table.

This contract is documented now so that the eventual include-
resolution implementation has a stable target. Implementations
calling `resolve_ids` against a manually-merged Document tree
already exercise this rule via the existing duplicate-detection
pass.

### 2.2 Duplicate handling

Two `#u-1` declarations in the same document is a parse error. This
matches XML's `xs:ID` posture and avoids the ambiguity of a
"last-wins" rule.

---

## 3. Public API (V core, v0)

```v
// Declared on cx.Element:
pub mut:
 id ?string // Set when the element has a `#name` declaration.

// Declared on cx.Attribute:
pub mut:
 is_ref bool // true when the attribute value was bare `@name`.

// Document methods:
pub fn (d Document) resolve_id(name string) ?Element
pub fn (d Document) elements_by_id() map[string]Element
```

`resolve_id(name)` walks the document looking for the matching
declaration; `elements_by_id()` returns a name → Element map for
repeated lookups. Both consult the same ID table that
`resolve_ids()` validated against during parse.

C ABI surface shipped Phase 7.65 (capability bit 20):

```c
char* cx_id_lookup (const char* input, const char* id, char** err_out);
char* cx_resolve_ref(const char* input, const char* ref, char** err_out);
char* cx_node_id (const char* input, const char* cxpath, char** err_out);
```

`cx_id_lookup` returns the AST-JSON encoding of the element
declaring `#id`; `cx_resolve_ref` is observationally equivalent
(refs and IDs share a namespace; the separate symbol matches the
 vocabulary); `cx_node_id` runs CXPath `cxpath` against
the input and returns the syntactic ID of the matched element
(or empty if the matched element has no ID, or no element
matched). All three are stateless string-in / string-out wrappers
that re-parse the input on each call; bindings doing repeated
lookups should use the higher-level `Document.resolve_id()` /
`elements_by_id()` accessors instead. Each of the 9 bindings
exposes the symbols with idiomatic naming and a 3–4-case test
suite per Phase 7.65.

---

## 4. CXPath integration

`[#id-name]` matches an element whose syntactic ID equals
`id-name`:

```
//user[#u-1] # the user element with ID u-1
//[#u-1] # any element with that ID, anywhere
//*[#u-1] # same as above, explicit wildcard
```

Distinct from `[name]` (child-existence test) and from
`[@id="u-1"]` (attribute-equality on a user-data attribute named
`id`). User attributes named `id` remain valid and are not
auto-promoted to syntactic IDs.

---

## 5. Conversion across formats (v0)

This section records what works in v0 and what is deferred.

| Format | v0 behavior | Pending |
| ------ | ----------- | ------- |
| CX → CX (round-trip) | ✅ `#id` declarations and `@id` references emit verbatim | none |
| CX → XML | ✅ `#id` ↔ `xml:id="id"` D6; `is_ref` attrs emit as plain `name="<id>"` | external `xs:IDREF` schema validation |
| XML → CX | ✅ `xml:id` hoists to `Element.id`; attributes whose value matches a declared `xml:id` are reconstructed as `is_ref` (bare `@id` form) | infer from arbitrary `xs:ID`-typed attribute names without a schema |
| CX → JSON / YAML / TOML / MD | ⚠ deferred | flatten `#id` to literal `"id": "u-1"`, refs to literal `"@u-1"` strings |
| Strict canonical form | ✅ deterministic `id-N` renaming in document order D7; references rewritten to track the renamed declarations; lossless `cx fmt` preserves source spellings | none |

---

## 6. Examples

### 6.1 Declaration with reference

```cx
[users
 [user #u-1 name=alice]
 [user #u-2 name=bob]
 [reviewer assigned-to=@u-1]
]
```

After parsing:

- `Element{name='user', id='u-1', attrs=[{name='name', value='alice'}]}`
- `Element{name='reviewer', attrs=[{name='assigned-to', value='u-1', is_ref=true}]}`

### 6.2 Forward reference

```cx
[users
 [reviewer assigned-to=@u-1]
 [user #u-1 name=alice]
]
```

Valid. The collection pass registers `u-1` before the validation
pass checks `assigned-to`.

### 6.3 Duplicate ID (parse error)

```cx
[a #x v=1]
[b #x v=2]
```

Parse error: `duplicate ID '#x' — declared on more than one
element in the document`.

### 6.4 Unresolved reference (parse error)

```cx
[item link=@missing]
```

Parse error: `unresolved reference '@missing' on attribute
'link' — no '#missing' declared in the document`.

### 6.5 Quoted `@`-literal

```cx
[item label='@literal']
```

`label` is a string-valued attribute (`is_ref = false`); the value
is `@literal`. Round-trips with the quotes preserved so the
distinction from a bare reference survives.

---

## 7. References

- — ID / IDREF cross-document references
- [`spec/grammar.ebnf`](grammar.ebnf) — productions for `#id` and
 `@id` will land alongside the full grammar update in the
 follow-up phase
- [`spec/cxpath.md`](cxpath.md) — CXPath `[#id]` predicate
- W3C XML 1.0 §3.3.1 — `ID` / `IDREF` attribute types
- W3C `xml:id` 1.0 Recommendation
- `conformance/identity.txt` — 9-case behavior suite
