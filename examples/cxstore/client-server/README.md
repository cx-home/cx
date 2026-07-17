# cxstore client + server over CSRP

A CX client talking to a CX **store server over CSRP** (the HTTP/1.1 +
CX-bodies store remote protocol) — two separate `cx` processes, real
sockets on loopback.

This is the CSRP counterpart to [`../grpc`](../grpc) (which drives the
same store surface over gRPC / HTTP/2 + protobuf). The store operations
are identical; only the transport scheme on the client's
`[$store:open]` URL differs:

| Transport | Client URL scheme |
|-----------|-------------------|
| CSRP (HTTP/1.1) | `cx-store+http://host:port/store/` (`cx-store+https://` for TLS) |
| gRPC (HTTP/2)   | `cx-store+grpc://host:port/store/`  (`cx-store+grpcs://` for TLS) |

## Pieces

- **`server.cx`** — a seven-line CSRP server: opens a private `mem://`
  store, listens on `tcp://127.0.0.1:18901`, and hands every accepted
  HTTP exchange to `[$store:csrp-handle]`. That one builtin is the
  whole server loop — routing, protocol framing, and store dispatch
  included.
- **`client.cx`** — opens `cx-store+http://127.0.0.1:18901/teststore/`
  and drives the surface end to end: `put-doc` → `get-doc` →
  `list-docs` → `query //title`, then renders one `[result …]` element
  with the returned hash, count, document, and query hits.
- **`Makefile`** — orchestrates start → client → stop (pidfile +
  `/tmp/cxstore-csrp.log`).

## Run

```sh
make run        # start server → run client → stop server
```

or step by step:

```sh
make server     # start the CSRP server in the background
make client     # run the client against it
make stop       # stop the server
```

The binary defaults to the repo build (`vcx/target/cx`); override with
`make run CX=/path/to/cx`.

## What it shows

- The store client/server split is symmetric CX: the *server* is an
  ordinary `cx` program (`[$http:listen]` + `[$store:csrp-handle]`),
  not a special daemon build. (The productionized daemon with auth,
  RBAC, and multi-listener config is `cx store-serve` — see the gRPC
  example.)
- The *same* `[$store:…]` verbs work against `mem://` locally and
  `cx-store+http://` remotely — remoting is a URL change, not an API
  change.
- Capabilities are deny-by-default; both processes run with explicit
  grants (see the Makefile note on why the server needs `--allow-all`:
  a denied capability on the observability path poisons
  `[$http:respond]`, and the client would see
  `E_STORE_BACKEND_UNREACHABLE`).

## Notes

- Cleartext HTTP against a loopback server. For production, terminate
  TLS and use `cx-store+https://`.
- The Python / Go / Rust client libraries drive the same core client,
  so they reach this server by opening the same
  `cx-store+http://…/teststore/` URL.
