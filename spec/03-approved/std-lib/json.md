# `cx-stdlib/json` — JSON parse and emit

```cx
[module-meta name=json tier=A status=current
  [standard ref='RFC 8259' title='JSON']]
```

**Status:** Current for v0.8.0

Normative reference for the `cx-stdlib/json` sub-package.

---

## §1. Scope

`cx-stdlib/json` parses JSON (RFC 8259) into CXDM values and emits CXDM values back to JSON. Two parse modes (strict, lenient) and three emit modes (canonical, pretty, compact).

Distinct from [`cx-stdlib/format`](format.md) (CX-to-CX emission) and [`spec/core/conversions.md`](../core/conversions.md) (cross-format Document-level CLI conversion); this module is the in-program library form.

## §2. CXDM ↔ JSON mapping

The data subset round-trips ceremony-free; elements are the explicit special case.

| JSON | CX |
|---|---|
| `null` | `null` scalar |
| `true` / `false` | `bool` scalar |
| Integer | `int` scalar (per §3.1 `number-mode`) |
| Float | `float` scalar (per §3.1 `number-mode`) |
| String | `string` scalar |
| `[1, 2, 3]` | `array` value |
| `{"k": v}` | `map` value |

**Parse is lossless.** A JSON object parses to a CX `map`; a JSON array to a CX `array`; scalars to scalars — every ordinary JSON value round-trips exactly. The one exception is the **`named` element encoding** below: an object whose keys are exactly a subset of `{$tag, $attrs, $children}` with `$tag` present is parsed back into the CX **element** it encodes (the parse inverse of lossless emit), so `parse(emit(el, {lossless: true})) ≡ el`.

A CX **element** has no idiomatic JSON counterpart, so `emit` is lossy-by-default and lossless-on-demand (matching conversions.md §0.2):

- **Default (lossy, idiomatic):** an element emits **semantically** (conversions.md §2.2) — `[a 1]` → `{"a":1}`, `[server [host x]]` → `{"server":{"host":"x"}}`.
- **`{lossless: true}`:** an element emits via the `named` encoding `{"$tag":"name","$attrs":{...},"$children":[...]}`, which `parse` reconstructs exactly. There is exactly one lossless element encoding — no flat alternative.

CXDM values (`map`/`array`/scalar) emit directly to JSON in both modes.

## §3. Public function surface

### §3.1. Parsing

```
[?def parse           scope=public pure [returns any] ($s::string) ...]
[?def parse-with-opts scope=public pure [returns any] ($s::string $opts::map) ...]
[?def parse-bytes     scope=public pure [returns any] ($b::bytes) ...]
```

`parse` is strict: rejects trailing commas, unquoted keys, comments, NaN/Infinity. `parse-bytes` strips UTF-8 BOM and auto-detects UTF-16 with BOM.

Opts for `parse-with-opts`:

| Key | Default | Semantics |
|---|---|---|
| `lenient` | `false` | Accept trailing commas, JS comments, NaN/Infinity, unquoted keys; duplicate keys last-wins (§4.2) |
| `number-mode` | `"auto"` | `"auto"` — int if fits int64, float on fraction/exponent; out-of-int64 integer raises `CXER3105`. `"all-float"` accepts as lossy float; `"string"` preserves source text; `"all-decimal"` exact via decimal (cap bit 11) |
| `max-depth` | `100` | Reject deeply nested input |
| `max-bytes` | `0` | 0 = unbounded |

### §3.2. Emitting

```
[?def emit            scope=public pure [returns string] ($value::any) ...]
[?def emit-pretty     scope=public pure [returns string] ($value::any) ...]
[?def emit-with-opts  scope=public pure [returns string] ($value::any $opts::map) ...]
[?def emit-bytes      scope=public pure [returns bytes]  ($value::any) ...]
```

`emit` produces canonical form: compact, map keys sorted, deterministic (useful for hashing JSON). `emit-pretty` uses two-space indent with map insertion order preserved.

Opts for `emit-with-opts`:

| Key | Default | Semantics |
|---|---|---|
| `indent` | `0` | 0 = compact, no whitespace |
| `sort-keys` | `false` | Sort map keys alphabetically |
| `ensure-ascii` | `false` | Escape non-ASCII as `\uXXXX` |
| `trailing-newline` | `false` | Append final `\n` |
| `lossless` | `false` | Emit CX elements via the `named` `$tag`/`$attrs`/`$children` encoding (round-trips exactly via `parse`) instead of idiomatic semantic JSON (§2) |
| `nan-handling` | `"null"` | `"null"` / `"string"` / `"error"` (raise `CXER3104`) |

Elements always emit via the `named` encoding (§2); there is no shape opt.

### §3.3. Streaming

```
[?def parse-stream  scope=public pure [returns [sequence any]]    ($input::[sequence string]) ...]
[?def parse-many    scope=public pure [returns [sequence any]]    ($s::string) ...]
[?def emit-stream   scope=public pure [returns [sequence string]] ($values::[sequence any]) ...]
```

`parse-stream` consumes JSONL/NDJSON: each input element MUST be exactly one complete JSON value (line-splitting is the producer's responsibility). `parse-many` parses a single string containing multiple whitespace-separated JSON values using JSON-aware boundary detection. `emit-stream` yields one newline-terminated record per value.

### §3.4. Validation

```
[?def is-valid scope=public pure [returns bool] ($s::string) ...]
```

True iff `s` is valid JSON (strict mode). Validator-only tokenize-and-balance scan — constructs no value tree.

## §4. Edge cases and policy

### §4.1. Number precision

`number-mode "auto"` parses an integer literal as `int` if it fits int64; a number with fractional or exponent part as `float`. An integer literal whose magnitude exceeds int64 raises `CXER3105 E_JSON_NUMBER_OUT_OF_RANGE` — no silent lossy promotion. Opt in to big-int handling via `"all-float"`, `"string"`, or `"all-decimal"`.

### §4.2. Duplicate keys

Strict mode (default) raises `CXER3106 E_JSON_DUPLICATE_KEY` on a duplicate object key. Lenient mode resolves last-value-wins.

### §4.3. Element round-trip

`parse(emit(v))` structurally equals `v` for any in-domain CX value: data subset round-trips with no special encoding, elements round-trip via the `named` encoding.

### §4.4. Special float values

JSON has no NaN or Infinity. Default emits as `null`; configurable via `nan-handling`. A non-finite float can only reach the emitter across the FFI boundary; `nan-handling="error"` (`CXER3104`) guards that case. It is **not** reachable from pure CX arithmetic, which raises `CXER0101` first (CX floats are finite-only — see [`code.md`](../core/code.md) §6.5).

### §4.5. UTF-8 in output

Non-ASCII emits as-is by default; `ensure-ascii=true` escapes to `\uXXXX`.

### §4.6. Non-JSON-emittable values

The JSON-emittable kinds are exactly those with a §2 mapping: `null`, `bool`, `int`, `float`, `string`, `array`, `map`, and `element` (via the `named` encoding). Every other CXDM kind has no JSON counterpart and raises `CXER3103 E_JSON_UNSUPPORTED_VALUE` when `emit` encounters it. This includes the `atom`, `bytes`, `date`, and `datetime` scalar kinds, and any other non-JSON scalar or kind enumerated in [`cxdm.md`](../core/cxdm.md) (e.g. `sequence`). `CXER3103` is raised on first encounter, whether the value is the emit root or nested within an `array`, `map`, or element child.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER3100` | `E_JSON_MALFORMED` | `parse` on unparseable input |
| `CXER3101` | `E_JSON_DEPTH_EXCEEDED` | Nested input exceeds `max-depth` |
| `CXER3102` | `E_JSON_BYTES_EXCEEDED` | Input exceeds `max-bytes` |
| `CXER3103` | `E_JSON_UNSUPPORTED_VALUE` | `emit` on a non-JSON-emittable value (`atom`, `bytes`, `date`, `datetime`, …; §4.6) |
| `CXER3104` | `E_JSON_NAN_DISALLOWED` | `nan-handling="error"` and value contains NaN/Infinity — an FFI-boundary guard; not reachable from pure CX arithmetic (code.md §6.5) |
| `CXER3105` | `E_JSON_NUMBER_OUT_OF_RANGE` | `parse` under default `number-mode="auto"` on out-of-int64 integer (§4.1) |
| `CXER3106` | `E_JSON_DUPLICATE_KEY` | `parse` in strict mode on object with duplicate key (§4.2) |

## §6. Conformance fixtures

Under `conformance/stdlib/json.cxd`:

- JSON Test Suite (Seriot): all `y_` files parse; all `n_` files raise `CXER3100`; `i_` cases per documented policy.
- Round-trip: scalar / array / object round-trip exactly.
- Data subset is element-free: JSON object → CX `map`; plain data emits without `$tag`/`$attrs`/`$children`.
- Element round-trip via `named` encoding preserves tag, attributes, and children.
- Number modes: out-of-int64 raises `CXER3105` under `"auto"`; `"all-float"` lossy; `"string"` preserves exactly; `"all-decimal"` exact (cap bit 11).
- Duplicate keys: strict raises `CXER3106`; lenient last-wins.
- Lenient mode: trailing commas, JS comments, unquoted keys accepted.
- NaN handling: `"null"` / `"string"` / `"error"` behave as specified.
- UTF-8 output: non-ASCII as-is; `ensure-ascii=true` escapes correctly.
- Streaming JSONL: `parse-stream` + `emit-stream` correct; `parse-many` splits concatenated/pretty-printed input.
- BOM: UTF-8 stripped; UTF-16 auto-detected.
- Pretty: indentation correct; insertion order preserved.

## §7. Cross-references

- [`spec/core/conversions.md`](../core/conversions.md) — cross-format Document-level conversion (CLI).
- [`spec/std-lib/format.md`](format.md) — CX-to-CX emission.
- [`spec/std-lib/csv.md`](csv.md) — sibling cross-format module.
- RFC 8259.
