# `cx-stdlib/jsonschema` — JSON Schema 2020-12 validation

```cx
[module-meta name=jsonschema tier=A status=current
  [standard ref='JSON Schema 2020-12' title='JSON Schema Core/Validation 2020-12']
  [standard ref='RE2' title='Pattern matching']]
```

**Status:** Current (post-v0.8.0 frozen addition; cx-private #6 S7)

Normative reference for the `cx-stdlib/jsonschema` sub-package — validation of a CX value against a **JSON Schema 2020-12** document (the common subset MCP tool `inputSchema`s use). It lets CX consume MCP tool schemas (which **are** JSON Schema) without reinventing.

---

## §1. Scope

`cx-stdlib/jsonschema` validates a value against a **JSON Schema** document — a JSON-native shape, distinct from the CX `[schema …]` record-form of [`cx-stdlib/validate`](validate.md). Both the schema and the value under test are ordinary CX values (a JSON object parsed by `[$json:parse]` is a map). Validation is a **pure** recursive walk; the module charges no capability.

### §1.1. Relationship to `cx-stdlib/validate`

| | `validate` | `jsonschema` |
|---|---|---|
| Schema shape | CX `[schema [field …] …]` element | JSON Schema 2020-12 (a JSON map) |
| Primary use | CX data records (pydantic-style) | MCP tool `inputSchema`s, JSON APIs |
| Outcome shape | `[ok $value]` / `[invalid [violation …]]` | `[ok]` / `[invalid [violation …]]` |

Both share the principle that **failure is an inspectable value, not a thrown error** (§2.2).

## §2. Conceptual model

### §2.1. Supported keywords (the common MCP subset)

`type` (string / number / integer / boolean / object / array / null), `enum`, `const`, `required`, `properties`, `items`, `minimum`, `maximum`, `minLength`, `maxLength`, `pattern`, `minItems`, `maxItems`.

- `type` is checked first; a type mismatch short-circuits the deeper keyword checks for that node.
- `integer` accepts an integral-valued number (a `number` with no fractional part satisfies `integer`).
- `pattern` is an **unanchored search** (JSON Schema §6.3.3) — it matches if the regex matches **any** substring (RE2 partial match), not a full match. An uncompilable pattern is treated as non-matching rather than raising.
- **Unsupported keywords are ignored** — a permissive superset is still schema-valid. Nothing is stubbed; every *supported* keyword is enforced.

Both runtime map shapes are accepted as the schema **and** the value: a `{…}` literal (a `MapNode`) and a `[$json:parse]` object (an `__cx_map__` element).

### §2.2. Validation result

`validate` returns `[ok]` on success, or `[invalid [violation keyword= path= message=] …]` — one `violation` per failed keyword, each carrying the JSON-pointer-style `path` to the offending node. Failure is data the caller iterates, never a control-flow fault.

## §3. Public function surface

| Function | Signature | Result |
|---|---|---|
| `validate` | `($value::any $schema::any)` → element | `[ok]` or `[invalid [violation …] …]` |
| `is-valid` | `($value::any $schema::any)` → bool | true when no violations |
| `violations` | `($result::element)` → `[sequence element]` | the `[violation …]` elements (empty for `[ok]`) |
| `violation-paths` | `($result::element)` → `[sequence string]` | the JSON-pointer path of each violation |

## §4. Error codes

| Code | Symbol | Raised when |
|---|---|---|
| CXER1610 | E_JSONSCHEMA_ARG_INVALID | `validate` called with fewer than the required `(value, schema)` arguments |

(A *validation failure* is the `[invalid …]` value — **not** an error code. CXER1610 is reserved for a misuse of the API itself.)

## §5. Implementation note

The recursive walk + RE2 `pattern` matching are not expressible as a pure CX `[?def]` body, so the bodies forward to native primitives (`vcx/code/stdlib_jsonschema.v`), reusing `cx-stdlib/validate`'s leaf helpers (kind classification, numeric/text extraction) and the shared RE2 engine. The outcome shape and keyword semantics above are the normative contract.

## §6. Loading semantics

Bundled in the binary; resolves via `[?lib 'cx-stdlib/jsonschema']` (the resolver string MUST be quoted). No filesystem or network access.

## §7. Conformance fixtures

`conformance/stdlib/jsonschema.cxd` — 20 behavioral cases: per-keyword pass/fail (type, enum, const, required, properties, items, minimum/maximum, minLength, pattern incl. the unanchored-search semantics), multi-violation counting, the `{…}`-literal map shape, and a realistic MCP tool-schema (object + required + enum) valid/invalid pair. Results are grounded via `is-valid` (bool), `violation-paths` (sequence), `[$count [violations …]]` (int), and CXPath `@keyword` projections.

## §8. Cross-references

- [`cx-stdlib/json`](json.md) — parses the schema + value from the wire.
- [`cx-stdlib/validate`](validate.md) — the CX-record-form sibling validator (§1.1).
- [`cx-x/mcp`](README.md#33-the-x-experimental-tier) — `validate-args` uses this to check MCP tool arguments against a tool's `inputSchema`.
