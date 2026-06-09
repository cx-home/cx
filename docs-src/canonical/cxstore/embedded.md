# CXStore — Embedded Tier (Phase 0.5: URL-dispatched Store)

**INTERNAL — DO NOT PUBLISH. DO NOT MIRROR TO `cx-home/cx`. SEE [`README.md`](README.md).**

**Status:** Draft. Phase 0.5 deliverable, ships day-of-v0.8.0 (gated on Layer-1 V impl from v0.8.0 Phase 2).
**Scope:** The Embedded tier of CXStore — a Store abstraction layered over the Layer-1 16-method API, dispatching to multiple storage backends (local filesystem, memory, HTTP, HTTPS+WebDAV, S3, FTP/FTPS, SFTP) via URL scheme. All processing happens client-side regardless of where bytes live.

---

## Premise

CXStore has two independent design dimensions ([`plan.md`](plan.md) "Storage backend is orthogonal to tier"):

- **Tier** — embedded · service (where processing happens — client-process vs remote-node)
- **Backend** — pack · files · http · ftp · sftp · s3 · tar · zip · git · memory · … (storage layout + transport for byte sources within Embedded; protocol identity within Service)

This document specifies the **Embedded tier** — all URL-dispatched backends where bytes are pulled to the client process for local processing. The eventual pack-backed indexed performance variant within Embedded is specified in [`pack_format.md`](pack_format.md). The Service tier (CSRP-speaking remote nodes) is specified at `spec/misc/cxstore-remote-protocol.md`. All three expose the *same* Store API; users switch by URL scheme.

Phase 0.5 ships **day-of-v0.8.0** without waiting for the pack format, indexes, or a remote-protocol implementation. Performance is sacrificed for ubiquity within Embedded: queries are O(N corpus size) because no indexes exist, but every modern byte-source transport (filesystem, HTTP, object store, FTP, SFTP) becomes a usable CXStore byte source immediately. Production-scale pushdown ships alongside via the Service tier in Phase 0.7.

---

## Store interface (above Layer-1)

The Layer-1 16-method API operates on loaded documents. The Store layer adds **doc-collection operations**:

```
trait StoreBackend {
    fn list() -> Iterator<DocId>
    fn get(id: DocId) -> Result<Bytes>
    fn put(id: DocId, bytes: Bytes) -> Result<()>
    fn delete(id: DocId) -> Result<()>
    fn exists(id: DocId) -> Result<bool>
    fn capabilities() -> StoreCapabilities  // read-only? writeable? listable?
}
```

User-facing Store API (built on the backend trait + Layer-1):

| Method | Returns | Notes |
|---|---|---|
| `store.put_doc(doc)` | `DocId` (the hash) | Layer-1 `bytes(node)` + `hash(node)` → backend.put |
| `store.get_doc(hash)` | `Document` | backend.get → Layer-1 `parse(bytes)` → rehash-verify → return |
| `store.list_docs()` | `Iterator<DocId>` | backend.list, optionally filtered |
| `store.delete_doc(hash)` | `Result<()>` | backend.delete |
| `store.exists(hash)` | `bool` | backend.exists |
| `store.query(cxpath)` | `Iterator<(DocId, Sequence<Node>)>` | naive: list → get → parse → CXPath select_all → emit |
| `store.modify_doc(hash, action)` | `DocId` (new hash) | get → Layer-1 `modify` → put → return new id |
| `store.iter_docs()` | `Iterator<(DocId, Document)>` | streaming version of list+get+parse |

`DocId` is the **SHA-256 of canonical ast_bin** (Layer-1 `hash(node)`). Same content-addressing as the pack backend → keys are portable across backends. Migrating a corpus from `file://` to `pack://` preserves every doc id.

---

## URL scheme dispatch

```
cxstore.open(url, options?) -> Store
```

| URL scheme | Backend | Default capabilities |
|---|---|---|
| `file:///path/dir/` | LocalFiles | RW, listable |
| `file:///path/archive.tar` | Tar | RO (writable variant TBD) |
| `file:///path/archive.zip` | Zip | RW if writeable; RO otherwise |
| `http://host/path/` | HTTP | RO by default; WebDAV PUT/DELETE if server supports |
| `https://host/path/` | HTTPS | Same |
| `ftp://host/path/` | FTP | RW |
| `s3://bucket/prefix/` | S3 | RW (credentials via standard SDK chain) |
| `gs://bucket/prefix/` | GCS | RW |
| `azure://container/prefix/` | Azure Blob | RW |
| `git://host/repo.git#ref` | Git | RW (commits per put); versioned for free |
| `mem://` | Memory | RW, ephemeral |
| `pack:///path.cxpack` | Pack (Phase 1) | RW, indexed |

**Capability negotiation.** Each backend reports its capabilities via `capabilities()`. Read-only backends reject `put`/`delete` with a typed error. The Store layer surfaces this so consumers can decide at open-time, not mid-operation.

---

## Format conventions

### Document file naming

Two formats supported; pick at store-open time or sniff per file:

| Extension | Content |
|---|---|
| `.cxd` | UTF-8 text CX (canonical form) |
| `.cxbin` | ast_bin v7 binary |

Layer-1 doesn't care which; the Store layer encodes/decodes as needed. `.cxbin` is preferred for storage (no parse on read), `.cxd` for human-readable transport.

### Compression suffixes (orthogonal to content)

Sniffed by extension; applied as a transparent wrapper around the backend bytes:

| Suffix | Compression |
|---|---|
| `.gz` | gzip |
| `.zst` | zstd (preferred for speed + ratio) |
| `.br` | brotli |
| `.xz` | xz (least common) |

Examples:
- `abc123…cxd` — raw text
- `abc123….cxd.zst` — zstd-compressed text
- `abc123….cxbin` — raw binary
- `abc123….cxbin.zst` — zstd-compressed binary

Compression is configurable per-store at open-time; defaults to `none` for `mem://`, `zst` for everything else.

### Sharded layout (LocalFiles, S3, etc.)

To avoid 1 M files in one directory, use a **Git-style sharded layout** by default:

```
{store_root}/
├── store.cxd          # store-level metadata (a CX doc)
├── ab/
│   └── 12/
│       └── ab123456…cxbin.zst
├── cd/
│   └── 34/
│       └── cd345678…cxbin.zst
└── …
```

- First 2 hex chars of the hash → first subdir level
- Next 2 hex chars → second subdir level
- Full hash (64 hex chars) + extension → filename

256 × 256 = 65 536 leaf directories; up to ~15 K docs per directory before filesystem performance degrades on common setups. Sufficient for ~10⁹ docs without changing layout.

Sharding is configurable: `{depth: 2, width: 2}` (default), `{depth: 0}` (flat for small stores), `{depth: 1, width: 1}` (256 dirs).

### Store-level metadata

A `store.cxd` (or `store.cxbin`) at the root holds:

```cx
[store
  [version "0.1"]
  [created_at "2026-05-23T18:30:00Z"]
  [layout [depth "2"] [width "2"]]
  [format [content "cxbin"] [compression "zst"]]
  [capabilities [read "true"] [write "true"] [list "true"]]
  [doc_count "12345"]    [- optional, updated lazily -]
]
```

Read at open-time to configure the Store. Written/updated on `put`/`delete` (best-effort; recoverable from filesystem walk if missing).

---

## Content addressing semantics

- **Primary key = `hash(node)`** = SHA-256 of canonical ast_bin.
- **Cross-backend portability.** A doc with hash `abc…` in `file://` has the same hash in `s3://`, `pack://`, anywhere. Migration preserves ids.
- **Free dedup.** `put_doc(d)` twice → backend.put twice (or write-if-not-exists if the backend supports it); only one entry persists since the key is the same.
- **Free integrity.** `get_doc(hash)` rehashes the decoded bytes after parse; mismatch → typed `IntegrityError`.
- **No "latest" pointers in the core Store.** All docs are immutable. Versioning / "give me the latest X" is a higher-layer alias store (see Open Questions).

---

## Query semantics

The URL-dispatched Embedded Store's `query(cxpath)` operation is naive:

```
fn query(cxpath: CXPath) -> Iterator<(DocId, Sequence<Node>)> {
    for hash in self.list_docs() {
        let bytes = self.backend.get(hash);
        let doc = parse(bytes);  // Layer-1
        let matches = doc.select_all(cxpath);  // Layer-1
        if !matches.is_empty() {
            yield (hash, matches);
        }
    }
}
```

**Optimizations available without giving up the "no index" simplicity:**

1. **Parallelism.** Fan out `get` + `parse` + `select_all` across a worker pool. Bounded by backend's concurrent-read characteristics (filesystems: dozens; HTTP: ~10 concurrent; S3: hundreds).
2. **Streaming.** Don't materialize all matches in memory; emit per-doc as iterator.
3. **Early-exit predicates.** If the CXPath has a non-existent root step (e.g., `//element-name` where no doc has that element), the per-doc `select_all` returns quickly.
4. **Pre-filter by name index** (if a backend reports one — most don't). Optional.

**Performance characteristics (rough):**

| Corpus | Local FS | HTTP | S3 |
|---|---|---|---|
| 10² docs | <100 ms | 1–5 s | 5–10 s |
| 10⁴ docs | ~1 s | ~minutes | ~minutes |
| 10⁶ docs | ~minutes | impractical without parallelism | impractical without parallelism |
| 10⁹ docs | hours+ | switch to pack backend | switch to pack backend |

**When to migrate to pack backend:** when `query` latency stops being acceptable, or corpus > ~10⁶ docs. Migration is a one-shot tool ([`pack_format.md`](pack_format.md) covers the destination format).

---

## Migration to pack backend

```
$ cxstore migrate file:///var/data/store/  pack:///var/data/store.cxpack
```

The migration tool:
1. Walks the source store (`list_docs`).
2. For each doc: `get → put` into the destination.
3. Preserves all `DocId`s (because hash is content-derived).
4. Writes a `migration.cxd` record at destination root with source URL, time, count.
5. Optionally validates: rehash every doc on both sides.

Streaming, bounded memory. Migration of 1 M small docs: ~10 min from local FS → local pack on commodity hardware. HTTP/S3 → local pack: bound by network.

After migration the application changes one URL:

```python
- store = cxstore.open("file:///var/data/store/")
+ store = cxstore.open("pack:///var/data/store.cxpack")
```

API surface, query language, behavior all identical. Speed improves; everything else is invisible.

---

## What the URL-dispatched Embedded Store does NOT do

- **No secondary indexes.** No element-name, attribute, path-summary, or text indexes. All cross-doc queries are O(N).
- **No bloom filters.** `exists` and miss-case lookups are O(1) on most backends (filesystem stat / HTTP HEAD / S3 HEAD), but no membership filtering at scale.
- **No query rewriter / optimizer.** CXPath runs as written; no cost-based planning.
- **No concurrent-writer safety** beyond what the backend gives you. Filesystem locking is best-effort; S3 has at-most-once write semantics; HTTP depends on server.
- **No transactions.** Each `put` is atomic at the backend level; no multi-doc atomic operations.
- **No replication / DR.** That's the backend's problem (S3 has 11×9s; filesystem has whatever RAID/backup you set up; HTTP has whatever the server gives).
- **No full-text search.** Body-text search requires the text index from Phase 1.
- **No streaming writes** of huge single docs. Each doc is fully materialized in memory during encode.

Users who need any of these migrate to the pack backend (Phase 1) or service (Phases 2–3).

---

## Backend implementations — priority order

### Tier 1 (ship together as the v0.1 URL-dispatched Embedded Store)

1. **LocalFiles** — directory operations, sharded layout, compression-aware. Most common backend; covers 80% of starter use cases.
2. **Memory** — in-process hashmap. Tests, REPL, ephemeral pipelines.
3. **HTTP (read-only)** — GET against sharded URL layout. Useful for distribution (publish a corpus on a static-file server).

### Tier 2 (subsequent URL-dispatched Embedded Store releases)

4. **S3** — read+write against S3-compatible object stores. Covers AWS, MinIO, R2, B2, Wasabi, etc. Most-requested cloud backend.
5. **HTTP (WebDAV)** — PUT/DELETE on servers that support it. Apache, nginx-dav, ownCloud, Nextcloud.

### Tier 3 (nice-to-haves)

6. **Git** — `git add`/`git commit` per put. Versioning + audit log for free.
7. **Tar / Zip** — archive backends. Useful for distribution and offline analysis.
8. **FTP** — legacy-system integration.
9. **GCS / Azure Blob** — cloud-vendor parity with S3.

Each Tier 2/3 backend is ~half a session once the Tier 1 abstractions are right.

---

## Effort breakdown (Phase 0.5)

| Sub-deliverable | Sessions |
|---|---|
| Store interface trait + capability model + URL parser + dispatch | 1–2 |
| Format conventions: encoding, compression sniffing, sharded layout, store.cxd | 1 |
| LocalFiles backend | 1–2 |
| Memory backend | 0.5 |
| HTTP read-only backend | 1–2 |
| Naive query implementation + parallelism layer | 1 |
| S3 backend (Tier 2) | 1 |
| WebDAV PUT/DELETE (Tier 2) | 0.5 |
| Migration tool (`cxstore migrate`) | 1 |
| Layer-1-level Store bindings (V/Python/Go/Rust) | 2–3 |
| Tests / fixtures / conformance | 2–3 |
| **Phase 0.5 total** | **12–17** |

(Slightly higher than the original 10–17 estimate after spelling out the conformance + bindings + migration tool work.)

Tier 3 backends are post-Phase-0.5; add as demand surfaces.

---

## Test surface

Conformance fixtures under `conformance/store_URL-dispatched Embedded Store.txt` (file lives in `cx-home/private`; do **not** publish without scrubbing references to commercial framing):

- **Round-trip:** put N docs → list → get each → rehash → bytes match.
- **Backend parity:** the same Store API call sequence on LocalFiles / HTTP / S3 / Memory yields byte-identical results.
- **Capability enforcement:** put against read-only HTTP backend → typed `ReadOnlyError`.
- **Integrity:** put doc, corrupt a byte at the backend level, get → `IntegrityError`.
- **Sharded layout:** put 10 K docs, verify no leaf directory exceeds depth × width budget.
- **Compression:** zst-roundtrip, gz-roundtrip, mixed-extension store.
- **Migration:** populate file:// store, migrate to pack://, verify all hashes preserved.
- **Concurrent put:** N writers, M docs each, verify no corruption (filesystem + S3).
- **Query parallelism:** 10 K docs, `//element-name` query, verify wall time within ~N× single-threaded.
- **URL parsing:** edge cases (trailing slash, query params, auth-in-URL, IPv6 hosts).
- **Cross-backend portability:** dump from one backend, load into another, hashes preserved.

---

## Open questions

1. **Concurrent-writer semantics for LocalFiles.** Filesystem locking is OS-dependent and unreliable across NFS/etc. Options: (a) optimistic + retry, (b) require single-writer, (c) explicit lock file, (d) document as "best-effort, use S3 for safe multi-writer." Lean toward (d) for v0.1.
2. **Cache layer for HTTP/S3 backends.** In-process LRU? On-disk cache? Configurable max-size? Lean toward: in-process LRU by default with optional disk overlay; user can disable.
3. **Naive-query parallelism defaults.** Pool size, streaming mode, bounded memory ceiling. Default: pool size = `min(cpu_count, backend.recommended_concurrency)`; streaming = on; memory bound = configurable, default 256 MB.
4. **Versioning convention.** URL-dispatched Embedded Store is content-addressed = immutable. "Latest" pointers need a separate alias store. Defer to v0.2 or layer it via a `store.alias("name", hash)` API backed by a separate small KV.
5. **Authentication.** HTTP basic, AWS creds, SSH keys, OAuth, custom headers. Pluggable provider trait? Lean toward: per-backend native auth (HTTP → headers, S3 → SDK chain, FTP → URL creds), with a `cxstore.auth_provider(...)` injection point for custom.
6. **`store.cxd` consistency under concurrent writes.** Best-effort + rebuild-from-walk on missing. Document the limitation; recommend S3-tier backends for multi-writer use.
7. **Migration tool: idempotent restart?** If migration fails mid-stream, allow `cxstore migrate --resume`. Implementation: keep a `migration_state.cxd` at destination tracking last hash processed.

---

## Next sub-deliverables (after this spec is locked)

1. V reference implementation of the Store trait + LocalFiles + Memory + HTTP-read-only backends.
2. URL parser + scheme dispatch table.
3. Format-conventions implementation (sharded layout, compression layer, store.cxd).
4. Naive parallel query implementation.
5. Layer-1 store bindings in Python / Go / Rust (V is the reference).
6. Migration tool (`cxstore migrate`).
7. S3 backend.
8. WebDAV write extension to HTTP backend.

Then Phase 1 (pack backend) begins; same Store API, much faster.
