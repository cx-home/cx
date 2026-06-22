# `cx-stdlib/store` — content-addressed object store

```cx
[module-meta name=store tier=B status=current
  [standard ref='SHA-256' title='Content hash']
  [standard ref='RFC 959' title='FTP']
  [standard ref='RFC 4217' title='FTPS']]
```

**Status:** Current

Normative reference for the `cx-stdlib/store` sub-package.

---

## §1. Scope

`cx-stdlib/store` provides a **content-addressed object store** with **URL-dispatched backends**. A single API surface operates against multiple storage backends (local filesystem, in-memory, HTTP-read-only, S3-compatible, WebDAV-write, FTP/FTPS/SFTP, CSRP service) selected at `open` time by URL scheme. Doc IDs are SHA-256 hashes of the document's **strict canonical bytes** (text by default, or the `cx_to_data_bin` compact binary form for nodes that round-trip through the binary lane) per [`spec/core/canonical.md §1.2`](../core/canonical.md) and [`spec/core/canonical.md §4`](../core/canonical.md). Layer-1 `hash(node)` per [`spec/misc/bindings.md`](../misc/bindings.md) wraps that hash — portable across backends, enabling lossless migration.

## §2. Conceptual model

A **Store** is an opaque element value returned by `open`. The Store wraps a backend trait, a capability set (read / write / list), and per-store configuration (compression, layout, encoding). Multiple Stores may exist simultaneously in a single program.

### §2.1. Doc identity

Every document has one canonical identity: the **SHA-256 of its strict canonical bytes** per [`spec/core/canonical.md §1.2`](../core/canonical.md) (text default) / [`spec/core/canonical.md §4`](../core/canonical.md) (binary `cx_to_data_bin` compact form). The identity is identical across:

- Programming language bindings (V / Python / Go / Rust).
- Storage backends (`file://`, `mem://`, `s3://`, future `pack://`).
- Compression states (gzip / zstd / raw).
- Wire encodings on disk or over CSRP (`.cxbin` ast_bin, `.cxd` text, etc.) — hash is computed after canonicalization, independent of transport.

Two semantically-equal documents have one identity; storing twice is observably a single store.

### §2.2. Backend capabilities

| Capability | Semantics |
|---|---|
| `read` | `get-doc`, `list-docs`, `query`, `iter-docs`, `exists` are supported |
| `write` | `put-doc`, `modify-doc`, `delete-doc` are supported |
| `list` | `list-docs`, `iter-docs` enumerate stored docs efficiently |

CXStore is organised in two tiers — Embedded (client-process processing) and Service (server-process processing). Both expose the same Store API and URL-dispatched open path.

#### §2.2.1. Embedded-tier backends

| Backend | URL scheme | Default capabilities | Notes |
|---|---|---|---|
| LocalFiles | `file:///dir/` | read + write + list | Sharded layout default |
| Memory | `mem://` | read + write + list | Ephemeral; no compression by default |
| HTTP read-only | `http://host/dir/` or `https://host/dir/` | read + list | GET; list via WebDAV PROPFIND if server supports |
| HTTP WebDAV | `http+dav://host/dir/` or `https+dav://host/dir/` | read + write + list | Write via PUT/DELETE |
| S3 | `s3://bucket/prefix/` | read + write + list | Standard SDK credential chain; covers AWS S3, MinIO, R2, B2, Wasabi |
| FTP / FTPS | `ftp://[user[:pass]@]host[:port]/dir/` or `ftps://...` | read + write + list | RFC 959 + RFC 4217; `ftps://` enforces TLS |
| SFTP | `sftp://[user@]host[:port]/dir/` | read + write + list | SSH agent default; `opts.auth.key-path` / `opts.auth.password`; host key per `opts.auth.known-hosts` |

#### §2.2.2. Service-tier backend

| Backend | URL scheme | Default capabilities | Notes |
|---|---|---|---|
| CSRP Service | `cx-store://[user@]host[:port]/store-name/` (HTTPS) or `cx-store+http://` (plaintext, dev only) | read + write + list + push-down query | HTTP/1.1 + Bearer-token + binary streaming ast_bin response. See [`spec/misc/cxstore-remote-protocol.md`](../misc/cxstore-remote-protocol.md) |

The Service tier is the only way to get server-side query pushdown.

## §3. Public function surface

### §3.1. Opening a Store

```
[?def open      scope=public impure [returns element] ($url::string) ...]
[?def open-opts scope=public impure [returns element] ($url::string $opts::map) ...]
```

Raises `CXER1100 E_STORE_UNRESOLVED_BACKEND` on unknown URL scheme; `CXER1101 E_STORE_BACKEND_UNREACHABLE` on connection failure.

| `opts` key | Default | Semantics |
|---|---|---|
| `compression` | `"zst"` (`"none"` for `mem://`) | Compression suffix (`"gz"`, `"zst"`, `"none"`) |
| `encoding` | `"cxbin"` | `"cxd"` (canonical text) or `"cxbin"` (binary) |
| `sharding` | `{depth: 2, width: 2}` | Sharded layout for filesystem-style backends |
| `auth` | per-backend default | URL userinfo, `username`/`password`, `key-path`, `known-hosts`, bearer token, SDK credential chain |
| `read-only` | `false` | Force read-only regardless of backend capability |
| `cache` | `{kind: "lru", size: 256MB}` | In-process cache for HTTP/S3 backends |

#### §3.1.1. Authentication

Built-in per-backend authentication ships via two sources:

- **URL userinfo** — `ftp://user:pass@host/dir/`, `sftp://user@host/dir/`.
- **`opts.auth` table** — `username` / `password` (FTP, FTPS, SFTP-password, HTTP basic), `key-path` (SFTP private-key file), `known-hosts` (SFTP host-key verification), bearer token (HTTP / CSRP), plus standard SDK credential chains for S3 and HTTP.

Pluggable custom credential-provider interfaces are deferred; built-in auth is not.

### §3.2. Storing docs

```
[?def put-doc        scope=public impure [returns string] ($store::element $doc::any) ...]
[?def put-doc-stream scope=public impure [returns string] ($store::element $source::element) ...]
```

Returns the SHA-256 hash (lowercase hex, 64 chars). Dedup is automatic. `put-doc-stream` accepts an `io`-style readable byte-source ([`spec/std-lib/io.md`](io.md)) over an already-canonical encoding of the doc (text strict canonical or `cx_to_data_bin` compact binary per [`spec/core/canonical.md §§1.2, 4`](../core/canonical.md)); bytes are pulled in bounded chunks and piped through the hasher, compressor, and backend writer incrementally so the doc is never fully resident. The returned hash is identical to `put-doc` for the same content. Backends requiring known content-length fall back to buffer-to-temp or multipart upload transparently. Raises `CXER1110 E_STORE_READ_ONLY` against a read-only Store.

### §3.3. Retrieving docs

```
[?def get-doc scope=public impure [returns any] ($store::element $hash::string) ...]
```

Re-validates the hash after parse — raises `CXER1120 E_STORE_INTEGRITY_MISMATCH` if mismatched. Raises `CXER1121 E_STORE_NOT_FOUND` if absent.

### §3.4. Listing and iterating

```
[?def list-docs scope=public impure [returns [sequence string]]  ($store::element) ...]
[?def iter-docs scope=public impure [returns [iterator element]] ($store::element) ...]
```

`iter-docs` yields `[hash $h doc $d]` element pairs lazily — bounded memory regardless of corpus size.

### §3.5. Querying across docs

```
[?def query scope=public impure [returns [sequence element]] ($store::element $cxpath::path) ...]
```

Evaluate the CXPath `cxpath` against every doc in the Store. Returns a sequence of `[hash $h matches [sequence ...]]` for docs where the path matches non-empty. **Naive O(N corpus)** — no inverted index. Parallelism is automatic (worker pool bounded by `backend.recommended-concurrency`). For high-frequency queries on large corpora, use `cx-stdlib/ft` or migrate to a future indexed backend.

### §3.6. Modifying docs

```
[?def modify-doc scope=public impure [returns string] ($store::element $hash::string $action::element) ...]
```

Retrieve doc at `hash`, apply Layer-1 `modify(action)`, store the result as a new doc. Returns the new hash. The original doc is not deleted (content-addressed = immutable).

### §3.7. Deletion and existence

```
[?def delete-doc scope=public impure [returns bool] ($store::element $hash::string) ...]
[?def exists     scope=public impure [returns bool] ($store::element $hash::string) ...]
```

`delete-doc` returns `true` if deleted, `false` if absent. Raises `CXER1110` on read-only Stores. `exists` is cheap (HEAD or bloom filter where available).

### §3.8. Introspection and lifecycle

```
[?def capabilities scope=public impure [returns map]  ($store::element) ...]
[?def close        scope=public impure [returns null] ($store::element) ...]
```

`capabilities` returns `[read $bool write $bool list $bool backend $string url $string compression $string encoding $string]`. Operations on a closed Store raise `CXER1130 E_STORE_CLOSED`.

### §3.9. Aliases — mutable name→hash

The content store is immutable and content-addressed (§5). The **alias layer** is the one mutable surface: a lightweight name→hash map stored in an `aliases.cxd` sidecar at the store root. Aliases are **last-write-wins, single-writer**.

```
[?def set-alias    scope=public impure [returns null]             ($store::element $name::string $hash::string) ...]
[?def get-alias    scope=public impure [returns [or string [sequence string]]] ($store::element $name::string) ...]
[?def list-aliases scope=public impure [returns [sequence element]] ($store::element) ...]
[?def delete-alias scope=public impure [returns bool]             ($store::element $name::string) ...]
```

- `set-alias` — bind `name` to `hash`; the target hash must already exist (`CXER1121` if not). Read-only → `CXER1110`.
- `get-alias` — resolve the alias to its hash, or **absence** (the empty sequence `()`) if it does not resolve. An alias miss is a pure, in-memory, optional lookup that found nothing — the **absence channel** ([`code.md`](../core/code.md) §9.1.2), **never** `null` (the §9.1.2.1 no-conflation guard); extract with `[?else]` (`getOrElse`).
- `list-aliases` — sequence of `[alias name=$n hash=$h]` elements.
- `delete-alias` — `true` if existed; deleting an alias does not delete the underlying doc.

**Mutability boundary.** Aliases are mutable; everything else is immutable. An alias is a pointer, not content.

### §3.10. Migration

```
[?def migrate scope=public impure [returns element] ($from::element $to::element) ...]
```

Copy every doc from `from` to `to`. Walks `from` via `list-docs`, fetches via `get-doc` (re-validating integrity), writes via `put-doc`. Doc IDs are content hashes, so every ID is preserved — lossless across backends and encodings. Aliases are migrated via `set-alias`. Returns `[migration-report doc-count=$n hashes-verified=$n bytes-written=$n]`.

`migrate` is a first-class library function. The `cxstore migrate <from-url> <to-url>` CLI subcommand wraps it.

## §4. Storage layout

### §4.1. Filesystem-style backends

```
{store_root}/
├── store.cxd               (Store metadata; readable CX)
├── aliases.cxd             (mutable name→hash alias map; §3.9)
├── ab/                     (first 2 hex chars of hash)
│   └── cd/                 (next 2 hex chars)
│       └── abcdef0123…cxbin.zst   (full hash + encoding + compression suffix)
```

Default sharding `{depth: 2, width: 2}` gives 65 536 leaf directories — supports ~10⁹ docs.

### §4.2. Store metadata (`store.cxd`)

```cx
[store
  [version "0.1"]
  [created-at "2026-05-26T00:00:00Z"]
  [layout depth="2" width="2"]
  [format encoding="cxbin" compression="zst"]
  [capabilities read="true" write="true" list="true"]
  [doc-count "12345"]]
```

Read at open-time. Written/updated on `put`/`delete` (best-effort; recoverable from filesystem walk if missing).

### §4.3. Transport encoding

| Encoding | Suffix | Description | When to choose |
|---|---|---|---|
| `cxbin` (default) | `.cxbin` | ast_bin per [`spec/core/ast-bin.md`](../core/ast-bin.md). Length-prefixed, mmap-friendly. | Production workloads; binary-clean transports |
| `cxd` | `.cxd` | UTF-8 canonical CX text per [`spec/core/canonical.md`](../core/canonical.md). | Debugging; Git-backed stores for diff-friendliness |

**Hash invariance across encodings.** Layer-1 `hash(node)` is SHA-256 over the doc's strict canonical bytes per [`spec/core/canonical.md §§1.2, 4`](../core/canonical.md), independent of the wire encoding used to transport or persist the bytes. A doc stored as `.cxbin` (ast_bin parse-AST wire) and the same doc stored as `.cxd` (text strict canonical) produce **identical Layer-1 doc IDs**, because both decode to the same value and canonicalize to the same hash input. The wire-encoding choice is a transport optimization, not a semantic decision.

### §4.4. Compression

| Scheme | Suffix | Default? |
|---|---|---|
| zstd | `.zst` | Default for non-memory backends |
| gzip | `.gz` | Available |
| brotli | `.br` | Reserved |
| xz | `.xz` | Reserved |
| none | (no suffix) | Default for `mem://` |

The compression suffix is part of the filename, sniffed on read — a single Store can hold mixed encodings/compressions during transitions.

## §5. Content-addressing semantics

- **Primary key = `hash(node)`** = SHA-256 of the doc's strict canonical bytes per Layer-1 (text default / `cx_to_data_bin` per [`core/canonical.md §§1.2, 4`](../core/canonical.md)).
- **Cross-backend portability.** Same hash across `file://`, `s3://`, future `pack://`.
- **Free dedup.** Storing the same doc twice writes once.
- **Free integrity.** `get-doc` rehashes after decode.
- **No latest pointers in the content store.** All docs are immutable; "latest of name X" is served by the alias layer (§3.9).

## §6. Query semantics

Query is currently a naive scan, fanned out across a worker pool with backend-aware concurrency (filesystem low-dozens, HTTP ~10, S3 hundreds). Streaming via `iter-docs` keeps memory bounded.

| Corpus size | LocalFiles | HTTP | S3 |
|---|---|---|---|
| 10² docs | <100 ms | 1–5 s | 5–10 s |
| 10⁴ docs | ~1 s | minutes | minutes |
| 10⁶ docs | minutes | impractical | impractical |

For high-frequency or large-corpus queries use `cx-stdlib/ft` or a future indexed backend.

## §7. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER1100` | `E_STORE_UNRESOLVED_BACKEND` | `open` on unknown URL scheme |
| `CXER1101` | `E_STORE_BACKEND_UNREACHABLE` | `open` on connection failure |
| `CXER1110` | `E_STORE_READ_ONLY` | `put-doc` / `modify-doc` / `delete-doc` / alias mutation on read-only Store |
| `CXER1120` | `E_STORE_INTEGRITY_MISMATCH` | `get-doc` when decoded bytes don't hash to requested hash |
| `CXER1121` | `E_STORE_NOT_FOUND` | `get-doc` / `modify-doc` / `delete-doc` / `set-alias` on missing hash |
| `CXER1130` | `E_STORE_CLOSED` | Any operation on a closed Store |
| `CXER1131` | `E_STORE_AUTH_FAILED` | Backend rejects credentials |
| `CXER1132` | `E_STORE_RATE_LIMIT` | Backend signals rate limiting (S3, HTTP) — caller should retry |

## §8. Conformance fixtures

Under `conformance/stdlib/store.cxd`:

- **Round-trip:** put N docs → list → get each → rehash → bytes match.
- **Cross-backend parity:** the same API sequence on LocalFiles / Memory / HTTP / S3 / FTP / SFTP yields byte-identical results (including hashes).
- **Cross-encoding parity:** the same doc stored as `.cxbin` and `.cxd` produces identical hashes; `migrate file://dir-cxbin/ file://dir-cxd/` round-trips losslessly.
- **Capability enforcement:** `put` against read-only HTTP backend raises `CXER1110`.
- **Integrity:** put doc, corrupt a byte at backend level, `get` raises `CXER1120`.
- **Sharded layout:** 10 K docs do not exceed depth × width budget.
- **Compression:** zst-roundtrip, gz-roundtrip, mixed-extension Store.
- **Migration:** populate a file:// Store (with an alias), `migrate` into a mem:// (or cxd-encoded file://) Store; report counts correct; aliases copied; cross-encoding cxbin→cxd preserves every doc ID.
- **Streaming put:** `put-doc-stream` on a doc larger than the streaming buffer threshold — returned hash equals `put-doc` hash; peak resident memory stays bounded.
- **Concurrent put:** N writers, M docs each, no corruption.
- **Query parallelism:** 10 K docs, `//element-name` query, wall time within ~N× single-threaded.
- **FTP / FTPS / SFTP authentication:** anonymous, URL-embedded credentials, `opts.auth` variants; TLS enforced; known-hosts verification.
- **Cross-binding parity:** Python / Go / Rust Store implementations produce byte-identical hashes for the same input doc set.
- **Alias round-trip:** `set-alias` → `get-alias` returns the hash; `list-aliases` enumerates; `delete-alias` returns `true`, next `get-alias` returns **absence** (the empty sequence `()`).
- **Alias to non-existent hash:** raises `CXER1121`.
- **Alias persistence:** set alias, `close`, reopen, `get-alias` still resolves.
- **Alias does not own content:** `delete-alias` leaves doc retrievable by hash.

## §9. Capabilities

Effectful functions in `cx-stdlib/store` run under deny-by-default capabilities ([`spec/core/security.md`](../core/security.md) §2): the effect point checks the active set and raises `cx-err:CXER0271` (E_CAP_DENIED, naming the missing capability and resource) when the grant is absent. Pure functions (in-memory transforms, parsing, formatting) require no capability.

The host capability required depends on the backend the Store was opened against. A file/local backend touches the filesystem, so read-path operations require `read` and write-path operations require `write`. A remote, URL-dispatched backend (HTTP/WebDAV, S3, FTP/SFTP, service tier) performs network I/O, so every operation against it requires `net`.

The `mem://` Memory tier (§2.2.1) is the exception: it is **capability-free**. A `mem://` Store is pure in-process state — it touches neither the filesystem nor the network — so it is neither a `read`/`write` (file/local) nor a `net` (remote) effect point. `open "mem://"` and every operation against the resulting Store run under any capability set, including the empty set, and never raise `CXER0271`. This is consistent with the per-function table below, which enumerates only the file/local and remote backends. (Store-specific errors — `CXER1110` read-only, `CXER1121` not-found, `CXER1130` closed — still apply to `mem://`, since they are not host-capability checks.)

These host capabilities are distinct from the per-backend read/write/list **traits** described in §2.2: those traits describe what a backend is structurally able to do, while the `CXER0271` host capabilities gate the underlying OS effect (filesystem or network) at the effect point.

| Capability | Functions |
|---|---|
| `read` (file/local backend) | `get-doc`, `exists`, `iter-docs`, `list-docs`, `get-alias`, `list-aliases`, `query` |
| `write` (file/local backend) | `put-doc`, `put-doc-stream`, `delete-doc`, `set-alias`, `delete-alias`, `modify-doc`, `migrate` |
| `net` (remote / URL-dispatched backend) | all of the above when the Store targets a remote backend |

## §10. Cross-references

- [`spec/misc/bindings.md`](../misc/bindings.md) — Layer-1 16-method API (`parse`, `bytes`, `hash`, `modify`).
- [`spec/core/cxdm.md`](../core/cxdm.md) — content-addressing hash policy.
- [`spec/core/canonical.md`](../core/canonical.md) — canonical form used as hash preimage.
- [`spec/core/ast-bin.md`](../core/ast-bin.md) — binary wire encoding.
- [`spec/core/abi.md`](../core/abi.md) — Layer-1 capability bits.
- [`spec/misc/cxstore-remote-protocol.md`](../misc/cxstore-remote-protocol.md) — CSRP wire spec for the Service-tier backend.
- [`spec/misc/parity-matrix.md`](../misc/parity-matrix.md) — Tier-1 binding parity tracking.
