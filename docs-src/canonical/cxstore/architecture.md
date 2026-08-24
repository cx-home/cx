# CXStore — Unified Multimodel Pluggable-Backend Architecture (Design)

**INTERNAL — DO NOT PUBLISH. DO NOT MIRROR TO `cx-home/cx`. SEE [`README.md`](README.md).**

**Status:** Design, for review. Issue #75 — the umbrella that pulls the cxstore direction together before the broad multimodel implementation.
**Scope:** the backend-trait shape, the model taxonomy, the read/write paths, the transaction layer, and how external engines plug in. The **native content-addressed engine** is specified in [`object_model.md`](object_model.md) (and its on-disk atom in [`pack_format.md`](pack_format.md)); this document is the *framework* around it.
**Foundation:** the native engine implements the richest trait set here; everything else is a specialization plug-in.

> No ADRs — decisions live in this spec, self-contained.

---

## 1 — Capability-tiered surface (not least-common-denominator)

The store is **not** a lowest-common-denominator KV API. It is a **universal core** plus **declared capability traits** that backends opt into, with **negotiation** and **degrade-with-visibility-or-error** (never silent flatten).

**Universal core** — `StorageBackend` (realized in `vcx/cxstore/backend.v`):

```
interface StorageBackend { get(key) ?string  has(key) bool  list() []string  mut: put(text) !string }
```

Content-addressed put/get/has/list keyed by store hash. Every backend implements this.

**Capability traits** (a backend advertises those it implements):

| Trait | Contract | Native engine |
|---|---|---|
| `Indexed` | structural secondary indexes (element/attr/path → docs) | ✅ #85 |
| `Queryable` | index-aware CXPath name-step query planning | ✅ #87 |
| `FullText` | stored inverted index + search | ✅ #86 (code layer) |
| `Compactable` | reachability GC + retention compaction | ✅ #81 |
| ~~`Transactional`~~ | AMENDED (stream 7 L127, #714): no spec'd backend advertises a transaction trait today, and the spec corpus carries no isolation vocabulary — the claim is superseded by the consistency vocabulary (`consistency_vocabulary.md`). Single-backend transactionality re-enters, if ever, as a declarable consistency token when a spec'd backend actually advertises it. | — |
| `Columnar` | columnar analytical scan (§6) | plugin |

**Negotiation.** Callers test capabilities (`is_indexed`, `is_queryable`, …) and choose a path. A request needing an absent capability **degrades with a visible signal or errors clearly** — it never silently produces a flattened/partial result. This promotes the existing coarse `[$store:capabilities]` / CSRP read/write/list flags to typed traits.

**Native escape hatch.** Backends may expose backend-specific power via an explicit, opt-in native channel; using it is a deliberate choice, not an accident of the common API.

---

## 2 — Read/write path separation (CQRS; no ORM)

Read and write paths are **separate, never combined** — this is what lets one substrate serve **multiple domain models at once**.

- **Read path** = query/projection pipelines (CXPath, full-text, columnar scan, secondary-index lookup). Pure, no enlistment in transactions.
- **Write path** = command/mutation pipelines (`put`, `[?modify]`, ref advancement, compaction).

This is explicitly **anti-JPA/Hibernate**: V's lightweight ORM is *not* the model. CX takes a data-flow approach — reads are projections over content-addressed state; writes are commands that append new content and advance refs (object_model.md §4). The two paths share only the content-addressed object store beneath them.

---

## 3 — Transaction / unit-of-work

A transaction context spans **multiple backends + other state-changing ops**. It is a **write-path** construct (reads don't enlist, §2).

**Resolved (open question 3): saga/compensating + per-backend ACID; no cross-backend 2PC.** True heterogeneous-backend 2PC ACID is not generally possible, so it is **not** offered. Instead:

- **Single-backend transactionality** — AMENDED (stream 7 L127, #714): the former "single-backend ACID via the `Transactional` capability" claim is superseded by the consistency vocabulary; no spec'd backend advertises it today, and the spec inventory records isolation vocabulary appearing nowhere. What IS true and spec'd: the native engine's ref-log CAS gives linearizable single-ref commit (`expect=` conditional writes). A transactionality advert re-enters, if ever, as a declarable consistency token.
- **Cross-backend unit-of-work** = a **saga**: an ordered set of per-backend steps with registered **compensating actions**; on failure, completed steps are compensated in reverse. Visibility over partial completion is explicit (no silent half-commit).
- The native engine's content-addressed writes are **idempotent** (same content → same hash), which makes retries and compensation safe by construction.

This sits in the write-path data flow as the enclosing context a command pipeline runs within.

---

## 4 — Model taxonomy (each a capability trait)

| Model | Role | Realization |
|---|---|---|
| **Document / CXPath structural** | the native core | object_model.md (Merkle tree, subtree addressing) |
| **KV** | put/get by key | the universal `StorageBackend` core |
| **SQL / relational** | tabular + relational query | external engine plugin (§5) |
| **Graph** | nodes + edges, traversal | native-over-substrate (resolved below) |
| **Columnar / analytical** | scan-optimized analytics | peer plugin (§6) |

**Resolved (open question 1) — Graph: native-over-substrate.** A graph is expressed **over the native content-addressed object model** (nodes are objects; edges are typed refs between object hashes — the Merkle DAG already is a graph), surfaced as a `Graph` capability with traversal ops. Wrapping an external graph database is a later specialization plugin for workloads that need a dedicated engine. Rationale: the object model already represents nodes+edges natively, so a native graph capability avoids a heavy external dependency and keeps graph data in the content-addressed, dedup'd, GC'd core; external graph engines remain an option, not a requirement.

Specialized ops on a model a backend doesn't implement **degrade-or-error per §1**.

---

## 5 — External-engine plug-in framework

**cxstore vs the database-access layer.** "cxstore" is the *native* content-addressed store (object_model.md). External databases are **not** cxstore — they are separate modules whose purpose is to use *their own* native power (SQL, etc.). They connect to cxstore only through the shared trait surface (§1): an external DB *may* implement the universal `StorageBackend` (so it can act as a content-addressed blob store — a secondary floor), but its **primary** value is its family capability. Independent build flags reflect the two concerns: `-d cx_db_sqlite` / `-d cx_db_pg` (database access — native SQL) and `-d cxstore_sqlite` (sqlite as a cxstore blob backend). The DB-access flags pull in `libsqlite3` / `libpq`; none is in the default/wasm build (verified: a default libcx links neither).

URL-dispatched backends over V's `vlib/db/*` (`sqlite://`, `postgres://`, `mysql://`, `redis://`):

- **Feature-gated C deps** — external engines are behind build features so the core binary doesn't force `libpq`/`libmysqlclient` on every build.
- **`net` capability-gating** — networked engines (postgres/mysql/redis) are denied at open without a `net` grant (deny-by-default), like the existing remote-backend gating.
- **Native model first — the point of an external engine.** An external engine is valued for its *native power* — SQL/relational for sqlite/postgres/mysql, data structures for redis, traversal for a graph DB — **not** as a dumb blob bucket. Each engine's native query capability is its **primary** surface: e.g. the SQL/relational capability exposes arbitrary **parameterized SQL** (`query`/`exec`) whose result rows return **as CX data** (a sequence of `row` elements, columns in projection order), flowing into CXPath / `[?match]` / `[?for]`. CX does **not** push CXPath/structural queries *down* into the engine — you query the engine in *its* language and get CX back.
- **The blob-KV floor — universal, secondary.** Every engine *also* satisfies the universal `StorageBackend` (put/get/has/list of CX docs as opaque blobs keyed by the Tier-1 content hash, object_model.md §5) — a portable content-addressed fallback on any backend. This is the floor, not the headline; the native capability above is why you reach for the engine.
- **Engines are gated impls of one common `SqlConn` trait.** The `[$sql-*]` surface (`sql.v`) is always compiled and engine-neutral: a `SqlConn` interface (`run(stmt, params) → SqlResult`), a registry, scheme→engine dispatch at `sql-open`, and a single rows→CX mapping. Each engine is a separate gated impl that converts its driver's rows into the neutral `SqlResult` — adding an engine never touches the surface. The URL scheme picks the engine; an engine not built errors clearly.
- **`sqlite` (#77) + `postgres` (#78) + `mysql`, realized.** `-d cx_db_sqlite` (libsqlite3, `sqlite://`), `-d cx_db_pg` (libpq, `postgres://`/`postgresql://`), and `-d cx_db_mysql` (libmysqlclient, `mysql://[user[:pw]@]host[:port]/db`) each provide a `SqlConn`. Native SQL via `[$sql-open]` / `[$sql-exec]` / `[$sql-query]` / `[$sql-close]`, parameterized (`?` for sqlite/mysql, `$1` for pg), rows → `[rows [row [<col> 'val'] …] …]` with real column names. (mysql's simple `query()` path has no placeholder binding, so `?` holes are filled with `escape_string`-quoted values — injection-safe; typed prepared binding is a follow-up.) sqlite open cap-guards `write`; pg/mysql open cap-guards `net`. Separately, the optional blob-KV `StorageBackend` floor exposes sqlite as a `[$store] sqlite://` cxstore backend (`-d cxstore_sqlite`) — distinct concern, distinct flag.
- **`redis`, realized — a non-SQL native surface.** redis is not relational, so it does not use `SqlConn`; `-d cx_db_redis` (pure-V RESP client, `redis://[:pw@]host[:port]`) provides its own self-contained surface. A single generic command verb exposes **every** redis command (not a fixed subset): `[$redis-open]` / `[$redis-cmd HANDLE WORD+]` / `[$redis-close]`. The RESP reply maps to CX recursively — string/integer/double/bool/bignum → scalar, null → CX null, array → `[list …]`, set → `[set …]`, push → `[push …]`, map/hash → `[map [k v] …]`. Open cap-guards `net`. (A `KvConn` abstraction is deferred until a second KV engine appears.) A graph DB would likewise expose its own traversal surface.

---

## 6 — Columnar (Arrow + Parquet)

- **Arrow** = in-memory columnar representation + zero-copy interchange (analytical results, binding hand-off).
- **Parquet** = on-disk columnar backend (`parquet://`).

**Resolved (open question 2) — Columnar sits *alongside* `data_bin`/`--cxcol`, not subsuming it.** `data_bin`/CXCol remains the **strict-canonical wire + identity** serialization (hashing, signed bundles, cross-binding parity — identity-critical, do not disturb). The `Columnar` capability (Arrow in-memory / Parquet on-disk) is a **separate analytical backend / Phase-1 peer plugin** for scan-heavy workloads. They share columnar concepts but serve distinct roles: `data_bin` = canonical wire/identity, Columnar = analytical query engine. The native pack store stays a row/tree store (object_model.md §9); analytical scans reach for the Columnar plugin. Relationship to the existing `vcx/arrow` module: that module is the Arrow C-Data interchange surface the Columnar capability builds on.

---

## 7 — Phase relationship

| Phase | What | This spec |
|---|---|---|
| **0.5 — Embedded** | in-process store, hardened by **#74** (append-log, [par] handle guard) | the floor the native engine ships on |
| **0.7 — Service** | CSRP service node + reference server (**#78**) | the service tier wraps a pack-backed local store |
| **Phase 1 — Native multimodel core** | the native pack engine (object_model.md) implementing the richest trait set; secondary/full-text indexes; bloom; mmap; compression; GC/retention; `StorageBackend` trait | **this spec is the foundation Phase 1 builds on** |
| **Phase 1.x+ — External engines** | sqlite (#77) → columnar → SQL servers/graph plugins | plug into §1/§5 |

Phase 1 delivers the native engine **and the pluggable framework** (this spec + the #76 trait). The external/columnar engines are the next milestone — they slot into the capability-tiered surface defined here.

---

## 8 — Relationship to the native engine

[`object_model.md`](object_model.md) specifies the native content-addressed engine that implements `StorageBackend` + `Indexed` + `Queryable` + `Compactable` (and, at the code layer, `FullText`). This document does not restate it; it defines the trait surface, taxonomy, CQRS paths, transactions, and plug-in framework that turn that single engine into a multimodel substrate other engines extend.
