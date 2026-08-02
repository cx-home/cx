# CXStore — Phase 2: Single-Node Production Service Tier (#105)

**Status:** **03-approved** (graduated by owner ruling 2026-07-22; sub-areas
had landed via owner-merged PRs with the as-built state recorded in
Appendices E/F — the umbrella graduation completes that record).
**Coordinates:** #105 (Phase 2), under #75. Builds on the **permanent** CSRP protocol
([`spec/03-approved/misc/cxstore-remote-protocol.md`](cxstore-remote-protocol.md),
#78 — landed) and the Phase-1 embedded engine (PR #102/#104). Phase 3 (multi-node
distributed) is **demand-gated** and out of scope here ([`plan.md`](../../../docs-src/canonical/cxstore/plan.md) §Phases).

> Spec-first draft. Sub-areas landed implementation via owner-merged PRs
> (each merge = the owner's sub-area approval; the as-built state is recorded
> honestly in Appendices E/F). Graduation of this umbrella document to
> 03-approved remains a pending owner action. Decisions live in this spec;
> open questions for the owner are collected in §9.

---

## 1 — Scope

Phase 2 turns the Phase 0.7 single-node CSRP reference server into a **production-grade,
operable daemon**. It **adds no storage smarts** — same wire format (CSRP), same query
language, same content-addressing, same API surface. It adds the operational layer a
real deployment needs:

1. **Daemon lifecycle** — supervised process, config, health, graceful shutdown (§2).
2. **AuthN/AuthZ** — RBAC + structured auth over CSRP's permanent Bearer base (§3).
3. **Observability** — Prometheus metrics, OpenTelemetry traces, structured logs (§4).
4. **Optional gRPC** alongside CSRP (§5).
5. **Client libraries** — thin, per-binding (§6).

**Non-goals (Phase 3, demand-gated):** multi-node distribution, S3 as a
*service-native storage tier* (a network-metadata service over S3 for multi-node
scale — distinct from the **embedded `s3://` byte-source/object substrate, which
shipped in Phase 0.5** and which a Phase-2 daemon may mount like any other
substrate; `plan.md` states this distinction), FoundationDB metadata, query
planner / worker pool, Kafka ingest, Helm, DR/PITR. Phase 2 **designs seams**
for these (§7) without building them — per `plan.md`'s 2→3 risk notes
("design the storage trait with S3 in mind"; "plan the tenant boundary in
Phase 2's auth model").

**Decision gate after Phase 2** (`plan.md`): real multi-node demand → Phase 3; otherwise
**stop here — single-node production Service is its own product.**

---

## 2 — Daemon lifecycle

### 2.1 Process model & serve architecture
- One server process bound to one host:port, serving CSRP over HTTP/1.1 (TLS recommended,
  plaintext allowed for localhost/sidecar — CSRP §2.1). The server wraps one Embedded
  Store (the Phase-1 engine) per configured store-name; multiple store-names MAY be
  mounted by one process.
- Single-writer discipline per store is inherited from the Embedded engine (#74 op-lock).
  The daemon serializes mutating CSRP ops (`put`/`delete`/`modify`) per store.

**Serve model — daemon-owned, multi-threaded (decided; long-term store-service
architecture).** The daemon runs its **own connection-oriented, multi-threaded serve
loop**, not picoev. A `net` listener accepts connections; each is handed to a **bounded
worker pool** of V threads; a worker runs the existing request primitives end-to-end —
`http_exchange_request_real` (parse) → `svc_handle_request` (dispatch, §brick-4) →
`http_respond_impl` (write). Rationale: the store workload is *connection-oriented* —
fewer, longer-lived clients doing bulk binary transfers + queries — which fits a
thread/worker-pool model, whereas picoev's event loop is optimized for high-count short
web requests. Owning the loop in V makes graceful drain, RBAC, per-tenant scoping, and
observability first-class (a flag checked between accepts; the pool tracks in-flight),
with no fork of the vendored picoev. Concurrency is sound under the default
cooperative-safepoint STW vgc collector (the multi-reactor UAF class that was fixed for
picoev does not re-bite a fresh pool). **picoev remains CX's general HTTP/SSE/web transport
(`[?service]`)** — this is a distinct, purpose-built server for the store tier, not a
replacement of picoev. The pool bound, per-connection read/write timeouts, HTTP keep-alive,
TLS termination, and accept backpressure are first-class requirements of this server (not
deferrable add-ons). Query-time fan-out (store.md §6 worker pool) is an orthogonal axis
(parallelizing one query's scan), composed beneath a worker handling a connection.

### 2.2 Configuration
- A CX config document (`cxstore.service.cx`) is the single source of truth: bind address,
  TLS cert/key paths, mounted stores (name → backend URL), auth provider config (§3),
  observability config (§4), worker-pool sizing, per-connection timeouts (`[timeouts
  read-ms=…]`). **Env-var overrides for secrets** — any config value may be written
  `${env:VAR}` and is resolved from the environment at parse, fast-failing if the var is
  unset; so a TLS key PEM or other secret material is externalized, never inlined (as-built
  #199). A `${env:VAR}`-injected TLS key PEM is parsed in memory (never written to disk).
- Config is validated at startup against a schema; an invalid config fails fast with a
  non-zero exit and a structured diagnostic — **`CXER1711 E_SVC_CONFIG_INVALID`** (a
  service-tier diagnostic code, distinct from the wire codes; #198 — it must NOT reuse
  `CXER1140 E_STORE_HANDLE_RACE`). Validation is attr-exact (an unknown section OR an
  unknown attribute in a known section fails, never a silent drop). No partial serve.

### 2.3 Supervision integration
- **systemd:** ship a `Type=notify` unit template — the daemon signals `READY=1` after the
  bind + store-open succeed, sends `WATCHDOG=1` pings when the unit sets `WatchdogSec`
  (parsed from `WATCHDOG_USEC`, pinged at half-interval from a background thread — as-built
  #181, so the shipped unit no longer kill/restart-loops), and handles `SIGTERM` as graceful
  shutdown. Restart policy `on-failure`.
- **Docker/OCI:** a minimal image (static `cx` binary + entrypoint reading config from a
  mounted path / env). `HEALTHCHECK` hits the readiness endpoint (§2.4).

### 2.4 Health & readiness
- `GET /cx-store/v1/health` (liveness — process is up) and
  `GET /cx-store/v1/ready` (readiness — stores opened, index loaded, accepting traffic).
  Both **unauthenticated** (like `capabilities`), return CX (`[health …]` / `[ready …]`).
- Readiness flips false during graceful drain so a load balancer stops routing.

### 2.5 Graceful shutdown
- On `SIGTERM`/`SIGINT`: stop accepting new connections, flip readiness false, drain
  in-flight requests up to a **bounded deadline** (as-built: `drain_bounded`, 30s, gated on
  the in-flight count via `drain_complete`; the per-connection read deadline keeps handlers
  from stalling), checkpoint (flush) each mounted store, then exit 0. **A second signal
  forces immediate exit** (as-built #186). The gRPC listener drains through the same bounded
  path (#211). Crash-safety is the Embedded engine's append-only ref-log recovery
  (object_model A.4/A.7) + the per-op atomic-rename flush (W1) — no new durability surface.
- **Drain readiness (as built, #233):** on the first signal the daemon flips readiness false
  immediately but KEEPS the listener(s) open for a drain grace (`[timeouts drain-ms=…]`,
  default 5s) — so a load-balancer readiness probe arriving mid-drain connects and observes
  `[ready [accepting false]]` (data ops get `503` + `Retry-After`) and de-routes, before the
  listeners close and in-flight requests drain.

### 2.6 Runtime config reload (#251)

The config is startup-static **except** for an explicitly-classified hot subset; the driver
is credential and TLS-certificate rotation without a restart. Everything here is
validate-then-swap, fail-closed — a failed reload NEVER degrades the running daemon.

- **Hot-reloadable** (Appendix A marks every attr): the `[auth …]` section (static token
  list, JWT/DID/OIDC provider settings), `[limits …]` (applied to the live limiter with
  per-principal bucket/in-flight state preserved — a removed principal is denied by auth
  before the limiter ever sees it), `[observability …]` (log format, OTel toggle/endpoint),
  `[timeouts …]` (picked up by new connections), and the `[tls …]` **certificate/key/CA
  contents** (re-read from their configured sources; new handshakes present the new
  identity, existing TLS sessions are untouched).
- **Restart-required**: `[bind]`, `[grpc]` (enabled/addr), `[stores …]` (mount add/remove/
  modify — deliberately out of scope: live mount mutation drags in per-store in-flight
  drain, handle close, dedup-pool teardown, and encryption-key durability hazards; it stays
  restart-only until a concrete need arrives, as its own issue), and `[workers]`.
- **Triggers** (one shared implementation, one outcome log/metric): `SIGHUP` (host-trust,
  §Appendix B `ExecReload`) and the `admin`-gated CSRP/gRPC `config-reload` op
  (CSRP §3.13 — the op re-reads the daemon's own `--config` path; nothing on the wire
  carries config content, the console *triggers* reload, never *writes* config).
- **Validate-then-swap:** the candidate is fully parsed + cross-validated
  (`parse_service_config`, the same attr-exact §2.2 validation) BEFORE anything applies.
  Validation failure → `CXER1711`, running config untouched. A candidate changing any
  restart-required attr → `CXER1712` naming every offending attr, and the reload is refused
  WHOLE — hot changes riding in the same candidate are not applied (atomic, all-or-nothing).
  Apply = swap of an immutable config snapshot read per-request; in-flight requests finish
  under the config they started with. A no-change reload succeeds (`applied=false`).
- **Secrets:** `${env:VAR}` resolves from the process environment, which CANNOT change
  post-start — env-injected secrets are therefore rotation-blind: a reload re-resolves them
  to the same startup values. Rotating a secret via reload requires a **file-based source**
  (TLS `cert=`/`key=`/`ca=` paths, JWT `key-path=`, static-token `secret-hash` in the config
  file itself) — the file is re-read at reload. Appendix A's table marks which secret attrs
  are file-rotatable.
- **Auth swap semantics:** a token/grant removed by reload → the NEXT request presenting it
  gets `401 CXER1702`; JWKS/did:web caches are rebuilt fresh with the new provider config
  (stale keys never outlive the providers that fetched them).
- **Observability:** one structured log record per reload attempt (trigger, outcome,
  changed subsystems, diagnostic on refusal) + a `cxstore_config_reload_total{outcome}`
  counter (Appendix F.1). Readiness is unaffected by reload.

---

## 3 — Authentication & authorization

CSRP defines the **permanent** transport-level auth: `Authorization: Bearer <token>`,
`401 → CXER1702`, and a `capabilities` advert (`[auth [bearer …] [mtls …] [anonymous …]]`).
Phase 2 layers a **structured authZ model** on top — the protocol is unchanged.

### 3.1 Identities & tokens
A **principal** is derived from a validated credential. All providers share one interface
(`credential → principal`); Phase 2 ships **four** (owner decision 3d):

1. **Static tokens** — config-listed, hashed at rest. Principal = the named service account.
2. **JWT** (configured key) — verify signature + `exp`/`aud`/`iss`. Principal = `sub`.
3. **DID** *(first-class — CX's principal model, XAP §22.1 R9)* — client presents a `did:…`
   plus a JWS signed by the DID's key; the server resolves the DID
   document via `cx-stdlib/did` (`did:key` offline / `did:web` over `cx-stdlib/http`),
   verifies the signature, and sets **principal = the DID**. Reuses the shipping module; no
   central issuer. This is the agentic-principal path (#50/#31). `methods=` restricts the
   accepted DID methods (a `did:` outside the set is rejected); `audience=` binds the
   DID-JWT's `aud` to this service (cross-service replay defense). Nonce challenge-response
   (`challenge=`) is a tracked follow-up — until it lands, `challenge=true` is a fast-fail
   config error (never a silently-inert knob), and audience binding is the replay defense.
4. **OIDC** — discovery (`.well-known/openid-configuration` + JWKS), validate
   `iss`/`aud`/`exp`, key rotation. The enterprise human-SSO bridge. Principal = `sub`.
   **Claim→role mapping (normative, settled at the console spec's G3):** the
   provider's `roles-claim` (default `roles`) yields the daemon-role strings
   **verbatim** (`reader`/`writer`/`admin`/`metrics`); `tenant-claim` (default
   `tenant`) yields the space-separated store-name spec, `*` for all stores.
   IdP groups map to these values IN THE IdP — group→claim mapping is IdP
   configuration, never daemon or console code. The same convention applies to
   the JWT provider's claims.

All four resolve to a `principal` carrying `{id, kind, roles, tenant}`. Optional **mTLS**
(CSRP already advertises `mtls`): client-cert subject → principal.

### 3.2 RBAC model
- **Permissions** are the CSRP operation classes: `read` (`get`/`list`/`iter`/`query`),
  `write` (`put`/`modify`), `delete`, `admin` (capabilities beyond data: store stats,
  compaction trigger). `capabilities`/`health`/`ready` need none.
- **Roles** bundle permissions (`reader`, `writer`, `admin`, plus a metrics-only `metrics`
  scope, §4.1); a principal holds one+ roles.
- Authorization is enforced at the endpoint dispatch (before the store op), mapping a
  denied op to `403 → CXER1703 E_CSRP_FORBIDDEN` (defined in the approved CSRP §4 error
  table; graduated — Appendix E).
- **Deny-by-default**: no role ⇒ only the unauthenticated endpoints.

### 3.3 Tenant boundary — store-per-tenant (owner decision 4a)
Phase 2 **is multi-tenant**, at **store granularity**: one daemon mounts many stores; a
principal is authorized for a set of them — `principal → {allowed store-names}` — and the
`tenant` travels in the auth context (`{id, kind, roles, tenant}`), keyed by the principal's
DID where applicable. Each tenant therefore owns a **separate content-address / dedup pool**
(its own store), giving **cryptographic isolation by construction**.

**Why not many tenants in one shared store (rejected for Phase 2):** content-addressing
dedups identical content globally, so a *shared* dedup pool is an existence oracle — tenant
A could probe `get(hash(X))` to learn tenant B holds document X. Per-key access checks or
per-tenant hash-salting would mitigate it but (a) add a Phase-3-grade security surface to a
single-node release and (b) salting breaks the pure `hash = f(content)` model (Tier-1/Tier-2
identity). Intra-store multi-tenancy + per-tenant quota/isolation is **Phase 3** (multi-node
scale is where "thousands of small tenants on shared infra" belongs anyway). The `tenant`
field is threaded now so Phase 3 is an extension, not a retrofit.

---

## 4 — Observability

### 4.1 Metrics (Prometheus)
- `GET /metrics` (text exposition; auth: a dedicated **`metrics` scrape scope** — a principal
  that can read metrics and nothing else, never `admin`/data — owner decision 6a). Surface:
  the normative catalog is **Appendix F.1** (request counts by endpoint/status/store;
  latency histograms by endpoint/store; bytes in/out; in-flight gauge; per-store doc/object
  gauges and dedup ratio where the backend instruments them). Bounded label cardinality
  (endpoint, status, store-name — **never** per-hash labels). Further store-internal series
  (ref-log length, compaction events) and a worker-pool saturation gauge attach only when
  the engine instruments them (F.1's no-fabricated-zeros rule).

### 4.2 Tracing (OpenTelemetry)
- Each CSRP request is a span (endpoint, store, principal-role, bytes, outcome); store ops
  (hash resolve, index lookup, transport) are child spans. W3C trace-context propagation in
  request headers. Exporter (OTLP endpoint) configured in §2.2; tracing off by default.

### 4.3 Structured logs
- One structured (CX or JSON) log record per request: timestamp, principal (role, not
  token), endpoint, store, status, latency, bytes, trace-id. Secrets never logged.

---

## 5 — gRPC alongside CSRP (in Phase 2 — owner decision 2b)

- CSRP (HTTP/1.1 + CX bodies) remains the **canonical, permanent** interface. gRPC ships in
  Phase 2 as an **opt-in second listener** (enabled in config, §2.2) offering the **same
  operation set** — **parity is normative: no gRPC-only ops, identical semantics + error
  codes**. The `.proto` mirrors the CSRP endpoints 1:1; messages carry the same Layer-1
  binary / CX-text bodies; server-streaming maps `iter`/large `query` results over HTTP/2.
- gRPC auth reuses §3 (Bearer in call metadata / mTLS) and the same RBAC + tenant context.
- **Scope cost (accepted):** a `.proto`, generated stubs per binding, and an op-for-op
  parity test suite against the CSRP fixtures (§8). The gRPC sub-area lands as its own PR
  after daemon + authZ (sequencing 1a).

---

## 6 — Client libraries

- The `cx-store://` client backend already exists (#78) in the V core and is reachable from
  the Python/Go/Rust bindings via the C-ABI. Phase 2's "client libs" = ergonomic per-binding
  wrappers (connect, auth, the CRUD+query surface, streaming `iter`) — **thin over CSRP**,
  no logic duplication. Cross-binding parity (byte-identical hashes, same error codes) is
  already a store conformance requirement (store.md §8) and extends to the service client.

### 6.1 Mechanism (decided — no per-language protocol duplication)

Each binding's `CxStoreClient` is a **thin façade that drives the existing,
audited `cx-store://` client in the V core through the C-ABI eval surface** — it
does **not** re-implement the CSRP wire protocol (HTTP framing, cxd request/
response, hash echo, error mapping) in Python/Go/Rust. Reimplementing it N times
is the explicit anti-pattern §6 forbids (N drift surfaces, N bug sites); routing
through the core keeps a **single source of protocol truth** and makes
cross-binding parity true *by construction* (every binding funnels into the same
V code, so byte-identical hashes + identical CXER codes are automatic).

- **Call path:** a client method builds a one-shot CX program
  (`[?let [= $c [$store:open "cx-store+http://host/store/"]] [$store:<op> $c …]]`)
  and evaluates it via the **capability-aware** entry point
  (`cx_code_eval_caps`), granting `net` **scoped to the configured `host:port`**
  via the `net:host:port` spec form and nothing else (deny-by-default for
  read/write/process/etc.). The scope is enforced (least-privilege — only the
  server host is dialable) and a literal-IP / `localhost` scope overrides the
  §4.5 private-range deny, so a loopback dev/test server is reachable without
  opening the whole net surface. The remote backend is stateless per request
  (each op is one HTTP exchange carrying the URL + bearer), so no handle persists
  across calls.
- **Auth:** the bearer token is carried in the `cx-store://[token@]host/…` URL
  the façade holds; it is never logged and is passed only into the scoped eval.
- **Surface:** `open(url, token)`, `put_doc_text`/`get_doc_text`/`exists`/
  `list_docs`/`delete_doc`/`query`/`iter`, mapped to each language's idioms
  (Python exceptions, Go `(T, error)`, Rust `Result`); CSRP/store CXER codes map
  to the binding's native error type (`CxError{code,message}` and peers).
- **Prereq:** bindings that today expose only the non-caps `cx_code_eval` gain a
  caps-aware wrapper (`eval_code_caps` / equivalent) — additive, no change to the
  existing entry points. The core `caps_apply_spec` now honours `net:host:port`
  host scoping (previously dropped to bare `net`), so the grant is genuinely
  least-privilege for every caps-aware caller.
- **Parity test:** each binding drives put → get → exists → list → delete →
  exists against a **live `cx store-serve`** (the §8 pattern, extending store.md
  §8 cross-binding parity), plus a wrong-token → auth-error case.

---

## 7 — Storage-backend seam (Phase-3-ready, not built)

Per `plan.md`'s 2→3 risk: define the server's store-mount abstraction so a future S3 /
multi-node backend slots in without reshaping Phase 2. Phase 2 implements **local only**
(the Phase-1 pack-backed Embedded Store) but the mount trait MUST express: open by URL,
the `StorageBackend`/capability traits (#76), and a master-index handle that is a local
file now / a network metadata service later. No S3 or FoundationDB code in Phase 2 — only
the seam, reviewed before Phase 3 starts.

### 7.1 As-built seam (Phase 2) vs Phase-3 plug points

The boundary is now pinned against the code that exists, so Phase 3 adds a backend
without reshaping the daemon:

| Seam element | Phase-2 reality | Phase-3 plug point |
|---|---|---|
| **Open-by-URL** | `store_open_impl` (`stdlib_store.v`) dispatches every scheme (`mem`/`file`/`cxpack`/`s3`/`http(s)`/`ftp(s)`/`sftp`/`cx-store`) to a `MemStore` handle; `svc_open_store` opens each configured mount. | An S3 / network-metadata URL parses through the **same** dispatch — no daemon change. |
| **Backend / capability trait** | The `StorageBackend` interface already exists in the Phase-1 engine (`vcx/cxstore/backend.v`: `get/has/list/put`), and the embedded `cxpack` engine implements it. The daemon dispatches store ops through the existing CSRP router over the opened handle. | The daemon's mount table (`map[string]cx.Node` today) becomes a trait-dispatched mount so a non-`MemStore` backend serves ops; capability flags (`read`/`write`/`list`, already carried on the handle) negotiate per-backend support. **This rewire is deliberately deferred** — doing it now would reshape Phase 2 for no local benefit. |
| **Master-index handle** | In-memory `docs` map + a local index/manifest file (`file://` append-log, `cxpack` manifest). | An `IndexService` abstraction (get/put/list metadata) backs the same handle with a network metadata service; the local file is one impl. |
| **Metrics introspection** | ✅ **Built now** — `store_mount_stats(handle) → StoreStats{backend, doc_count, has_object_graph, object_count, logical_objects, distinct_objects}` reads the live backend under its op-lock; the daemon gauges it into `/metrics` as `cxstore_store_docs{store,backend}` (+ the object/dedup gauges for object-graph backends, F.1) at scrape time. Remote-backed mounts are skipped (no local count without a round-trip). | Phase-3 backends provide the same `StoreStats` shape; richer series (dedup ratio, ref-log length, compaction events) attach **when the backend instruments them** — never as fabricated zeros (Appendix F.1). |

**Invariant:** Phase 2 adds **no new storage backend**; a daemon mounts the
substrates the embedded engine already ships (including the Phase-0.5 embedded
`s3://` byte-source/object substrate). The Phase-3 item is S3 as a
*service-native storage tier* (network metadata service, multi-node). The seam
is the abstraction boundary + the metrics hook, not a new backend. The introspection hook is the one
part realized now because it closes the store-internal-metrics gap O1 left open
and is exercised by a real backend (no stub).

---

## 8 — Conformance & tests (as it will be built)

Process is unchanged (spec → graduate → red tests → green impl → guide-check; no stubs).
Planned coverage:
- **Lifecycle:** start with valid/invalid config (fast-fail on invalid); readiness flips on
  drain; graceful shutdown fsyncs + exits 0; systemd `READY=1` / Docker `HEALTHCHECK`.
- **AuthZ:** each permission class enforced (reader can't write → CXER1703; no token →
  only unauth endpoints; admin-only `/metrics`); tenant store-scoping.
- **Observability:** `/metrics` exposes the documented series with bounded cardinality;
  a request emits one span + one structured log with no secret material.
- **gRPC (if included):** op-for-op parity with CSRP over the same fixtures.
- **Client libs:** cross-binding parity against a live single-node server (extends store.md
  §8 "cross-binding parity").
Service-tier conformance is driven from CX programs against a live `mem://`-backed server
(the CSRP reference-server pattern, protocol §6); behavioral V tests for the daemon
internals (config validation, authZ dispatch, metrics registry).

---

## 9 — Decisions (owner-locked 2026-06-25) + remaining detail

Locked:
1. **Sequencing (1a):** umbrella spec (this doc) → one PR per sub-area, order
   **daemon → authZ → observability → gRPC → client libs**.
2. **gRPC (2b):** built in Phase 2 (§5) — opt-in listener, normative CSRP parity.
3. **Auth providers (3d):** all four ship — static + JWT + **DID (first-class)** + OIDC
   (§3.1), one provider interface.
4. **Tenancy (4a):** store-per-tenant; Phase 2 *is* multi-tenant at store granularity with
   isolated dedup pools (§3.3). Intra-store tenancy = Phase 3.
5. **Config (5a):** CX document `cxstore.service.cx` (Appendix A).
6. **`/metrics` auth (6a):** dedicated `metrics` scrape scope (§4.1).

Remaining detail (decide within the owning sub-area, not blocking):
- Exact Prometheus series names/buckets (observability sub-area; Appendix C lists the set).
- ~~Claim→role mapping for JWT/OIDC~~ — settled as normative wording in §3.1
  item 4 (store-management-console G3, 2026-07-07). DID→tenant binding
  convention remains (authZ sub-area).
- gRPC `.proto` package/versioning naming (gRPC sub-area).

---

## Appendix A — `cxstore.service.cx` config schema (sketch)

```
[cxstore-service
  [bind addr="0.0.0.0:8443"]
  [tls cert="/etc/cxstore/tls.crt" key="/etc/cxstore/tls.key" ca="/etc/cxstore/client-ca.pem"]
             [; omit → plaintext (localhost/sidecar only); cert/key are file paths ;]
             [; or ${env:VAR}-injected PEM; ca= (optional) → mTLS require-client-cert ;]
  [grpc enabled=true addr="0.0.0.0:8444"]                         [; 2b — opt-in ;]
  [timeouts read-ms=30000]                                        [; #187 per-connection read deadline; 0 disables ;]
  [stores
    [store name="docs"   url="file:///var/lib/cxstore/docs"]
    [store name="code"   url="file:///var/lib/cxstore/code"]]     [; store-per-tenant: one mount per tenant ;]
  [auth
    [static  [token id="ci"   secret-hash="sha256:…" roles="writer" tenant="docs"]]
    [jwt     issuer="…" audience="…" key-path="/etc/cxstore/jwt.pub" roles-claim="roles"]
             [; key material: key-path= (PEM/JWKS file) or inline jwks= — one required ;]
             [; issuer= REQUIRED (§3.1 iss verification); missing audience= warns ;]
    [did     methods="key,web" audience="cxstore"]                [; 3d — DID first-class ;]
             [; methods= restricts DID methods; audience= binds the DID-JWT aud ;]
             [; (cross-service replay defense). challenge= (nonce) is a tracked ;]
             [; follow-up — challenge=true fast-fails until implemented ;]
    [oidc    issuer="https://idp" audience="cxstore" roles-claim="roles"]
             [; discovery URL is derived: <issuer>/.well-known/openid-configuration ;]
    [scrape  [token id="prom" secret-hash="sha256:…" roles="metrics"]]]
  [limits per-principal-concurrency=64 per-principal-rate=10.0 per-principal-burst=20.0
          pre-auth-rate=100.0 pre-auth-burst=200.0]               [; DoS fairness; omitted attr → default ;]
  [observability
    [otel endpoint="" enabled=false]                              [; tracing off by default ;]
    [log format="cx"]]
  [workers query-pool=8]]
```
Secrets (`tls.key` passphrase, signing material) come from env-var overrides / `cxdm.md §12`
secret values — never inline. Invalid config ⇒ fast-fail, non-zero exit, structured
diagnostic (§2.2). Validation is **attr-exact**, not just section-exact: an unknown
*section* rejects, and an unknown/unsupported *attribute* inside a known section is a
startup error too — a config never parses while silently dropping a directive the
operator wrote (fail-closed, §2.2).

**Reload classification (§2.6)** — every section is explicitly hot or restart-required;
a reload candidate differing in a restart-required attr is refused whole (`CXER1712`):

| Section | Reload class | Notes |
|---|---|---|
| `[bind]` | **restart** | listener rebind |
| `[tls cert= key= ca=]` | **hot** | file paths re-read; new handshakes get the new identity, live sessions untouched; `${env:VAR}`-injected PEM re-resolves to the startup value (env is rotation-blind — use file paths to rotate) |
| `[grpc]` | **restart** | second listener lifecycle |
| `[timeouts]` | **hot** | read-ms/idle-ms picked up by new connections; drain-ms by the next shutdown |
| `[stores]` | **restart** | live mount mutation deliberately out of scope (§2.6) |
| `[auth]` | **hot** | token/provider swap; removed credential 401s on next request; JWKS/did:web caches rebuilt |
| `[limits]` | **hot** | applied to the live limiter; per-principal buckets/in-flight preserved |
| `[observability]` | **hot** | log format, OTel toggle/endpoint |
| `[workers]` | **restart** | pool is sized at startup |

## Appendix B — supervision templates

**systemd** (`Type=notify`):
```
[Unit]
Description=CXStore service
[Service]
Type=notify
ExecStart=/usr/local/bin/cx store-serve --config /etc/cxstore/cxstore.service.cx
ExecReload=/bin/kill -HUP $MAINPID
WatchdogSec=30
Restart=on-failure
KillSignal=SIGTERM
TimeoutStopSec=30
[Install]
WantedBy=multi-user.target
```
The daemon calls `sd_notify(READY=1)` after bind + store-open, pings `WATCHDOG=1`, treats
`SIGTERM` as graceful drain (§2.5), and `SIGHUP` as runtime config reload (§2.6 — so
`systemctl reload cxstore` works; a refused reload keeps the running config and logs the
diagnostic, it never exits).

**Docker `HEALTHCHECK`:**
```
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD cx store-health --url http://127.0.0.1:8443/cx-store/v1/ready || exit 1
```

## Appendix C — RBAC permission ↔ endpoint matrix

| Endpoint | Permission |
|---|---|
| `capabilities` · `health` · `ready` | *(none — unauthenticated)* |
| `get` · `list` · `iter` · `query` | `read` |
| `put` · `modify` | `write` |
| `delete` | `delete` |
| `objects-have` · `objects-get` · `refs` (object-wire reads) | `read` |
| `objects-put` · `refs-set` (object-wire writes) | `write` |
| `aliases` (alias remoting read, explicit presence — CSRP §3.14) | `read` |
| `aliases-set` (alias remoting write, optional CAS — CSRP §3.14) | `write` |
| `status` (store stats) · `gc` (compaction trigger) · `mounts` (daemon-level enumeration, tenant-filtered) · `config-reload` (daemon-level, §2.6) | `admin` |
| `/metrics` | `metrics` |

The object-wire rows (#195) are the plumbing the porcelain (`clone`/`push`/`pull`)
**and the primary client put path** ride on — `put_doc_text` preflights
`objects-have`, so mapping these to `admin` (the pre-fix default) broke the
`writer` role for even a basic put and blocked `reader` pull/clone. They mirror
their data-op peers: read-shaped ops → `read`, write-shaped ops → `write`.

Roles: `reader = {read}`, `writer = {read, write}`, `admin = {read, write, delete, admin}`,
`metrics = {metrics}`. Every authorized op is additionally scoped to the principal's
`tenant` (allowed store-names, §3.3); an op on a store outside the tenant → `CXER1703`.

## Appendix D — CSRP §4 error-table addition (GRADUATED)

The `403 CXER1703 E_CSRP_FORBIDDEN` row this appendix proposed **landed in the
approved CSRP §4 error table** (owner graduation recorded in Appendix E). The
approved table is normative; nothing here remains proposed.

---

## 10 — Out of scope (Phase 3, demand-gated)

Multi-node distribution; S3 as a service-native storage tier (the embedded `s3://`
substrate shipped in Phase 0.5 and is mountable today — §1); FoundationDB metadata;
query planner / worker pool (Trino-fork question, `plan.md` open); Kafka ingest log;
Helm chart; DR/PITR; per-tenant quota/isolation; replication. Phase 2 ships a
single-node production Service and stops there unless multi-node demand is proven.

---

## Appendix E — authN/Z + tenant routing (as built; spec-graduation items)

The authZ sub-area (brick set 2a) is implemented on `cxstore/phase2-service-tier-105`:

- **Store-name routing (1a):** CSRP path gains a store-name segment
  (`/cx-store/v1/<store-name>/<op>`, sole-store form still accepted) so one daemon
  serves multiple mounts — the substrate for store-per-tenant isolation (§3.3).
- **Providers (3d), one interface (credential → `Principal{id,kind,roles,tenant}`):**
  static tokens (sha256 secret-hash), JWT (RS*/ES256/EdDSA via `crypto_jwt_verify`,
  fail-closed), **DID** (ledger-free: `did:key` offline + `did:web` HTTPS with a TTL
  resolver cache; a DID-JWT whose `iss` is the signer's DID), OIDC (JWKS discovery +
  TTL cache, reusing the JWT path). No hand-rolled crypto.
- **RBAC (App C):** deny-by-default; op→permission (read/write/delete/admin/metrics);
  `403 CXER1703` on a permission miss, `401 CXER1702` for anonymous data ops.
- **Tenant isolation (4a):** the principal's tenant must allow the target store-name,
  else `403` — combined with separate per-store dedup pools this is logical isolation
  by construction (the threat-boundary note: not process/hardware isolation; that +
  per-tenant quota = Phase 3).
- **DoS fairness (default-on):** per-principal token-bucket rate + concurrency cap
  and a global pre-auth cap — every admission rejection is `429 CXER1706` with
  `Retry-After` (see the graduation item below: the parallel 173x codes were removed);
  a flooding client gets backpressure, never starves others. Health/ready probes are
  exempt.
- **capabilities `[auth …]` advert** reflects the configured providers.

### Spec-graduation items (owner — these touch `03-approved`)
2. **CSRP store-name path scheme** (`cxstore-remote-protocol.md` §3 + §5.1) —
   ✅ **GRADUATED**: `/cx-store/v1/<store-name>/<op>` routing + grammar
   `[A-Za-z0-9_-]{1,128}` + store-independent endpoints landed.
3. **did:web resolver caching** (`spec/03-approved/std-lib/did.md` §5) —
   ✅ **GRADUATED**: resolve-once/verify-many TTL cache note landed (trust
   decision unaffected; short TTL bounds staleness; shared with OIDC JWKS cache).
1. **CSRP §4 error table** (`cxstore-remote-protocol.md` §4) — ✅ **GRADUATED
   (owner-approved A(a) + B(a), HTTP-semantics alignment):**
   - `CXER1703` renamed `E_CSRP_AUTH_REJECTED` → **`E_CSRP_FORBIDDEN`** (403 =
     authenticated-but-forbidden, RBAC/tenant); `CXER1702` (401) broadened to
     "missing **or invalid/rejected** credential" (a rejected token is an authN
     failure → 401, RFC 9110). Impl already matched.
   - The parallel service-tier block was **removed**: `CXER1730/1731/1732` reuse
     the protocol codes by HTTP semantics — per-principal rate **and** concurrency
     **and** pre-auth cap all → `429 CXER1706`; draining/not-ready/overloaded →
     `503 CXER1708`. The wire code encodes the client's required action, not the
     server's internal reason (which-limiter-tripped stays in `/metrics` + logs).
     Impl updated (`e_svc_*` constants → 1706/1708; per-principal concurrency
     moved 503 → 429).

---

## Appendix F — observability catalog (as built; observability sub-area)

Normative surface for the observability sub-area (decision 1a: metrics + tracing
+ structured logs). **Cardinality is bounded by construction** — the only metric
labels are `endpoint`, `status`, and `store`, each normalized to a *fixed* set
before recording, so the series count is `O(endpoints × statuses × stores)` and
is **independent of traffic**:

- `endpoint` ∈ {`capabilities`,`get`,`put`,`delete`,`list`,`iter`,`query`,`modify`,`health`,`ready`,`metrics`,`objects-have`,`objects-get`,`objects-put`,`refs`,`refs-set`,`aliases`,`aliases-set`} else `_other` — never the raw path (the `objects-*`/`refs*` labels are the object-wire verbs). **The `metrics` scrape endpoint is intentionally EXEMPT from request instrumentation** (#207.1): counting scrapes in `cxstore_requests_total{endpoint="metrics"}` is self-referential (each scrape would inflate the next), so `/metrics` is served before the recording path and the `metrics` label is reserved-but-unpopulated. The exposition carries `Content-Type: text/plain; version=0.0.4; charset=utf-8`.
- `store` ∈ the configured mount names else `_unknown` — **never a per-hash or per-request value** (an attacker spraying bogus store-names can't inflate cardinality).
- `status` is the HTTP status integer.

### F.1 Metrics (`GET /metrics`, Prometheus text exposition format)
Auth: the dedicated **`metrics` scrape scope** (decision 6a) — a principal whose
role is `metrics` may read `/metrics` and nothing else (no data, no `admin`).
When the daemon is not enforcing auth, `/metrics` is open like the other
endpoints. Series (daemon-owned, truthfully populated — no stubbed zeros):

| Series | Type | Labels | Meaning |
|---|---|---|---|
| `cxstore_requests_total` | counter | endpoint,status,store | CSRP requests served |
| `cxstore_request_duration_seconds` | histogram | endpoint,store | request latency (buckets: 1ms…10s) |
| `cxstore_request_bytes_in_total` | counter | endpoint,store | request body bytes accepted |
| `cxstore_request_bytes_out_total` | counter | endpoint,store | response body bytes sent |
| `cxstore_inflight_requests` | gauge | — | requests currently in dispatch |
| `cxstore_build_info` | gauge(=1) | version | static build identification |
| `cxstore_store_docs` | gauge | store,backend | unique documents held (master-index size); local backends only |
| `cxstore_store_objects` | gauge | store,backend | distinct content-addressed objects physically held; object-graph backends only |
| `cxstore_store_dedup_ratio` | gauge | store,backend | subtree-dedup ratio (logical objects without sharing / distinct objects stored, ≥ 1); object-graph backends only, omitted when the store is empty |
| `cxstore_config_reload_total` | counter | outcome | §2.6 reload attempts; `outcome` ∈ {`applied`,`noop`,`invalid`,`restart-required`} |

`cxstore_store_docs` (and, for object-graph backends, `cxstore_store_objects` /
`cxstore_store_dedup_ratio`) are gauged live at scrape time from the backend via
the §7 introspection hook (`store_mount_stats` →
`StoreStats{backend, doc_count, has_object_graph, object_count,
logical_objects, distinct_objects}` — `has_object_graph` gates the object/dedup
series so flat backends emit no fabricated zeros); remote-backed mounts are
skipped (no local count without a round-trip). The remaining store-internal
series from §4.1 (ref-log length, compaction events) attach **only** when the
backend instruments them — they are NOT emitted as fabricated zeros (no-stub
rule), and land as the embedded engine grows the counters.

### F.2 Tracing (OpenTelemetry, off by default)
W3C trace-context: a request carries its trace via the `traceparent` header
(`00-<32hex trace-id>-<16hex span-id>-<flags>`); absent/malformed → a fresh root
trace is minted. Each request is one server span (attributes: endpoint, store,
`principal.role` — never the token, bytes, outcome status); store ops are child
spans. Export is OTLP/HTTP+JSON to the configured `[otel endpoint=…]`; disabled
(`enabled=false`) unless configured — when disabled, ids are still minted +
propagated + logged (so logs correlate) but nothing is exported.

### F.3 Structured logs
One record per request, rendered as a **CX element by default or a JSON object**
when `[observability [log format="json"]]` is set (#207.2): `ts`, `endpoint`,
`store`, `status`, `latency-ms`, `bytes-in`, `bytes-out`, `principal-role` (role,
**never** the token/secret), `trace-id`. **Health/ready probe logs are suppressed**
(these orchestration/LB probes fire constantly and carry no operational signal per
request — full suppression, not rate-sampling; #207.3). No secret material is ever
logged.
