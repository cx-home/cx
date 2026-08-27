# Store management console — a XAP that manages cx store deployments

**Status:** APPROVED (G3 granted 2026-07-07, see §status history below; status line trued 2026-08-20 at the SPR-1 reshape — the file already lived in 03-approved). Owner decisions locked 2026-07-06: free/paid line =
single-daemon-free/estate-paid; token bootstrap = CLI helper + console flow,
one stanza format; delivery surface = served-web XAP; repo =
`cx-home/xap-store-console`, private; claim→role convention accepted).
Companion issue: cx-private#249.
**Depends on:** the store admin plane (shipped — CSRP `status`/`gc`/`mounts`/
`config-reload`, cx-private#248/#251), the XAP feature distribution & market
spec (`xap_feature_distribution_market.md`), the service-tier Phase-2 spec
(`cxstore_service_tier_phase2.md`), and the CSRP protocol spec
(`cxstore-remote-protocol.md`).
**Wire-transition note (stream 4, #676):** CSRP retires at the parity gate —
the console's wire becomes the **XSP store profile** (store.md §6.4), its
credentials become XSP-AUTH principals + VC-compiled capabilities, and every
CSRP op named in this spec maps verb-for-verb onto profile ops (the
admin-plane names are unchanged). Read this document's CSRP references
through that mapping; the console migrates with the other consumers before
the CSRP data plane is removed.
**Bootstrap-retirement note (cx-private#968):** the CSRP wire came out at
the stream-4 S3 demolition, and the `cx store-token` half of the §4.5
token bootstrap came out with it — the verb is deleted and the `[auth …]`
config section it wrote for is a hard config error. The 2026-07-06 owner
lock below records what was decided for the CSRP world; it is not a
description of the shipped surface. §4.5 is rewritten against the
successor-bootstrap ruling, which is under design as cx-private#969.
**Delivers:** a separate project — one XAP whose features (free + paid) manage
`cx store-serve` deployments. This spec is the project's contract; the
implementation repo is bootstrapped from it.

---

## §1. Architectural position (settled direction, restated normatively)

1. **The console is a standalone XAP that connects in.** It speaks CSRP
   (`cx-store://` / `cx-store+https://`, optionally `cx-store+grpc://`) to
   `cx store-serve` instances using role-scoped credentials. It is NEVER
   embedded in the daemon; the daemon remains a headless operations shell with
   no UI, no assets, no console-private endpoints.
2. **Everything the console needs is a public, RBAC-gated CSRP op.** The
   console is the proof that the management API is complete: any capability it
   cannot build from the public wire is a daemon API gap to be filed and
   spec'd (as #248/#251 were), never a side channel.
3. **The console is written in CX and distributed via the market model** —
   its features are sealed/signed feature packages (kind `feature`, plus
   `library` packages for shared client code), published to a registry,
   entitled via VC shapes. The console dogfoods the platform it is sold on.
4. **The console adds no trust.** Every authorization decision is the
   daemon's (RBAC + tenant, server-side). The console's own governance (which
   operator may use which console feature) is the ordinary XAP PEP; the two
   layers never substitute for each other.

## §2. Feature decomposition

Each row is one feature package (own grammar, own `needs`, independently
installable/entitled). Names are the package names.

| Feature | Grammar sketch (nouns / verbs) | Daemon surface consumed | Daemon role |
|---|---|---|---|
| `store-connect` | `daemon`, `credential`; `add-daemon` (act), `remove-daemon` (act), `probe` (observe) | `capabilities`, `health`, `ready` | none (bootstrap ops are unauthenticated) |
| `store-health` | `daemon`, `probe`; `watch` (observe) | `health`, `ready`, `capabilities` | none |
| `store-metrics` | `series`, `scrape`; `view` (observe) | `GET /metrics` | `metrics` |
| `store-status` | `store`, `economy`; `inspect` (observe) | `status`, `mounts`, per-store `capabilities` | `admin` |
| `store-browse` | `doc`, `query`, `alias`; `list`/`get`/`query` (observe) | data plane: `list`, `iter`, `get`, `query` | `reader` |
| `store-maintain` | `gc-run`, `schedule`; `run-gc` (act), `schedule-gc` (act) | `gc` | `admin` |
| `store-reload` | `config-generation`; `trigger-reload` (act) | `config-reload` | `admin` |
| `store-fleet` | `fleet`, `member`; `define-fleet` (act), `sweep` (observe, fans out any observe verb fleet-wide) | all of the above, ×N daemons | per-member credential |
| `store-tenants` | `tenant`, `grant`; `inspect-tenants` (observe), `draft-token` (act — emits config stanzas, §5.4) | `mounts` (tenant-filtered), `status` | `admin` |
| `store-audit` | `request-record`; `explore` (observe) | structured request logs (file/OTel-collector source adapter — NOT a daemon wire op) | n/a (log transport) |
| `store-alerts` | `rule`, `alert`; `define-rule` (act), `watch` (observe) | `/metrics` + `ready` polling | `metrics` |
| `store-query-console` | `saved-query`, `result`; `run` (observe), `save` (act) | `query` (pushdown), `capabilities` (feature detect) | `reader` |

Notes, each load-bearing:

- **Least privilege is per-feature** (§5.1): `store-browse` functions with a
  `reader` credential alone; installing only free features never requires
  handing the console an `admin` token.
- **`store-audit` consumes logs, not a wire op.** The daemon's structured
  request logs (service-tier observability appendix) reach the console via a
  source adapter (file tail, OTel collector). Defining a log-shipping wire op
  on the daemon is explicitly out of scope (it would re-invent the collector).
- **`store-fleet` is composition, not new plumbing:** a fleet definition
  document (§6.3) + fan-out of the single-daemon verbs. This is why it can be
  a paid feature without forking any free feature's code path.
- **Phase-3 seam:** topology/replication monitoring and capacity planning
  attach as new features (`store-topology`, `store-capacity`) consuming
  whatever admin ops Phase 3 defines. The seam is: new daemon ops → advertised
  in `admin-ops` → new console feature keys on the advert. Nothing here needs
  redesign when Phase 3 lands; the features are named now, built then.

### §2.1. Free / paid line (owner-locked 2026-07-06: single daemon free, estate paid)

The machinery is identical either way (free = gratis VC, market spec §5.1);
the line is a commercial-positioning decision, now locked:

- **FREE tier:** `store-connect`, `store-health`, `store-metrics`,
  `store-status`, `store-browse`, `store-reload`, and `store-maintain`
  restricted to immediate `run-gc`. A solo operator gets a genuinely
  complete single-daemon console at no cost — which both drives adoption and
  keeps the "console proves the daemon API" loop free.
- **PAID tier:** `store-fleet`, `store-tenants`, `store-audit`,
  `store-alerts`, `store-query-console`, `store-maintain` scheduling, and
  the entire Phase-3 tier (`store-topology`, `store-capacity`) when it
  lands. Everything whose value scales with deployment size — fleets,
  tenants, audit, alerting, scheduling — is paid.
- The line is legible in one sentence — "one daemon free; operating an
  estate is paid" — and each paid feature has a natural free teaser beside
  it (status free → audit explorer paid; run-gc free → gc scheduling paid).
- Rejected alternatives, recorded: *observe-free/act-paid* paywalls
  single-daemon basics operators expect gratis and starves the act paths of
  real-world exercise; *everything-free-until-Phase-3* ships the market's
  entitlement pipeline unexercised by its own first product.

## §3. Commerce & entitlement

Everything here is the market spec applied; nothing console-specific is
invented.

- **Licensing/purchase/verification** ride the market XAP: catalog listing →
  `commerce` order/settlement → `issue-license` → entitlement VC. Free
  features ship with gratis VCs (trial/free-tier shape) — free is not a
  special case, so the pipeline is exercised by every install.
- **Entitlement check location:** enable-time PEP check in the CONSUMING XAP
  (the console instance), per the market spec — client-side feature gating in
  the UI is a courtesy reflection of entitlement state, never the
  enforcement point.
- **Offline / air-gapped:** VCs verify offline by construction. Paid
  subscription features follow the short-lived-VC + grace-window shape;
  perpetual licenses (one-time shape) never phone home. An air-gapped fleet
  imports packages + VCs through its own internal registry (git-repo-as-
  registry, market spec §4.1) — the console must not assume public-market
  reachability at runtime, only at acquisition.
- **Pricing lives in the catalog, never in packages** (market spec). This
  spec therefore fixes the FEATURE SET per tier (§2.1), not prices.

## §4. Security model

### §4.1. Credentials per daemon, scoped per feature

- The console holds, per configured daemon, one or more named credentials
  (static token or SSO login), each tagged with the daemon roles it carries.
  A feature requests a connection BY ROLE (`store-browse` asks for `reader`);
  the connect layer picks the least-privileged matching credential — an
  `admin` token is never used where a `reader` one suffices.
- **Storage:** credentials at rest in the console's own store, sealed with
  the store encryption layer (`encrypt-key-id`, the shipped at-rest
  machinery); the KEK comes from the operator's platform keychain/KMS via the
  existing key-source seam. Secrets never appear in fleet definition
  documents (§6.3), exports, or journals — journaled intents reference
  credentials by name.
- **TLS:** `cx-store+https://` with verification ON is the default posture;
  accepting a self-signed daemon cert is an explicit per-daemon operator
  choice, journaled, and re-prompted when the pinned fingerprint changes.
  mTLS client identity is deferred until the daemon advertises mTLS
  (`[auth [mtls true]]` — currently always false; the console keys on the
  advert, not on this spec).

### §4.2. Tenant boundaries

A tenant-scoped operator configures the console with their tenant-scoped
credential and simply SEES less — `mounts` returns their tenant's stores,
`status`/`gc`/data ops 403 outside it. The console renders what the daemon
returns and MUST NOT cache-and-merge across credentials in any view that a
lesser credential can open (no cross-tenant bleed through shared client-side
state; per-credential cache partitions).

### §4.3. SSO login (OIDC authorization-code + PKCE)

The daemon side is already built and stays untouched: `[oidc issuer=…
audience=… roles-claim=… tenant-claim=… cache-ttl=…]` makes the daemon a pure
resource server validating Bearer JWTs (discovery + JWKS TTL cache). The
console owns the interactive flow:

- Authorization-code + PKCE against the IdP (console-side config per daemon
  or per fleet: client-id, redirect URI, scopes). The resulting access token
  is presented as the CSRP Bearer credential; roles/tenant arrive via the
  daemon's claim mapping. Refresh tokens live in the encrypted credential
  store (§4.1); access tokens are memory-only.
- The redirect URI targets the console's own served-web surface (§6.1) —
  `https://<console-host>/oidc/callback`; for a terminal/native surface the
  loopback-redirect pattern applies. No IdP secrets are required (public
  client + PKCE).
- **Claim→role mapping convention (settles the Phase-2 open item):** the
  daemon's `roles-claim` (default `roles`) yields the daemon-role strings
  verbatim (`reader`/`writer`/`admin`/`metrics`); `tenant-claim` (default
  `tenant`) yields the space-separated store-name spec, `*` for all. IdP
  groups map to these values IN THE IdP (group→claim mapping is IdP
  configuration, not daemon or console code). The console documents the
  recipe per major IdP; the daemon spec carries this convention as normative
  wording (its §3.1, since this spec's G3).

### §4.4. Open dev mode (no `[auth]`) — first-class, loudly marked

An absent/empty `[auth]` section runs the daemon open: anonymous full access,
deny-by-default the moment any provider appears, and deliberately NO default
credentials — no admin/admin, ever. The console mirrors this honestly:

- Connecting to an open daemon requires no credential prompt and works fully.
- Every view over an open daemon carries a persistent, non-dismissable
  "UNSECURED DAEMON — anyone who can reach this address has full access"
  marker, and the connect flow offers the secure-setup path (§4.5) as the
  primary action, connect-anyway as the secondary.

### §4.5. Token bootstrap (owner-locked 2026-07-06: CLI helper + console flow, one stanza format)

**SUPERSEDED — read with the bootstrap-retirement note above.** The
mechanism this section specifies is CSRP-era: bearer tokens, `sha256:`
secret-hashes, and the `[static [token …]]` stanza all went out with the
CSRP bearer/RBAC plane. Under XSP-AUTH a principal is an ed25519 DID
(`xsp-did` / `xsp-seed-env` open-opts) and `[xsp [grants …]]` is the only
grant table ([`cxstore-grpc.md`](cxstore-grpc.md) §4); no shipped verb mints
a seed or emits a `[grants …]` stanza, so a deny-by-default daemon is
provisioned out of band today. The text below stands as the record of the
2026-07-06 owner lock — the print-once posture and the one-stanza-shape
constraint are the parts the successor design (cx-private#969) is expected
to carry forward.

Operators must not hand-roll `sha256:` secret-hashes. Both halves were
specified to ship, and both emit the SAME stanza shape — one documented
recipe:

- **CLI helper (daemon-side, cx-private) — RETIRED:**
  `cx store-token --id ops --roles admin --tenant '*'` generated a
  cryptographically-random token, printed the ready-to-paste
  `[static [token id=… secret-hash="sha256:…" roles=… tenant=…]]` stanza on
  stdout, and showed the SECRET once on stderr (so the stanza could be piped
  into a config while the secret went to the operator's eyes). It was the
  ONLY daemon-side code this spec introduced — optional sugar, not API — and
  it was deleted with the CSRP plane. The claim it backed, *"the daemon
  stays securable without a console"*, is currently unmet: that is the gap
  cx-private#969 exists to close.
- **Console flow (`store-connect`):** the guided first-secured-setup runs
  the same generation client-side, hands the operator the identical stanza
  to place in the config file, then triggers `config-reload` through an
  existing admin credential — or, for the very first token on an open
  daemon, instructs the one restart that flips it to deny-by-default.
- The generated secret is shown once and never stored by either generator;
  the config file carries only the hash (existing daemon posture).
- Rejected alternatives, recorded: *CLI-only* leaves the console's front
  door displaying instructions instead of removing the friction; *console-
  only* leaves headless deployments hand-rolling hashes.

## §5. Connectivity & API dependency

- **Hard dependency (shipped):** the #248/#251 admin plane — `status`, `gc`,
  `mounts`, `config-reload` — plus the data plane, `health`/`ready`,
  `/metrics`, and `capabilities`. No unshipped daemon work blocks the console.
- **Capability-driven degradation is mandatory.** The server-level
  `capabilities` advert carries `admin-ops` (the op names the daemon routes)
  and `csrp-version`. Console features MUST key their availability on the
  advert: a feature whose ops are absent renders as "not supported by this
  daemon (upgrade to ≥X)" — never a raw 404 surfaced to the operator, and
  never a probe-for-404 discovery loop. Same-major version validation is the
  client library's existing behavior; the console surfaces its CXER1100
  verdict as an actionable connect error.
- **Transports:** `cx-store+https://` is the reference path; `+grpc` is
  supported wherever the client library supports it (feature parity is the
  daemon's cross-transport guarantee, not console code).

## §6. Delivery & UI surface

### §6.1. Surface (owner-locked 2026-07-06: served-web XAP)

The console XAP serves a web client — the served-web HTMX pattern proven by
the original external reference instance's web client: server-rendered CX →
hypermedia, the client's control vocabulary projected from the composed
grammar. One deliverable reaches every operator
with a browser (including on-daemon-host via SSH tunnel), it reuses the only
client-materializer pattern that exists and is battle-tested today (marine
stage-1), and the OIDC authorization-code + PKCE redirect (§4.3) needs an
HTTP surface anyway.

The XAP itself stays surface-agnostic (grammar-first): terminal and native
materializers remain open as later additions per the client-platforms design
issue — rejected only as the FIRST surface (terminal cannot host the OIDC
redirect cleanly or render dashboards; native is the most expensive start
and blocked on the two-track client strategy).

### §6.2. Repo boundary

The user directive is a separate project. Boundary:

- **New repo (`cx-home/xap-store-console`):** the console XAP — feature
  packages (§2), its registry (git-repo-as-registry, marine-pattern: own
  trust domain, publish-by-PR), web-client materializer, project docs.
- **Stays in cx-private:** the daemon, the CSRP/service-tier specs, THIS spec
  (the contract), and the daemon-side conformance suite. The daemon's wire
  behavior is asserted where the daemon lives; the console repo asserts
  console behavior against a released daemon binary, never against daemon
  internals.
- The console repo pins the daemon version it targets (min `csrp-version` +
  required `admin-ops` set) in one place, consumed by its conformance gate.

### §6.3. Fleet definition

A CX document (`fleet.cxd`, schema in the console repo) enumerating daemons:
name, base URL, transport, TLS posture (verify / pinned fingerprint),
credential NAMES (never secrets, §4.1), tags. It is data (queryable,
versionable, journal-referenced); `store-fleet` verbs operate over it.

## §7. Conformance & process

- **Fixture-first, two suites:** (1) daemon-side (cx-private, exists) — the
  wire contract; (2) console-side (console repo) — each feature's acceptance
  fixtures run against a REFERENCE DAEMON (a released `cx` binary spawned by
  the harness: open-mode, static-auth, and tenant-scoped configurations),
  plus degradation fixtures against a stub server advertising REDUCED
  `admin-ops`/versions (the §5 mandate is testable, so it is tested).
- **Marine stage-1 conventions carry over verbatim:** sealed/signed packages,
  registry publish-by-PR, `xap.cxd` as hash-pinned lockfile, stage-1 check
  gate (pins⇄registry⇄tree agreement, re-host invariance, W-gate-clean,
  deterministic compose).
- **Spec pipeline:** owner reviewed and locked the staged decisions (§2.1,
  §4.5, §6.1, §6.2, the §4.3 claim→role convention) on 2026-07-06 →
  02-working; **G3 to 03-approved granted 2026-07-07** (gate condition met:
  the free tier was built and conforms against it). Build order inside the
  console repo:
  `store-connect` → free tier → market/entitlement wiring → paid tier.

## §8. Non-goals

- Embedding any UI or asset-serving in `cx store-serve`.
- Runtime daemon config MUTATION — the console never writes daemon config.
  It may TRIGGER the narrow reload (`config-reload`) and it may EMIT config
  stanzas for the operator to apply (§4.5); the config file remains the
  operator's, on the daemon host, under their change control.
- A log-shipping wire op on the daemon (§2 — `store-audit` consumes logs via
  collector/file adapters).
- Phase-3 (multi-node) features — seam named (§2), built when Phase 3 lands.
- New daemon endpoints of any kind. (The retired §4.5 `cx store-token` CLI
  helper was a local generator subcommand, not an endpoint; whatever
  cx-private#969 rules must satisfy the same non-goal.)

## §9. Dependencies

- cx-private#248 (admin plane — SHIPPED) and #251 (config reload — SHIPPED):
  the complete daemon surface this spec consumes.
- `xap_feature_distribution_market.md` (03-approved/xap): packages, registry,
  entitlement VCs, commerce.
- `cxstore_service_tier_phase2.md` + `cxstore-remote-protocol.md`: the wire
  contract, RBAC/tenant model, `admin-ops` advert, reload semantics.
- The external reference instance's stage-1 conversion (tracked on that
  project's own tracker): the conventions and the served-web materializer
  pattern §6.1(a) reuses.
