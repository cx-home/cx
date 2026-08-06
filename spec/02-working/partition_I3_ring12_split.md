# I3 — Ring-1/2 split: working ledger

**Status: OPEN** (2026-08-06). Branch `impl/I3-ring12-split` off
`design/651-516-partition` @ 7a38b6a6 (the I2 exit-merge).
Phase row: `partition_impl_PLAN.md` Part B; this file is I3's working
ledger, the successor to `partition_I2_extraction.md`.

## The phase (plan row, verbatim contract)

The `vcx/code` frontier: store verbs, protocols,
xap/fabric/session/authz/did/vc, DB drivers, process/io → Ring-2
modules; evaluator + pure/local stdlib stays Ring 1. Pack gates named
per the profile table.

**Exit gate:** full corpus green; import gates green; **libcx ABI
unchanged (symbol diff empty)**.

Membership test per module (spec §10): imports cxstore/protocol
modules or serves ⇒ Ring 2; otherwise Ring 1, pack-gated for weight.
The plan-row enumeration is the contract; where the mechanical test
and the enumeration disagree, the enumeration wins (see census note
N3 on did/vc).

## Standing constraints carried in

- `make test-extraction-gate` (I2's byte-for-byte lane) stays green
  throughout — the Ring-0 artifacts must be untouched by this split.
- Import gates (I0) stay green; I3 EXTENDS `ring_import_gate.sh` from
  the Ring-0 sink invariant to the Ring-1/2 frontier (spec §3: Ring 1
  MAY import Ring 0 only; Ring 2 MAY import Rings 0–1).
- Any red is a plain regression (deliberate-red ledger EMPTY at open).
- Fixture-before-fix; full `make test` + `test-binding-api-parity` at
  phase close; no pipes on gate runs (exit-code masking).
- The libcx ABI freeze direction (spec §8): I3 changes module
  boundaries, never the export surface. Profile/artifact re-shaping is
  I4 — during I3 libcx keeps building over the full (now-split) tree.
- Entry-25 mode-in-identity residual still rides BEHIND, before I5
  (pinned by `test_mode_does_not_survive_canonical_text_named_residual`).
- #737 exclusion (parser_multidoc_test.v out of test-vcx-cx BY NAME)
  and the CODE_SERIAL_RETRY membership of store_grpc_parity_test.v
  (#648 class) carry forward unchanged.

## Dispositions into this phase (pre-I3 corpus obligations)

- **G6** (`partition_corpus_audit.md`): formatting.md has ZERO
  fixtures; §1's purity invariant ("never changes the data") untested
  beyond `fmt_lossless_test.v`. fmt is Ring 1 — pinned before the
  split ships the surface.
- **G14**: did.md / vc.md unfixtured — pure crypto/document surfaces
  underpinning Ring 2's single authority model; V-tests only today.

## Work log

1. **Census re-derived at branch cut (2026-08-06).**

   **Corpus (Q2-normative per-case resolution, `ring_query.cx`):**
   doc lane Ring 0 = 1564, Ring 1 = 1998, Ring 2 = 646 (total 4208);
   eval lane = 991 (code.cxd, eval-ring=1). Suite-level ring=2
   families (17): a2a-xap, adjudicate, authz, bus, db, email, fabric,
   http, journal, mcp-server, net, session, store, xap-compose,
   xap-dist, xsp-auth + the 3 io watch case-overrides. Two suites are
   deliberately MIXED via per-case tags (the I0 C8 repairs):
   `stdlib/http.cxd` header ring=2 with the client cases ring=1;
   `stdlib/io.cxd` header ring=1 with the 3 watch-cap cases ring=2.

   **Module census:** `vcx/code` = 226 `.v` files — 144 production,
   82 `_test.v` — plus 5 raw `.c` files (cx_iowatch_darwin/linux,
   cx_pty, cx_stack_guard, cx_term). ALL production files are one V
   module (`module code`), so intra-module call edges do NOT appear
   as imports — the import census below under-detects coupling; the V
   compiler becomes the frontier oracle once files move into separate
   modules.

   **Ring-2 file census (production, by contract bucket):**

   | Bucket | Files | Import evidence |
   |---|---|---|
   | Store verb surface + engine adapters (33) | store_authz, store_columnar_d_cxstore_columnar, store_csrp, store_csrp_binary_route, store_csrp_client_bin, store_csrp_wire, store_cxpack, store_cxpack_fold, store_ft, store_graph, store_grpc_client, store_grpc_conn, store_grpc_frame, store_grpc_h2, store_grpc_hpack, store_grpc_huffman, store_grpc_proto, store_grpc_serve, store_limits, store_objgraph, store_observability, store_porcelain, store_reload, store_remote, store_remote_ftp, store_remote_object, store_remote_read, store_remote_sftp_d_cx_sftp, store_rotation, store_s3_subtree, store_service, store_sqlite_d_cxstore_sqlite, store_tracing | 11 import `cxstore` directly; the rest are protocol/policy adapters (audit: 70/22 split) |
   | Store verbs + journal (stdlib) | stdlib_store (imports cxstore), stdlib_journal | corpus store/journal ring=2 |
   | Protocols | stdlib_xsp, stdlib_xsp_auth (+ csrp/grpc files above) | corpus xsp-auth ring=2 |
   | Serve/services substrate | services, services_listener_d_wasm32_emcc, services_listener_notd_wasm32_emcc (imports transport.picoev + picohttpparser, 11 C decls), serve_file, mime (single consumer = serve_file), stdlib_net (serves: listen/bind; net ring=2), stdlib_email (ring=2), stdlib_bus (ring=2) | serves ⇒ Ring 2 |
   | http SERVE half | stdlib_http.v **serve/listen surface only** — the file is MIXED client+server and needs an in-file split; corpus already split per-case | client half → Ring-1 http-client pack (§4 cli profile) |
   | xap/fabric | stdlib_xap, stdlib_xap_dist, stdlib_xap_host_auth_notd_wasm32_emcc, stdlib_xap_host_d_wasm32_emcc, stdlib_xap_host_notd_wasm32_emcc, stdlib_xap_serve_d_wasm32_emcc, stdlib_xap_serve_notd_wasm32_emcc (imports transport.picoev), fabric_service, stdlib_fabric, stdlib_fabric_remote | corpus xap-compose/xap-dist/fabric/a2a-xap ring=2 |
   | session/authz/did/vc | stdlib_session, stdlib_authz, stdlib_did, stdlib_vc | corpus session/authz ring=2; did/vc = note N3 |
   | DB drivers | sql (verb surface), sql_mysql_d_cx_db_mysql, sql_pg_d_cx_db_pg, sql_sqlite_d_cx_db_sqlite, redis_d_cx_db_redis | corpus db ring=2; drivers import db.* |
   | io watch | stdlib_iowatch, stdlib_iowatch_darwin.c.v, stdlib_iowatch_linux.c.v + cx_iowatch_darwin.c, cx_iowatch_linux.c | corpus io watch cases ring=2 (I0 repair "io watch → 2") |

   Ring-2 production total: **63 .v files + 2 .c files** (plus the
   serve half of stdlib_http.v).

   **Ring-1 file census (production, stays):**

   - *Evaluator + language core (39):* api, ast_json, async, cabi,
     code_diagram, code_identity, cxpath_eval, cxpath_forward,
     cxpath_misc, cxpath_reverse, diagram, dispatcher_bridge,
     dynamic_construction, effect_alignment, error_hooks, eval,
     eval_stack_guard.c.v (+ cx_stack_guard.c), let_collapse,
     lower_to_cx_node, match_eval, matcher, modify_eval,
     module_loader, par_eval, predicate_eval, predicate_migrate,
     program_emit, program_fmt, program_xml, purity_checker, render,
     scheduler, select, state_locks, stdlib_bundle (embeds the 14
     cx-stdlib CX sources), stdlib_caps (capability enforcement is
     Ring 1 per spec §2), stdlib_dispatch, stdlib_cx,
     type_strict_validator.
   - *Pure stdlib packs (Ring-1 core, 27):* bytes, codec, crypto,
     csv, format, fp, ft, geo, hash, html, i18n, json, jsonschema,
     locale, math, mime(stdlib_mime), path, prof, re, sched,
     similar + similar_assign + similar_metaphone + similar_verbs,
     strings, testkit, url, uuid, validate.
   - *Local-effect packs (Ring 1, gated out of `embed` per §4 profile
     table):* stdlib_io (watch verbs excluded → Ring 2), stdlib_env,
     stdlib_process + stdlib_process_pty.c.v + cx_pty.c, stdlib_time,
     stdlib_random, stdlib_log, stdlib_term + cx_term.c.
   - *http client pack:* stdlib_http.v client half (§4: rides the
     `cli` profile).

   **Census notes:**
   - **N1 — the dispatch seam is the real work.**
     `stdlib_dispatch.v::stdlib_builtin` is a STATIC chain of ~45
     direct calls; store/sql/redis/net/http/bus/journal/fabric/
     session/authz/did/vc/xap/xap_dist/xsp/xsp_auth in that chain are
     Ring-1→Ring-2 compile-time edges, inverted vs §3. The split
     needs a registration seam: Ring-2 packs register their
     `<mod>_stdlib_builtin` chains into a Ring-1 registry (Ring 2 MAY
     import Ring 1; artifact roots trigger registration). Same
     pattern for directive-level entry points (services.v's
     [?http-service] family, [$store] URL dispatch) — enumerate at
     split time; the V compiler surfaces every residual edge the
     moment files change modules.
   - **N2 — `process` and `io` are Ring 1** (corpus tags process=1,
     io=1-except-watch; §4 cli profile lists them as local-effect
     packs). The plan row's "process/io" shorthand = the WATCH
     surfaces (spec §2 "process/io watch"); only iowatch moves to
     Ring 2. The I0 ring-tag repairs already ruled this.
   - **N3 — did/vc go Ring 2 by contract, not by the mechanical
     test.** Both import only cx + crypto/base58 (the test would say
     Ring 1); the plan row and G14 place them in Ring 2 as the
     substrate of the single authority model (§11). Enumeration wins.
   - **N4 — libcx ABI facts at cut:** code-side exports = 9 in
     cabi.v (cx_code_eval{,_with_len,_caps,_streaming},
     cx_code_diagram{,_with_level}, cx_code_ast_json,
     cx_wasm_set_wall_sleep, cx_wasm_is_asyncify) — all Ring 1 — plus
     2 C→V callback exports in stdlib_iowatch_darwin.c.v
     (cx_iowatch_emit, cx_iowatch_publish_runloop) — Ring 2, shipped
     in libcx today. The symbol baseline is captured at the cut
     (`make -C vcx lib` @ 7a38b6a6, `nm -gU`); the exit gate diffs
     against it. Artifact/ring reconciliation of the iowatch exports
     is I4's question; I3 preserves the surface bit-for-bit.
   - **N5 — hygiene:** the one `import code as _` blank-alias lives
     in `vcx/tests/data_bin_one_shots_test.v` (tests may import
     anything — no production hidden edge). `vcx/code/code.dylib` is
     untracked local build debris (not in git; no rider needed).

2. **libcx ABI gate landed FIRST (exit-gate machinery before any code
   moves — the I0 discipline applied to I3's own gate).** Baseline
   captured at the cut: `nm -gU` over dev-shape libcx @ 7a38b6a6 =
   713 exported symbols (166 cx_* intentional ABI + vendored C
   statics; V exports no module-mangled internals, so the full-list
   diff is stable across the split). Committed at
   `vcx/tests/runners/abi_gate/libcx_exports_baseline_darwin.txt`;
   `make libcx-abi-gate` wired into TEST_TARGETS. Verified green on
   the clean tree AND red on a synthetic baseline mutation
   (exit 2), then restored. Darwin-only baseline (Mach-O vs ELF
   export semantics); a Linux baseline joins if the linux lane ever
   runs TEST_TARGETS (today it builds only) — noted in the target
   comment.
