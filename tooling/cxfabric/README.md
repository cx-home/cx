# cx-fabric served tier (#531 P1)

`cx fabric-serve` runs the single-node cx-fabric served tier: it mounts named
fabrics (journal-backed durable streams + latest-wins transient channels),
accepts XSP-AUTH attaches over raw XSP frames (TCP or TLS), sequences durable
publishes, pushes delivery under the bounded pending window, and hosts
sticky-exclusive consumer-group assignment with liveness-window failover. See
`spec/03-approved/xap/fabric.md` (§13 serve tier, §19 design decisions).

## Run

```sh
CX_FABRIC_SEED=<64-hex-ed25519-seed> \
cx fabric-serve --config /etc/cxfabric/fabric.service.cx --allow-net --allow-read --allow-write
```

- Config is a CX document (`fabric.service.cx`, see the sample here),
  attr-exact validated — an unknown section or attribute fails the boot with a
  structured diagnostic, never a silent drop.
- The `[identity]` seed env var must re-derive the declared host DID or the
  boot refuses (there is no anonymous responder).
- Capabilities are deny-by-default: `--allow-net[=host:port]` to bind,
  `--allow-read --allow-write` for `file://`-backed journals.
- Authorization is per-principal grants over the three fabric actions —
  `observe` / `publish` / `consume` — per stream/channel scope (`*` = all),
  deny-by-default.
- Graceful shutdown: `SIGTERM`/`SIGINT` flips readiness, drains, exits 0.

## Wire (v1)

Raw XSP frames (`xsp.md` §2). The attach handshake (M1–M4) rides binary
stream-0 frames — the same `$xsp:auth-*` calculus the web client uses. After
establishment, verbs / replies / pushes ride **text frames carrying canonical
CX** (lossless for event trees):

```
[publish stream="orders" [event [do :order.placed]]]      → [receipt seq=N stream=orders]
[subscribe stream="orders" group="g1" [pattern :order.*]] → [fabric-sub id=K … assigned=true]
[observe stream="orders" [pattern :order.*]]              → [fabric-sub id=K … observe=true]
[ack sub=K seq=N]                                         → null   (cumulative through N)
[emit channel="coord/map" [value [viewport zoom=12]]]     → null
[read channel="coord/map"]                                → latest value | () absence
```

Matching `[entry …]` elements push as `event` frames whose stream-id is the
subscription id; transient fan-out pushes `[channel-value …]`. `ping` answers
`pong` and refreshes the liveness window.

## Readiness probe

The optional `[health addr=…]` listener serves unauthenticated
`GET /health` + `GET /ready` — probe-compatible with:

```sh
cx store-health --url http://127.0.0.1:8448/ready   # exit 0 iff accepting
```

## Deployment

The store-serve patterns apply unchanged (`tooling/cxstore/`): the systemd
unit shape (Type=notify; the daemon signals `READY=1` once bound) and the
Docker HEALTHCHECK-via-probe pattern both work verbatim — point them at
`cx fabric-serve` and the `/ready` URL above.

## Webhook adapter (#531 P3)

`webhook-adapter.cx` (pure cx, in this directory) is the first §14 edge
adapter — an ordinary fabric client holding grants, riding the remote tier
of the client surface (`[$fabric:open "xsp://host:port" {…}]`):

```sh
CX_ADAPTER_SEED=<hex> CX_ADAPTER_TOKEN=<token> \
cx webhook-adapter.cx --data=adapter.config.cx \
   --allow-net=<daemon> --allow-net=<listen> [--allow-net=<callback>] --allow-env
```

- **webhook-in** — `POST <route path>` with a CX or JSON body → the payload
  publishes **verbatim** as the event (canonical CX at the boundary; JSON
  converts to its wrapped map element) → `200 [receipt seq=…]`; an
  unparseable body is a `400`, never a silent drop.
- **SSE out** — `GET <route path>` joins a live feed; matching entries
  arrive as canonical-CX `data:` frames (or JSON with `fmt="json"`).
- **webhook push** — a background pump POSTs `[batch …]` bodies to the
  configured callback and acks cumulatively **only after a 2xx**: a failing
  callback stops the ack, the daemon's pending window stops the push, and
  the uncommitted tail redelivers (at-least-once).
- The HTTP door is bearer-token first (`[http token-env=…]`); without the
  key the door is open (dev posture, like an `[auth]`-less store-serve).

## NATS bridge (#547)

`nats-bridge.cx` (pure cx, in this directory) is the legacy-migration seam
(§14/§18): NATS-side producers and consumers keep their subjects while the
estate migrates onto fabric. It speaks the client subset of the NATS text
protocol itself over `cx-stdlib/net` (INFO/CONNECT/PING/PONG/SUB/PUB/MSG —
no NATS library, no core seam):

```sh
CX_BRIDGE_SEED=<hex> \
cx nats-bridge.cx --data=nats-bridge.config.cx \
   --allow-net=<daemon> --allow-net=<nats-server> --allow-env
```

- **NATS → fabric** — a `SUB` per `[in subject=… stream=…]` route; each MSG
  becomes canonical CX at the boundary (JSON → its wrapped map element,
  CX-parseable text → the element verbatim, anything else → a `[nats-raw]`
  wrapper — lossless, never a drop) and publishes onto the route's stream.
  A failed publish ends the session loudly; delivery up to the bridge
  inherits core-NATS fire-and-forget semantics.
- **fabric → NATS** — a durable group subscription per `[out …]` route;
  received events render per `fmt` (`cx` canonical default, `json`) and PUB
  to the route's subject; `body="event"` (default) ships just the event,
  `body="entry"` the full attributed envelope. After each PUB batch the
  bridge PINGs and **acks cumulatively only on the server's PONG** — the
  round-trip proves the server processed the batch (at-least-once, the
  ack-after-2xx cognate).
- Reconnect with a 1s backoff re-dials and re-SUBs; fabric offsets live
  outside the NATS connection, so egress resumes at the committed offset.
- NATS auth rides env vars (`[nats token-env=…]` or `user=`/`pass-env=`);
  reply-to subjects are ignored (request-reply is fabric-native, §12.1);
  TLS-required NATS servers are not supported in v1.

The remote client tier itself is part of the `cx-fabric` package: any cx
program opens a served fabric with
`[$fabric:open "xsp://host:port" {tenant: …, did: …, seed: <bytes>,
responder: <daemon-did>}]` and uses the same publish / subscribe / receive /
ack / emit / read / respond / request / serve verbs as the embedded tier
(anonymous open — no did/seed — is admitted only by a floor-policy daemon).
Group subscriptions may carry the §9.1 redelivery policy
(`{group: …, max-deliveries: N, dlq: "…"}` — declaring it needs a publish
grant on the DLQ stream); request-reply (§12.1) is the call convention: a
responder process registers a callable with `respond` and pumps it with
`serve`, a requester's `request` blocks (deadline-bounded) until the reply
routes back over native XSP request/reply frames.
