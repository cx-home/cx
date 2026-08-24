# XAP — Identity Model (the ledger-free trust spine)

```cx
[module-meta name=xap_identity tier=D status=current]
```

**Status:** Current (owner G3 2026-07-18; authored 2026-07-12, issue #116 — the
owner's recharter: the complete identity model as ONE normative spec, not an
incremental residual; graduated from `spec/02-working`).
Companion pattern: this spec **extends [`xap.md`](./xap.md)
§22.1/§22.2 by reference** — the same modular-sibling shape
[`xap_feature_distribution_market.md`](./xap_feature_distribution_market.md)
took. It also resolves issue **#24** (session multiplicity & attach policy —
§4.9, §6.2). The dispatch-family catalog entry is
[`std-lib/xsp-auth.md`](../std-lib/xsp-auth.md).

**Foundations this spec builds on and does NOT respec** (each verified Current
2026-07-12): [`did.md`](../std-lib/did.md) and
[`vc.md`](../std-lib/vc.md) (R9 — a DID identifies a principal; a VC
is a portable, signed, attenuating §22.2 delegation);
[`xsp.md`](./xsp.md) (the frame carries the principal DID;
anonymous = `principal-len 0`); [`xap.md`](./xap.md)
§22.1–§22.10 (the trust model, one PEP, N-TRUST-1);
[`session.md`](../std-lib/session.md) (attach pipeline, mirrored
attach, `attach-did` realized); [`crypto.md`](../std-lib/crypto.md)
(Ed25519, X25519, HKDF, HMAC, crypto-random); the distribution spec
(packages signed by publisher DID, §3); [`code-identity.md`](../core/code-identity.md)
(Tier-2 semantic identity, never a trust input).

**Purpose — the load-bearing gap this closes.** Everything above ships, and yet
**no proof-of-control handshake is specified anywhere**: the XSP frame's
`principal` field is a **claim, not an authentication** —
[`xsp.md`](./xsp.md) §2 says so explicitly ("verification …
and authorization … are separate handshake/PEP concerns, not in the frame") and
then no spec supplies the handshake. This spec supplies it (§4), together with
the four parts the owner ruled inseparable from it: the DID-document profile the
handshake authenticates against (§2), the discovery that determines the
channel-binding target (§3), the lifecycle that governs mid-session rotation and
delegation survival (§6), and the VC→capability compilation that defines what an
authenticated DID must yield at the authz gate (§5).

**One-sentence model.**

> Every principal in the decentralized realization (R9) **is a ledger-free
> DID**; a peer **proves control** of it with a mutual, channel-bound,
> signed-ephemeral handshake **before** any session binds; authority reaches
> the session only as **verified, attenuating VCs compiled into the session's
> authority basis**; and the one PEP, the hash-chained journal, and the
> capability model are **unchanged** — this spec adds the missing *proof*
> layer, not a new trust primitive.

**No new trust primitive (checkable claim, §9.22).** Identity = DID
(`did.md`); authority = VC carrying a §22.2 `[delegation …]` (`vc.md`);
enforcement = the one PEP (§22.3); sessions = `session.md`; cryptography =
`crypto.md`. This spec composes those surfaces into a protocol and a set of
binding rules. It introduces **no new key format, no new credential format, no
new enforcement point, and no frame change** (the handshake rides ordinary XSP
v1 frames).

---

## §0. Invariants introduced (graduated into `xap.md` §26 at G3, 2026-07-18; normative text lives here)

> **N-IDENT-1 (proof before principal).** A runtime MUST NOT bind a session to
> a DID principal without verifying **fresh proof of control** of that DID,
> bound to the channel or handshake over which the session is established. The
> XSP `principal` field is an attribution/routing **label**; it is **never** an
> authentication input.

> **N-IDENT-2 (mutuality at trust boundaries).** Across a trust-domain boundary
> (`xap.md` §22.6.1 — federated peers, third-party features, foreign clients)
> authentication is **mutual**: the responder always proves its DID; an
> initiator that does not prove a DID is **anonymous** and receives at most the
> deployment's anonymous floor (§4.7). There is no configuration in which an
> unproven DID is treated as authenticated.

> **N-IDENT-3 (point-in-time attribution).** Attribution binds to the key
> material **proven at commit time**. Key rotation, document deactivation, and
> resolver-state changes act **forward only**: they gate *new* verifications and
> never retroactively re-attribute, invalidate, or orphan journaled history.

> **N-IDENT-4 (authority is per session).** Authority compiles **per session**
> — the session's individual authority is the deployment's local grants for
> the principal **plus** the delegations of VCs verified *on that session*
> (§5), and the whole is clamped by every envelope (`xap.md` §22.10:
> `effective = individual ∩ ⋂envelopes`); a VC can never confer authority an
> envelope forbids. Two concurrent sessions of one principal MAY hold
> different authority bases (§4.9). Authority never attaches to a connection,
> a client, or a bare DID string.

---

## §1. Principals & method-per-role

A **principal** is `xap.md` §22.1's authenticated subject, tenant-scoped. This
spec fixes its decentralized realization (R9): **the principal is a DID**, and
the supported methods are assigned per role:

| Role | Method | Why | Status |
|---|---|---|---|
| Ephemeral / per-task agent, offline client, universal default | **`did:key`** | the keypair *is* the identity — offline, instant, no hosting; per-task agent identity is free (`did.md` §2) | shipped (`did.md` v1) |
| Persistent agent, XAP server, org/domain identity, publisher | **`did:web`** | rotatable keys + a hosted document that can carry the **`XAPStreamEndpoint`** service (§2.3) — discoverable, human-meaningful, DNS+TLS-anchored (`did.md` §5) | shipped (`did.md` v1); service entry is this spec's profile (§2.3) |
| Pairwise, private agent↔agent channel | **`did:peer`** (numalgo-0 profile) | a self-describing inception-key DID exchanged directly, never published — pairwise identity without a public footprint | **staged** (§10 P4; a `did.md` v-next amendment) |

Normative rules:

- **`did:key` and `did:web` are the v1 floor** — exactly `did.md` §2; a
  conforming implementation of this spec MUST support both. `did:peer` is
  OPTIONAL until its `did.md` amendment lands; its v1 profile is **numalgo-0**
  (`did:peer:0z<mb>` — the same multicodec/multibase encoding as `did:key`, so
  resolution is the same offline synthesis; the only semantic difference is the
  *usage contract*: a `did:peer` MUST NOT be published in catalogs, documents,
  or public journals — it names a pairwise relationship).
- **One DID, one subject.** A DID names exactly one principal (or one agent
  acting as a delegated subject). Sharing a DID's private key across subjects
  is outside the model and unprovable within it — attribution (§22.6) assumes
  key custody per subject (custody itself is the #98 client concern, §8.9).
- **Servers are principals too.** A XAP server/deployment holds its own DID
  (typically `did:web`) — it is the responder identity of §4 and the signer of
  its provenance attestations (§7). This is already the distribution spec's
  publisher model applied to the serving role.
- **The anonymous principal.** XSP v1 admits `principal-len 0` frames. This
  spec reconciles that with `xap.md` §22.1's "there is no anonymous XAP":
  *anonymous is a channel property, never a commit property*. An anonymous
  **peer** (§4.7) may hold a session only where the deployment's attach policy
  maps it to a real `(principal, tenant)` — the §22.1 fixed pre-granted dev
  principal under `--role tooling` localhost trust, or a deployment-defined
  public observe-only principal. Every intent still commits under that
  `(principal, tenant)` through the one PEP. An anonymous *frame* on an
  authenticated channel inherits the channel's session principal (§4.8) — it is
  wire compression, not anonymity.

Fixtures: §9.1–§9.2.

---

## §2. DID-document profile

`did.md` §4 defines the document shape; this section profiles **what a document
must carry to participate in each XAP identity role**. The profile adds no new
document syntax — it constrains which standard blocks are present.

### §2.1. Baseline (all roles)

Every participating DID document MUST satisfy `did.md` §4:

- at least one **Ed25519** `verification-method` whose `controller` is the DID
  itself (v1 key floor, `did.md` §2.1 — other key types are forward-compatible
  additions there, not here);
- an **`authentication`** reference to an Ed25519 verification method — the key
  the §4 handshake accepts for proof of control;
- an **`assertion-method`** reference — the key that signs VCs (`vc.md` §4),
  provenance attestations (§7), and packages (distribution §3).

For `did:key` (and `did:peer:0`) the whole document is synthesized offline from
the identifier (`did.md` §4) and the profile is satisfied by construction —
the one derived key serves both `authentication` and `assertion-method`.

### §2.2. Key agreement (optional, reserved)

A document MAY carry an **X25519 `key-agreement`** verification method. The §4
handshake does **not** use it — the handshake generates *ephemeral* X25519 keys
per connection (forward secrecy; §4.5) and authenticates them with Ed25519
signatures. A static `key-agreement` key is **reserved** for payload-level
confidentiality (encrypted store objects, offline message envelopes,
`did:peer` pairwise use) — out of scope for v1 (§8.10: transport
confidentiality is TLS's job, per `session.md`'s TLS posture).

### §2.3. Service — `XAPStreamEndpoint` (the discovery seam)

A DID that **serves XSP** (a XAP deployment, a persistent agent that accepts
attaches) declares where, as a `service` entry — the only addition this profile
makes to the `did.md` §4 document shape (staged as a `did.md` amendment at
graduation, §10):

```cx
[did-document
  [id "did:web:xap.example.com"]
  [verification-method
    [vm [id "did:web:xap.example.com#key-1"] [type Ed25519VerificationKey2020]
        [controller "did:web:xap.example.com"] [public-key-multibase "z6Mk…"]]]
  [authentication  "did:web:xap.example.com#key-1"]
  [assertion-method "did:web:xap.example.com#key-1"]
  [service
    [svc [id "did:web:xap.example.com#xsp"] [type XAPStreamEndpoint]
         [endpoint "https://xap.example.com/xsp"]]]]
```

- **`type=XAPStreamEndpoint`**, one entry per offered transport binding. The
  `endpoint` URL's scheme selects the binding (`xsp.md` §4): `https://` = the
  v1 SSE+POST binding; `wss://` = the WebSocket binding when it lands;
  `tcps://` = raw TCP/TLS. Multiple entries are ordered by the publisher's
  preference; an initiator picks the first binding it speaks.
- The **endpoint origin is a trust input**: the initiator records the URL it
  dialed in the handshake transcript (§4.4), so a document that advertises one
  endpoint and a network that delivers another is detected at authentication,
  not discovered post-hoc (§8.4 unknown-key-share).
- `did:key` documents carry no `service` (nothing hosted, `did.md` §2) — a
  `did:key` peer can *initiate* but is discovered out of band (it is the
  ephemeral-agent method; persistent reachable identity is what `did:web` is
  for).

### §2.4. Rotation shape (consumed by §6.3)

A `did:web` document under **routine rotation** SHOULD carry **both** the
outgoing and incoming Ed25519 keys for a declared overlap window — both listed
under `verification-method` and `assertion-method`, the *new* key first (order
expresses succession; verifiers try in order). Verifiers accept either during
overlap; the overlap's length is the publisher's policy, bounded below by its
resolver-cache TTL (`did.md` §5 — a cached old document must age out before the
old key leaves). **Compromise rotation** carries only the new key (§6.4).

Fixtures: §9.3–§9.5.

---

## §3. Resolution & discovery (ledger-free)

Resolution is `did.md`'s, by reference — restated here only where the identity
model adds a rule:

1. **`did:key` / `did:peer:0`** — offline synthesis from the identifier
   (`did.md` §2.1/§4). Pure, no I/O, cache-irrelevant. This is the disconnected /
   field / air-gapped path: **two `did:key` peers achieve full mutual
   authentication (§4) with zero network beyond their own channel.**
2. **`did:web`** — HTTPS GET per `did.md` §5 (TLS required, `id` must match,
   net-gated on the domain, SSRF guard applies). The **`trust-domains`**
   allow-list (`did.md` §5, the §22.10 honor-list) is an **attach-policy
   input**: a responder MAY refuse to resolve initiator DIDs outside its
   honor-list (fail-closed federation); an initiator SHOULD pin the domains it
   will dial.
3. **Caching — resolve-once, verify-many** (`did.md` §5). A TTL cache never
   weakens §4: the handshake always uses **fresh nonces and fresh ephemerals**
   against whatever key the (possibly cached) document supplies; staleness is
   bounded by the TTL and priced in §6.3's rotation overlap.
4. **Discovery = resolve → select service → connect.** To reach a peer XAP:
   resolve its DID, read the `XAPStreamEndpoint` entries (§2.3), select the
   first mutually-supported binding, dial, and run §4 **before anything else**.
   Discovery is never trust (the distribution spec's rule, applied to
   endpoints): the *handshake* authenticates the peer; the resolved endpoint
   only says where to try, and the dialed URL is signed into the transcript so
   substitution is caught (§4.4, §8.4).
5. **No ledger, by design.** Create/rotate/deactivate are file operations on
   the publisher's own host (`did:web`) or nothing at all (`did:key`). There is
   no registration, no consensus, no phone-home; revocation of *authority* is
   the VC journal (`vc.md` §5), revocation of *identity* is document
   replacement (§6.3–§6.5).

Fixtures: §9.6–§9.7.

---

## §4. XSP mutual authentication — XSP-AUTH (the load-bearing section)

### §4.1. The gap, stated normatively

The XSP frame names *who* (`principal`); nothing in the shipped stack proves
it. `session.md` attaches by **JWT** (the centralized IdP path) and
`did.md` §7 defines the one-shot `attach-did` (nonce + signature — the realized
engine precursor, `session-attach-did`), but no spec defines a **mutual**,
**channel-bound**, **transport-uniform** handshake for XSP itself. XSP-AUTH is
that handshake. After it, N-IDENT-1 holds on the channel: the principal field
becomes an integrity-checked label (§4.8), never an identity source.

### §4.2. Protocol overview

XSP-AUTH is a **SIGMA-style authenticated key exchange**: signed ephemeral
X25519 Diffie–Hellman, four messages, riding ordinary XSP v1 frames. Both
identities are DIDs; both proofs are Ed25519 signatures over a canonical-form
transcript that covers the fresh ephemerals — which makes the exchange
**self-binding**: a relay that forwards messages unchanged learns nothing (it
cannot derive the session secret), and a relay that substitutes its own
ephemerals breaks the signatures. Properties delivered:

| Property | Mechanism |
|---|---|
| mutual proof of control | each side signs the transcript with its DID's `authentication` key (§4.4) |
| freshness / anti-replay | both nonces and both ephemerals are fresh per handshake; every signature covers both (§8.1) |
| channel binding | the transcript covers the dialed endpoint and the transport's binding value (§4.6); the derived keys bind all post-handshake traffic on non-connection transports (§4.8) |
| downgrade protection | offered + selected versions/parameters AND profile/feature token sets are inside the signed transcript (§4.4a, §8.3) |
| forward secrecy | ephemeral X25519; static keys only sign (§4.5) |
| anonymous-initiator support | the initiator MAY omit its DID and signature; everything else holds (§4.7) |
| reflection / role-confusion proofing | role labels inside every signed payload (§4.4) |

### §4.3. Messages & frame encoding

Handshake messages are CX elements carried as **CX `data-bin` payloads**
(`binary=true`) in ordinary XSP v1 frames on **stream-id 0** — no frame change,
no new frame type. When XSP-AUTH is active on a channel (the deployment's
attach policy requires it, or either peer initiates it), stream 0 is the
**control stream**: only XSP-AUTH payloads (and, post-handshake, §5
presentations and §6.3 rotations) ride it, and **no frame on any other stream
is admitted until the handshake completes** — a violation is
`CXER-XSP-AUTH-STREAM`, and `ping`/`pong` frames are the only exemption
(liveness is pre-trust). Deployments not using XSP-AUTH are untouched (stream 0
keeps its `xsp.md` default meaning there).

Frame usage: M1/M3 are `type=request` frames from the initiator; M2/M4 are
`type=reply` frames from the responder; M4 sets `eos=false` (stream 0 stays
open as the control stream). The frame-level `principal` field on M1/M3 MUST be
the initiator's claimed DID (empty when anonymous) and on M2/M4 the
responder's; a mismatch with the in-payload DID is `CXER-XSP-AUTH-STATE`.

```
initiator                                              responder
   │ ─ M1 hello:    v, i-did?, n_i, e_i, endpoint ────────▶ │
   │ ◀─ M2 challenge: v-sel, r-did, n_r, e_r, cb, sig_r ─── │
   │ ─ M3 prove:    sig_i?, tag_i, attach ────────────────▶ │
   │ ◀─ M4 confirm: tag_r, session ──────────────────────── │
```

```cx
# M1 — hello (initiator → responder)
[xsp-auth phase=hello
  [versions 1]                       # offered protocol versions, descending
  [offer-profiles "store xap"]       # offered profile + semantic-feature token
  [offer-features "credit peer resume store-delta store-feed"]
                                     # sets (§4.4a; xsp.md §5.0 surface 1) —
                                     # space-separated, SORTED, may be empty
  [initiator "did:key:z6Mk…"]        # ABSENT when anonymous (§4.7)
  [nonce  <bytes 32>]                # n_i — fresh, [$random:crypto-bytes]
  [eph    <bytes 32>]                # e_i — fresh X25519 public key
  [endpoint "https://xap.example.com/xsp"]]  # the URL/address the initiator dialed
                                     # (empty string on in-process/unix channels)

# M2 — challenge (responder → initiator)
[xsp-auth phase=challenge
  [version 1]                        # selected version
  [offer-profiles "store xap"]       # the responder's token sets (§4.4a)
  [offer-features "credit resume store-feed"]
  [responder "did:web:xap.example.com"]
  [nonce  <bytes 32>]                # n_r
  [eph    <bytes 32>]                # e_r
  [cb     <bytes>]                   # channel-binding value (§4.6; empty allowed)
  [sig    "z<base58btc>"]]           # sig_r over T-resp (§4.4)

# M3 — prove (initiator → responder)
[xsp-auth phase=prove
  [sig  "z<base58btc>"]?             # sig_i over T-init (§4.4); ABSENT when anonymous
  [tag  <bytes 32>]                  # tag_i = key confirmation (§4.5)
  [attach                            # session binding request (§4.9)
    [tenant "acme"]
    [session mirror]                 # mirror | new [name=…] | id=… | name=…
    [client [channel tui]]]]

# M4 — confirm (responder → initiator)
[xsp-auth phase=confirm
  [tag <bytes 32>]                   # tag_r = key confirmation (§4.5)
  [confirmed-profiles "store xap"]   # the selected sets — MUST equal the
  [confirmed-features "credit resume store-feed"]  # §4.4a intersection
  [session id="s-…" client="c-…"     # the session.md attach result (§4.9)
    [principal "did:key:z6Mk…"] [tenant "acme"]]]
```

Nonces and ephemerals MUST come from `[$random:crypto-bytes]` (via
`[$crypto:x25519-keypair]` for ephemerals). Signatures are base58btc
`z`-multibase strings, matching `vc.md` §4. Element order inside each message
is as listed; unknown extra children MUST be rejected in v1
(`CXER-XSP-AUTH-STATE`) — forward compatibility is the `versions` field's job,
not silent tolerance (§8.3).

### §4.4. Transcript & signatures (exact coverage)

The **transcript** assembles both opening messages verbatim, minus the
responder's own signature:

```cx
[xsp-auth-transcript
  [hello     <the M1 element, verbatim>]
  [challenge <the M2 element with its [sig] child removed>]]
```

Signing follows `vc.md` §4 exactly — Ed25519 over the **canonical render**
(`render_canonical`, `core/canonical.md`) of a wrapper that pins the
signer's role:

- `sig_r` = `[$crypto:ed25519-sign sk_r bytes-of [xsp-auth-sign role=responder T]]`
- `sig_i` = `[$crypto:ed25519-sign sk_i bytes-of [xsp-auth-sign role=initiator T [responder-sig "z…"]]]`
  — the initiator's signature additionally covers the responder's, closing the
  transcript (the TLS-1.3 pattern).

What the coverage buys, item by item: both **nonces** and both **ephemerals**
(freshness + self-binding), the **version** offer and selection (downgrade,
§8.3), the **profile/feature offers** on both sides (vocabulary downgrade,
§4.4a), both **DIDs** (identity misbinding), the **role labels** (reflection —
a message signed as responder can never verify as initiator), the dialed
**endpoint** and the **cb** value (channel binding, §4.6/§8.4).

### §4.4a. Vocabulary negotiation (stream 4, L164 — transcript-covered)

M1 and M2 each carry `[offer-profiles …]` and `[offer-features …]`; M4
carries `[confirmed-profiles …]` and `[confirmed-features …]`. Each is a
**single-scalar** field holding a space-separated, lexicographically
**sorted, duplicate-free** token set (the empty string is the empty set).
All four are REQUIRED from the `/3/` label generation; a message missing
one, or carrying a non-canonical set, is `CXER-XSP-AUTH-STATE`. Two
normative reasons for exactly that shape:

- **Single-scalar, not a nested element.** Handshake fields atomize to
  attributes across the data-bin frame round trip (§4.3); a nested carrier
  would pin child order and move the signed bytes between the fresh
  child-form message and the decoded attr-form one — the two sides would
  sign different transcripts. Every other handshake field already obeys
  this rule; these follow it.
- **Canonical set form.** The transcript signs BYTES, so two spellings of
  one set would be two distinct signed values — an aliasing surface.
  Builders normalize (sort + dedup); validators refuse non-canonical input.

The **selected set is not negotiated — it is COMPUTED**: the per-field
intersection of M1's and M2's offers. M4 STATES that
intersection, and the initiator MUST verify it equals the value it computes
from its own M1 and the received M2; a mismatch is `CXER-XSP-AUTH-STATE` and
the handshake aborts. Because both offer sets live inside the signed
transcript (§4.4) and the selection is a pure function of them, stripping or
injecting a token anywhere breaks a signature or the M4 check — the
downgrade-protection property extends from versions/suites to vocabulary,
closing #718's downgrade-strip hole. Semantic tokens (anything that changes
what a peer may say: `credit`, `resume`, `publish-batch`, `store-feed`,
`store-delta`, `peer`, profile names) MUST be offered here; operational
limits stay on the post-attach advert (xsp.md §5.0 surface 2), which
restates the confirmed set and MUST NOT extend it.

Verification: the peer's signing key is the Ed25519 key referenced by
`authentication` in its resolved DID document (§2.1; `did:key` offline via
`[$did:verify-control]` semantics, `did:web` via `[$did:resolve]` → key —
`did.md` §3). During a §2.4 rotation overlap the verifier tries the listed
keys in document order. A failed signature is `CXER-XSP-AUTH-SIG`; the
handshake aborts and nothing attaches (fail-closed — no partial state, §8.6).

### §4.5. Key schedule

```
ss    = [$crypto:x25519-shared-secret e_i_priv e_r_pub]      # 32 bytes, both sides
prk   = [$crypto:hkdf-extract (n_i ‖ n_r) ss]
k_tag_i   = hkdf-expand(prk, "xsp-auth/3/confirm/initiator", 32)
k_tag_r   = hkdf-expand(prk, "xsp-auth/3/confirm/responder", 32)
k_proof_i = hkdf-expand(prk, "xsp-auth/3/proof/initiator",  32)   # §4.8 request proofs
k_proof_r = hkdf-expand(prk, "xsp-auth/3/proof/responder",  32)
chan-id   = hkdf-expand(prk, "xsp-auth/3/channel-id",       16)   # §4.8 non-connection locator
```

**Label lineage** — the label generation is the version handle for WHAT THE
TRANSCRIPT COVERS, independent of the `[versions]` protocol field: `/1/` =
the original coverage; `/2/` = the I1 crypto-agility cut (the explicit
signature-suite carriage — #684 row 3, L35/L36); `/3/` = the stream-4
vocabulary-negotiation carriage (§4.4a's offer/confirmed fields). A
transcript from one generation MUST NOT verify against another: the keyed
tags diverge by construction, and message-shape validation rejects a
missing or unexpected `[offers]` loudly (`CXER-XSP-AUTH-STATE`), so
cross-generation replay fails closed on both sides.

- `tag_i = [$crypto:hmac-sha256 k_tag_i bytes-of T]`,
  `tag_r = [$crypto:hmac-sha256 k_tag_r bytes-of T]` (T = §4.4 transcript).
  Tags prove each side actually derived the shared secret (key confirmation) —
  load-bearing for the anonymous initiator, whose *only* proof is possession
  (§4.7). A bad tag is `CXER-XSP-AUTH-CONFIRM`.
- The static DID keys never enter the schedule — they only sign. Compromising
  a static key later never decrypts or forges past sessions (forward secrecy).
- The labels are domain-separated per direction and purpose (HKDF `info`,
  `crypto.md` §2.3); the version number inside the label hard-partitions future
  revisions of the schedule.

### §4.6. Channel binding

The `cb` value in M2 (signed by both sides via the transcript) ties the
XSP-AUTH exchange to the outer channel, so a completed handshake cannot be
lifted onto a different channel:

| Transport (binding per `xsp.md` §4) | `cb` |
|---|---|
| raw TCP/**TLS**, `wss://` | SHA-256 of the responder's end-entity TLS certificate (the `tls-server-end-point` construction) |
| Unix socket / in-process | empty (the OS/process boundary is the channel) |
| **SSE + POST** (the v1 web binding) | empty — there is no single connection to bind; binding is provided *forward* by the §4.8 per-request proofs instead |

The initiator computes `cb` from its own view of the channel and MUST verify
it equals M2's before signing M3; mismatch is `CXER-XSP-AUTH-BINDING`. Where
`cb` is empty the exchange still self-binds (§4.2 — signatures over
ephemerals); `cb` adds the outer-channel tie where one exists. Note TLS here is
**infrastructure, not identity**: the DID signature is the trust anchor
(`did.md` §7 — no CA hierarchy); the certificate hash only pins *this
channel*, and self-signed certificates bind exactly as well as CA-issued ones.

### §4.7. Mutuality & the anonymous case

- **The responder always authenticates.** A XAP endpoint MUST present and
  prove its DID (M2). There is no anonymous responder — an initiator MUST
  abort a handshake whose M2 omits or fails proof (N-IDENT-2).
- **Mutual mode** (both DIDs proven) is REQUIRED across trust-domain
  boundaries: federation peers (§22.6.1), third-party features, any channel on
  which VCs will be presented (§5) or non-observe intents emitted — subject to
  the deployment's attach policy, which MAY require mutual mode everywhere.
- **Anonymous mode**: M1 omits `[initiator]`, M3 omits `[sig]` (the `tag`
  remains — possession of the channel secret is still confirmed). This is the
  TLS server-auth shape: the initiator knows *whom it reached* and traffic is
  bound to the exchange, but the responder knows only "the peer holding this
  channel." The responder's attach policy then either **refuses**
  (`CXER-XSP-AUTH-ANONYMOUS-REFUSED` — the production default) or maps the
  channel to the deployment's **anonymous floor** principal (§1): the §22.1
  dev principal on localhost trust, or a public observe-only principal. Per
  §22.1 there is no anonymous *commit* — the floor principal is a real
  `(principal, tenant)` and the PEP gates it like any other.
- An anonymous channel MUST NOT present VCs (§5 — there is no proven subject
  to bind them to) and MUST NOT be granted non-floor authority.

### §4.8. Post-handshake binding — closing the principal-claim gap

Once XSP-AUTH completes, the channel is bound to exactly one authenticated
peer and one session, and the frame `principal` field is demoted to a checked
label:

1. **Connection transports (TCP/TLS, Unix, in-process, WebSocket).** The
   connection is the session carrier. On every subsequent frame:
   `principal-len 0` ⇒ the frame **inherits the session principal**;
   a non-empty `principal` MUST equal the authenticated DID byte-for-byte —
   anything else is rejected with `CXER-XSP-AUTH-PRINCIPAL-MISMATCH` and the
   frame never reaches the bus. *(This single rule is what makes the XSP
   principal field safe: it can no longer smuggle an identity.)*
2. **Request/response transports (SSE + POST, the v1 web binding).** There is
   no connection to inherit from, so **every client→server request carries a
   possession proof** at the binding layer (HTTP headers beside the frame
   bytes, `xsp.md` §4.1):
   - `XSP-Channel: <hex chan-id>` (§4.5 — locates the server-side keys),
   - `XSP-Counter: <n>` — strictly monotonic per channel, starting at 1,
   - `XSP-Proof: <base64 hmac>` =
     `[$crypto:hmac-sha256 k_proof_i (counter-be8 ‖ sha256(frame-bytes))]`.
   The server verifies proof and monotonicity (replayed or reordered counters
   ⇒ `CXER-XSP-AUTH-PROOF`, §8.1); the SSE downstream is bound by its
   subscription GET carrying the same three headers (proved with `k_proof_i`;
   the stream then serves under that channel). The frame-level principal rule
   of (1) applies identically once the request is bound.
3. **Sessions outlive channels, not the reverse.** A channel binds to exactly
   one session for its lifetime. The session itself survives channel death
   (`session.md` N-SESSION-4 — the tmux invariant); a returning client runs a
   **fresh full handshake** and re-attaches (mirror, §4.9). Channel secrets are
   never resumed across channels in v1 (resumption is deferred with `xsp.md`
   §5 reconnect-resume; when that lands it must derive from `prk` with a new
   HKDF label, never reuse `k_proof_*`).

### §4.9. Session binding & multiplicity — resolving issue #24

The handshake authenticates a **peer**; the `[attach …]` payload (M3) selects
the **session**. This closes #24's four gaps within one XAP:

**1 · Lifecycle & selection.** The M3 `[session …]` selector admits four forms:

| Selector | Semantics |
|---|---|
| `mirror` (default) | resolve-or-mint the subject's **default session** — `session.md` §2.7 verbatim: first attach mints, later attaches add a client. Backward-compatible: a selector-less attach behaves exactly as today. |
| `new [name=…]?` | mint an **independent session** for the same `(principal, tenant)` — its own client set, surface composition, context, foreground, attention tier, and **authority basis** (N-IDENT-4). The optional `name` is unique per `(principal, tenant)`; a collision is a fault. |
| `id=<session-id>` / `name=<name>` | mirror **that specific session**. It MUST belong to the same `(principal, tenant)` — else the `session.md` `CXER4805` rebind refusal applies — **unless** the attacher holds a delegated-mirror grant (below). |

A principal MAY hold **N concurrent sessions** on one XAP, each with any mix
of mirrored clients. `[$session:list $principal $tenant]` and
`[$session:by-name …]` enumerate and resolve them (staged `session.md`
amendment, §10 — alongside the `name` attribute and the attach selector).

**2 · What is shared vs per-session** (#24 item 3, normative):

| Shared (authoritative, per XAP) | Per-session |
|---|---|
| the journal + fold/state (§14/§14.4) | client set (mirrored views) |
| the composed grammar | surface composition, context, foreground |
| tenant partition + local grants *held by the principal* | **compiled authority basis** ((local grants + this session's verified VCs) ∩ envelopes — §5, N-IDENT-4) |
| the one PEP | attention tier (§20.2), working-panel local loops |
| | cookie/CSRF material, channel bindings |

Two sessions of one principal are **views with independent authority**, never
independent facts: both read the same fold, and an intent committed via either
lands in the same journal under the same principal (attributed with its
session id — §22.6).

**3 · Delegated mirror (over-the-shoulder, #24 item 4).** Mirroring **another
principal's** session — admin/support, `xap.md` §16/§21 — is not an identity
exception; it is a §22.2 delegation: the attacher authenticates as *itself*
(its own DID, §4), presents a grant (local delegation or VC, §5) carrying the
`observe-session` capability scoped `[over session:<id>]`, time-bounded and
revocable, and attaches with `id=<that session>`. The journal attributes the
mirror attach to the *observer's* principal; the observed principal's attention
surface reflects it (§20.2). Without the grant: `CXER4805` semantics —
default-deny (N-TRUST-1).

**4 · `session-lost` and attention tiers** evaluate **per session** over that
session's client set (`session.md` §2.7) — multiplicity does not blur the
§22.8 incapacity read-model: each session's predicate folds its own clients.

### §4.10. Errors (symbolic, trust-stack style — matching `CXER-XSP-*`)

| Code | When |
|---|---|
| `CXER-XSP-AUTH-VERSION` | no mutually supported version in M1/M2 |
| `CXER-XSP-AUTH-STATE` | phase out of order, duplicate/malformed message, unknown extra children, frame/payload DID mismatch |
| `CXER-XSP-AUTH-SIG` | a transcript signature fails against the peer's resolved `authentication` key |
| `CXER-XSP-AUTH-CONFIRM` | a key-confirmation tag fails |
| `CXER-XSP-AUTH-BINDING` | channel-binding (`cb`) or dialed-endpoint mismatch |
| `CXER-XSP-AUTH-ANONYMOUS-REFUSED` | anonymous M1/M3 where policy requires mutual |
| `CXER-XSP-AUTH-PRINCIPAL-MISMATCH` | a post-handshake frame carries a principal ≠ the session principal (§4.8) |
| `CXER-XSP-AUTH-STREAM` | non-auth traffic before completion, or foreign frames on the control stream |
| `CXER-XSP-AUTH-PROOF` | a per-request possession proof fails or replays (§4.8) |
| `CXER-XSP-AUTH-SUBJECT` | a presented VC's subject (or chain-terminal subject) ≠ the session principal (§5.1) |
| `CXER-XSP-AUTH-ROTATE` | an in-band rotation fails continuity (§6.3) |

Every failure is fail-closed: the handshake aborts, no session binds, nothing
is staged (§8.6). Failures are `[err …]` values on the failure channel (SAP
§1), carried to the peer as an XSP `error` frame on stream 0 where the channel
still permits.

### §4.11. Surface (sketch — full signatures at P0, §10)

The handshake calculus lives in **`cx-stdlib/xsp`** (the module that owns the
frame): `[$xsp:auth-hello]`, `[$xsp:auth-challenge]`, `[$xsp:auth-prove]`,
`[$xsp:auth-confirm]`, `[$xsp:auth-finish]`, `[$xsp:auth-transcript]`,
`[$xsp:auth-verify]`, `[$xsp:auth-keys]` — **pure** given their inputs (nonces,
ephemeral keypairs, and clocks are passed in; generation via
`[$crypto:x25519-keypair]` / `[$random:crypto-bytes]` stays at the impure
caller), exactly the purity split `did.md` §6 uses. Session integration is
**`[$session:attach-xsp]`** — the third attach transport beside Bearer and
cookie (`session.md` §1), generalizing the realized `attach-did`
(`did.md` §7): the transcript is the challenge, the M3 signature the proof,
and the §4.9 selector rides the attach cfg.

Fixtures: §9.8–§9.16.

### §4.12. The deployment-host binding — `[host-auth]` at `[$xap:host]` (P2 closure)

`[$xap:host]` (the distribution spec's §6.3 deployment host) serves
`POST /intent` + `GET /stream` for every hosted XAP. Pre-P2 it resolves the
committing actor from the intent's **claimed** `author=`/`role=` attributes (or
the `resolve-actor` adapter hook) — the §4.1 claim-not-authentication shape at
the host's HTTP surface. This section closes it by wiring §4 (attach) and §4.8
rule 2 (per-request proofs) into the host, keyed off one block of deployment
**data**.

**The `[host-auth]` block** (in the `*.xap.cxd` deployment document):

```cx
[host-auth
  [identity did="did:key:z6Mk…" seed-env="CX_XAP_HOST_SEED"]
  [policy mode="mutual"]                 # or mode="floor" floor="dev" role="guest"
  [principals
    [principal did="did:key:z6Mk…" role="operator"]]
  [public [route "/"] [route "/static/"]]]
```

The block is named `[host-auth]`, **not** `[auth]`: a deployment may already
carry an `[auth]` element for its own login/credential configuration (the
reference-instance deployment does — username/password-case, KDF), a distinct concern
from this channel handshake. Squatting on `[auth]` would silently break the
absent-⇒-today's-behavior invariant for every such deployment (it did, at
first — the reference-instance live-boot caught it). `[host-auth]` names what it is: the
host's channel-authentication policy.

- **Absent ⇒ today's behavior, byte-for-byte** — the `xap.md` §22.1 localhost
  dev-floor: no handshake, no proof headers, actor from the claimed
  `author=`/`role=` (or the adapter hook). This is the N-IMPL-1 one-seam
  promise: floor→production is *adding this block to the deployment document*
  and nothing else. (An `[auth]` login-config element, if the deployment has
  one, is untouched — the two never interact.)
- **`[identity]`** — the host's responder DID (N-IDENT-2: there is no
  anonymous responder) and the name of the environment variable holding its
  hex-encoded 32-byte Ed25519 seed. The DID must be offline-resolvable
  (`did:key` / `did:peer:0`) in v1. Boot is fail-closed: a missing variable, a
  malformed seed, or a seed whose public key does not re-derive `did=` refuses
  to boot — never a latent runtime denial.
- **`[policy]`** — `mode="mutual"` (the default when the row is absent):
  an anonymous M1 is refused with `CXER-XSP-AUTH-ANONYMOUS-REFUSED` (§4.7).
  `mode="floor"`: an anonymous peer attaches as the fixed principal
  `floor:<floor>` holding `role=`'s grants. The `floor:` prefix is constructed
  by the host — a bare name is never used, so the floor principal can never
  collide with the PEP's inherent-authority `principal:` kind.
- **`[principals]`** — the deployment's DID→role authority map, compiled at
  boot exactly like the `[roles]` ladder: every `[governance]` grant that
  reaches `role=` is also dialed to the DID itself (the actor id **is** the
  DID). An authenticated DID with no row attaches (the session is real) but
  holds no dials — every intent is PEP-denied (N-TRUST-1 default-deny).
- **`[public]`** — routes served without a channel (the client-app shell and
  its static assets, so a browser can bootstrap). A `route` value ending in
  `/` is a prefix. `POST /attach` is always open (it *is* the handshake);
  everything else requires an established channel and a valid proof.

**Attach flow (XSP-AUTH over SSE + POST).** The host is the responder; the
M1–M4 payloads ride `POST /attach` bodies as **XSP v1 stream-0 frames**
(`xsp.md` §4.1: frame bytes, base64-encoded for the text-only path — the same
codec the host's `envelope=xsp` intent path already speaks), so the data-bin
losslessness the transcript signatures depend on holds across the wire
(canonical *text* is not byte-stable for the bytes-valued handshake fields):

1. `POST /attach`, body = frame(M1) → `200`, body = frame(M2). The host generates its
   nonce/ephemeral, signs with the `[identity]` seed, derives the §4.5
   schedule, and pends the handshake **keyed by `chan-id`** (§4.5 — the
   non-connection locator). Pending entries are few (bounded) and expire
   (~60 s); eviction is silent — the client simply re-runs the handshake.
2. `POST /attach`, header `XSP-Channel: <hex chan-id>`, body = frame(M3) → the host
   runs `[$session:attach-xsp]` (M1, M2, M3, cfg with its `eph-priv`,
   `require-mutual`/`anonymous-floor` per `[policy]`, and the deployment
   tenant) → `200`, body = frame(M4) with the established `[session …]` spliced
   (§4.11). The channel moves to the established table:
   `chan-id → (k_proof_i, counter high-water = 0, session principal, actor)`.
   The client verifies M4 with `[$xsp:auth-finish]`.
3. A verify failure is the exact `CXER-XSP-AUTH-*` err value, verbatim, as an
   `application/cx` body with HTTP status 403 (anonymous-refused, sig, confirm)
   — fail-closed, nothing pends, nothing binds (§8.6).

**Per-request enforcement (§4.8 rule 2).** Every non-`[public]` request on an
auth-enabled host carries the three headers; the host verifies
`XSP-Proof = HMAC-SHA256(k_proof_i, counter-be8 ‖ sha256(raw-request-body))`
(a `GET` proves the empty body) and strict counter monotonicity —
verify-and-advance is atomic per channel. A missing header, unknown channel,
bad proof, or replayed/reordered counter is HTTP 401 carrying
`[err [code :CXER-XSP-AUTH-PROOF]]`. The SSE subscription `GET /stream`
carries the same three headers; its proof binds the downstream to the channel
(§4.8 rule 2), and the stream then serves under that channel.

**The proven actor.** On an admitted `POST /intent`, the committing actor is
the channel's **session principal** — the §4.8 frame rule applied at the host:
an empty/absent `author=` inherits the session principal; a non-empty
`author=` MUST equal it byte-for-byte, else the intent is rejected with
`CXER-XSP-AUTH-PRINCIPAL-MISMATCH` (HTTP 403) and never reaches the bus. When
the deployment's envelope is `xsp`, the decoded frame's `principal` field is
checked by the same rule first (§4.8 rule 1, applied verbatim).
`role=` is ignored (authority is the DID's compiled dials), and the
`resolve-actor` adapter hook is **not consulted** — a proven principal is
never overridden by an adapter's claim. The journal therefore attributes every
act to the authenticated DID (or the `floor:` principal), at per-DID
granularity.

**The initiator side.** A CX-native client (the reference-instance web client is one:
a CX process serving the htmx browser UI and relaying its intents) runs the §4.11
calculus directly — `auth-hello`/`auth-prove`/`auth-finish` + `auth-proof` per
request — and sets the three headers on every relayed request. The
browser↔web-client hop stays on the web client's own session discipline; the
web-client↔host hop is the authenticated channel.

Host-level lanes live beside `vcx/tests/xap_host_real_test.v` (auth-off
bit-identical regression; auth-on attach/admit/deny/replay) — network-real, so
they are V test lanes, not conformance fixtures; the pure calculus they
compose is already fixture-gated (§9.8–§9.16).

---

## §5. VC presentation → attenuation → capability compilation

Authority reaches an authenticated session as VCs; this section defines the
**only** path from a credential to an enforceable capability.

### §5.1. Presentation

- A presentation is a `[vp …]` (`vc.md` §3 `present`) carried on the control
  stream — `[xsp-auth phase=present [vp …]]` — or supplied in the M3 `[attach]`
  payload. Presentations MAY occur any time while the session lives (late
  grants extend a session without re-attach).
- **The handshake is the proof of possession.** A presented VC's subject —
  or, for a chained credential, the chain's terminal subject — MUST be the
  **session principal** (byte-equal DID). Because the session principal proved
  key control at §4, no separate holder-binding challenge is needed; a VC whose
  subject is any other DID is rejected (`CXER-XSP-AUTH-SUBJECT`). There are
  **no bearer credentials** in this model.
- Anonymous sessions cannot present (§4.7).

### §5.2. Verification & attenuation (by reference, with the chain rule)

Each VC verifies per `vc.md` §4/§6: signature over canonical form against the
issuer's resolved key, validity window, non-revocation against the local
`revoked-set` fold (`vc.md` §5). For a **chain** (VC_1 … VC_n, each
`attenuates` its parent):

1. every link verifies independently;
2. link *k*'s issuer is link *k−1*'s subject (the delegation walks);
3. **attenuation is strict**: link *k*'s `capabilities`/`over`/window ⊆ link
   *k−1*'s (§22.2 — a holder cannot widen);
4. the root issuer's authority is a **local** fact of the consuming XAP: the
   root delegation must trace to a principal *this deployment* recognizes as
   holding those capabilities (N-TRUST-1 — a foreign chain cannot conjure
   authority the deployment never granted its root).

### §5.3. Compilation into the session's authority basis

For each **verified** delegation, per capability:

- resolve the capability name against the deployment's **composed grammar**
  (its declared intent vocabulary — the distribution spec's `needs`/grammar
  plane): a resolvable capability compiles to an authority-basis record on
  **this session** (N-IDENT-4), carrying provenance `(vc-id, issuer,
  chain-depth)`; an unresolvable name compiles to **nothing** — inert, logged,
  never an error that voids the rest of the credential (a VC spanning several
  XAPs compiles partially in each, which is attenuation-safe: an inert name
  grants nothing).
- the session's **effective authority** is then exactly `xap.md` §22.10:
  `effective = individual ∩ ⋂envelopes`, where **individual** is the
  deployment's local grants for the principal **plus** the compiled-VC
  records — a verified delegation enters the authority basis as an ordinary
  grant (`vc.md` §6) and is clamped by every envelope like any other; a VC
  can never confer authority an envelope forbids. Every record stays subject
  to conditions/context and the tenant partition (`delegation.tenant` MUST
  equal the session tenant — else the record is rejected, not inert: a
  cross-tenant grant is a fault, `CXER4805` semantics).

### §5.4. Enforcement timing (the PEP is unchanged — R9)

The one PEP (§22.3) checks every intent against the session's authority basis.
Two different **times** matter (N-IDENT-3):

| Check | When | Consequence |
|---|---|---|
| signature validity | **at presentation** — a fact about bytes and the key that was authoritative then; recorded with the compiled record | later issuer rotation does NOT retro-invalidate an already-compiled record (§6.3 prices this: rotation is forward-only) |
| validity window (`expires`) | **at every PEP check** (time-of-use) | a VC expiring mid-session stops authorizing *new* intents at that instant; committed history stands |
| revocation | **at every PEP check**, against the current `revoked-set` fold | revocation lands mid-session without re-attach; propagation across runtimes is `vc.md` §5 (3b) / D5 — the enforcement read is local either way |

`why-allowed` (`xap.md` §3.7) over a VC-compiled record answers with the full
chain provenance — the audit story is the same one delegation already has.

### §5.5. Signing tiers

A VC **is** the T1 "principal-signed" carrier of `xap.md` §22.9 in DID form.
Where policy demands **T2 (M-of-N co-signature)** — guardian grants over
irreversible capabilities — the artifact is N VCs over the **same** `[claim]`
from distinct required issuers; the PEP's tier check counts verified
co-signers before arming (§22.9 unchanged; no new envelope format).

Fixtures: §9.17–§9.21.

---

## §6. Lifecycle — issuance, rotation, revocation, recovery

### §6.1. Issuance

- **`did:key` / `did:peer:0`**: `[$crypto:ed25519-keypair]` →
  `[$did:key-create]`. Instant, offline, free — mint one per task/agent
  (§1). No publication step exists or is needed.
- **`did:web`**: generate, author the §2 document, publish at the `did.md` §5
  URL over the operator's own HTTPS host. The publisher's key custody is the
  #98 client concern (platform secure store) — §8.9.
- **Sessions** (#24): minted at attach per §4.9; named/listed/selected via the
  staged `session.md` surface; detached per `session.md` §3.2 (whole session)
  or `detach-client` (one view).

### §6.2. Delegation issuance

Local grants: the dial (`xap.md` §3.7/§21.4) — unchanged. Portable grants: the
principal issues a VC (`vc.md` §3 `issue`) whose claim is the §22.2
`[delegation …]`, subject = the grantee DID. Agent pools sub-delegate by
issuing chained VCs, each strictly attenuating (§22.2, §5.2) — the delegation
chain *is* the org chart of authority, offline-verifiable per link.

### §6.3. `did:web` key rotation — including live-session semantics

**Routine rotation** (the charter's mid-session case):

1. Publish the §2.4 overlap document (new key first, old key retained).
2. During overlap, verifiers accept either key (§4.4); **new** handshakes and
   **new** VC issuance SHOULD use the new key immediately.
3. **Live sessions continue** — a session is bound to the proof made at attach
   time (N-IDENT-3), not to the document's current state; rotation never drops
   established sessions. Two bounds keep this honest: the deployment's
   **max-session-age** (attach policy; forces a periodic fresh proof) and the
   optional **in-band re-proof**: `[xsp-auth phase=rotate]` on the control
   stream — a fresh M1–M4 exchange over the live channel, its transcript
   additionally carrying the prior channel's `chan-id`, **dual-signed** by old
   and new keys (continuity: the new key's holder provably holds the old).
   Streams and the session survive; the journal records the rotation event with
   both key ids. A rotate that cannot dual-sign fails (`CXER-XSP-AUTH-ROTATE`)
   and the old binding stands until re-attach.
4. **Delegation survival:** VCs signed by the outgoing key keep verifying
   while it remains in the document (§5.4 — and records already compiled stay
   compiled). Before the overlap closes, the issuer re-issues still-needed VCs
   under the new key (the distribution spec's subscription-reissuance pattern,
   §5.1 there, applied to identity). After overlap, old-key VCs fail *new*
   verifications — the honest ledger-free consequence; the mitigation is
   short-lived credentials + re-issuance cadence, never a revocation ledger.
5. `did:key` does not rotate (`did.md` §2) — an ephemeral identity is retired,
   not rotated; persistent identity is what `did:web` is for.

### §6.4. Compromise recovery

- Replace the document **immediately** with a new-key-only document (no
  overlap — overlap is for *routine* rotation; a compromised key must die).
- Issue **revocation** events for every VC issued under the compromised key's
  window (`vc.md` §5 — journaled events, folded into `revoked-set`s).
- Live sessions authenticated under the compromised key are terminated by the
  operator **on their own runtime** (detach); *peer* runtimes converge via
  resolver TTL expiry + max-session-age — there is **no remote reach-in**, by
  the same principle as the distribution spec's N-DIST-1. The window between
  compromise and convergence is priced by the TTL and session-age knobs
  (§8.7).
- Journaled history under the compromised key **stands, flagged** — N-IDENT-3:
  attribution is point-in-time; the compromise announcement (an attestation,
  §7) tells auditors *which* window to distrust, without rewriting the chain.

### §6.5. Deactivation

`did:web`: remove/tombstone the document (`did.md` lifecycle) — resolution
fails, new handshakes and new VC verifications fail, live sessions drain under
max-session-age. `did:key`/`did:peer`: cease use; anything durable the DID
signed remains verifiable against the identifier itself (self-describing),
which is exactly right for provenance (§7).

Fixtures: §9.17, §9.19–§9.21.

---

## §7. Provenance binding

Identity binds to **artifacts** the same way everywhere — a detached Ed25519
signature by a DID's `assertion-method` key over a **content address**:

```cx
[provenance
  [subject  hash="<tier-1-hash>"]          # the store object attested
  [signer   "did:web:pub.example.com"]
  [claim    published]                     # published | reviewed | approved | compromised-window | …
  [at       2026-07-12T00:00:00Z]
  [sig      "z<base58btcbytes>"]]          # over canonical render of provenance-sans-sig
```

- **Packages** — the distribution spec §3 *is* this shape's packaging
  instance (`pkg-sign` signs the Tier-1 hash; attestations are VCs about a
  hash). This section generalizes, it does not duplicate: one provenance
  grammar for packages, journal snapshots (`xap.md` §14.4 anchors), published
  documents, and compromise-window announcements (§6.4).
- **Tier-1 only.** Trust decisions bind the exact artifact (Tier-1 hash);
  Tier-2 code identity (`code-identity.md`) remains a semantic-equivalence
  tool and is **never** a trust input — the distribution spec's rule, restated
  as the general one.
- **Runtime events need no per-event signatures.** The journal is
  hash-chained and every event carries `:actor`/`:authority` (§22.6);
  authorship binding follows the §22.9 tiers — T0 session-attributed (now
  *actually* authenticated, §4 — the tier's floor rises for free), T1 for
  delegations/guardian grants (the VC form, §5.5), T2 co-signed. Signing every
  event would tax every click for nothing the chain + authenticated session
  don't already give (§22.9's explicit design point).

Fixtures: §9.21.

---

## §8. Security considerations

1. **Replay.** Handshake: fresh nonces + ephemerals inside every signature —
   a replayed M2/M3 fails against the live exchange's values. SSE+POST: the
   strictly-monotonic signed counter (§4.8); the server tracks the high-water
   mark per `chan-id` (no window — reordering at the binding layer is a fault,
   HTTP delivers requests whole).
2. **MITM / relay.** The AKE is self-binding (§4.2): pure relays learn nothing
   and substitution breaks signatures. `cb` (§4.6) additionally pins the outer
   TLS channel where one exists.
3. **Downgrade.** Version offer + selection are signed (§4.4), and — from
   the `/3/` label generation — so are the profile/feature offer sets, with
   the selection computed as their intersection and re-verified against
   M4's confirmed set (§4.4a): stripping a `store-feed`/`store-delta`-class
   token breaks a signature or the M4 check, never silently narrows the
   vocabulary. Unknown extra message children are rejected (§4.3) —
   parameter sneaking has no unsigned channel to ride.
4. **Unknown-key-share / identity misbinding.** Both DIDs, both role labels,
   and the dialed endpoint are inside both signatures — a responder reached
   through a hostile redirect sees an endpoint it does not serve and aborts
   (`CXER-XSP-AUTH-BINDING`).
5. **Reflection.** Role labels in the signed wrapper (§4.4): initiator and
   responder signatures are domain-separated by construction.
6. **Pre-auth DoS.** M1 costs the responder one X25519 op + one signature
   before any initiator proof exists. Mitigations are deployment policy:
   pre-auth rate limits per source, handshake timeouts, and (deferred) a
   stateless-retry cookie for TCP-class transports. Fail-closed aborts keep no
   per-attempt state (§4.10).
7. **Resolver trust (`did:web`).** DNS + TLS anchor `did:web` (`did.md` §5) —
   an attacker owning both the domain and its certificate *is* that identity's
   controller as far as ledger-free resolution can know. The honor-list
   (`trust-domains`), short TTLs, and short-lived VCs bound the blast radius;
   `did:key`/`did:peer` peers are immune (nothing to poison). This is the
   ledger-free trade, stated plainly — the mitigation budget (TTL ×
   max-session-age × VC lifetime) is the deployment's compromise-convergence
   bound (§6.4).
8. **Entropy & constant-time.** Nonces/ephemerals MUST come from
   `[$random:crypto-bytes]`; signature and MAC verification use `crypto.md`'s
   primitives (constant-time comparison is that module's contract, not
   re-implemented here).
9. **Key custody.** Private keys never appear in any message, journal, or
   store object of this spec. Custody (secure enclave / platform keystore,
   agent key provisioning) is the #98 client-platform concern; this spec's
   only demand is that signing happen *where the key lives*.
10. **Confidentiality.** XSP-AUTH authenticates and binds; it does not
    encrypt. Transport confidentiality remains TLS's job (`session.md`'s
    TLS-required posture carries over: production attach policy MUST require a
    confidential transport for non-localhost channels). Payload-level
    encryption via static `key-agreement` keys is reserved (§2.2), deferred.
11. **Clock skew.** VC windows (§5.4) and provenance timestamps compare
    against the verifier's clock; deployments SHOULD allow bounded skew
    (policy, default ≤ 5 min) and MUST NOT let skew tolerance exceed the
    shortest credential lifetime they issue. The handshake itself needs no
    clock (nonces give freshness) — the offline/disconnected path stays clock-free.
12. **Anonymous floor.** The §4.7 floor principal is a real principal; its
    grants define the entire anonymous attack surface. Deployments MUST keep
    the floor observe-only outside localhost dev trust (§22.1).

---

## §9. Conformance fixture plan (fixture-first — authored before P0 code)

Fixture home: `conformance/stdlib/xsp-auth.cxd` (pure calculus + compilation),
engine tests beside the transport code for live-channel lanes (the
`module_pkg_loader_test.v` precedent). Every lane asserts **values**, not
prose — the failure lanes name their exact `CXER-…` code.

**§1 — principals & methods**
1. Method-per-role: a `did:key` and a `did:web` principal each complete §4 and
   bind sessions; a `did:peer:0` string round-trips parse/resolve offline
   (staged until the `did.md` amendment; asserts the numalgo-0 profile).
2. Anonymous floor: an anonymous attach under a floor policy binds the floor
   `(principal, tenant)`; the PEP still gates it; under `require-mutual` the
   same M1 yields `CXER-XSP-AUTH-ANONYMOUS-REFUSED`.

**§2 — document profile**
3. A `did:web` document missing an Ed25519 `authentication` method fails
   profile validation; the synthesized `did:key` document passes by
   construction.
4. `XAPStreamEndpoint` discovery: resolve → service entries → binding
   selection order honored; a document with no service entry yields
   "not reachable" (absence, not a fault).
5. Rotation-overlap document: both keys listed; §4 verification succeeds
   against either; order (new-first) is preserved by the resolver.

**§3 — resolution & discovery**
6. Offline mutual: two `did:key` peers complete the full §4 handshake with the
   net capability withheld (zero network, the disconnected lane).
7. `trust-domains`: a responder resolving an initiator `did:web` outside its
   honor-list refuses the handshake fail-closed.

**§4 — XSP-AUTH** (the load-bearing set)
8. Happy mutual: M1–M4 over recorded frames; both sides derive equal keys;
   tags verify; the session binds to the initiator DID.
9. Signature lanes: tampered nonce / swapped ephemeral / wrong key / role
   label swapped (reflection) each → `CXER-XSP-AUTH-SIG`, nothing attaches.
10. Replay lanes: a replayed M2 against a fresh M1 → `CXER-XSP-AUTH-SIG`
    (nonce mismatch inside the signature); a replayed SSE+POST request
    (counter reuse) → `CXER-XSP-AUTH-PROOF`.
11. Downgrade: an M2 selecting a version not offered, or a message with
    injected extra children → `CXER-XSP-AUTH-STATE`/`-VERSION`.
12. Channel binding: mismatched `cb` → `CXER-XSP-AUTH-BINDING`; mismatched
    dialed endpoint (unknown-key-share lane) → same code; empty-`cb`
    transports still complete.
13. **Principal-claim closure (the #116 gap, asserted):** on an authenticated
    channel, a frame claiming a *different* DID →
    `CXER-XSP-AUTH-PRINCIPAL-MISMATCH`, never reaches the bus; a
    `principal-len 0` frame inherits the session principal and commits
    attributed to it.
14. Control stream: a non-auth frame before M4 → `CXER-XSP-AUTH-STREAM`;
    `ping`/`pong` are exempt.
15. Key confirmation: a corrupted `tag_i`/`tag_r` → `CXER-XSP-AUTH-CONFIRM`
    (covers the anonymous-initiator possession lane).
16. **Session multiplicity (#24):** `mirror` reproduces `session.md` §2.7
    byte-for-byte (regression lane); `new name=…` mints an independent session
    — both listed by `list`, distinct authority bases (N-IDENT-4 asserted by
    granting a VC on one and PEP-denying the same intent on the other);
    `id=` mirror onto a foreign principal's session without a grant →
    `CXER4805`; with a scoped `observe-session` delegation it attaches and the
    journal attributes the observer.

**§5 — presentation & compilation**
17. Subject binding: a VC whose subject ≠ session principal →
    `CXER-XSP-AUTH-SUBJECT`; a chain terminating at the principal compiles.
18. Attenuation: a chain link widening `capabilities` or `over` is rejected at
    verification (the §22.2 lane, run over the wire path).
19. Time-of-use: a VC expiring mid-session authorizes an intent before expiry
    and PEP-denies after, no re-attach; a `revoke` event folded mid-session
    denies from the next intent on.
20. Partial compilation: a VC naming one resolvable and one unknown capability
    compiles the first, logs the second inert, rejects nothing; a
    cross-tenant delegation is rejected outright.
21. Tier lane: a guardian-grant VC verifies T1; a T2 (2-of-2) armed only when
    both co-signing VCs verify; provenance: a `[provenance]` attestation
    round-trips sign→verify and a tampered subject hash fails.

**cross-cutting**
22. **§0-absence checks** (the distribution-spec §11.8 pattern): asserts the
    implementation calls `crypto`/`did`/`vc`/`session`/PEP surfaces and
    introduces no parallel primitive (grep/assert gate in `make`, like
    `check_xap_dist_absences.py`).
23. Rotation: §6.3 end-to-end — overlap doc, dual-signed in-band rotate,
    session + streams survive, journal records both key ids; a rotate unable
    to dual-sign → `CXER-XSP-AUTH-ROTATE`; post-overlap old-key VC fails a
    *new* verification while an already-compiled record stands (N-IDENT-3).
24. Compromise: new-key-only doc + revocation events; local sessions
    terminated; a peer's next handshake against the cached old doc fails after
    TTL expiry (convergence lane, clock injected).

---

## §10. Staged implementation (design complete; build order)

| Phase | Ships | Depends on | Status |
|---|---|---|---|
| **P0 — handshake calculus** | `$xsp:auth-*` pure surface (§4.11): message build/parse, transcript, signatures, key schedule, verification; fixtures §9.8–§9.15 as pure lanes (recorded frames, injected randomness) | `crypto`/`did`/`xsp` (all shipped) | **✅ shipped** — `vcx/code/stdlib_xsp_auth.v`, `stdlib/xsp.cx` (`auth-hello/challenge/prove/confirm/finish/transcript/keys/verify`); `conformance/stdlib/xsp-auth.cxd` 001–024 (021–024 added with P4) |
| **P1 — session integration + connection transports** | `[$session:attach-xsp]` (third attach transport), stream-0 discipline, §4.8 rule 1 enforcement at the frame reader, anonymous-floor policy knob; fixtures §9.2, §9.13–§9.14, §9.16 mirror-regression lane | P0; `session` (shipped); TCP/TLS binding (`xsp.md` §4 — buildable now) | **✅ shipped** — `session:attach-xsp` + `xsp:auth-frame-check` (§4.8 rule 1); `conformance/stdlib/session.cxd` 045–049 |
| **P2 — web binding proofs** | §4.8 rule 2 (`XSP-Channel`/`-Counter`/`-Proof` headers) on the SSE+POST binding; web-client attach flow | P1; `xsp.md` §4.1 (shipped) | **✅ shipped** — calculus (`xsp:auth-proof`/`auth-proof-verify`, fixtures §9.15–§9.16) + the `[$xap:host]` binding per §4.12 (issue #394): `[host-auth]` deployment block, `POST /attach` M1–M4 → `session:attach-xsp`, per-request proof verification incl. the SSE subscription GET, proven actor; web-client attach + header emission in the reference-instance web client |
| **P3 — presentation & compilation** | §5 end-to-end at the PEP: presentation on the control stream, chain verification, per-session authority records, time-of-use checks, `why-allowed` provenance | P1; `vc`/`authz` (shipped) | **✅ shipped** — `session:present-vc` (subject-binding + verify + tenant guard → delegation for the unchanged PEP); `conformance/stdlib/session.cxd` 050–054. §5.2 VC *chain* verification (link walk, strict attenuation) is **spec-staged, not yet implemented** — `present-vc` handles a single VC |
| **P4 — lifecycle & multiplicity surface** | §4.9/#24 `session.md` amendments (`name`, selector, `list`/`by-name`, delegated mirror), §6.3 in-band rotate, §6.4 compromise flow, `did:peer:0` (`did.md` amendment), `XAPStreamEndpoint` in `did.md` §4 | P1–P3 | **✅ shipped** — #24 multiplicity (selector + `list`/`by-name`, lanes 048/055/056); `did:peer-create` + generalized offline resolution; `xsp:auth-rotate`/`auth-rotate-verify` (§6.3, lanes 022/023); §6.4 = operator procedure over `vc:revoke` + document replacement (no new primitive). **Spec-staged, not yet implemented** (the same staging `did:peer` had): delegated mirror (`observe-session`, §4.9), `XAPStreamEndpoint` discovery (§2.3), `max-session-age` (§6.3) |

Every phase ships whole (no stubs — the standing global rule): P0+P1 alone
close the #116 load-bearing gap (a proven principal on every authenticated
channel), and are **shipped and conformance-gated**; P3+P4 shipped likewise.
P2 is fully shipped (host-auth #394, closed 2026-07-14), matching its
phase-table row: host-side `[host-auth]` verification lives in this repo
(`vcx/code/stdlib_xap_host_auth_notd_wasm32_emcc.v`,
`vcx/tests/xap_host_auth_test.v`); initiator header emission lives in the
web-client repo (`serve.cx` `$xa:open`). The `session.md` /
`did.md` / `xsp.md` amendments listed below are prepared by these
implementations and formalized into those specs at G3.

**Graduation (owner G3, executed 2026-07-18):** this document moved to
`spec/03-approved/xap/`; `xap.md` gains N-IDENT-1…4 (§26) and lexicon entries
(**proof of control**, **XSP-AUTH**, **channel binding**, **anonymous floor**,
**session selector**, **delegated mirror**, **provenance attestation**);
`session.md` gains the attach selector + multiplicity surface (closing #24),
adds `attach-xsp` as an attach transport — rewriting §1's "two attach
transports" closed set, which must also catalog the already-shipped
`attach-did` — adds the `present-vc` compilation surface (§5), and qualifies
§2.2's "established by a verified IdP token" framing to cover the DID paths;
`did.md` gains `XAPStreamEndpoint` (§4) and `did:peer:0` (§2) — the latter
also touching §2's method table and §8's `CXER-DID-METHOD-UNSUPPORTED` row
("method is not `key` or `web` (v1)"), since the implementation already
accepts `did:peer:0`; `xsp.md` gains a cross-reference from §2's principal
bullet (verification/authorization are handshake/PEP concerns) and §6 to the
graduated identity spec. Issues #116 and #24 closed with the graduation
merge.

---

**References:** [`xap.md`](./xap.md) (§22 trust model,
N-TRUST-1, §22.6.1 federation, §22.9 tiers, §22.10 composition) ·
[`xsp.md`](./xsp.md) (the frame, bindings, principal field) ·
[`did.md`](../std-lib/did.md) / [`vc.md`](../std-lib/vc.md)
(identity, credentials — R9) · [`session.md`](../std-lib/session.md)
(attach, mirrored sessions) · [`crypto.md`](../std-lib/crypto.md)
(Ed25519, X25519, HKDF, HMAC) ·
[`xap_feature_distribution_market.md`](./xap_feature_distribution_market.md)
(publisher signing, attestations, N-DIST-1/2) ·
[`code-identity.md`](../core/code-identity.md) (Tier-2, never a
trust input) · issues #116 (charter), #24 (session multiplicity), #31 (XSP),
#26 (did/vc), #98 (clients/key custody), #99 (publisher identity).
