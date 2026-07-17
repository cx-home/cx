# `cx-stdlib/vc` — verifiable credentials

```cx
[module-meta name=vc tier=D status=current
  [standard ref='W3C VC Data Model 2.0' title='Verifiable Credentials']]
```

**Status:** Current (owner ruling 2026-07-12, #363 item 2(a) — graduated from Approved; same catalogue-linkage lag as [`did`](did.md)). Tier D — trust.

Normative reference for the `cx-stdlib/vc` module: **issue, verify, present, and revoke verifiable credentials**. Per [xap.md](../xap/xap.md) **R9**, a verifiable credential **is** a *portable, signed, attenuating [§22.2](../xap/xap.md) delegation* — the decentralized way to carry authority between DIDs without a shared central IdP. `vc` is the authority-carrying counterpart to [`did`](did.md) (identity).

---

## §1. Scope & role

The trust split:

| Concern | Module | Object |
|---|---|---|
| **who** you are | [`did`](did.md) | a DID (a principal, §22.1) |
| **what** you may do | **`vc`** | a signed delegation a DID issues to a DID |
| **enforcement** | [`authz`](authz.md) | the one PEP (§22.3) — **unchanged** |

A VC is **not a new trust primitive** (R9). The authority it carries is exactly a [§22.2](../xap/xap.md) `[delegation …]`: scoped, **attenuating** (cannot grant more than the issuer holds), time-bounded, revocable, tracing to a principal (N-TRUST-1). The VC is the *transport* — a signed, portable envelope that lets a delegation cross a trust domain and be verified offline against the issuer's DID, with no callback to the issuer.

> **Terminology — "capability" vs "feature".** In this doc (and the trust model generally) a **capability** is the §22.2 security primitive: a *granted right* to emit certain intents / read certain slices. A VC's `[delegation]` grants capabilities in exactly this sense. This is **distinct** from a **feature** — the composition *unit* a XAP is built from (the word that superseded "capability" as the unit term). A capability is a right; a feature is a unit. The two never mean the same thing here.

## §2. Credential shape

```cx
[vc id="urn:uuid:…"
  [issuer "did:key:z6Mk…"]              # the DID that signed this credential
  [subject "did:key:z6Mk…"]            # the DID the credential is about (the holder)
  [issued-at 2026-06-16T12:00:00Z]
  [expires   2026-06-16T13:00:00Z]
  [claim
    [delegation d-recon-77             # the §22.2 authority being conveyed
      [tenant acme]
      [from [principal "did:key:z6Mk…issuer"]] [to [principal "did:key:z6Mk…subject"]]
      [capabilities [refund-duplicate]]
      [over /orders] [attenuates d-dana-ops] [revocable true]]]
  [proof type=Ed25519Signature2020
    [verification-method "did:key:z6Mk…issuer#z6Mk…issuer"]
    [signature "z<base58btc>"]]]        # Ed25519 sig over the canonical credential-sans-proof
```

The `claim` carries a verbatim §22.2 `[delegation …]`. `from`/`to` principals are DIDs; the PEP consumes the delegation inside a *verified* VC identically to a locally-issued one — so DID/VC changes the *authority basis transport*, not the enforcement (R9).

## §3. Surface

```cx
[?lib 'cx-stdlib/vc']

# ── issue ──────────────────────────────────────────────────────────────────
# Sign a credential conveying `claim` (a §22.2 [delegation …]) from `issuer-did`
# to `subject-did`. The issuer's 32-byte Ed25519 seed signs the canonical
# credential-sans-proof. Deterministic given inputs ⇒ pure.
[?def issue   scope=public pure   [returns element]
  ($issuer-did::string $issuer-key::bytes $subject-did::string $claim::element $opts::map {})
  [$vc-issue $issuer-did $issuer-key $subject-did $claim $opts]]

# ── verify ─────────────────────────────────────────────────────────────────
# Verify signature + validity window + non-revocation. Returns a
# [vc-verification status=… …] report (never throws on an invalid VC).
#   status ∈ valid | bad-signature | expired | not-yet-valid | revoked | malformed
# `now` anchors the validity-window check. `opts.revoked` is the set of revoked
# VC ids (a fold of revoke events — §5); offline-clean for a did:key issuer.
[?def verify  scope=public pure   [returns element] ($vc::element $now::datetime $opts::map {})
  [$vc-verify $vc $now $opts]]

# valid? — convenience boolean over verify.
[?def valid?  scope=public pure   [returns bool]    ($vc::element $now::datetime $opts::map {})
  [$vc-valid $vc $now $opts]]

# ── present ────────────────────────────────────────────────────────────────
# Package a VC for transport to a verifier, optionally binding it to a holder
# proof over a verifier-supplied challenge (proof-of-possession). v1 returns a
# [vp …] wrapper; without a holder key it is a passthrough envelope.
[?def present scope=public pure   [returns element] ($vc::element $opts::map {})
  [$vc-present $vc $opts]]

# ── revoke ─────────────────────────────────────────────────────────────────
# Append a revoke event for a VC id to a journal (§5). Impure — it writes.
[?def revoke  scope=public impure [returns element] ($journal::element $vc-id::string $opts::map {})
  [$vc-revoke $journal $vc-id $opts]]

# revoked-set — fold a journal's revoke events into the id set verify consults.
[?def revoked-set scope=public impure [returns element] ($journal::element)
  [$vc-revoked-set $journal]]
```

## §4. Canonicalization & proof

The signed bytes are `render_canonical(credential-without-the-proof-child)` (the lossless, deterministic CX canonical form — [core/code.md](../core/code.md)). `issue` removes any existing `proof`, canonicalizes, signs with `[$crypto:ed25519-sign]`, and attaches the `[proof …]` with the signature base58btc-encoded (`z`-multibase). `verify` reconstructs the identical bytes (strip `proof`, canonicalize), recovers the issuer's Ed25519 key from `verification-method`/`issuer` via [`did`](did.md) (`key-of` for did:key; `resolve` for did:web), and checks the signature with `[$crypto:ed25519-verify]`. Proof type: `Ed25519Signature2020`.

## §5. Revocation (decision #3)

A VC is offline-verifiable, so revoking a *still-unexpired* VC is the cert-revocation problem. The model:

- **`revoke`** appends a `[revoke vc-id=… at=…]` **event** to a journal — revocation is *data in the log*, not mutable state.
- **`revoked-set`** folds those events into the id set; **`verify`** rejects any VC whose id is in `opts.revoked` (status `revoked`).

**(3a — implemented now): single-runtime, journal-backed.** Correct and complete for one runtime; `verify` enforces against the local fold.

**(3b — documented, forward-compatible): cross-runtime propagation.** Because revocation is a journaled *event*, fleet-wide revocation across the [§9.2](../../02-working/xap_architecture.md) load-balanced workers / federated peers / vessels is **just** letting `revoke` events ride the same federation journal-sync that carries every other event — `verify`'s logic is unchanged; only how `revoked-set` is populated changes. Eventual-consistency, offline-tolerant (a verifier enforces on its last-synced view). This is a [§28.3](../xap/xap.md) **D5 open decision** (revocation propagation across N runtimes; trust-domain honor-list) — the federation sync transport itself is out of scope here (relates to the XSP RFC #31). The day-one event model means adopting (3b) needs **no redesign** of issue/verify.

## §6. Trust integration (R9)

- VC ⇄ §22.2 delegation: the `claim` is a verbatim `[delegation …]`; **attenuation is preserved** — a holder re-issuing (chained VC, `attenuates`) cannot widen capabilities.
- The **PEP is unchanged** (§22.3): on an incoming intent, the bus consumes the delegation from a *verified, unrevoked, unexpired* VC exactly as a local grant; authority still traces to a principal (N-TRUST-1).
- **did:web issuer** ⇒ `verify` must resolve (net); **did:key issuer** ⇒ fully offline (the marine/at-sea path).

## §7. Purity & effects

| Function | Purity | Effect |
|---|---|---|
| `issue`, `verify`, `valid?`, `present` | **pure** | none (Ed25519 sign/verify are deterministic; did:key resolution is offline). A did:web *issuer* requires the caller to resolve first. |
| `revoke`, `revoked-set` | **impure** | journal write / read |

## §8. Errors / statuses

`verify` returns a status rather than throwing: `valid` · `bad-signature` · `expired` · `not-yet-valid` · `revoked` · `malformed`. `issue` errors: `CXER-VC-KEY-INVALID` (seed not 32 bytes), `CXER-VC-CLAIM-INVALID` (claim is not a `[delegation …]`).

## §9. Cross-references

- [xap.md](../xap/xap.md) §22.2 (delegation), §22.3 (PEP), §28.2 R9, §28.3 D5.
- [did.md](did.md) — the issuer/subject identifiers + key recovery.
- [std-lib/crypto.md](crypto.md) — Ed25519 sign/verify.
- [std-lib/journal.md](journal.md) — the revoke-event log.
- [std-lib/authz.md](authz.md) — the PEP that consumes the delegation.
- Issue #26 (foundational did + vc); #31 (XSP / revocation propagation transport).
