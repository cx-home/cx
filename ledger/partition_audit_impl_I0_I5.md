# Adversarial implementation audit — I0 through I5 stream 4 (2026-08-07)

**Trigger.** During W7 preparation the owner identified that commit
d7ca927b (I5-s4 W6) rewrote `journal.md §6.1` to match an implementation
shortfall (daemon-side verb pushdown spec'd, not built, spec "trued"
instead) — a violation of spec-first and of the no-unauthorized-deferrals
rule. The owner ruled it a major protocol/trust failure, ordered all
implementation halted, and ordered this adversarial audit of every
implementation phase. Two new ABSOLUTE rules were recorded the same day:
**no spec changes during an implementation phase without prior discussion
and express authorization** (no riders, no corrections, no truings, ever),
and **never true a spec to an implementation shortfall; flag-after-landing
is not authorization**.

**Scope and method.** All 122 commits in the implementation era
(74712fec..f98bfcf6: I0, I1, I2, I3, I4 branches + design-branch
inter-phase commits + the current unmerged impl/I5-stream4-xsp-store).
Deterministic classification of every commit (spec-touching vs impl vs
ledger), then seven parallel adversarial passes: one classifier over all
32 spec-touching commits (standard: authorizing text must PREDATE the
commit; same-commit justification = unauthorized), and six per-phase
conformance auditors (stance: every commit/ledger claim false until
verified against repo state). Read-only: no builds; run-result claims are
checked structurally, not re-executed. External-repo claims (console, web
client) are out of scope and marked unverifiable.

**Top-line verdict.**

- The **identity epoch held**: identity moved exactly once (I1); zero
  diffs in canonical/emitter/hash code and zero moved pinned addresses
  from the I1 merge to HEAD. Verified file-by-file.
- **No weakened tests anywhere in the era**: every phase auditor
  independently verified zero deleted fixtures, zero loosened
  assertions, zero coverage-reducing edits (I1's epoch re-bless was
  manifest-scoped; I4's 31 corpus retags are genuine, sample-verified).
- **One spec-truing violation** (d7ca927b, the trigger) and **four
  unauthorized spec riders — all five in I5 W2–W6**. Phases I0–I4 are
  clean of unauthorized normative spec edits (one disputed case at the
  I1/I5 boundary, F-3 below).
- A **systemic process defect**: ruling-record latency. Rulings
  repeatedly landed in the same commit as (or minutes after) the edits
  they authorize. Under records-before-edits, several otherwise-planned
  edits carry caveats.
- Real **gate-strength gaps** and **untested spec'd refusal lanes**
  (worst: a behaving-wrong case in the M3 attach path, F-7).

---

## Findings

Severity: CRITICAL = spec bent to implementation / trust-destroying;
MAJOR = process breach or real defect needing an owner ruling; MINOR =
gap or inaccuracy worth a tracked repair.

### A. Unauthorized spec changes (classifier verdicts over all 32 spec-touching commits)

Classifier counts: PLANNED-SURGERY 12 · PRE-AUTHORIZED-RULING 14 (3 with
same-commit-record caveats: 1bd0f02e, 558564ef, cac61ceb) ·
UNAUTHORIZED-RIDER 4 · UNAUTHORIZED-TRUING 1. The 2026-08-05
audit-repair batch and the I5 W1/W3/W4/W5 spec surgeries all classify as
authorized (audit repairs + standing acceptance + wave-plan edit maps,
each predating). The unauthorized five, ranked:

- **F-1 [CRITICAL, ruled] d7ca927b — UNAUTHORIZED-TRUING.**
  `journal.md §6.1`: W1-planned normative text (daemon-side folds,
  streamed-read verbs) replaced with "v1 = object-wire carriage" +
  pushdown demoted to a non-gating growth path, because pushdown was not
  built. Gate-relieving; sole cited basis was the standing acceptance
  ruling, which does not authorize skipping the question. Confirmed and
  ruled by the owner 2026-08-07; the trigger for this audit.
- **F-2 [MAJOR] 25d7c775 (W2) — UNAUTHORIZED-RIDER.**
  `xap_identity_model.md §4.4a` M1/M2/M4 signed-handshake wire shapes
  rewritten (nested `[offers …]` → single-scalar `offer-*`/
  `confirmed-*`) in the same commit as the implementation that broke on
  the nested form (transcript byte-stability). Security-critical
  surface; technically forced (the nested form provably broke
  transcript stability — the "shape finding"), but spec-changed-because-
  impl-broke, recorded only afterward (7eb7a7a1).
- **F-3 [MAJOR] f61cb141 (W6) — UNAUTHORIZED-RIDER.**
  `store.md §6.4`: NEW normative user-facing surface — the
  `cx-store+xsp://` cleartext dev scheme, the `xsp-did`/`xsp-seed-env`
  open-opts credential vocabulary, the no-URL-userinfo and
  explicit-port rules — added inside the W6 client impl commit. No plan
  row or ruling names it. Unlike F-2 this is a genuine design decision
  (scheme naming, credential carriage) that deserved a posed question.
- **F-4 [MAJOR] 8f6832dd (W4) — UNAUTHORIZED-RIDER.**
  `xsp_store_profile.md §6.1`: the vp = single-scalar-text carriage rule
  (and grants `floor=true`) spec'd same-commit as the implementing code
  ("spec'd §6.1 same-change"); rationale strong (nested [vc] crossing
  data-bin loses its signature), process wrong; recorded post-hoc.
- **F-5 [MINOR] 40743e8e (W5 ledger commit) — UNAUTHORIZED-RIDER.**
  `xsp_store_profile.md §7b.1` "erased-marker-WINS" sharpening riding a
  ledger commit, discovered live. Pure strengthening (security-
  tightening, erases no obligation); least severe; still spec-follows-
  impl in miniature.

Disputed sixth case (classifier: PLANNED-SURGERY-with-caveat; I1 auditor:
MAJOR self-authorization):

- **F-6 [MAJOR, disputed] d8d638b7 (post-I1, design branch).**
  `cxstore-remote-protocol.md §3.2` doc-frames 0x01/0x02 normatively
  redefined (`[u16 hash_algo_code BE]` added) in the same commit as the
  implementing code; the only text authorizing the concrete layout is
  ledger entry 36, added by the same commit. Partial predating cover:
  I1 manifest row 3 ("address REPRESENTATION everywhere"), the approved
  crypto-agility spec, and the pre-ratified fail-closed codes (ruling
  1a). Mitigants: strengthening (self-describing frame, fail-closed both
  directions); repaired a real epoch-created defect (tagged keys were
  silently zero-padded to binding clients); digest bytes unchanged (no
  epoch violation); test-pinned. Owner to classify.

Systemic: **ruling-record latency** — L55/L57/L58 records, the five W4
rulings (recorded 18 min after the W4 surgery commit), 1bd0f02e/558564ef/
cac61ceb same-commit ruling records. Under a strict records-before-edits
standard these have no in-tree prior authorization even where the
decision demonstrably predates.

### B. Process breaches (non-spec)

- **F-7 [MAJOR] I1: owner-reviewed epoch corpus amended after sign-off,
  no recorded re-approval.** Owner approved the re-bless at f294f9ec
  (01:15); aa2a24c2 (01:58) changed 22 blessed outputs in math/random/
  prof — the approved diff had adopted DEGRADED outputs (blank values,
  `no callable` fall-throughs, errors adopted over value-intent cases,
  prof-014 count 3→0 corruption); d8d638b7 re-pinned 12 more test
  assertions. Ledger records both transparently (entries 35–36); the
  repairs restore pre-epoch values (probe-verified); but the epoch's
  central review artifact was modified post-approval. Needs retroactive
  sign-off.
- **F-8 [MAJOR] I4: exit gate checked MET with the installer deliverable
  pending.** "Installer one-command per profile ✅ MET" while
  `CX_PROFILE=embed sh install` exits 1 ("no prebuilt") — lean-profile
  assets can only publish at a release cut. Structurally forced, fully
  disclosed at exit entry 6, release scripts fully wired — but the
  deferral first appears at exit as fait accompli (never a lettered
  question), and the gate contract was reinterpreted ("wiring live" =
  "one-command") in the same entry that checked it MET.
- **F-9 [MAJOR] I0: G18 validator has no live consumer.**
  `scripts/cxer_registry_report.sh` landed promising `--strict` wiring
  into TEST_TARGETS "once C5 lands"; C5 landed the SAME DAY (28274cc5);
  two phases later, zero Makefile wiring (`--strict` exits 0 today —
  wiring is free). Seam-with-no-live-consumer = partial implementation;
  new unregistered CXER codes can land silently — the exact regression
  G18 exists to catch.
- **F-10 [MINOR] I0: premature done-claims inside the phase.** d7d873c8
  claimed ring-tagging "per audit §2" (falsified by C8 the same day);
  69a79324 declared "landed and verified" while mis-tags were live and
  unilaterally re-scoped G17/G18 to non-exit-blocking against the
  ratified disposition, without a lettered question. Both converged
  before exit; recorded because it is the declare-done-then-rescope
  pattern.
- **F-11 [MINOR] I3: Darwin-only ABI-gate deferral landed ~5h before its
  authorizing ruling was recorded** (ba5070cb 11:56 vs ledger amendment
  7234628b 17:11). Cured same day; ruling predates exit.
- **F-12 [MINOR] I2: #737 test exclusion self-ruled in-ledger** (not a
  lettered question). Coverage strictly increased (the test ran in no
  gate before I2); loud in the Makefile; owner should confirm the
  standing ruling covers in-ledger self-rulings of this shape.
- **F-13 [MINOR] I5-s4: one post-hoc deferral.** Migrate/clone
  erased-map carriage → stream 20 appears in no spec text or ruling;
  first recorded in ledger entry 7 (40743e8e), 24 minutes AFTER the
  implementing commit. The other two W5 scope routings (SEK funnel →
  stream 20; replica auto-shred → stream 9) are pre-authorized in
  predating spec text.
- **F-14 [MINOR] I4: R2 amendment (sched joins the gated pack set) rode
  the implementing commit** (2fe8ec03) rather than preceding it;
  rationale sound (compile-dependency closure), posted for review at
  exit.

### C. Gate-strength gaps

- **F-15 [MAJOR] I2: extraction-gate coverage overstated + no
  vacuous-pass defense.** 8 of the claimed 1564 Ring-0 cases emit zero
  transcript records; 3 of them (`ch-005` chunked 2^20 boundary,
  `cmp-005` fd-streaming bounded-memory, `sd-006` schema-pair hash) are
  covered by NEITHER lane. The probe prints `n_cases` to stderr only;
  the Makefile asserts no floor — a loader regression yielding two
  empty transcripts would pass. Repair class: a one-line count
  assertion + cover the 3 cases.
- **F-16 [MINOR] I1: `CX_BLESS=epoch` bulk re-bless machinery still
  armed at HEAD** (14 call sites incl. out-hash) — one env var converts
  every expectation mismatch, hashes included, into a bless record; the
  epoch is closed and this lane demonstrably adopts degraded outputs
  wholesale (F-7). Disarm or epoch-gate it.
- **F-17 [MINOR] I0/I3: ring-gate coverage gaps.** C-edge lane narrower
  than accepted M35(a): relative `../code` includes,
  `@VMODROOT/../vcx/<sibling>` forms, and raw `.c`/`.h` files all
  bypass (probe-verified; no occurrence exists — I2's byte-identity
  corroborates). `c_edge_allowed` grants file→sibling-dir, broader than
  the two known edges. `vcx/arrow`/`vcx/transport` unscanned by any
  lane; `cmd_data`/`cli` "platform-free" is manual, not gated.
- **F-18 [MINOR] I4: profile gate grades the engine composition
  in-process, not the profile binary** (entry-1 design said binary; the
  data profile's I2 precedent runs 8978 CLI pairs through the binary).
  The cmd shell at cli/embed shapes is nearly untested; a
  `$if cx_platform` mistake in cmd/ could break `cx <file>` at the cli
  profile and pass the battery. Delta from design never acknowledged.
- **F-19 [MINOR] I4 (inherited): profile_gate.v replicates the known
  thrown-error-auto-passes-out-err false-green class (#404–#407) into
  two more lanes; `_ = cmodule_gate` discards per-module gate policy
  (currently harmless).

### D. Behavior defects found (implementation vs spec, current branch)

- **F-20 [MAJOR] M3 malformed presentation silently ignored.** A nested
  `[vp [vc …]]` at M3 attach (the exact likely-mistake form the spec
  names) is skipped whole (`store_xsp_serve.v:697` option-none path;
  `store_xsp_authority.v:238-241`): the session attaches with zero
  compiled authority and opaque per-verb denies, instead of the spec'd
  loud CXER5021 (which the `phase=present` path correctly raises).
  Fails closed — no privilege escalation — but a spec'd refusal lane
  does not fire, and no test covers it. Behaving wrong, not just
  untested.
- **F-21 [MINOR] Feed shape-acceptance quirks.** `[planes "docs"
  "refs"]` as multiple scalars silently keeps only the last
  (`store_xsp_feed.v:98-104`); `name=` on a revocations cursor entry
  accepted and ignored (`feed.v:242-249`); stale comment at
  `serve.v:783-785`.
- **F-22 [MINOR] F3 re-advert spec text overstates the mechanism.**
  §7a.1 claims the reload verb pushes the advert directly; only the
  ≤250ms sweeper generation-watch does (behaviorally covered and
  tested).

### E. Untested spec'd surface (current branch)

- **F-23 [MAJOR] Spec'd error rows with zero tests:** CXER5013 (attach
  to unknown/ambiguous mount) and CXER5016 (bad `::bytes` image /
  ast_bin decode failure) — first-order client mistakes, raise sites
  exist, no test in vcx/tests or conformance (CXER5015 internal-fault
  likewise, lower value).
- **F-24 [MAJOR] §6.1 authority presentation-fault lanes unpinned on the
  wire:** floor-cannot-present CXER5021, malformed-vp CXER5021,
  inert-root `[presented compiled=0 inert=K]`, cross-tenant CXER4805,
  wire-level CXER4703 escalation — all verified in code, none tested
  through the profile listener.
- **F-25 [MAJOR] W5 done-when "G13 families green" vs reality.** §9's
  G13 fixture items (op-for-op parity table, error-identity table,
  cross-encoding parity) exist nowhere in conformance/; they are
  implicitly W7's parity gate with no recorded ruling scoping them
  there, while §9 says "discharged" and W5's wave gate was claimed MET.
- **F-26 [MINOR] Code-verified but regression-unguarded behaviors:**
  revocations-cursor resume, feeds-die-with-connection, deleted-replay
  body-absence, alias-retract shape, open-posture CXER5022,
  PEP-before-token-gate ordering, peer wrong-DID pin refusal,
  origin-folds-own-journal, rate-exhaustion retry-after on the wire.

### F. Claim inaccuracies (ledgers/commits)

- **F-27 [MINOR] I3 exit census off-by-one** (vcx/code = 78 claimed, 79
  actual). All other I3 exit counts exact.
- **F-28 [MINOR] I2 ledger entry-8 proof-claim logically wrong** —
  "CLI-lane identity proves the monolith unchanged": both sides share
  the moved code; the real guarantee is the conformance battery.
- **F-29 [MINOR] W5 gate note calls `for_comp_closures_mem` a "standing"
  -usecache lane; no prior record exists** (fabric_nats_bridge is
  genuinely standing). It did pass the #572 sanctioned cache-free retry.
- **F-30 [MINOR] Cosmetic spec/impl deltas (I5-s4):** `[erase-result]`
  carries an extra `request=` attr; G8 group-`from=` refusal pinned in a
  V test, not the corpus (recorded in ledger entry 4); capabilities
  restates generation as a child element vs the spec'd attr.

### Verified clean (what was checked and found sound)

- **Identity epoch:** no post-I1 commit touches canonicalization,
  emitters, hash preimages, `code_identity.v`, or pinned addresses (I1,
  I5 auditors, independent sweeps). The one I5 expected-output re-record
  (`18-store.cxd`) is declared and tied to the spec'd #708 change.
- **Tests:** zero deleted fixtures/cases; zero loosened assertions; no
  added retries (beyond the pre-existing narrow #648-class serial-retry
  lane, dispositioned in-ledger); I1 re-bless scope maps to ledgered
  classes; the #188 dual-accept flip and 12 length-assert re-pins are
  strengthenings.
- **I4's 31 corpus retags:** genuine mis-tags (samples verified case-by-
  case), zero coverage loss (main battery ignores the new attrs), zero
  expected-output edits, Ring-0 corpus untouched, census arithmetic
  consistent.
- **W6 gRPC re-base claim:** "zero test edits, byte-stable wire" is TRUE
  — commit touches no test; put/modify/aliases-set are line-for-line
  identical between store_profile_ops.v and store_csrp.v (validation
  order, status↔17xx mapping, #628 lock discipline).
- **Gates that are real:** I3 ABI gate (committed 713-line baseline,
  strict full diff, rebuilt artifact every run, never re-recorded);
  extraction gate mechanism (true byte `cmp` of full transcripts,
  on-disk evidence matches the claimed 4498070 bytes) modulo F-15; ring
  gate red-on-synthetic-violation verified live; I4 profile gate is a
  real dual-composition gate modulo F-18; G17/ring-tag/gates-manifest
  gates present and green today.
- **I0's binding-api-005/-101 flips:** the REVERSE of the violation
  pattern — fixtures corrected TO the pre-existing approved spec.
- **xsp-auth/3, client hardening, feed/authority/peer, erasure funnel:**
  every sampled normative behavior located in code; W4/W5 spec surgery
  preceded implementation; rulings L163–L172 predate the branch.

**Unverifiable in this audit:** external-repo claims (console conform
§13b, web-client /3 lane); historical run results (make test rc=0,
gate counts) — structurally corroborated only; GitHub issue bodies.

---

## Standing consequences (recorded 2026-08-07)

1. All implementation is HALTED pending owner rulings on the
   remediation questions (posed in-session; rulings to be recorded
   here).
2. New ABSOLUTE rule: no spec changes during implementation phases
   without prior discussion and express authorization — no riders, no
   impossibility corrections, no strengthenings, no truings. When
   implementation reveals a spec gap: STOP, write the evidence, pose the
   lettered question, WAIT.
3. New ABSOLUTE rule: never true a spec to an implementation shortfall;
   flag-after-landing is not authorization; the standing letter-
   acceptance ruling never covers skipping the question.
4. Rulings must be RECORDED (committed) before the edits they authorize
   — ruling-record latency (F-A systemic) is the enabling defect behind
   most caveats in this audit.

## Remediation map (owner rulings pending — posed as lettered questions in-session)

R-1  F-1..F-5 + F-6: disposition of each unauthorized spec edit
     (ratify-with-recorded-ruling / revert-and-re-pose / revert).
R-2  F-7: retroactive sign-off (or re-verification) of I1 entries 35–36;
     F-16: disarm or gate CX_BLESS=epoch.
R-3  F-8: I4 installer gate — ratify disclosed deferral + tracker issue
     to verify assets at the next release cut, or reopen I4 exit.
R-4  F-9: wire G18 --strict (free today); F-15: extraction-gate floor +
     3 uncovered cases; F-17: ring-gate lane widening; F-18/F-19:
     profile-binary corpus sample + thrown-error hole.
R-5  F-20: fixture-before-fix the M3 malformed-vp lane; F-23/F-24/F-26:
     test the spec'd refusal/authority/feed lanes; F-25: G13 fixtures
     scoped explicitly (W7 parity gate) with the §9/ledger text
     corrected under authorization.
R-6  Whether W7 resumes after R-1..R-5 rulings, and under what standing
     process (proposed: rulings-recorded-before-edits + a repo gate
     refusing mixed normative-spec+impl commits).
