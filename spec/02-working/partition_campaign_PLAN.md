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

## Phase 2 status

Partition spec drafted: `spec/02-working/cx_partition.md` (all letters
resolved — P1a lockstep versioning, P2a Windows tier-2). Awaiting Gate G-B
(owner approval, user-only). Phase 3 (implementation plan) follows G-B.

## Decision log

| Date | Decision | Where it binds |
|---|---|---|
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
