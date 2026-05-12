# CX Type Mapping Specification
# Version: 1.0
# Date: 2026-05-06

This document specifies how CX scalar and container types map to native
types in each language binding. Mappings are normative: bindings that
expose different types fail conformance. This is the source of truth for
the parity matrix and for user expectations of `loads` / `dumps`
semantics.

The mappings are designed for predictability. Where a host language has
multiple plausible target types, this spec picks one and documents it.
Bindings may offer additional opt-in conversions (e.g., Python's
`pandas.DataFrame` for `:table`), but the default `loads` return value
follows this spec exactly.

---

## 1 — Goals

- **Predictability**: a CX value of declared type T produces the same
 host type across all bindings, modulo unavoidable host-language
 differences.
- **Type fidelity**: scalar typing from CX is preserved through `loads`
 to the largest extent the host type system allows.
- **Failure honesty**: when a value cannot be represented in the host
 type system without loss, the binding errors rather than silently
 truncating.
- **Insertion order preserved**: CX maps `loads` to ordered-map types
 in every binding (no `HashMap` / `dict` that loses order).

---

## 2 — Scalar mapping table

The canonical mapping for each CX scalar type to each binding's default
return type from `loads`. Cell format: `host_type` (notes).

| CX type | V (native) | Python | Go | Rust | TypeScript / JS | Java | Kotlin | C# | Swift | Ruby |
|---|---|---|---|---|---|---|---|---|---|---|
| `:null` | `json2.Null` | `None` | `nil` (untyped) | `serde_json::Value::Null` (default) or `Option::None` (typed) | `null` | `null` | `null` | `null` | `NSNull` | `nil` |
| `:bool` | `bool` | `bool` | `bool` | `bool` | `boolean` | `Boolean` | `Boolean` | `bool` | `Bool` | `TrueClass` / `FalseClass` |
| `:int` (≤ i64) | `i64` | `int` | `int64` | `i64` | `number` (safe) / `bigint` | `Long` | `Long` | `long` | `Int64` | `Integer` |
| `:int` (> i64) | `error` | `int` (arbitrary) | `error` | `error` (or `BigInt` if feature enabled) | `bigint` | `BigInteger` | `BigInteger` | `BigInteger` | `error` | `Integer` |
| `:i8` / `:i16` / `:i32` / `:i64` | (typed) | `int` | (typed) | (typed) | `number` (safe int) / `bigint` (i64 outside safe) | `Byte` / `Short` / `Integer` / `Long` | `Byte` / `Short` / `Int` / `Long` | `sbyte` / `short` / `int` / `long` | `Int8` / `Int16` / `Int32` / `Int64` | `Integer` |
| `:u8` / `:u16` / `:u32` / `:u64` | (typed) | `int` | (typed) | (typed) | `number` / `bigint` | `Short` / `Integer` / `Long` / `BigInteger` (no native u64) | `UByte` / `UShort` / `UInt` / `ULong` | `byte` / `ushort` / `uint` / `ulong` | `UInt8` / `UInt16` / `UInt32` / `UInt64` | `Integer` |
| `:float` | `f64` | `float` | `float64` | `f64` | `number` | `double` | `Double` | `double` | `Double` | `Float` |
| `:f32` | `f32` | `float` | `float32` | `f32` | `number` | `float` | `Float` | `float` | `Float` | `Float` |
| `:f16` | (custom struct) | `float` (widened) | (custom struct) | (custom struct) | `number` (widened) | `float` (widened) | `Float` (widened) | `Half` (.NET 5+) | `Float16` (Swift 5.3+) | `Float` (widened) |
| `:decimal` | `Decimal` (custom) | `decimal.Decimal` | `*big.Float` (with precision) | `rust_decimal::Decimal` | `Decimal.js` (peer dep) or precise string | `BigDecimal` | `BigDecimal` | `decimal` (with overflow check; falls back) | `Decimal` (Foundation) | `BigDecimal` |
| `:string` | `string` | `str` | `string` | `String` | `string` | `String` | `String` | `string` | `String` | `String` (UTF-8) |
| `:bytes` | `[]u8` | `bytes` | `[]byte` | `Vec<u8>` | `Uint8Array` | `byte[]` | `ByteArray` | `byte[]` | `Data` | `String` (binary encoding) |
| `:date` | `time.Time` (date-only) | `datetime.date` | `time.Time` | `chrono::NaiveDate` | `Date` (with time set to 00:00:00 UTC; documented gotcha) | `LocalDate` | `LocalDate` | `DateOnly` (.NET 6+) | `Date` (with time set to start-of-day; or custom struct) | `Date` |
| `:datetime` | `time.Time` | `datetime.datetime` (tz-aware) | `time.Time` | `chrono::DateTime<FixedOffset>` (lossless) / `<Utc>` (strict) | `Date` (always UTC; offset lost — documented) | `OffsetDateTime` | `OffsetDateTime` | `DateTimeOffset` | `Date` (UTC) + `TimeZone` if needed | `Time` |

**Notes on individual cells:**

- **JS/TS `:int`**: the host's `number` is IEEE 754 double-precision. Values within the safe-int range (`[-(2^53-1), 2^53-1]`) are returned as `number`; values outside the safe range are returned as `bigint`. Heterogeneous arrays mixing `number` and `bigint` are emitted unchanged. This is the single largest type-mapping wart in the spec; the alternative ("always bigint") would make idiomatic JS code unusable. Documented loudly in the migration guide.
- **Go `:int`**: outside i64 range is an error. Go has no built-in arbitrary-precision integer in idiomatic code; users wanting big ints must explicitly use `math/big.Int` via a separate API not part of the default `loads`. Pragmatic.
- **Rust `:int`**: outside i64 is an error by default. A binding feature flag `bigint` enables `BigInt` (via `num-bigint`); when enabled, the default return type for very large ints becomes `serde_json::Value::Number` widened or a `BigInt` variant in a custom value enum.
- **C# `:decimal`**: .NET's `decimal` is a 128-bit fixed-point with limited range (28-29 digits). Values with greater precision are returned as `BigInteger` × `int` exponent in a `CXDecimal` struct that may be downcast to `decimal` when in range.
- **Java `:datetime`**: the v1 spec used `Instant` (UTC); v2 widens to `OffsetDateTime` to preserve source offset in lossless mode. `Instant` is recoverable via `.toInstant()`.
- **Swift `:date`**: Swift's `Date` is technically a moment in time (not a calendar date); we map `:date` to `Date` at start-of-day UTC for ergonomic interop. Bindings may offer a `CXDate` struct for callers needing strict semantics.
- **Ruby `:bytes`**: Ruby has no first-class byte-array type; binary `String` with `Encoding::ASCII_8BIT` is the idiomatic choice.

---

## 3 — Container mapping

| CX construct | V (native) | Python | Go | Rust | TS / JS | Java | Kotlin | C# | Swift | Ruby |
|---|---|---|---|---|---|---|---|---|---|---|
| Element (object form) | `map[string]json2.Any` (insertion-order) | `dict` (insertion-order) | `cxlib.OrderedMap` (typed wrapper) | `indexmap::IndexMap<String, Value>` | `Object` (insertion-order; or `Map` if non-string keys arise — they don't in CX) | `LinkedHashMap<String, Object>` | `LinkedHashMap<String, Any?>` | `cxlib.OrderedDictionary` | `OrderedDictionary` (custom) | `Hash` (insertion-order) |
| `:[]` array (any element type) | `[]json2.Any` | `list` | `[]any` | `Vec<Value>` | `Array` | `ArrayList<Object>` | `MutableList<Any?>` | `List<object>` | `[Any]` | `Array` |
| Typed array `:T[]` | `[]T` | `list[T]` | `[]T` | `Vec<T>` | `T[]` | `ArrayList<T>` | `MutableList<T>` | `List<T>` | `[T]` | `Array` (untyped at runtime) |
| `:table` | `cxlib.Table` | `cxlib.Table` (with `.to_pandas()` / `.to_polars()`) | `cxlib.Table` (with `.to_arrow()`) | `cxlib::Table` (with `.to_polars()` / `.to_arrow()`) | `cxlib.Table` | `cxlib.Table` | `cxlib.Table` | `cxlib.Table` | `cxlib.Table` | `cxlib.Table` |

**Insertion-order preservation** is mandatory. Per `spec/canonical.md` §2.1, CX preserves attribute order; `loads` must return ordered-map types in every binding. The existing v1 implementations using `map[string]any` (Go), `BTreeMap` (Rust without IndexMap feature), and similar order-losing types are conformance failures and must be replaced.

Per-binding implementation notes:

- **V**: V's `map[string]X` preserves insertion order natively. No custom type needed.
- **Python**: `dict` preserves insertion order since Python 3.7. Minimum supported Python is 3.9; no compatibility shim needed.
- **Go**: stdlib `map` is unordered. Bindings ship a `cxlib.OrderedMap` type (slice-of-pairs internally; lookup via index map). API surface: `Get`, `Set`, `Has`, `Keys`, `Values`, `Range`, `Len`, MarshalJSON / UnmarshalJSON for ergonomic interop.
- **Rust**: bindings ship `IndexMap` from the `indexmap` crate (light, stable, idiomatic).
- **TypeScript / JavaScript**: `Object` preserves insertion order for string keys. The plain `Object` is used.
- **Java**: `LinkedHashMap` preserves insertion order. Used directly.
- **Kotlin**: `LinkedHashMap` (Java interop) used directly.
- **C#**: `OrderedDictionary` from `System.Collections.Specialized` is non-generic; bindings ship a generic `cxlib.OrderedDictionary<TKey, TValue>` wrapper.
- **Swift**: Swift's stdlib lacks a stable `OrderedDictionary`; bindings ship a custom struct (or use `Swift Collections` package if accepted as dep — decision deferred to binding maintainer; either is conformant).
- **Ruby**: `Hash` preserves insertion order since Ruby 1.9. Used directly.

---

## 4 — Special semantics

### 4.1 `null` vs missing key

CX distinguishes a key with explicit `null` value from a missing key.
Bindings preserve this distinction:

- **Present key with null value**: the host map contains the key with
 the host's null sentinel (`None`, `nil`, `null`, `NSNull`, `nil`).
- **Absent key**: the host map does not contain the key.

Code that does `loads(s).get("key")` and gets `None` cannot distinguish
"present with null" from "absent" without explicitly checking for
membership (`"key" in obj`, etc.). This matches every other modern
serialization library; documented for users.

### 4.2 Empty containers

- Empty array (`[]`) round-trips as the host's empty array.
- Empty map round-trips as the host's empty ordered-map.
- The two are not interchangeable: `loads(dumps([])) == []` and
 `loads(dumps({})) == {}` but never `[] == {}`.

### 4.3 `:bytes` encoding in CX text

`:bytes` values are base64-encoded in CX text (`[blob :bytes 'aGVsbG8='] `).
The base64 decoding happens in the parser; bindings receive raw bytes
in their host type.

### 4.4 Date-only and time-only on the wire

CX has `:date` and `:datetime` but not `:time` (time-of-day). A future
extension may add `:time`; until then, time-of-day is encoded as
either a string with documented format or a datetime where the date
component is meaningless.

### 4.5 Large integers and overflow

Per `spec/canonical.md` §1.3, integer overflow on `loads` is an error
(not silent truncation). Bindings throw / return error / panic per the
language's idiom:

- V: `error` via `!` return type.
- Python: `OverflowError`.
- Go: returns wrapped error from `Loads`.
- Rust: returns `Err(CXError::Overflow)`.
- TS: throws `CXError`.
- Java/Kotlin: throws `CXOverflowException` (subclass of `CXException`).
- C#: throws `OverflowException`.
- Swift: throws `CXError.overflow`.
- Ruby: raises `CXLib::OverflowError`.

The exception types follow each binding's idiomatic style; the behavior
(error rather than truncate) is normative.

### 4.6 NFC normalization

String values stored in maps are bytewise preserved. NFC normalization
is applied only for duplicate-key detection during parse (see
`spec/canonical.md` §6 and `spec/abi.md` §1.7). After parse, the keys
in the host map are the original input bytes.

### 4.7 Auto-typing edge cases on round-trip

CX auto-typing produces typed values from unquoted tokens. After
`loads → dumps`, the result is the same data but the dumps output may
differ presentationally from the source (e.g., source `42` and source
`:int 42` produce identical AST and dump identically, but source
`'42'` produces a string that dumps as `'42'` not `42`). This is
correct per the `spec/canonical.md` rules.

The known edge case: `[zip 02134]` auto-types `02134` as integer 2134
(leading zero stripped). Per the policy decision in this branch's
migration, **the parser refuses to auto-type integer literals with a
leading zero (other than `0` itself or `0x...`)**: the parser produces
a string in this case. Sources relying on the v1 behavior get a
documented breaking change in MIGRATION.md.

### 4.8 Negative zero

`-0.0` is preserved as a distinct float value from `0.0`. Equality
comparison in host languages may collapse them (`-0.0 == 0.0` is true
in IEEE 754 across all the languages), but bit-level comparison (and
re-serialization to CX or `cx_to_data_bin`) preserves the distinction.

---

## 5 — Type-coercion-on-`dumps`

`dumps(value)` is the inverse direction. The mapping rules:

| Host type | CX output |
|---|---|
| Native bool | `:bool` (`true` / `false`) |
| Native integer in i64 range | `:int` |
| Native integer outside i64 range | `:int` (bigint encoding in `cx_to_data_bin`; decimal text in CX) |
| Native float (any precision) | `:float` (canonical Ryū) |
| Native string | `:string` (auto-quoted per `spec/canonical.md` §2.3) |
| Bytes / byte-array | `:bytes` (base64) |
| Native date type | `:date` |
| Native datetime type | `:datetime` |
| Decimal type | `:decimal` |
| Ordered map / dict / object | Element with attributes |
| Array / list | `:[]` array (typed if homogeneous, otherwise mixed) |
| `cxlib.Table` | `:table` block |
| Null sentinel | `:null` |

Types not in this table cause `dumps` to error rather than guess. For
example, dumping a Python `set` errors (sets are unordered; CX is
order-preserving). Users explicitly convert sets to lists before
dumping. This is intentional honesty over guessing.

---

## 6 — Per-binding additional conversions

Bindings may offer **opt-in** conversions beyond the defaults:

| Binding | Optional conversion |
|---|---|
| Python | `cxlib.Table.to_pandas()` returns `pandas.DataFrame`; `.to_polars()` returns `polars.DataFrame`. |
| Rust | `cxlib::Table::to_polars()` returns `polars::DataFrame`. `cxlib::Table::to_arrow()` returns `arrow::record_batch::RecordBatch`. |
| Go | `cxlib.Table.ToArrow()` returns `*array.Record` from `apache/arrow/go`. |
| TS/JS | `cxlib.Table.toApacheArrow()` returns Arrow JS `RecordBatch`. |

These are not part of the default `loads` return type. They are explicit
conversions called by user code. Cross-binding conformance does not
depend on Arrow / pandas availability.

---

## 7 — Conformance fixtures

The conformance suite (per `spec/architecture.md` §Conformance) exercises
each cell of §2 and §3 with at least one fixture:

```
conformance/types/
 scalar/
 int_negative.cx expected outputs across all 10 bindings
 int_max_safe_js.cx
 int_outside_safe_js.cx
 float_neg_zero.cx
 decimal_high_precision.cx
 date_bce.cx
 datetime_offset.cx
 bytes_base64.cx
 bool_both.cx
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

Each fixture has expected `expected.canonical.cx`,
`expected.canonical.json`, `expected.data.bin`, plus per-binding type
assertions describing what `loads(input)` should return as a host-typed
value (encoded in a binding-specific test harness).

---

## 8 — Open questions

The following are deliberate v2 deferrals:

- **Schema-driven typing**: when the schema language ships, `loads` may
 use the schema to coerce types more aggressively (e.g., `:string` field
 declared as `:int` in schema causes a parse-time coercion). v2 does not
 do this.
- **Custom user types**: a future extension may allow bindings to
 register custom (de)serializers for user-defined host types
 (analogous to serde derive in Rust). v2 does not include this.
- **Streaming mode type fidelity**: `cx_events_next` returns events,
 not loaded values. Type mapping applies when consumers materialize
 events into containers.
