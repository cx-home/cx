# CXStore — Content-Addressed Object Model (Design, Draft)

**INTERNAL — DO NOT PUBLISH. DO NOT MIRROR TO `cx-home/cx`. SEE [`README.md`](README.md).**

**Status:** Spec-track, lifecycle stage **02-working** (design record; the model is **implemented and shipped** — the subtree object-graph engine is live on `release/0.13.0` across the pack (`file://?encoding=pack`), object-per-key, sqlite, and s3 substrates plus the CSRP/gRPC object wire; the approved [`store.md`](../../../spec/03-approved/std-lib/store.md) §7/§9 defines the ObjectBackend/encryption seam inline and normatively — this doc is the deeper design rationale, not a normative dependency of any approved spec). **Home (decided, 2a):** `docs-src/canonical/cxstore/` alongside [`pack_format.md`](pack_format.md) — lifecycle tracked via this header, *not* relocated into `spec/01-new` (keeps cxstore specs together inside the INTERNAL tree).
**Scope:** The storage *model* beneath the on-disk [`pack_format.md`](pack_format.md) — object kinds, identity, dedup, recovery, concurrency, and the in-memory ↔ persistent unification. The pack file is the storage *atom*; this is the *model* it serializes.
**Coordinates:** #80 (subtree addressing / structural sharing), under #75 (unified backend architecture); couples #76 (StorageBackend trait), #77 (sqlite backend), #79 (code identity / normalization), #81 (GC/retention), #82 (identity/order), #83 (pack engine + master index), #84 (bloom), #85/#86 (secondary/full-text indexes), #89 (compression).

> **No ADRs.** CX does not use ADRs; all decisions live in specs. References below point to spec files (e.g. `[?modify]` → [`spec/03-approved/core/code.md`](../../../spec/03-approved/core/code.md)), never to decision records.

---

## 1 — Design values (the weighting behind every decision)

In priority order, as set by the project owner:

1. **Soundness & resilience.** Immutable content must be self-verifying; the store must be recoverable. The floor; nothing compromises it.
2. **Uniformity / one mechanism** (*not* raw simplicity). The model is orthodox, not minimal — Merkle + bounded-fanout spine + bloom + refcount + compaction is several moving parts. The value we hold is that they are *one uniform mechanism* applied everywhere, not a pile of special cases. We accept an explicit **complexity budget** for that uniformity, paid deliberately (see §3).
3. **Homoiconic leverage.** Exploit code = data, but only where it *removes* mechanism.
4. **Performance.** Predictable across all document/store shapes; no O(n) cliffs.
5. **Pluggability.** A sound native core; specialized engines (analytics/graph/SQL) plug in.

Palette is deliberately conventional (git log + Merkle + bloom + B+tree). The novel angle — homoiconic reuse — is additive.

---

## 2 — Architecture: content-addressed, append-only

Objects are named by the hash of their content (a Merkle tree). The alternative — a copy-on-write, page-addressed B-tree (LMDB/Noms-page style) — was rejected for the core because #80's defining capabilities require content addressing:

- **cross-doc / cross-version dedup** — content hashes are universal; page-ids are store-local and edit-order-dependent.
- **diff & sync by hash-skip** — transfer only subtrees the peer lacks.
- **content-addressed code** — a function is a subtree named by its (normalized, §5) hash; dependency hashing is automatic.

**These three are confirmed non-negotiable Phase-1 product bets** (service tier + dedup + code store). The spine complexity is therefore a forward bet, paid before the #74 hardening gate, accepted deliberately under the value-2 complexity budget. CoW-B-tree wins only if all three are dropped — they are not.

Content addressing is also the **integrity mechanism**: name = hash(content), so every read self-verifies and silent corruption of immutable content is impossible.

---

## 3 — Object model: four kinds, one spine principle

| Kind | Content |
|---|---|
| **Leaf** | A single CX scalar; inlined into its parent below a size threshold, promoted to its own object only when large. |
| **Blob** | A large opaque byte payload, stored as a chunked byte-rope. |
| **Node** | An element/map: tag + attributes + an ordered child **Sequence**. |
| **Sequence-node** | Internal node of the bounded-fanout tree over a Node's children. |

**Governing principle:**

> **No object's hash input may exceed a bounded size B.**

Every "N things" (child list, byte payload) is interposed by a bounded-fanout tree, so a parent references at most ~B child-hashes. This turns every O(n) into O(log_B n) — what a naive per-element Merkle-DAG lacks (its wide-node parent references all N children → O(n) rehash; the **wide-table cliff**).

**Worked pathological case (to be a normative spec example):** a table of 10⁶ rows is one Node whose child Sequence is a B+tree of depth `⌈log_B 10⁶⌉` (≈ 3 at B=256). Editing one row rehashes that one root-to-leaf path — ~3 Sequence-nodes + the Node — *not* a 32 MB concatenation of 10⁶ child hashes. Appending a row touches only the rightmost spine.

**Spine structure:** deterministic **fixed-fanout B+tree** (ordered sequences) / **HAMT** (maps). Chosen over content-defined / "prolly" chunking for the core: deterministic, no probabilistic tuning knob, append-optimal. **Explicit consequence:** native sync/diff is **structure-dependent, not history-independent** — the same *semantic* edit may move a larger subtree than a content-defined peer would. Content-defined chunking (history-independent sync, better diff under mid-sequence-insert churn — collab/event-stream workloads) is a **named plugin**, required for that workload class, not "free." See the workload table (§11).

`B`, the leaf-inlining threshold, and blob chunk-size are **format parameters** (tunable without a version bump). **`B` is locked to 32** by the PL8 benchmark (§11); the leaf-inlining threshold and blob chunk-size remain to be tuned.

**Object-kind versioning:** every log entry carries a tagged header `(kind, version)`; readers skip-with-warning on unknown kinds/versions using the entry length (per [`pack_format.md`](pack_format.md) reserved-kind rule). Forward-compatible by construction.

---

## 4 — Concurrency & multi-writer (in the v1 floor)

Multi-writer is designed into the floor, not deferred. It is cheap *because* content addressing localizes contention:

- **Object writes need no coordination.** Any writer may append any object to the log at any time. Two writers appending the same object produce byte-identical duplicates — harmless (self-verifying, valid), reconciled at compaction (§5). No locks on the object log.
- **The only contention point is ref advancement.** Advancing a named root (`ref → root-hash`) is a **compare-and-swap** against the expected current root, or a **lease**-guarded write, on the ref-log. Concurrent advances on the same ref serialize; the loser retries (re-reads the new root, re-applies its change, re-CASes) or merges.
- **Epochs for crash-ordering.** Each ref-log entry carries a monotonic epoch. Recovery selects the highest-epoch ref entry whose root subtree fully verifies (§6).

This keeps the coordination surface identical to the corruption surface: a tiny ref-log. The embedded tier collapses to the single-writer special case (CAS always succeeds); the service tier uses the same mechanism under contention.

---

## 5 — Identity & dedup (two-tier)

A single identity notion cannot serve both lossless data round-trip *and* content-addressed code (`f x = x+1` and `f y = y+1` must collide for Unison-style code dedup, but must not be conflated with presentation-stripping for data). So identity is **two-tier, both first-class in the spec** (Tier-2 impl may lag; the relation is defined now, jointly with #79/#82):

| Tier | Hash domain | Used for | Match defeats on |
|---|---|---|---|
| **1 — Lossless** | Canonical AST incl. comments/anchors/order | All data; storage identity; native dedup; sync | differing comments/anchors |
| **2 — Normalized** | Binder/alpha-normalized, comment-insensitive, dependency-resolved-by-hash | Code/lib kinds (opt-in namespace) | true semantic difference |

- **Native dedup and sync use Tier-1.** Two subtrees share storage iff their canonical AST is byte-identical (canonicalization already normalizes whitespace/attr-order/formatting; only comments/anchors defeat a match — and in a lossless language those *are* different documents).
- **Code addressing uses Tier-2**, in a distinct namespace, never conflated with Tier-1. This is what makes the §2 "content-addressed code" claim true. Defining the normalization (binder handling, dependency-by-hash) is the work of #79/#82 — this doc names it as required, not solved.
- A comment/anchor-insensitive **data-identity index** (a third, derived layer) remains optional/future — only if that margin proves material.

**Dedup is automatic, global, fine-grained** (a consequence of content addressing): within a doc, across versions (edit one field of a 10⁶-row doc → only the O(log n) changed-path objects are written), across docs, store-wide, and over code (Tier-2).

**Logical vs physical dedup.** Logical dedup is **immediate** (a write references an existing hash). Physical single-copy-store-wide is **eventual** — reached at compaction. Between write and compaction a few byte-identical duplicate objects may exist on disk; harmless, just unreclaimed space. **APIs must not promise "single physical copy" before compaction.** Compaction latency is bounded by policy (#81).

**Refcounts count content-hash, not physical slot** — else transient duplicates double-count reachability. (See §8.)

---

## 6 — Soundness & recovery model

**Honest claim:** *immutable subgraphs are self-verifying; the mutable ref surface is minimal and recoverable by scan.* (Not "the whole store is nearly impossible to corrupt" — the mutable name layer and multi-writer ordering are where real corruption risk lives, addressed below.)

1. **One source of truth: the append-only object log.** No in-place mutation; a change writes new objects + advances a ref.
2. **Everything else is derived & regenerable** — footer index, bloom (#84), secondary indexes (#85), full-text (#86), master hash→pack index (#83). Lost/corrupt → `cxstore rebuild` re-scans the log. None authoritative.
3. **The mutable surface is a tiny `ref → root-hash` log** — append-only, fsync'd, double-buffered, epoch-stamped (§4). The corruptible surface is a few hundred bytes per ref.
4. **Crash safety (object log):** a torn write leaves a valid prefix; recovery truncates to the last entry whose hash verifies.
5. **Crash ordering (ref log):** "current root" is the **highest-epoch ref entry whose root subtree fully verifies.** A crash between an object write and its ref advance simply leaves orphan objects (reclaimed by GC), never a dangling ref.
6. **Mutable name/alias layer is in the floor.** A name resolving to a wrong-but-verifying root is user-visible corruption; the ref-log's epoch + CAS discipline (§4) and the "verify subtree before accepting a root" rule (5) are what prevent it. This layer is specified at the same bar as the object log, not bolted on.
7. **Pack torn-write.** A torn pack must be no worse than a torn log entry: pack seal is the commit point (footer + footer-length); an unsealed/torn pack is treated as a valid-prefix object stream and its tail truncated. [`pack_format.md`](pack_format.md) MUST align its seal/recovery semantics with this section.
8. **Rebuild is recoverable *and* must be operable.** "Recoverable" ≠ "fast": full-log rescan may be long. Spec a **rebuild SLO** and incremental/checkpointed rebuild tooling (#83), so ops has a bounded restore time, not just a guarantee.
9. **Versioning/rollback/audit** are inherent — old roots persist.

---

## 7 — In-memory ↔ persistent unification + promotion invariants

One object model, same content hashes both layers; a document begins as a plain in-memory tree (un-promoted: no hashing, no spine) and is **lazily promoted** to content-addressed form when it (a) crosses a size threshold, (b) is persisted, or (c) undergoes a structural-sharing update. Persisting a modified doc writes only the new changed-path objects — the in-memory sharing contract and the on-disk write cost become the same number.

`[?modify]` (see [`spec/03-approved/core/code.md`](../../../spec/03-approved/core/code.md), §8.10 action vocabulary) already produces a new document sharing unchanged subtrees in RAM; under this model, persisting its result is exactly "write the new objects." The structural-sharing perf contract for `[?modify]` is the in-memory case of this doc's on-disk dedup.

**Promotion invariants (normative — must hold before implementation):**

- **P1 — One canonicalization.** The canonicalization used for promotion ≡ the one used for persistence: same `B`, same ordering rules, same thresholds. There is exactly one canonical-form function.
- **P2 — Path independence.** `load_from_disk(root_hash)` and `promote(in_RAM_tree)` yield the **same root hash** for the same logical document.
- **P3 — No premature hashes.** An un-promoted in-memory tree exposes **no** content hash through any API. Hashes appear only post-promotion.
- **P4 — Pure promotion.** Promotion is a pure function of (canonical rules, thresholds). No ad-hoc hashing in eval/build caches. (Failure mode to forbid: the evaluator caching a hash of an un-promoted tree under its own rules.)
- **P5 — Shape determinism.** Partial/subtree promotion yields **identical spine shapes** for the same semantic subtree, regardless of promotion order.

---

## 8 — GC / retention (couples #81)

- **Reachability graph = structural edges (parent→child) + alias/anchor edges.** Mark-sweep from roots MUST traverse both. The Merkle structure makes structural edges visible (closing the flat-manifest "orphaned child" hole); **alias edges are specified as reachability edges now**, even though cycle *collection* is deferred.
- **Refcount (by content-hash) on the hot path; mark-sweep authoritative at compaction.** Because aliases can create cycles, refcount alone is insufficient for reclamation — mark-sweep is the source of truth; refcount is an optimization that must be safe (never reclaim a mark-sweep-reachable object).
- **Bounded compaction latency** is a retention policy (#81), required because physical dedup and space reclamation both depend on it (§5).

---

## 9 — Bloom, columnar, external backends

- **Bloom (#84)** — derived per-pack existence-check accelerator (no false negatives), central to write-path dedup and sync; rebuilt at seal, never authoritative. A small in-memory union/hierarchical bloom across packs answers "which pack might hold H" (a derived master-index accelerator, #83). Variant (standard vs cuckoo/xor) **not locked** — perf-data-driven (#84).
- **Columnar / analytics — a Phase-1 peer, not "later."** Not a native object kind. It appears as (a) an optional internal chunk-encoding for compression (#89), and (b) a **pluggable specialized backend** (Arrow in-memory / Parquet `parquet://`) whose trait boundary ships in Phase 1 via #76 (impl may lag). **The native store is a row/tree store, not a warehouse:** tabular *scan* workloads require the columnar backend; native handles transactional cell edits at O(log n).
- **External engines (#77 sqlite, etc.) — one identity model, not two.** External backends store CX documents as **opaque blobs keyed by the native Tier-1 hash**; they do **not** participate in subtree dedup or CXPath pushdown (the "KV-works / no-CXPath-pushdown" boundary from #75 §5). There is a single identity model (the native Merkle's); external engines are blob stores indexed by it.

---

## 10 — Homoiconic leverage (additive)

The same content-addressed store holds data, code, schema, queries, and its own metadata with no new machinery:

- **No separate code store** — Unison-style function addressing is "a function is a subtree named by its Tier-2 hash" (§5); dependency-aware hashing is automatic from the Merkle structure (#79).
- **Self-describing store** — meta-records, index descriptors, schemas, lineage are CX docs in the same store; recovery tooling reads the store in CX itself.
- **Provenance & caching fall out** — a cached result references its query-doc hash + input-root hash; staleness is a hash comparison; incremental recompute is "which input subtree-hashes changed."

---

## 11 — Workload table (gates locking B / bloom / CDC)

Native vs plugin per workload class. `B` = fanout; `n` = size. **`B`, bloom variant, and CDC are now LOCKED per the PL8 benchmark below.**

| Workload | Shape | Native handling | Disposition |
|---|---|---|---|
| Doc edit (localized) | tree, small/medium | B+tree path rehash, O(log n) | **native** |
| Code library | many function subtrees | Tier-2 normalized identity (§5) | **native + normalized-identity mode** |
| Wide table — transactional | Node + B+tree of row-Nodes | O(log_B n) cell edit | **native** |
| Wide table — analytical scan | columnar | row/tree store, O(n) scan | **columnar plugin** (#76 trait, Phase-1 peer) |
| Large blob | chunked rope | O(log size) edit/append | **native** |
| Sync / replication | hash-skip | structure-dependent diff (not history-independent) | **native** |
| Collab / high mid-insert churn | sequence churn | larger subtree movement per semantic edit | **CDC plugin** (named, required for this class) |

### PL8 — measured fanout tradeoff (locks `B`)

Measured by `vcx/cxstore/bench_test.v` on a 100,000-element sequence (single-element edit cost = objects written for one change; overhead = seq-node metadata as % of element count):

| B | depth | total objs | seq-node overhead | edit cost (objs) | build ms |
|---|---|---|---|---|---|
| 8 | 6 | 114,289 | 14.3% | 7 | 26 |
| 16 | 5 | 106,669 | 6.7% | 6 | 20 |
| **32** | **4** | **103,228** | **3.2%** | **5** | **17** |
| 64 | 3 | 101,589 | 1.6% | 4 | 15 |
| 128 | 3 | 100,790 | 0.8% | 4 | 14 |

`edit cost == depth + 1` exactly across all B → confirms O(log_B n) edits empirically. The tradeoff: smaller B = finer dedup granularity (a leaf groups fewer children, so scattered edits share more) but more objects (index/GC pressure); larger B = fewer objects but coarser sharing and a larger per-edit leaf rewrite (`B × 32` bytes).

**Locked decisions:**
- **Fanout `B` = 32** (default). The balance point: single-digit edit cost (5 objects), depth 4, modest 3.2% metadata overhead, and finer dedup than 64/128. `B` remains a **format parameter** — workloads that are append/scan-heavy and rarely edited may set `B = 64` to halve overhead; this needs no version bump.
- **Bloom variant = standard Bloom for v1** (no false negatives; simple, proven). Cuckoo/Xor filters deferred to **#84**, to be revisited only if lookup-perf data justifies the extra complexity.
- **CDC disposition = out of the core.** Fixed-fanout already delivers O(log_B n) edits (table above), so content-defined chunking earns its place only for history-independent sync / high mid-sequence-insert churn — it stays a **named plugin** (the Collab row), not the default spine.

---

## 12 — Cost model across the shape matrix

| Shape | Edit one item | Append | Read | Dedup unit |
|---|---|---|---|---|
| Small doc | rewrite tiny doc | — | O(1) | whole-doc |
| Deep-narrow | O(depth) = O(log n) | — | O(depth) fault | subtree |
| **Wide-shallow** | **O(log_B n)** | amortized O(1) | O(log_B n) | seq-chunk |
| Columnar (native) | O(log_B n), one path | amortized O(1) | O(log_B n) | seq-chunk |
| Large blob | O(log size) | O(log size) | O(log size) | byte-chunk |
| Many small docs | — | — | — | subtree across docs |
| Hot-edit versioned | O(log n) new objects | — | — | all unchanged shared |
| **Very deep tree** | O(depth) | — | O(depth) | subtree |

**Very deep trees:** O(depth) read/edit is acceptable, but store walkers MUST be **iterative (heap-stacked), not native-recursive**, and a configurable **max-depth** bound is enforced to prevent native-stack exhaustion and hostile-input blowups.

---

## 13 — Wins / tradeoffs

### Wins
- Integrity by construction (immutable content self-verifies).
- Trivial rebuild-from-log recovery; corruptible surface = a tiny epoch-stamped ref-log.
- Global, fine-grained dedup (data Tier-1) + content-addressed code (Tier-2).
- O(log n) everywhere; no wide-doc edit cliff.
- In-memory and on-disk unified (`[?modify]` sharing = persistence), under written promotion invariants.
- Multi-writer cheap (contention only on the tiny ref-log).
- Homoiconic reuse (one store for data + code + schema + meta).
- Conservative palette; pluggable specialization (columnar a Phase-1 peer).
- Versioning/rollback/audit inherent.

### Tradeoffs (accepted)
- Orthodox, not minimal — explicit complexity budget (value 2).
- Write-path hashing (mitigated by lazy promotion §7 + bloom §9).
- More small objects → index/GC pressure (bounded fanout caps it; compaction reclaims).
- Tier-1 dedup is comment/anchor-sensitive (data-identity index deferred, optional).
- Native sync is structure-dependent, not history-independent (CDC plugin for that class).
- Physical dedup eventual (logical immediate); compaction must be bounded-latency.
- Native store is row/tree, not warehouse — analytics needs the columnar plugin.
- Rebuild is bounded by an SLO, not instantaneous.

---

## 14 — Decision ledger

| Decision | Resolution |
|---|---|
| Architecture | Content-addressed append-only Merkle tree (not CoW-B-tree); Merkle bets confirmed non-negotiable |
| Source of truth | Append-only object log; all indexes/blooms derived & rebuildable |
| Mutable surface | Tiny fsync'd, double-buffered, epoch-stamped `ref → root-hash` log |
| Concurrency | **Multi-writer in v1 floor** — uncoordinated object writes; CAS/lease on ref advancement |
| Object kinds | Four — Leaf, Blob, Node, Sequence-node; tagged `(kind,version)` headers |
| Spine | Deterministic fixed-fanout B+tree / HAMT; CDC = named plugin; sync structure-dependent |
| Identity | **Two-tier** — Tier-1 lossless canonical-AST (data); Tier-2 normalized (code, #79/#82); data-identity index optional |
| Dedup | Automatic/global/fine-grained; logical immediate, physical at compaction; refcount by content-hash |
| Columnar/analytics | Phase-1 peer pluggable backend (#76) + optional chunk-encoding; not a native kind |
| External backends | Opaque blobs keyed by Tier-1 hash; one identity model (#77) |
| GC | Reachability = structural + alias edges; refcount (by hash) + mark-sweep authoritative |
| In-mem ↔ persist | One model, same hashes, lazy promotion; promotion invariants P1–P5 |
| Value framing | Value 2 = uniformity/one-mechanism (not raw simplicity); explicit complexity budget |

---

## 15 — Pre-promotion punch-list (must clear before implementation / #74 gate)

1. §6 expansion landed: ref-log crash ordering, pack torn-write alignment in [`pack_format.md`](pack_format.md), rebuild SLO + tooling.
2. Two-tier identity (§5) co-developed with #79/#82; Tier-2 normalization defined (impl may defer).
3. Promotion invariants (§7, P1–P5) verified against the eval/build path.
4. Multi-writer ref-log CAS/lease + epoch semantics specified (§4) and reflected in the service-tier design.
5. GC reachability rule incl. alias edges (§8) specified; cycle collection may defer.
6. Explicit ties to #75, #76, #77, #79–#82 (§ throughout) — no parallel story.
7. ✓ `canonical.md` §2.11.1 pins map key order (lexicographic, normative for content-addressed identity); Sequence/Array stay order-significant (§2.1). Spine order follows canonical order. (PL7 — resolved.)
8. Workload table (§11) ratified with measured numbers before locking `B`, bloom variant, CDC disposition.

---

## 16 — Open / deferred (non-blocking for the core lock; owned downstream)

- Fanout `B`, leaf-inlining threshold, blob chunk-size (tune via §11; format params).
- Tier-2 normalization *implementation* (#79).
- ~~Set-like order normalization specifics (#82).~~ Resolved: map keys order-normalize per `canonical.md` §2.11.1; Sequence/Array are order-significant. Remaining for #82: Tier-2 normalization impl (→ #79) and anchor/alias cycle semantics.
- Cycle *collection* in GC (reachability rule incl. aliases is specified now; #81/#82).
- Bloom variant std-vs-cuckoo/xor (#84).
- Optional data-identity dedup index.
- CDC plugin (only for the named insert-heavy/collab class).

---

## Appendix A — Normative mechanics (impl-ready)

Detail level sufficient to implement #83 directly. Parameters in `code font` are tunable (locked by §11 Track-2 benchmarks), not magic numbers.

### A.1 Object encoding & naming
- Canonical object bytes: `[kind:u8][version:u8][body]`. Object name = `H(canonical-bytes)`, 256-bit.
- **Hash function** = SHA-256 to match [`pack_format.md`](pack_format.md). BLAKE3 (faster, tree-friendly — directly attacks the write-path-hashing tradeoff) is a **Track-2 benchmark candidate**, not yet locked; switching is a `pack_format` version bump.
- Leaf inlining: a child below `inline_threshold` serialized bytes is embedded in its parent body rather than referenced by hash (kills small-object explosion).

### A.2 Node, Sequence-node, HAMT
- **Node body:** `[tag][attrs (canonical-ordered)][seq_root_ref]`; `seq_root_ref` is the hash of (or inline) the child Sequence root.
- **Sequence-node (ordered children, B+tree):** internal = `[child_ref × m]`, leaf = `[element_ref × m]`, `m ≤ B`. Order = canonical document order. Edit at index *i* rehashes only the root→leaf path (O(log_B n)); append touches only the rightmost path (amortized O(1)).
- **Maps (HAMT):** keyed by canonical key hash; key order pinned by `canonical.md` §2.11.1 (normative for identity → order-normalized map dedup). Insert/delete touches one root→leaf path.

### A.3 Blob rope
- Bounded-fanout tree of byte-chunks; chunk target = `blob_chunk_target`. Edit/append/read O(log size). Chunk encoding may be columnar/compressed (#89) without changing the model.

### A.4 Ref-log (the entire mutable surface)
- **Record (fixed-width, 92 B):** `[epoch:u64][ref_name_hash:32][root_hash:32][writer_id:16][crc32c:4]`.
- **Durability:** append-only; each 92-B record is fsync'd on commit. A torn **trailing** record is detected by crc + length and ignored — the log is read as its valid prefix (any corruption in an append-only log is in the tail). Crash-safe **compaction** (squashing the log to the live head per ref) writes a temp file + `fsync` + atomic `rename`, so a crash mid-compaction leaves the old log intact.
- **Current root of a ref** = the record with the **highest `epoch`** for that `ref_name_hash` whose `root_hash` resolves to a **fully-verifying** subtree (every reachable object's hash checks). A higher-epoch record pointing at a non-verifying root is skipped (covers crash-between-object-write-and-ref-advance).

### A.5 Multi-writer commit protocol (3b)
- **Object append: uncoordinated.** Any writer appends any object at any time; duplicate objects are byte-identical → harmless, reconciled at compaction (§5). No locks on the object log.
- **Ref advance: compare-and-append.** To commit a new root R for ref F observed at prior root R₀:
  1. Write all new objects of R to the log; fsync.
  2. Append a ref-log record `{epoch = max_epoch(F)+1, F, R, writer_id, crc}` **iff** the current head of F still resolves to R₀ (compare-and-swap).
  3. CAS realized by: an OS advisory file-lock around the read-head-then-append on the ref-log (embedded tier), or a lease/CAS primitive (service tier). Same protocol both tiers; embedded is the always-wins special case.
  4. **On conflict** (head moved to R₁ ≠ R₀): re-read R₁, rebase the change onto R₁, recompute R, retry from step 1. (Application-level merge policy is out of scope here; the store guarantees linearizable ref advancement, not semantic merge.)
- Coordination surface = ref-log appends only; identical to the corruption surface (§6).

### A.6 Tier-2 normalized identity (code) — definition
Applies only to objects in the opt-in code/lib namespace. Tier-1 (lossless) is always computed and is the storage/round-trip identity; Tier-2 is an **additional** key used for code dedup/lookup. `N(tree)`:
1. **Strip comments** and presentation-only anchors.
2. **Alpha-normalize binders** → positional De Bruijn indices, so `f x = x+1` and `f y = y+1` normalize identically.
3. **Resolve free references** (dependencies) to their **Tier-2 hashes** (content-addressed deps → dependency-aware hashing falls out).
4. **Canonical-order** declarative/commutative sections per `canonical.md`.
- Tier-2 hash = `H(N(tree))`. Binder rules, dependency resolution scope, and which kinds are "code" are owned jointly with **#79/#82** — this is the contract; their issues ratify the edge cases.

### A.7 Pack torn-write (aligns §6 ↔ pack_format.md)
- Pack seal = footer + 8-byte footer-length suffix. Reader: if footer-length or footer-crc is invalid → treat the pack as **unsealed**; recover by scanning entries from offset 64 until the first entry whose length/hash fails, then truncate there. An unsealed pack still contributes its valid object prefix — every object self-verifies, so objects remain addressable; they are merely unindexed until re-seal/compaction. **`pack_format.md` must state this seal/recovery contract explicitly.**

### A.8 Rebuild (recoverable AND operable)
- `cxstore rebuild`: sequential scan of all packs' object streams → reconstruct master `hash→(pack,offset)` index, per-pack blooms, and secondary indexes (#85/#86). All are derived (§6.2).
- **Incremental:** checkpoint `(pack_id, offset)` of the last fully-scanned position; rebuild resumes from the checkpoint rather than rescanning sealed packs.
- **SLO:** target restore time is a `rebuild_slo` policy bounded by sequential-read throughput over live bytes; surfaced to ops, not just guaranteed in principle (#83).

### A.9 GC mechanics (PL5; couples #81/#82)

- **Roots** = all live ref-log heads (§A.4) ∪ roots pinned by the retention policy (#81: latest-N / time-window / tagged). Retention policy defines the root set and bounds compaction latency.
- **Edge set of an object** (both kinds are reachability edges):
  - *structural* — Node → `seq_root_ref` and attr refs; Sequence-node → child refs; Blob → chunk refs;
  - *alias/anchor* — an alias object references its anchor's target by Tier-1 hash.
- **Mark-sweep (authoritative, at compaction):** from roots, trace all edges, mark every reachable content-hash; any object whose hash is unmarked is garbage and is omitted from the compacted pack. Tracing is cycle-safe by construction (a visited-set terminates cycles).
- **Refcount (hot-path optimization only):** a per-**content-hash** refcount maintained on ref-advance (incref objects newly referenced by the new root, decref those the old root no longer reaches). Counting by content-hash — never physical slot — so transient physical duplicates (§5) don't perturb it. Refcount = 0 is a *hint* for eager reclaim; it is **not** authoritative, because alias edges can form cycles a refcount can't collect. Only mark-sweep reclaims definitively; the refcount optimization is safe because its worst case is *failing to free* a cycle, never freeing a live object.
- **Cycle collection: deferred** (whether cycles are even reachable depends on #82's anchor/alias semantics). Until resolved, mark-sweep already handles cycles correctly; only the refcount *optimization* is cycle-blind, which is the safe direction.

---

## Appendix B — Coordination matrix (PL6)

Single source of truth for what this spec **provides** to each coupled issue and **assumes/needs** from it — so there is no parallel or contradictory story.

| Issue | object_model provides → | ← assumes / needs from it |
|---|---|---|
| **#75** unified arch | the native, richest-trait storage engine this spec models | the trait surface, capability tiers, CQRS read/write split, transaction/unit-of-work envelope |
| **#76** StorageBackend trait | native implementation of the trait | the trait shape; columnar as a *peer* trait (§9) |
| **#77** sqlite backend | the Tier-1 hash as the opaque blob key | external engines = opaque blob stores keyed by hash, no CXPath pushdown; one identity model |
| **#79** code identity | the Tier-2 normalization *contract* (A.6) | ratification of binder rules, dependency-resolution scope, and which kinds count as "code" |
| **#81** GC/retention | the reachability rule + mark-sweep + refcount (A.9) | the retention policy (root set) and the compaction-latency bound |
| **#82** identity/order | two-tier identity + reliance on a canonical form | map key-order pin (✓ `canonical.md` §2.11.1); still: Tier-2 norm (#79), alias/anchor cycle semantics |
| **#83** pack engine | the full object model + impl-ready mechanics (App. A) | the implementation, master `hash→(pack,offset)` index, rebuild SLO/tooling |
| **#84** bloom | the derived existence-accelerator role + no-false-negative contract | the filter variant (std vs cuckoo/xor), perf-data-driven |
| **#85/#86** indexes | the "derived & rebuildable, never authoritative" contract | the secondary / full-text index designs |
| **#89** compression | the per-chunk encoding hook (transparent to the model) | the codec choice |

---

## Appendix C — Promotion invariants verified against the implementation (PL3)

Grounded in a read-only audit of `vcx/`. **Node model:** a `Node` sum type with `Element{name, attrs[], items []Node, meta, table}` and collections `SequenceNode/ArrayNode/MapNode` — children held as **flat `[]Node` slices** (`vcx/cx/ast.v`). **Per-node** binary encoding already exists (`encode_node`, `vcx/cx/binary.v:293`). Today's only content hash is text-level: `cx_text_hash` = canonicalize → emit canonical text → SHA-256 (`vcx/cx/tooling.v:65`).

| Invariant | Verdict | Evidence / action |
|---|---|---|
| **P1** one canonicalization | **pin (low risk)** | Tier-1 = `SHA-256(canonical ast_bin)`, where the subtree is canonicalized with the **existing `cx_text_canonical` rules** (MapNode lexicographic sort, prefix/namespace canon — `canonical.md`) *before* `encode_node`. Reuses CX's one canonical form; matches `pack_format.doc_hash`. #83 wires per-node `encode_node` + this canon, **not** the whole-doc text path. |
| **P2** load ≡ promote → same hash | **holds by construction** (given P1) | `encode_node` is deterministic (fixed tags/field order, LE — `binary.v:293-455`); canonicalization is pure → same subtree hashes identically whether promoted in RAM or decoded from disk. |
| **P3** no premature hashes | **CONFIRMED in code** | No runtime path hashes an in-memory node. The `*_node_hash` helpers (`path_node.v`/`match_node.v`/`modify_node.v`…) are **test-only**; must stay out of runtime. Invariant already holds — only needs *preserving*. |
| **P4** pure promotion, no ad-hoc eval hashing | **CONFIRMED** | Eval never hashes nodes; promotion adds cleanly as a pure function. |
| **P5** shape determinism | **holds by construction (fixed-fanout)** | Children are a flat `[]Node`; the B+tree spine is a NEW layer inserted between an Element and its `items` when `items.len > B`. Fixed-fanout (not CDC) → spine shape is a pure function of the sequence, order-independent. (Independent reason to keep CDC out of the core, §3.) |

**Strong corroboration of §7.** `[?modify]` already performs **spine-copy structural sharing** (`vcx/code/eval.v:7910-8260`, gate 30.5): it clones the `items` slice along the root→match path and leaves every sibling subtree pointer-identical. That is the exact in-memory analog of on-disk path-copy — promotion only needs to content-address the objects `[?modify]` already produces. §7's "in-memory sharing and persistence are the same operation" is therefore **validated against real code, not assumed**.

**Integration note for #83.** The flat `items []Node` is the *un-promoted* form. Promotion = canonicalize → build a fixed-fanout B+tree over `items` when large → content-address each object via `encode_node` + SHA-256 (`MapNode` → HAMT analogously). Reuse `encode_node`; never route promotion through the whole-doc text path.

