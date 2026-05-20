# CX Data Model (CXDM) Specification
# Version: 1.1
# Date: 2026-05-11

The **CX Data Model (CXDM)** is the runtime value model shared by every member
of the CX expression family: CXPath (navigation, [`spec/cxpath.md`](cxpath.md))
and CXL (the CX Language for rendering, querying, and transformation,
[`spec/eval.md`](cxl.md)). It defines the values that predicates compare,
that directives bind to loop variables, that interpolations emit, and that
conformance fixtures match byte-identically across bindings.

### What's new in v1.1 (2026-05-11)

Per — Collection literals + CXL 1.0 refactor:

- **Three new Item kinds in §2**: Array, Map, and Sequence-as-Item, joining
 the existing Node and Scalar kinds. The container-vs-atom distinction is
 load-bearing for function signatures (D18).
- **§3 AST→CXDM mapping** gains rows for `ArrayNode`, `MapNode`,
 `SequenceNode` (per `spec/ast.md` v1.1).
- **§4.6 EBV rule** (was §4.5 in v1.0) extended for the new container kinds.
- **§4 Equality** extended for Array, Map, and Sequence-as-Item.
- **§8 Type coercion** clarifies the container ↔ sequence non-coercion rule.

v1.1 is **additive**: every well-formed v1.0 CXDM value remains a
well-formed v1.1 value with identical semantics. v1.1 values that use
the new Item kinds fail to evaluate on v1.0 readers (per capability bit
29 in `spec/abi.md`). See §10 for the version policy.

CXDM is the runtime/value analog of the parse AST in
[`spec/ast.md`](ast.md). The parse AST describes the static structure of a
parsed CX document; CXDM describes the dynamic values that flow through an
expression evaluator. The two are connected: every parse-AST node has a
direct CXDM value representation (§3), and every CXDM value can be emitted
back as a parse-AST construct (§7).

This spec is **normative** for any conformant expression-family evaluator
(per R3).
Implementations MUST produce identical evaluation results for the same input
across all bindings. Deviations are conformance failures.

---

## 1 — The sequence-flat principle

CXDM is built on one architectural commitment:

> **Every value is a sequence. A single value is a sequence of one. An empty
> result is a sequence of zero. Sequences do not nest.**

This is the XQuery/XPath 2+ data model property (XDM), adopted verbatim for
CX. It is the property that makes the expression family compose: there is
never a question of "is this one variant or a list of variants?" Both are
sequences.

### 1.1 Why sequence-flat

In a sequence-flat model:

- `//service` returns a sequence whether the document has 0, 1, or N services.
 Consumers iterate uniformly; there is no `null`-vs-`[]` edge case.
- `[?for v in xs ...]` works the same whether `xs` is a single element or a
 list — both are sequences.
- Concatenation is associative and total: `concat(a, b, c)` never raises
 "can't concatenate scalar to list" errors.
- A directive's return value is "what it evaluates to"; multiple
 emit operations naturally concatenate.

### 1.2 What sequence-flat is not

- **Not a list-of-lists model.** Concatenating two sequences produces one
 flat sequence, never a sequence containing two sub-sequences. Nesting is
 expressed via *items inside elements*, not via sequences-of-sequences.
- **Not a tuple model.** A sequence is ordered but every member has the same
 abstract type (Value, defined in §2). There are no fixed-arity heterogeneous
 tuples at the value level.
- **Not an arbitrary-graph model.** CXDM values form trees, not graphs.
 Identity-via-reference is not part of the model; equality is structural
 (§4).

---

## 2 — Value taxonomy

A **Value** is one of:

```
Value ::= Sequence
 | Item

Sequence ::= Item*

Item ::= Node | Scalar | Array | Map | Sequence-as-Item

Node ::= Element | Text | ScalarNode | Comment | PI | Directive | Document
Scalar ::= bool | int | float | string | date | datetime | bytes | null
Array ::= [ Item* ] (* preserves nesting *)
Map ::= { (ScalarKey → Item)* } (* keys are atomic Scalars *)
ScalarKey ::= bool | int | float | string | date | datetime | bytes
 (* null is not a valid key *)
Sequence-as-Item (* a Sequence value boxed into
 one Item slot inside an
 Array, a Map value, or a
 function-argument slot;
 does NOT flatten there *)
```

A `Sequence` is an ordered, finite, possibly-empty collection of `Item`s.
Sequences MUST NOT contain other Sequences directly **at a Sequence-level
boundary** — any operation that would concatenate sequence-of-sequences
into a containing Sequence flattens to a single Sequence (§2.6).

An `Item` is exactly one of five disjoint kinds: a **Node**, a **Scalar**,
an **Array**, a **Map**, or a **Sequence-as-Item**. The first two are
v1.0 kinds; the last three are introduced in v1.1 per
 §D18.

### 2.0 Container vs atom distinction

CXDM v1.1 makes a **load-bearing distinction** between *atom* Items
(Node, Scalar) and *container* Items (Array, Map, Sequence-as-Item):

- **Atoms** are leaf values from the value-model perspective. A
 Scalar `42` is a single Item; a Node is a single Item even though
 its tree contents are richly structured.
- **Containers** hold further Items by composition at the value
 level. `[1, 2, 3]` is one Array Item that holds three Scalar Items.
 `{name: 'a'}` is one Map Item that holds one (key, value) pair.

The distinction governs which operations apply where:

- Sequence operations (§5 — `count`, `head`, `tail`, `concat`,
 `distinct`, `union`, `intersect`, `except`) take `Sequence` and
 return `Sequence`. They **do not implicitly descend into a
 container**. `count(arr)` raises a type error; the user
 explicitly writes `count(flatten(arr))` or `count(items(arr))`
 to ask "how many items in this Array."
- Array operations (Array indexing, `array:size`, future
 `array:append`) take `Array` and treat it as a single value.
- Map operations (key access, `map:keys`, `map:get`) take `Map`.

Treating containers as new Scalar subtypes was considered and
rejected (per): it would erase the structural
distinction that makes function signatures type-check.

### 2.1 Node items

A Node is a CX tree value, corresponding directly to AST node types in
[`spec/ast.md`](ast.md). CXDM Node kinds:

| Node kind | AST type | Description |
|------------|---------------|----------------------------------------------|
| Element | Element | Named element with attrs and items |
| Text | Text | Character data, no type |
| ScalarNode | Scalar | Typed scalar appearing in element body |
| Comment | Comment | `[-text]` comment |
| PI | PI | Processing instruction |
| Directive | CXDirective | `[?cx ...]` file-level directive |
| Document | Document | Document root (sequence of top-level items) |

Each kind has the field set described in
[`spec/ast.md`](ast.md). CXDM does not redefine fields; it makes those
fields **accessible** to expressions and **comparable** under typed equality.

A Document Item, when used as a sequence member, is treated as a sequence
of its top-level children (the `elements` field), flattened. Documents
rarely appear as Items in expressions; they are usually the implicit
top-level context.

**BlockContent**, **Alias**, **RawText**, **EntityRef**, and the DTD-family
nodes (EntityDecl, ElementDecl, AttlistDecl, NotationDecl, ConditionalSect)
are not first-class Node kinds in CXDM v1. They appear in the parse AST and
are preserved through evaluation, but expressions cannot match against them
directly. (CXPath v1 already specifies "Elements only" per
[`spec/cxpath.md`](cxpath.md); CXDM aligns.)

### 2.2 Scalar items

A Scalar is a typed primitive value. Types match the auto-typing taxonomy
already in CX ([`spec/ast.md` §Scalar — Auto-typing rule](ast.md)):

| Type | Storage | Example sources |
|-----------|---------------------------|-------------------------|
| `bool` | true / false | `[active true]` |
| `int` | 64-bit signed integer | `[port 8080]` |
| `float` | IEEE 754 double | `[ratio 1.5]` |
| `string` | UTF-8 byte sequence | `[name auth]` |
| `date` | ISO 8601 calendar date | `[born 1980-01-01]` |
| `datetime`| ISO 8601 instant | `[at 2026-05-10T12:00Z]`|
| `bytes` | byte sequence (explicit) | `[data :bytes …]` |
| `null` | the null singleton | `[absent null]` |

Scalars in CXDM are **immutable values**. There is no notion of scalar
identity beyond structural equality. Two scalars of the same type and
value are indistinguishable.

**Type coherence with attribute values.** An attribute whose AST representation
has `dataType: int` evaluates to a CXDM Scalar of type `int`. An attribute
without a `dataType` field evaluates to a Scalar of type `string` with the
attribute's literal value. Auto-typing is performed at parse time
([`spec/ast.md`](ast.md)); the evaluator consumes the already-typed value.

### 2.3 What about attributes?

Attributes are **not** first-class Items in CXDM. They are accessed via the
`@name` axis (per CXPath) on an Element, which produces a Scalar — the
attribute's typed value. The same attribute referenced twice produces two
equal Scalars, not the same Item identity (because Scalars have no
identity).

Rationale: making attributes Items would create two ways to navigate to
the same data (attribute-as-Item and attribute-via-axis), require the
sequence type to discriminate between attribute-bearing and child-bearing
contexts, and complicate equality. The XPath/XDM approach (attributes are
nodes but the axis is special) is technically more flexible; for CXDM v1
the simpler "attributes evaluate to Scalars" model suffices for every
template and CXPath use case.

CXDM v2 MAY promote attributes to first-class Node items if user-defined
functions in CXL v0.9.0+ need to pass attributes around as values; this is a
forward-compatible extension because no v1 syntax produces an attribute
Item directly.

### 2.4 Array items

An **Array** is an ordered, finite, possibly-empty container of Items
that **preserves structure**. Unlike a Sequence, an Array does not
auto-flatten — it is a single Item from the value-model perspective.

Source-text form: `[a, b, c]` per
[`spec/grammar.ebnf`](grammar.ebnf) (the array-literal production
introduced at v0.6.0). The bracket form is disambiguated from element
syntax by the presence of a comma before any `=` (per §D1).

Array characteristics:

| Property | Value |
|---|---|
| Item kind | Container |
| Order | Preserved |
| Item types | Any CXDM Item (Node, Scalar, Array, Map, Sequence-as-Item) |
| Nesting | Preserved: `[[1,2], [3,4]]` is a 2-Item Array whose items are 2-Item Arrays |
| Duplicate items | Permitted (no dedup) |
| Empty form | `[]` |
| Identity | Structural (no reference identity) |

Indexing is **1-based** to match CXDM Sequence conventions and CXPath
predicate-index conventions (per [`spec/cxpath.md`](cxpath.md) §D13).
`arr[1]` returns the first item; out-of-range index returns the empty
Sequence.

A Sequence containing one Array is **distinct** from the Items of
that Array. `(arr)` where `arr = [1, 2, 3]` is a Sequence of length 1
holding one Array Item, **not** a Sequence of length 3 holding three
Scalars. This is the load-bearing property that lets Arrays serve as
the canonical positional-slot container for CXL directives without
collapsing into the surrounding directive's Sequence value.

### 2.5 Map items

A **Map** is an unordered, finite collection of (key, value) pairs.
Keys are atomic Scalars; values are any CXDM Item.

Source-text form: `{k: v, k: v, …}` per
[`spec/grammar.ebnf`](grammar.ebnf) (the map-literal production
introduced at v0.6.0).

Map characteristics:

| Property | Value |
|---|---|
| Item kind | Container |
| Key types | Atomic Scalars: `bool`, `int`, `float`, `string`, `date`, `datetime`, `bytes` |
| `null` as key | **Not permitted** — parse error W014 / evaluation error |
| Duplicate keys | **Not permitted** — parse error W014 (per §D4) |
| Value types | Any CXDM Item |
| Runtime order | Insertion order preserved (per Q6 / §D14) |
| Canonical order | Lexicographic Unicode order of canonical-key serialization (per [`spec/canonical.md`](canonical.md) §D14) |
| Empty form | `{}` |
| Identity | Structural (no reference identity) |

**Key equality** is the §4.1 atomic-equality rule applied to the
key Scalar. Numeric widening (§4.1 cross-type `int` ↔ `float`) does
**not** apply to map-key equality: `{1: 'a'}` and `{1.0: 'a'}` are
**distinct maps** at runtime, even though `1 = 1.0` evaluates true
in expression position. This avoids collision-by-coercion and
matches XQuery 3.1 map-key semantics.

**Bare-name key sugar.** Source-text `{name: 'a'}` is sugar for
`{'name': 'a'}` — a bare unquoted name parses as a string key
identical to the quoted form. The two forms produce the same Map
value.

### 2.6 Sequence-as-Item

A **Sequence-as-Item** is a Sequence value boxed into a single Item
slot. It exists in exactly three positions:

1. As an item inside an Array: `[(a, b), c]` — the inner `(a, b)`
 is a 2-Item Sequence held as one Item of the outer 2-Item Array.
2. As the value of a Map entry: `{key: (a, b, c)}` — the
 3-item Sequence is the value bound to `key`.
3. As an argument to a function or directive that names a
 Sequence-typed formal parameter (v0.9.0+ user-defined functions).

A Sequence-as-Item does **not auto-flatten** because the surrounding
container (Array, Map value slot, function-argument slot) is not a
Sequence-level position. The sequence-flat rule (§1) applies at
Sequence-into-Sequence boundaries only.

Example:

```
(1, (2, 3), 4) ≡ (1, 2, 3, 4) # Sequence boundary; flattens
[1, (2, 3), 4] ≡ Array of 3 items: 1, Sequence(2, 3), 4 # Array boundary; preserved
{k: (2, 3)} ≡ Map { k → Sequence(2, 3) } # Map-value boundary; preserved
```

Sequence-as-Item is a **distinct Item kind** from Array even when
both wrap "three items in a list." The difference is that Sequences
auto-flatten on Sequence-level concatenation while Arrays do not;
the type-level distinction preserves that downstream behavior.
Conversion is explicit: `array(seq)` boxes a Sequence into a
1-element Array containing it as Sequence-as-Item, while a notional
`flatten(arr)` unrolls an Array into a Sequence (CXL 3.1+ surface).

---

## 3 — AST-to-CXDM mapping

This table is normative. An evaluator MUST map each parse-AST construct to
the corresponding CXDM value as specified.

| AST construct (per ast.md) | CXDM value |
|--------------------------------------|-----------------------------------------------------------|
| Document | Sequence of its `elements` (each mapped per this table) |
| Element | Element Node (one-Item Sequence in any context) |
| Attribute with `dataType=T` | Scalar of type T (not directly an Item; via `@name` axis) |
| Attribute without `dataType` | Scalar of type `string` |
| Text | Text Node (or, if all-whitespace per `xml:space` rules, may be elided per evaluator policy) |
| Scalar (AST node in element body) | ScalarNode Node containing a Scalar of the AST `dataType` |
| Comment | Comment Node |
| PI | PI Node |
| CXDirective | Directive Node |
| BlockContent | Sequence of the BlockContent's items, flattened |
| Alias (Parse AST) | Resolved before CXDM mapping |
| RawText, EntityRef, DTD-family | Opaque Node (preserved, not introspectable in v1) |
| **SequenceNode** *(v1.1)* | Sequence Value (auto-flattens at Sequence-level positions; preserved as Sequence-as-Item Item inside Array / Map value / function-arg slots per §2.6) |
| **ArrayNode** *(v1.1)* | Array Item containing the items mapped per this table |
| **MapNode** *(v1.1)* | Map Item containing the (key, value) pairs mapped per this table; keys are Scalar values per §2.5 |

The mapping is total: every well-formed parse-AST node has exactly one
CXDM representation. Evaluators MUST NOT lose information in the mapping
direction (parse AST → CXDM); the inverse direction (§7) may be lossy
only where explicitly noted.

---

## 4 — Equality and comparison

### 4.1 Atomic equality

For two Scalars `a` and `b`:

- If both are `null` → equal.
- If types are the same → value equality (`bool` direct; `int` direct;
 `float` IEEE-754 with `NaN ≠ NaN` and `+0.0 == -0.0`; `string` byte-by-byte
 on the UTF-8 representation; `date` / `datetime` on the canonical ISO 8601
 normalized form; `bytes` byte-by-byte).
- If types differ but both are numeric (`int` ↔ `float`) → numeric equality
 after widening the `int` to `float`. (This is the same rule CXPath uses
 per [`spec/cxpath.md`](cxpath.md) §scalar comparison.)
- All other cross-type comparisons → not equal.

### 4.2 Node equality

Two Element Nodes are equal iff:

- Their `(ns_uri, local)` qualified names are equal (per
 [`spec/canonical.md`](canonical.md) namespace handling).
- Their attribute *sets* are equal (same names, same values; attribute
 order does not affect equality).
- Their item sequences are equal element-wise, in order.

Two Text Nodes are equal iff their `value` strings are byte-identical.
Two ScalarNode Nodes are equal iff their wrapped Scalars are equal (§4.1).
Two Comment / PI / Directive Nodes are equal iff their AST-level
representations match field-for-field.

Cross-kind Node comparisons are not equal.

### 4.3 Container equality *(v1.1)*

**Array equality.** Two Array Items are equal iff they have the same
length and their items are pairwise equal in order, recursively under
this section's rules. Arrays do not auto-flatten for equality; an
Array of one Array is **not** equal to its inner Array.

**Map equality.** Two Map Items are equal iff they have the same key
set (compared under §4.1 atomic equality, with the numeric-widening
exception noted in §2.5 — map-key equality is **type-strict**) and
their values at each key are pairwise equal under this section's rules.
Map equality is **order-independent**: `{a: 1, b: 2}` and `{b: 2, a: 1}`
are equal.

**Sequence-as-Item equality.** Two Sequence-as-Item Items are equal iff
their wrapped Sequences are equal under §4.4.

Cross-kind Item comparisons (e.g., Array vs Sequence-as-Item, Array vs
Map, container vs Scalar, container vs Node) are **not equal**. There
is no implicit unwrapping for equality.

### 4.4 Sequence equality

Two Sequences are equal iff they have the same length and their Items are
pairwise equal in order under §4.1 (Scalars), §4.2 (Nodes), §4.3
(containers).

### 4.5 Ordering

Total order is defined only on Scalars of the same numeric or temporal type
(`int`, `float`, `date`, `datetime`). Other Scalar types and Node Items
have no total order at the language level — sort operations on
heterogeneous Sequences require an explicit key projection (v0.9.0+).

CXPath comparison operators (`<`, `>`, `<=`, `>=`) require numeric Scalars
on both sides per [`spec/cxpath.md`](cxpath.md); CXDM inherits this rule
and panics on order-comparing non-orderable Scalars.

### 4.6 The Effective Boolean Value (EBV) rule

For directives that take a "condition" (`[?if cond …]`, multi-branch
`?if` conditions §D7), the truthiness of a Value is
determined by this rule, applied in order:

1. If the Value is the empty Sequence → false.
2. If the Value is a Sequence of length 1 containing a Scalar:
 - `bool` → that bool's value.
 - `string` → length > 0.
 - `int` / `float` → value != 0 (and not NaN, for float).
 - `null` → false.
 - `date` / `datetime` / `bytes` → true.
3. If the Value is a Sequence of length 1 containing a Node → true
 (Node existence is truthy).
4. *(v1.1)* If the Value is a Sequence of length 1 containing an
 **Array** → true iff the Array is non-empty (length > 0). Empty
 array `[]` → false.
5. *(v1.1)* If the Value is a Sequence of length 1 containing a
 **Map** → true iff the Map is non-empty (length > 0). Empty map
 `{}` → false.
6. *(v1.1)* If the Value is a Sequence of length 1 containing a
 **Sequence-as-Item** → EBV applied recursively to the wrapped
 Sequence (per rules 1–5).
7. If the Value is a Sequence of length > 1 → true.

This is the same rule XPath uses for its EBV computation, adapted to
CXDM's type set and extended in v1.1 with the container rules 4–6.
It is the rule that makes `[?if //service …]` mean "if any service
exists", `[?if @debug …]` mean "if the debug attribute exists and is
truthy", and `[?if @items …]` mean "if the items array is non-empty"
when `@items` is an Array-typed attribute.

The container rules (4–6) follow the **empty-is-falsy** convention
shared by Python lists/dicts, JSON-template engines, and YAML/TOML
processors. CX deliberately diverges from XQuery 3.1, which raises a
type error on EBV(array)/EBV(map); CX's pragmatic rule reads more
naturally in template position and aligns with the
empty-Sequence-is-false case (rule 1).

---

## 5 — Sequence operations

The following operations are total over CXDM Sequences. Implementations
MUST provide them; the surface (filter functions, FLWOR clauses, etc.)
appears in CXL 1.0 (templating-oriented subset, ships at CX release
v0.7.0) and CXL 3.1+ (full language with FLWOR, maps, arrays, arrow
operator, ships at CX release v0.9.0+).

| Operation | Signature | Notes |
|------------------------|-------------------------------------------------|-------|
| `length(seq)` | `Sequence → int` | Count of items. |
| `empty(seq)` | `Sequence → bool` | True iff length == 0. |
| `concat(s1, s2, …)` | `Sequence × … → Sequence` | Flattening concat. |
| `index(seq, n)` | `Sequence × int → Item` | 1-based; out-of-range is empty. |
| `head(seq)` | `Sequence → Sequence` | First item or empty. |
| `tail(seq)` | `Sequence → Sequence` | All but first. |
| `reverse(seq)` | `Sequence → Sequence` | Order-reverse. |
| `distinct(seq)` | `Sequence → Sequence` | Order-preserving dedup under §4 equality. |
| `union(s1, s2)` | `Sequence × Sequence → Sequence` | `distinct(concat(s1, s2))`. |
| `intersect(s1, s2)` | `Sequence × Sequence → Sequence` | Items in both, source-1 order. |
| `except(s1, s2)` | `Sequence × Sequence → Sequence` | Items in s1 not in s2. |

**Surface mapping:**

- CXL 1.0 exposes `length`, `empty`, `index` (via predicate-style `[1]`),
 `head` (via `[?first xs]`), `tail` (via `[?rest xs]`), `concat` (implicit
 in directive body sequencing).
- CXL 3.1+ exposes the full set as built-in functions plus FLWOR
 composition (`[?for x in seq :where=[…] :order=[…] :return=[…]]`). The
 `order` attribute name follows XQuery 3.1's preferred spelling — short,
 unambiguous, and reads naturally in attribute position.

Implementations MUST evaluate these with the same semantics whether
called from CXL evaluation contexts or future CXPath function-call
positions.

### 5.1 Container operations vs Sequence operations *(v1.1)*

The §5 operations are **Sequence-typed** in both argument and return
position. Per §2.0 (container-vs-atom distinction), they do **not**
implicitly descend into Array, Map, or Sequence-as-Item values.

| Operation called as | Behavior |
|---|---|
| `length(seq)` where `seq` is a Sequence | Returns int item-count of the Sequence (v1.0) |
| `length(arr)` where `arr` is an Array | **Type error** — explicit `length(items(arr))` required |
| `length(map)` where `map` is a Map | **Type error** — explicit `length(map:keys(map))` required |
| `length((arr))` — Sequence holding one Array Item | Returns 1 (the Sequence has one Item; that Item happens to be an Array) |

The same rule applies to every §5 operation: arguments are Sequences,
not containers. CXL 3.1+ will add container-typed operations
(`array:size`, `array:get`, `array:append`, `map:size`, `map:keys`,
`map:get`, `map:put`, `flatten`, `items`) in a parallel `array:` /
`map:` namespace. At v0.6.0 / CXL 1.0, the surface exposes only
the Sequence operations of §5 plus Array/Map indexing per
[`spec/cxpath.md`](cxpath.md) §D13.

---

## 6 — Filter pipeline composition

The expression family composes operations via **bracket-nested directive
calls**, not infix pipes. A filter `f` applied to a value `x` is written:

```
[f x] # length applied to x
[upper [trim x]] # upper(trim(x))
[where xs [@stock > 0]] # filter xs by predicate
```

This is the most CX-native composition shape — each call is a normal CX
node with its arguments as children. There is no separate "filter syntax"
to learn.

CXL 3.1+ MAY introduce arrow-operator sugar (`xs => trim => upper`,
mirroring XQuery 3.1's `=>`) and CXL 4.0 MAY introduce pipeline-
operator sugar (`xs |> trim |> upper`, mirroring XQuery 4.0's `|>`);
both desugar to the bracket form (`[?upper [?trim xs]]`). CXL 1.0
has neither and uses bracket-nested calls exclusively.

A small fixed set of built-in filters is frozen at CXL 1.0; see
[`spec/eval.md` §4](cxl.md). Host-binding-pluggable extensions follow
the v0.6.0 rule (frozen core, opt-in extensions,
`[?cx output-strict]` rejects non-core).

---

## 7 — CXDM-to-AST emission

The inverse direction (expression evaluator output → emittable parse AST)
is required for renderer output, query result serialization, and
`cx render` / `cx query` CLI surface.

The mapping is:

| CXDM value | Parse-AST emission |
|-------------------------|---------------------------------------------------|
| Empty Sequence | Nothing emitted |
| Sequence of length 1 | Emit the contained Item |
| Sequence of length > 1 | Emit Items in order, no wrapping |
| Element Node | Element AST node (round-trip-faithful) |
| Text Node | Text AST node |
| ScalarNode Node | Scalar AST node |
| Other Node kinds | Corresponding AST node |
| Bare Scalar (not in a Node) | Context-dependent (see §7.1) |
| Array Item *(v1.1)* | ArrayNode AST node (canonical form `[a, b, c]` per [`spec/canonical.md`](canonical.md) §D14); format-specific rendering §D12 |
| Map Item *(v1.1)* | MapNode AST node (canonical form `{k: v, …}` keys lexicographically ordered per §D14); format-specific rendering §D12 |
| Sequence-as-Item *(v1.1)* | SequenceNode AST node (canonical form `(a, b, c)` per §D14); preserved at Array-item / Map-value positions per §2.6 |

### 7.1 Bare scalars in emission contexts

When an expression produces a bare Scalar (a value that is not wrapped in
a Node), the emission depends on the context where the value lands:

| Context | Emission |
|------------------------------------------|-------------------------------------------|
| `[?=expr]` interpolation in program text | Scalar's canonical text representation |
| `:attr=[expr]` directive attribute value | Scalar with its type (`dataType` carried) |
| Element body position (in CX-to-CX out) | Wrap as a Scalar AST node |
| FLWOR `:return` clause output (CXL 3.1+) | Wrap as a Scalar AST node |

Canonical text representations follow
[`spec/canonical.md`](canonical.md) §scalar formatting:

- `bool` → `true` / `false`
- `int` → decimal, no leading zeros, optional sign
- `float` → shortest round-trip decimal (Grisu / Ryū family)
- `string` → UTF-8 literal (no quoting in text-emission context;
 quoting applies in CX-emission context per the CX grammar)
- `date` → ISO 8601 calendar date
- `datetime` → ISO 8601 instant in UTC (`Z` suffix)
- `bytes` → base64 standard alphabet, no padding stripping
- `null` → `null`

### 7.2 Container values in emission contexts *(v1.1)*

When an expression produces a container (Array, Map, Sequence-as-Item)
the emission depends on the context where the value lands:

| Context | Emission |
|------------------------------------------|-------------------------------------------|
| `[?=expr]` interpolation, output format CX | Canonical CX form per §D14 (`[a, b, c]`, `{k: v}`, `(a, b, c)`) |
| `[?=expr]` interpolation, output format ≠ CX | Per-format rendering §D12 (JSON `[…]` / `{…}`, XML `<arr>`/`<map>` wrappers, YAML / TOML / MD per table) |
| `:attr=[expr]` directive attribute value (CX-emission) | Canonical CX form per §D14, embedded in attribute-value position |
| Element body position (CX-emission) | Emit as the corresponding AST node (ArrayNode / MapNode / SequenceNode) |
| FLWOR `:return` clause output (CXL 3.1+) | Per the FLWOR result-binding context (CXL 3.1 spec) |

Format-specific container rendering (JSON / XML / YAML / TOML / MD)
is normative in [`spec/conversions.md`](conversions.md) once that spec
is amended §D12. CXDM is the value model; format
rendering is the conversions.md responsibility.

### 7.3 Lossy emission cases (normative)

These cases lose information; evaluators MUST document them per their
output channel:

- Document Node emitted into an Element body position: the Document's
 `prolog` / `doctype` fields are not preserved (a Document only retains
 prolog/doctype as a top-level value).
- Multiple Element Nodes emitted into an attribute value position: not
 representable; evaluator MUST raise an evaluation error.
- A Sequence containing a mix of Node kinds emitted to a non-CX
 output format: per the target format's lossy semantics in
 [`spec/conversions.md`](conversions.md).

---

## 8 — Type coercion (normative)

The expression family is **strictly typed**. Implicit coercion is permitted
in exactly these contexts:

### 8.1 Numeric widening

`int` widens to `float` when one operand of a numeric operation
(`+`, `-`, `*`, `/`, `<`, `>`, `<=`, `>=`, `=`, `!=`) is `float` and the
other is `int`. The result is `float`. No narrowing coercion exists; an
explicit `int(x)` filter (v0.9.0+) truncates.

### 8.2 String concatenation in text-emission contexts

In `[?=expr]` interpolation, any Scalar (or single-Node Sequence) is
converted to its canonical text representation per §7.1. This is the
only implicit "stringification."

### 8.3 EBV in conditional contexts

Per §4.6. Implicit only in `[?if …]` test positions and predicate
boolean contexts.

### 8.4 What is not implicit

The following raise an evaluation error rather than coercing silently:

- Comparing a `string` Scalar with a numeric Scalar using `<` / `>` /
 `<=` / `>=` (same rule as CXPath).
- Comparing values of incompatible non-numeric types with `=` / `!=`
 (returns false rather than coercing — values of different types are
 not equal).
- Passing a Scalar where a Node Sequence is required, or vice versa,
 except where §7.1 specifies the conversion.
- *(v1.1)* Passing an Array, Map, or Sequence-as-Item where a
 Sequence is required by a §5 operation. The container-vs-atom
 distinction (§2.0) is strict; convert explicitly via
 `flatten(arr)` / `items(arr)` / `map:values(m)` (CXL 3.1+
 surface).
- *(v1.1)* Passing a Sequence where an Array is required (e.g., to
 Array indexing `arr[N]`). Convert explicitly via `array(seq)`
 (CXL 3.1+).
- *(v1.1)* Using a container in an arithmetic, comparison, or
 ordering operation. Containers participate in equality (§4.3) and
 EBV (§4.6) only.

Error reporting follows [`spec/eval.md` §2.5](cxl.md) for CXL.

---

## 9 — Worked examples

CXL surface syntax in §9 examples is the ** / CXL 1.0
at v0.6.0** form: every directive is `[?Name [arg, arg, …]]` with
a positional-array slot list. Earlier `:then=` / `:else=`
attribute forms are not valid.

### 9.1 Sequence flattening

```
[?for [v, //variant, [?=v/@sku]]]
```

`//variant` returns a Sequence of N Element Nodes. `[?for]` binds `v`
to each item of the second slot in order, evaluates the third slot
(`[?=v/@sku]`) per iteration. `[?=v/@sku]` produces a Scalar (the
typed `sku` attribute) for each iteration. The directive's value is
the concatenation of those Scalars, in document order, flattened —
one Sequence of N Scalars.

### 9.2 Empty results

```
[?if [//variant[@stock > 0], Some in stock, None]]
```

`//variant[@stock > 0]` may return a 0-, 1-, or N-element Sequence.
The EBV rule §4.6 applies to the first slot: empty → false (third
slot renders), non-empty → true (second slot renders). No `null`
handling; no "0 vs 1 vs many" branching.

### 9.3 Cross-type comparison

```
[?if [@port = 8080, exact match]]
```

`@port` evaluates to a Scalar typed `int` (per ast.md auto-typing).
The literal `8080` is parsed as Scalar `int 8080` per CXPath scalar
parsing. `=` compares two ints → equal iff values match.

```
[?if [@port = '8080', unreachable]]
```

`@port` is `int`; `'8080'` is `string`. Cross-type non-numeric equality
is false (§8.4). The branch never fires. This is a programming bug,
not a runtime error; CXPath's existing behavior applies.

### 9.4 Document order in sequences

```
[?for [s, //service, [item :name=[?=s/@name]]]]
```

`//service` returns services in **document order** (depth-first per
[`spec/cxpath.md`](cxpath.md) §depth-first order). The Sequence
ordering is the same as document order. Emission preserves order.

### 9.5 Array vs Sequence distinction *(v1.1)*

```
(1, 2, 3) # Sequence of 3 Scalar Items
[1, 2, 3] # Sequence of 1 Item (an Array of 3 Scalars)
(1, (2, 3), 4) # Sequence of 4 Scalars — inner seq flattens at Sequence boundary
[1, (2, 3), 4] # Sequence of 1 Item; the Array has 3 items: Scalar, Sequence-as-Item, Scalar
{name: 'alice', age: 30} # Sequence of 1 Item (a Map of 2 entries)
```

The first two values look interchangeable at a glance but compose
differently. `concat((1,2,3), (4,5))` yields `(1,2,3,4,5)` —
five-item Sequence. `concat([1,2,3], [4,5])` is a type error
(`concat` operates on Sequence values, not Array values; see §5).
The user explicitly writes `concat(flatten(arr1), flatten(arr2))`
to merge Arrays into one Sequence, or `array(concat(arr1.items,
arr2.items))` (CXL 3.1+) to concatenate Arrays into a new Array.

### 9.6 Map key types *(v1.1)*

```
{name: 'alice', 1: 'one', 2026-05-11: 'today'}
```

Map keys are atomic Scalars per §2.5. Three keys here: the string
`'name'` (bare-name sugar), the int `1`, and the date `2026-05-11`.
Key equality is type-strict — `{1: 'a'}` and `{1.0: 'a'}` are
distinct Maps even though `1 = 1.0` is true in expression position.

---

## 10 — Version policy

| Version | CXDM change |
|---------|------------------------------------------------------------------------|
| v1.0 | Sequence-flat, two Item kinds (Node, Scalar), CXPath-aligned semantics |
| v1.1 | **This spec** — adds Array, Map, Sequence-as-Item as Item kinds §D18. Additive: every v1.0 value remains a v1.1 value with identical semantics. v1.1 values using the new Item kinds fail on v1.0 readers per capability bit 29 ([`spec/abi.md`](abi.md)). |
| v1.2+ | Reserved for additive extensions: new filter built-ins, new Scalar types only by spec revision |
| v2.0 | Reserved for promoting attributes to first-class Node items if CXL v0.9.0+ user-defined-function ergonomics require it (forward-compatible from v1 because v1 syntax does not produce attribute Items) |

A v1.0-conformant implementation MUST reject v1.1 collection Item
kinds rather than silently misinterpret them; a v1.x-conformant
implementation MUST reject a v2-only construct similarly. The
version is implicit in the CX format version declared per
[`spec/governance.md`](governance.md) and is signalled at the
binding-ABI level by capability bit 29 (set ⇒ v1.1, clear ⇒ v1.0-only).

---

## 11 — References

- [`spec/ast.md`](ast.md) — parse AST; CXDM is the runtime/value analog.
- [`spec/cxpath.md`](cxpath.md) — navigation sublanguage; CXDM is its
 value model.
- [`spec/eval.md`](cxl.md) — CXL language spec; consumes CXDM.
- [`spec/canonical.md`](canonical.md) — canonical scalar formatting,
 namespace-aware equality.
- [`spec/conversions.md`](conversions.md) — format-emission semantics
 CXDM-to-AST output composes with. §D12 normative for
 container emission per output format once conversions.md is
 amended.
- [`spec/grammar.ebnf`](grammar.ebnf) — source-text productions for
 collection literals (v1.1).
- [`spec/canonical.md`](canonical.md) — canonical-form rules for
 containers (§D14 sort order, formatting).
- [`spec/abi.md`](abi.md) — capability bit 29 signalling v1.1 support.
- —
 the architectural commitment this spec implements.
- —
 the v1.1 amendment driver: collection literals + CXL 1.0 refactor.
- XPath/XQuery Data Model (XDM) — the prior art CXDM is structurally
 modeled after, adapted to CX's typed-attribute system and bracket
 syntax. v1.1 sequence-flat + array-nested + map-keyed split mirrors
 XQuery 3.1's three primitive container types.
