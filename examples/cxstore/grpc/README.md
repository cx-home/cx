# cxstore over gRPC

A CX client talking to a cxstore **server over gRPC** (HTTP/2 + protobuf).

This is the gRPC counterpart to [`../client-server`](../client-server) (which uses
CSRP — the HTTP/1.1 + CX-bodies protocol). The store operations are identical;
only the transport scheme on the client's `[$store:open]` URL differs:

| Transport | Client URL scheme |
|-----------|-------------------|
| CSRP (HTTP/1.1) | `cx-store+http://host:port/store/` (`cx-store+https://` for TLS) |
| gRPC (HTTP/2)   | `cx-store+grpc://host:port/store/`  (`cx-store+grpcs://` for TLS) |

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

- The client uses cleartext h2c (`cx-store+grpc://`) against a loopback daemon.
  For production, run the daemon with TLS and use `cx-store+grpcs://`.
- Because the Python / Go / Rust client libraries drive the same core client,
  they reach the gRPC server simply by opening a `cx-store+grpc://` URL — one
  client implementation, no per-language gRPC code.
