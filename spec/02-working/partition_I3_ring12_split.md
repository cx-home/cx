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
   comment. **OWNER RULED 2026-08-06 (session scorecard, 1a):**
   Darwin-only STANDS until the linux lane runs TEST_TARGETS; the ELF
   baseline is captured as part of THAT work, never before — an
   unexercised baseline is a dead artifact (seam-without-consumer).

3. **Pre-I3 corpus obligations G6 + G14 CLOSED (2026-08-06).**

   **G6 — `conformance/fmt.cxd` (ring=1, 12 cases) + NEW runner
   `vcx/tests/runners/fmt/fmt_conform.v` + `conform-fmt` lane** (vcx
   Makefile aggregate + root `test-vcx` recipe — the ring-1 suite does
   NOT ride the extraction battery, so it needed its own gate hook).
   The runner enforces the formatting.md contract MECHANICALLY on
   every positive case: byte-pinned output, §1 purity
   (cx_text_canonical(fmt(x)) == cx_text_canonical(x)), §7
   idempotence (fmt∘fmt = fmt); out-err cases pin the fail-closed
   CXER0100 lane. Coverage: fixed point, whitespace/indent, blank-line
   collapse, inline-short-element, quote-style preservation, [; …]
   note + trailing-hash-comment (own-line) preservation,
   scalars-as-written (1.50/007/offset-datetime), one-per-line wrap,
   program-faithful [?let]/multi-form docs. SCOPE: pins the ONE
   shipped profile (fmt_source's canonical layout); --profile surfaces
   are spec-forthcoming and gain families when they land.
   CORPUS-FORMAT LIMIT recorded in the suite doc: content containing
   the raw-block terminator sequence cannot ride a .cxd raw section
   (it closes the section), so hash-raw byte-exactness stays covered
   by fmt_lossless_test.v.

   **G14 — `conformance/stdlib/did.cxd` (ring=2, 25 cases) +
   `conformance/stdlib/vc.cxd` (ring=2, 17 cases)**, auto-discovered
   by the stdlib fixtures driver (no whitelist). Hermetic golden
   material: fixed seeds 01..20 / 40..5f → pinned did:key values;
   ed25519 determinism pins signatures byte-for-byte; mem:// journals
   for the revocation fold. did: key-create/peer-create, parse
   (key/web/peer + malformed), method, document (full did:key shape +
   not-self-describing lanes), key-of (round-trip, peer, non-Ed25519
   refusal), verify-control (pass / wrong signer / stale challenge),
   resolve (offline did:key, unsupported method, did:web net-DENIAL).
   vc: issue (full golden shape subject≠issuer + minimal), verify all
   six statuses (valid/expired/not-yet-valid/bad-signature via literal
   AND real-signature-tampered-claim/malformed/revoked), the
   revocation fold end-to-end (revoke event, CXER4609 attribution
   refusal, revoked-set, issue→revoke→verify), present passthrough,
   issue negatives, revoked-list negative control.

   **Findings → tracker (fixture-before-fix, both pinned as shipped):**
   - **#739** — vc.md's `valid?` surface is UNREACHABLE: the lexicon
     rejects `?` in the qualified call form (CXER0100); definition
     side parses. Pin = vc-016.
   - **#740** — did:resolve failure wraps the real cause (CXER0271
     net denial) in a misleading CXER-DID-DOC-MISMATCH + message=panic
     envelope. Pin = did-023.
   - **Harness gotcha worth remembering:** the #707 three-way grant
     policy scans OUT-ERR for CXER0271; a denial returned as an
     [err …] VALUE (rc=0) in out-text still gets grant-all — did-023
     initially hit the LIVE network from inside the fixture run.
     Explicit least-privilege `grant="read"` is the pattern for
     value-channel denial pins.
   - .cxd sections are parsed as real CX (the differential corpus
     parses suite files whole): section content must not contain the
     raw-terminator sequence ANYWHERE, not just at line starts.

   Validation: `make test-vcx-suite` green (did/vc fixtures enforced
   in the 2600+ battery); `conform-fmt` 12/12; cxparse differential
   UNCHANGED (stdlib in-cx [empty] docs don't move the baseline);
   gates-manifest-gate + ring-tag-gate green; extraction gate green
   (1564 Ring-0 cases, corpus census now R0=1564 R1=2010 R2=688 —
   growth rides Rings 1/2 only).

4. **The Ring-1→Ring-2 frontier ENUMERATED mechanically + seam design
   (2026-08-06).** Method: extract every top-level fn/type/const from
   the 68 Ring-2 production files, intersect with all identifiers used
   in the 76 Ring-1 files. Result: **65 frontier functions, 1 real
   type edge, 0 const edges** (Journal/ListenerHandler/XapHost/Span
   hits were comments or cx.Re2Span false positives). Clusters and
   dispositions:

   | Seam | Edges | Disposition |
   |---|---|---|
   | A. stdlib_dispatch.v chain | 17 `<mod>_stdlib_builtin` entries (store, sql, redis, email, net, http, bus, journal, fabric, session, authz, did, vc, xap, xap_dist, xsp, xsp_auth) | registry probe (LANDED, entry 5) |
   | B. eval.v env chains | 6 `_env` entries + try_eval_serve_file; TWO pre-split compositions (main chain probes serve-file+store, closure-callback chain does not) | registry with shared/main lists preserving both memberships (LANDED, entry 5) |
   | C. directive dispatch | 6 match arms (http-service, service-handle, stop, http-client, test-service-client, test-tls-config) + wait-for :service arm + dispatch_client_call ([http-client] postfix) | directive-handler map + two single-slot hooks |
   | D/E. iterator walkers | `iter_{net_accept,http_accept,sse_events,net_line,net_chunk}_walk(_streamed)` — 10 fns dispatched on `cx.IteratorNode.source_kind` (Ring-0 enum); the 20 net_*/http_* helper calls live INSIDE these walkers | move the walkers to Ring 2 wholesale + a source_kind→walker registry; .iter_iterate/.iter_unfold stay direct |
   | F. new_env resets | matcher.v calls session_reset_state + authz_reset_state (prof/sched resets are Ring 1, stay direct) | env-reset hook list |
   | G. module init | stdlib_codec.v init() seeds g_csrp_disco*/g_http_pool* + services_listener_init_globals + (now) ring2_register_all | rearranges at file-move time; single-init-per-module constraint noted in place |
   | H. crypto→http | crypto_jwks_fetch calls http_request_verb + http_body_text_impl (both CLIENT-side) | dissolves with the stdlib_http.v client/serve in-file split — http client is Ring 1 (§4 cli profile), so this edge is legal once the file splits |
   | I. io→iowatch | io_stdlib_builtin probes iowatch_dispatch inline | iowatch registers env-free via the A registry (probe precedes io in the chain; names disjoint) |
   | J. sched→journal | durable-timer persistence calls journal_stdlib_builtin BY NAME (3 sites) | call `ring2_stdlib_builtin('journal-…')` — registry-by-name; unregistered (embed) ⇒ the existing `or { return }` degrades persistence gracefully |
   | K. ft→store | ft_search_store resolves Store handles via store_get_open/store_doc_text/store_decode_doc | relocate ft_search_store to the Ring-2 side; its verb name registers via A |
   | L. identity→store | cx_code_store_put_def/get_def (MemStore — the one real type edge); consumers are Ring-2 xap_dist + tests | relocate both fns to the Ring-2 store side (they call Tier-2 hash helpers Ring-2→Ring-1, legal) |
   | M. loader→xap_dist | module_loader resolves pkg: URLs via xap_pkg_module_source | single-slot pkg-source resolver hook; unset ⇒ pkg: unavailable (correct profile behavior) |

   **Module naming decision:** the Ring-2 V module is `vcx/platform`
   (spec §2 names Ring 2 "platform"; the §4 profile that ships it is
   `platform`). Files move AFTER all seams are landed in-module and
   green — the V compiler then becomes the frontier oracle for any
   residual edge, and `code` retains zero compile-time references to
   platform symbols.

5. **Seams A+B LANDED (registry conversion, behavior-identical).**
   NEW `ring_registry.v` (Ring 1): fn-typed chains
   (`Ring2Builtin`, `Ring2BuiltinEnv`), @[has_globals] lists, register
   + probe fns; the ordering argument (entries name-gated, pack
   name-sets disjoint ⇒ collapsed probe position is
   behavior-identical, original relative order preserved regardless)
   written at the registry. NEW `ring2_register.v` (RING 2 — moves
   verbatim into the platform module's init at split): registers all
   17 env-free dispatchers (redis under its `$if cx_db_redis` pack
   gate), the 5 shared env dispatchers, and the 2 main-only env
   entries (serve-file, store). stdlib_dispatch.v chain: 17 direct
   entries → one probe; eval.v main env chain: serve-file + 6 env
   entries → one probe; try_stdlib_builtin_env: 5 entries → shared
   probe. Registration called from the module init()
   (stdlib_codec.v). Build green; full suite + gates at the seam
   commit.

6. **Seams C, D/E, F, I, J, K, L, M LANDED — the frontier is
   registry-clean (65 → 2 dispositioned residuals).**
   - **C (directives):** the six services match arms leave
     eval_directive; the `else` probes `g_ring2_directives` before the
     not-in-subset refusal (so an unregistered profile refuses exactly
     as before). eval_test_tls_config gains a signature adapter.
     wait-for :service and the [http-client] postfix dispatcher become
     single-slot hooks; unregistered ⇒ explicit profile refusal /
     fallthrough.
   - **D/E (live-source walkers):** the ten
     `iter_{net_accept,http_accept,sse_events,net_line,net_chunk}_walk(_streamed)`
     fns move VERBATIM to NEW Ring-2 `iter_walks_net_http.v`; both
     [?for] dispatch sites (buffered + streamed) collapse to one probe
     of `g_ring2_iter_walks(_streamed)` keyed by
     int(cx.IteratorSourceKind); .iter_iterate/.iter_unfold stay
     direct. The walkers drive the Ring-1 yield pipeline
     (gen_emit_item(_streamed), YieldSpec, ForLimitState, StreamCtx) —
     Ring-2→Ring-1, legal.
   - **F (resets):** new_env runs `ring2_run_env_resets()`; session +
     authz register. prof/sched resets stay direct (Ring 1).
   - **I (io watch):** iowatch_ring2_builtin registers on the env-free
     chain and CARRIES THE READ-CAP GATE WITH IT (cap_guard on
     io-watch/io-watch-next before any effect) — the registry probe
     precedes the io pack, so leaving the gate in io_stdlib_builtin
     would have BYPASSED it (caught in seam review; the io-105/106/107
     denial fixtures pin it). watch-close needs no cap (io-107's
     denial is the inner watch's).
   - **J (sched→journal):** the three durable-timer persistence sites
     call `ring2_stdlib_builtin('journal-…')` — registry-by-name;
     unregistered degrades persistence via the existing or-arms.
   - **K (ft):** ft_search_store moved to store_ft.v +
     store_ft_ring2_builtin claims 'ft-search-store'.
   - **L (identity storage):** cx_code_store_put_def/get_def moved to
     store_objgraph.v (beside store_put_raw/doc_present/doc_text);
     Tier-2 hashing stays in Ring-1 code_identity.v.
   - **M (loader):** pkg: resolution probes `g_ring2_pkg_source`
     (xap_pkg_module_source registered); unset ⇒ explicit
     "requires the distribution engine (platform profile)" error.
   - Residual frontier after this entry: **http_body_text_impl +
     http_request_verb** (crypto→http CLIENT; dissolves at seam H, the
     stdlib_http.v client/serve in-file split — client is Ring 1) and
     **services_listener_init_globals** (seam G, rearranges with the
     module init at file-move time). Everything else is
     registry-mediated or relocated.

7. **Seam H LANDED — the http client/serve split, and it pulled a NET
   TRANSPORT CORE out with it (2026-08-06).** The crypto→http residual
   is dissolved; the frontier census is clean (see below).

   **The split was bigger than the file it names.** The one-shot client
   core (pool/dial/exchange) was already Ring-1-clean — it dials V
   `net`/`net.mbedtls` directly. But the SSE CLIENT rides the buffered
   net handle table, and the corpus had already ruled SSE-client
   ring=1 (the I0 C8 per-case repairs: http-066/072/073). Pushing the
   SSE client to Ring 2 would have re-litigated that ruling AND gutted
   the §4 cli-profile http-client pack (xap_identity_model §4.12 needs
   an authenticating SSE client wherever the client pack ships). So
   the net transport CORE became Ring-1 infrastructure:

   - **NEW `net_core.v` (Ring 1)** — moved VERBATIM out of
     stdlib_net.v: NetHandle/NetRegistry + the handle registry global,
     register/lookup/mut_handle/handle_id/close_id (+ the SSE
     stream-slot release hook it calls), set_read_deadline_id, the
     §4.5 SSRF/DNS-rebinding guard (canonicalize/deny-set/spec-match/
     override/ssrf_check), dial tcp/tls, the buffered stream reads
     (read_line_buf/read_exact_buf/h_read/h_write/read-deadline
     arming/NetReadKind), socket_element, the tls/ms opts readers, the
     net error consts. stdlib_net.v keeps the RING-2 verb surface
     ([$net:…] — all ring=2 by corpus), listen/accept (tcp/tls/udp/
     dtls/unix), datagram + unix transports, resolve, sock-opts, and
     listener TLS rotation.
   - **NEW `stdlib_http_serve.v` (Ring 2)** — the serve half, moved
     verbatim: listen/accept-iter/exchange-request/respond/stop arms
     in a NEW `http_serve_stdlib_builtin` (registered via
     ring2_register.v in http's old chain slot),
     http_stdlib_builtin_env (http-serve) + http_serve_env, the
     serializers (keep-alive + chunked + reason phrases), the ONE
     query parser (#627 — all consumers are Ring 2), server handles,
     exchange wrap/finalize, bind-URL validation, and the SSE SERVER
     push half (sse/send-event/sse-publish/heartbeat/stream-open).
   - **stdlib_http.v (Ring 1)** = the http-client pack: client/close,
     introspection, one-shot verbs + request + send, the pool, the
     shared SSE frame/parse codec (the symmetry invariant stays one
     implementation), and the SSE client incl. the TWO WALKERS
     (`iter_sse_events_walk(_streamed)`) moved BACK from
     iter_walks_net_http.v — the [?for] sites dispatch them DIRECTLY
     like iterate/unfold (a Ring-1 pack's walk does not ride the
     Ring-2 registry; registration removed). Dispatcher renamed
     `http_client_stdlib_builtin`, chained directly in
     stdlib_dispatch.v after the registry probe (name sets disjoint ⇒
     position behavior-neutral).
   - **SSE stream counter**: stays Ring 1 beside net_core's close hook
     (net_close_id releases the slot); the Ring-2 server increments
     through NEW accessors http_sse_streams_at_cap /
     http_sse_stream_opened — check-before-write order preserved
     exactly (bound check early, increment only after the prelude
     write succeeds).
   - `store_null()` → `http_null()` in http_dial_conn (2 sites,
     value-identical) — the client half's only store reference, gone.

   **Frontier re-check found a const edge the entry-4 census
   under-reported:** `stdlib_src_{store,journal,xap,fabric}` were
   defined in their Ring-2 pack files but consumed by RING-1
   stdlib_bundle.v (register_source / bundled_stdlib_source). Moved to
   stdlib_bundle.v beside the other 38 embeds ($embed_file paths are
   file-relative and unchanged — same directory). The embedded CX
   surface is DATA in Ring 1; the packs' native primitives register
   via ring2_register.v, and an artifact without them refuses at call
   time. Re-enumeration (entry-4 method, scripted) now shows the
   frontier = exactly the two dispositioned seam-G init residuals
   (`ring2_register_all`, `services_listener_init_globals`) + method-
   name noise on distinct receiver types. stdlib_codec.v's init()
   comment now records the seam-H truth: the g_http_pool seeds STAY
   Ring 1 (client pool); g_csrp_disco + listener globals move with G.

   **Corpus:** http-067/068 (last-event-id present/absent) retagged
   ring=1 with a provenance note — PURE accessors over the CLIENT
   [sse-source]; the C8 repair tagged the equally-pure 066 but missed
   this pair. Census: **R0=1564 (untouched), R1=2012 (+2),
   R2=686 (−2)**; doc-lane total 4262 unchanged. The in-case `[; …]`
   notes are inert to the fixture loader (sections are read by known
   key only) and to the cxparse differential (in-cx doc count
   unchanged; baseline holds at 741).

   **Validation:** full `make test-vcx-suite` 240/241 + the one FAIL
   (fabric_nats_bridge_test) green on the recipe's classified
   cache-free retry (#572 stale-usecache class — expected after
   moving code between files; also reproduced green standalone);
   conform-fmt 12/12; ring-import-gate + gates-manifest-gate +
   ring-tag-gate OK; extraction gate BOTH lanes byte-identical (1564
   Ring-0 cases; ABI transcript 4498070 bytes, CLI 8978 pairs + 17
   refusals); **libcx-abi-gate: 713-symbol surface identical to the
   I3-cut baseline**.

   **Move-time notes banked for the module move (next):** cmd/cli
   carry 23 `code.<sym>` references to Ring-2 symbols (fabric_serve +
   store daemon verbs) that retarget to the platform module; the
   platform module's init() takes g_csrp_disco seeds +
   services_listener_init_globals + ring2_register_all; code's init()
   keeps json codec registration + g_http_pool seeds +
   ring_registry_init; libcx builds over the platform module dir (it
   imports code, pulling the full surface — ABI gate pins the 713);
   cmd needs `import platform as _` so registration init runs.
