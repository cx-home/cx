# Rulings 2026-08-20 — durable feed lineage on the columnar substrate (#887)

## FL-3 — the columnar backend joins the FL-1/FL-2 durability contract

**Status:** RULED (owner, 2026-08-20: **"2a"** — fix pre-cut). The owner's
standard, quoted: *"cx store must hold content addressed pieces (default) or
document based across all substrates the same."* Restart-safe resume must not
be substrate-dependent. FL-2's own out-of-scope note named exactly this gap
(rider (a), ledger/rulings_2026_08_20_s3_lineage.md): *"the gated
columnar-over-s3 variant (backend `columnar`, root `''`, one Parquet object)
still keeps process-lifetime lineage."* This ruling closes it.

**The gap, precisely.** FL-1 (#764) gave every LOCAL durable substrate an
append-ordered lineage sidecar and already listed `columnar` in
`store_lineage_path_of` (`<root>.cxstore-lineage`), so a columnar store over a
local file root has had durable lineage since FL-1 — *unproven*, though: no
gate exercised it, because the columnar pack is compile-gated
(`-d cxstore_columnar`) and neither store_lineage_test.v nor
store_s3_lineage_test.v runs in that lane. FL-2 (#885) gave `s3`-ROOTED stores
(backend `s3`) bucket lineage. The columnar substrate's s3 shape is neither:
`store_columnar_open_s3` builds a MemStore with `backend == 'columnar'`,
`root == ''`, and the whole store held as ONE Parquet/Arrow object addressed
through an injected `S3Transport` (`columnar_s3` / `columnar_s3_key`). It
matched no arm: `store_lineage_path_of` returned `''` (no root),
`store_feed_open`'s bucket arm tested `backend == 's3'` and did not fire, so
`lineage_active` stayed false and every boot reseeded compacted-from-snapshot
under a fresh epoch — a prior-boot cursor refused `CXER5020` and the
subscriber re-replayed in full. The one asterisk on the contract.

**Single-writer: the precondition holds on columnar too (evidence, not
assumption).**

1. `store_columnar_flush` (vcx/platform/store_columnar_d_cxstore_columnar.v)
   rewrites the WHOLE store on every mutation: the s3 arm serializes the entire
   live collection and PUTs it as one unconditional object at
   `columnar_s3_key`; the local arm writes the whole file to a sibling temp
   path and atomically renames it over the root. The alias sidecar
   (`<key>.cxstore-aliases`) is the same whole-object rewrite. Two concurrent
   daemon writers on one columnar store would therefore already clobber each
   other's ENTIRE DOCUMENT COLLECTION today — with or without lineage. This is
   a strictly stronger statement than FL-2's s3-subtree evidence, where only
   the refs manifest was the wholesale PUT.
2. No conditional-write machinery exists on this path either: `S3Transport`
   carries `fetch/keys/store/remove` and nothing more — no `If-Match`, no ETag
   parse, no `If-None-Match` — and the local arm holds no flock.
3. #628's shared-root rule is unchanged: the only sound multi-writer shape is a
   SHARED in-process MemStore. Columnar (like `sqlite` and `s3`, and unlike
   `file`/`cxobj`/`cxpack`) does not register with
   `store_open_shared_or_conflict`, so it inherits the same
   single-writer-daemon-per-store contract FL-1 and FL-2 rode. FL-3 weakens
   nothing and invents no lock. (Flagged as a rider, not absorbed: whether
   columnar should join the #628 same-root sharing gate is a pre-existing
   question about the whole-object rewrite, not about lineage.)

**The ruling: reuse by FACTORING, never a third lineage.**

There are exactly TWO lineage media in CX and there will not be a third:

- an append-ordered SIDECAR FILE beside a local root (FL-1,
  `store_lineage.v`), and
- a family of small OBJECTS under a key prefix on an S3 transport (FL-2,
  `store_s3_lineage.v`).

The columnar substrate needs no new medium — it needs to be MOUNTED on the
existing two. So:

1. **The bucket machinery is factored from a backend to a MOUNT.** FL-2's
   segment implementation addressed `&S3ObjectBackend` and hard-coded the key
   prefix `.cxstore-lineage/`. It is factored to a `StoreLineageBucket` =
   `(S3Transport, key-prefix)` pair, resolved once by
   `store_lineage_bucket_of`. Two mounts, one implementation:
   - the s3 SUBTREE store — transport = the concrete `S3ObjectBackend`'s
     transport, prefix `.cxstore-lineage/` (a sibling of `.cxstore-manifest`:
     byte-for-byte the FL-2 layout, unchanged);
   - the COLUMNAR store over s3 — transport = `columnar_s3`, prefix
     `<columnar_s3_key>.cxstore-lineage/`, siblings of the Parquet/Arrow object
     itself, exactly as its alias sidecar is `<columnar_s3_key>.cxstore-aliases`.
     A columnar store IS one object, so its lineage keys hang off that object,
     not off the bucket root — two columnar stores in one bucket keep separate
     lineages by construction.
2. **The substrate dispatch becomes a predicate, not a backend-name test.**
   `store_feed_open` / `store_lineage_append` / `store_lineage_compact` ask
   `store_lineage_is_bucket(ms)` (`backend == 's3'`, or `backend == 'columnar'`
   with an s3 transport) instead of `backend == 's3'`. A columnar store over a
   LOCAL root keeps the FL-1 sidecar file it already had — `store_lineage_path_of`
   already resolves `<root>.cxstore-lineage` for it — and is now GATED, so the
   contract is proven on both columnar shapes rather than assumed on one.
3. **Everything else is FL-1/FL-2 verbatim.** The same durable epoch token on
   the same head-set `boot=` attribute; the same retention floors and the same
   `records > 2 × live + 64` compaction heuristic; the same generation guard
   (boot trusts the highest generation with a full object, the new base lands
   before the old generation is purged best-effort); the same narrowed
   `CXER5020` (wrong epoch / below floor / above head); the same
   verify-before-trust boot (header + epoch intact, per-stream density above
   the floors, retained-acts fold agreeing with the loaded snapshot). Anything
   torn or inconsistent discards, mints a FRESH epoch, and reseeds
   compacted-from-snapshot — today's behavior remains the fallback and the
   first-boot / pre-FL-3 path. **Zero wire change.**
4. **Ordering holds by construction.** The columnar flush is a whole-store
   rewrite triggered by the op AFTER `store_feed_append` has run, so the
   lineage segment PUT still lands BEFORE the state — append-ordered, FL-1 §6
   unchanged. A failed segment PUT is tolerated in-process; the next boot's
   density check catches the gap and reseeds. Read-only handles load, never
   write.

**What changes.**
- `vcx/platform/store_s3_lineage.v`: `StoreLineageBucket` + `store_lineage_bucket_of`
  + `store_lineage_is_bucket`; the key builders, the scan, the read, the full
  PUT, the purge, the open, the append and the compacted write all take the
  mount instead of `&S3ObjectBackend`. No behavior change for the s3 subtree
  (its mount is the previous hard-coded pair).
- `vcx/platform/store_lineage.v`: the three dispatch sites test
  `store_lineage_is_bucket(ms)`; `store_lineage_path_of`'s comment trued.
- `spec/03-approved/xap/xsp_store_profile.md` §5.1: the durable-lineage
  paragraph names the columnar substrate on BOTH shapes — the sidecar beside a
  local root, the object family beside the single columnar object on s3 — and
  the "local substrates … columnar" phrasing that carved columnar-over-s3 out
  by omission is replaced (RULED: FL-3).
- `vcx/platform/store_columnar_lineage_test.v` (new, `-d cxstore_columnar`):
  the FL-2 restart-resume proof mirrored at the columnar seam over the
  hermetic in-memory transport, plus the local-root columnar sidecar proof.
- `Makefile`: `test-vcx-columnar` runs the new gate alongside
  `store_columnar_test.v`.

Closes #887 (pre-cut).
