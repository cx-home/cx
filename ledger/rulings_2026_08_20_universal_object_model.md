# Rulings — 2026-08-20 — universal object/subtree model (UOM)

Scope: `spec/01-new/cxstore_universal_object_model.md` (the #129/#76 design
draft, landed from PR #149) versus the shipped store; the §7 phasing; the §6
conformance gate; graduation into `spec/03-approved/std-lib/store.md`.

---

## UOM-1 — the universal object/subtree model IS the store contract; execute
## the draft's own §7 phasing to completion and graduate it

**Owner ruling (2026-08-20, verbatim):** "you broke the substrate consistency
and mucked up the cx store. cx store must be able to hold content addressed
pieces (default) or document based across all substrates the same. Isn't that
what was spec'd?"

It was spec'd — `spec/01-new/cxstore_universal_object_model.md` is the
contract. Ruling: the subtree (content-addressed pieces) model is available
across EVERY substrate (`mem`, `local-fs` pack + object-per-key, `sqlite`,
`s3`) and the server tier, with the `document` model retained as the
compatibility option on the same substrates; **subtree is the default for new
stores**; **model is orthogonal to substrate**; **store keys never change**
(canonical doc hash, tier-invariant — load-bearing invariant, no fork here).

### State-of-tree audit (release-cut/v0.16.0 @ 56cab635, audited before work)

The draft's §7 phases 1–4 are ALREADY LANDED on this branch by the #129 PR
series and the stream-4 wire cutover — the owner-observed inconsistency
matches the draft's §0 state (and the stale v0.15.0 base this worktree seeded
from), not this tip:

- **Phase 1 (seam-first, zero behavior change):** b0c4ec3f routes cxpack
  persistence through `ObjectBackend`; bd4cc7cb behavioral coverage.
- **Phase 2 (mem + sqlite + local-fs/object-per-key):** d25d73bf (2a cxobj
  object-per-key), 08f35e15 (2b mem defaults subtree), 01c60398 (2c sqlite
  object rows, `-d cxstore_sqlite`); 8cfb2f0c (B2: the degenerate `document`
  model on mem/cxobj/sqlite/s3 — same code path, "don't decompose").
- **Phase 3 (s3 object-per-key):** 01709053 (S3ObjectBackend + hermetic §6
  test), 31e7ac6f (live seam consumer).
- **Phase 4 (object-level wire + daemon-as-ObjectBackend):** 04df12a9 →
  e0079fd9 (object verbs, RemoteObjectBackend client, cx-store:// client on
  the object wire, gRPC parity); doc-level verbs remain the compatibility
  layer over the object verbs (put-doc = decompose → have → put-missing →
  set ref; store_objwire_client).
- **Phase 5 (normative merge):** 3b1531fa/5217f555 (PR-F: store.md faceted
  §1–§4 axis frame + §7 subtree model), 99e55e5f (PR-G canonical scheme
  cutover + self-describing reopen), fcf72b14 (PR-H document+ prefix).
  REMAINING at audit time: the draft's archival banner (held by SPR-3
  pending a demonstrated §6 conformance run), explicit store.md text for two
  of the draft's six §4 properties (universal integrity self-verification as
  a property row; model-invisible-to-the-API as a property row), and the §6
  gate run recorded.

### The §3 wire re-base (the one staleness — RECORDED here as ordered)

The draft's §3 is built on CSRP. CSRP was RETIRED whole by stream 4
(abaea9b9): the store wire is the XSP profile
(`spec/03-approved/xap/xsp_store_profile.md`). The re-base is ALREADY
MATERIAL in the approved tree — the draft's object-level verbs exist as
XSP-profile verbs following the profile's own conventions:

| draft §3 (CSRP) | shipped (XSP profile) |
|---|---|
| `objects/have` | `objects-have` (§4 vocabulary row; batch tagged addresses → the MISSING set — dedup-on-wire primitive) |
| `objects/get` | `objects-get` (batch fetch, each self-verifying; erased-root discriminator §7b) |
| `objects/put` | `objects-put` (server verifies address↔bytes, CXER5017 on mismatch) |
| `refs` | `refs-set` / ref resolution on the docs/refs planes (E3 advances) |

Credit flow, planes, XSP-AUTH, and the capability floors (`read` covers
objects-have/objects-get, `write` covers objects-put/refs-set) follow the
profile's §4/§5/§7a as shipped (wire composition 3d6f5868). gRPC remains the
integration edge at verb parity. The archived draft carries a banner naming
this re-base so its §3 CSRP framing cannot mislead.

### Phase plan under this ruling

1. Verify phases 1–4 live against this tip: run every store lane
   (store_lineage, store_s3_lineage, store_s3_subtree, platform_store_
   pack/core/wire umbrellas, store_remote umbrella, store_porcelain,
   xap_umbrella) — fix anything red; fix any genuine substrate-consistency
   gap found.
2. Run the §6 conformance gate, all seven items, as real gated lanes;
   add/extend lanes where an item lacks direct coverage.
3. Graduate: merge the missing §4 property text into store.md §7 (`RULED:
   UOM-1`), move the draft 01-new → spec/_archived with a ✅ GRADUATED
   banner naming store.md + xsp_store_profile.md, confirm the profile's
   object-verb section (§4 rows + §7a) stands.
4. Interactions held invariant: FL-1/FL-2 lineage (acts record doc-level
   events; the object model changes at-rest encoding, not the act stream);
   erasure/shred (shared objects survive until unreferenced —
   reachability-based reclamation via the substrate-generic
   `cxstore.mark_live`; erase-attribution stays doc-level); encryption-at-
   rest per-substrate posture (fail-closed on non-sealing substrates).

### Riders

- **UOM-1r1 (erasure × sharing, sound-refusal-first, pre-confirmed by
  audit):** erasing a doc whose subtrees are shared with live docs destroys
  only the doc entry (root ref + tombstone); shared objects survive until
  unreferenced and are reclaimed by reachability (`mark_live`) at
  compaction/gc — erase-attribution stays doc-level. This is the shipped
  behavior (store_objgraph.v store_erase_doc_local; store_cxpack.v fold;
  store_porcelain gc/prune) and is hereby recorded as the ruled posture.

(Ledger updated with dispositions as the phases verify/land below.)

### Execution record

- (appended as work lands)
