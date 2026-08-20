# Rulings 2026-08-20 — durable feed lineage on s3-rooted stores (#885)

## FL-2 — bucket lineage: the s3 substrate joins the FL-1 durability contract

**Status:** RULED (owner, 2026-08-20: "6b" — pre-cut, do not defer). FL-1
(#764) gave every LOCAL durable substrate an append-ordered lineage sidecar;
`s3` was left on seed-per-boot ("flagged for an owner call, not silently
absorbed" — FL-1 ledger). The owner call is: land it now, soundly.

**The gap.** An s3-rooted store's STATE survives restart (objects +
`.cxstore-manifest` in the bucket) but its feed lineage did not: every boot
reseeded compacted-from-snapshot under a fresh epoch, so every prior-boot
cursor refused (`CXER5020`) and every subscriber re-replayed in full — the
exact bug FL-1 fixed everywhere else, still present on the one substrate
whose state is the MOST durable.

**Single-writer: the precondition holds (evidence, not assumption).**

1. `store_s3_flush` (vcx/platform/store_s3_subtree.v) persists the refs
   manifest as ONE unconditional snapshot PUT of the whole key →
   `.cxstore-manifest`. Two concurrent daemon writers on one bucket root
   would already silently clobber each other's REFS today — with or without
   lineage. The substrate's existing durability contract is therefore
   single-writer-daemon per bucket root.
2. No cross-process locking or conditional-write machinery exists anywhere
   in the store tree (grep `If-Match`/`ETag`/`If-None-Match` over vcx/: zero
   hits in store code; local substrates have no flock either).
3. #628 ruled the only sound multi-writer shape is a SHARED in-process
   MemStore ("two independent writers on one root collide on segment
   numbering — the second flush clobbers the first's segment file";
   store_open_shared_or_conflict). s3 inherits the same model: the daemon
   that owns the store is the one writer. FL-1 rode this; FL-2 rides it
   unchanged and weakens nothing.

**The design choice: (i) per-segment lineage objects — never RMW.**

Ruled for segments over read-modify-write of one lineage object under
conditional PUT, on the evidence:

- **The client has no conditional-write machinery** (`s3_object_op` sends no
  `If-Match`; nothing parses response ETags). Under the single-writer model
  conditional PUT buys NOTHING — there is no concurrent writer to lose a
  race to — so adding ETag plumbing to the client would be machinery without
  a consumer (the "seam with no live consumer = partial impl" rule).
- **Append = PUT a new small object with a monotonic name.** Names are
  unique by construction (the owning daemon mints them), so there is no RMW
  race to avoid in the first place. RMW would also make every append
  O(lineage) transferred bytes (GET whole + PUT whole); a segment is O(act).
- **S3 PUT is atomic per key** (readers see the whole object or none — the
  same property #287's replace_object_keyed already relies on), so a crashed
  append leaves a complete segment or nothing: NO torn tails on this
  substrate. The FL-1 verify-before-trust boot still guards every other
  inconsistency window (crash between the lineage PUT and the manifest PUT,
  a bucket mutated by a pre-FL-2 binary) via the same density + fold-match
  checks — any mismatch discards, mints a fresh epoch, and reseeds
  (today's exact behavior remains the fallback and the first-boot path).

**The bucket layout** (sibling keys of `.cxstore-manifest`, same transport,
same at-rest posture as the manifest — substrate metadata, plaintext even on
an encrypted store, exactly like the manifest whose keys/roots it mirrors):

- `.cxstore-lineage/G-<gen 16-hex>-full` — one generation's base: header +
  epoch record + per-stream floor/head records + the retained acts (the
  byte-identical FL-1 sidecar format; one parser serves both media).
- `.cxstore-lineage/G-<gen>-S-<seq 16-hex>` — one act per segment, PUT at
  write time from the same funnel (`store_feed_append`), BEFORE the state
  flush lands — append-ordered, as FL-1 requires.

Boot = one LIST (the rotation-walk pattern) + GET full + GETs of that
generation's segments in seq order, concatenated and fed to the SAME
parse/verify/install as the local sidecar. Compaction (same
`records > 2 × live + 64` heuristic) writes the compacted full object under
generation g+1 — the generation guard: boot trusts the HIGHEST generation
that has a full object — then deletes the old generation's keys best-effort
(stragglers are ignored by the guard and swept by the next compaction).
Unrecognized keys under `.cxstore-lineage/` are ignored, never trusted and
never a permanent reseed-flap: content verification (density + fold-match)
is the authority, not key names.

**Semantics preserved verbatim from FL-1 (zero wire change):** the durable
epoch token rides the same head-set `boot=` attribute; retention floors and
the narrowed `CXER5020` (wrong epoch / below floor / above head) apply
unchanged; a valid prior-boot cursor RESUMES on an s3-rooted store. A failed
segment PUT is tolerated in-process (the in-memory lineage keeps serving
this boot); the next boot's density check catches the gap and reseeds fresh
— degraded retention, never silent divergence. Read-only handles load but
never write. `mem://` and remote-proxy mounts keep their FL-1 story.

**Out of scope (riders, flagged not absorbed):** the gated columnar-over-s3
variant (backend `columnar`, root `''`, one Parquet object) still keeps
process-lifetime lineage — it is the columnar substrate's story, not the s3
subtree's; and the remote-proxy mounts keep no local lineage by design.

**What changes.**
- `vcx/platform/store_s3_lineage.v` (new): key naming, bucket scan,
  load-else-seed open, segment append, generation-guarded compaction write,
  old-generation purge.
- `vcx/platform/store_lineage.v`: the sidecar parser is factored to bytes
  (`store_lineage_install`) so one parser serves file and bucket media;
  `store_feed_open` / `store_lineage_append` / `store_lineage_compact`
  dispatch per substrate.
- `vcx/platform/stdlib_store.v`: MemStore gains `lineage_gen` /
  `lineage_seq` bookkeeping (stays with the handle, like
  lineage_path/active/records — the FL-1 swap rule).
- `spec/03-approved/xap/xsp_store_profile.md` §5.1: the "`s3` keeps
  seed-per-boot at this landing" carve-out is replaced by the bucket-lineage
  sentence (RULED: FL-2).
- `vcx/platform/store_s3_lineage_test.v` (new): the store_lineage_test.v
  restart-resume proof mirrored against the hermetic in-memory S3 transport
  (the same client seam the §6 conformance test uses): resume across
  "restart" (fresh MemStore over the same bucket), wrong-epoch / above-head
  / below-floor refusals, pre-FL-2 bucket seeds fresh and writes lineage,
  torn lineage discards + reseeds + is durable again, compaction bumps the
  generation and purges the old one.

Closes #885 (pre-cut; the parent closes).
