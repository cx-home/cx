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

- **UOM-1r2 (version-consistency rider, pre-existing red):** the tip carried
  two unmarked version literals in `spec/02-working/diagram_renderer_cx.md`
  (an owner-ruling citation and the literal branch name) failing
  check_version_consistency tree-wide. Fixed with the check's own
  `version-literal-ok` inline markers (genuine historical citations) — not
  UOM scope, fixed in-line to keep the gate green throughout.

(Ledger updated with dispositions as the phases verify/land below.)

### Execution record

**Live substrate-consistency probe (the owner's complaint, verbatim check)**
— one program puts two docs sharing a fat subtree into `mem://`,
`document+mem://`, `file://` (pack), `file://…?encoding=object-per-key`, and
`document+file://` (flat index), then cross-checks:

- store keys UNIVERSAL: the same doc yields the same store key on every
  substrate and BOTH models (all six cross-equalities true);
- round-trip byte-identical on all five mounts;
- dedup live where subtree: logical=38 / distinct=28 IDENTICAL on
  mem/pack/opk; document mounts honestly report the degenerate counts
  (objects=2 for 2 docs).

**Two genuine substrate-consistency defects found by the probe and FIXED
(both `RULED: UOM-1`):**

1. `store_status` reported **`remote=true` for a LOCAL `document+file://`
   store** — the non-objgraph/non-columnar fallback arm assumed
   remote/byte-source. Fix (store_porcelain.v): `remote` is emitted only
   when ops actually route over a remote transport (`ms.remote` set); a
   local flat store now reports plain `docs=N`. No golden pinned the old
   behavior (checked conformance + tests).
2. `store_objgraph_stats` **under-reported `object_count` for the pack
   substrate** (live-sink remnant, e.g. 15, where mem/opk answered 28 for
   the same docs): the pack backend carries its durable substrate in
   `obj_pack`, which the stats counter skipped (it consulted only
   `obj_backend`). Fix (stdlib_store.v): count from `obj_pack` when
   attached — object_count's documented meaning ("distinct objects
   physically held", durable + staged). In-memory cxpack test mounts
   (obj_pack nil) keep the sink count, so the existing stats/fingerprint
   tests and the mem-pinned conformance goldens are unmoved.

**§6 wire-economy literal assertion added** (`RULED: UOM-1`,
store_remote_object_test.v): through the REAL client funnel
(`push_doc` = decompose → objects-have → objects-put of only the missing →
refs-set), pushing a doc sharing a fat subtree with one already on the
daemon transfers strictly fewer content bytes than the whole doc
(`put_bytes < canonical.len`), the have probe fires, and the daemon serves
the doc back byte-identical.

**§6 conformance-gate mapping (all seven items, gated lanes):**

1. Round-trip per substrate — mem/pack/opk: platform_store_pack +
   platform_store_core umbrellas + live probe; sqlite:
   test_store_sqlite_subtree_roundtrip_and_dedup (test-vcx-sqlite lane);
   s3: test_s3_subtree_roundtrip_dedup_versionsharing (hermetic);
   server mount: test_cxstore_object_wire_put_get_roundtrip +
   test_xsp_client_full_surface (store_remote umbrella).
2. Dedup (object-count delta) — test_cxobj_dedup_* (pack umbrella GATE 2),
   test_objgraph_stats_object_count_and_dedup (core), sqlite + s3 lanes.
3. Version sharing — test_cxobj_version_sharing (pack umbrella GATE 3),
   s3 subtree lane, modify-structural-sharing (core umbrella).
4. Cross-tier object identity —
   test_remote_object_backend_client_wire_crosstier (same object hashes
   embedded vs wired; objects-have reports the overlap).
5. Wire economy — test_cxstore_object_wire_economy (daemon object-count
   delta < decompose count) + the NEW bytes-on-wire assertion above.
6. Universal integrity — test_object_backend_self_verifies_on_read,
   test_cxobj/pack corruption tests (CXER1120),
   test_store_sqlite_corruption_is_hard_error,
   test_s3_subtree_corruption_is_hard_error, wire CXER5017
   (xsp regression guards).
7. Full gate — test-vcx battery + doc gates (recorded below).

**Lane RCs (2026-08-20/21, worktree off release-cut/v0.16.0 @ 56cab635,
V pin b3d0da67):**

Baseline battery — 18/18 RC=0: store_lineage, store_s3_lineage,
store_s3_subtree, platform_store_pack/core/wire umbrellas, store_porcelain,
store_cxstore_wire, store_remote_object, store_remote_read,
store_subject (erasure/shred), platform_journal umbrella,
cxstore_object_backend, store_core_umbrella, store_remote_umbrella,
xap_umbrella (packages install through the store), test-vcx-sqlite,
test-vcx-cxstore. BATTERY-OVERALL-RC=0.

Post-fix definitive reruns (code changed after the baseline compiled) —
7/7 RC=0: platform_store_core, platform_store_pack, store_porcelain,
store_remote_object (incl. the NEW bytes-on-wire test),
store_cxstore_wire, store_s3_encryption, test-vcx-sqlite (incl. sqlite
encryption + concurrent-writer). RERUN-OVERALL-RC=0.

Doc/process gates: verify-doc-links 1420+0 failed (spec/03-approved) +
docs-src clean; verify-doc-blocks 361 passed / 0 failed;
check_version_consistency OK (after the UOM-1r2 rider);
spec-freeze-gate clean through the UOM commits.

**Commits (this worktree, never pushed):**
- ed16e946 ledger(UOM-1) — this ruling, before work.
- 3bd35520 fix(gate) — UOM-1r2 version-literal rider.
- 30e5ac8a fix(UOM-1) — the two substrate-consistency fixes + the §6
  item-5 literal bytes-on-wire assertion.
- a9e10375 spec(UOM-1) — store.md §7 property completion + CSRP→XSP seam
  truing + draft archival with GRADUATED banner.

- **UOM-1r4 (libcx-abi-gate toolchain-vintage sensitivity, environment —
  found running the full gate in this worktree):** a freshly built
  `third_party/re2/obj/libre2.a` (same pinned source 3a8436ac, today's
  clang 21 / libc++ 20.1 headers) emits `std::piecewise_construct` as an
  EXTERNAL data symbol (`__ZNSt3__119piecewise_constructE`), where the
  2026-08-02 archive kept it internal (`…L19…`, type `s`) — one extra
  dylib export, failing the full-list baseline diff with zero CX-surface
  change. Remedied here by reusing the pinned-source artifact from the
  main checkout (byte-parity: ABI-PARITY-OK). LATENT: the baseline is
  vintage-sensitive through vendored C++ statics — the main checkout hits
  this the day re2 is rebuilt; the durable fix is visibility-hidden
  vendored C++ (or filtering vendored `__Z` internals from the contract),
  which amends the I3-cut baseline and belongs to the owner/main tree.
  RECOMMEND filing as an issue (kind:defect area:build prio:medium).
- **UOM-1r5 (full-gate `-j` same-path races, environment):** under
  `make test -j<ncpu>` in this cold worktree, three transient classes
  fired across attempts, none a tree defect: (1) check-code-fixtures
  dlopened `vcx/target/libcx.dylib` mid-relink (another target rebuilds
  the same path) → "symbol not found" on a symbol the lib exports;
  (2) the extraction CLI lane exec'd `vcx/target/cx` mid-relink →
  sv-048 rc-1 divergence that does not reproduce standalone (both
  binaries convert identically when probed directly); (3) spec-freeze-gate
  transiently read empty commit messages under shared-.git contention
  (parallel sessions share this object store) and flagged three commits
  that all carry their RULED: tokens — direct rerun clean. The §6.7 run
  therefore uses the Makefile's own sequential fallback
  (`make test-no-parallel`), which removes every raced pair.

Full gate (§6 item 7, `make test-no-parallel` — same TEST_TARGETS union,
sequential): GATE-RC recorded in the final commit touching this file.
