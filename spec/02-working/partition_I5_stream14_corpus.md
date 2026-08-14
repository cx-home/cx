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
