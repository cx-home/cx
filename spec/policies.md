# CX Policies Specification
# Version: 1.0
# Date: 2026-05-06

This document specifies CX's behavior at edge cases — values and inputs
where multiple plausible answers exist and the project has chosen one.
Conformance with these policies is mandatory; "no surprises" is a
project value, and silent divergence between bindings on edge-case
inputs is the most visible source of surprise.

The policies are grouped by domain.

---

## 1 — Numeric edge cases

### 1.1 NaN

`f64.NaN`, `f32.NaN`, `f16.NaN` are **rejected**. A document containing
NaN cannot be canonicalized, hashed, or serialized to `cx_to_data_bin`.

- On parse: detection of an explicit NaN literal (no syntax in CX text
 exposes NaN, so this only arises in `dumps` from host data) — error.
- On `dumps(host_value_containing_NaN)` — error with code `E101`.
- On binary read of a NaN bit pattern in float bytes — error with code
 `E102`.

Rationale: NaN ≠ NaN. Canonical-form equality and hashing are broken
by NaN. Bindings users handling NaN must convert it (e.g., to null or
to a sentinel string) before serialization.

### 1.2 +Inf / -Inf

Same treatment as NaN. Rejected on serialization (`E103`) and on
binary read (`E104`).

### 1.3 Negative zero

`-0.0` is preserved as a distinct float value from `0.0`.

- Bit-level preservation in `cx_to_data_bin`.
- Text canonical: `-0.0` (lossless and strict).
- JSON canonical: `-0.0`.
- Equality (`cx_eq`) treats `0.0` and `-0.0` as equal because they
 compare equal in IEEE 754. Hash is on canonical bytes, which
 distinguishes them; users wanting "data-equal" on `±0.0` must
 normalize before hashing.

### 1.4 Subnormals

Preserved bit-exact. No flush-to-zero.

### 1.5 Integer overflow on parse

A literal that exceeds the host type's range:

- Type-annotated value (`:i32 9999999999`): error with code `E201`.
- Auto-typed value within `:int` (default `i64`): if exceeds `i64` range,
 promoted to `bigint` (a CX-specific type, see §1.6).
- Bigint exceeding host's representable range: error with code `E202`,
 per `spec/type_mapping.md` §4.5.

### 1.6 Bigint type

CX supports arbitrary-precision integers via the `bigint` extension.
- Auto-typed when an integer literal exceeds `i64` range.
- Type-annotated as `:int` (auto-promotes) or `:bigint` (explicit).
- Encoded as length-prefixed two's-complement big-endian bytes (per
 `spec/data_bin.md` §3.4.1).
- Maps to host bigint types per `spec/type_mapping.md` §2.

### 1.7 Leading zeros in integer literals

A literal with a leading zero (e.g., `02134`) is **not** auto-typed as
integer. It is parsed as a string.

- `[zip 02134]` — `zip` element body is the string `"02134"`.
- `[year 0]` — `year` body is the integer `0`.
- `[hex 0xFF]` — `hex` body is the integer `255` (0x prefix exempts).
- Leading zero followed by other digits: string.

This is a v3.4 grammar change from v3.3. v3.3 silently parsed `02134`
as integer 2134, dropping the leading zero. The change is documented
in `MIGRATION.md` as a breaking input-handling change.

### 1.8 Decimal precision boundary

`:decimal` values are arbitrary-precision in CX text and `cx_to_data_bin`.
Host types may have finite precision (.NET `decimal` is 28-29 digits).
On `loads`:

- Value within host precision: returned as host decimal type.
- Value exceeding host precision: behavior per `spec/type_mapping.md`
 §2 cell for that binding. Default: error with code `E203` rather
 than silent truncation.

---

## 2 — String edge cases

### 2.1 Invalid UTF-8

Rejected at every entry point:

- Text input with invalid UTF-8 bytes: parse error `E301`.
- Binary input with a string field containing invalid UTF-8: read
 error `E302`.

No replacement characters are inserted. No "best effort" recovery.

### 2.2 Control characters

C0 controls (U+0000–U+001F) and DEL (U+007F) in string values:

- Allowed in input.
- Escaped on canonical output per `spec/canonical.md` §2.4.
- Preserved bit-exactly in `cx_to_data_bin`.

Control characters in element / attribute names: rejected (`E303`).
Names follow the grammar's NameChar rules.

### 2.3 BOM at start of input

UTF-8 BOM (U+FEFF as `EF BB BF`) at the very start of a CX or other
text input:

- **Stripped silently** before parsing.
- Not preserved in canonical output.
- Not emitted in canonical output even if input had one.

### 2.4 Lone surrogates

Lone surrogates (U+D800–U+DFFF) in input strings:

- In CX input or any text format: invalid UTF-8 (cannot occur in
 well-formed UTF-8), already covered by §2.1.
- In `cx_to_data_bin` UTF-8 length-prefixed strings: rejected per
 §2.1.
- In JSON input via `\uXXXX` escapes: a surrogate pair must form a
 valid pair; lone surrogates rejected (`E304`).

### 2.5 Unicode normalization

- **Stored bytes**: never normalized. Input bytes preserved.
- **Comparison** (duplicate-key detection in maps; `cx_eq`):
 NFC-normalized for comparison only.
- **Canonical output**: not normalized. Input bytes preserved.

This means two strings that are NFC-equivalent but differ in input
bytes (e.g., precomposed vs decomposed) will:

- Round-trip to the same bytes they came in as.
- Compare equal under `cx_eq`.
- Hash to different values under `cx_hash` (because hash is over
 bytes, not normalized form).

Users who need normalized hashing must explicitly NFC-normalize their
input before hashing.

### 2.6 Empty string vs missing vs null vs empty-element

CX distinguishes four "absence-of-value" states. All four are
distinct in the AST and in every binding:

| construct | meaning | type | body | parsed AST |
| --------- | ------- | ---- | ---- | ---------- |
| `[name]` | empty element — element exists with no body and no type annotation | unset | none | `Element(name="name", body=None, type=None)` |
| `[name :string]` | typed empty — element with a declared type but no body | string | none | `Element(name="name", body=None, type=String)` |
| `[name :string '']` | empty string — element with a string body of length zero | string | `""` | `Element(name="name", body=String(""), type=String)` |
| `[name :null]` | explicit null — element whose body is the null sentinel | null | `null` | `Element(name="name", body=Null, type=Null)` |

Round-trip rules:

- `cx fmt` (lossless canonical) preserves all four forms exactly.
- `cx canonical` (strict canonical) preserves the type tag but
 collapses `[name]` and `[name :null]` to a single canonical
 shape only if equality already considers them equal — see below.
- `cx_to_data_bin` encodes all four distinctly: empty-body bit
 for `[name]` and `[name :string]`; string-length-zero for
 `[name :string '']`; null-tag for `[name :null]`.

Equality (`cx_eq`) rules:

- `[name]` and `[name :null]` are **distinct** — empty element vs
 explicit null is a meaningful structural difference that
 conversion to JSON `null` collapses but CX preserves.
- `[name :string]` and `[name :string '']` are **distinct** —
 declared-type-with-no-body vs declared-type-with-empty-body.
- `[name]` and `[name :string]` are **distinct** — type
 annotation is part of structural identity.
- `[name :string '']` and `[name '']` are **equivalent** under
 `cx_eq` (auto-typed empty string == declared empty string).

Conversion to other formats:

| construct | JSON | YAML | TOML | XML |
| --------- | ---- | ---- | ---- | --- |
| `[name]` | `"name": null` | `name:` (empty mapping value) | `name = ""` (TOML has no null) | `<name/>` (empty element) |
| `[name :string]` | `"name": ""` | `name: ""` | `name = ""` | `<name/>` |
| `[name :string '']` | `"name": ""` | `name: ""` | `name = ""` | `<name></name>` |
| `[name :null]` | `"name": null` | `name: null` | error (no null in TOML; emit comments) | `<name xsi:nil="true"/>` |

These mappings are lossy in the JSON/YAML/TOML directions because
those formats don't model the four-way distinction. The reverse
direction (JSON/YAML/TOML → CX) collapses to `[name :null]` for
null and `[name :string '']` for empty string; the two
empty-element forms (`[name]`, `[name :string]`) cannot be
recovered from the lossy formats.

A missing key (an attribute or element that doesn't appear at all
in the source) is the fifth state — distinct from all four above
and not representable as any element value. The host map / object
simply does not contain the key (per `spec/type_mapping.md` §4.1).

### 2.7 Line-ending policy

CX accepts `\n` (LF), `\r\n` (CRLF), and `\r` (CR-only, classic Mac)
on input as line terminators. All three are normalized to `\n`
internally before parsing.

- **Parse**: line endings are normalized but the original
 encoding is **not** preserved on the AST. A document with
 CRLF input and another with LF input parse to byte-identical
 ASTs.
- **`cx fmt` (lossless canonical) emit**: always `\n`. The
 formatter does not preserve the source's line-ending choice;
 reformatting normalizes to LF.
- **`cx canonical` (strict canonical) emit**: always `\n` per
 `spec/canonical.md` §9.
- **Inside string literals and raw-text blocks (`[# ... #]`)**:
 line endings are preserved bit-exactly. A CRLF embedded in a
 raw-text block survives parse and round-trip; an LF in a string
 literal is `\n` (2 chars source = 1 char value if escaped, else
 1 char source = 1 char value).
- **CSV / delimited emit**:
 D3, default is `\r\n` (RFC 4180); flag to override with `\n`.

Rationale: a CX document's line-ending choice is presentation,
not data. Normalizing on parse means cross-platform git-tracked
files don't produce different ASTs. Always emitting LF on
canonical/fmt means tooling output is platform-independent.
Adopters who need to preserve specific line endings inside
string content use raw-text blocks.

---

## 3 — Map / element edge cases

### 3.1 Duplicate keys

A map with duplicate keys (after NFC normalization) is rejected by
default with code `E401`.

Bindings may expose a `strict=false` (or equivalent) option on `loads`
that:

- Logs a warning per duplicate.
- Keeps the **last** value for each duplicate key.

The default is strict (error). Lossy behavior is opt-in only.

### 3.2 Empty map vs empty array

`[empty]` (CX element with no body) parses as an empty map at the data
layer. `[empty :[]` (or `[empty :int[] ]`) parses as an empty typed
array. They are distinct host types and round-trip to distinct
canonical forms.

### 3.3 Order significance

CX preserves attribute order. `[server host=a port=80]` and
`[server port=80 host=a]` parse to the same data but produce different
canonical text bytes (lossless preserves order). Their **strict**
canonical forms also differ (since strict canonical preserves order
too). They hash to different values.

If users want order-independent equality, they must sort before
hashing — outside the scope of CX's strict canonical form.

---

## 4 — Date / datetime edge cases

### 4.1 Out-of-range dates

- Year > 9999 or < -9999: out of `i16` range; error `E501`.
- Month outside 1-12: error `E502`.
- Day outside 1-31, or invalid for month/leap-year: error `E503`.
- Datetime offset outside ±18:00: error `E504`.

### 4.2 Leap second

CX does not support leap seconds. A `:datetime` literal with `60` in
the seconds field is rejected (`E505`). Users transmitting leap-second
events must use a domain-specific encoding outside the type system.

### 4.3 Pre-1970 datetimes

Supported via negative `unix_nanos` in `cx_to_data_bin`. Range covers
±292 years from epoch (i64 nanoseconds limit).

### 4.4 Calendar systems

Gregorian only. ISO 8601 strict. No support for Julian, Hebrew,
Islamic, etc., calendars.

### 4.5 Time zones

- Lossless canonical: preserves source offset.
- Strict canonical: normalizes to UTC.
- IANA time zone names (`America/New_York`) are not supported in
 v3.4; only fixed offsets (`Z`, `+05:30`, `-08:00`). A future
 extension may add named TZ support.

---

## 5 — Binary input edge cases

### 5.1 Truncated input

Any length-prefixed payload exceeding remaining input: error `E601`.
The decoder must check before allocation.

### 5.2 Invalid magic / version

- Wrong magic bytes: error `E602` (`not a CXDB document`).
- Higher major version than reader supports: error `E603`.
- Lower minor version than reader requires: error `E604`.

### 5.3 Reserved bit set

Reserved bits in flags or reserved tag bytes: error `E605`. v1 readers
must not silently accept future-reserved values; this prevents
ambiguous interpretation when v2 lands.

### 5.4 Recursion depth

Container nesting exceeds configured `max_depth` (default 64): error
`E606`. Configurable per call.

### 5.5 Allocation cap

Total allocated payload exceeds configured cap (default 4 GB): error
`E607`. Configurable per call.

---

## 6 — CSV edge cases

### 6.1 Inconsistent column count

A row with fewer or more fields than the header: error `E701`.

### 6.2 Embedded newlines / quotes

Per RFC 4180. Quoted fields containing `\r` / `\n` / `,` / `"` are
parsed correctly; unquoted fields containing these are an error.

### 6.3 BOM at start

Stripped silently per §2.3.

### 6.4 Trailing newline

Optional on parse; canonical output always emits a single trailing LF.

### 6.5 Empty file

A zero-byte CSV input parses as an empty table with no columns and no
rows. (Distinct from a CSV with only a header row, which parses as a
table with columns and zero rows.)

---

## 7 — Anchors / aliases / merges (CX text only)

### 7.1 Undefined alias / merge target

A `*name` (alias or merge) that references an undefined `&name`:
error `E801`.

### 7.2 Cyclic anchor reference

An anchor that ultimately references itself (directly or transitively)
during expansion: error `E802`. CX prohibits cycles in the resolved
AST.

### 7.3 Forward references

`*name` may reference an `&name` defined later in the document. The
parser resolves anchors after the full parse, so order does not matter.

### 7.4 Multiple anchors on one element

Grammar [301] permits at most one `&name` per element. Multiple anchor
defs: error `E803`.

---

## 8 — Hash randomization

`libcx` initializes its internal hash maps with a per-process random
seed obtained from OS entropy (`/dev/urandom` on Unix, `BCryptGenRandom`
on Windows). This mitigates hash-flooding DoS where an attacker crafts
keys colliding to one bucket.

The seed is process-local and is not exposed via the C ABI. Bindings
inherit this protection automatically when they use libcx maps. Bindings
that maintain their own host-language maps for `loads` outputs rely on
the host language's hash randomization (built into Python/Go/Rust/Java
since their respective stable releases).

Bindings without seeded hash maps (rare): document the gap and apply
mitigation per host idiom (e.g., `RANDOMIZE_HASH=true` env var).

---

## 9 — Locale independence

All numeric parsing and formatting uses C/POSIX locale rules:

- Decimal separator: `.`
- Thousands separator: not emitted; not accepted on parse.
- Date parsing: ISO 8601 strict.
- No localized digits, names, or formats.

This is enforced in libcx by setting `setlocale(LC_NUMERIC, "C")` at
library load and on every entry point. The user's process locale does
not affect any CX parsing or formatting.

CI tests this with `LC_ALL=de_DE.UTF-8 cargo test` (and equivalents)
on every binding. Drift from POSIX numeric handling is a CI failure.

---

## 10 — Error code registry

Error codes are stable across libcx versions. New codes are added;
existing codes are never reused for different errors.

| Code | Domain | Description |
|---|---|---|
| E101 | numeric | NaN on dumps |
| E102 | numeric | NaN in binary |
| E103 | numeric | Inf on dumps |
| E104 | numeric | Inf in binary |
| E201 | numeric | Annotated overflow |
| E202 | numeric | Bigint exceeds host |
| E203 | numeric | Decimal exceeds host precision |
| E301 | string | Invalid UTF-8 in text |
| E302 | string | Invalid UTF-8 in binary |
| E303 | string | Control char in name |
| E304 | string | Lone surrogate |
| E401 | map | Duplicate key |
| E501-E504 | datetime | Range / format errors |
| E505 | datetime | Leap second |
| E601-E607 | binary | Decoder integrity |
| E701 | csv | Column-count mismatch |
| E801-E803 | anchor | Anchor / alias / merge errors |
| E901-E999 | reserved | (not yet assigned) |

Future codes use the next available block per domain; reserved block
`E001-E099` is for internal use.

The full registry with messages lives at `spec/error_codes.md` (a
follow-up artifact maintained alongside this spec).
