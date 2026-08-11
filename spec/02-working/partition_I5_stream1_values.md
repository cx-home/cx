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

2. **W2 COMPLETE (2026-08-11) — R1 discharged + the E2 anchoring
   machinery landed. Full gate GATE-RC=0 (s1_w2_gate3.log).**
   **R1 (mode-in-identity, entry-25 ruling executed):** the schema
   surface cut over from directive spellings to the `[schema of=…
   mode=… name=… version=…]` HEADER ELEMENT — ordinary body data, so
   every header attribute rides in the canonical text and the
   content-hash (probe: with-mode vs without-mode schemas hash
   distinctly). Spec: schema.md §1/§2/§8/§9/§10.1/§13.1 + S-table
   (detection = first top-level element `[schema]` w/ `of=`; the name
   `schema` reserved at exactly that position; the four
   `[?cx schema-*]` pragmas + standalone `[?cx frag]` RETIRED and
   rejected at schema load with targeted S009s — `[?cx frag]` was the
   SAME identity hole, and §8's anchored-type form was already spec'd
   semantically identical; the §13.1 owner-flagged known-conflict
   paragraph replaced by the resolution; `--mode` documented as
   run-scoped, never identity-bearing); data-bin.md examples;
   shape_inference.md's emitted-form example synced so #688 never
   implements the retired spelling. Impl: parse_schema reads the
   header (fail-closed: unknown mode = S009 — a typo must never
   silently weaken to open; version ≠ 0.8 = S020; missing of = S009);
   retired spellings rejected recursively; parser.v
   maybe_flag_schema_header is the live schema detection (pragma
   detection KEPT parse-only so legacy text reaches the targeted S009
   instead of dying CXER0107 — not dual-accept: no path treats the old
   spelling as working); S017 message re-worded.
   **Migration (the full census):** xap_schemas ×5, inventory.cxs +
   README, _sample_suite.cx, fixtures.cxs, validate.py;
   schema_validate.cxd 60 cases migrated + 4 NEW negatives
   sv-064…067 (retired schema-of / retired frag / unknown mode /
   missing of) = 67/67; data_bin_schema_driven.cxd 12/12;
   eval_semantics (14 sites) / identity / store_columnar umbrella
   tests. TWO LANES MISSED BY THE FIRST CENSUS (caught by gates 1+2,
   both migrated): lang/rust schema_validate_test.rs (2 schemas +
   docstrings; go docstring) and tests/abi/c_abi_test.c (2 schemas) —
   gotcha booked: the census for a DATA-SURFACE cutover must sweep
   extension-blind, binding tests embed schema text in .rs/.c/.go
   string literals. The named-residual test FLIPPED as designed
   (test_mode_rides_in_canonical_text_and_hash asserts ≠) +
   test_retired_schema_pragmas_rejected. New identity pairs
   idh-029/030/031 (mode-in-identity, reformat-invariant,
   facet-significant) — identity_hash.cxd 21/21. cxparse differential
   744→748 (+4 agree = sv-064…067 plain-data targets; growth only,
   movement note in the baseline).
   **E2 anchoring machinery (L83):** `cx:type-binding` constructs the
   Lane-2 `[type-binding [subject hash=…] [name …] [schema …]]` claim
   (pair recoverable-by-computation; fail-closed CXER4116 anchoring
   refusals — one-type-per-schema-document NORMATIVE for anchoring,
   multi-type validates-but-cannot-anchor; E1 totality refusals
   propagate through the cx:hash acquisition path) and
   `cx:type-binding-verify` recomputes-and-compares field by field
   (CXER4119 on any malformation/mismatch). modules/cx.md §2.1 rows +
   prose + §6 error rows (4116/4119 leave the reserved list;
   governance registry row is band-level, unchanged). Fixtures
   cx-113…116 (claim byte-pin, verify-true, tamper→4119,
   multi-type→4116); full stdlib battery green. Schema-store
   resolution stays #688 (cross-bound, not duplicated).
   Gate history: gate 1 RC=2 (rust binding lane — missed .rs class +
   the cxparse growth), gate 2 RC=2 (C ABI lane — missed .c class),
   gate 3 GATE-RC=0 with the two known #572 C-compile flakes green on
   their classified cache-free retries. W3 opens with R2.

3. **W3 COMPLETE (2026-08-11) — R2 executed + the E3 residuals closed.
   Gate: SHARED with W4 (both landings spec/impl-disjoint; W3's three
   affected lanes also green standalone first) — GATE-RC=0
   (s1_w3w4_gate2.log).**
   The `expect-prev-seq` → `expect-pos` cutover (L84: ONE position
   encoding in the ONE CAS vocabulary; semantics unchanged — "the
   stream/ref is currently at position N"; live.md already shipped
   expect-pos): stdlib_journal.v (the §3.2 check), fabric_service.v
   (attribution forward + the batch refusal), journal.cxd ×3,
   fabric_umbrella_test ×4, store_g13_parity_test ×2, journal.md
   (all 9 mentions + a retirement note at §3.2), fabric.md/xap.md/
   delivery.md. Repo-wide sweep: zero residuals beyond the retirement
   note. BONUS repairS the sweep surfaced: gates.cxd's journal gate
   doc-string still said "expect-prev-seq → CXER4604" — the 4604 half
   was STALE since I1 row 15 (tombstoned); now reads expect-pos →
   CXER1114. cxstore-grpc.md's mapping table still carried the retired
   `409 CXER1704` row — the L84 spec-edit map named the grpc mapping
   and the code has mapped 1114→ABORTED since I1; row repaired.
   Lanes green standalone: stdlib fixture battery, fabric_umbrella,
   g13_parity. Gate history: first shared gate RC=2 — the fabric
   floor-group LIVENESS lane panicked under parallel-gate machine load
   ("a heartbeating holder lost the assignment"), green standalone
   twice at the same commit → load-sensitivity, #778 filed (prio:low),
   not a rename regression; second shared gate GATE-RC=0.

4. **W4 COMPLETE (2026-08-11) — E4 authored as the binding contract.
   Gate: shared with W3 (above), GATE-RC=0.**
   semantic_value_model.md §5 now IS the contract: the universal
   invariant stated normatively (same identity and meaning across the
   seven modes; surfaces that cannot honor it MUST refuse loudly —
   never re-key or coerce), the bound-by-reference list (zero copied
   normative text), and the four-senses terminology table (document
   ID/IDREF · content address · cx:equal · CXDM set-equality; an
   unqualified "identity" means the content address). Cross-binding
   edits executed (RULED: L85 + L77–L81): cxdm §4 gains the
   terminology pointer (keeps its name — the reader trap closes by
   glossary, not rename); code.md §6.4.3.1 gains the normative E1
   promise (post-substitution tree, lowered, Tier-1 address, name-
   sensitive w/ additional-tiers-only layering); code-identity.md
   gains the L79 layering statement (open upward, closed against
   redefinition); canonical §11.4 gains the quote-result closure
   property (parse ∘ canonicalize over lowered quote results; the cx:
   image is projection-only, E210 intact); cx_partition.md §2 names
   the contract as Ring 0's contract artifact. G3 graduation of this
   document = OWNER-GATED handoff packet (item 6), not attempted here.

5. **W5 COMPLETE (2026-08-11) — §7 corpus completion. Full gate
   GATE-RC=0 (s1_w5_gate2.log).**
   The remaining §7 families landed: idh-032 meta-does-not-participate
   (hash + cx:equal across a `[?meta]` wrap — the #708-item-1 corpus
   pin), idh-033 quote-roundtrip-closure (parse ∘ serialize byte-stable
   over a lowered quote result + same Tier-1 address — the §11.4
   closure pin), store-branch-003-cas-conflict (local non-fast-forward
   `branch` → CXER1114 — the ONE conflict code locally, completing the
   encoding×surface matrix: journal expect-pos local (journal-06x),
   wire both encodings (g13 parity + store_concurrent_writer +
   cxstore_wire expect=/"" cases), force-move visibility
   (store-log-003)). Lanes: identity_hash 23/23; stdlib battery green;
   cxparse differential UNMOVED at 748 (identity_hash/store.cxd are
   outside its walk set). Gate history: first W5 gate RC=2 — a REAL
   race surfaced: store_rotation_test panicked in
   PackObjectBackend_fold_commit (`array.set (0,0)` — b.segs emptied
   under the worker's held op-lock ⇒ a segment-set-replacing path
   mutates without the same lock identity). Pre-existing (zero cxstore
   edits this stream; same tree gated green twice earlier today; three
   standalone re-runs green). Filed #779 prio:high, PINNED to #692's
   landing (rotation is erasure/compliance surface). Second gate
   GATE-RC=0.
