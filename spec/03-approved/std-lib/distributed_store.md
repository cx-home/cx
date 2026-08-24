# Distributed store (stream 9)

**Status:** APPROVED — graduated 2026-08-20 by owner ruling SPR-1 (G3; ledger/rulings_2026_08_20_spec_tree_reshape.md). Prior status: working draft (stream 9, issue #681). Replicated references, causal history, offline synchronization, conflict-representation-as- values; the M5 offline replica is the live consumer. Builds on stream 4 (the profile is the wire). Normative once approved; implementation at I5 after stream 4.

**Worked example (M5):** a clerk takes orders on a disconnected tablet.
Seed: `changes-since` at a signed head-set (a filtered, authorized
replica — the seed is a query). Offline: orders append to a
REPLICA-LOCAL stream with `valid-from` in the payload. Sync: objects and
entries transfer byte-identical (content addressing — solved); the
replica stream ingests as a disjoint aggregate (order-independent
composition — no sequencer touched); refs reconcile per-ref under
`expect-pos` CAS; the two refs that both moved come back as inspectable
`[conflict]` values with base/ours/theirs diffs; resolutions re-enter on
the next sync as an input table. Reading the synced order at
`{at-seq: post-sync, valid-at: Aug 1}` shows VT preceding TX by four
days — the honest picture, not an anomaly. Every entry hash verifies
against a signed chain.

## §1. Findings

1. **The immutable plane is solved; the mutable plane is untouched:**
   clone/push/pull/fetch move objects + content-addressed doc-refs
   (conflict-free by construction) and deliberately skip
   aliases/branches — the only plane where divergence is expressible.
   `pull` ≡ `fetch` today; results are bare counters; zero divergence
   fixtures exist anywhere.
2. **`status`'s spec'd ahead/behind does not exist in the
   implementation** — the one field the ruled replica profile requires
   (#719).
3. **E3 made store.md's "no parent-linked structure" claim stale in the
   narrow direction:** a per-ref lineage IS a parent-linked chain; what
   is missing is a merge NODE, not parentage. The common base is
   recoverable with no new metadata: the greatest position at which two
   lineages share an entry hash.
4. **A replica structurally cannot append to an origin stream** — three
   independent grounds (declared single-writer exclusivity; re-append
   assigns new seq/ts/prev-hash so the entry hash cannot survive; the
   #521 sequencer deferral).
5. `cx:merge` is spec'd, unimplemented, and its error-on-conflict
   posture (raise) predates the conflicts-as-values mandate (#719).
6. Replication is Phase-3+/#521-deferred everywhere it appears; the
   nearest live prior art is vc.md 3b's federation journal-sync claim —
   which this stream makes true.

## §2. The architecture (L173)

**Offline writes land in replica-local streams; sync is ingestion of
disjoint aggregates plus per-ref reconciliation.** Ingestion requires no
ordering decision — tenant state is the order-independent composition of
per-stream folds, so a new stream joins by composition; entry hashes are
byte-preserved (object transfer); chains verify unchanged; attribution
survives. Re-appending replica entries into origin streams is REFUSED on
the record (the three grounds above). Ref reconciliation runs per-ref
under `expect-pos` CAS (CXER1114, the ONE vocabulary), batch semantics
inheriting validate-then-apply all-or-nothing.

## §3. Causal history: merge-as-an-entry (L174)

The lineage stays LINEAR; **a reconciliation is an ordinary ref advance
whose payload records the join** — both parent tips and the base, as
locator triples (`stream`,`seq`,`hash` — the #717 rule). This satisfies
the no-commit-object sentence literally while making the join fully
recorded, hashed, and inspectable. store.md §6.3's sentence is amended
to the narrower truth (parentage exists via E3; the merge NODE is what
the model declines to keep). The commit-graph/DAG alternative is
REFUSED with trade-offs on the record (it reopens compaction, retention,
verify density, and the identity story for a structure the merge-entry
makes unnecessary). The **common base rule is normative**: greatest
position at which both lineages record the same entry hash.
`:causal` does NOT become a consistency token (the closed-set ruling
stands — this stream builds causal history, not a causal-consistency
claim).

## §4. The conflict value (L175 — the ONE shape, unified with stream 10)

```
[conflict subject="order:o-5521" kind=:diverged-advance
  [base   position=14 hash="sha2-256:…"]
  [ours   position=17 hash="…" [diff [change …]…]]
  [theirs position=16 hash="…" [diff [change …]…]]
  [cas code=CXER1114 expect-pos=14 actual-pos=16]]
```

Assembled entirely from live precedents: the `[conflict]` element + the
**enforcing/reporting agreement law** (sync raises iff sync-report says
`ok=false`); `ours`/`theirs` carrying navigable, patchable
`[diff [change …]]` payloads against the base (`patch(base, ours-diff)
≡ ours` — the shipped law); the CAS coordinates carried AS DATA (never
a second dialect); finding-not-fault. **This is THE conflict shape** —
stream 10's saga case adopts the same slots (`subject`/`kind`/`base`/
`ours`/`theirs` + a `policy` or `cas` child); the cross-stream-
coordination spec's sketch is amended to it (one shape, two consumers,
co-owned as both S4 specs intended). **Conflicts are Ring-0 values**
(parse, canonicalize, hash, navigate, patch in a `data`-profile build);
**sync is a Ring-2 effect** — that split is what makes
conflicts-are-data true in the strong sense. Resolutions re-enter as an
input table on a later sync — pure, replayable, deterministic
(identical input + identical resolutions ⇒ identical end state).

## §5. Sync surface (L176) and retention (L177)

- **v1 is bidirectional replica↔origin** (M5 needs both directions;
  both engines ship). N replicas are structurally admitted on the entry
  plane (disjoint streams compose); ref reconciliation is spec'd
  pairwise, with N-way named additive behind demand. Replica↔replica
  peering is named additive (no consumer). The `pull`≡`fetch` debt is
  discharged: **fetch = objects + doc-refs only; pull = fetch + ref
  reconciliation.** Sync results are head-set-bearing reports, never
  bare counters.
- **Retention (L177):** a replica MAY register at the origin (buying
  the retention hold under the extended cover rule, at the cost of
  origin-side per-replica state) or stay client-anchored (cheap; a
  cursor below the origin's compacted boundary gets the loud
  `:gapless`-class refusal and re-seeds — never silently). Both are
  spec'd; the deployment chooses. **`status` implements the spec'd
  ahead/behind as a per-stream HEAD-SET** (a staleness scalar is ruled
  insufficient). The replica id does NOT enter the hashed `stream`
  field as topology — stream keys name aggregates; replica provenance
  rides the envelope's actor/authority and Lane-2 claims, so re-homing
  a replica never changes entry identity.

## §6. Requirements on stream 4, filed formally (L178)

Ref-advance notifications carry **E3 positions** (ahead/behind is
computable, not inferred); the object wire (`objects-have/get/put`,
`refs`) is a first-class profile op family with its own spec section;
the profile handshake advert carries the **signed head-set coordinate +
the guarantee set**, generation-bound; batch ref-set =
validate-then-apply all-or-nothing. (Discharge CORRECTED 2026-08-05,
audit C6: the original "(discharged by the stream-4 spec's §4–§5)"
parenthetical was false — two of the four requirements appeared nowhere
in that spec. NOW discharged for real: the stream-4 spec's §7a carries
the object-wire op family AND the generation-bound signed-head-set +
guarantee-set advert — the latter simultaneously satisfying stream 7's
F3 MUST, which had been dangling from both sides; E3-position
notifications and all-or-nothing batch ref-set live in §4/§5/§7a.)

**Replica declaration profile — ADOPTED (audit M8; previously stream
7's §8 handoff had no receiving text here):** a replica surface
declares from the consistency vocabulary exactly per stream 7's replica
profile — it CAN declare `:prefix-consistent` (chain-checkable),
`:at-seq-pinned` up to its synced head, and `:monotonic-reads`; it
**MUST refuse `:read-your-writes` and `:linearizable-ref`** (offline
ref advance is precisely where this spec's conflict values land); and
it MUST advertise its signed head-set and per-stream ahead/behind
through status. These are wiring-time refusals on the declaration
floor, not runtime surprises.

**Shred reach to replicas — RECEIVED (stream 20's handoff, #692; the
joint requirement its §11 files here):** destroying a subject's SEK at
the origin does not reach replicas — plaintext a replica already holds
is outside the origin's key custody. A shred therefore propagates as
**journal data on the same feed a revocation rides**: the journaled
shred-request (the reserved `cx:erasure` stream) replicates like any
entry, and the store-profile feed already carries the attributed
`[erase plane=docs …]` act (stream 4's spec, §7b). On ingesting a
shred record, a replica executes its **own local shred walk** and
emits its own balanced shred report (the erasure spec's §9 shape);
ingestion is idempotent under the record's (subject, request-token)
dedup key, and fleet-wide completion is the collection of per-replica
reports — never an origin-side assumption. Until the sync engines
implement that consumption, custody holds the line the store spec
already enforces: subject-keyed docs do not ride the transfer verbs
(`push` refuses `CXER1144`), so no replica can hold subject plaintext
a shred cannot reach. Erasure spanning multiple origin stores remains
stream 10's saga vocabulary, not a replication concern.

## §7. Corpus handoff (stream 14; M5 substrate; L180)

Seed round-trip + tampered-anchor negative (CXER4615); the mandated
VT-precedes-TX sync fixture with all four quadrants; the ref
reconciliation discriminator pair (fast-forward applies / diverged
returns the conflict value and applies nothing — partial success
reported, never mixed silently); conflict-value round-trip
(parse/canonicalize/hash/navigate + the patch law); the
enforcing/reporting agreement law; the replica declaration-profile
pairs (refusals name token+surface+actual set); the head-set
ahead/behind advert (before/after sync differs by exactly the
transferred set); the retention wall refusal; replica-stream ingestion
(hash byte-identity + tenant-fold order-independence pinned);
idempotent re-sync (nothing new, no second conflict); resolution-resume
determinism.

## §8. Rulings ledger — RULED

Letters 173–180 **ruled (a) 2026-08-05 under the standing acceptance
ruling** (each verified against the long-term-best bar; two
cross-spec corrections applied: the conflict shape UNIFIED with stream
10's — ours/theirs slots, one vocabulary; the band moved to
**CXER5050–5069** since the sweep's 4950–4969 proposal was allocated to
stream 10 in the same wave): replica-local streams + ingestion + CAS
reconciliation, re-append refused on three grounds (173);
merge-as-an-entry, the DAG refused with trade-offs, the common-base
rule (174); the ONE Ring-0 conflict value + agreement law + resume
seam (175); bidirectional v1, pairwise reconciliation, fetch/pull
split, additive N-way and peering (176); register-or-refuse retention
+ head-set status + no-topology-in-stream-keys (177); the stream-4
requirements discharged in-wave (178); Ring/naming/band (179); the
corpus program + the demo one-liner (180). Recorded in the campaign
decision log. Spec-edit map: store.md (§6.3 porcelain semantics,
status head-sets, the amended merge sentence), journal.md (ingestion
§, stream-key naming note), cross_stream_coordination.md §4 (the
unified conflict shape — applied), modules/cx.md (cx:merge's conflict
posture aligned to values, #719), consistency/live/bitemporal
cross-refs, stream-20 handoff (shredding a replicated subject reaches
replicas via the same feed).

## Identity-epoch membership (audit C9)

**ADDITIVE — this stream owns no I1 manifest row and joins no epoch.**
Replication consumes the I1-frozen entry/snapshot preimages UNCHANGED:
objects and entries transfer byte-identical because content addressing
already holds; re-append deliberately assigns new seq/ts/prev-hash (an
entry hash MUST NOT survive re-append — that is the design, not a
migration); head-sets, sync reports, and `[conflict]` values are new
value shapes. This stream adds NO entry form (stream 20's
detached-payload form rode I1; stream 21's reserved `fold-id?` slot
fills with no new epoch) and touches no Tier-1/Tier-2 spelling.
