# Rulings 2026-08-20 — durable feed lineage across daemon restarts (#764)

## FL-1 — data-plane feed positions become durable (the revocations-plane precedent)

**Status:** RULED (owner reclassified #764 as a pre-cut BUG, 2026-08-20:
"764 is now classified as a bug and should be taken care of prior to cut").
Direction ruled: follow the revocations-plane precedent — durable,
journal-backed positions that survive restart; never carry the
process-lifetime retention debt across the cut.

**The bug.** The XSP store profile's three data planes (`docs` / `refs` /
`aliases`) kept lineage for the daemon PROCESS LIFETIME only: every boot,
`store_feed_seed` rebuilt the lineage compacted from the loaded snapshot
under a FRESH boot token, so every resume cursor from a previous boot was
refused (`CXER5020`) and the client re-seeded a full replay. Only the
revocations plane survived restart (its positions are a designated
journal's seqs). Restart of a healthy daemon therefore cost every
subscriber a full replay — cross-cutting technical debt, now a bug.

**Ruling.**

1. **Durable lineage sidecar.** Every local durable substrate (`file`
   document model, `cxpack`, `cxobj`, `sqlite`, `columnar`) persists its
   lineage in an append-ordered sidecar log (`.cxstore-lineage` under the
   store root for directory-rooted substrates; `<root>.cxstore-lineage`
   beside file-rooted ones). Each live act (insert / retract / erase /
   advance across the three data planes) appends ONE record at write time,
   through the same funnel that records the in-memory act
   (`store_feed_append`) — one log, two media. `mem://` has no durable
   substrate (restart loses the STORE, so boot-relative positions are
   already the honest story) and remote-proxy mounts keep no local lineage
   at all; both keep today's behavior by construction. `s3` keeps
   process-lifetime lineage at this landing (its state survives restart
   but it has no local root; an old cursor refuses typed and re-seeds
   exactly as today) — flagged for an owner call, not silently absorbed.

2. **The boot token becomes the durable EPOCH token.** Minted once at the
   store's first lineage seed, persisted in the sidecar header, reloaded
   on every boot. The head-set / cursor wire shape is UNCHANGED (fully
   additive — zero wire change): an old client that echoes the head-set's
   `boot="…"` token now finds it stable across restarts, so its prior-boot
   cursor RESUMES.

3. **Boot reload replaces reseed.** On open, a store whose sidecar replays
   cleanly loads the persisted epoch token, per-stream floors, retained
   acts, and head positions — positions are stable across boots and
   strictly monotonic per stream, forever. The snapshot-compaction seed
   remains ONLY for a store with no persisted lineage (first boot /
   upgraded store / non-durable substrate): that path keeps today's
   behavior and then writes the initial sidecar.

4. **Retention is explicit and bounded.** The sidecar is compacted when it
   accumulates redundancy (records > 2 × live entities + 64 — the same
   heuristic the file index log uses): the rewrite retains the
   state-compacted story (the latest act per live entity, erase evidence
   included — attribution survives compaction) at their ORIGINAL positions
   and records one explicit per-stream retention FLOOR = the highest
   compacted-away position. Invariant: each stream's retained acts are
   exactly positions floor+1 … head, dense. No unbounded growth, on disk
   or at boot.

5. **CXER5020 narrows to what it honestly means.** A resume cursor refuses
   typed (`E_XSP_STORE_CURSOR`, the `:gapless`-class refusal — re-seed
   from the new head-set) exactly when gapless resume is impossible:
   (a) its epoch token is not this lineage's token (unknown boundary);
   (b) any entry's position is below that stream's retention floor
   (compacted-away history); (c) any entry's position is above that
   stream's head (a position this lineage never issued — a crash-window
   cursor). A valid prior-boot cursor RESUMES. An empty `[from]` remains
   the full replay of the retained (state-compacted) story and needs no
   token.

6. **Crash-safety: verify-then-trust, never silent divergence.** Sidecar
   writes are append-ordered; the boot reload VERIFIES before it trusts:
   header/epoch intact, per-stream density above the floors, and the
   retained acts' fold agreeing with the loaded snapshot (live docs,
   ref roots, alias targets, erased set). Any mismatch — torn tail, a
   crash between the lineage append and the state append, a store mutated
   by a pre-lineage binary — discards the sidecar, mints a FRESH epoch,
   reseeds from the snapshot (today's exact behavior), and rewrites the
   sidecar. A partially-persisted act can therefore never corrupt resume:
   the failure mode is the honest typed refusal + re-seed, never a gap
   served silently. A failed sidecar append mid-boot leaves a position
   gap in the file that the next boot's density check catches the same
   way.

**What is preserved.**
- The wire contract: `feed` / `feed-sub` / head-set / `[from …]` shapes
  are byte-compatible; old clients keep working (they simply stop being
  refused after restarts).
- The revocations plane: untouched (already durable; it was the
  precedent).
- The seed story: "history compacted to a snapshot" remains the from-empty
  replay semantics and the first-boot path.
- `store:log` porcelain and the live-modes local feed read the same
  in-memory lineage as before.
- Clone/migrate destinations still start their lineage at the destination
  open's seed (fresh epoch — positions are per-store, never transplanted).

**What changes.**
- `vcx/platform/store_lineage.v` (new): sidecar format, append, load /
  verify, compaction, epoch persistence.
- `vcx/platform/store_objgraph.v`: `store_feed_append` also appends the
  durable record; `store_feed_open` (load-else-seed) replaces the bare
  seed at registration.
- `vcx/platform/store_xsp_feed.v`: cursor validation = epoch + floor +
  head checks (the narrowed CXER5020).
- `vcx/platform/stdlib_store.v`: MemStore lineage fields; swap/close
  carry them.
- `spec/03-approved/xap/xsp_store_profile.md` §5.1/§5.2 amended: durable
  data-plane positions, the retention rule, the narrowed CXER5020
  meaning. §4.2 row wording trued. No other clause weakened.
- `vcx/platform/stdlib_live.v` stale "#764" comment trued.

**Owner options flagged (not landed).**
- s3-substrate lineage (sidecar object in the bucket) — see report,
  lettered option; today's refuse-and-reseed behavior retained there.

Closes #764 (pre-cut).
