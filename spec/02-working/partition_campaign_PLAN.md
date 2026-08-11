# Partition campaign plan — #651 architecture review + #516 CX partition

**Status:** working plan (not normative — the spec remains the only normative source).
**Issues:** #651 (future-architecture review), #516 (v-next scope proposal; headline = the CX partition, #143 rings).
**Started:** 2026-08-04.

## Ground rules (owner directives, 2026-08-04)

1. **The current release line stays a stable maintenance branch for downstream
   consumers.** Campaign work never lands on it directly.
2. **One campaign branch for both issues** — `design/651-516-partition`, cut
   from the release line head at campaign start (`d4e53643`). It holds this
   master plan and ALL spec work for both issues: #651 spec amendments
   (direction notes, lettered rulings), the partition spec, and the evidence
   (import-edge audit, corpus ring-tagging). Verdicts themselves live as
   tracker comments on #651. **Implementation branches are cut off this
   branch** once the gates below pass — never off the release line directly.
3. **Merge target is decided at gate time**, not now: the campaign branch
   merges into whichever `release/X.Y.0` is the current integration line when
   its gate passes. Nothing in this campaign assumes which release ships it.
4. **HARD GATE — no implementation before the paperwork is complete:** all spec
   work and a phased implementation plan with gates, for BOTH issues, must be
   done before any implementation begins.
5. **NO UNAUTHORIZED DEFERRALS (owner directive 2026-08-04):** nothing is
   deferred or partially scoped without express owner authorization. Every
   deferral candidate surfaces as an explicit lettered question with
   trade-offs — never as a clause inside an accepted verdict. Sequencing
   behind a live consumer is allowed (standing rule); cutting scope is not.

## Evaluation criteria (owner directive 2026-08-04)

This campaign is likely the last foundational pass on CX before production
downstream consumers. Every verdict and G-decision is argued against these
criteria, in this order:

1. **First principles.** Argue from the problem and CX's own invariants
   (homoiconic value model, canonical identity, fail-loud, single surface —
   no dual-accept), never from incumbents' shapes or the reviewed document's
   authority. The document is input, not precedent.
2. **Long-term health of CX and its consumers.** A direction that helps this
   release but constrains the platform's decade is wrong. Consumer experience
   — one-command install, byte-stable identity, additive-only evolution — is
   part of platform health, not packaging gloss.
3. **Agent–principal symbiosis.** The north star: humans (principals) and
   agents operate on one typed semantic surface, with authority explicit,
   attenuable, and auditable (DID principals + capabilities, already live in
   XAP's identity model). Each verdict weighs whether the direction
   strengthens or muddies that symbiosis.
4. **Timely and marketable.** The result must yield artifacts an adopter can
   want *now* (the small data-format on-ramp) and a claim the market can
   repeat. Design purity that cannot be shipped or explained fails this
   criterion — as does marketability that borrows against criterion 2.

## Sequencing

#651 runs first; #516's partition spec consumes its verdicts (plus #37's
architecture review, which folds into the partition spec as its foundation
rather than running separately). Rationale: the #651 verdicts on the value
model (§10), XSP (§12), CSRP fold-in (§13), store topology (§14), and the
Layer 1–6 model determine where the #516 ring seams can legitimately cut.

## Phases and gates

### Phase 1 — #651 review

- Seam-first verdict order: §10, §12, §13, §14, layering — then §1–§9, §15,
  roadmap milestones.
- Every verdict records: accept/reject/defer + rationale + **ring assignment**
  (which ring owns it; what dependency contract accepting it implies) +
  **business value case** (below).
- **Business value case (owner directive 2026-08-04):** every ACCEPT must
  state the tangible, material outcome — the capability a consumer gains that
  they cannot approximate today — as concrete use cases and benefits. The bar
  is *revolutionary territory, not incremental*: if the honest case for a
  recommendation is "somewhat better than the status quo," that is evidence
  for REJECT or DEFER, not for a softer accept. Named use cases must be
  CX-generic (industry-recognizable workloads); **no specific downstream
  clients may be mentioned** — the sanitization gate applies to this campaign's
  documents and tracker comments exactly as it does everywhere else. A verdict
  whose business case cannot be written without naming a downstream consumer
  is not ready to be ruled.
- The Layer 1–6 ↔ Ring 0–3 reconciliation is written as its own verdict, in a
  form liftable into the partition spec's boundary table.
- Evidence gathered alongside: the vcx
  import-edge audit (module → proposed ring, current seam violations) and the
  conformance-corpus ring-tagging (which fixture families exercise Ring 0
  only — the future extraction gate corpus).
- Follow-up issues filed, one per accepted work stream.
- Owner G-questions from both issues batched into one memo: repo strategy
  (multi-repo vs monorepo-multi-artifact), Ring-0 CLI verb set, CSRP fold-in,
  `hash:`/`cap:` reference spelling, Track 3 riders.

**Gate G-A:** every document section has a recorded verdict with ring
assignment; accepted items mapped to existing spec language / open issues;
the owner memo is ruled.

### Phase 2 — #516 partition spec

`spec/02-working/` partition spec: ring boundaries as dependency contracts,
repo/artifact strategy per G-A ruling, build/release story per ring, migration
path (from the audit), conformance corpus as the cross-ring contract, #37
foldout as the foundation section.

**Gate G-B:** owner approval of the partition spec (user-only, G3-style).

### Phase 3 — phased implementation plan

Extraction order (Ring 0 first, strangler pattern), CI import/link gate
definitions, the byte-for-byte conformance gate for the extracted Ring 0,
rollback posture per phase.

**Gate G-C:** owner approval of the plan. Implementation begins only after
G-C, on its own branches, per the plan.

## Scope interpretation

"All spec work for both issues" = #651's direction amendments + #516's
partition spec and this plan. Per-stream working specs for #651 follow-up
issues (e.g. a query-algebra spec) belong to those issues and gate their own
implementations later. (Owner may pull them into this campaign's gate; not
assumed.)

## Work-stream issue map (filed 2026-08-05)

Streams 1–22 = #673–#694 (in order: 1→#673 … 22→#694) · hygiene batch =
#695 · consumability C1–C4 = #696–#699. Every issue carries gate rule 4(b).

## Consumability track (ruled 2026-08-05: post-gate sequencing)

Tooling/product streams that consume the partition's artifacts; sequenced
AFTER the spec gate (they don't block G-A→G-C), tracked here so nothing
silently drops:

- **C1 — Browser playground:** Ring-0-only wasm target (sidesteps the
  mbedtls/emcc blocker), shareable content-addressed snippets.
- **C2 — Schema inference:** `cx schema infer` over JSON/CSV/XML corpora +
  XSD→CX catalog (#288 promoted from Track 3).
- **C3 — Model-facing docs pack:** llms.txt-style grammar summary, idiom
  corpus, error→fix examples; compounds with stream 18.
- **C4 — Package-manager distribution:** Ring 0 bindings on pip/npm/brew/
  cargo; early Ring 3, pulled forward.
- **Windows support tier:** express ruling at partition-spec time, beside the
  build/release platform matrix (owner 2026-08-05).
- **Flags:** GitHub linguist registration (timing-bound on public usage);
  published benchmark page (marketing, harnesses exist).

## Gate G-A: PASSED 2026-08-05

All document sections ruled (tracker comments on #651); 22 spec streams +
hygiene + consumability filed (#673–#699); G-decisions ruled on #516:
**repo strategy = monorepo multi-artifact; Ring-0 tool = data-only verb
subset; M5 proof domain = commerce/order-fulfillment** (one worked example
across all stream specs). Phase 2 (partition spec) is open.

Adjacent (not gate-bound): #700 test-suite duration relief — maintenance-line
tooling, immediate; per-ring gates land with the partition as the structural
fix.

## Phase 2 status — GATE G-B PASSED 2026-08-05

Partition spec approved: `spec/02-working/cx_partition.md` (rings/packs/
profiles, import contracts, artifacts + §5.1 repo-split policy, lockstep
versioning, Windows tier-2, corpus contract, compatibility promise +
archival guarantee, §12 bindings story). Phase 3 drafted:
`partition_impl_PLAN.md` — spec waves S0–S4 (all 22 stream specs inside the
gate, dependency-ordered) + implementation phases I0–I6 (seams → identity
epoch → Ring-0 extraction byte-for-byte → Ring 1/2 split → profiles →
streams → M5 proof). **GATE G-C PASSED 2026-08-05.** Execution order: spec waves S0–S4 (owner approval per spec), then implementation phases I0–I6.

## Decision log

| Date | Decision | Where it binds |
|---|---|---|
| 2026-08-11 | **BUG-DRAWDOWN SCHEDULING RULED (owner "1a, 2a"):** (1a) the unpinned open-bug residue (#705 #736 #738 #739 #740 #760 #771 #774 #777 #778 + the #704 RE-PIN — its "fix at I1/I2" landing lapsed when both phases closed without it — + #508 as an external-blocked verify-or-close rider) forms ONE item-4-style defect batch on its own branch BETWEEN item-5 streams #679 and #680; the march order becomes … → #679 → **defect-batch-mid5** → #680 → …; batch discipline = the item-4 pattern (every issue closed with evidence or re-pinned to a NAMED later landing, one exit gate GATE-RC=0). (2a) the **#775 V-runtime campaign runs INTERLEAVED once the item-5 back half opens** (the #692–#688 window; own worktree per its plan, so it never blocks a stream gate) — deliberately overlapping the two biggest pinned buckets (#775's ~9 runtime bugs + the back half's ~7 stream-pinned bugs) so the open-bug count bends down in one window; #742/#743 land before the adoption track needs the embedder surface. | March order (item 5); #704; #508; #775; the ~12-bug residue. |
| 2026-08-05 | **OWNER RULINGS BATCH — the audit's four owner decisions closed (1c/2a/3b/4b/5b; full ladders were on the record per the new ledger rule).** **L83 → (c)** (see the closed letter below; the last I1 blocker). **C10 → (a):** the pre-campaign #516 comment sanitized + the `downstream:`-prefixed label renamed to the consumer-neutral form with its description cleared, and the sanitization gate gains a gh-metadata mode (labels + campaign-referenced issue bodies/comments; scheduled, not per-commit). **M41 → (b) BREACH:** the vessel/nautical domain vocabulary in the xap specs is ruled a consumer-workload proxy; rewritten CX-generically across the five working xap specs AND the four approved xap specs — hypothetical examples moved to the M5 commerce domain, factual validation/roadmap records abstracted domain-neutrally (never falsified: the reference instance's engineering facts survive without domain nouns; Appendix C's non-screen worked example re-told as a blind field-machine operator with every lexicon term intact). Artifact-identifier residue (`cx-home/xap-marine` repo path; the in-tree `packages/nmea0183` package) flagged to the owner separately — paths are artifacts, not prose. **M40 → (b):** counsel routing DEFERRED until the first production consumer in a GDPR-scope domain; the struck-leg design-intent note stands. **C11 → (b):** the verified-empty record is ACCEPTED; no retroactive reconstruction (on-demand per-letter reconstruction remains available). | Everything above; the xap spec set; the sanitization gate. |
| 2026-08-05 | **C11 EXTRACTION VERIFIED EMPTY; LEDGER RULE ADOPTED HENCEFORTH (audit C11).** The audit's (a) repair — extract letters 14–189's option texts from the authoring-session transcripts "while they survive" — was attempted and its premise FAILS on direct inspection: all 91 session transcripts survive (380 MB), but they contain NO per-letter (a)/(b)/(c) ladders — the batches were drafted as single-proposal analysis prose with alternatives argued inline (which is where the specs' rejected-alternative passages came from), so the un-recorded options never existed as text. The recoverable record therefore IS the specs' rejected-alternative prose + this decision log (= the audit's option (b), available on owner request, partial-at-best and labeled as reconstruction). **Adopted henceforth (the (a) repair's forward half): every letter recorded in this ledger from this date carries its full option ladder at recording time — the Phase-1 (L1–L10) format, proven in-tree** (the L83 reopen entry below is the first instance). The reviewability defect the audit named is thereby closed for all future letters and honestly documented as unrecoverable for 14–189. | Ground rule 5; every future letter batch. |
| 2026-08-05 | **OPEN LETTER — L83 REOPENED (audit M39; express owner ruling required BEFORE I1).** L83 (type identity = (element name, whole-schema content-hash)) was recorded as "additive" — misclassified: the hash basis is the campaign's own now-or-never class, moving to per-type subtree hashing later changes every type identity in multi-type documents, and the only guard today is a non-normative one-type-per-document RECOMMENDATION. Options: **(a) whole-schema FOREVER** — accept that all types in one schema document share the hash component and co-move on any edit; simplest, but forecloses per-type identity and multi-type schema docs churn spuriously; **(b) per-type subtree hashing NOW (at I1)** — finest identity, avoids the trap outright; costs new normative subtree-canonicalization machinery in the epoch's critical path; **(c) whole-schema + a NORMATIVE one-type-per-schema-document rule for identity-bearing schemas (RECOMMENDED)** — multi-type documents remain legal for validation but cannot anchor type identity; whole-schema ≡ subtree by construction, zero new hashing machinery, the trap is closed structurally, and per-type subtree hashing stays available later as a pure superset IF multi-type identity anchoring is ever wanted. Recommendation: (c) — it buys (b)'s safety at (a)'s cost, and it strengthens rather than replaces the existing recommendation the specs already carry. **RULED (c) BY THE OWNER 2026-08-05** (verified against the long-term-best bar with the caveat stated on the record: a later move to subtree hashing re-bases only NEW multi-type anchoring as a second basis — existing one-type pairs keep theirs; the invariant secured is no-cross-type-identity-churn, permanently, with zero machinery in the I1 critical path). Spec edits applied: the one-type-per-schema-document rule is NORMATIVE for identity-bearing schemas in semantic_value_model §3. **The last I1 blocker is closed — I1 is unblocked pending G-C-holder go.** | E2/L83 (semantic_value_model §3, shape_inference); the I1 manifest. |
| 2026-08-05 | **ERROR-BAND REGISTRY REPAIR EXECUTED (adversarial-audit C5 + M5 + n3; repair (a) under the standing ruling).** xap.md §8 amended IN PLACE: the never-registered `4850–4949` proposal becomes registered `4850–4889` (xap 4850–4879 incl. compose; xap-dist 4880–4889), **yielding 4890–4949**; similar's shipped `4900–4901` registered as an island; fabric registered `4920–4949`; **stream 3's band relocated `4902–4919` → `5070–5089`** (the "corrected" band had landed inside xap's allocation — the same defect class it was correcting; 18 codes don't fit the freed 4890–4899, so a fresh block above sched); **stream 20's store surface moved `1143+` → `1144–1149`** with shipped-unregistered `CXER1143 E_STORE_OPEN_CONFLICT` documented in store.md §13; **journal `4617–4649` sub-partitioned** stream 20 `4617–4639` / stream 21 `4640–4649` (first code named: `CXER4640 E_JOURNAL_FOLD_ID_MISMATCH`); §9.6 rows landed/extended: core `0001–0009` (0003 RE2 shim), store `1100–1149` sparse, ft `→1205`, jsonschema `1610–1619` NEW, CSRP `→1712`, random `→1906`, io `→3412`, term `3450–3459` NEW; stream 10's prior "shrink-from-a-third-spec" registry text corrected to the amendment-in-place model (§9.6 append-only invariant). Verified: the hardened G18 report's two-owner detector confirms the live_modes/xap and erasure/journal partial intersections resolve; remaining unregistered set = the phantom `CXER0014` LSP-hover citation (shipped-code fix queued). | governance.md §9.6; xap.md §8; store.md §13; similar.md §7; live_modes.md §2; erasure_compliance.md §9; schema_event_evolution.md; cross_stream_coordination.md §5. |
| 2026-08-05 | **Stream 3 mandate += external-source adapter contract** (guarantee ladder CDC/watch/poll, cursor mapping, ingest-identity rules, adapter-is-only-client posture). Verified unspec'd before ruling; recorded on #675. | Stream 3 spec (wave S3). |
| 2026-08-04 | **XSP has no human-readable wire form** (owner letter (a)). Binary framing stays the only wire encoding; the `[frame …]` CX-value projection is the normative logical frame; human readability = CX text emit of that element, plus a future `cx xsp decode` tooling verb when demand appears. | Input to the #651 §12 verdict; eventual xsp.md direction note. |
| 2026-08-04 | **Ring 0/1 seam = representation vs. interpretation.** The parser (full grammar including program forms), node kinds, canonical identity, codecs, emitters, diff, schema/validate sit in Ring 0; evaluation, purity, stdlib sit in Ring 1. The grammar is never forked — cxparse unification ("one engine") is the partition's foundation. Canonical hashes must be product-independent. The data product differentiates by link surface + data-only CLI verbs + an opt-in "data profile" validation (post-parse node-kind predicate, not a parser mode). | Partition spec boundary section; feeds #516 G-decision (c). |
| 2026-08-04 | **Branch/merge model** as in Ground rules above (maintenance line stable; ONE campaign branch `design/651-516-partition` for all plan+spec work on both issues, superseding a briefly-created two-branch split the same day; implementation branches later cut off the campaign branch; merge target at gate time; hard spec-before-implementation gate). | This campaign. |
| 2026-08-04 | **Verdict sequencing seam-first** (§10, §12, §13, §14, layering before §4–§8), each verdict carrying a ring assignment. | Phase 1 execution. |
| 2026-08-04 | **Evaluation criteria codified** (section above): first principles; long-term health of CX + consumers; agent–principal symbiosis as north star; timely and marketable. Likely the last foundational pass before production downstream consumers — depth over speed. | Every verdict and G-decision in this campaign. |
| 2026-08-04 | **§10 RULED: ACCEPT with content-only-identity amendment** (L1a intrinsic envelope rejected — three attachment lanes normative; L2a type = element name + schema content-hash; L3a expression identity = Tier-1 of quoted tree; L4a version = ref-history position, no version fields on values). Extensions E1–E4 = one follow-up work stream. Posted: issue 651 comment 5186712253. | §10 verdict; E-stream spec; partition spec Ring-0 contract. |
| 2026-08-04 | **§12 RULED: L5a** — XSP generalizes additively on the v1 frame (negotiated features + payload vocabulary; spec splits generic-frame vs profiles when the store profile lands). No XSP/2 rewrite. | §12 verdict; XSP work stream. |
| 2026-08-04 | **§13 RULED: ACCEPT THE FOLD** (owner overruled the permanent-CSRP-adapter draft; nothing in production ⇒ no migration cost, and the store's parallel auth stack must die). XSP store profile = the store wire; internal consumers (remote client, journal #644, porcelain, fabric mounts) migrate; CSRP data plane retires at parity; HTTP keeps probes/metrics/pre-auth bootstrap only; gRPC stays an opt-in edge adapter; ONE authority model (DID + capabilities) across execution/events/store. | §13 verdict; store-profile work stream; partition spec Ring-2 contract. |
| 2026-08-04 | **§14 RULED: ACCEPT + L7a** — store = composition of shipped identities (no new machinery); computation identity = hash(Tier-2 fn, Tier-1 inputs, environment, capability-set) with environment MINIMAL + ADDITIVE (runtime version, builtin-set id, schema dialect), spec'd as a canonical CX value; host-dependence is a conformance bug, never an identity axis. Posted: 651 comment 5186932918. | §14 verdict; computation-identity work stream. |
| 2026-08-04 | **Layering RULED: ACCEPT + L8a** — rings = pure import contracts (DAG, not strict stack; Ring-2 component may import Ring 0 only); **packs** (stdlib units declaring caps + external deps, -d gate pattern) and **profiles** (minimal-embed / cli / platform artifact compositions) decide what ships. Ring1/2 line in code/: imports cxstore/protocols or serves ⇒ Ring 2. Posted: 651 comment 5187057899. SEAM-CRITICAL SET COMPLETE — #516 partition spec unblocked. | Layering verdict; partition spec normative core. |
| 2026-08-04 | **§1–§9/§15/milestones RULED — SECTION PASS COMPLETE** (L9a: effect proposals = opt-in propose mode at trust boundaries, direct effects stay default; L10a: consistency vocabulary = only what CX guarantees, declare-and-verify fail-loud, serializable cross-stream DEFERRED). M3 XSP/2 rejected as rewrite; M4 replication/offline deferred pending consumer; M5 proof domain accepted as post-extraction showcase. Posted: 651 comment 5187137263. Eight follow-up work streams identified for G-A. | Completes Phase 1 verdicts; G-A next. |
| 2026-08-04 | **DEFERRAL AUDIT RULED (window directive: no production dependencies yet — use the one-time strategic window):** bitemporal semantics ACCEPTED as stream; M4 distributed-store items ACCEPTED as design stream (M5 offline replica = consumer); cross-stream atomic command coordination ACCEPTED as design stream (compatible-with-replay mandate; doc §7's own example is two-subject atomic); gate scope = ALL stream specs inside the campaign gate, authored in dependency order, before ANY implementation. Work streams now 10 (+hygiene batch). Posted: 651 comment 5187207085. | Supersedes every embedded deferral in prior verdicts; Phase 2/3 scope. |
| 2026-08-04 | **WINDOW ADDITIONS RULED (streams 11–15):** (11) decimal/bigint as true semantic kinds (financial-data correctness; hash-affecting — now or never); (12) canonical-form warts sweep (incl. map-ordering tension canonical.md vs data-bin) — one-time re-ruling of identity-bearing rules; (13) grammar/lexicon final review (Unicode identifier policy, directive naming, hash:/cap: spelling); (14) conformance-corpus completeness audit vs every normative spec (corpus = the extraction + cross-binding contract); (15) namespace/domain permanence confirmation (cxhome.org URI participates in hashes). Licensing/distribution model flagged as business decision, taken offline. | Window streams; specs inside the gate per ruling 4(b). |
| 2026-08-04 | **GAP ADDITIONS RULED (streams 16–18 + audit mandate):** (16) shape/type inference over pipelines (#37 lean; re-rules the inherited schema-registry/returns=SchemaRef deferral — the mechanism behind the "typed" claim); (17) runtime representation ruled as direction (#37 reframing: homoiconic node surface + unboxed columnar data-in-flight, lazy node materialization; constrains C ABI + Ring 1 internals); (18) agent-tool projection (command defs → MCP/tool schemas as generated Ring 2 edge adapter, propose-mode approval built in); inherited spec deferrals (caps granularity C1, debug time-travel v2, Tier-2 index, xsp §5.4) batch-reviewed in stream 14's audit for express confirm-or-adopt. | Streams 16–18; stream 14 mandate. |
| 2026-08-04 | **FINAL WINDOW ADDITIONS RULED (streams 19–20 + mandates):** (19) crypto-agility — self-describing hash addresses (algorithm-tagged, multihash-style) for Tier-1/Tier-2 + signature-suite naming in provenance values; adopting a prefix costs nothing pre-production, re-hashing the world later is impossible; (20) erasure/compliance in the immutable substrate — crypto-shredding (per-subject keys), redactable journal entries (detached payloads, chains verify with payloads gone), tombstone semantics; "can't legally delete" is an adoption-killer in the target domains. Mandate edits: stream 12 += Unicode normalization policy for equality/strict-canonical; stream 13 += MIME types + file extensions. Window sweep complete — no further irreversibles identified. | Streams 19–20; stream 12/13 mandates. Roster: 20 streams + hygiene batch. |
| 2026-08-04 | **Stream 21 + mandates RULED:** (21) schema & event evolution — versioned folds/upcasting for journals (replay over v1 entries with v2 vocabulary), value-migration story for stored docs (inventory NOT-FOUND #6 promoted); mandate edits: stream 6 += idempotency semantics on command defs; streams 4/6 += budget/metering attenuation (grants with quantitative bounds — rate/count/spend); partition spec += compatibility-promise section (what 1.0 freezes: grammar, canonical bytes, data-bin, corpus, C ABI, wire). | Stream 21; stream 4/6 mandates; partition spec §. |
| 2026-08-04 | **Stream 22 + horizon mandates RULED:** (22) clean-room implementability — implementability audit + operational-semantics hardening of the evaluation core; explicit spec-quality bar = a conforming implementation buildable from spec/ + conformance/ alone (kills the reference-impl-becomes-spec trap). Mandates: stream 19 += post-quantum signature-suite slot; stream 13 += semantic-kind extension policy; compatibility promise += archival guarantee (canonical text CX = eternal preservation format). Business flags w/ licensing: stewardship succession, trademark/fork governance. | Stream 22; 13/19 mandates; partition spec §. |
| 2026-08-05 | **WAVE S4 EXITED — letters 155–189 ruled (a) under the standing ruling → ALL 22 STREAM SPECS DONE; SPEC AUTHORING (Part A) COMPLETE.** Four final specs: **stream 4** `xsp_store_profile.md` (the §13 CSRP fold made real — the XSP store profile becomes the store wire, generic-frame/profile spec split w/ zero wire change; **feature negotiation moved INTO the signed transcript, closing a downgrade-strip hole**; one authority model, the 4-provider stack retires; the D-XSP-c server↔server revocation channel = a subscription to the peer's revocations feed, no remote reach-in; bounds ride the VC chain as the 4th attenuation axis; lanes by role — ast_bin bodies, text envelopes, multihash binary; the gRPC-style 3-listener parity gate is the I5 retirement condition); **stream 9** `distributed_store.md` (**replica-local-stream ingestion needs no sequencer** — disjoint-aggregate composition; **merge-as-an-entry** keeps lineage linear while recording the join, the DAG refused w/ trade-offs; the ONE Ring-0 `[conflict subject/kind/base/ours/theirs/cas]` value unified across streams 9/10 w/ the enforcing/reporting agreement law; re-append refused on three grounds; bidirectional v1, fetch/pull split); **stream 10** `cross_stream_coordination.md` (**PRINCIPLED REJECTION of cross-stream atomic commit, DERIVED** — replay-safe 2PC degenerates into a saga, an in-doubt 2PC participant is the worst value shape; the mechanism IS the normative saga/escrow vocabulary: `[compensates]` clause, ordinary-value saga records, escrow allocations answer the cross-stream budget residual, compensation = an `:assertion` w/ the locator-triple link never a 5th taxonomy relation; entity-groups first-resort); **stream 20** `erasure_compliance.md` (three-tier key hierarchy KEK→**SEK (destroyable)**→DEK; **address covers PLAINTEXT** — ciphertext-address & hash-salting both rejected, the oracle neutralized by per-record nonce + pool isolation; **the detached-payload entry form is the sole I1 hash-affecting item** — `verify valid=true` with payloads gone; typed `[erased]` tombstone on the value channel; exhaustive derived-artifact reach via stream-21 fold-id shred-generations; legal hold = an enforced Lane-2 precondition blocking shred AND re-snapshot; the visible-count rule generalized here for streams 3/7/8/21). Defects #717–#720. **I1 manifest final contents:** streams 11/12/19/13/15 + E2 schema hash basis + Lane-1 `__cx_meta__` fix + `*`-head parse fix + quote lowering + journal ts-form (#712) + **the detached-payload entry form (#720)**. **CAMPAIGN MOVES TO IMPLEMENTATION: I0 (import gates + #686 ring tagging on the monolith, no code moves).** | Part A complete; I0 begins. |
| 2026-08-05 | **WAVE S3 EXITED — letters 122–154 ruled (a) under the standing ruling** (each verified against the long-term-best bar; three corrections applied under the proviso: the stream-7 error band moved to the verified-free CXER4990+ (the sweep's 4850+ is XAP-occupied); **stream 18's L139 AMENDS stream 6's finalized text — approvals bind the Tier-1 def-text address, Tier-2 rides for cache only** (Tier-2 never a trust input + `[effects]` outside the Tier-2 hash made the Tier-2 binding a replay hole); stream 3's directive spellings corrected to module verbs). Four specs finalized: **stream 7** `consistency_vocabulary.md` (closed atom lattice — prefix-consistent/at-seq-pinned/at-head-set-as-the-honest-CUT/linearizable-ref/read-your-writes/monotonic+gapless/at-least-once; `:exactly-once` permanently refused NAMING [idempotent]; `:serializable` refused NAMING stream 10; two attachment points w/ generation-bound pre-flight, NO def clause; conjunct lattice not a level ladder; F1–F8 register #714 — sharpest: journal `head` is a pure read of a handle-cached position; replica profile handed to stream 9); **stream 3** `live_modes.md` (the three modes = MODULE VERBS in `cx-stdlib/live` over QUOTED planar comprehensions — the single-surface rule survives, module qualification dissolves four name collisions; the equivalence quartet normative; ∂ streams never coalesce / materialize reads may; head-set cursors; source-order group stability forced by maintained≡recompute; three-way resume split onto shipped models; retention cover rule extended to registered materializations; **the owner's adapter contract:** declared closed guarantee ladder :complete-ordered/:coalesced-rescan/:snapshot-diff w/ wiring-time refusals, two-direction cursor mapping, the lowering-ladder ingest identity + stream-6 dedup keys, enforced single-writer exclusivity; CDC spec'd-now-additive w/ poll/watch v1 floor; **the store change feed formally required of stream 4**); **stream 18** `agent_tool_projection.md` (2025-06-18 MCP target; out-of-band approvals — elicitation a NON-GOAL (signing must not land on the agent); ONE descriptor model / two lossy adapters / the projection is Ring 0/1 PURE and derived-never-materialized; the field-mapping table w/ the lossy-downward rule (hints are courtesy, enforcement is at the effect point); [param-doc] + required summaries + the doc gate extended; **G15: SPEC ALL FIVE, retire none** + x-tier ring placement + #715); **stream 21** `schema_event_evolution.md` (payload version vocabulary + caller/Lane-2 upcasters at stream 8's pre-fold seam; **fold determinism widens to the quadruple** w/ chain-in-env + fold-id-carrying snapshots + the cover rule read as current-fold — closing a real data-loss path; migration = the representational FOURTH relation, never a correction; pure migrations are stream-5 computations, impure migrations FORCED OUT to stream-6 commands; `[schema-lineage]` Lane-2 claims w/ unique-path enforcement; the three-valued `compat?` predicate behind stream 16's repairs; tolerance = discovery-surfaces-only w/ visible skip counts; **wholly post-I1 additive**; #716). Defects #714–#716. **S4 OPENS** (streams 4 #676, 9 #681, 10 #682, 20 #692 — the final wave). | S3 exit; stream-4 inherits the store-feed requirement + ∂ wire frames + bounds carriage + vocabulary negotiation; streams 9/10/20 inherit their named seams. |
| 2026-08-05 | **WAVE S2 EXITED — letters 93–121 ruled (a) under the standing ruling** (each verified against the long-term-best bar). Four specs finalized: **stream 2** `planar_algebra.md` (canonical PLAN FORM as the additional identity tier L79 anticipated — cache keys share across equivalent spellings; γ = hash-partition + `$group` implemented (COUNT-only today, #711); six-point LOUD membership test — ambient document and order-observers excluded, hints erased; equivalences w/ the ERR-TOTALITY rule (σ-pushdown only for total predicates — fail-loud fidelity outranks the optimizer); source refs = E3's closed versionable scope, FLAT provenance-bearing results; windows OUT of v1 (future = clauses, never heads); quoted-planar store queries w/ dual-layer authorization on the purity theorem; the ONE traversal contract discharging L62a; the ∂ delta vocabulary authored once for streams 3/4); **stream 5** `computation_identity.md` (map-shaped `[computation]` record, plain Tier-1 id, DUAL fn addresses (Tier-2 semantic + Tier-1 trust — the Tier-1-only rule stands); env = full semver + builtin-set id = hash of the two closed spec tables (never cx_features) + `cx:version` added; caps IN the hash w/ the §6.5.1 invariance note; **`pure ⇒ deterministic` ruled as a new theorem — `[par]` reassembles source order ALWAYS ([ordered] tombstoned), locale audit mandated, map-traversal pre-closed**; pure-only VISIBLE cache (alias namespace, no new API, no [?memo]); tapes = inputs not axes; addresses defined from I1 onward); **stream 6** `commands_effects.md` (clause-children on [?def], `[effects]` = THE command discriminator, CHECKED-AND-ENFORCED never advisory; idempotency = explicit-key-wins + normalized-arg-record derived key (the anti-double-refund trap), must-not-exist CAS, present-value dedup hits, retention-extended windows; **budgets = [bounds] on the DELEGATION, commit-point debit + pure-PEP snapshot meter, per-stream v1 (cross-stream = stream 10), value-shaped exhaustion CXER4713, refunds never credit, shared-meter attenuation, D-C1 discharged as independent conjuncts**; propose mode = address-bound Lane-2 approvals + commit re-checks + boundary-decides + propose-only grants + dry-run unified; cap: = any authority artifact, fail-closed); **stream 8** `bitemporal.md` (VT = payload data under normative `valid-from`/`valid-to`, half-open, absent-open-end, two attrs not a kind; TX = position-only v1 w/ **journal ts FORM fixed at I1** (deterministic UTC-Z synthesis, #712 joins the manifest); hash-linked `[supersedes]` + the three-relation correction taxonomy; the pure pre-fold projection w/ `{at-seq, valid-at}` naming (as-of retired from new surfaces — the three-claimant collision resolved); **VT shreddable w/ VISIBLE redaction reporting — stream 20's binding input**; authz coherence rule w/ dual-coordinate decisions). Defects filed #711–#713. **S3 OPENS** (streams 3 #675 w/ the owner's adapter mandate, 7 #679, 21 #693, 18 #690). | S2 exit; I1 manifest gains the journal-ts form fix; streams 3/4/7/9/10/18/20/21 inherit named seams. |
| 2026-08-05 | **WAVE S1 EXITED — stream 17 letters 86–92 ruled (a) under the standing ruling** (each verified against the long-term-best bar). `runtime_representation.md` finalized: **representation-transparency normative, internals QoI** (grounded in ruling 19, the output-shaped corpus contract, the freeze story, and the `[?view]` precedent) with four observable normative items — the boundary rule (identity ALWAYS via canonical text, direct batch→canonical emit admitted iff byte-identical; inspection/CXPath-into/match/quasiquote/meta are node-observable; **D22's table-rows carve-out is the columnar seam**), the wire column lattice implemented in FULL (0x18/0x28 columns, narrowing-within-kind extended, 0x80 nullable, 0x62 dictionary w/ atom columns dictionary-encoded, 0x81 mixed as totality escape, **secret never columnar**), tables-not-modify-targets (COW as QoI guidance), and the honest-reporting obligation generalized. **The direction recorded is the owner's "BOTH" correction — dual lean (unboxed scalar core + columnar bulk), NOT columnar-only** (the issue text carried the pre-correction framing). table-api's false column-major claim amended now; dead parser_streaming.v pipeline wired-or-removed; eager combinators fall to stream 22's EV-PULL; perf gates 14-16/30.5 (red on build failures) repaired as prerequisite. #710 filed. **All four S1 specs finalized — S2 OPENS** (streams 2 #674, 5 #677, 6 #678, 8 #680). | S1 exit; I5 stream-17 work; abi/table-api/data-bin edits. |
| 2026-08-05 | **STANDING RULING for the remainder of the campaign:** all letter-batch recommendations are ACCEPTED as ruled (a), conditional on the long-term-best-for-CX bar — every recommendation is re-verified against that bar at recording time; any recommendation that fails it (or where confidence is genuinely low) is strengthened or surfaced as an explicit open letter instead of auto-ruled. Letters + rulings still posted per batch (decision log + stream issues) for the record. Wave exits proceed on this basis. | Every remaining letter batch (86+); waves S1–S4 exits. |
| 2026-08-05 | **S1 LETTERS 62–85 RULED (a)** (owner: "all recommendations accepted if they are the best long term for cx" — each re-verified against that bar; ONE strengthening applied under the proviso: EV-WORKER-EXIT rules cancel-and-drain outright, replacing the draft's shipped-wins escape clause). Three S1 specs finalized: **stream 16** `shape_inference.md` (two layers — Ring-0 corpus synthesis `cx schema infer` + Ring-1 modular pipeline flow, one traversal w/ stream 2; SchemaRef ≡ E2 content identity, named registry superseded by hint-binding over the content store; advisory-first + `--strict` made real; full TypeExpr repair; validator completed w/ bracket-prefix spelling; ingest auto-typing split ruled deliberate; never-widen-to-string lattice + determinism contract; stream 16 owns `cx schema export --to=json-schema` for stream 18); **stream 22** `clean_room_implementability.md` (desugar-to-core + normative §Evaluation w/ numbered observable-order rules + evaluation-witness corpus w/ discriminator PAIRS; A/B/C/D grades; three corollaries of the bar — no vcx paths as truth, no impl-internal representations, floors+fixtures for freedoms; conformance front door: result image spec'd FIRST, grant= promoted, README rewritten, out-effects channel; gates repaired + governance §10.1 clean-room clause; V-bound gates partitioned; EV-* register pins shipped semantics — let* sequential, snapshot capture, eager async w/ fire-and-forget guarantee, exact pull counts, parking clock, 1e6 floor, L2R effects, effect table into security.md, worker cancel-and-drain RULED); **stream 1** `semantic_value_model.md` (E1 = post-substitution quoted value LOWERED to authorable canonical CX — one substrate, E210 intact, name-sensitive w/ alpha-norm as future ADDITIONAL tier, plain Tier-1 address, `*`-head gap fixed; E2 hash basis = canonical TEXT bytes — 0x10/0x12 re-bless, whole-schema pair at v1, recoverable-by-computation + Lane-2 claim, fail-closed; E3 = journal-backed per-ref lineage, ONE CAS code CXER1114 w/ address+position encodings, 4604/1704 retire, closed ref scope; E4 = binding contract doc, CLOSED three-lane list, universal invariant, terminology glossary). **I1 manifest gains:** E2 schema hash basis, Lane-1 `__cx_meta__` fix, `*`-head parse fix, quote lowering. Bugs filed: #706 type-language batch, #707 conformance front door + spec gates, #708 value-model identity divergences. Stream 17 (#689) evidence relaunched after API-error failure; its spec completes S1. | S1 specs; I1 cutover manifest; streams 2/5/9/18 inherit E4's invariant + stream-16 seams. |
| 2026-08-05 | **WAVE S0 RULED — letters 1–61 all ruled (a)** (owner: "all recommendations accepted"). Six S0 specs finalized on the campaign branch: **stream 14** `partition_corpus_audit.md` (code.cxd splits by lane; `ring=` in fixture data; pair-case + digest fixture forms adopted; io/process/env = Ring-1 packs w/ watch→Ring 2; gap table G1–G18 ratified — G1/G2/G3/G5 pre-I1; deferral batch: C1/DBG/T2X/XSP-1,2/MOD confirmed, XSP-3 VC-revocation ADOPTED into stream 4, identity.cxd D7 ADOPTED into stream 12); **stream 12** `canonical_warts_sweep.md` (canonical bytes carry the trailing LF and the hash covers it; §2.4 escapes in; single-quote tiebreak; NO triquote in canonical; CX-owned Ryū; identity over canonical TEXT only — data-bin demoted to faithful codec w/ 3 round-trip bugs fixed; UTC-Z datetimes; redundant annotations stripped; Unicode identifiers widen to grammar w/ NFC names / verbatim values; dup attrs+xmlns = errors; layout budget struck from strict; PIs stripped; Tier-2 = named-token stream w/ arity/shape in the hash; multi-doc addresses defined); **stream 19** `crypto_agility.md` (multiformats-named tagged addresses + varint multihash binary; bare hex rejected post-I1; sha2-256 default; suite registry w/ PQ reserved rows; verifiers fail closed; provenance suite slot; no discovery ABI); **stream 11** `decimal_bigint_kinds.md` (9→11 kinds; scale-preserving identity + value equality; §3.5.1 model; postfix value ascription — #485 REVERSED; decimal⊕float=error; 0x18/0x28 narrowing-within-kind; map keys admitted; Go/Rust mappings corrected; #703 fixed at I1); **stream 15** `namespace_permanence.md` (identity URI = `tag:cxhome.org,2026:ns/cx`; legacy https spellings reserved-to-reject; domain-free inventory normative); **stream 13** `grammar_lexicon_review.md` (registry repair; [59a] deleted; ModulePrefix opened; take-while/drop-while; `cap:` + §12.3 reference-prefix registry — `hash:` superseded by 19; formal repair batch; r''' in data mode; kind addition = major event; application/cx + full extension registry). Bugs filed: #701 fixture-source shadowing, #702 fail-open verifiers, #703 decimal defects, #704 namespace enforcement, #705 tooling divergences — all fix at I1/I2 per their specs. **Wave S0 EXIT: all six specs owner-approved. S1 opens** (streams 1, 17, 16, 22). | Every downstream spec and phase I1's cutover manifest. |
| 2026-08-04 | **Business value case required on every ACCEPT** (Phase 1 bullet above): tangible + material outcome, revolutionary-not-incremental bar, concrete CX-generic use cases and benefits; "somewhat better" is evidence for reject/defer. No specific downstream clients named, ever. | Every #651 verdict; carries into #516 G-decisions. |

## Known extraction risks — ANSWERED by the import audit (2026-08-04)

See `partition_audit_vcx_imports.md` for the full evidence. Headlines:
`vcx/cx` is a strict sink (zero internal imports; V stdlib only) — the Ring-0
import seam already holds. re2 is load-bearing for Ring 0 (schema §7.1
normative RE2; sole in-cx caller is schema_validate.v). arrow_pub.v carries no
dependency edge. GC shims are build-gated and self-contained.
fixture_loader.v is compiled into libcx unconditionally with zero production
consumers — extraction cleanup. Dead module `cxstore/cxsqlite` + build debris
found (cleanup issues to file). Layering finding: the store ENGINE (cxstore)
depends only on cx; the store VERB surface lives in code — the extraction
frontier is inside `code`, not around `cx`.
