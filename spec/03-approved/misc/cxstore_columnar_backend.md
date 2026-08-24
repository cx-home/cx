# cxstore — Columnar (Parquet / Arrow) Document Backend

**Status:** **03-approved** (graduated by owner ruling 2026-07-22; the
backend is implemented and conformance/test-covered, gated `-d` opt-in at
build time). For #129 / closes the D5 strand (#76 columnar peer backend).
**G3 GRANTED by owner 2026-06-29: Q1=a, Q2=a, Q3=a, Q4=a, Q5=b**
(URI `document+file://…?encoding=parquet`; one-level nested promotion + `__cx_doc`
blob fallback; declared `?schema=` supported + inference default; zstd default
codec; **scope INCLUDES object-store-hosted columnar `document+s3://…?encoding=
parquet` in this PR** — §8's s3 item is promoted in-scope). This note is
reimplementation-grade.

Companion docs: [`object_model.md`](../../03-approved/core/../std-lib/store.md)
(subtree object model), [`data-bin.md`](../../03-approved/core/data-bin.md)
(CXCol — the strict-canonical columnar binary), the locked cxstore URI/surface
design (memory `project_cxstore_url_and_surface_design`), and `vcx/arrow/`
(existing CX data-bin ↔ Parquet / Arrow-IPC round-trip).

---

## 1 — Framing (owner-locked: option (a), 2026-06-29)

The columnar backend is **a `document`-model store with a columnar at-rest
encoding** — a *peer* to the subtree object model, not built on it.

- A columnar store holds a **homogeneous-ish collection of record documents**
  (rows). At rest the collection is serialized **column-wise** (Parquet on disk,
  or Arrow IPC), via the existing `vcx/arrow` bridge over CXCol (`data-bin`).
- It presents the **same `[$store]` document API** as every other substrate
  (`put-doc` / `get-doc` / `list` / `iter` / `query` / `delete`). Columnar is an
  at-rest *encoding* choice, invisible to the verb surface — exactly as the
  faceted URI grammar intends (model × substrate × encoding are orthogonal).
- It is **doc-identity only** (see §4). The Merkle subtree object graph is *not*
  used: content-addressed objects are opaque blobs with nothing columnar to
  exploit, and a column store's value is the opposite of per-object framing.

Why (a) and not the alternatives (recorded for the G3 trail):
- **(b) columnar as an `ObjectBackend`** was rejected — objects are opaque
  hash-named blobs; storing them column-wise exposes no column to prune or push
  a predicate into, and it would break subtree structural sharing.
- **(c) an export/import verb only** (`[$store:export-parquet]`) was rejected as
  the primary form — it leaves query-pushdown and live-store interop on the
  table, which is the whole point of #76/D5. (An export/import *convenience* may
  still ride on top of the backend; see §8.)

The payoff (the reason D5 exists): **column projection + predicate pushdown** on
`[$store:query]` — read only the referenced columns / row-groups instead of every
document — plus zero-friction interop with the Parquet/Arrow ecosystem (a CX
store opens directly in DuckDB / pandas / Polars and vice-versa).

---

## 2 — Surface (URI grammar)

Columnar is an **encoding** of the `document` model on a file (or, later, an
object-store) substrate. It is therefore named within the locked grammar
`[document+]<substrate>://<loc>[?encoding=…]`, NOT as a brand-new scheme:

```
document+file:///data/events.parquet?encoding=parquet
document+file:///data/events.arrow?encoding=arrow-ipc
```

- `document+` is **required** (columnar is inherently the degenerate one-row-per-
  doc model — it has no subtree graph). A bare `file://…?encoding=parquet`
  (subtree default) is a **hard error**: subtree + columnar are incompatible.
- `encoding=parquet` (on-disk, compressed, the default columnar form) |
  `encoding=arrow-ipc` (memory-mappable Arrow stream/file, for zero-copy hand-off).
- **Self-describing reopen** (friction-reducer #1): on reopen the encoding is read
  from the file's own magic (`PAR1` / Arrow IPC schema message), so the
  `?encoding=` need only be stated at create or to assert. A stated encoding that
  mismatches the file's magic is a hard error.
- **OPEN QUESTION G3-Q1:** is `?encoding=parquet` the right spelling, or do we
  want a dedicated convenience substrate (`parquet://`, `arrow://`) that desugars
  to `document+file://…?encoding=…`? Recommendation: keep the canonical form
  `document+file://…?encoding=parquet`; the file extension already disambiguates
  for self-describing reopen, and a new top-level scheme would re-introduce the
  axis-conflation the URI rework removed. (A bare-path `*.parquet` → this form is a
  later inference convenience, tied to the deferred scheme-inference item B4.)

---

## 3 — At-rest layout

The store is a thin layer over the existing CXCol ↔ Parquet/Arrow bridge:

- **Collection → table.** The store's live document collection is assembled into
  one CXCol (`data-bin`) table — each document is one row; the union of document
  fields is the column set (§5). `vcx/arrow::write_parquet_data_bin(framed, path)`
  / `write_ipc_data_bin` serialize that framed CXCol to the file;
  `read_parquet_to_data_bin` / `read_ipc_to_data_bin` reverse it. **No new
  serializer is written** — the columnar file format is exactly what `vcx/arrow`
  already produces, so a CX columnar store IS a standard Parquet/Arrow file.
- **Store-key column.** A reserved column `__cx_key` carries each row's
  doc-identity store-key (SHA-256 of strict-canonical bytes, §4). It makes
  `get-doc`/`exists`/`delete` an O(row-group) keyed lookup (and a Parquet
  row-group statistics min/max prune on `__cx_key`), and it is what `migrate`
  preserves across substrates. `list` returns `__cx_key` column values without
  materializing rows.
- **Row reconstruction.** `get-doc(key)` reads the row whose `__cx_key == key`
  (column-pruned to the row + needed columns), rebuilds the CXCol single-row
  table, and `cx_from_data_bin`-decodes it back to the canonical document — which
  re-hashes to `key` (integrity check, hard error on mismatch, mirroring the
  object-graph `CXER1120` contract).
- **Write batching / persistence.** Parquet is write-once per file; a live store
  accumulates appended docs in an in-memory CXCol row buffer and flushes a
  **row-group** on `flush` / threshold / close (Parquet supports multiple row
  groups in one file). `delete` is a tombstone in the buffer; compaction
  (`gc`) rewrites the file dropping tombstoned rows — the same
  flush/compact shape the pack backend already uses, so the refs/watermark
  bookkeeping is reused. Arrow-IPC uses the streaming record-batch form for
  append.
  - **As-built (#221):** the shipped flush rewrites the whole file per persist —
    O(N) write amplification per put, inherent to the single-file snapshot
    posture until row-group-incremental append lands (the refinement above).
    Crash-safety is guaranteed regardless of cadence: the local `file://` flush
    writes to a same-directory temp file and **atomically renames** onto the
    live path (mirroring the s3 arm's single-object PUT), so a (re)open sees
    either the old file or the new file, whole — never a torn parquet against a
    live manifest.

---

## 4 — Identity & compatibility

- **doc-identity = UNIVERSAL (preserved).** The store-key is the SHA-256 of the
  document's strict-canonical bytes — substrate/encoding-invariant, exactly as on
  every other backend. A doc put into a columnar store has the *same* store-key it
  would have anywhere. `migrate` to/from columnar preserves keys (re-encode rows ↔
  re-decompose objects), so columnar interoperates with every other substrate at
  the document level.
- **object-identity = N/A.** A columnar store has no subtree object graph, so the
  `subtree↔subtree` "transfer-only-missing-objects" path (`clone`/`push`/`pull`)
  does **not** apply. Cross-model transfer degrades to the doc-level `migrate`
  fallback (already the defined cross-model rule). `clone`/`push`/`pull` against a
  columnar endpoint are a capability-gated error directing the caller to
  `migrate` — never a silent partial.
- **status/introspection.** `object_count`/dedup ratio are object-graph metrics
  and are reported as **not-applicable** (no fabricated zeros — same posture as
  the document model on other substrates). Columnar reports its own observables:
  row count, row-group count, column count, on-disk bytes, compression codec.

---

## 5 — Schema, heterogeneity, nesting (the hard part)

Columnar demands a column schema; CX documents are arbitrary trees. The backend
must be **total** (any document collection is storable) while giving pushdown for
the homogeneous common case.

- **Homogeneous records (the target case).** A collection of records with the
  same scalar fields (e.g. AIS positions, log events, metrics rows) infers a flat
  schema: one typed column per field, full CXCol type fidelity (int width/sign,
  float, bool, date/datetime, string, bytes). This is the pushdown-fast path.
- **Schema = union, nullable.** Across a heterogeneous-but-flat collection the
  schema is the **union** of all top-level fields; a row missing a field stores
  null. Column order is the strict-canonical field order (deterministic), so the
  file is reproducible.
- **Nested / irregular documents.** A field whose value is itself an element /
  sequence / map (not a scalar) is encoded as a **nested column** when the nesting
  is uniform (Parquet/Arrow support nested types, and CXCol already carries the
  structure). When a collection is too irregular to project (mixed shapes at the
  same path), the backend falls back to a single **`__cx_doc` blob column**
  carrying the canonical document bytes: fidelity and doc-identity are preserved,
  but that store (or that column) loses pushdown — and the store **says so** via
  an introspection flag (`columnar_pushdown=false`), never silently.
- **OPEN QUESTION G3-Q2:** how aggressive should automatic nested-column
  promotion be vs. defaulting irregular collections to the `__cx_doc` blob?
  Recommendation: promote uniform top-level scalar + one-level-nested fields;
  blob-fallback anything deeper or mixed, with the introspection flag. (Deeper
  nested-pushdown is a later refinement, not a #129 gate item.)
- **OPEN QUESTION G3-Q3:** declared vs. inferred schema. Recommendation: support
  an optional declared schema at open (`?schema=<cxschema-ref>`, reusing
  `cx-stdlib/validate` shapes) that *pins* columns and rejects non-conforming
  docs (CXER); default to inference when absent. Declared schema is what makes a
  columnar store a stable analytics table.

---

## 6 — Query pushdown (the value)

`[$store:query]` with a CXPath that reduces to **column projection + a scalar
predicate** (e.g. `//event[= $_@level 'error']/timestamp`) is lowered to a columnar
scan: read only the projected columns, prune row-groups by Parquet min/max
statistics on the predicate column, and evaluate the predicate vectorized over
the surviving batches via `vcx/arrow`. A CXPath that does not reduce to
columns/predicates (deep structural navigation) falls back to row materialization
(decode each row → existing predicate engine) — correct, just not accelerated;
the backend reports which path it took (no silent full-scan masquerading as
pushdown). This reuses the CSRP/`store-query` pushdown plumbing already shipped
(#119) — columnar is a new *executor* under the same query verb, not a new verb.

*(Timing note — I5 stream 17 W4, ruled L91/#710 item 2.)* The shipped executor
reads **only** the projected column + `__cx_key` (a projected decode that
cursor-skips every other column payload) and answers final-step predicates from
columns whenever the answer provably equals the row scan's (the Q6 exactness
envelope): for promoted columns the candidate shape is promotion-invariant, so
one evaluation of the row scan's own predicate engine decides every row —
that verdict-once form *is* the vectorized evaluation for the shipped predicate
grammar, which tests names/attributes/position and never cell values. Min/max
row-group pruning and per-cell vectorized comparison therefore have **no live
predicate form to consume them yet**; they activate when the predicate grammar
grows a value-comparison form, extending over the already-projected buffers.

---

## 7 — Capabilities & read/write

- **Substrate = file** ⇒ embedded; needs the `file` write capability for create /
  append / compact, `read` for open. (A future `s3`/object-store-hosted Parquet is
  a follow-up — same encoding, remote substrate.)
- A Parquet store opened read-only (or over a read-only byte source) honors
  `read-only=true`; writes error (`CXER1110`).
- No new capability classes; columnar rides the existing `file`/`net` gates.

### 7.1 Build gating (libcx_arrow is opt-in) — IMPORTANT

The Parquet/Arrow read/write lives in `vcx/arrow` over the **optional**
`libcx_arrow` C library (Makefile §153: "Optional Apache Arrow C-Data interop
library … built on demand by `test-*-arrow` … opt-in per binding"). It is **not**
built or exercised by the default `make test` gate. Therefore the columnar
backend is a **gated substrate**, exactly like `cxsqlite` (`-d cx_db`):

- **Graceful absence (no silent fail).** Opening `…?encoding=parquet` /
  `arrow-ipc` when `libcx_arrow` is not present must return an honest error
  (`E_STORE_UNRESOLVED_BACKEND`-class, mirroring `store_sftp_unbuilt()`):
  "columnar encoding requires the Arrow build (`make build-lib-arrow`)". The
  capability gate (`file`/`net`) is still checked FIRST (deny-by-default), so an
  ungranted caller learns nothing about whether arrow is built.
- **Dedicated gated test target.** The §9 behavioral gate cannot run under default
  `make test`. It needs a target that builds `lib-arrow` first (e.g.
  `test-vcx-columnar`, analogous to `test-python-arrow`), wired so CI exercises it
  with the lib present. The default `make test CX_CACHE=` stays green by routing
  the columnar test behind that target — NOT by leaving the backend untested
  (that would recreate the unconsumed-seam gap). Document the target in the gate.

---

## 8 — Non-goals / deferred

- **Columnar over a service tier** (`cx-store://` daemon serving Parquet) — later;
  this note covers embedded substrates (file + s3) only.
- **Object-store-hosted columnar** (`document+s3://…?encoding=parquet`) — **IN
  SCOPE (G3-Q5=b).** The columnar file is serialized to bytes and stored as a
  single s3 object (one PUT / one GET) over the existing s3 transport; reuses the
  file-backend's CXCol↔Parquet bytes path, differing only in where the bytes
  land. The `vcx/arrow` bridge is path-based, so the s3 path writes to a temp
  file then uploads (or uses a bytes variant if one is added).
- **Deep nested-column pushdown** beyond one level — refinement.
- **CDC / incremental column append across files** (D4) — stays deferred.
- An explicit `[$store:export-parquet]` / `import-parquet` convenience MAY wrap the
  backend later, but is not the primary surface (§1 (c)).

---

## 9 — Acceptance gate (§6-style, what "done" proves, post-G3)

A gated behavioral test through the **live `[$store]` verbs** (no engine-only
island), per substrate-test convention, hermetic (writes a temp Parquet/Arrow
file — no external service):

1. **Round-trip:** open `document+file://tmp.parquet?encoding=parquet`; put a
   homogeneous record collection; `get-doc` each by store-key → byte-identical
   canonical doc; reopen (self-describing) → same docs.
2. **Doc-identity universality:** the store-key of a doc in the columnar store ==
   its store-key in a `mem://` store (same strict-canonical hash).
3. **Migrate:** `migrate` a `mem://` collection → columnar and back; all
   store-keys preserved.
4. **Pushdown:** a column-projecting + predicate `[$store:query]` returns the
   correct rows AND reports `pushdown=true` (assert it did not full-scan); a
   deep-structural query returns correct rows with `pushdown=false`.
5. **Heterogeneity totality:** an irregular collection stores via the `__cx_doc`
   blob fallback with `columnar_pushdown=false`, round-trips byte-identically.
6. **Interop:** the written file opens as a valid Parquet/Arrow file (validated by
   the existing `vcx/arrow` reader, which is the production reader — i.e. the file
   IS standard Parquet, provable by reading it back through `read_parquet_to_data_bin`).
7. **Integrity:** a corrupted row / wrong `__cx_key` on read → hard `CXER1120`,
   never a silent wrong doc.

New verbs: **none** (columnar is an encoding under existing verbs). New
introspection fields (`columnar_pushdown`, codec, row/row-group counts) need their
co-located `[fn-doc]` updates + conformance backing where they surface.

---

## 10 — Decisions needed for G3

- **G3-Q1** — URI spelling: `document+file://…?encoding=parquet` (recommended) vs.
  a `parquet://`/`arrow://` convenience scheme.
- **G3-Q2** — nested-column promotion aggressiveness vs. `__cx_doc` blob fallback
  (recommended: one level + flag).
- **G3-Q3** — declared (`?schema=`) vs. inferred schema (recommended: support
  both, infer by default).
- **G3-Q4** — codec default for `encoding=parquet` (recommended: zstd; snappy as
  an option) and whether the codec is part of the URI (`?compression=`) — it
  already is in the grammar.
- **G3-Q5** — scope confirmation: embedded-file only for #129/D5, with
  service-tier + object-store-hosted columnar as named follow-ups (§8).

---

## 11 — Implementation status (as built, PR-D)

Reimplementation-grade record of how the G3-locked design was realized. All of
Q1–Q5 are implemented; nothing in this note is deferred.

- **Backend shape.** Columnar is a `document`-model, docs-backed store
  (`store_objgraph_active == false`): the live collection is `ms.docs`
  (hash → canonical text). Persistence assembles a CXCol `:table` →
  `cx.emit_data_bin_chunked` → `vcx/arrow` `write_parquet_data_bin` /
  `write_ipc_data_bin`. Gated `-d cxstore_columnar` (+ `-d cx_arrow_files` for the
  Arrow file I/O); the dispatcher cap-gates first, then honest-errors when the
  Arrow build is absent. Dedicated gate target `make test-vcx-columnar`.
- **Reserved columns + integrity anchor.** Every file carries `__cx_key` (string,
  the store-key) and `__cx_doc` (string, the doc's canonical TEXT). `__cx_doc` is
  the reconstruction + integrity anchor: `get-doc` returns it verbatim, and load
  re-hashes `__cx_doc == __cx_key` (CXER1120 on mismatch). Promoted columns are a
  **redundant projection** — never the reconstruction source — so the store is
  total for any document collection.
- **Q2 — promotion via column FLATTENING (one level).** A top-level field promotes
  as a depth-1 scalar column (`name`) when it is a scalar leaf in every doc that
  has it, or as **flattened depth-2 columns** (`name.sub`) when it is a flat scalar
  sub-record in every doc that has it. CX leaf kinds: numbers are `ScalarNode`,
  strings/atoms are `TextNode` (both are scalar leaves). The **sound rule**: a name
  observed in more than one shape (scalar vs record), or ever complex
  (deeper-nested / attributed / mixed), **or duplicated** — the same top-level name
  twice in one doc, or the same sub-name twice in one record (ruled 2026-08-10,
  #767: a column holds ONE cell, so duplicates cannot round-trip) — is not
  promoted; a column null ⟺ the path is absent, keeping predicate pushdown exact.
  Type union: `int`+`float` → `float`, otherwise → `string`; **decimal scalars
  project as `float` columns** (ruled 2026-08-10, #766 — the projection is
  redundant by design, `__cx_doc` stays the exact reconstruction source, and
  `float` is the Parquet/DuckDB interop type). Each column carries a derived
  **exactness bit**: exact iff every observed cell's re-synthesis reproduces the
  stored leaf byte-for-byte — no type widening ever occurred and no coerced
  source (decimal→float, temporal→string, …) contributed. Columns are sorted for
  a reproducible file.
- **Q6 — query pushdown (exactness-gated; ruled 2026-08-10, #767 + #768).** The
  pushdown answers a query from columns **exactly when its answer provably equals
  the row scan's** — never a fast wrong answer. Projectable class: the
  DESCENDANT forms `//field` (depth-1 column) and `//parent/child` (the flattened
  `parent.child` column) — absolute/relative paths row-materialize (under
  document-node anchoring, `/x` addresses the per-doc ROOT, whose name varies by
  doc — not a column). Preconditions, all derived in the schema pass (which
  already parses every live doc): **occurs-only-top-level** — the first segment's
  name is never a doc's root name and never occurs deeper than depth 1 anywhere
  in the corpus (else a descendant query could match nodes no column carries);
  the answering **column is exactness-marked** (Q2); the name is promoted at all.
  Any failed precondition, a deeper path, or a predicate returns `none` → the
  caller materializes rows from `__cx_doc`. Returning some/none is the honest
  pushdown report. The pushdown emits the same **flat provenance-bearing
  relation** as the row executor ([`store.md`](../std-lib/store.md) §12, stream-2
  ruling L97) — one `[result doc= source= …]` tuple per match; shape AND answer
  parity between the two executors is pinned by the #711 probe fixtures.
- **Q3 — declared `?schema=`.** `?schema=<path>` (or `[opts schema=…]`) loads a
  `cx-stdlib/validate` `[schema …]` shape at open; every put to a columnar store
  with a declared schema is validated via `cx.validate` and a non-conforming doc is
  rejected with **CXER1115 `E_STORE_SCHEMA_VIOLATION`** (pinning the table shape).
  Inference is the default when no schema is declared.
- **Q5 — s3-hosted columnar.** `document+s3://…?encoding=parquet` stores the
  columnar file as a single s3 object (one PUT/GET) over the injected
  `S3Transport` seam; the Arrow bridge is path-based, so flush stages a temp file
  then uploads its bytes, and load fetches → temp → reads. The alias map is a
  sidecar object. The object is a standard Parquet/Arrow file.
- **Introspection (§4).** `[$store:status]` on a columnar store reports `docs`
  (row count), `encoding`, `codec`, `columnar-pushdown`, and `columns`
  (reserved + promoted) — and omits `object_count` / dedup / `remote`
  (doc-identity only; no fabricated metrics).
- **Acceptance gate.** `vcx/code/store_columnar_test.v` (16 tests, run under
  `make test-vcx-columnar`) covers §9 items 1–7 plus scalar + nested-flattened
  promotion, mixed-shape non-promotion, s3 round-trip, status observables, and
  declared-schema accept/reject. The default `make test CX_CACHE=` stays
  Arrow-free and green (the backend honest-errors when unbuilt).
