# RULED: 1400-a, 1401-a — XML Encryption comes IN: `saml:verify` decrypts `EncryptedAssertion` / `EncryptedID` / `EncryptedAttribute` with `opts.decryption-keys`; `crypto` gains RSA key transport (OAEP, SHA-1 inside OAEP allowed; PKCS#1 v1.5 behind a loud opt-in with implicit rejection) and AES-CBC + AES-128/192-GCM; encryption is detected BEFORE the signature search

**Fable, 2026-09-11 03:3xZ, under the owner's delegation of 2026-09-09 05:50 ET**; the owner
may override on #1354. Lane S item S8 (#1400) and S13 (#1401), ruled together because the
honest refusal (#1401) is the no-key arm of the support (#1400). Premises re-verified at
`19af3b349`: no `EncryptedKey`/`CipherValue`/`xmlenc` code anywhere; `crypto` has
`rsa-sign`/`rsa-verify` over its own `math.big` RSA (`stdlib_crypto.v:1784-1830`, CRT path
present) and no decrypt; AEAD is `aes-256-gcm`/`chacha20-poly1305` only (`:601,641`) over an
in-house GCM (`gcm_*` `:712-810`) on `crypto.aes` blocks — `aes.new_cipher` takes 16/24/32-byte
keys, so 128/192 is a gate, not a primitive; V's vlib ships `cipher.new_cbc`; `saml_verify_verb`
searches signatures FIRST (`:401-404`) so an encrypted assertion under an unsigned Response is
reported as `CXER5401 SIGNATURE_MISSING` (measured on #1401); `EncryptedAttribute` has zero
occurrences in the implementation (silently dropped by `attributes`/`claims`); OpenSSL 3.6.2 is on
the host, `xmlsec1` is not. `saml.md` §1.1's revisit trigger — *"the first IdP that will not send
plaintext assertions over TLS"* — has fired: ADFS and Entra tenants enforce assertion encryption
by security policy, and the owner named both.

## 1. Scope of the support — RULED (a)

- **(a) all three encrypted forms, in `verify`, behind `opts.decryption-keys`.** `verify` gains
  `opts.decryption-keys` — a sequence of `[rsa-private-key …]` elements (or a `[jwk]` carrying
  private members), tried in turn like `keys` is. Order, fixed: (1) verify every VISIBLE
  signature (a signed `Response` is verified over the ciphertext it carries); (2) decrypt each
  `EncryptedAssertion` — resolve its `EncryptedKey` (inline `ds:KeyInfo/xenc:EncryptedKey`, or
  a `RetrievalMethod`/`ReferenceList` pointing at a sibling `EncryptedKey`), RSA-unwrap the
  content key, decrypt `CipherValue` (IV-prefixed), parse the plaintext octets with the §2.1
  reader **in the parent's in-scope namespace context** (XML-Enc §4.3), and splice the
  `Assertion` where the `EncryptedAssertion` stood; (3) verify the decrypted assertion's own
  signature(s) — every signature present must verify, an unsigned decrypted assertion under an
  unsigned Response is `CXER5401` exactly as a plaintext one is; (4) inside the verified
  assertion, decrypt `EncryptedID` → `NameID` and every `EncryptedAttribute` → `Attribute`,
  splicing in place; (5) return a fully-plaintext verified subtree. `assertion`, `validate`,
  `attributes`, `name-id`, `claims` are unchanged — they never see ciphertext. DELETES the §1.1
  XML-Encryption exclusion and the "XML Encryption" clause of `CXER5411` (which keeps its
  non-`bearer` clause).
- **(b) `EncryptedAssertion` only** — refused: `EncryptedID` and `EncryptedAttribute` are the
  same seam with the same key, and the measured silent DROP of `EncryptedAttribute` is the
  worst of the three defects.
- **(c) a separate `decrypt` verb the caller runs before `verify`** — refused: it hands the
  caller ciphertext-then-plaintext ordering to get right, which is the "boolean beside the
  document" shape this module exists to refuse; and a Response signature must be verified over
  the ciphertext, which only `verify` can order.

## 2. Algorithms — decided, with the reasons on record

| XML-Enc identifier | Decision |
|---|---|
| `xmlenc#rsa-oaep-mgf1p` (SHA-1 digest, MGF1-SHA1) | **ACCEPTED.** Every named IdP's default key transport. **SHA-1 INSIDE OAEP IS ALLOWED**: OAEP's hash and MGF1 are not collision-sensitive uses, so S-5's SHA-1 refusal — about signatures and digests over signed content — does NOT extend here. Recorded as its own line in `saml.md` §6 so nobody reads S-5 as forbidding it. |
| `xmlenc11#rsa-oaep` (+ `DigestMethod` sha256/384/512, `MGF` param) | **ACCEPTED.** |
| `xmlenc#rsa-1_5` (PKCS#1 v1.5 key transport) | **REFUSED by default** (`CXER5405`) — Bleichenbacher/ROBOT-class padding oracles; **loud per-deployment opt-in `allow-rsa-1_5`** in the verify opts, logged at every use, the 1410-a shape. The primitive underneath uses **implicit rejection** (a padding failure yields a deterministic pseudo-random key derived from the ciphertext and the private key, never an error), so the wrapped-key path exposes no oracle even when opted in. |
| `xmlenc#aes128-cbc` · `aes192-cbc` · `aes256-cbc` | **ACCEPTED** (ADFS and Entra default to `aes256-cbc`; Okta `aes128-cbc`). Padding per XML-Enc §5.2 (last octet = pad length, pad bytes arbitrary; PKCS#7 satisfies it). CBC has no integrity: the decrypted assertion MUST still carry a verifying signature (step 3), which is the integrity, and the record says so. |
| `xmlenc11#aes128-gcm` · `aes192-gcm` · `aes256-gcm` | **ACCEPTED** (IV‖C‖T layout, 12-byte IV, 16-byte tag). |
| `xmlenc#tripledes-cbc` | **REFUSED**, no opt-in (`CXER5405`): Sweet32-class, and no named IdP defaults to it. |
| `xmlenc#kw-aes128/192/256`, `kw-tripledes` (symmetric key wrap) | **DECLINED in v1** (`CXER5405`): SAML IdPs use RSA key transport; revisit trigger recorded: the first IdP metadata advertising key-wrap only. |

## 3. The crypto primitives — RULED (a): four verbs and a widened AEAD, all in `cx-stdlib/crypto`

```
[?def rsa-encrypt  scope=public impure [returns bytes]   ($public-key::element  $plaintext::bytes  $opts::map {}) …]   ; OAEP seed / v1.5 padding are random
[?def rsa-decrypt  scope=public pure   [returns bytes]   ($private-key::element $ciphertext::bytes $opts::map {}) …]
[?def cbc-encrypt  scope=public impure [returns element] ($algo::string $key::bytes $plaintext::bytes $opts::map {}) …]   ; → [cbc algo= iv= ciphertext=], IV generated internally
[?def cbc-decrypt  scope=public pure   [returns bytes]   ($algo::string $key::bytes $iv::bytes $ciphertext::bytes $opts::map {}) …]
```

`rsa-*` opts: `scheme` (`"oaep"` default | `"pkcs1-v1_5"`), `hash` (`"sha1"` default for OAEP —
the XML-Enc 1.0 identifier's meaning — `"sha256"`/`"sha384"`/`"sha512"`), `mgf1-hash` (defaults
to `hash`), `label` (OAEP `OAEPparams`, default empty). `cbc-*` `algo`: `"aes-128-cbc"` /
`"aes-192-cbc"` / `"aes-256-cbc"`; `opts.padding`: `"pkcs7"` (default) | `"none"`. `cbc-encrypt`
generates the IV internally for the same reason `aead-encrypt` generates its nonce (§3.7) — a
caller-supplied IV is the reuse footgun; `cbc-decrypt` takes the IV because the wire hands it
over. `aead-encrypt`/`aead-decrypt` accept `"aes-128-gcm"` and `"aes-192-gcm"` beside the two
today; `key` length follows the algorithm. **The encrypt halves exist** so the in-tree IdP
(`scripts/sso_interop/idp.cx`) can emit an encrypted response and the round trip is graded per
commit — dogfood, and the only way the interop lane can grade this at all. New code
**`CXER3720 E_CRYPTO_DECRYPT_FAILED`** for a CBC padding failure or an OAEP decode failure (the
v1.5 path never raises it — implicit rejection); a GCM tag failure stays `CXER3704`. Refused: (b)
a single `xmlenc-decrypt` verb in saml doing all of it privately — the primitives are general
(JWE will want the same four) and belong where `aead-*` lives.

## 4. The honest refusal — RULED 1401-a

Encryption is detected **BEFORE the signature search** (a walk for `EncryptedAssertion` /
`EncryptedID` / `EncryptedAttribute` runs first): with no `opts.decryption-keys` the answer is
**`CXER5413 E_SAML_ENCRYPTED`**, naming which element is encrypted and that `decryption-keys`
would read it — never `CXER5401 SIGNATURE_MISSING`, which the measured shape (unsigned Response
+ encrypted assertion, the one ADFS and Entra send) produces today. `EncryptedAttribute` is
never dropped: without keys → `CXER5413`; with keys → decrypted. `CXER5413` is also the answer
when no supplied key unwraps the `EncryptedKey`, or the content decrypt fails (bad padding, GCM
tag) — "the key is wrong / the ciphertext is not what was sent", the decryption analogue of
`CXER5402`; an algorithm outside §2's accepted set is `CXER5405`, as for signatures.
`saml-063` (today `CXER5411`) is deliberately re-recorded to `CXER5413`: the meaning changed by
ruling, and the landing note says so.

## 5. Spec text (delegated G3, flagged; commits carry `RULED: 1400-a`)

`saml.md` §1.1 (encryption IN; 3DES/kw declined with trigger; rsa-1_5 opt-in), §2.3
(`decryption-keys`, `allow-rsa-1_5`), §4.3 (the five decrypt steps interleaved with the
signature steps), §6 (the algorithm table above; the SHA-1-inside-OAEP line), §7 (5413; 5411
narrowed), §8 (cases), §9 (CBC has no integrity — the signature is the integrity).
`crypto.md` §3.7 (aes-128/192-gcm; `cbc-*`), §3.8 (`rsa-encrypt`/`rsa-decrypt`; implicit
rejection), §5 (3720). `governance.md` §9.6 (5413 in the 5400 row, 3720 in the 3700 row).

## 6. Conformance — vectors from an INDEPENDENT implementation, the S-2 rule

OpenSSL 3.6.2: `openssl pkeyutl -encrypt -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha1
-pkeyopt rsa_mgf1_md:sha1` for the `EncryptedKey`; `openssl enc -aes-256-cbc -K … -iv …` for the
content (PKCS#7 = valid XML-Enc padding); `openssl rand` for keys. The SP decryption key is a
FIXTURE key, inline in `saml.cxd` and labelled as a test vector — the corpus already carries
private test keys (`crypto.cx:252`), and a decryptor holds a private key by definition. Cases:
an encrypted (signed-inside) assertion under an unsigned Response decrypts and verifies, `claims`
unchanged; the same with no `decryption-keys` → `CXER5413` naming `EncryptedAssertion` (not
5401 — the #1401 arm); a signed Response wrapping an encrypted assertion (both signatures
verify, Response over the ciphertext); `EncryptedID` → `name-id` reads the plaintext;
`EncryptedAttribute` → `attributes`/`claims` carry it, and without keys → 5413; `aes128-cbc`,
`aes256-gcm` content variants; `rsa-oaep` (xmlenc11, sha256) key transport; `rsa-1_5` refused
5405 and accepted under `allow-rsa-1_5`; `tripledes-cbc` → 5405; a wrong SP key → 5413; a
tampered `CipherValue` → 5413 (CBC) / 5413 (GCM tag); every `crypto` verb pinned against the
OpenSSL vectors in `crypto.cxd` (OAEP decrypt of an OpenSSL ciphertext; CBC decrypt; the
implicit-rejection property — two different bad ciphertexts yield two different non-error
outputs; `rsa-encrypt` → `rsa-decrypt` round trip; `cbc-encrypt` → `cbc-decrypt` round trip).
Interop lane: the IdP gains `/saml/response-encrypted` (signed assertion, AES-256-CBC,
OAEP-MGF1P) and `rp_drive.cx` a `saml-encrypted-over-wire` row.

Nothing deferred except the two DECLINED algorithm families above, each with its trigger.
