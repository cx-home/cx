# `cx-stdlib/crypto` — security primitives

```cx
[module-meta name=crypto tier=A status=current
  [standard ref='RFC 2104' title='HMAC']
  [standard ref='RFC 5869' title='HKDF']
  [standard ref='BLAKE3' title='keyed hash']
  [standard ref='RFC 8032' title='Ed25519']
  [standard ref='RFC 7748' title='X25519']
  [standard ref='RFC 8017' title='RSA PKCS#1']
  [standard ref='FIPS 186' title='ECDSA']
  [standard ref='RFC 9106' title='Argon2']
  [standard ref='RFC 7519' title='JWT']]
```

**Status:** Current

Normative reference for the `cx-stdlib/crypto` sub-package.

---

## §1. Scope

`cx-stdlib/crypto` provides operations involving a **key, a secret, or authentication**. It is the security sibling of [`cx-stdlib/hash`](hash.md), which provides content fingerprinting of public data.

> **Does it involve a key, a secret, or authentication? → `cx-stdlib/crypto`. Is it just a fingerprint of public data? → `cx-stdlib/hash`.**

HMAC lives here even though it uses SHA-256 underneath: HMAC is keyed and its purpose is authentication, not content addressing.

The module ships with:

- **HMAC** (RFC 2104) over SHA-256 / SHA-384 / SHA-512, single-shot and streaming.
- **keyed-BLAKE3** — BLAKE3 in 32-byte-key MAC mode.
- **HKDF** (RFC 5869) — extract / expand / one-shot, SHA-256 default + SHA-512 variant.
- **Constant-time MAC verification.**
- **AEAD** — AES-256-GCM and ChaCha20-Poly1305.
- **Asymmetric** — Ed25519 signatures, X25519 key exchange.
- **Password hashing** — Argon2id, PHC-string encoded.

The four generating surfaces (`aead-encrypt`, `ed25519-keypair`, `x25519-keypair`, `password-hash`) draw fresh randomness from [`cx-stdlib/random`](random.md)'s `[$random:crypto-bytes]` and are declared `impure`. Every other function is `pure`.

## §2. Conceptual model

### §2.1. Keys, messages, MACs — all `bytes`

Keys, messages, MACs, salts, IKM, PRK, info, OKM, signatures, and ciphertexts are all CXDM `bytes`. Convert hex/base64 inputs via [`cx-stdlib/bytes`](bytes.md) before passing in.

### §2.2. MAC = Message Authentication Code

A MAC proves a message was produced by a holder of the secret key. Compute `mac = hmac-sha256(key, msg)`, transmit `(msg, mac)`, and verify in **constant time** with `hmac-verify`. Plain `=` byte-by-byte comparison short-circuits and leaks timing.

### §2.3. HKDF — derive many keys from one secret

HKDF (RFC 5869) turns one high-entropy-but-not-uniform secret into one or more uniformly-random fixed-length subkeys, each bound to an `info` context label:

- `prk = hkdf-extract(salt, ikm)` concentrates entropy into a fixed-length PRK.
- `okm = hkdf-expand(prk, info, length)` stretches PRK into `length` bytes, domain-separated by `info`.
- `hkdf(ikm, salt, info, length)` does both. Distinct `info` values produce independent subkeys from the same `ikm`.

### §2.4. Purity

Single-shot HMAC / HKDF / keyed-BLAKE3 and all `verify` functions are `pure`. The streaming HMAC hasher is observably pure: `hmac-update` returns a new hasher; the input is unchanged.

The four generating surfaces (`aead-encrypt`, `ed25519-keypair`, `x25519-keypair`, `password-hash`) are `impure` — they consume `[$random:crypto-bytes]`. This is the sole impurity in the module; the crypto-random source is `cx-stdlib/random` and is never duplicated here.

## §3. Public function surface

### §3.1. HMAC — single-shot

```
[?def hmac-sha256 scope=public pure [returns bytes] ($key::bytes $msg::bytes) ...]
[?def hmac-sha384 scope=public pure [returns bytes] ($key::bytes $msg::bytes) ...]
[?def hmac-sha512 scope=public pure [returns bytes] ($key::bytes $msg::bytes) ...]
```

RFC 2104 / FIPS 198-1. Output 32 / 48 / 64 bytes. `key` may be any length.

The digest is baked into the name for single-shot calls where the digest is known at the call site; the streaming path (§3.2) and HKDF (§3.4) follow the same named-per-digest convention.

### §3.2. HMAC — streaming

```
[?def hmac-new      scope=public pure [returns element] ($algo::string $key::bytes) ...]
[?def hmac-update   scope=public pure [returns element] ($h::element $chunk::bytes) ...]
[?def hmac-finalize scope=public pure [returns bytes]   ($h::element) ...]
```

`algo` is one of `"sha256"` / `"sha384"` / `"sha512"`. The hasher value is immutable. Streaming produces the same MAC as the single-shot function over concatenated chunks.

```cx
[?let [= $h0  [$crypto:hmac-new "sha256" $key]]
      [= $h1  [$crypto:hmac-update $h0 $chunk1]]
      [= $h2  [$crypto:hmac-update $h1 $chunk2]]
      [= $mac [$crypto:hmac-finalize $h2]]
  ...]
```

### §3.3. keyed-BLAKE3

```
[?def blake3-keyed      scope=public pure [returns bytes] ($key::bytes $msg::bytes) ...]
[?def blake3-mac-verify scope=public pure [returns bool]  ($key::bytes $msg::bytes $expected::bytes) ...]
```

`blake3-keyed` requires `key` exactly 32 bytes (else `CXER3700`); output 32 bytes. `blake3-mac-verify` follows the §3.6 verify contract.

### §3.4. HKDF

```
[?def hkdf-extract scope=public pure [returns bytes] ($salt::bytes $ikm::bytes) ...]
[?def hkdf-expand  scope=public pure [returns bytes] ($prk::bytes $info::bytes $length::int) ...]
[?def hkdf         scope=public pure [returns bytes] ($ikm::bytes $salt::bytes $info::bytes $length::int) ...]
[?def hkdf-extract-sha512 scope=public pure [returns bytes] ($salt::bytes $ikm::bytes) ...]
[?def hkdf-expand-sha512  scope=public pure [returns bytes] ($prk::bytes $info::bytes $length::int) ...]
[?def hkdf-sha512         scope=public pure [returns bytes] ($ikm::bytes $salt::bytes $info::bytes $length::int) ...]
```

RFC 5869. The bare names are SHA-256 based; the `-sha512` variants `hkdf-sha512` / `hkdf-extract-sha512` / `hkdf-expand-sha512` carry identical shapes over SHA-512 (so `hkdf-extract-sha512` yields a 64-byte PRK). Empty `salt` is permitted (defaults to HashLen zero bytes). `length` MUST satisfy `0 < length <= 255 * HashLen`; otherwise raises `CXER3703 E_CRYPTO_LENGTH_INVALID`. The one-shot identity holds: `hkdf(ikm, salt, info, length) == hkdf-expand(hkdf-extract(salt, ikm), info, length)`.

### §3.6. Verification contract — fail-closed, `true`-or-raise

```
[?def hmac-verify scope=public pure [returns bool] ($algo::string $key::bytes $msg::bytes $expected::bytes) ...]
```

`hmac-verify` recomputes the HMAC and compares in **constant time**. The whole verify family shares one contract: returns `true` on success, raises on failure, **never returns `false`**. Failure codes:

| Function | Failure code |
|---|---|
| `hmac-verify` | `CXER3701 E_CRYPTO_MAC_VERIFY_FAILED` |
| `blake3-mac-verify` | `CXER3701 E_CRYPTO_MAC_VERIFY_FAILED` |
| `ed25519-verify` | `CXER3705 E_CRYPTO_SIGNATURE_INVALID` |
| `password-verify` | `CXER3706 E_CRYPTO_PASSWORD_VERIFY_FAILED` |
| `aead-decrypt` (auth check) | `CXER3704 E_CRYPTO_AEAD_AUTH_FAILED` |

Plain `=` comparison short-circuits and leaks timing — use the named verify functions, or compute the MAC and compare with the constant-time `[$hash:equals]`.

To branch on a boolean: wrap in `[?fallback]` (e.g. `[?fallback [$crypto:hmac-verify ...] false]`), or compute the MAC manually and compare with `[$hash:equals]`.

### §3.7. AEAD — authenticated encryption with associated data

```
[?def aead-encrypt scope=public impure [returns element] ($algo::string $key::bytes $plaintext::bytes $aad::bytes) ...]
[?def aead-decrypt scope=public pure   [returns bytes]   ($algo::string $key::bytes $aead::element $aad::bytes) ...]
```

AES-256-GCM and ChaCha20-Poly1305. `algo` is `"aes-256-gcm"` or `"chacha20-poly1305"`; otherwise `CXER3700`. `key` MUST be exactly 32 bytes.

`aead-encrypt` is the impurity exception: it generates a fresh 12-byte nonce internally via `[$random:crypto-bytes]` per call (nonce reuse is catastrophic for GCM — generating internally makes reuse-by-mistake structurally impossible). Result element:

```
[aead algo=<string> ciphertext=<bytes> nonce=<bytes> tag=<bytes>]
```

`tag` is 16 bytes; `ciphertext` is same length as plaintext; `aad` may be empty.

`aead-decrypt` verifies the tag in constant time **before returning any plaintext**. Authentication failure raises `CXER3704`. Wrong-length `nonce` or `tag` raises `CXER3707 E_CRYPTO_NONCE_INVALID`.

### §3.8. Asymmetric — Ed25519 + X25519

```
[?def ed25519-keypair      scope=public impure [returns element] () ...]
[?def ed25519-sign         scope=public pure   [returns bytes]   ($private-key::bytes $msg::bytes) ...]
[?def ed25519-verify       scope=public pure   [returns bool]    ($public-key::bytes $msg::bytes $sig::bytes) ...]
[?def x25519-keypair       scope=public impure [returns element] () ...]
[?def x25519-shared-secret scope=public pure   [returns bytes]   ($private-key::bytes $peer-public-key::bytes) ...]
[?def rsa-verify           scope=public pure   [returns bool]    ($public-key::element $msg::bytes $sig::bytes $opts::map {}) ...]
[?def ecdsa-verify         scope=public pure   [returns bool]    ($public-key::element $msg::bytes $sig::bytes $opts::map {}) ...]
```

Keypair element:

```
[keypair public=<bytes> private=<bytes>]
```

Ed25519 (RFC 8032): `public` 32 bytes, `private` 32-byte seed. X25519 (RFC 7748): both 32 bytes.

`ed25519-sign` is deterministic per RFC 8032 (nonce derived from key+msg). Wrong key length raises `CXER3700`. `ed25519-verify` follows the §3.6 contract; malformed key or signature raises `CXER3705`. `x25519-shared-secret` returns the 32-byte shared secret — the natural `ikm` for `hkdf`.

**`rsa-verify`** (RSASSA-PKCS1-v1_5, RFC 8017 §8.2) and **`ecdsa-verify`** (ECDSA, FIPS 186 / SEC1) are verify-only public-key primitives backing the JWT `RS*`/`ES256` families (§3.10). Both follow the §3.6 contract (`true`-or-raise), are pure, and raise `CXER3705` on an invalid signature / `CXER3700` on a malformed key or unsupported `hash`/`curve`. Their public keys are elements carrying big-endian `bytes` (the JWKS material, §3.10):

```
[rsa-public-key n=<bytes> e=<bytes>]                 ; modulus + exponent
[ec-public-key crv="P-256" x=<bytes> y=<bytes>]      ; affine curve point
```

- `rsa-verify` `opts.hash` ∈ `{"sha256","sha384","sha512"}` (default `"sha256"`) selects the PKCS#1 v1.5 digest for `RS256`/`RS384`/`RS512`. A modulus < 2048 bits is the caller's policy to reject; the primitive verifies whatever key it is handed.
- `ecdsa-verify` `opts` `curve` (default `"P-256"`) + `hash` (default `"sha256"`) cover `ES256`; the signature is the **JOSE fixed-width raw `r‖s`** (RFC 7518 §3.4 — 64 bytes for P-256), **not** ASN.1/DER. `P-384`/`P-521` raise `CXER3700` this revision (a noted extension wired through the same primitive).

### §3.9. Password hashing — Argon2id

```
[?def password-hash   scope=public impure [returns string] ($password::bytes $cost::element) ...]
[?def password-verify scope=public pure   [returns bool]   ($password::bytes $encoded::string) ...]
```

`password-hash` generates a fresh salt per call and returns a self-describing PHC-string format value:

```
$argon2id$v=19$m=65536,t=3,p=4$<base64-salt>$<base64-hash>
```

`cost` element:

```
[argon2-cost memory-kib=65536 iterations=3 parallelism=4]
```

Malformed cost raises `CXER3700`. `password-verify` follows the §3.6 contract; unparseable PHC string raises `CXER3706`.

### §3.10. JWT / JWKS verification

Verification of tokens an external IdP (OIDC) already minted — **verify only**: this surface does not mint tokens, run OAuth/OIDC flows, manage refresh tokens, or do discovery (those are the IdP's job and the application's integration layer). Built on the §3.8 verify primitives; adds no crypto of its own.

```
[?def jwt-verify  scope=public pure   [returns element] ($token::string $key::element $now::datetime $opts::map {}) ...]
[?def jwks-fetch  scope=public impure [returns element] ($jwks-uri::string $opts::map {}) ...]
[?def jwks-parse  scope=public pure   [returns element] ($json-text::string) ...]
[?def claim       scope=public pure   [returns element] ($claims::element $name::string) ...]
[?def jwk-by-kid  scope=public pure   [returns element] ($jwks::element $kid::string) ...]
```

**A whole-token verification is a VALUE, not the §3.6 one-bit raise.** A raw signature check (`rsa-verify`/`ecdsa-verify`/`ed25519-verify`) is `true`-or-raise; `jwt-verify` answers the composite "is this token currently valid for this audience?" on the four-channel model ([`code.md`](../core/code.md) §9.1.2): success → a present `[claims …]` value (registered claims as attributes, full decoded payload reachable); any verification failure → an `[err]` carrying a specific §5 code. It **never** returns `false` and never returns unverified claims (fail-closed). Verified result and key-set shapes:

```cx
[claims iss="…" sub="…" aud="…" exp=… nbf=… iat=… jti="…"
  [payload [#{ …full decoded JSON claim-set… }#]]]
[jwks [jwk kid="…" kty="RSA" alg="RS256" n="<b64url>" e="AQAB"]
      [jwk kid="…" kty="EC"  crv="P-256" alg="ES256" x="<b64url>" y="<b64url>"]
      [jwk kid="…" kty="OKP" crv="Ed25519" alg="EdDSA" x="<b64url>"]]
```

**Supported algorithms (v1): `RS256` (default), `RS384`, `RS512`, `ES256`, `EdDSA`.** `RS*`→`rsa-verify`, `ES256`→`ecdsa-verify`, `EdDSA`→`ed25519-verify`. `ES384`/`ES512` (P-384/P-521) parse but raise `CXER3713` at verify (deferred extension). **`alg:"none"` is always rejected** (`CXER3713`) — the JWT downgrade attack.

`jwt-verify` checks, fail-closed, in order: (1) **structural** — three b64url segments, header+payload JSON decode, and any `require`d claim present, else `CXER3709`; (2) **algorithm** — header `alg` ∈ the caller's `expected-alg` allow-list (default all five; the token can't pick its own algorithm — alg-confusion guard), else `CXER3713`; (3) **key resolution** — header `kid` selects the `[jwk]` (no/ambiguous match → `CXER3714`); the resolved key's `kty` must match the chosen `alg` (`RSA`↔`RS*`, `EC/P-256`↔`ES256`, `OKP`↔`EdDSA`), else `CXER3719`; (4) **signature** over the reconstructed signing input, constant-time, mismatch → `CXER3710`; (5) **temporal** — `exp`/`nbf` with caller `leeway` (default `0s`), → `CXER3711`/`CXER3712`; (6) **issuer/audience** — if `expected-iss`/`expected-aud` supplied, must match/contain, else `CXER3715`. `[claims]` returns only after **all** pass.

`jwt-verify` is **pure** — `now` is passed in (no clock read), so identical inputs give identical results. `opts`: `expected-alg` (allow-list), `expected-iss`, `expected-aud`, `leeway` (`0s`), `require` (`("exp")`).

`jwks-fetch` GETs the JWKS over [`cx-stdlib/http`](http.md), requires the **`net`** capability (§7), and returns a parsed `[jwks]`; a non-2xx / transport fault / non-JWKS body → `CXER3716` (carrying the underlying http/net `[err]` child).

> **Implementation tier (this revision).** `jwks-fetch`'s **live GET is deferred** — same posture as `cx-stdlib/http`/`net` live transport (which this revision serves only via a synthetic engine that returns no response body). The `net`-denial path (`CXER0271` under an empty cap set) is enforced; the granted-fetch path returns over the synthetic transport and so cannot yet materialize a real JWKS body. This is not claimed implemented — but it does **not** gate the security-critical surface: the **offline `jwks-parse` → `jwt-verify`** seam (fetch-once / verify-many) is fully implemented, pure, and cross-validated against OpenSSL vectors. A granted-fetch conformance case lands when the live http transport does.

`jwks-parse` (pure) parses already-fetched JWKS JSON; a malformed document or a `[jwk]` whose `alg` is inconsistent with its `kty`/`crv` → `CXER3717`. `claim` reads a claim from a verified `[claims]` (absent → the absence channel, not `null`, not error; non-`[claims]` arg → `CXER3718`); `jwk-by-kid` selects a `[jwk]` by `kid` (no match → absence). This fetch-once / verify-many seam keeps verification fully offline and pure.

## §4. Edge cases

- **Empty message** — `hmac-sha256(key, b"")` matches the NIST/RFC empty-message vector. `hkdf` with empty `info` is well-defined.
- **Empty HKDF salt** — `hkdf-extract(b"", ikm)` uses HashLen zero bytes per RFC 5869 §2.2.
- **BLAKE3 key length** — `blake3-keyed` with key ≠ 32 bytes raises `CXER3700`. HMAC keys may be any length.
- **HKDF length out of range** — `length <= 0` or `length > 255 * HashLen` raises `CXER3703`.
- **Unknown algo** — `hmac-new` / `hmac-verify` outside `{"sha256","sha384","sha512"}`, or AEAD outside `{"aes-256-gcm","chacha20-poly1305"}`, raises `CXER3700`.
- **AEAD tamper** — any flipped byte in `ciphertext` / `tag` / `nonce`, or mismatched `aad`, raises `CXER3704` and returns no plaintext.
- **AEAD / asymmetric key length** — non-32-byte key raises `CXER3700`; wrong-length nonce/tag on `aead-decrypt` raises `CXER3707`.
- **Per-call freshness** — `aead-encrypt`, `ed25519-keypair`, `x25519-keypair`, `password-hash` return different results on identical arguments (CSPRNG).
- **Malformed PHC** — `password-verify` raises `CXER3706`.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER3700` | `E_CRYPTO_KEY_INVALID` | wrong key length; unknown `algo`; malformed `argon2-cost` |
| `CXER3701` | `E_CRYPTO_MAC_VERIFY_FAILED` | `hmac-verify` / `blake3-mac-verify` on mismatch |
| `CXER3703` | `E_CRYPTO_LENGTH_INVALID` | `hkdf-expand` / `hkdf` length out of range |
| `CXER3704` | `E_CRYPTO_AEAD_AUTH_FAILED` | `aead-decrypt` on auth failure |
| `CXER3705` | `E_CRYPTO_SIGNATURE_INVALID` | `ed25519-verify` on invalid signature |
| `CXER3706` | `E_CRYPTO_PASSWORD_VERIFY_FAILED` | `password-verify` on wrong password or malformed PHC |
| `CXER3707` | `E_CRYPTO_NONCE_INVALID` | `aead-decrypt` on wrong-length `nonce` / `tag` |
| `CXER3709` | `E_JWT_MALFORMED` | not three b64url segments; header/payload decode fails; a `require`d claim absent (§3.10) |
| `CXER3710` | `E_JWT_SIGNATURE_INVALID` | `jwt-verify` signature does not verify against the resolved key |
| `CXER3711` | `E_JWT_EXPIRED` | `exp` is in the past beyond `leeway` |
| `CXER3712` | `E_JWT_NOT_YET_VALID` | `nbf` is in the future beyond `leeway` |
| `CXER3713` | `E_JWT_ALG_UNSUPPORTED` | header `alg` is `"none"`, absent, not in `expected-alg`, or unimplemented (`ES384`/`ES512`, or any other) |
| `CXER3714` | `E_JWT_KEY_NOT_FOUND` | no JWKS `[jwk]` matches the header `kid` (or `kid` ambiguous/absent against a multi-key set) |
| `CXER3715` | `E_JWT_CLAIM_MISMATCH` | token `iss` ≠ `expected-iss`, or `aud` does not contain `expected-aud` |
| `CXER3716` | `E_JWKS_FETCH_FAILED` | `jwks-fetch` got a non-2xx / transport fault / non-JWKS body (carries the http/net `[err]` child) |
| `CXER3717` | `E_JWKS_INVALID` | `jwks-parse` (or a fetched body) is not a well-formed JWKS, or a `[jwk]` `alg` is inconsistent with its `kty`/`crv` |
| `CXER3718` | `E_JWT_ARG_INVALID` | `claim` on a non-`[claims]` value; `jwt-verify` `$key` is none of a `[jwk]`/`[jwks]`/Ed25519 key / `[rsa-public-key]` / `[ec-public-key]` |
| `CXER3719` | `E_JWT_KEY_ALG_MISMATCH` | resolved key's `kty` inconsistent with the chosen `alg` (RS256 header vs EC/Ed25519 key, etc.) |

`CXER3702` is reserved (formerly `E_CRYPTO_NOT_IMPLEMENTED`; not reused). `CXER3708` is reserved (JWT/JWKS sub-block header). The `rsa-verify`/`ecdsa-verify` primitives take **no** new code — they join the §3.6 verify family (`CXER3705`/`CXER3700`).

## §6. Conformance fixtures

Under `conformance/stdlib/crypto.cxd`:

- **NIST HMAC vectors** — `hmac-sha256` / `hmac-sha384` / `hmac-sha512` reproduce NIST CAVP / RFC 4231.
- **Streaming = single-shot** — `hmac-new → update* → finalize` matches single-shot over concatenated chunks.
- **RFC 5869 HKDF vectors** — `hkdf-extract` / `hkdf-expand` / `hkdf` reproduce Appendix A cases 1–3 plus the SHA-512 variant.
- **HKDF one-shot identity** holds for arbitrary inputs.
- **BLAKE3 keyed vectors** — 35 official keyed-mode vectors.
- **Constant-time verify** — correct MAC returns `true`; a MAC differing at first byte and last byte both raise `CXER3701` with timing within tolerance.
- **Wrong BLAKE3 key length** raises `CXER3700`.
- **HKDF length bounds** — `length == 0` and `length > 255·HashLen` both raise `CXER3703`.
- **Unknown algo** raises `CXER3700` for HMAC and AEAD.
- **Webhook verification** — `hmac-verify("sha256", secret, raw-body, expected)` succeeds for matching MAC, raises `CXER3701` for tampered body.
- **AEAD round-trip** — both AES-256-GCM and ChaCha20-Poly1305 round-trip; result carries `algo`, `ciphertext`, `nonce` (12 bytes), `tag` (16 bytes).
- **AEAD nonce freshness** — two identical-input encrypts produce different `nonce` and `ciphertext`.
- **AEAD tamper** — any flipped byte of `ciphertext` / `tag` / `nonce`, or different `aad`, raises `CXER3704`; wrong-length nonce/tag raises `CXER3707`.
- **Ed25519 RFC 8032 vectors** — `ed25519-sign` reproduces §7.1; flipped-byte signature raises `CXER3705`.
- **Ed25519 keypair round-trip** — `ed25519-verify(kp.public, msg, ed25519-sign(kp.private, msg))` is `true`.
- **X25519 RFC 7748 vectors** — `x25519-shared-secret` reproduces §5.2 / §6.1; Diffie-Hellman agreement holds across two fresh keypairs.
- **Argon2id PHC round-trip** — `password-verify(pw, password-hash(pw, cost))` returns `true`; wrong password raises `CXER3706`; output parses as `$argon2id$v=19$m=...,t=...,p=...$<salt>$<hash>`; two calls produce different encoded strings.
- **`rsa-verify` (RFC 7518/8017)** — RS256/RS384/RS512 valid-signature vectors verify `true`; a flipped signature byte and a wrong key each raise `CXER3705`; an unsupported `hash` raises `CXER3700`.
- **`ecdsa-verify` (RFC 7518 §3.4)** — an ES256 P-256/SHA-256 vector verifies `true` with a raw `r‖s` (64-byte) signature; flipped-byte / wrong-key / off-curve-point each raise `CXER3705`; a DER-encoded signature does **not** verify; `P-384`/`P-521` raise `CXER3700`.
- **`jwt-verify` (hermetic, `now` pinned)** — RS256/ES256/EdDSA tokens verify to `[claims]`; `alg:"none"`, an `alg` outside `expected-alg`, a tampered signature, an expired `exp` (and within-`leeway` pass), a future `nbf`, a wrong `iss`/`aud`, a missing `kid`, and a key whose `kty` mismatches `alg` each raise the matching `CXER371x` code; a `require`d-claim-absent token raises `CXER3709`.
- **`jwks-parse`** — a mixed RSA/EC/OKP JWKS parses to `[jwks]`; `jwk-by-kid` selects by `kid` (absence on no match); an inconsistent `alg`/`kty` raises `CXER3717`.

## §7. Capabilities

Effectful functions in `cx-stdlib/crypto` run under deny-by-default capabilities ([`spec/core/security.md`](../core/security.md) §2): the effect point checks the active set and raises `cx-err:CXER0271` (E_CAP_DENIED, naming the missing capability and resource) when the grant is absent. Pure functions (in-memory transforms, parsing, formatting) require no capability.

The `random` capability is required wherever the function sources fresh OS entropy — the four `impure` surfaces: `password-hash` generates a random salt, `aead-encrypt` generates a nonce when one is not supplied by the caller, and `ed25519-keypair` / `x25519-keypair` sample fresh private-key material. Key generation is entropy consumption and is therefore capability-gated under deny-by-default — a trusted runtime never lets unprivileged code mint keys. All keyed primitives that operate purely over caller-provided material — HMAC, HKDF, keyed-BLAKE3, `constant-time-verify`, and the keyed signing/verification primitives — are pure and require no capability.

| Capability | Functions |
|---|---|
| `random` | `password-hash` (salt generation), `aead-encrypt` (nonce generation when internally generated), `ed25519-keypair` (private-key generation), `x25519-keypair` (private-key generation) |
| `net` | `jwks-fetch` (GET the JWKS document over `cx-stdlib/http`; the URI host:port is the gated resource — `CXER0271` on denial). Introduces no new capability; the same `net` grant http uses. |
| (none) | HMAC, HKDF, keyed-BLAKE3, `constant-time-verify`, all keyed primitives over caller-provided material, and the **pure** JWT surface (`jwt-verify`, `jwks-parse`, `claim`, `jwk-by-kid`, `rsa-verify`, `ecdsa-verify`) |

## §8. Cross-references

- [`spec/std-lib/hash.md`](hash.md) — content-fingerprinting sibling; D1 boundary rule lives there as well.
- [`spec/std-lib/random.md`](random.md) — the crypto-random source (`[$random:crypto-bytes]`) consumed by the four `impure` surfaces.
- [`spec/std-lib/bytes.md`](bytes.md) — hex / base64-url encoding for key and MAC transport.
- Algorithm support is implementation-internal; see §2 above for the supported primitive set. Bindings do not probe for individual crypto primitives via `cx_features` capability bits.
- RFC 2104 (HMAC), RFC 4231 (HMAC test vectors), RFC 5869 (HKDF), RFC 7748 (X25519), RFC 8032 (Ed25519), RFC 9106 (Argon2).
- JWT/JWKS (§3.10): RFC 7515 (JWS), RFC 7517 (JWK/JWKS), RFC 7518 (JWA — §3.3 RSA, §3.4 ECDSA), RFC 7519 (JWT), RFC 8017 (RSA PKCS#1), RFC 8037 (EdDSA JOSE), FIPS 186 / SEC1 (ECDSA). JWKS fetch transport: [`cx-stdlib/http`](http.md); JSON parse: [`cx-stdlib/json`](json.md). The consumer mapping verified claims → a session principal is `cx-stdlib/session` (XAP).
