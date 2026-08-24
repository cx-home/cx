# CXStore gRPC interface

**Status:** Approved. Normative wire contract for the optional gRPC transport of
the CXStore service. Since the stream-4 ruling (#676: the XSP store profile
becomes THE store wire and the CSRP data plane retires at the parity gate),
the canonical companion is the store profile (store.md §6.4); the parity
obligations below transfer to the profile pipeline, which this adapter
re-bases onto.

## 1. Position & invariants

- The **XSP store profile** is the canonical store wire (stream 4; formerly
  this sentence named CSRP "canonical, permanent" — struck, per the CSRP-fold
  ruling). gRPC is an **opt-in second listener** offering the **same
  operation set**, synthesizing internal profile-pipeline ops (never CSRP
  requests). Parity is **normative**: there are no gRPC-only operations,
  semantics are identical, and error identity is identical across transports.
- The listener is configured by `[grpc enabled=true addr="host:port"]` in the
  service config (`GrpcConfig{enabled, addr}`). It is **disabled by default**; a
  daemon with no gRPC config binds only the bootstrap HTTP surface and (when
  enabled) the XSP profile listener. When enabled, `addr` is required and MUST
  differ from the bootstrap `bind` address.
- gRPC reuses the **same** request pipeline behind the transport: store-name
  routing, per-call XSP-AUTH (§4 — one authority calculus with the profile),
  the DoS-fairness limiter, and the observability hooks. Only the framing
  differs; there is no second copy of the request logic.

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
  // The object wire (#129 item 4 / #645 alias remoting) — ONE envelope shape
  // drives all seven: the verb's cxd-text request document in, its cxd-text
  // result document out (byte-identical to the profile's object-wire bodies).
  rpc ObjectsHave  (ObjWireRequest)      returns (ObjWireResponse);
  rpc ObjectsGet   (ObjWireRequest)      returns (ObjWireResponse);
  rpc ObjectsPut   (ObjWireRequest)      returns (ObjWireResponse);
  rpc Refs         (ObjWireRequest)      returns (ObjWireResponse);
  rpc RefsSet      (ObjWireRequest)      returns (ObjWireResponse);
  rpc Aliases      (ObjWireRequest)      returns (ObjWireResponse);
  rpc AliasesSet   (ObjWireRequest)      returns (ObjWireResponse);
  // The F1' OPAQUE blob pair (S6.5 — G13 edge parity): raw bytes, byte-exact,
  // identity = hash of the bytes as given. The Put/Get message shapes are
  // reused with encoding "raw"; PutBlob's reply hash field carries the blob
  // KEY; GetBlob absence is NOT_FOUND with the cx-err trailer (the client
  // surfaces the blob surface's CXER1121 contract, identical to the profile).
  rpc PutBlob      (PutRequest)          returns (PutResponse);
  rpc GetBlob      (GetRequest)          returns (GetResponse);
  // The admin plane (#248 status/gc/mounts; #251 §3.13 config-reload). The
  // porcelain element rides back as a cxd-text body (the ObjWireResponse
  // carrier); mounts + reload are daemon-level (store ignored).
  rpc Status       (StoreRequest)        returns (ObjWireResponse);
  rpc Gc           (StoreRequest)        returns (ObjWireResponse);
  rpc Mounts       (StoreRequest)        returns (ObjWireResponse);
  rpc Reload       (StoreRequest)        returns (ObjWireResponse);
}

// store is the store-name path segment from the cx-store:// URL (CSRP
// /cx-store/v1/<store-name>/<op>); empty selects the sole-store form.
message GetRequest    { string store = 1; string hash = 2; }
message GetResponse   { bytes  body  = 1; string encoding = 2; } // cxd | astbin | raw (GetBlob)
message PutRequest    { string store = 1; bytes  body = 2; string encoding = 3; }
message PutResponse   { string hash  = 1; bool   stored = 2; }
message DeleteRequest { string store = 1; string hash = 2; }
message DeleteResponse{ bool   deleted = 1; }
message ListRequest   { string store = 1; }
message HashItem      { string hash  = 1; }
message IterRequest   { string store = 1; }
message Doc           { string hash  = 1; bytes body = 2; string encoding = 3; }
message QueryRequest  { string store = 1; bytes query = 2; bytes comp = 3; }   // query = CXPath; comp = a QUOTED planar comprehension's source text (stream-2 L99, store.md §6.2) — exactly one of the two
message QueryRow      { bytes  row   = 1; string encoding = 2; }
message ModifyRequest { string store = 1; string hash = 2; bytes action = 3; }
message ModifyResponse{ string old_hash = 1; string new_hash = 2; bool stored = 3; }
message CapabilitiesRequest  {}
message CapabilitiesResponse { bytes capabilities = 1; } // the same [capabilities …] CX body
message ObjWireRequest  { string store = 1; bytes body = 2; } // the verb's cxd-text request doc
message ObjWireResponse { bytes  body  = 1; }                 // the verb's cxd-text result doc
message StoreRequest    { string store = 1; }
```

This service block is the COMPLETE served RPC surface (21 RPCs) — the
pre-S6.5 revision listed only the eight data ops while the listener already
served the object wire + admin plane (#718 item 2); the reconciliation landed
with the G13 parity families, which drive Aliases/AliasesSet/Reload (and the
blob pair) explicitly.

- **Bodies are the existing Layer-1 payloads** (`encoding` = `cxd` text or
  `astbin`), byte-identical to what CSRP carries — the message is an envelope, not
  a re-modeling of the document. There is no protobuf modeling of CX node
  structure.
- `Capabilities` returns the same `[capabilities …]` CX body (the bootstrap
  discovery form; the retired bearer `[auth …]` advert is gone — G2a) that
  the HTTP bootstrap endpoint returns.

## 3. Error identity (parity is normative)

A gRPC call maps the CSRP error onto the closest gRPC status **and** carries the
exact CXER code in the trailer, so the symbolic↔wire identity holds across both
transports — a client may key on the CXER code regardless of transport.

| CSRP | gRPC `status.code` | trailer `cx-err-code` |
|---|---|---|
| 400 `CXER1701` request malformed | `INVALID_ARGUMENT` (3) | `cx-err:CXER1701` |
| missing/invalid CxCall credential (`CXER5021`/`CXER5018`) | `UNAUTHENTICATED` (16) | `cx-err:CXER5021` / `cx-err:CXER5018` |
| authority deny (profile PEP, `CXER5021`) | `PERMISSION_DENIED` (7) | `cx-err:CXER5021` |
| 404 `CXER1721` not found | `NOT_FOUND` (5) | `cx-err:CXER1721` |
| 404 `CXER1709` operation unsupported | `UNIMPLEMENTED` (12) | `cx-err:CXER1709` |
| 404 `CXER1710` store not found | `NOT_FOUND` (5) | `cx-err:CXER1710` |
| 409 `CXER1114` concurrent modify (ref-conflict CAS — the ONE conflict code, E3/L84; the CSRP-era `CXER1704` is a tombstone, I1 row 15) | `ABORTED` (10) | `cx-err:CXER1114` |
| 413 `CXER1705` payload too large | `RESOURCE_EXHAUSTED` (8) | `cx-err:CXER1705` |
| 422 `CXER1720` integrity mismatch | `DATA_LOSS` (15) | `cx-err:CXER1720` |
| 429 `CXER1706` rate/concurrency | `RESOURCE_EXHAUSTED` (8) | `cx-err:CXER1706` |
| 500 `CXER1707` server internal | `INTERNAL` (13) | `cx-err:CXER1707` |
| 503 `CXER1708` unavailable | `UNAVAILABLE` (14) | `cx-err:CXER1708` |

429 and 413 both surface as `RESOURCE_EXHAUSTED`; the trailer CXER disambiguates.
The gRPC status is the coarse class; the CXER is the precise identity — the gRPC
analogue of CSRP carrying its own symbolic name alongside the HTTP status.

## 4. Auth & tenant

Authentication is **per-call XSP-AUTH** (RULED G1a/G2a/G3a, 2026-08-08 — the
bearer/RBAC plane is retired with the CSRP data plane; the gRPC edge runs
under the SAME authority calculus as the profile listener, with no second
implementation):

- The `authorization` call-metadata header carries a **CxCall credential**:
  `CxCall <base64url([grpc-call-auth did= at= nonce= path= body-sha256=
  sig= [vp …]?])>`. The ed25519 signature (by the presenting DID's key)
  covers the strict canonical text of `[grpc-call-auth-canonical did= at=
  nonce= path= body-sha256=]` — binding the credential to THIS call: the
  exact method path, the exact request-message bytes, a timestamp inside
  the freshness window (60 s), and a single-use nonce (server-side replay
  cache scoped to the window). The optional `[vp …]` is the profile's
  presentation form — a delegation VC chain whose terminal subject MUST be
  the signing DID — verified and compiled by the same code path the
  profile's `phase=present` uses.
- Authority: `[xsp [grants …]]` is the ONLY grant table. Grants configured
  ⇒ deny-by-default — every call needs a valid credential
  (missing/invalid → `UNAUTHENTICATED` 16), and the compiled per-call basis
  decides through the profile PEP (capability classes read/write/delete/
  admin; a deny → `PERMISSION_DENIED` 7 carrying the `[deny …]` value).
  No grants ⇒ the open/dev posture: data ops open, admin ops require a
  valid credential (the profile's mutual-gate analogue). The `[auth …]`
  config section is a HARD config error — cutover, no dual-accept.
- Tenant scoping rides the authority basis (delegations are tenant-scoped
  to the target mount), exactly as on the profile.
- Client identity comes from the same open-opts the profile client uses
  (`xsp-did` + `xsp-seed-env`); the seed never rides a URL or an opts
  literal. Revocation: the daemon's live revoked-set (folded on the
  profile listener) crosses into per-call verification; a credential from
  a revoked chain refuses at the next call.
- The DoS-fairness limiter and observability (metrics endpoint label,
  structured log, trace span) apply identically; the `endpoint` metric
  label folds the gRPC method name into the same bounded set. The
  bootstrap HTTP surface is health/ready/metrics/capabilities ONLY;
  `/metrics` is unauthenticated operator-plane (the bind address is the
  operator's control — standard scrapers cannot sign requests).

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

The gRPC edge is reachable from the normal store surface via two open
schemes, siblings of the profile's `cx-store(+xsp)://`:

- `cx-store+grpc://host[:port]/store-name/` — h2c (cleartext HTTP/2;
  loopback / dev).
- `cx-store+grpcs://host[:port]/store-name/` — HTTP/2 over TLS.

Client identity rides open-opts (`xsp-did` + `xsp-seed-env` — §4); the
client signs each call's CxCall credential with it. Absent identity =
anonymous (open-posture data ops only). The client dials through the
capability-gated, SSRF-guarded net dialer (TCP or TLS), issues one HTTP/2
stream per call, and reads the response frames plus the `grpc-status`
trailer, mapping it back onto the store error space (§3). Each operation
returns the same result shape as the local store builtins, so
`cx-store+grpc` is a drop-in store backend for gRPC-speaking environments —
the INTEGRATION edge; CX-to-CX deployments use the XSP store profile
(`cx-store://`), THE store wire.

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
