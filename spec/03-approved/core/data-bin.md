# CX Binary Data Format Specification (`cx_to_data_bin`)

**Status:** Current.

Format identifier: CXCol v1.

This document specifies the byte-level format produced by `cx_to_data_bin`
and consumed by `cx_from_data_bin`. The format is the strict-canonical
binary serialization of CX data — equivalent in semantics to the strict
canonical text form (see [`canonical.md`](canonical.md) §3) but in compact
bytes.

The format is distinct from the AST binary protocol (`cx_to_ast_bin`),
which preserves full parse-tree structure including comments and anchors.
`cx_to_data_bin` is for data binding (`loads`/`dumps` style consumption);
it preserves only data-equivalence form, identical to what semantic JSON
would carry but with full type fidelity and tabular efficiency.

This spec is normative. Conforming implementations produce byte-identical
output for the same input.

---

## 1 — Goals and non-goals

### 1.1 Goals

- **Strict canonical**: byte-identical output across implementations for
 the same input. Suitable for hashing and signed bundles.
- **Type fidelity**: integers preserve width and signedness; floats
 preserve bit-exact representation; dates and decimals preserve precision.
- **Compact**: varint-encoded integers and lengths; bit-packed bool
 columns; per-table string dictionaries; columnar layout for tables.
- **Self-describing**: tag bytes carry type information; no schema needed
 to deserialize. Streaming-friendly (one pass, forward-only).
- **Hardened**: every length is validated against remaining input before
 allocation; recursion depth tracked; reserved bits and tags rejected.
- **Versioned**: header carries format version. Forward-compatible
 capability bits in flags. Reserved tag space for v2 features.

### 1.2 Non-goals

- **Not lossless w.r.t. text presentation**: comments, anchors, aliases,
 CXDirectives, and BlockContent markers are stripped (they are
 presentation, not data). The text canonical form preserves these; the
 data binary form does not.
- **Not the AST format**: use `cx_to_ast_bin` when full parse-tree
 fidelity is required (tooling, debuggers, format converters).
- **Not random-access**: this is a sequential-decode format. A future v2
 may add a footer with table offsets for memory-mapped random access.

---

## 2 — Encoding primitives

### 2.1 Endianness

Little-endian throughout. The header flags byte declares this; readers
verify on header parse. Big-endian machines byte-swap on read.

### 2.2 Unsigned varint (uvarint)

Standard length-quantity encoding compatible with Protobuf's varint.

- Each byte's low 7 bits carry payload.
- High bit (`0x80`) is the continuation flag: set means more bytes follow.
- Little-endian byte order: least-significant 7 bits first.
- Maximum width: **5 bytes** (caps the value at `2^32 - 1` for length
 fields). Implementations must reject 6-byte varints when used for
 lengths. For value ints, see §3.4.

Examples:

| Value | Bytes |
|------------|-------|
| 0 | `00` |
| 127 | `7F` |
| 128 | `80 01` |
| 16383 | `FF 7F` |
| 16384 | `80 80 01` |
| 2³² − 1 | `FF FF FF FF 0F` |

**Canonical constraint**: minimal width. The encoding `00 80` (an extra
zero byte before terminator) is a valid varint mathematically but is
forbidden in canonical form. Readers must reject non-minimal varints.

### 2.3 Signed varint (zigzag)

For signed integer values (§3.4). Maps signed to unsigned by interleaving
positive and negative numbers around zero, then applies uvarint.

- Encode: `(n << 1) ^ (n >> 63)` for `i64`.
- Decode: `(u >> 1) ^ -(u & 1)`.

### 2.4 Length-prefixed bytes

Used for strings, byte values, bigints, decimals, and dictionary
payloads. Layout: `uvarint(length) bytes(length)`. Readers verify
`length ≤ remaining_input` *before* allocating the destination buffer.

### 2.5 UTF-8 strings

All strings are UTF-8. No normalization on storage (input bytes preserved
exactly). For comparison purposes (duplicate-key detection), readers
apply NFC normalization to the comparison only, not to the stored bytes.

Invalid UTF-8 input is an error. The format does not transmit replacement
characters.

---

## 3 — Header and value encoding

### 3.1 File / message header

```
offset size field value
─────────────────────────────────────────────────────────────────
0 5 magic "CXCol" (0x43 0x58 0x43 0x6F 0x6C)
5 1 version 0x01 (CXCol v1)
6 1 flags bit 0 = endian (1 = LE; 0 reserved)
 bit 1 = schema-driven encoding
 (1 = schema reference precedes
 root value per §3.13; 0 = self-
 describing root value)
 bits 2-7 reserved (must be zero)
7 4 max_depth uint32 LE: maximum recursion depth allowed
 by writer; readers may use this to
 pre-allocate a stack and abort when the
 actual depth exceeds it.
11 1 reserved must be zero in v1
12 ... <schema-ref> present iff flags bit 1 = 1 (§3.13.1)
N ... <root value> encoded per §3.2
```

Total fixed header: **12 bytes**. When flag bit 1 is unset, the root
value follows immediately at offset 12. When flag bit 1 is set, a
schema reference (§3.13.1) intervenes between offset 12 and the root
value.

Readers MUST reject any payload whose first 5 bytes are not
`0x43 0x58 0x43 0x6F 0x6C` with the "bad magic" error — no
fallback path exists.

The root value tag may be any value tag (§3.2). The most common roots are
map (`0x50`) for object-shaped data, table (`0x60`) for tabular data, and
chunked-table (`0x63`, §3.11) for tabular data that exceeds memory.

**Schema-driven encoding (flag bit 1).** When set, the writer has omitted
per-value type tags wherever the schema (§3.13.1) declares the value's
type. The reader walks the schema in lockstep with the data to recover
those types. Tag-omission is **per-field**: declared fields are
tag-omitted, undeclared fields fall back to self-describing form. See
§3.13 for the full encoding contract. Capability bit 24 (`0x1000000`)
signals reader / writer support.

### 3.2 Tag byte assignments

Tags are 1 byte. Ranges:

| Range | Purpose |
|-------------|---------|
| 0x00–0x07 | Sentinel scalars (null, bool) |
| 0x08–0x0F | Reserved for future singletons |
| 0x10–0x1F | Numeric scalars |
| 0x20–0x2F | Floats and decimals |
| 0x30–0x3F | String, bytes, temporal scalars |
| 0x40–0x4F | Array / Sequence-as-Item containers |
| 0x50–0x5F | Map (element/object) containers |
| 0x60–0x6F | Table containers (incl. chunked tables, §3.11) |
| 0x70–0x77 | CXDM Item kinds (atom, Path, Iterator) |
| 0x78–0x7F | Reserved for v2 (delta arrays, string pool, footer index) |
| 0x80–0x8F | Reserved |
| 0x90 | Page-compression wrapper (§3.12) |
| 0x91–0xFF | Reserved (must reject in current versions) |

### 3.3 Sentinel scalars

| Tag | Meaning | Payload |
|------|---------|---------|
| 0x00 | null | (none) |
| 0x01 | false | (none) |
| 0x02 | true | (none) |

`0x03–0x07` reserved.

### 3.4 Numeric scalars

The integer tags use width-tagging because zigzag varint loses width
information that some host types care about (e.g., Rust's `i8` vs `i64`).
Canonical writers select the **smallest tag that fits the value**.

| Tag | Meaning | Payload |
|------|---------|---------|
| 0x10 | int8 | 1 byte signed |
| 0x11 | int16 | 2 bytes signed LE |
| 0x12 | int32 | 4 bytes signed LE |
| 0x13 | int64 | 8 bytes signed LE |
| 0x14 | uint8 | 1 byte unsigned |
| 0x15 | uint16 | 2 bytes unsigned LE |
| 0x16 | uint32 | 4 bytes unsigned LE |
| 0x17 | uint64 | 8 bytes unsigned LE |
| 0x18 | bigint | length-prefixed (§3.4.1) |
| 0x19–0x1F | reserved | |

**Canonical constraint**: writers MUST select the narrowest tag that
preserves the value. `42` is `0x10 2A`; `42` as `0x13 2A 00 00 00 00 00 00 00`
is non-canonical. Readers compare using mathematical value, not tag.

The canonical encoding promotes through the signed types first; an
unsigned tag (`0x14–0x17`) is used **only** when the source declared an
unsigned type explicitly (via type annotation `::u8` / `::u16` / `::u32` / `::u64`).
Default integer auto-typing produces signed widths.

#### 3.4.1 bigint encoding

For integer values outside the `i64` / `u64` range. Layout:

```
0x18 uvarint(byte_length) <byte_length bytes>
```

The bytes encode a **two's-complement big-endian** signed integer, in
the minimum number of bytes required (no leading `0x00` for positive,
no leading `0xFF` for negative-without-information).

Per the host-type-mapping spec ([`../misc/type-mapping.md`](../misc/type-mapping.md)), bindings whose
host int type cannot represent the value error on decode rather than
truncating.

### 3.5 Floats and decimals

| Tag | Meaning | Payload |
|------|-----------|---------|
| 0x20 | float64 | 8 bytes IEEE 754 binary64, LE |
| 0x21 | float32 | 4 bytes IEEE 754 binary32, LE |
| 0x22 | float16 | 2 bytes IEEE 754 binary16, LE |
| 0x23 | reserved | |
| 0x28 | decimal | length-prefixed (§3.5.1) |
| 0x29–0x2F | reserved | |

**Canonical constraints**:
- NaN, +Inf, -Inf are rejected on write and read. Encoders error; decoders error.
- Negative zero is preserved bit-exact.
- `float32` / `float16` are emitted only when the source carried an
 explicit `::f32` / `::f16` annotation. Default `::float` is `float64`.
- Subnormals are preserved bit-exact.

#### 3.5.1 decimal encoding

Arbitrary-precision decimal. Layout:

```
0x28 zigzag_varint(exponent) uvarint(coef_byte_length) <coef_bytes>
```

- `exponent` is signed `i64` zigzag-varint.
- `coef_bytes` is the unsigned big-endian byte representation of the
 coefficient's absolute value, minimum-width (no leading zeros).
- Sign of the value is encoded as the sign bit in the *first* coefficient
 byte's high bit when `coef_bytes.length > 0` and value is negative.
 Specifically: a leading bit set to 1 indicates negative; canonical
 writers add a leading `0x00` byte if the high bit would otherwise be
 set on a positive value.

Value is `(-1)^sign × coefficient × 10^exponent`.

Bindings map to host decimal types per [`../misc/type-mapping.md`](../misc/type-mapping.md):
- Python `decimal.Decimal`
- Java `BigDecimal`
- C# `decimal` (with overflow check; falls back to error)
- Rust `rust_decimal::Decimal` or feature-gated alternative
- JS: precise-string fallback or `Decimal.js` if linked

### 3.6 String, bytes, temporal scalars

| Tag | Meaning | Payload |
|------|-----------|---------|
| 0x30 | string | uvarint(length) UTF-8 bytes |
| 0x31 | date | 4 bytes: i16 year LE, u8 month, u8 day |
| 0x32 | datetime | 12 bytes (§3.6.1) |
| 0x33 | bytes | uvarint(length) raw bytes |
| 0x34 | reserved | |
| 0x35–0x3F | reserved | |

#### 3.6.1 datetime encoding

```
0x32 i64 unix_nanos (8 bytes LE) i16 offset_minutes (2 bytes LE) u16 reserved (2 bytes; zero)
```

- `unix_nanos`: nanoseconds since Unix epoch UTC. Negative values represent
 pre-1970 instants. Range covers ±292 years from epoch.
- `offset_minutes`: signed offset from UTC in minutes. `0` for `Z`. Range
 ±1080 (±18:00 hours, the IANA maximum).
- `reserved`: 2 bytes, must be zero.

**Strict canonical constraint**: `offset_minutes` is **always 0** in
strict canonical form. Datetime offsets are normalized to UTC during
strict canonicalization (per [`canonical.md`](canonical.md) §2.6).

For dates that include sub-nanosecond precision in the source, the
fractional component is rounded to the nearest nanosecond at encode time
(half-to-even). The text canonical form preserves the original precision;
the data binary form does not. This is documented as a known precision
boundary.

### 3.7 Date encoding

```
0x31 i16 year (LE) u8 month u8 day
```

- `year`: signed 16-bit, supports BCE via negative values (range
 −32768..+32767).
- `month`: 1-12.
- `day`: 1-31, validated against `month` and leap-year rules.

Invalid dates (e.g., `0x31 E7 07 02 1E` = Feb 30, 2023) are rejected
on read.

### 3.8 Array container

```
0x40 uvarint(count) <value>(count)
0x41 empty array (no payload)
```

Tag `0x41` is the canonical encoding for an empty array (zero-length
array). Tag `0x40` with `count = 0` is non-canonical and rejected by
readers.

Values are encoded sequentially with no padding. Each value carries its
own tag, so heterogeneous arrays are supported.

#### 3.8.1 Sequence-as-Item container

```
0x44 uvarint(count) <value>(count)
0x45 empty Sequence-as-Item (no payload)
```

Tag `0x44` encodes a CXDM Sequence boxed into a single Item position
(per `cxdm.md §2.7`). Distinct from Array (`0x40`) so that round-trip
preserves the Sequence-as-Item vs Array distinction required by
`cxdm.md §2.7`. Otherwise identical wire layout to `0x40`.

Tag `0x45` is the canonical encoding for an empty Sequence-as-Item;
`0x44` with `count = 0` is non-canonical and rejected.

`0x42` / `0x43` / `0x46–0x4F` reserved.

### 3.9 Map container (element / object)

```
0x50 uvarint(pair_count) <key, value>(pair_count)
0x51 empty map (no payload)
```

Tag `0x51` is canonical for empty map. `0x50` with `count = 0` is
non-canonical and rejected.

Each pair: `<key>` followed by `<value>`. Pair order is preserved
insertion order from the source. Sorting is not performed.

**Key types**: Map keys MUST encode using one of the seven atomic
scalar tags permitted by `cxdm.md §2.6`:

| Tag | Key kind |
|------|----------|
| `0x01` / `0x02` | bool (`false` / `true`) |
| `0x10–0x1F` | int (any sized integer variant) |
| `0x20–0x2F` | float / decimal |
| `0x30` | string |
| `0x31` | date |
| `0x32` | datetime |
| `0x33` | bytes |

`null` keys (tag `0x00`), atom keys (tag `0x70`), Path keys (`0x71`),
and Iterator keys (`0x72`) are forbidden per `cxdm.md §2.6` — readers
reject them with `cx-err:D004 E_INVALID_MAP_KEY`.

**Duplicate key detection**: readers track keys within each map using
the canonical-key serialization (per `canonical.md §2.11.1`). On
detecting a duplicate key, readers error unless the binding's `loads`
was called with `strict=false` (in which case last-wins and a warning
is recorded). Writers never emit duplicate keys in canonical form —
they error on encountering duplicate keys in the source AST.

`0x52–0x5F` reserved.

### 3.10 Table container

```
0x60 table-with-meta (§3.10.1)
0x61 empty table (no payload)
0x62 table-with-dict-columns (§3.10.2)
0x63 chunked table (§3.11)
```

Tag `0x61` is canonical for an empty table. Empty table has zero columns
and zero rows.

`0x64–0x6F` reserved.

#### 3.10.1 Table layout (`0x60`)

```
0x60
uvarint(col_count)
<col-spec>(col_count)
uvarint(row_count)
<col-payload>(col_count)
```

`<col-spec>`:

```
<string-key> (tag 0x30, the column name)
<col-type> (1 byte type code, §3.10.3)
```

`<col-payload>`: depends on `<col-type>`. See §3.10.3 for layouts.

Column-major order: all of column 0's values, then all of column 1's
values, etc. This is the source of the format's compactness for tabular
data — the column type is declared once, and per-value tag bytes are
omitted.

#### 3.10.2 Dictionary-encoded columns (`0x62`)

For columns where the distinct value count is significantly less than
the row count (categorical data: status, region, type). Format:

```
0x62
uvarint(col_count)
<col-spec>(col_count) — same as 0x60
uvarint(row_count)
<col-payload-or-dict>(col_count)
```

Each column's payload begins with a tag indicating whether the column is
dictionary-encoded:

```
0x00 no dictionary; payload follows §3.10.3
0x01 dictionary-encoded
```

For dictionary-encoded:

```
0x01
uvarint(dict_distinct_count)
<value>(dict_distinct_count) — distinct values in insertion order
uvarint_per_row(dict_index) — packed varints, one per row
 (varint width grows as needed)
```

Distinct values may be of any column-compatible type. Indexes into the
dictionary are zero-based. Indexes are stored as varints; for very small
dictionaries (≤ 16 distinct values) writers MAY use packed-nibble
encoding (high nibble = row 2k, low nibble = row 2k+1), but this is a
v1.1 extension and is not used in v1.

**Canonical constraint**: writers use dictionary encoding only when the
dictionary actually saves bytes (distinct_count × avg_value_size +
row_count × index_varint_width < row_count × avg_value_size). Otherwise
the column is emitted plain. The canonical writer evaluates this for
each column independently.

#### 3.10.3 Column type codes and payloads

| Code | Type | Payload (per row, plain encoding) |
|------|-----------|-----------------------------------|
| 0x00 | null | (none — all rows are null) |
| 0x01 | bool | bit-packed (§3.10.4) |
| 0x10 | int8 | 1 byte signed × row_count |
| 0x11 | int16 | 2 bytes signed LE × row_count |
| 0x12 | int32 | 4 bytes signed LE × row_count |
| 0x13 | int64 | 8 bytes signed LE × row_count |
| 0x14 | uint8 | 1 byte × row_count |
| 0x15 | uint16 | 2 bytes LE × row_count |
| 0x16 | uint32 | 4 bytes LE × row_count |
| 0x17 | uint64 | 8 bytes LE × row_count |
| 0x18 | bigint | length-prefixed × row_count (§3.4.1) |
| 0x20 | float64 | 8 bytes × row_count |
| 0x21 | float32 | 4 bytes × row_count |
| 0x22 | float16 | 2 bytes × row_count |
| 0x28 | decimal | length-prefixed × row_count (§3.5.1) |
| 0x30 | string | length-prefixed UTF-8 × row_count |
| 0x31 | date | 4 bytes × row_count |
| 0x32 | datetime | 12 bytes × row_count |
| 0x33 | bytes | length-prefixed × row_count |
| 0x80 | nullable | wrapper (§3.10.5) |
| 0x81 | mixed | per-row tagged values (§3.10.6) |

Other type codes reserved.

#### 3.10.4 Bit-packed bool columns

```
type_code = 0x01
ceil(row_count / 8) bytes
```

Byte 0, bit 0 (LSB) is row 0. Byte 0, bit 1 is row 1. Byte 1, bit 0 is
row 8. Trailing bits in the last byte (above row_count) are zero.

#### 3.10.5 Nullable column wrapper (`0x80`)

```
0x80
<inner_type_code>
ceil(row_count / 8) bytes — null bitmap, bit 0 of byte 0 is row 0;
 bit set = null
<inner_payload — only for non-null rows, packed sequentially>
```

A column where some rows are null and others are typed. The bitmap
indicates null rows; the inner payload contains values only for non-null
rows (count = row_count − popcount(bitmap)). This is more compact than
encoding a per-row presence byte plus a value.

#### 3.10.6 Mixed column (`0x81`)

For columns with heterogeneous value types (rare in well-typed CX data,
but possible). Each row carries its own tag byte.

```
0x81
<value>(row_count)
```

Equivalent in size to encoding the column as part of a `0x50` map per row;
discouraged but supported for round-trip fidelity when the source had no
declared column type and rows differ.

---

## 3.10a — CXDM Item kinds (`0x70`–`0x72`)

Three CXDM Item kinds defined in `cxdm.md §§2.3 / 2.8 / 2.9` require
distinct wire tags. Cap-bit advertisement per `abi.md §3`:
**bit 33** (atom), **bit 36** (Path joint with MatchNode/ModifyNode in
ast_bin v8), **bit 37** (Iterator).

### 3.10a.1 Atom (`0x70`)

```
0x70 uvarint(name_len) <name UTF-8 bytes>
```

Encodes an atom scalar per `cxdm.md §2.3`. `name` matches the atom
literal production `[A-Za-z_][A-Za-z0-9_-]*` (validated on read).
Atoms are **type-strict against strings** (`cxdm.md §5.1`): a buffer
that decodes `0x70 03 6f 6b` produces atom `:ok`, NOT the string
`"ok"` — the two values compare unequal under `cxdm.md §5.1`.

Reserved atom names `:true` / `:false` / `:null` are rejected on read
with `cx-err:CXER0100` (per `cxdm.md §2.3` + grammar [122b]).

Atoms are forbidden as map keys (per `cxdm.md §2.6` / §3.9 above).

### 3.10a.2 Path (`0x71`)

```
0x71 <ast_bin §4.4 PathNode payload>
```

Encodes a first-class CXPath value (per `cxdm.md §2.8`). The wire
payload is byte-identical to the ast_bin v8 PathNode payload defined
in `ast-bin.md §4.4` (form discriminator + optional binding NCName +
`steps[]` + trailing top-level predicates). Decoders rely on the
ast_bin v8 codec to read the payload.

Path values are forbidden as map keys (per `cxdm.md §2.6`).

### 3.10a.3 Iterator (`0x72`)

```
0x72 u8:source_kind u8:single_use <source_args wire>
```

Encodes a CXDM Iterator (per `cxdm.md §2.9`). The wire payload after
the `0x72` tag byte is byte-identical to the IteratorNode payload
defined in [`ast-bin.md §4.7`](ast-bin.md) — `source_kind`
(IteratorSourceKind ordinal), `single_use` (declarative source
property), `u16 LE:source_args_count`, then `source_args[]` per the
per-kind shape table. `source_kind` byte values:

| ordinal | kind |
|---|---|
| `0x00` | `iter_range` |
| `0x01` | `iter_map` |
| `0x02` | `iter_filter` |
| `0x03` | `iter_take` |
| `0x04` | `iter_drop` |
| `0x05` | `iter_concat` |
| `0x06` | `iter_zip` |
| `0x07` | `iter_enumerate` |
| `0x08` | `iter_chunks` |
| `0x09` | `iter_cycle` |
| `0x0a` | `iter_scan` |
| `0x0b` | `iter_flatten` |
| `0x0c` | `iter_partition` |
| `0x0d` | `iter_group_by` |

`single_use` is a declarative property of the source program (`0x00`
re-walkable, `0x01` single-use; see `ast-bin.md §4.7`) and **IS**
carried on the wire. The runtime-derived `memo[]` and `exhausted`
fields from the in-memory AST shape are **NOT carried on the wire** —
decoders restore a fresh iterator with `memo=[]` / `exhausted=false`
that re-evaluates from source on first pull (per `ast.md` IteratorNode
AST-vs-wire note).

Iterator values are forbidden as map keys (per `cxdm.md §2.6`).

`0x73–0x77` reserved.

---

## 3.11 — Chunked table (`0x63`)

A chunked table declares its column schema once and emits zero or more
**row groups**, each carrying a bounded subset of the table's rows.
Forward-decodable (each row group is byte-length-prefixed; readers may
skip groups they don't need) and memory-bounded for both writer and
reader.

Capability bit 21 (`0x200000`) signals reader / writer support per
[`abi.md §3`](abi.md).

### 3.11.1 — Layout

```
0x63 chunked-table tag
uvarint(col_count)
<col-spec>(col_count) same shape as §3.10.1 col-spec
<row-group>* zero or more
0x00 end-of-table marker (uvarint of 0)
```

A chunked-table with zero row groups is valid (the marker `0x00`
follows the column specs immediately). Such a table is semantically
equivalent to an empty `0x60` table with the same col-spec; canonical
writers prefer `0x60` when emitting an empty table they hold in memory.

### 3.11.2 — Row-group format

```
<row-group> :=
 uvarint(body_byte_len) bytes of the body that follow; > 0
 <body-tag> 1 byte: 0x01 = plain, 0x90 = compressed-zstd (§3.12)
 <body> exactly (body_byte_len - 1) bytes
```

`body_byte_len = 0` is the end-of-table marker (a single `0x00`
byte) and is mutually exclusive with a row group (which has
`body_byte_len > 0`).

**Plain body (`<body-tag> = 0x01`):**

```
0x01
uvarint(row_count) > 0
<col-payload>(col_count) column-major per §3.10.3,
 each column scoped to this group's rows
```

**Compressed body (`<body-tag> = 0x90`):**

See §3.12 — the page-compression wrapper. The decompressed bytes form
a plain body without the leading `0x01` tag (the wrapper substitutes
for it):

```
decompressed = uvarint(row_count) <col-payload>(col_count)
```

Body-tag values other than `0x01` and `0x90` are reserved; readers
reject them.

### 3.11.3 — Canonicality of chunking

A given table chunked into N row groups produces **different**
strict-canonical bytes than the same table chunked into M ≠ N
row groups. The chunk boundaries are part of the canonical form and
are reflected in `cx_hash`.

Canonical writers use `0x60` (non-chunked) when all rows fit in
memory. When chunking is forced (streaming write, oversized table),
the strict-canonical chunk size is **2²⁰ rows per group** (with the
last group carrying the remainder). `cx canonical` and `cx hash`
re-chunk inputs to this default before emitting / hashing.

Adopters who want chunk-invariant hashing across writers either
(a) materialize through `0x60` when the row count permits, or
(b) agree on the 2²⁰-rows-per-group canonical chunk size.

### 3.11.4 — Worked example: chunked table with two row groups

Six rows of `[name::string, score::i32]`, chunked at 4 / 2:

Row groups:
- group 0: rows ("alice", 91), ("bob", 88), ("carol", 73), ("dave", 95)
- group 1: rows ("eve", 84), ("frank", 60)

Wire bytes:

```
43 58 43 6F 6C 01 01 40 00 00 00 00 header (12 bytes; CXCol v1, LE, no schema-driven)
63 chunked-table tag
02 col_count = 2
30 04 6E 61 6D 65 30 col 0: name "name" (4 bytes), type string (0x30)
30 05 73 63 6F 72 65 12 col 1: name "score" (5 bytes), type int32 (0x12)

 -- row-group 0: 39 body bytes (body-tag + row_count + col-payloads) --
 27 body_byte_len = 39
 01 body-tag = 0x01 (plain)
 04 row_count = 4
 -- column 0 (string, 4 rows): 21 bytes (uvarint(len) + bytes per row) --
 05 61 6C 69 63 65 "alice" (1+5=6)
 03 62 6F 62 "bob" (1+3=4)
 05 63 61 72 6F 6C "carol" (1+5=6)
 04 64 61 76 65 "dave" (1+4=5)
 -- column 1 (i32, 4 rows): 16 bytes --
 5B 00 00 00 91
 58 00 00 00 88
 49 00 00 00 73
 5F 00 00 00 95

 -- row-group 1: 20 body bytes --
 14 body_byte_len = 20
 01 body-tag = 0x01 (plain)
 02 row_count = 2
 -- column 0 (string, 2 rows) --
 03 65 76 65 "eve"
 05 66 72 61 6E 6B "frank"
 -- column 1 (i32, 2 rows) --
 54 00 00 00 84
 3C 00 00 00 60

00 end-of-table marker
```

A 6-row non-chunked `0x60` table of the same data weighs ~7 bytes less
(it omits the row-group framing); chunked form's overhead is a constant
≈ `2-3 × num_row_groups + 1` bytes. The cost is negligible relative to
the multi-GB inputs the format targets.

### 3.11.5 — Worked example: empty chunked table

```
43 58 43 6F 6C 01 01 40 00 00 00 00 header
63 chunked-table tag
02 col_count = 2
30 04 6E 61 6D 65 30 col 0: "name" / string
30 05 73 63 6F 72 65 12 col 1: "score" / i32
00 end-of-table marker
```

Total: 12 + 1 + 1 + (6 + 1) + (7 + 1) + 1 = 30 bytes.

---

## 3.12 — Page-compression wrapper (`0x90`)

A row-group body in §3.11 may be wrapped in zstd compression. The
wrapper applies at the **row-group body** position; `0x90` is not
permitted at the value-level (root, map value, array element) or
inside a column payload.

Capability bit 22 (`0x400000`) signals reader / writer support per
[`abi.md §3`](abi.md).

### 3.12.1 — Layout

```
0x90 compression-wrapper tag (body-tag per §3.11.2)
<codec-id> 1 byte: 0x01 = zstd v1
 0x00 reserved (no compression)
 0x02–0xFF reserved
uvarint(uncompressed_byte_len)
uvarint(compressed_byte_len)
<compressed_byte_len bytes> codec-specific payload
```

For `<codec-id> = 0x01` the payload is a **single zstd v1 frame**
(per [RFC 8478](https://www.rfc-editor.org/rfc/rfc8478)). The frame
decompresses to a plain row-group body (§3.11.2):

```
decompressed = uvarint(row_count) <col-payload>(col_count)
```

Note: the plain-body's leading `0x01` body-tag is **not** part of the
decompressed bytes — the `0x90` wrapper substitutes for it. Writers
producing a compressed row group thus compress only the
`uvarint(row_count) <col-payload>(col_count)` portion, not a full
plain body.

`<codec-id> = 0x00` is reserved and not legal in canonical form;
adopters wanting "wrapped but uncompressed" use the plain `0x01`
body-tag form instead.

### 3.12.2 — Canonicality: hash over uncompressed bytes

`cx_hash` decompresses 0x90-wrapped row groups before computing the
SHA-256. Compression level, zstd dictionary use, and zstd block
boundaries do **not** affect the hash. A chunked table written at
`zstd -1` and the same table written at `zstd -19` produce
**identical** `cx_hash` values.

This is a deliberate design choice: storage / transport (compression)
and content identity (hash) remain orthogonal.

A chunked table whose row groups mix plain and compressed forms is
legal; the hash decomposes per-group and is invariant of that mixing.

### 3.12.3 — Worked example: 2-row group, zstd-compressed

Same 4-row group from §3.11.4 column 0 + 1, compressed:

```
... (same chunked-table prefix through col-spec) ...

 -- row-group 0 (compressed) --
 uvarint(body_byte_len) e.g., 0x18 = 24 (depends on actual zstd size)
 90 body-tag = 0x90 (compressed)
 01 codec-id = 0x01 (zstd v1)
 1D uncompressed_byte_len = 29
 (= 1 + 25 + 16 from the §3.11.4 plain body
 minus the body-tag byte)
 13 compressed_byte_len = 19 (illustrative)
 <19 bytes of zstd v1 frame> compresses to: row_count(=4) + col0(25 B) + col1(16 B)
```

Decompressing the 19-byte frame yields:

```
04 row_count = 4
05 61 6C 69 63 65 03 62 6F 62 ... col 0 string payloads
5B 00 00 00 58 00 00 00 ... col 1 i32 payloads
```

— identical to the §3.11.4 plain body without its leading `0x01`.

For typical analytical workloads (low-cardinality strings, monotonic
ints, repeated keys) zstd compresses CXCol row groups by 2-5×.

---

## 3.13 — Schema-driven encoding (header flag bit 1)

When header flag bit 1 is set, the document is **schema-driven**: per-
value type tags are omitted wherever the schema declares the value's
type. The reader walks the schema in lockstep with the data and
recovers the omitted types from the schema declarations.

Tag-omission is **per-field**: schema-declared fields are tag-omitted,
undeclared fields fall back to self-describing CXCol encoding (the
exact byte sequence that would have been emitted with flag bit 1
unset). Schema-driven and self-describing form thus coexist in a
single document.

Encoding and validation are **decoupled**. A schema in scope (e.g.,
via `[?cx schema=...]` directive) does **not** auto-promote the
encoder to schema-driven mode. Schema-driven encoding is an explicit
opt-in (`cx_to_data_bin --schema-driven`, streaming-writer open
variant). Validation (per [`schema.md`](schema.md)) runs
orthogonally — a document can be self-describing and validated,
schema-driven and unvalidated, both, or neither.

Capability bit 24 (`0x1000000`) signals reader / writer support.

### 3.13.1 — Schema reference

When flag bit 1 is set, a schema reference appears between the 12-byte
header and the root value:

```
12 1 schema-ref-tag 0x10 / 0x11 / 0x12
13 ... schema-ref-payload variable; per-tag (below)
N ... <root value> first byte at the end of schema-ref
```

Schema-ref-tag values:

| tag | form | payload |
|------|------|---------|
| 0x10 | content-hash only | 32 bytes: SHA-256 of schema's CXCol strict-canonical encoding |
| 0x11 | inline schema | uvarint(schema_byte_len) <schema_byte_len bytes>; the schema as a recursive CXCol blob |
| 0x12 | content-hash + name hint | 32 bytes hash; uvarint(name_byte_len); <name bytes> as UTF-8; informational |
| 0x13–0x1F | reserved | |

The schema content-hash is computed as **`SHA-256(cx_to_data_bin(parse(schema_text), strict_canonical))`**.
This is the same primitive `cx_hash` applies to data documents; see
[`canonical.md`](canonical.md).

The `0x12` name hint is a UTF-8 string (commonly the schema's source
filename, e.g., `"book.cxs"`). Readers MAY use it to look up the
schema in a content-addressable store, but MUST verify that the
looked-up schema's hash matches the embedded 32-byte hash. The wire
format defines no path / URL / scheme semantics; those are tooling-
layer concerns (the `cx table` subcommand resolves `--schema-from=`
arguments to a content-hash before emit).

A schema reference is **mandatory** when flag bit 1 is set. Readers
that encounter flag bit 1 set without a schema reference reject the
document.

### 3.13.2 — Tag-omission rules

The reader walks the schema's type-declaration tree in lockstep with
the data. Each map node (`0x50 ...`) corresponds to a schema type
declaration whose name matches the map's enclosing context (root
matches `[?cx schema-of <name>]`; nested matches the parent's
`[elem <name>]` declaration).

For each `(key, value)` pair in a map:

1. **Key.** Encoded as a normal string (`0x30 uvarint(len) bytes`).
 Schema-driven encoding does not omit map keys.
2. **Value.** If the schema declares an `[attr <key>::<T> ...]`
 matching the key, the type tag is **omitted** and the value is
 encoded as the typed payload only (e.g., `::u16` value = 2 bytes
 LE without a leading `0x15`). If the schema does not declare the
 key (under `open` mode per [`schema.md §9`](schema.md)) the
 value is encoded with full tag (self-describing fallback).

For each scalar body (`[name::T value]`):

- If the schema declares `[body::<T> ...]` for a scalar type, the
 body's type tag is omitted; the value is encoded as the typed
 payload only.
- If the body shape is `elem` or `mixed` (per [`schema.md §6`](schema.md)),
 children encode normally (each child Element is a `0x50` map;
 recursion applies).
- If `[body ...]` is absent (no body declared), the body is encoded
 self-describing.

For tables (`0x60` / `0x62` / `0x63`):

- Per-cell type bytes are already omitted by the §3.10 column-major
 layout; schema-driven encoding has **no additional effect on
 column-internal data**.
- Schemas that declare a table body matching the table's column
 declarations enable validation but do not change the wire layout.
 Future minor revisions may extend tag-omission to drop the col-spec
 when schema declares it.

For arrays (`0x40`):

- Array elements remain self-describing. Schemas declare
 `[list T]` (typed array, per [`schema.md`](schema.md)) which
 validates the array but does not yet drive tag-omission for array
 elements.

The reader maintains a schema cursor that descends in lockstep with
the data cursor. When the data exits a typed scope (EndElement
boundary in the conceptual stream), the schema cursor pops to the
parent declaration. When data enters an undeclared scope (open mode,
unknown element name), the schema cursor enters a "no-schema"
sentinel state and self-describing fallback applies for every value
inside the unknown subtree.

### 3.13.3 — Worked example: schema-driven map

Schema (`server.cxs`):

```cx
[?cx schema-of server]
[server
 [body [elem]]
 [attr host::string [req]]
 [attr port::u16 [req]]
 [attr active::bool [default true]]
]
```

Document:

```cx
[server host=localhost port=8080 active=true]
```

Without schema-driven (header flag bit 1 = 0; §8.2 reproduced):

```
43 58 43 6F 6C 01 01 40 00 00 00 00 header (flags = 0x01 = LE)
50 03 map / pair_count = 3
30 04 'host' 30 09 'localhost' (host: string)
30 04 'port' 15 90 1F (port: int16 with tag 0x15)
30 06 'active' 02 (active: bool true)
```

Byte count: 49.

With schema-driven (flag bit 1 = 1, schema referenced by hash):

```
43 58 43 6F 6C 01 03 40 00 00 00 00 header (flags = 0x03 = LE | schema-driven)
10 <32-byte SHA-256> schema-ref tag 0x10 + 32 bytes
50 03 map / pair_count = 3
30 04 'host' 09 'localhost' (host: string — type tag 0x30 omitted; uvarint length retained)
30 04 'port' 90 1F (port: u16 — type tag 0x15 omitted; raw 2-byte LE retained)
30 06 'active' 02 (active: bool — bool's `0x02` IS the value; sentinel scalars
 per §3.3 don't have a separate tag-vs-payload split,
 so schema-driven encoding leaves them unchanged)
```

Byte count: 49 + 33 (schema-ref) − 2 (host tag, port tag omitted) = 80.

The example shows that schema-driven encoding pays a fixed 33-byte
schema-reference overhead. For small documents (this 49-byte example)
the overhead dominates. For large documents the per-field tag savings
amortize. Adopters use schema-driven mode when the document is large
relative to the schema reference (typical: hundreds of KB+), and use
self-describing mode when the document is small or the schema isn't
well-known to the consumer.

For string values, the type tag `0x30` is what tells the reader "the
next bytes are a length-prefixed string". When omitted, the reader
must know from the schema that the next bytes form `uvarint(len)
<len bytes>`. That's exactly what the schema declaration `:string`
provides. The byte cost of the value's raw encoding is unchanged;
only the tag prefix is dropped.

### 3.13.4 — Worked example: schema-driven with undeclared field (open mode)

Same schema as §3.13.3. Document adds an undeclared `region` field:

```cx
[server host=localhost port=8080 active=true region=us-west]
```

Under `[?cx schema-mode open]` (default), the validator accepts
`region`; the encoder encodes it self-describing:

```
... (header + schema-ref + 'host' / 'port' / 'active' as in §3.13.3) ...
30 06 'region' 30 07 'us-west' (region: undeclared; type tag 0x30 retained)
```

The reader walks the schema cursor in lockstep through `host`, `port`,
`active`. When it encounters `region`, the cursor finds no
declaration; it falls back to reading a self-describing value (full
`0x30 ...` string).

Under `[?cx schema-mode closed]`, the encoder rejects `region` at
emit time (`S012`); a schema-driven CXCol document with `region`
encoded as self-describing fallback would be rejected by the reader's
validation pass even if the wire bytes decode correctly.

### 3.13.5 — Reader-side error modes

Schema-driven decode fails in these cases:

- **Schema not available.** The schema reference is content-hash only
 (or content-hash + name hint) and the consumer's content-addressable
 store does not contain the schema. Reader errors with code `D001`.
 Tooling MAY retry with a different store; core libcx fails closed.
- **Schema content-hash mismatch.** The looked-up schema's actual hash
 differs from the reference's embedded hash. Reader errors with code
 `D002`.
- **Schema disagreement with data.** The data violates the schema in a
 way that breaks decoding (e.g., a `:u16` field but the next 2 bytes
 decode as a value outside `:range` would; or worse, the data's wire
 layout doesn't match what the schema implies). Reader errors with
 code `D003` and reports the byte offset.
- **Schema reference present but flag bit 1 unset (or vice versa).**
 Inconsistent header. Reader errors with code `D004`.

Codes `D001`–`D099` reserved for schema-driven decode errors. Other
schema-domain errors continue to use the `S` prefix per
[`schema.md §12`](schema.md).

---

## 4 — Length and recursion limits

### 4.1 Default limits

Writers declare `max_depth` in the header (§3.1). Readers also enforce
their own limits independently:

| Limit | Default | Rationale |
|-------|---------|-----------|
| Recursion depth | 64 | Most real CX is ≤ 16 deep; 64 has headroom |
| Single string length | 256 MB | Above this, callers should chunk |
| Single bytes length | 256 MB | Same |
| Container count | 100 M elements | Pathological array/map size |
| Total document size | 4 GB | uvarint width for lengths is capped at 4 bytes |

Readers MUST reject documents that exceed their configured limits with a
recoverable error indicating which limit was hit. Limits are configurable
per-call; the defaults above are the minimum a conforming reader must
accept.

### 4.2 Bounds checking

Every length-prefixed payload is bounds-checked **before** allocation:

- `length ≤ remaining_input` → proceed to allocate and read.
- `length > remaining_input` → reject as malformed input.

This prevents the classic "claim 4 GB length, allocate, OOM" attack.

Recursion is tracked via a counter incremented on each container open
(`0x40`, `0x50`, `0x60`, `0x80`). Exceeding the configured depth is an
error.

---

## 5 — Reserved features

The following features are designed-for but not implemented at the
current spec version. Readers reject any tag from these reserved
ranges; future minor / major revisions will activate them without
disturbing already-shipped wire bytes.

The reserved-features window is `0x78–0x7F` (per §3.2 tag map). The
prior `0x70` range originally earmarked for these features is now
allocated to CXDM Item kinds (atom / Path / Iterator) — see §3.10a.
Tag assignments below are illustrative; concrete bytes are fixed at the
revision that activates them.

### 5.1 Delta-encoded arrays / columns (`0x78`)

For monotonic sequences (timestamps, IDs):

- `0x78 delta_array` — store first value plus diffs.
- Sub-tag declares diff encoding (zigzag varint, fixed-width).
- Big win for log/event data.

### 5.2 Document-level string pool (`0x79`)

For documents with many repeated strings (recurring keys, shared
namespaces):

- `0x79 string_pool` — header-level pool of distinct strings; map keys
 and string values reference by index.
- Engaged when overall size savings exceed the pool's overhead.

### 5.3 Footer index (`0x7A`)

For memory-mapped random access to large files:

- File ends with `0x7A footer_offset` pointing to a footer block.
- Footer contains offsets of top-level tables and large containers.
- Enables `mmap` + seek to read column-of-interest without full scan.

Random-access footer indexing is **deferred indefinitely**. CXCol's
bridge model treats Parquet as the columnar-projection target;
adopters who need footer-indexed random access transcode to Parquet
via the Arrow bridge.

### 5.4 Run-length encoded columns (`0x7B`)

For columns with long runs of repeated values. Compact wire form for
sorted or low-entropy data. Deferred indefinitely — RLE is one of
the encoding-density features CXCol cedes to Parquet via the Arrow
bridge.

---

## 6 — Conformance

### 6.1 Writer requirements

A conforming writer:

1. Produces byte-identical output for the same input AST under strict
 canonical rules.
2. Uses minimal-width varints throughout.
3. Selects the narrowest scalar tag that preserves the source value.
4. Rejects NaN, Inf, duplicate keys, invalid UTF-8, and integer overflow
 per [`canonical.md`](canonical.md) validity preconditions.
5. Includes the file header in every output.
6. Sets reserved bits to zero.
7. When emitting a chunked table (§3.11), uses byte-length prefixes on
 every row group and terminates with a single `0x00`. Writers that
 target strict-canonical use 2²⁰ rows per group with the last
 group carrying the remainder.
8. When emitting a page-compression wrapper (§3.12), records the
 uncompressed body length correctly and produces a single zstd v1
 frame.
9. When emitting schema-driven encoding (§3.13), includes a schema
 reference between the header and the root value; `cx_hash` of the
 document over the canonical (uncompressed, possibly schema-driven)
 bytes matches the value `cx_hash` would compute on a self-describing
 re-emission of the same data.

### 6.2 Reader requirements

A conforming reader:

1. Verifies magic, version, flags before any further parsing.
2. Validates every length against remaining input prior to allocation.
3. Tracks recursion depth and rejects overflow.
4. Rejects non-minimal varints.
5. Rejects tags in reserved ranges.
6. Rejects reserved bits set to non-zero.
7. Errors on NaN, Inf, duplicate keys, invalid UTF-8.
8. Errors when a value's bigint tag exceeds the host's representable
 range (per [`../misc/type-mapping.md`](../misc/type-mapping.md)).
9. Accepts chunked-table containers (`0x63`) per §3.11, decodes row
 groups in source order, and bounds memory by the largest single
 row group's body length.
10. Accepts page-compression wrappers (`0x90`) per §3.12. Errors with
 `D005` if the codec id is not 0x01 (zstd v1) at this spec version.
11. Accepts header flag bit 1 (schema-driven) per §3.13, looks up the
 schema by content-hash, and walks the schema cursor in lockstep
 with the data. Errors per §3.13.5 when the schema is unavailable
 or mismatches.

### 6.3 Reference fixtures

The conformance suite (see [`../misc/parity-matrix.md`](../misc/parity-matrix.md))
includes binary fixture files: `fixture.input.cx` + expected
`fixture.data.bin`. All bindings produce byte-identical `data.bin`
output for these inputs. Drift is a conformance failure.

Fixture set (see `conformance/data_bin_chunked.txt`,
`conformance/data_bin_compression.txt`,
`conformance/data_bin_schema_driven.txt`):

- Chunked-table round-trips: single row group, multi row group,
 empty (zero row groups).
- Compressed forms: hash invariance across uncompressed and
 compressed encodings of the same logical data.
- Schema-driven round-trips: inline schema (`0x11`), external
 schema by content hash (`0x10`), partial schema with mixed
 tag-present and tag-omitted fields under `open` mode.

---

## 7 — Versioning

`CXCol v1` is the format version declared by the version byte (`0x01`).

Future versions:

- **v1.x point releases**: additive changes that don't touch the wire
 layout. New optional capability bits in the flags byte. Existing v1
 readers continue to decode.
- **v2 major release**: activates reserved features (§5). Wire layout
 may change in reserved tag ranges. v1 readers reject v2 documents at
 the version-byte check; v2 readers accept v1 documents transparently
 (canonical writers generate v1 unless v2 features are explicitly
 requested).

Strict-canonical bytes are stable within a major version: `cx hash`
produces the same SHA-256 for the same input across all conforming v1
implementations.

---

## 8 — Worked examples

### 8.1 Empty map

Input CX: `[empty]` (an element with no attributes or items).

Wire bytes:

```
43 58 43 6F 6C magic "CXCol"
01 version 1
01 flags: little-endian
40 00 00 00 max_depth 64
00 reserved
51 empty-map tag (root is the document, which
 is an empty map at the data layer)
```

Total: 13 bytes.

### 8.2 Server config

Input CX:

```
[server host=localhost port=8080 active=true]
```

Wire bytes:

```
43 58 43 6F 6C 01 01 40 00 00 00 00 header (12 bytes)
50 map tag
03 pair_count = 3
30 04 68 6F 73 74 string "host" (4 bytes)
30 09 6C 6F 63 61 6C 68 6F 73 74 string "localhost" (9 bytes)
30 04 70 6F 72 74 string "port"
11 90 1F int16 0x1F90 = 8080
30 06 61 63 74 69 76 65 string "active"
02 bool true
```

Total: 12 + 1 + 1 + (6 + 11) + (6 + 3) + (8 + 1) = 49 bytes.

(The same data in JSON: ~46 bytes. Comparable, but with full type
fidelity preserved.)

### 8.3 Numeric table

Input CX:

```
[points [table[x::f64 y::f64 z::f64]]
 1.5 2.5 3.5
 1.6 2.6 3.6
 1.7 2.7 3.7
]
```

Wire bytes (sketch; floats elided):

```
43 58 43 6F 6C 01 01 40 00 00 00 00 header
60 table tag
03 col_count = 3
30 01 78 20 col 0: name "x" (1 byte), type float64
30 01 79 20 col 1: name "y", type float64
30 01 7A 20 col 2: name "z", type float64
03 row_count = 3
00 00 00 00 00 00 F8 3F column 0: 1.5, 1.6, 1.7
9A 99 99 99 99 99 F9 3F (8 bytes per value × 3 rows)
33 33 33 33 33 33 FB 3F
00 00 00 00 00 00 04 40 column 1: 2.5, 2.6, 2.7
9A 99 99 99 99 99 04 40
33 33 33 33 33 33 05 40
00 00 00 00 00 00 0C 40 column 2: 3.5, 3.6, 3.7
9A 99 99 99 99 99 0C 40
33 33 33 33 33 33 0D 40
```

Total: 12 + 1 + 1 + 3×(2 + 1 + 1) + 1 + 9×8 = 100 bytes.

For 1000 rows of the same table: ~12 + 1 + 1 + 12 + 5 + 24000 = ~24 KB
versus JSON's ~50 KB and CSV's ~24 KB at the bytes-only level — but with
full type fidelity, schema, and signed canonicalization.

For 1000 rows where one column is a categorical string (10 distinct
values), dictionary encoding takes that column from ~10 KB to
~1 KB — dropping the total to ~16 KB. Approaching Parquet density without
the format complexity.

---

## 9 — Open questions

The following are deliberate deferrals. None block the current
spec version:

- **Random-access footer**: requires §5.3 (v2). Deferred indefinitely;
 CXCol transcodes to Parquet via the Arrow bridge for footer-indexed
 access.
- **String pool**: requires §5.2 (v2).
- **Schema-driven tag-omission for tables and arrays**: §3.13 ships
 per-attribute and per-scalar-body tag-omission; column-spec omission
 inside `0x60` / `0x62` / `0x63` containers and per-element
 tag-omission inside `0x40` arrays are future candidates.
- **Per-column compression**: §3.12 ships row-group-level compression;
 per-column compression with codec selection is a future candidate.
- **Custom user types**: extension tag space (`0xC0–0xCF`) is reserved
 for a future user-type registry. Readers reject these tags at the
 current spec version.
