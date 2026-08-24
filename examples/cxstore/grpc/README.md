# cxstore over gRPC

A CX client talking to a cxstore **server over gRPC** (HTTP/2 + protobuf).

This is the gRPC counterpart to [`../client-server`](../client-server) (which uses
CSRP — the HTTP/1.1 + CX-bodies protocol). The store operations are identical;
only the transport scheme on the client's `[$store:open]` URL differs:

| Transport | Client URL scheme |
|-----------|-------------------|
| CSRP (HTTP/1.1) | **`cx-store+https://host:port/store/`** — TLS, the form to copy (`cx-store+http://` = loopback dev only) |
| gRPC (HTTP/2)   | **`cx-store+grpcs://host:port/store/`** — TLS, the form to copy (`cx-store+grpc://` = loopback dev only) |

## Pieces

- **`cxstore.service.cx`** — the daemon config. One `mem://` store named `docs`,
  exposed on **two** listeners: CSRP on `127.0.0.1:18910` and gRPC on
  `127.0.0.1:18911` (`[grpc enabled=true]`).
- **`client.cx`** — opens `cx-store+grpc://127.0.0.1:18911/docs/` and drives the
  full surface over gRPC: `put-doc` → `get-doc` → `list-docs` → `query //title`
  → `modify-doc` (and reads the modified doc back).
- **`Makefile`** — orchestrates start → client → stop.

## Run

```sh
make run        # start daemon → run client over gRPC → stop daemon
```

or step by step:

```sh
make server     # start the daemon (CSRP + gRPC listeners) in the background
make client     # run the gRPC client against it
make stop       # stop the daemon
```

## What it shows

- gRPC is a first-class cxstore transport: the **same** `[$store:…]` verbs work
  unchanged — switching from CSRP to gRPC is a one-line URL-scheme change.
- The server is the `cx store-serve` daemon; the gRPC listener reuses the same
  request pipeline (auth, RBAC, tenant routing, the DoS limiter, observability) as
  CSRP, so the two transports are at full op parity.
- Capabilities are deny-by-default: the daemon is granted net to both listener
  ports via `--allow-net`; the client only needs net to the gRPC port.

## Notes

- **The URL in this example is not the one to copy.** `cx-store+grpc://` is
  cleartext h2c — the **loopback development shortcut**, so the quickstart
  needs no certificates. The production form is **`cx-store+grpcs://`**
  against a TLS daemon; never use the cleartext scheme off `127.0.0.1`.
  (No TLS-on-loopback demo ships deliberately: a self-signed cert would
  force `tls-verify=false` on the client, and teaching *disable
  verification* is worse than an honestly-labeled cleartext shortcut.)
- Because the Python / Go / Rust client libraries drive the same core client,
  they reach the gRPC server simply by opening a `cx-store+grpc://` URL — one
  client implementation, no per-language gRPC code.
