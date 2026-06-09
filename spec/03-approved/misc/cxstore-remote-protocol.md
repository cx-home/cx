# CXStore Remote Protocol (CSRP)

**Status:** Current for v0.8.0

Wire protocol for the Service tier of `cx-stdlib/store`. Companions:
[`spec/std-lib/store.md`](../std-lib/store.md) (client-side Store API),
[`spec/misc/bindings.md`](../misc/bindings.md) (Layer-1 16-method API
round-tripped by the protocol).

---

## 1 — Scope

CSRP is the wire protocol for server-side query pushdown in CXStore. A
client opens a Store via a `cx-store://host[:port]/store-name/` URL;
operations dispatch over CSRP to a remote server; the server runs
queries against its local data and streams matching documents back as
length-prefixed ast_bin records (parse-AST wire per
[`core/ast-bin.md`](../core/ast-bin.md)). Doc IDs carried in CSRP frames
are SHA-256 over the doc's strict canonical bytes per
[`core/canonical.md §§1.2, 4`](../core/canonical.md) — independent of
the ast_bin transport encoding.

CSRP is the **Service tier's protocol** in the embedded/service taxonomy:

- **Embedded tier** — client-process processing; byte-source backends
  (`file://`, `mem://`, `http://`, `s3://`, `ftp://`, `sftp://`).
  Specified by [`std-lib/store.md`](../std-lib/store.md).
- **Service tier** — server-process processing; network protocol (CSRP).
  Specified here.

The protocol is permanent. Future operational features (RBAC,
observability, gRPC alternative) layer on top without changing it.

## 2 — Conceptual model

A CSRP **server** wraps a local Store and exposes it over HTTP. A CSRP
**client** speaks the protocol via the `cx-store://` URL backend in
`cx-stdlib/store`. The client-side surface is identical to any other
backend; the difference is server-side execution.

| Operation | Embedded byte-source backend | CSRP Service backend (`cx-store://`) |
|---|---|---|
| `put-doc` | Encode → write bytes to remote | Encode → POST bytes; server writes |
| `get-doc` | GET remote bytes → decode | POST hash; server returns bytes |
| `query(cxpath)` | List → fetch each → parse → filter locally | POST query; **server executes**; binary matches stream back. Aggregate function-heads (`count`/`sum`/`avg`/`min`/`max`) are pushed down — server evaluates and returns a scalar (§3.2) |
| `list-docs` | Enumerate remote bytes | POST list-request; server returns hash sequence |
| `modify-doc` | Get → modify locally → put | POST modify-request; server modifies in place |
| `iter-docs` | Stream remote bytes → parse each | POST iter-request; server streams (hash, doc) pairs |

The qualitative win is `query`: server-side execution means a 1 M doc
corpus filtered to 50 matches transports only the 50 matches.

### 2.1 Wire format

HTTP/1.1 over TLS (HTTPS) recommended; plaintext HTTP supported for
development.

Request body: CX document as ast_bin (cxbin) by default; cxd-text
accepted via `Content-Type` negotiation. Either wire encoding decodes
to the same value and produces the same SHA-256 doc-ID at the client
after strict canonicalization (see §2.2 below and
[`core/canonical.md §§1.2, 4`](../core/canonical.md)).

Response body: streaming binary — concatenated length-prefixed ast_bin
records, chunked transfer encoding. Each chunk is
`[u32 length][ast_bin bytes]`.

Authentication: Bearer token in `Authorization: Bearer <token>` header.

### 2.2 Hash invariance

Per [`std-lib/store.md`](../std-lib/store.md), Layer-1 `hash(node)` is
SHA-256 over the document's **strict canonical bytes** (text default,
or `cx_to_data_bin` compact binary per
[`core/canonical.md §§1.2, 4`](../core/canonical.md)) — independent of
the wire encoding used to transport the document. CSRP responses with
cxbin and cxd encodings produce identical doc IDs at the client because
both decode to the same value and hash to the same canonical bytes.

## 3 — Endpoints

All endpoints rooted at `/cx-store/v1/`. Versioning is via the URL
prefix (`/v1/` → `/v2/` on incompatible breaks).

### 3.1 `GET /cx-store/v1/capabilities`

Discover server capabilities. Returned without authentication.

```cx
[capabilities
  [csrp-version "1.0"]
  [server-impl "cx-stdlib-store-ref" version="0.8.0"]
  [backend-tier "embedded"]
  [backend-name "file"]
  [encodings [supported "cxbin" "cxd"] [default "cxbin"]]
  [compressions [supported "zst" "gz" "none"] [default "zst"]]
  [query-features
    [cxpath true]
    [cxpath-axes "child" "descendant" "ancestor" "attribute" "self" "parent"]
    [predicates true]
    [push-down-filter true]
    [push-down-aggregate true]
    [push-down-aggregates "count" "sum" "avg" "min" "max"]]
  [auth [bearer true] [mtls false] [anonymous false]]
  [read true] [write true] [list true] [iter true]
  [max-request-bytes 16777216]
  [max-response-bytes 0]
  [rate-limit
    [requests-per-minute 600]
    [bytes-per-second 104857600]]]
```

**Per-store scope.** A server may expose multiple named stores (§6);
capabilities reflect the addressed store. The `backend-tier` /
`backend-name` and write/read/list/iter flags describe that store's
backend.

The client uses `capabilities` to decide whether to push down a query
or fall back to byte-transport. If `push-down-filter` is false, the
client uses `list` + `get-doc`.

### 3.2 `POST /cx-store/v1/query`

Push down a CXPath query. Request body:

```cx
[query
  [cxpath "//user[@active=true]/@email"]
  [limit 100]
  [offset 0]
  [encoding "cxbin"]
  [shape "matches"]]
```

`shape` is one of `"matches"` / `"doc-pairs"` / `"aggregate"`.

Response: streaming binary. Frame format:

```
[u32 frame_length][u8 frame_kind][frame_payload]
```

Frame kinds:
- `0x01` — **doc-pair**: `[u8 hash[32]][u32 ast_bin_len][ast_bin_bytes]`
- `0x02` — **match**: `[u8 hash[32]][u32 ast_bin_len][ast_bin_bytes]`
- `0x03` — **error**: `[u32 code_len][code_bytes][u32 msg_len][msg_bytes]` (terminal)
- `0x04` — **end**: `[u32 total_count]` (terminal success)
- `0x05` — **aggregate-result**: `[u32 ast_bin_len][ast_bin_bytes]` (terminal success; single scalar)

Streaming continues until an error frame (`0x03`) or a terminal success
frame (`0x04` end or `0x05` aggregate-result) is received.

#### Push-down aggregates

When the request `cxpath` is an aggregate function-call at expression
head (`count(...)`, `sum(...)`, `avg(...)`, `min(...)`, `max(...)` per
[`core/code.md`](../core/code.md)), the server evaluates the aggregate
server-side and returns the scalar result. The client signals with
`[shape "aggregate"]`. The server responds with exactly one `0x05`
frame, then ends the stream. On failure the server returns a `0x03`
error frame.

A client MUST check `query-features.push-down-aggregate` before sending
`[shape "aggregate"]`; if unsupported, it falls back to
`[shape "matches"]` and reduces client-side.

### 3.3 `POST /cx-store/v1/get`

Fetch a single document by hash. Request body:

```cx
[get hash="abc123..."]
```

- **Happy path** — `HTTP 200` with the raw ast_bin doc bytes as the
  entire body.
- **Not found** — `HTTP 404` with an error-frame body carrying
  `CXER1721`.
- **Integrity mismatch** — `HTTP 422` with a single `0x03` error frame
  carrying `CXER1720`.

`/get` never returns `200` with an error frame.

### 3.4 `POST /cx-store/v1/put`

Store a document. Request body: raw ast_bin bytes (or cxd text per
`Content-Type`). Response body:

```cx
[put-result hash="abc123..." stored=true]
```

`stored=false` indicates the doc was already present (content-addressed
dedup).

### 3.5 `POST /cx-store/v1/delete`

Delete a document by hash.

```cx
[delete hash="abc123..."]
```

Response:

```cx
[delete-result hash="abc123..." deleted=true]
```

### 3.6 `POST /cx-store/v1/list`

List all hashes in the store. Request body:

```cx
[list [limit 1000] [cursor "..."]]
```

Response body (streaming if many hashes):

```cx
[list-result
  [hashes [sequence "abc123..." "def456..."]]
  [next-cursor "..."]
  [total-count 1234]]
```

### 3.7 `POST /cx-store/v1/iter`

Stream all (hash, doc) pairs. Request body:

```cx
[iter [cursor "..."] [encoding "cxbin"]]
```

Response: streaming binary, same frame format as `/query` with
`frame_kind 0x01` doc-pair frames. Iteration order is
implementation-defined but stable for a given server instance.

### 3.8 `POST /cx-store/v1/modify`

Apply a `[?modify]`-style action to a document.

```cx
[modify hash="abc123..." action=[action set=[...] focus=...]]
```

Response:

```cx
[modify-result old-hash="abc123..." new-hash="def456..." stored=true]
```

The modified document is stored as a new content-addressed entry; the
original remains immutable.

## 4 — Error mapping

CSRP errors reuse client-side `cx-stdlib/store` codes (CXER1100-1132)
where they overlap and define CSRP-specific codes (CXER1700-1708) for
the rest.

| HTTP status | Error code | Mnemonic | Meaning |
|---|---|---|---|
| 200 + `0x03` frame | `CXER1700` | `E_CSRP_QUERY_FAILED` | Query execution failed server-side |
| 400 | `CXER1701` | `E_CSRP_REQUEST_MALFORMED` | Request body unparseable or schema-invalid |
| 401 | `CXER1702` | `E_CSRP_AUTH_REQUIRED` | Missing Bearer token |
| 403 | `CXER1703` | `E_CSRP_AUTH_REJECTED` | Token rejected |
| 404 | `CXER1721` | `E_CSRP_NOT_FOUND` | Hash doesn't exist (distinct wire code from `CXER1121 E_STORE_NOT_FOUND` in std-lib/store.md; CSRP carries its own symbolic name to preserve the 1:1 symbolic↔wire invariant) |
| 409 | `CXER1704` | `E_CSRP_CONCURRENT_MODIFY` | Modify conflict |
| 413 | `CXER1705` | `E_CSRP_PAYLOAD_TOO_LARGE` | Request exceeded `max-request-bytes` |
| 422 | `CXER1720` | `E_CSRP_INTEGRITY_MISMATCH` | `/get` corruption detected (distinct wire code from `CXER1120 E_STORE_INTEGRITY_MISMATCH` in std-lib/store.md; CSRP carries its own symbolic name to preserve the 1:1 symbolic↔wire invariant) |
| 429 | `CXER1706` | `E_CSRP_RATE_LIMITED` | Rate limit hit; `Retry-After` header set |
| 500 | `CXER1707` | `E_CSRP_SERVER_INTERNAL` | Unspecified server error |
| 503 | `CXER1708` | `E_CSRP_SERVER_UNAVAILABLE` | Server overloaded or shutting down |

CSRP error code allocation: **1700–1708** (CSRP-specific). Codes
**1720** and **1721** are aliases of `std-lib/store.md` `CXER1120` and
`CXER1121` carried over the wire.

Client-side translates these into the standard `cx-stdlib/store` error
codes where they overlap.

## 5 — URL scheme and connection model

### 5.1 `cx-store://` URL syntax

```
cx-store://[user@]host[:port]/store-name/
cx-store+https://host/store-name/
cx-store+http://host/store-name/
```

- `host[:port]` — Service node hostname and port. Default port: 7800.
- `store-name` — opaque path identifying which store on the server.
- `user@` — optional username (passed to `Authorization` lookup).

Bare `cx-store://` defaults to HTTPS. Plaintext requires
`cx-store+http://`.

### 5.2 Connection lifecycle

The CSRP client maintains a persistent connection pool. HTTP/1.1
keep-alive is required; connections are reused; idle connections close
after 60 seconds. Default pool size: 8.

### 5.3 Capability discovery

On `cxstore.open("cx-store://host/store-name/")`, the client:

1. Issues `GET /cx-store/v1/capabilities` (no auth).
2. Validates `csrp-version` (semver: same major, server's minor ≥
   client's).
3. Caches the capability profile.
4. Stores the auth provider per `opts.auth.bearer-token`.

Operations the server doesn't support raise `CXER1709
E_CSRP_OPERATION_UNSUPPORTED` client-side without round-tripping.

## 6 — Reference server

The reference server is multi-store: a single node exposes multiple
named stores, routing by the `store-name` path component. The server
is configured with a `store-name → backend URL` mapping and composed
from the `[?http-service]` / `[resource]` surface in
[`core/code.md §10.3`](../core/code.md).

```cx
[?lib 'cx-stdlib/store']

[?const STORES
  [stores
    [store name="corpus-a" url="file:///var/data/a/"]
    [store name="corpus-b" url="s3://bucket/b/"]]]

[?const AUTH_TOKEN [env/var "CSRP_BEARER_TOKEN"]]

[?http-service on=http port=7800 name="csrp-ref"
  [resource [get "/cx-store/v1/:store-name/capabilities"]
    [?let $store=[csrp/resolve-store STORES [/ $request path-params store-name]]
      [csrp/capabilities-response $store]]]
  [resource [post "/cx-store/v1/:store-name/query"]
    [auth [bearer AUTH_TOKEN]]
    [?let $store=[csrp/resolve-store STORES [/ $request path-params store-name]]
          $req=[cxbin/parse [/ $request body]]
          $cxpath=[/ $req cxpath]
          $shape=[/ $req shape default="matches"]
          $limit=[/ $req limit default=0]
      [csrp/stream-query $store $cxpath $shape $limit]]]
  [resource [post "/cx-store/v1/:store-name/put"]    [auth [bearer AUTH_TOKEN]]
    [?let $s=[csrp/resolve-store STORES [/ $request path-params store-name]] [csrp/respond-put $s [/ $request body]]]]
  [resource [post "/cx-store/v1/:store-name/delete"] [auth [bearer AUTH_TOKEN]]
    [?let $s=[csrp/resolve-store STORES [/ $request path-params store-name]] [csrp/respond-delete $s [cxbin/parse [/ $request body]]]]]
  [resource [post "/cx-store/v1/:store-name/list"]   [auth [bearer AUTH_TOKEN]]
    [?let $s=[csrp/resolve-store STORES [/ $request path-params store-name]] [csrp/respond-list $s [cxbin/parse [/ $request body]]]]]
  [resource [post "/cx-store/v1/:store-name/iter"]   [auth [bearer AUTH_TOKEN]]
    [?let $s=[csrp/resolve-store STORES [/ $request path-params store-name]] [csrp/respond-iter $s [cxbin/parse [/ $request body]]]]]
  [resource [post "/cx-store/v1/:store-name/modify"] [auth [bearer AUTH_TOKEN]]
    [?let $s=[csrp/resolve-store STORES [/ $request path-params store-name]] [csrp/respond-modify $s [cxbin/parse [/ $request body]]]]]]
```

Requests for an unconfigured `store-name` raise `CXER1721`
`E_CSRP_NOT_FOUND` (404). Stores are isolated — a hash in `corpus-a`
is invisible to `corpus-b` requests.

`csrp/stream-query` dispatches on `$shape` — `"matches"` /
`"doc-pairs"` stream framed docs, `"aggregate"` evaluates the aggregate
function-head server-side and emits a single `0x05` frame.

Run as: `cx serve-store --config server-config.cx --bind 0.0.0.0:7800`.

## 7 — Conformance fixtures

Under `conformance/csrp.txt`:

- **Capabilities discovery:** `GET /cx-store/v1/capabilities` without
  auth returns valid capabilities element.
- **Query pushdown:** server-side CXPath evaluation matches client-side
  evaluation over same data.
- **Aggregate pushdown:** `count(//user[@active=true])` with
  `[shape "aggregate"]` returns the correct scalar in a single `0x05`
  frame.
- **Streaming response framing:** multi-match query produces
  correctly-framed binary stream.
- **Cross-encoding parity:** cxbin and cxd response encodings produce
  identical doc IDs at the client.
- **Auth required / rejected:** 401 `CXER1702`; 403 `CXER1703`.
- **Not found:** `POST /get` with non-existent hash returns 404
  `CXER1721`.
- **Integrity mismatch (/get):** `POST /get` for corrupted bytes
  returns `HTTP 422` with `0x03` error-frame `CXER1720`.
- **Integrity mismatch (/query mid-stream):** corrupted bytes
  mid-stream produce a `0x03` error frame `CXER1720`.
- **Put dedup:** same doc PUT twice; second response has
  `stored=false`.
- **Modify produces new hash:** result has distinct `old-hash` /
  `new-hash`.
- **Connection reuse:** N requests share one connection.
- **Capability-driven fallback:** server reports
  `push-down-filter=false`; client falls back to list+get.
- **Cross-tier portability:** a doc stored via `file://` Embedded
  gets the same hash when retrieved via `cx-store://` Service.
- **Multi-store isolation:** a hash present in `corpus-a` returns 404
  under `corpus-b`.
- **Rate limiting:** rapid requests hit `CXER1706` 429 with
  `Retry-After`.

## 8 — Cross-references

- [`std-lib/store.md`](../std-lib/store.md) — client-side Store API.
- [`core/code.md`](../core/code.md) — `[?service]` directive and
  CXPath aggregate function-heads.
- [`misc/bindings.md`](../misc/bindings.md) — Layer-1 16-method API
  round-tripped by the protocol.
- [`core/ast-bin.md`](../core/ast-bin.md) — wire encoding format for
  response streams.
