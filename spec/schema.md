# CX Schema Language Specification (`.cxs`)
# Version: 0.6.1 (Draft)
# Date: 2026-05-11

### What's new in v0.6.1 (2026-05-11)

Per §D15:

- **`arr[T]`, `seq[T]`, `map[K, V]` content-shape productions**
 added to §4 for CXDM v1.1 container Items. Compose recursively
 with all scalar / node types.
- **`:T[]` legacy form** marked deprecated; remains valid as a
 parse-time desugar to `arr[T]`. Canonical emit produces `arr[T]`.
- Per §R3 the schema validator's 20/20 spec-rules
 conformance is to be re-audited under the new productions
 (~1 day of work). Re-audit pending Phase 2 implementation.

This document specifies the CX schema language. A schema (`.cxs`
file) describes the shape of a target CX document: which elements
may appear, what attributes they may carry, what their content
shape is, and what constraints values must satisfy.

The approach is recorded in 
schemas are themselves CX documents. The schema language defines
a reserved vocabulary of element names that, when they appear at
specific positions inside a schema document, are interpreted as
shape declarations rather than as data.

This document is the normative grammar and semantics.

> **Note on syntax sketch.** illustrated the
> vocabulary using a `+` sigil and longer names (`[+element ...]`,
> `[+attribute ...]`, `:cardinality='1..1'`, etc.). That sketch is
> *not* normative for two reasons: (1) `+` is not a legal
> NameStartChar in CX (`spec/grammar.ebnf §87`), so an element
> literally named `+attribute` cannot exist; (2) per design review,
> the schema vocabulary is uniformly abbreviated for read-density.
> This spec uses plain abbreviated reserved names (`elem`, `attr`,
> `body`, `check`, `frag`) and abbreviated constraint sigils
> (`:req`, `:opt`, `:def`, `:card`, `:pat`, `:len`, `:scalar`,
> `:elem`). The *intent* (CX-native schema vocabulary)
> stands; only the spelling differs.

---

## 1 — Introduction

A `.cxs` file is a CX document. It parses with the standard CX
parser. The schema validator interprets the parsed AST under the
rules in this document.

**File naming**: schemas use the `.cxs` extension by convention.
The validator does not require the extension; any CX document
that begins with `[?cx schema-of <name>]` is treated as a schema.

**Schema versioning**: the v0.6.0 schema language is "version
0.6"; future revisions add a `[?cx schema-version 0.7]` directive
when breaking changes occur. v0.6.0 schemas are forward-compatible
within the v0.6.0 → 1.0 stability window per the project's
versioning policy (`spec/governance.md §9`).

**Validator entry points**:

- `cx validate <doc.cx> --schema=<schema.cxs>` — CLI subcommand.
 Flags: `--fail-on=info|warn|error|none` (default `error`,
 matches `cx lint`); `--mode=open|strict|closed` overrides the
 schema-mode directive; `--apply-defaults` inserts `:def=...`
 attribute values into the validated output.
- `cx_validate(doc_bytes, schema_bytes, err_out)` — C ABI symbol
 (added at v0.6.0); `cx_validate_apply_defaults` for the
 defaults-applying variant. Both have `_with_len` companions per
 [`spec/abi.md §2.14`](abi.md). Diagnostic wire format normative
 per §10.2 below.
- Per-binding `validate(doc, schema)` and
 `validate_with_defaults(doc, schema)` — bound across all 9
 language bindings; thin wrappers over the C ABI so RE2 pattern
 semantics (S008) stay identical across bindings.
- Document-embedded `[?cx schema=schema.cxs]` directive — opts
 the document into validate-on-parse against the named schema.

---

## 2 — Schema document structure

A schema document begins with at least one directive identifying
it as a schema:

```cx
[?cx schema-of book ]
```

The argument to `schema-of` is the name of the **root element** of
the target document. A schema may declare exactly one root.

After the directive, the schema body is a sequence of **type
declarations** — top-level elements whose names match elements
that appear in the target document. The element name in the schema
is the type name being defined.

Optional companion directives at the top:

- `[?cx schema-name '<title>']` — human-readable schema name used
 in diagnostics.
- `[?cx schema-version <ver>]` — explicit schema-language version.
 Optional; defaults to 0.6 when absent.
- `[?cx schema-mode open]`, `[?cx schema-mode strict]`, or
 `[?cx schema-mode closed]` — see §9. **Default is `open`** per
 .

### Example schema

```cx
[?cx schema-of book ]
[?cx schema-name 'Book schema v1']

[book
 [body :elem]
 [attr id :string :req]
 [elem title :card='1..1']
 [elem author :card='1..*']
 [elem chapter :card='0..*']
]

[title
 [body :string]
]

[author
 [body :string]
]

[chapter
 [body :elem]
 [attr number :int :req :range='1..*']
 [elem title :card='1..1']
 [elem body :card='1..1']
]

[body
 [body :mixed]
 [elem para :card='0..*']
 [elem emphasis :card='0..*']
]

[para
 [body :mixed]
 [elem emphasis :card='0..*']
]

[emphasis
 [body :string]
]
```

This schema validates documents whose root is `<book>` containing
one or more authors, exactly one title, and zero or more chapters,
each with attribute `number`, exactly one title, and exactly one
body containing a sequence of mixed-content paragraphs.

### Reserved schema-vocabulary names

These element names are reserved when they appear as **direct
children of a type declaration** in a schema document:

| name | meaning |
| ---- | ------- |
| `body` | declares the body shape (§4) |
| `attr` | declares an attribute on the type being defined (§5) |
| `elem` | declares a child element (§6) |
| `check` | declares a custom validation constraint (§7) |
| `frag` | reserved for inlined fragment definitions (§8) |

The reservation applies **only** within a schema document, only at
the position "direct child of a type declaration." Target documents
may use these names freely as user data.

---

## 3 — Type declaration anatomy

A type declaration is a top-level element in a schema body whose
name is the target-element type being defined:

```cx
[<type-name>
 [body <body-shape> <constraints>]?
 [attr <name> :<type> <constraints>]*
 [elem <name> <constraints>]*
 [check <expr>]*
]
```

Order is significant for readability but not for semantics:
the validator collects all four child kinds and applies them as a
set. `[body ...]` may appear at most once per type declaration
(or be omitted, defaulting to `[body :elem]` if any
`[elem ...]` declarations exist, otherwise `[body :none]`).

A type declaration whose name matches a reserved schema-vocabulary
name (e.g., a target document with elements literally named
`content`) is permitted but produces a diagnostic-clarity warning;
adopters who hit this rename the target element or rename in the
target schema.

---

## 4 — Content shape

The `[body :<shape> <constraints>]` declaration specifies what
form the element's body takes. Exactly one shape per declaration.

Shapes:

| `:shape` | meaning | example body |
| -------- | ------- | ------------ |
| `:none` | empty body — `[name]` only | `[hr]` |
| `:string` | scalar string body | `[title 'My Book']` |
| `:int` / `:i8` / `:i16` / `:i32` / `:i64` | sized integer | `[count :i32 42]` |
| `:u8` / `:u16` / `:u32` / `:u64` | sized unsigned | `[port :u16 8080]` |
| `:f16` / `:f32` / `:f64` / `:float` | float | `[ratio :f64 0.5]` |
| `:bool` | boolean | `[active true]` |
| `:decimal` | arbitrary-precision decimal | `[price :decimal 19.99]` |
| `:bigint` | arbitrary-precision integer | `[id :bigint 12345...]` |
| `:bytes` | base64-encoded bytes | `[blob :bytes 'aGVsbG8=']` |
| `:date` | ISO 8601 date | `[d :date 2026-05-07]` |
| `:datetime` | ISO 8601 datetime | `[t :datetime 2026-05-07T12:00:00Z]` |
| `:time` | ISO 8601 time | `[t :time 12:00:00]` |
| `:null` | explicit null | `[x :null]` |
| `:scalar` | any scalar type (validator accepts) | any |
| `:<T>[]` | typed array *(legacy; v1.1 prefers `arr[T]`)* | `[ports :i32[] [8080 8081 8082]]` |
| `arr[T]` *(v1.1)* | CXDM Array Item of type T §D15 | `[ports [80, 443]]` |
| `seq[T]` *(v1.1)* | CXDM Sequence of type T §D15 | `[results (//a, //b)]` |
| `map[K, V]` *(v1.1)* | CXDM Map Item with K-typed keys, V-typed values §D15 (K restricted to atomic Scalars per `spec/cxdm.md §2.5`) | `[config {name: 'svc'}]` |
| `:elem` | child elements only, no text | `[book [chapter ...]]` |
| `:mixed` | text + child elements | `[para See [b above]]` |
| `:any` | no body shape constraint | any |

**v1.1 collection-type productions (per §D15).** The
`arr[T]` / `seq[T]` / `map[K, V]` productions compose recursively
with all scalar and node-type productions above. Examples:

```cx
[ports
 [body arr[u16] :len='1..16']
]

[tags
 [body arr[string] :len='0..32']
]

[stats
 [body map[string, int]]
]

[matrix
 [body arr[arr[float]]] # nested arrays of floats
]

[lookup
 [body map[string, arr[u32]]] # string-keyed map of u32 arrays
]
```

The legacy `:T[]` shape (e.g., `:i32[]`) remains valid for the
v0.6.0 migration window and parses identically to `arr[T]` per
[`spec/conversions.md §0.2`](conversions.md) desugaring rule.
Canonical-form emit produces the `arr[T]` form. The legacy form
may be removed at v0.7.0+.

Constraints attached to `[body ...]`:

- `:req` — the element must have a body (cannot be `[name]`).
 Implicit for non-`:none` shapes; explicit form for clarity.
- `:def=<value>` — used only with `:none` or scalar shapes;
 if the target element omits the body, the validator inserts
 the default. See §11.
- `:range='<min>..<max>'` — for numeric shapes, value must be in
 the range (inclusive both ends; `*` for unbounded one side).
- `:enum=[<v1> <v2> ...]` — for scalar shapes, value must be one
 of the listed.
- `:pat='<re2-regex>'` — for `:string` shape, value must match
 the regex. Regex flavor is RE2 (no backreferences, no
 exponential blowup; cross-binding-deterministic).
- `:len='<min>..<max>'` — for `:string` and `:bytes` shapes,
 byte length (UTF-8 bytes for `:string`, raw bytes for `:bytes`)
 must be in the range.

Examples:

```cx
[port
 [body :u16 :range='1..65535']
]

[email
 [body :string :pat='^[^@]+@[^@]+\.[^@]+$']
]

[size
 [body :string :enum=['small' 'medium' 'large']]
]

[blob
 [body :bytes :len='0..1048576'] # max 1MB
]

[fallback-tag
 [body :string :def='untagged']
]
```

---

## 5 — Attribute declarations

```cx
[attr <name> :<type> <constraints>]
```

Declares an attribute on the type being defined. Type and
constraints follow the same vocabulary as `[body ...]` (§4):
sized scalars, ranges, enums, patterns, length, default.

Additional attribute-only constraints:

- `:req` — attribute must be present. Default if no `:opt`
 or `:def=...` is specified.
- `:opt` — attribute may be absent; if present, must satisfy
 the type and remaining constraints.
- `:def=<value>` — if absent, validator inserts default.
 Implies `:opt`.

Examples:

```cx
[server
 [attr host :string :req]
 [attr port :u16 :def=8080]
 [attr tls :bool :def=false]
 [attr env :string :enum=['dev' 'staging' 'prod'] :opt]
]
```

Multiple attribute declarations on the same target element with
the same name are an error (`S014`). Reserved/built-in attribute
names (`cx:lang` per `spec/i18n.md`, `xml:doctype` on the document
root per `)
are recognized by the validator without requiring schema declaration
unless the schema explicitly constrains them.

---

## 6 — Child element declarations

```cx
[elem <name> <constraints>]
```

Declares a child element on the type being defined. The element's
type definition lives in a separate top-level type declaration
elsewhere in the schema; the child-element declaration here only
records that an element of `<name>` may appear under the parent
and its cardinality / order constraints.

Constraints:

- `:card='<min>..<max>'` — number of times this child may
 appear. Default `'1..1'`. Use `'*'` for unbounded max.
- `:req` — alias for `:card='1..1'`.
- `:opt` — alias for `:card='0..1'`.
- `:order='strict'` or `:order='any'` — within the parent, child
 elements appear in declared order (`'strict'`) or any order
 (`'any'`). Default at the parent level; per-element override
 not supported in v0.6.0.

The parent's child-order policy is set via `[check ordering=<mode>]`
on the parent type declaration, defaulting to `'any'`:

```cx
[book
 [body :elem]
 [check ordering=strict]
 [elem title :card='1..1']
 [elem author :card='1..*']
 [elem chapter :card='0..*']
]
```

A target document with `<book><chapter ...><title>...</title>...</book>`
under this schema would fail with `S015` (child-element order
violation).

If the parent type's content shape is `:elem` or `:mixed`, the
schema must declare every child-element name that may appear; under
strict mode, target documents containing undeclared children fail
with `S001`. Under open mode (§9), undeclared children are warned
or accepted.

---

## 7 — Constraint vocabulary

Constraints attach to `[body ...]`, `[attr ...]`, or
`[elem ...]` as `:<sigil>=<value>` or `:<sigil>` (boolean).

Catalog (alphabetical):

| sigil | applies to | value | meaning |
| ----- | ---------- | ----- | ------- |
| `:card` | element | `'M..N'` (ints, or `*` for unbounded) | child count range |
| `:def` | content, attribute | CX literal | inserted if absent |
| `:enum` | content (scalar), attribute | `[v1 v2 ...]` | must be one of |
| `:len` | content (string/bytes), attribute (string/bytes) | `'M..N'` | byte length range |
| `:opt` | attribute, element | (boolean) | absence permitted |
| `:pat` | content (string), attribute (string) | RE2 regex string | must match |
| `:range` | content (numeric), attribute (numeric) | `'M..N'` | value range |
| `:req` | content, attribute, element | (boolean) | must be present |
| `:order` | element | `'strict'` / `'any'` | sibling order |

Custom validation logic beyond the above (e.g., "this attribute's
value must equal another attribute's value plus 1") is out of
scope for v0.6.0. Adopters apply such checks in consumer code or
wait for post-v0.6.0 schema extensions.

### 7.1 — RE2 pattern engine (normative for cross-binding determinism)

`:pat=` patterns evaluate under Google RE2 semantics
(<https://github.com/google/re2/wiki/Syntax>) — no backreferences,
no lookaround, no exponential blowup, deterministic match across
binding boundaries. The pattern engine lives **inside libcx**: every
binding routes `:pat=` checking through `cx_validate` /
`cx_validate_apply_defaults` (per [`spec/abi.md §2.13`](abi.md)) so
a regex authored once produces identical match results regardless of
which binding loaded the document. Bindings do **not** ship their own
regex engines for schema validation; that would split the
behavioural contract.

Match shape is **full-match** (RE2's `RE2::FullMatch`). `:pat='\w+'`
matches strings consisting entirely of word characters; the schema
author writes `:pat='\w+'` for the full-string check rather than the
search-style `\w+`. To match anywhere, use `^.*<inner>.*$` or
`(?s).*<inner>.*` (RE2 dot-all).

Capability bit 25 (`spec/abi.md §3`) signals RE2 support; this is
unconditional on a v0.6.0+ libcx. v0.6.0 ships with a system RE2
dependency (Homebrew `re2` / `libre2-dev`); a vendored submodule
pin lands post-tag, no API change.

#### Known parser limitation (v0.6.0)

The CX text parser does not yet enter "in-quoted-string" sub-state
when reading `[attr ...]` / `[body ...]` / `[elem ...]` flag
values. Pattern strings containing `[` or `]` (regex character
classes) inside a `:pat='...'` flag are currently rejected as
"expected node" parse errors. RE2 patterns expressible without
character classes — using `\w`, `\d`, `\s`, `.`, anchors, and
shorthand quantifiers — work today. Bracket support is queued for
Phase 7.74e (parser change, not a schema-language change).

---

## 8 — Reusable fragments

A reusable shape fragment is declared via the standard CX anchor
mechanism (`&name`) and referenced via alias (`*name`). The schema
validator treats anchored sub-bodies inside type declarations as
reusable fragments.

```cx
[?cx schema-of database ]

[server-config &server-config
 [body :elem]
 [attr host :string :req]
 [attr port :u16 :req :range='1..65535']
 [attr tls :bool :def=false]
]

[database
 [body :elem]
 [elem primary]
 [elem replica :card='0..*']
]

[primary *server-config]
[replica *server-config]
```

Here `&server-config` declares a reusable schema fragment. The
type declarations for `primary` and `replica` reference it via
`*server-config`. The validator resolves the alias at schema-load
time, inlining the fragment's `[body ...]` and `[attr ...]`
declarations into each referencing type.

A fragment may not be self-referential; cycles are detected at
schema-load time (`S016` cyclic fragment).

The `&fragment-name` anchor may be declared on a top-level type
declaration (as in the `server-config` example above) or as a
standalone fragment under `[?cx frag <body>]`:

```cx
[?cx frag &port-range
 [body :u16 :range='1..65535']
]

[server
 [attr port *port-range :req]
]
```

The choice between the two spellings is stylistic; they have
identical semantics.

---

## 9 — Schema modes: open / strict / closed

CX schemas support three modes per
 D6,
selectable via `[?cx schema-mode <mode>]`:

| mode | undeclared elements / attributes | typical use |
| ---- | -------------------------------- | ----------- |
| **`open` (default)** | **permitted** without diagnostic; auto-typed per CX's standard rules; declared items still validate fully | partial schemas; "describe what you care about, accept the rest"; matches CX's permissive auto-typing philosophy |
| `strict` | permitted but produce **warning** diagnostics (`S001` / `S012` at `info`/`warn` severity) | schema authoring — find missing declarations without failing the build; downgrade to `open` once the schema stabilizes or upgrade to `closed` when the schema becomes authoritative |
| `closed` | rejected as **errors** (`S001` / `S012`) | schema is the gate; all permissible content is named; useful for compliance / regulated-data scenarios |

Mode is per-schema, not per-element. Per-element overrides are out
of scope for v0.6.0.

**Encoding decoupling.** Per
 D3
and [`spec/data_bin.md §3.13`](data_bin.md), schema-driven CXDB
encoding (per-field type-tag omission) is **independent** of
schema mode. A document encoded schema-driven under `open` mode
emits declared-field values without type tags AND undeclared-field
values with full self-describing tags; the validator and the
encoder consult the schema for different reasons and reach the
same conclusion. A document encoded self-describing (header flag
bit 1 = 0) carries full tags everywhere regardless of mode.

The previous v0.6 schema spec named two modes (`open` / `strict`)
defaulting to `strict`. The three-mode model in this revision was
locked at v0.6.0 spec-lock; existing two-mode references in
already-shipped tests are normalized at implementation time.

---

## 10 — Validation semantics

### 10.1 Order of operations

For each target document under a schema:

1. **Schema load**: parse the schema, resolve fragments, build the
 type-declaration map (name → declaration). Errors here (`S009`,
 `S016`) produce a single diagnostic and abort.
2. **Root match**: target document's root element name must equal
 the schema's `[?cx schema-of <name>]` argument. Mismatch:
 `S017`. (Mismatch with the document is fatal — no further
 validation.)
3. **Tree walk**: depth-first, in document order. At each element:
 a. Match the element's name to a type declaration. (Strict
 mode: missing declaration is `S001`; open mode: skip subtree.)
 b. Validate the element's body against `[body ...]`.
 c. Validate each attribute against `[attr ...]`.
 d. Validate child-element cardinality and (if `:order='strict'`)
 order against `[elem ...]`.
 e. Apply `[check ...]`.
 f. Recurse into children.
4. **Diagnostic emission**: errors collected during the tree walk
 are emitted in document order with line/column metadata.

### 10.2 Error collection

The validator collects **all** errors in one pass; it does not
short-circuit on first error. This means a document with multiple
issues produces a complete report, not a one-error-at-a-time
trickle. Implementation must accumulate diagnostics and return
them as a list.

The C ABI returns diagnostics as a length-prefixed array (per
[`spec/abi.md §2.13`](abi.md)):

```
[u32 LE: framing_size] 4-byte framing prefix
[u32 LE: count]
[diagnostic_1] [diagnostic_2] ... [diagnostic_count]
```

Each diagnostic is `[u32 LE: line] [u32 LE: col] [u8 prefix]
[u32 LE: error_code] [u8 severity] [u32 LE: message_len]
[message_utf8]`.

`prefix` is the single-ASCII-letter rule-code namespace tag —
`'S'` (0x53) for the schema validator, reserved `'W'` (0x57) for
the streaming-write event writer (per
)
and `'D'` (0x44) for the future data validator. A value of `0x00`
means "namespace unspecified"; bindings render such diagnostics
without a prefix character. New rule-code namespaces are
allocated by reserving an additional ASCII letter in this byte;
no further wire-format change is required.

`error_code` is the numeric form of the prefixed code
(`"S002"` → 2, `"S017"` → 17, `"W001"` → 1). Severity values:
0 = info, 1 = warn, 2 = error.

A target document that produces zero diagnostics at the **error**
severity is *valid*. Strict-mode warnings and info diagnostics
do not invalidate the document; CLI exit-code thresholding via
`--fail-on=info|warn|error|none` lets adopters dial the gate.

### 10.3 Diagnostic format

Each diagnostic carries:

- **Source location** — line and column in the target document
 pointing at the offending construct.
- **Error code** — from the registry in §12.
- **Friendly message** — UTF-8 string describing the problem in
 adopter-readable terms (e.g., "attribute 'port' (value: 99999)
 exceeds range 1..65535").
- **Schema location** (informational) — line and column in the
 schema where the violated rule is declared. Useful when the
 adopter has access to the schema source.

CLI output formats the diagnostics as:

```
doc.cx:42:8: error: S006: attribute 'port' value 99999 exceeds range 1..65535
 schema: book.cxs:18:5
```

### 10.3.1 CLI exit codes

The `cx validate` CLI exits as follows (matching `cx lint`'s
`--fail-on` convention so adopters learn one model):

| `--fail-on=` | Exit 1 when | Exit 0 when |
| ------------ | ----------- | ----------- |
| `info` | any diagnostic | no diagnostics |
| `warn` | warn or error | only info / none |
| `error` (default) | any error | only warn / info / none |
| `none` | (never; always exit 0) | always |

Exit 2 is reserved for usage / I/O / schema-load failure. The CLI
also surfaces the `--mode=open|strict|closed` flag, which overrides
the schema's `[?cx schema-mode ...]` directive at validate time
(useful for "lint a published open-mode schema strictly").

### 10.4 What validation does not do

- **Validation does not modify the target AST** unless schema-driven
 defaults (§11) are explicitly applied via the `--apply-defaults`
 flag (CLI) or the `apply_defaults=true` parameter (per-binding
 API). Without that flag, defaults are advisory and not inserted.
- **Validation does not infer types**. A string value where a
 schema declares `:int` is a type-mismatch error (`S005`), not
 a coerce-and-warn.
- **Validation does not resolve includes**. The target document is
 validated as parsed; if includes were resolved at parse time,
 they're part of the AST and validate normally. If includes were
 deferred, the validator does not chase them.

---

## 11 — Schema-driven defaults

When `--apply-defaults` is set (or the per-binding equivalent), the
validator inserts default values for missing attributes and missing
content per the schema's `:def=...` declarations. The behavior:

- Missing attribute with `:def=<value>` declared: attribute is
 inserted on the target element with the default value, before
 validation continues.
- Missing element body (e.g., `[name]`) with `:def=<value>`
 declared on `[body ...]`: body is inserted with the default
 value.
- Missing child element with `:def=<value>` declared on
 `[elem ...]` *not supported* in v0.6.0 — defaults apply only
 to attributes and scalar content. Adopters needing defaulted
 child elements use `:card='0..*'` and check at consumer
 side.

Type coercion of default values happens at schema-load time. A
default whose CX literal type does not match the declared type
fails with `S011` at schema-load, not at validate-time. This means
schema typos surface immediately.

The C ABI surfaces the modified AST through a separate output
parameter (the validator does not modify the input buffer):

```c
char* cx_validate_apply_defaults(
 const char* doc_bytes,
 const char* schema_bytes,
 char** modified_doc_out,
 char** err_out);
```

Without `apply_defaults`, the validator returns only diagnostics;
the document is unchanged.

---

## 12 — Error code registry

Schema-domain error codes use the `S` prefix (consistent with `E`
for parse errors per `spec/policies.md §10`).

| code | meaning |
| ---- | ------- |
| `S001` | unknown element (strict mode) — element name has no type declaration |
| `S002` | missing required attribute |
| `S003` | child-element cardinality violation — too few children |
| `S004` | child-element cardinality violation — too many children |
| `S005` | type mismatch — value does not match declared type |
| `S006` | range violation — value outside `:range` |
| `S007` | enum violation — value not in `:enum` |
| `S008` | pattern mismatch — string does not match `:pat` |
| `S009` | schema not found / malformed |
| `S010` | schema directive `[?cx schema=...]` references missing schema |
| `S011` | default-value coercion failure (schema-load time) |
| `S012` | unknown attribute (strict mode) — attribute name has no declaration |
| `S013` | fragment alias resolution failure |
| `S014` | duplicate attribute declaration on same type |
| `S015` | child-element order violation (`:order='strict'`) |
| `S016` | cyclic fragment reference detected at schema-load |
| `S017` | root-element name mismatch — document root does not match schema's `schema-of` |
| `S018` | length violation — string/bytes byte length outside `:len` |
| `S019` | required content missing — element has no body but content `:req` |
| `S020` | schema-version mismatch — schema declares an unsupported version |

Codes `S101+` reserved for post-v0.6.0 extensions.

---

## 13 — The `[?cx schema=...]` directive

A target document may declare its schema via:

```cx
[?cx schema=path/to/book.cxs]
[book
 ...
]
```

When the validator (or parser, if validate-on-parse is enabled)
encounters this directive, it loads the named schema and validates
the document against it. Path resolution follows the same rules as
`[?cx include=...]` (caller-supplied root, no URL fetching, no
file: scheme).

Multiple `[?cx schema=...]` directives in one document are an
error (`S009`). A schema directive plus an explicit
`--schema=<other.cxs>` CLI flag uses the CLI flag and warns about
the directive override.

A target document without a schema directive parses normally; the
validator-via-CLI-flag is the explicit-validation path.

### 13.1 — Schema reference forms

A schema is referenced from a target document or a schema-driven
CXDB binary in one of three forms, per
[`spec/data_bin.md §3.13.1`](data_bin.md) and
 D4:

| form | wire tag | notes |
| ---- | -------- | ----- |
| **Inline** | `0x11` (binary), or `[?cx schema-inline ...]` followed by inline `.cxs` (text) | schema travels with the data; no external lookup needed |
| **External by content-hash** | `0x10` (binary) — 32-byte SHA-256 of the schema's CXDB strict-canonical encoding | format-stable, location-independent identifier; consumers resolve via a content-addressable store |
| **External by content-hash with name hint** | `0x12` (binary) — hash + UTF-8 name string | same as above, plus a hint (typically the schema's source filename) for human-readable diagnostics and tooling lookup; readers MUST verify the looked-up schema's hash matches the embedded hash |

The schema's content-hash is computed as
`SHA-256(cx_to_data_bin(parse(schema_text), strict_canonical))` — the
hash is over the schema's CXDB strict-canonical encoding, NOT over
the raw `.cxs` source bytes. This makes the hash invariant under
comment edits, whitespace changes, and source-format reorganization.

Path / URL references (`[?cx schema=path/to/x.cxs]`,
`[?cx schema=https://...]`) are **tooling-layer** features. The
`cx table` subcommand and `cx validate` CLI accept paths and
resolve them to a content-hash before emit; the wire format itself
defines no path / URL semantics. This keeps the wire format
deterministic and free of confused-deputy / TOCTOU concerns; see
[`spec/threat_model.md §4 T3`](threat_model.md).

### 13.2 — Tooling transformations (planned for v0.6.0+)

Four `cx schema` subcommand transformations bridge between the
three reference forms. These ship with the `cx table` subcommand
phase, after V core schema validator implementation lands.

| command | input | output | use |
| ------- | ----- | ------ | --- |
| `cx schema embed --doc=D --schema=S` | doc D + schema S | doc D' with inline-schema reference | bundle a schema into a CXDB for self-contained delivery |
| `cx schema extract --doc=D` | doc D with inline schema | (doc D' with content-hash reference) + (schema S) | unbundle for content-addressable storage |
| `cx schema bundle --schemas=S1,S2,...` | one or more `.cxs` files | content-addressable schema archive (manifest + schema contents keyed by hash) | build a schema registry / content store for content-hash references to resolve against |
| `cx schema unbundle --bundle=B` | content-addressable schema archive | individual `.cxs` files in a directory | inverse of `bundle`; useful for reviewing a registry's contents |

`embed` and `extract` are inverses (modulo formatting, since
`extract` materializes the schema as canonical CX text). `bundle`
and `unbundle` operate on the schema registry layer that adopters
populate from a corpus of authoritative `.cxs` files.

Adopters who run schema-driven CXDB pipelines typically: author
schemas as `.cxs` files; `cx schema bundle` them into a registry
(content-addressable on a shared filesystem, S3 bucket, or git
LFS); produce schema-driven CXDB outputs that reference schemas by
content-hash; consumers point libcx at the registry via
`CX_SCHEMA_STORE` (or per-call API parameter) and resolve schemas
on-the-fly during decode.

---

## 14 — Conversion behavior

Schemas describe CX documents. They do not directly describe
JSON, YAML, TOML, XML, or delimited equivalents.

- **CX → XML**: schema validation (if invoked) runs on the CX
 side. The XML output is whatever the existing CX → XML
 conversion produces. There is no XSD generation in v0.6.0.
 Adopters who need XSD for downstream consumers either write it
 by hand or wait for the post-v0.6.0 schema-export feature
 (planned for "Later").
- **CX → JSON / YAML / TOML / MD**: same — schema validates the
 CX side; no JSON Schema / YAML schema generation in v0.6.0.
- **XML / JSON / YAML / TOML → CX**: importing a non-CX document
 produces a CX document. Validation against a `.cxs` runs after
 import; it does not look at the source format.

A schema may not span format boundaries — e.g., it cannot say
"this attribute must be `:int` in CX but `:string` in JSON
output." Per-format shape control is the separate v0.6.0 work
item (rubric §6 output-shape control); the two are
complementary.

---

## 15 — Conformance fixtures expected

The v0.6.0 implementation cycle produces conformance fixtures
under `vcx/tests/conformance/schema/` covering at least:

1. **Required attribute success** — schema declares `:req`,
 doc has it, validates clean.
2. **Required attribute failure** — schema declares `:req`,
 doc omits it, `S002` reported.
3. **Cardinality success** — schema declares `:card='1..3'`,
 doc has 1, 2, or 3 children of that name.
4. **Cardinality failure (too few)** — `S003`.
5. **Cardinality failure (too many)** — `S004`.
6. **Type mismatch** — schema declares `:int`, doc has `:string`,
 `S005`.
7. **Range constraint** — both inside and outside the declared
 range; `S006` for outside.
8. **Enum constraint** — value in / not in the enum; `S007` for
 not-in.
9. **Pattern constraint** — RE2 regex match / mismatch; `S008` for
 mismatch.
10. **Length constraint** — both string and bytes; `S018` for
 out-of-range.
11. **Default-value insertion** — with and without `--apply-defaults`.
12. **Default-value coercion failure** — schema with bad default
 type; `S011` at schema-load.
13. **Unknown element strict mode** — `S001` reported.
14. **Unknown element open mode** — accepted, no diagnostic.
15. **Schema not found** — `S009` / `S010`.
16. **Schema malformed** — `S009`.
17. **Root mismatch** — doc root differs from `schema-of`; `S017`.
18. **Child order strict** — `S015` for out-of-order.
19. **Fragment reuse** — `*alias` resolves correctly across
 multiple referencing positions.
20. **Cyclic fragment** — `S016` at schema-load.
21. **Multi-error collection** — doc with three issues produces
 three diagnostics in document order.
22. **`[?cx schema=...]` directive** — opt-in validate-on-parse
 works; missing schema yields `S010`.

Additional fixtures cover the cross-cutting cases: schema with
namespaces (per ), schema with ID/IDREF (per ),
schema validating documents that include other documents
(`[?cx include=...]`).

---

## 16 — Open questions deferred to post-v0.6.0

These are not blockers for v0.6.0 but tracked for visibility:

- **Substitution groups / type derivation**. XSD-style
 polymorphism. Adopters surface specific use cases first.
- **Conditional / dependent attributes**. XSD 1.1-style assertions
 expressed in the schema. Likely candidate post-v0.6.0 if
 adopters surface need.
- **Identity constraints in the schema** (selector / field
 XPath subsets). CXPath is the substrate; the schema language
 could host this.
- **Cross-schema imports / inheritance**. A schema that extends
 another schema. Useful for large schemas; not in v0.6.0.
- **Schema export to XSD / JSON Schema**. Generate XSD or JSON
 Schema from a `.cxs`. Lossy in places (CX has constructs neither
 format models). Roadmap "Later" if adoption demand surfaces.
- **Per-element open/strict override**. v0.6.0 has only schema-
 global mode; per-element override is straightforward to add but
 not in v0.6.0 scope.
- **Custom constraint expressions** beyond the §7 catalog. Could
 be an embedded expression mini-language; out of scope until
 the catalog proves insufficient.
- **`element` declarations carrying `:def`**. v0.6.0 supports
 defaults only for attributes and scalar content; default child
 elements is a known limitation.

---

## 17 — References

- [`spec/grammar.ebnf §418`](grammar.ebnf) — `[?cx schema=...]`
 directive reservation.
- [`spec/abi.md`](abi.md) — C ABI conventions; `cx_validate` lands
 in v0.6.0 per these conventions.
- [`spec/policies.md §10`](policies.md) — error code registry
 conventions (`E` prefix for parse, `S` prefix for schema).

- [`spec/i18n.md`](i18n.md) — `cx:lang` recognition.
- W3C XML Schema Part 1: Structures (XSD 1.1) — primary
 intellectual reference for the constraint vocabulary.
- RELAX NG (ISO/IEC 19757-2) — secondary intellectual reference,
 particularly for the cardinality / element-content patterns.
- Google RE2 — `https://github.com/google/re2/wiki/Syntax` —
 the regex flavor for `:pat`.

 — analytics-bridge design. Locks the open / strict / closed mode
 set (D6), the encoding-decoupling rule (D3), and the
 content-hash schema reference form (D4 + D5).
