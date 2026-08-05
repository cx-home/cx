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
  (which ring owns it; what dependency contract accepting it implies).
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

## Decision log

| Date | Decision | Where it binds |
|---|---|---|
| 2026-08-04 | **XSP has no human-readable wire form** (owner letter (a)). Binary framing stays the only wire encoding; the `[frame …]` CX-value projection is the normative logical frame; human readability = CX text emit of that element, plus a future `cx xsp decode` tooling verb when demand appears. | Input to the #651 §12 verdict; eventual xsp.md direction note. |
| 2026-08-04 | **Ring 0/1 seam = representation vs. interpretation.** The parser (full grammar including program forms), node kinds, canonical identity, codecs, emitters, diff, schema/validate sit in Ring 0; evaluation, purity, stdlib sit in Ring 1. The grammar is never forked — cxparse unification ("one engine") is the partition's foundation. Canonical hashes must be product-independent. The data product differentiates by link surface + data-only CLI verbs + an opt-in "data profile" validation (post-parse node-kind predicate, not a parser mode). | Partition spec boundary section; feeds #516 G-decision (c). |
| 2026-08-04 | **Branch/merge model** as in Ground rules above (maintenance line stable; ONE campaign branch `design/651-516-partition` for all plan+spec work on both issues, superseding a briefly-created two-branch split the same day; implementation branches later cut off the campaign branch; merge target at gate time; hard spec-before-implementation gate). | This campaign. |
| 2026-08-04 | **Verdict sequencing seam-first** (§10, §12, §13, §14, layering before §4–§8), each verdict carrying a ring assignment. | Phase 1 execution. |
| 2026-08-04 | **Evaluation criteria codified** (section above): first principles; long-term health of CX + consumers; agent–principal symbiosis as north star; timely and marketable. Likely the last foundational pass before production downstream consumers — depth over speed. | Every verdict and G-decision in this campaign. |

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
