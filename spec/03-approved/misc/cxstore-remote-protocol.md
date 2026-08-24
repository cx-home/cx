# CXStore Remote Protocol (CSRP) — RETIRED (historical)

**Status:** RETIRED (2026-08-08, stream-4 S3). This document is a
**historical record** of the removed CSRP data plane; it is no longer
normative. The stream-4 ruling (#676, the #651/#516 partition campaign;
the §13 CSRP-fold decision) retired CSRP: its routers, binary codec,
client arms, HTTP data-plane, and the `cx-store+http|+https` scheme
tokens are **deleted** (the tokens now refuse at open). The `17xx` error
band is Reserved (retired, never reused).

**The live wire** is the **XSP store profile** — THE CX-to-CX store wire
([`std-lib/store.md §6.4`](../std-lib/store.md); the store profile spec) —
with the **gRPC edge adapter** ([`cxstore-grpc.md`](cxstore-grpc.md)) as
the integration transport for gRPC-speaking systems, both authenticated
per-call by XSP-AUTH. The daemon's HTTP surface is now bootstrap-only
(health/ready/metrics/capabilities). The op contracts, error identity,
and hash invariance below carried forward to the profile verbatim (that
was the parity obligation); the transport framing they describe is gone.
The V wire tests named in §7 (`store_csrp_*`, `store_keepalive_test.v`,
`store_discovery_test.v`, `store_grpc_parity_test.v`, `store_authz*`) were
removed with the plane; the surviving coverage lives in the profile +
gRPC-edge suites (`store_xsp_*`, `store_grpc_*`, `store_grpc_call_auth_test.v`).
The body is preserved unedited below for historical reference.

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

The protocol is TRANSITIONAL (see the retirement banner above — the
"permanent" claim this paragraph once made contradicted the CSRP-fold
ruling and is struck). Operational features (RBAC, observability) layer on
top without changing it. An optional gRPC transport offers the same operation set
at normative parity — specified by [`cxstore-grpc.md`](cxstore-grpc.md).

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

Media types (negotiation tokens):

| Media type | Body |
|---|---|
| `application/cx-astbin` | a single ast_bin document (default request encoding; `/get` happy-path response; result documents when cxbin is negotiated) |
| `application/cx` | the canonical-text alternative for the same bodies (negotiated via `Content-Type` on requests, `Accept` on responses). The former `text/cx` token is RETIRED (stream 13 ruling 61): `text/*` invites charset/line-ending normalization by intermediaries, which corrupts content addresses. |
| `application/cx-frame-stream` | a framed streaming response (§3.2 frame format; used by `/query`, `/iter`, and streaming `/list`) |

**Every operation parameter rides in the request body.** CSRP defines
no URL query parameters: the URL carries only the version prefix, the
store-name, and the operation name (§3). A server MUST ignore nothing —
a request whose parameters are missing from the body is
`400 CXER1701`, regardless of what the URL carries.

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

All **store** endpoints are rooted at `/cx-store/v1/<store-name>/` — the
`<store-name>` is the path component of the `cx-store://host/<store-name>/`
URL (§5.1), letting one daemon serve many mounts (the substrate for
store-per-tenant isolation). A single-mount server also accepts the
`/cx-store/v1/<op>` shorthand. The **server-level** endpoints
(`capabilities`, `health`, `ready`) are rooted at `/cx-store/v1/` with no
store-name; `capabilities` additionally has a per-store form (§3.1).
`<store-name>` is `[A-Za-z0-9_-]{1,128}` — so it can never carry
path traversal (`..`, `/`), percent-encoding, or whitespace; an unknown or
malformed name resolves to `404 CXER1710 E_CSRP_STORE_NOT_FOUND` (never
normalized; a wire code distinct from the hash-level `CXER1721`, and — per
the §4 invariant — the std-lib `CXER1121` never rides the wire). On a
multi-mount server the bare shorthand is ambiguous and is likewise
`404 CXER1710` ("store name required"). An unknown *operation* name is
`404 CXER1709 E_CSRP_OPERATION_UNSUPPORTED` (§4). Each store is a separate
content-address / dedup pool, so a request authorized for store A can never
observe store B's content or its existence (no cross-tenant hash probing).

The endpoint headings below show the sole-store shorthand; on a multi-mount
server each store op is correspondingly `/cx-store/v1/<store-name>/<op>`.

Versioning is via the URL prefix (`/v1/` → `/v2/` on incompatible breaks).

### 3.1 `GET /cx-store/v1/capabilities` · `GET /cx-store/v1/<store-name>/capabilities`

Capability discovery has two forms:

- **Server-level** (`/cx-store/v1/capabilities`) — always served
  **without authentication** (the §5.3 bootstrap). It carries the
  server-wide profile only: `csrp-version`, `server-impl`, `encodings`,
  `compressions`, `auth`, `max-request-bytes`/`max-response-bytes`,
  `rate-limit`, and `admin-ops` — the list of admin-plane op names this
  server serves (`"status" "gc" "mounts" "config-reload"` on the current
  daemon; the embedded reference server advertises what it actually
  routes). A management client (#249 console) drives feature degradation
  off this list rather than probing ops for 404s: an op absent from
  `admin-ops` is treated as unsupported client-side (the §5.3
  `CXER1709` pre-flight applies). The list names ops, not permissions —
  whether the *principal* may call them is still RBAC's answer at call
  time. It carries **no** backend or store fields (a server serves many
  stores; there is no server-wide backend).
- **Per-store** (`/cx-store/v1/<store-name>/capabilities`) — the full
  advert below, including `backend-tier`/`backend-name`,
  `query-features`, and the store's true `read`/`write`/`list`/`iter`
  flags. Resolution happens **before** the response: an unknown
  store-name is `404 CXER1710`, never a generic `200`. When the server
  enforces authentication, the per-store form requires the store's
  `read` permission (store names and backend shapes are
  tenant-scoped facts); when auth is not enforced it is open like the
  server-level form.

Both forms carry **`[config-generation N]`** (stream 7 F3, #714 item 3):
the advert **binds the daemon's config-reload generation** — the same
counter `config-reload` (§3.13) answers. The daemon computes the advert
live per request, so the server can never serve a stale one; the binding
rule is for **clients**: a cached advert (capability profile, and any
guarantee advert that rides it) is valid only for the generation it was
fetched under — **a cached advert across `config-reload` is a cached
lie** ([`consistency_vocabulary.md`](../core/consistency_vocabulary.md)
§3), and a consumer that observes a different generation MUST re-fetch
before relying on any advertised fact.

```cx
[capabilities
  [csrp-version "1.0"]
  [server-impl "cx-stdlib-store-ref" version="0.8.0"]
  [config-generation 0]
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
the per-store form reflects the addressed store. The `backend-tier` /
`backend-name` and write/read/list/iter flags describe that store's
backend, truthfully — a flag MUST NOT advertise an ability the
backend does not deliver.

`[auth [mtls …]]` is an **optional** feature flag: a server that does
not implement mTLS advertises `[mtls false]` (never omits the field,
never advertises `true` aspirationally).

The client uses `capabilities` to decide whether to push down a query
or fall back to byte-transport. If `push-down-filter` is false, the
client uses `list` + `get-doc`.

### 3.2 `POST /cx-store/v1/query`

Push down a CXPath query. Request body:

```cx
[query
  [cxpath "//user[= $_@active true]/@email"]
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
- `0x01` — **doc-pair**: `[u16 hash_algo_code BE][u8 digest[32]][u32 ast_bin_len][ast_bin_bytes]`
- `0x02` — **match**: `[u16 hash_algo_code BE][u8 digest[32]][u32 ast_bin_len][ast_bin_bytes]`
- `0x03` — **error**: `[u32 code_len][code_bytes][u32 msg_len][msg_bytes]` (terminal)
- `0x04` — **end**: `[u32 total_count]` (terminal success)
- `0x05` — **aggregate-result**: `[u32 ast_bin_len][ast_bin_bytes]` (terminal success; single scalar)

Streaming continues until an error frame (`0x03`) or a terminal success
frame (`0x04` end or `0x05` aggregate-result) is received.

`hash_algo_code` is the multicodec code of the algorithm naming the
32-byte digest slot (`sha2-256` = `0x0012`), drawn from THE ONE hash
registry — the same convention as the `.cxpack` entry's `hash_code`
field. Writers derive it from the store key's tagged address
(`sha2-256:<hex>`); readers FAIL CLOSED on an unregistered or
registered-but-unimplemented code (`cx-err:CXER0131`) and reconstruct
the tagged address `<registry-name>:<hex>` from the code — a bare
untagged hex never crosses this boundary in either direction. All 1.0
registry algorithms have 32-byte digests; a non-32-byte digest
requires a frame-format revision.

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
[modify hash="abc123..." action=[action set=[server host="newhost"] focus="config/server"]]
```

Response:

```cx
[modify-result old-hash="abc123..." new-hash="def456..." stored=true]
```

The modified document is stored as a new content-addressed entry; the
original remains immutable.

### 3.9 `GET /cx-store/v1/health` · `GET /cx-store/v1/ready`

Liveness and readiness probes. Server-level (no store-name), always
**unauthenticated** (like server-level `capabilities`), exempt from
rate limiting.

- `health` — the process is up and the serve loop is dispatching.
  `200` with body `[health [status "ok"]]`.
- `ready` — the daemon can serve traffic: stores opened, accepting
  connections, not draining. `200` with body
  `[ready [accepting true] [draining false]]` when ready;
  `503 CXER1708` with the same body shape (`accepting`/`draining`
  reflecting the actual state) when not — so a load balancer stops
  routing during graceful drain (readiness flips false at drain start).

### 3.10 `GET /cx-store/v1/<store-name>/status` *(admin)*

The **admin-plane introspection** op: the wire form of the store porcelain's
`status` (std-lib `store.md` — one name across the CX surface and the wire).
Requires the `admin` permission (App C of the service-tier spec) and is
tenant-scoped like every store op; unauthenticated → `401 CXER1702`,
authenticated-but-not-admin → `403 CXER1703`.

`200` with the same `[status …]` element the local porcelain returns —
`backend` plus, for an object-graph store, the object economy
(`docs`, `objects`, `logical`, `distinct`, `unflushed`); other backends
report their own observables and never fabricate object-graph numbers.
This is the structured management surface — `/metrics` (Prometheus
exposition text, `metrics` permission) is for scrapers, not consoles.
No request parameters; the response is an `application/cx` body.

### 3.11 `POST /cx-store/v1/<store-name>/gc` *(admin)*

The **compaction/maintenance trigger**: the wire form of the porcelain's
`gc` (prune unreachable objects + make the result durable via the
substrate's compaction). `admin` permission, tenant-scoped.

`200` with the porcelain's `[gc-result reclaimed=N objects=N]`. A store
whose backend has no object graph to collect (document model, columnar,
byte-source remotes) is `404 CXER1709 E_CSRP_OPERATION_UNSUPPORTED` —
the same honest fail-closed the porcelain raises locally. A read-only
mount is `400 CXER1701` (matching the read-only mapping of the other
write-shaped ops). Empty request body.

### 3.12 `GET /cx-store/v1/mounts` *(admin, server-level)*

Daemon-level **mount enumeration** — the discovery surface a management
client needs (per-store `capabilities` requires knowing the name a
priori). Server-level (no store-name) but — unlike `capabilities`/
`health`/`ready` — **authenticated**: `admin` permission required, and
the result is **tenant-filtered**: only mounts the principal's tenant
allows appear (a principal can never enumerate — or learn the existence
of — stores outside its tenant, preserving §3's no-cross-tenant-probing
invariant).

`200` with:

```
[mounts
  [mount name="docs"  backend="cxpack" read=true write=true list=true]
  [mount name="audit" backend="sqlite" read=true write=false list=true]]
```

one `[mount]` per visible store (sorted by name; deterministic), the
flags reflecting the mount's real capability trait (the same source as
per-store `capabilities`). An empty (but authorized) enumeration is
`200 [mounts]`, never an error. On the embedded single-store reference
server the op is not served (`404 CXER1709`) — mounts are a service-tier
(daemon) concept.

### 3.13 `POST /cx-store/v1/config-reload` *(admin, server-level)*

Daemon-level **runtime config reload** — re-read, validate, and apply the
hot-reloadable subset of the daemon's config document without a restart
(the service-tier spec's §2.6 defines which attrs are hot vs
restart-required; the driver is credential and TLS-certificate rotation).
Server-level and **tenant-agnostic** like `mounts` — `admin` permission
required (`401 CXER1702` / `403 CXER1703`); the op is daemon-global, so a
tenant-scoped admin reloading config affects the whole daemon (config is
already daemon-global state; the spec calls this out rather than hiding
it). Empty request body.

Semantics are **validate-then-swap, fail-closed**:

- The daemon re-reads its own config source (the `--config` path it was
  started with — the op carries no config content; the console *triggers*
  reload, it never *writes* config), fully parses + cross-validates the
  candidate, and only then applies. Any validation error leaves the
  running config untouched: `400 CXER1711 E_SVC_CONFIG_INVALID` with the
  parse diagnostic in the message.
- A candidate that changes a **restart-required** attr is refused whole —
  never partially applied — with `400 CXER1712
  E_SVC_CONFIG_RESTART_REQUIRED`, the message naming every offending
  attr. Hot changes riding in the same candidate are NOT applied (a
  reload is atomic: all-or-nothing).
- Success is `200` with the applied outcome:

```
[config-reload applied=true generation=2 changed="auth limits tls"]
```

`generation` counts successful applies since start (0 = startup config);
`changed` lists the hot subsystems that actually differed (an unchanged
file is `200 [config-reload applied=false generation=1 changed=""]` — a
no-op reload is success, not an error). In-flight requests always finish
under the config they started with; the next request observes the new
snapshot. Existing TLS sessions keep their negotiated identity; new
handshakes present the re-read certificate.

The same reload path is triggered process-locally by `SIGHUP`
(service-tier §2.6); signal and wire trigger share one implementation and
one outcome log/metric. On the embedded reference server the op is not
served (`404 CXER1709`) — there is no daemon config to reload. gRPC
parity: the `Reload` method routes through the same pipeline and carries
the same `cx-err-code` trailer on refusal (§6.1).

### 3.14 `POST /cx-store/v1/aliases` · `POST /cx-store/v1/aliases-set` *(alias remoting)*

The **mutable-pointer layer over the wire**: a client's `get-alias` /
`list-aliases` / `set-alias` on a `cx-store://` handle resolve against the
mount's **authoritative alias table** — one authority, so target-presence
enforcement, gc pinning, and the durable alias records apply on the daemon
exactly as for an in-process `set-alias`. This supersedes the earlier
blanket "CSRP carries no alias verbs" refusal *for CSRP handles only*: the
original concern (a remote miss indistinguishable from absence — the
silent-empty lie) is answered by **explicit per-name presence** in the
response, never assumed by the client. Byte-source remotes (`http(s)`,
`ftp(s)`, `sftp` document sources) still refuse alias ops with
`404 CXER1709` — there is no service to ask.

**`aliases`** (permission: `read`) resolves named entries and/or lists the
table:

```
[aliases [k name="users"] [k name="head"]]        → 200
[aliases-result [a name="users" hash="<store-key>" present="true"]
                [a name="head" present="false"]]

[aliases all="true"]                              → 200, every present entry
```

A name the daemon does not hold answers `present="false"` — a
**server-asserted absence** the client surfaces as the absence channel
`()`, exactly like a local miss. The client never fabricates an empty
result from a transport failure: a non-2xx surfaces as the transport /
auth error, distinct from absence.

**`aliases-set`** (permission: `write`) applies alias writes through the
same arm as a local `set-alias`:

```
[aliases-set [a name="users" hash="<store-key>"]]                → 200 [aliases-set-result set="1"]
[aliases-set [a name="head" hash="<k2>" expect="<k1>"]]          → 200 (CAS advance)
[aliases-set [a name="head" hash="<k1>" expect=""]]              → 409 CXER1114 (exists)
```

- Every target `hash` must already be present on the daemon (a data doc or
  a `code:`-namespace def) — a missing target is `404 CXER1721`
  (`E_CSRP_NOT_FOUND`, the wire alias of the local `CXER1121` this same
  refusal raises in-process). Aliases can never dangle, remote or local.
- An optional per-record `expect="<store-key>"` makes the write a
  **compare-and-set**: it applies only if the alias currently resolves to
  `expect` (`expect=""` ⇒ the alias must not exist yet). Semantics mirror
  `refs-set` (#218): **validate-then-apply, all-or-nothing** across the
  records of one request, under the store's op lock; a mismatch is
  `409 CXER1114` and nothing is applied. This is the conflict-safe pointer
  advance a remote journal head rides. Records without `expect` keep
  last-writer-wins (the local single-writer contract of §6.2).
- A read-only mount refuses with `400` carrying the local read-only code,
  matching the other write-shaped ops.

**Deliberately not carried**: `delete-alias` (no wire consumer; deletion
stays a daemon-local operation and the client refuses with `404 CXER1709`
rather than mutating dead client-side state). gRPC parity: `Aliases` /
`AliasesSet` ride the same object-wire body shape through the same route
(§6.1).

## 4 — Error mapping

CSRP errors reuse client-side `cx-stdlib/store` codes (CXER1100-1132)
where they overlap and define CSRP-specific codes (CXER1700-1708) for
the rest.

| HTTP status | Error code | Mnemonic | Meaning |
|---|---|---|---|
| 200 + `0x03` frame | `CXER1700` | `E_CSRP_QUERY_FAILED` | Query execution failed server-side |
| 400 | `CXER1701` | `E_CSRP_REQUEST_MALFORMED` | Request body unparseable or schema-invalid |
| 401 | `CXER1702` | `E_CSRP_AUTH_REQUIRED` | Missing **or invalid/rejected** Bearer credential — i.e. *unauthenticated* (RFC 9110 §15.5.2: 401 is the authN failure; a rejected token is reported here, not at 403) |
| 403 | `CXER1703` | `E_CSRP_FORBIDDEN` | *Authenticated* but not permitted: the principal's role lacks the op's permission, or its tenant is not allowed the target store (RBAC + tenant, App C). RFC 9110 §15.5.4 |
| 404 | `CXER1721` | `E_CSRP_NOT_FOUND` | Hash doesn't exist (distinct wire code from `CXER1121 E_STORE_NOT_FOUND` in std-lib/store.md; CSRP carries its own symbolic name to preserve the 1:1 symbolic↔wire invariant) |
| 404 | `CXER1709` | `E_CSRP_OPERATION_UNSUPPORTED` | The operation is unknown to / unsupported by this server. Also raised **client-side without a round-trip** when `capabilities` says the op is unsupported (§5.3) |
| 404 | `CXER1710` | `E_CSRP_STORE_NOT_FOUND` | Unknown, malformed, or ambiguous `<store-name>` (§3; wire alias of std-lib `CXER1121` at store granularity) |
| 400 | `CXER1711` | `E_SVC_CONFIG_INVALID` | `config-reload` candidate failed parse/validation — running config untouched (§3.13; also the daemon's startup fast-fail diagnostic, service-tier §2.2) |
| 400 | `CXER1712` | `E_SVC_CONFIG_RESTART_REQUIRED` | `config-reload` candidate changes restart-required attrs (named in the message) — nothing applied (§3.13) |
| 409 | `CXER1114` | `E_STORE_REF_CONFLICT` | Modify conflict |
| 413 | `CXER1705` | `E_CSRP_PAYLOAD_TOO_LARGE` | Request exceeded `max-request-bytes` |
| 422 | `CXER1720` | `E_CSRP_INTEGRITY_MISMATCH` | `/get` corruption detected (distinct wire code from `CXER1120 E_STORE_INTEGRITY_MISMATCH` in std-lib/store.md; CSRP carries its own symbolic name to preserve the 1:1 symbolic↔wire invariant) |
| 429 | `CXER1706` | `E_CSRP_RATE_LIMITED` | The client is over its allowance — per-principal **rate or concurrency**, or the pre-auth admission cap. `Retry-After` set. (RFC 6585: 429 = too many requests; concurrency over-quota is the client's load, so 429, not 503.) |
| 500 | `CXER1707` | `E_CSRP_SERVER_INTERNAL` | Unspecified server error |
| 503 | `CXER1708` | `E_CSRP_SERVER_UNAVAILABLE` | The server is not in a state to serve: draining / not-yet-ready / overloaded. `Retry-After` set. (RFC 9110 §15.6.4.) |

CSRP error code allocation: **1700–1710** (CSRP-specific; `1709` is
also raised client-side pre-flight per §5.3). Codes **1711** and
**1712** are service-tier config diagnostics (`E_SVC_*`, service-tier
§2.2/§2.6) that ride the wire only on the `config-reload` op (§3.13).
Codes **1720** and **1721** are wire aliases of `std-lib/store.md`
`CXER1120` and `CXER1121` (document granularity); `1710` is the
store-granularity alias of `CXER1121`. Std-lib codes themselves never
ride the wire.

A wire error encodes the **client's situation** (the HTTP status semantics),
not the server's internal reason. So the service tier (the single-node daemon)
reuses these same codes rather than minting parallel ones: every admission
rejection — per-principal rate, per-principal concurrency, the pre-auth global
cap — is `429 CXER1706`, and every not-serving state — draining, not-yet-ready,
overloaded — is `503 CXER1708`. Which limiter tripped is observable on the
server (`/metrics`, structured logs), but it is not a distinct wire code: a
client's action is the same (`429` → back off + honor `Retry-After`; `503` →
retry later / fail over).

Client-side translates these into the standard `cx-stdlib/store` error
codes where they overlap.

## 5 — URL scheme and connection model

### 5.1 `cx-store://` URL syntax

```
cx-store://[token@]host[:port]/store-name/
cx-store+https://[token@]host[:port]/store-name/
cx-store+http://[token@]host[:port]/store-name/
```

- `host[:port]` — Service node hostname and port. The default port
  follows the underlying transport: `443` for HTTPS (bare `cx-store://`
  and `cx-store+https://`), `80` for `cx-store+http://` — so a CSRP
  server sits behind standard HTTP infrastructure with no port
  ceremony.
- `store-name` — the store to address on the server; it maps to the
  `/cx-store/v1/<store-name>/` request path segment (§3). Grammar:
  `[A-Za-z0-9_-]{1,128}`.
- `token@` — optional **bearer token**, carried as
  `Authorization: Bearer <token>` on every request (identical to the
  gRPC scheme's userinfo, [`cxstore-grpc.md §6`](cxstore-grpc.md)).
  Prefer supplying the token via `opts.auth.bearer-token` / environment
  configuration; a URL-embedded credential is convenient for dev but
  leaks through logs and shell history.

Bare `cx-store://` defaults to HTTPS. Plaintext requires
`cx-store+http://`. The gRPC transport is selected by the parallel
`cx-store+grpc://` / `cx-store+grpcs://` schemes
([`cxstore-grpc.md §6`](cxstore-grpc.md)) — the wire axis is a scheme
token, identical URL shape otherwise.

### 5.2 Connection lifecycle

The CSRP client maintains a persistent connection pool. HTTP/1.1
keep-alive is required; connections are reused; idle connections close
after 60 seconds. Default pool size: 8.

### 5.3 Capability discovery

On `cxstore.open("cx-store://host/store-name/")`, the client:

1. Issues the **server-level** `GET /cx-store/v1/capabilities`
   (no auth, §3.1) — version, encodings, auth methods.
2. Validates `csrp-version` (semver: same major, server's minor ≥
   client's).
3. Stores the auth provider per `opts.auth.bearer-token`.
4. Fetches the **per-store**
   `GET /cx-store/v1/<store-name>/capabilities` (authenticated when
   the server enforces auth) and caches the capability profile;
   `404 CXER1710` here fails the open (unknown store).

Operations the server doesn't support raise `CXER1709
E_CSRP_OPERATION_UNSUPPORTED` client-side without round-tripping.

## 6 — Reference server

The reference server is the **`cx store-serve` daemon**: a single node
exposes multiple named stores, routing by the `store-name` path
component. It is configured with a CX config document mapping
`store-name → backend URL` (the service-tier config schema — see the
service-tier spec's Appendix A):

```cx
[cxstore-service
  [bind addr="0.0.0.0:7800"]
  [stores
    [store name="corpus-a" url="file:///var/data/a/"]
    [store name="corpus-b" url="s3://bucket/b/"]]]
```

Run as: `cx store-serve --config server-config.cx`.

Requests for an unconfigured `store-name` raise `CXER1710`
`E_CSRP_STORE_NOT_FOUND` (404, §3/§4). Stores are isolated — a hash in
`corpus-a` is invisible to `corpus-b` requests.

For the **embedded single-store pattern** (a CX program serving one
local store without the daemon), the accept loop is a CX program and
one request/response cycle is the canonical
[`std-lib/store.md §6.2`](../std-lib/store.md) surface
`[$store:csrp-handle]`:

```cx
[?lib 'cx-stdlib/store']
[?lib 'cx-stdlib/http']

[?let [= $local [$store:open "file:///var/data/corpus/"]]
      [= $srv [$http:serve port=7800]]
  [?for [in $ex [$http:accept-iter $srv]]
    [yield [$store:csrp-handle $ex $local]]]]
```

The handler dispatches on `$shape` for `/query` — `"matches"` /
`"doc-pairs"` stream framed docs, `"aggregate"` evaluates the aggregate
function-head server-side and emits a single `0x05` frame.

## 7 — Conformance fixtures

Under `conformance/csrp.txt`:

- **Capabilities discovery:** `GET /cx-store/v1/capabilities` without
  auth returns valid capabilities element.
- **Query pushdown:** server-side CXPath evaluation matches client-side
  evaluation over same data.
- **Aggregate pushdown:** `[$count //user[= $_@active true]]` with
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
- **Unknown store-name:** any op (including per-store `capabilities`)
  against an unconfigured store-name returns 404 `CXER1710`.
- **Unknown operation:** an unrecognized op name returns 404
  `CXER1709`.
- **Rate limiting:** rapid requests hit `CXER1706` 429 with
  `Retry-After`.
- **Admin-plane RBAC (§3.10–3.12):** `status`/`gc`/`mounts` under a
  `reader`, `writer`, or `metrics` credential return 403 `CXER1703`;
  under `admin` they succeed; unauthenticated → 401 `CXER1702`.
- **Mounts tenant isolation (§3.12):** an `admin` principal
  tenant-scoped to store A enumerates ONLY A — store B's name never
  appears.
- **Admin-plane parity:** `status`/`gc`/`mounts` return the same
  element over CSRP and gRPC (cx-err-code trailer on denial).
- **Config reload (§3.13):** `config-reload` under non-admin roles →
  403 `CXER1703` / unauthenticated → 401 `CXER1702`; a rotated static
  token applies atomically (old token 401s on the NEXT request, new
  token authenticates); an invalid candidate → 400 `CXER1711` with the
  old config demonstrably still in force; a candidate changing a
  restart-required attr → 400 `CXER1712` naming the attrs, nothing
  applied; unchanged file → `applied=false`; CSRP and gRPC triggers
  produce identical outcomes (parity).

**Where these run.** The `.cxd`/`.txt` conformance harness evaluates CX
programs; it cannot drive raw HTTP status codes, binary frame streams,
keep-alive connection reuse, or TLS — so the wire-level fixtures above are
realized as V wire tests (real loopback sockets / hermetic route calls) rather
than a `conformance/csrp.txt` file, while the CX-surface store behaviors remain
in [`conformance/stdlib/store.cxd`](../../../conformance/stdlib/store.cxd). The
wire suite and its coverage map live in `vcx/code/store_csrp_conformance_test.v`
(the item→test table), with the individual behaviors in
`store_binary_wire_test.v` (framing / aggregate `0x05` / not-found `1721` /
integrity `1720` / put-dedup), `store_csrp_test.v` (live query/iter/modify
pushdown), `store_keepalive_test.v` (connection reuse), `store_discovery_test.v`
(capability discovery + version validation), `store_grpc_parity_test.v`
(cross-transport op + error-identity parity incl. the `cx-err-code` trailer),
and `store_authz_test.v` (401/403). Cross-encoding parity and capability-driven
fallback are asserted directly in `store_csrp_conformance_test.v`.

## 8 — Cross-references

- [`std-lib/store.md`](../std-lib/store.md) — client-side Store API.
- [`core/code.md`](../core/code.md) — `[?service]` directive and
  CXPath aggregate function-heads.
- [`misc/bindings.md`](../misc/bindings.md) — Layer-1 16-method API
  round-tripped by the protocol.
- [`core/ast-bin.md`](../core/ast-bin.md) — wire encoding format for
  response streams.
