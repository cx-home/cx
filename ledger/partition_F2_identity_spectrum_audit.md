# F2 spectrum audit — computation-identity-as-address rip-out (ruled F1/F2, 2026-08-08)

Independent read-only survey (agent that did not do the remediation),
recorded verbatim as the authority for the F2 rip-out. Principle (F1):
documents are the ONLY object kind; document identity (hash of canonical
bytes) is the only address/storage-key/wire carriage; computation
identity (normalized-program hash) is ONLY a derived index or a
recompute-and-refuse verification claim.

## Bottom line
The violation cluster is exactly ONE mechanism —
`cx_code_store_put_def`'s `'code:'+hash` storage keying
(store_objgraph.v:493-512) — and everything downstream: the
`put-def`/`get-def` store verbs, the on-disk `C` (code) manifest record
kind, the skip-rehash integrity hole in THREE backends (cxpack,
columnar, migrate — the key is not the hash of the stored bytes, so
content-addressing is broken by design for code), feed/refs/alias/wire
leakage of `code:` keys, code-identity.md §3 storage, canonical.md §1.4's
"additional key" framing, and the dead P1 letters. The RELATION
(code_identity.v, the §2 normalization, the pair-property tests) and
every "claim/cache, never trust" surface ALREADY CONFORM — rename only.

## Epoch safety — VERIFIED
No `conformance/` expected-output byte contains "tier"; zero `code:sha`
occurrences anywhere in `conformance/`; no fixture pins a `code:`
address. The rename + rip-out are prose/metadata + code only — the
identity epoch is not touched. Case-id/tag renames are non-epoch per the
I4 eval-ring=/packs= precedent.

## VIOLATES — rip out
- store_objgraph.v:493-512 `cx_code_store_put_def`/`get_def` (the root),
  :155-184 `store_put_raw` code-as-special-raw-object, :388-395 code:
  feed-seed leakage.
- store_cxpack.v:380 + store_graph.v:84,142 `C` manifest record kind;
  store_cxpack.v:704-707 + store_porcelain.v:730-736 presence-only
  "verify"; store_columnar_*.v:258,288,620-631 + stdlib_store.v:3567-3577
  skip-rehash for code: keys (the integrity hole).
- stdlib_store.v:2012,2531-2562 `store-put-def`/`store-get-def` verbs +
  stdlib/store.cx:25-26,127-137; :2670-2674 alias into code: namespace.
- code-identity.md §3 (:96-104) storage; canonical.md §1.4 (:85-104)
  "additional key/namespace" framing; store.md put-def/get-def
  (:98-99,173,603,637).
- Address surface: code-identity.md §2 (:24-28) `code:sha2-256:<hex>`
  composition; grammar_lexicon_review.md §12.3 (:24,55) code: prefix;
  namespace_permanence.md:71 + cx_partition.md:180-181 listing the
  retiring address.
- Tests: code_identity_store_test.v, store_code_persist_test.v,
  canonical_tagged_address_test.v:69-77.
- Dead P1 letters (partition_I5_stream4_xsp.md:656-746) — superseded by
  F3, rewritten to def-document-by-address + computation-identity claim.

## CONFORMS — rename only (Tier-1/Tier-2 → document identity / computation identity)
- code_identity.v:46-116 (the pure relation), the §2 normalization, the
  pair-property tests (identity_tier2_*_test.v).
- computation_identity.md fn-slot role (cache index — re-spell the
  address, keep the role), commands_effects/agent_tool_projection/
  schema_event_evolution/xap_identity_model "rides for cache, never
  trust" surfaces, xap dist `identity=` install-verify claim,
  registry publish (name@version → manifest DOCUMENT hash).
- hash_registry.v cx_parse_tagged_address ALREADY REJECTS code: (keep).
- lang/* "Tier-1/Tier-2 binding" = binding-priority, a NAME COLLISION —
  EXCLUDE from the rename.

## Rename name-collisions to EXCLUDE (four distinct concepts, not the identity one)
1. docs tier1-guardrail (learnability tier) — check_docs_tier1_guardrail.
2. XAP Tier-1 read-model / Tier-2 coordination plane (feature-composition
   planes) — xap.md, fabric.md, stdlib_xap.v, stdlib_fabric.v. HIGHEST
   mis-rename risk (exact "Tier-2" spelling in the sweep dirs).
3. binding/implementation tiers (code.md, test-conformance-tier1, lang/).
4. platform support tiers (Windows is tier-2), authz verify-tier T0/T1/T2,
   service tier, resolver tier.

## Owner calls A1–A6 — see the rulings log in partition_remediation_register.md
