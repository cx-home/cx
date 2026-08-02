# CX Store, service tier — the production daemon

`cx store-serve` runs the single-node CXStore service: a purpose-built,
multi-threaded daemon serving the **same** API, wire format, and
content-addressing as the embedded store — it adds the operational layer,
no storage smarts. Governing specs: the CXStore service-tier spec
(`spec/03-approved/misc/cxstore_service_tier_phase2.md`) and the permanent wire
protocol, the CXStore remote protocol spec (CSRP,
`spec/03-approved/misc/cxstore-remote-protocol.md`). Deploy artifacts live in
`tooling/cxstore/` (README, `cxstore.service` systemd unit, `Dockerfile`,
sample config).

## Run it (verified end-to-end)

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

One daemon mounts many named stores (`/cx-store/v1/<store-name>/<op>`); each
mount is any embedded substrate URL (`file://`, `sqlite://`, `s3://`, …).
Config is a CX document, validated **attr-exact** at startup — an unknown
attribute is a startup error, never a silent drop (`CXER1711`). Full schema:
the service-tier spec's config appendix.

## Talking to it from CX — the same store API

A `cx-store://` handle is a named remote store; the client API is identical
to embedded (verified against the live daemon above):

```cx
[?lib 'cx-stdlib/store' :as store]
[?let [= $remote [$store:open "cx-store+http://127.0.0.1:18761/docs/"]]
 [= $h [$store:put-doc $remote [doc [title "over the wire"]]]]
 [$store:get-doc $remote $h]]
# → [doc [title 'over the wire']]      (needs --allow-net=127.0.0.1:18761)
```

`cx-store+https://` is TLS; a bearer token rides the URL
(`cx-store://token@host/name/`). Python/Go/Rust `CxStoreClient` wrappers
drive this same client through the C-ABI — one source of protocol truth,
cross-binding hash parity by construction (the client-libraries section of
the service-tier spec).

## Auth — four providers, RBAC, deny-by-default

Configure any of: **static tokens** (hashed at rest), **JWT**, **DID**
(first-class — the agentic-principal path; `did:key` offline, `did:web`
cached), **OIDC** (enterprise SSO). All resolve to a principal
`{id, kind, roles, tenant}`. Roles bundle CSRP permission classes: `reader`,
`writer`, `admin`, plus a metrics-only `metrics` scrape scope. No credential
⇒ only `capabilities`/`health`/`ready`. Verified against a live daemon:

```sh
cx store-token --id ci --roles writer --tenant docs   # prints the [static [token …]] stanza + the secret ONCE
# anonymous put  → 401 [err code="cx-err:CXER1702" …]
# bearer put     → [put-result hash="…" stored="true"]
```

Tenancy is **store-per-tenant**: a principal is authorized for a set of
store-names; each tenant owns a separate dedup pool — cryptographic isolation
by construction (a shared pool would be an existence oracle; the tenancy
section of the service-tier spec explains the rejection). Intra-store
tenancy, quotas, and multi-node are the demand-gated next phase — **not
implemented**.

## Observability

- `GET /metrics` — Prometheus exposition, gated by the `metrics` scope.
  Bounded cardinality by construction (labels: endpoint, status, store —
  never per-hash). Request counters/histograms/bytes, in-flight gauge,
  per-store doc/object/dedup gauges. No fabricated zeros: store-internal
  series attach only when the backend instruments them.
- **OpenTelemetry tracing** — off by default; W3C trace-context propagated
  either way so logs correlate; OTLP/HTTP export when enabled.
- **Structured logs** — one record per request (role, never the token;
  health/ready probe logs suppressed). CX or JSON format.

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
  validate-then-swap, all-or-nothing, fail-closed — auth, limits,
  observability, timeouts, and TLS cert/key *contents* are hot; bind, gRPC,
  mounts, workers are restart-required (`CXER1712` names offenders and the
  whole reload is refused). Env-injected secrets are rotation-blind — use
  file-based sources to rotate.

## gRPC

An opt-in second listener (`[grpc enabled=true addr=…]`) with **normative
CSRP parity** — same ops, same semantics, same error codes; server-streaming
for `iter`/large query. CSRP over HTTP/1.1 remains the canonical, permanent
interface (the gRPC spec: `spec/03-approved/misc/cxstore-grpc.md`).

## DoS fairness (default-on)

Per-principal token-bucket rate + concurrency caps and a global pre-auth
cap; every admission rejection is `429 CXER1706` with `Retry-After`;
draining/not-ready is `503 CXER1708`. A flooding client gets backpressure,
never starves others.
