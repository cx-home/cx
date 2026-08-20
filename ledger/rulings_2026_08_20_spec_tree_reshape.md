# Rulings 2026-08-20 — spec-tree reshape at the v0.16.0 cut (owner "1a 2a 3a")

Owner ruled on the full 02-working + 01-new audit (30 files, evidence-based
verdicts: promotion-gap citations, implementation greps, ledger cross-refs).

## SPR-1 (owner 1a) — G3: eleven working specs GRADUATE to 03-approved

The release contract must not ship with approved specs deferring to a
"working" directory as normative authority (e.g. approved code.md citing
planar_algebra.md as "the normative ruling authority"). All eleven are true
of the shipped v0.16 engine. Filenames are preserved; each file's status
line records the graduation; every `spec/02-working/<file>` citation
repo-wide is repointed.

| file | destination | primary evidence |
|---|---|---|
| cx_partition.md | core/ | vcx/Makefile implements §4/§5 by name |
| delivery.md | core/ | 10 approved citations (code.md ×4, journal, fabric, bus, io, http) |
| planar_algebra.md | core/ | code.md cites it as normative ruling authority (L95) |
| erasure_compliance.md | std-lib/ | journal.md ×5, store.md ×2, live.md; store_erase.v shipped |
| distributed_store.md | std-lib/ | store.md ×2, journal.md, governance.md; replica surface shipped |
| stdlib_colocated_docs.md | std-lib/ | 46/46 stdlib modules carry doc-blocks |
| xsp_store_profile.md | xap/ | xsp.md, store.md, governance.md cite; 16 vcx files |
| xap_grammar_composition.md | xap/ | own status: "destined to graduate as sibling of xap.md"; #865–#867 landed |
| xap_authoring_process.md | xap/ | cx xap init wired (#726); 2 approved citations |
| xap_schemas/ (6 .cxs) | xap/xap_schemas/ | live build artifacts; xap_umbrella_test.v runs them (2 test paths updated) |
| agent_tool_projection.md | x/ | x/tools.md + x/README.md cite for L138–L146 |

## SPR-2 (owner 2a) — fourteen files ARCHIVE to spec/_archived/

Per the standing convention: annotate + move, never delete. Eleven I5
stream derivation records whose normative text already landed in approved
files get `✅ GRADUATED` banners naming their approved homes; three spent
plan/transient docs get `✅ EXECUTED` banners.

GRADUATED: canonical_warts_sweep, decimal_bigint_kinds, crypto_agility,
grammar_lexicon_review, namespace_permanence, live_modes, shape_inference,
clean_room_implementability, cross_stream_coordination,
xap_feature_augmentation, xap_feature_composition_model.

EXECUTED: evict_cx_from_v_PLAN (eviction done, June), docs_restructure_826
(ruled 1a 2a 3a on 08-17 and implemented), delivery_edit_packets (every
P-packet now applied in the approved tree — its "no packet applied" header
had gone false).

**Extraction executed before archival:** the "never `text/cx`" media-type
ruling (stream-13 L61) lived ONLY in grammar_lexicon_review.md — the
normative clause and its rationale (a `text/*` intermediary that normalizes
charset/line-endings corrupts content addresses) now live in
spec/03-approved/misc/bindings.md beside the media-type table.

## SPR-3 (owner 3a) — both spec/01-new cxstore files STAY at 01-new

- cxstore_set_identity_index.md: parked by the #82 scope ruling; retained
  as load-bearing precedent ("identity depends on content only, never
  content+policy") which the audit inventory cites.
- cxstore_universal_object_model.md: live Phase-1+ design — the named
  source for a future store.md amendment; its own conformance gate has not
  been declared passed (only the cxpack:// subset shipped via #136–#138).

## Left in 02-working (active design, unimplemented)

supervise.md, worker_lifecycle.md (no stdlib/supervise.cx exists),
message_delivery_unification.md (U1.8 still open), xap_architecture.md
(open questions; flagged for owner review post-cut as the stalest genuine
design file).

## SPR-4 (owner "1b", same day, spec-review session) — set-identity sketch RETIRED, precedent made normative

Reviewing spec/01-new/cxstore_set_identity_index.md, the owner could not name
the problem it solves — and the honest answer is: barely one. Strict
canonical already sorts map keys (§2.11.1); the residue ("a sequence the
caller privately means as a set") is app-level discipline (sort before
write); no consumer exists. Ruled 1b: the address-purity precedent from the
#82 closure (identity = pure function of canonical bytes; no schema/profile/
policy input; semantic-equality beyond bytes may only be a DERIVED,
rebuildable, explicit-profile index) is now NORMATIVE in
spec/03-approved/core/canonical.md §1; the sketch is archived
⛔ RETIRED — NEVER GRADUATED. spec/01-new now holds exactly one file
(cxstore_universal_object_model.md, review pending).

## SPR-5 (owner "2a 3a", spec-review session) — xap_architecture split-and-settled; the U1 letter archived

**3a — message_delivery_unification.md ✅ EXECUTED → _archived.** All fifteen
sub-rulings ruled (U1.1a–U1.9a, U1.10 no-action, U1.11a–U1.15a) and every
ruled implementation live-verified at archival: channel sharing/retention
axes construct, [?receive max=/deadline=] present, [$journal:subscribe] /
[$journal:seq-at] shipped with RULED tokens in the code, [?select] send case
present, [$fabric:receive] retired ("no callable"). delivery.md (approved,
SPR-1) is the normative home. #761 CLOSED at archival; #764 tracks the one
remainder — which the owner then reclassified as a PRE-CUT BUG (see FL-1,
its own ledger file; fixed in a dedicated worktree).

**2a — xap_architecture.md split-and-settled → _archived:**
- §11 serving execution model → GRADUATED as std-lib/http.md §14 (shipped,
  field-proven #275 → PRs #278/#279; gate http_slow_handler_isolation_test).
- §10 deployment process model → GRADUATED as misc/deployment.md (port is
  the only mutex; fail-fast collisions; no bespoke supervision).
- §9.3 DID/VC — found ALREADY SUPERSEDED during the split: std-lib/did.md +
  vc.md are approved and stdlib/session.cx ships attach-did with tests. The
  review's "unfiled forward design" claim was wrong; corrected here.
- §9.1–9.2 — consolidation of approved xap.md §14.1/§16/§22; no extraction.
- §1–§8 positioning essay — ADOPTED 2026-06-15 in-document; §5's open
  questions since answered by the composition track / 804-1c / value-model
  spec. Code comments and the vc.md link repointed.

**Also ruled the same session (recorded here for the chain):** #764
reclassified bug + pre-cut (FL-1 lane, dedicated worktree agent); the W26
studio design letter POSED at design/787/w26/studio.md (ST-1…ST-8) — the
studio was to be POC'd early in the ux campaign and finished by v0.16.0;
never scheduled; the contract half (ux.md §2.2/§4) graduated with UX-1, the
editor half is W26.
