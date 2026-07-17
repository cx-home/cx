# `cx-stdlib/bytes` — byte-level operations

```cx
[module-meta name=bytes tier=A status=current
  [standard ref='RFC 4648' title='Base16/32/64']
  [standard ref='RFC 1952' title='gzip']
  [standard ref='RFC 8478' title='zstd']]
```

**Status:** Current

Normative reference for the `cx-stdlib/bytes` sub-package.

---

## §1. Scope

`cx-stdlib/bytes` operates on the CXDM `bytes` scalar kind. Capability groups:

- Inspection + slicing — length, indexing, slicing, search.
- Encoding — hex / base64 / base32.
- Compression — gzip / zstd.
- Binary packing — fixed-width int / float pack and unpack.

Pure byte manipulation; no I/O. File and stream I/O lives in [`cx-stdlib/io`](io.md).

## §2. Representation

CXDM `bytes` is a sealed scalar: a length-prefixed byte buffer; length up to 2^32-1 bytes (4 GiB). All operations return new bytes values (immutable). Byte indices are 0-based. Slices use half-open ranges (`[start:end)`).

## §3. Public function surface

### §3.1. Inspection

```
[?def length              scope=public pure [returns int]  ($b::bytes) ...]
[?def at                  scope=public pure [returns int]  ($b::bytes $i::int) ...]
[?def is-empty            scope=public pure [returns bool] ($b::bytes) ...]
[?def equals              scope=public pure [returns bool] ($a::bytes $b::bytes) ...]
[?def constant-time-equals scope=public pure [returns bool] ($a::bytes $b::bytes) ...]
```

- `at(b, i)` — byte value 0–255. Raises `CXER2300 E_BYTES_INDEX_OUT_OF_RANGE` on out-of-bounds.
- `constant-time-equals` — timing-attack-resistant equality. Different-length inputs return `false` via a fast path; the constant-time guarantee holds only over equal-length inputs (matches Python `hmac.compare_digest`).

### §3.2. Slicing and search

```
[?def slice         scope=public pure [returns bytes]            ($b::bytes $start::int $end::int) ...]
[?def head          scope=public pure [returns bytes]            ($b::bytes $n::int) ...]
[?def tail          scope=public pure [returns bytes]            ($b::bytes $n::int) ...]
[?def concat        scope=public pure [returns bytes]            ($parts::[sequence bytes]) ...]
[?def repeat        scope=public pure [returns bytes]            ($b::bytes $n::int) ...]
[?def find          scope=public pure [returns int]              ($haystack::bytes $needle::bytes) ...]
[?def contains      scope=public pure [returns bool]             ($haystack::bytes $needle::bytes) ...]
[?def starts-with   scope=public pure [returns bool]             ($b::bytes $prefix::bytes) ...]
[?def ends-with     scope=public pure [returns bool]             ($b::bytes $suffix::bytes) ...]
[?def split         scope=public pure [returns [sequence bytes]] ($b::bytes $sep::bytes) ...]
```

`find` returns -1 if not found. `concat` / `repeat` whose result would exceed 2^32-1 bytes raise `CXER2307 E_BYTES_LENGTH_EXCEEDED` before allocation.

### §3.3. Hex encoding

```
[?def to-hex        scope=public pure [returns string] ($b::bytes) ...]
[?def to-hex-upper  scope=public pure [returns string] ($b::bytes) ...]
[?def from-hex      scope=public pure [returns bytes]  ($s::string) ...]
```

`to-hex` is lowercase; `from-hex` accepts both cases and raises `CXER2301 E_BYTES_INVALID_HEX` on non-hex.

### §3.4. Base64 encoding

```
[?def to-base64       scope=public pure [returns string] ($b::bytes) ...]
[?def to-base64-url   scope=public pure [returns string] ($b::bytes) ...]
[?def from-base64     scope=public pure [returns bytes]  ($s::string) ...]
[?def from-base64-url scope=public pure [returns bytes]  ($s::string) ...]
```

- `to-base64` — RFC 4648 §4 standard alphabet, padded.
- `to-base64-url` — RFC 4648 §5 URL-safe alphabet, unpadded.
- Both decoders auto-detect padded or unpadded input. Malformed input raises `CXER2302 E_BYTES_INVALID_BASE64`.

### §3.5. Base32 encoding

```
[?def to-base32   scope=public pure [returns string] ($b::bytes) ...]
[?def from-base32 scope=public pure [returns bytes]  ($s::string) ...]
```

RFC 4648 base32 (uppercase, padded).

### §3.5.1. Base58 encoding

```
[?def to-base58   scope=public pure [returns string] ($b::bytes) ...]
[?def from-base58 scope=public pure [returns bytes]  ($s::string) ...]
```

base58btc — the **Bitcoin alphabet** (`123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz`), the multibase `z`-prefixed encoding. Leading zero bytes encode as leading `1`s (round-trip preserved). `from-base58` returns `CXER2302` on a character outside the alphabet. This is the payload encoding for `did:key` ([did.md](did.md) §2.1).

### §3.6. Compression

```
[?def gzip-compress            scope=public pure [returns bytes] ($input::bytes) ...]
[?def gzip-decompress          scope=public pure [returns bytes] ($input::bytes) ...]
[?def zstd-compress            scope=public pure [returns bytes] ($input::bytes) ...]
[?def zstd-decompress          scope=public pure [returns bytes] ($input::bytes) ...]
[?def zstd-compress-with-level scope=public pure [returns bytes] ($input::bytes $level::int) ...]
```

gzip — RFC 1952; default zlib level 6. zstd — RFC 8478; default level 3; `zstd-compress-with-level` accepts 1–22.

### §3.7. Binary packing

```
[?def pack   scope=public pure [returns bytes]            ($format::string $values::[sequence any]) ...]
[?def unpack scope=public pure [returns [sequence any]]   ($format::string $b::bytes) ...]
```

The format string is struct-inspired but CX-owned (not Python-`struct`-compatible).

Byte-order prefixes (first char): `<` little-endian (default), `>` big-endian, `!` network (= big-endian), `=` native, `@` native byte order only — CX never inserts native struct-alignment padding.

Format chars:

| Char | Type | Bytes |
|---|---|---|
| `b` / `B` | signed / unsigned byte | 1 |
| `h` / `H` | signed / unsigned int16 | 2 |
| `i` / `I` | signed / unsigned int32 | 4 |
| `q` / `Q` | signed / unsigned int64 | 8 |
| `f` / `d` | float32 / float64 | 4 / 8 |
| `?` | 1-byte bool | 1 |
| `Ns` | fixed-length N-byte string | N |
| `x` | padding | 1 |

Out-of-scope chars (`p`, `P`, `e`, native-`@`-alignment) raise `CXER2305 E_BYTES_PACK_FORMAT_INVALID`.

```cx
[$bytes:pack "<IIs" [1234 5678 "hello"]]   # → 13 bytes
[$bytes:unpack "<II" $bytes]               # → [1234 5678]
```

### §3.8. String conversion

```
[?def from-string-utf8      scope=public pure [returns bytes]  ($s::string) ...]
[?def to-string-utf8        scope=public pure [returns string] ($b::bytes) ...]
[?def to-string-utf8-lossy  scope=public pure [returns string] ($b::bytes) ...]
[?def from-string-latin1    scope=public pure [returns bytes]  ($s::string) ...]
[?def to-string-latin1      scope=public pure [returns string] ($b::bytes) ...]
```

`to-string-utf8` is strict and raises `CXER2303 E_BYTES_INVALID_UTF8` on invalid UTF-8. `to-string-utf8-lossy` replaces each maximal invalid run with U+FFFD and never raises. Latin-1 variants preserve every byte for byte-clean round-trips.

## §4. Edge cases

- **Slice bounds** — `slice` clamps to the buffer length; negative indices count from end.
- **Empty inputs** — All functions accept empty `bytes`. `find(empty-haystack, needle)` returns -1 unless `needle` is also empty (then 0).
- **gzip empty** — `gzip-compress(empty)` produces a valid empty-payload gzip frame (~20 bytes); `gzip-decompress(empty)` raises `CXER2304 E_BYTES_DECOMPRESS_FAILED`.
- **Length-ceiling guard** — `repeat` / `concat` exceeding 2^32-1 bytes raise `CXER2307` before allocating.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER2300` | `E_BYTES_INDEX_OUT_OF_RANGE` | `at` with out-of-bounds index |
| `CXER2301` | `E_BYTES_INVALID_HEX` | `from-hex` on non-hex input |
| `CXER2302` | `E_BYTES_INVALID_BASE64` | `from-base64*` on malformed input |
| `CXER2303` | `E_BYTES_INVALID_UTF8` | `to-string-utf8` on invalid UTF-8 |
| `CXER2304` | `E_BYTES_DECOMPRESS_FAILED` | gzip/zstd decompress on malformed input |
| `CXER2305` | `E_BYTES_PACK_FORMAT_INVALID` | `pack` / `unpack` with unsupported format char |
| `CXER2306` | `E_BYTES_PACK_LENGTH_MISMATCH` | `pack` / `unpack` value count mismatch |
| `CXER2307` | `E_BYTES_LENGTH_EXCEEDED` | `repeat` / `concat` result would exceed 2^32-1 |

## §6. Conformance fixtures

Under `conformance/stdlib/bytes.cxd`:

- Hex / base64 (standard + URL, padded + unpadded) / base32 round-trips.
- Base64 padding tolerance on both decoders; URL output contains no `+` / `/` / `=`.
- gzip and zstd round-trips at 0 / 100 / 100000 bytes; zstd level 22 ≤ level 1 for compressible input.
- Slice clamping; find at start/middle/end/absent; split on standard separators.
- UTF-8 round-trip; strict raises `CXER2303`; lossy substitutes U+FFFD.
- Pack/unpack across enumerated format chars; out-of-scope chars raise `CXER2305`.
- Length-ceiling guard raises `CXER2307` without allocating.
- Constant-time equals: timing-resistant; different-length returns `false`.

## §7. Cross-references

- [`spec/std-lib/hash.md`](hash.md) — hash-specific encoding shortcuts atop bytes encoding.
- [`spec/std-lib/store.md`](store.md) — compression suffixes (`.gz`, `.zst`).
- [`spec/std-lib/io.md`](io.md) — file I/O reads/writes bytes.
- RFC 4648 (base16/base32/base64), RFC 1952 (gzip), RFC 8478 (zstd).
