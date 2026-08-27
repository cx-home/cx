# CX Store, service tier — the production daemon

`cx store-serve` runs the single-node CXStore service: a purpose-built,
multi-threaded daemon serving the **same** API, wire format, and
content-addressing as the embedded store — it adds the operational layer,
no storage smarts. Governing specs: the CXStore service-tier spec
(`spec/03-approved/misc/cxstore_service_tier_phase2.md`) and the store wire
itself, the XSP store profile (`spec/03-approved/xap/xsp_store_profile.md`);
the optional gRPC edge is `spec/03-approved/misc/cxstore-grpc.md`. Deploy
artifacts live in `tooling/cxstore/` (README, `cxstore.service` systemd unit,
`Dockerfile`, sample config).

## Two listeners: a bootstrap port and the store wire

`[bind addr=…]` is **required** and is a **bootstrap-only** HTTP surface:
`health`, `ready`, `capabilities` under `/cx-store/v1/`, plus a daemon-level
`/metrics`. It carries no store operations — any other path answers 404
`CXER1709` naming the profile as the wire.

The data wire is the **XSP store profile** on its own listener
(`[xsp enabled=true addr=…]`), with an optional gRPC edge
(`[grpc enabled=true addr=…]`) for non-CX integrations. All three addresses
must differ, and `[xsp enabled=true]` requires an `[identity did= seed-env=]`:
attach is XSP-AUTH and there is no anonymous responder.

## Run it (verified end-to-end)

The bootstrap surface alone — enough for orchestration probes, not yet a
store wire:

```sh
PORT=18761
printf '[cxstore-service [bind addr="127.0.0.1:%s"]
  [stores [store name="docs" url="mem://docs"]]]' "$PORT" > svc.cx
cx store-serve --config svc.cx --allow-net=127.0.0.1:$PORT &

curl -s http://127.0.0.1:$PORT/cx-store/v1/health   # [health [status "ok"]]
curl -s http://127.0.0.1:$PORT/cx-store/v1/ready    # [ready [accepting true] [draining false]]
cx store-health --url http://127.0.0.1:$PORT/cx-store/v1/ready && echo READY
kill -TERM %1    # graceful: stop accepting, drain bounded, checkpoint, exit 0
```

`capabilities` is the discovery advert: `csrp-version`, `server-impl`,
`config-generation`, encodings, the `admin-ops` this daemon routes, the
request/response size caps and the rate limit — and, when the profile
listener is up, `[xsp [addr …] [did …]]`, so a management client learns the
store wire's address and responder DID from the bootstrap port instead of
being configured with them twice. No `[auth …]` block appears in the advert;
it retired with the bearer plane.

One daemon mounts many named stores; each mount is any embedded substrate URL
(`file://`, `sqlite://`, `s3://`, …). Config is a CX document, validated
**attr-exact** at startup — an unknown attribute is a startup error, never a
silent drop (`CXER1711`). Full schema: the service-tier spec's config
appendix.

## Clean-state bootstrap — mint, grant, serve, present

Store credentials are **XSP-AUTH principals**: an Ed25519 `did:key` whose
seed the holder proves possession of per attach. `[xsp [grants …]]` is the
only grant table, and a non-empty table means **deny-by-default** — the
daemon admits exactly the DIDs written into its config and refuses every
other principal.

That leaves one question a fresh deployment has to answer: where does the
*first* principal come from? `cx store-mint-principal` (platform profile)
answers it offline — it generates the seed and derives the DID locally,
touching no network and no store. Minting grants nothing; the config is
still the sole authority.

**1 — Mint the principal.** The seed lands in a `0600` file and is never
printed. `--caps` is required — the authority a grant carries is stated at
mint time, never inherited from a default:

```sh
cx store-mint-principal --id ops --seed-file ./ops.seed --caps "read write admin"
```

stdout is one canonical CX element, so it is machine-readable as well as
copy-paste-able:

```cx
[xsp-principal id=ops for=grant did=did:key:z6Mk… seed-file='./ops.seed' seed-env=CX_XSP_SEED_OPS
  [config-stanza [xsp [grants [grant did=did:key:z6Mk… caps='read write admin']]]]
  [client-opts [map xsp-did=did:key:z6Mk… xsp-seed-env=CX_XSP_SEED_OPS]]]
```

(Canonical CX quotes bare-when-unsafe, so the DIDs print unquoted and the
space-separated `caps` does not; it is one line in practice, wrapped here.)

Operator guidance goes to stderr. Back the seed file up — it is the only
proof of that DID, and a lost seed means re-minting and re-granting.
Re-running the verb against an existing `--seed-file` is refused; `--force`
replaces it and invalidates the old DID.

`--id` must be the canonical spelling of the env var it derives —
lowercase, `-` for word breaks. `CX_XSP_SEED_<NAME>` upper-cases and folds
`-` to `_`, so `fleet_ops` and `Fleet-Ops` would derive the same
`CX_XSP_SEED_FLEET_OPS` as `fleet-ops`; two principals minted under two
spellings would silently share one seed variable. The verb refuses the
non-canonical spellings, naming both the id to use and the variable they
would have shared.

**2 — Mint the daemon's own identity.** Attach is XSP-AUTH in both
directions: the daemon needs a responder identity of its own
(`[xsp [identity did= seed-env=]]`). Same verb, `--for identity` — and no
`--caps`, because the daemon's identity is the root of its authority rather
than a grantee:

```sh
cx store-mint-principal --id host --seed-file ./host.seed --for identity
```

```cx
[xsp-principal id=host for=identity did=did:key:z6MkHost… seed-file='./host.seed' seed-env=CX_XSP_SEED_HOST
  [config-stanza [xsp [identity did=did:key:z6MkHost… seed-env=CX_XSP_SEED_HOST]]]
  [client-opts [map xsp-did=did:key:z6MkHost… xsp-seed-env=CX_XSP_SEED_HOST]]]
```

**3 — Assemble the config.** Both `[config-stanza]` bodies splice into the
same `[xsp …]` section verbatim — the identity row from step 2, the grant
row from step 1:

```cx
[cxstore-service
  [bind addr="127.0.0.1:18761"]
  [stores [store name="main" url="file:///var/lib/cxstore/main"]]
  [xsp enabled=true addr="127.0.0.1:18762"
    [identity did="did:key:z6MkHost…" seed-env="CX_XSP_SEED_HOST"]
    [grants [grant did="did:key:z6Mk…" caps="read write admin"]]]]
```

(The fabric daemon takes the same `[identity did= seed-env=]` row at its own
top level.)

**4 — Serve.** The daemon resolves `seed-env` while parsing the config, so
the host seed must be exported *before* it starts. With grants present the
daemon is deny-by-default from the first attach; no separate switch turns
enforcement on:

```sh
export CX_XSP_SEED_HOST="$(cat ./host.seed)"
cx store-serve --config cxstore.service.cx \
  --allow-read --allow-write --allow-env \
  --allow-net=127.0.0.1:18761 --allow-net=127.0.0.1:18762
```

The startup line says which posture it came up in — `auth ENFORCED
(XSP-AUTH, N grant(s))` with a grant table, `auth OPEN — no
[xsp [grants …]] configured, anonymous full access` without one. Read it
on every deploy; it is the daemon's own answer, not an inference from the
config file you think you shipped.

**5 — Present the identity.** The client loads the seed from the
environment (never from the URL, never from an opts literal) and passes the
`[client-opts]` map verbatim:

```sh
export CX_XSP_SEED_OPS="$(cat ./ops.seed)"
```

```cx
[?lib 'cx-stdlib/store' :as store]
[?let [= $c [$store:open-opts "cx-store+xsp://127.0.0.1:18762/main/"
              [map xsp-did="did:key:z6Mk…" xsp-seed-env="CX_XSP_SEED_OPS"]]]
 [$store:put-doc $c [note [body "first write"]]]]
```

A principal that was never granted is an equally well-formed identity and is
still refused: the daemon rejects the op and the client raises `CXER1131`
(`E_STORE_AUTH_FAILED`) naming the rejected wire op. Deny-by-default is a
property of the config, not of the credential's cryptographic quality.

## Talking to it from CX — the same store API

Past the handle, the client API is identical to embedded: `put-doc`,
`get-doc`, `query`, the porcelain, all of it. Only the open URL differs.

| Scheme | Transport |
|---|---|
| `cx-store://host:port/name/` | the XSP store profile over TLS — **the** store wire |
| `cx-store+xsp://host:port/name/` | the cleartext sibling: loopback / dev |
| `cx-store+grpc://` / `cx-store+grpcs://` | the gRPC edge (h2c / TLS) — the integration transport for non-CX callers |

Two rules the URL enforces rather than documents:

- The **port is required** on `cx-store(+xsp)://` — the profile listener has
  no registered default, so a portless URL refuses at open rather than
  dialing something arbitrary.
- The URL carries **no userinfo**. A `user@host` authority refuses with
  `CXER1100`; client identity rides the `xsp-did` / `xsp-seed-env` open-opts
  and the seed always comes from the environment.

`cx-store+http://` and `cx-store+https://` were the CSRP data plane's schemes
and are **retired** — opening one refuses with `CXER1100`
(`E_STORE_UNRESOLVED_BACKEND`) naming the replacements. Cutover, no
dual-accept window.

Python/Go/Rust `CxStoreClient` wrappers drive this same client through the
C-ABI — one source of protocol truth, cross-binding hash parity by
construction, and a `cx-store+grpc://` URL routes them over gRPC through that
same one implementation (the client-libraries section of the service-tier
spec).

## Authority — XSP-AUTH, one grant table

There is exactly one authority model, shared by the profile listener and the
gRPC edge with no second implementation. `[xsp [grants …]]` is the **only**
grant table; the CSRP-era `[auth …]` section — static tokens, JWT, OIDC,
role bundles, the Bearer base — is a **hard config error** that names the
replacement, never a silently ignored stanza.

- **Grants compile to delegations.** Each `[grant did="…" caps="…" over=?]`
  becomes an ordinary delegation in the session's authority basis at attach,
  so one decision function governs every verb — attenuation, revocation and
  explain come for free rather than as a parallel RBAC engine.
- **The shipped capability grammar** is `read`, `write`, `delete`, `admin`,
  `peer`. An unrecognized capability is a startup error listing the accepted
  set. `over="/path"` slices a grant to a subtree; `[grant floor=true
  caps="read"]` is the anonymous floor (paired with
  `[xsp [policy mode=floor floor=NAME]]`). `admin` is the class that carries
  `status`, `gc`, `mounts` and `config-reload`; `peer` is deliberately
  narrower than `read` — a peer daemon receives revocations without holding
  read on any data plane.
- **Posture follows the table's presence.** Grants configured ⇒
  deny-by-default, every verb PEP-checked and the PEP's `[deny …]` value
  crossing the wire verbatim. No grants ⇒ the open dev posture: data verbs
  open, the daemon-level admin verbs still requiring a DID-proven principal.
  Absent = open dev mode, present = enforced; there is no third switch.
- **Delegation and presentation.** A client may attenuate its authority
  further by presenting a VC chain (`[vp …]` on attach or a later
  `phase=present`), whose terminal subject must be the session principal
  byte-for-byte. Escalation on any of the four axes refuses; a root issuer
  this deployment does not recognize compiles to nothing rather than
  conjuring authority. Revocation is live: a credential from a revoked chain
  stops verifying at its next use.
- **Client identity never rides the wire URL or a literal.** `xsp-did` names
  the DID, `xsp-seed-env` names the environment variable holding the seed.

Grammar and refusal codes: the profile spec's listener-model section and the
gRPC spec's `spec/03-approved/misc/cxstore-grpc.md` §4, which share one
authority calculus.

## Mounts and tenant scoping

Tenancy is **store-per-tenant**: one daemon mounts many named stores, an
attach names the mount it wants, and each mount owns a separate dedup pool —
cryptographic isolation by construction (a shared pool would be an existence
oracle; the tenancy section of the service-tier spec explains the rejection).
Scoping rides the authority basis rather than a principal-to-store-name list:
a grant, and any delegation attenuated from it, is bound to its mount, and a
cross-tenant delegation is a fault rather than something that quietly
compiles to nothing. Intra-store tenancy, quotas, and multi-node are the
demand-gated next phase — **not implemented**.

## Observability

- `GET /metrics` — Prometheus exposition on the bootstrap port,
  **unauthenticated operator-plane**: the bind address is the operator's
  control, and a standard scraper cannot sign a request. It is not exempt
  from admission control — the global pre-auth bucket covers it, so a scrape
  flood cannot force unbounded work. Bounded cardinality by construction
  (labels: endpoint, status, store — never per-hash). Request
  counters/histograms/bytes, in-flight gauge, per-store doc/object/dedup
  gauges. No fabricated zeros: store-internal series attach only when the
  backend instruments them.
- **OpenTelemetry tracing** — off by default; W3C trace-context propagated
  either way so logs correlate; OTLP/HTTP export when enabled.
- **Structured logs** — one record per bootstrap-surface request (endpoint,
  store, status, latency, bytes in/out, `principal-role`, trace id), CX or
  JSON format; health/ready probe logs are suppressed as probe noise.
  `principal-role` reads `anon` here: the bootstrap port has no principal,
  and the field survives as the shape a log consumer already parses. The
  record carries no credential material, and the startup banner redacts the
  userinfo of any mount URL that has one (an `ftp://user:pass@…` substrate)
  rather than printing it.

## Lifecycle

- **systemd**: `Type=notify` unit ships in `tooling/cxstore/` — `READY=1`
  after bind + store-open, watchdog pings, `SIGTERM` = graceful drain,
  `ExecReload` = `SIGHUP`.
- **Docker**: minimal image; `HEALTHCHECK` runs `cx store-health` against
  `/ready`.
- **Graceful shutdown**: readiness flips false immediately but listeners
  stay open for a drain grace so LB probes observe `[ready [accepting
  false]]` (data ops get 503 + Retry-After); in-flight requests drain
  bounded; a second signal forces exit.
- **Runtime config reload** (SIGHUP or the admin-gated `config-reload` op):
  validate-then-swap, all-or-nothing, fail-closed. Hot: `[tls]` (cert/key
  *contents*, so rotation works without a restart), `[timeouts]`,
  `[limits]`, `[observability]`, and `[xsp [grants …]]`.
  Restart-required: `[bind]`, `[grpc]`, `[stores]`, `[workers]`, and every
  part of `[xsp]` other than `[grants]` (`addr`, `[identity]`, `[policy]`,
  `[limits]`, `[peers]`, `[revocations]`) — a change there refuses the whole
  reload with `CXER1712` naming the offenders. Env-injected secrets are
  rotation-blind — use file-based sources to rotate.
- **Revoking a principal** is a `[xsp [grants …]]` edit plus `SIGHUP`, and it
  is **live**: the reload re-folds the grant table into every session already
  attached, so the revoked principal is refused at its very next call rather
  than at the next restart. Revocation reaches delegated authority too — a
  credential presented by that principal only ever conveyed authority through
  the config grant it was rooted in, so dropping the grant breaks the chain.
  The gRPC edge compiles its basis per call and picks the change up the same
  way. A live session's authority only ever **narrows** on reload: if you
  remove every grant, already-attached sessions keep enforcing (they must
  re-attach to pick up the open posture).

## gRPC

An opt-in second listener (`[grpc enabled=true addr=…]`) offering the same
operation set with **normative parity** — same semantics, same error codes;
server-streaming for `iter`/large query. It synthesizes internal
profile-pipeline ops rather than carrying a second copy of the request logic,
and authenticates **per call**: the `authorization` metadata header carries a
`CxCall` credential signed by the presenting DID over the exact method path,
the exact request bytes, a timestamp inside a freshness window and a
single-use nonce. Same `[xsp [grants …]]` table, same PEP. The gRPC edge is
the integration transport; CX-to-CX deployments use `cx-store://`. Spec:
`spec/03-approved/misc/cxstore-grpc.md`.

## Backpressure and DoS fairness (default-on)

The bootstrap surface and the gRPC edge run a token-bucket rate limit plus a
concurrency cap keyed on the **resolved store name** — tenant-level
backpressure (the per-principal key retired with the bearer plane) — behind a
global pre-auth bucket covering unauthenticated traffic. Every admission
rejection is `429 CXER1706` with `Retry-After`; draining/not-ready is `503
CXER1708`.

The profile listener carries its own flow control instead:
`[xsp [limits pending-window= liveness-ms= handshake-ms= max-frame-bytes=]]`,
and `[xsp [limits [pushdown steps= memory-mb=]]]` budgets daemon-side
evaluation for the compute-class verbs — an exhausted budget is a loud typed
refusal, never a daemon takedown.
