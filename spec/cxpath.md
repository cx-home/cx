# CXPath Specification
# Version: 1.1
# Date: 2026-05-11

CXPath is the CX query expression language. It selects Elements from a Document
or Element tree using path steps, axis specifiers, and predicates. CXPath is to
CX what XPath is to XML — the same conceptual model, adapted for CX's typed
attribute system and bracket syntax.

### What's new in v1.1 (2026-05-11)

Per §D13:

- **Union operator `|`** — `path1 | path2` produces a flat Sequence
 concatenation (de-duplicated, document-order). Previously deferred
 to v2; promoted to v1.1.
- **Sequence literal `(path1, path2)`** — syntactic sugar for union;
 equivalent to `path1 | path2`.
- **Array indexing `expr[N]`** — when `expr` evaluates to a CXDM
 Array Item (per `spec/cxdm.md §2.4`), `expr[N]` returns the N-th
 item (1-based; out-of-range returns the empty Sequence). Note
 that **position predicates** `path[N]` (existing v1.0 form)
 continue to apply when `path` evaluates to a Sequence of Element
 Nodes — the disambiguation is type-based on the LHS value.
- **Map key access `expr.key`** and **`expr['key']`** — when `expr`
 evaluates to a CXDM Map Item, the `.key` or `['key']` postfix
 accesses the key's value. The bare-name form `.key` accepts any
 identifier name; the bracketed-string form accepts any string
 literal (for keys with special characters).
- Capability bit **29** (`0x20000000` per `spec/abi.md`) signals
 the v1.1 surface.

CXPath expressions are passed to `select` and `select_all` methods on Document
and Element. The structural navigation API (`at`, `get`, `find_all`, etc.)
remains unchanged and is the substrate CXPath compiles down to.

---

## Conventions

- A **context node** is the Document or Element on which `select`/`select_all`
 is called. All paths are evaluated relative to it.
- CXPath selects **Elements only**. Text, Scalar, Comment, and other non-Element
 nodes are never returned.
- A missing result is `none` / `nil` from `select`, `[]` from `select_all`.
 An invalid expression is a **programming error** — implementations MUST
 panic/throw rather than return a soft error.
- Attribute values in predicates are **typed**. `true` is a bool, `8080` is an
 int, `localhost` is a string — the same auto-typing rules as the CX format.
 No silent coercion.

---

## Methods

### select(expr) → Element or none

Returns the first Element matching the expression, in depth-first document
order, or `none` if no element matches.

### select_all(expr) → Element[]

Returns all Elements matching the expression, in depth-first document order.
Returns `[]` if no element matches.

Both methods are available on **Document** and **Element**.

When called on a **Document**, the search context is the entire document. 
When called on an **Element**, the search context is that element's subtree.
The element itself is never included in results — only descendants are searched.

---

## Path syntax

A CXPath expression is a sequence of steps separated by `/`.

```
step a single step
step/step child of child
step//step child, then any descendant
//step any descendant of context (shorthand for descendant axis)
```

Each step is: `[axis] name-test [predicate]*`

### Axis

| Syntax | Meaning |
|--------|---------|
| `name` or `/name` | Direct children named `name` |
| `//name` | All descendants named `name`, depth-first |

The leading `//` is shorthand for the descendant axis on the context node.
Within a path, `//` between two steps means "any depth between these steps":

```
config/server → direct child named config, then its direct child server
config//p → direct child named config, then any descendant p
//p → any descendant p of context
//section//p → any descendant section, then any descendant p within each
```

### Name test

| Syntax | Meaning |
|--------|---------|
| `name` | Elements with this exact name |
| `*` | Any element (wildcard) |

```
//service → all service elements
//* → all elements at any depth
config/* → all direct children of config
//*[@id] → any element that has an id attr
```

---

## Predicates

A step may be followed by one or more predicates in `[...]`. All predicates
must be satisfied for an element to match.

```
//service[@active=true] one predicate
//service[@active=true][@region=us] two predicates (both required)
//service[@active=true and @region=us] same — and within one predicate
```

### Attribute comparison

```
[@name] attr exists (any value)
[@name=value] attr equals value
[@name!=value] attr does not equal value
[@name>value] attr greater than value (numeric)
[@name<value] attr less than value (numeric)
[@name>=value] attr greater than or equal
[@name<=value] attr less than or equal
```

Values follow CX auto-typing:

| Written | Type |
|---------|--------|
| `true` / `false` | bool |
| `42`, `-7` | int |
| `3.14` | float |
| `null` | null |
| `localhost`, `'hello world'` | string |

String values that contain spaces or special characters must be quoted with
single quotes. Simple strings (letters, digits, hyphens, underscores, dots)
may be unquoted.

```
[@name=auth] string "auth"
[@name='hello world'] string with space — must quote
[@port=8080] int 8080
[@active=true] bool true
[@ratio=1.5] float 1.5
[@region!=eu] not equal
[@port>=8000] numeric range
```

Comparison operators `>`, `<`, `>=`, `<=` require both sides to be numeric.
Comparing a string attribute with a numeric literal produces a panic.

### Boolean operators

`and` and `or` combine conditions within a predicate. `and` binds tighter
than `or`.

```
[@active=true and @region=us]
[@port=80 or @port=443]
[@active=true and (@region=us or @region=eu)]
```

### not()

```
[not(@active=false)] elements where active is not false
[not(@debug)] elements without a debug attr
```

### Child existence

A bare name (no `@`) tests whether a direct child element with that name exists.

```
[meta] has a child named meta
[not(meta)] does not have a child named meta
```

### ID match

`[#id-name]` matches the element whose syntactic ID (declared via
the `#name` ElementMeta token)
equals `id-name`. Distinct from `[name]` (child-existence) and from
`[@id="..."]` (attribute equality on a user-data attribute named
`id`). User-data `id` attributes are not auto-promoted to
syntactic IDs.

```
//user[#u-1] user element whose syntactic ID is "u-1"
//*[#u-1] any element with that ID, anywhere
//section[not(#u-1)] sections without that ID
```

### Position

Position predicates select by index among the matched elements at that step,
in document order. Positions are **1-based**.

```
[1] first match
[2] second match
[last()] last match
```

```
//item[1] first item descendant
//item[last()] last item descendant
config/*[1] first direct child of config (any name)
```

### Functions

| Function | Tests |
|----------|-------|
| `contains(@k, val)` | attr value contains the string val |
| `starts-with(@k, val)` | attr value starts with the string val |
| `not(expr)` | negates any predicate expression |
| `local-name()` | element's local name (post-colon part of the source name) — see [§Namespace-aware queries](#namespace-aware-queries) |
| `namespace-uri()` | element's namespace URI; empty string when the element has none |

```
//p[contains(@class, note)] class attr contains "note"
//service[starts-with(@name, auth)] name starts with "auth"
//item[not(contains(@tags, beta))] tags does not contain "beta"
```

---

## Examples

```cx
[services
 [service name=auth port=8080 active=true region=us
 [tags :string[] core internal]
 ]
 [service name=api port=9000 active=false region=eu]
 [service name=web port=80 active=true region=us
 [tags :string[] public]
 ]
]
[docs
 [section id=intro
 [h1 Introduction]
 [p class=lead First paragraph.]
 [p Second paragraph.]
 ]
 [section id=detail
 [h2 Details]
 [p class=note A note.]
 ]
]
```

```
// All active services
doc.select_all("//service[@active=true]")
→ [service name=auth ..., service name=web ...]

// First active service
doc.select("//service[@active=true]")
→ service name=auth ...

// Services in us region with port over 8000
doc.select_all("//service[@region=us and @port>8000]")
→ [service name=auth ...]

// Service named exactly "api"
doc.select("//service[@name=api]")
→ service name=api ...

// Any element that has an id attribute
doc.select_all("//*[@id]")
→ [section id=intro, section id=detail]

// All p elements inside any section
doc.select_all("//section//p")
→ [p class=lead ..., p ..., p class=note ...]

// Only p elements with class=note
doc.select_all("//p[@class=note]")
→ [p class=note A note.]

// Paragraphs that contain "lead" in their class
doc.select_all("//p[contains(@class, lead)]")
→ [p class=lead ...]

// Services that have a tags child
doc.select_all("//service[tags]")
→ [service name=auth ..., service name=web ...]

// First direct child of services (any name)
doc.select("services/*[1]")
→ service name=auth ...

// All direct children of any section
doc.select_all("//section/*")
→ [h1, p, p, h2, p]

// Select relative to an element
services := doc.at("services") or { return }
services.select_all("service[@active=true]")
→ [service name=auth ..., service name=web ...]
```

---

## Namespace-aware queries

When the queried document declares XML namespaces (per
[`spec/namespaces.md`](namespaces.md) and ), CXPath name tests
and attribute predicates resolve query prefixes against an in-document
binding map. Two predicate functions, `local-name()` and
`namespace-uri()`, surface the resolved expanded-name fields directly
for cross-prefix queries.

### Prefix resolution

Before evaluation, the evaluator builds a flat `prefix → URI` map from
the document being queried. Walk order is depth-first; the first
xmlns / xmlns:prefix declaration encountered for a given prefix wins.
Reserved prefixes are seeded unconditionally:

| Prefix | URI |
| ------ | ----------------------------------------- |
| `xml` | `http://www.w3.org/XML/1998/namespace` |
| `cx` | `https://cx-home.org/ns/cx` |

For a name test `prefix:local`:

- If `prefix` is bound in the query map (or reserved), match by
 expanded name: an element matches iff its `(ns_uri, local)` equals
 the resolved query URI plus `local`.
- If `prefix` is not bound, match by source name verbatim. This
 preserves back-compat for namespace-free queries that happen to
 use colon-bearing identifiers (e.g., XML-Schema-style typed
 references that aren't actually namespaces).

Unprefixed name tests match `el.name` literally and do **not** pick
up any default namespace. Query authors decide whether namespacing
applies; a default-namespace document that wants to query its own
elements either declares an alias prefix in source or uses
`*[local-name()='foo']`.

### `local-name()` and `namespace-uri()`

```
//*[local-name()='circle']
//*[namespace-uri()='http://www.w3.org/2000/svg']
//*[namespace-uri()='http://www.w3.org/2000/svg' and local-name()='circle']
```

`local-name()` returns the post-colon part of the source name (or the
whole name when no colon is present). `namespace-uri()` returns the
resolved URI; the empty string `''` matches an element with no
namespace.

Only `=` and `!=` are supported; both functions return strings, and
ordered comparisons are not meaningful.

### Attribute predicates with prefixes

`[@prefix:local]` and `[@prefix:local=value]` apply the same
resolution rule. Per XML Namespaces 1.0 §6.2 (and namespaces.md §2.3),
unprefixed attributes are never in any namespace; an unprefixed query
attribute matches `attr.name` literally and ignores the document's
default namespace.

```
//link[@xl:href] xl: bound in document
//link[@xl:href='https://example.com']
//link[@href] unprefixed; literal match
```

### First-occurrence semantics under redeclaration

Documents that redeclare the same prefix in a nested scope produce a
single entry in the CXPath ns map (the outer occurrence wins). A
query `//p:item` against:

```cx
[outer xmlns:p=urn:outer
 [p:item v=1]
 [inner xmlns:p=urn:inner
 [p:item v=2]
 ]
]
```

resolves `p:` to `urn:outer` and matches the v=1 element only — the
v=2 element's `(urn:inner, item)` doesn't match the resolved query
URI. To query across both, use `//*[local-name()='item']` or query
each URI explicitly with `namespace-uri()`.

### Reserved prefix usage

`xml:` and `cx:` always resolve to their fixed URIs. Queries like
`//*[@xml:id]` or `//cx:lang` work without an explicit declaration.

---

## Relation to structural API

CXPath expressions without predicates or `//` are equivalent to the structural
API. Implementations MAY optimise these to direct structural calls.

| CXPath expression | Structural equivalent |
|----------------------|--------------------------------|
| `name` | `get(name)` |
| `a/b/c` | `at("a/b/c")` |
| `//name` | `find_all(name)` / `find_first(name)` |
| `//name[1]` | `find_first(name)` |
| `*` | `children()` |

---

## Error contract

**Invalid expression** — any syntax error in the CXPath string is a programming
error. Implementations MUST panic or raise an unrecoverable exception. CXPath
expressions are always program literals, never user-supplied data.

**No match** — not an error. `select` returns `none`, `select_all` returns `[]`.

**Type mismatch in predicate** — comparing a string attribute with `<`, `>`,
`<=`, `>=` is a programming error. Implementations MUST panic.

---

## v1.1 operators

### Union operator

```
//service | //product
```

Returns the flat Sequence concatenation of both operands. De-
duplicates per CXDM §4 equality (Element-node equality is by
structural equality, not identity); preserves document order over
the union (items from the left operand come first in source order,
then items from the right that weren't already present).

The union operator's operands MUST evaluate to Sequences of Node
Items. Mixing Node and Scalar operands is a type error.

Associative and commutative under equality:
```
a | b | c ≡ (a | b) | c ≡ a | (b | c)
```

### Sequence literal

```
(path1, path2, path3)
```

Equivalent to `path1 | path2 | path3`. The parens form is the
canonical way to enumerate paths when more than two are involved.
Source `((a, b), c, (d, e))` flattens at the sequence-level
boundary per CXDM §1.2 sequence-flat principle, yielding the
5-element sequence `(a, b, c, d, e)`.

### Array indexing

```
arr[N]
```

When `arr` evaluates to a CXDM Array Item, returns the N-th item
(1-based). `N` may be any expression returning an int; out-of-range
indices yield the empty Sequence.

Disambiguation from position predicates:

| LHS type | `expr[N]` meaning |
|---|---|
| Sequence of Element Nodes | Position predicate (v1.0): N-th element |
| Array Item (v1.1) | Array indexing: N-th item of the Array |
| Other | Type error |

The disambiguation is type-based on the LHS value, evaluated at
runtime. Static expressions where the LHS type is unambiguous
(e.g., a literal Array) compile to the obvious indexing operation.

### Map key access

```
m.key # bare-name access
m['key'] # string-literal access
m[expr] # general-key access via expression
```

When `m` evaluates to a CXDM Map Item, returns the value
associated with the key. The bare-name form `.key` is sugar for
the string-key form `['key']`. The expression form `[expr]` allows
non-string keys (int, date, etc.) per CXDM §2.5.

Missing key returns the empty Sequence (no error — consistent with
the v1.0 "missing attribute returns empty" convention).

### Composition

The v1.1 operators compose with the existing v1.0 path syntax:

```
//config.replicas # access Map's replicas key
//product[1].tags[2] # first product, second tag in its tags Array
(@a | @b).key # union, then key access (if the union is a Map)
```

---

## v1 scope

### In scope

- Descendant axis (`//name`, `a//b`)
- Direct child axis (`name`, `a/b/c`)
- Wildcard name test (`*`)
- Attribute predicates — existence, equality, inequality, numeric comparisons
- Boolean operators — `and`, `or`, `not()`
- Child existence predicate (`[name]`)
- Position predicates — `[n]`, `[last()]`
- String functions — `contains()`, `starts-with()`
- Namespace-aware predicates — prefixed name tests resolve via the
 document's xmlns map, plus `local-name()` and `namespace-uri()`
 predicate functions (see [§Namespace-aware queries](#namespace-aware-queries))
- Relative evaluation — `select` / `select_all` on Element as well as Document
- *(v1.1)* **Union operator** `path1 | path2` — flat-sequence
 concatenation, de-duplicated, document-order. See §Union operator
 below.
- *(v1.1)* **Sequence literal** `(path1, path2, path3)` — equivalent
 to union; reads naturally when listing multiple paths.
- *(v1.1)* **Array indexing** `expr[N]` when `expr` is an Array Item
 (CXDM `Array`, per `spec/cxdm.md §2.4`). 1-based; out-of-range
 yields the empty Sequence.
- *(v1.1)* **Map key access** `expr.key` and `expr['key']` when
 `expr` is a Map Item (CXDM `Map`, per `spec/cxdm.md §2.5`).

### Deferred

**Parent and sibling axes** — `parent::`, `ancestor::`, `following-sibling::`,
`preceding-sibling::` require upward traversal context.

Documents are immutable values (see `spec/api.md` §Immutability). Elements have
no `parent` field and are not connected to the tree after extraction. Parent and
sibling context is available to the CXPath evaluator during traversal — it
threads a parent stack internally — so these axes work correctly inside
expressions. They are not available as standalone API calls outside of
evaluation.

```
//p[parent::section] works — evaluator has context
//h2/following-sibling::p works — evaluator has sibling list
el.parent() does not exist — Elements are values
```

No AST changes required. Deferred to v2.

**Attribute as path endpoint** — `config/server/@port` returning the attribute
value `8080` directly rather than an Element. Deferred to v2 alongside a typed
return variant of `select`.

**Union operator** — *(promoted to v1.1 §D13.)* See
the In-scope list above.

**XQuery / FLWOR** — `for`/`let`/`where`/`return` expressions, aggregates
(`count()`, `sum()`), transforms. Out of scope for CXPath — separate spec if
pursued.
