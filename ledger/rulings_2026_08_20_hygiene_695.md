# Ruling HYG-1 (2026-08-20) — #695 stale-inventory reconciliation (pre-cut hygiene sweep)

**Authorization:** owner-directed pre-cut stale-issue sweep, 2026-08-20 —
issue #695 carries the eleven protocol-surface spec/impl divergences from
the #651 inventory (restated as xsp_store_profile.md §1 finding 6 / #718).
The batch should have been reconciled when stream 4 (xsp_store_profile,
now spec/03-approved/xap/xsp_store_profile.md, APPROVED under SPR-1)
exited on 2026-08-09; this ruling records the per-item disposition against
the release-cut/v0.16.0 tree of 2026-08-20 (dfabaecc).

## Per-item disposition

| # | Item (from the #651/#718 inventory) | Verdict | Evidence / action |
|---|---|---|---|
| 1 | `.proto` lists 8 RPCs, listener serves 19 | RESOLVED | cxstore-grpc.md §2 now lists the COMPLETE 21-RPC surface (S6.5 reconciliation note at §2, "the pre-S6.5 revision listed only the eight data ops … #718 item 2"); `grpc_op_from_path` (vcx/platform/store_grpc_serve.v) maps exactly those 21 methods. No edit. |
| 2 | Object wire has no CSRP §3 endpoint section | RESOLVED (relocated) | CSRP is RETIRED whole (cxstore-remote-protocol.md status, stream-4 S3 2026-08-08) — non-normative history. The object wire is first-class in the live wire spec: xsp_store_profile.md §7a + the §4.1 vocabulary rows. No edit. |
| 3 | journal-over-CSRP (#644) unspec'd | RESOLVED | journal.md §6.1 "Journal over the wire — the XSP store profile" is NORMATIVE (v1 shipped, I5 stream-4 W6); the pushdown family is xsp_store_profile.md §4.3. No edit. |
| 4 | List response shape differs text vs binary (`[sequence]` forbidden by networked-backends §C) | RESOLVED (moot) | One wire vocabulary now: profile list = credit-governed event stream, one `[hash "…"]` per doc (xsp_store_profile.md §4.1 row); the internal op emits `[list-result [hashes [hash …]…]]` (vcx/platform/store_profile_ops.v). `[sequence]` survives only in the retired historical CSRP doc. No edit. |
| 5 | Capabilities sample `zst` default vs daemon `none` | RESOLVED | The daemon adverts truthfully: `[compressions [supported "none"] [default "none"]]` (vcx/platform/store_service.v svc_store_capabilities). The `[default "zst"]` sample survives only in the retired CSRP doc. No edit. |
| 6 | Retired URL-query-param path still live | RESOLVED | The HTTP data plane is DELETED — the daemon's HTTP surface is bootstrap-only (health/ready/metrics/capabilities) and 404s all data paths (store_service.v); the `?hash=` convention persists only as internal synthesized-request plumbing between the gRPC edge and the shared op pipeline, not a wire surface. No edit. |
| 7 | `xsp.cxd` conformance fixture missing | RESOLVED | conformance/stdlib/xsp.cxd exists (28 cases; G8 discharged at W3 per xsp_store_profile.md §9). No edit. |
| 8 | SSE binding drift: xsp.md §4.1 says base64 XSP frames; host serves plain CX | STILL TRUE — owner ruling needed (class C) | The shipped host pushes plain-CX named SSE events (xap_host_push_frame, vcx/platform/stdlib_xap_host_notd_wasm32_emcc.v — no envelope branch on the downstream); only the upstream POST intent has the opt-in `[envelope codec="xsp"]` base64+XSP decode. xap.md §24 (normative, #609) meanwhile defines the /v1 feed as plain `[surface …]`/`[surface-delta …]` pushes. NOT fixed here — truing xsp.md §4.1 to the shipped downstream would re-scope a normative binding, and implementing the base64 downstream is implementation work. Lettered options in the #695 report. |
| 9 | fabric.md §11 capability table missing `rotate` | STILL TRUE — FIXED here (class B) | The implementation has FOUR grant actions (`fs_grant_actions = ['observe','publish','consume','rotate']`, vcx/platform/fabric_service.v) and fabric.md §13.1 already normatively specifies the `rotate` grant (#640: explicit, deny-by-default, no other action implies it, mount-wide). §11's table simply predates the #640 landing — the implementation is the ruled-correct side (the grant discipline is #640's shipped, spec'd contract). Edit: xap/fabric.md §11 — "three" → "four" grantable actions; add the `rotate` row cross-referencing §13.1. No normative clause weakened; the table is trued to the contract §13.1 already states. |
| 10 | gRPC parity suite missing Aliases/AliasesSet/Reload | RESOLVED | The G13 parity families (store_g13_parity_test.v, in platform_netwire umbrella) drive them explicitly: test_g13_alias_parity (AliasesSet — "#718 item 2's missing lane"), test_g13_admin_and_advert_parity (Reload/config-reload), test_g13_docs_blobs_delete_parity (the S6.5 blob pair). cxstore-grpc.md §2 records the reconciliation. No edit. |
| 11 | XAP-tier symbolic error codes unallocated in governance.md §9.6 | RESOLVED | §9.6 now carries the rows: CXER4850–4889 cx-xap (registered 2026-08-05, C5 amendment), 4900–4901 similar island, 4920–4949 fabric, 4950–4969 coordination, 4990–4999 consistency, 5000–5049 XSP generic layer + store profile (the numeric cutover of the retired symbolic CXER-XSP-* spellings). No edit. |

**Scope of the spec edit under this ruling:** exactly one file,
spec/03-approved/xap/fabric.md §11 (item 9). Nine items were already
resolved by the stream-4/S6.5/G13 landings and are recorded above as
evidence, not edits; item 8 is remanded to the owner.
