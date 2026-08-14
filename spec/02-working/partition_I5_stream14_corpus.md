# I5 stream 14 — corpus completeness audit + absorption (implementation ledger)

**Branch** `impl/I5-stream14-corpus` off `design/651-516-partition`
(opened 2026-08-14 @ 488fc5ee, the stream-18 exit merge). **THE LAST
STREAM of the I5 phase** — the campaign exit review follows it.
**Governing spec** `partition_corpus_audit.md` (structural letters 1–13
all ruled (a) 2026-08-05: lane splits, ring= in fixture data, the
pair-case form + digest assertions, ratified §4 gap dispositions, the
§5 deferral batch rulings). **Issue:** #686 (corpus completeness vs
every normative spec; the receiving register; the inherited-deferral
batch — batch already RULED per §6, so no new confirm-or-adopt round
is owed unless verification falsifies a ruling's premise).

## Opening evidence sweep (2026-08-14, at 488fc5ee)

- **Receiving register** (partition_corpus_audit.md §Stream-14): NINE
  owing rows — s8/s9/s10/s16/s17/s18/s20/s21/s22 — each pointing at
  its ledger section; the audit-added corpus notes ride below it
  (strict-tag handling absent in stdlib/package runner lanes;
  out-effects grading skipped for thrown-error fixtures; the
  every-out-err-carries-a-code discipline).
- **Gap-register artifact sweep** (what exists at open): xsp.cxd ✓
  (G8, stream 4), did.cxd + vc.cxd ✓ (G14), lockfile.cxd ✓ (G10),
  fmt.cxd ✓ (G6), streaming_write.cxd ✓ (G12 — V-lane wiring to
  verify), identity_hash.cxd ✓ (G1, pairs included), ast_bin.cxd ✓
  (G4). G15 inverse gap RESOLVED by stream 18 (six approved x specs).
  G17/G18 validators live. OPEN by evidence: **G9/D-DBG** (no
  debug.cxd — the tape-completeness fixture is a RULED adoption, not
  optional); **G16** (the grammar-production traceability map —
  judgment work; inputs exist: 310 production ids, witnesses.txt now
  198 rows, stream 13 CLOSED with grammar_lexicon_review.md in-tree);
  **G2/G3/G5-half** (Tier-2 pair-property corpus reach, canonical-emit
  family breadth, decimal/bigint wire goldens) — VERIFY-then-close
  per row in W1 (their owning phases ran; the register's truth needs
  the per-gap verification pass, never assumed).
- **Corpus scale at open:** 89 .cxd files; code.cxd 1072 enforced
  cases (fixture runner, no whitelist); the full `make test` union
  GREEN at the branch point.

## Wave plan

- **W1 — the verification pass:** per-gap truth over the §4 register
  (each row → CLOSED-by-evidence w/ the artifact named, or OPEN w/ the
  landing wave here); the receiving-row inventory (read each owing
  ledger section; extract the concrete family list; size it); the
  audit-notes triage (strict-tag lanes, out-effects grading,
  out-err-code discipline — mechanical fixes land here if small);
  register truth-up commits.
- **W2 — story-substrate rows (s8 bitemporal, s20 erasure, s21
  evolution):** the journal-lineage corpus families.
- **W3 — distribution rows (s9 store, s10 coordination):** ingestion/
  conflict/saga/escrow/pin families.
- **W4 — identity/runtime rows (s16 shape, s17 runtime, s22
  clean-room):** inference witnesses, per-combinator pull matrix, EV
  witnesses.
- **W5 — s18 choreography + the ruled adoptions:** the end-to-end
  refund-order witness + registry-dispatch + two-boundary strict-args;
  G9/D-DBG tape fixtures (debug.cxd); G16 traceability map (authored
  against stream 13's review — honest-judgment mapping, no
  prefix-match fabrication).
- **W6 — exit:** register final truth-up; full `make test` union;
  closure evidence (#686); merge; the campaign I5 exit-review packet
  (OWNER-GATED — stop-point (iv): the exit review itself is the
  owner's).

## Wave record

- **OPENED 2026-08-14** — branch cut @ 488fc5ee; evidence sweep above;
  the wave plan sized off the receiving register. W1 begins with the
  per-gap verification pass.
- **W1 verification pass — gap verdicts (2026-08-14).**
  **G12 CLOSED-by-evidence:** conform-streaming-write V lane exists
  (vcx/Makefile:436, rides `conform`) — the register's "no V lane"
  claim is stale; truth-up applies to partition_corpus_audit.md §4 at
  the W6 register pass. **G2 OPEN (real W-work):** identity_hash.cxd
  carries ZERO Tier-2 (computation-id) pair cases — the Tier-2
  pair-property family (alpha-renaming / whitespace / comment
  invariance + the S0 exclusion set as CORPUS pairs) still lives only
  in V tests (identity_umbrella_test.v tier2 sections); cmd-011 covers
  exactly one exclusion property. Lands W4 (identity group).
  **G3 PARTIAL:** out-canonical assertions now 37 across six files
  (was 31) — the stream-12 "canonical-emit family expansion" landed
  thin; NOTE: broad canonical-emit goldens are PARTIALLY BLOCKED by
  #810 (the singleton-seq-in-map-value emit defect, owner-gated):
  pinning today's broken emission as goldens would freeze the defect —
  the G3 family lands AFTER or AROUND the #810 ruling (the non-broken
  shapes can pin now; the singleton shape gets its fixture WITH the
  #810 fix). **G5-half OPEN-thin:** one decimal/bigint mention in
  data_bin_chunked.cxd — the post-epoch wire goldens for 0x18/0x28
  columns (stream-17 columnar variants) need the family; lands W4.
  **Receiving-row pointers resolved:** s8 → its ledger §wave-record
  four-quadrant family; s9 → distributed_store.md §7 (every row has a
  shipped pin; the FULL program is the handoff); s10 →
  cross_stream_coordination.md §6; s16 → shape_inference §11; s17 →
  runtime_representation §9 (+ the s22 handoff); s20 →
  erasure_compliance §10; s21 → its ledger §8 row (8 named families +
  the pure/impure M5 split); s22 → clean_room §9; s18 →
  agent_tool_projection §8 beyond the shipped pins (the register row
  enumerates). Audit-notes triage: strict-tag stdlib/package lane
  handling + out-effects grading for thrown errors = runner work
  (lands W5 with the discipline sweep); every-out-err-carries-a-code =
  a sweepable check (W5).
- **W2 progress (2026-08-14).** s8 row DISCHARGED @ e94b24a8
  (journal-143..147 — restatement-delta pair w/ control, amendment ×
  quadrants, assertion coexistence, depth-2 correction chain,
  fold≡replay parity; gate green). **s20 diff (verify-then-author):**
  shipped pins cover journal-127 (absent-nonce CXER4619), 128 (legal
  holds), 129 (erase-subject), 130 (shred generation), 131 (dedup
  purge), 132 (verify reconciliation), 116 (redaction visibility);
  snapshot/fold-from/retain generally at 027-030/050-054; o-5521 RTBF
  lives as the V test test_rtbf_o5521_end_to_end (s20's judged home —
  spans keys/store/authz). TRUE REMAINDER to author: (1) KEK-rotation
  balanced-report case; (2) the C7 weak-nonce negative TWINS (derived
  nonce, short nonce — the absent case alone passes for nonce=1, the
  ruled trap); (3) the plaintext-vs-encrypted address-parity witness;
  (4) the tombstone THREE-WAY discriminator (never-existed / corrupt /
  erased in one case); (5) verify-valid-headline explicitness check on
  132 (assert valid=true post-shred if not already); (6) the
  visible-count silent-under-report negative twin check on 116. Then
  s21's 8 named families (its ledger §8 row) close W2.
- **W2: the s20 row DISCHARGED BY VERIFICATION (2026-08-14) — zero new
  cases owed.** Every §10 item traced to a recorded honest home:
  verify-valid-with-payloads-destroyed = journal-132 (asserts
  valid=true both sides + the unattributed-missing LOUD account);
  visible-count + its no-silent-under-report half = journal-116
  (projected count does not shrink AND erased=1 is visible); weak-nonce
  C7 twins = store-subject-001/002/003 (required/short/derived) +
  journal-127 (coordinate-derived — all four §3 rules pinned);
  plaintext-vs-encrypted parity = SUPERSEDED BY DESIGN (store-subject-
  004: a plaintext store REFUSES subject declarations CXER1144 — there
  is no plaintext lane to compare; the §10 sentence predates the
  refusal ruling); SEK-destroy → TYPED unavailable finding (M33,
  never "tampered") + KEK rotation balanced account over subjects
  (rewrapped + already-current + subject-keyed; SEK envelopes never
  move; destroyed stays shredded through rotation) + the attributed
  [erased] tombstone read = vcx/platform/store_subject_test.v
  (test_subject_seal_shred_and_rotation_cxpack + the erase-subject
  walks) — the custody lane journal-129's own note records as the
  V-tested boundary (mem:// has no key custody); tombstone three-way =
  COVERED-AS-SPLIT (never-existed + corrupt = store negatives;
  erased-attributed = the custody lane + journal-132's reconciliation)
  — a single-case discriminator cannot reach the custody leg from
  mem:// without faking custody, refused; snapshot-reach family =
  journal-027..030/050..054 + the shred-generation CXER4640 leg in
  journal-129/130; o-5521 RTBF end-to-end = test_rtbf_o5521_end_to_end
  (s20's judged home). NEXT: the s21 row (8 named families, its ledger
  §8) closes W2.
- **W2: the s21 diff (2026-08-14).** Shipped pins journal-118..126
  cover: add-a-field (118 seam + 119 VT order + 120 refusals), the
  pre-flight pair (121 carries both halves), fold-id snapshot/mismatch
  (122/123), cover-current-fold (124), migrated-from + the
  migration-is-not-a-correction discriminator (125), lineage
  ambiguous-graph + :split relations + gap (126). RECORDED VERDICTS:
  compat-predicate three-valued + [req]-in-open-mode + export-lossiness
  = NO SHIPPED SURFACE (no schema-compat verb anywhere; the s21→#688
  re-route closed with s16 without the verb) — fixtures land WITH the
  surface, never against nothing; downgrade-skip pair = same class
  (L150's own row: "no downgrade replay impl surface exists").
  AUTHORING REMAINDER (§8's two open families): (1) SPLIT — pure split
  AS COMPUTATION (flat-map over materialized entries; the SEAM's 1→N
  refusal CXER4642 is design, pin it), impure-split-refused leg,
  totality-residue loud per-entry err leg; (2) 10k-replay — the scale
  witness + parallel-upcast ≡ sequential equivalence (fold-id legs
  already pinned at 122/123; prune-cover at 036/052).
- **W2 COMPLETE — all three story rows discharged (2026-08-14).** s21's
  two open families LANDED as journal-148..152: split-as-computation
  (flat-map, 2→4 partition), the seam-is-1→1 refusal pin (CXER4642 BY
  DESIGN — splits are computations), impure-split refused-as-computation
  (CXER4611 pre-effect), totality residue LOUD per-entry (CXER4641
  carrying the chain's message), and the 10k parallel≡sequential parity
  witness ([par 4] over the pure chain ≡ the seam fold; closed-form
  50005000; ~2s runtime, acceptable enforced). Gate GATE-RC=0 @
  686_w2_s21.log. W2 tally: s8 authored (+5), s20 verified (+0 owed),
  s21 authored (+5) + two no-surface verdicts recorded. W3 NEXT:
  s9 (distributed_store.md §7) + s10 (cross_stream_coordination.md §6).
- **W3 COMPLETE — both distribution rows discharged (2026-08-14).**
  **s9 (distributed_store §7):** discharged with ONE authored case —
  journal-153 (the s9×s8 cross: the four-quadrant table holds UNCHANGED
  over an INGESTED replica stream; ingested=2, answers ≡ journal-108's
  origin-native shape — sync never bends time). Everything else
  verified at shipped pins: seed+tamper (134/135 CXER4615), the M5
  end-to-end w/ VT-precedes-TX read + attribution survival +
  conflict→resolution (138), reconcile FF/diverged/merge-entry
  (store-reconcile-001/002/003 — 002 alone carries the conflict-value
  round-trip [stable true], THE PATCH LAW [law true], the
  enforcing/reporting AGREEMENT law, and unmoved-ref; 001's [again]
  row IS idempotent re-sync: identical=1 advanced=0), replica
  declaration profile + wiring-time refusals (store-replica-001
  CXER4990), retention wall (136 CXER4616), ingest byte-identity +
  idempotent re-ingest + CXER5050/5052 (133), head-set plane
  (store-status-002; the advance rows' from/to hashes ENUMERATE the
  transferred set — exact-delta covered by report shape).
  **s10 (cross_stream_coordination §6): discharged BY VERIFICATION —
  zero new cases.** both-ways pair = 092 (:serializable teaching
  refusal) + 139 (the same intent succeeding as a saga) covered-as-
  split; replay-isolation + anti-2PC CXER4611 = 142; compensation
  triple = 140 (+141 uncompensatable); redelivery⇒one-effect = 139
  ([deduped], re-executes NOTHING); positional-vs-named⇒one-key =
  COLLAPSED BY DESIGN into the name-keyed args record (the W2
  commands_effects §5 sentence + cmd-021 order-insensitivity +
  cmd-023 record normalization); escrow pair + budget conjuncts =
  authz-085 (the durable-timer ARMING is sched's own pinned surface —
  covered-as-split); stale pins = authz-084 (CXER4950/4951) + the
  journal expect-pos CXER1114 lane; head-set cut = 101; [conflict]
  shape-shared = store-reconcile-002. Gate GATE-RC=0 @
  686_w3_gate.log. W4 NEXT: s16/s17/s22 rows + G2 (Tier-2 corpus
  pairs) + G5-half (decimal/bigint wire goldens).
