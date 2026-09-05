# Ruling record — #1287: `crypto:certificate-key` — an X.509 certificate becomes a public-key element (2026-09-05)

Issue: #1287 (enhancement, area:cx-stdlib, **prio:high**). The S-10 gap #1091 left open
(`ledger/rulings_2026_08_29_saml_sp_1091.md`, implementation record 2026-09-04).
Spec: `std-lib/crypto.md` §3.10 (the JWKS / public-key material), §3.9 (public-key
verification primitives). Module: `cx-stdlib/crypto`.

## The gap, in one line

`cx-stdlib/saml` verifies against `crypto` public-key ELEMENTS — `[rsa-public-key n= e=]`,
`[ec-public-key crv= x= y=]`, `[jwk]`, `[jwks]` — which is right, because KeyInfo is never
trusted and the key comes from configured IdP metadata. But every SAML IdP publishes its
signing key as an **X.509 certificate** (`<KeyDescriptor><ds:KeyInfo><ds:X509Data>
<ds:X509Certificate>`, base64 DER), and `crypto` has no X.509 reader at all. So the one
step of enterprise SSO that cannot be done in CX is extracting a public key from the
certificate the deployment already trusts.

## 1287-Q1 — RULED (a): `crypto:certificate-key`

- **(a) RULED.** A pure verb in `cx-stdlib/crypto`, beside `jwks-parse`:
  `[$crypto:certificate-key CERT]` where `CERT` is DER `bytes` or a PEM string. It reads
  **SubjectPublicKeyInfo only** and answers the element the rest of the stdlib already
  speaks — `[rsa-public-key n= e=]` for `rsaEncryption`, `[ec-public-key crv= x= y=]` for
  `id-ecPublicKey` over P-256 / P-384 / P-521. Malformed input, an unsupported algorithm
  OID, or an unsupported curve → `CXER3700` (`E_CRYPTO_KEY_INVALID`, the code every other
  malformed-key path in this module already answers).
  **DELETES:** nothing. `certificate-key` is a free name in `crypto` (checked against the
  module's export list), no existing verb changes shape, and no error code changes meaning.
  Why crypto and not saml: crypto's J-3 ("crypto does not import keys") was about key
  LIFECYCLE — generation, storage, rotation. This is a **codec** over a certificate the
  deployment trusts by configuration, which is exactly what `jwks-parse` already is: a
  certificate is the other wire form of the same material. `did` / `vc` / `oidc` read the
  same form and would otherwise each re-import it.
- (b) `saml:certificate-key`. Rejected: it puts an X.509 reader inside the one module that
  must never trust an embedded certificate, which invites exactly the confusion the
  KeyInfo rule exists to prevent; and every other consumer re-imports it.
- (c) leave it to external tooling. Rejected: it is the last hand-rolled step in an
  otherwise all-CX SSO path, and every deployment carries the same shell snippet.

**Explicitly NOT in scope, and this is the security half of the ruling.**
`certificate-key` performs **no** chain building, **no** validity-window check, **no**
revocation check, and **no** name or usage constraint check. Those are deployment policy
over metadata trust, not codec work, and a verb that did some of them would read as if it
did all of them. The verb's contract is exactly "give me the key bytes inside these
certificate bytes"; trusting the certificate happened when someone configured it.

## 1287-Q2 — RULED (b): `saml:verify` does NOT also accept a certificate

- (b) **RULED — one key shape reaches `saml:verify`.** The caller composes:
  `[$saml:verify $doc [$crypto:certificate-key $cert]]`. **DELETES:** the convenience arm
  the issue floated. Reasons, in order: no dual-accept for one concept (the standing rule);
  a `saml:verify` that took certificates would have to decide silently whether to
  validity-check them, which is precisely what 1287-Q1 refuses to decide for the caller;
  and the composition is one call, visible at the call site, which is where "I chose to
  trust this certificate" belongs.

## Exit

Fixtures (`conformance/stdlib/crypto.cxd`, and the saml corpus): a self-signed RSA-2048
IdP-style certificate and an EC P-256 certificate as DER and as PEM →
`certificate-key` answering the exact `n`/`e` and `crv`/`x`/`y` bytes (cross-checked
against the same key's JWKS form, so the two importers agree by fixture); a truncated DER,
a PEM with a corrupt body, an Ed25519 certificate (unsupported here) and a garbage OID →
`CXER3700`; then `saml:verify` over the #1091 corpus documents using the extracted key,
byte-identical to the same run with the key written out by hand. Spec: `crypto.md` §3.10
gains the verb under `RULED: 1287-Q1`, with the "no chain, no validity, no revocation"
sentence normative; `saml.md`'s key paragraph points at the composition under
`RULED: 1287-Q2`.
