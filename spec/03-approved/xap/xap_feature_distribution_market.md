# XAP — Feature Distribution & Market

```cx
[module-meta name=xap_dist tier=D status=current]
```

**Status:** Current (owner G3 2026-07-12, #363 item 6(a) — graduated from
`02-working`; authored 2026-07-04). Full design, no "TBD" seams; implementation is
staged (§10) and the P0+ surface (`$xap:pkg-tree/seal/sign/publish/install/verify`)
ships and is exercised by the reference-instance and xap-store-console registry flows and
their stage-1 invariant gates. Companion to
[`xap_grammar_composition.md`](../xap/xap_grammar_composition.md) (the compose
gate every install runs), [`xap_authoring_process.md`](../xap/xap_authoring_process.md)
(the three spec layers a package carries), and the approved
[`xap.md`](xap.md) (trust model, federation, the marketplace ruling)
and [`std-lib/store.md`](../std-lib/store.md) /
[`core/code-identity.md`](../core/code-identity.md) (the substrate this
rides on).

**Purpose.** Define how a **feature** — the XAP composition unit — is packaged,
identified, signed, distributed, discovered, licensed, installed, updated, and retired,
such that a third-party feature is first-class (`xap.md`: "third-party features are
first-class but must prove identity + authority by DID/VC") and installing one is
*seamless*: it either composes cleanly into the target XAP's single grammar or is
rejected at install time with exact conflict values — never at runtime by surprise.

**One-sentence model.**

> A feature package is a **content-addressed subtree object** in a CX store, **signed
> by a publisher DID**; a **market is itself a XAP** whose features are catalog,
> entitlement, and distribution; a **license is a VC** (an attenuating delegation);
> and **installing = fetch by hash → verify → compose-gate → enable** — the same
> compose gate as load-time and summon-time.

Everything below is existing machinery pointed at distribution: the store's subtree
model and aliases, Tier-1/Tier-2 identity, DID/VC, the §22.2 capability model, and the
composition W-gate. **This spec introduces no new trust primitive and no new store
primitive** — that is a checkable claim (§11 fixtures assert each mechanism against
its owning spec).

---

## §1. The unit — what a feature package is

A **feature package** seals the feature's authoring-process directory as one artifact:

```
<feature>/
  package.cxd            ⊢ package.cxs     # manifest (this spec, §2)
  <feature>.feature.cxd  ⊢ feature.cxs     # requirements → grammar (+ frames/keys/governance/source)
  <feature>.cx                             # implementation (CX; the in-feature language)
  <feature>.test.cxd                       # acceptance fixtures (requirements are the tests)
  assets/…                                 # optional static assets
```

- **Form:** a **subtree object** (`store.md` §7) in a CX store — the git-style
  tree-of-blobs the store already defines. No archive format is invented; a package
  *is* a stored subtree.
- **Archetypes distribute as ordinary feature packages.** An archetype — an
  immutable base feature a third-party catalog sells, instantiated per tenant
  under the refinement contract — introduces NOTHING here: it travels as a
  sealed feature package whose Tier-1 hash is exactly the `of=` pin an
  instance binding names. Instantiation semantics, the refinement contract
  (rename/add/tighten/select; repurpose and loosen refuse), and the re-bless
  discipline are the grammar-composition spec's §4.3 (#866).
- **Identity (two-tier, exactly the store/code-identity model):**
  - **Tier-1** — the subtree root hash: the *exact artifact*. Installs pin Tier-1.
  - **Tier-2** — code identity (`code-identity.md`) of the defs inside `<feature>.cx`:
    semantic identity that survives reformatting; used for dedup and equivalence
    queries, never for trust decisions.
- **Version:** a store **alias** (`store.md` §6.2) `<feature>@<semver> → tier-1-hash`.
  A version is a *name for a hash*; the hash is the truth. Re-pointing a released
  version alias is forbidden by market policy (§5) — a new artifact is a new version.
- **A composite feature packages like a base feature** (composition is closed under
  feature); its manifest declares its `uses` set as dependencies (§2).

### §1.1. Package kinds — not everything is a feature

The sealing/identity/signing/distribution machinery above is **content-agnostic**: it
seals a directory. The **kind** of what's inside determines only which *gate* runs at
install:

| `kind` | Unit | Contains | Install gate |
|---|---|---|---|
| **feature** | the XAP composition unit | the layers of §1: spec (grammar), impl, fixtures, assets | verify (§3) + **compose-gate W1–W6** + `needs` consent |
| **library** | plain CX code — modules/defs with **no grammar and no governance surface** (a wire-protocol codec, a spreadsheet writer, geodesy math) | modules + fixtures + docs | verify (§3) + **module-surface check** (exported defs present, Tier-2 identities as declared) |
| **client** | a medium materializer app (a separate project by N-CLIENT-2) | `client.cxd ⊢ client.cxs` + renderer impl | verify (§3) + client-spec validation |

One substrate, per-kind gates — a library never meets the compose gate (nothing to
compose), a feature never skips it.

**Two dependency planes, never blurred:**

- **grammar plane** — feature `uses` feature (composition; W-gate territory; changes
  what a principal can *say*).
- **code plane** — any package `requires` a **library** package (implementation;
  hash-pinned, resolved at load/build; changes what the code *calls*). Features
  require libraries (a gateway adapter requires its wire-protocol codec);
  libraries require libraries; **a library never `uses` a feature** (code does not
  depend on grammar).

> **N-DIST-2 (libraries carry no authority).** Grants attach to features and
> principals at the PEP — never to library code. A feature's `needs` block covers its
> **entire code closure**: library code executes under the requiring feature's
> authority, and a dependency can neither hold nor request capabilities of its own.
> Authority cannot be smuggled through the code plane.

Tier-2 code identity earns its keep on the code plane: two library releases whose defs
normalize identically are semantically the same code (dedup, equivalence queries,
"did this update actually change anything I call?"), while trust stays strictly Tier-1
+ signature.

**Dependency visibility is a query, not a tool to build.** Manifests are data, so the
full graph — features, their `uses`, their `requires`, the libraries' own `requires` —
is CXPath-queryable; the catalog serves it, `cx pkg graph` renders it, and the
hash-pinned `*.xap.cxd` together with the resolved `requires` closure is the lockfile
(one reproducible closure, §7, now spanning both planes).

### §1.2. The feature runtime contract — behavior travels with the feature

A feature's *behavior* ships inside its package as the `<feature>.cx` code entry
(the §1 layout), never inside the serving process. The module exports a
**conventional surface the deployment host (§6.3) calls** — this is what makes a
XAP's server generic and a feature's deployment a data change:

| Export | Required | Called |
|---|---|---|
| `readout ($store $t)` · `readout ($store $t $actor)` | **always** (every feature projects a read-model) | serves `GET /surface/<feature>`; feeds the push channel's change digest |
| `apply ($verb $intent $store)` | iff the feature's grammar declares any non-`observe` verb | **after** the runtime PEP admits the emit (§8.2 of the composition spec) — `$verb` is the qualified name ρ resolved; the committed journal event precedes the call |
| `simulate ($store $t $params)` | optional | the host's sim tick when the deployment runs a source in simulated mode; `$params` = the spec's `[simulation]` params overlaid with current config |

**The actor-aware readout (per-principal lens).** A feature whose read-model
carries a per-principal confidentiality boundary declares the three-parameter
form: `$actor` is **exactly the request's resolved identity** — on an
auth-enabled host the proven §4.12 principal (the same value an admitted
intent commits as `actor=`), and the empty string on an auth-off host or an
unauthenticated `[public]` route. The feature composes its lens **as data**:
scoping happens where the fold happens, and the wire carries only what that
principal may see — client-side filtering of a full read-model is not a
control, and the two-parameter form remains the identity-blind contract for
features with no such boundary (arity selects the behavior; existing
two-parameter features are untouched). The **push channel renders lensed
readouts with the anonymous actor**: an SSE frame fans out to every `/stream`
subscriber, so the broadcast carries the feature's public subset only, and a
lensed client treats the named event as a change *signal* — it re-fetches
`GET /surface/<feature>` under its own possession proof for its view.

Everything else a feature carries stays **spec data, not code**: seeds, `[config]`
settings, `[devices]`, `[simulation]` parameters, `[source]` stacks, governance —
the host reads them generically from the sealed spec layer.

Normative rules:

- **Declaration.** A package whose content tree carries a `<name>.cx` code entry
  MUST declare its module surface in the manifest's `exports` block (§2) — for
  features exactly as for libraries: the listing is projected from the code at
  publish and re-verified at install. A tree with no code entry declares no
  `exports`. (Machine-checkable both ways; there is no half state.)
- **Authority.** `apply` runs only after the PEP admits the qualified emit, under
  the feature's granted slice — N-DIST-2 extends verbatim: the contract surface
  can neither hold nor request authority; it *receives* admitted work.
- **Closure.** The module's `[?lib]` imports resolve on the code plane (`requires`
  → `pkg:` references, §6.2) or within the package's own tree — never by reaching
  into the deployment's filesystem. The feature's `needs` covers this whole
  closure (§1.1).
- **Composites** are ordinary features here: a derived feature's `readout` joins
  the read-models its `needs` block declares it reads; deriving nouns from other
  features' stores is what `reads` consent is for.

---

## §2. The manifest — `package.cxd ⊢ package.cxs`

The fourth authoring document kind at the package boundary (draft schema in
[`xap_schemas/package.cxs`](../xap/xap_schemas/package.cxs)):

| Block | Kinds | Carries |
|---|---|---|
| identity | all | `kind` (feature \| library \| client), `name`, `version`, Tier-1 `hash` of the sealed subtree (self-describing seal, computed not hand-written) |
| publisher | all | the **publisher DID** + display metadata |
| grammar summary | feature | the exported verbs/nouns/frames/keys **projected from the feature spec** — the listing *is* the grammar (never restated by hand; recomputed at publish, verified at install) |
| **exports** | library, feature (with a code entry) | the exported **module/def surface**, with Tier-2 code identities — the code listing, projected from the code like a feature's grammar is from its spec. For a feature this is the §1.2 runtime-contract surface; a tree carrying `<name>.cx` MUST declare it (and only then) |
| dependencies | feature | for composites: the `uses` set as `(feature-name, version-range, publisher-DID?)` — the **grammar plane** (§1.1) |
| **requires** | all | the **code plane** (§1.1): library packages this package's implementation needs, as `(name, version-range, publisher-DID?)`, hash-resolved into the closure |
| compatibility | all | the XAP spec revision + toolchain floor the package validates against |
| **needs** | feature | the capability manifest: every grant the feature requires to function — nouns it reads across features, coordination channels it subscribes to, gateways/adapters it opens, its verbs' consequence ceiling — **covering its whole code closure** (N-DIST-2). Install-time consent = the principal granting exactly this set (§6); **a feature may not request at runtime what it did not declare here** (default-deny, N-TRUST-1). Libraries have no `needs` — they hold no authority |
| license-terms | all | reference to the terms under which entitlements (§5) are issued |
| signature | all | detached publisher signature over the Tier-1 hash (§3) |

The `needs` block is the marketplace-safety keystone: composition governance
(N-COMPOSE-2, per-verb grants, the consequence axis) already bounds what a co-located
third-party feature can *do*; `needs` makes that bound **visible before install** and
consented to explicitly, instead of discovered grant-by-grant afterwards.

---

## §3. Trust — publisher identity, signing, attestation

Exactly the approved trust model applied at the package boundary
(`xap.md` §22.6.1 — the boundary is the *trust domain*, not the XAP):

- **Publisher = a DID.** Signing = `ed25519` detached signature over the Tier-1 hash,
  by a key in the publisher's DID document (`std-lib/did.md`, `vc.md` — already
  shipped, R9).
- **Verification at install (fail-closed, in order):** (1) fetched bytes re-hash to the
  pinned Tier-1 hash; (2) signature verifies against the publisher DID; (3) required
  VCs (entitlement §5, attestations if policy demands them) verify. Any failure ⇒ the
  install yields a failure value and stages nothing.
- **Attestations are VCs** issued *about* a package hash by third parties (a market's
  review, an auditor, an enterprise's internal approval): portable, offline-verifiable
  claims. A XAP's install policy MAY require attestation sets ("only features attested
  by our security team") — this is a local policy over VC verification, not new
  machinery.
- **Trust-domain rule at runtime is unchanged:** an installed third-party feature is a
  co-located foreign trust domain; its cross-feature reads/subscriptions present
  DID/VC at the one PEP exactly as `xap.md` §22.6.1 already requires. Distribution
  adds the *provenance* (who published these bytes); it does not touch the runtime
  authority model.
- **Offline-first:** every verification above is offline-verifiable (hash, signature,
  VC chain). An offline field deployment installs from a local store mirror with full trust checks
  and no phone-home — the same property the identity model already holds for sessions.

---

## §4. Distribution — the transport is the store

Distribution introduces **no transport of its own**:

- A **registry** is a CX store: packages are subtree objects, versions are aliases.
  Served actively over **`cx-store://`** (CSRP), or passively from any byte substrate
  the store already supports (`s3://`, `https://`, `file://`, …) — the full faceted
  substrate axis of `store.md` applies to feature distribution for free.
- **Fetch is by Tier-1 hash** (content-addressed ⇒ any mirror is as good as the
  origin; integrity is the hash check, not the channel). Aliases are consulted only to
  *discover* hashes; trust never rests on an alias.
- **Mirroring/vendoring** = store replication (`store.md` migrate/clone porcelain). An
  air-gapped or at-sea XAP vendors its feature set into a local store; installs and
  verifications proceed identically.
- A XAP project declares its **remotes** (named acquisition stores, ordered) in its
  `*.xap.cxd` deployment block — the store's named-remotes model, reused. (*Not*
  named "source": that word is already taken twice — a feature's adapter stack in
  `feature.cxs`, and the XAP-level shared data providers in real instances.)

### §4.1. A git repository is a registry

Because a registry is a store and the store has filesystem-style backends, **a git
repo containing a store layout is a complete registry** with zero new machinery:
consumers reach it as `file://` (clone/vendor) or `https://` (raw), packages inside
are content-addressed as always, and version aliases are committed index files. What
git adds is exactly what an *internal* registry wants:

- **publish-by-PR** — moving an alias is a reviewed commit; the publish gate is your
  code-review gate;
- **history as audit** — the repo log is a (non-hash-chained) record of every alias
  move, sufficient inside one trust domain;
- **access control** — repo permissions govern who may publish.

Trust does **not** weaken: integrity is still the Tier-1 hash + DID signature of each
package, never the transport or the repo host. What a git registry *cannot* do —
server-side search, entitlement issuance, commerce — is precisely what the later
stages add. Sign packages from day one even internally: it costs nothing and makes
every later stage a re-host, never a re-package.

### §4.2. Growth path — internal registry → market

Four stages; **artifacts, hashes, and signatures never change across them**:

| Stage | What | Adds |
|---|---|---|
| **0 — monorepo** | features as in-repo dirs, path refs (the reference instance today) | nothing — the floor |
| **1 — internal git registry** | sealed + signed packages in a store-layout repo (§4.1); publish by PR; consume by pin; vendor by clone | packaging discipline, review-gated publish, audit trail |
| **2 — served registry** | a `cx-store://` (CSRP) service over the **same** store — the git repo may remain origin-of-truth with the service as a head | server-side catalog search over grammar data (P1) |
| **3 — market** | the market XAP (§5) wraps the registry | entitlements (P2), commerce (P3), federation |

Each stage is a strict superset; graduating is re-hosting and wrapping, never
re-packaging. An organization can stop at any stage indefinitely — stage 1 is a
complete, trustworthy distribution system for one trust domain.

---

## §5. The market — a XAP, dogfooded

A **market** is not a platform bolted onto XAP; it is **a XAP** whose features are:

| Market feature | Grammar (sketch) |
|---|---|
| **catalog** | nouns: `package`, `release`, `publisher`, `attestation`; verbs: `publish` (act, gated on publisher DID), `yank` (act, attestation-issuing — §8), `search` (observe) |
| **entitlement** | nouns: `license`, `grant-record`; verbs: `issue-license` (act — issues the VC), `revoke-license` (act — issues a revocation), `verify` (observe) |
| **distribution** | the store service itself (`cx-store://` CSRP endpoint) + mirror management verbs |

Consequences of "market = XAP", each load-bearing:

- **Auditability for free** — publishes, yanks, license issuances are committed
  intents in a hash-chained journal. A market's history is replayable evidence.
- **Discovery is grammar search.** Because a listing *is* the feature's grammar +
  requirements (structured data, §2), search is CXPath/query over grammars — "features
  with a verb that acts on nouns keyed by `mmsi`", "features whose requirements cover
  collision avoidance" — and an agent can compose **trial surfaces** from search
  results before any install (the grammar is enough to preview what could be said).
  Text search is the degenerate case, not the model.
- **Markets federate like XAPs** (`xap.md` §22.6.1). There is **no single central
  market** — the market is a *protocol* (this spec's shapes: package, manifest,
  entitlement VC, catalog grammar), so N markets compose into one discovery surface
  exactly as N XAPs compose into one experience. An enterprise-internal market and a
  public market blend on the same principal's surface.
- **Licenses are VCs** — an entitlement is an **attenuating delegation** from the
  publisher (or the market as the publisher's delegated issuer — an ordinary VC
  chain) to the acquiring principal, granting the right to **enable** the package,
  attenuable by the terms: seats, duration, tenant set, feature subset. Verified at
  install and at enable (offline-capable); recorded in the installing XAP's journal.
  Enforcement is the existing capability model — **the entitlement check is a PEP
  check**, not a DRM subsystem.
- **Payments/settlement sit below the entitlement seam** (§10 phases). The runtime
  sees exactly one artifact: the entitlement VC. How it came to be issued (purchase,
  subscription, enterprise agreement, gratis) is invisible above the seam — which is
  what keeps commerce swappable and the runtime honest.

### §5.1. Pricing models — every model is a VC shape

For-fee features add **no runtime machinery**. The enable-time check is always the
same PEP question — "does a verifying entitlement VC cover enabling this package for
this principal/tenant?" — and every commercial model is an **attenuation shape** of
the issued VC:

| Model | VC shape |
|---|---|
| **one-time / perpetual** | no expiry; bound to principal or tenant; attenuated to a **version range** (typically the purchased major, `1.x`). Updates within range verify against the same VC; a new major is a new purchase or an upgrade VC (which supersedes — market policy, invisible above the seam). |
| **subscription** | **short-lived VCs re-issued on a cadence** (the certificate-renewal pattern — preferred over long-lived VC + revocation polling, which reintroduces phone-home), with a declared **grace window** so an offline holder (a deployment mid-mission) keeps verifying through the term + grace. Lapse fails the *next* enable/verify point per the consuming XAP's policy; the running XAP is untouched (N-DIST-1 — lapse is contractual, surfaced by the composer, never mechanical seizure). |
| **per-seat** | an **org-level VC delegable into at most N principal-bound sub-VCs** — seat assignment *is* attenuating delegation (the §22.2 chain doing commercial work), performed by the org's admin, journaled at the org, offline-verifiable per seat. No seat-counting service; the delegation chain is the count. |
| **metered / usage** | the entitlement grants enable **plus a reporting obligation** in its terms; the consuming XAP's **hash-chained journal is the non-repudiable meter** (committed intents, attributable and replayable), settled post-hoc below the seam. |
| **trial / free tier** | a time-boxed and/or subset-attenuated **gratis VC**. Same machinery end to end; free is not a special case. |

> **Price is a market property, not a package property.** The manifest carries
> `license-terms` (under what terms entitlements may be issued), never a price: the
> same signed artifact can be paid in one market, free in another, and site-licensed
> in a third. Pricing lives in the catalog listing of each market that carries the
> package.

### §5.2. Payment processing — the `commerce` feature, rails as adapters

Settlement is a feature *of the market XAP*, structured like every other feature:

- **`commerce`** — nouns: `order`, `settlement`, `price`; verbs: `quote` (observe),
  `place-order` (act), `record-settlement` (act, gateway-fed). The
  order → settlement → `issue-license` choreography is **journaled intents inside the
  market XAP** — a market's commercial history is replayable evidence like everything
  else in it.
- **Payment providers are source adapters** behind the `commerce` feature — the same
  layered gateway seam features already use for data (`kind` not enum'd): a card
  processor, invoicing/PO flows, app-store settlement, crypto — each a gateway feeding
  the `settlement` noun. Swapping or adding a rail touches no grammar above the seam.
- **Compliance scope is confined by construction:** the consuming runtime never sees
  payment data at all, and within the market XAP the PCI/PSD2 surface is the payment
  adapter, not the catalog or entitlement features.
- **Refunds / chargebacks** — a settlement-reversal event triggers a **revocation VC**
  for the affected entitlement (§8 semantics apply: checked at the next verify point,
  contractual for running instances, journaled on arrival).

### §5.3. Packs & bundles — catalog objects, not features

A bundle is a **commercial grouping, not a semantic composition** — it MUST NOT be
modeled as a composite feature (composites join grammars; bundles join price tags).
Normatively:

- A **bundle** is a **catalog object**: a named, versioned **member set** —
  `(package name, version range, publisher DID)` per member — with its own listing and
  terms. It lives in the market's catalog grammar; nothing about it exists at runtime.
- **One entitlement VC covers the set**, via the feature-subset attenuation already
  defined for licenses (§5). Enable-time check: package ∈ the VC's member set. Install
  remains strictly **per-package** (each member verifies and passes the compose-gate
  individually — bundling never bypasses W1–W6 or the `needs` consent).
- **Fixed vs. growing bundles are both VC shapes:** an *enumerated-members* VC
  entitles the set as purchased; a *bundle-reference* VC (bundle id + version bound)
  entitles the member set the referenced bundle version defines — "the suite as it
  grows" is a re-issuance policy on the reference form, per the terms.
- Adding/removing a member is a **new bundle version** at the catalog; whether existing
  licensees follow is a terms question, never a runtime one.

---

## §6. The lifecycle

```
author → validate → seal → sign → publish            (publisher side)
discover → acquire → verify → compose-gate → consent → enable   (consumer side)
update = new hash, explicit re-pin  ·  rollback = re-pin previous hash
yank / revoke = attestations, never remote reach-in   (§8)
```

Normative points per step:

1. **author/validate** — the authoring process unchanged; `cx validate` over the three
   layers + the manifest.
2. **seal** — store the subtree; compute Tier-1 hash; write it into the manifest;
   re-seal (the manifest names the hash of the content it seals — the manifest blob
   itself sits beside, not inside, the hashed content tree, exactly the git
   tag-object pattern).
3. **publish** — a committed `publish` intent in the market XAP: alias
   `<name>@<version> → manifest hash` (the tag-object pattern completed: the name
   resolves to the **manifest**, whose `hash=` pins the content tree — discovery
   goes name → manifest → content), signature + manifest recorded. Released
   aliases are immutable (re-pointing is a market-rule violation; consumers pin
   hashes anyway).
   **Schema lineage rides the publish (RULED: SEA-1).** When the store already
   holds a previous released version of the name, publish diffs the two content
   trees' schema entries (`*.cxs`, matched by tree path) and, for each changed
   schema, runs the `cx schema compat` classification
   ([`core/schema.md`](../core/schema.md) §16.5): a **derivable** change derives
   its Lane-2 `[schema-lineage]` claim + upcaster mechanically; a
   **reinterpreting** change REFUSES the publish (`CXER4890`) with the
   classifier's specific missing-rule prompts — unless the package itself
   carries an **authored** claim covering exactly the detected old→new address
   pair (tree entries whose path ends `lineage.cx` — SEA-1d). The accepted
   claims (derived or authored) are stored beside the manifest as one lineage
   document, aliased **`<name>@<version>+lineage`**. An added schema file links
   nothing; a removed schema file publishes (feature pruning is legal — the
   install-time coverage gate below still guards any journal history it leaves
   behind). Additive changes therefore deploy silently; only a genuine
   reinterpretation stops the author, with the rule it is missing named.
4. **acquire/verify** — fetch by hash from any source; run §3 verification.
5. **compose-gate** — run **W1–W6** (`xap_grammar_composition.md`) over the target
   XAP's enabled set ∪ {candidate}. Conflicts are `[!compose-conflict]` values shown
   *before* anything is enabled. **Seamless integration is this gate**: a package that
   passes composes into the one grammar; a package that would collide, contradict a
   rule, or mis-register a frame/key never gets in half-way.
6. **consent/enable** — the principal (or an authorized role) reviews the `needs`
   block and issues the grants (local delegation for first-party; the feature's DID as
   grantee for third-party); the feature is added to the `*.xap.cxd` (pinned by hash);
   per-tenant workers recycle per the deployment model. Enabling **is** granting —
   there is no separate "installed but ungoverned" state.
7. **update** — a new release is a new hash; a XAP moves by explicit re-pin (agent-
   assisted: the composer can diff the two grammars — data! — and show exactly what
   changes in the one language before you move). N-COMPOSE-1 applies across updates:
   an update that would rebind existing utterances surfaces as ambiguity prompts, never
   silent change.
8. **rollback** — re-pin the previous hash. Journal + snapshot compatibility across
   feature versions follows the evolution rules of
   `schema_event_evolution.md` (stream 21 — the former `xap.md` §14.4
   citation resolved to no such rule, #716 item 3): a feature's events
   remain replayable; a downgraded feature MAY skip event kinds introduced
   by the newer version ONLY as the narrow downgrade exception, and every
   skip is COUNTED AND VISIBLE (tolerance is discovery-surfaces-only —
   never a silent drop).

### §6.1. Function surface & error codes (P0)

The lifecycle's toolchain face, on `cx-xap` (native reference
`vcx/code/stdlib_xap_dist.v`; the engine **composes** the shipped store / did /
vc / composition surfaces — §9 absence 8 is checkable because it introduces no
parallel primitive). `pkg-tree` and `pkg-sign` are pure; the rest are env-aware
(they touch a store and, at install, a runtime's authority store).

| Function | Signature → result |
|---|---|
| `[$xap:pkg-tree ENTRIES]` (pure) | `ENTRIES` = a sequence of `[entry path='…' CONTENT]` (CONTENT = one text/element payload per entry). Returns the canonical `[package-tree …]` content document — entries **sorted by path**, byte-stable under canonical form, so its store hash *is* the package's Tier-1 hash. Empty, duplicate, absolute, or `..`-traversing paths → `CXER4880`. |
| `[$xap:pkg-seal STORE TREE DRAFT]` | Validates `DRAFT` (kind-aware §2 structure: `kind`, `name`, `version`, `publisher.did` present; `needs` on a `kind=library` → `CXER4880`), stores `TREE`, writes its Tier-1 hash into the manifest's `hash=`, stores the completed manifest **beside** the tree (tag-object pattern), and returns `[sealed hash=<tree> manifest=<manifest-hash>]`. |
| `[$xap:pkg-sign MANIFEST PRIVATE-KEY]` (pure) | Returns the manifest with its `[signature alg=ed25519 key=… value=…]` filled: a detached ed25519 signature **over the Tier-1 `hash=` string**. `key=` names the key in the publisher's DID document; binding is checked at verify time (signing is possession, verification is trust). |
| `[$xap:pkg-publish STORE NAME VERSION MANIFEST-HASH]` | Sets alias `NAME@VERSION → MANIFEST-HASH` (§6.3 — the name resolves to the manifest; its `hash=` pins the content). Re-pointing an existing released alias to a *different* hash → `CXER4887`; re-publishing the identical hash is idempotent. **Schema-lineage stage (RULED: SEA-1, §6 step 3):** against the highest previously-released version of NAME, changed `*.cxs` tree entries (path-matched) classify via `core/schema.md` §16.5 — derivable changes derive their `[schema-lineage]` claim + upcaster into a lineage document stored beside the manifest and aliased `NAME@VERSION+lineage`; a reinterpreting change uncovered by an authored in-tree claim (`…lineage.cx`, endpoints matching) refuses `CXER4890` carrying the classifier's `[missing-rule …]` prompts. No previous version, or no schema deltas → the stage is a no-op. |
| `[$xap:pkg-fetch STORE REF]` | `REF` = a manifest Tier-1 hash or `name@version` alias (aliases are consulted only to discover hashes — trust never rests on one). Returns the manifest document. Missing alias/object → `CXER4886`. |
| `[$xap:pkg-verify STORE REF OPTS?]` | The §3 fail-closed chain, in order: (1) the manifest's pinned content tree loads (absent → `CXER4886`) and **re-hashes to `hash=`** (divergent → `CXER4881`; unreachable through an honest content-addressed store — it guards dishonest mirrors, behind the store's own `CXER1120`); (2) the detached signature verifies against the **publisher DID** (unsigned or non-verifying → `CXER4882`); (3) every VC in `OPTS.attestations` (+ entitlements, P2) verifies (else `CXER4883`; `OPTS.now` pins the verification clock for determinism). Success returns `[package-verification status=ok name=… version=… kind=… hash=… publisher=…]`; every failure is the err value of its stage — nothing is staged on failure. |
| `[$xap:pkg-install XAP STORE REF OPTS?]` | `XAP` = the `[xap …]` deployment document, or a previous `[installed …]` report (chaining — the report carries the updated doc). The consumer pipeline (§6 steps 4–6), fail-closed at each stage: **fetch** → **verify** (full chain above) → **per-kind gate** — `feature`: W1–W6 over `XAP`'s enabled feature set ∪ {candidate} via `[$xap:compose]` (conflicts → `CXER4884` carrying the `[conflict …]` set), **plus** the exports-surface check whenever the tree carries a code entry (§1.2 — a `<name>.cx` with no `exports`, `exports` with no code entry, or a declared def absent from the code each → `CXER4884`); `library`: exports-surface check (every `exports` def present in the tree's code; a declared computation-identity `identity=` claim — spelled `computes-as:<algo>:<hex>`, the [$cx:computation-id] token — must match the code's, recomputed via the same pure relation — else `CXER4884`); `client`: `client.cxd` structural validation → **journal-coverage gate (RULED: SEA-1)** — when `OPTS.journal` names the installing deployment's open journal handle, the L151 coverage pre-flight runs as a pure query over (declared `schema=` addresses in the journal) × (the package's lineage graph: every `NAME@*+lineage` document in the store, plus `OPTS.lineage` claims): each in-scope address (SEA-1e: one appearing in the package's history — a published version's schema content-hash, a lineage-claim endpoint, or a current address; a current address being the content-hash of a `*.cxs` entry in the candidate's tree) must be current or admit the unique lineage path to a current address, else the install refuses `CXER4891` naming every uncovered address and its entry count; entries declaring no schema are out of scope; without `OPTS.journal` there is no history to check and the gate is vacuous (deployments that carry journals supply them) → **consent = grants** — with `OPTS.runtime` + `OPTS.grantee`, issue **exactly** the manifest's `needs` set as delegations into the runtime's authority store (enabling *is* granting; a library has no `needs` and receives no grants — N-DIST-2) → **enable**: returns the updated `XAP` deployment document with the package pinned by hash under `[features]`/`[libraries]` and the `requires` closure resolved hash-pinned beneath it (the §7 lockfile view). |
| `[$xap:pkg-requires-closure STORE MANIFEST]` | Resolves the code plane transitively: each `requires` entry → the store's best published version in range → its manifest → recurse. Returns the closure as a sorted sequence of `[pin library=… version=… manifest=… hash=…]`. Unresolvable → `CXER4886`; a dependency cycle → `CXER4880`. |
| `[$xap:pkg-catalog STORE OPTS?]` | Discovery over any store, composing only the store's own surfaces (§9): on a store holding **aliases** (a local/file registry) the alias table is authoritative; on a **served** `cx-store://` handle (no alias verbs on the wire) discovery falls back to **CXPath query pushdown** — `//publisher` matches every manifest server-side, each result carrying its manifest hash. Returns a name@version-sorted `[catalog [package name=… version=… kind=… manifest=… hash=… publisher=… [verbs …]? [exports …]?]*]`. `OPTS`: `term` (substring over name + verb/noun/def names), `name`/`version` (exact). Discovery is never trust: install/verify re-run the full §3 chain on whatever discovery surfaced. This is the stage-2 catalog seed (§4.2): the same function serves locally and over the wire, so graduating the registry to a served head changes no consumer code. |

| `[$xap:license-issue ISSUER-DID ISSUER-KEY SUBJECT-DID TERMS]` (pure) | Issues an **entitlement VC** (§5/§5.1): an ordinary VC whose claim is a §22.2 `[delegation [capabilities [enable]] [over pkg:…] [entitlement …]]`. `TERMS`: `package`/`bundle`, `versions` (range attenuation: exact, `M.x`, `*`), `kind`, `expires` + `grace-until` (subscription), `seats` (org credential) / `seat` + `parent` (per-seat sub-issuance — the embedded org VC makes each seat offline-verifiable; **the delegation chain is the count**), `members` (bundle member set). Composes `vc:issue`; missing package/bundle → `CXER4880`. |
| `[$xap:license-verify VC PACKAGE VERSION OPTS?]` | The enable-time check: (1) the VC verifies at `OPTS.now` — `expired` is still admitted while `now ≤ grace-until` (status `grace`; the offline-subscription window); (2) coverage holds — direct `package=` + version-in-range, or bundle `[members]` membership; (3) a seat credential's chain attenuates — the embedded org VC verifies, its subject is the seat issuer, `seat ≤ seats`, and the org entitlement covers the package. Success → `[entitlement-verification status=ok\|grace …]`; every failure is `CXER4883` with the failing stage. |

`pkg-verify` / `pkg-install` accept `OPTS.entitlement` (a license VC — verified
as stage 3.5 of the trust chain, fail-closed) and `OPTS.require-entitlement`
(the consuming XAP's install **policy**: absent VC → `CXER4883`). Price is a
market property: the same signed artifact installs gratis where no policy
demands a VC and under entitlement where one does — the artifact and its
verification are identical in both (§5.1, fixture §11.12).

**Error codes** (cx-xap band — registered `CXER4850–4879` after the
2026-08-05 xap.md §8 amendment (audit C5: the original `…–4949`
proposal yielded `4890–4949`); next free block after the composition
engine's `…4873`; fold into the approved registry at graduation):

| Code | Symbol | Raised when |
|---|---|---|
| `cx-err:CXER4880` | `E_XAP_PKG_INVALID` | manifest/tree structurally invalid: bad entry paths, kind-rule violations (`needs` on a library), draft missing identity fields, requires cycle |
| `cx-err:CXER4881` | `E_XAP_PKG_HASH_MISMATCH` | the pinned content does not re-hash to the manifest's Tier-1 `hash=` |
| `cx-err:CXER4882` | `E_XAP_PKG_SIG_INVALID` | the detached signature fails against the publisher DID (wrong key, wrong DID, tampered manifest) |
| `cx-err:CXER4883` | `E_XAP_PKG_VC_INVALID` | a required VC (attestation; entitlement from P2) fails verification |
| `cx-err:CXER4884` | `E_XAP_PKG_GATE_REJECTED` | the per-kind install gate rejects — carries the gate's own values (the compose `[conflict]` set / the exports mismatch) |
| `cx-err:CXER4886` | `E_XAP_PKG_NOT_FOUND` | fetch/alias/closure target absent from the store |
| `cx-err:CXER4887` | `E_XAP_PKG_ALIAS_IMMUTABLE` | re-pointing a released `name@version` alias to a different hash |
| `cx-err:CXER4888` | `E_XAP_PKG_PIN_MISMATCH` | a `pkg:` reference's `#hash` pin (or a lockfile pin supplied to the loader) does not match the resolved manifest (§6.2) |
| `cx-err:CXER4889` | `E_XAP_PKG_REGISTRY_UNBOUND` | a `pkg:` reference is resolved with no registry bound (§6.2) |
| `cx-err:CXER4890` | `E_XAP_PKG_SCHEMA_REINTERPRETS` | publish-time schema-lineage refusal (RULED: SEA-1): a changed schema entry classifies as reinterpreting (`core/schema.md` §16.5) and no authored in-tree claim covers the pair — carries the classifier's `[missing-rule …]` prompts |
| `cx-err:CXER4891` | `E_XAP_PKG_COVERAGE_GAP` | install-time journal-coverage refusal (RULED: SEA-1): a declared `schema=` address in the supplied journal, in scope of the package's lineage graph, admits no lineage path to a current schema — names every uncovered address and its entry count |

(`CXER4885` is reserved unallocated: partial-consent semantics are deliberately
absent in P0 — consent is the caller's decision to invoke `pkg-install` at all,
and a runtime request beyond `needs` is already the PEP's `CXER4850`, not a new
code.)

Conformance fixtures live at `conformance/stdlib/xap-dist.cxd` (authored
spec-first from §11's P0 subset).

### §6.2. Code-plane loading — `pkg:` module references

Code loads by pin the same way artifacts install by pin. `[?lib]` admits a fourth
resolver alongside file paths, registered names and `https://`:

```
[?lib 'pkg:<name>@<version>' :as n]                    # registry-resolved
[?lib 'pkg:<name>@<version>#<manifest-hash>' :as n]    # pinned
```

Resolution (eval-time, like every `[?lib]`):

1. **Registry binding.** The process's registry is bound by the `CX_REGISTRY`
   environment variable (a store URL — the same binding the publish tooling
   uses). Unbound → `CXER4889`. The store opens **read-only**; the load is
   gated by the `read` capability exactly like a file-path `[?lib]`.
2. **Fetch.** The bare form resolves `name@version` through the registry's alias
   table to the manifest (absent → `CXER4886`). The pinned form fetches the
   manifest **by `#hash` directly** — the alias table is never consulted, so a
   re-pointed or hostile registry cannot substitute code — then requires the
   manifest's `name`/`version` to match the reference (else `CXER4888`).
3. **Verify.** The full §3 fail-closed chain runs on every load — content
   re-hash (`CXER4881`), publisher signature (`CXER4882`). There is no
   trust-the-registry mode.
4. **Load.** The module source is the verified tree's `<name>.cx` code entry
   (§1 layout; absent → `CXER4880`); it loads through the standard module
   loader — same two-pass semantics, same `scope=public` export rules, same
   cycle detection — with the reference string as the module name.

Deployment docs supply the pinned form: the host (§6.3) derives each feature's
`pkg:` reference from the `*.xap.cxd` row's pins, so a running XAP's code plane
is exactly its lockfile. Vendor-materialization (fetch → verify → write files →
`[?lib './…']`) remains valid — §4.1's vendoring is unchanged — but is no longer
required machinery; `pkg:` is the canonical path.

### §6.3. The deployment host — a XAP server is data plus adapters

`[$xap:host XAP-DOC OPTS]` boots a complete XAP from its deployment document.
The host owns everything every XAP would otherwise re-implement:

1. **acquire** — open the deployment's store and the bound registry; for every
   pinned `[feature]` row: fetch by pin, run §3 verification (a pin/content
   mismatch refuses to boot — fail closed).
2. **compose** — `[$xap:compose]` over the sealed spec layers (W1–W6 at load);
   the composed grammar is stored (alias `grammar`) and attached via
   `[$xap:run {grammar: …}]` — ρ + N-COMPOSE-2 exactly per the composition
   spec's runtime integration.
3. **govern** — translate the deployment's `[roles]` (rank-ordered) and each
   spec's `[governance]` grants, plus `[agents]` capabilities and
   autonomy-envelope allows, into runtime dials. Actor resolution is an OPTS
   hook (`resolve-actor`: request + intent → actor id) with a default of
   `role:<author's role>`; auth schemes stay deployment adapters.
4. **load** — resolve each feature's `pkg:` reference (§6.2) and register its
   §1.2 contract surface, keyed by the composed grammar's qualified verbs.
5. **serve** — the standard surface: `GET /grammar` (the composed projection),
   `GET /features` (from the grammar's provenance root), `GET /surface` +
   `GET /surface/<f>` (contract `readout`), `POST /intent` (ρ-resolve →
   runtime emit → PEP → contract `apply`; refusals carry `unknown-verb` /
   `ambiguous` + candidates / the PEP denial), `GET /stream` (per-feature
   push events on the readout change digest).
6. **extend** — OPTS registers what is genuinely deployment-specific:
   `routes:` closures for extra endpoints, `[worker …]` source/ingest loops,
   sim cadence. Adapters register onto the host; they never fork it.
   Adapter routes are consulted **before** the standard surface, so a
   deployment may *enrich* a standard route (e.g. a `/features` catalog with
   display titles) without forking; a route key ending in `/` matches by
   prefix (`history/` serves `/history/...`). Deployment workers that change
   read-models outside the intent path (source ingest, simulation ticks)
   push their features' fresh readouts through `[$xap:host-push RT FEATURE]`
   — the same named-event frame an admitted act pushes.

   The contract `apply` may **refuse** on the feature's own domain policy
   (value bounds, device state) by returning a `[refused reason=…]` value:
   the host acks `ok=false` with that reason. The PEP admitted the *verb*;
   the feature refused the *values* — two layers, both visible in the ack.

A XAP with no custom transport is therefore **zero server code**: deployment doc
+ published packages + a client. Deploying one more feature is: publish, add a
pinned row, re-pin, restart — the host recomposes, re-gates, re-loads.

---

## §7. Reproducibility

The `*.xap.cxd` with hash-pinned features — and, through each manifest's `requires`,
the hash-resolved library closure beneath them (§1.1) — is a **complete, reproducible
closure** spanning both dependency planes: the
composed grammar is a deterministic function of the pinned set
(`xap_grammar_composition.md` §3.1), so **the composed grammar itself is
content-addressable** — two deployments with the same pins have bit-identical composed
grammars, and a grammar hash mismatch is proof of a supply-chain divergence. This is
the audit story: *what could be said, by whom, under which grants* is pinned, hashed,
and replayable end to end (pins → grammar → journal).

---

## §8. Retirement — yank & revocation, without reach-in

> **N-DIST-1 (no remote reach-in).** No market, publisher, or registry ever has
> authority *into* a running XAP. Yanks and revocations are **attestations published
> at the market**; acting on them is the consuming principal's decision, surfaced by
> their own composer/agent. Authority originates only from principals — distribution
> gets no exception to the trust model's root rule.

- **yank** — a market attestation (VC) that a release should no longer be adopted
  (defect, vulnerability, rights issue). Effects: catalog hides it from discovery;
  installers warn/fail-by-policy on new installs; **running XAPs are untouched** but
  their composers surface the yank with the stated reason.
- **license revocation** — a revocation VC. Checked at the next enable/verify point
  per the consuming XAP's policy; contractual, not mechanical, for already-running
  instances (the journal records the revocation's arrival either way).
- **publisher key rotation/compromise** — DID document rotation per `did.md`;
  attestations re-anchor trust for artifacts signed pre-rotation.

---

## §9. What this spec deliberately does not introduce

Each a checkable absence (§11 asserts them):

1. **No archive/package format** — a package is a store subtree object.
2. **No new transport** — `cx-store://` + the store's substrates.
3. **No new trust primitive** — DID/VC + §22.2 delegation; entitlement = VC;
   verification = PEP check.
4. **No central market** — the market is a protocol instance (a XAP); markets
   federate.
5. **No runtime kill-switch** — N-DIST-1.
6. **No second compose gate** — install runs the same W1–W6 as load and summon.
7. **No billing/DRM subsystem** — every pricing model is a VC attenuation shape
   (§5.1); payment rails are source adapters behind the market's `commerce` feature
   (§5.2); bundles are catalog objects (§5.3). The runtime's only commercial concept
   is the entitlement check at the PEP.
8. **No separate library package manager** — libraries ride the identical
   seal/sign/store/verify machinery (§1.1); only the install gate differs by kind.
9. **No registry server requirement** — a store-layout git repo is a complete
   stage-1 registry (§4.1); the CSRP service is a graduation, not a floor.

---

## §10. Staged implementation (design complete; build order)

| Phase | Ships | Depends on |
|---|---|---|
| **P0 — package + local install** | kind-aware `package.cxs` (feature **and library**, §1.1), seal/verify (hash+sig), per-kind install gates, hash-pinned `*.xap.cxd` + `requires` closure, `file://`/local-store remotes incl. the git-registry convention (§4.1) | grammar-composition impl; store subtree (shipped); did/vc (shipped) |
| **P1 — registry + discovery** | catalog feature (publish/search over grammar data, bundle listings §5.3), named remote sources, mirroring/vendoring flows | P0; `cx-store://` service (shipped) |
| **P2 — entitlements** | entitlement feature (license VCs in all §5.1 shapes — perpetual/subscription/per-seat/metered/trial — incl. bundle coverage; issuance/verification at enable), attestation policies | P1 |
| **P3 — market federation + commerce seam** | multi-market blend on one surface; the `commerce` feature + payment-rail adapters below the entitlement seam (§5.2); yank/revocation/refund attestation flows end-to-end | P2; XAP federation runtime |
| **P4 — code plane + host** | the §1.2 feature runtime contract (feature `exports` + install-gate check), `pkg:` module references (§6.2), the deployment host (§6.3) — a XAP boots from its deployment doc + packages with zero bespoke server code | P0 (gates, pins); module loader; composition runtime (§8.2, shipped) |

Every phase ships whole (no stubs): P0 is a complete distribution system for
first-party/vendored use; each later phase adds a complete capability, not a scaffold.

---

## §11. Conformance fixtures (to author with P0 onward)

1. **Seal/verify** — round-trip: seal → mutate one byte → verify fails with the exact
   hash-mismatch value; unsigned / wrong-DID / bad-VC each fail with their own value.
2. **Compose-gate at install** — a package conflicting at W2 (key type mismatch) is
   rejected pre-enable with `[!compose-conflict]`; the XAP's enabled set is unchanged.
3. **Consent = grants** — enabling a third-party package wires exactly the `needs`
   set as DID-grantee capabilities; an undeclared runtime request is PEP-denied.
4. **Pin/rollback** — enable v2, roll back to v1 by re-pin; composed-grammar hash
   returns to the v1 value; journal replay clean across both.
5. **Alias immutability** — re-pointing a released alias is rejected by the catalog's
   own rules (a market-XAP fixture).
6. **Offline install** — full verify + install from a vendored local store with no
   network.
7. **N-DIST-1** — a yank attestation arrives; running XAP state is bit-unchanged;
   the composer surfaces the warning; new install of the yanked hash fails per policy.
8. **§9 absences** — greps/asserts that the implementation calls store/did/vc/PEP
   surfaces rather than shipping parallel ones (the no-new-primitive claims).
9. **Subscription lapse** — a lapsed (past term + grace) entitlement fails the next
   enable with the exact verification value; the running XAP's state is bit-unchanged
   (N-DIST-1); a within-grace offline verify succeeds with no network.
10. **Per-seat chain** — an org VC with `seats=N`: the N-th principal sub-delegation
    verifies; the N+1-th fails attenuation; each seat verifies offline.
11. **Bundle coverage** — one bundle VC: enabling a member package succeeds; a
    non-member from the same publisher is denied; every member still individually
    passes verify + compose-gate + `needs` consent (bundling bypasses nothing).
12. **Price is a market property** — the same signed package hash installs from a
    gratis market with no VC requirement and from a paid market only with one; the
    artifact and its verification are identical in both.
13. **Library round-trip** — a `kind=library` package (the in-tree `gtin` codec package is the reference
    case) seals/verifies/installs through the module-surface gate; it never meets the
    compose gate; a `needs` block in a library manifest fails validation.
14. **N-DIST-2** — library code invoked from a feature executes under exactly the
    requiring feature's grants: an act the feature lacks is PEP-denied identically
    whether emitted from feature code or its dependency's code.
15. **Git registry** — publish-by-commit to a store-layout repo; a consumer installs
    from the clone (`file://`) with full hash + signature verification and no service
    running; the same artifact later served over `cx-store://` verifies bit-identically
    (stage 1 → stage 2 is a re-host).
16. **Runtime-contract gate (§1.2)** — a feature package whose tree carries
    `<name>.cx` but whose manifest declares no `exports` (and the converse, and a
    declared def absent from the code) each fail the install gate with `CXER4884`;
    a spec-only feature (no code entry, no `exports`) still installs.
17. **`pkg:` loading (§6.2)** — a published library loads via
    `[?lib 'pkg:<name>@<version>']` and its defs are callable; the `#hash` pinned
    form loads without consulting the alias table; a wrong `#hash` →
    `CXER4888`; unbound registry → `CXER4889`; a tampered tree → `CXER4881` at
    load. (The loader family needs a process-level registry binding, so it lives
    as engine-level tests beside the wire re-host test; the gate fixtures above
    stay in the conformance corpus.)
18. **Host boot (§6.3)** — a toy XAP (deployment doc + two published feature
    packages, one with a non-observe verb) boots through `[$xap:host]` alone:
    `/grammar` serves the composed projection, `/surface/<f>` renders each
    contract `readout`, an admitted `POST /intent` reaches `apply` with the
    qualified verb and a denied one never does, and a registered adapter route
    responds — with zero XAP-specific server code in the fixture.
19. **Publish-lineage (RULED: SEA-1)** — v2 of a feature changes a shipped
    schema additively: publish derives and stores the `[schema-lineage]` claim
    (alias `name@version+lineage`) and succeeds silently; a reinterpreting
    change (a type change) refuses `CXER4890` with the named missing rule; the
    same change plus an authored in-tree `…lineage.cx` claim covering the pair
    publishes.
20. **Install-coverage (RULED: SEA-1)** — a journal holding v1-declared events
    installs the v2 feature cleanly when the published lineage covers v1→v2;
    with the lineage absent, the install refuses `CXER4891` naming the
    uncovered address; without `OPTS.journal` the gate is vacuous.

---

## §12. Graduation path

01-new → 02-working once P0's fixture set runs against a real implementation
(spec-first: the fixtures above are authored from this spec's acceptance claims before
code). **Done 2026-07-06** — this document lives in 02-working with the full
implementation staircase behind it. Graduates to `spec/03-approved/xap/` as a modular
sibling (user G3 only), alongside `xap_grammar_composition.md`; on that pass `xap.md`
gains lexicon entries (**package** and its kinds — **feature package** / **library** /
**client package** —, **publisher**, **entitlement**, **attestation**, **market**,
**yank**, the two **dependency planes**) and invariants **N-DIST-1/N-DIST-2**, and
`package.cxs` graduates into the toolchain with the other schemas.

### Graduation checklist (staged for user G3 — status as of 2026-07-06)

| Item | Status | Evidence |
|---|---|---|
| §6.1 P0 surface implemented, gate enforced | ✅ | `conformance/stdlib/xap-dist.cxd` 001–024 (engine `vcx/code/stdlib_xap_dist.v`) |
| §11.1 seal/verify rejection lanes | ✅ | 002–011 |
| §11.2 compose-gate at install | ✅ | 019 |
| §11.3 consent = grants (exactly `needs`) | ✅ | 018; N-DIST-2 zero-grant lane 016 |
| §11.4 pin/rollback hash identity | ✅ | 020 |
| §11.5 alias immutability | ✅ | 014 (idempotent re-publish admitted) |
| §11.6 offline vendored install | ✅ | 024 |
| §11.8 §9-absence checks | ✅ | `scripts/check_xap_dist_absences.py` (make gate) |
| §11.9 subscription lapse + grace | ✅ | 031/032 |
| §11.10 per-seat delegation chain | ✅ | 033/034 |
| §11.11 bundle coverage (+ §5.3 reference form) | ✅ | 035/036/042/043 |
| §11.12 price is a market property | ✅ | 016/025 (gratis) vs 037/038 (entitled) — same artifact |
| §11.13 library round-trip (gtin reference) | ✅ | 016 + `packages/gtin/` corpus (packages suite) |
| §11.14 N-DIST-2 (libraries carry no authority) | ✅ | 005 (needs-on-library) + 016 (zero grants issued) |
| §11.15 git registry → served re-host | ✅ | 025 (stage 1, committed `registry/`) + `vcx/tests/xap_registry_serve_real_test.v` (stage 2, wire) |
| §4.1 registry realized + publish-by-PR | ✅ | `registry/` (store, keys, publish.cx, `make registry-publish`/`registry-serve`) |
| §5 market = a XAP (worked case) | ✅ | `market/` feature specs; 039–041 (compose, journaled choreography, N-COMPOSE-2 at `fulfil`) |
| §1.2 runtime contract + §11.16 gate lanes | ✅ | fixtures 046–049 (all four lanes, enforced) |
| §6.2 `pkg:` loading + §11.17 lanes | ✅ | `vcx/tests/module_pkg_loader_test.v` (bare / pinned / cross-pin 4888 / unbound 4889 / absent 4886, black-box) |
| §6.3 deployment host + §11.18 boot fixture | ✅ engine | `vcx/tests/xap_host_real_test.v` (toy XAP from packages only: standard surface, PEP admit/deny, contract apply, adapter route); the reference-instance conversion = the first real consumer (in flight) |
| §5 federation | ✅ | 044 (two markets blend as data; installs verify at origin) |
| §11.7 yank end-to-end (attestation flow) | ◻ deferred | needs the market-XAP composer surface (P3 flow); yank VERB is in the catalog grammar (039), attestation VC machinery shipped (011) |
| lexicon cutover + `package.cxs` toolchain graduation | ◻ user G3 | the §10-listed reconciliation in `xap.md`, at approval time |

---

**References:** [`xap_grammar_composition.md`](../xap/xap_grammar_composition.md)
(the W-gate; composed-grammar determinism) ·
[`xap_authoring_process.md`](../xap/xap_authoring_process.md) (the packaged
layers) · [`../xap/xap.md`](../xap/xap.md) (trust model §22,
federation §22.6.1, marketplace ruling; N-TRUST-1) ·
[`../std-lib/store.md`](../std-lib/store.md) (subtree objects,
aliases, substrates, CSRP, named remotes) ·
[`../core/code-identity.md`](../core/code-identity.md) (Tier-2) ·
[`../std-lib/did.md`](../std-lib/did.md) /
[`vc.md`](../std-lib/vc.md) (identity, credentials, delegation).
