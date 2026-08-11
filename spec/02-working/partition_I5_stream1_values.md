# I5 stream 1 — semantic value model (E1–E4): implementation ledger

**Status:** OPEN (started 2026-08-11; order-of-march item 5, stream 1
FIRST per the item-4 exit handoff).
Branch `impl/I5-stream1-values` off `design/651-516-partition`
(cut at 51740e05 — the #725 close merge).
Governing spec: `semantic_value_model.md` — letters L77–L85 inside the
S1 batch **RULED (a) 2026-08-05 (letters 62–85)**; RULED-token anchor =
the S1 ruling row in `partition_campaign_PLAN.md` (decision log
2026-08-05, "S1 LETTERS 62–85 RULED (a)").
Issues: #673 (stream), #708 (evidence: the five value-model identity
divergences — items 1/3/4 verified closed in the item-4 batch, item 2
rides this stream's W1 verification, item 5 is #688's L63 surface,
cross-pinned not duplicated).

**Epoch posture (the loud part):** I1 IS CLOSED (ef80e409). This stream
is POST-EPOCH: no re-bless is available — a moved Tier-1/Tier-2 address
is a defect, never a blessing. Every wave below is either (a) already
covered by an executed I1 row (verify, never re-land), (b) additive
(new machinery, new fixtures, new addresses DEFINED not moved), or
(c) schema-identity-scoped where the I1 mapping records "zero pinned
movers by design" (row 6: schema digests are recomputed, never pinned
literals — the ONE class where new bytes may lawfully change computed
schema identities, per the entry-25 owner ruling that mandates exactly
that resolution before anchoring).

## Standing constraints

- Spec-first; NO spec edits without a recorded ruling (RULED: tokens on
  spec+impl commits; fragments must grep in `partition_*.md`).
- Every wave ends green on the full gate — launched UNPIPED, full log,
  `GATE-RC=$?` propagated, verdict read FROM the log.
- Fixtures ride WITH their machinery wave, never after; W5 carries only
  the §7 families no earlier wave owns.
- Cutover-first, no dual-accept; never true a spec to a shortfall.
- Fable 5 only; push per landing; exit-merge IS an exit step.

## Pre-open recon verdicts (2026-08-11, all probed live this session)

1. **E1 quote lowering + hole form: LANDED AT I1 (row 9), not open
   work.** Probes: `[?quote [total $x]]` → `cx:serialize` gives
   `[total $x]`, `cx:hash` gives
   `sha2-256:cf1204b421c2179448e1fe82338d37e64998a1897ea67d8c27674204ebf2c5a0`
   = the cx-094 pin = `cx hash` of the data document (L77/L81
   discharged); `[total $x]` vs `[total '$x']` hash DIFFERENTLY
   (idh-026, the C4 collision MUST). Spec surface exists: canonical.md
   quote-table `$`-sigil rule (I1 row 9), ast.md Hole node row,
   ast-bin.md 0x18 HoleNode. Operator heads: all seven flipped at I1
   row 8 (`operator_heads.cxd` v2.0). Totality refusals: CXER4101
   (closures) / 4117 / 4118 shipped.
   **HONEST BOOKING (audit C4 sequencing miss):** the C4 amendment
   mandated the hole form be SPEC'D BEFORE the I1 epoch; it was
   spec'd AT the epoch (I1 row 9 landed spelling + spec together).
   The collision pair idh-026 exists and pins the fix; the miss is
   sequencing-only, no identity consequence survives it. Booked here
   so the record never claims the mandate was met as written.
2. **E2 hash basis: LANDED AT I1 (row 6 COMPLETE, mapping row "zero
   pinned movers by design"; schema_hash_basis_test.v).** OPEN
   RESIDUAL: the entry-25 owner ruling (2026-08-06) — strict canonical
   strips `[?cx …]` directives, so `schema-of`/`schema-mode` do NOT
   ride in the hashed bytes; the strip STANDS at I1 and
   mode-in-identity MUST be resolved before THIS stream's type-binding
   anchoring, by (i) content-bearing-directive preservation under its
   own ruling or (ii) schema-of/schema-mode moving into
   schema-document BODY data. Pinned by
   `test_mode_does_not_survive_canonical_text_named_residual` — the
   resolution flips a test, never a silent behavior.
3. **E2 anchoring machinery: NOT IMPLEMENTED.** `[type-binding]`
   Lane-2 claim form: zero implementation (schema.md names it as
   "I5's type-binding anchoring"; the umbrella test names it as the
   pending consumer). One-type-per-schema-document (L83 ruled (c),
   NORMATIVE for identity-anchoring schemas): no enforcement exists.
4. **E3 lineage substrate: LANDED (72909cdf + item-4).** Per-ref
   advance log; `store:log` per-act arrival order w/ force-moves
   visible (#708 item 3 CLOSED); CXER4604/CXER1704 retired at I1 row
   15 (audit M21), CXER1114 the ONE conflict code, governance §9.6
   tombstones recorded; wire refs-set/alias CAS carries
   `expect="<address>"` w/ `""` = must-not-exist (store_profile_ops.v).
   TWO RESIDUALS: (i) the position encoding ships as `expect-pos`
   (live.md L119) but journal.md §3.2 + stdlib_journal.v still spell
   it `expect-prev-seq` — L84 names `expect-pos=N` as THE position
   encoding of the ONE vocabulary; (ii) cxstore-grpc.md's mapping
   table still carries the retired `409 CXER1704` row (the L84
   spec-edit map named the grpc mapping; the code already maps 1114 —
   store_grpc_client.v).
5. **E4 contract: NOT EXECUTED.** semantic_value_model.md is the
   rulings record, not yet the binding contract §5/L85 describes (no
   terminology glossary text); the cross-binding spec-edit map rows
   that were not I1 manifest rows are unexecuted — cxdm (terminology,
   lanes), code.md §4.2/§6.4.3 (identity promises normative),
   code-identity.md (layering statement), cx_partition.md §2 (Ring-0
   named-artifact amendment). canonical §11.4's quoted-tree extension
   needs verification against what I1 row 9 already landed.
6. **§7 corpus: PARTIAL.** identity_hash.cxd = 18 cases (singles,
   spelling-invariance pairs, significance pairs, idh-026 hole pair,
   NFC + map-order). MISSING families: meta-does-not-participate
   pairs, quoted-tree round-trip closure (`parse ∘ canonicalize` over
   quote results), type-identity pairs (reformat ⇒ same; one facet ⇒
   different), ref-history fixtures (positions + force-move; the
   unified CAS error in BOTH encodings, local AND over the wire).

## Rulings taken this stream (standing acceptance, long-term-best verified)

- **R1 (mode-in-identity, discharges the entry-25 owner ruling) —
  option (ii): `schema-of` / `schema-mode` move into schema-document
  BODY data.** Verified against the bar: (i) directive preservation
  would move the address of EVERY directive-bearing document post-epoch
  (no re-bless exists — disqualifying) and needs its own identity
  ruling; (iii) schema-specific canonicalization violates
  one-primitive (already rejected at entry 25). Body data satisfies
  the ruled E2 sentence LITERALLY ("schema-mode rides in the hash as
  document bytes and is never a separate policy input"), keeps ONE
  canonical primitive, and its only identity movement is inside the
  row-6 recomputed-never-pinned class. The named-residual test flips
  to assert mode-bearing schemas hash DIFFERENTLY. RULED anchor:
  entry-25 ruling text (partition_I1_rebless.md header) + L82/L83
  fragments (PLAN decision log).
- **R2 (position-encoding spelling) — journal's `expect-prev-seq`
  renames to `expect-pos`, cutover-first.** L84's ruled vocabulary
  names `expect-pos=N` as THE position encoding; two spellings for one
  encoding is exactly the divergence E3 exists to close; no external
  users, no dual-accept. journal.md + stdlib_journal.v + fixtures
  cut over in one landing. RULED anchor: the L84 fragment ("ONE CAS
  code CXER1114 w/ address+position encodings", PLAN decision log).

## Wave plan (dependency order; each = one landing + gate)

| Wave | Work | Done-when |
|---|---|---|
| **W1 — E1 verification + honest bookings** | This ledger authored; every recon-verdict-1 pin verified live (cx-094, idh-026, oph v2.0 seven heads, the three totality refusals); the C4 sequencing miss booked; #708 item 2 evidence recorded | Ledger committed; probe transcript in the entry; no code movement |
| **W2 — E2 anchoring machinery (R1 first)** | R1: schema-of/schema-mode → schema-document body data (schema.md surface + validator + the named-residual test flips); L83 one-type-per-schema-document enforcement for identity-anchoring schemas (typed refusal when a multi-type document anchors); `[type-binding]` Lane-2 claim form (subject/name/schema) + fail-closed validation at trust boundaries (#702 posture) | Mode-bearing schemas hash distinctly (flipped test green); anchoring refusal fixtures green; type-binding claim fixtures green; type-identity §7 pairs ride here |
| **W3 — E3 vocabulary completion (R2)** | `expect-prev-seq` → `expect-pos` cutover (journal.md §3.2 + stdlib_journal.v + journal fixtures); cxstore-grpc.md retired-1704 row repaired to the CXER1114 mapping the code already implements | Journal CAS fixtures green under the new spelling; grep shows zero live `expect-prev-seq`; grpc doc row matches store_grpc_client.v |
| **W4 — E4 the binding contract** | semantic_value_model.md §5 made real: the universal invariant stated normatively + the four-senses terminology glossary authored; cross-binding edits executed (cxdm terminology+lanes, code.md §4.2/§6.4.3 promises normative, code-identity.md layering statement, canonical §11.4 quoted-tree closure verified/extended, cx_partition.md §2 names the artifact) — every edit RULED: L85 | Cross-refs resolve (G18 strict clean); contract text binds by reference, zero copied normative text; G3 graduation = OWNER-GATED handoff packet, never attempted here |
| **W5 — §7 corpus completion** | The remaining families: meta-does-not-participate pairs; quoted-tree round-trip closure; ref-history fixtures (dense positions, force-move APPEARS, unified CAS error in BOTH encodings, local + over the wire) | identity_hash.cxd + store/journal fixture families green; every §7 family present or ridden by an earlier wave |
| **W6 — exit** | Full gate GATE-RC=0; exit-merge to design/651-516-partition (the merge IS an exit step); #673 + #708 closed with evidence; handoff to #677 | Gate log + merge pushed; issues closed |

Wave order rationale: R1 before any anchoring consumer exists (the
entry-25 mandate is literally "before I5's type-binding anchoring" —
so mode resolution and the anchoring machinery share W2 with R1
sequenced first inside it); E3's rename is independent but its §7
fixtures depend on the final spelling, so W3 precedes W5; E4 binds
what W2/W3 finish, so it follows them; corpus completion last-but-one
so it pins the finished surface; exit alone.

## Work log

(entries append here; each wave = one entry with commits + gate verdict)

1. **W1 COMPLETE (2026-08-11) — E1 verified landed; the C4 sequencing
   miss booked (recon verdict 1 above); #708 item 2 evidence recorded.**
   Live probes this session: `[?quote [total $x]]` →
   serialize `[total $x]`, hash
   `sha2-256:cf1204b421c2179448e1fe82338d37e64998a1897ea67d8c27674204ebf2c5a0`
   (= the cx-094 pin = `cx hash` of the data document — L77/L81/L78
   discharged live); `[total $x]` ≠ `[total '$x']` addresses (C4
   collision MUST holds); all SEVEN operator heads hash as elements,
   `[+ $x 2]` = `sha2-256:7478d6bb…` (= the I1 mapping row-8
   representative). Verification lanes (unpiped, logs in vcx/target/):
   `s1_w1_lane_idh.log` identity_hash.cxd 18/18 LANE-RC=0;
   `s1_w1_lane_oph.log` operator_heads.cxd 10/10 LANE-RC=0;
   `s1_w1_lane_cxfix.log` stdlib fixture battery incl. cx.cxd (cx-094
   + the CXER4101/4117/4118 refusal fixtures) LANE-RC=0 under the
   standard `-d cx_db_sqlite -d cx_db_redis` engine set (a bare run
   without the engine flags red-flags db.cxd redis rows as
   `enforced` — lane-harness gotcha, not a defect). No code movement
   in this wave; W2 opens with R1.
