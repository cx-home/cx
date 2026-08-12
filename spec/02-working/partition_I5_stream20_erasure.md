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
in the registered journal `4617–4639` + store `1144–1149` bands
(registry repair executed 2026-08-05).

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
- **W2 — the SEK tier (L181, §2 + §9 custody):** keying-backend
  refactor — key-id → (KEK, SEK, DEK) resolution; SEK-absence =
  fail-closed; SEKs KMS-resident as `sek/<tenant>/<subject-token>`
  (opaque token, never the subject id); the re-wrap primitive reused;
  `envelope_open` gains the fail-closed `unavailable` finding now (the
  `shredded` discrimination lands with the journaled shred-request it
  is evidenced from — W5; never key-absence-derived, audit M33).
- **W3 — subject/nonce vocabulary + the oracle family (L182/L183,
  §3+§4):** `subject=`/`nonce=` reserved payload attributes; CXER4617
  E_ERASURE_NONCE_REQUIRED refusal (first code of 4617–4639);
  weak-nonce NEGATIVE witnesses (no-nonce refusal; derived/short nonce
  rejection — dedup/parity witnesses alone pass for `nonce=1`, the C7
  trap); ≥128-bit CSPRNG; nonce inside the sealed payload only;
  address-parity + nonced-dedup-loss witnesses.
- **W4 — legal hold (L188, §8):** signed Lane-2 `[legal-hold]` claim;
  per-tenant hold-stream (a hold binds from its journaled position
  onward); the `[requires-at]` head pin + commit-lock re-check;
  unsigned → fail-closed. Lands BEFORE the command so the shred
  precondition is never a partial impl.
- **W5 — erase-subject + the shred walk (L184 remainder/L187/L181
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
- **W6 — read surfaces + verify reconciliation (L185/L186, §6):** typed
  `[erased subject? at= authority= actor= shred-request=]` tombstone on
  the value channel; `get-doc` three-way (never-existed CXER1121 /
  unreconstructable CXER1120 / lawfully-erased `[erased]` — #720 item
  1; `get-doc-text` inconsistency resolved); `verify` reconciliation:
  `redacted=N unattributed-missing=K`, any K>0 LOUD; the negative
  fixture (payload destroyed with no shred-request →
  `unattributed-missing=1`); visible-count generalization
  cross-references (streams 3/21 per audit M7).
- **W7 — hygiene + exit:** §12 edit-map residue (store.md §9, cxdm §12,
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

*(appended per wave: commit ids, gate logs, fixture ids, HEAD guards)*
