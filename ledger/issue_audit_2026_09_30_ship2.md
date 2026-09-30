# Issue audit 2026-09-30 — open issues without v0.18 (cx-private) and the component repositories

Head `cc14beee6` (= origin/release/0.18), graded green: `2026-09-30T14:59:02Z cc14beee6 RUN-EXIT=0 passed selected` (the prior: `2026-09-30T13:51:21Z 05889bf2d RUN-EXIT=0 passed selected`). Release cx: `deps/cx-core-code/vcx/target/cx` = `cx v0.18.0-pre.1-dev+cc14beee6` (core fbe9753, V fork 27cbbcdb10). Component trees read at the head's pins under `deps/<repo>/`. Repros run in the session scratchpad, never in the checkout.

Amendment (owner, relayed 15:2xZ): every actionable OPEN/STALE issue labelled `v0.18` (cx-private) or title-prefixed `v0.18 ` (component); only the non-actionable left out (listed at the end).

| issue | class | one-line measurement | action taken |
|---|---|---|---|
| cx-private#1717 | FIXED | `[$cx:to-format [$cx:parse …] "yaml"]` now gives service-a host/tls/port, same as `cx --to=yaml` (doc leftovers `b8fe372da`) | closed |
| cx-private#1715 | FIXED | plugs_svg.cx prints "the root of the graph" only for `site-self`, else "none recorded" (`7465e4303` ancestor of head) | closed |
| cx-private#1662 | FIXED | guide_build.cx globs `deps/*/stdlib/*.cx` + `deps/*/x/*.cx` (`a3285d7bb`); 84 `docs/guide/lib-*.html` | closed |
| cx-private#1663 | FIXED | guide-render-gate removes index.html/codec-xml.html before render and requires them after; no `-nt` left (`60382f583`) | closed |
| cx-private#1654 | FIXED | README.md:225 links `https://github.com/cx-home/cx-platform-store/blob/main/spec/…/store.md` (`0685659f7`); verify-doc-links in the green docs runs | closed |
| cx-private#1696 | FIXED | serve_static.cx serves through `[$serve-file]` (`4e9b282ff`) | closed |
| cx-private#1682 | FIXED | `conn_cx()`/`wh_cx()` take the `cx` beside `testenv.cx_bin()`, never the root `vcx/target/cx` (connector pin); the leftover root binary (2026-09-26) still exists in the main checkout | closed |
| cx-private#1614 | FIXED | option (a) on the head: env_retention_test.v on SUITE_SERIAL_RETRY with a declared reason (`5672a1d2e`); loop green | closed |
| cx-home/cx-core-code#3 | FIXED | computed `name=` now keys per value: 4th call `name='b'` = test-failure (breaker), `(ok, ok, CXER0151, ok)` (rate-limit) — CBKEY-1 `0f09ba4e2` | closed |
| cx-platform-flow#14 | FIXED | `f--session-principal` reads `id=` when present (flow.cx:815) | closed |
| cx-platform-xap#3 | FIXED | composition.md rows S-42 (flow → xsp, the host's session) and S-43 (flow → vc, did, the step-ack) present at the pin | closed |
| cx-platform-connector#3 | FIXED | connector_webhook_test.v:169 `[timeout per-attempt='5s']` | closed |
| cx-platform-connector#4 | FIXED | every `[?retry]` predicate is `[$c--retry-on [$string $e@retryable]]` (connector.cx:5936–5941) | closed |
| cx-platform-connector#7 | FIXED | `c--walk-pages` calls the budget refusal and the spend record per page | closed |
| cx-platform-connector#10 | FIXED | `[$sync:validate [feature …]]` answers `[findings]`, no CXER0100 | closed |
| cx-platform-db#1 | FIXED | db_access.md §6.1 table (sqlstate=/sqlite=/redis=); db.cxd db-024/028/030 enforced, 32 passed 0 failed on the release cx | closed |
| cx-platform-db#3 | FIXED | the pinned `sql_mysql_d_cx_db_mysql.v` no longer calls `Result.free()` (C.mysql_free_result) | closed |
| cx-platform-identity#1 | FIXED | stdlib_did_web.v:41 decodes `%3A`/`%3a` in the domain segment | closed |
| cx-private#1664 | STALE | BARE-1 (0f09ba4e2) made every bare def-named head data: all five calls now answer `[f 3]`/`[h 3]`; LINTB-1 (L142) ruled the lint, `cx lint --fail-on=info` still `[]` | commented; v0.18 |
| cx-private#1581 | STALE | still reproduces on `profiles/cli/cx` (+cc14beee6): CXER0136 no callable "journal-open"; `vcx/platform/ring2_register.v` gone, the bundle table is cx-core-code's | commented; v0.18 |
| cx-private#1624 | STALE | D56a moved the data-side cores to cx-core-data; `vcx/corpus/grade.v` (module corpus) stays at the front door and cx-core-code's corpus_verb.v, grader.v, code_eval_fixtures_test.v import it — the upward edge exists | commented; v0.18 |
| cx-private#1622 | STALE | the five register files moved to net/mail/store/xap pins; D35a still binds | commented; left out (D35a) |
| cx-private#1650 | STALE | `fab_remote_receive` still holds `fr.mu` (lock + defer) across the drain; test and adapter now in cx-platform-fabric; no front-door roster row | commented; v0.18 |
| cx-private#1648 | STALE | release cx `fmt` on the same 1,377,998-byte doc: 7.61–7.70 s (load 25) vs 1304 ms floor; run_bench_json.cx's row still execs the retired `vcx/target/cx` | commented; v0.18 |
| cx-private#696 | STALE | PLAY-1/PLAY-2 shipped the browser playground (docs/guide/playground.html) with share-by-URL (base64url text, `#ex=` ids); content-addressed snippets not built | commented; v0.18 |
| cx-private#746 | STALE | examples/cxstore → cx-platform-store; xsp_store_profile.md → cx-platform-store spec/03-approved/xap/; xsp.md → cx-platform-xsp | commented; v0.18 |
| cx-private#747 | STALE | CK-10 ruled the scoping; tooling/cxfabric/ → cx-platform-fabric | commented; v0.18 |
| cx-private#987 | STALE | the diagram module left with cx-tooling (RS-5); DIAGB-1 ruled bare heads for it; `--view=instance` refused (accepted: auto, erd, cfg, seq, effects) | commented; v0.18 |
| cx-private#1441 | STALE | vcx/arrow/arrow.v → cx-core-data | commented; v0.18 |
| cx-private#1442 | STALE | vcx/cx/binary.v → cx-core-data | commented; v0.18 |
| cx-platform-flow#2 | STALE | "a ruling is needed" superseded: 1387-a + 1387-b (owner 09-17); neither `cx_wasm_set_manual_clock` nor the inline pump is on the pins | commented; titled v0.18 |
| cx-private#1722 | OPEN | `[?let [= $e [err …]] $e?]` → CXER0100 unexpected `?`; needs its letter | v0.18 |
| cx-private#1721 | OPEN | lsp_content.v:292 still says L003; lint.v CX-L003 = unused anchor | v0.18 |
| cx-private#1720 | OPEN | two-deep `[?let]` cascade: `cx lint --fail-on=info --format=json` → `[]` | v0.18 |
| cx-private#1718 | OPEN | item 1 reproduces (`--data` multi-root → 0); items 2 and 3 no longer (`--data` expands; corpus answers CXER0271) | v0.18 |
| cx-private#1716 | OPEN | code.cxd `program-builtin-concat` still carries `[in-cx [ignored]]` | v0.18 |
| cx-private#1714 | OPEN | secrets/sso/ux rows of registry/repos.cxd still carry no `pins=` | v0.18 |
| cx-private#1713 | OPEN | `[and false [$io:read-file '/no/such']]` → CXER3401, exit 1 | v0.18 |
| cx-private#1712 | OPEN | process.md has no append disposition nor `stderr: :stdout` | v0.18 |
| cx-private#1711 | OPEN | io-lock arm still "Advisory locking is not portably exposed…" (stdlib_io_notd_cx_no_pack_io.v:1283) | v0.18 |
| cx-private#1710 | OPEN | flow.md grants observe only to `effect=observe` verbs; no hand-written observe act | v0.18 |
| cx-private#1709 | OPEN | repro → CXER4953 act resolves to nothing | v0.18 |
| cx-private#1708 | OPEN | plugs_svg fixed (`[$string BOX-W]`); the ask stands: `[rect width=BOX-W]` emits the name, lint `[]` | v0.18 |
| cx-private#1707 | OPEN | no `--stay` in the flow CLI or flow.md | v0.18 |
| cx-private#1706 | OPEN | process.md / env.md: no foreign-pid probe | v0.18 |
| cx-private#1705 | OPEN | process.md / env.md: no signal handler registration | v0.18 |
| cx-private#1704 | OPEN | `name: x (RULED: C-1)` plain scalar still read, exit 0 | v0.18 |
| cx-private#1703 | OPEN | suite paths fixed by `fcc2c2218` (deps/cx-core-code/vcx/tests/…); the `2 of 1` denominator still counts the front door's vcx/tests | v0.18 |
| cx-private#1702 | OPEN | `{timeout: 10}` → V panic string index out of range (code__duration_to_ns) | v0.18 |
| cx-private#1701 | OPEN | cx-core-code has no VERSION (build_libcx_wasm.sh:103 reads its own root); re2_shim.c returns NULL | v0.18 |
| cx-private#1698 | OPEN | flow repo-acts.cx lines 37/41/81 call `$cat`, defined nowhere in the module | v0.18 |
| cx-private#1695 | OPEN | cx-gap: no CDP/WebSocket client; the node harness stands | v0.18 |
| cx-private#1689 | OPEN | no front-door target names deps/cx-platform-xap/vcx/tests | v0.18 |
| cx-private#1688 | OPEN | repo-gate.flow.cx:10 validate line still lacks `--allow-read` | v0.18 |
| cx-private#1685 | OPEN | ed25519-sign reads its seed with `crypto_arg_bytes` (stdlib_crypto.v:451) | v0.18 |
| cx-private#1684 | OPEN | stdlib_fabric_remote.v:230 `seed = arg_bytes(v)`; no `attempts=` on a received entry | v0.18 |
| cx-private#1681 | OPEN | `[$time:duration-ms 100]` → 100000000 (int); `[+ [$time:parse-duration '3s'] 3s]` refused | v0.18 |
| cx-private#1680 | OPEN | cx-gap: code.md §12.6 has two visibilities; needs the decision | v0.18 |
| cx-private#1678 | OPEN | `CX_CONNECTOR_SECRET_X_Y=hello cx -e '[$session-secret-resolve 1 "handle:x/y"]'` → hello, no grant | v0.18 |
| cx-private#1677 | OPEN | `$string` of a secret → x; `[__cx_secret__ $v]` pattern → x; `::secret` test → no; `$concat` refuses | v0.18 |
| cx-private#1674 | OPEN | release_linux.sh:124 tar list unchanged (no deps/, `vcx stdlib x`) | v0.18 |
| cx-private#1672 | OPEN | cx-gap: release_asset_links_selftest.sh stands; a binary-download primitive is designable | v0.18 |
| cx-private#1668 | OPEN | not reproduced by length: rows of 1.1–2.7 KB and a 791-byte why= (db) match, gate OK; KEY-1's text not recovered — the asked fixture is owed | v0.18 |
| cx-private#1667 | OPEN | FAQ fixed (`1b87aed63`, snippet check 160 pass 0 fail); guide-snippets-check still not in TEST_TARGETS | v0.18 |
| cx-private#1666 | OPEN | pure def with `[?modify]` → CXER0233 at run; lint exit 0 | v0.18 |
| cx-private#1665 | OPEN | repro → second query CXER4711 "check expects an open [authz-store] handle" | v0.18 |
| cx-private#1661 | OPEN | `[?lib]` of a `[# … #]` module → CXER0210 MODULE_PARSE unbalanced at 0 | v0.18 |
| cx-private#1660 | OPEN | mktemp half done (vcache_soundness_gate.sh:89); probe builds still `>/dev/null 2>&1` (l.228–230) | v0.18 |
| cx-private#1659 | OPEN | AGENT-STANDING-RULES.md:238 still carries the manual `grep -vE` strip | v0.18 |
| cx-private#1649 | OPEN | `TMPDIR=… [$io:system-temp-dir]` → '/tmp' | v0.18 |
| cx-private#1644 | OPEN | `cx FILE` reads the comma as a sequence separator (measured); parse_program's position not re-measured (V test only) | v0.18 |
| cx-private#1642 | OPEN | the workaround `xap_gc_join_names` stands in xap; the fork codegen defect not bisected | v0.18 |
| cx-private#1640 | OPEN | fork 27cbbcdb10: `v -gc e test vlib/builtin/array_test.v` fails l.89/111/146 | v0.18 |
| cx-private#1636 | OPEN | `cx corpus conformance/llm/antipatterns.cxd` → 20 passed, 4 failed; D70 (b) refusal not built | v0.18 |
| cx-private#1632 | OPEN | cx-decisions' Makefile still `check-tree` only, "cannot run ledger-index-check on itself" | v0.18 |
| cx-private#1630 | OPEN | repro → `[proc-result exit-code=1 … stderr='No such file or directory; code: 2\n']` | v0.18 |
| cx-private#1629 | OPEN | fork array_notd_gcboehm_opt.v:17 `__new_array_noscan` forwards to `__new_array` | v0.18 |
| cx-private#1628 | OPEN | fork vgc_platform.h:540 `vgc_s2c8[(size + 7) >> 3]` over a table filled for `(i+1)*8` | v0.18 |
| cx-private#1623 | OPEN | `v -check` of the probe: l.346 `expected cx.Node, not cx.LazyRecord` (plus `import xap` not found) | v0.18 |
| cx-private#1616 | OPEN | stdlib/x half fixed (DEPS_EMBED_SRC); the comment's address stands: 15 `$embed_file`s of flow `data/` in vcx/cmd, not in DEPS_EMBED_SRC | v0.18 |
| cx-private#1608 | OPEN | mute.cx under `--allow-read` prints nothing, exit 0 | v0.18 |
| cx-private#1604 | OPEN | `cd libtest && cx sub/p.cx` → CXER0210 `./m.cx` not readable | v0.18 |
| cx-private#1601 | OPEN | devbox.json `setup` has no gitconfig rewrite (and ends `vcx/target/cx --version`, a retired path) | v0.18 |
| cx-private#1593 | OPEN | cmp-005 bound still 1.50, gauge still box-dependent; dev2 full unions pass (09-28/29/30) at VJOBS=14 | v0.18 (milestone already v0.18) |
| cx-private#1440 | OPEN | V fork: `[mut x]` by-value capture, no warning; actionable in the fork | v0.18 |
| cx-private#1439 | OPEN | V fork: `-shared` exports all symbols; actionable in the fork (include/cx.h now cx-core-code's) | v0.18 |
| cx-private#1321 | OPEN | not re-measured (bench/flow now cx-platform-flow's); milestone v0.19 stays | v0.18 (milestone v0.19 — integrator to reconcile) |
| cx-private#1286 | OPEN | VG-2a ruled; no prefs:/view: verbs in ux | v0.18 |
| cx-private#1125 | OPEN | pty race still on SUITE_SERIAL_RETRY (Makefile:3269, reason #1125); root not fixed | v0.18 (milestone v0.19 — reconcile) |
| cx-private#1008 | OPEN | per its 09-07 comment: a CI dispatch on the fork's FreeBSD workflow with the one-definition test un-skipped | v0.18 (milestone v0.19 — reconcile) |
| cx-private#804 | OPEN | gate-15 honest red not re-measured; engine work | v0.18 (milestone v0.19 — reconcile) |
| cx-private#800 | OPEN | members #751 #786 #797 #798 #799 closed NOT_PLANNED into this epic (TRIAGE-1); the epic carries the scope | v0.18 |
| cx-private#750 | OPEN | design track; no `cx view` verb | v0.18 |
| cx-private#748 | OPEN | no pdf module; its references are now cx-core-code's stdlib | v0.18 |
| cx-private#735 | OPEN | design track (IaC profile) | v0.18 |
| cx-private#734 | OPEN | RFLOW-1/CICD-1 made the repo's own CI/CD flow documents; the pipeline profile + hermetic executor of the issue not built | v0.18 |
| cx-private#733 | OPEN | design (TS client); RS-3 archived cx-binding-typescript — the letter should say where it would live | v0.18 |
| cx-private#732 | OPEN | design track | v0.18 |
| cx-private#731 | OPEN | design track (depends on #750) | v0.18 |
| cx-private#729 | OPEN | design track | v0.18 |
| cx-private#728 | OPEN | umbrella; SEC-1 (component 6) shipped as cx-platform-secrets; kit waves running | v0.18 |
| cx-private#699 | OPEN | no package-manager distribution | v0.18 |
| cx-private#697 | OPEN | no `cx schema infer` | v0.18 |
| cx-home/cx-core-code#2 | OPEN | DEPS_V_DIRS = `$(wildcard $(r)/*/)` still includes `target/` (vcx/Makefile:50) | titled v0.18 |
| cx-home/cx-core-code#1 | OPEN | `sch_rearm_intent` still builds `journal: cx.mk_element(cx.Element{})` (l.1668) | titled v0.18 |
| cx-platform-flow#13 | OPEN | `cx flow diagram --level=full` still drops `await-export` and `poll` | titled v0.18 |
| cx-platform-flow#1 | OPEN | enhancement; W3 (its prerequisite) shipped | titled v0.18 |
| cx-platform-xap#7 | OPEN | not re-run (filed today); no step runs the check | titled v0.18 |
| cx-platform-xap#5 | OPEN | needs its letter (a/b/c in the body) | titled v0.18 |
| cx-platform-xap#4 | OPEN | canonical issue for the umbrella test's pinned layout; no step runs it | titled v0.18 |
| cx-platform-connector#13 | OPEN | c--imap-open-link still hands `[auth scheme= handle=]` (connector.cx:6017); needs its letter | titled v0.18 |
| cx-platform-connector#12 | OPEN | fixed only on `impl/kitw1c` (kit wave 1C, running); not on the pin | titled v0.18 |
| cx-platform-connector#11 | OPEN | needs its letter (a/b/c) | titled v0.18 |
| cx-platform-connector#8 | OPEN | vendor window keyed by the handle (design, with #6) | titled v0.18 |
| cx-platform-connector#6 | OPEN | `$session-binding-open $feature $tenant` (connector.cx:5679), no deployment | titled v0.18 |
| cx-platform-connector#5 | OPEN | repro → `[d1 [decision 'denied'] [emit 'cx-err:CXER6200']]` | titled v0.18 |
| cx-platform-connector#2 | OPEN | circuit-breaker threshold/window still literal (connector.cx:6408); attempts= and §13.2 not done | titled v0.18 |
| cx-platform-db#5 | OPEN | not re-measured (filed today) | titled v0.18 |
| cx-platform-db#4 | OPEN | not re-measured (filed today) | titled v0.18 |
| cx-platform-db#2 | OPEN | fork sqlite.c.v `exec` loop still `if res != sqlite_row { break }`, code dropped | titled v0.18 |
| cx-platform-store#4 | OPEN | stdlib_audit.v:261–263 still sets `j.reserved_append_ok` on the handle | titled v0.18 |
| cx-platform-store#3 | OPEN | not re-measured; a decision (durability vs documented limit) | titled v0.18 |
| cx-platform-store#2 | OPEN | not re-measured (flake; fixture of 30 owed) | titled v0.18 |
| cx-platform-store#1 | OPEN | not re-measured; three live.md §7 gaps | titled v0.18 |
| cx-platform-mail#1 | OPEN | enhancement (interop lane, RULED 1085-a) | titled v0.18 |
| cx-platform-ux#4 | OPEN | no theme-resolve / allow / adopt-base in x/ux-web.cx | titled v0.18 |
| cx-platform-ux#3 | OPEN | no theme-color / web manifest emission | titled v0.18 |
| cx-platform-ux#2 | OPEN | no nav-group | titled v0.18 |
| cx-platform-ux#1 | OPEN | ux:column carries no href/sort | titled v0.18 |
| cx-platform-identity#2 | OPEN | `did_web_resolve` calls `http_request_verb([get, url])`, never reads opts (l.52) | titled v0.18 |
| cx-private#1697 | DUPLICATE | of cx-home/cx-core-code#2 (same DEPS_V_DIRS/target defect, filed 10 h earlier, in the owning repository) | none |
| cx-private#1679 | DUPLICATE | of cx-home/cx-platform-connector#13 (the imap `[auth handle=]` defect with its letter) | none |
| cx-platform-xap#6 | DUPLICATE | of cx-platform-xap#4 (the same `cannot list ./fabric` panic of the pinned layout) | none |
| cx-platform-xap#8 | DUPLICATE | of cx-platform-xap#4 (the umbrella's pre-split path scans) | none |
| cx-private#1591 | OPEN (left out) | the split board; tracker, no work | none |
| cx-private#1519 | OPEN (left out) | the v0.18 board of 09-14; tracker, no work | none |
| cx-private#1589 | OPEN (left out) | the split's design of record; shape approved, split complete | none |
| cx-private#954 | OPEN (left out) | blocked outside the tree: Linguist's adoption bar | none |
| cx-private#1444 | OPEN (left out) | a question for upstream V; posting is the owner's | none |
| cx-private#1443 | OPEN (left out) | upstream V language feature (generators) | none |
| cx-private#834 | OPEN (left out) | needs a Linux host with a signal-owning Go host; no such runner | none |
| cx-private#1011 | OPEN (left out) | needs a Windows runner; its 09-07 comment: nothing to fix | none |
| cx-private#517 | OPEN (left out) | Windows investigation-only by ruling; no Windows host | none |
| cx-private#1724 | OPEN (left out) | blocked on the V toolchain's Windows support | none |
| cx-private#784 | OPEN (left out) | NOT SCHEDULED by its own record: after #681 (closed) and M5's replica consumer | none |
| cx-private#801 | OPEN (left out) | NOT SCHEDULED; its open decision is ruled at scheduling | none |
| cx-private#521 | OPEN (left out) | trigger-bound: multi-node demand proven by a consumer | none |
| cx-private#1673 | OPEN (left out) | cx-gap with no work: the bootstrap precedes any cx by construction | none |
| cx-platform-xap#9 | OPEN (left out) | HKEY-1 (owner, Letter 125 (a)) puts it after the v0.18.0 cut | none |

## Counts

- **cx-private, not v0.18 (108):** FIXED 8 (closed) · STALE 12 (commented) · DUPLICATE 2 · OPEN 86. Labelled `v0.18`: 83 (72 OPEN + 11 STALE). Open v0.18 in cx-private after the audit: 146.
- **Components (41):** FIXED 10 (closed) · STALE 1 (commented) · DUPLICATE 2 · OPEN 28. Title-prefixed `v0.18 `: 28 (27 OPEN + flow#2).
- **Left out of v0.18 (20):** cx-private #1591 #1519 #1589 #954 #1444 #1443 #834 #1011 #517 #1724 #784 #801 #521 #1673 #1622; cx-platform-xap#9; duplicates cx-private#1697 #1679, cx-platform-xap#6 #8.
- Not in scope, seen: cx-private#1728 (filed during the audit, unlabelled).
- Corrections posted after my own comments: #1614 (the "no red since" sentence narrowed to the six logs read), #987 (`--view=` accepts auto, erd, cfg, seq, effects).
