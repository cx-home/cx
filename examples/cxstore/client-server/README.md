# cxstore client + server over the store wire (XSP profile)

A CX client talking to a CX **store daemon over the XSP store profile** —
THE store wire for CX-to-CX — two separate processes, real sockets on
loopback.

This is the native-wire counterpart to [`../grpc`](../grpc), which drives
the same store surface over the **integration edge** (gRPC / HTTP/2 +
protobuf) for gRPC-speaking environments. The store operations are
identical; only the transport scheme on the client's `[$store:open]` URL
differs:

| Transport | Role | Client URL scheme |
|-----------|------|-------------------|
| XSP store profile | THE CX-to-CX wire | **`cx-store://host:port/store/`** — TLS, the form to copy |
| gRPC (HTTP/2)     | integration edge  | **`cx-store+grpcs://host:port/store/`** — TLS, the form to copy |

> **The URL in this example is not the one to copy.** Every example here
> runs `cx-store+xsp://` — the **loopback development shortcut**: cleartext,
> on `127.0.0.1`, so the quickstart has zero setup and zero dependencies.
> **Never use a `+xsp` (or `+grpc`, or `+http`) URL off the loopback
> interface.** The real deployment form is `cx-store://` over TLS, one line
> of daemon config and one scheme change on the client — see
> [Going to production](#going-to-production) below.
>
> We deliberately do NOT ship a TLS-on-loopback demo: on a self-signed
> certificate the client would need `tls-verify=false`, and an example that
> teaches *disabling transport verification* is a worse lesson than an
> honestly-labeled cleartext shortcut.

## Pieces

- **`cxstore.service.cx`** — the daemon config: a private `mem://` store
  served over the XSP profile on `tcp://127.0.0.1:18901`, with the
  bootstrap health surface on `127.0.0.1:18900`. `floor` policy admits an
  anonymous client as `guest`, so this demo needs no client identity;
  a production deployment names `[grants …]` and the client presents an
  `xsp-did` (see `store.md` §6.4).
- **`client.cx`** — opens `cx-store+xsp://127.0.0.1:18901/teststore/` and
  drives the surface end to end: `put-doc` → `get-doc` → `list-docs` →
  `query //title`, then renders one `[result …]` element with the returned
  hash, count, document, and query hits.
- **`Makefile`** — orchestrates start → client → stop (pidfile +
  `/tmp/cxstore-xsp.log`).

## Run

```sh
make run        # start server → run client → stop server
```

or step by step:

```sh
make server     # start the store daemon in the background
make client     # run the client against it
make stop       # stop the server
```

The binary defaults to the repo build (`vcx/target/cx`); override with
`make run CX=/path/to/cx`.

## What it shows

- The store server is `cx store-serve` — the productionized daemon with
  identity, authority, and multi-listener config. (Serving a store is a
  daemon concern; a store is not hosted from an ordinary `cx` program.)
- The *same* `[$store:…]` verbs work against `mem://` locally and
  `cx-store+xsp://` remotely — remoting is a URL change, not an API change.
- Capabilities are deny-by-default; both processes run with explicit
  loopback `--allow-net` grants for exactly the ports they use.

## Notes

## Going to production

Two changes, both small — this example is the shape, not the deployment:

1. **The daemon serves TLS.** Add a `[tls cert=… key=…]` block to
   `cxstore.service.cx`'s listener; the profile then speaks TLS on that
   port.
2. **The client opens `cx-store://`** instead of `cx-store+xsp://` — the
   TLS scheme is the default form, and the `+xsp` spelling exists only to
   say "I know this is cleartext."

Client identity does NOT ride the URL: the profile refuses URL userinfo,
and identity travels in open-opts (`xsp-did` / `xsp-seed-env`). A
production daemon also names `[grants …]` rather than the `floor` policy
this example uses.

## Notes
- The Python / Go / Rust client libraries drive the same core client, so
  they reach this daemon over the same wire.
- Need to interoperate with a gRPC-speaking system instead? Enable
  `[grpc …]` and open `cx-store+grpc://` — see [`../grpc`](../grpc).
