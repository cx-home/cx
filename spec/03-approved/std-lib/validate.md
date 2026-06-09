# `cx-stdlib/validate` — runtime schema validation

```cx
[module-meta name=validate tier=A status=current
  [standard ref='RE2' title='Pattern matching']]
```

**Status:** Current for v0.8.0

Normative reference for the `cx-stdlib/validate` sub-package — the **data-record validator** (JSON-Schema / pydantic-shaped) that validates a CX value at runtime via `validate-shape`.

---

## §1. Scope

`cx-stdlib/validate` validates **data records** (maps / arrays / scalars — e.g. `json` or `csv` parse results) against a record-schema. Its scalar-constraint vocabulary is **normative**.

### §1.1. Validator boundary

Two sibling validators cover two distinct shapes; pick by what you are validating:

- **Document / element tree** → [`spec/core/schema.md`](../core/schema.md) (`.cxs`, via `[?cx schema=...]`). XSD-shaped: type-decl-per-element, `body` / `attr` / `elem` / `check`, body-shape types, child-element cardinality.
- **Data record** → `cx-stdlib/validate` (this document, via `validate-shape`). JSON-Schema / pydantic-shaped: fields with scalar / nested-record constraints over the data subset of CXDM.

### §1.2. Relationship to `spec/core/schema.md`

The two validators are **siblings**, sharing **one scalar-constraint vocabulary** spelled identically: `pattern=`, `min=`, `max=`, `min-length=`, `max-length=`, `required=`, `optional=`, `type="string"|"int"|…`, `enum=[v …]`. A `pattern=` on a `[field …]` here and a `pattern=` on a `[body …]` in `.cxs` mean the same thing and apply the same RE2 full-match semantics.

Structural keywords differ because the *thing being validated* differs. `validate-with=` (§3.6) and `extends=` (§3.7) are **record-validator extensions** owned by this document.

## §2. Conceptual model

### §2.1. Schemas

A **schema** is a CX element built from the record-validation vocabulary:

```cx
[?const LEAD_SCHEMA [schema
  [field name="email"      type="string" pattern=".+@.+\..+"]
  [field name="first_name" type="string" min-length=1]
  [field name="last_name"  type="string" min-length=1]
  [field name="score"      type="int"    min=0 max=100]]]
```

Schemas can be **inline elements** passed directly to `validate-shape`, or **named references** resolved by `validate-against`.

### §2.2. Validation result

`validate-shape` returns one of two shapes:

```cx
[ok $value]

[invalid
  [violation code="TYPE_MISMATCH"    path="/score" expected="int"    got="string"       message="score: expected int, got \"abc\""]
  [violation code="PATTERN_MISMATCH" path="/email" expected=".+@.+\..+" got="not-an-email" message="email: value does not match pattern"]]
```

**Failure is data, not a thrown error.** The failure case is the *inspectable*
`[invalid …]` outcome — NOT the control-flow err sentinel `[err …]` (code.md
§9.1). A validation report is the validator's primary deliverable: data the
caller iterates, counts, and renders. Modeling it as `[err …]` would make it
**auto-propagate** through the argument of every inspection call (the err-value
convention, code.md §9.2) — so `errors-of` / `violation-paths` / `[$count …]`
could never receive a *failure* result. `[invalid …]` is ordinary data: it
never propagates, so the §3.3/§3.4 inspection API works uniformly on success and
failure. (A *malformed schema* — distinct from a value that fails validation —
still raises a genuine control-flow `[err code=cx-err:CXER16xx …]`.) This is the
general rule: **`[err]` is reserved for abort-and-propagate control-flow failure;
a function whose job is to report problems *as data* — a validator, linter,
diff, type-checker, assertion collector — returns a distinct inspectable
outcome, never the `[err]` sentinel.**

Each violation carries:

- `code=` — machine-readable violation kind (§2.3).
- `path=` — a **CXPath** locating the offending value. Directly consumable by `select` and `[?modify]` for re-inspection or repair; root violations carry `/`, nested fields carry their step path (`/address/zip`).
- `expected=` — what the schema required.
- `got=` — what the value actually was.
- `message=` — human-readable description.

### §2.3. Violation codes

| Code | Triggered when |
|---|---|
| `TYPE_MISMATCH` | Value's CXDM kind doesn't match `type=` |
| `PATTERN_MISMATCH` | String value fails `pattern=` regex |
| `MIN_VIOLATION` | Numeric value below `min=` |
| `MAX_VIOLATION` | Numeric value above `max=` |
| `MIN_LENGTH_VIOLATION` | String/sequence shorter than `min-length=` |
| `MAX_LENGTH_VIOLATION` | String/sequence longer than `max-length=` |
| `REQUIRED_MISSING` | Required field absent |
| `ENUM_MISMATCH` | Value not in `enum=` set |
| `SCHEMA_NOT_FOUND` | Named schema reference doesn't resolve |
| `UNKNOWN_FIELD` | `strict=true` schema sees extra fields |
| `NESTED_VIOLATION` | Nested-element validation produced its own violations (path is the parent path) |
| `CUSTOM_VIOLATION` | A `validate-with=` validator rejected the value without itself returning a `[violation …]` |

## §3. Public function surface

### §3.1. Validate against inline schema

```
[?def validate-shape scope=public pure [returns element] ($value::any $schema::element) ...]
```

Validate `$value` against the inline `$schema`. Returns `[ok $value]` on success or `[invalid [violation …] …]` on failure (§2.2). **Pure**: same value + schema always produce the same result.

```cx
[?let [= $result [$validate:validate-shape
                   [user [email "alice@example.com"] [score 87]]
                   LEAD_SCHEMA]]
  [?match $result
    [case [ok $v] [?str "valid: {$v/email}"]]
    [else [?str "invalid: {$result/violation/@field} failed"]]]]
```

### §3.2. Validate against named schema

```
[?def validate-against scope=public pure [returns element] ($value::any $schema-ref::string) ...]
```

Validate against a schema registered under `$schema-ref`. Raises `CXER1600 E_VALIDATE_SCHEMA_NOT_FOUND` if unregistered.

> **Operability deferred to v0.8.x.** This signature is **specified but
> not operable at v0.8.0**: there is no Current way to populate the
> named-schema registry. Schema registration (`register-schema` and the
> `[?schema-register]` directive) is deferred to a future v0.8.x
> amendment (§7). Until that ships, `validate-against` always raises
> `CXER1600` because the registry is unpopulable. Use the Current,
> fully-operable `validate-shape` (§3.1) with an inline schema instead.

### §3.3. Result inspection

```
[?def is-ok       scope=public pure [returns bool]              ($result::element) ...]
[?def errors-of   scope=public pure [returns [sequence element]] ($result::element) ...]
```

`is-ok` is true iff `$result` is `[ok …]` (false for `[invalid …]`). `errors-of` returns the sequence of `[violation …]` children of an `[invalid …]` result, or empty for `[ok …]`.

### §3.4. Composition helpers

```
[?def violation-paths    scope=public pure [returns [sequence string]] ($result::element) ...]
[?def violation-messages scope=public pure [returns [sequence string]] ($result::element) ...]
```

Project the `path=` and `message=` field of each violation.

### §3.5. Record-schema vocabulary

| Keyword | Position | Evaluated as |
|---|---|---|
| `type="T"` | `[field …]` | match value's CXDM kind against `T` (§4.5) |
| `pattern=RE` | `[field …]` | RE2 full-match on string value (§4.4) |
| `min=` / `max=` | `[field …]` | numeric bounds |
| `min-length=` / `max-length=` | `[field …]` | string/sequence length bounds |
| `enum=[v …]` | `[field …]` | membership test |
| `required=` (default) / `optional=true` | `[field …]` | presence policy (§4.2) |
| `schema=[schema …]` | `[field type="element"]` | nested validation (§4.3) |
| `strict=true` | `[schema …]` | reject undeclared fields (§4.1) |
| `validate-with=FN` | `[field …]` **or** `[schema …]` | custom validator (§3.6) |
| `extends=$BaseSchema` | `[schema …]` | field-set inheritance (§3.7); value reference (`$`-bound or inline `[schema …]`) |

The scalar constraints are the vocabulary shared with [`spec/core/schema.md`](../core/schema.md) (§1.2). `validate-with=` and `extends=` are record-validator extensions.

### §3.6. Custom validators — `validate-with=FN`

`validate-with=FN` attaches a user `[?def]` to a field or schema:

- **Field-level** — `[field name="…" … validate-with=FN]`. `FN` takes the field value; returns `true` / `[ok]` / `false` / `[violation …]`.
- **Record-level** — `[schema … validate-with=FN]`. `FN` takes the whole value; returns an ok signal or a **sequence of violations** for cross-field rules (e.g. "`end-date` > `start-date`"). Empty sequence / `true` / `[ok]` = ok.

`FN` **MUST** be `pure`. An impure `validate-with=` is a malformed schema (`CXER1603 E_VALIDATE_SCHEMA_MALFORMED`).

```cx
[?def even-score pure [returns bool] ($v::int)
  [= [$mod $v 2] 0]]

[?def dates-ordered pure [returns [sequence element]] ($rec::any)
  [?if [$time:is-after $rec/start-date $rec/end-date]
    [then [violation code="CUSTOM_VIOLATION" path="/end-date"
                     message="end-date must be after start-date"]]]]

[?const BOOKING_SCHEMA [schema validate-with=dates-ordered
  [field name="score"      type="int"      validate-with=even-score]
  [field name="start-date" type="datetime"]
  [field name="end-date"   type="datetime"]]]
```

Field-level validators run **after** the field's declarative constraints (skipped if the field already failed). Record-level validators run **last**, after all per-field validation.

### §3.7. Schema composition — `extends=`

`[schema extends=$BaseSchema [field …] …]` includes all of `$BaseSchema`'s fields plus the inline ones. A child field whose `name=` equals a base field's `name=` **replaces** the base declaration wholesale. `extends=` takes a **value reference** to the base schema: a `$`-bound name (`extends=$BASE`, the idiomatic way to reference a bound `[?const]`/`[?let]` schema value) or an inline `extends=[schema …]`. A bare word (`extends=Base`, no `$`) is a literal symbol — not a value reference — and resolves to no base schema (`CXER1603`).

```cx
[?const BASE_ENTITY_SCHEMA [schema
  [field name="id"         type="string"   pattern="[0-9a-f-]{36}"]
  [field name="created-at" type="datetime"]]]

[?const CONTACT_SCHEMA [schema extends=$BASE_ENTITY_SCHEMA
  [field name="email" type="string" pattern=".+@.+\..+"]
  [field name="phone" type="string" optional=true]]]
```

A record-level `validate-with=` on the base **also fires** under extension (both run). Cycles in an `extends=` chain are malformed (`CXER1603`).

Intersection / union composition are deferred (§7); record-level `validate-with=` covers many use cases.

## §4. Edge cases and policy details

### §4.1. Strict vs lax fields

Default schemas are **lax**: unknown fields are ignored. `strict=true` raises `UNKNOWN_FIELD`.

```cx
[schema strict=true [field name="email" type="string"]]
```

### §4.2. Optional fields

Fields default to **required**. `optional=true` opts in:

```cx
[field name="phone" type="string" optional=true]
```

Missing optional fields produce no violation.

### §4.3. Nested schemas

`type="element"` with a `schema=` child enables nested validation:

```cx
[field name="address" type="element" schema=[schema
  [field name="street" type="string"]
  [field name="city"   type="string"]
  [field name="zip"    type="string" pattern="^\d{5}(-\d{4})?$"]]]
```

Nested violations propagate up with their `path=` CXPath extended by the nesting step (`/address/zip`). The propagated path remains a well-formed CXPath, directly consumable by `select` / `[?modify]`.

### §4.4. Regex patterns

`pattern=` uses RE2 syntax — same engine as `cx-stdlib/re` (RE2 capability bit per [`spec/core/abi.md`](../core/abi.md)). Patterns compile once per schema use; reuse is cached internally.

### §4.5. Type coverage

| Type | Matches CXDM kind |
|---|---|
| `"string"` | string scalar |
| `"int"` | int scalar **only** — a float (even integral like `3.0`) is rejected (§4.5.1) |
| `"float"` | float scalar **and** int (lossless int↦float widening, §4.5.1) |
| `"number"` | int **or** float |
| `"bool"` | bool |
| `"bytes"` | bytes |
| `"date"` | date |
| `"datetime"` | datetime |
| `"duration"` | duration (per `cx-stdlib/time`) |
| `"atom"` | atom |
| `"element"` | element |
| `"sequence"` | sequence |
| `"array"` | array |
| `"map"` | map |
| `"any"` | always matches |
| `"null"` | only null |

A `type=` not in this set raises `CXER1601 E_VALIDATE_TYPE_UNKNOWN`.

#### §4.5.1. Type coercion: asymmetric int↦float widening

`type="float"` **accepts** an int (lossless widening). `type="int"` **rejects** a float — including `3.0` — because narrowing float↦int loses information in general and conflates two distinct CXDM scalar kinds. Mirrors the language's math promotion rule (int widens to float, never the reverse).

For "any integral number, including `3.0`", use `type="number"` plus a `validate-with=` check:

```cx
[?def is-integral pure [returns bool] ($v::number)
  [= $v [$floor $v]]]

[field name="quantity" type="number" validate-with=is-integral]
```

### §4.6. Custom-validator semantics

- **Purity enforced**: the referenced `[?def]` MUST carry `pure`; otherwise `CXER1603`.
- **Ordering**: field-level validators run after declarative constraints (skipped if already failed); record-level runs last.
- **Return-to-violation mapping**: `true` / `[ok]` / empty sequence → no violation. `false` → one `CUSTOM_VIOLATION` at the field's CXPath (record-level: `/`). A returned `[violation …]` is surfaced verbatim with `path=` back-filled if omitted.

### §4.7. `extends=` semantics

- **Base resolution**: `extends=` takes a value reference — `extends=$BASE` (the evaluator substitutes the bound schema value in the user's env) or an inline `extends=[schema …]`. A bare word (no `$`) is a literal symbol carrying no schema → `CXER1603`.
- **Merge**: child's effective field set is base's fields plus child's inline fields, resolved at schema-evaluation time.
- **Override by name**: child field with matching `name=` replaces the base declaration wholesale.
- **Schema-root keywords**: `strict=` and child-level `validate-with=` apply to the merged set; base-level `validate-with=` also fires.
- Single-inheritance; cycles malformed (`CXER1603`).

## §5. Error codes (CXER block 1600–1605)

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER1600` | `E_VALIDATE_SCHEMA_NOT_FOUND` | `validate-against` with unregistered `$schema-ref` |
| `CXER1601` | `E_VALIDATE_TYPE_UNKNOWN` | Schema declares a `type=` not in §4.5 |
| `CXER1602` | `E_VALIDATE_PATTERN_INVALID` | Schema declares a `pattern=` that doesn't compile under RE2 |
| `CXER1603` | `E_VALIDATE_SCHEMA_MALFORMED` | Schema structure invalid (bad shape, impure `validate-with=`, `extends=` cycle) |
| `CXER1604` | `E_VALIDATE_ENUM_INVALID` | `enum=` value is non-comparable |
| `CXER1605` | `E_VALIDATE_NESTED_DEPTH` | Nested-schema recursion exceeds implementation-defined limit (≥ 64) |

**Minimum nesting depth.** Implementations MUST accept at least 64 levels of nested-schema recursion in `validate` / `validate-shape` without raising `CXER1605`. An implementation MAY raise `CXER1605` only beyond an implementation-defined limit, and that limit MUST be ≥ 64. Consequently, `CXER1605` is guaranteed observable only at nesting depths exceeding 64; at depths ≤ 64 a conforming implementation never raises it.

## §6. Conformance fixtures

Under `conformance/stdlib/validate.cxd`:

- **Type matrix**: each `type=` from §4.5 validates a matching value to `[ok …]` and a non-matching value to `[invalid [violation code="TYPE_MISMATCH" …]]`.
- **Pattern**: valid + invalid email against `pattern=".+@.+\..+"`.
- **Min/max numeric**: in-range, below-min, above-max.
- **Min/max length**: strings and sequences.
- **Required vs optional**: missing required → `REQUIRED_MISSING`; missing optional → no violation.
- **Strict vs lax**: unknown field → `UNKNOWN_FIELD` under `strict=true`; ignored otherwise.
- **Nested schema**: violations bubble up with extended paths.
- **Multi-violation**: value with two distinct violations produces both.
- **Named schema**: `register-schema` + `validate-against`; unregistered name → `CXER1600`.
- **Composition helpers**: `errors-of` / `violation-paths` / `violation-messages` projections.
- **CXPath `path=`**: feeding `path=` to `select` returns the offending value; `[?modify]` repairs it. Nested paths (`/address/zip`).
- **Type widening (§4.5.1)**: `type="float"` accepts int; `type="int"` rejects `3.0`; `type="number"` + `validate-with=` integral-check accepts `3` and `3.0`, rejects `3.7`.
- **Field-level `validate-with=`**: `false` → `CUSTOM_VIOLATION` at field path; returned `[violation …]` surfaced verbatim with path back-filled; impure validator → `CXER1603`.
- **Record-level `validate-with=`**: cross-field rule produces `CUSTOM_VIOLATION`; ok value produces none.
- **`extends=`**: child validates base + own fields; override replaces base; cycle → `CXER1603`; base record-level `validate-with=` still fires.

## §7. Open follow-ups

- **Declarative `returns=SchemaRef` on `[?def]`** — integrates with the type checker; future amendment to the function-definition surface.
- **Schema-as-data registration directive `[?schema-register]`** — `validate-against` resolves through a named-schema registry; the registration directive specified in a future amendment.
- **Schema composition — intersection / union** — single-inheritance `extends=` ships at v0.8.0; intersection / union deferred. Record-level `validate-with=` covers many use cases.
- **Convergence with `spec/core/schema.md`** — opportunistic; not a blocker.
- **Per-language error message localization** — v0.8.0 messages are English; future `format-violations` with `locale=` localizes.

## §8. Cross-references

- [`spec/core/schema.md`](../core/schema.md) — sibling document/element-tree validator; shares this document's scalar-constraint vocabulary (§1.2).
- [`spec/std-lib/README.md`](README.md) — sub-package surface enumeration.
- [`spec/core/abi.md`](../core/abi.md) — RE2 engine capability bit used for `pattern=` validation.
- [`spec/core/code.md`](../core/code.md) §5.5 — CXPath as first-class value kind; violation `path=` values are CXPaths consumable by `select` / `[?modify]`.
- [`spec/std-lib/re.md`](re.md) — RE2 regex engine that backs `pattern=`.
