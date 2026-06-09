# `cx-stdlib/uuid` — UUID generation, parsing, formatting

```cx
[module-meta name=uuid tier=B status=current
  [standard ref='RFC 4122' title='UUID v3/4/5']
  [standard ref='RFC 9562' title='UUID v7']]
```

**Status:** Current for v0.8.0

Normative reference for the `cx-stdlib/uuid` sub-package.

---

## §1. Scope

`cx-stdlib/uuid` generates, parses, formats, and validates Universally Unique Identifiers. v0.8.0 supports four variants:

- **UUID v4** — fully random (RFC 4122 §4.4).
- **UUID v7** — timestamp-ordered with random tail (RFC 9562 §5.7); intra-millisecond monotonic counter (RFC 9562 §6.2 method 1, §3.1).
- **UUID v5** — name-based, SHA-1 hashed (RFC 4122 §4.3). Deterministic.
- **UUID v3** — name-based, MD5 hashed (RFC 4122 §4.3). Legacy-compat counterpart to v5.

UUID v1 and v6 are deferred (§8).

## §2. Representation

UUIDs are 128-bit values. Two canonical forms:

- **Bytes**: 16-byte sequence in CXDM `bytes` scalar.
- **String**: lowercase 8-4-4-4-12 hex (`550e8400-e29b-41d4-a716-446655440000`); RFC 4122 §3 textual form.

`v4` / `v7` / `v5` / `v3` return the canonical **string**; `-bytes` variants return raw **bytes**. There is no `[uuid …]` element kind — a UUID is a scalar identifier carried in a `string` or `bytes` scalar.

## §3. Public function surface

```
[?def v4        scope=public impure [returns string]  () ...]
[?def v7        scope=public impure [returns string]  () ...]
[?def v5        scope=public pure   [returns string]  ($namespace::bytes $name::string) ...]
[?def v3        scope=public pure   [returns string]  ($namespace::bytes $name::string) ...]
[?def v4-bytes  scope=public impure [returns bytes]   () ...]
[?def v7-bytes  scope=public impure [returns bytes]   () ...]
[?def v5-bytes  scope=public pure   [returns bytes]   ($namespace::bytes $name::string) ...]
[?def v3-bytes  scope=public pure   [returns bytes]   ($namespace::bytes $name::string) ...]
[?def parse     scope=public pure   [returns bytes]   ($s::string $lenient=false) ...]
[?def format    scope=public pure   [returns string]  ($b::bytes) ...]
[?def validate  scope=public pure   [returns bool]    ($s::string) ...]
[?def variant   scope=public pure   [returns int]     ($b::bytes) ...]
[?def version   scope=public pure   [returns int]     ($b::bytes) ...]
[?def nil-uuid  scope=public pure   [returns string]  () ...]
[?def ns-dns    scope=public pure   [returns bytes]   () ...]
[?def ns-url    scope=public pure   [returns bytes]   () ...]
[?def ns-oid    scope=public pure   [returns bytes]   () ...]
[?def ns-x500   scope=public pure   [returns bytes]   () ...]
```

### §3.1. Random / time-ordered generators

- `v4` / `v4-bytes` — RFC 4122 v4; 122 random bits + 4 version + 2 reserved.
- `v7` / `v7-bytes` — RFC 9562 v7; 48-bit Unix-millis timestamp + 4 version + 12-bit `rand_a` monotonic counter + 2 variant + 62-bit CSPRNG `rand_b`.

Both use cryptographically-secure randomness (per [`cx-stdlib/random`](random.md) crypto-random).

**v7 intra-millisecond monotonicity (RFC 9562 §6.2 method 1).** Within a single millisecond, the 12-bit `rand_a` field is used as a monotonic counter:

1. First v7 in a millisecond seeds the counter from CSPRNG with the high-order bits masked low to leave headroom.
2. Subsequent v7s in the same millisecond increment the counter by 1, making each UUID strictly greater than its predecessor lexicographically and as big-endian bytes.
3. The 62 low bits (`rand_b`) stay CSPRNG-random on every call.

**Counter rollover.** When the 12-bit counter would overflow (more than 4096 v7s in one millisecond), the generator advances the timestamp to the next millisecond and reseeds the counter. Strict ordering is preserved without blocking on the wall clock.

### §3.2. Name-based generators

- `v5` / `v5-bytes` — RFC 4122 §4.3 SHA-1; computes `SHA-1($namespace ++ utf8($name))`, takes first 16 bytes, overwrites version nibble to `5` and variant bits.
- `v3` / `v3-bytes` — RFC 4122 §4.3 MD5; same construction with MD5.

`$namespace` MUST be a 16-byte UUID (typically a §3.5 predefined constant). Length ≠ 16 raises `CXER1801 E_UUID_WRONG_LENGTH`.

SHA-1 and MD5 are RFC-mandated bit-mixing here, not security primitives. [`cx-stdlib/hash`](hash.md) §4.3 deliberately excludes them from its public surface; this module carries internal SHA-1 / MD5 implementations without re-exposing them as hashing surface.

### §3.3. Parse and format

- `parse($s $lenient=false)` — strict by default. Accepts only the canonical 8-4-4-4-12 hex form (case-insensitive). Any other shape raises `CXER1800 E_UUID_MALFORMED`. With `$lenient=true`, additionally accepts the relaxed forms in §4.
- `format($b)` — emits canonical lowercase 8-4-4-4-12. Raises `CXER1801` if `$b` is not 16 bytes. Never emits `urn:uuid:` prefix or braces.

### §3.4. Validation and inspection

- `validate($s)` — true iff `$s` matches the strict canonical form.
- `variant($b)` — variant bits per RFC 4122 §4.1.1 (`0` NCS, `2` RFC 4122, `6` Microsoft, `7` future).
- `version($b)` — version number; reports nibble `1`–`8` correctly even for externally-supplied v1/v6/v8 UUIDs this module does not generate.
- `nil-uuid` — returns `"00000000-0000-0000-0000-000000000000"`.

### §3.5. Predefined namespace constants

The four RFC 4122 Appendix C namespaces, exposed as pure accessor functions returning 16 bytes:

| Accessor | Namespace | Canonical UUID |
|---|---|---|
| `ns-dns`  | DNS names | `6ba7b810-9dad-11d1-80b4-00c04fd430c8` |
| `ns-url`  | URLs      | `6ba7b811-9dad-11d1-80b4-00c04fd430c8` |
| `ns-oid`  | ISO OIDs  | `6ba7b812-9dad-11d1-80b4-00c04fd430c8` |
| `ns-x500` | X.500 DNs | `6ba7b814-9dad-11d1-80b4-00c04fd430c8` |

Example: `[uuid/v5 [uuid/ns-url] "https://example.com"]` produces a stable UUID for that URL.

## §4. Lenient parse forms (`$lenient=true` only)

Relaxed forms accepted exclusively when the caller passes `$lenient=true`; without it each raises `CXER1800`. `format` never emits any of these.

- **Hyphen-less** — 32-hex-char form (no hyphens).
- **URN prefix** — `urn:uuid:` prefix stripped before parsing.
- **Microsoft GUID braces** — `{…}` wrapper stripped before parsing.

May combine (brace-wrapped URN), but the inner body must resolve to 32 hex digits.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER1800` | `E_UUID_MALFORMED` | `parse` on a string that is not the canonical form (and, with `$lenient=true`, not one of the relaxed forms either) |
| `CXER1801` | `E_UUID_WRONG_LENGTH` | `format` / inspector functions on bytes ≠ 16; `v5` / `v3` / `v5-bytes` / `v3-bytes` on a `$namespace` not 16 bytes |

## §6. Conformance fixtures

Under `conformance/stdlib/uuid.cxd`:

- **v4 randomness:** 1000 `v4` calls produce 1000 distinct UUIDs.
- **v7 ordering:** successive `v7` UUIDs sort lexicographically.
- **v7 intra-millisecond monotonicity:** a tight loop generating same-millisecond `v7` UUIDs produces a strictly lexicographically-increasing sequence; the property holds across the millisecond boundary.
- **v7 timestamp recoverable:** first 48 bits of `v7-bytes` decode as Unix milliseconds within ±1 second of `time/now`.
- **v5 determinism:** `v5($ns $name)` repeated yields the same UUID across calls and runs.
- **v5 RFC test vector:** `format(v5-bytes(ns-dns "www.example.com"))` equals `"2ed6657d-e927-568b-95e1-2665a8aea6a2"`.
- **v3 determinism:** likewise.
- **v5 / v3 version and variant:** `version(v5-bytes(ns-dns "x"))` is `5`; `version(v3-bytes(ns-dns "x"))` is `3`; both report `variant=2`.
- **Namespace constants:** `format(ns-dns)` equals `"6ba7b810-9dad-11d1-80b4-00c04fd430c8"`; same for `ns-url`, `ns-oid`, `ns-x500`.
- **Bad namespace length:** `v5(<15-byte value> "x")` raises `CXER1801`.
- **Round-trip:** `format(parse($s))` produces canonical lowercase for any valid canonical input.
- **Case insensitivity:** `parse` accepts lower and uppercase hex in canonical form.
- **Strict-by-default rejection:** without `$lenient`, hyphen-less / URN / brace forms each raise `CXER1800`.
- **Lenient acceptance:** with `$lenient=true`, those three inputs all succeed and produce identical bytes.
- **Malformed:** invalid lengths, non-hex chars, wrong group sizes raise `CXER1800` regardless of `$lenient`.
- **Variant / version inspection:** v4 reports `variant=2 version=4`; v7 reports `variant=2 version=7`.
- **Nil UUID:** `nil-uuid` returns `"00000000-0000-0000-0000-000000000000"`; `validate(nil-uuid)` is true.

## §7. Capabilities

Effectful functions in `cx-stdlib/uuid` run under deny-by-default capabilities ([`spec/core/security.md`](../core/security.md) §2): the effect point checks the active set and raises `cx-err:CXER0271` (E_CAP_DENIED, naming the missing capability and resource) when the grant is absent. Pure functions (in-memory transforms, parsing, formatting) require no capability.

The random / time-ordered generators source OS entropy (cryptographically-secure randomness via [`cx-stdlib/random`](random.md), §3.1) and therefore require `random`. The name-based generators (`v3` / `v5`) are pure functions of caller-supplied namespace + name and need no capability.

| Capability | Functions |
|---|---|
| `random` | `v4`, `v4-bytes`, `v7`, `v7-bytes` |
| (none) | `v3`, `v3-bytes`, `v5`, `v5-bytes`, `parse`, `format`, `validate`, `variant`, `version`, `nil-uuid`, `ns-dns`, `ns-url`, `ns-oid`, `ns-x500` |

## §8. Open follow-ups

- **UUID v1** (timestamp + MAC) — depends on a stable node identifier and clock-sequence persistence; deferred.
- **UUID v6** (reordered v1) — niche retrofit layout; deferred.
- **Performance bench fixture** — v7 generation throughput.

## §9. Cross-references

- [`spec/std-lib/random.md`](random.md) — crypto-random source for v4 / v7 generation.
- [`spec/std-lib/bytes.md`](bytes.md) — byte-array operations on the 16-byte payload.
- [`spec/std-lib/hash.md`](hash.md) §4.3 — why SHA-1 / MD5 are excluded from the public hashing surface; this module uses them internally per RFC mandate.
- RFC 4122 (UUID URN namespace; §4.3 name-based v3/v5; Appendix C namespaces); RFC 9562 (UUID v6/v7/v8; §6.2 method 1 monotonic counter) — external normative references.
