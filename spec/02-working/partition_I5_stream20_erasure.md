# I5 stream 20 — erasure & compliance: implementation ledger

**Status:** OPEN (started 2026-08-12; order-of-march item 5 continuation,
stream #692 per the stream-21 exit handoff).
Branch `impl/I5-stream20-erasure` off `design/651-516-partition`
(cut at ffb7dadc — the stream-21 exit-merge).
Governing spec: `erasure_compliance.md` — letters **L181–L189 inside the
S4 batch RULED (a) 2026-08-05 (letters 155–189)**.
RULED-token anchors = the S4 exit row in `partition_campaign_PLAN.md`
(decision log 2026-08-05, "WAVE S4 EXITED — letters 155–189 ruled (a)"),
stream-20 fragment: "three-tier key hierarchy KEK→SEK (destroyable)→DEK;
address covers PLAINTEXT — ciphertext-address & hash-salting both
rejected, the oracle neutralized by per-record nonce + pool isolation;
the detached-payload entry form is the sole I1 hash-affecting item —
verify valid=true with payloads gone; typed [erased] tombstone on the
value channel; exhaustive derived-artifact reach via stream-21 fold-id
shred-generations; legal hold = an enforced Lane-2 precondition blocking
shred AND re-snapshot; the visible-count rule generalized here". The
spec's own §12 rulings ledger records 181–189 with the spec-edit map as
part of the ruled text.
Issues: #692 (stream); #720 rides (the evidence-sweep register — five
items); **#779 rides (prio:high rotation-vs-fold race — pinned here by
stream 1 because the KEK-rotation walk is this stream's surface; owner
policy: prio:high fixed ASAP, W1)**.

**Epoch posture:** POST-I1 ADDITIVE with the ONE I1 item ALREADY
EXECUTED — the detached-payload entry form (L184, I1 manifest row 11 /
#720) shipped at I1: verified in-tree at journal.md §2.2 (the
`entry-canonical` preimage carries `payload=<tagged-address>`; payload
stored as its own doc in the same group-commit scope; rotation carries
payload docs; an already-shredded payload copies nothing) and
implemented at `vcx/platform/stdlib_journal.v` (`jrn_canonical_bytes`
takes `payload_addr`; `jrn_store_put_doc_err` detaches on append). No
canonical-byte changes remain in this stream. One item is
**I5-STRUCTURAL, not additive (audit M32):** the SEK tier is a
keying-backend refactor — shipped `encryption.v` is two-tier KEK→DEK
with one-backend-per-key_id; inserting the destroyable middle tier means
key-id → (KEK, SEK, DEK) resolution with SEK-absence as the fail-closed
shred signal. Everything else is additive: reserved payload vocabulary
(`subject=`/`nonce=`), tombstone reads, the `verify` reconciliation
axis, legal-hold Lane-2 claims, the shred report, fold-id
shred-generations (stream 21's fold-id shipped at ffb7dadc), error rows
in the registered journal `4619–4639` + store `1144–1149` bands
(registry repair executed 2026-08-05; slice re-corrected at W2 —
`4617`/`4618` were consumed by U1 delivery + stream 8 after the S4
ruling; journal.md §8 records the operative slice).

## Binding inputs — verified shipped at branch cut

- **Stream 8 redaction posture:** journal §2.9 valid-time vocabulary +
  the `journal-116-redaction-visibility` fixture (real shred:
  pass-through unjudged, `erased=1 checked=1`, chain `valid=true`) —
  the L119 precedent this stream generalizes (§6).
- **Stream 21 fold-id:** fold-id-carrying snapshots + CXER4640 +
  covered-under-the-CURRENT-fold retention (exit-merge ffb7dadc) — the
  §7 shred-generation mechanism composes on it with no new
  invalidation machinery. The shredded-payload fold outcome = a
  REDACTION FINDING with a visible count (a missing upcaster is a
  fault; a lawful shred is a finding — §11).
- **Detached-payload entry form:** executed at I1 (above).
- **Shipped crypto:** `encryption.v` KEK→DEK envelope encryption keyed
  by PLAINTEXT hash; `rotate_kek` (encryption.v:487) = the re-wrap
  primitive the spec names as the SEK-rotation primitive; `LocalKms` =
  the reference KMS (destruction = key removal, fail-closed unwrap).
- **#779 surface mapped:** `objectstore_pack.v` — `fold_commit` (:578,
  lock held, generation check) vs `write_compacted` (:649 `b.segs = []`)
  / `write_compacted_keyed` (:696) / load paths (:760, :820). Suspects
  per the issue: a segment-set-replacing path reaching the backend
  without the fold worker's op-lock identity (or a second handle under
  a different lock identity, cf. the #628 same-root rule).

## Standing constraints

- Spec-first; NO spec edits without a recorded ruling (RULED: tokens on
  spec+impl commits; fragments must grep in `partition_*.md`). The §12
  spec-edit map of `erasure_compliance.md` IS ruled — each executed edit
  cites its letter: store.md §9 (SEK tier, shred verbs, get-doc
  tombstone), journal.md §2.2/§4.2 (VERIFIED EXECUTED at I1), §2.8/§4.9
  (shred reach + fold-id generations), §3.6 (`verify` reconciliation
  axis), cxdm §12 (tombstone-vs-secret distinction), authz/vc
  (legal-hold claim), governance §9.6 (band rows as codes land — the
  repair itself executed 2026-08-05), cx_partition §8 (erasure in the
  archival/compatibility promise), streams 4/9/10/21 handoff texts.
- Fixture-first every wave; user-domain error codes in fixtures are
  NON-CXER strings (the registry gate strict-fails unregistered
  CXER-shaped tokens).
- Every wave ends green on the full gate — `make test` UNPIPED, full
  log, `GATE-RC=$?` propagated, verdict read FROM the log, PRE/POST
  HEAD guards; probe reflog+status before every git mutation
  (shared-checkout rule); explicit-path staging only; NEVER edit
  runtime-read files mid-gate.
- Wipe `/tmp/v_501` + `/tmp/cxc*` before gates when fresh symbols
  landed (#572 stale-layer class); classified #572 retries only.
- cxparse_full_corpus_diff baseline moves with EVERY in-cx fixture, in
  the SAME commit, plus the regenerated
  `_gate_evidence/cxparse_headline_rebless_scope.md`.
- `[$count $b/path]` inline answers 0 — bind first; `?if` takes
  [then]/[else] wrappers; no deferrals without named landings;
  sanitized labeled issues; push per landing; never main.

## Wave plan (refined at each wave open; dependency-ordered)

- **W1 — #779 (prio:high, ASAP per owner policy):** deterministic repro
  first (delay hook between fold_commit's scan and its assignment),
  then the fix: every segment-set-replacing path (compaction, rotation
  rewrite, reload) takes the SAME op-lock instance the fold worker
  holds — or the set-replacement moves behind the backend's own mutex
  so gen-check→mutate is atomic against fold_commit. The KEK-rotation
  walk this stream ships must not build on a racy substrate.
- **W2 — the SEK tier + subject vocabulary (L181/L182/L183, §2+§3+§4+§9
  custody; MERGED at wave open 2026-08-12 from the original W2+W3 —
  the live-consumer rule: SEK create/destroy and seal-under-named-key
  would otherwise ship as dormant seams until the subject= write path
  consumes them):** keying-backend refactor — key-id → (KEK, SEK, DEK)
  resolution; SEK-absence = fail-closed; SEKs KMS-resident as
  `sek/<tenant>/<subject-token>` (opaque CSPRNG token, never the
  subject id); `envelope_open` gains the fail-closed `unavailable`
  discrimination now (absent-key vs auth-fail; the `shredded`
  classification lands with the journaled shred-request it is evidenced
  from — the erase wave; never key-absence-derived, audit M33).
  `subject=`/`nonce=` reserved payload attributes; CXER4619
  E_ERASURE_NONCE_REQUIRED refusal (first FREE code of the slice —
  `4617`/`4618` were consumed by U1 delivery + stream 8 after the S4
  ruling; the spec's premise corrected in place with a dated bracket,
  the registry-repair precedent; journal.md §8 row rides the same
  commit); weak-nonce NEGATIVE witnesses (no-nonce
  refusal; derived/short nonce rejection — dedup/parity witnesses alone
  pass for `nonce=1`, the C7 trap); ≥128-bit CSPRNG; nonce inside the
  sealed payload only; address-parity + nonced-dedup-loss witnesses.
  **Wave-open design decisions (inside ruled bounds):**
  - **Rotation×SEK interaction (found at wave open — a compliance hole
    if unhandled):** the shipped KEK-rotation walk re-wraps EVERY
    envelope to the new tenant key; once SEK-wrapped envelopes exist
    that would move subject payloads back under the tenant KEK and
    defeat crypto-shredding. Ruled basis: §2 "the re-wrap primitive
    from rotation IS the SEK-rotation primitive" + §10 "KEK rotation
    over a store with shredded subjects keeps the report balanced".
    Design: envelopes whose recorded key-id is `sek/…` are OUT OF SCOPE
    for tenant rotation (their wrapping key is the SEK — carried
    verbatim, visible `subject-keyed=` count); the SEK KEY MATERIAL
    (KEK-wrapped) re-wraps under the new KEK via the same rewrap
    kernel; a destroyed-SEK envelope also carries verbatim (the shred
    survives rotation); the §9.1 balanced account extends.
  - **Reference SEK custody:** durable KEK-wrapped SEK blobs in a
    store-root `keys/` sidecar (EnvKms layer); create = CSPRNG 32B
    wrapped under the tenant KEK; destroy = file removal, after which
    unwrap fails closed by construction (§2/§9); `sek/` ids NEVER
    lazy-mint (an ephemeral re-mint would misreport absence as
    auth-fail). Production supplies a real KMS through the same seam.
  - **subject→token mapping** = a manifest-level tenant-scoped record
    (consistent with the shipped plaintext refs/aliases posture —
    content seals, names don't); removed by the shred walk (the erase
    wave); post-shred the substrate names the subject only from the
    journaled shred-request (§4's stated design).
  - **CXER4617 raised from BOTH write surfaces** (journal append +
    store put-doc of a subject-bearing doc) — the stream-7 precedent
    (CXER4990 consistency codes raise from store verbs); band 4617–4639
    already registered as a §9.6 range (2026-08-05 repair).
- **W3 — legal hold (L188, §8):** signed Lane-2 `[legal-hold]` claim;
  per-tenant hold-stream (a hold binds from its journaled position
  onward); the `[requires-at]` head pin + commit-lock re-check;
  unsigned → fail-closed. Lands BEFORE the command so the shred
  precondition is never a partial impl.
- **W4 — erase-subject + the shred walk (L184 remainder/L187/L181
  completion, §7):** the recorded command (stream-6 mechanics:
  `[effects]` checked-and-enforced, `[idempotent]` w/ the exempt
  opaque-token dedup record — audit M31 carve-out; shred reach beats
  retention for every OTHER dedup record); head-set scope; hold
  precondition enforced (pin + re-check; blocks shred AND re-snapshot);
  KMS destroy strictly POST-COMMIT (the forward-only pivot); the
  enumerated derived-artifact walk (snapshots via fold-id
  shred-generation in the ENV quadrant, compacted segments, rotation
  targets + index, archived predecessors, `archive=` stores,
  materializations + checkpoints, columnar `__cx_doc`, stream-5 visible
  cache, stream-6 dedup records, replay tapes); the §9.1-shaped
  balanced shred report; `envelope_open`'s `shredded` finding evidenced
  from the journaled record (M29 read-time reconciliation).
  **Wave-open design decisions (2026-08-12, inside ruled bounds):**
  - **Surface:** `[$journal:erase-subject $j $subject $attribution
    $opts?]` — journal-level (the journal is the system of record; the
    walk covers the backing store + every store the segment index
    names). Attribution requires actor+authority (the append rule —
    authority journaled). `opts.request` may name the shred-request id
    explicitly (the xsp erase `request=` precedent; fixtures need the
    determinism); the DEFAULT mints the opaque 128-bit CSPRNG token.
  - **The reserved record stream `cx:erasure`:** the shred-request
    journals as an `[erase-subject [subject] [request] [sek]?
    [holds-head] [generation] [head-set …] [docs …] [report …]]` record
    on a reserved per-tenant stream; DIRECT appends refuse `CXER4622
    E_ERASURE_RECORD_RESERVED` (a forgeable erasure record would poison
    M29 read-time reconciliation and W5 verify) — the write-time §2.11
    posture spent again. The record payload names the subject via a
    CHILD element, never the reserved `subject=` root attr (the record
    must not itself demand a nonce + SEK seal).
  - **M31 discharged by construction:** the eval-layer `[idempotent]`
    clause is deliberately NOT used — its derived key
    (tier2‖tenant‖args) is subject-derivable, the exact digest oracle
    M31 forbids, and its registry is in-process only. The journaled
    record IS the durable dedup record: replay detection scans the
    reserved stream for the subject (records are seq-keyed journal
    entries — no subject-keyed digest namespace exists anywhere); the
    opaque token is the `request=` id. Replay returns
    `[deduped [shred-report …]]` (stream-6 R13 present-value shape)
    AND re-runs the idempotent walk (self-heal: a crashed walk —
    committed record, incomplete walk — completes on replay; destroy
    of an absent key and re-erase of a tombstoned doc are no-ops,
    never a second destructive act).
  - **Hold precondition = pin + re-check on ONE lock:** the unlocked
    precondition pass loads holds (subject-scoped match on $subject;
    hash-scoped match against the enumerated doc set) and pins head H1;
    then the store op-lock is taken FOR THE WHOLE COMMAND (the W1 #779
    posture) — under it the hold head re-reads, entries H1+1..H2
    re-validate, a binding hold refuses `CXER4621 E_ERASURE_HELD`
    naming hold seq/signer/scope. All journal appends serialize on this
    same lock (#628), so no hold can land between re-check and commit —
    the lock IS the writing commit lock. Refusal is atomic: the
    generation never advances, no re-snapshot is forced (the §8 "blocks
    shred AND re-snapshot" suspension is structural, not a second
    check).
  - **Atomic record + generation:** the erase entry append and the
    per-tenant shred-generation advance
    (`cx-journal/shred-generation/<tenant>` meta alias) share one outer
    flush-hold scope (#614 group-commit; the counter nests).
    `[$journal:shred-generation $j]` reads it — the ENV-quadrant input
    callers bind into their fold identity (cx:env itself stays a build
    constant; the generation is tenant state, so it rides the journal,
    and the CXER4640 staleness machinery consumes it unchanged — no new
    invalidation machinery).
  - **KMS destroy strictly POST-COMMIT:** after the record is durable,
    the walk runs: per-store `store_erase_subject_walk` (SEK lookup
    WITHOUT create; enumerate sek-wrapped envelopes — durable keys +
    staged seal-overrides; tombstone each doc via the §7b.1 funnel with
    T+E records; destroy the store's SEK blob + remove the
    `keys/subjects/` mapping; purge in-process plaintext: pc_reclaim
    after persist — tombstone objects flush first, then the rebuilt
    sink drops shredded plaintext — plus targeted `obj_cache` eviction,
    the W2 carried note). Each predecessor/archive store seals under
    ITS OWN sidecar SEK (rotation re-puts payload docs through the
    subject arm), so the walk destroys each store's key.
  - **Predecessor + archive reach via a TRUTHFUL segment index:**
    `fs_retention_dispose` now records its disposition on the segment
    record (`archived-to=<url>` after a clone; `disposed=true` after an
    `archive="none"` drop) — the index the walk follows; a non-disposed
    segment store that fails to open is a LOUD walk error (missing an
    enumerated surface is a compliance failure), a disposed one is
    reported visibly. The `store_erasure_transfer_guard` is REMOVED and
    clone/migrate carry the erased map (E records — attribution
    survives archival), the removal its own comment names stream 20
    for.
  - **Derived surfaces in each walked store:** `computation/` aliases
    whose record doc references a scoped address or the subject id →
    record + result docs erased, alias dropped (cache-cold is safe);
    `cx-live/materialization/` aliases whose target is a `[checkpoint]`
    doc → checkpoint erased + alias dropped (derived-state posture:
    loss = full replay; `[live-materialization]` REGISTRATION markers
    are untouched — no payload rows, and retention-cover extension
    depends on them); the in-process stream-6 dedup registry purges
    records whose rendered outcome references the subject or a scoped
    address (selective — the M31 exempt record lives in the journal,
    not here; reached via the env dispatch hook). Columnar `__cx_doc` =
    N/A by construction (subject puts refuse CXER1144 on
    plaintext/non-objgraph substrates — recorded, not walked); replay
    tapes = discharged by construction (computation-record inputs,
    L107) — no shipped surface.
  - **M29 read classification `CXER1145 E_STORE_SHREDDED`:** the
    whole-doc read fallback, on an unwrap that probes key-ABSENT,
    reconciles against the journaled erasure records in the same store
    (the `cx:erasure` entry pointers): covered → the typed shredded
    finding naming `request=`; uncovered → fail-closed unavailable
    (W5's `unattributed-missing` feeds on the same discrimination). The
    store band's second code (1144 spent at W2).
  - **Fixture split (the W2 pattern):** journal-129 covers the
    mem-expressible command surface byte-exact (hold-blocked refusal
    CXER4621 + no generation advance; zero-doc erase report; deduped
    replay; reserved-stream refusal CXER4622; shred-generation +
    CXER4640 staleness); the custody-deep walk (SEK destroy, envelope
    enumeration, predecessors/archives, sink/cache purge, clone
    carriage, CXER1145) = V tests (store/journal layers).
- **W5 — read surfaces + verify reconciliation (L185/L186, §6):** typed
  `[erased subject? at= authority= actor= shred-request=]` tombstone on
  the value channel; `get-doc` three-way (never-existed CXER1121 /
  unreconstructable CXER1120 / lawfully-erased `[erased]` — #720 item
  1; `get-doc-text` inconsistency resolved); `verify` reconciliation:
  `redacted=N unattributed-missing=K`, any K>0 LOUD; the negative
  fixture (payload destroyed with no shred-request →
  `unattributed-missing=1`); visible-count generalization
  cross-references (streams 3/21 per audit M7).
- **W6 — hygiene + exit:** §12 edit-map residue (store.md §9, cxdm §12,
  cx_partition §8, handoff texts 4/9/10/21); #720 all-items closure
  evidence; #692 closure; unnonced-legacy remedy text verified
  (re-write-with-nonce before shred / documented residual-risk); M5
  `o-5521` end-to-end fixture; exit audit + full gate.

Named landings (ruled, not deferrals): replica shred-reach = stream 9
joint requirement, FILED not solved here (§9); cross-stream erasure =
stream 10's saga/escrow vocabulary (§11); M5 corpus families = stream
14 substrate (§10); erasure never spec'd onto the retiring CSRP plane
(stream 4, §11).

## Wave record

- **W1 EXECUTED 2026-08-12 — #779 root-fixed @ 0c024d5f.** Root cause:
  the eval path's dispatch funnel locks around
  `store_stdlib_builtin_inner`, but `svc_rotate_kek` (the
  `cx store-rotate-kek` CLI wrapper) and the daemon call the INNER
  dispatch directly — the whole rotation walk ran UNLOCKED there; its
  own `store_persist` kicks the background fold worker, and the
  unlocked `write_compacted_keyed` (b.segs reset + gen bump) could land
  inside the worker's LOCKED `fold_commit` between the position scan
  and the `b.segs[lo_pos]` install — the observed `array.set (0,0)`
  panic. Fix: `store_lock_enter/exit` in `store_rotate_kek` itself
  (re-enters via the #628 owner-tid bookkeeping on the already-locked
  eval path; acquires on the direct-inner paths; covers all four
  substrates + the walk's read snapshot). Regression guard FIRST:
  `test_rotation_cxpack_vs_background_fold_worker_779` (24-round
  rotate-vs-fold-kick storm through the exact pre-fix unlocked path;
  pre-fix window µs-narrow — 4 pre-fix runs green, fired once across
  many parallel gates; post-fix closed by construction). Gate:
  `s20_w1_gate2.log` GATE-RC=0, PRE/POST HEAD = 0c024d5f, 0 dirty
  (first run `s20_w1_gate.log` GATE-RC=2 — the fabric credit/resume
  lane blew its 5s frame-read deadline because the retry ran while
  parallel lanes were still executing; green standalone at HEAD +
  green with the quiet-tree gate's classified retries). #779 CLOSABLE
  at stream exit (evidence recorded here).
- **W2 EXECUTED 2026-08-12 — the SEK tier + subject vocabulary
  @ 98416168 (+ W2.1 @ 166ffad2).** Everything the wave-plan entry
  names landed: the three-tier keying (Kms `create/destroy/has_key`;
  `sek/` ids never lazy-mint; EnvKms durable sidecar custody — KEK-
  wrapped SEK blobs + the subject→full-sek-id mapping under the store
  root `keys/`, atomic fsynced, destroy = removal, fail-closed); the
  typed unavailable-vs-tampered discrimination (audit M33; #720 item 2
  first half); the subject write path (whole-doc sealed object, self-
  identifying root key == doc hash, address parity, dedup lost only
  for nonced records; CXER4619 nonce discipline at store arm + journal
  coordinate check; CXER1144 custody fail-closed); rotation×SEK closed
  on all four walks (verbatim carry + `subject-keyed=`/`subject-keys=`
  balanced report; the shred survives rotation); read-path whole-doc
  branches (doc-text, eager verify ×2, porcelain). **Code correction:**
  E_ERASURE_NONCE_REQUIRED = CXER4619 (the ruled 4617 premise went
  stale — 4617 U1 resume-gap + 4618 stream-8 temporal-invalid shipped
  post-S4; dated brackets in erasure_compliance §3/§9; journal.md §8
  was already correct). Spec edits per the ruled §12 map: journal.md
  §2.11 + §8 row; store.md §9.2 + §9.1 report + §13 CXER1144 row.
  Tests both layers + fixtures journal-127, store-subject-001..004
  (corpus baseline unchanged — `[empty]` in-cx). **W2.1 (the #779
  class, second instance, caught by this wave's own first gate):**
  orphaned fold worker vs same-root reopen — close cannot join the
  worker (op-lock inversion), so the fix is a per-root active-worker
  registry (own mutex) + open-time quiescence for FRESH instances;
  shared opens never wait. Plus the missed s3-test `store_kek_kms`
  call sites. Gate: `s20_w2_gate2.log` GATE-RC=0, PRE/POST HEAD =
  166ffad2, 0 dirty (first run `s20_w2_gate.log` GATE-RC=2 = the two
  real W2.1 items + the classified fabric/http pair). Carried notes
  for W4: the erase walk purges IN-PROCESS plaintext (obj_sink +
  obj_cache) per §7 reach; eager verify of a shredded payload must
  become a finding-not-fault when reconciled (W5); objwire client
  reconstruct of whole-doc subject docs = stream-4 joint surface.
- **W4 EXECUTED 2026-08-12 — erase-subject + the shred walk @ 0c942eb5
  (+ W4.1 @ fc90f98a). Gate `s20_w4_gate2.log` GATE-RC=0, PRE/POST HEAD =
  fc90f98a, 0 dirty** (first run `s20_w4_gate.log` GATE-RC=2: the one real
  miss = the columnar suite's own S3 stub lacking the new
  `S3Transport.remove` — the `-d cxstore_columnar` gated-lane class, W2.1's
  pattern; fixed as W4.1 — plus the classified fabric/http #572 cache-free
  retry pair, green on retry in gate 2: "every failed lane green on its
  classified retry"). Everything the wave-open design names landed:
  `[$journal:erase-subject]` (env-dispatched — it reaches the in-process
  dedup registry) + `[$journal:shred-generation]` + the internal
  `journal-segment-disposed`; the reserved `cx:erasure` stream with
  write-time CXER4622; CXER4621 hold refusals at pin AND commit-lock
  re-check (atomic — no record, no generation advance); the record+
  generation group-commit; the strictly-post-commit walk
  (store_erase_subject_walk per store: scope by recorded key-id + staged
  seal overrides, §7b.1 tombstones w/ T+E, SEK destroy + subject unmap,
  computation/checkpoint sweeps w/ registration markers untouched,
  obj_cache eviction + pc_reclaim after persist, durable residue purge);
  segment-index reach (predecessors + archived-to=) with the EMPTY-open
  fail-closed guard (file:// creates on open — a missing predecessor must
  never read as clean); fs_retention_dispose records dispositions;
  clone/migrate custody carry + erased-map carriage (the R3.16 interim
  guard REMOVED as its own comment promised; push refuses CXER1144);
  migrate routes subject docs through the subject arm; CXER1145
  E_STORE_SHREDDED at the whole-doc read fallback (M29: evidenced from the
  journaled record, never key absence). **Design decisions beyond the
  wave-open notes (inside ruled bounds):**
  - **Dedup keys on (subject, request-token), not subject alone** — a
    subject's first record must never absorb every later RTBF act
    (re-landed data stays erasable; a subject-only match would BE the
    subject-keyed forever-record M31 forbids). Resubmission = same token →
    `[deduped <recorded report>]` + the idempotent self-heal walk; new
    token = new command.
  - **The durable residue purge** (pack survivors-fold / cxobj unlink /
    sqlite DELETE / s3 keyed DELETE via the new S3Transport.remove):
    found by the re-landed-data test — a re-put at the same address
    content-dedups against the STALE envelope under the destroyed SEK
    (wrapper has_object short-circuit), so the supersede silently broke
    across restart. Physical purge closes the class; crypto-shred remains
    the erasure mechanism (the purge is residue hygiene, zero writes to
    sealed bytes it keeps).
  - **CXER1145's positive case** = restored-from-backup (objects restored
    separately from the KMS) or a crashed walk: envelope present, key
    absent, record covers → typed + attributed. No covering record →
    fail-closed unavailable (W5's unattributed-missing feeds here).
  Fixtures journal-129 (the mem-expressible command surface, byte-exact:
  CXER4621 + no generation advance; zero-doc balanced report; deduped
  replay; CXER4622; CXER4640 staleness via generation-composed fold-ids),
  journal-130 (shred-generation), journal-131 (the stream-6 dedup purge:
  purged=1, replay re-executes — the §7-accepted consequence, visible);
  V tests (store_subject_test.v): the full cxpack walk (derived sweeps,
  cache+sink purge, sidecar removal, re-land + second erase, CXER1145),
  predecessor+archive reach (3 stores, 3 SEKs destroyed), disposed vs
  unreachable segments (loud vs visible), transfer custody+carriage
  (clone/migrate/push × encrypted/plaintext); the old interim-guard tests
  flipped to pin carriage. fn-docs verbatim ×2; guide-check OK 46.
  **Found in passing:** W2's `store_kek_kms(…, os.dir(ms.root))` call in
  the cxstore_sqlite-gated file lacked `import os` — every
  `-d cxstore_sqlite` platform compile broken since 98416168 (the gated
  -d-file class, third instance; one-line fix rides this wave). **Filed
  #785:** rotate/compact targets open with no at-rest options — an
  encrypted journal cannot rotate (found composing predecessor reach; the
  erase walk already passes encrypt-key-id to segment opens, so it is
  unaffected when #785 lands). Named landings unchanged: replica reach =
  stream 9; wire custody = streams 4/9 (push refusal + CXER1144 posture
  hold the line meanwhile).
- **W5 EXECUTED 2026-08-12 — read surfaces + verify reconciliation
  @ bdd3026b (+ W5.1 @ a642a0ad). Gate `s20_w5_gate3.log` GATE-RC=0,
  PRE/POST HEAD = a642a0ad, 0 dirty** (gate 1 `s20_w5_gate.log` RC=2:
  the one real miss = the wire-feed erase act losing `request=` — W5.1;
  gate 2 `s20_w5_gate2.log` RC=2 = the spec-freeze token missing from
  W5.1's own message, amended in place pre-push; gate 3 fails all
  classified — fabric/http #572 cache-free-retry pair + the known
  net_udp real-socket contention lane, every one green on its
  classified retry). Everything the wave-plan entry names landed:
  - **The §3.6 reconciliation axis** on `verify`/`verify-slice`
    (default + named streams): a VALID walk fetches + re-hashes every
    detached payload; each missing/rehash-failing payload reconciles
    against a covering `cx:erasure` record (`[docs]` scan) or the
    address's own tombstone → `redacted=N payloads-verified=M
    unattributed-missing=K`, any K>0 LOUD; attrs emitted only when
    N+K>0 (L119 posture) so every shipped verify fixture stayed
    byte-identical. Fixture journal-132 = §6's named negative corpus
    fixture (raw delete-doc → `unattributed-missing=1`, chain
    valid=true).
  - **Tombstone shape → the §6 ruled form** `[erased hash= root?= at=
    authority?= actor= shred-request=]` (request= renamed, order
    aligned; `subject` NEVER emitted — §4; hash/root lead as
    addressing mechanics). No reader of the old attr existed; the
    shred-REPORT's `request=` (W4-ruled §9.1 shape) and the wire ACT's
    `request=` (stream-4 §5.3 vocabulary) are distinct surfaces and
    keep their names — W5.1 maps tombstone `shred-request=` → act
    `request=` explicitly (the gate-found adjacent-wire-surface miss,
    the W2.1/W4.1 class: the act renders in the spawned daemon).
  - **Hydration polish (found in passing):** since W4 a tombstoned
    payload hydrated as `[event [erased …]]` (get-doc-text answers
    tombstone text), silently defeating event-less shred semantics —
    now the tombstone attaches as a DIRECT typed child
    (`jrn_tombstone_of`: rehash-mismatch AND name — either mark alone
    misclassifies); has-event stays false, coherence `erased=` and
    L119 pass-through unchanged, readers get the attribution.
  - **Finding-not-fault ×2 (the W2 carried note):** porcelain
    `store-verify` classifies a failed whole-doc open via the M29
    evidence scan — covered → `redacted=N` counted visibly
    (valid=true), uncovered → the typed unavailable fault naming the
    missing evidence; the EAGER load defers exactly the absent-`sek/`
    envelope class at the decrypt slurp (records replay AFTER the
    slurp — judging there is impossible; wrong-KEK/tampered stays the
    hard open error) and pass-2 reconciles: covered → the store OPENS
    (reads answer CXER1145), uncovered → the loud refusal.
  - **#720 item 1 = already-shipped evidence:** the get-doc three-way
    + get-doc-text verbatim tombstone parity were landed by W4
    (`test_local_get_doc_of_erased_answers_tombstone` pins all three
    ways + exists=false); W5 verified the shape against §6 and closed
    the spec residue (store.md §6.1 rows now document the three-way).
  - **M7 cross-refs executed** (the §6 CLAIM-CORRECTED reconciliation
    pass): live.md (02-working, the normative pack spec — the
    per-frame redaction-count sentence now cites the generalized
    visible-count rule + the store:log erase act as a delivered,
    attributed change); journal.md §3.9 shredded-pass-through bullet
    cites the generalization (lawful shred = finding; missing upcaster
    = fault). Stream 8 is the precedent's home and needs none (per the
    corrected claim).
  - V tests (store_subject_test.v): verify evidence path 1 (tombstone
    → redacted=1) and path 2 (record-covered, tombstone dropped →
    redacted=1, never unattributed); tombstone-as-direct-child
    hydration; §6 shape asserts (authority present, subject absent);
    porcelain verify redacted=1 on the restored-envelope construction;
    the durable eager construction (re-land under a fresh SEK + raw
    destroy; the address stays covered — content-addressed, the same
    address IS the plaintext the lawful record ordered destroyed) →
    eager open green + CXER1145 + verify redacted=1; the UNCOVERED
    counter-case (raw key destroy, no record) → store-verify CXER1120
    naming 'NO covering erasure record' + eager open REFUSES.
  Spec edits per the ruled §12 map: journal.md §3.6 axis block + §2.2
  read note; store.md §6.1 three-way rows + §9.2 tombstone shape +
  verify bullet; xsp_store_profile.md §7b tombstone line (W5.1).
  fn-docs: verify/verify-slice summaries carry the axis; guide-check
  OK 46; corpus-diff baseline unchanged ([empty] in-cx). Suites green
  standalone: fixture battery (+132, pre-existing byte-stable),
  journal/pack/store-core/misc umbrellas, rotation, s3
  subtree+encryption, subject+erase battery, store_remote (under the
  gate's exact flags).
- **W3 EXECUTED 2026-08-12 — legal holds @ aeca490f.** The signed
  Lane-2 `[legal-hold]` claim (scope = exactly one of subject/hash;
  detached ed25519 sig over the claim's strict canonical text sans
  [sig]; key→signer binding = authz/vc's domain per §2.6); the reserved
  per-tenant hold-stream `cx:legal-hold` (binds from journaled position
  — the honest rule); WRITE-TIME validation at append (CXER4620
  E_ERASURE_HOLD_INVALID — immutable entries, an unbindable hold must
  never be recorded) + the fail-closed `legal-holds` load (CXER4620
  naming seq, never a skip; returns holds + `head=` — the position
  W4's precondition pins; {subject:|hash:} filters). Fixture
  journal-128 FIRST (RFC 8032 vector-1 keys, deterministic ed25519;
  preimage parity `[$cx:canonical [$cx:serialize …]]` == V-side proved
  by verification passing); fn-doc verbatim; journal.md §2.11
  hold-stream bullet + §3.3 verb + §8 CXER4620 row. Gotcha recorded:
  store-rehydrated claims carry string items as TextNode (read both).
  Gate: `s20_w3_gate.log` GATE-RC=0, PRE/POST HEAD = aeca490f, 0 dirty
  (fabric/http classified retries only). Enforcement (hold-beats-shred,
  head pin + commit-lock re-check, blocking shred AND re-snapshot) =
  W4, with the erase-subject command it preconditions.
- **W6 EXECUTED 2026-08-12 — hygiene + exit.** The ruled §12 edit-map
  residue closed, the closure evidence assembled, the M5 end-to-end
  landed:
  - **cxdm §12.5** gains the tombstone-vs-secret decision bullet (the
    marker withholds a LIVE value's bytes at an output boundary; the
    tombstone records ATTRIBUTED at-rest destruction — never
    substitutable; #720 item 5's distinction stated in the marker's own
    spec).
  - **cx_partition §8** gains the erasure-inside-the-guarantee bullet
    (RTBF coexists with the archival promise by construction; chains
    verify with payloads lawfully gone; unauthorized deletion and
    lawful shred observationally distinct forever).
  - **governance §9.6 rows refreshed to shipped state:** store sparse
    list → 1140–1145 with 1144/1145 named shipped (1146–1149 remain
    reserved; the parser's sparse-scan semantics unchanged — reserved
    codes were already inside the scanned parenthetical); journal row
    amended — 4617 (U1) + 4618 (stream 8) shipped ahead of the stale
    reservation bracket, which now reads 4619–4639 with 4619–4622
    named shipped; 4640 named shipped (stream 21, 4641–4649 reserved).
  - **vc.md §9** gains the legal-hold receiving bullet (the edit map's
    unexecuted authz/vc row, found by this exit audit): key→signer
    binding for `[legal-hold]` claims is vc's §4 recovery model; an
    unbindable signer carries only raw key possession.
  - **Handoffs 4/9/10/21 disposed:** stream 4 = verified pre-carried
    (xsp_store_profile §7b/§7b.1 + the W5.1 act mapping: tombstone as
    distinct wire response, erase act carriage, replica posture, no
    CSRP); stream 9 = RECEIVING text authored in distributed_store.md
    (the shred-reach block: shred-requests as journal data on the same
    feed a revocation rides, per-replica walk + own §9-shaped report,
    (subject, request-token) idempotence, `push`-refuses-CXER1144
    line-hold, multi-store = stream 10's saga) + the joint requirement
    filed on #681 (comment); stream 10 = verified pre-carried
    (cross_stream_coordination's erasure step-class: one irreversible
    pivot, visible per-stream counts); stream 21 = verified landed at
    W5 (journal.md §3.9 finding-vs-fault + schema_event_evolution's M7
    visible-count cross-reference).
  - **Unnonced-legacy remedy VERIFIED (the §3 text vs shipped state):**
    both arms are mechanically real — re-write-with-nonce = a stream-8
    supersedes-correction re-landing through the subject arm, then both
    generations shredded (the record's `[docs]` scope + the doc-level
    erase funnel reach the unnonced generation); documented
    residual-risk = doc-level erase → attributed record + tombstone →
    the redaction accounting is nonce-agnostic and counts it VISIBLY
    (`redacted=`, never silent). The C7 negatives
    (store-subject-001..003, CXER4619) guard the trap the witnesses
    alone miss.
  - **M5 `o-5521` end-to-end = `test_rtbf_o5521_end_to_end`**
    (store_subject_test.v, cxpack+SEK — the custody-deep half of the
    standing fixture split; the mem-expressible command slice is
    journal-129/130/131/132, and the corpus-expressible family stays
    §10's stream-14 handoff): the order aggregate stream
    (`order:o-5521`) carries personal + non-personal events; the RTBF
    command with authority (docs=1 erased=1 subject-keys=1, balanced
    account, `holds-head=` pinned — the head-set scope); idempotent
    replay `[deduped …]`; the named-stream chain green (valid=true
    redacted=1 unattributed-missing=0 payloads-verified=2);
    attribution intact on BOTH evidence bases (the tombstone naming
    shred-request with `subject` absent; the `cx:erasure` record
    naming subject/request + the `[docs]` scope covering the erased
    address + the pinned `[head-set]`); non-personal events read
    intact and the erased entry hydrates the typed tombstone as a
    direct child. **Gotcha found:** `journal-read` takes a TRAILING
    STREAM KEY (`jrn_opt_stream`), not an opts map — a `{stream: …}`
    map arg silently reads the default stream.
  - **#720 all-items closure evidence:** item 1 = W4/W5
    (`test_local_get_doc_of_erased_answers_tombstone` + store.md §6.1
    three-way rows); item 2 = `test_sek_destroy_unavailable_vs_tampered`
    (encryption_test.v, the M33 typed discrimination, W2) + the
    CXER1145-vs-fail-closed M29 classification (W4/W5); item 3 = the
    2026-08-05 registry repair + this wave's §9.6 row refresh; item 4 =
    #712 CLOSED (keep-after-time implemented, stdlib_journal.v); item
    5 = the cxdm §12.5 distinction bullet + the shipped typed
    `[erased]` element (deliberately divergent, rationale stated).
  - **#779 closure evidence** = the W1 record (root cause; the
    store_lock_enter/exit fix in store_rotate_kek covering all four
    substrates; `test_rotation_cxpack_vs_background_fold_worker_779`).
  **Exit audit — every §12 edit-map row disposed:** store.md §9
  (W2/W4/W5), journal.md §2.2/§4.2 (I1 + W2), §2.8/§4.9 (W4), §3.6
  (W5), cxdm §12 (W6), authz/vc legal-hold (W6, this audit's find),
  governance §9.6 (2026-08-05 repair + W6 refresh), cx_partition §8
  (W6), handoffs 4/9/10/21 (W6, above). Named landings (ruled, not
  deferrals) unchanged: replica shred-reach = stream 9 (#681 comment +
  distributed_store receiving text); cross-stream erasure = stream 10's
  saga vocabulary; M5 corpus families = stream 14 (§10); no erasure on
  the retiring CSRP plane (stream 4). Open adjacents filed, not
  stream-20 scope: #784 (placement tier), #785 (rotate/compact at-rest
  options), #786 (SQL facade).
