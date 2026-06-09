# CX Data Model (CXDM)

**Status:** Current for v0.8.0.

The CXDM is the value substrate of CX: the typed values that the parser
produces, that the program language operates over, that the schema
language validates, that format conversions translate, and that the
binary wire formats serialise. CXDM is the runtime/value analog of the
parse AST in [`core/ast.md`](ast.md).

---

## §1. The sequence-flat principle

Every value is a sequence. A single value is a sequence of one. An
empty result is a sequence of zero. **Sequences do not nest.**

- Concatenation at a sequence boundary flattens: `(1, (2, 3), 4)` is
  the four-item sequence `(1, 2, 3, 4)`.
- Nesting at a non-sequence boundary is preserved: see §2.5 (Array),
  §2.6 (Map), §2.7 (Sequence-as-Item).
- **MODE FORK (SEQ-NEST).** Flattening is the **data**-reading rule: when a CX
  *document* is read as data, nested sequences flatten as above. The **program**
  reading **preserves sequence rank** — an evaluator that produces a sequence of
  sequences keeps the nesting (flattening it would collapse, e.g., per-row slices
  and geometry results). This is one of the few deliberate data/program mode
  differences; both readings agree on every non-sequence value.
- Identity-via-reference is not part of the model; equality is
  structural (§5).

**Absence is the empty sequence (normative cross-ref, `code.md` §9.1.2).** The
**empty node-set / empty sequence `()`** is CX's single **absence** channel
("nothing here") — and simultaneously the sequence-monad zero / `None`
(`cx-stdlib/fp`). It propagates inertly (ops on empty → empty). A present `null`
scalar (§2.3) is a **value**, never absence; CX adds **no new `nil` scalar**, and
**no builtin returns `null` to mean "absent"** (the no-conflation guard,
`code.md` §9.1.2.1). The other EBV-false values (`false`, `0`, `''`, `[]`, `{}`)
are present values that flow, not absence.

---

## §2. Value taxonomy

```
Value     ::= Sequence | Item
Sequence  ::= Item*
Item      ::= Node | Scalar | Array | Map | Sequence-as-Item | Path | Iterator

Node      ::= Element | Text | ScalarNode | Comment | PI | Directive | Document
Scalar    ::= bool | int | float | string | date | datetime | bytes | null | atom
Array     ::= '[' Item* ']'              ; preserves nesting
Map       ::= '{' (ScalarKey ':' Item)* '}'
ScalarKey ::= bool | int | float | string | date | datetime | bytes
                                          ; null and atom are not valid keys
Sequence-as-Item                          ; a Sequence boxed as one Item
                                          ; inside an Array, a Map value, or a
                                          ; function-argument position; does NOT flatten
Path      ::= compiled CXPath expression  ; evaluates to a Sequence (§2.8)
Iterator  ::= lazy walkable value         ; produces Items on demand (§2.9)
```

A Sequence MUST NOT contain another Sequence directly at a sequence-
level boundary; any operation that would do so flattens.

### 2.1 Container vs atom distinction

CXDM distinguishes **atom** Items (Node, Scalar) from **container**
Items (Array, Map, Sequence-as-Item, Iterator). Path is structural —
it is neither atom nor container; it evaluates to a Sequence and
otherwise behaves as a first-class value.

Sequence operations (§7) take Sequence and return Sequence; they do
**not** implicitly descend into a container. Calling `count(arr)` on
an Array is a type error; the user writes `count(items(arr))` to ask
"how many items in this Array."

### 2.2 Node

A Node is a CX tree value, corresponding to AST node types in
[`core/ast.md`](ast.md):

| Node kind  | Description |
|---|---|
| Element    | Named element with attributes and items. |
| Text       | Character data. |
| ScalarNode | Typed scalar appearing in element body. |
| Comment    | `[- text -]` comment. |
| PI         | Processing instruction. |
| Directive  | `[?cx …]` file-level directive. |
| Document   | Document root; sequence of top-level items. |

A Document Item used as a sequence member is treated as a sequence
of its top-level children, flattened.

BlockContent, Alias, RawText, EntityRef, and DTD-family nodes are
preserved in the AST but are not first-class CXDM Node kinds —
expressions cannot match against them.

### 2.3 Scalar

Nine atomic kinds:

| Type        | Storage              | Example source |
|---|---|---|
| `bool`      | true / false         | `[active true]` |
| `int`       | 64-bit signed        | `[port 8080]` |
| `float`     | IEEE 754 double      | `[ratio 1.5]` |
| `string`    | UTF-8 byte sequence  | `[name "auth"]` |
| `date`      | ISO 8601 date        | `[born 1980-01-01]` |
| `datetime`  | ISO 8601 instant     | `[at 2026-05-10T12:00Z]` |
| `bytes`     | byte sequence        | `[data::bytes …]` |
| `null`      | the null singleton   | `[absent null]` |
| `atom`      | tag-shaped UTF-8 name | `:ok`, `:err`, `:not-found` |

**Atom semantics.** An atom is a tag-shaped scalar with surface
`:NAME` where `NAME` matches `[A-Za-z_][A-Za-z0-9_-]*`. Atoms are
distinct from strings: `:ok` and `"ok"` carry the same UTF-8 bytes
but are **not equal** (§5.1 — no atom↔string coercion). The names
`:true`, `:false`, `:null` are forbidden at lex time. Atoms render
canonically as `:NAME` (never `:"NAME"`, never bare `NAME`). Atoms
are truthy in EBV (§6).

Atoms are not valid map keys.

**Usage guidance (D4).** An atom is an interned symbolic constant — ≈ an
Erlang atom / Clojure keyword / Scala `Symbol`, **not** a Scala `enum` or an
ADT with fields. It has no total order (§5.5), is not indexable, carries no
attached payload, and is not a valid map key.

- **Use atoms for:** `match` / `case` discriminants, status / result values
  (`:ok`, `:err`, `:not-found`), a small CLOSED set of mode / environment /
  tag flags, and annotation values.
- **Do NOT use atoms for:** ordered enums (atoms have no sort order — use an
  `int` or an explicit order), open / unbounded / user-derived values (every
  distinct atom interns permanently — use a `string`), or values that need an
  attached payload (use an element or a map).

Scalars are immutable; equality is structural.

**Storage-precision refinements.** The grammar accepts additional
type names that encode to the nine semantic kinds with explicit
storage precision: `decimal` and `bigint` (encode as `int` /
`float`), `i8`..`i64` and `u8`..`u64` (encode as `int`),
`f16` / `f32` / `f64` (encode as `float`), `duration` (encode as
`int` — signed nanosecond count), and `instant` (encode as
`datetime` — ISO 8601 instant; nanosecond precision is admitted
by the canonical ISO 8601 form). These are surface-layer storage
hints, not new semantic kinds — equality, EBV, and coercion rules
in this document operate on the nine kinds. See
[`grammar.ebnf` [26a]](grammar.ebnf) for the complete TypeName set.

### 2.4 Attributes

Attributes are **not** first-class Items. They are accessed via the
`@name` axis on an Element, which produces a Scalar — the attribute's
typed value. Two accesses of the same attribute produce two equal
Scalars, not the same Item identity.

A plain (non-directive) element carries only attributes (`name=value`)
and child elements. A scalar field is an attribute; a structured
field (element / sequence / map) is a child element. The glued
double-colon `name::T` is the type annotation form; a single `:` in
data-element body is an atom literal (§2.3).

### 2.5 Array

An Array is an ordered, finite container of Items that preserves
structure (does not flatten).

| Property        | Value |
|---|---|
| Surface         | `[a, b, c]` per [`core/grammar.ebnf`](grammar.ebnf). |
| Order           | Preserved. |
| Item types      | Any CXDM Item. |
| Nesting         | Preserved: `[[1,2],[3,4]]` is a 2-Item Array of 2-Item Arrays. |
| Duplicate items | Permitted. |
| Indexing        | 1-based; out-of-range returns the empty Sequence. |
| Identity        | Structural. |

A Sequence containing one Array (`(arr)`) is **distinct** from the
items of that Array — the Sequence has length 1, holding one Array
Item.

### 2.6 Map

A Map is an unordered, finite collection of (key, value) pairs.

| Property         | Value |
|---|---|
| Surface          | `{k: v, k: v, …}` per [`core/grammar.ebnf`](grammar.ebnf). |
| Key types        | `bool`, `int`, `float`, `string`, `date`, `datetime`, `bytes`. |
| `null` key       | Not permitted (parse error). |
| `atom` key       | Not permitted. |
| Duplicate keys   | Not permitted (parse error). |
| Value types      | Any CXDM Item. |
| Runtime order    | Insertion order. |
| Canonical order  | Lexicographic Unicode order of canonical key serialisation per [`core/canonical.md`](canonical.md). |
| Identity         | Structural. |

Key equality is the §5.1 atomic-equality rule. Numeric widening
(`int` ↔ `float`) does **not** apply to map keys: `{1: 'a'}` and
`{1.0: 'a'}` are distinct.

A bare unquoted name as a key is sugar for the string-quoted form:
`{name: 'a'}` ≡ `{'name': 'a'}`.

### 2.7 Sequence-as-Item

A Sequence value boxed as a single Item, valid in exactly three
positions:

1. As an item inside an Array: `[(a, b), c]`.
2. As the value of a Map entry: `{key: (a, b, c)}`.
3. As a function or directive argument that names a Sequence-typed
   formal parameter.

A Sequence-as-Item does **not** auto-flatten because the surrounding
container is not a sequence-level position. Sequence-as-Item is a
distinct Item kind from Array even when both wrap "three items in a
list" — Sequences flatten on sequence-level concatenation, Arrays do
not.

### 2.8 Path

A Path is a compiled CXPath expression. It evaluates to a Sequence
of matching nodes. Round-trips in canonical emit as the terse `//name`
form. See [`core/code.md` §5.5](code.md) for syntax and semantics.

### 2.9 Iterator

An Iterator is a lazy, walkable value that produces items on demand.
It is the only CXDM Item kind that is lazy by construction.

| Property     | Value |
|---|---|
| Item kind    | Container (lazy). |
| Walk order   | Generator order. |
| Indexable    | No — consume via `[?for]` or materialise first. |
| Mutable      | No (memo growth is internal). |
| Equality     | Identity-only; use `[?seq-equal]` for walk-comparison. |
| Wire format  | Carries source-kind + args so decoders can re-evaluate without eager materialisation; see [`data-bin.md`](data-bin.md). |

Iterators force-materialise to a Sequence at host boundaries: output
rendering, indexing, or the explicit `[?to-sequence]` / `[?to-array]` /
`[?to-map]` directives.

**Generator-family kinds (N-GEN-3).** The arithmetic/functional generator
builtins (`core/code.md` §6.3) split across the two sequence-shaped Item kinds
by whether they are statically finite:

- A **finite** `[$range lo hi step?]` is an **eager Sequence** (§2.5) — a
  materialised value usable everywhere, including operations that force the
  whole thing (`count`, `reverse`).
- The **open / functional** forms — `[$range lo *]`, `[$iterate f seed]`,
  `[$unfold f seed]` — are **lazy Iterators**. `[$range lo *]` and `[$iterate]`
  are statically-known-infinite (must be bounded by `[take]`/`[takewhile]`/a
  `[?for]` terminator before forcing). `[$unfold]` MAY terminate (its `f`
  returns `()`), so it is force-realizable to a finite Sequence — its **kind is
  Iterator**, the realised value is a Sequence (a host force budget backstops a
  runaway).

---

## §3. Namespaces

CX adopts XML-style scoped namespaces.

### 3.1 Prefix declaration

```cx
[doc xmlns:dc=http://purl.org/dc/elements/1.1/
  [dc:title "CX Spec"]]
```

`xmlns:prefix=URI` declares a namespace binding scoped to the declaring
element and its descendants until a redeclaration ends the scope.

### 3.2 Default namespace

```cx
[doc xmlns=urn:doc [section …]]
```

`xmlns=URI` declares a default namespace; applies to the declaring
element and unprefixed descendants until redeclared. It does **not**
apply to attribute names. `xmlns=""` undeclares the default.

### 3.3 Prefixed names

A name of the form `prefix:local` has prefix resolved against the
in-scope binding; the first colon delimits prefix from local part.

### 3.4 Reserved prefixes

| Prefix  | URI                                          | Notes |
|---|---|---|
| `xml`   | `http://www.w3.org/XML/1998/namespace`       | Always resolves. |
| `cx`    | `https://cxhome.org/ns/cx`                   | Cannot be redeclared. |
| `xmlns` | declaration syntax only                      | Never resolves as a name prefix. |

### 3.5 Resolution

Resolution runs post-parse and populates two fields on every Element
and Attribute:

- `local` — the part after the first `:`, or the whole name if no colon.
- `ns_uri` — the resolved URI, or `none` if no in-scope binding for an
  unreserved prefix.

The source-form `name` is preserved verbatim. Round-trip emit uses
`name`; resolved equality uses `(ns_uri, local)`.

The default namespace does NOT apply to attribute names (per XML
Namespaces §6.2); unprefixed attributes have `ns_uri = none`.

`xmlns` and `xmlns:*` declarations themselves carry `ns_uri = none` —
they are declarations, not data.

Resolution is idempotent.

### 3.6 Equality

Two Elements with names `(uri₁, local₁)` and `(uri₂, local₂)` are
namespace-equal iff `uri₁ = uri₂` and `local₁ = local₂`. Source-prefix
choice does not affect equality. Canonical-form rewriting per
[`core/canonical.md`](canonical.md) chooses one canonical prefix per
URI for cross-document hash equality.

---

## §4. Identity (ID / IDREF)

CX provides a syntactic ID/IDREF mechanism for stable cross-element
references, distinct from anchors/aliases (intra-document merge) and
from CXPath (positional).

### 4.1 ID declaration

```cx
[user #u-1 name=alice admin=true]
```

A `#name` token immediately after the element name (and after any
`AnchorDef` / `MergeRef`) declares the element's syntactic ID. The
meta-order per [`grammar.ebnf`](grammar.ebnf) [51] is:

```
AnchorDef? MergeRef? IdDecl? TypeAnnotation? Attribute*
```

`#name` is a grammar token, not an attribute. ID names follow the
`Name` production with the additional constraint that an ID does
not contain `:`.

### 4.2 Reference forms

**Attribute-value reference.** A bare `@name` token at attribute-value
position is a reference:

```cx
[reviewer assigned-to=@u-1]
```

A quoted `'@literal'` is a string value, not a reference. The emitter
quotes any string-valued attribute starting with `@` to preserve the
distinction.

**Body-position reference.** `[ref @name]` at body position is a
reference node — an Element named `ref` whose body is exactly one
bare `@name` token:

```cx
[para See [ref @section-3] for the rationale.]
```

The name `ref` is RESERVED in element-body position: the ONLY admitted
`[ref …]` shape is the exact `[ref @Name]` body-position reference form
above (grammar.ebnf [50a]). Any other `[ref …]` shape (attributes,
non-`@` body, multiple body items) is a parse error with code `E207`
(§11).

### 4.3 Resolution

`resolve_ids(doc)` runs post-parse, in two passes:

1. **Collection.** Walks every Element, registering each `#name` in
   the document-scope ID table. Duplicate `#name` is a parse error.
2. **Validation.** Walks every reference (`is_ref` attribute or
   `body_ref`), confirming the referenced name was declared. An
   unresolved reference is a parse error.

Forward references are valid (collection precedes validation).

### 4.4 Scope

Document scope by default. The `[?include]` directive (per
[`core/code.md`](code.md) §10) merges the included document's IDs
into the including document's ID space at include-resolution time
(after parse, before ID resolution). A duplicate ID across the
include boundary is a parse error (`E208`, §11) with both source
locations reported.

### 4.5 CXPath integration

`[#id-name]` matches an element whose syntactic ID equals `id-name`:

```
//user[#u-1]          ; the user element with ID u-1
//[#u-1]              ; any element with that ID, anywhere
```

Distinct from `[@id="u-1"]` (attribute-equality on a user-data attribute
named `id`).

---

## §5. Equality and comparison

### 5.1 Scalar equality

For two Scalars `a` and `b`:

- Both `null` → equal.
- Same type → value equality:
  - `bool`/`int`/`string`/`bytes`: direct byte / value match.
  - `float`: IEEE-754 with `NaN ≠ NaN` and `+0.0 == -0.0`.
  - `date`/`datetime`: canonical ISO 8601 form.
  - `atom`: byte-by-byte on the UTF-8 name.
- Different numeric types (`int` ↔ `float`) → numeric equality after
  widening the `int` to `float`.
- All other cross-type comparisons → not equal. An `atom` is never
  equal to a `string` of the same characters.

Explicit coercion is the only path across kinds: `[cast value :type-tag]`
(see [`core/code.md` §6.5](code.md)).

### 5.2 Node equality

Two Element Nodes are equal iff:

- Their `(ns_uri, local)` qualified names are equal.
- Their attribute *sets* are equal (same names, same values; order
  does not matter).
- Their item sequences are equal element-wise, in order.

Two Text Nodes are equal iff their `value` strings are byte-identical.
Two ScalarNode Nodes are equal iff their wrapped Scalars are equal.
Cross-kind Node comparisons are not equal.

### 5.3 Container equality

- **Array.** Equal iff same length and items pairwise equal in order.
- **Map.** Equal iff same key set (under §5.1, type-strict per §2.6)
  and values pairwise equal. Order-independent.
- **Sequence-as-Item.** Equal iff wrapped Sequences are equal.

Cross-kind Item comparisons (e.g. Array vs Sequence-as-Item, container
vs Scalar) are not equal. No implicit unwrapping.

### 5.4 Sequence equality

Two Sequences are equal iff same length and items pairwise equal.

### 5.5 Ordering

Total order is defined only on Scalars of the same numeric or temporal
type (`int`, `float`, `date`, `datetime`). Other Scalar types and
Nodes have no language-level total order — sort operations require
an explicit key projection.

`<`, `>`, `<=`, `>=` require numeric or temporal Scalars on both
sides; otherwise a runtime type error.

---

## §6. Effective Boolean Value (EBV)

For directives taking a condition (`[?if cond …]`, predicates), a
Value's truthiness is:

1. Empty Sequence → false.
2. Sequence of length 1 containing a Scalar:
   - `bool` → the bool's value.
   - `string` → length > 0.
   - `int` / `float` → value ≠ 0 (and not NaN).
   - `null` → false.
   - `date` / `datetime` / `bytes` / `atom` → true.
3. Sequence of length 1 containing a Node → true.
4. Sequence of length 1 containing an Array → true iff non-empty.
5. Sequence of length 1 containing a Map → true iff non-empty.
6. Sequence of length 1 containing a Sequence-as-Item → EBV applied
   recursively to the wrapped Sequence.
7. Sequence of length > 1 → true.

Containers follow the empty-is-falsy convention shared by Python
lists/dicts and JSON-template engines.

---

## §7. Sequence operations

The following are total over CXDM Sequences and MUST be provided by
every conformant evaluator.

| Operation              | Signature                       | Notes |
|---|---|---|
| `count(seq)`           | `Sequence → int`                | Item count. |
| `empty(seq)`           | `Sequence → bool`               | True iff count = 0. |
| `concat(s1, s2, …)`    | `Sequence × … → Sequence`       | Flattening concat. |
| `index(seq, n)`        | `Sequence × int → Item`         | 1-based; out-of-range is empty. |
| `head(seq)`            | `Sequence → Sequence`           | First item or empty. |
| `tail(seq)`            | `Sequence → Sequence`           | All but first. |
| `reverse(seq)`         | `Sequence → Sequence`           | Order reversal. |
| `distinct(seq)`        | `Sequence → Sequence`           | Order-preserving dedup under §5. |
| `union(s1, s2)`        | `Sequence × Sequence → Sequence` | `distinct(concat(s1, s2))`. |
| `intersect(s1, s2)`    | `Sequence × Sequence → Sequence` | Items in both, source-1 order. |
| `except(s1, s2)`       | `Sequence × Sequence → Sequence` | Items in s1 not in s2. |

These take Sequence and return Sequence; they do **not** descend
into containers (per §2.1). Container-typed operations
(`array:size`, `map:keys`, …) live in their own namespaces — see
[`std-lib/`](../std-lib/).

---

## §8. AST ↔ CXDM mapping

Every parse-AST construct maps to a CXDM value:

| AST construct                  | CXDM value |
|---|---|
| Document                       | Sequence of its `elements`, mapped per this table. |
| Element                        | Element Node. |
| Attribute with `dataType=T`    | Scalar of type T (accessed via `@name` axis). |
| Attribute without `dataType`   | Scalar of type `string`. |
| Text                           | Text Node. |
| Scalar (in element body)       | ScalarNode containing a Scalar of the AST `dataType`. |
| Comment                        | Comment Node. |
| PI                             | PI Node. |
| CXDirective                    | Directive Node. |
| BlockContent                   | Sequence of items, flattened. |
| Alias                          | Resolved before CXDM mapping. |
| RawText / EntityRef / DTD      | Opaque Node (preserved, not introspectable). |
| SequenceNode                   | Sequence value (auto-flattens at sequence boundaries; preserved as Sequence-as-Item inside containers). |
| ArrayNode                      | Array Item. |
| MapNode                        | Map Item. |
| PathNode                       | Path Item. |
| IteratorNode                   | Iterator Item. |

The mapping is total. Evaluators MUST NOT lose information in the
parse-AST → CXDM direction.

The inverse direction (CXDM → emittable AST) is specified in
[`core/canonical.md`](canonical.md) for canonical form and in
[`core/conversions.md`](conversions.md) for format-specific output.

---

## §9. Type coercion

CXDM is strictly typed. Implicit coercion is permitted only in:

### 9.1 Numeric widening

`int` widens to `float` when one operand of a numeric operation is
`float` and the other is `int`. Result is `float`. No narrowing.

### 9.2 Text-emission stringification

In `[?=expr]` interpolation, any Scalar (or single-Node Sequence) is
converted to its canonical text representation:

| Type        | Canonical text |
|---|---|
| `bool`      | `true` / `false`. |
| `int`       | Decimal, no leading zeros, optional sign. |
| `float`     | Shortest round-trip decimal. |
| `string`    | UTF-8 literal (unquoted in text-emission). |
| `date`      | ISO 8601 calendar date. |
| `datetime`  | ISO 8601 instant, UTC (`Z` suffix). |
| `bytes`     | Base64 standard alphabet. |
| `null`      | `null`. |
| `atom`      | `:NAME`. |

### 9.3 EBV in conditional contexts

Per §6. Implicit only in `[?if …]` test position and predicate boolean
contexts.

### 9.4 What is not implicit

The following raise an evaluation error:

- Comparing `string` with numeric using `<` / `>` / `<=` / `>=`.
- Cross-type non-numeric equality silently succeeding.
- Passing a Scalar where a Node Sequence is required.
- Passing a container where a Sequence is required by a §7 operation.
  Convert explicitly via `flatten(arr)` / `items(arr)` /
  `map:values(m)`.
- Passing a Sequence where an Array is required. Convert via
  `array(seq)`.
- Arithmetic / comparison / ordering on a container. Containers
  participate in equality (§5.3) and EBV (§6) only.

---

## §10. Worked example — sequence flattening + container distinction

```
(1, 2, 3)        ; Sequence of 3 Scalar Items
[1, 2, 3]        ; Sequence of 1 Item (an Array of 3 Scalars)
(1, (2, 3), 4)   ; Sequence of 4 Scalars — inner seq flattens
[1, (2, 3), 4]   ; Sequence of 1 Item; the Array has 3 items:
                 ;   Scalar, Sequence-as-Item, Scalar
{name: 'alice'}  ; Sequence of 1 Item (a Map of 1 entry)
```

`concat((1,2,3), (4,5))` yields `(1,2,3,4,5)`. `concat([1,2,3], [4,5])`
is a type error — `concat` operates on Sequence values, not Arrays
(per §2.1).

---

## §11. Data-parse error codes (`E` prefix)

The data-parse / identity layer raises errors in the `cx-err:E<nnn>`
namespace, distinct from CX code's `CXERnnnn` range (`core/code.md`
§9.5) and schema's `S` range (`core/schema.md`). This registry is
normative; symbolic names are documentation labels, the wire-level code
is always the `E<nnn>` number. The mapping is append-only.

| Symbolic name | Wire code | Subsystem | Where raised |
|---|---|---|---|
| E_REF_RESERVED | `cx-err:E207` | Identity | `[ref …]` body-position shape other than the exact `[ref @Name]` reference form (§4.2) |
| E_DUPLICATE_ID | `cx-err:E208` | Identity | Two `#NAME` declarations with the same id within one document (§4.1; checked after parse, before ID resolution) |
| E_RESERVED_NS_PREFIX | `cx-err:E210` | Namespace | An authored QName resolving to the reserved `cx:` URI (ANY local name, carrier or not) or an `xml:` URI name outside {space, lang, base, id} — the `cx:`/`xml:` namespaces are reserved for the serializer and may not be authored in CX source (§3.1; `grammar.ebnf` GR-RESERVED-PREFIX) |
| E_ATTR_NODE_VALUED | `cx-err:E211` | Attribute | An attribute value opening with `[` / `{` / `(` (other than the `[#…#]` raw-string) — attributes are scalar-only (D2); a `[…]` node may not be an attribute value |
| E_UNBOUND_NS_PREFIX | `cx-err:E212` | Namespace | A QName `p:local` whose prefix `p` is neither in scope (no enclosing `xmlns:p`) nor reserved (§3.1). **Reserved — `grammar.ebnf` defines it; parser enforcement pending.** |
| E_RESERVED_NS_REBIND | `cx-err:E213` | Namespace | `xmlns`/`xmlns:p` used as an element head, rebinding the reserved `xml:`/`cx:` prefixes, or a non-default `xmlns:p=""` undeclaration (§3.1; XML Namespaces 1.0). **Reserved — `grammar.ebnf` defines it; parser enforcement pending.** |
| E_INCLUDE_ABSOLUTE_PATH | `cx-err:E901` | Include | Absolute or UNC path supplied to `[?cx include=…]` |
| E_INCLUDE_PATH_ESCAPES_ROOT | `cx-err:E902` | Include | Resolved include path escapes the include root (lexical or post-symlink) |
| E_INCLUDE_URL_REJECTED | `cx-err:E903` | Include | URL-scheme include path (`://`, `file:`, `http:`, etc.) |
| E_INCLUDE_CYCLE | `cx-err:E904` | Include | Include stack already contains the resolved path |
| E_INCLUDE_DEPTH_EXCEEDED | `cx-err:E905` | Include | `max_include_depth` exceeded |
| E_INCLUDE_FILE_NOT_FOUND | `cx-err:E906` | Include | Resolved file does not exist |
| E_INCLUDE_NOT_READABLE | `cx-err:E907` | Include | Resolved file is not readable (reserved — surfaced via the `E909` carrier in the current impl) |
| E_INCLUDE_NOT_REGULAR_FILE | `cx-err:E908` | Include | Resolved path is a directory or non-regular file |
| E_INCLUDE_IO_ERROR | `cx-err:E909` | Include | Permission denied or I/O failure reading the included file |
| E_INCLUDE_NOT_UTF8 | `cx-err:E910` | Include | Included file bytes are not valid UTF-8 (NUL byte) |
| E_INCLUDE_PARSE_FAILED | `cx-err:E911` | Include | Included file failed its own parse |

`[?cx include]` (`core/code.md` §13) is resolved at parse / document-
assembly time, so the `E901–E911` Include codes are **data-parse** codes
and this registry is their **sole normative home** (code.md §13.8 / §9.5
defer here; the CX-code `CXER0250–0259` range is retired). `abi.md` §1.3
points here for the conversion ABI's error prefix.

## §12. Secret values

A **secret** is a value that computes like its underlying value but is
**redacted at every output boundary** — it never appears in serialization, error
messages, logs, debug inspection, or replay tapes unless explicitly
**declassified** (gated by the `secret-reveal` capability, `security.md`).
Secret-ness is metadata on the value; in memory the real value is present so
computation works.

### 12.1 Marking a secret
- Directive `[?secret EXPR]` wraps a value as secret (`code.md` §4.1; grammar
  `[168]` — exactly one expr, any other arity is `cx-err:CXER0100`).
- Type annotation `$token::secret` marks a secret-typed binding/param
  (grammar `[26a]`); `::secret` is the secret type.
- **Crypto defaults** — key/secret inputs and outputs in `cx-stdlib/crypto`
  (keys, IKM, PRK, shared secrets) are secret by default; MACs / signatures /
  ciphertexts (meant to be transmitted) are not secret.
- Common sources MAY be auto-marked when the capability supplies them (e.g. an
  `env` value whose name matches a secret convention) — an opt-in policy.

### 12.2 Redaction boundaries (normative)

Redaction is a **safe, lossy projection** — distinct from the lossless
guarantees of `canonical.md` §1.1 and `conversions.md`. Emitting a secret
**drops its value** (replacing it with the marker), so a document containing
un-declassified secrets does **not** round-trip losslessly through
serialization. Lossless round-trip of a secret requires declassification
(`[?reveal]`, §12.3, gated by `secret-reveal`); the secret-ness metadata and the
value's type are preserved either way — only the value itself is withheld.

A secret renders as the redaction marker `'‹redacted›'` (never the value) at:

| Boundary | Behavior |
|---|---|
| canonical / CX / JSON / XML / YAML / TOML emit | `'‹redacted›'`; a `secret`-typed field keeps its type, not its value |
| `[err …]` messages + attributes (`code.md` §9.6) | any secret in `message`/`where`/attrs is redacted before the err is built |
| logs (`std-lib/log`) | redacted in structured fields + message |
| debug inspection (`misc/debug.md` frame bindings, `eval`) | shown as `‹redacted›` unless the session holds `secret-reveal` |
| replay tapes (`misc/debug.md` §6a) | recorded as `‹redacted›`; on replay the secret is an opaque hole the program may re-supply |

### 12.3 Propagation + declassify
- **Propagation (best-effort taint)** — a value derived from a secret through a
  pure operation is secret (e.g. `[$substring $token 0 4]` is secret).
  Conservative, not a full information-flow lattice.
- **Declassify** — `[?reveal EXPR]` returns the underlying non-secret value
  (grammar `[169]` — exactly one expr, any other arity is `cx-err:CXER0100`),
  **gated by the `secret-reveal` capability** (`security.md`); without it, reveal
  raises `cx-err:CXER0271` (E_CAP_DENIED). Declassification is an audit event.
- **Crypto declassifies by design** — `hmac` / `sign` / `encrypt` outputs are
  public (transmittable) even though inputs are secret; the boundary is the
  crypto function, not a manual reveal.
- **Comparison** — equality on secrets uses constant-time compare (no early-exit
  timing leak), consistent with `crypto.md`'s `hash/equals`.

### 12.4 Integration
- **Error pipeline (`code.md` §9.6)** — because err `message`/attrs redact
  secrets (§12.2), a `report` sink shipping to a remote tracker cannot leak a
  token in scope at the failure site.
- **Debug (`misc/debug.md`)** — remote frame inspection redacts secrets unless
  the attaching client holds `secret-reveal`.
- **Replay tapes** — secrets are redacted in the tape, so a tape attached to a
  bug report is shareable without leaking credentials; replay treats the secret
  as a hole.

### 12.5 Decisions and scope
- **Redaction marker** is the string `'‹redacted›'` (not a typed `[redacted]`
  node), for format-portability across CX / JSON / XML / YAML / TOML.
- **Taint propagation** is **best-effort** (§12.3) — conservative single-step
  derivation, not a full information-flow type system.
- **Tape policy** is **redact** (`misc/debug.md` §6a): tapes stay shareable; the
  secret is an opaque hole on replay.
- **Out of v1 scope (future extension):** `::secret` composing with an underlying
  type (a "secret string") — `[26]` TypeAnnotation admits a single TypeName, so
  secret-of-T composition needs a later grammar addition. v1 treats `secret` as
  a standalone type annotation.
