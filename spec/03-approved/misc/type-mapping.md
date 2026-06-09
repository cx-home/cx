# CX Type Mapping

**Status:** Current for v0.8.0

How CX scalar and container types map to native types in each v0.8.0
binding (V native, Python, Go, Rust). Mappings are normative; bindings
exposing different host types fail conformance. This is the source of
truth for the parity matrix (`misc/parity-matrix.md`) and for user
expectations of `loads` / `dumps` semantics. The mapping covers the
nine semantic kinds of [`core/cxdm.md §2.3`](../core/cxdm.md) plus the
storage-precision refinements admitted in `core/cxdm.md` (decimal,
bigint, i8..i64, u8..u64, f16..f64, duration, instant).

---

## 1 — Goals

- **Predictability.** A CX value of declared kind T produces the same
  host type across all bindings, modulo unavoidable host-language
  differences.
- **Type fidelity.** Scalar kind information from CX is preserved
  through `loads` to the largest extent the host type system allows.
- **Failure honesty.** When a value cannot be represented in the host
  type system without loss, the binding raises an error rather than
  silently truncating.
- **Insertion order preserved.** CX maps `loads` to ordered-map types
  in every binding.

---

## 2 — Scalar mapping table

Canonical mapping for each CX scalar kind to the binding's default
return type from `loads`.

| CX kind | V (native) | Python | Go | Rust |
|---|---|---|---|---|
| `null` | `json2.Null` | `None` | `nil` | `serde_json::Value::Null` / `Option::None` (typed) |
| `bool` | `bool` | `bool` | `bool` | `bool` |
| `int` (≤ i64) | `i64` | `int` | `int64` | `i64` |
| `int` (> i64) | `error` | `int` (arbitrary precision) | `error` | `error` (or `BigInt` under `bigint` feature) |
| `i8` / `i16` / `i32` / `i64` | (typed) | `int` | (typed) | (typed) |
| `u8` / `u16` / `u32` / `u64` | (typed) | `int` | (typed) | (typed) |
| `float` | `f64` | `float` | `float64` | `f64` |
| `f32` | `f32` | `float` | `float32` | `f32` |
| `f16` | (custom struct) | `float` (widened) | (custom struct) | (custom struct) |
| `decimal` | `Decimal` (custom) | `decimal.Decimal` | `*big.Float` (with precision) | `rust_decimal::Decimal` |
| `bigint` | `big.Integer` | `int` | `*big.Int` | `num_bigint::BigInt` |
| `string` | `string` | `str` | `string` | `String` |
| `bytes` | `[]u8` | `bytes` | `[]byte` | `Vec<u8>` |
| `date` | `time.Time` (date-only) | `datetime.date` | `time.Time` | `chrono::NaiveDate` |
| `datetime` | `time.Time` | `datetime.datetime` (tz-aware) | `time.Time` | `chrono::DateTime<FixedOffset>` |
| `duration` | `time.Duration` (i64 ns) | `datetime.timedelta` | `time.Duration` | `chrono::Duration` |
| `instant` | `time.Time` (UTC) | `datetime.datetime` (UTC) | `time.Time` (UTC) | `chrono::DateTime<Utc>` |
| `atom` | `cxlib.Atom` (name string + tag) | `cxlib.Atom` | `cxlib.Atom` | `cxlib::Atom` |

**Cell notes:**

- **Go `int` outside i64.** Returns an error. Callers needing
  arbitrary-precision integers must use `math/big.Int` via a separate
  API not part of the default `loads`.
- **Rust `int` outside i64.** Returns an error by default. The
  `bigint` feature flag (depends on `num-bigint`) enables a `BigInt`
  variant in the value enum.
- **`atom`.** Atoms are tag-shaped scalars per
  [`core/cxdm.md §2.3`](../core/cxdm.md); equality is byte-by-byte on
  the UTF-8 name and disjoint from `string`. Every binding ships a
  thin `Atom` wrapper to preserve the kind distinction at the host
  level.
- **`duration`.** Encodes as a signed nanosecond count per
  [`core/cxdm.md §2.3`](../core/cxdm.md). Host types use each
  binding's idiomatic duration kind; the wire is `int`.
- **`instant`.** Encodes as a `datetime` in UTC per
  [`core/cxdm.md §2.3`](../core/cxdm.md).
- **Storage-precision refinements** (`i8`..`i64`, `u8`..`u64`,
  `f16`..`f64`, `decimal`, `bigint`, `duration`, `instant`) collapse
  to the nine semantic kinds for equality and EBV; host bindings
  preserve the storage type through `loads` and re-emit the
  refinement in `dumps` when the source declared it.

---

## 3 — Container mapping

| CX construct | V (native) | Python | Go | Rust |
|---|---|---|---|---|
| Element (object form) | `map[string]json2.Any` (insertion-order) | `dict` (insertion-order) | `cxlib.OrderedMap` | `indexmap::IndexMap<String, Value>` |
| Array `[a, b, …]` | `[]json2.Any` | `list` | `[]any` | `Vec<Value>` |
| Typed array `T[]` | `[]T` | `list[T]` | `[]T` | `Vec<T>` |
| Map `{k: v, …}` | `map[string]json2.Any` (insertion-order) | `dict` (insertion-order) | `cxlib.OrderedMap` | `indexmap::IndexMap<String, Value>` |
| Sequence (lazy) | `cxlib.Sequence` | `cxlib.Sequence` | `cxlib.Sequence` | `cxlib::Sequence` |
| `:table` | `cxlib.Table` | `cxlib.Table` (`.to_pandas()` / `.to_polars()`) | `cxlib.Table` (`.to_arrow()`) | `cxlib::Table` (`.to_polars()` / `.to_arrow()`) |

**Insertion-order preservation is mandatory.** Per
[`core/canonical.md`](../core/canonical.md), CX preserves attribute
order; `loads` returns an ordered-map type in every binding.

Per-binding implementation notes:

- **V.** Native `map[string]X` preserves insertion order.
- **Python.** `dict` preserves insertion order (Python 3.7+).
- **Go.** Stdlib `map` is unordered; bindings ship `cxlib.OrderedMap`
  (slice-of-pairs internally; lookup via index map). Surface: `Get`,
  `Set`, `Has`, `Keys`, `Values`, `Range`, `Len`, `MarshalJSON`,
  `UnmarshalJSON`.
- **Rust.** Bindings ship `IndexMap` from the `indexmap` crate.

---

## 4 — Special semantics

### 4.1 `null` vs missing key

CX distinguishes a key with explicit `null` value from a missing key.
Bindings preserve the distinction: a present key with `null` value
returns the host's null sentinel under that key; an absent key returns
no entry.

### 4.2 Empty containers

Empty array `[]` round-trips as the host's empty array. Empty map `{}`
round-trips as the host's empty ordered-map. The two are not
interchangeable.

### 4.3 `bytes` encoding in CX text

`bytes` values are base64-encoded in CX text (`[blob '...'::bytes]`).
The parser decodes; bindings receive raw bytes in their host type.

### 4.4 `atom` vs string

Atoms (`:tag`) and strings are disjoint per
[`core/cxdm.md §5.1`](../core/cxdm.md). Bindings expose `cxlib.Atom`
(or equivalent) to preserve the distinction; an `Atom` is never `==`
to a host string.

### 4.5 Large-integer overflow

Integer overflow on `loads` is an error, never silent truncation
(`cx-err:CXER0100` on the wire; bindings raise their idiomatic
exception):

- **V.** `error` via `!` return type.
- **Python.** `OverflowError`.
- **Go.** Returns wrapped error from `Loads`.
- **Rust.** Returns `Err(CXError::Overflow)`.

### 4.6 NFC normalization

String values are bytewise preserved through `loads`. NFC
normalization is applied only for duplicate-key detection during
parse (per [`core/abi.md §1.7`](../core/abi.md) Unicode handling);
host-map keys are the original input bytes.

### 4.7 Auto-typing edge cases on round-trip

CX auto-typing produces typed scalars from unquoted tokens. After
`loads → dumps` the data is identical but presentation may differ
(unquoted `42` and `x::int 42` produce identical scalars; the quoted
`'42'` is a string). The parser refuses to auto-type integer literals
with a leading zero other than `0` itself or `0x...`; such tokens
produce a string.

### 4.8 Negative zero

`-0.0` is preserved as a distinct float bit pattern from `0.0`.
Host-language equality may collapse them (IEEE 754); bit-level
comparison and re-serialization preserve the distinction.

---

## 5 — `dumps` coercion

`dumps(value)` is the inverse direction.

| Host type | CX output |
|---|---|
| Native bool | `bool` |
| Native integer in i64 range | `int` |
| Native integer outside i64 range | `int` (bigint encoding in `cx_to_data_bin`; decimal text in CX) |
| Native float | `float` (canonical Ryū) |
| Native string | `string` (auto-quoted per [`core/canonical.md`](../core/canonical.md)) |
| Bytes / byte-array | `bytes` (base64) |
| Native date type | `date` |
| Native datetime type | `datetime` |
| Native duration type | `duration` |
| Decimal type | `decimal` |
| `cxlib.Atom` | `atom` |
| Ordered map / dict / object | Element with attributes |
| Array / list | `[]` array |
| `cxlib.Table` | `:table` block |
| Null sentinel | `null` |

Host types absent from this table cause `dumps` to error rather than
guess. Dumping a Python `set` is an error (sets are unordered; CX is
order-preserving); users explicitly convert to lists first.

---

## 6 — Per-binding optional conversions

Bindings may offer opt-in conversions beyond the defaults:

| Binding | Optional conversion |
|---|---|
| Python | `cxlib.Table.to_pandas()` → `pandas.DataFrame`; `.to_polars()` → `polars.DataFrame` |
| Rust | `cxlib::Table::to_polars()` → `polars::DataFrame`; `cxlib::Table::to_arrow()` → `arrow::record_batch::RecordBatch` |
| Go | `cxlib.Table.ToArrow()` → `*array.Record` from `apache/arrow/go` |

These are not part of the default `loads` return type and are excluded
from cross-binding conformance.

---

## 7 — Conformance fixtures

The conformance suite (per [`misc/parity-matrix.md`](parity-matrix.md))
exercises each cell of §2 and §3 with at least one fixture:

```
conformance/types/
  scalar/
    int_negative.cx
    int_max_safe.cx
    int_outside_i64.cx
    float_neg_zero.cx
    decimal_high_precision.cx
    bigint.cx
    date_bce.cx
    datetime_offset.cx
    duration_negative.cx
    instant_utc.cx
    bytes_base64.cx
    bool_both.cx
    atom_disjoint_from_string.cx
    null.cx
  array/
    homogeneous_int.cx
    homogeneous_string.cx
    mixed.cx
    nested.cx
    empty.cx
  map/
    insertion_order.cx
    null_value_vs_missing.cx
    empty.cx
    unicode_keys.cx
  table/
    typed_columns.cx
    nullable_column.cx
    dict_encoded_column.cx
    empty.cx
```

Each fixture has `expected.canonical.cx`, `expected.canonical.json`,
`expected.data.bin`, plus per-binding type assertions describing what
`loads(input)` returns as a host-typed value.

---

## 8 — Open questions

- **Schema-driven typing.** When schemas drive `loads`, declared
  column kinds may coerce more aggressively. Not part of the default
  return.
- **Custom user types.** A future extension may let bindings register
  custom (de)serializers for user-defined host types.
- **Streaming type fidelity.** `cx_events_next` returns events, not
  loaded values; type mapping applies when consumers materialize
  events into containers.
