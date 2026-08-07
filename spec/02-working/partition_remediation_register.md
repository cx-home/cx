# Remediation register — adversarial audit I0–I5 (companion to partition_audit_impl_I0_I5.md)

**Rules of this register.**
1. Every finding F-1..F-30 has exactly one row. No row closes without
   (a) an express owner ruling where the row poses a question, (b) the
   acceptance criterion met, and (c) independent adversarial
   re-verification recorded in the Evidence column (a fresh agent pass
   or a named gate — never the implementer's own claim).
2. Spec-text changes required by a row happen ONLY under the row's
   recorded ruling (the no-spec-edits-during-implementation rule stands;
   a ruling recorded here IS the express authorization for that row's
   named edit and nothing else).
3. Default posture where spec and implementation disagree: **make the
   implementation true to the spec.** A row proposing the opposite says
   so explicitly and why.
4. Remediation work follows fixture-before-fix. Nothing outside this
   register lands until the register closes and the owner rules on
   resumption (R-final).
5. Rulings are recorded in this file (RULED: <letter> <date>) BEFORE the
   work of that row begins.

**Status legend:** OPEN-Q (awaiting owner ruling) · AUTH-PENDING (batch
authorization question pending) · IN-WORK · VERIFYING · CLOSED.

---

## Part 1 — Unauthorized spec edits: re-adjudication rows

These are NOT rubber-stamp ratifications. Each row is a fresh
adjudication: the evidence and the real alternatives are put before the
owner as if the question had been posed at the proper time. "Adjudicate
shipped" means: if ruled, the ledger records the ruling + evidence and
the shipped text stands AS RULED TEXT; if ruled otherwise, the shipped
text/implementation is unwound per the ruling.

| Row | Finding | Question (owner ruling required) | Acceptance criterion | Status |
|---|---|---|---|---|
| R1.1 | F-1 d7ca927b journal §6.1 | The substantive question never answered: (a) v1 = object-wire carriage stands; pushdown = future work behind its own spec pass (fn-as-data carriage + snapshot-key custody letters) at a stream the owner names; (b) pushdown implemented IN stream 4 (spec-first pass → G3 → build; extends stream materially); (c) revert §6.1 to pushdown text without building it (violates seam rule — listed for completeness). | Ruling recorded; §6.1 text conformed to the ruling under it; if (b): pushdown letters posed before any code. | OPEN-Q |
| R1.2 | F-2 25d7c775 M1/M2/M4 single-scalar shapes | Alternatives, honestly: (i) single-scalar offer-*/confirmed-* fields (shipped) — minimal carriage that keeps transcript byte-stability; (ii) nested [offers] signed over exact-bytes-as-sent — abandons canonical-form signing discipline (signature no longer tied to canonical identity); (iii) nested [offers] + fix data-bin atomization of element children — touches the identity-adjacent data-bin lane, which is epoch-frozen post-I1 (would require a new epoch = ruled out by "I1 is the only epoch" unless the owner reopens it). Probe evidence: nested children do not atomize; the same offer landed at different byte positions across encode/decode → the signed transcript was unstable (recorded W2, xsp-auth-025..031 pin the downgrade family). | Ruling recorded with the probe evidence cited; ledger gains the adjudication entry; if not (i), the /3 handshake re-cut under its own plan. | OPEN-Q |
| R1.3 | F-3 f61cb141 store.md §6.4 scheme + credential vocabulary | Design adjudication: (a) shipped design — bare cx-store:// = profile over TLS; cx-store+xsp:// = cleartext dev sibling, port explicit; identity via open-opts xsp-did + xsp-seed-env (seed ALWAYS an env-var name; URL userinfo refused at parse); (b) owner-directed alternative (e.g. different scheme names, config-file credential carriage, TLS-only with no cleartext sibling) — owner specifies, I spec-first it; (c) revert the scheme rows entirely (removes the shipped W6 client surface pending redesign). | Ruling recorded; §6.4 conformed under it; client behavior + tests conformed. | OPEN-Q |
| R1.4 | F-4 8f6832dd vp single-scalar carriage | Same evidence class as R1.2: a [vc] crossing the data-bin lane re-canonicalizes and its SIGNATURE dies (probed: [delegation d-vc-1 …] re-parses with a trailing-space id → bad-signature); M3 is transcript-signed so nested children hit the same W2 trap. (a) adjudicate shipped single-scalar [vp "<canonical text>"]; (b) alternative carriage the owner names; (c) revert (breaks W4 authority on the wire pending redesign). | Ruling recorded w/ evidence; §6.1 conformed under it. | OPEN-Q |
| R1.5 | F-5 40743e8e erased-marker-WINS | (a) adjudicate shipped rule (objects-get answers erased=true and never the bytes while the root awaits reclamation; objects-have keeps it missing — serving bytes would leak lawfully erased content); (b) strike the sharpening, restore prior §7b.1 (re-opens the leak window). | Ruling recorded; §7b.1 conformed under it. | OPEN-Q |
| R1.6 | F-6 d8d638b7 CSRP doc-frame (disputed classification) | Owner classifies AND adjudicates: the concrete [u16 hash_algo_code BE][digest32] layout + fail-closed rules landed same-commit with self-recorded authorization, under partial predating cover (manifest row 3, crypto-agility, ruling 1a codes). (a) classify as covered-by-manifest, adjudicate shipped layout (it repaired silent zero-padded hashes to binding clients; digest bytes unchanged; test-pinned); (b) classify as unauthorized, adjudicate shipped layout anyway (record both); (c) unwind the frame re-form (re-breaks the binding-client defect). | Classification + ruling recorded. | OPEN-Q |

## Part 2 — Process-breach rows

| Row | Finding | Question / action | Acceptance criterion | Status |
|---|---|---|---|---|
| R2.1 | F-7 epoch corpus amended post-approval | I prepare the complete amended-output review packet (the 22 outputs of aa2a24c2 + the 12 re-pins of d8d638b7, each with before/approved-degraded/after values). Owner: (a) review packet → retroactive sign-off; (b) order a full epoch-corpus re-verification pass instead (independent agents re-derive expected outputs for the amended families). | Packet delivered; ruling recorded; sign-off or re-verification result in Evidence. | OPEN-Q |
| R2.2 | F-8 I4 installer exit-gate | (a) ratify the disclosed deferral: I4 exit stands; tracker issue (sanitized, labeled) REQUIRING verification that CX_PROFILE=<lean> installs succeed at the next release cut, gate-listed for that cut; (b) reopen I4 exit until assets exist (blocks on a release cut by construction). | Ruling recorded; issue filed w/ acceptance criteria if (a). | OPEN-Q |
| R2.3 | F-10 I0 premature done-claims; F-11 I3 deferral-before-ruling; F-12 I2 in-ledger self-ruling; F-13 W5 post-hoc deferral; F-14 I4 R2 riding amendment | Owner ruling on the CLASS: (a) acknowledge as recorded process defects, no unwind (each converged/was cured; all are now impossible under the rulings-before-edits protocol + the R4.1 gate); (b) owner names specific items from this set for individual unwind/re-posing. | Ruling recorded; any named items get their own rows. | OPEN-Q |
| R2.4 | F-13 specifically: migrate/clone erased-map → stream 20 | The deferral itself needs its ruling (recorded post-hoc at entry 7): (a) confirm the routing (stream 20 owns the SEK/erased-map carriage cut; migrate/clone carry it then); (b) pull it back into stream 4's remediation. | Ruling recorded; stream-20 spec row named if (a). | OPEN-Q |
| R2.5 | F-25 W5 wave-gate validity ("G13 families green" vs missing G13 fixtures) | (a) rule the G13 fixture items (op-for-op parity table, error-identity table, cross-encoding parity) = W7 parity-gate scope; §9 "discharged" + the W5 done-when text corrected UNDER THIS RULING; W5 exit stands conditional on W7 delivering them; (b) reopen W5's gate now: build the G13 fixture families as remediation before any W7 work. | Ruling recorded; if (a): text corrected under ruling + W7 plan row amended; if (b): fixtures built + green. | OPEN-Q |

## Part 3 — Defect and gap rows (spec already clear; authorization to execute)

Default direction per register rule 3: implementation conforms to spec.
One batch authorization question covers execution; every row still
closes individually with its own evidence.

| Row | Finding | Work (fixture-before-fix) | Acceptance criterion | Status |
|---|---|---|---|---|
| R3.1 | F-20 M3 malformed vp silently ignored | Fixture first: nested [vp] at M3 → expect CXER5021 loud refusal (spec §6.1 text is unambiguous). Then fix sx_m3_vp_text option-none path to refuse, matching the phase=present lane. | New test red→green; both M3 and phase=present lanes pinned. | AUTH-PENDING |
| R3.2 | F-23 CXER5013/5016 (+5015) untested | Tests: attach to unknown/ambiguous mount → 5013; bad ::bytes image + ast_bin decode failure → 5016; an internal-fault lane for 5015 if constructible without mocks. | Each code has at least one wire-level test. | AUTH-PENDING |
| R3.3 | F-24 authority presentation-fault lanes untested | Wire tests through the profile listener: floor-cannot-present 5021; malformed-vp 5021 (rides R3.1); inert-root [presented compiled=0 inert=K]; cross-tenant CXER4805; wire CXER4703 escalation. | Each lane pinned over a real daemon. | AUTH-PENDING |
| R3.4 | F-26 code-verified, regression-unguarded behaviors | Tests: revocations-cursor resume; feeds-die-with-connection; deleted-replay body-absence (strengthen the weak assert); alias-retract shape; open-posture CXER5022; PEP-before-token-gate ordering; peer wrong-DID pin; origin-folds-own-journal; rate retry-after on the wire. | Each behavior pinned. | AUTH-PENDING |
| R3.5 | F-21 feed shape-acceptance quirks | Cutover posture (no dual-accept): multi-scalar [planes] refused loudly (or all scalars honored — whichever §5.2 says; if §5.2 is silent, this row escalates to a letter before code); name= on revocations cursor refused; stale comment corrected. | Off-spec inputs refuse loudly; tests pin. | AUTH-PENDING |
| R3.6 | F-22 F3 re-advert direct-push missing | MAKE THE SPEC TRUE (register rule 3): implement the direct advert push from the config-reload verb handler alongside the sweeper watch; test pins immediate re-advert on the reloading listener. (Reverse option — truing §7a.1 to sweeper-only — would be a spec edit to match a shortfall; not proposed.) | Direct push implemented + pinned; sweeper lane unchanged. | AUTH-PENDING |
| R3.7 | F-9 G18 --strict unwired | Wire scripts/cxer_registry_report.sh --strict into TEST_TARGETS (exits 0 today). Synthetic-violation check: an unregistered CXER in a probe branch fails it. | Gate in TEST_TARGETS; red-on-synthetic verified. | AUTH-PENDING |
| R3.8 | F-15 extraction-gate floor + 3 uncovered cases | Assert a case-count floor in the Make recipe (n_cases >= recorded); cover ch-005/cmp-005/sd-006 in a lane (probe sections or CLI); document the 5 md ABI-lane exclusions as intentional with the CLI-lane cross-reference. | Floor asserts; 3 cases compared somewhere; vacuous-pass probe fails. | AUTH-PENDING |
| R3.9 | F-16 CX_BLESS=epoch armed | Disarm: epoch-bless paths refuse unless an explicit build-time flag (-d cx_epoch_bless) is set; normal builds cannot bulk-bless. | Env var alone no longer blesses; test pins refusal. | AUTH-PENDING |
| R3.10 | F-17 ring-gate C-edge gaps | Widen the lane: relative ../<sibling> includes, @VMODROOT/../vcx/<sibling> forms, raw .c/.h scanning; narrow c_edge_allowed to the two exact known edges; add arrow/transport (and cmd_data/cli platform-free) lanes. Red-on-synthetic for each new class. | All probe bypasses from the audit now fail the gate. | AUTH-PENDING |
| R3.11 | F-18 profile-binary corpus sample | Add a corpus sample lane through the cli and embed BINARIES (the I2 CLI-lane precedent), sized for CI budget; tracker issue for full-corpus-through-binary if the sample stays green. | Sample lane in the profile gate; failure demonstrably possible (synthetic probe). | AUTH-PENDING |
| R3.12 | F-19 thrown-error auto-pass hole (inherited class) | Scope honestly: this is the historical #404-#407 class across THREE lanes now. Fixture-first repair in profile_gate.v + the two code_eval lanes: a thrown error only passes an out-err case when the code matches. Risk: may surface latent mismatches — each surfaced case triages as fixture-or-code under fixture-before-fix. Also: stop discarding cmodule_gate. | Thrown-vs-expected mismatch fails all three lanes; surfaced cases triaged. | AUTH-PENDING |
| R3.13 | F-27 I3 census off-by-one; F-28 I2 proof-claim; F-29 "standing" label | Ledger corrections (process docs): each corrected in place with a dated correction note citing this register. | Corrections landed. | AUTH-PENDING |
| R3.14 | F-30 cosmetic spec/impl deltas | Each is a spec-vs-impl divergence → per register rule 3 the default is conform-the-impl: drop the extra request= attr from [erase-result] (or owner rules to spec it); move the G8 group-from refusal pin into the corpus; emit generation= as the spec'd attr (keep child during migration? NO — cutover rule: attr only). Any row where the owner prefers the impl's shape escalates to a letter. | Impl matches spec text exactly; pins updated. | AUTH-PENDING |
| R3.15 | I5-s4 auditor's unverifiable externals | Verification pass in the two external repos (console conform §13b, web-client /3 lane) — re-run their gates, record results here. | Results recorded (green or filed). | AUTH-PENDING |

## Part 4 — Structural enforcement + resumption

| Row | Item | Question / action | Status |
|---|---|---|---|
| R4.1 | Mechanical spec-freeze gate | (a) repo gate (pre-commit + TEST_TARGETS lane): any commit touching normative spec paths (spec/03-approved/**, working feature specs) TOGETHER WITH implementation paths hard-fails unless the commit message carries a ruling token (RULED:<row/letter/date>) that matches a recorded ruling in the ledger/register; ledgers (spec/02-working/partition_*) exempt; (b) rules-only, no mechanical gate. | OPEN-Q |
| R4.2 | Rulings-before-edits protocol | Standing: every ruling is COMMITTED (ledger/register) before the work it authorizes begins; same-commit recording is a violation by definition. Already memorialized in standing memory; register rule 5 applies it here. | STANDING |
| R4.3 | Independent re-audit gate | After Parts 1–3 close: a fresh adversarial verification pass (same method as this audit — agents that did not do the remediation) over every CLOSED row's evidence + a full make test wave gate. Nothing resumes before it reports clean. | PENDING PARTS 1–3 |
| R4.4 | Resumption ruling (R-final) | Owner rules whether W7 resumes, and under what scope, ONLY after R4.3 reports. No pre-commitment. | PENDING R4.3 |
| R4.5 | Durability | Push impl/I5-stream4-xsp-store (audit + register commits) to origin so the record survives the machine. | OPEN-Q (owner: push now (a) / at next batch (b)) |

**Wave-gate note.** W2–W6 wave gates were claimed under the now-broken
process. The audit found their TECHNICAL claims sound where verifiable
(no weakened tests, epoch intact, gRPC byte-stability true) with the
exceptions carried in rows R2.5 (W5 done-when) and R3.x (coverage). The
R4.3 re-audit + full gate re-run is the compensating control: every wave
gate's executable portion re-runs before resumption.
