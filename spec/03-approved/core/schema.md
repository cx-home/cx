# CX Schema Language Specification (`.cxs`)

**Status:** Current.

---

## 1 — Introduction

A `.cxs` file is a CX document. It parses with the standard CX
parser. The schema validator interprets the parsed AST under the
rules in this document.

**File naming**: schemas use the `.cxs` extension by convention.
The validator does not require the extension; any CX document
whose **first top-level element** is `[schema …]` carrying an
`of` attribute is treated as a schema.

**Validator entry points**:

- `cx validate <doc.cx> --schema=<schema.cxs>` — CLI subcommand.
 Flags: `--fail-on=info|warn|error|none` (default `error`,
 matches `cx lint`); `--mode=open|strict|closed` overrides the
 header's `mode` attribute; `--apply-defaults` inserts `[default …]`
 attribute values into the validated output.
- `cx_validate(doc_bytes, schema_bytes, err_out)` — C ABI symbol;
 `cx_validate_apply_defaults` for the defaults-applying variant.
 Both have `_with_len` companions per `abi.md`. Diagnostic wire
 format normative per §10.2 below.
- Per-binding `validate(doc, schema)` and
 `validate_with_defaults(doc, schema)` — thin wrappers over the C
 ABI so RE2 pattern semantics (S008) stay identical across
 bindings.
- Document-embedded `[?cx schema=schema.cxs]` directive — opts
 the document into validate-on-parse against the named schema.

---

## 2 — Schema document structure

A schema document begins with a **header element** identifying it
as a schema:

```cx
[schema of=book]
```

The header MUST be the **first top-level element** of the document.
The `of` attribute is required and names the **root element** of
the target document. A schema may declare exactly one root.

After the header, the schema body is a sequence of **type
declarations** — top-level elements whose names match elements
that appear in the target document. The element name in the schema
is the type name being defined.

Optional header attributes:

- `name='<title>'` — human-readable schema name used in
 diagnostics.
- `mode=open`, `mode=strict`, or `mode=closed` — see §9.
 **Default is `open`**.
- `version='<semver>'` — optional; declares the schema-dialect
 version the schema document targets; an unknown/unsupported
 declared version is rejected with `S020`. The dialect identity
 is **major.minor** — a dialect patch is clarification-only
 (governance §9.1), so `0.8`, `0.8.0`, and `0.8.N` all target
 dialect `0.8`; a non-semver declaration is `S020` (stream 21,
 #716 item 4 — the pre-I5 check was hard string equality).
 Example: `[schema of=book version='0.8']`.

The header is ordinary document **body data**: every header
attribute rides in the schema's canonical text and therefore in
its content-hash (§13.1) — two schemas differing only in `mode`
are two schemas with two identities. (The pre-I5 spelling was a
set of `[?cx schema-of/-name/-mode/-version]` directives; strict
canonical strips `[?cx …]` directives, so those spellings leaked
content OUT of the hashed bytes — the identity hole the I1 ledger
entry-25 ruling closed by moving the header into body data. The
directive spellings are retired and rejected at schema load.)

**Schema revisions are distinct identities** — an `Order` v2 is a
different content address sharing an element name, and nothing links
the two intrinsically. The link is the **Lane-2
`[schema-lineage [from <address>] [to <address>] [relation …]
[upcaster …]]` claim**
([`schema_event_evolution.md`](../core/schema_event_evolution.md),
ruling L149): a plain value, never a field on either schema. The
lineage graph must admit a **unique path** between any two endpoints —
ambiguity is rejected fail-closed at load
([`journal.md`](../std-lib/journal.md) §3.9, `lineage-path`). Evolution
never perturbs an address: **migration is always additive** — new
representations join; history stays replayable.

### Example schema

```cx
[schema of=book name='Book schema v1']

[book
 [attr id::string [req]]
 [elem title [card "1..1"]]
 [elem author [card "1..*"]]
 [elem chapter [card "0..*"]]]

[type title::string]
[type author::string]

[chapter
 [attr number::int [req] [min 1]]
 [elem title [card "1..1"]]
 [elem body [card "1..1"]]]

[body
 [elem para [card "0..*"]]
 [elem emphasis [card "0..*"]]]

[para
 [elem emphasis [card "0..*"]]]

[type emphasis::string]
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

The name `schema` is additionally reserved at exactly one position:
the **first top-level element** of a schema document is the header
(§2 above). A type declaration named `schema` is legal at any later
top-level position.

---

## 3 — Type declaration anatomy

A type declaration is a top-level element in a schema body whose
name is the target-element type being defined:

```cx
[<type-name>
 [attr <name>::<type> <clauses>*]*
 [elem <name> <clauses>*]*
 [check <expr>]*]
```

Or, for a named scalar / composite body alias:

```cx
[type <name>::<type> <clauses>*]
```

Order is significant for readability but not for semantics:
the validator collects all child kinds and applies them as a set.
A type-decl with no `::T` ascription and no `[type …]` wrapper is
implicitly an `elem` body — its body shape is "child elements
only", determined by the presence of `[attr]` / `[elem]` children.

A type declaration whose name matches a reserved schema-vocabulary
name (e.g., a target document with elements literally named
`content`) is permitted but produces a diagnostic-clarity warning;
adopters who hit this rename the target element or rename in the
target schema.

---

## 4 — Content shape

Body shapes are expressed via the `::<type>` ascription on `[type]`,
`[attr]`, and `[elem]` declarations. Exactly one shape per
declaration; constraints on the value attach as `[clause …]`
positional children of the same declaration (catalog §7).

Shape vocabulary (the `T` in `name::T`):

| `T` | meaning | example declaration |
| --- | ------- | ------------------- |
| `none` | empty body — `[name]` only | `[type hr::none]` |
| `string` | scalar string body | `[type title::string]` |
| `int` / `i8` / `i16` / `i32` / `i64` | sized integer | `[attr count::i32]` |
| `u8` / `u16` / `u32` / `u64` | sized unsigned | `[attr port::u16]` |
| `f16` / `f32` / `f64` / `float` | float | `[attr ratio::f64]` |
| `bool` | boolean | `[attr active::bool]` |
| `decimal` | arbitrary-precision decimal | `[attr price::decimal]` |
| `bigint` | arbitrary-precision integer | `[attr id::bigint]` |
| `bytes` | base64-encoded bytes | `[type blob::bytes]` |
| `date` | ISO 8601 date | `[attr born::date]` |
| `datetime` | ISO 8601 instant | `[attr at::datetime]` |
| `null` | explicit null | `[type unset::null]` |
| `atom` | tag-shaped scalar (`:NAME`) | `[attr status::atom [enum :ok :err :pending]]` |
| `scalar` | any scalar type | `[type any-scalar::scalar]` |
| `[list T]` / `[seq T]` | CXDM Array / Sequence of type T | `[attr ports::[list u16]]` |
| `[map K V]` | CXDM Map with K-typed keys, V-typed values (K restricted to atomic Scalars per `cxdm.md §2.6`) | `[attr stats::[map string int]]` |
| `[enum V…]` | value must be one of V… | `[attr role::[enum admin user guest]]` |
| `[or T…]` | union of T… | `[attr id::[or int string]]` |
| `[tuple T…]` | fixed-arity tuple | `[type point::[tuple int int]]` |
| `[ref Name]` | reference to a named type | `[elem children::[list [ref Tree]]]` |
| `[record [attr …]*]` | inline record shape | `[type addr::[record [attr street::string] [attr zip::string]]]` |
| `elem` | child elements only, no text | implicit on types with `[elem …]` children |
| `mixed` | text + child elements | `[type para::mixed]` |
| `any` | no shape constraint | `[type opaque::any]` |
| `ref` | body must be a `[ref @Name]` body-position identity reference (`cxdm.md §4.2`); text or other content is `S023` | `[type xref::ref]` |

Composite types nest recursively: `[list [list float]]`,
`[map string [list u32]]`, `[or int [list int]]`, etc.

**Spelling (normative, stream 16 W2):** the bracket-prefix forms
above are THE composite spelling — the pre-I5 glued forms
(`arr[T]` / `seq[T]` / `map[K, V]` and the `:T[]` body desugar) are
RETIRED with no dual-accept. In `[body …]` declarations the
composite may spell either as the annotation (`[body [list u16]]`
read as a type-shaped ELEMENT child) or via `::`-ascription on the
declaration; `[ref Name]` works ONLY in annotation position (the
element spelling collides with the reserved `[ref @id]`
body-position identity reference, cxdm.md §4.2).

**Examples:**

```cx
[type port::u16 [range 1 65535]]

[type email::string [pattern '^[^@]+@[^@]+\.[^@]+$']]

[type size::string [enum small medium large]]

[type blob::bytes [len 0 1048576]]  # max 1MB

[type fallback-tag::string [default 'untagged']]
```

---

## 5 — Attribute declarations

```cx
[attr <name>::<type> <clauses>*]
```

Declares an attribute on the type being defined. The type
ascription `::<type>` is byte-adjacent to the attribute name; type
and constraints follow the catalog in §7.

Attribute-only constraints:

- `[req]` — attribute must be present. Default if no `[opt]`
 or `[default …]` is specified.
- `[opt]` — attribute may be absent; if present, must satisfy
 the type and remaining constraints.
- `[default <value>]` — if absent, validator inserts default.
 Implies `[opt]`.

Examples:

```cx
[server
 [attr host::string [req]]
 [attr port::u16 [default 8080]]
 [attr tls::bool [default false]]
 [attr env::string [opt] [enum dev staging prod]]]
```

Multiple attribute declarations on the same target element with
the same name are an error (`S014`). Reserved/built-in attribute
names (`cx:lang`, `xml:doctype` on the document root) are recognized
by the validator without requiring schema declaration unless the
schema explicitly constrains them.

---

## 6 — Child element declarations

```cx
[elem <name> <clauses>*]
[elem <name>::<type-name> <clauses>*]    # named-type reference
```

Declares a child element on the type being defined. The element's
type definition lives in a separate top-level type declaration
elsewhere in the schema; the child-element declaration here only
records that an element of `<name>` may appear under the parent
and its cardinality / order constraints.

Constraints:

- `[card "<min>..<max>"]` — number of times this child may
 appear. Default `"1..1"`. Use `*` for unbounded max.
- `[req]` — alias for `[card "1..1"]`.
- `[opt]` — alias for `[card "0..1"]`.

The parent's child-order policy is set via `[check ordering=<mode>]`
on the parent type declaration, defaulting to `any`:

```cx
[book
 [check ordering=strict]
 [elem title [card "1..1"]]
 [elem author [card "1..*"]]
 [elem chapter [card "0..*"]]]
```

A target document with `<book><chapter ...><title>...</title>...</book>`
under this schema would fail with `S015` (child-element order
violation).

If the parent type's content shape is `elem` or `mixed`, the
schema must declare every child-element name that may appear; under
strict mode, target documents containing undeclared children fail
with `S001`. Under open mode (§9), undeclared children are warned
or accepted.

---

## 7 — Constraint vocabulary

Constraints attach to `[attr …]`, `[elem …]`, or `[type Name::T …]`
as positional child `[clause …]` elements.

Catalog:

| clause | applies to | payload | meaning |
| ------ | ---------- | ------- | ------- |
| `[card "M..N"]` | elem | range string (`*` for unbounded) | child count range |
| `[default V]` | content, attr | CX literal | inserted if absent |
| `[enum V…]` | content (scalar), attr | bareword / quoted values | must be one of |
| `[len M N]` / `[min-length M] [max-length N]` | content (string/bytes), attr | ints | byte length range |
| `[opt]` | attr, elem | (boolean) | absence permitted |
| `[pattern S]` | content (string), attr (string) | RE2 regex string | must match |
| `[range M N]` / `[min M] [max N]` | content (numeric), attr (numeric) | numeric | value range |
| `[req]` | content, attr, elem | (boolean) | must be present |
| `[ref Name]` | content, attr | named reference | body-position reference shape |

Per-element open/closed marker clauses `[open]` / `[closed]`
override the schema-wide mode (§9) for one type. These parse but
have no effect — full per-element mode is future work.

Custom validation logic beyond the above (e.g., "this attribute's
value must equal another attribute's value plus 1") is out of
scope. Adopters apply such checks in consumer code.

### 7.1 — RE2 pattern engine (normative for cross-binding determinism)

`[pattern …]` regexes evaluate under Google RE2 semantics
(<https://github.com/google/re2/wiki/Syntax>) — no backreferences,
no lookaround, no exponential blowup, deterministic match across
binding boundaries. The pattern engine lives **inside libcx**: every
binding routes pattern-checking through `cx_validate` /
`cx_validate_apply_defaults` (per `abi.md`) so a regex authored once
produces identical match results regardless of which binding loaded
the document. Bindings do **not** ship their own regex engines for
schema validation; that would split the behavioural contract.

Match shape is **full-match** (RE2's `RE2::FullMatch`).
`[pattern '\w+']` matches strings consisting entirely of word
characters. To match anywhere, use `^.*<inner>.*$` or
`(?s).*<inner>.*` (RE2 dot-all).

Capability bit 25 (`abi.md §3`) signals RE2 support.

#### Pattern strings — full character-class support

A `[pattern '...']` flag value is read in the in-quoted-string
sub-state, so the full RE2 surface is expressible. Regex character
classes (`[a-z]`, `[^0-9]`, …) embed directly — the `[` / `]` inside a
quoted pattern are atomic and do not terminate the clause. Escaped
quotes (`\'`, `\"`, grammar [11]) and the shorthand escapes (`\w`,
`\d`, `\s`, `.`, anchors, quantifiers) all pass through to RE2
unchanged. For example `[attr slug::string [pattern '[a-z][a-z0-9-]*']]`
loads and matches as written.

---

## 8 — Reusable fragments

A reusable shape fragment is declared via the standard CX anchor
mechanism (`&name`) and referenced via alias (`*name`). The schema
validator treats anchored sub-bodies inside type declarations as
reusable fragments.

```cx
[schema of=database]

[server-config &server-config
 [attr host::string [req]]
 [attr port::u16 [req] [range 1 65535]]
 [attr tls::bool [default false]]]

[database
 [elem primary]
 [elem replica [card "0..*"]]]

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

The `&fragment-name` anchor is declared on a top-level type
declaration (as in the `server-config` example above). A
fragment-only helper is simply an anchored top-level declaration
that no target element happens to match:

```cx
[port-range &port-range
 [body i32 [range 1 65535]]]

[server
 [attr port *port-range [req]]]
```

(A standalone `[?cx frag &name …]` directive form existed pre-I5;
it is retired and rejected at schema load — a fragment is schema
CONTENT, and content-bearing `[?cx …]` directives are stripped by
strict canonical, so the directive spelling leaked the fragment out
of the schema's hashed bytes. The anchored-type form above was
already spec'd as semantically identical.)

---

## 9 — Schema modes: open / strict / closed

CX schemas support three modes, selectable via the header's
`mode` attribute (`[schema of=… mode=<mode>]`):

| mode | undeclared elements / attributes | typical use |
| ---- | -------------------------------- | ----------- |
| **`open` (default)** | **permitted** without diagnostic; auto-typed per CX's standard rules; declared items still validate fully | partial schemas; "describe what you care about, accept the rest"; matches CX's permissive auto-typing philosophy |
| `strict` | permitted but produce **warning** diagnostics (`S001` / `S012` at `info`/`warn` severity) | schema authoring — find missing declarations without failing the build; downgrade to `open` once the schema stabilizes or upgrade to `closed` when the schema becomes authoritative |
| `closed` | rejected as **errors** (`S001` / `S012`) | schema is the gate; all permissible content is named; useful for compliance / regulated-data scenarios |

Mode is per-schema, not per-element. Per-element overrides are out.

**Encoding decoupling.** Per
 D3
and `data-bin.md`, schema-driven CXCol
encoding (per-field type-tag omission) is **independent** of
schema mode. A document encoded schema-driven under `open` mode
emits declared-field values without type tags AND undeclared-field
values with full self-describing tags; the validator and the
encoder consult the schema for different reasons and reach the
same conclusion. A document encoded self-describing (header flag
bit 1 = 0) carries full tags everywhere regardless of mode.

The previous v0.6 schema spec named two modes (`open` / `strict`)
defaulting to `strict`. The three-mode model in this revision was
locked spec-lock; existing two-mode references in
already-shipped tests are normalized at implementation time.

---

## 10 — Validation semantics

### 10.1 Order of operations

For each target document under a schema:

1. **Schema load**: parse the schema, resolve fragments, build the
 type-declaration map (name → declaration). Errors here (`S009`,
 `S016`) produce a single diagnostic and abort.
2. **Root match**: target document's root element name must equal
 the schema header's `of` attribute. Mismatch:
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
`abi.md`):

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
the schema header's `mode` attribute at validate time
(useful for "lint a published open-mode schema strictly"). The
override changes THIS validation run only — it never reinterprets
the schema document, whose identity carries the authored mode.

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
content per the schema's `[default ...`] declarations. The behavior:

- Missing attribute with `[default <value>`] declared: attribute is
 inserted on the target element with the default value, before
 validation continues.
- Missing element body (e.g., `[name]`) with `[default <value>`]
 declared on `[body ...]`: body is inserted with the default
 value.
- Missing child element with `[default <value>`] declared on
 `[elem ...]` *not supported* — defaults apply only
 to attributes and scalar content. Adopters needing defaulted
 child elements use `[card "0..*"]` and check at consumer
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
for parse errors per `policies.md §10`).

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
| `S017` | root-element name mismatch — document root does not match the schema header's `of` |
| `S018` | length violation — string/bytes byte length outside `:len` |
| `S019` | required content missing — element has no body but content `[req]` |
| `S020` | schema-version mismatch — schema declares an unsupported version |
| `S023` | body-ref required but absent — an element whose declared type is a `ref` body (`[type X::ref]`) carries text or other content instead of the `[ref @Name]` body-position reference |
| `S024` | container/tuple/record type declared in ATTRIBUTE position — attributes are strictly scalar (`cxdm.md` §2.4); shapes live on body / `[type]` positions (stream 16) |
| `S025` | `[ref Name]` names an unknown type — references resolve fail-closed, never a silent pass (stream 16) |

Codes `S021`–`S022` are reserved/unused; `S023` sits in this
reserved span. Codes `S101+` reserved for future extensions.

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
CXCol binary in one of three forms, per
`data-bin.md` and
 D4:

| form | wire tag | notes |
| ---- | -------- | ----- |
| **Inline** | `0x11` (binary), or `[?cx schema-inline ...]` followed by inline `.cxs` (text) | schema travels with the data; no external lookup needed |
| **External by content-hash** | `0x10` (binary) — the 32-byte schema content-hash (below) | format-stable, location-independent identifier; consumers resolve via a content-addressable store |
| **External by content-hash with name hint** | `0x12` (binary) — hash + UTF-8 name string | same as above, plus a hint (typically the schema's source filename) for human-readable diagnostics and tooling lookup; readers MUST verify the looked-up schema's hash matches the embedded hash |
| **External by multihash** | `0x13` (binary) — `uvarint(multicodec) ‖ uvarint(len) ‖ digest` | the same content-hash, self-describing (crypto-agility L34); decoders fail closed on unregistered codes |

The schema's content-hash is the **SHA-256 of the schema's strict
CANONICAL TEXT bytes** — a schema's identity IS its Tier-1 document
identity, one primitive (I1, E2/L82; the former CXCol-encoding basis
and its #724 framing ambiguity are superseded). The hash is invariant
under comment edits, whitespace changes, and source reorganization
(canonical text normalizes them all).

**Mode-in-identity (I1 ledger entry 25 — RESOLVED, I5 stream 1):**
the schema header (§2) is ordinary body data, so `of` / `mode` /
`name` / `version` all ride in the canonical text and therefore in
the content-hash — two schemas differing only in mode are two
schemas with two identities, as E2 requires ("schema-mode rides in
the hash as document bytes and is never a separate policy input").
The pre-I5 directive spellings leaked these values out of the
hashed bytes (strict canonical strips `[?cx …]` directives); they
are retired and rejected at schema load.

Path / URL references (`[?cx schema=path/to/x.cxs]`,
`[?cx schema=https://...]`) are **tooling-layer** features. The
`cx table` subcommand and `cx validate` CLI accept paths and
resolve them to a content-hash before emit; the wire format itself
defines no path / URL semantics. This keeps the wire format
deterministic and free of confused-deputy / TOCTOU concerns; see
`threat-model.md`.

### 13.2 — Tooling transformations

Four `cx schema` subcommand transformations bridge between the
three reference forms. These ship with the `cx table` subcommand
phase, after V core schema validator implementation lands.

| command | input | output | use |
| ------- | ----- | ------ | --- |
| `cx schema embed --doc=D --schema=S` | doc D + schema S | doc D' with inline-schema reference | bundle a schema into a CXCol for self-contained delivery |
| `cx schema extract --doc=D` | doc D with inline schema | (doc D' with content-hash reference) + (schema S) | unbundle for content-addressable storage |
| `cx schema bundle --schemas=S1,S2,...` | one or more `.cxs` files | content-addressable schema archive (manifest + schema contents keyed by hash) | build a schema registry / content store for content-hash references to resolve against |
| `cx schema unbundle --bundle=B` | content-addressable schema archive | individual `.cxs` files in a directory | inverse of `bundle`; useful for reviewing a registry's contents |

`embed` and `extract` are inverses (modulo formatting, since
`extract` materializes the schema as canonical CX text). `bundle`
and `unbundle` operate on the schema registry layer that adopters
populate from a corpus of authoritative `.cxs` files.

Adopters who run schema-driven CXCol pipelines typically: author
schemas as `.cxs` files; `cx schema bundle` them into a registry
(content-addressable on a shared filesystem, S3 bucket, or git
LFS); produce schema-driven CXCol outputs that reference schemas by
content-hash; consumers point libcx at the registry via
`CX_SCHEMA_STORE` (or per-call API parameter) and resolve schemas
on-the-fly during decode.

### 13.3 — The runtime registry: names are hints, hashes are identity

The runtime named-schema surface (stream 16 W4, L63) generalizes the
`0x12` rule to every resolution hop. `register-schema` (validate.md
§3.2) binds a LOCAL NAME to the schema's content-hash and retains the
schema text; `validate-against` resolves **name → hash → content**,
fail-closed at every hop: an unknown name, an unpinned hash, or store
content that fails hash self-verification all raise `CXER1600` — a
poisoned store never resolves. Resolution order: in-process bindings,
then the module's `cx.lock` `[schemas]` pins (lockfile.md). Content
order: the in-process registry, then `CX_SCHEMA_STORE` — a
content-addressed directory (`<hex[0..2]>/<hex>.cxs`) whose reads
recompute the canonical-bytes hash over what was read
(formatting-invariant) and whose writes are cache-writes
(silent-degrade; the binding is the act). The stored/registered
CONTENT is the VERBATIM text; canonical bytes are the HASH BASIS
only (#791 — canonical data emission is not a schema-semantics-
preserving carrier for `::T`-annotated tokens). Rebinding a name is
allowed (a hint-binding, not an identity); module-level pins ride
`cx.lock` (`cx lock --pin-schema NAME=FILE.cxs`), the stream-19
address posture.

`infer` and `export` shipped with stream 16 (§16, §14); `compat`
shipped under RULED: SEA-1 (§16.5); the §13.2
`embed|extract|bundle|unbundle` transformations remain spec-only.

---

## 14 — Conversion behavior

Schemas describe CX documents. They do not directly describe
JSON, YAML, TOML, XML, or delimited equivalents. The ONE projection
exception is `cx schema export --to=json-schema` (stream 16 W6,
shape_inference.md §9): a Ring-0 conversion emitting JSON Schema
2020-12 that describes the document's LOSSLESS JSON projection (the
conversions.md §2.2.1 `\$tag` envelope) — element types become
`\$defs` objects, `[card]` becomes `contains`/`minContains`/
`maxContains`, and type-bearing child kinds ride their
`{"cx:T": …}` carriers. Deterministic and byte-stable per schema
identity; golden-pinned. XSD export follows #288's
mapping-table-with-declared-non-goals.

- **CX → XML**: schema validation (if invoked) runs on the CX
 side. The XML output is whatever the existing CX → XML
 conversion produces. There is no XSD generation.
 Adopters who need XSD for downstream consumers either write it
 by hand or wait for the future schema-export feature
 (planned for "Later").
- **CX → JSON / YAML / TOML / MD**: same — schema validates the
 CX side; no JSON Schema / YAML schema generation.
- **XML / JSON / YAML / TOML → CX**: importing a non-CX document
 produces a CX document. Validation against a `.cxs` runs after
 import; it does not look at the source format.

A schema may not span format boundaries — e.g., it cannot say
"this attribute must be `:int` in CX but `:string` in JSON
output." Per-format shape control is the separate work
item (rubric §6 output-shape control); the two are
complementary.

---

## 15 — Conformance fixtures expected

The implementation cycle produces conformance fixtures
under `vcx/tests/conformance/schema/` covering at least:

1. **Required attribute success** — schema declares `[req]`,
 doc has it, validates clean.
2. **Required attribute failure** — schema declares `[req]`,
 doc omits it, `S002` reported.
3. **Cardinality success** — schema declares `[card "1..3"]`,
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
17. **Root mismatch** — doc root differs from the header's `of`; `S017`.
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

## 16 — Schema inference (`cx schema infer`)

Corpus shape synthesis (stream 16 W3, shape_inference.md §8 — L68
normative): `cx schema infer FILE...` reads a corpus of documents
(every document's top-level elements must share ONE name — that name
becomes `of=`; mixed roots refuse loudly) and emits a deterministic
open-mode `.cxs`. Ring 0 — no evaluator; the verb ships in both the
monolith and the `data` profile.

**The join lattice (normative):** identical→identical; `int ⊔ float
→ float` (the one collapsing join — §10.4's validator already admits
int where float is declared); `decimal` joins only `decimal` (the
no-mixing rule); anything else → a sorted `[or …]` — inference NEVER
widens to string. Containers join ITEM-WISE (`[list int] ⊔ [list
float]` → `[list float]`, never textual union members). Observed
attr absence → `[opt]`; observed child counts → `[card "M..N"]`
(absence and late first-sight floor the minimum to 0); a body absent
in some occurrences → `[opt]`; mixed-content bodies are left untyped
(open mode covers them).

**Determinism contract:** the same corpus yields byte-identical
output (attrs / elems / types / or-members all name-sorted, the root
type first, the CLI sorts its file list, no timestamps) — an
inferred schema's content-hash is therefore a stable E2 identity.

**Mode and sampling:** emitted schemas are always `mode=open` (they
describe what was seen). Sampling is full-corpus by default;
`--sample=N` bounds it to the first N documents and records
`sample="N/TOTAL"` in the header (identity-bearing, but
corpus-determined — the determinism contract holds).

**Correctness property (fixture-pinned):**
`validate(docs, infer(docs))` → zero diagnostics, for every corpus
in the fixture family.

---

## 16.5 — Schema compatibility (`cx schema compat`) — RULED: SEA-1

The L149 compatibility predicate
([`schema_event_evolution.md`](schema_event_evolution.md) §5 — "a
decidable Ring-0 pure predicate … surfaced as `cx schema compat`"),
shipped. Ring 0 — no evaluator; the verb ships in both the monolith
and the `data` profile.

```
cx schema compat [--rename=TYPE/OLD=NEW]... [--allow-remove=TYPE/FIELD]...
                 [--output=FILE] OLD.cxs NEW.cxs
```

Both operands parse as schemas (§2); their identities are their
content addresses (§13.1, spelled `sha2-256:<hex>`). The verb
classifies **every field-level change** between the two declaration
forms into the closed class set below, derives the **translator**
(an *upcaster document*, below) for the mechanically-derivable
classes, and **refuses** — with a specific prompt naming the missing
rule per change — for the reinterpreting classes. The acceptance
sentence this implements: *an author is stopped ONLY when the change
genuinely reinterprets data; additive changes deploy silently.*

### 16.5.1 — The change classes (normative)

| class | detected when | verdict |
| ----- | ------------- | ------- |
| `:additive-optional` | new `[opt]` attribute; new child element with min-cardinality 0; new type declaration | derivable — identity (old documents/events already valid) |
| `:additive-default` | new attribute carrying `[default V]` | derivable — the upcaster materializes `V` on old data |
| `:default-changed` | an existing `[default]`'s value changed | derivable — the upcaster materializes the **old** default explicitly on old data lacking the field (old meaning preserved; the new default binds new data only) |
| `:rename` | **declared** via `--rename TYPE/OLD=NEW` — never guessed (SEA-1a: a removed field plus an added same-shaped field is mechanically indistinguishable from a rename, and a guessed rename silently moves data) | derivable — key rename, value bytes unchanged |
| `:widen` | a constraint loosened: enum superset, `[range]`/`[len]` superset, cardinality widened, `[req]`→`[opt]`, a type widened along §16's join lattice (`int → float`; member added to `[or …]`), `[pattern]` removed, mode loosened (`closed`→`strict`→`open`) | derivable — identity |
| `:narrow` | a constraint tightened: `[req]` added (**breaking even in open mode** — open waives undeclared content, not declared requirements, L149), enum subset, `[range]`/`[len]` shrunk, cardinality narrowed, `[or]` member removed, `[pattern]` added **or changed** (regex containment is not mechanically provable — treated as tightening), mode tightened | **REFUSED** — the prompt names the field and the rule needed (a mapping for now-out-of-domain values) |
| `:remove` | attribute / child element / type declaration removed | **REFUSED** by default (dropping a field loses data — SEA-1c); the explicit `--allow-remove TYPE/FIELD` acknowledgment derives the dropping translator (a field-level drop is payload rewriting, never a shred — journal.md §3.9's never-shred rule binds the whole `[event]` payload) |
| `:reinterpret` | a declared type changed outside the join lattice; the root `of` changed; a body kind changed | **REFUSED** — no acknowledgment path; the author supplies a hand-written upcaster via an authored lineage claim |

A rename **candidate** (exactly one removed and one added attribute
of identical declared shape within one type) that was *not* declared
refuses under `:remove` + the additive class of the added field, and
the refusal prompt **names the candidate pair** and the `--rename`
declaration that would derive it.

### 16.5.2 — The derived translator (the upcaster document)

On a derivable verdict, `--output=FILE` writes one CX document: the
**Lane-2 lineage claim itself, carrying the derived rules as data**
(RULED: SEA-1g — `[?modify]`, the one lossless in-language element
surgery, is classified impure by code.md §6.5.0, so a *generated pure
def* cannot spell a lossless rewrite; the rules therefore ride the
claim and the journal seam applies them natively):

```cx
[schema-lineage
  [from '<old-address>']
  [to '<new-address>']
  [relation :additive]
  [upcaster <derived-name>]
  [derived root=<root>
    [set-default attr=<name> value='<literal>' vtype=<type>]*
    [rename-attr from=<old> to=<new>]*
    [drop-attr attr=<name>]*
    [rename-elem from=<old> to=<new>]*
    [drop-elem elem=<name>]*]]
```

The rule vocabulary is **closed** (exactly the five forms above —
each mechanically implied by a derivable class); every derivable
class is an additive evolution, so the derived relation is always
`:additive` (narrowing/split/merge claims are authored, never
derived). The claim composes directly as a journal §3.9 chain —
`{upcast: <claim>}` or the `lineage-path`-ordered claim sequence
(journal.md §3.9, the derived-chain form).

Derivation semantics (SEA-1b, normative — enforced by the seam's
native applier):

- The rules rewrite **exactly** the entries whose payload declares
  `schema=` equal to the **old** address: per-field surgery on the
  authored payload — undeclared/open-mode content rides through
  untouched (**lossless by construction**; a derived translator never
  enumerates-and-rebuilds) — then `schema=` restamps to the new
  address.
- Entries declaring the **new** address pass through unchanged.
- Entries declaring an address **unknown to the chain** refuse (the
  seam's loud `CXER4641`) — stale vocabulary never silently passes.
- Entries declaring **no** schema pass through — there is no claim to
  translate.

**Determinism:** the same schema pair plus the same declarations
yields a byte-identical translator document — the translator is
content-addressable, and the claim's content address is the chain's
trust identity exactly per journal.md §3.9's derived-chain form.

### 16.5.3 — Report, refusals, exit codes

The report (stdout) is a `[schema-compat from=<addr> to=<addr>
verdict=derivable|identical|refused]` element carrying one
`[change class=… type=… field=…]` child per classified change and,
on refusal, one `[missing-rule class=… type=… field=… prompt='…']`
child per reinterpreting change — the prompt is specific (it names
the field, the old and new declarations, and the rule that would
admit the change). Nothing is derived on a refused verdict.

Exit codes: `0` — derivable (or the two schemas are identical);
`1` — refused (missing rules named); `2` — usage / parse / load
failure (matches §10.3.1's convention).

Publish-time and install-time consumers of this verdict are the
distribution spec's
([`xap_feature_distribution_market.md`](../xap/xap_feature_distribution_market.md)
§6.1): lineage derivation at `pkg-publish`, coverage enforcement at
`pkg-install`.

---

## 17 — References

- [`grammar.ebnf`](../formal/grammar.ebnf) — `[?cx schema=...]` directive reservation.
- [`abi.md`](abi.md) — C ABI conventions; `cx_validate` lands per
 these conventions.
- [`code.md` §9.5](code.md) — error-code wire-code map; schema codes
 use the `S` prefix (`S001–S020`), distinct from the `CXER` numeric
 wire-code namespace.
- W3C XML Schema Part 1: Structures (XSD 1.1) — primary
 intellectual reference for the constraint vocabulary.
- RELAX NG (ISO/IEC 19757-2) — secondary intellectual reference,
 particularly for the cardinality / element-content patterns.
- Google RE2 — <https://github.com/google/re2/wiki/Syntax> —
 the regex flavor for `[pattern …]`.
