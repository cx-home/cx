# The feature marketplace — today vs specified

Governing spec: the feature distribution & market spec
(`spec/03-approved/xap/xap_feature_distribution_market.md`). One-sentence model:

> A feature package is a content-addressed subtree signed by a publisher DID;
> a **market is itself a XAP** whose features are catalog, entitlement, and
> distribution; a **license is a VC** (an attenuating delegation); installing
> = fetch by hash → verify → compose-gate → enable.

There is **no central market**: the market is a protocol instance; N markets
compose into one discovery surface exactly as N XAPs compose into one
experience.

## Status at v0.13.0 — read this first

| Piece | Status |
|---|---|
| Packaging, signing, publish, verify, install, `pkg:` loading, deployment host | **Implemented** (see [registry setup](registry-setup.md) / [consuming](registry-consuming.md)) |
| Stage-1 git registry, stage-2 served registry, catalog/discovery | **Implemented** — proven by the original external reference instance (in-family successor: `reference/shop`) and the cx-private `registry` |
| Entitlement machinery — `[$xap:license-issue]` / `[$xap:license-verify]`, all pricing shapes, install-policy enforcement | **Implemented** (engine + conformance; verified below) |
| The market **as a running product** — hosted catalog XAP, publisher onboarding, storefront | **Specified, not yet implemented** — the market-as-a-XAP grammar is spec'd and conformance-exercised as data; no deployed market service exists |
| The `commerce` feature + **payment-rail adapters** (card, invoicing/PO, app-store, crypto), refunds/chargebacks → revocation VCs | **Specified, not yet implemented** (phase P3 of the spec's staged implementation) |
| Yank / revocation attestation flow end-to-end (composer surfacing) | **Specified, not yet implemented** (needs the market composer surface; the attestation VC machinery itself is shipped) |
| Multi-market federation on one surface | **Specified**; markets-federate-as-data is fixture-proven, no runtime surface |

## Entitlements — a license is a VC

Enforcement is the existing capability model: **the entitlement check is a
PEP check, not a DRM subsystem**. The enable-time question is always "does a
verifying VC cover enabling this package for this principal?" — and every
commercial model is an attenuation shape of the issued VC. Verified today:

```cx
[?lib 'cx-xap' :as xap]
[?lib 'cx-stdlib/crypto' :as crypto]
[?lib 'cx-stdlib/did' :as did]
[?let [= $kp [$crypto:ed25519-keypair]]              # --allow-random
 [= $publisher [$did:key-create $kp@public]]
 [= $vc [$xap:license-issue $publisher $kp@private "principal:alice"
                 {package: "own-ship" versions: "0.x" kind: "perpetual"}]]
 [?let [= $v [$xap:license-verify $vc "own-ship" "0.1.1" {now: "2026-07-10T00:00:00Z"}]]
  $v@status]]
# → 'ok'   (a version outside the range fails with CXER4883)
```

Subscription with an offline grace window (verified — `now` past `expires`
but inside `grace-until` verifies with status `grace`, so a vessel
mid-passage keeps working with no phone-home):

```cx
[?let [= $vc [$xap:license-issue $publisher $kp@private "principal:vessel-1"
               {package: "weather" versions: "*" kind: "subscription"
                expires: "2026-08-01T00:00:00Z" grace-until: "2026-08-15T00:00:00Z"}]]
 [$xap:license-verify $vc "weather" "0.1.0" {now: "2026-08-07T00:00:00Z"}]]
# → status 'grace'
```

## Fee structures — every pricing model is a VC shape

From the pricing-models section of the spec (all shapes implemented in the
license machinery; the *selling* of them awaits the market/commerce phases):

| Model | VC shape |
|---|---|
| one-time / perpetual | no expiry; attenuated to a version range (`1.x`); a new major is a new purchase |
| subscription | short-lived VCs re-issued on a cadence + a declared grace window (the certificate-renewal pattern — no revocation polling) |
| per-seat | an org VC delegable into at most N principal-bound sub-VCs — **the delegation chain is the count**; each seat offline-verifiable |
| metered / usage | entitlement grants enable + a reporting obligation; the consuming XAP's hash-chained journal is the non-repudiable meter, settled post-hoc |
| trial / free tier | a time-boxed / subset-attenuated gratis VC — free is not a special case |

**Price is a market property, never a package property.** The manifest
carries `license-terms` only; the same signed artifact can be paid in one
market, free in another. `pkg-install` takes `OPTS.entitlement` (verified
fail-closed as part of the trust chain) and `OPTS.require-entitlement` (the
consuming XAP's install policy) — the artifact and its verification are
identical with or without a VC requirement.

Bundles are **catalog objects, not features** (commercial grouping, not
semantic composition): one VC covers the member set; install stays strictly
per-package — bundling bypasses no gate and no consent.

## Payment processing — rails as adapters (specified)

Settlement is designed as a `commerce` feature *of the market XAP*: nouns
`order`/`settlement`/`price`, verbs `quote`/`place-order`/`record-settlement`;
the order → settlement → `issue-license` choreography is journaled intents,
so a market's commercial history is replayable evidence. Payment providers
are **source adapters** behind the feature — the same layered gateway seam
features use for data — so swapping or adding a rail touches no grammar, and
the PCI/PSD2 surface is confined to the adapter by construction. The
consuming runtime never sees payment data at all: everything below the
entitlement seam is invisible above it. **None of this is implemented yet**
(phase P3); build against the entitlement seam and commerce slots in later
without touching your XAP.

## What a dev can do TODAY

1. Publish sealed, signed packages to a git registry and consume them by pin
   — a complete, trustworthy distribution system for one trust domain.
2. Serve the same registry over CSRP and search it with `pkg-catalog`.
3. Issue and verify entitlement VCs in every pricing shape, and enforce them
   at install with `require-entitlement` — e.g. gate an internal paid tier.
4. Design listings: a catalog listing *is* the feature's grammar +
   requirements, so discovery is structured query, not text search.

What you cannot do yet: point a customer at a hosted market, take a card
payment, or run the yank/refund attestation flows — all specified in the
distribution & market spec, staged behind its market-federation + commerce
phase.
