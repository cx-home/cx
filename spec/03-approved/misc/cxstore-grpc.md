# CXStore gRPC interface

**Status:** Approved. Normative wire contract for the optional gRPC transport of
the CXStore service. Companion to [`cxstore-remote-protocol.md`](cxstore-remote-protocol.md)
(CSRP, the canonical interface); this document defines the gRPC alternative and
its parity obligations.

## 1. Position & invariants

- CSRP (HTTP/1.1 + CX bodies) is the canonical, permanent interface. gRPC is an
  **opt-in second listener** offering the **same operation set**. Parity is
  **normative**: there are no gRPC-only operations, semantics are identical, and
  error identity is identical across transports.
- The listener is configured by `[grpc enabled=true addr="host:port"]` in the
  service config (`GrpcConfig{enabled, addr}`). It is **disabled by default**; a
  daemon with no gRPC config binds only CSRP. When enabled, `addr` is required
  and MUST differ from the CSRP `bind` address.
- gRPC reuses the **same** request pipeline behind the transport: store-name
  routing, authentication/authorization (RBAC + tenant→store scoping), the
  DoS-fairness limiter, and the observability hooks. Only the framing differs;
  there is no second copy of the request logic.

## 2. The `.proto` (mirrors CSRP endpoints 1:1)

```proto
syntax = "proto3";
package cxstore.v1;

// One RPC per CSRP op. Unary where CSRP is request/response; server-streaming
// where CSRP streams (list / iter / large query results over HTTP/2 DATA frames,
// the analogue of CSRP's 0x02/0x03 result-frame stream).
service CxStore {
  rpc Capabilities (CapabilitiesRequest) returns (CapabilitiesResponse);
  rpc Get          (GetRequest)          returns (GetResponse);
  rpc Put          (PutRequest)          returns (PutResponse);
  rpc Delete       (DeleteRequest)       returns (DeleteResponse);
  rpc List         (ListRequest)         returns (stream HashItem);
  rpc Iter         (IterRequest)         returns (stream Doc);
  rpc Query        (QueryRequest)        returns (stream QueryRow);
  rpc Modify       (ModifyRequest)       returns (ModifyResponse);
}

// store is the store-name path segment from the cx-store:// URL (CSRP
// /cx-store/v1/<store-name>/<op>); empty selects the sole-store form.
message GetRequest    { string store = 1; string hash = 2; }
message GetResponse   { bytes  body  = 1; string encoding = 2; } // cxd | astbin
message PutRequest    { string store = 1; bytes  body = 2; string encoding = 3; }
message PutResponse   { string hash  = 1; bool   stored = 2; }
message DeleteRequest { string store = 1; string hash = 2; }
message DeleteResponse{ bool   deleted = 1; }
message ListRequest   { string store = 1; }
message HashItem      { string hash  = 1; }
message IterRequest   { string store = 1; }
message Doc           { string hash  = 1; bytes body = 2; string encoding = 3; }
message QueryRequest  { string store = 1; bytes query = 2; }   // CXPath/CX query body
message QueryRow      { bytes  row   = 1; string encoding = 2; }
message ModifyRequest { string store = 1; string hash = 2; bytes action = 3; }
message ModifyResponse{ string old_hash = 1; string new_hash = 2; bool stored = 3; }
message CapabilitiesRequest  {}
message CapabilitiesResponse { bytes capabilities = 1; } // the same [capabilities …] CX body
```

- **Bodies are the existing Layer-1 payloads** (`encoding` = `cxd` text or
  `astbin`), byte-identical to what CSRP carries — the message is an envelope, not
  a re-modeling of the document. There is no protobuf modeling of CX node
  structure.
- `Capabilities` returns the same `[capabilities …]` CX body (including the
  `[auth …]` advert) that the CSRP endpoint returns.

## 3. Error identity (parity is normative)

A gRPC call maps the CSRP error onto the closest gRPC status **and** carries the
exact CXER code in the trailer, so the symbolic↔wire identity holds across both
transports — a client may key on the CXER code regardless of transport.

| CSRP | gRPC `status.code` | trailer `cx-err-code` |
|---|---|---|
| 400 `CXER1701` request malformed | `INVALID_ARGUMENT` (3) | `cx-err:CXER1701` |
| 401 `CXER1702` auth required/rejected | `UNAUTHENTICATED` (16) | `cx-err:CXER1702` |
| 403 `CXER1703` forbidden (RBAC/tenant) | `PERMISSION_DENIED` (7) | `cx-err:CXER1703` |
| 404 `CXER1721` not found | `NOT_FOUND` (5) | `cx-err:CXER1721` |
| 404 `CXER1709` operation unsupported | `UNIMPLEMENTED` (12) | `cx-err:CXER1709` |
| 404 `CXER1710` store not found | `NOT_FOUND` (5) | `cx-err:CXER1710` |
| 409 `CXER1704` concurrent modify | `ABORTED` (10) | `cx-err:CXER1704` |
| 413 `CXER1705` payload too large | `RESOURCE_EXHAUSTED` (8) | `cx-err:CXER1705` |
| 422 `CXER1720` integrity mismatch | `DATA_LOSS` (15) | `cx-err:CXER1720` |
| 429 `CXER1706` rate/concurrency | `RESOURCE_EXHAUSTED` (8) | `cx-err:CXER1706` |
| 500 `CXER1707` server internal | `INTERNAL` (13) | `cx-err:CXER1707` |
| 503 `CXER1708` unavailable | `UNAVAILABLE` (14) | `cx-err:CXER1708` |

429 and 413 both surface as `RESOURCE_EXHAUSTED`; the trailer CXER disambiguates.
The gRPC status is the coarse class; the CXER is the precise identity — the gRPC
analogue of CSRP carrying its own symbolic name alongside the HTTP status.

## 4. Auth & tenant

- A bearer token is carried in the `authorization` call-metadata header
  (`Bearer <tok>`), or via an mTLS client certificate. Both resolve through the
  **same** authenticate → `Principal` → authorize (RBAC + tenant→store) path as
  CSRP. There is no second authentication implementation.
- The DoS-fairness limiter and observability (metrics endpoint label, structured
  log, trace span) apply identically; the `endpoint` metric label folds the gRPC
  method name into the same bounded set as the CSRP endpoints.

## 5. Streaming & connection concurrency

`List`/`Iter`/`Query` are server-streaming: each result element is one gRPC
message over an HTTP/2 DATA frame, terminated by `grpc-status: 0` in the trailer
(or a non-zero status + `cx-err-code` on mid-stream failure) — the direct
analogue of CSRP's `0x02` result frames terminated by `0x03`.

The gRPC listener serves connections through a bounded worker pool (the analogue
of the CSRP serve pool): worker threads drain a bounded connection queue, and
`submit` blocks when the queue is full (backpressure; never unbounded thread
spawning). Each worker owns its own lifecycle state (no shared mutable state
across threads); the shared serve-context members (limiter / metrics / tracer)
are mutex-guarded. Within a single connection, the HTTP/2 codec reassembles every
stream and the dispatcher handles each completed call independently, so multiple
concurrent streams on one connection are dispatched concurrently.

## 6. Client transport (`cx-store+grpc://`)

The gRPC interface is reachable from the normal store surface via two open
schemes, parallel to the CSRP `cx-store(+http|+https)://` schemes:

- `cx-store+grpc://[token@]host[:port]/store-name/` — h2c (cleartext HTTP/2;
  loopback / dev).
- `cx-store+grpcs://[token@]host[:port]/store-name/` — HTTP/2 over TLS.

The URL shape, bearer placement, and store-name routing are identical to the CSRP
schemes; only the framing differs. The client dials through the capability-gated,
SSRF-guarded net dialer (TCP or TLS), issues one HTTP/2 stream per call, and reads
the response frames plus the `grpc-status` trailer, mapping it back onto the store
error space (§3). Each operation returns the same result shape as the local store
builtins, so `cx-store+grpc` is a drop-in store backend.

Because the language client libraries (Python/Go/Rust) drive the core client,
passing a `cx-store+grpc://` URL routes them over gRPC through the one client
implementation — parity by construction with CSRP, with no per-language gRPC code.

## 7. Parity conformance (the obligation that makes parity real)

One conformance suite drives the **same fixtures** through **both** transports
against a single live daemon (CSRP listener + gRPC listener on its own port) and
asserts:

- identical content hashes for every `put`/`get` round trip (byte-identical);
- identical CXER code for every error case (via the gRPC trailer);
- identical `list`/`iter`/`query` result sets.

This extends the cross-binding parity contract to cross-transport parity. No
gRPC-only behavior may exist — any divergence is a conformance failure.
