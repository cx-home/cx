# Rulings — JOSE completeness for enterprise IdPs (#1093)

2026-08-28, release/0.18. Campaign umbrella #1097, workstream C (enterprise
SSO). Issue #1093 lettered five items; the campaign order taken this session
covers items 1–3, which are what unblocks #1090's `private_key_jwt` client
authentication. Items 4 and 5 are ruled here as well so the roster gaps stop
being silent.

Standing constraint: `spec/03-approved/std-lib/crypto.md` §3.6 (fail-closed,
`true`-or-raise) and §3.10 (a whole-token verification is a VALUE) are not
reopened by any item below. Every addition rides the contracts already there.

## J-1 — RSASSA-PSS verification (PS256 / PS384 / PS512)

RULED: `rsa-verify` gains `opts.scheme` ∈ `{"pkcs1-v1_5", "pss"}`, default
`"pkcs1-v1_5"` — one primitive, two padding schemes, rather than a second
verb. PSS parameters are the JOSE profile and are NOT caller-tunable
(RFC 7518 §3.5): MGF1 over the same hash, salt length = hash length,
trailer `0xBC`. An unknown scheme raises `CXER3700`; an invalid signature
raises `CXER3705`; the §3.6 contract is unchanged.

`jwt-verify`'s supported roster gains `PS256`/`PS384`/`PS512`, routed to
`rsa-verify` with `scheme: "pss"`. §3.10's step-3 key/alg agreement rule
extends to `RSA` ↔ `RS*` | `PS*`.

Rationale: this is an IdP-roster gap, not a new capability — no new key
material shape, no new grant, verify-only. ADFS/Ping profiles and every
FAPI-grade deployment offer or mandate PS*.

## J-2 — ES384 / ES512

RULED: `ecdsa-verify`'s `opts.curve` gains `"P-384"` and `"P-521"`; the
JOSE pairing fixes the hash (`ES384` → P-384/SHA-384, `ES512` →
P-521/SHA-512). Signatures stay the JOSE fixed-width raw `r‖s` — 96 bytes
for P-384, 132 for P-521 (66-byte coordinates, NOT 64) — never ASN.1/DER.
`jwt-verify` stops raising `CXER3713` for these two and verifies; the
`kty`/`crv` agreement rule extends to `EC/P-384` ↔ `ES384` and
`EC/P-521` ↔ `ES512`.

Rationale: crypto.md §3.8 already names these "a noted extension wired
through the same primitive". The curve arithmetic is generic over the
domain parameters; only the P-256 constants are hard-coded today.

## J-3 — asymmetric JWS signing, and the private-key posture

The blocking design question #1093 flags. Options put, and the ruling:

- **(a) Caller-supplied private key material only** — signing takes the
  JWK private members as an element, exactly mirroring the public-key
  element shapes §3.8 already defines. No key generation, no PEM/PKCS#8
  parsing, no key storage in Ring 1.
- (b) Add key generation + PEM/PKCS#8 import, so CX can mint its own
  client-authentication keys.
- (c) Signing only through an external KMS/HSM seam.

**RULED: (a).** It closes `private_key_jwt` — the actual #1090 blocker —
with the smallest new surface; it keeps key *lifecycle* (generation,
rotation, storage, attestation) out of a codec module, where it does not
belong; and a JWK with private members is the form an enterprise
deployment already holds a client-auth key in, because that is what the
IdP registration flow speaks. (b) adds an ASN.1/PEM parser with no live
consumer — a partial implementation by the seam-needs-live-consumer rule.
(c) likewise has no consumer today and can be added later behind the very
same verb, since the verb takes a key *value*, not a key *handle*.

Surface:

```
[?def rsa-sign   scope=public pure [returns bytes]  ($private-key::element $msg::bytes $opts::map {}) ...]
[?def ecdsa-sign scope=public pure [returns bytes]  ($private-key::element $msg::bytes $opts::map {}) ...]
[?def jwt-sign   scope=public pure [returns string] ($claims::map $key::element $opts::map {}) ...]
```

Private-key element shapes (the JWK private members, big-endian `bytes`):

```
[rsa-private-key n=<bytes> e=<bytes> d=<bytes> p=<bytes> q=<bytes> dp=<bytes> dq=<bytes> qi=<bytes>]
[ec-private-key crv="P-256" x=<bytes> y=<bytes> d=<bytes>]
```

`p`/`q`/`dp`/`dq`/`qi` are OPTIONAL: present, signing takes the CRT path;
absent, it falls back to the plain `m^d mod n`. Both produce the identical
signature, so this is a speed choice, never a semantic one.

**ECDSA nonce: RULED deterministic, RFC 6979.** `ecdsa-sign` stays PURE.
A per-signature random `k` would make the verb impure and, far worse,
makes catastrophic private-key disclosure a single RNG mistake away —
the same reasoning §3.7 uses to generate AEAD nonces internally rather
than accept them. RFC 6979 derives `k` from (key, message) via HMAC-DRBG;
every JOSE verifier accepts the result, because a signature is just
`(r, s)`. This also makes `jwt-sign` a pure function of its inputs, which
keeps the conformance corpus able to pin exact tokens.

`jwt-sign` composes the JOSE header (`alg`, `typ: "JWT"`, `kid` when the
key carries one) and the payload, b64url-encodes both, signs the
reconstructed signing input, and returns the compact serialization. It
mints only what it is given: no clock read (`iat`/`exp` are the caller's
claims, passed in), so it is pure like `jwt-verify`. Algorithms:
`RS256`/`RS384`/`RS512`, `PS256`/`PS384`/`PS512`, `ES256`/`ES384`/`ES512`,
`EdDSA` — the verify roster after J-1 and J-2, minus nothing.

## J-4 — HS256 and the rest of the HS* family

RULED: **permanently refused, and now documented as a decision rather
than a roster gap.** `jwt-verify` stays asymmetric-only. A shared-secret
JWS is exactly the material of the classic alg-confusion downgrade
(RS256 → HS256, using the RSA public key as the MAC key), and this
surface exists to verify tokens an *external* IdP minted — an IdP that
signs with HS* is handing the same symmetric secret to every relying
party, a posture the stdlib should not make convenient. The refusal keeps
`CXER3713` and its message names both the reason and `hmac-verify` as the
primitive for a caller who genuinely holds a shared secret.

## J-5 — JWE (RFC 7516)

RULED: **not scoped this cycle**, and this is a measurement decision, not
a deferral of ruled work. Encrypted ID tokens are a per-tenant IdP
configuration; scoping a JWE surface before a named deployment needs one
would build a decryption stack against a guess. Trigger to revisit: a
named target tenant that encrypts ID tokens. If it is ever built it is
decrypt-only, on the same reasoning that keeps §3.10 verify-only.

## Execution notes

- Spec first: `crypto.md` §3.8 (scheme/curve rows, the private-key element
  shapes, the sign verbs), §3.10 (roster, `jwt-sign`), §5 (codes), §6
  (fixtures). Then fixtures, then implementation — the zip lane's order.
- Test vectors are the acceptance bar: RFC 8017 PSS, RFC 6979 §A.2.5/A.2.6
  deterministic-ECDSA vectors, and a round-trip `jwt-sign` → `jwt-verify`
  per algorithm. A signing surface with no cross-implementation vector is
  not evidence.
