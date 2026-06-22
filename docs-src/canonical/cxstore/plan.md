# CXStore — Plan

**INTERNAL — DO NOT PUBLISH. DO NOT MIRROR TO `cx-home/cx`. SEE [`README.md`](README.md).**

**Status:** Draft. Captured 2026-05-23 from a design conversation. Not yet ratified.
**Branch context:** Designed against main. Assumes ast_bin v7, CXPath value-kind, Layer-1 16-method API, and CXCol bridges are shipped.

---

## Product thesis

A content-addressed store and query engine for CX data. **Two deployment tiers** — embedded and service — sharing the same wire format, query language, and API surface. Embedded → service migration is configuration, not rewrite.

## Tier definitions

### Embedded

- Library linked into the host application's process. All processing client-side.
- Backends can be local (file, mem) or remote-byte-source (http, s3, ftp, sftp) — the byte source doesn't change the tier; what makes it Embedded is that the *processing* runs in the calling process.
- Simplest case: pure file-based with no indexing. Pack-backed indexed storage is a perf upgrade within the same tier (still client-side processing).
- No daemon, no auth (beyond what the byte source itself requires), no network surface.
- Lifecycle = host app lifecycle.
- Distribution: `pip` / `cargo` / `go get` / V import.
- Pattern reference: SQLite, DuckDB embedded mode.

### Service

- Processing happens on a remote node. Server speaks the **CXStore Remote Protocol (CSRP)** over HTTP/1.1; clients use `cx-store://` URLs.
- Scales from **one node** (single server next to the data) to **many nodes** (distributed, with replication / sharding / query planner). Same protocol either way — cluster topology is hidden from clients.
- Server-side query pushdown: client sends CXPath; server executes against local data; binary ast_bin matches stream back.
- Pattern reference: DuckDB-server, PostgreSQL + libpq, MarkLogic Server, BaseX HTTP server.

## Qualitative line

The split between embedded and service is **where the processing happens**, not where the bytes live. Embedded processes data in the client process even when bytes are pulled from S3 or FTP. Service pushes the computation to a remote node and streams binary matches back. Scaling Service from 1 → N nodes is a *quantitative* operational change; switching from Embedded to Service is the *qualitative* one.

## Invariants across both tiers

- **Storage atom:** ast_bin v7 (pack-friendly, mmap-friendly, length-prefixed).
- **Query language:** CXPath (XPath 3.1-aligned, first-class value kind).
- **API surface:** Layer-1 16 methods (`parse`, `bytes`, `hash`, `equals`, `eval`, `select_all`, `select`, `modify`, `find_all`, `root`, `name`, `attr`, `attrs`, `children`, `body`, `kind`). Byte-identical across V/Python/Go/Rust per gate 28.6.
- **Content addressing:** SHA-256 of canonical bytes via Layer-1 `hash(node)`. Primary key for docs; free dedup, integrity, cross-language consistency.
- **Manifest format:** CX document. Eat-own-dogfood.
- **Analytical sidecar:** CXCol → Parquet bridge for aggregate / scan queries.

## Storage backend is orthogonal to tier

CXStore has **two independent design dimensions**, not one:

| Axis | Choices |
|---|---|
| Tier (where processing happens) | embedded · service |
| Backend (storage layout + transport) | pack · files · http · ftp · sftp · s3 · tar · zip · git · memory · cx-store (CSRP) · … |

The non-pack Embedded backends (Phase 0.5) ship as the **URL-dispatched Embedded Store** — slower-than-pack but transport-portable, requires zero new infrastructure beyond what filesystems / HTTP / object stores already provide. The `pack` backend (Phase 1) is the eventual indexed performance upgrade within the Embedded tier.

The Service tier (Phase 2+) speaks **CSRP** and is dispatched via the `cx-store://` URL scheme. Server-side speaks the same CSRP whether running single-node or multi-node distributed.

The Layer-1 16-method API is identical across all backends and both tiers. Users change backends — or change tiers — by changing a URL scheme:

```
cxstore.open("file:///var/data/store/")        # Embedded, LocalFiles
cxstore.open("https://archive.example.org/cx/") # Embedded, HTTP read-only byte source
cxstore.open("s3://bucket/prefix/")             # Embedded, S3 byte source
cxstore.open("sftp://data-host/cx/")            # Embedded, SFTP byte source
cxstore.open("pack:///var/data/store.cxpack")   # Embedded, Phase 1 native indexed
cxstore.open("cx-store://host/store-name/")     # Service, Phase 2+ remote pushdown via CSRP
```

Same code on both sides of the URL change. See [`embedded.md`](embedded.md) for the Embedded tier spec; CSRP spec is at `spec/misc/cxstore-remote-protocol.md`.

## Storage layout (pack backend, both tiers)

- **Pack files** — append-only, immutable, ~1 GB each. Sequence of length-prefixed ast_bin entries. See [`pack_format.md`](pack_format.md).
- **Per-pack metadata** — bloom filter (~10 bits/entry, ~1% FPR), hash-prefix → offset index.
- **Master index** — hash → (pack-id, offset, length). Local file in embedded / single-node service; FoundationDB in multi-node service.
- **Secondary indexes (BaseX-four, applied to CX):**
  - Path summary (path → node-list)
  - Element/name (name → offsets)
  - Attribute ((name, value) → offsets)
  - Text / full-text (token → posting list)
- Indexes themselves are CX documents.

## Query model

- **Inside a loaded doc:** CXPath via Layer-1 `select_all` / `select`.
- **Across the corpus by indexed field:** secondary index extracted at write time → hash list → fetch packs.
- **Analytical aggregates:** project to Parquet via CXCol; query through DuckDB / Polars / Trino. Don't try to make CXPath compete with a columnar engine.
- **Full-text:** posting-list index per pack; distributed scoring in multi-node Service mode.

## Scale envelope (rough)

| Tier / shape | Capacity |
|---|---|
| Embedded | bounded by host process memory + local disk + remote-byte-source throughput |
| Service, single-node (NVMe) | ~10–60 TB / ~10–100 B small docs |
| Service, multi-node distributed (S3 + FDB) | effectively unbounded |

## Phases & estimates

Sessions = focused AI-paired work units of a few hours each. Calendar months assume sustained but not full-time work.

| Phase | Tier | Product | Scope | Sessions | Calendar |
|---|---|---|---|---|---|
| **0** | — | Prereqs | ast_bin v7, CXPath value-kind, Layer-1 API, gate 28.6 — shipped | done | — |
| **0.5** | Embedded | **URL-dispatched Embedded Store** | Store interface trait + URL dispatch + format conventions; LocalFiles, Memory, HTTP-RO, HTTP-WebDAV, S3, FTP/FTPS, SFTP backends; naive O(N) query; migration tool; 4-language bindings; cxd + cxbin encodings; gzip + zstd compression | 14–20 | 3–6 wks |
| **0.7** | Service | **CSRP + single-node Service (minimum)** | CSRP wire protocol spec; cx-store:// client backend; reference server CX program using `[?service]` + Embedded Store; Bearer-token auth; capability negotiation; binary streaming response | 4–6 | 1–2 wks |
| **1** | Embedded | **Pack-backed Embedded Store** | Pack file format + ADR; mmap writer/reader; master hash→offset index; bloom filters; four secondary indexes (element / attribute / path summary / full-text); query rewriter; perf-gated against BaseX; pack-aware migration tool | 110–220 | 3.5–9 mo |
| **2** | Service | **Service (single-node, production)** | Daemon lifecycle (systemd/Docker); RBAC + structured auth; observability hooks (Prometheus/OTel); optional gRPC alongside CSRP; client libs | 30–60 | 1–2 mo |
| **3** | Service | **Service (multi-node distributed)** | S3 storage backend; FoundationDB metadata; worker pool + query planner (likely Trino-fork); Kafka ingest log; Helm chart; DR/PITR; multi-tenancy; TLS+RBAC | 140–280 | 4.5–9 mo |
| | | **Totals** | | **298–586** | **9.5–21 mo** |

## Decision gates

| After | Question | If yes | If no |
|---|---|---|---|
| 0.5 | Embedded Store usable for real workloads? | Continue to 0.7 for pushdown | Iterate Embedded ergonomics; the URL-dispatched Embedded Store is itself a real product |
| 0.7 | Single-node Service usable for real pushdown workloads? | Continue to 1 for indexed perf | Iterate CSRP ergonomics; single-node Service is a real product |
| 1 | Pack backend competitive with BaseX on tree workloads? | Continue to 2 for ops-tier | Optimize indexes/rewriter; pack backend lives alongside URL-dispatched Embedded |
| 2 | Real multi-node demand from users? | Continue to 3 | Stop here; single-node production Service is its own product |
| 3 | Production-grade or preview? | GA | Treat as preview, gather operator feedback |

## Rejected / deferred

- **MarkLogic-tier** (sharded ACID enterprise DB): explicitly skipped. Shrinking market, decade-long build, weak fit for CX's design center.
- **Three-tier framing** (embedded / standalone / distributed): collapsed to two. Standalone is just Service deployed small.
- **"Lake" / "Lattice" naming:** both rejected. "Service" is descriptive and self-explanatory; metaphorical names (Lake, Lattice) added friction without clarity.
- **"Polyfill" naming for Phase 0.5:** rejected. Phase 0.5 is a permanent Embedded tier implementation, not a temporary shim. Renamed to "URL-dispatched Embedded Store."
- **Final product branding** (CXCell, etc.): deferred. Working terms = `embedded` and `service`.
- **Service query engine choice:** Trino-fork vs CX-native for multi-node. Open until start of Phase 3.
- **Multi-tenancy model for Service:** open.
- **Replication / DR model for Service:** open.

## Critical risks

| Risk | Phase | Mitigation |
|---|---|---|
| Query rewriter complexity (BaseX has 15 years of optimizer cleverness) | 1 | Ship naive rewriter first; add cost-based heuristics incrementally; perf-gate against BaseX on fixed workloads |
| Storage backend abstraction leaking (must work clean for local + S3) | 2 → 3 | Design the trait in Phase 2 with S3 in mind even if only local is implemented; review before 3 starts |
| Full-text index is a substantial sub-project on its own | 1 | Vendor Tantivy or comparable; do not build full-text from scratch |
| Multi-tenancy retrofitted vs designed-in | 3 | Plan tenant boundary in Phase 2's auth model |

## Baseline anchors this depends on

- ast_bin v7 wire format (`spec/core/ast-bin.md`, atom-as-scalar).
- CXPath as first-class value kind (`spec/cxpath_alignment.md`).
- `[?modify]` with structural sharing — needed for cheap versioned storage.
- Layer-1 16-method binding parity (gate 28.6, `spec/bindings.md`).
- CXCol (formerly CXDB) Parquet/Arrow bridges.
- `programs` → `code` rename — CXStore evaluates `code` documents, not `programs`.

## Build-order commitment

**Commit to Phase 0.5 + Phase 0.7 together.** Embedded URL-dispatched Store gives CXStore a working surface (assuming Layer-1 V impl lands in Phase 2). CSRP single-node Service ships alongside as a ~4–6 session add — small because it composes existing primitives (`[?service]` + local Embedded Store + Layer-1 binary form). Together they cover the agentic-deployment shape: byte-source backends for legacy/cloud storage, plus query pushdown for remote corpora that don't fit the "download then process" model.

**Phase 1 (pack backend) is then a performance upgrade, not a new product.** Users keep the same API; they switch URL schemes (`file://` → `pack://`) when they need indexed query performance. Migration is `cxstore migrate <from> <to>`; no application rewrite.

Single-node CSRP Service (Phase 0.7) is the **smallest viable Service tier**. Production Service (Phase 2) adds operational features (daemon lifecycle, RBAC, observability) on top. Multi-node distributed Service (Phase 3) is ~1.5–2× the work of pack-backend Embedded and only justified if Phases 0.7 + 1 + 2 get traction. Stopping after Phase 2 is a real outcome, not a failure mode.
