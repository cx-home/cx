# `cx-stdlib/hash` — content-addressable hashing

```cx
[module-meta name=hash tier=A status=current
  [standard ref='FIPS 180-4' title='SHA-2']
  [standard ref='BLAKE3' title='BLAKE3']
  [standard ref='RFC 4648' title='Base encoding']
  [standard ref='W3C SRI' title='Subresource integrity']]
```

**Status:** Current for v0.8.0

Normative reference for the `cx-stdlib/hash` sub-package.

---

## §1. Scope

`cx-stdlib/hash` provides content-addressable hashing — fixed-length digests of arbitrary byte payloads. Four algorithms at v0.8.0:

- **SHA-256** (default; FIPS 180-4) — 32-byte output. CX content-addressing canon.
- **SHA-384** / **SHA-512** (FIPS 180-4) — 48 / 64 bytes.
- **BLAKE3** (Aumasson et al., 2020) — 32-byte default; supports arbitrary-length output (XOF mode).

The module covers **integrity** and **content addressing**, not password hashing. Distinct from `cx-stdlib/random` (non-deterministic bytes) and `cx-stdlib/validate` (shape, not bytes).

### §1.1. Fingerprint vs security boundary

`cx-stdlib/hash` is fingerprinting; [`cx-stdlib/crypto`](crypto.md) is security:

> **Key, secret, or authentication? → `crypto`. Fingerprint of public data? → `hash`.**

Keyed operations (HMAC, keyed-BLAKE3, HKDF) live in `crypto` even when SHA-2 is used underneath — the presence of the key is the discriminator.

## §2. Representation

Outputs are bytes by default and convertible to lowercase hex, URL-safe base64 (no padding), or RFC 4648 uppercase base32 via the `format-*` family.

## §3. Public function surface

### §3.1. Single-shot hashers

```
[?def sha256       scope=public pure [returns bytes] ($input::bytes) ...]
[?def sha384       scope=public pure [returns bytes] ($input::bytes) ...]
[?def sha512       scope=public pure [returns bytes] ($input::bytes) ...]
[?def blake3       scope=public pure [returns bytes] ($input::bytes) ...]
[?def blake3-xof   scope=public pure [returns bytes] ($input::bytes $out-length::int) ...]
```

`blake3-xof` produces `out-length` bytes (1 to 2^64-1).

### §3.2. String convenience

```
[?def sha256-hex     scope=public pure [returns string] ($input::bytes) ...]
[?def sha384-hex     scope=public pure [returns string] ($input::bytes) ...]
[?def sha512-hex     scope=public pure [returns string] ($input::bytes) ...]
[?def blake3-hex     scope=public pure [returns string] ($input::bytes) ...]
[?def sha256-string  scope=public pure [returns bytes]  ($input::string) ...]
[?def blake3-string  scope=public pure [returns bytes]  ($input::string) ...]
```

`*-hex` returns hex directly; `*-string` accepts UTF-8 string input.

### §3.3. Streaming hashers

```
[?def hasher-new      scope=public pure [returns element] ($algo::string) ...]
[?def hasher-update   scope=public pure [returns element] ($h::element $chunk::bytes) ...]
[?def hasher-finalize scope=public pure [returns bytes]   ($h::element) ...]
```

For chunked input that does not fit in memory:

```cx
[?let [= $h0 [$hash:hasher-new "sha256"]]
      [= $h1 [$hash:hasher-update $h0 $chunk1]]
      [= $h2 [$hash:hasher-update $h1 $chunk2]]
      [= $digest [$hash:hasher-finalize $h2]]
  ...]
```

`algo` is `"sha256"` / `"sha384"` / `"sha512"` / `"blake3"`. The streaming hasher is observably pure — `hasher-update` returns a new value; the input hasher is unchanged from the caller's view; the same sequence of updates over the same data produces the same digest. Implementations MAY use interior mutability not observable to callers.

### §3.4. Format conversion

```
[?def format-hex        scope=public pure [returns string] ($digest::bytes) ...]
[?def format-base64-url scope=public pure [returns string] ($digest::bytes) ...]
[?def format-base32     scope=public pure [returns string] ($digest::bytes) ...]
[?def parse-hex         scope=public pure [returns bytes]  ($s::string) ...]
[?def parse-base64-url  scope=public pure [returns bytes]  ($s::string) ...]
```

`parse-hex` accepts both cases; `format-hex` emits lowercase.

### §3.5. Constant-time comparison

```
[?def equals scope=public pure [returns bool] ($a::bytes $b::bytes) ...]
```

Timing-attack-resistant equality. MUST be used when comparing hashes derived from secrets. The general `=` operator may short-circuit.

### §3.6. SRI helpers

```
[?def sri-format scope=public pure [returns string]  ($digest::bytes $algo::string) ...]
[?def sri-parse  scope=public pure [returns element] ($s::string) ...]
```

`sri-format(digest, "sha384")` → `"sha384-<base64>"` per W3C SRI. `sri-parse("sha384-abc...")` → `[sri algo="sha384" digest=<bytes>]`. Consumed by the module loader ([`spec/core/lockfile.md`](../core/lockfile.md)) for HTTPS-fetched module integrity.

## §4. Algorithms

- **SHA-2** — FIPS 180-4; implementations MUST pass NIST CAVP vectors.
- **BLAKE3** — implementations MUST pass the official BLAKE3 test vectors; parallelism is implementation-defined.
- **SHA-1 / MD5** — not included; cryptographically broken.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER2000` | `E_HASH_ALGO_UNKNOWN` | `hasher-new` with unsupported algo |
| `CXER2001` | `E_HASH_DIGEST_WRONG_LENGTH` | `sri-format` / `format-*` on wrong-length digest |
| `CXER2002` | `E_HASH_INVALID_HEX` | `parse-hex` on non-hex input |
| `CXER2003` | `E_HASH_INVALID_BASE64` | `parse-base64-url` on malformed base64 |
| `CXER2004` | `E_HASH_SRI_MALFORMED` | `sri-parse` on input not matching `<algo>-<base64>` |
| `CXER2005` | `E_HASH_XOF_LENGTH_INVALID` | `blake3-xof` with `out-length <= 0` |

## §6. Conformance fixtures

Under `conformance/stdlib/hash.cxd`:

- Empty-input vectors for SHA-256/384/512 and BLAKE3 match NIST / BLAKE3 official digests.
- Sample NIST CAVP vectors pass for each SHA-2.
- All 35 BLAKE3 official vectors pass.
- Streaming `hasher-new → update* → finalize` equals the single-shot digest.
- `blake3-xof` at lengths 1 / 1000 / 65536 produce correct prefix-extending outputs.
- `parse-hex(format-hex(digest)) == digest`; case-insensitive parse.
- `sri-parse(sri-format(d, "sha384"))` returns `[sri algo="sha384" digest=d]`.
- Constant-time equals: equal vs first-byte-differ vs last-byte-differ wall-time within tolerance.
- `hasher-update` returns a new element; original unchanged.
- `hasher-new("md5")` raises `CXER2000`.

## §7. Cross-references

- [`spec/std-lib/crypto.md`](crypto.md) — security sibling (HMAC / keyed-BLAKE3 / HKDF / AEAD / signatures); §1.1 boundary rule states the keys-vs-fingerprints split.
- [`spec/core/cxdm.md`](../core/cxdm.md) — CX content-addressing; uses `sha256` as canonical.
- [`spec/core/lockfile.md`](../core/lockfile.md) — SRI tags use `sri-format`.
- [`spec/std-lib/store.md`](store.md) — store doc-IDs are SHA-256 over the doc's strict canonical bytes per [`spec/core/canonical.md §§1.2, 4`](../core/canonical.md); independent of wire encoding.
- Algorithm support is implementation-internal; see §3 above for the supported set. Bindings do not probe for individual hash algorithms via `cx_features` capability bits.
