# cxstore service (Phase 2, #105)

`cx store-serve` runs the single-node CXStore service: a multi-threaded CSRP
daemon over the Phase-1 embedded store. See
`spec/03-approved/misc/cxstore_service_tier_phase2.md` for the full design.

## Run

```sh
cx store-serve --config /etc/cxstore/cxstore.service.cx --allow-net
```

- Config is a CX document (`cxstore.service.cx`, see the sample here); invalid
  config fails fast with a structured diagnostic and a non-zero exit.
- `--allow-net[=host:port]` grants the network capability to bind (deny-by-default).
- Graceful shutdown: `SIGTERM`/`SIGINT` stops accepting, drains in-flight
  requests, then exits 0.
- Single store mount per daemon (multi-store-per-daemon arrives with the authZ
  sub-area's CSRP store-name routing).

## Readiness probe

```sh
cx store-health --url http://127.0.0.1:8443/cx-store/v1/ready   # exit 0 iff accepting
```

## systemd (Type=notify)

Install `cxstore.service` to `/etc/systemd/system/`, the config to
`/etc/cxstore/cxstore.service.cx`, then `systemctl enable --now cxstore`. The
daemon signals `READY=1` once bound (sd_notify).

## Docker

`docker build -t cxstore .` (copy a built `cx` binary alongside the Dockerfile
first). The image's `HEALTHCHECK` runs `cx store-health` against `/ready`.

## Smoke test (loopback)

```sh
PORT=18760
printf '[cxstore-service [bind addr="127.0.0.1:%s"] [stores [store name="docs" url="mem://docs"]]]' "$PORT" > /tmp/svc.cx
cx store-serve --config /tmp/svc.cx --allow-net=127.0.0.1:$PORT &
DPID=$!; sleep 1
curl -s http://127.0.0.1:$PORT/cx-store/v1/health     # [health [status "ok"]]
curl -s http://127.0.0.1:$PORT/cx-store/v1/ready      # [ready [accepting true] [draining false]]
H=$(curl -s -X POST --data-binary '[doc [title "hi"]]' http://127.0.0.1:$PORT/cx-store/v1/put)
curl -s -X POST "http://127.0.0.1:$PORT/cx-store/v1/get?hash=$(echo "$H" | sed -n 's/.*hash="\([a-f0-9]*\)".*/\1/p')"
kill -TERM $DPID                                       # drains, exits cleanly
```
