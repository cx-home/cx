# `cx-stdlib/did` — decentralized identifiers

```cx
[module-meta name=did tier=D status=current
  [standard ref='W3C DID Core 1.0' title='Decentralized Identifiers']]
```

**Status:** Current (owner ruling 2026-07-12, #363 item 1(a) — graduated from Approved; the module ships and the spec was already normative, only the catalog linkage lagged). Tier D — trust.

Normative reference for the `cx-stdlib/did` module: create, parse, resolve, and prove control of **W3C Decentralized Identifiers (DIDs)**. A DID is a globally-unique, self-sovereign, cryptographically-verifiable identifier — the **decentralized** identity source named in [xap.md](../xap/xap.md) §22.1 (an external identity source is "an IdP (OIDC/SAML) **or** a DID resolver"), and the concrete realization of **R9**: *a DID identifies a principal*.

---

## §1. Scope & role in the trust model

`did` sits behind the [§22.1](../xap/xap.md) identity seam, alongside `crypto`'s JWT/JWKS surface:

| Identity source | Module | Federation style | Trust anchor |
|---|---|---|---|
| IdP (OIDC/SAML) → JWT | `crypto` (`jwt-verify`/`jwks-*`) | **centralized** (SSO) | the IdP's signing key |
| **DID resolver** | **`did`** | **decentralized** | **proof of key control** — no CA, no central IdP |

Per **R9**, DID is a *decentralized authority-basis transport*, **not a new trust primitive**: it produces a `(principal, tenant)` session exactly as JWT verification does ([§22.1](../xap/xap.md)), and the one PEP ([§22.3](../xap/xap.md)) + N-TRUST-1 are unchanged. The principal **is** the DID; authority delegated to it travels as a **verifiable credential** (see [vc.md](vc.md), the R9 "portable, signed, attenuating §22.2 delegation").

**Why DID for XAP specifically.** A DID needs no always-online central IdP: a `did:key` is self-describing and **offline-verifiable**, which is the correct identity model for an intermittently-connected marine helm at sea and for a **cross-org agent mesh** ([§22.6.1](../xap/xap.md)) where peer XAPs authenticate each other by DID rather than a shared SSO.

## §2. Supported methods (v1)

| Method | Form | Resolution | Network | Use |
|---|---|---|---|---|
| **`did:key`** | `did:key:z<mb>` | **self-describing** — the public key IS the identifier; the DID Document is synthesized **offline** | none | clients (web/TUI/native), agents, offline/marine, the universal default |
| **`did:web`** | `did:web:<domain>[:<path>]` | HTTPS GET of `https://<domain>/.well-known/did.json` (or `/<path>/did.json`) | yes | **org/domain-anchored** identity; peer-XAP federation; human-meaningful trust |
| **`did:peer:0`** (identity-model G3) | `did:peer:0z<mb>` | **self-describing** — numalgo-0 wraps the same key material as `did:key`; synthesized **offline** ([identity model](../xap/xap_identity_model.md) §1) | none | pairwise peer identity in XSP-AUTH handshakes; interop with did:peer ecosystems |

`did:key` (and `did:peer:0`, its numalgo-0 sibling) is the universal client +
offline path. `did:web` adds an HTTPS **resolver seam** for domain-anchored org
identity and server↔server federation — it is the *only* method that touches
the network, and only at `resolve` time.

### §2.1. `did:key` encoding (normative)

For an Ed25519 public key (32 bytes):

```
did:key:z ‖ base58btc( 0xed 0x01 ‖ <32-byte-ed25519-public-key> )
```

- `0xed01` is the **multicodec** varint prefix for `ed25519-pub`.
- `z` is the **multibase** prefix selecting base58btc (Bitcoin alphabet).
- base58btc is provided by [`cx-stdlib/bytes`](bytes.md) `to-base58` / `from-base58`.

v1 standardizes on **Ed25519** (the key type `crypto` already provides). Other key types are a forward-compatible addition (new multicodec prefix); the surface does not change.

## §3. Surface

All bodies bottom out in the `did-*` native primitives (see `vcx/code/stdlib_did.v`). Encoding/parsing/`did:key` resolution is **pure**; `did:web` resolution is **impure** (net).

```cx
[?lib 'cx-stdlib/did']

# ── construct ──────────────────────────────────────────────────────────────
# Encode an Ed25519 public key as a did:key string.
[?def key-create  scope=public pure   [returns string]  ($public-key::bytes)
  [$did-key-create $public-key]]

# ── inspect ────────────────────────────────────────────────────────────────
# Structural parse of any DID string → [did method=… id=… raw=…].
[?def parse       scope=public pure   [returns element] ($did::string)
  [$did-parse $did]]

# Method name only ("key" | "web" | …).
[?def method      scope=public pure   [returns string]  ($did::string)
  [$did-method $did]]

# ── resolve ────────────────────────────────────────────────────────────────
# Synthesize the DID Document OFFLINE for self-describing methods (did:key).
# Errors (CXER-DID-NOT-SELF-DESCRIBING) for methods that require the network
# (did:web) — use `resolve` for those.
[?def document    scope=public pure   [returns element] ($did::string)
  [$did-document $did]]

# Resolve ANY supported method to a DID Document. did:key is offline;
# did:web performs an HTTPS GET (net-gated on the domain) via cx-stdlib/http.
[?def resolve     scope=public impure [returns element] ($did::string $opts::map {})
  [$did-resolve $did $opts]]

# ── keys & proof-of-control ──────────────────────────────────────────────────
# Extract the Ed25519 public-key bytes from a self-describing DID (did:key),
# derived offline from the identifier. Errors (CXER-DID-NOT-SELF-DESCRIBING)
# for did:web — read the verification method from `resolve`'s document instead.
[?def key-of      scope=public pure   [returns bytes]   ($did::string)
  [$did-key-of $did]]

# Proof-of-control: verify that `sig` over `challenge` was made by the key
# behind `did`. For self-describing DIDs (did:key) this is fully offline and
# pure — the auth handshake for an attach (§22.1). For network-resolved
# methods, resolve → key-of → [$crypto:ed25519-verify].
[?def verify-control scope=public pure [returns bool]   ($did::string $challenge::bytes $sig::bytes)
  [$did-verify-control $did $challenge $sig]]
```

`key-of` operates on a self-describing DID string (did:key) and is the offline path that `verify-control` uses internally. For `did:web`, resolve the document and read its verification method.

## §4. DID Document shape

`document` / `resolve` return a CX-native DID Document (a lossless projection of the W3C JSON-LD shape):

```cx
[did-document
  [id "did:key:z6Mk…"]
  [verification-method
    [vm [id "did:key:z6Mk…#z6Mk…"] [type Ed25519VerificationKey2020]
        [controller "did:key:z6Mk…"] [public-key-multibase "z6Mk…"]]]
  [authentication "did:key:z6Mk…#z6Mk…"]
  [assertion-method "did:key:z6Mk…#z6Mk…"]]
```

For `did:key` (and `did:peer:0`) every field is derived from the identifier itself (no I/O). For `did:web` the document is the parsed `did.json`, validated to contain at least one Ed25519 verification method whose `controller` matches the DID.

**`XAPStreamEndpoint` service entry (identity-model G3; spec-staged).** A DID
Document MAY carry a `[service]` child of type `XAPStreamEndpoint` advertising
where the subject accepts XSP streams ([identity model](../xap/xap_identity_model.md)
§2.3 — the discovery seam). *Staged:* the shape is normative in the identity
model, but no resolver or consumer ships yet; a document without it loses
nothing today.

## §5. `did:web` resolution

`resolve` of a `did:web` maps the identifier to a URL and GETs it over [`cx-stdlib/http`](http.md):

| DID | URL |
|---|---|
| `did:web:example.com` | `https://example.com/.well-known/did.json` |
| `did:web:example.com:agents:radar` | `https://example.com/agents/radar/did.json` |

- **TLS required**; net capability is gated on the domain (the existing `net`/`http` capability surface — §4.5 SSRF guard applies).
- `opts` may carry `timeout`, `http-client`, and a `trust-domains` allow-list (the [§22.10](../xap/xap.md) honor-list of domains a tenant accepts — a D5 open decision surfaced here).
- The fetched document MUST declare `id == <the DID>` or resolution fails (`CXER-DID-DOC-MISMATCH`).
- **Caching (resolve-once, verify-many):** a resolver MAY TTL-cache a resolved
  `did:web` document (keyed by DID), so repeated `verify-control` / key lookups
  for the same DID need not re-fetch within the TTL. The cache is an
  availability/latency optimization only — it never changes the trust decision
  (the cached verification key is still checked against a fresh challenge), and
  a short TTL bounds staleness given `did:web` has no revocation ledger
  (*authority* revocation is expressed via short-lived credentials, not
  document edits; *identity* lifecycle — routine key rotation via overlap
  documents, deactivation via tombstone — does edit the document and acts
  forward-only, N-IDENT-3; [identity model](../xap/xap_identity_model.md)
  §6.3–§6.5). The
  TTL is implementation-configured; `did:key` is offline and never cached. The
  CSRP service tier uses such a cache (shared with its OIDC JWKS cache).

## §6. Purity & effects

| Function | Purity | Effect |
|---|---|---|
| `key-create`, `parse`, `method`, `document`, `key-of`, `verify-control` | **pure** | none (offline; `document`/`verify-control` only support self-describing methods) |
| `resolve` | **impure** | net (only when the method is `did:web`) |

The split keeps the **offline/marine** path (`did:key`) entirely pure and capability-free; only `did:web` requires the net capability, and only at `resolve`.

## §7. Trust integration (R9)

- A **principal is a DID** ([§22.1](../xap/xap.md), R9). `session` attach accepts a DID + a proof-of-control signature (and optionally a VC) and maps it to a `(principal, tenant)` — see [session.md](session.md) and the attach handshake below.
- **Proof of control is mutual and CA-free**: the verifier resolves the DID Document and checks a signature over a fresh challenge (`verify-control`). The DID *is* the trust anchor (no X.509 hierarchy).
- **Authority** delegated to a DID principal travels as a **VC** ([vc.md](vc.md)) — the R9 portable, signed, attenuating [§22.2](../xap/xap.md) delegation. The PEP and N-TRUST-1 are unchanged. (Note: a *capability* here is the §22.2 granted right the VC conveys — **not** a composition unit; the unit is a *feature*. See [vc.md](vc.md) §1.)

Attach handshake (realized — [`session/attach-did`](session.md)):

```cx
# client proves control of its DID by signing a server-issued nonce
[?let [= $sig [$crypto:ed25519-sign $client-priv $nonce]]
  [$session:attach-did $client-did $nonce $sig {tenant: "acme"} {tls: true}]]
# server-side attach-did internally verifies control (did:key offline), gates on
# TLS, optionally verifies a cfg `vc`, and binds a (DID-principal, tenant) session.
```

## §8. Errors

| Code | When |
|---|---|
| `CXER-DID-MALFORMED` | not a `did:<method>:<id>` string |
| `CXER-DID-METHOD-UNSUPPORTED` | method is not `key`, `web`, or `peer` numalgo-0 (identity-model G3; was "`key` or `web`" in v1) |
| `CXER-DID-NOT-SELF-DESCRIBING` | `document`/`verify-control`/`key-of` called on a method that needs network resolution (e.g. `did:web`) — use `resolve` |
| `CXER-DID-DOC-MISMATCH` | resolved `did:web` document `id` ≠ the requested DID |
| `CXER-DID-KEY-UNSUPPORTED` | key type is not Ed25519 (v1) |

## §9. Cross-references

- [xap.md](../xap/xap.md) §22.1 (identity), §22.2 (delegation), §22.3 (PEP), §28.2 R9 (DID-anchoring), §22.6.1 (federation mesh).
- [std-lib/crypto.md](crypto.md) — Ed25519 primitives + the centralized JWT/JWKS counterpart.
- [std-lib/bytes.md](bytes.md) — `to-base58`/`from-base58` (multibase base58btc).
- [vc.md](vc.md) — verifiable credentials (the delegation transport over DIDs).
- [std-lib/session.md](session.md) — DID attach path.
- Issue #26 (foundational `did` + `vc` libraries); #31 (XSP identity section).
