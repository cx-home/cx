# CX AST Specification

**Status:** Current.

Both the CX parser and XML parser produce this AST. It is the canonical representation
shared by all emitters (CX, XML, JSON) and all language implementations.

---

## Conventions

- Optional fields are omitted when absent/null/empty — never serialized as null or [].
- `string` fields store literal values with no implicit escaping or normalization.
- Node types are identified by the `type` field (string discriminant).
- All field names use camelCase. No cx: prefixes in AST field names.

---

## Parse AST vs. Resolved AST

Two phases produce different ASTs from the same source. Parsers MUST document which
they return, and provide a resolver if they return Parse AST.

**Parse AST** — exact structural representation of what was parsed:
- `CXDirective` include nodes are preserved as-is (file not expanded)
- `Alias` nodes are preserved (not replaced with the anchored element)
- `anchor` and `merge` fields on elements are preserved (not resolved)
- Used for: round-trip serialization, source tools, formatters

**Resolved AST** — fully expanded, semantically complete:
- `[?cx include=file.cx]` nodes are replaced with the parsed content of that file
- `[*name]` alias nodes are replaced with a deep copy of the anchored element
- `merge` references are resolved (anchor attrs/items merged, local attrs override)
- Used for: XML emission, validation, code generation, data binding

When emitting XML, the emitter MUST work from the Resolved AST.

---

## Document

```json
{
 "type": "Document",
 "prolog": [], // XMLDecl, PI, CXDirective, Comment — omitted if empty
 "doctype": {}, // DoctypeDecl — omitted if absent
 "elements": [] // top-level nodes — same set as element body nodes (see below)
}
```

`elements` may contain any AST node produced by grammar [53] BodyItem:
Element, Alias, Scalar, Text, BlockContent, EntityRef, RawText,
Comment, PI, CXDirective, Interpolation, EvalDirective, Sequence,
Array, Map, EntityDecl, ElementDecl, AttlistDecl, NotationDecl,
ConditionalSect. (LineComment parses to a `Comment` AST node — there
is no separate `LineComment` node type.) Text and EntityRef at the
top level represent loose mixed content (no wrapping element).

A file using `---` separators produces multiple Document nodes (stream or array).
Each Document is independent — anchors, entities, and declarations do not cross boundaries.

Top-level Scalar and Text nodes are allowed (loose content at document level):
```json
{"type": "Document", "elements": [{"type": "Scalar", "dataType": "int", "value": 42}]}
```

---

## XMLDecl

```json
{
 "type": "XMLDecl",
 "version": "1.0",
 "encoding": "UTF-8", // omitted if absent
 "standalone": "yes" // omitted if absent; "yes" or "no"
}
```

CX: `[?xml version=1.0 encoding=UTF-8]`
XML: `<?xml version="1.0" encoding="UTF-8"?>`

Must be first item in `prolog` when present.

---

## CXDirective

```json
{
 "type": "CXDirective",
 "attrs": [{"name": "include", "value": "base.cx"}]
}
```

CX: `[?cx include=base.cx]`
XML: `<?cx include="base.cx"?>` (serializes as a standard XML PI)

Known attrs split by consuming layer:

| Layer | Attrs | Effect |
|---|---|---|
| Parser | `include`, `version`, `schema` | inline another file; declare CX version; attach a `.cxs` schema |
| Evaluator | `output-target`, `output-strict`, `cx-version`, `allow-eval` | configure the CX code evaluator |

The two layers share one AST node: `[?cx ...]` always parses to a
single `CXDirective`. The layer that consumes each attr is determined
by attr name, not by AST shape — there is no separate
"EvalConfigDirective" production. Unknown attrs round-trip verbatim;
the attribute set is open by design.

In Parse AST: preserved as CXDirective node.
In Resolved AST: `include` directives are expanded inline; others remain.

---

## PI (Processing Instruction)

```json
{
 "type": "PI",
 "target": "php",
 "data": "echo $foo;" // omitted if empty
}
```

CX: `[?php echo $foo;]`
XML: `<?php echo $foo;?>`

`data` is a raw string — not parsed as name=value pairs.
`target` is never `xml` or `cx` (those produce XMLDecl and CXDirective).

---

## Comment

```json
{"type": "Comment", "value": "comment text"}
```

CX: `[;comment text]`
XML: `<!--comment text-->`

---

## DoctypeDecl

```json
{
 "type": "DoctypeDecl",
 "name": "html",
 "externalID": {"public": "-//W3C//DTD...", "system": "http://..."},
 "intSubset": [] // omitted if empty
}
```

### ExternalID

```json
{"system": "file.dtd"}
{"public": "-//Example//EN", "system": "file.dtd"}
```

SystemLiteral and PubidLiteral are always single-quoted in CX output.

---

## Element

```json
{
 "type": "Element",
 "name": "person",
 "anchor": "def", // omitted if absent (Parse AST only)
 "merge": "def", // omitted if absent (Parse AST only)
 "id": "u-1", // IdDecl `#name` per cxdm.md §4.1; omitted if absent
 "bodyRef": "u-1", // body-position `@name` IDREF per cxdm.md §4.2; omitted if absent
 "dataType": "string[]", // omitted if absent — from TypeAnnotation
 "attrs": [], // Attribute[] — omitted if empty
 "items": [] // Node[] — omitted if empty
}
```

`anchor` and `merge` are present in Parse AST. In Resolved AST they are removed
after resolution.

`id` and `bodyRef` carry the syntactic ID / IDREF state defined in
[`cxdm.md` §4](cxdm.md). `id` holds the `#name` declared on the element
(without the `#`); `bodyRef` is set on a `[ref @name]` body-position
reference element (Element name `ref`, single body item that is a bare
`@name` token), holding the referenced ID (without the `@`). Both are
omitted from JSON projection when absent. Wire formats carry them
explicitly ([`ast-bin.md` §4.1](ast-bin.md) Element payload `id` and
`body_ref` slots).

`dataType` carries the TypeAnnotation value (`::int`, `::string[]`, etc.) when present.
Emitters MUST always store the canonical long form (`int`, not `i`; `string[]`, not `s[]`).

**Namespace fields (in-memory, not currently in JSON wire shape).** Per
[`cxdm.md` §3](cxdm.md), every Element carries two additional fields
populated by the post-parse `resolve_namespaces` pass:

- `local` — the part of `name` after the first `:`, or all of `name` if no `:`.
- `ns_uri` — the resolved namespace URI (optional). `none` means no in-scope binding
 and the prefix is not reserved (`xml:`, `cx:`).

Source `name` is preserved verbatim for round-trip emission. Equality (`cx eq`) and
canonical form use `(ns_uri, local)`. The `ns_uri`/`local` fields are not currently
emitted in the AST-JSON wire shape — they are derivable from `name` plus the
xmlns declarations carried as ordinary attributes.

### Attribute

```json
{"name": "href", "value": "https://example.com"}
{"name": "port", "value": 8080, "dataType": "int"}
{"name": "debug", "value": true, "dataType": "bool"}
{"name": "assigned-to", "value": "u-1", "isRef": true}
{"name": "label", "value": "x,y"}
```

`isRef` is `true` when the attribute value is a bare `@name` IDREF
token per [`cxdm.md` §4.2](cxdm.md) (the stored `value` is the
referenced ID without the `@`); omitted otherwise. Wire formats carry
this as the `is_ref` byte ([`ast-bin.md` §4.2](ast-bin.md)).

An attribute `value` is **always a single SCALAR** (D2; grammar [55a],
`lexicon.ebnf` §10) — there is no separate `body` field and no
node-valued form. The admitted forms are bare / quoted / triple-quoted,
plus `[# … #]` which yields its raw content as a STRING scalar
(`a=[# x,y #]` → `"x,y"`). The `value` is auto-typed per the scalar
priority (string default; `dataType` recorded when non-string;
quoted / triple-quoted / `[#…#]` are always string).

`dataType` carries the **canonical long type name**. A glued type
ascription `name::T=value` (D3; `lexicon.ebnf` [L50]) records `T` here and
coerces the value to it — so a sized numeric (`u8`..`u64`, `i8`..`i64`,
`f16`/`f32`/`f64`), `decimal`, `bigint`, `bytes`, or `atom` is preserved on
the attribute, not just the base-kind enum. An array type (`::T[]`) on an
attribute is a parse error (scalar-only, D2).

Any other `[` / `{` / `(`-opened attribute value (Element / Array / Map /
Sequence / BlockContent) is a **parse error** — rich / nested data is
expressed as a child element (`[node [tags a, b]]`), never an attribute.

Same `local` and `ns_uri` fields apply. Per XML Namespaces 1.0 §6.2 the default
namespace does **not** apply to unprefixed attributes — `ns_uri` is `none` for
unprefixed attribute names even when an `xmlns="…"` default is in scope. `xmlns`
and `xmlns:*` declarations themselves have `ns_uri = none` (they are declarations,
not data).

BareValue attribute values are auto-typed using the same scalar priority as body
scalars (see Scalar › Auto-typing rule). The `dataType` field is present when the
value is non-string; string is the default and is omitted. QuotedText attribute
values are always string — use `'8080'` to force a numeric-looking value to string.
Array auto-type does not apply to attribute values.

XML emission: a scalar attribute value serializes as an ordinary XML string
attribute. Auto-recoverable types (`int`/`float`/`bool`/`null`/`date`/`datetime`)
are recovered on re-parse via the auto-typing rule and carry no extra markup. A
type the bare value cannot recover — sized numeric, `decimal`, `bigint`, `bytes`,
`atom`, or an explicit string that would otherwise auto-type — is carried in the
reserved per-element `cx:attr-types` sidecar attribute (D3; see
[`conversions.md` §2.1](conversions.md)), keeping the CX⇄XML round-trip lossless.
Because attributes are scalar-only (D2), every attribute is a real XML attribute —
there is no `<cx:attr>` node-valued encoding.

### Examples

`[p class=note Hello]`
```json
{
 "type": "Element", "name": "p",
 "attrs": [{"name": "class", "value": "note"}],
 "items": [{"type": "Text", "value": "Hello"}]
}
```

`[server host=localhost port=8080 debug=false]`
```json
{
 "type": "Element", "name": "server",
 "attrs": [
 {"name": "host", "value": "localhost"},
 {"name": "port", "value": 8080, "dataType": "int"},
 {"name": "debug", "value": false, "dataType": "bool"}
 ]
}
```

`[tags::string[] admin user guest]`
```json
{
 "type": "Element", "name": "tags", "dataType": "string[]",
 "items": [
 {"type": "Scalar", "dataType": "string", "value": "admin"},
 {"type": "Scalar", "dataType": "string", "value": "user"},
 {"type": "Scalar", "dataType": "string", "value": "guest"}
 ]
}
```

`[defaults &def timeout=30 retries=3]` (Parse AST)
```json
{
 "type": "Element", "name": "defaults", "anchor": "def",
 "attrs": [
 {"name": "timeout", "value": 30, "dataType": "int"},
 {"name": "retries", "value": 3, "dataType": "int"}
 ]
}
```

`[production *def host=prod.example.com]` (Parse AST)
```json
{
 "type": "Element", "name": "production", "merge": "def",
 "attrs": [{"name": "host", "value": "prod.example.com"}]
}
```

---

## Alias

```json
{"type": "Alias", "name": "def"}
```

CX: `[*def]`
XML: `<cx:alias name="def"/>` (Parse AST) or expanded element (Resolved AST)

In Resolved AST, Alias nodes are replaced with a deep copy of the anchored element.

---

## Text

```json
{"type": "Text", "value": "Hello world"}
```

`value` is the literal character content after whitespace rules are applied:
- **CX unquoted**: S between tokens → single space; adjacency → no space
- **CX quoted** (`'...'`): whitespace preserved exactly
- **CX triple-quoted** (`'''...'''`): verbatim content (no escapes); common indent stripped (dedent — lexicon [L31])
- **CX block** (`[|...|]`): verbatim text + nested `[`-nodes; NO dedent, NO newline-strip (see BlockContent [28])
- **XML**: whitespace preserved exactly

The CX emitter wraps Text in single quotes when the value contains leading/trailing
whitespace, consecutive spaces, or newlines — unless the value spans multiple lines,
in which case the emitter SHOULD use TripleQuoted form.

Text nodes contain only string content. Typed tokens produce Scalar nodes.

---

## Scalar

Typed value node. Produced by explicit TypeAnnotation or by auto-typing.

```json
{"type": "Scalar", "dataType": "int", "value": 30}
{"type": "Scalar", "dataType": "float", "value": 3.14}
{"type": "Scalar", "dataType": "bool", "value": true}
{"type": "Scalar", "dataType": "null", "value": null}
{"type": "Scalar", "dataType": "string", "value": "hello"}
{"type": "Scalar", "dataType": "date", "value": "2026-04-19"}
{"type": "Scalar", "dataType": "datetime", "value": "2026-04-19T14:30:00Z"}
{"type": "Scalar", "dataType": "bytes", "value": "SGVsbG8="}
{"type": "Scalar", "dataType": "atom", "value": "ok"}
```

The `atom` dataType
carries a tag-shaped scalar. `value` is the atom's name as a JSON
string. Atom scalars compare type-strict — an atom is never equal
to a string of the same characters (per [`cxdm.md` §5.1](cxdm.md)).
Surface syntax `:NAME` parses to this AST shape.

`value` uses native JSON types: number for int/float, boolean for bool, null for null,
string for date/datetime/bytes/string.

`dataType` always stores the canonical long form (`int`, `string[]`, etc.).

### Auto-typing rule

**Scalar auto-type:** applies when an element's body is a single unquoted token with
no child elements. Priority for that token:

1. Matches `0x[0-9a-fA-F]+` → `int`
2. Matches integer pattern → `int`
3. Matches float/scientific pattern → `float`
4. `true` or `false` → `bool`
5. `null` → `null`
6. Matches ISO 8601 datetime → `datetime`
7. Matches ISO 8601 date → `date`
8. Otherwise → `Text`

**Body value (scalar / array) classification** is defined normatively in
`lexicon.ebnf` §9 [L25a]-[L25d] (it applies to an element body with no head
TypeAnnotation; a child element is always a discrete child). In summary
(@CHOICE-1): ONE bare token auto-types as a scalar by the priority above; a
no-comma run of 2+ SELF-DELIMITING tokens (typed scalars / atoms / quoted strings
— no bareword) yields DISCRETE auto-typed children (mixed content, NOT an array —
`[ports 80 443]` → two int children, no promotion); a bareword in a no-comma run
makes the whole body one verbatim Text run (`[p the quick fox]`); and a COMMA
makes a single heterogeneous Array value of ANY types, items auto-typed, with NO
annotation needed (`[tags web, prod]` → Array ["web","prod"]). An explicit head
`::T` / `::T[]` / `::[]` overrides the whole classification (`::T[]` / `::[]` yield
a uniformly-typed array).

**Attribute auto-type:** BareValue attribute values follow the scalar priority. Array
auto-type does not apply to attributes.

Explicit TypeAnnotation overrides all auto-typing in all contexts.
QuotedText is always `Text`, never `Scalar`.
`::bytes` is always explicit — never auto-typed.

### TypeAnnotation form

TypeAnnotations use the glued double-colon form (`name::T`,
`name::T[]`). The short single-letter aliases are removed; only the
long type names are accepted. The unglued form `::[]` produces an
inferred-type array: non-string tokens → that type; any string token
→ `string[]`.

```
[age 30] → Scalar int 30 (scalar auto-type)
[scores 10 20 30] → int children 10, 20, 30 (no-comma, no bareword → discrete; NOT int[])
[p the quick fox] → Text "the quick fox" (bareword run → prose)
[tags web, prod] → Array ["web","prod"] (comma → heterogeneous array, no annotation)
[tags::[] a b c] → Array string[] (inferred via ::[], tokens are strings)
[tags::string[] a b c] → Array string[] (explicit long form)
[port::int 8080] → Scalar int 8080 (explicit long form)
[port '8080'] → Text "8080" (quoted → always Text)
[scores::string[] 1 2 3] → Array string[] (override auto-int)
```

### Scalar in XML

Auto-typed scalar: `[age 30]` → `<age>30</age>`
Explicit scalar: `[age::int 30]` → `<age cx:type="int">30</age>`
Discrete typed list (no-comma): `[scores 10 20 30]` → `<scores><cx:int>10</cx:int><cx:int>20</cx:int><cx:int>30</cx:int></scores>`
Comma array: `[tags web, prod]` → `<tags><cx:arr><item>web</item><item>prod</item></cx:arr></tags>`
Explicit array: `[tags::string[] a b]` → `<tags cx:type="string[]"><item>a</item>...</tags>`

---

## BlockContent

Parsed block literal. Content is parsed as normal CX body items but newlines are
preserved literally rather than normalized to spaces.

```json
{
 "type": "BlockContent",
 "items": [] // Node[] — same set as element body items
}
```

CX: `[| ... ]`
XML round-trip: `<cx:block>...</cx:block>`
Semantic XML: items inlined directly into the parent element's content (no wrapper)

`items` may contain any AST node produced by grammar [53] BodyItem:
Text (with literal newlines), Element, Alias, Scalar, EntityRef,
RawText, BlockContent (nested), Comment, PI, CXDirective,
Interpolation, EvalDirective, Sequence, Array, Map.

Whitespace processing applied to the raw block content:
1. One leading newline immediately after `[|` is stripped.
2. One trailing newline immediately before the closing `]` is stripped.
3. Common leading whitespace of all non-blank lines is stripped.

BlockContent is the preferred form for mixed content where newlines are significant —
poetry, preformatted prose, code with inline markup, template literals.

### Examples

```
[poem
 [|
 Roses are red,
 Violets are blue,
 CX is [em elegant],
 And YAML is through.
 ]
]
```
```json
{
 "type": "Element", "name": "poem",
 "items": [{
 "type": "BlockContent",
 "items": [
 {"type": "Text", "value": "Roses are red,\nViolets are blue,\nCX is "},
 {"type": "Element", "name": "em",
 "items": [{"type": "Text", "value": "elegant"}]},
 {"type": "Text", "value": ",\nAnd YAML is through.\n"}
 ]
 }]
}
```

XML (semantic): `<poem>Roses are red,\nViolets are blue,\nCX is <em>elegant</em>,\nAnd YAML is through.\n</poem>`

---

## EntityRef

```json
{"type": "EntityRef", "name": "amp"}
```

CX/XML: `&amp;`

Predefined entities (`amp`, `lt`, `gt`, `quot`, `apos`) are **never resolved**.
They remain as EntityRef nodes for round-trip fidelity: `&amp;` → `EntityRef("amp")` → `&amp;`.

CharRefs (`&#NNN;`, `&#xHHH;`) are resolved to their Unicode character and stored
as a single-character Text node. The resolved value MUST be a valid Unicode
scalar — a surrogate (U+D800–U+DFFF) or a value > U+10FFFF is rejected
(`cx-err:CXERLEX-CODEPOINT`). The resolve-vs-preserve asymmetry with EntityRef is
intentional and mirrors XML: a char-ref is character sugar XML does not preserve,
whereas a named entity is markup that round-trips. An undeclared `&name;` is
accepted (CX stores refs without requiring an entity declaration).

---

## Interpolation

```json
{"type": "Interpolation", "expr": "@name"}
{"type": "Interpolation", "expr": "//service[@port=8080]/@host"}
```

CX: `[?=EXPR]` (grammar [58])
XML: round-trip preserved as `<cx:interp expr="..."/>` (round-trip XML)
 / opaque text in semantic XML

The opaque-body bracket form `[?=EXPR]` / grammar v3.5.
`expr` holds the captured expression text verbatim; the CX parser does
not interpret it. The program evaluator parses `expr` as CXPath
at evaluation time.

In pure-data documents (no program evaluator running): Interpolation
nodes round-trip as-is and have no semantic effect. They are inert
data.

In evaluated documents (CX code): the evaluator parses `expr`,
evaluates it against the current context, and emits the result per
`cxdm.md` (canonical scalar formatting) or
`eval.md` (interpolation rules).

---

## EvalDirective

```json
{
 "type": "EvalDirective",
 "name": "if",
 "items": [/* the directive's body items directly, in source order — e.g.
            [in $xs] / [yield $x] clause-children — NOT wrapped in an ArrayNode */]
}
```

CX: `[?Name arg1 arg2 [clause-child ...] ...]` (grammar [59])
XML: round-trip preserved as `<cx:eval name="..."><cx:args>.../></cx:eval>`
 (round-trip XML) / opaque preserved structure in semantic XML

CX code evaluation directive at the data-AST layer (parse-time
representation). The `name` field carries an EvalName from the closed
directive set defined in [`code.md` §4.1](code.md) (mirrored in
`grammar.ebnf` [127e]+[127e′]).

**Two-layer note.** `EvalDirective` is the data-AST node that every
parser produces. The code-evaluation layer additionally exposes
`ProgramDirective` (see "program AST" section below), a richer
representation that decomposes `items` into a tagged `args` list
(positional + clause-child entries) ready for evaluator dispatch.
Data-only tools (`cx fmt`, `cx diff`, `cx hash`) operate on
`EvalDirective`; the CX-code evaluator promotes to `ProgramDirective`
on demand. Both refer to the same source text; conversion is
deterministic.

**`items` field** — the directive's body items, in source order,
**directly** (there is NO wrapping `ArrayNode`). `items` mirrors the
element-body model: `items.len` is the number of body items — `0` for
an empty body (`[?Name]`), `N` otherwise. Directives are slot-free:
every body item is a clause-child element or positional value
(e.g. `[?for [in $xs] [yield $x]]` → `items == [Element "in",
Element "yield"]`); no `:name value` syntax is accepted at the parser.
This makes `EvalDirective` structurally uniform with `Element`
(name + body items). The reshape retired the prior single-
`ArrayNode` "ArgArray" wrapper; the program AST layer reconstructs the
specialised `ProgramDirective` / `DefNode` / `LibNode` / `ConstNode`
shapes from `name` + the body items.

**`?def` arguments** — for `?def` directives, position 0 is the
template name, position 1 is the params `ArrayNode` (bare-identifier
`TextNode`/`ScalarNode` items), position 2 is the body. Zero-parameter
`?def` has `params = []`. Lexical-scope binding semantics are
signaled by capability bit 30.

Attributes are **not** valid on EvalDirective. The runtime V struct
retains a vestigial `attrs []Attribute` field that is always empty.

In pure-data documents (no program evaluator running): EvalDirective
nodes round-trip as-is, preserve their structure under canonical
form and hashing, and have no semantic effect.

In evaluated documents (CX code): the evaluator dispatches on
`name` and produces a CXDM value per
`eval.md`.

reject `[?<EvalName> ...]` as a parse error (would have been
attempted as PI but lacked the structural shape).

---

## SequenceNode

```json
{"type": "Sequence", "items": [/* BodyItem nodes */]}
```

CX: `(a, b, c)` (grammar [56a])
XML: `<cx:seq><cx:item>a</cx:item>…</cx:seq>` (round-trip)

Sequence-literal node / grammar v3.6. Represents a
**Sequence-as-Item** runtime value (per `cxdm.md`)
when stored as one item of an enclosing Array or Map. At top level
or in element body position, the value flattens into the enclosing
Sequence per CXDM §1 sequence-flat principle.

`items` is the ordered list of contained body items. Items
themselves may be Element / Scalar / Text / ArrayNode / MapNode /
SequenceNode / any other BodyItem; nested SequenceNode values at
the SequenceNode-into-SequenceNode boundary auto-flatten at
runtime per CXDM §1. Source-text round-trip preserves source
nesting in the parse AST; flattening is a runtime operation, not
an AST-level normalization.

reject `` collection literals. Capability bit 29
(`0x20000000` per [`abi.md`](abi.md)) signals support.

---

## ArrayNode

```json
{"type": "Array", "items": [/* BodyItem nodes */]}
```

CX: `[a, b, c]` (grammar [56b])
XML: `<cx:arr><cx:item>a</cx:item>…</cx:arr>` (round-trip)

Array-literal node / grammar v3.6. Represents an
**Array Item** runtime value per `cxdm.md` —
ordered, non-flat, preserves nesting.

`items` is the ordered list of contained body items. Nested
ArrayNode values are preserved as ArrayNode items (do not
flatten). SequenceNode items inside an ArrayNode preserve their
Sequence-as-Item semantics per CXDM §2.7.

The empty Array `[]` parses to `{"type": "Array", "items": []}`.
Empty Arrays are valid in BodyItem / AttValue / Node position;
they remain a parse error in Element position per grammar [50].

Capability bit 29 signals ArrayNode support across bindings.

---

## MapNode

```json
{
 "type": "Map",
 "entries": [
 {"key": {"type": "Scalar", "dataType": "string", "value": "name"}, "value": /* BodyItem */},
 {"key": {"type": "Scalar", "dataType": "int", "value": 42}, "value": /* BodyItem */}
 ]
}
```

CX: `{k: v, k2: v2}` (grammar [56c])
XML: `<cx:map><cx:entry cx:key="k">v</cx:entry>…</cx:map>` (round-trip)

Map-literal node / grammar v3.6. Represents a
**Map Item** runtime value per `cxdm.md` —
unordered (runtime) / canonical-sorted (emit), atomic-Scalar keys,
any-Item values.

`entries` is the list of `(key, value)` pairs. Each entry's
`key` is a Scalar AST node (per `ast.md`)
with `dataType` ∈ `{string, int, float, bool, date, datetime, bytes}`;
`null` is not a valid key (parse error W014). Bare-name keys in
source text (`{name: 'a'}`) parse with `dataType=string`. Each
entry's `value` is any BodyItem.

Duplicate keys (per §4.1 atomic equality, type-strict — `1` and
`1.0` are distinct keys) are a parse error W014.

Runtime order is insertion order §D14 / Q6.
Canonical-form emit sorts keys lexicographically by canonical-
string form per `canonical.md`.

The empty Map `{}` parses to `{"type": "Map", "entries": []}`.

support.

---

## IteratorNode

```json
{
 "type": "Iterator",
 "source_kind": "iter_map",
 "source_args": [/* BodyItem nodes */],
 "memo": [/* BodyItem nodes — append-only */],
 "exhausted": false,
 "single_use": false
}
```

Runtime value-kind for lazy iterators (per
`cxdm.md`). IteratorNode has no source-text
literal form — it is produced exclusively by combinator directives,
range literals, and `[?to-iterator]`; it round-trips through the
wire format defined by.

Fields:

- `source_kind` — enum of `iter_none / iter_range / iter_map /
 iter_filter / iter_reduce / iter_zip / iter_enumerate /
 iter_chunks / iter_chain / iter_cycle / iter_scan / iter_flatten /
 iter_partition / iter_group_by / iter_take / iter_drop` per the
 W3c registry. Records how the iterator produces items.
- `source_args []Node` — the source argument list. Shape depends
 on `source_kind` (e.g., for `iter_map`: `[source_iter, lambda]`;
 for `iter_range`: `[start, stop, step]`).
- `memo []Node` — memoization buffer; appended on each pull so a
 named iterator (bound via `[?def]`
 identical items on re-walk.
- `exhausted bool` — true once the source emits no more items.
- `single_use bool` — D25 marker for file/channel-backed sources
 that cannot be re-walked.

Construct via `cx.new_iterator(source_kind, source_args)`.
Heap-allocated (V `@[heap]`) so memoization mutations through
binding lookup are sticky.

**AST vs wire format.** The fields `memo[]` and `exhausted` are
**runtime-only** — they appear in the in-memory AST representation but
are **NOT carried on the ast_bin wire format** (per `ast-bin.md` and
the capability-bit-37 contract). On decode, fresh iterators are
restored that re-evaluate from `source_kind` + `source_args` on first
pull. `single_use` is a declarative property of the source (not
runtime-derived) and **IS** carried on the wire; decoders restore it
verbatim. Tools that consume the in-memory AST (e.g., `cx_code_tree`
JSON projection) MAY include `memo[]` / `exhausted`; the wire codec
MUST NOT.

Identity-only equality; force-materializes to a Sequence at host
boundaries (output, indexing, `[?to-sequence]`) per
[`code.md` §6.7](code.md).

---

## RawText (CDATA)

```json
{"type": "RawText", "value": "if (x < y) { return [1,2,3]; }"}
```

CX: `[# if (x < y) { return [1,2,3]; } #]`
XML: `<![CDATA[if (x < y) { return [1,2,3]; }]]>`

Raw text uses `#]` as its two-character terminator, allowing bare `]` inside.
Inner CX elements are NOT parsed — use BlockContent when inner elements are needed.

**CDATA split rule:** When emitting XML, if `value` contains the sequence `]]>`,
the emitter MUST split it using adjacent CDATA sections:
```
]]> → ]]><![CDATA[>
```
Example: `value = "a]]>b"` → `<![CDATA[a]]><![CDATA[>b]]>`.
XML parsers reassemble adjacent CDATA sections into the original content.
The `]]>` sequence is valid in CX raw text (only `#]` is forbidden in CX source).

---

## EntityDecl

```json
{
 "type": "EntityDecl",
 "kind": "GE",
 "name": "ext",
 "def": {"externalID": {"system": "external.txt"}}
}
```

`kind`: `"GE"` (general) or `"PE"` (parameter).
`def`: string for internal entities; ExternalEntityDef object for external.

**Wire format.** `EntityDecl`, `ElementDecl`, `AttlistDecl`,
`NotationDecl`, and `ConditionalSect` are in-memory AST kinds populated
by re-parsing the DOCTYPE internal subset. The ast_bin wire format
carries the internal subset as verbatim bytes inside
`DoctypeDecl.int_subset` ([`ast-bin.md` §4.1](ast-bin.md) tag `0x0B`)
— there are no per-kind wire tags currently. Consumers that need
structured DTD content re-parse `int_subset` themselves; the
streaming-read API performs this re-parse to fabricate `ElementDecl` /
`AttlistDecl` events.

### ExternalEntityDef

```json
{
 "externalID": {"system": "file.ent"},
 "ndata": "gif" // omitted if absent
}
```

---

## ElementDecl

```json
{"type": "ElementDecl", "name": "p", "contentspec": "(#PCDATA|b|em)*"}
```

`contentspec` stored as raw string.

---

## AttlistDecl

```json
{
 "type": "AttlistDecl",
 "name": "img",
 "defs": [
 {"name": "src", "type": "CDATA", "default": "#REQUIRED"},
 {"name": "alt", "type": "CDATA", "default": "#IMPLIED"}
 ]
}
```

---

## NotationDecl

```json
{
 "type": "NotationDecl",
 "name": "gif",
 "publicID": "image/gif",
 "systemID": "viewer.exe"
}
```

At least one of `publicID` or `systemID` present.

---

## ConditionalSect

```json
{
 "type": "ConditionalSect",
 "kind": "include",
 "subset": []
}
```

CX: `[![INCLUDE[ ... ]]]`
XML: `<![INCLUDE[ ... ]]>`

IGNORE sections preserve their `subset` for round-trip fidelity.

---

## cx: Namespace

Namespace URI: `https://cxhome.org/ns/cx`
Reserved prefix: `cx` — documents may not use `ns:cx` as a namespace alias.

CX AST fields map to XML `cx:` attributes. Two XML output modes exist (see below):

| AST field | Round-trip XML | Semantic XML |
|---------------------|---------------------------|---------------------------|
| `element.anchor` | `cx:anchor="name"` | omitted (resolved) |
| `element.merge` | `cx:merge="name"` | omitted (resolved) |
| `element.dataType` | `cx:type="string[]"` | `cx:type="string[]"` |
| `alias.name` | `<cx:alias name="name"/>` | expanded element (clone) |
| `CXDirective` | `<?cx ...?>` | omitted / inlined |
| `BlockContent` | `<cx:block>...</cx:block>`| items inlined into parent |

---

## XML Output Modes

**Round-trip XML** (from Parse AST) — preserves all CX structure as `cx:`
attributes and PIs. Used for tooling, formatters, and conformance tests.
Alias nodes emit as `<cx:alias name="…"/>`. `cx:anchor`, `cx:merge`, `cx:type`
are preserved on elements. CXDirective emits as `<?cx …?>`. BlockContent emits
as `<cx:block>`.

**Semantic XML** (from Resolved AST) — expands all aliases, inlines includes,
resolves merges. Suitable for XML consumers that do not understand `cx:`.
Only `cx:type` is preserved (to carry type information for re-parsing).
BlockContent items are inlined into the parent element without a wrapper.
Requires the resolver pass (future; not covered by conformance tests v1.0).

Conformance tests specify Round-trip XML in their `out_xml` sections.

---

## program AST

CX code — the unified pattern / query / transform language ratified by
[`code.md`](code.md) — adds seven AST node types, and four further node
types for the module system (`LibNode`, `DefNode`,
`ConstNode`, `TypeExprNode` per [`code.md` §12](code.md)).
Every CX source file parses to a `Program` whose body is a single
`ProgramExpr` subtree; module-top-level files additionally carry a
header sequence of `LibNode`, `DefNode`, and `ConstNode` declarations
preceding the body. Gate 3 ([`code.md` §11.4.1](code.md))
enforces consistency between this section, the EBNF productions
[120]–[129] and [149]–[158] in [`grammar.ebnf`](grammar.ebnf),
and the directive registry in [`code.md` §4.1](code.md).

### Program

```json
{"type": "Program", "body": /* ProgramExpr */}
```

Top-level node for a CX source file. `body` is the single
expression whose evaluation produces the program's result. The host
parser wraps a `.cx` file's content in a `Program` automatically;
embedded CX code inside a CX `[?<directive>]` block round-trips as the
directive's argument value without a `Program` wrapper.

### ProgramBinding

```json
{"type": "ProgramBinding", "name": "x"}
```

CX: `$x` (grammar [123])

Represents a bare `$Ident` reference with no path steps. Pattern
contexts use `ProgramBinding` as a *bind site*; expression contexts use
it as a *read site*. The AST shape is identical; the directive that
owns the surrounding argument position determines the role per
[`code.md` §6.1](code.md).

Path-bearing forms (`$x/name`, `$x//name`, `$x/axis::name`,
`$x@attr`, `$x.key`) parse to `ProgramBindingPath` per grammar
[135] (see below).

In **pattern position only**, `ProgramBinding` carries two extra,
pattern-scoped fields (erased in expression position):

- `type_test` — the `::T` value-kind tag of a typed-bind pattern
  `$name::T` (grammar [140g], `code.md` §5.2 rule 14). When `name` is
  `"_"` the bind is the anonymous form `_::T` (tests the kind, binds
  nothing).
- `is_rest` — set for a rest-capture `*$name` (grammar [140f]) inside a
  map / sequence / array pattern; binds the unmatched trailing items as a
  value of the surrounding kind (`code.md` §5.2 rules 11–13). Legal only
  as the final item of a collection pattern.

### ProgramCall

```json
{
 "type": "ProgramCall", "name": "upper",
 "args": [/* ProgramExpr */],
 "fallible": false, // '?' suffix
 "must_succeed": false // '!' suffix
}
```

CX: `[$upper $x]` (grammar [125] — head-dispatch element form).

Function or filter invocation. `fallible` and `must_succeed` are
mutually exclusive; both `false` is the default total form. Built-in
function names are listed in [`code.md` §4.1](code.md); user
functions appear via `[?fn …]` or `[?def …]` and resolve through the
lexical scope per [`code.md` §8](code.md).

The legacy paren-call form `name(args)` is no longer a general
function-call surface; it survives only inside CXPath predicates as
the XPath-syntactic-parity carrier (per grammar [132b] FunctionCall).
Calls inside predicates parse to the same `ProgramCall` AST shape.

### ProgramPattern

```json
{
 "type": "ProgramPattern",
 "head": {"kind": "name"|"wildcard"|"deep"|"type-guard",
 "value": "User"|"*"|"**", "bind": "u"|null},
 "attrs": [/* ProgramPatternAttr */],
 "direct": false,
 "body": [/* ProgramPatternItem */]
}
```

CX: `[name $bind @attr=v $x **]` (grammar [126])

Structural shape match per [`code.md` §5](code.md). `head.kind`
selects between named element (`"name"`), one-level wildcard
(`"wildcard"`, source `*`), recursive descent (`"deep"`, source `**`),
and type-guard (`"type-guard"`, source `:User`). `head.bind` is the
optional `$ident` binding for the matched node. `attrs` carries
attribute predicates (existence / absence / equality / comparison).
`direct: true` activates adjacency-strict child matching per
[`code.md` §3.1](code.md). `body` is the ordered list of child
matchers; `ProgramPatternItem` is one of `ProgramPattern`, `ProgramBinding`, or
the literal tokens `"*"` / `"**"` rendered as `{"type": "ProgramWildcard",
"deep": false|true}`.

### ProgramDirective

```json
{
 "type": "ProgramDirective",
 "name": "for",
 "args": [
 {"kind": "positional", "value": /* ProgramExpr */},
 {"kind": "clause-child", "name": "yield", "value": /* ProgramExpr */}
 ]
}
```

CX: `[?<name> <args> [clause-child ...] ...]` (grammar [127])

The universal directive AST shape. `name` is one of the directive
names listed in [`code.md` §4.1](code.md). `args` is the ordered list
of positional arguments and clause-child elements as they appear in
source; the evaluator dispatches against `name`'s argument schema
(per the directive's table in [`code.md` §§5/8/10](code.md)).
Argument order is **preserved** at the AST level — canonical-form
serialisation reorders to the directive's documented canonical
argument order per [`canonical.md`](canonical.md).

### ProgramForComp

```json
{
 "type": "ProgramForComp",
 "clauses": [
 {"kind": "generator", "bind": "u", "source": /* ProgramExpr */},
 {"kind": "where", "expr": /* ProgramExpr */},
 {"kind": "let", "bind": "n", "expr": /* ProgramExpr */},
 {"kind": "order-by", "expr": /* ProgramExpr */, "direction": "asc"|"desc"},
 {"kind": "group-by", "expr": /* ProgramExpr */}
 ],
 "yield": /* ProgramExpr */
}
```

CX: `[?for [in $u $users] [where ...] [yield ...]]` (grammar [129])

A specialisation of `ProgramDirective` with `name = "for"`. The
specialised shape exists because for-comprehension is a structural
core construct of CX code (per [`code.md` §7](code.md)) — the
evaluator visits `clauses` in source order to build the binding
environment per [`code.md` §7.2](code.md), then evaluates `yield`
once per surviving iteration. AST consumers MAY transparently treat
`ProgramForComp` as a `ProgramDirective` with `name = "for"`; the explicit
shape is provided for evaluator and renderer ergonomics.

### ProgramLiteral

```json
{"type": "ProgramLiteral",
 "kind": "string_lit"|"int_lit"|"float_lit"|"bool_lit"|"duration_lit"
 |"sequence_lit"|"array_lit"|"map_lit"|"cx_element"|"block"
 |"atom_lit",
 "...": "kind-specific fields"}
```

CX: literal value in expression position (grammar [122]). `kind`
selects which payload field is populated.

Kinds (`vcx/code/ast.v` `ProgramLiteralKind`):

| kind | Payload field(s) | Source surface |
|---|---|---|
| `string_lit` | `str_val` | `"hello"` / `'hello'` |
| `int_lit` | `int_val` | `42`, `-7`, `0x1F` |
| `float_lit` | `flt_val` | `1.5`, `1e10` |
| `bool_lit` | `bool_val` | `true`, `false` |
| `duration_lit` | `dur_val` | `100ms`, `5s`, `1h` |
| `sequence_lit` | `items` | `(a, b, c)` |
| `array_lit` | `items` | `[a, b, c]` |
| `map_lit` | `keys`, `items` | `{k: v, …}` |
| `cx_element` | `name`, `items`, `args`, `attrs` | `[name body...]` |
| `block` | `items` | implicit top-level multi-expression program |
| **`atom_lit`** | `str_val` (= name) | `:ok`, `:not-found` |

The `atom_lit` kind carries the atom's name in `str_val`. The kind is
disjoint from `string_lit` despite both fields carrying UTF-8 — the
discriminator is the kind tag, and equality/identity compare the kind
tag before the payload (per [`cxdm.md` §5.1](cxdm.md)).

### LibNode

```json
{
 "type": "LibNode",
 "resolver": "cx-stdlib/strings",
 "resolver_kind": "file"|"https"|"registered",
 "as": "strings"|null,
 "only": ["upper", "lower"]|null,
 "in_memory": false,
 "version_override": "1.2.3"|null
}
```

CX: `[?lib RESOLVER MODIFIER*]` (grammar [149], normative
[`code.md` §12.1](code.md))

Module-import directive. Module-top-level only — a `LibNode`
appearing in any expression position is a parse error
(`cx-err:CXER0212`). `resolver` is the literal source string from
the directive (`'cx-stdlib/strings'`, `'./helpers.cx'`,
`'https://cdn.example.com/regex-1.2.3.zip'`); `resolver_kind` is
the loader's classification computed at parse time per the §12.1
table. `as` carries the explicit `[as ...]` rebinding clause-child
when present; when absent, the importer's bound name is derived from
the resolver string's last path segment by the loader (not stored on
the node). `only` carries the `[only ...]` selective-import set;
`null` means "import the module's full public surface."

`in_memory` corresponds to the `[?lib '...' [in-memory]]` zip-package
modifier (runtime deferred). `version_override` carries the
hotfix-override `[version ...]` clause-child; idiomatic source leaves
it `null` and lets `cx.lock` own the version mapping.

### DefNode

```json
{
 "type": "DefNode",
 "name": "format-msg",
 "scope": "public"|"private",
 "returns": /* TypeExprNode */ | null,
 "throws": /* TypeExprNode */ | null,
 "params": [
 {"kind": "positional", "name": "url",
 "type": /* TypeExprNode */ | null},
 {"kind": "named", "name": "timeout",
 "type": /* TypeExprNode */ | null,
 "default": /* ProgramExpr */ | null},
 {"kind": "rest", "name": "extra-headers",
 "type": /* TypeExprNode */ | null}
 ],
 "body": /* ProgramExpr */
}
```

CX: `[?def NAME MODIFIER* (params) body]` (grammar [152], normative
[`code.md` §12.2](code.md))

Module-level named function with no closure capture. `name` is
unique per module — re-declaration raises `cx-err:CXER0205`.
`scope` defaults to `"private"`; only `"public"` exports the
definition to importers. `returns` / `throws` carry the optional
`[returns T]` / `[throws T]` clause-children. The `throws` slot is
reserved by [`code.md` §12.2.5](code.md): its surface syntax parses
and the AST carries the clause, but its runtime checking semantics
are deferred to a future revision and consumers MUST treat the
field as informational.

`params` is the ordered parameter list. Each entry's `kind`
discriminates positional / named-with-default / rest. At most one
`rest` entry; always last. `type` is the optional per-parameter
annotation (null if bare).

The body is a single `ProgramExpr`. Function bodies evaluate
lazily — at each call site, not at module load.

### ConstNode

```json
{
 "type": "ConstNode",
 "name": "GREETING",
 "scope": "public"|"private",
 "lazy": false,
 "expr": /* ProgramExpr */
}
```

CX: `[?const MODIFIER* NAME EXPR]` (grammar [154], normative
[`code.md` §12.3](code.md))

Module-level immutable binding. `scope` defaults to `"private"`;
`"public"` exports. `lazy` defaults to `false` (eager — evaluated
at module-load pass 2.2); `true` defers evaluation
to first read with memoisation.

`ConstNode` is single-assignment by construction; there is no
"mutable" variant.

### TypeExprNode

```json
{
 "type": "TypeExprNode",
 "kind": "kind"|"element"|"or"|"sequence",
 "name": "string"|"Person"|null,
 "items": [/* TypeExprNode */]|null
}
```

CX: type expression in `[returns T]`, `name::T`, or a future type
position. Always a CX-data value (types-as-data); never executed.
Grammar [155]–[158]; normative [`code.md` §12.7](code.md).

The `kind` discriminator picks the shape of the node's payload:

| `kind` | Payload | Source surface |
|---|---|---|
| `"kind"` | `name` ∈ {`string`, `int`, `float`, `bool`, `null`, `atom`, `element`, `sequence`, `map`, `function`, `path`} | bare lowercase keyword (e.g. `string`) |
| `"element"` | `name` (capitalized identifier) | bare capitalized identifier (e.g. `Person`) |
| `"or"` | `items` (≥ 2 child `TypeExprNode`s) | `[or T1 T2 ...]` (union) |
| `"sequence"` | `items` (exactly 1 child `TypeExprNode`) | `[sequence T]` (parameterised sequence) |

The `kind=sequence` shape is parameterised-sequence
(`[sequence T]`); bare `sequence` parses as `kind=kind,
name=sequence` and matches any sequence regardless of item type.
Bare `element` is the analogous match-any-element shape.

There is no nullable shorthand: `[or T null]` is the canonical
nullable form.

### ProgramPathExpr

```json
{
 "type": "ProgramPathExpr",
 "leading": "absolute" | "descendant" | "relative",
 "steps": [
 {
 "axis": "child" | "descendant" | "descendant-or-self" | "parent"
 | "ancestor" | "ancestor-or-self"
 | "following-sibling" | "preceding-sibling"
 | "following" | "preceding" | "self" | "attribute",
 "node_test": "Name" | "*" | "node" | "text" | "element" | "attribute",
 "predicates": [ /* ProgramExpr */ ]
 }
 ]
}
```

CX: `//user[@active=true]` / `/root/item` / `user/email` (grammar [130]–[131a])

A first-class Path value. Evaluation produces a `cx.Sequence`
of matching nodes. The `leading` field encodes the opening token:
`"descendant"` for `//`, `"absolute"` for `/`, `"relative"` for a bare
step list with no leading slash.

**Leading forms:**

| Source | `leading` | Notes |
|---|---|---|
| `//user` | `"descendant"` | `descendant-or-self::node/child::user` per XPath 3.1 |
| `/root` | `"absolute"` | Absolute path from document root |
| `user/email` | `"relative"` | Relative path from the evaluation context node |

**Axes** — all 12 XPath 3.1 selection axes are supported (grammar [131a]):

| Axis | Selects |
|---|---|
| `child` | Direct child nodes (default when `axis::` is absent) |
| `descendant` | All descendants, not including self |
| `descendant-or-self` | All descendants plus self |
| `parent` | The parent node |
| `ancestor` | All ancestors up to document root |
| `ancestor-or-self` | All ancestors plus self |
| `following-sibling` | Siblings that follow in document order |
| `preceding-sibling` | Siblings that precede in document order |
| `following` | All nodes that follow in document order, not descendants |
| `preceding` | All nodes that precede in document order, not ancestors |
| `self` | The context node itself |
| `attribute` | Attribute nodes of the context node |

**Node tests** (`node_test` field, grammar [131b]):

| Value | Matches |
|---|---|
| `"Name"` | Element or attribute with that exact name |
| `"*"` | Any element node |
| `"node"` | Any node (element, text, PI, comment) |
| `"text"` | Text nodes only |
| `"element"` | Element nodes only |
| `"attribute"` | Attribute nodes only |

**Predicates** — each entry in `predicates` is an arbitrary `ProgramExpr`
evaluated with the current step's matched node as the context item (grammar
[132]). Two evaluation rules apply:

- Integer result: positional filter — keeps only the N-th node (1-based).
- Any other result: boolean coercion via Effective Boolean Value (EBV) per
 [`cxdm.md` §6](cxdm.md) — the node is kept iff EBV is `true`.

Attribute tests (`[@attr = val]`) are the common predicate form; they
desugar to a comparison `ProgramExpr` that evaluates the attribute named
`attr` against `val` per grammar [133]. Comparison uses value-comparison
semantics only — no keyword synonyms; multi-valued operands raise
`CXER0103`.

**JSON example** — `//user[@active=true]/email`:

```json
{
 "type": "ProgramPathExpr",
 "leading": "descendant",
 "steps": [
 {
 "axis": "child",
 "node_test": "user",
 "predicates": [
 {
 "type": "ProgramCall", "name": "attr-eq",
 "args": [
 {"type": "ProgramLiteral", "kind": "string_lit", "str_val": "active"},
 {"type": "ProgramLiteral", "kind": "bool_lit", "bool_val": true}
 ]
 }
 ]
 },
 {
 "axis": "child",
 "node_test": "email",
 "predicates": []
 }
 ]
}
```

### ProgramBindingPath

```json
{
 "type": "ProgramBindingPath",
 "name": "x",
 "steps": [
 {
 "axis": "child" | "descendant" | /* any axis from [131a] */,
 "node_test": "Name" | "*" | /* any NodeTest from [131b] */,
 "predicates": [ /* ProgramExpr */ ]
 }
 ],
 "predicates": [ /* ProgramExpr */ ]
}
```

CX: `$x/name` / `$x/*` / `$x//name` / `$x/axis::name` (grammar [135])

The binding-path variant of `ProgramPathExpr`. `name` is the binding
identifier (without `$`); `steps` is a non-empty step list rooted at
the bound value. The top-level `predicates` field carries any trailing
predicates on the whole path expression (rare; present for spec completeness).

This form closes the gap documented in
[`code.md` §6.2](code.md): `$x/*` (all children) and `$x//name`
(descendant) were not expressible before.

**Relationship to `ProgramBinding`:** A bare binding `$x` with no steps
continues to parse to `ProgramBinding{name: "x", path: []}` (grammar
[123]). The single-level `$x/name` binding step form
(grammar [124], `ProgramBinding.path`) is **superseded** by
`ProgramBindingPath` for step lists that include descendant (`//`),
explicit axes, or predicates. Implementations MAY emit `ProgramBinding`
for the `$x/name` (single child step, no predicate) form and
`ProgramBindingPath` for all richer forms; the spec-canonical shape is
`ProgramBindingPath` for any path step under.

**Round-trip note:** canonical emit uses the terse `$name/step/...` form. The structured homoiconic form `[?path [binding name] [steps ...]]` is accepted on parse but never auto-emitted.

**Cross-references:**
- Grammar productions [130]–[135]: [`grammar.ebnf`](grammar.ebnf)
- CXPath surface and desugar table: [`code.md` §5.5](code.md)

### PathNode

```json
{
 "type": "PathNode",
 "form": "absolute" | "descendant" | "relative" | "binding",
 "binding": "u" | null,
 "steps": [
 {
 "axis": "child" | "descendant" | "descendant-or-self" | "parent"
 | "ancestor" | "ancestor-or-self"
 | "following-sibling" | "preceding-sibling"
 | "following" | "preceding" | "self" | "attribute",
 "node_test": "Name" | "*" | "*:LocalName" | "Prefix:*"
 | "node" | "text" | "element" | "attribute",
 "predicates": [ /* ProgramExpr */ ]
 }
 ],
 "predicates": [ /* ProgramExpr — trailing top-level predicates (rare) */ ],
 "source": "//user[@active=true]/email",
 "loc": {"line": 12, "col": 3}
}
```

CX: `//user[@active=true]` / `/root/item` / `user/email` / `$u/name`
(grammar [130]–[135])

First-class Path value kind ratified by
D1: `//user[@active=true]`
parses to `cx.PathNode { steps: […] }`, evaluates to a `cx.Sequence`
of matching nodes, and round-trips as the terse `//`-form
D6. The same node kind covers both rooted paths (grammar [130]) and
binding-rooted paths (grammar [135]) — the `form` discriminator
distinguishes the leading-token shape.

**Form discriminator** (mirrors grammar [130] + [135]):

| `form` | Source surface | Semantics |
|---|---|---|
| `"descendant"` | `//user` | `descendant-or-self::node/child::user` per XPath 3.1 |
| `"absolute"` | `/root` | Absolute path from document root |
| `"relative"` | `user/email` | Relative from the evaluation context node |
| `"binding"` | `$u/name`, `$u//item`, `$u/axis::name` | Rooted at the binding named by `binding` (grammar [135]) |

`binding` is the bound identifier (without `$`) when `form = "binding"`;
otherwise `null` and omitted from JSON projection per the
file-wide convention.

**Fields**

- `form` — leading-token discriminator (see table above; grammar [130]
 for the rooted forms, [135] for `binding`).
- `binding` — bound identifier when `form = "binding"`; `null` /
 omitted otherwise.
- `steps` — ordered list of selection steps (grammar [130a]).
 Each step carries `axis` (grammar [131a], 12 XPath 3.1 axes), a
 `node_test` (grammar [131b]), an optional per-step `binding` carrying
 the bound identifier (without the `$` sigil) from a `(bind $name)`
 peer-annotation per grammar [160a] (`null` / omitted when absent;
 reserved `_` rejected at parse time with `CXER0232`), and the step's
 `predicates` (grammar [132]). For `form = "binding"` the step list is
 non-empty per grammar [135]; bare `$x` with no steps remains a
 `ProgramBinding` per the §`ProgramBinding` rule above.
- `predicates` — trailing top-level predicates on the whole path
 expression (rare; present for spec completeness). Each entry is an
 arbitrary `ProgramExpr` evaluated under EBV (per
 [`cxdm.md` §6](cxdm.md)) — integer result is a positional
 filter (1-based); any other kind is boolean-coerced.
- `source` — the literal source-text snippet of the path as parsed,
 preserved verbatim for round-trip and tooling (LSP / tree-sitter)
 hover text. Canonical emit re-derives the terse form from
 `form` + `steps`; `source` is informational, not authoritative.
- `loc` — `{line, col}` of the leading token (the first `/`, `//`, or
 step token for rooted forms; the `$` for binding forms). Optional;
 present when the parser was invoked with source-location tracking.

**Predicate body shape.** The `predicates` arrays carry general
`ProgramExpr` values per
D1 — the closed `PredExpr` enumeration in grammar [132a] is parse-time
sugar over a general predicate expression. AttrTest, positional
integer, function call, and the other [132a] alternatives all
materialise as ordinary `ProgramExpr` AST subtrees here.

**Equality and hashing.** PathNode equality follows the CXDM §5 equality rule
([`cxdm.md` §5](cxdm.md)):
two PathNode values are equal iff `form`, `binding`, the `steps`
list (pairwise on `axis`, `node_test`, and `predicates`), and the
top-level `predicates` list compare equal under the same recursive
rule. Hashing follows the same field set in canonical order. The
`source` and `loc` fields are advisory and do **not** participate in
equality or hashing — two PathNodes parsed from differently-formatted
source text (e.g. `//user[@active = true]` vs
`//user[@active=true]`) compare equal. This matches the round-trip
contract in
form regardless of source whitespace).

PathNode equality enables the matcher cache
`[?modify]` and `[?for]` re-evaluating the same PathNode inside a
loop reuse the compiled Matcher state machine.

**JSON projection.** `ast_to_json` / `cx_to_json` emits the shape
above, omitting optional fields per the file-wide
`## Conventions` rule:
- `binding` is omitted when `form != "binding"`.
- Empty `predicates` arrays (on the top-level node or on individual
 steps) are omitted.
- `source` and `loc` are omitted when the parser was not invoked with
 source-tracking; tooling that needs them MUST request them
 explicitly. The structured homoiconic form
 `[?path [form ...] [steps ...]]` round-trips through the same JSON shape.

**Binary codec hook.** PathNode encodes under ast_bin tag `0x13` at
version byte **v8**, gated on capability bit **36** (`0x1000000000`).
The wire payload mirrors the AST shape above, excluding the
advisory `source` and `loc` fields (per D9 — identity-irrelevant).
See `ast-bin.md` for the full step / axis /
node-test encoding tables and `abi.md` for the
cap-bit table. Bindings that have not yet implemented the v8 codec
leave cap-bit-36 clear and AST-bin emitters MUST reject PathNode
values with `CXER0290` until the wire-format tag is honoured.

**Relationship to `ProgramPathExpr` / `ProgramBindingPath`.** The
two earlier shapes documented in the program-AST block above
are the parser-internal forms; `PathNode` is the spec-canonical name
under. The two parser-internal forms collapse onto a single
`PathNode` value at the AST-bin boundary and at every spec
cross-reference. V implementations MAY retain the split for parser
ergonomics; binding-level consumers and the JSON wire shape see the
unified `PathNode` kind.

**Node-type summary table.** PathNode appears as a single row in the
summary at the end of this file.

**Cross-references**

- Grammar productions [130]–[135]: [`grammar.ebnf`](grammar.ebnf)
- CXPath surface + desugar table: [`code.md` §5.5](code.md)
- Wire-format binary codec tag: `ast-bin.md` — tag `0x13`, v8 version byte, cap-bit 36 (Phase 1.7)

### MatchNode

```json
{
 "type": "MatchNode",
 "mode": "scrutinee" | "predicate-only",
 "scrutinee": /* ProgramExpr */ | null,
 "arms": [
   {"kind": "case", "pattern": /* ProgramExpr */, "body": /* ProgramExpr */, "guard": /* ProgramExpr | null */},
   {"kind": "when", "predicate": /* ProgramExpr */, "body": /* ProgramExpr */},
   {"kind": "else", "body": /* ProgramExpr */}
 ]
}
```

CX: `[?match $x [case PAT [yield V]] [when PRED [yield V]] [else [yield V]]]`
(grammar [136]–[140]).

First-class multi-arm dispatch directive. `mode` is set by the parser
and is one of exactly two values: `scrutinee` (a scrutinee expression
is present; pattern-matched dispatch) or `predicate-only` (no
scrutinee — SQL Searched-CASE form). Arms appear in source order; the
evaluator tries them sequentially. At most one `else` arm; if present,
MUST be the last entry. In `predicate-only` mode, `case` arms are
forbidden (only `when` and `else`).

**Single-arm sugar.** The surface form `[?match X PAT [yield E]]`
(grammar [136] alt 2 — single-arm convenience without an inner
`[case ...]` clause-child) is parse-time sugar: it desugars to
`mode = "scrutinee"` with a single `CaseArm` carrying the
fronted `PAT` / `[yield E]`. The single-arm vs multi-arm distinction
is **not** an AST property — it is recoverable from `arms.length` (a
single `case` arm with no `when`/`else` peers). The AST and wire
([`ast-bin.md §4.5`](ast-bin.md)) carry exactly the two `mode` values
above.

**Scrutinee is a §9.2-exempt boundary.** `scrutinee` is any `ProgramExpr`
(an inline call such as `[/ 10 0]`, a binding, or a literal); when it
yields `[err …]`, that err is *captured* as the match value rather than
auto-propagated (`code.md` §8.2/§9.2) — so a `[case [err …] …]` arm can
dispatch on it. Each arm's `pattern` is the uniform pattern grammar
(`code.md` §5.2 rules 1–14: element/attr/scalar/map/sequence/array
literals, `$bind`, `_`, spread `*$rest`, and the `::T` value-kind test).

`case.guard` is the optional per-arm guard from `[case PAT [where G] [yield V]]`.

**Binary codec hook.** MatchNode encodes under ast_bin tag `0x14` at
version byte **v8**, gated on capability bit **36**. Wire payload per
`ast-bin.md §4.5`.

### ModifyNode

```json
{
 "type": "ModifyNode",
 "doc": /* ProgramExpr */ | null,
 "focus": /* ProgramExpr */ | null,
 "actions": [
   {"kind": "set",           "value": /* ProgramExpr */},
   {"kind": "delete"},
   {"kind": "using",         "value": /* ProgramExpr */},
   {"kind": "rename",        "name":  "..."},
   {"kind": "set-attr",      "name":  "...", "value": /* ProgramExpr */},
   {"kind": "delete-attr",   "name":  "..."},
   {"kind": "append",        "value": /* ProgramExpr */},
   {"kind": "prepend",       "value": /* ProgramExpr */},
   {"kind": "insert-before", "value": /* ProgramExpr */},
   {"kind": "insert-after",  "value": /* ProgramExpr */},
   {"kind": "replace",       "value": /* ProgramExpr */}
]
}
```

CX: `[?modify $doc //user[@id=1] [set "Alice"] [set-attr class "lead"] [delete] ...]`
(grammar [141]–[148]).

First-class pure-functional update directive. Returns a new document
with the requested actions applied; the input is not mutated.
`focus` is the CXPath focus expression narrowing the scope of contained
actions. `actions` are applied in source order against the
focus-selected nodes.

**Action `kind` enum (11 actions).** Mirrors the closed action
vocabulary in [`code.md §8.10`](code.md) and the wire-format
`action_kind` byte in [`ast-bin.md §4.6`](ast-bin.md). The
per-action field validity matrix:

| `kind` | Spelling | `name` | `value` |
|---|---|---|---|
| `set` | `[set EXPR]` | absent | **present** |
| `delete` | `[delete]` | absent | absent |
| `using` | `[using EXPR]` | absent | **present** |
| `rename` | `[rename NAME]` | **present** | absent |
| `set-attr` | `[set-attr NAME EXPR]` | **present** | **present** |
| `delete-attr` | `[delete-attr NAME]` | **present** | absent |
| `append` | `[append EXPR]` | absent | **present** |
| `prepend` | `[prepend EXPR]` | absent | **present** |
| `insert-before` | `[insert-before EXPR]` | absent | **present** |
| `insert-after` | `[insert-after EXPR]` | absent | **present** |
| `replace` | `[replace EXPR]` | absent | **present** |

`name` is the Name-slot identifier (attribute name for `set-attr` /
`delete-attr`; element name for `rename`). `value` is the
ProgramExpr the action evaluates. Absent fields are omitted from JSON
projection per the file-wide convention.

**Binary codec hook.** ModifyNode encodes under ast_bin tag `0x15` at
version byte **v8**, gated on capability bit **36**. Wire payload per
`ast-bin.md §4.6`.

### Pipe — no distinct AST type

The pipeline `[?pipe seed STAGE …]` (grammar [127]/[128b]) is a
`ProgramDirective` with `name = "pipe"` and `args = [positional(seed),
positional(stage_1), positional(stage_2), …]` per
[`code.md` §8.9](code.md) — each bare stage is a positional child (a
transform), and a `[tap …]` clause is a clause-child. There is **no**
`ProgramPipe` node type and **no** infix `|` (retired); a `[through …]`
wrapper is no longer produced. The directive form is the canonical and
only AST shape.

---

## Node type summary

| Type | Core/Ext | CX syntax | XML syntax (round-trip) |
|-----------------|----------|-------------------------|--------------------------------|
| Document | Core | (document) | (document) |
| XMLDecl | Core | [?xml ...] | <?xml ...?> |
| CXDirective | Core | [?cx include=f.cx] | <?cx include="f.cx"?> |
| PI | Core | [?target data] | <?target data?> |
| Comment | Core | [;text] | <!--text--> |
| DoctypeDecl | Core | [!DOCTYPE ...] | <!DOCTYPE ...> |
| Element | Core | [name ...] | <name>...</name> |
| Alias | Extended | [*name] | <cx:alias name="name"/> |
| Text | Core | word or 'phrase' | text node |
| Text | Extended | '''multiline''' | text node |
| Scalar | Extended | 30 true 2026-04-19 | text node (+ cx:type opt.) |
| BlockContent | Extended | [| ... ] | <cx:block>...</cx:block> |
| Interpolation | Extended | [?=EXPR] | <cx:interp expr="EXPR"/> |
| EvalDirective | Extended | [?Name ...] | <cx:eval name="Name">...</cx:eval> |
| Sequence | Extended | (a, b, c) | <cx:seq>...</cx:seq> |
| Array | Extended | [a, b, c] | <cx:arr>...</cx:arr> |
| Map | Extended | {k: v} | <cx:map>...</cx:map> |
| EntityRef | Core | &name; | &name; |
| RawText | Core | [# content #] | <![CDATA[content]]> |
| EntityDecl | Core | [!ENTITY ...] | <!ENTITY ...> |
| ElementDecl | Extended | [!ELEMENT ...] | <!ELEMENT ...> |
| AttlistDecl | Extended | [!ATTLIST ...] | <!ATTLIST ...> |
| NotationDecl | Extended | [!NOTATION ...] | <!NOTATION ...> |
| ConditionalSect | Extended | [![INCLUDE[...]]] | <![INCLUDE[...]]> |
| Program | Extended | (CX source file) | n/a (CX code is CX-only) |
| ProgramBinding | Extended | $x or $x/foo | n/a |
| ProgramCall | Extended | [$upper $x] | n/a |
| ProgramPattern | Extended | [name $b @a=v *] | n/a |
| ProgramDirective | Extended | [?<name> args clause-children] | n/a |
| ProgramForComp | Extended | [?for [in $u $xs] [yield e]] | n/a |
| LibNode | Extended | [?lib 'name' [as alias] [only (a b)]] | n/a |
| DefNode | Extended | [?def name [scope public] (params) body] | n/a |
| ConstNode | Extended | [?const [lazy] NAME expr] | n/a |
| TypeExprNode | Extended | string \| Person \| [or T1 T2] \| [sequence T] | n/a |
| PathNode | Extended | //user[@active=true] / $u/name / $u//item | n/a |
| MatchNode | Extended | [?match $x [case ...] [when ...] [else ...]] | n/a |
| ModifyNode | Extended | [?modify $doc //focus [set EXPR] [delete] ...] | n/a |

EntityDecl is Core because EntityRef is Core — entity declarations define the
names that appear as EntityRef nodes. ElementDecl, AttlistDecl, NotationDecl,
and ConditionalSect are Extended (DTD schema declarations, not needed to parse
element content).

---

## JSON serialization

`ast_to_json` produces a JSON representation for inspection, testing, and interop.

- All optional/empty fields omitted.
- Scalar `value` uses native JSON types.
- `dataType` always uses long-form canonical names (`int`, `string[]`, not `i`, `s[]`).
- Key order is not significant; implementations may sort keys for stability.

**Mixed content:** `[p Hello [b world] and [em you]]`
```json
{
 "type": "Document",
 "elements": [{
 "type": "Element", "name": "p",
 "items": [
 {"type": "Text", "value": "Hello"},
 {"type": "Element", "name": "b",
 "items": [{"type": "Text", "value": "world"}]},
 {"type": "Text", "value": "and"},
 {"type": "Element", "name": "em",
 "items": [{"type": "Text", "value": "you"}]}
 ]
 }]
}
```

**Typed data with auto-typed attributes:**
`[server host=localhost port=8080 debug=false]`
```json
{
 "type": "Document",
 "elements": [{
 "type": "Element", "name": "server",
 "attrs": [
 {"name": "host", "value": "localhost"},
 {"name": "port", "value": 8080, "dataType": "int"},
 {"name": "debug", "value": false, "dataType": "bool"}
 ]
 }]
}
```

**Discrete typed list (no-comma, no bareword):** `[scores 10 20 30]` — discrete
auto-typed children (mixed content); the element carries NO `dataType` and it is
NOT an `int[]` array (use a comma or `::int[]` for an array).
```json
{
 "type": "Document",
 "elements": [{
 "type": "Element", "name": "scores",
 "items": [
 {"type": "Scalar", "dataType": "int", "value": 10},
 {"type": "Scalar", "dataType": "int", "value": 20},
 {"type": "Scalar", "dataType": "int", "value": 30}
 ]
 }]
}
```

**Mixed typed data:** `[person [age 30] [active true] [tags :[] admin user]]`
```json
{
 "type": "Document",
 "elements": [{
 "type": "Element", "name": "person",
 "items": [
 {"type": "Element", "name": "age",
 "items": [{"type": "Scalar", "dataType": "int", "value": 30}]},
 {"type": "Element", "name": "active",
 "items": [{"type": "Scalar", "dataType": "bool", "value": true}]},
 {"type": "Element", "name": "tags", "dataType": "string[]",
 "items": [
 {"type": "Scalar", "dataType": "string", "value": "admin"},
 {"type": "Scalar", "dataType": "string", "value": "user"}
 ]}
 ]
 }]
}
```
