# The ledger index

Every decision id this store carries, and where to read it. **Generated** by
[`scripts/ledger_index.cx`](../scripts/ledger_index.cx) -- run `make ledger-index`
after adding or editing a ledger page; `make ledger-index-check` is the drift step
and fails when this file is stale. Do not edit it by hand.

A commit subject ends `(RULED: <id>)`; this is how that id resolves.

## Declared -- the heading that carries the decision

| id | file | heading |
|---|---|---|
| `1058-q1` | [rulings_2026_09_07_fmt_layout_followups_1058.md](rulings_2026_09_07_fmt_layout_followups_1058.md) | RULED 1058-Q1 (a) — `cli.md` §3.1's "authorial structure" sentence is corrected |
| `1058-q2` | [rulings_2026_09_07_fmt_layout_followups_1058.md](rulings_2026_09_07_fmt_layout_followups_1058.md) | RULED 1058-Q2 (a) — a number's SPELLING is preserved where it is meaning-bearing |
| `1058-q3` | [rulings_2026_09_07_fmt_layout_followups_1058.md](rulings_2026_09_07_fmt_layout_followups_1058.md) | RULED 1058-Q3 (a) — the 10 MB `cx fmt` cost is filed |
| `1058-t1.2` | [rulings_2026_09_05_fmt_module_directive_and_layout_1318_1058.md](rulings_2026_09_05_fmt_module_directive_and_layout_1318_1058.md) | RULED 1058-T1.2 — one emitter, two widths |
| `1058-t1.2` | [rulings_2026_09_05_fmt_module_directive_and_layout_1318_1058.md](rulings_2026_09_05_fmt_module_directive_and_layout_1318_1058.md) | 1058-T1.2 IMPLEMENTED (2026-09-07) — measured, and two rules the record did not anticipate |
| `1058-t1.2-b` | [rulings_2026_09_05_fmt_module_directive_and_layout_1318_1058.md](rulings_2026_09_05_fmt_module_directive_and_layout_1318_1058.md) | RULED 1058-T1.2-b — the data lane's dangling closer stays |
| `1058-t1.4-b` | [rulings_2026_09_08_unterminated_opener_1058.md](rulings_2026_09_08_unterminated_opener_1058.md) | RULED: 1058-T1.4-b — the parser names the construct that was never closed |
| `1058-t1.6-b` | [rulings_2026_09_08_no_callable_code_and_builtin_content_type_1058.md](rulings_2026_09_08_no_callable_code_and_builtin_content_type_1058.md) | RULED: 1058-T1.6-b, 1058-T1.7-a, 1058-T1.7-c |
| `1058-t1.7-a` | [rulings_2026_09_08_no_callable_code_and_builtin_content_type_1058.md](rulings_2026_09_08_no_callable_code_and_builtin_content_type_1058.md) | RULED: 1058-T1.6-b, 1058-T1.7-a, 1058-T1.7-c |
| `1058-t1.7-c` | [rulings_2026_09_08_no_callable_code_and_builtin_content_type_1058.md](rulings_2026_09_08_no_callable_code_and_builtin_content_type_1058.md) | RULED: 1058-T1.6-b, 1058-T1.7-a, 1058-T1.7-c |
| `1058-t1.8-a` | [rulings_2026_09_08_no_callable_code_and_builtin_content_type_1058.md](rulings_2026_09_08_no_callable_code_and_builtin_content_type_1058.md) | T1.8 — 1(a): the Content-Type fallback moves to the WIRE layer (RULED: 1058-T1.8-a, Fable 2026-09-09 04:09 ET) |
| `1058-t1.9-a` | [rulings_2026_09_09_def_interior_comments_1058_t19.md](rulings_2026_09_09_def_interior_comments_1058_t19.md) | RULED: 1058-T1.9-a — def-body comments are RECORDED with their depth and PLACED by the width-bounded layout |
| `1061-a` | [rulings_2026_09_17_probe_scoping_1061.md](rulings_2026_09_17_probe_scoping_1061.md) | Owner decision 2026-09-17 ~19:15Z — `--probe` means the working tree: read/write path scoping (#1061) is pulled into lane 7's branch (the probe preset) (RULED: 1061-a) |
| `1066-q1` | [rulings_2026_09_04_diagram_def_namespace_1066.md](rulings_2026_09_04_diagram_def_namespace_1066.md) | Question 1066-Q1 — what image mints the def namespace? |
| `1068-a` | [rulings_2026_09_07_diagram_binding_bridge_1068.md](rulings_2026_09_07_diagram_binding_bridge_1068.md) | RULED 1068-A — the binding registry, and the for-comp anchor is `lh` |
| `1068-b` | [rulings_2026_09_07_diagram_binding_bridge_1068.md](rulings_2026_09_07_diagram_binding_bridge_1068.md) | RULED 1068-B — golden movement authorized, 8 renders and 2 conformance rows |
| `1074-a` | [rulings_2026_09_01_process_disposition_caps_1074.md](rulings_2026_09_01_process_disposition_caps_1074.md) | RULED: 1074-a — `run`/`spawn` file dispositions are charged to `write` (#1074) |
| `1075-q1` | [rulings_2026_09_04_pipeline_rows_on_timeout_1075.md](rulings_2026_09_04_pipeline_rows_on_timeout_1075.md) | Question 1075-Q1 — what row does a stage the deadline stopped before it started get? |
| `1085-a` | [rulings_2026_09_11_email_world_class_agentic_1085.md](rulings_2026_09_11_email_world_class_agentic_1085.md) | RULED: 1085-a — v0.18 carries a WORLD-CLASS, AGENT-READY email system, client AND server: SMTP + IMAP as protocol modules with both halves, the mailbox as an XAP feature whose intents are the agent surface, delivery on the saga substrate |
| `1085-b` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) | RULED: 1085-b — the ten open rulings in the `smtp.md` / `imap.md` working drafts, plus `cx-stdlib/sasl` as a shared module |
| `1085-b` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) | Consequences for the drafts (the steward applies them; each block becomes decided text citing `RULED: 1085-b`) |
| `1085-c` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) | 1085-c — implementation rulings |
| `1085-d` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) | 1085-d — `[delivery]` carries BOTH the parsed `[message …]` and the raw `[body <bytes>]` |
| `1085-e` | [rulings_2026_09_13_mail_hosting_deferred_connector_line_1085e.md](rulings_2026_09_13_mail_hosting_deferred_connector_line_1085e.md) | RULED: 1085-e — CX does not host mailboxes (now); CX owns protocols, not system connectors (owner, 2026-09-13) |
| `1099-a` | [rulings_2026_09_10_run_surface_err_at_rest_1099.md](rulings_2026_09_10_run_surface_err_at_rest_1099.md) | RULED: 1099-a — the run surface's exit status counts a COMPUTED err at any depth of the result; a WRITTEN err is data wherever it sits |
| `1103-a` | [rulings_2026_09_10_scim_attribute_projection_1103.md](rulings_2026_09_10_scim_attribute_projection_1103.md) | RULED: 1103-a — SCIM attribute projection ships in v0.18, and `returned: never` is not narrowable in either direction |
| `1150-a` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) | Integrator decisions, 2026-09-17 — the Ring 0 rulings owed (1363-b, 1387-a, FMT-2, GRADER-1, 1150-a, 1250-b) |
| `1151-a` | [rulings_2026_09_07_doc_drift_1342_1151_1152.md](rulings_2026_09_07_doc_drift_1342_1151_1152.md) | RULED 1151-A — diagram.md's retired match-cost figure is replaced by the record |
| `1152-a` | [rulings_2026_09_07_doc_drift_1342_1151_1152.md](rulings_2026_09_07_doc_drift_1342_1151_1152.md) | RULED 1152-A — bus.md is trued to the shipped `::any`, not the reverse |
| `1152-b` | [rulings_2026_09_07_doc_drift_1342_1151_1152.md](rulings_2026_09_07_doc_drift_1342_1151_1152.md) | RULED 1152-B — stdlib/fp.cx's header note is deleted, not corrected |
| `1170-d` | [rulings_2026_09_08_playground_output_pin_1170.md](rulings_2026_09_08_playground_output_pin_1170.md) | 1170-d / 1170-e / 1170-f — the mermaid gate joins the matrix (RULED, Fable 2026-09-09 05:07 ET) |
| `1170-d` | [rulings_2026_09_08_playground_output_pin_1170.md](rulings_2026_09_08_playground_output_pin_1170.md) | 708). They are a NAMED, COUNTED skip — `cx: image (1170-d)` in the gate's |
| `1170-e` | [rulings_2026_09_08_playground_output_pin_1170.md](rulings_2026_09_08_playground_output_pin_1170.md) | 1170-d / 1170-e / 1170-f — the mermaid gate joins the matrix (RULED, Fable 2026-09-09 05:07 ET) |
| `1170-f` | [rulings_2026_09_08_playground_output_pin_1170.md](rulings_2026_09_08_playground_output_pin_1170.md) | 1170-d / 1170-e / 1170-f — the mermaid gate joins the matrix (RULED, Fable 2026-09-09 05:07 ET) |
| `1170-g` | [rulings_2026_09_09_playground_expect_check_1170g.md](rulings_2026_09_09_playground_expect_check_1170g.md) | RULED: 1170-g — §C4 is EXACT: an optional `[expect [#…#]]` per example pins a substring of its output; the note↔output check reads that field, never the prose |
| `1172-q1` | [rulings_2026_09_04_head_bind_whole_element_1172.md](rulings_2026_09_04_head_bind_whole_element_1172.md) | Question 1172-Q1 — what does `[NAME$x]` mean? |
| `1173-b` | [rulings_2026_09_17_owner_decisions_0345z.md](rulings_2026_09_17_owner_decisions_0345z.md) | Owner decisions 2026-09-17 ~03:45Z — three of the integrator's declines reversed: libcx-sync gets an inline pump (1387-b), sets get a module (1173-b), closure's bound gets a default (1174-b); #1389's close confirmed |
| `1173-c` | [rulings_2026_09_18_owner_decisions_2345z.md](rulings_2026_09_18_owner_decisions_2345z.md) | Owner decisions 2026-09-18 ~23:45Z — the set module's code band (1173-c); the deployment binding's spelling enters connector.md §4.6 (1466-a); the adapter contract gains a `binding-of` hook (1483-a) |
| `1174-b` | [rulings_2026_09_17_owner_decisions_0345z.md](rulings_2026_09_17_owner_decisions_0345z.md) | Owner decisions 2026-09-17 ~03:45Z — three of the integrator's declines reversed: libcx-sync gets an inline pump (1387-b), sets get a module (1173-b), closure's bound gets a default (1174-b); #1389's close confirmed |
| `1175-b` | [rulings_2026_09_17_owner_decisions_0410z.md](rulings_2026_09_17_owner_decisions_0410z.md) | Owner decisions 2026-09-17 ~04:10Z — chained destructuring gets a flat form: `[?match]` takes a chain (RULED: 1175-b) |
| `1177-a` | [rulings_2026_09_01_index_base_1177.md](rulings_2026_09_01_index_base_1177.md) | RULED: 1177-a — #1177 index base: 1-based across the value surface |
| `1192-a` | [rulings_2026_09_10_else_no_callable_1192.md](rulings_2026_09_10_else_no_callable_1192.md) | RULED: 1192-a — `[?else]` does not coalesce E_NO_CALLABLE; every other failure and absence still does |
| `1195-a` | [rulings_2026_09_07_contract_check_at_seal_and_boot_1195.md](rulings_2026_09_07_contract_check_at_seal_and_boot_1195.md) | RULED: 1195-a — the §1.2 runtime contract is checked wherever a package is |
| `1196-a` | [rulings_2026_09_07_deployment_doc_two_stages_1196.md](rulings_2026_09_07_deployment_doc_two_stages_1196.md) | RULED: 1196-a — a deployment document has TWO STAGES, and `xap.cxs` describes |
| `1197-a` | [rulings_2026_09_15_owner_decisions_1945z.md](rulings_2026_09_15_owner_decisions_1945z.md) | Owner decisions 2026-09-15 ~19:45Z — "5a 6a if those are the best cx long term" (RULED: 1197-a, 1220-a) |
| `1198-a` | [rulings_2026_09_10_apply_refusal_shape_1198.md](rulings_2026_09_10_apply_refusal_shape_1198.md) | RULED: 1198-a — what `apply` may return, and a refusal the host does not recognise is SAID, never dropped |
| `1220-a` | [rulings_2026_09_15_owner_decisions_1945z.md](rulings_2026_09_15_owner_decisions_1945z.md) | Owner decisions 2026-09-15 ~19:45Z — "5a 6a if those are the best cx long term" (RULED: 1197-a, 1220-a) |
| `1221-a` | [rulings_2026_09_08_nav_item_nested_link_1221.md](rulings_2026_09_08_nav_item_nested_link_1221.md) | RULED: 1221-a — a `[ux:nav-item]` that swallows a nested `[ux:link]` refuses |
| `1221-a` | [rulings_2026_09_08_nav_item_nested_link_1221.md](rulings_2026_09_08_nav_item_nested_link_1221.md) | 1221-a — `[ux:nav-item]` REFUSES a descendant `[ux:link]` |
| `1221-b` | [rulings_2026_09_08_nav_item_nested_link_1221.md](rulings_2026_09_08_nav_item_nested_link_1221.md) | it instead. 1221-b (the `[$xap:serve]` option guard) is NOT ruled here: the |
| `1221-b` | [rulings_2026_09_08_nav_item_nested_link_1221.md](rulings_2026_09_08_nav_item_nested_link_1221.md) | 1221-b — NOT RULED. The pre-flight moved the question. |
| `1221-b-1a` | [rulings_2026_09_08_xap_serve_option_set_1221.md](rulings_2026_09_08_xap_serve_option_set_1221.md) | RULED: 1221-b-1a, 1221-b-2a — `[$xap:serve]` takes a CLOSED option set of |
| `1221-b-1a` | [rulings_2026_09_08_xap_serve_option_set_1221.md](rulings_2026_09_08_xap_serve_option_set_1221.md) | Ruled — 1221-b-1a: the closed set, `serve` ≠ `run` |
| `1221-b-2a` | [rulings_2026_09_08_xap_serve_option_set_1221.md](rulings_2026_09_08_xap_serve_option_set_1221.md) | RULED: 1221-b-1a, 1221-b-2a — `[$xap:serve]` takes a CLOSED option set of |
| `1221-b-2a` | [rulings_2026_09_08_xap_serve_option_set_1221.md](rulings_2026_09_08_xap_serve_option_set_1221.md) | Ruled — 1221-b-2a: no landed state shows a call the verb refuses |
| `1222-a` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) | 1250 (1250-b, the same lineage) → #1222 (1222-a) → #1239 (1239-a) → #1241 (1241-a) → #1387 (1387-a) → #1436's |
| `1239-a` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) | 1250 (1250-b, the same lineage) → #1222 (1222-a) → #1239 (1239-a) → #1241 (1241-a) → #1387 (1387-a) → #1436's |
| `1240-q1` | [rulings_2026_09_04_map_lookup_1240.md](rulings_2026_09_04_map_lookup_1240.md) | Question 1240-Q1 — a hash index for wide maps (OPEN, owner ruling) |
| `1240-q1` | [rulings_2026_09_04_map_lookup_1240.md](rulings_2026_09_04_map_lookup_1240.md) | 1240-Q1 — RULED (a) 2026-09-05: an EAGER index above a 64-entry threshold |
| `1241-a` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) | 1250 (1250-b, the same lineage) → #1222 (1222-a) → #1239 (1239-a) → #1241 (1241-a) → #1387 (1387-a) → #1436's |
| `1241-q1` | [rulings_2026_09_04_immutable_append_1241.md](rulings_2026_09_04_immutable_append_1241.md) | Question 1241-Q1 — the asymptotic fix (OPEN, owner ruling — it changes a RULED carrier) |
| `1249-q1` | [rulings_2026_09_04_perf_ratchet_at_cut_1249.md](rulings_2026_09_04_perf_ratchet_at_cut_1249.md) | Question 1249-Q1 — where does the throughput measurement live? |
| `1250-b` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) | Integrator decisions, 2026-09-17 — the Ring 0 rulings owed (1363-b, 1387-a, FMT-2, GRADER-1, 1150-a, 1250-b) |
| `1250-b` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) | 1250 (1250-b, the same lineage) → #1222 (1222-a) → #1239 (1239-a) → #1241 (1241-a) → #1387 (1387-a) → #1436's |
| `1250-q1` | [rulings_2026_09_05_comprehension_totality_1250.md](rulings_2026_09_05_comprehension_totality_1250.md) | 1250-Q1 — RULED (a): extend the EXISTING pass to the evaluator's `[?for]` |
| `1253-a` | [rulings_2026_09_08_nav_item_current_and_rail_width_1253.md](rulings_2026_09_08_nav_item_current_and_rail_width_1253.md) | RULED: 1253-a / 1253-b — `current=` joins `ux:nav-item`; the side rail's width |
| `1253-a` | [rulings_2026_09_08_nav_item_current_and_rail_width_1253.md](rulings_2026_09_08_nav_item_current_and_rail_width_1253.md) | 1253-a — `current=` is granted to `ux:nav-item` |
| `1253-b` | [rulings_2026_09_08_nav_item_current_and_rail_width_1253.md](rulings_2026_09_08_nav_item_current_and_rail_width_1253.md) | RULED: 1253-a / 1253-b — `current=` joins `ux:nav-item`; the side rail's width |
| `1253-b` | [rulings_2026_09_08_nav_item_current_and_rail_width_1253.md](rulings_2026_09_08_nav_item_current_and_rail_width_1253.md) | 1253-b — a `rail-width` token WITH a fallback; NOT `aside-width` |
| `1255-a` | [rulings_2026_09_08_grammar_plane_preflight_1255.md](rulings_2026_09_08_grammar_plane_preflight_1255.md) | RULED: 1255-a, 1255-b — the grammar plane's preflight, and rollout order |
| `1255-a` | [rulings_2026_09_08_grammar_plane_preflight_1255.md](rulings_2026_09_08_grammar_plane_preflight_1255.md) | 1255-a = Q1(a) — a per-refinement preflight on the grammar plane |
| `1255-b` | [rulings_2026_09_08_grammar_plane_preflight_1255.md](rulings_2026_09_08_grammar_plane_preflight_1255.md) | RULED: 1255-a, 1255-b — the grammar plane's preflight, and rollout order |
| `1255-b` | [rulings_2026_09_08_grammar_plane_preflight_1255.md](rulings_2026_09_08_grammar_plane_preflight_1255.md) | 1255-b = Q2(a) — rollout order is deliberately unprescribed, and says so |
| `1256-a` | [rulings_2026_09_15_owner_decisions_1145z.md](rulings_2026_09_15_owner_decisions_1145z.md) | Owner decisions 2026-09-15 ~11:45Z — "1a 2a 3 accepted 4a 5a 6a" (RULED: 1502-a, 1456-a, 1503-a, 1256-a, 1453-a) |
| `1259-a` | [rulings_2026_09_08_emits_of_1259.md](rulings_2026_09_08_emits_of_1259.md) | RULED: 1259-a, 1259-b, 1259-c — the derived client vocabulary |
| `1259-a` | [rulings_2026_09_08_emits_of_1259.md](rulings_2026_09_08_emits_of_1259.md) | 1259-a = Q1(b) — one pure verb, not a `from:` option |
| `1259-b` | [rulings_2026_09_08_emits_of_1259.md](rulings_2026_09_08_emits_of_1259.md) | RULED: 1259-a, 1259-b, 1259-c — the derived client vocabulary |
| `1259-b` | [rulings_2026_09_08_emits_of_1259.md](rulings_2026_09_08_emits_of_1259.md) | 1259-b = Q2(a) — the derived atoms carry the field TYPES |
| `1259-c` | [rulings_2026_09_08_emits_of_1259.md](rulings_2026_09_08_emits_of_1259.md) | RULED: 1259-a, 1259-b, 1259-c — the derived client vocabulary |
| `1259-c` | [rulings_2026_09_08_emits_of_1259.md](rulings_2026_09_08_emits_of_1259.md) | 1259-c = Q3(a) — `component`'s option set is CLOSED |
| `1259-g` | [rulings_2026_09_09_composed_emits_of_1259.md](rulings_2026_09_09_composed_emits_of_1259.md) | The fork the rulings did not reach — `1259-g`, drafted on #1259 |
| `1259-h` | [rulings_2026_09_09_section6_agreement_1259.md](rulings_2026_09_09_section6_agreement_1259.md) | #1259 — `1259-h`: two readers of §6, pinned by a gate |
| `1259-h` | [rulings_2026_09_09_section6_agreement_1259.md](rulings_2026_09_09_section6_agreement_1259.md) | What `1259-h` decided, and what it deleted |
| `1259-i` | [rulings_2026_09_09_section6_agreement_1259.md](rulings_2026_09_09_section6_agreement_1259.md) | 1259-i — the readers agree on MEMBERSHIP, not only on names |
| `1261-a` | [rulings_2026_09_10_str_hole_quotes_1261.md](rulings_2026_09_10_str_hole_quotes_1261.md) | RULED: 1261-a — a `[?str]` hole is scanned to its matching brace, quotes inside it skipped |
| `1262-a` | [rulings_2026_09_10_exists_over_a_node_1262.md](rulings_2026_09_10_exists_over_a_node_1262.md) | RULED: 1262-a — `[$exists]` keeps its content-arity meaning; the presence question is `present`, and the lint names the trap |
| `1265-pb-1` | [rulings_2026_09_04_flow_w1_runner_seam_1265.md](rulings_2026_09_04_flow_w1_runner_seam_1265.md) | Edit map (this wave, ruling-gated; `RULED: 1265-PB-1` on the commit) |
| `1265-pb-1` | [rulings_2026_09_08_flow_serve_wf28.md](rulings_2026_09_08_flow_serve_wf28.md) | Ratified as a defect fix against `1265-PB-1`, no ruling needed |
| `1265-pc-1` | [rulings_2026_09_04_flow_w1_map_scale_1265.md](rulings_2026_09_04_flow_w1_map_scale_1265.md) | Edit map (packet D, `RULED: 1265-PC-1`) |
| `1265-pd-1` | [rulings_2026_09_04_flow_w1_cli_1265.md](rulings_2026_09_04_flow_w1_cli_1265.md) | Edit map (packet D, `RULED: 1265-PD-1`) |
| `1265-pe-1` | [bench_flow_w1e_anchored_reader_2026_09_06.md](bench_flow_w1e_anchored_reader_2026_09_06.md) | THE INTERVAL, RE-SWEPT: RULED 1265-PE-1's GATE |
| `1265-pv-1` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) | WF-20 consequence, found in implementation (2026-09-06) — `1265-PV-1` |
| `1265-pw-1` | [rulings_2026_09_04_flow_w3_performers_1265.md](rulings_2026_09_04_flow_w3_performers_1265.md) | Edit map (W3, ruling-gated; `RULED: 1265-PW-1` on the commits that touch spec/**) |
| `1265-wf-40` | [rulings_2026_09_08_flow_serve_wf28.md](rulings_2026_09_08_flow_serve_wf28.md) | RULED: 1265-WF-40, 1265-WF-41 (Fable + owner, 2026-09-08 15:20 ET) |
| `1265-wf-40` | [rulings_2026_09_08_flow_serve_wf28.md](rulings_2026_09_08_flow_serve_wf28.md) | 1265-WF-40 — the admission sentence in W1 |
| `1265-wf-40b` | [rulings_2026_09_09_flow_pep_admission_1265_wf40b.md](rulings_2026_09_09_flow_pep_admission_1265_wf40b.md) | RULED: 1265-WF-40b — the PEP admission mechanism on the flow act path |
| `1265-wf-41` | [rulings_2026_09_08_flow_serve_wf28.md](rulings_2026_09_08_flow_serve_wf28.md) | RULED: 1265-WF-40, 1265-WF-41 (Fable + owner, 2026-09-08 15:20 ET) |
| `1265-wf-41` | [rulings_2026_09_08_flow_serve_wf28.md](rulings_2026_09_08_flow_serve_wf28.md) | 1265-WF-41 — rung 1 exits on §4.16 flow 3 alone |
| `1268-b` | [rulings_2026_09_05_xap_queue.md](rulings_2026_09_05_xap_queue.md) | RULED: 1268-b — an act's undeclared fields: refuse EXTRAS, tolerate MISSING (#1268) |
| `1268-c1` | [rulings_2026_09_08_pump_ingest_fields_1268.md](rulings_2026_09_08_pump_ingest_fields_1268.md) | 1268-c1 — YES, and the binding states the mapping (letter 1(a)) |
| `1268-c2` | [rulings_2026_09_08_pump_ingest_fields_1268.md](rulings_2026_09_08_pump_ingest_fields_1268.md) | 1268-c2 — the parameter refusal lands FIRST in the §4.9 order (letter 2(a)) |
| `1268-d` | [rulings_2026_09_08_pump_ingest_fields_1268.md](rulings_2026_09_08_pump_ingest_fields_1268.md) | RULED: 1268-d — the error code (Fable + owner, 2026-09-08 16:25 ET) |
| `1270-q1` | [rulings_2026_09_05_pattern_attr_rest_1270.md](rulings_2026_09_05_pattern_attr_rest_1270.md) | 1270-Q1 — RULED (a): keep [126d] and implement it |
| `1270-q2` | [rulings_2026_09_05_pattern_attr_rest_1270.md](rulings_2026_09_05_pattern_attr_rest_1270.md) | 1270-Q2 — RULED: both riders, as the natural reading |
| `1271-b1` | [rulings_2026_09_08_served_tier_journal_1271.md](rulings_2026_09_08_served_tier_journal_1271.md) | RULED: 1271-b1, 1271-b2 — a served-tier journal binding hands a fold-capable handle (Fable + owner, 2026-09-08 16:25 ET) |
| `1271-b2` | [rulings_2026_09_08_served_tier_journal_1271.md](rulings_2026_09_08_served_tier_journal_1271.md) | RULED: 1271-b1, 1271-b2 — a served-tier journal binding hands a fold-capable handle (Fable + owner, 2026-09-08 16:25 ET) |
| `1271-c1` | [rulings_2026_09_08_served_tier_journal_1271.md](rulings_2026_09_08_served_tier_journal_1271.md) | SUPERSEDED IN MECHANISM, ANSWERED IN OUTCOME — RULED: 1271-c1, 1271-c2 (owner + Fable, 2026-09-08 18:00 ET) |
| `1271-c1` | [rulings_2026_09_08_served_tier_journal_1271.md](rulings_2026_09_08_served_tier_journal_1271.md) | RULED: 1271-c1 — `attach`, not a widened `open` |
| `1271-c1` | [rulings_2026_09_09_served_tier_boot_1271_addendum.md](rulings_2026_09_09_served_tier_boot_1271_addendum.md) | Addendum to 1271-c1 / 1271-c2 — what the first gates carrying `d92c2ceb7` measured (Fable, 2026-09-09 21:15Z) |
| `1271-c2` | [rulings_2026_09_08_served_tier_journal_1271.md](rulings_2026_09_08_served_tier_journal_1271.md) | SUPERSEDED IN MECHANISM, ANSWERED IN OUTCOME — RULED: 1271-c1, 1271-c2 (owner + Fable, 2026-09-08 18:00 ET) |
| `1271-c2` | [rulings_2026_09_08_served_tier_journal_1271.md](rulings_2026_09_08_served_tier_journal_1271.md) | RULED: 1271-c2 — the invariant is DECLARED and CHECKED, not assumed |
| `1271-c2` | [rulings_2026_09_09_served_tier_boot_1271_addendum.md](rulings_2026_09_09_served_tier_boot_1271_addendum.md) | Addendum to 1271-c1 / 1271-c2 — what the first gates carrying `d92c2ceb7` measured (Fable, 2026-09-09 21:15Z) |
| `1272-a1` | [rulings_2026_09_08_contract_revision_1272.md](rulings_2026_09_08_contract_revision_1272.md) | RULED: 1272-a1, 1272-a2 — the §1.2 feature runtime contract carries a revision |
| `1272-a1` | [rulings_2026_09_08_contract_revision_1272.md](rulings_2026_09_08_contract_revision_1272.md) | RULED: 1272-a1 — 1(a), the revision is declared in the spec and derived |
| `1272-a2` | [rulings_2026_09_08_contract_revision_1272.md](rulings_2026_09_08_contract_revision_1272.md) | RULED: 1272-a1, 1272-a2 — the §1.2 feature runtime contract carries a revision |
| `1272-a2` | [rulings_2026_09_08_contract_revision_1272.md](rulings_2026_09_08_contract_revision_1272.md) | RULED: 1272-a2 — 2(a), the boot-side check stays |
| `1272-a3` | [rulings_2026_09_08_contract_revision_1272.md](rulings_2026_09_08_contract_revision_1272.md) | RULED: 1272-a3 — the ABOVE-host direction refuses too (owner + Fable, 19:35 ET) |
| `1280-q3` | [rulings_2026_09_05_bareword_position_1280.md](rulings_2026_09_05_bareword_position_1280.md) | 1280-Q3 — RULED: the DIAGNOSTIC names the sigil |
| `1287-q1` | [rulings_2026_09_05_certificate_key_1287.md](rulings_2026_09_05_certificate_key_1287.md) | 1287-Q1 — RULED (a): `crypto:certificate-key` |
| `1287-q2` | [rulings_2026_09_05_certificate_key_1287.md](rulings_2026_09_05_certificate_key_1287.md) | 1287-Q2 — RULED (b): `saml:verify` does NOT also accept a certificate |
| `1292-a` | [rulings_2026_09_12_sessions_on_the_bridge_1292.md](rulings_2026_09_12_sessions_on_the_bridge_1292.md) | RULED: 1292-a — sessions on the served bridge: the request's session is the attribution; a bound runtime served without a session configuration refuses at boot; no configured stand-in principal |
| `1295-a` | [rulings_2026_09_19_cited_ids_without_a_page_1447.md](rulings_2026_09_19_cited_ids_without_a_page_1447.md) | RULED: 1295-a — a coalesced pooled span inherits the OLDEST `pool_gen` of its parts |
| `1310-a` | [rulings_2026_09_09_xap_correction_taxonomy_1310.md](rulings_2026_09_09_xap_correction_taxonomy_1310.md) | RULED: 1310-a, 1310-b, 1310-c — the xap slice folds the journal's correction taxonomy |
| `1310-a` | [rulings_2026_09_09_xap_correction_taxonomy_1310.md](rulings_2026_09_09_xap_correction_taxonomy_1310.md) | 1310-a = Q1(a) — `hash=` on a slice record names the JOURNAL's entry address |
| `1310-b` | [rulings_2026_09_09_xap_correction_taxonomy_1310.md](rulings_2026_09_09_xap_correction_taxonomy_1310.md) | RULED: 1310-a, 1310-b, 1310-c — the xap slice folds the journal's correction taxonomy |
| `1310-b` | [rulings_2026_09_09_xap_correction_taxonomy_1310.md](rulings_2026_09_09_xap_correction_taxonomy_1310.md) | 1310-b = Q2(a) — the carriers decode to nanoseconds |
| `1310-c` | [rulings_2026_09_09_xap_correction_taxonomy_1310.md](rulings_2026_09_09_xap_correction_taxonomy_1310.md) | RULED: 1310-a, 1310-b, 1310-c — the xap slice folds the journal's correction taxonomy |
| `1310-c` | [rulings_2026_09_09_xap_correction_taxonomy_1310.md](rulings_2026_09_09_xap_correction_taxonomy_1310.md) | 1310-c = Q3(a) — an engaged read that cannot resolve a linkage REFUSES |
| `1310-c` | [rulings_2026_09_09_xap_correction_taxonomy_1310.md](rulings_2026_09_09_xap_correction_taxonomy_1310.md) | Question 4 — the stale spec text, rewritten under 1310-c |
| `1310-d` | [rulings_2026_09_09_xap_correction_taxonomy_1310.md](rulings_2026_09_09_xap_correction_taxonomy_1310.md) | RULED: 1310-d — points 1, 3 and 4 landed; point 2 drafted back as a fork |
| `1310-f` | [rulings_2026_09_19_cited_ids_without_a_page_1447.md](rulings_2026_09_19_cited_ids_without_a_page_1447.md) | 1310-f — NEVER RULED |
| `1313-b` | [rulings_2026_09_08_local_runner_rearm_1313.md](rulings_2026_09_08_local_runner_rearm_1313.md) | RULED: 1313-b — `cx flow run` re-arms the WHOLE journal, each timer under its run's RECORDED basis |
| `1313-c` | [rulings_2026_09_08_flow_run_overlay_1316b.md](rulings_2026_09_08_flow_run_overlay_1316b.md) | Implementation is SEQUENCED BEHIND #1313's `1313-c`, and this is measured |
| `1313-d` | [rulings_2026_09_09_serve_completion_bound_1313d.md](rulings_2026_09_09_serve_completion_bound_1313d.md) | RULED: 1313-d — `test_flow_serve_four_kinds_and_the_nonce_rule` asserts completion BY IDENTITY, and bounds the schedule kind's in-flight count |
| `1314-c1` | [rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md](rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md) | RULED: 1314-c1 … 1314-c4 — the flow re-attempt WAIT and the timer's kind segment |
| `1314-c1` | [rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md](rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md) | 1314-c1 — the timer name gains a KIND segment |
| `1314-c2` | [rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md](rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md) | 1314-c2 — the fired-timer law is KIND × STATUS |
| `1314-c3` | [rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md](rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md) | 1314-c3 — `deadline=` bounds the WHOLE step, not each attempt |
| `1314-c4` | [rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md](rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md) | RULED: 1314-c1 … 1314-c4 — the flow re-attempt WAIT and the timer's kind segment |
| `1314-c4` | [rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md](rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md) | 1314-c4 — `every=` lands in v0.18 |
| `1316-a` | [rulings_2026_09_08_flow_picture_address_1316.md](rulings_2026_09_08_flow_picture_address_1316.md) | RULED: 1316-a — the flow picture's node id IS the construct's sanitized |
| `1316-a` | [rulings_2026_09_08_flow_picture_address_1316.md](rulings_2026_09_08_flow_picture_address_1316.md) | Ruled — 1316-a |
| `1316-b1` | [rulings_2026_09_08_flow_run_overlay_1316b.md](rulings_2026_09_08_flow_run_overlay_1316b.md) | RULED: 1316-b1, 1316-b2, 1316-b5 — the run overlay is a VALUE keyed by the |
| `1316-b1` | [rulings_2026_09_08_flow_run_overlay_1316b.md](rulings_2026_09_08_flow_run_overlay_1316b.md) | Ruled — 1316-b1: the run overlay is an OVERLAY VALUE keyed by the node id |
| `1316-b2` | [rulings_2026_09_08_flow_run_overlay_1316b.md](rulings_2026_09_08_flow_run_overlay_1316b.md) | RULED: 1316-b1, 1316-b2, 1316-b5 — the run overlay is a VALUE keyed by the |
| `1316-b2` | [rulings_2026_09_08_flow_run_overlay_1316b.md](rulings_2026_09_08_flow_run_overlay_1316b.md) | Ruled — 1316-b2: emit what the record bears; register the rest |
| `1316-b3` | [rulings_2026_09_08_flow_run_overlay_1316b.md](rulings_2026_09_08_flow_run_overlay_1316b.md) | RULED: 1316-b3 — `cx flow watch` is READ-ONLY; a watcher has no liveness |
| `1316-b4` | [rulings_2026_09_08_flow_run_overlay_1316b.md](rulings_2026_09_08_flow_run_overlay_1316b.md) | RULED: 1316-b4 — the run overlay rides the EXISTING host `GET /stream` |
| `1316-b5` | [rulings_2026_09_08_flow_run_overlay_1316b.md](rulings_2026_09_08_flow_run_overlay_1316b.md) | RULED: 1316-b1, 1316-b2, 1316-b5 — the run overlay is a VALUE keyed by the |
| `1316-b5` | [rulings_2026_09_08_flow_run_overlay_1316b.md](rulings_2026_09_08_flow_run_overlay_1316b.md) | Ruled — 1316-b5: §4.17's construct table gains a step re-attempt row |
| `1316-c1` | [rulings_2026_09_09_flow_activation_seq_1316c1.md](rulings_2026_09_09_flow_activation_seq_1316c1.md) | RULED: 1316-c1 — the construct row gains a sticky `activated=<entry seq>`; |
| `1316-c1` | [rulings_2026_09_09_flow_activation_seq_1316c1.md](rulings_2026_09_09_flow_activation_seq_1316c1.md) | One clause of `1316-c1` this ruling widens, and it is a MEASUREMENT |
| `1316-c2` | [rulings_2026_09_09_stdout_answer_channel_1316c2.md](rulings_2026_09_09_stdout_answer_channel_1316c2.md) | RULED: 1316-c2 — (a): the invocation's own stdout (fd 1) is its ANSWER |
| `1316-d` | [rulings_2026_09_09_flow_activation_seq_1316c1.md](rulings_2026_09_09_flow_activation_seq_1316c1.md) | AMENDED — RULED: 1316-d — `activated=` is the activating transition's FOLD |
| `1317-h` | [rulings_2026_09_09_xsp_handshake_budget_1317h.md](rulings_2026_09_09_xsp_handshake_budget_1317h.md) | RULED: 1317-h — the XSP responder's IDLE TICK and its HANDSHAKE BUDGET are two named constants, and xsp.md states the budget |
| `1318-a` | [rulings_2026_09_05_fmt_module_directive_and_layout_1318_1058.md](rulings_2026_09_05_fmt_module_directive_and_layout_1318_1058.md) | RULED 1318-A — the emitter gets a module-directive lane |
| `1318-b` | [rulings_2026_09_05_fmt_module_directive_and_layout_1318_1058.md](rulings_2026_09_05_fmt_module_directive_and_layout_1318_1058.md) | RULED 1318-B — a `[?fn]` parameter list is space-separated |
| `1319-a` | [rulings_2026_09_07_fmt_interior_comments_and_text_run_1320_1319.md](rulings_2026_09_07_fmt_interior_comments_and_text_run_1320_1319.md) | RULED 1319-A — the document-level string scalar uses the TEXT predicate |
| `1320-a` | [rulings_2026_09_06_fmt_comment_preservation_1320.md](rulings_2026_09_06_fmt_comment_preservation_1320.md) | RULED 1320-A — the comment inventory rides on `Program`, never on a node |
| `1320-b` | [rulings_2026_09_06_fmt_comment_preservation_1320.md](rulings_2026_09_06_fmt_comment_preservation_1320.md) | RULED 1320-B — depth 0 only, and that is a boundary, not an omission |
| `1320-b` | [rulings_2026_09_07_fmt_interior_comments_and_text_run_1320_1319.md](rulings_2026_09_07_fmt_interior_comments_and_text_run_1320_1319.md) | 1320-B's boundary moves, exactly on the condition it named |
| `1320-c` | [rulings_2026_09_06_fmt_comment_preservation_1320.md](rulings_2026_09_06_fmt_comment_preservation_1320.md) | RULED 1320-C — every accepting lane compares the comment inventory |
| `1320-w2` | [rulings_2026_09_07_fmt_interior_comments_and_text_run_1320_1319.md](rulings_2026_09_07_fmt_interior_comments_and_text_run_1320_1319.md) | RULED 1320-W2 — placement is decided by the comment's WRITTEN bracket depth |
| `1327-a` | [rulings_2026_09_08_flow_verb_status_table_1327.md](rulings_2026_09_08_flow_verb_status_table_1327.md) | RULED: 1327-a — §3's verb list says which verbs answer, and a gate holds it |
| `1328-a` | [rulings_2026_09_06_fmt_shape_spelling_and_idempotence_1328_1330.md](rulings_2026_09_06_fmt_shape_spelling_and_idempotence_1328_1330.md) | RULED 1328-A — `src` is fingerprinted only when it differs from `str_val` |
| `1330-a` | [rulings_2026_09_06_fmt_shape_spelling_and_idempotence_1328_1330.md](rulings_2026_09_06_fmt_shape_spelling_and_idempotence_1328_1330.md) | RULED 1330-A — idempotence is checked, not trusted |
| `1338-a` | [rulings_2026_09_06_fmt_emitter_quoting_and_directive_surface_1338_1339.md](rulings_2026_09_06_fmt_emitter_quoting_and_directive_surface_1338_1339.md) | RULED 1338-A — one quoting rule, and it is the one the language specifies |
| `1339-a` | [rulings_2026_09_06_fmt_emitter_quoting_and_directive_surface_1338_1339.md](rulings_2026_09_06_fmt_emitter_quoting_and_directive_surface_1338_1339.md) | RULED 1339-A — the generic directive path emits the attribute form |
| `1342-a` | [rulings_2026_09_07_doc_drift_1342_1151_1152.md](rulings_2026_09_07_doc_drift_1342_1151_1152.md) | RULED 1342-A — canonical.md §2.10's TripleQuoted row is the stale one |
| `1347-a` | [rulings_2026_09_09_fmt_fingerprint_underscores_1347.md](rulings_2026_09_09_fmt_fingerprint_underscores_1347.md) | RULED: 1347-a — the `cx fmt` fingerprint hashes an integer's canonical §2.5 image, EXCEPT under a text-coercing ascription |
| `1347-b` | [rulings_2026_09_09_float_image_and_decimal_fingerprint_1347.md](rulings_2026_09_09_float_image_and_decimal_fingerprint_1347.md) | RULED: 1347-b — the program emitter's `.float_lit` renders through `cx_format_float`; §2.5's exponent-always float row STANDS |
| `1348-c` | [rulings_2026_09_09_fmt_sweep_gate_1348c.md](rulings_2026_09_09_fmt_sweep_gate_1348c.md) | RULED: 1348-c — the `cx fmt` census becomes a gate, and the ERROR column is a named roster |
| `1348-d` | [rulings_2026_09_09_fmt_sweep_gate_1348c.md](rulings_2026_09_09_fmt_sweep_gate_1348c.md) | RULED: 1348-e — the memory column is dropped; `1348-d`'s instrument half is superseded |
| `1348-e` | [rulings_2026_09_09_fmt_sweep_gate_1348c.md](rulings_2026_09_09_fmt_sweep_gate_1348c.md) | RULED: 1348-e — the memory column is dropped; `1348-d`'s instrument half is superseded |
| `1349-d` | [rulings_2026_09_09_diagram_node_id_ordinals_1349.md](rulings_2026_09_09_diagram_node_id_ordinals_1349.md) | 1349-d — the second landing: `modify` joins the family |
| `1350-b` | [rulings_2026_09_09_mermaid_golden_sidecars_1350.md](rulings_2026_09_09_mermaid_golden_sidecars_1350.md) | 1350-b — what does the byte gate assert? |
| `1350-c` | [rulings_2026_09_09_mermaid_golden_sidecars_1350.md](rulings_2026_09_09_mermaid_golden_sidecars_1350.md) | 1350-c — how does `diagram_mermaid_golden` acquire the sidecar half? |
| `1351-a1` | [rulings_2026_09_08_err_classification_verb_1351.md](rulings_2026_09_08_err_classification_verb_1351.md) | RULED: 1351-a1, 1351-a2 — one public verb classifies an err result over TEXT |
| `1351-a2` | [rulings_2026_09_08_err_classification_verb_1351.md](rulings_2026_09_08_err_classification_verb_1351.md) | RULED: 1351-a1, 1351-a2 — one public verb classifies an err result over TEXT |
| `1352-a` | [rulings_2026_09_09_agent_tool_projection_feature_verbs_1352.md](rulings_2026_09_09_agent_tool_projection_feature_verbs_1352.md) | RULED: 1352-a, 1352-b, 1352-f — the agent-tool projection projects feature VERBS beside `[?def]` commands (implementation record) |
| `1352-b` | [rulings_2026_09_09_agent_tool_projection_feature_verbs_1352.md](rulings_2026_09_09_agent_tool_projection_feature_verbs_1352.md) | RULED: 1352-a, 1352-b, 1352-f — the agent-tool projection projects feature VERBS beside `[?def]` commands (implementation record) |
| `1352-c` | [rulings_2026_09_19_cited_ids_without_a_page_1447.md](rulings_2026_09_19_cited_ids_without_a_page_1447.md) | 1352-c, 1352-d, 1352-e — NEVER RULED |
| `1352-d` | [rulings_2026_09_19_cited_ids_without_a_page_1447.md](rulings_2026_09_19_cited_ids_without_a_page_1447.md) | 1352-c, 1352-d, 1352-e — NEVER RULED |
| `1352-e` | [rulings_2026_09_19_cited_ids_without_a_page_1447.md](rulings_2026_09_19_cited_ids_without_a_page_1447.md) | 1352-c, 1352-d, 1352-e — NEVER RULED |
| `1352-f` | [rulings_2026_09_09_agent_tool_projection_feature_verbs_1352.md](rulings_2026_09_09_agent_tool_projection_feature_verbs_1352.md) | RULED: 1352-a, 1352-b, 1352-f — the agent-tool projection projects feature VERBS beside `[?def]` commands (implementation record) |
| `1352-g` | [rulings_2026_09_09_agent_tool_projection_feature_verbs_1352.md](rulings_2026_09_09_agent_tool_projection_feature_verbs_1352.md) | RULED: 1352-g — `compose` carries `[summary]` / `[doc]` onto the composed verb (Fable, 2026-09-09 16:00 ET) |
| `1353-b` | [rulings_2026_09_08_decimal_negative_zero_1353.md](rulings_2026_09_08_decimal_negative_zero_1353.md) | RULED: 1353-b, 1353-c, 1353-d — a decimal negative zero KEEPS its sign in |
| `1353-c` | [rulings_2026_09_08_decimal_negative_zero_1353.md](rulings_2026_09_08_decimal_negative_zero_1353.md) | RULED: 1353-b, 1353-c, 1353-d — a decimal negative zero KEEPS its sign in |
| `1353-d` | [rulings_2026_09_08_decimal_negative_zero_1353.md](rulings_2026_09_08_decimal_negative_zero_1353.md) | RULED: 1353-b, 1353-c, 1353-d — a decimal negative zero KEEPS its sign in |
| `1358-a` | [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) | RULED: 1358-a … 1358-d — sched's production `:wall` clock |
| `1358-a` | [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) | 1358-a — the fire path is a safepoint pump at the blocking cancellation points |
| `1358-b` | [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) | 1358-b — `:wall` is the process default; `:manual` has exactly two selectors |
| `1358-c` | [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) | 1358-c — all five cadences land together |
| `1358-d` | [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) | RULED: 1358-a … 1358-d — sched's production `:wall` clock |
| `1358-d` | [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) | 1358-d — how the wall arm is graded |
| `1358-e` | [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) | RULED: 1358-e — the fire instant is bound into the fire value |
| `1358-e` | [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) | What did NOT land under 1358-e, and why it was a ruling rather than a choice |
| `1358-f1` | [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) | RULED: 1358-f1, 1358-f2 — the fire instant's two faces |
| `1358-f1` | [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) | 1358-f1 — the channel tick stays a bare signal |
| `1358-f2` | [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) | RULED: 1358-f1, 1358-f2 — the fire instant's two faces |
| `1358-f2` | [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) | 1358-f2 — a fired timer's instant is recorded as `fired-at=` |
| `1358-g` | [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) | 1358-g — the `cmp-005` bisect: #1358 did NOT regress it, and the assertion is the defect |
| `1360-a` | [rulings_2026_09_08_saml_session_1360.md](rulings_2026_09_08_saml_session_1360.md) | 1360-a — `saml:claims`, a PUBLIC PURE projection |
| `1360-b` | [rulings_2026_09_08_saml_session_1360.md](rulings_2026_09_08_saml_session_1360.md) | 1360-b — `session:attach-saml`, the fifth attach path, verification IN-PATH |
| `1361-a` | [rulings_2026_09_10_doc_top_postfix_ascription_1361.md](rulings_2026_09_10_doc_top_postfix_ascription_1361.md) | RULED: 1361-a — the document top is an unnamed value slot: a root `v::T` token is the typed scalar; an element body is a named slot and stays [27] |
| `1361-b` | [rulings_2026_09_10_doc_top_postfix_ascription_1361.md](rulings_2026_09_10_doc_top_postfix_ascription_1361.md) | RULED: 1361-b — canonical §2.6a's merged column is read per slot kind |
| `1363-b` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) | Integrator decisions, 2026-09-17 — the Ring 0 rulings owed (1363-b, 1387-a, FMT-2, GRADER-1, 1150-a, 1250-b) |
| `1364-a` | [rulings_2026_09_10_bounded_memory_own_process_1364.md](rulings_2026_09_10_bounded_memory_own_process_1364.md) | RULED: 1364-a — the cmp-005 bounded-memory gauge runs in a process of its OWN |
| `1365-a` | [rulings_2026_09_08_flow_commit_retry_1365.md](rulings_2026_09_08_flow_commit_retry_1365.md) | 1365-a — the retry class is EXACTLY the journal's stale tail |
| `1365-b` | [rulings_2026_09_08_flow_commit_retry_1365.md](rulings_2026_09_08_flow_commit_retry_1365.md) | 1365-b — the normative sentence belongs to the JOURNAL |
| `1365-c` | [rulings_2026_09_08_flow_commit_retry_1365.md](rulings_2026_09_08_flow_commit_retry_1365.md) | 1365-c — the `opts.expect-pos` branch is KEPT, narrowed to stale-tail |
| `1367-a` | [rulings_2026_09_10_splice_adoption_predicate_1367.md](rulings_2026_09_10_splice_adoption_predicate_1367.md) | RULED: 1367-a — `[?splice]`'s adoption predicate covers every kind R-A1's refusal predicate names |
| `1368-a` | [rulings_2026_09_10_synthesized_module_set_1368.md](rulings_2026_09_10_synthesized_module_set_1368.md) | RULED: 1368-a — the synthesized codec modules become a fourth ENUMERATED set; `codec.md` §3 is their normative text |
| `1371-a` | [rulings_2026_09_09_ux_form_subject_noun_1371.md](rulings_2026_09_09_ux_form_subject_noun_1371.md) | RULED: 1371-a — `ux:form` takes a verb's SUBJECT NOUN as `emits-of` does: `[writes]`, else `[reads]`; neither → untyped parameters, never an error |
| `1373-a` | [rulings_2026_09_10_diagram_golden_quote_rerecord_1373.md](rulings_2026_09_10_diagram_golden_quote_rerecord_1373.md) | What was wrong — a false negative in `1373-a`'s own golden audit |
| `1373-a` | [rulings_2026_09_10_mermaid_label_quote_1373.md](rulings_2026_09_10_mermaid_label_quote_1373.md) | RULED: 1373-a — the mermaid label escape for a double quote is the entity `#quot;` |
| `1373-b` | [rulings_2026_09_10_diagram_golden_quote_rerecord_1373.md](rulings_2026_09_10_diagram_golden_quote_rerecord_1373.md) | RULED: 1373-b — the two diagram golden corpora re-record onto `#quot;` |
| `1377-a` | [rulings_2026_09_10_diagram_view_axis_1377.md](rulings_2026_09_10_diagram_view_axis_1377.md) | RULED: 1377-a — one diagram VIEW axis, everywhere: `auto` \| `erd` \| `cfg` \| `seq` \| `effects` |
| `1384-a` | [rulings_2026_09_12_fmt_1384_1391.md](rulings_2026_09_12_fmt_1384_1391.md) | RULED: 1384-a, 1391-a — `cx fmt` enforces its own §1 contract with a second guard, fixes the two text-run/char-ref defects at the cause, formats a bracketed or collection value in argument and attribute position, and never declines silently again |
| `1384-a` | [rulings_2026_09_12_fmt_1384_1391.md](rulings_2026_09_12_fmt_1384_1391.md) | RULED: 1384-a — the contract is ENFORCED, and the two measured defects are fixed at the cause |
| `1387-a` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) | Integrator decisions, 2026-09-17 — the Ring 0 rulings owed (1363-b, 1387-a, FMT-2, GRADER-1, 1150-a, 1250-b) |
| `1387-a` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) | 1250 (1250-b, the same lineage) → #1222 (1222-a) → #1239 (1239-a) → #1241 (1241-a) → #1387 (1387-a) → #1436's |
| `1387-b` | [rulings_2026_09_17_owner_decisions_0345z.md](rulings_2026_09_17_owner_decisions_0345z.md) | Owner decisions 2026-09-17 ~03:45Z — three of the integrator's declines reversed: libcx-sync gets an inline pump (1387-b), sets get a module (1173-b), closure's bound gets a default (1174-b); #1389's close confirmed |
| `1391-a` | [rulings_2026_09_12_fmt_1384_1391.md](rulings_2026_09_12_fmt_1384_1391.md) | RULED: 1384-a, 1391-a — `cx fmt` enforces its own §1 contract with a second guard, fixes the two text-run/char-ref defects at the cause, formats a bracketed or collection value in argument and attribute position, and never declines silently again |
| `1391-a` | [rulings_2026_09_12_fmt_1384_1391.md](rulings_2026_09_12_fmt_1384_1391.md) | RULED: 1391-a — argument and attribute position format, and a decline is never silent |
| `1394-a` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | RULED: Lane S, five forks — 1394-a, 1397-a, 1399-a, 1404-a, 1408-a; plus the 1409-b / 1410-b decision batch |
| `1394-a` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | 1394-a — the deployment surface is a stdlib module of MOUNTABLE HANDLERS plus ONE graded in-tree deployment; the pending request lives in the session store seam |
| `1394-a` | [rulings_2026_09_11_session_persistence_1395.md](rulings_2026_09_11_session_persistence_1395.md) | RULED: 1395-a — the session registry becomes STORE-BACKED through `cfg.store` (url or handle, default `mem://`), carrying the pending-request table of 1394-a; client ids become CSPRNG; `session:reap` sweeps |
| `1394-b` | [rulings_2026_09_12_sso_enterprise_complete_1394b.md](rulings_2026_09_12_sso_enterprise_complete_1394b.md) | RULED: 1394-b — the SSO deployment surface is complete for an enterprise security review: an XML signer enters crypto, SP-initiated SAML and SLO are routes, agents and CLIs get sessions (client credentials, device flow), multi-tenant and rotation are first-class, identity linking and grant mapping are normative, and the interop step grades the SAML accept path live |
| `1395-a` | [rulings_2026_09_11_session_persistence_1395.md](rulings_2026_09_11_session_persistence_1395.md) | RULED: 1395-a — the session registry becomes STORE-BACKED through `cfg.store` (url or handle, default `mem://`), carrying the pending-request table of 1394-a; client ids become CSPRNG; `session:reap` sweeps |
| `1395-a` | [rulings_2026_09_11_session_persistence_1395.md](rulings_2026_09_11_session_persistence_1395.md) | Spec text (delegated G3, flagged; commits carry `RULED: 1395-a`) |
| `1396-a` | [rulings_2026_09_11_sso_transport_opts_1396.md](rulings_2026_09_11_sso_transport_opts_1396.md) | RULED: 1396-a — one `transport` map for every SSO dial: threaded, honoured, and grown by proxy + client certificate; env-derived settings only under the `env` grant; a token-endpoint POST never follows a redirect |
| `1397-a` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | RULED: Lane S, five forks — 1394-a, 1397-a, 1399-a, 1404-a, 1408-a; plus the 1409-b / 1410-b decision batch |
| `1397-a` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | 1397-a — `attach-saml` is STRICT, with no opt-out; the pure verbs keep the opts-gated rule via a `strict` opt that `attach-saml` always sets |
| `1398-a` | [rulings_2026_09_11_session_leeway_saml_path_1398.md](rulings_2026_09_11_session_leeway_saml_path_1398.md) | RULED: 1398-a — session's `leeway` default reaches the SAML path: `attach-saml` injects it into `cfg.saml` when that map names none |
| `1399-a` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | RULED: Lane S, five forks — 1394-a, 1397-a, 1399-a, 1404-a, 1408-a; plus the 1409-b / 1410-b decision batch |
| `1399-a` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | 1399-a — `refresh` revalidates per OIDC Core §12.2 against the ORIGINAL claims; `authorize-url` and `begin` read `$opts` as extras; `audience` is emitted |
| `1400-a` | [rulings_2026_09_11_saml_xml_encryption_1400_1401.md](rulings_2026_09_11_saml_xml_encryption_1400_1401.md) | RULED: 1400-a, 1401-a — XML Encryption comes IN: `saml:verify` decrypts `EncryptedAssertion` / `EncryptedID` / `EncryptedAttribute` with `opts.decryption-keys`; `crypto` gains RSA key transport (OAEP, SHA-1 inside OAEP allowed; PKCS#1 v1.5 behind a loud opt-in with implicit rejection) and AES-CBC + AES-128/192-GCM; encryption is detected BEFORE the signature search |
| `1400-a` | [rulings_2026_09_11_saml_xml_encryption_1400_1401.md](rulings_2026_09_11_saml_xml_encryption_1400_1401.md) | 5. Spec text (delegated G3, flagged; commits carry `RULED: 1400-a`) |
| `1401-a` | [rulings_2026_09_11_saml_xml_encryption_1400_1401.md](rulings_2026_09_11_saml_xml_encryption_1400_1401.md) | RULED: 1400-a, 1401-a — XML Encryption comes IN: `saml:verify` decrypts `EncryptedAssertion` / `EncryptedID` / `EncryptedAttribute` with `opts.decryption-keys`; `crypto` gains RSA key transport (OAEP, SHA-1 inside OAEP allowed; PKCS#1 v1.5 behind a loud opt-in with implicit rejection) and AES-CBC + AES-128/192-GCM; encryption is detected BEFORE the signature search |
| `1401-a` | [rulings_2026_09_11_saml_xml_encryption_1400_1401.md](rulings_2026_09_11_saml_xml_encryption_1400_1401.md) | 4. The honest refusal — RULED 1401-a |
| `1402-a` | [rulings_2026_09_11_saml_metadata_exchange_1402a.md](rulings_2026_09_11_saml_metadata_exchange_1402a.md) | RULED: 1402-a — SAML metadata exchange: `saml:metadata` parses an IdP's (or SP's) `EntityDescriptor` into keys + endpoints; `saml:sp-metadata` emits ours |
| `1402-b` | [rulings_2026_09_11_saml_binding_1402b_scim_1406b.md](rulings_2026_09_11_saml_binding_1402b_scim_1406b.md) | RULED: 1402-b and 1406-b — the SAML binding layer (S14) and the SCIM service-provider remainder (S15) |
| `1402-b` | [rulings_2026_09_11_saml_binding_1402b_scim_1406b.md](rulings_2026_09_11_saml_binding_1402b_scim_1406b.md) | 1402-b — S14, `cx-stdlib/saml` and `cx-stdlib/bytes` |
| `1404-a` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | RULED: Lane S, five forks — 1394-a, 1397-a, 1399-a, 1404-a, 1408-a; plus the 1409-b / 1410-b decision batch |
| `1404-a` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | 1404-a — an unrecognized `<Condition>` INVALIDATES; `OneTimeUse` and `ProxyRestriction` are recognized; `AuthnStatement` and `@Version` are read |
| `1405-a` | [rulings_2026_09_11_replay_defense_1405.md](rulings_2026_09_11_replay_defense_1405.md) | RULED: 1405-a — replay defense lives in session's store seam and is ON by default; the assertion ID travels as `jti`; JWKS rotation re-fetches once |
| `1406-b` | [rulings_2026_09_11_saml_binding_1402b_scim_1406b.md](rulings_2026_09_11_saml_binding_1402b_scim_1406b.md) | RULED: 1402-b and 1406-b — the SAML binding layer (S14) and the SCIM service-provider remainder (S15) |
| `1406-b` | [rulings_2026_09_11_saml_binding_1402b_scim_1406b.md](rulings_2026_09_11_saml_binding_1402b_scim_1406b.md) | 1406-b — S15, `cx-stdlib/scim` (and one `session` row) |
| `1407-a` | [rulings_2026_09_11_oidc_hardening_1407.md](rulings_2026_09_11_oidc_hardening_1407.md) | RULED: 1407-a — the four OIDC hardening gaps and the four smaller ones: every row implemented in one lane except the logout-token `jti` replay, which is #1405's replay store |
| `1408-a` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | RULED: Lane S, five forks — 1394-a, 1397-a, 1399-a, 1404-a, 1408-a; plus the 1409-b / 1410-b decision batch |
| `1408-a` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | 1408-a — `out-err` pins the TOP-LEVEL code in ONE shared matcher; a `[cause]` is pinned by an explicit `cause=` token; oidc stops borrowing the panic converter, and a capability denial propagates as `CXER0271` |
| `1409-b` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | RULED: Lane S, five forks — 1394-a, 1397-a, 1399-a, 1404-a, 1408-a; plus the 1409-b / 1410-b decision batch |
| `1409-b` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | The decision batch — 1409-b and 1410-b (record, not build) |
| `1409-b` | [rulings_2026_09_11_sso_transport_opts_1396.md](rulings_2026_09_11_sso_transport_opts_1396.md) | 6. `Retry-After` — RULED (a), the 1409-b placement made concrete |
| `1409-c` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | 1409-c — the shape of the `client_secret_jwt` exception, decided detail by detail |
| `1410-a` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | Addendum, 2026-09-11 — RULED: 1410-a (owner, recorded here) and 1410-c |
| `1410-b` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | RULED: Lane S, five forks — 1394-a, 1397-a, 1399-a, 1404-a, 1408-a; plus the 1409-b / 1410-b decision batch |
| `1410-b` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | The decision batch — 1409-b and 1410-b (record, not build) |
| `1410-c` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | Addendum, 2026-09-11 — RULED: 1410-a (owner, recorded here) and 1410-c |
| `1411-a` | [rulings_2026_09_11_flow_ingress_turn_1411.md](rulings_2026_09_11_flow_ingress_turn_1411.md) | RULED: 1411-a — a `serial` serve gives its handlers the program's evaluator TURN; `cx flow serve` is serial |
| `1420-a` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md) | Addendum — RULED: 1420-a (Fable, 2026-09-11 11:3xZ, under the owner's delegation) — a bare-safe collection item re-reads as a STRING; the #790 kind pin follows 831-1a′ |
| `1421-a` | [rulings_2026_09_12_net_tls_accept_wrap_1421.md](rulings_2026_09_12_net_tls_accept_wrap_1421.md) | RULED: 1421-a — the server-role TLS upgrade on an accepted connection, and the `STARTTLS` offer it unblocks |
| `1421-a` | [rulings_2026_09_12_net_tls_accept_wrap_1421.md](rulings_2026_09_12_net_tls_accept_wrap_1421.md) | The name (1421-a-1) — what 1421-a's `tls-accept-wrap` becomes, and why |
| `1421-a-1` | [rulings_2026_09_12_net_tls_accept_wrap_1421.md](rulings_2026_09_12_net_tls_accept_wrap_1421.md) | The name (1421-a-1) — what 1421-a's `tls-accept-wrap` becomes, and why |
| `1421-b` | [rulings_2026_09_12_net_tls_accept_wrap_1421.md](rulings_2026_09_12_net_tls_accept_wrap_1421.md) | §3. `smtp` and `imap` — the `STARTTLS` offer (1421-b) |
| `1422-a` | [rulings_2026_09_12_audit_sink_1422.md](rulings_2026_09_12_audit_sink_1422.md) | RULED: 1422-a — the audit sink is a Ring 2 module `audit` over a reserved `journal` stream: a fixed, attributed, append-only record with a module-owned detail element; `emit` / `query` / `bind`; the boot refusal replaces the first-use one; and the `audit:` effects-trace prefix becomes the UNBOUND fallback only |
| `1422-b` | [rulings_2026_09_12_audit_sink_1422.md](rulings_2026_09_12_audit_sink_1422.md) | ADDENDUM — RULED: 1422-b — the owner's two answers to the ⚠ rows, recorded before phase 2 touched a spec or a file |
| `1427-a` | [rulings_2026_09_12_ring_legible_tree_1427.md](rulings_2026_09_12_ring_legible_tree_1427.md) | RULED: 1427-a…1427-j — the ring-legible tree (owner, 2026-09-12 ~13:40Z, option (a) on every dimension of the integrator's table) |
| `1427-j` | [rulings_2026_09_12_ring_legible_tree_1427.md](rulings_2026_09_12_ring_legible_tree_1427.md) | RULED: 1427-a…1427-j — the ring-legible tree (owner, 2026-09-12 ~13:40Z, option (a) on every dimension of the integrator's table) |
| `1430-b` | [rulings_2026_09_14_owner_letters_1430_1434.md](rulings_2026_09_14_owner_letters_1430_1434.md) | Owner letters 2026-09-14 ~04:50Z — #1430 and #1434 (RULED: 1430-b, 1434-b) |
| `1430-c` | [rulings_2026_09_14_connector_transports_1430c.md](rulings_2026_09_14_connector_transports_1430c.md) | Owner letter 2026-09-14 ~05:20Z — the connector kit executes every protocol, DB included (RULED: 1430-c) |
| `1430-d` | [rulings_2026_09_14_connector_transports_1430c.md](rulings_2026_09_14_connector_transports_1430c.md) | 1430-d — the kit is an OPEN adapter contract, wide and specialized (owner, 2026-09-14 ~05:35Z) |
| `1430-e` | [rulings_2026_09_14_connector_catalog_1430e.md](rulings_2026_09_14_connector_catalog_1430e.md) | Owner letter 2026-09-14 ~05:50Z — every connection type, every database, the reference set (RULED: 1430-e, 1455-a, 1430-f) |
| `1430-f` | [rulings_2026_09_14_connector_catalog_1430e.md](rulings_2026_09_14_connector_catalog_1430e.md) | Owner letter 2026-09-14 ~05:50Z — every connection type, every database, the reference set (RULED: 1430-e, 1455-a, 1430-f) |
| `1430-g` | [rulings_2026_09_14_connector_ingest_1430g.md](rulings_2026_09_14_connector_ingest_1430g.md) | Owner letter 2026-09-14 ~16:05Z — every kind ingests its declarative description at build time (RULED: 1430-g) |
| `1431-a` | [rulings_2026_09_13_load_class_flaky_tests_1431_1432.md](rulings_2026_09_13_load_class_flaky_tests_1431_1432.md) | RULED: 1431-a, 1432-a — two load classes join the classified serial-retry policy |
| `1431-a` | [rulings_2026_09_13_load_class_flaky_tests_1431_1432.md](rulings_2026_09_13_load_class_flaky_tests_1431_1432.md) | Why 1431-a |
| `1432-a` | [rulings_2026_09_13_load_class_flaky_tests_1431_1432.md](rulings_2026_09_13_load_class_flaky_tests_1431_1432.md) | RULED: 1431-a, 1432-a — two load classes join the classified serial-retry policy |
| `1432-a` | [rulings_2026_09_13_load_class_flaky_tests_1431_1432.md](rulings_2026_09_13_load_class_flaky_tests_1431_1432.md) | Why 1432-a |
| `1434-a` | [rulings_2026_09_13_incremental_sync_1434.md](rulings_2026_09_13_incremental_sync_1434.md) | Ruling 2026-09-13 — #1434 (#728 component 3): incremental sync — placement, decided before the spec (1434-a) |
| `1434-a` | [rulings_2026_09_13_incremental_sync_1434.md](rulings_2026_09_13_incremental_sync_1434.md) | 1434-a — the module is `sync`, Ring 2, and where each of its four dimensions lives |
| `1434-a` | [rulings_2026_09_13_incremental_sync_1434.md](rulings_2026_09_13_incremental_sync_1434.md) | The scope 1434-a fixes |
| `1434-b` | [rulings_2026_09_14_owner_letters_1430_1434.md](rulings_2026_09_14_owner_letters_1430_1434.md) | Owner letters 2026-09-14 ~04:50Z — #1430 and #1434 (RULED: 1430-b, 1434-b) |
| `1434-c` | [rulings_2026_09_14_owner_letters_1434c_1437_1451.md](rulings_2026_09_14_owner_letters_1434c_1437_1451.md) | Owner letters 2026-09-14 ~04:55Z — #1434 (5, 6), #1437, #1451 (RULED: 1434-c, 1437-a, 1451-a) |
| `1437-a` | [rulings_2026_09_14_owner_letters_1434c_1437_1451.md](rulings_2026_09_14_owner_letters_1434c_1437_1451.md) | Owner letters 2026-09-14 ~04:55Z — #1434 (5, 6), #1437, #1451 (RULED: 1434-c, 1437-a, 1451-a) |
| `1449-a` | [rulings_2026_09_14_profile_gate_tail_1449.md](rulings_2026_09_14_profile_gate_tail_1449.md) | Ruling 2026-09-14 — #1449: the profile gate's serial tail is built inside the -j block and graded at two compositions concurrently (1449-a) |
| `1451-a` | [rulings_2026_09_14_owner_letters_1434c_1437_1451.md](rulings_2026_09_14_owner_letters_1434c_1437_1451.md) | Owner letters 2026-09-14 ~04:55Z — #1434 (5, 6), #1437, #1451 (RULED: 1434-c, 1437-a, 1451-a) |
| `1451-b` | [rulings_2026_09_14_owner_letters_1451b_m2_patterns.md](rulings_2026_09_14_owner_letters_1451b_m2_patterns.md) | Owner letters 2026-09-14 ~19:20Z — "1c 2a 3a" (RULED: 1451-b, INT-3 addendum 2, COMP-1 addendum) |
| `1453-a` | [rulings_2026_09_15_owner_decisions_1145z.md](rulings_2026_09_15_owner_decisions_1145z.md) | Owner decisions 2026-09-15 ~11:45Z — "1a 2a 3 accepted 4a 5a 6a" (RULED: 1502-a, 1456-a, 1503-a, 1256-a, 1453-a) |
| `1455-a` | [rulings_2026_09_14_connector_catalog_1430e.md](rulings_2026_09_14_connector_catalog_1430e.md) | Owner letter 2026-09-14 ~05:50Z — every connection type, every database, the reference set (RULED: 1430-e, 1455-a, 1430-f) |
| `1456-a` | [rulings_2026_09_15_owner_decisions_1145z.md](rulings_2026_09_15_owner_decisions_1145z.md) | Owner decisions 2026-09-15 ~11:45Z — "1a 2a 3 accepted 4a 5a 6a" (RULED: 1502-a, 1456-a, 1503-a, 1256-a, 1453-a) |
| `1456-b` | [rulings_2026_09_18_owner_decisions_1640z.md](rulings_2026_09_18_owner_decisions_1640z.md) | Owner decisions 2026-09-18 ~16:40Z — "recommendations accepted": twenty-one issues closed by the owner's word on the triage list (TRIAGE-1); the soap version is the string '1.1' (1575-b); unknown Security members are carried (1456-b) |
| `1457-a` | [rulings_2026_09_15_owner_decisions_1830z.md](rulings_2026_09_15_owner_decisions_1830z.md) | Owner decisions 2026-09-15 ~18:30Z — "1a 2a 3a 4a" (RULED: INT-20, 1503-b, 1502-b, 1457-a) |
| `1461-a` | [rulings_2026_09_18_owner_decisions_1620z.md](rulings_2026_09_18_owner_decisions_1620z.md) | Decisions 2026-09-18 ~16:20Z — the ws defs' placement between the two http halves (1461-a); an atom the renderer writes must read back (1575-a) |
| `1466-a` | [rulings_2026_09_18_owner_decisions_2345z.md](rulings_2026_09_18_owner_decisions_2345z.md) | Owner decisions 2026-09-18 ~23:45Z — the set module's code band (1173-c); the deployment binding's spelling enters connector.md §4.6 (1466-a); the adapter contract gains a `binding-of` hook (1483-a) |
| `1483-a` | [rulings_2026_09_18_owner_decisions_2345z.md](rulings_2026_09_18_owner_decisions_2345z.md) | Owner decisions 2026-09-18 ~23:45Z — the set module's code band (1173-c); the deployment binding's spelling enters connector.md §4.6 (1466-a); the adapter contract gains a `binding-of` hook (1483-a) |
| `1502-a` | [rulings_2026_09_15_owner_decisions_1145z.md](rulings_2026_09_15_owner_decisions_1145z.md) | Owner decisions 2026-09-15 ~11:45Z — "1a 2a 3 accepted 4a 5a 6a" (RULED: 1502-a, 1456-a, 1503-a, 1256-a, 1453-a) |
| `1502-b` | [rulings_2026_09_15_owner_decisions_1830z.md](rulings_2026_09_15_owner_decisions_1830z.md) | Owner decisions 2026-09-15 ~18:30Z — "1a 2a 3a 4a" (RULED: INT-20, 1503-b, 1502-b, 1457-a) |
| `1503-a` | [rulings_2026_09_15_owner_decisions_1145z.md](rulings_2026_09_15_owner_decisions_1145z.md) | Owner decisions 2026-09-15 ~11:45Z — "1a 2a 3 accepted 4a 5a 6a" (RULED: 1502-a, 1456-a, 1503-a, 1256-a, 1453-a) |
| `1503-b` | [rulings_2026_09_15_owner_decisions_1830z.md](rulings_2026_09_15_owner_decisions_1830z.md) | Owner decisions 2026-09-15 ~18:30Z — "1a 2a 3a 4a" (RULED: INT-20, 1503-b, 1502-b, 1457-a) |
| `1503-b` | [rulings_2026_09_16_integrator_decisions.md](rulings_2026_09_16_integrator_decisions.md) | Integrator decisions, 2026-09-16 — the 1503-b addendum |
| `1509-a` | [rulings_2026_09_18_owner_decisions_1220z.md](rulings_2026_09_18_owner_decisions_1220z.md) | Owner decisions 2026-09-18 ~12:20Z — "all recommendations": the work continues past the clock with umbrella steps for Ring 0 (VERIFY-2); the twelve open letters ruled (1563-a, 1559-a, 1515-a, 1566-c, 1534-a, 1552-a, 1556-a, 1540-a, 1551-b, 1544-b, 1509-a) and the integrator's 1559-d recorded |
| `1509-a` | [rulings_2026_09_27_integrator_decisions_l60.md](rulings_2026_09_27_integrator_decisions_l60.md) | 1690's agent; reversible by the owner's word. 1509-a, CXF-8, FIX-1, #1690.** |
| `1509-a` | [rulings_2026_09_28_owner_decisions_l80_l84.md](rulings_2026_09_28_owner_decisions_l80_l84.md) | LITER-1 — a `[?for]` contributes one item per `[yield]` in a `(…)` or array literal, as 1509-a says (L83 = (b)) |
| `1515-a` | [rulings_2026_09_18_owner_decisions_1220z.md](rulings_2026_09_18_owner_decisions_1220z.md) | Owner decisions 2026-09-18 ~12:20Z — "all recommendations": the work continues past the clock with umbrella steps for Ring 0 (VERIFY-2); the twelve open letters ruled (1563-a, 1559-a, 1515-a, 1566-c, 1534-a, 1552-a, 1556-a, 1540-a, 1551-b, 1544-b, 1509-a) and the integrator's 1559-d recorded |
| `1521-a` | [rulings_2026_09_17_owner_decisions_2202z.md](rulings_2026_09_17_owner_decisions_2202z.md) | Owner decisions 2026-09-17 ~22:02Z — an unread err binding propagates (1537-a); the quote-opening rule becomes a lexicon sentence (1521-a) |
| `1527-a` | [rulings_2026_09_17_trap_batches.md](rulings_2026_09_17_trap_batches.md) | The traps become fixtures — two batch branches for the CXF-8 defects, and the one ruling they need (RULED: TRAP-1, 1527-a) |
| `1534-a` | [rulings_2026_09_18_owner_decisions_1220z.md](rulings_2026_09_18_owner_decisions_1220z.md) | Owner decisions 2026-09-18 ~12:20Z — "all recommendations": the work continues past the clock with umbrella steps for Ring 0 (VERIFY-2); the twelve open letters ruled (1563-a, 1559-a, 1515-a, 1566-c, 1534-a, 1552-a, 1556-a, 1540-a, 1551-b, 1544-b, 1509-a) and the integrator's 1559-d recorded |
| `1536-a` | [rulings_2026_09_18_owner_decisions_0440z.md](rulings_2026_09_18_owner_decisions_0440z.md) | Owner decisions 2026-09-18 ~04:40Z — `cx --ast` arbitrates the two readings as `cx lint` does (1536-a); `[?fn]` has no labeled slots (1558-b); the verification-cost lane is written (VCOST-1) |
| `1537-a` | [rulings_2026_09_17_owner_decisions_2202z.md](rulings_2026_09_17_owner_decisions_2202z.md) | Owner decisions 2026-09-17 ~22:02Z — an unread err binding propagates (1537-a); the quote-opening rule becomes a lexicon sentence (1521-a) |
| `1540-a` | [rulings_2026_09_18_owner_decisions_1220z.md](rulings_2026_09_18_owner_decisions_1220z.md) | Owner decisions 2026-09-18 ~12:20Z — "all recommendations": the work continues past the clock with umbrella steps for Ring 0 (VERIFY-2); the twelve open letters ruled (1563-a, 1559-a, 1515-a, 1566-c, 1534-a, 1552-a, 1556-a, 1540-a, 1551-b, 1544-b, 1509-a) and the integrator's 1559-d recorded |
| `1544-a` | [rulings_2026_09_18_owner_decisions_0155z.md](rulings_2026_09_18_owner_decisions_0155z.md) | Owner decisions 2026-09-18 ~01:55Z — CSRP does not exist in cx: every live reference goes (1544-a); the two readers' divergence is a named property and the em-dash refusal a lexer bug (1548-c) |
| `1544-b` | [rulings_2026_09_18_owner_decisions_1220z.md](rulings_2026_09_18_owner_decisions_1220z.md) | Owner decisions 2026-09-18 ~12:20Z — "all recommendations": the work continues past the clock with umbrella steps for Ring 0 (VERIFY-2); the twelve open letters ruled (1563-a, 1559-a, 1515-a, 1566-c, 1534-a, 1552-a, 1556-a, 1540-a, 1551-b, 1544-b, 1509-a) and the integrator's 1559-d recorded |
| `1544-c` | [rulings_2026_09_18_owner_decisions_2100z.md](rulings_2026_09_18_owner_decisions_2100z.md) | Owner decisions 2026-09-18 ~18:30Z–21:00Z — the design backlog leaves the release label (BACKLOG-1); the store's wire field is `wire-version` (1544-c); the sched restore cases carry their ring |
| `1545-a` | [rulings_2026_09_18_owner_decisions_0200z.md](rulings_2026_09_18_owner_decisions_0200z.md) | Owner decision 2026-09-18 ~02:00Z — an err value carries its position (1545-a); the diagnostics audit's fix batches are decided (DIAG-1) |
| `1548-c` | [rulings_2026_09_18_owner_decisions_0155z.md](rulings_2026_09_18_owner_decisions_0155z.md) | Owner decisions 2026-09-18 ~01:55Z — CSRP does not exist in cx: every live reference goes (1544-a); the two readers' divergence is a named property and the em-dash refusal a lexer bug (1548-c) |
| `1551-b` | [rulings_2026_09_18_owner_decisions_1220z.md](rulings_2026_09_18_owner_decisions_1220z.md) | Owner decisions 2026-09-18 ~12:20Z — "all recommendations": the work continues past the clock with umbrella steps for Ring 0 (VERIFY-2); the twelve open letters ruled (1563-a, 1559-a, 1515-a, 1566-c, 1534-a, 1552-a, 1556-a, 1540-a, 1551-b, 1544-b, 1509-a) and the integrator's 1559-d recorded |
| `1552-a` | [rulings_2026_09_18_owner_decisions_1220z.md](rulings_2026_09_18_owner_decisions_1220z.md) | Owner decisions 2026-09-18 ~12:20Z — "all recommendations": the work continues past the clock with umbrella steps for Ring 0 (VERIFY-2); the twelve open letters ruled (1563-a, 1559-a, 1515-a, 1566-c, 1534-a, 1552-a, 1556-a, 1540-a, 1551-b, 1544-b, 1509-a) and the integrator's 1559-d recorded |
| `1556-a` | [rulings_2026_09_18_owner_decisions_1220z.md](rulings_2026_09_18_owner_decisions_1220z.md) | Owner decisions 2026-09-18 ~12:20Z — "all recommendations": the work continues past the clock with umbrella steps for Ring 0 (VERIFY-2); the twelve open letters ruled (1563-a, 1559-a, 1515-a, 1566-c, 1534-a, 1552-a, 1556-a, 1540-a, 1551-b, 1544-b, 1509-a) and the integrator's 1559-d recorded |
| `1558-b` | [rulings_2026_09_18_owner_decisions_0440z.md](rulings_2026_09_18_owner_decisions_0440z.md) | Owner decisions 2026-09-18 ~04:40Z — `cx --ast` arbitrates the two readings as `cx lint` does (1536-a); `[?fn]` has no labeled slots (1558-b); the verification-cost lane is written (VCOST-1) |
| `1559-a` | [rulings_2026_09_18_owner_decisions_1220z.md](rulings_2026_09_18_owner_decisions_1220z.md) | Owner decisions 2026-09-18 ~12:20Z — "all recommendations": the work continues past the clock with umbrella steps for Ring 0 (VERIFY-2); the twelve open letters ruled (1563-a, 1559-a, 1515-a, 1566-c, 1534-a, 1552-a, 1556-a, 1540-a, 1551-b, 1544-b, 1509-a) and the integrator's 1559-d recorded |
| `1559-d` | [rulings_2026_09_18_owner_decisions_1220z.md](rulings_2026_09_18_owner_decisions_1220z.md) | Owner decisions 2026-09-18 ~12:20Z — "all recommendations": the work continues past the clock with umbrella steps for Ring 0 (VERIFY-2); the twelve open letters ruled (1563-a, 1559-a, 1515-a, 1566-c, 1534-a, 1552-a, 1556-a, 1540-a, 1551-b, 1544-b, 1509-a) and the integrator's 1559-d recorded |
| `1562-a` | [rulings_2026_09_19_owner_decisions_0445z.md](rulings_2026_09_19_owner_decisions_0445z.md) | Owner decisions 2026-09-19 ~04:45Z — a failed run reports every red class (RUN-2); the daily full union runs on an idle runner (RUN-3); an escalated branch runs the computed selection pre-merge (RUN-4); the run log carries step timing and the timings file (RUN-5); the two agents and their order (AGENTS-1); the budget step stays open until it measures (1562-a) |
| `1563-a` | [rulings_2026_09_18_owner_decisions_1220z.md](rulings_2026_09_18_owner_decisions_1220z.md) | Owner decisions 2026-09-18 ~12:20Z — "all recommendations": the work continues past the clock with umbrella steps for Ring 0 (VERIFY-2); the twelve open letters ruled (1563-a, 1559-a, 1515-a, 1566-c, 1534-a, 1552-a, 1556-a, 1540-a, 1551-b, 1544-b, 1509-a) and the integrator's 1559-d recorded |
| `1566-c` | [rulings_2026_09_18_owner_decisions_1220z.md](rulings_2026_09_18_owner_decisions_1220z.md) | Owner decisions 2026-09-18 ~12:20Z — "all recommendations": the work continues past the clock with umbrella steps for Ring 0 (VERIFY-2); the twelve open letters ruled (1563-a, 1559-a, 1515-a, 1566-c, 1534-a, 1552-a, 1556-a, 1540-a, 1551-b, 1544-b, 1509-a) and the integrator's 1559-d recorded |
| `1575-a` | [rulings_2026_09_18_owner_decisions_1620z.md](rulings_2026_09_18_owner_decisions_1620z.md) | Decisions 2026-09-18 ~16:20Z — the ws defs' placement between the two http halves (1461-a); an atom the renderer writes must read back (1575-a) |
| `1575-b` | [rulings_2026_09_18_owner_decisions_1640z.md](rulings_2026_09_18_owner_decisions_1640z.md) | Owner decisions 2026-09-18 ~16:40Z — "recommendations accepted": twenty-one issues closed by the owner's word on the triage list (TRIAGE-1); the soap version is the string '1.1' (1575-b); unknown Security members are carried (1456-b) |
| `192-gcm` | [rulings_2026_09_11_saml_xml_encryption_1400_1401.md](rulings_2026_09_11_saml_xml_encryption_1400_1401.md) | RULED: 1400-a, 1401-a — XML Encryption comes IN: `saml:verify` decrypts `EncryptedAssertion` / `EncryptedID` / `EncryptedAttribute` with `opts.decryption-keys`; `crypto` gains RSA key transport (OAEP, SHA-1 inside OAEP allowed; PKCS#1 v1.5 behind a loud opt-in with implicit rejection) and AES-CBC + AES-128/192-GCM; encryption is detected BEFORE the signature search |
| `728-ck-4b` | [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md) | RULED: 728-CK-4b — ingestion NEVER infers `idempotent=` — RULED: (a) under the standing letter-acceptance rule (owner veto open) |
| `787-poc` | [rulings_2026_08_19_787_integration.md](rulings_2026_08_19_787_integration.md) | Ledger — #787 integration: the ONE rebase of impl/787-poc onto release/0.16.0 |
| `aa-1` | [rulings_2026_09_26_automation_authoring_l40.md](rulings_2026_09_26_automation_authoring_l40.md) | Owner decisions 2026-09-26 — Letter 40, end-user automation authoring (#1498): AA-1…AA-6 |
| `aa-1` | [rulings_2026_09_26_automation_authoring_l40.md](rulings_2026_09_26_automation_authoring_l40.md) | AA-1 — a skeleton is a CX document shipped as data (L40.1 = (a)) |
| `aa-10` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | AA-10 — the #1498 spec branch is approved (owner, 2026-09-27 ~04:0xZ: "specs approved") |
| `aa-2` | [rulings_2026_09_26_automation_authoring_l40.md](rulings_2026_09_26_automation_authoring_l40.md) | AA-2 — four skeletons and one selection attribute (L40.2 = (a)) |
| `aa-3` | [rulings_2026_09_26_automation_authoring_l40.md](rulings_2026_09_26_automation_authoring_l40.md) | AA-3 — one pure `fill`, two callers (L40.3 = (a)) |
| `aa-4` | [rulings_2026_09_26_automation_authoring_l40.md](rulings_2026_09_26_automation_authoring_l40.md) | AA-4 — a fourth studio plane filled from closed pick-lists (L40.4 = (a)) |
| `aa-5` | [rulings_2026_09_26_automation_authoring_l40.md](rulings_2026_09_26_automation_authoring_l40.md) | AA-5 — a published automation lives on the tenant's own automation stream (L40.5 = (a)) |
| `aa-6` | [rulings_2026_09_26_automation_authoring_l40.md](rulings_2026_09_26_automation_authoring_l40.md) | Owner decisions 2026-09-26 — Letter 40, end-user automation authoring (#1498): AA-1…AA-6 |
| `aa-6` | [rulings_2026_09_26_automation_authoring_l40.md](rulings_2026_09_26_automation_authoring_l40.md) | AA-6 — two grades, one fixture shape (L40.6 = (a)) |
| `aa-7` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | Owner decisions 2026-09-27 — Letters 46–50 and the org profile: KIT-4's shape (KIT4-1…3), the #1498 spec gaps (AA-7…9), HOST-4's seed made real (SEED-1), the host act's basis (HOSTB-1), the call spread's readings (SPREAD-2), the org-profile push (ORG-1) |
| `aa-7` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | AA-7 — `fill` lives in `cx-platform/flow` (L47.1 = (a)) |
| `aa-8` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | AA-8 — the CLI names the binder (L47.2 = (a)) |
| `aa-9` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | AA-9 — the boot check counts the automation stream (L47.3 = (a)) |
| `ack-1` | [rulings_2026_09_27_owner_decisions_l52_l54.md](rulings_2026_09_27_owner_decisions_l52_l54.md) | Owner decisions 2026-09-27 (afternoon) — Letters 52, 53 and 54: XCO's two readings (ACK-1, RT-1), a list verb through the host walks every page (WALK-1), the vendor budget is per process (BUDGET-1) |
| `ack-1` | [rulings_2026_09_27_owner_decisions_l52_l54.md](rulings_2026_09_27_owner_decisions_l52_l54.md) | ACK-1 — `by=` on the `:peer` step's ack is a space-separated list of DIDs (L52.1 = (a)) |
| `ackr-1` | [rulings_2026_09_27_owner_decisions_l59.md](rulings_2026_09_27_owner_decisions_l59.md) | Owner decision 2026-09-27 (evening) — Letter 59: the host's ack stays a receipt (ACKR-1) |
| `ackr-1` | [rulings_2026_09_27_owner_decisions_l59.md](rulings_2026_09_27_owner_decisions_l59.md) | ACKR-1 — an act's answer is read from the record, not carried by the ack (L59 = (a)) |
| `ad-1` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) | AD-1 — `[selection …]` binds every consumption point, through the one PEP (#1181) |
| `ad-10` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) | AD-10 — instantiation is CONTRACT-LEVEL by design, and an unservable `[add]` refuses (#1162) |
| `ad-2` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) | AD-2 — contract evolution gets the SEA-1 treatment (#1182) |
| `ad-3` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) | AD-3 — content addresses: a stated promise, declared migrations, and a re-derivation command (#1183) |
| `ad-4` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) | AD-4 — planned supersession is an ATTESTATION, not a manifest element (#1184) |
| `ad-5` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) | AD-5 — declarative process is #789's vocabulary, projected at the XAP layer — never a second one (#1185) |
| `ad-5` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) | AD-5 execution record — the reconciled design (W5, #1185 / #789) |
| `ad-5` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) | Why not two vocabularies (AD-5(b), refused) |
| `ad-5` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) | Why not "application territory" (AD-5(c), refused) |
| `ad-6` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) | AD-6 — per-tenant fields are tenant DATA, and never enter the composed grammar (#1186) |
| `ad-7` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) | AD-7 — v0.18 campaign scope: four land whole, one lands as a capability, one lands as design |
| `ad-8` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) | AD-8 — admit #1161 and #1162 to the campaign |
| `ad-9` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) | AD-9 — a first-party feature library, and the register of what must NOT be a feature (#1189) |
| `ae-1` | [rulings_2026_08_26_diagram_arm_escape_1037.md](rulings_2026_08_26_diagram_arm_escape_1037.md) | AE-1 — the two sides, measured |
| `ae-2` | [rulings_2026_08_26_diagram_arm_escape_1037.md](rulings_2026_08_26_diagram_arm_escape_1037.md) | AE-2 — which side the spec supports |
| `ae-3` | [rulings_2026_08_26_diagram_arm_escape_1037.md](rulings_2026_08_26_diagram_arm_escape_1037.md) | AE-3 — the fix removes the switch rather than flipping it |
| `ae-4` | [rulings_2026_08_26_diagram_arm_escape_1037.md](rulings_2026_08_26_diagram_arm_escape_1037.md) | AE-4 — golden movement: NONE, and that is the finding |
| `ae-5` | [rulings_2026_08_26_diagram_arm_escape_1037.md](rulings_2026_08_26_diagram_arm_escape_1037.md) | AE-5 — the pins that close it |
| `ae-6` | [rulings_2026_08_26_diagram_arm_escape_1037.md](rulings_2026_08_26_diagram_arm_escape_1037.md) | AE-6 — red-proof |
| `aes-128` | [rulings_2026_09_11_saml_xml_encryption_1400_1401.md](rulings_2026_09_11_saml_xml_encryption_1400_1401.md) | RULED: 1400-a, 1401-a — XML Encryption comes IN: `saml:verify` decrypts `EncryptedAssertion` / `EncryptedID` / `EncryptedAttribute` with `opts.decryption-keys`; `crypto` gains RSA key transport (OAEP, SHA-1 inside OAEP allowed; PKCS#1 v1.5 behind a loud opt-in with implicit rejection) and AES-CBC + AES-128/192-GCM; encryption is detected BEFORE the signature search |
| `agents-1` | [rulings_2026_09_19_owner_decisions_0445z.md](rulings_2026_09_19_owner_decisions_0445z.md) | Owner decisions 2026-09-19 ~04:45Z — a failed run reports every red class (RUN-2); the daily full union runs on an idle runner (RUN-3); an escalated branch runs the computed selection pre-merge (RUN-4); the run log carries step timing and the timings file (RUN-5); the two agents and their order (AGENTS-1); the budget step stays open until it measures (1562-a) |
| `anc-1` | [rulings_2026_08_20_anchor_semantics.md](rulings_2026_08_20_anchor_semantics.md) | Ruling ANC-1 (2026-08-20) — the Resolved AST is the semantic reading (#877, owner "3a") |
| `anc-1` | [rulings_2026_08_20_anchor_semantics.md](rulings_2026_08_20_anchor_semantics.md) | ANC-1 implementation record + ANC-1a (XML lane), 2026-08-20 (#877 landing) |
| `anc-1a` | [rulings_2026_08_20_anchor_semantics.md](rulings_2026_08_20_anchor_semantics.md) | ANC-1 implementation record + ANC-1a (XML lane), 2026-08-20 (#877 landing) |
| `arr-1` | [rulings_2026_08_20_read_construct.md](rulings_2026_08_20_read_construct.md) | ARR-1 — readers destructure any collection; constructors keep container typing |
| `asp-1` | [rulings_2026_08_21_array_separator.md](rulings_2026_08_21_array_separator.md) | ASP-1 — one rule for array-literal items, with no exceptions |
| `asp-1` | [rulings_2026_08_21_array_separator.md](rulings_2026_08_21_array_separator.md) | ASP-1 REVERTED (2026-08-21, same day) — the uniform rule collides with mixed-content slots |
| `asp-1a` | [rulings_2026_08_21_array_separator.md](rulings_2026_08_21_array_separator.md) | ASP-1a — the same fault at the TOP LEVEL (#906) |
| `asp-2` | [rulings_2026_08_21_array_separator.md](rulings_2026_08_21_array_separator.md) | ASP-2 — RULED (owner "b", 2026-08-21): the discrete-token array, plus the slot-fill rule |
| `asp-3` | [rulings_2026_08_21_surface_closeout.md](rulings_2026_08_21_surface_closeout.md) | ASP-3 — the element body reads discrete values, like every position beside it (#909) |
| `atc-1` | [rulings_2026_08_20_authoring_toolchain.md](rulings_2026_08_20_authoring_toolchain.md) | ATC-1 — client.cxs authored; the surface derivation check graduates to `cx xap check-surface` |
| `atc-2` | [rulings_2026_08_20_runnable_client.md](rulings_2026_08_20_runnable_client.md) | ATC-2 — `cx xap init --client` produces a RUNNABLE client |
| `atc-2` | [rulings_2026_08_20_runnable_client.md](rulings_2026_08_20_runnable_client.md) | ATC-2 riders resolved at integration (parent session, same day) |
| `bare-1` | [rulings_2026_09_28_owner_decisions_l80_l84.md](rulings_2026_09_28_owner_decisions_l80_l84.md) | BARE-1 — a bare head is data, namespaced or not; `$` is the only call sigil (L84 = (a)) |
| `batch-1` | [rulings_2026_09_16_batch_branches_batch1.md](rulings_2026_09_16_batch_branches_batch1.md) | Integrator decision 2026-09-16 ~10:15Z — a batch branch carries several small bugs of one ring (RULED: BATCH-1) |
| `bc-1` | [rulings_2026_08_22_bug_campaign.md](rulings_2026_08_22_bug_campaign.md) | Ruling 2026-08-22 — the bug campaign to cut-readiness (BC-1..BC-4) |
| `bc-1` | [rulings_2026_08_22_bug_campaign.md](rulings_2026_08_22_bug_campaign.md) | BC-1 (1a) — #923: the program reading of a multi-dot bare attr value is the STRING, parity with the data reading |
| `bc-2` | [rulings_2026_08_22_bug_campaign.md](rulings_2026_08_22_bug_campaign.md) | BC-2 (2a) — examples/htmx/serve.py is REWRITTEN IN CX on [?http-service] |
| `bc-3` | [rulings_2026_08_22_bug_campaign.md](rulings_2026_08_22_bug_campaign.md) | BC-3 (order, owner-corrected) — #925 is the first MAJOR; #923 alone cuts ahead as prio:high-ASAP |
| `bc-4` | [rulings_2026_08_22_bug_campaign.md](rulings_2026_08_22_bug_campaign.md) | Ruling 2026-08-22 — the bug campaign to cut-readiness (BC-1..BC-4) |
| `bc-4` | [rulings_2026_08_22_bug_campaign.md](rulings_2026_08_22_bug_campaign.md) | BC-4 (4a) — the v0.16.0 cut WAITS on this campaign |
| `bex-1` | [rulings_2026_09_27_owner_decisions_l41_l44.md](rulings_2026_09_27_owner_decisions_l41_l44.md) | Owner decisions 2026-09-27 — Letters 41–45: the call spread (SPREAD-1), the orders-db partial (ODB-1), R-1492 as graded (BEX-1), the bus audit subject (BUS-1), no new agents (PACE-2) |
| `bex-1` | [rulings_2026_09_27_owner_decisions_l41_l44.md](rulings_2026_09_27_owner_decisions_l41_l44.md) | BEX-1 — R-1492 merges as graded; the socket-driven flow follows cx-platform-flow#12 (Letter 43 = (a)) |
| `bp-1` | [rulings_2026_08_20_binding_axes.md](rulings_2026_08_20_binding_axes.md) | BP-1 — binding paths carry the value-meaningful compact steps only |
| `bp-1` | [rulings_2026_08_20_call_result_steps.md](rulings_2026_08_20_call_result_steps.md) | CRS-1a rider — code.md §6.2 trued to BP-1 |
| `budget-1` | [rulings_2026_09_27_owner_decisions_l52_l54.md](rulings_2026_09_27_owner_decisions_l52_l54.md) | Owner decisions 2026-09-27 (afternoon) — Letters 52, 53 and 54: XCO's two readings (ACK-1, RT-1), a list verb through the host walks every page (WALK-1), the vendor budget is per process (BUDGET-1) |
| `budget-1` | [rulings_2026_09_27_owner_decisions_l52_l54.md](rulings_2026_09_27_owner_decisions_l52_l54.md) | BUDGET-1 — the vendor budget is per process under one host per tenant; §4.3 says so (L54 = (a)) |
| `bus-1` | [rulings_2026_09_27_owner_decisions_l41_l44.md](rulings_2026_09_27_owner_decisions_l41_l44.md) | Owner decisions 2026-09-27 — Letters 41–45: the call spread (SPREAD-1), the orders-db partial (ODB-1), R-1492 as graded (BEX-1), the bus audit subject (BUS-1), no new agents (PACE-2) |
| `bus-1` | [rulings_2026_09_27_owner_decisions_l41_l44.md](rulings_2026_09_27_owner_decisions_l41_l44.md) | BUS-1 — the bus audit record's subject (Letter 44 = (a)) |
| `ca-1` | [rulings_2026_09_03_canonical_act_form_1260.md](rulings_2026_09_03_canonical_act_form_1260.md) | CA-1 — the canonical act form — RECOMMENDED: (a) |
| `ca-1` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | 1260 CA-1..CA-4 were ruled. Branch |
| `ca-2` | [rulings_2026_09_03_canonical_act_form_1260.md](rulings_2026_09_03_canonical_act_form_1260.md) | CA-2 — how a flow step carries its act — RECOMMENDED: (a) |
| `ca-3` | [rulings_2026_09_03_canonical_act_form_1260.md](rulings_2026_09_03_canonical_act_form_1260.md) | CA-3 — the run's input record — RECOMMENDED: (a) |
| `ca-4` | [rulings_2026_09_03_canonical_act_form_1260.md](rulings_2026_09_03_canonical_act_form_1260.md) | CA-4 — sequencing the host cutover — RULED (a) BY OWNER 2026-09-03 |
| `ca-4` | [rulings_2026_09_03_canonical_act_form_1260.md](rulings_2026_09_03_canonical_act_form_1260.md) | Edit map (ruling-gated; lands with the CA-4 landing, NOT this branch) |
| `ca-4` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | 1260 CA-1..CA-4 were ruled. Branch |
| `capadr-1` | [rulings_2026_09_27_owner_decisions_l58.md](rulings_2026_09_27_owner_decisions_l58.md) | Owner decisions 2026-09-27 (evening) — Letter 58: a feature's gate is the feature's (GATE-1), the boot report names each seeded basis (CAPADR-1) |
| `capadr-1` | [rulings_2026_09_27_owner_decisions_l58.md](rulings_2026_09_27_owner_decisions_l58.md) | CAPADR-1 — the boot report prints each seeded basis (L58.3 = (a)) |
| `capex-1` | [rulings_2026_09_28_integrator_decisions_l64_l70.md](rulings_2026_09_28_integrator_decisions_l64_l70.md) | CAPEX-1 — `[capture]` is exempt from the connector's credential scan (L70 = (a)) |
| `cbkey-1` | [rulings_2026_09_28_owner_decisions_l80_l84.md](rulings_2026_09_28_owner_decisions_l80_l84.md) | CBKEY-1 — a computed `name=` keys resilience state by its evaluated value (L82 = (a)) |
| `cfg-1` | [rulings_2026_09_13_claude_context_audit.md](rulings_2026_09_13_claude_context_audit.md) | RULED: CFG-1 — the agent-context layers get ONE stated precedence, the load-bearing agent rules become tracked repo content, and the stale config is removed |
| `cg-1` | [rulings_2026_09_05_constraint_grammar_1308.md](rulings_2026_09_05_constraint_grammar_1308.md) | Rulings 2026-09-05 — #1308 the feature grammar as a CONSTRAINT grammar (CG-1..CG-7) |
| `cg-1` | [rulings_2026_09_05_constraint_grammar_1308.md](rulings_2026_09_05_constraint_grammar_1308.md) | CG-1 — `kind=cardinality` (#1301) — RULED (a) |
| `cg-2` | [rulings_2026_09_05_constraint_grammar_1308.md](rulings_2026_09_05_constraint_grammar_1308.md) | CG-2 — the evaluable `[check]` and rule scope (#1302) — RULED (a) |
| `cg-3` | [rulings_2026_09_05_constraint_grammar_1308.md](rulings_2026_09_05_constraint_grammar_1308.md) | CG-3 — `type=` resolves to the schema type language (#1303) — RULED (a) |
| `cg-4` | [rulings_2026_09_05_constraint_grammar_1308.md](rulings_2026_09_05_constraint_grammar_1308.md) | CG-4 — the verb declares its transition (#1304) — RULED (a) |
| `cg-5` | [rulings_2026_09_05_constraint_grammar_1308.md](rulings_2026_09_05_constraint_grammar_1308.md) | CG-5 — a derived noun carries its `[fold]` (#1305) — RULED (a) |
| `cg-6` | [rulings_2026_09_05_constraint_grammar_1308.md](rulings_2026_09_05_constraint_grammar_1308.md) | CG-6 — the valid-time axis (#1306) — RULED (a′) |
| `cg-7` | [rulings_2026_09_05_constraint_grammar_1308.md](rulings_2026_09_05_constraint_grammar_1308.md) | Rulings 2026-09-05 — #1308 the feature grammar as a CONSTRAINT grammar (CG-1..CG-7) |
| `cg-7` | [rulings_2026_09_05_constraint_grammar_1308.md](rulings_2026_09_05_constraint_grammar_1308.md) | CG-7 — what a surface needs beyond `[views]`, and fields on the composed grammar (#1307) — RULED (a) |
| `cicd-1` | [rulings_2026_09_28_owner_direction_cicd1.md](rulings_2026_09_28_owner_direction_cicd1.md) | Owner direction 2026-09-28 (morning) — documentation generation in the cx-flow CI/CD (CICD-1) |
| `cicd-1` | [rulings_2026_09_28_owner_direction_cicd1.md](rulings_2026_09_28_owner_direction_cicd1.md) | CICD-1 — every generated document is made, checked and assembled by one cx flow document |
| `ck-1` | [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md) | Rulings 2026-09-06 — #728 component 2: a connector is a feature (CK-1 … CK-6) |
| `ck-1` | [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md) | CK-1 — what a connector IS — RULED: (a) |
| `ck-10` | [rulings_2026_09_06_connector_open_items_728.md](rulings_2026_09_06_connector_open_items_728.md) | Rulings 2026-09-06 — #728 component 2: the four open items (CK-7 … CK-10) |
| `ck-10` | [rulings_2026_09_06_connector_open_items_728.md](rulings_2026_09_06_connector_open_items_728.md) | CK-10 — per-feature network reach in one process (#747's prerequisite) — RULED: (a) |
| `ck-2` | [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md) | CK-2 — where the transport declaration lives — RULED: (a) |
| `ck-3` | [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md) | CK-3 — one road to a verb from both faces — RULED: (a) |
| `ck-4` | [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md) | CK-4 — OpenAPI ingestion: what it produces, and when — RULED: (a) |
| `ck-5` | [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md) | CK-5 — where the engine lives — RULED: (a) |
| `ck-6` | [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md) | Rulings 2026-09-06 — #728 component 2: a connector is a feature (CK-1 … CK-6) |
| `ck-6` | [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md) | CK-6 — a connector feature does NOT depend on flow — RULED: (a) |
| `ck-7` | [rulings_2026_09_06_connector_open_items_728.md](rulings_2026_09_06_connector_open_items_728.md) | Rulings 2026-09-06 — #728 component 2: the four open items (CK-7 … CK-10) |
| `ck-7` | [rulings_2026_09_06_connector_open_items_728.md](rulings_2026_09_06_connector_open_items_728.md) | CK-7 — where `client_credentials` lands — RULED: (a) |
| `ck-8` | [rulings_2026_09_06_connector_open_items_728.md](rulings_2026_09_06_connector_open_items_728.md) | CK-8 — `Retry-After` — RULED: (a) |
| `ck-9` | [rulings_2026_09_06_connector_open_items_728.md](rulings_2026_09_06_connector_open_items_728.md) | CK-9 — pagination's vocabulary — RULED: (a) |
| `co-1` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-1 (#974, ruled 1a) — store multicodec read-compat |
| `co-10` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-10 (#969 edges, ruled 3a) — all three mint hardenings |
| `co-11` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-11 (#990, ruled 1a) — $eq's attribute atomization IS the ruled compare |
| `co-12` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-12 (#991, ruled full-fidelity) — canonical serialization is BIJECTIVE; |
| `co-13` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-13 (#1003, delegated disposition, 2026-08-26) — check_capabilities.cx RETIRED |
| `co-14` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-14 (aggregates numeric policy, owner "2a", 2026-08-26) — AGGREGATES ADOPT THE OPERATORS' DISCIPLINE |
| `co-15` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-15 (§3.3 pipeline per-stage keys, owner "1a", 2026-08-26) — NARROWING RATIFIED + PER-STAGE ENV IS REAL, NOW |
| `co-16` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-16 (run dispositions + spawn encoding + process spec pass, owner "1b 2a 3b", 2026-08-26) |
| `co-17` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-17 (exact division context + §6.5 operand sentence, owner "1a 2a", 2026-08-26) |
| `co-17` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-17 execution note |
| `co-17` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-17 execution note (band) — the narrowing helper saturated |
| `co-18` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-18 (#1042/#1048 dispositions, owner "1a 1a", 2026-08-26) |
| `co-18` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-18 execution note — the authorized sentence overclaimed; corrected to |
| `co-19` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-19 (release-eve letters, owner "1a 2a 3a 4a", 2026-08-27) |
| `co-2` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-2 (#975, ruled 2a) — refusals refuse at the EFFECT boundary |
| `co-2` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | AMENDMENT 1 (2026-08-25) — CO-2 scope resolutions from implementation |
| `co-2` | [rulings_2026_09_10_run_surface_err_at_rest_1099.md](rulings_2026_09_10_run_surface_err_at_rest_1099.md) | Why this is not CO-2's question |
| `co-20` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-20 (owner "a" + "that's all we need for nvim as well", 2026-08-27, |
| `co-3` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-3 (#978, ruled 3a) — $format:pretty becomes round-trip faithful |
| `co-4` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-4 (#979, ruled 4a) — release-ness derives from HEAD==tag |
| `co-4` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | AMENDMENT 2 (2026-08-26) — CO-4 extension recorded from #984 |
| `co-5` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-5 (#969, ruled 5a) — clean-state bootstrap = offline identity mint |
| `co-6` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-6 (#968 riders, ruled 6a) — retired verbs name their retirement; CSRP-era store docs get their own issue |
| `co-7` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-7 (#963, ruled (a)) — EXECUTED |
| `co-8` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-8 (AMENDMENT 1 item 4, ruled 1a) — journal and fabric stay UNGUARDED |
| `co-8` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-8 execution note — the exemption was defeated by its own plumbing |
| `co-9` | [rulings_2026_08_25_0170_closeout.md](rulings_2026_08_25_0170_closeout.md) | CO-9 (#982, ruled 2a) — hosted bindings are DEPLOYMENT-DOCUMENT DATA |
| `comp-1` | [rulings_2026_09_14_owner_letters_1451b_m2_patterns.md](rulings_2026_09_14_owner_letters_1451b_m2_patterns.md) | Owner letters 2026-09-14 ~19:20Z — "1c 2a 3a" (RULED: 1451-b, INT-3 addendum 2, COMP-1 addendum) |
| `comp-1` | [rulings_2026_09_14_platform_composition_comp1.md](rulings_2026_09_14_platform_composition_comp1.md) | Owner letter 2026-09-14 ~17:05Z — the platform's composition is stated once, checked, and read by the agents that build on it (RULED: COMP-1) |
| `comp-2` | [rulings_2026_09_14_deployment_topology_comp2.md](rulings_2026_09_14_deployment_topology_comp2.md) | Owner letter 2026-09-14 ~19:05Z — the platform's runtimes, and every cross-runtime seam over XSP (RULED: COMP-2) |
| `cr-1` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-1 — where a codec's parse/emit core lives (#1126) (RULED: CR-1 = a) |
| `cr-1` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-1 — where a codec's parse/emit core lives (#1126) (RULED: CR-1 = a) |
| `cr-2` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-2 — one error conversion, one direction (RULED: CR-2 = a) |
| `cr-2` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-2 — one error conversion, one direction (RULED: CR-2 = a) |
| `cr-3` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-3 — capability parity becomes a property the gates check, not an |
| `cr-4` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-4 — the vacuous-pass hole (#1127) (RULED: CR-4 = a, registry-driven) |
| `cr-4` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-4 — the vacuous-pass hole (#1127) (RULED: CR-4 = a, registry-driven) |
| `cr-5` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-5 — refusal locations, the #1128 gap (RULED: CR-5 = a) |
| `cr-5` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-5 — refusal locations, the #1128 gap (RULED: CR-5 = a) |
| `cr-6` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-6 — cx_features must tell the truth per artifact (RULED: CR-6 = a) |
| `cr-6` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-6 — cx_features must tell the truth per artifact (RULED: CR-6 = a) |
| `cr-7` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-7 — the data profile's verb set (RULED: CR-7 = a, BY OWNER 2026-08-30) |
| `cr-7` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-7 — the data profile's verb set (RULED: CR-7 = a, BY OWNER 2026-08-30) |
| `cr-8` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-8 — the ABI conversion surface (#1133) (RULED: CR-8 = a, BY OWNER 2026-08-30) |
| `cr-8` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-8 — the ABI conversion surface (#1133) (RULED: CR-8 = a, BY OWNER 2026-08-30) |
| `cr-9` | [rulings_2026_08_30_codec_ring_layering.md](rulings_2026_08_30_codec_ring_layering.md) | CR-9 — the fmt cone is Ring-0; the ABI cx_fmt tells the truth |
| `crs-1` | [rulings_2026_08_20_call_result_steps.md](rulings_2026_08_20_call_result_steps.md) | CRS-1 — call-result heads gain the [135a] compact-step subset |
| `crs-1a` | [rulings_2026_08_20_call_result_steps.md](rulings_2026_08_20_call_result_steps.md) | CRS-1a rider — code.md §6.2 trued to BP-1 |
| `cut-1` | [rulings_2026_09_28_integrator_decisions_l64_l70.md](rulings_2026_09_28_integrator_decisions_l64_l70.md) | CUT-1 — the v0.18.0 cut comes after the docs and playground items, on the owner's "cut" (L68 = (a), the owner's word) |
| `cxf-1` | [rulings_2026_09_17_cx_first_1522.md](rulings_2026_09_17_cx_first_1522.md) | cx first — the decisions of the #1522 mini-campaign (owner, 2026-09-17 ~13:50Z: "highest priority"; RULED: CXF-1 … CXF-8) |
| `cxf-2` | [rulings_2026_09_17_owner_decisions_2202z.md](rulings_2026_09_17_owner_decisions_2202z.md) | 1537's branch takes the next free agent slot (prio:high); CXF-2 (c) and CXF-4 follow it; the cx-first page's order |
| `cxf-4` | [rulings_2026_09_17_owner_decisions_2202z.md](rulings_2026_09_17_owner_decisions_2202z.md) | 1537's branch takes the next free agent slot (prio:high); CXF-2 (c) and CXF-4 follow it; the cx-first page's order |
| `cxf-8` | [rulings_2026_09_17_cx_first_1522.md](rulings_2026_09_17_cx_first_1522.md) | cx first — the decisions of the #1522 mini-campaign (owner, 2026-09-17 ~13:50Z: "highest priority"; RULED: CXF-1 … CXF-8) |
| `cxf-8` | [rulings_2026_09_17_trap_batches.md](rulings_2026_09_17_trap_batches.md) | The traps become fixtures — two batch branches for the CXF-8 defects, and the one ruling they need (RULED: TRAP-1, 1527-a) |
| `cxf-8` | [rulings_2026_09_27_integrator_decisions_l60.md](rulings_2026_09_27_integrator_decisions_l60.md) | 1690's agent; reversible by the owner's word. 1509-a, CXF-8, FIX-1, #1690.** |
| `cxp-1` | [rulings_2026_08_20_cx_pragma_registry.md](rulings_2026_08_20_cx_pragma_registry.md) | Ruling CXP-1 (2026-08-20) — the [?cx] pragma key set closes (#879, owner "4a") |
| `dblane-1` | [rulings_2026_09_28_owner_decisions_l89_l90.md](rulings_2026_09_28_owner_decisions_l89_l90.md) | DBLANE-1 — DBNUL-1 merges on sqlite's proof; a real-server lane grades every db case on postgres and mysql (L89 = (a)) |
| `dbnul-1` | [rulings_2026_09_28_integrator_decisions_l64_l70.md](rulings_2026_09_28_integrator_decisions_l64_l70.md) | DBNUL-1 — a kind=db parameter may be absent, and the kit binds NULL for a cursor on page one (L64 = (a)) |
| `dbnul-1` | [rulings_2026_09_28_owner_decisions_l89_l90.md](rulings_2026_09_28_owner_decisions_l89_l90.md) | DBLANE-1 — DBNUL-1 merges on sqlite's proof; a real-server lane grades every db case on postgres and mysql (L89 = (a)) |
| `df-1` | [rulings_2026_09_05_computed_fields.md](rulings_2026_09_05_computed_fields.md) | Rulings 2026-09-05 — computed field values, and how a slug is declared (DF-1, DF-2) |
| `df-1` | [rulings_2026_09_05_computed_fields.md](rulings_2026_09_05_computed_fields.md) | DF-1 — may the grammar compute a field's value? — RULED (c): NO |
| `df-2` | [rulings_2026_09_05_computed_fields.md](rulings_2026_09_05_computed_fields.md) | Rulings 2026-09-05 — computed field values, and how a slug is declared (DF-1, DF-2) |
| `df-2` | [rulings_2026_09_05_computed_fields.md](rulings_2026_09_05_computed_fields.md) | DF-2 — how a slug is declared — RULED (a): a pattern, not a surface |
| `dg-1` | [rulings_2026_09_11_delivery_grammar_DG1.md](rulings_2026_09_11_delivery_grammar_DG1.md) | RULED: DG-1 — the delivery grammar is spec (status New) and the only vocabulary in communications |
| `dgf-1` | [rulings_2026_08_21_surface_closeout.md](rulings_2026_08_21_surface_closeout.md) | DGF-1 — the CLI accepts the diagram detail rungs it already implements (#912) |
| `dgx-1` | [rulings_2026_08_21_diagram_capabilities.md](rulings_2026_08_21_diagram_capabilities.md) | Rulings 2026-08-21 — the effect/capability graph, a new renderable kind (DGX-1) |
| `dgx-1` | [rulings_2026_08_21_diagram_capabilities.md](rulings_2026_08_21_diagram_capabilities.md) | DGX-1 — a second VIEW of a CX program: what it can actually do |
| `dgx-1a` | [rulings_2026_08_21_diagram_capabilities.md](rulings_2026_08_21_diagram_capabilities.md) | DGX-1a — the effect table is READ LIVE from the engine, never copied |
| `dgx-1b` | [rulings_2026_08_21_diagram_capabilities.md](rulings_2026_08_21_diagram_capabilities.md) | DGX-1b — the sealed `effect-rules` table, and its completeness gate |
| `dgx-1c` | [rulings_2026_08_21_diagram_capabilities.md](rulings_2026_08_21_diagram_capabilities.md) | DGX-1c — honesty is normative: five opacity classes, always rendered |
| `dgx-1c` | [rulings_2026_08_21_diagram_capabilities.md](rulings_2026_08_21_diagram_capabilities.md) | DGX-1c amended: the `caps` opacity class is REMOVED (measured) |
| `dgx-1c` | [rulings_2026_08_21_diagram_capabilities.md](rulings_2026_08_21_diagram_capabilities.md) | DGX-1c amended: a fifth capability STATUS, `x` |
| `dgx-1d` | [rulings_2026_08_21_diagram_capabilities.md](rulings_2026_08_21_diagram_capabilities.md) | DGX-1d — the corpus is AUTHORED, then frozen |
| `dgx-1e` | [rulings_2026_08_21_diagram_capabilities.md](rulings_2026_08_21_diagram_capabilities.md) | DGX-1e — the ingress: a third image mode, not a fourth primitive |
| `dgx-1f` | [rulings_2026_08_21_diagram_capabilities.md](rulings_2026_08_21_diagram_capabilities.md) | DGX-1f — what the effect graph cannot see, stated in the spec |
| `dgx-2` | [rulings_2026_08_21_diagram_capabilities.md](rulings_2026_08_21_diagram_capabilities.md) | DGX-2 — `cd-erd-full`'s DOCUMENT box is POPULATED, and loses one row |
| `dgx-2` | [rulings_2026_08_21_diagram_capabilities.md](rulings_2026_08_21_diagram_capabilities.md) | DGX-2 (the DOCUMENT box) — the movement, as adjudicated |
| `diag-1` | [rulings_2026_09_18_owner_decisions_0200z.md](rulings_2026_09_18_owner_decisions_0200z.md) | Owner decision 2026-09-18 ~02:00Z — an err value carries its position (1545-a); the diagnostics audit's fix batches are decided (DIAG-1) |
| `docs-41` | [rulings_2026_09_28_owner_decisions_l71_l79.md](rulings_2026_09_28_owner_decisions_l71_l79.md) | DOCS-41 — one prose file per repository, every fact projected from the registries (L71 = (a)) |
| `docs-42` | [rulings_2026_09_28_owner_decisions_l71_l79.md](rulings_2026_09_28_owner_decisions_l71_l79.md) | DOCS-42 — the ring SVG is rendered from the registry at build time, untracked (L72 = (a)) |
| `docs-43` | [rulings_2026_09_28_owner_decisions_l71_l79.md](rulings_2026_09_28_owner_decisions_l71_l79.md) | DOCS-43 — Python confined to the bridge pages and held by a step (L73 = (a)) |
| `docs-44` | [rulings_2026_09_28_owner_decisions_l71_l79.md](rulings_2026_09_28_owner_decisions_l71_l79.md) | DOCS-44 — the internal link step extends the site assembler's check (L74 = (a)) |
| `docs-45` | [rulings_2026_09_28_owner_decisions_l71_l79.md](rulings_2026_09_28_owner_decisions_l71_l79.md) | DOCS-45 — external links are checked by a CX script in the site workflow, not pre-merge (L75 = (a)) |
| `docs-46` | [rulings_2026_09_28_owner_decisions_l71_l79.md](rulings_2026_09_28_owner_decisions_l71_l79.md) | DOCS-46 — the LLM door is rendered and `docs/dev/` retires into the guide (L76 = (a)) |
| `docs-47` | [rulings_2026_09_28_owner_decisions_l71_l79.md](rulings_2026_09_28_owner_decisions_l71_l79.md) | DOCS-47 — every example on a touched page is a fixture citation, with a ratchet (L77 = (a)) |
| `docs-48` | [rulings_2026_09_28_owner_decisions_l71_l79.md](rulings_2026_09_28_owner_decisions_l71_l79.md) | DOCS-48 — the value map becomes the enterprise page, each item re-backed (L78 = (a)) |
| `docs-49` | [rulings_2026_09_28_owner_decisions_l71_l79.md](rulings_2026_09_28_owner_decisions_l71_l79.md) | DOCS-49 — the generators and the front pages first, the repository pages next, the voice pass last (L79 = (a)) |
| `docs-50` | [rulings_2026_09_28_owner_decisions_l85.md](rulings_2026_09_28_owner_decisions_l85.md) | DOCS-50 — the bindings page is a fourth allowed page for a host language's name, as a binding's target only (L85 = (a)) |
| `dr-1` | [rulings_2026_08_20_diagram_renderer.md](rulings_2026_08_20_diagram_renderer.md) | DR-1 … DR-11 — the design letter's eleven sub-rulings |
| `dr-10` | [rulings_2026_08_20_diagram_renderer.md](rulings_2026_08_20_diagram_renderer.md) | DR-10 consult log (spec-sufficiency probe register) |
| `dr-11` | [rulings_2026_08_20_diagram_renderer.md](rulings_2026_08_20_diagram_renderer.md) | DR-1 … DR-11 — the design letter's eleven sub-rulings |
| `dr-5` | [rulings_2026_08_20_diagram_wave3.md](rulings_2026_08_20_diagram_wave3.md) | The DR-5 gate, extended |
| `dr-8` | [rulings_2026_08_20_diagram_renderer.md](rulings_2026_08_20_diagram_renderer.md) | Mini-rulings (DR-8 adjudications — each recorded BEFORE any behavior moves) |
| `dr-8` | [rulings_2026_08_20_diagram_renderer.md](rulings_2026_08_20_diagram_renderer.md) | Mini-rulings (DR-8 adjudications) |
| `dr-8` | [rulings_2026_08_20_diagram_wave3.md](rulings_2026_08_20_diagram_wave3.md) | Mini-rulings (DR-8 adjudications — recorded BEFORE the behavior moves) |
| `dr-8` | [rulings_2026_08_20_diagram_wave3.md](rulings_2026_08_20_diagram_wave3.md) | The DR-8 instrument |
| `dr-8` | [rulings_2026_08_26_diagram_let_node_ids_1036.md](rulings_2026_08_26_diagram_let_node_ids_1036.md) | LT-5 — golden movement, adjudicated (DR-8) |
| `dr-8` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) | NT-7 — golden movement, adjudicated (DR-8) |
| `dr-8` | [rulings_2026_08_26_playground_quality_992.md](rulings_2026_08_26_playground_quality_992.md) | PQ-3 — golden movement, adjudicated (DR-8) |
| `dr-8` | [rulings_2026_09_04_diagram_def_namespace_1066.md](rulings_2026_09_04_diagram_def_namespace_1066.md) | Ruling record — #1066 code-diagram per-def id namespace (DR-8 mini-ruling, 2026-09-04) |
| `ds-11` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) | Addendum — DS-11: the studio gets a normative spec section (owner, 2026-08-20) |
| `ds-12` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) | Addendum — DS-12: design control, and the adopter→client contract (owner, 2026-08-20) |
| `ds-13` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) | Addendum — DS-13…DS-17: the finish pass (owner directives, 2026-08-20) |
| `ds-17` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) | Addendum — DS-13…DS-17: the finish pass (owner directives, 2026-08-20) |
| `ds-18` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) | Addendum — DS-18: the second owner walkthrough (2026-08-21) |
| `ds-19` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) | Addendum — DS-19: the third owner walkthrough (2026-08-21) |
| `dsc-1` | [rulings_2026_08_20_diagram_svg_capability.md](rulings_2026_08_20_diagram_svg_capability.md) | DSC-1 — both halves of #890 are FIXED pre-cut |
| `dsc-1` | [rulings_2026_08_21_supervise_profile_and_python.md](rulings_2026_08_21_supervise_profile_and_python.md) | The Python test — RULED: assert the surface DSC-1 ruled, and widen it |
| `dsc-1a` | [rulings_2026_08_20_diagram_svg_capability.md](rulings_2026_08_20_diagram_svg_capability.md) | DSC-1a — the SVG carrier belongs inside the root element |
| `dsc-1b` | [rulings_2026_08_20_diagram_svg_capability.md](rulings_2026_08_20_diagram_svg_capability.md) | DSC-1b — PNG is CLEAN; no analogous defect |
| `dsc-1c` | [rulings_2026_08_20_diagram_svg_capability.md](rulings_2026_08_20_diagram_svg_capability.md) | DSC-1c — the graphviz formats require an explicit grant |
| `edl-1` | [rulings_2026_08_21_diagram_vector_data.md](rulings_2026_08_21_diagram_vector_data.md) | EDL-1 — the examples-diagram gate (the #910 suggestion, homed) |
| `en-1` | [rulings_2026_08_31_enum_campaign.md](rulings_2026_08_31_enum_campaign.md) | EN-1 — exhaustiveness: a `[?match]` over a schema-closed set knows when its arms cover it (#1154) |
| `en-2` | [rulings_2026_08_31_enum_campaign.md](rulings_2026_08_31_enum_campaign.md) | EN-2 — closed-key maps: the schema `[keys …]` constraint, the honest EnumMap (#1155) |
| `en-2` | [rulings_2026_08_31_enum_campaign.md](rulings_2026_08_31_enum_campaign.md) | EN-2 — schema side ([keys] is ordinary schema vocabulary, data reading) |
| `en-3` | [rulings_2026_08_31_enum_campaign.md](rulings_2026_08_31_enum_campaign.md) | EN-3 — member enumeration: the blessed idiom for "give me the declared set" (#1156) |
| `en-3` | [rulings_2026_08_31_enum_campaign.md](rulings_2026_08_31_enum_campaign.md) | EN-3 — member enumeration, declared order |
| `en-4` | [rulings_2026_08_31_enum_campaign.md](rulings_2026_08_31_enum_campaign.md) | EN-4 — the one-page enum story: primer section + cxdm §2.6 rationale (#1157) |
| `en-5` | [rulings_2026_08_31_enum_campaign.md](rulings_2026_08_31_enum_campaign.md) | EN-5 — the enum refusals register (#1158) |
| `ent-1` | [rulings_2026_08_20_cx_pragma_registry.md](rulings_2026_08_20_cx_pragma_registry.md) | ENT-1 rider — attribute-position entity references (#878, corrected) |
| `fabr-1` | [rulings_2026_09_28_owner_decisions_l80_l84.md](rulings_2026_09_28_owner_decisions_l80_l84.md) | FABR-1 — the host context carries the fabric the host built on the deployment's journal (L81 = (a)) |
| `fdisp-1` | [rulings_2026_09_28_owner_decisions_l80_l84.md](rulings_2026_09_28_owner_decisions_l80_l84.md) | FDISP-1 — the host dispatches a verb through a feature→package map built at boot (L80 = (d)) |
| `fe-1` | [rulings_2026_08_30_functional_ergonomics.md](rulings_2026_08_30_functional_ergonomics.md) | FE-1 — operator-form holes are the first-class-operator mechanism |
| `fe-2` | [rulings_2026_08_30_functional_ergonomics.md](rulings_2026_08_30_functional_ergonomics.md) | FE-2 — single-arm `[?match]` honors grammar [136]; it is the destructuring bind form |
| `fe-3` | [rulings_2026_08_30_functional_ergonomics.md](rulings_2026_08_30_functional_ergonomics.md) | FE-3 — `[?for]` pattern position extends to the full pattern grammar, refuse-on-miss |
| `fe-4` | [rulings_2026_08_30_functional_ergonomics.md](rulings_2026_08_30_functional_ergonomics.md) | FE-4 — §12.2.4 parameter shapes govern `[?fn]` and `[?def]` alike |
| `fe-5` | [rulings_2026_08_30_functional_ergonomics.md](rulings_2026_08_30_functional_ergonomics.md) | FE-5 — expression call heads stay refused; bind-first is the papered posture |
| `fe-6` | [rulings_2026_08_30_functional_ergonomics.md](rulings_2026_08_30_functional_ergonomics.md) | FE-6 — computed-key map lookup (CONDITIONAL — probe first) |
| `fe-7` | [rulings_2026_08_30_functional_ergonomics.md](rulings_2026_08_30_functional_ergonomics.md) | FE-7 — one canonical result image (RULED: FE-7 = a, BY OWNER 2026-08-31; #1148) |
| `fe-7` | [rulings_2026_08_30_functional_ergonomics.md](rulings_2026_08_30_functional_ergonomics.md) | FE-7 — one canonical result image (RULED: FE-7 = a, BY OWNER 2026-08-31; #1148) |
| `fix-1` | [rulings_2026_09_18_owner_decisions_0210z.md](rulings_2026_09_18_owner_decisions_0210z.md) | Owner decision 2026-09-18 ~02:10Z — find it, fix it: a small same-area defect is fixed in the branch that finds it (RULED: FIX-1) |
| `fix-1` | [rulings_2026_09_27_integrator_decisions_l60.md](rulings_2026_09_27_integrator_decisions_l60.md) | 1690's agent; reversible by the owner's word. 1509-a, CXF-8, FIX-1, #1690.** |
| `fl-1` | [rulings_2026_08_20_columnar_lineage.md](rulings_2026_08_20_columnar_lineage.md) | FL-3 — the columnar backend joins the FL-1/FL-2 durability contract |
| `fl-1` | [rulings_2026_08_20_feed_lineage.md](rulings_2026_08_20_feed_lineage.md) | FL-1 — data-plane feed positions become durable (the revocations-plane precedent) |
| `fl-1` | [rulings_2026_08_20_s3_lineage.md](rulings_2026_08_20_s3_lineage.md) | FL-2 — bucket lineage: the s3 substrate joins the FL-1 durability contract |
| `fl-2` | [rulings_2026_08_20_columnar_lineage.md](rulings_2026_08_20_columnar_lineage.md) | FL-3 — the columnar backend joins the FL-1/FL-2 durability contract |
| `fl-2` | [rulings_2026_08_20_s3_lineage.md](rulings_2026_08_20_s3_lineage.md) | FL-2 — bucket lineage: the s3 substrate joins the FL-1 durability contract |
| `fl-3` | [rulings_2026_08_20_columnar_lineage.md](rulings_2026_08_20_columnar_lineage.md) | FL-3 — the columnar backend joins the FL-1/FL-2 durability contract |
| `fmt-1` | [rulings_2026_09_16_fmt_ratchet_fmt1.md](rulings_2026_09_16_fmt_ratchet_fmt1.md) | Integrator decision 2026-09-16 ~11:30Z — the fmt-sweep ratchet moves one way, and a decline fixed under it needs no spec sentence (RULED: FMT-1) |
| `fmt-2` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) | Integrator decisions, 2026-09-17 — the Ring 0 rulings owed (1363-b, 1387-a, FMT-2, GRADER-1, 1150-a, 1250-b) |
| `fw-1` | [rulings_2026_09_24_flow_waves_v018_fw1.md](rulings_2026_09_24_flow_waves_v018_fw1.md) | RULED: FW-1, FW-2 — every named landing of `flow.md` lands in v0.18, end-user automation authoring (#1498) with it, and the v0.18.0 tag waits for them while the repo split lands (owner, 2026-09-24, in session on dev2) |
| `fw-2` | [rulings_2026_09_24_flow_waves_v018_fw1.md](rulings_2026_09_24_flow_waves_v018_fw1.md) | RULED: FW-1, FW-2 — every named landing of `flow.md` lands in v0.18, end-user automation authoring (#1498) with it, and the v0.18.0 tag waits for them while the repo split lands (owner, 2026-09-24, in session on dev2) |
| `ga-1` | [rulings_2026_08_20_guest_attach.md](rulings_2026_08_20_guest_attach.md) | Ruling GA-1 (2026-08-20) — attach-guest: the anonymous-floor transport (#857, owner "857a") |
| `gate-1` | [rulings_2026_09_27_owner_decisions_l58.md](rulings_2026_09_27_owner_decisions_l58.md) | Owner decisions 2026-09-27 (evening) — Letter 58: a feature's gate is the feature's (GATE-1), the boot report names each seeded basis (CAPADR-1) |
| `gate-1` | [rulings_2026_09_27_owner_decisions_l58.md](rulings_2026_09_27_owner_decisions_l58.md) | GATE-1 — the `[requires cap:…]` gate stays on `apply`, one per feature (L58.2 = (a)) |
| `ge-0` | [rulings_2026_09_05_grammar_expression_env.md](rulings_2026_09_05_grammar_expression_env.md) | Rulings 2026-09-05 — the grammar-expression environment (GE-0..GE-3) |
| `ge-0` | [rulings_2026_09_05_grammar_expression_env.md](rulings_2026_09_05_grammar_expression_env.md) | GE-0 — the caller-dependence is a DEFECT — RULED (a) |
| `ge-1` | [rulings_2026_09_05_grammar_expression_env.md](rulings_2026_09_05_grammar_expression_env.md) | GE-1 — which modules a grammar expression may read — RULED (a) |
| `ge-2` | [rulings_2026_09_05_grammar_expression_env.md](rulings_2026_09_05_grammar_expression_env.md) | GE-2 — how those modules are reached — RULED (a) |
| `ge-3` | [rulings_2026_09_05_grammar_expression_env.md](rulings_2026_09_05_grammar_expression_env.md) | Rulings 2026-09-05 — the grammar-expression environment (GE-0..GE-3) |
| `ge-3` | [rulings_2026_09_05_grammar_expression_env.md](rulings_2026_09_05_grammar_expression_env.md) | GE-3 — scope — RULED (a) |
| `gen-1` | [rulings_2026_08_20_fixture_generator_cx.md](rulings_2026_08_20_fixture_generator_cx.md) | GEN-1 — option 1: rewrite in CX; the Python generator is DELETED in the same commit |
| `gen-1a` | [rulings_2026_08_20_fixture_generator_cx.md](rulings_2026_08_20_fixture_generator_cx.md) | GEN-1a — the Python generator was already STALE; the port RECOVERS the 14 orphaned cases |
| `gen-1b` | [rulings_2026_08_20_fixture_generator_cx.md](rulings_2026_08_20_fixture_generator_cx.md) | GEN-1b — the port must RE-CREATE the Python generator's fail-loud behavior |
| `gen-1c` | [rulings_2026_08_20_fixture_generator_cx.md](rulings_2026_08_20_fixture_generator_cx.md) | GEN-1c — the acceptance, measured |
| `grader-1` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) | Integrator decisions, 2026-09-17 — the Ring 0 rulings owed (1363-b, 1387-a, FMT-2, GRADER-1, 1150-a, 1250-b) |
| `hc-1` | [rulings_2026_09_04_host_context_1210.md](rulings_2026_09_04_host_context_1210.md) | HC-1 — the shape of "a journal beside the store" — RECOMMENDED: (a) |
| `hc-1` | [rulings_2026_09_05_xap_queue.md](rulings_2026_09_05_xap_queue.md) | 1210 HC-1), `xap.md` §3.1.1, `std-lib/journal.md`. |
| `host-1` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | Owner decisions 2026-09-26 — the four designs of Letters 26–29: the connector kit (KIT-1…KIT-6), cross-company (XCO-1…XCO-5), the minimal keystore (SEC-1), the host's four choices (HOST-1…HOST-4) |
| `host-1` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | HOST-1 — a projected command def's parameters are the intent list verbatim |
| `host-2` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | HOST-2 — one code for the host's internal boot faults |
| `host-3` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | HOST-3 — an act on an auth-enabled host is the session's |
| `host-4` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | Owner decisions 2026-09-26 — the four designs of Letters 26–29: the connector kit (KIT-1…KIT-6), cross-company (XCO-1…XCO-5), the minimal keystore (SEC-1), the host's four choices (HOST-1…HOST-4) |
| `host-4` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | HOST-4 — both faces decide a feature verb the same way |
| `host-4` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | Owner decisions 2026-09-27 — Letters 46–50 and the org profile: KIT-4's shape (KIT4-1…3), the #1498 spec gaps (AA-7…9), HOST-4's seed made real (SEED-1), the host act's basis (HOSTB-1), the call spread's readings (SPREAD-2), the org-profile push (ORG-1) |
| `host-4` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | SEED-1 — HOST-4's seed made real (L48 = (a)) |
| `hostac-1` | [rulings_2026_09_27_integrator_decisions_l61.md](rulings_2026_09_27_integrator_decisions_l61.md) | Integrator decision 2026-09-27 (evening), under the owner's delegation — Letter 61: the host refuses a claimed authority and stamps what it derives (HOSTAC-1) |
| `hostac-1` | [rulings_2026_09_27_integrator_decisions_l61.md](rulings_2026_09_27_integrator_decisions_l61.md) | HOSTAC-1 — strict handling of a session act's claims (L61 = (a)) |
| `hostb-1` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | Owner decisions 2026-09-27 — Letters 46–50 and the org profile: KIT-4's shape (KIT4-1…3), the #1498 spec gaps (AA-7…9), HOST-4's seed made real (SEED-1), the host act's basis (HOSTB-1), the call spread's readings (SPREAD-2), the org-profile push (ORG-1) |
| `hostb-1` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | HOSTB-1 — a session principal's act runs under a basis the host derives (L49 = (a)) |
| `hyg-1` | [rulings_2026_08_20_hygiene_695.md](rulings_2026_08_20_hygiene_695.md) | Ruling HYG-1 (2026-08-20) — #695 stale-inventory reconciliation (pre-cut hygiene sweep) |
| `int-1` | [rulings_2026_09_12_integrator_decisions.md](rulings_2026_09_12_integrator_decisions.md) | INT-1 — why |
| `int-1` | [rulings_2026_09_12_integrator_decisions.md](rulings_2026_09_12_integrator_decisions.md) | INT-1 — the §6 reading |
| `int-13` | [rulings_2026_09_15_int13_downstream_requests.md](rulings_2026_09_15_int13_downstream_requests.md) | Integrator decisions, 2026-09-15 — INT-13 |
| `int-14` | [rulings_2026_09_15_sd1_placement.md](rulings_2026_09_15_sd1_placement.md) | Integrator placement 2026-09-15 — where the schema-as-data feature kind lives (RULED: INT-14) |
| `int-15` | [rulings_2026_09_15_integrator_decisions_int15.md](rulings_2026_09_15_integrator_decisions_int15.md) | Integrator decisions, 2026-09-15 — INT-15 |
| `int-16` | [rulings_2026_09_15_bug_tail_int16.md](rulings_2026_09_15_bug_tail_int16.md) | Owner decision 2026-09-15 ~12:20Z — the v0.18 bug tail: 17 open bugs pulled in, 8 stay out (RULED: INT-16) |
| `int-17` | [rulings_2026_09_15_default_in_campaign_int17.md](rulings_2026_09_15_default_in_campaign_int17.md) | Owner decision 2026-09-15 ~12:55Z — every open issue is IN v0.18 unless the owner rules it out (RULED: INT-17) |
| `int-17` | [rulings_2026_09_15_default_in_campaign_int17.md](rulings_2026_09_15_default_in_campaign_int17.md) | Order (integrator, under INT-17) |
| `int-18` | [rulings_2026_09_15_file_surface_placement_int18.md](rulings_2026_09_15_file_surface_placement_int18.md) | Integrator decision 2026-09-15 — the file-surface contract is its own normative page (RULED: INT-18) |
| `int-19` | [rulings_2026_09_15_websocket_stream_placement_int19.md](rulings_2026_09_15_websocket_stream_placement_int19.md) | Integrator decision 2026-09-15 — where the WebSocket frame codec, the upgrade and `kind=stream` live (RULED: INT-19) |
| `int-20` | [rulings_2026_09_15_owner_decisions_1830z.md](rulings_2026_09_15_owner_decisions_1830z.md) | Owner decisions 2026-09-15 ~18:30Z — "1a 2a 3a 4a" (RULED: INT-20, 1503-b, 1502-b, 1457-a) |
| `int-3` | [rulings_2026_09_14_owner_letters_1451b_m2_patterns.md](rulings_2026_09_14_owner_letters_1451b_m2_patterns.md) | Owner letters 2026-09-14 ~19:20Z — "1c 2a 3a" (RULED: 1451-b, INT-3 addendum 2, COMP-1 addendum) |
| `isw-1` | [rulings_2026_08_21_issue_sweep_893.md](rulings_2026_08_21_issue_sweep_893.md) | ISW-1 — the sweep's scope and its per-issue dispositions |
| `isw-1` | [rulings_2026_08_21_issue_sweep_893.md](rulings_2026_08_21_issue_sweep_893.md) | ISW-1.1 — #900: the fabric retention flake is a CLIENT that ignored a normative retry |
| `isw-1` | [rulings_2026_08_21_issue_sweep_893.md](rulings_2026_08_21_issue_sweep_893.md) | ISW-1.2 — #893: the mermaid bench gate asserts a WALL TIME it cannot own |
| `isw-1` | [rulings_2026_08_21_issue_sweep_893.md](rulings_2026_08_21_issue_sweep_893.md) | ISW-1.3 — #898: `[err …]` in the source contaminates the injected image |
| `isw-1` | [rulings_2026_08_21_issue_sweep_893.md](rulings_2026_08_21_issue_sweep_893.md) | ISW-1.4 — #899: the `/Name` → `//Name` source rewrite RETIRES |
| `isw-1` | [rulings_2026_08_21_issue_sweep_893.md](rulings_2026_08_21_issue_sweep_893.md) | ISW-1.5 — #894: the missing comma in an array literal |
| `kit-1` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | Owner decisions 2026-09-26 — the four designs of Letters 26–29: the connector kit (KIT-1…KIT-6), cross-company (XCO-1…XCO-5), the minimal keystore (SEC-1), the host's four choices (HOST-1…HOST-4) |
| `kit-1` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | KIT-1 — a reference connector declares one verb per kit mechanism it proves |
| `kit-2` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | KIT-2 — a tool is named by the composition-qualified verb |
| `kit-3` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | KIT-3 — the fold example runs |
| `kit-4` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | KIT-4 — a reference scenario runs under the real XAP host |
| `kit-4` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | Owner decisions 2026-09-27 — Letters 46–50 and the org profile: KIT-4's shape (KIT4-1…3), the #1498 spec gaps (AA-7…9), HOST-4's seed made real (SEED-1), the host act's basis (HOSTB-1), the call spread's readings (SPREAD-2), the org-profile push (ORG-1) |
| `kit-5` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | KIT-5 — the binding's values are live |
| `kit-6` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | Owner decisions 2026-09-26 — the four designs of Letters 26–29: the connector kit (KIT-1…KIT-6), cross-company (XCO-1…XCO-5), the minimal keystore (SEC-1), the host's four choices (HOST-1…HOST-4) |
| `kit-6` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | KIT-6 — the design pages tell the truth |
| `lim-1` | [rulings_2026_08_20_limits_second_half.md](rulings_2026_08_20_limits_second_half.md) | 876 closes: LIM-1 (spec home) + LIM-2 (this ruling) cover both halves. |
| `lim-1` | [rulings_2026_08_20_limits_spec.md](rulings_2026_08_20_limits_spec.md) | Ruling LIM-1 (2026-08-20) — limits spec home (#876, first half) |
| `lim-2` | [rulings_2026_08_20_limits_second_half.md](rulings_2026_08_20_limits_second_half.md) | Ruling LIM-2 (2026-08-20) — no blanket caps; amplification is a gated property (#876 second half, owner "2a") |
| `lim-2` | [rulings_2026_08_20_limits_second_half.md](rulings_2026_08_20_limits_second_half.md) | 876 closes: LIM-1 (spec home) + LIM-2 (this ruling) cover both halves. |
| `liter-1` | [rulings_2026_09_28_owner_decisions_l80_l84.md](rulings_2026_09_28_owner_decisions_l80_l84.md) | LITER-1 — a `[?for]` contributes one item per `[yield]` in a `(…)` or array literal, as 1509-a says (L83 = (b)) |
| `lt-1` | [rulings_2026_08_26_diagram_let_node_ids_1036.md](rulings_2026_08_26_diagram_let_node_ids_1036.md) | LT-1 — the defect |
| `lt-2` | [rulings_2026_08_26_diagram_let_node_ids_1036.md](rulings_2026_08_26_diagram_let_node_ids_1036.md) | LT-2 — the fix is a threaded counter, because the alternatives do not cover siblings |
| `lt-3` | [rulings_2026_08_26_diagram_let_node_ids_1036.md](rulings_2026_08_26_diagram_let_node_ids_1036.md) | LT-3 — the spelling is `lt1`, not a bare `lt` for the first |
| `lt-4` | [rulings_2026_08_26_diagram_let_node_ids_1036.md](rulings_2026_08_26_diagram_let_node_ids_1036.md) | LT-4 — the `full` binding bridge follows the id, and its behaviour is unchanged |
| `lt-5` | [rulings_2026_08_26_diagram_let_node_ids_1036.md](rulings_2026_08_26_diagram_let_node_ids_1036.md) | LT-5 — golden movement, adjudicated (DR-8) |
| `lt-6` | [rulings_2026_08_26_diagram_let_node_ids_1036.md](rulings_2026_08_26_diagram_let_node_ids_1036.md) | LT-6 — one conformance fixture moves with them |
| `lt-7` | [rulings_2026_08_26_diagram_let_node_ids_1036.md](rulings_2026_08_26_diagram_let_node_ids_1036.md) | LT-7 — red-proof |
| `mss-1` | [rulings_2026_08_22_map_syntax_settlement.md](rulings_2026_08_22_map_syntax_settlement.md) | MSS-1 (= letter Q1a) — map values are expression-shaped; prose is quoted |
| `mss-2` | [rulings_2026_08_22_map_syntax_settlement.md](rulings_2026_08_22_map_syntax_settlement.md) | MSS-2 (= letter Q2a) — entries separate by comma OR whitespace, both readers |
| `mss-3` | [rulings_2026_08_22_map_syntax_settlement.md](rulings_2026_08_22_map_syntax_settlement.md) | MSS-3 (= letter Q3, all seven confirmed) — refuse, never invent |
| `mss-4` | [rulings_2026_08_22_map_syntax_settlement.md](rulings_2026_08_22_map_syntax_settlement.md) | MSS-4 (= letter Q4a + Q4b-ii) — the declaration-only entry |
| `mss-5` | [rulings_2026_08_22_map_syntax_settlement.md](rulings_2026_08_22_map_syntax_settlement.md) | MSS-5 (= letter Q5a, the revised recommendation) — xap's `ref` is spelled honestly |
| `mss-6` | [rulings_2026_08_22_map_syntax_settlement.md](rulings_2026_08_22_map_syntax_settlement.md) | MSS-6 (= letter Q6a) — the fences |
| `mss-7` | [rulings_2026_08_22_map_syntax_settlement.md](rulings_2026_08_22_map_syntax_settlement.md) | MSS-7 — the prefix family completes: `::T VALUE` types the value (RULED "1a", 2026-08-22, same day) |
| `names-1` | [rulings_2026_09_28_integrator_decisions_l64_l70.md](rulings_2026_09_28_integrator_decisions_l64_l70.md) | NAMES-1 — the names #1498 wave 2 chose get fixture-backed sentences (L66 = (a)) |
| `nt-1` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) | NT-1 — the defect, and why `cd-label` was not the place to fix it |
| `nt-10` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) | NT-10 — the visual pass is part of the deliverable |
| `nt-2` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) | NT-2 — the form is a flowchart HTML label; #992's measurement is not re-litigated |
| `nt-3` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) | NT-3 — the nesting model |
| `nt-4` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) | NT-4 — what is deliberately NOT converted |
| `nt-5` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) | NT-5 — the rung's cuts, and the caps |
| `nt-6` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) | NT-6 — structure is ASKED FOR, never parsed |
| `nt-7` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) | NT-7 — golden movement, adjudicated (DR-8) |
| `nt-8` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) | NT-8 — the validity gate is the floor, and it grows to cover the new shapes |
| `nt-9` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) | NT-9 — open questions, recorded not decided |
| `odb-1` | [rulings_2026_09_27_owner_decisions_l41_l44.md](rulings_2026_09_27_owner_decisions_l41_l44.md) | Owner decisions 2026-09-27 — Letters 41–45: the call spread (SPREAD-1), the orders-db partial (ODB-1), R-1492 as graded (BEX-1), the bus audit subject (BUS-1), no new agents (PACE-2) |
| `odb-1` | [rulings_2026_09_27_owner_decisions_l41_l44.md](rulings_2026_09_27_owner_decisions_l41_l44.md) | ODB-1 — the graded orders-db partial merges now; #1467 finishes after L41's fix and #1434's code (Letter 42 = (a)) |
| `ol-14` | [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) | Addendum, ~05:20Z — OL-14 and OL-15 (owner: "recommendations accepted for the library and repo plan"; "we can't keep making these big organization mistakes that cause refactoring and restructuring. its been very costly.") |
| `ol-15` | [rulings_2026_09_12_audit_sink_1422.md](rulings_2026_09_12_audit_sink_1422.md) | 1. Placement, stated before any spec or code (OL-15) |
| `ol-15` | [rulings_2026_09_12_net_tls_accept_wrap_1421.md](rulings_2026_09_12_net_tls_accept_wrap_1421.md) | §4. Placement (OL-15) |
| `ol-15` | [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) | Addendum, ~05:20Z — OL-14 and OL-15 (owner: "recommendations accepted for the library and repo plan"; "we can't keep making these big organization mistakes that cause refactoring and restructuring. its been very costly.") |
| `ol-15` | [rulings_2026_09_14_connector_transports_1430c.md](rulings_2026_09_14_connector_transports_1430c.md) | Placement, decided here before spec or code (OL-15) |
| `ol-15` | [rulings_2026_09_15_websocket_stream_placement_int19.md](rulings_2026_09_15_websocket_stream_placement_int19.md) | Placement, decided here before spec or code (OL-15) |
| `opxap-1` | [rulings_2026_09_28_integrator_decisions_l64_l70.md](rulings_2026_09_28_integrator_decisions_l64_l70.md) | OPXAP-1 — order-pipeline's scenario moves under the XAP host (L69 = (b)) |
| `ord-1` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) | Sequencing (ORD-1) |
| `ord-2` | [rulings_2026_09_17_bug_batches_ord2.md](rulings_2026_09_17_bug_batches_ord2.md) | Owner decision 2026-09-17 ~23:34Z — the bug tail is worked in BATCHES of same-area bugs, tooling first with the nested `make test` at its head (RULED: ORD-2) |
| `ord-2` | [rulings_2026_09_18_owner_decisions_0155z.md](rulings_2026_09_18_owner_decisions_0155z.md) | Sequencing (ORD-2 amended) |
| `ord-2` | [rulings_2026_09_18_owner_decisions_0200z.md](rulings_2026_09_18_owner_decisions_0200z.md) | Sequencing (ORD-2 amended again) |
| `org-1` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | Owner decisions 2026-09-27 — Letters 46–50 and the org profile: KIT-4's shape (KIT4-1…3), the #1498 spec gaps (AA-7…9), HOST-4's seed made real (SEED-1), the host act's basis (HOSTB-1), the call spread's readings (SPREAD-2), the org-profile push (ORG-1) |
| `org-1` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | ORG-1 — the org-profile README is pushed (`go .github` = (a)) |
| `pace-1` | [rulings_2026_09_26_owner_decisions_l35_l39.md](rulings_2026_09_26_owner_decisions_l35_l39.md) | Owner decisions 2026-09-26 (evening) — Letters 35, 37, 38 and 39: the site token (SITE-1), the pace past the weekly meter (PACE-1), shared-slot steps beside a selected run (RUN-5), #1498 stays in v0.18 (SD-2) |
| `pace-1` | [rulings_2026_09_26_owner_decisions_l35_l39.md](rulings_2026_09_26_owner_decisions_l35_l39.md) | PACE-1 — the post-split epic crosses the weekly meter on extra usage (Letter 37 = (a), 23:1xZ) |
| `pace-2` | [rulings_2026_09_27_owner_decisions_l41_l44.md](rulings_2026_09_27_owner_decisions_l41_l44.md) | Owner decisions 2026-09-27 — Letters 41–45: the call spread (SPREAD-1), the orders-db partial (ODB-1), R-1492 as graded (BEX-1), the bus audit subject (BUS-1), no new agents (PACE-2) |
| `pace-2` | [rulings_2026_09_27_owner_decisions_l41_l44.md](rulings_2026_09_27_owner_decisions_l41_l44.md) | PACE-2 — no new agent from this session; the switch to the other account when reasonable (owner, 01:1xZ, on Letter 45) |
| `pace-3` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | PACE-3 — this session runs the kit overnight (owner, 2026-09-27 ~04:2xZ: "a") |
| `pb-1` | [rulings_2026_09_04_flow_w1_runner_seam_1265.md](rulings_2026_09_04_flow_w1_runner_seam_1265.md) | PB-1 — how the runner performs a step's act — RULED (a) |
| `pb-2` | [rulings_2026_09_04_flow_w1_runner_seam_1265.md](rulings_2026_09_04_flow_w1_runner_seam_1265.md) | PB-2 — the run id preimage — RULED (a) |
| `pb-3` | [rulings_2026_09_04_flow_w1_runner_seam_1265.md](rulings_2026_09_04_flow_w1_runner_seam_1265.md) | PB-3 — the home stream default — RULED (a) |
| `pb-4` | [rulings_2026_09_04_flow_w1_runner_seam_1265.md](rulings_2026_09_04_flow_w1_runner_seam_1265.md) | PB-4 — a deadline expiring with no ladder — RULED (a) |
| `pb-5` | [rulings_2026_09_04_flow_w1_runner_seam_1265.md](rulings_2026_09_04_flow_w1_runner_seam_1265.md) | PB-5 — the `[timer-fired …]` event shape — RULED (a) |
| `pb-6` | [rulings_2026_09_04_flow_w1_runner_seam_1265.md](rulings_2026_09_04_flow_w1_runner_seam_1265.md) | PB-6 — one `advance`, one effect, and its outcome — RULED (a) |
| `pb-7` | [rulings_2026_09_04_flow_w1_runner_seam_1265.md](rulings_2026_09_04_flow_w1_runner_seam_1265.md) | PB-7 — `resumed=` on the record — RULED (a) |
| `pb-8` | [rulings_2026_09_04_flow_w1_runner_seam_1265.md](rulings_2026_09_04_flow_w1_runner_seam_1265.md) | PB-8 — the conflict value's locator — RULED (a) |
| `pc-1` | [rulings_2026_09_04_flow_w1_map_scale_1265.md](rulings_2026_09_04_flow_w1_map_scale_1265.md) | PC-1 — "O(1) transitions per map" — RULED (a) |
| `pc-2` | [rulings_2026_09_04_flow_w1_map_scale_1265.md](rulings_2026_09_04_flow_w1_map_scale_1265.md) | PC-2 — the 1 000-item map fixture and the 10⁵ / 10⁶ bench rows — RULED (a) |
| `pc-3` | [rulings_2026_09_04_flow_w1_map_scale_1265.md](rulings_2026_09_04_flow_w1_map_scale_1265.md) | PC-3 — `max-parallel=` in the W1 profile — RULED (a) |
| `pd-1` | [rulings_2026_09_04_flow_w1_cli_1265.md](rulings_2026_09_04_flow_w1_cli_1265.md) | PD-1 — the `cx flow` subcommands and how acts are found — RULED (a) |
| `pe-1` | [rulings_2026_09_06_flow_snapshot_interval_1265.md](rulings_2026_09_06_flow_snapshot_interval_1265.md) | Ruling 2026-09-06 — #1265 W1-E, the snapshot-anchor interval (PE-1) |
| `pe-1` | [rulings_2026_09_06_flow_snapshot_interval_1265.md](rulings_2026_09_06_flow_snapshot_interval_1265.md) | PE-1 — the default interval — RULED: (a) |
| `pgc-1` | [rulings_2026_08_22_gate_hygiene.md](rulings_2026_08_22_gate_hygiene.md) | PGC-1 — the gate checks the payload a profile PROMISES (#915) |
| `pgl-1` | [rulings_2026_08_22_profile_gate_lane.md](rulings_2026_08_22_profile_gate_lane.md) | PGL-1 — one implementation, reachable from a pre-cut lane |
| `pgl-1a` | [rulings_2026_08_22_profile_gate_lane.md](rulings_2026_08_22_profile_gate_lane.md) | PGL-1a — AMENDMENT: the gate was BROKEN, and the lane proved it on its first run |
| `pivot-1` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | PIVOT-1 — a read-only step before the pivot needs no compensator (Letter 51 = (a), owner ~06:1xZ) |
| `pivot-2` | [rulings_2026_09_27_integrator_decisions_l57.md](rulings_2026_09_27_integrator_decisions_l57.md) | Integrator decision 2026-09-27 (afternoon), under the owner's delegation — Letter 57: a verb's `effect=` reaches both faces from the feature (PIVOT-2) |
| `pivot-2` | [rulings_2026_09_27_integrator_decisions_l57.md](rulings_2026_09_27_integrator_decisions_l57.md) | PIVOT-2 — both faces copy a verb's `effect=` from the feature it came from (L57 = (b)) |
| `pivot-2` | [rulings_2026_09_28_integrator_decisions_l64_l70.md](rulings_2026_09_28_integrator_decisions_l64_l70.md) | 1690, #1498, #1434, PIVOT-2, SYNC-3, SYNC-6, KIT4-1, KIT4-2, RS-38, D83a, K10.** |
| `pq-1` | [rulings_2026_08_26_playground_quality_992.md](rulings_2026_08_26_playground_quality_992.md) | PQ-1 — the ERD row comment carries a VALUE, and the `@` sigil is retired |
| `pq-2` | [rulings_2026_08_26_playground_quality_992.md](rulings_2026_08_26_playground_quality_992.md) | PQ-2 — every ERD column token is forced to a valid ATTRIBUTE_WORD |
| `pq-3` | [rulings_2026_08_26_playground_quality_992.md](rulings_2026_08_26_playground_quality_992.md) | PQ-3 — golden movement, adjudicated (DR-8) |
| `pq-4` | [rulings_2026_08_26_playground_quality_992.md](rulings_2026_08_26_playground_quality_992.md) | PQ-4 — the instance view is an HTML table, not erDiagram rows |
| `pq-5` | [rulings_2026_08_26_playground_quality_992.md](rulings_2026_08_26_playground_quality_992.md) | PQ-5 — the control model: pane header = what applies to everything |
| `pq-5` | [rulings_2026_08_26_playground_tree_detail_1001.md](rulings_2026_08_26_playground_tree_detail_1001.md) | 992's PQ-5 placed `Detail` inside the graph panel and said why: |
| `pq-6` | [rulings_2026_08_26_playground_quality_992.md](rulings_2026_08_26_playground_quality_992.md) | PQ-6 — a graph that cannot render says one line, not a wall |
| `pq-7` | [rulings_2026_08_26_playground_quality_992.md](rulings_2026_08_26_playground_quality_992.md) | PQ-7 — the engine staleness gate |
| `pq-8` | [rulings_2026_08_26_playground_quality_992.md](rulings_2026_08_26_playground_quality_992.md) | PQ-8 — diagram validity is a gate, driven from the shipped files |
| `pq-9` | [rulings_2026_08_26_playground_quality_992.md](rulings_2026_08_26_playground_quality_992.md) | PQ-9 — an operator-headed element's NAME is its head (owner feedback) |
| `ps-1` | [rulings_2026_08_20_postfix_uniformity.md](rulings_2026_08_20_postfix_uniformity.md) | PS-1 — every program-position bracketed form's closing bracket takes the [135a] compact-step postfix |
| `pubfix-1` | [rulings_2026_09_27_owner_decisions_l56.md](rulings_2026_09_27_owner_decisions_l56.md) | Owner decision 2026-09-27 (afternoon) — Letter 56: the public-history replacements file must survive its own pass (PUBFIX-1) |
| `pubfix-1` | [rulings_2026_09_27_owner_decisions_l56.md](rulings_2026_09_27_owner_decisions_l56.md) | PUBFIX-1 — fix first, then REFRESH-5 (L56 = (a)) |
| `pw-1` | [rulings_2026_09_04_flow_w3_performers_1265.md](rulings_2026_09_04_flow_w3_performers_1265.md) | PW-1 — how a composed-grammar verb declares its compensator — RULED (a) |
| `pw-2` | [rulings_2026_09_04_flow_w3_performers_1265.md](rulings_2026_09_04_flow_w3_performers_1265.md) | PW-2 — the inbox before `fleet` — RULED (a) |
| `pw-3` | [rulings_2026_09_04_flow_w3_performers_1265.md](rulings_2026_09_04_flow_w3_performers_1265.md) | PW-3 — how an `[approval]` correlates to a run and step — RULED (a) |
| `pye-1` | [rulings_2026_08_22_bug_campaign.md](rulings_2026_08_22_bug_campaign.md) | 925 map:/array: IN FULL per PYE-1 (26 functions, new normative spec, |
| `pye-1` | [rulings_2026_08_22_computed_path_steps.md](rulings_2026_08_22_computed_path_steps.md) | PYE-1a (1a) — the grammar edit for a computed member step is INSIDE PYE-1's authorization |
| `pye-1` | [rulings_2026_08_22_python_eradication.md](rulings_2026_08_22_python_eradication.md) | PYE-1 (item 1b) — implement `map:` and `array:` IN FULL |
| `pye-1a` | [rulings_2026_08_22_computed_path_steps.md](rulings_2026_08_22_computed_path_steps.md) | Ruling 2026-08-22 — computed path steps (PYE-1a, PYE-1b) |
| `pye-1a` | [rulings_2026_08_22_computed_path_steps.md](rulings_2026_08_22_computed_path_steps.md) | PYE-1a (1a) — the grammar edit for a computed member step is INSIDE PYE-1's authorization |
| `pye-1b` | [rulings_2026_08_22_computed_path_steps.md](rulings_2026_08_22_computed_path_steps.md) | Ruling 2026-08-22 — computed path steps (PYE-1a, PYE-1b) |
| `pye-1b` | [rulings_2026_08_22_computed_path_steps.md](rulings_2026_08_22_computed_path_steps.md) | PYE-1b (2b) — ALL FOUR compact steps take a computed name, not just `.` |
| `pye-2` | [rulings_2026_08_22_python_eradication.md](rulings_2026_08_22_python_eradication.md) | PYE-2 (item 2c) — program arguments are positional; cx's flags bind before the FILE |
| `pye-3` | [rulings_2026_08_22_python_eradication.md](rulings_2026_08_22_python_eradication.md) | PYE-3 (item 3a) — reading program arguments requires NO capability grant |
| `pye-4` | [rulings_2026_08_22_python_eradication.md](rulings_2026_08_22_python_eradication.md) | PYE-4 (item 4c) — the regex class rewrite becomes correct, not narrowed |
| `pye-5` | [rulings_2026_08_22_python_eradication.md](rulings_2026_08_22_python_eradication.md) | PYE-5 (item 5a) — the exemption is all of `lang/python/**` |
| `pye-6` | [rulings_2026_08_22_python_eradication.md](rulings_2026_08_22_python_eradication.md) | PYE-6 (item 6a) — an all-SKIP gate run is a failure |
| `rp-0` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | RP-0 — the streaming direction is ALREADY RULED; it stands (TF-5 = a) |
| `rp-1` | [rulings_2026_08_28_rowset_perf_1080_1083.md](rulings_2026_08_28_rowset_perf_1080_1083.md) | RP-1 — re compile reuse (#1080) (RULED: RP-1 = a) |
| `rp-1` | [rulings_2026_08_28_rowset_perf_1080_1083.md](rulings_2026_08_28_rowset_perf_1080_1083.md) | RP-1 — re compile reuse (#1080) (RULED: RP-1 = a) |
| `rp-1` | [rulings_2026_08_28_rowset_perf_1080_1083.md](rulings_2026_08_28_rowset_perf_1080_1083.md) | RP-1 mechanism note (execution) |
| `rp-1` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | Rulings 2026-09-02 — #1119 CXDM in-memory representation (RP-1..RP-6) |
| `rp-1` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | RP-1 — the value carrier: a compact inline tagged Node (RULED: RP-1 = a) |
| `rp-1` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | RP-1 — the value carrier: a compact inline tagged Node (RULED: RP-1 = a) |
| `rp-2` | [rulings_2026_08_28_rowset_perf_1080_1083.md](rulings_2026_08_28_rowset_perf_1080_1083.md) | RP-2 — order-by sort (#1081) (RULED: RP-2 = a) |
| `rp-2` | [rulings_2026_08_28_rowset_perf_1080_1083.md](rulings_2026_08_28_rowset_perf_1080_1083.md) | RP-2 — order-by sort (#1081) (RULED: RP-2 = a) |
| `rp-2` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | RP-2 — migration mechanics: API-fication first, then ONE flip (RULED: RP-2 = a) |
| `rp-2` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | RP-2 — migration mechanics: API-fication first, then ONE flip (RULED: RP-2 = a) |
| `rp-3` | [rulings_2026_08_28_rowset_perf_1080_1083.md](rulings_2026_08_28_rowset_perf_1080_1083.md) | RP-3 — group-by partition (#1082) (RULED: RP-3 = a) |
| `rp-3` | [rulings_2026_08_28_rowset_perf_1080_1083.md](rulings_2026_08_28_rowset_perf_1080_1083.md) | RP-3 — group-by partition (#1082) (RULED: RP-3 = a) |
| `rp-3` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | RP-3 — the map / array / sequence carriers: one representation, the element envelopes retire (RULED: RP-3 = a) |
| `rp-3` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | RP-3 — the map / array / sequence carriers: one representation, the element envelopes retire (RULED: RP-3 = a) |
| `rp-3` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | RP-3 execution amendment — two behaviour changes RATIFIED, one deviation ratified (owner, 2026-09-02) |
| `rp-4` | [rulings_2026_08_28_rowset_perf_1080_1083.md](rulings_2026_08_28_rowset_perf_1080_1083.md) | RP-4 — $group phantom member (#1083) (RULED: RP-4 = a) |
| `rp-4` | [rulings_2026_08_28_rowset_perf_1080_1083.md](rulings_2026_08_28_rowset_perf_1080_1083.md) | RP-4 — $group phantom member (#1083) (RULED: RP-4 = a) |
| `rp-4` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | RP-4 — names interned per parse; kinds inline on attributes; exact-size arrays (RULED: RP-4 = a) |
| `rp-4` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | RP-4 — names interned per parse; kinds inline on attributes; exact-size arrays (RULED: RP-4 = a) |
| `rp-5` | [rulings_2026_08_28_rowset_perf_1080_1083.md](rulings_2026_08_28_rowset_perf_1080_1083.md) | RP-5 — [?match] wide-literal dispatch (#1094, owner-added mid-campaign) (RULED: RP-5 = a) |
| `rp-5` | [rulings_2026_08_28_rowset_perf_1080_1083.md](rulings_2026_08_28_rowset_perf_1080_1083.md) | RP-5 — [?match] wide-literal dispatch (#1094, owner-added mid-campaign) (RULED: RP-5 = a) |
| `rp-5` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | RP-5 — the exit bar and the guard (RULED: RP-5 = a) |
| `rp-5` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | RP-5 — the exit bar and the guard (RULED: RP-5 = a) |
| `rp-5` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | W8 — the exit measurement (RP-5), and the bar is MISSED |
| `rp-5` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | The attribution RP-5 requires |
| `rp-5` | [rulings_2026_09_05_rp5_bar_1226.md](rulings_2026_09_05_rp5_bar_1226.md) | Ruling record — #1226 / #1119 RP-5: the exit bar is RSS ÷ LIVE at parse peak, not RSS ÷ input (2026-09-05) |
| `rp-5` | [rulings_2026_09_05_rp5_bar_1226.md](rulings_2026_09_05_rp5_bar_1226.md) | RULED (a) — re-base RP-5 to **RSS ÷ live ≤ 2.5× at parse peak** |
| `rp-6` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | Rulings 2026-09-02 — #1119 CXDM in-memory representation (RP-1..RP-6) |
| `rp-6` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | RP-6 — shape-shared record maps and columnar/lazy record arrays: ruled in principle, trigger-bound (RULED: RP-6 = a) |
| `rp-6` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | RP-6 — shape-shared record maps and columnar/lazy record arrays: ruled in principle, trigger-bound (RULED: RP-6 = a) |
| `rs-1` | [rulings_2026_09_21_repo_split_1589.md](rulings_2026_09_21_repo_split_1589.md) | RS-1…RS-12 — the multi-repo split of cx-private (owner, 2026-09-21; shape approved in session) |
| `rs-12` | [rulings_2026_09_21_repo_split_1589.md](rulings_2026_09_21_repo_split_1589.md) | RS-1…RS-12 — the multi-repo split of cx-private (owner, 2026-09-21; shape approved in session) |
| `rs-13` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) | RS-13…RS-25 — the repo split's follow-up decisions (owner, 2026-09-22/23, in session on dev2) |
| `rs-13` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) | RS-13 — `authz` splits along the store-auth design line (owner: D14a) |
| `rs-14` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) | RS-14 — did/vc's impure remainder gets modules named for what leaves (owner: D15b) |
| `rs-15` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) | RS-15 — the xsp `auth-*` defs become `cx-platform/xsp-auth` (owner: D16a) |
| `rs-16` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) | RS-16 — the `cx` binary grades a corpus file (owner: D13a) |
| `rs-17` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) | RS-17 — the `-gc e` per-case growth is fixed at the root (owner: D3b) |
| `rs-18` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) | RS-18 — builtin registration splits per family, before the db extracts (owner: D20a) |
| `rs-19` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) | RS-19 — mail claims its smtp/imap pure halves, as `sasl` already is (owner: D19a) |
| `rs-20` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) | RS-20 — flow's CLI verbs stay in the front door, and the act seam gets a row (owner: D21a) |
| `rs-21` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) | RS-21 — a decision's design item may ADD spec text where the edit map is silent (owner: D22b) |
| `rs-22` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) | RS-22 — `authz-store` and `vc-revocation` stay in `cx-platform-identity` (owner: D24a) |
| `rs-23` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) | RS-23 — the decision half gets a pure `open` over an in-memory trust store (owner: D25b) |
| `rs-24` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) | RS-24 — `vcx/platform` splits by product, one V module per V product (owner: D28a) |
| `rs-25` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) | RS-13…RS-25 — the repo split's follow-up decisions (owner, 2026-09-22/23, in session on dev2) |
| `rs-25` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) | RS-25 — the mock adapter is declared by the kit's own CX, and the compile-time gate retires (owner: D30d) |
| `rs-26` | [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) | RS-26…RS-31 — five spec-sentence authorizations, the afternoon letters, documentation and CI/CD, the documentation voice and the evening letters (owner, 2026-09-23, in session on dev2) |
| `rs-27` | [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) | RS-27 — the afternoon letters of 2026-09-23 (owner: D49a, D50a, D51d, D52a, D53a) |
| `rs-27` | [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) | Not decided here (RS-27) |
| `rs-28` | [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) | RS-28 — one site, thin repositories, and cx created by the recipe (owner: D57a, D58a, D59a) |
| `rs-28` | [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) | Not decided here (RS-28, RS-29) |
| `rs-29` | [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) | RS-29 — CI/CD is cx flow, documentation included (owner: D60a) |
| `rs-29` | [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) | Not decided here (RS-28, RS-29) |
| `rs-30` | [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) | RS-30 — the documentation voice (owner, 2026-09-23 ~16:4xZ) |
| `rs-30` | [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) | Not decided here (RS-30, RS-31) |
| `rs-31` | [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) | RS-26…RS-31 — five spec-sentence authorizations, the afternoon letters, documentation and CI/CD, the documentation voice and the evening letters (owner, 2026-09-23, in session on dev2) |
| `rs-31` | [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) | RS-31 — the evening letters of 2026-09-23 (owner: D54c, D55c, D56a, D62a, D63a, D64c, D65d, D66a, D67a, D68a, D69b, D70a1, D71a, D72a, D73a, D74c, D75a, D76c, D77d, D78a) |
| `rs-31` | [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) | Not decided here (RS-30, RS-31) |
| `rs-32` | [rulings_2026_09_24_front_door_letters.md](rulings_2026_09_24_front_door_letters.md) | RS-32 — the front-door letters of 2026-09-24 (owner: D79a, D80a, D81a, D82a, D83a, D84a) |
| `rs-33` | [rulings_2026_09_24_no_ai_attribution_rs33.md](rulings_2026_09_24_no_ai_attribution_rs33.md) | RS-33 — zero AI attribution anywhere in any repository, ever (owner: D87, D88b) |
| `rs-34` | [rulings_2026_09_25_llm_front_door_k11a.md](rulings_2026_09_25_llm_front_door_k11a.md) | K11a and RS-34 — the LLM front door's home, and the order of work before the cut (owner: K11a, D89a, D90b) |
| `rs-34` | [rulings_2026_09_25_llm_front_door_k11a.md](rulings_2026_09_25_llm_front_door_k11a.md) | RS-34 — the letters of 2026-09-25 (owner: D89a, D90b) |
| `rs-35` | [rulings_2026_09_25_v_fork_rs35.md](rulings_2026_09_25_v_fork_rs35.md) | RS-35 — the V fork under the zero-attribution rule: strip the fork's own range only (owner: Letter 2 = (a), 2026-09-25) |
| `rs-36` | [rulings_2026_09_25_component_waves_rs36.md](rulings_2026_09_25_component_waves_rs36.md) | RS-36 — how a wave in a component repository lands after the split (owner, 2026-09-25, Letter 4 (a)) |
| `rs-38` | [rulings_2026_09_26_fixture_backed_sentences_rs38.md](rulings_2026_09_26_fixture_backed_sentences_rs38.md) | RS-38 — a flow-ladder wave may state, inside its ruled section, the exact semantics its fixtures grade (owner: Letter 18 = (a), 2026-09-26) |
| `rs-38` | [rulings_2026_09_28_integrator_decisions_l64_l70.md](rulings_2026_09_28_integrator_decisions_l64_l70.md) | 1690, #1498, #1434, PIVOT-2, SYNC-3, SYNC-6, KIT4-1, KIT4-2, RS-38, D83a, K10.** |
| `rt-1` | [rulings_2026_09_27_owner_decisions_l52_l54.md](rulings_2026_09_27_owner_decisions_l52_l54.md) | Owner decisions 2026-09-27 (afternoon) — Letters 52, 53 and 54: XCO's two readings (ACK-1, RT-1), a list verb through the host walks every page (WALK-1), the vendor budget is per process (BUDGET-1) |
| `rt-1` | [rulings_2026_09_27_owner_decisions_l52_l54.md](rulings_2026_09_27_owner_decisions_l52_l54.md) | RT-1 — the `[runtime …]` rows' sentence and the delegated-intent frame are written in the host rounds, fixture-backed (L52.2 = (a)) |
| `run-1` | [rulings_2026_09_16_run_selection_run1.md](rulings_2026_09_16_run_selection_run1.md) | Owner decision 2026-09-16 ~05:05Z — the post-merge run tests what changed and what reads it (RULED: RUN-1) |
| `run-2` | [rulings_2026_09_19_owner_decisions_0445z.md](rulings_2026_09_19_owner_decisions_0445z.md) | Owner decisions 2026-09-19 ~04:45Z — a failed run reports every red class (RUN-2); the daily full union runs on an idle runner (RUN-3); an escalated branch runs the computed selection pre-merge (RUN-4); the run log carries step timing and the timings file (RUN-5); the two agents and their order (AGENTS-1); the budget step stays open until it measures (1562-a) |
| `run-3` | [rulings_2026_09_19_owner_decisions_0445z.md](rulings_2026_09_19_owner_decisions_0445z.md) | Owner decisions 2026-09-19 ~04:45Z — a failed run reports every red class (RUN-2); the daily full union runs on an idle runner (RUN-3); an escalated branch runs the computed selection pre-merge (RUN-4); the run log carries step timing and the timings file (RUN-5); the two agents and their order (AGENTS-1); the budget step stays open until it measures (1562-a) |
| `run-4` | [rulings_2026_09_19_owner_decisions_0445z.md](rulings_2026_09_19_owner_decisions_0445z.md) | Owner decisions 2026-09-19 ~04:45Z — a failed run reports every red class (RUN-2); the daily full union runs on an idle runner (RUN-3); an escalated branch runs the computed selection pre-merge (RUN-4); the run log carries step timing and the timings file (RUN-5); the two agents and their order (AGENTS-1); the budget step stays open until it measures (1562-a) |
| `run-5` | [rulings_2026_09_19_owner_decisions_0445z.md](rulings_2026_09_19_owner_decisions_0445z.md) | Owner decisions 2026-09-19 ~04:45Z — a failed run reports every red class (RUN-2); the daily full union runs on an idle runner (RUN-3); an escalated branch runs the computed selection pre-merge (RUN-4); the run log carries step timing and the timings file (RUN-5); the two agents and their order (AGENTS-1); the budget step stays open until it measures (1562-a) |
| `run-5` | [rulings_2026_09_26_owner_decisions_l35_l39.md](rulings_2026_09_26_owner_decisions_l35_l39.md) | Owner decisions 2026-09-26 (evening) — Letters 35, 37, 38 and 39: the site token (SITE-1), the pace past the weekly meter (PACE-1), shared-slot steps beside a selected run (RUN-5), #1498 stays in v0.18 (SD-2) |
| `run-5` | [rulings_2026_09_26_owner_decisions_l35_l39.md](rulings_2026_09_26_owner_decisions_l35_l39.md) | RUN-5 — a shared-slot step may run beside a SELECTED loop run under load 20 (Letter 38 = (a)) |
| `sd-1` | [rulings_2026_09_15_views_group_vg3_schema_sd1.md](rulings_2026_09_15_views_group_vg3_schema_sd1.md) | Owner letters 2026-09-15 ~01:20Z — the fourth clause of `[views]`, and the schema-as-data feature kind (RULED: VG-3, SD-1) |
| `sd-2` | [rulings_2026_09_26_owner_decisions_l35_l39.md](rulings_2026_09_26_owner_decisions_l35_l39.md) | Owner decisions 2026-09-26 (evening) — Letters 35, 37, 38 and 39: the site token (SITE-1), the pace past the weekly meter (PACE-1), shared-slot steps beside a selected run (RUN-5), #1498 stays in v0.18 (SD-2) |
| `sd-2` | [rulings_2026_09_26_owner_decisions_l35_l39.md](rulings_2026_09_26_owner_decisions_l35_l39.md) | SD-2 — #1498 stays in v0.18 (Letter 39 = (b)) |
| `sea-1` | [rulings_2026_08_20_schema_evolution_automation.md](rulings_2026_08_20_schema_evolution_automation.md) | SEA-1 — the four automation gaps close; sound-refusal-first everywhere |
| `sea-1` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) | AD-2 — contract evolution gets the SEA-1 treatment (#1182) |
| `sec-1` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | Owner decisions 2026-09-26 — the four designs of Letters 26–29: the connector kit (KIT-1…KIT-6), cross-company (XCO-1…XCO-5), the minimal keystore (SEC-1), the host's four choices (HOST-1…HOST-4) |
| `sec-1` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | SEC-1 — the minimal keystore that expands without impact |
| `sec-1` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | Note 2026-09-26 — Letters 30, 31 and 32 = (a): the SEC-1 spec's three questions, and the letter's details recorded |
| `seed-1` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | Owner decisions 2026-09-27 — Letters 46–50 and the org profile: KIT-4's shape (KIT4-1…3), the #1498 spec gaps (AA-7…9), HOST-4's seed made real (SEED-1), the host act's basis (HOSTB-1), the call spread's readings (SPREAD-2), the org-profile push (ORG-1) |
| `seed-1` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | SEED-1 — HOST-4's seed made real (L48 = (a)) |
| `seq-1` | [rulings_2026_08_26_seq_classification.md](rulings_2026_08_26_seq_classification.md) | SEQ-1 — the filed mechanism is WRONG; this is not a port regression |
| `seq-2` | [rulings_2026_08_26_seq_classification.md](rulings_2026_08_26_seq_classification.md) | SEQ-2 — the hole is a real contract violation, and the CONTRACT wins |
| `seq-3` | [rulings_2026_08_26_seq_classification.md](rulings_2026_08_26_seq_classification.md) | SEQ-3 — golden movement: ZERO, and it is measured, not asserted |
| `seq-3` | [rulings_2026_08_26_seq_classification.md](rulings_2026_08_26_seq_classification.md) | SEQ-3 — a CALLED `[?def]` body reaches the sequence lane |
| `seq-4` | [rulings_2026_08_26_seq_classification.md](rulings_2026_08_26_seq_classification.md) | SEQ-4 — the corpus gains the shape that was never pinned |
| `seq-4` | [rulings_2026_09_08_seq4_pin_page_sync_1170.md](rulings_2026_09_08_seq4_pin_page_sync_1170.md) | Ruling — the two SEQ-4 pins re-sync to the page, and the cascade shape stays pinned (#1170) |
| `sf-1` | [rulings_2026_09_02_standard_features.md](rulings_2026_09_02_standard_features.md) | SF-1 — the home: a new private repo, `cx-standard-features` (#1189) |
| `sf-2` | [rulings_2026_09_02_standard_features.md](rulings_2026_09_02_standard_features.md) | SF-2 — the #866 boundary line |
| `sf-3` | [rulings_2026_09_02_standard_features.md](rulings_2026_09_02_standard_features.md) | SF-3 — where the register lives |
| `sf-4` | [rulings_2026_09_02_standard_features.md](rulings_2026_09_02_standard_features.md) | SF-4 — membership, and the three `market/` features |
| `sf-5` | [rulings_2026_09_02_standard_features.md](rulings_2026_09_02_standard_features.md) | SF-5 — how a catalog identifies the set |
| `sf-6` | [rulings_2026_09_02_standard_features.md](rulings_2026_09_02_standard_features.md) | SF-6 — the spec pointer |
| `sf-7` | [rulings_2026_09_02_standard_features.md](rulings_2026_09_02_standard_features.md) | SF-7 — `retention`'s scope: it carries a sweep that actually erases |
| `sha-1` | [rulings_2026_09_11_saml_xml_encryption_1400_1401.md](rulings_2026_09_11_saml_xml_encryption_1400_1401.md) | RULED: 1400-a, 1401-a — XML Encryption comes IN: `saml:verify` decrypts `EncryptedAssertion` / `EncryptedID` / `EncryptedAttribute` with `opts.decryption-keys`; `crypto` gains RSA key transport (OAEP, SHA-1 inside OAEP allowed; PKCS#1 v1.5 behind a loud opt-in with implicit rejection) and AES-CBC + AES-128/192-GCM; encryption is detected BEFORE the signature search |
| `since-1` | [rulings_2026_09_28_owner_decisions_l89_l90.md](rulings_2026_09_28_owner_decisions_l89_l90.md) | SINCE-1 — an absent `:since` on a baseline sync run binds NULL, and it lands today (L90 = (a), today) |
| `site-1` | [rulings_2026_09_26_owner_decisions_l35_l39.md](rulings_2026_09_26_owner_decisions_l35_l39.md) | Owner decisions 2026-09-26 (evening) — Letters 35, 37, 38 and 39: the site token (SITE-1), the pace past the weekly meter (PACE-1), shared-slot steps beside a selected run (RUN-5), #1498 stays in v0.18 (SD-2) |
| `site-1` | [rulings_2026_09_26_owner_decisions_l35_l39.md](rulings_2026_09_26_owner_decisions_l35_l39.md) | SITE-1 — the public site builds on GitHub's runner with a read-only token (Letter 35 = (a)) |
| `sk-1` | [rulings_2026_09_06_sched_missed_one_shot_1324.md](rulings_2026_09_06_sched_missed_one_shot_1324.md) | Ruling 2026-09-06 — #1324, a restored one-shot that came due while the process was down (SK-1) |
| `sk-1` | [rulings_2026_09_06_sched_missed_one_shot_1324.md](rulings_2026_09_06_sched_missed_one_shot_1324.md) | SK-1 — which side is right — RULED: (a) |
| `sk-1` | [rulings_2026_09_06_sched_missed_one_shot_1324.md](rulings_2026_09_06_sched_missed_one_shot_1324.md) | SK-2 — 2026-09-06, the OWNER REVISED SK-1 (asked "is (a) the best long term?") |
| `sk-1` | [rulings_2026_09_06_sched_missed_one_shot_1324.md](rulings_2026_09_06_sched_missed_one_shot_1324.md) | What SK-1 got wrong |
| `sk-2` | [rulings_2026_09_06_sched_missed_one_shot_1324.md](rulings_2026_09_06_sched_missed_one_shot_1324.md) | SK-2 — 2026-09-06, the OWNER REVISED SK-1 (asked "is (a) the best long term?") |
| `sk-2` | [rulings_2026_09_06_sched_missed_one_shot_1324.md](rulings_2026_09_06_sched_missed_one_shot_1324.md) | SK-2 — RULED: (a), three parts |
| `spf-1` | [rulings_2026_08_21_supervise_profile_and_python.md](rulings_2026_08_21_supervise_profile_and_python.md) | SPF-1 — a unique id is not a scheduler's to lend; a missing pack refuses at composition |
| `spf-2` | [rulings_2026_08_21_supervise_profile_and_python.md](rulings_2026_08_21_supervise_profile_and_python.md) | SPF-2 — the third release-blocking red, unreported until now |
| `spg-1` | [rulings_2026_08_22_gate_hygiene.md](rulings_2026_08_22_gate_hygiene.md) | SPG-1 — the SIGPIPE pipe class becomes a gate (#916) |
| `spr-1` | [rulings_2026_08_20_spec_tree_reshape.md](rulings_2026_08_20_spec_tree_reshape.md) | SPR-1 (owner 1a) — G3: eleven working specs GRADUATE to 03-approved |
| `spr-2` | [rulings_2026_08_20_spec_tree_reshape.md](rulings_2026_08_20_spec_tree_reshape.md) | SPR-2 (owner 2a) — fourteen files ARCHIVE to spec/_archived/ |
| `spr-3` | [rulings_2026_08_20_spec_tree_reshape.md](rulings_2026_08_20_spec_tree_reshape.md) | SPR-3 (owner 3a) — both spec/01-new cxstore files STAY at 01-new |
| `spr-4` | [rulings_2026_08_20_spec_tree_reshape.md](rulings_2026_08_20_spec_tree_reshape.md) | SPR-4 (owner "1b", same day, spec-review session) — set-identity sketch RETIRED, precedent made normative |
| `spr-5` | [rulings_2026_08_20_spec_tree_reshape.md](rulings_2026_08_20_spec_tree_reshape.md) | SPR-5 (owner "2a 3a", spec-review session) — xap_architecture split-and-settled; the U1 letter archived |
| `spread-1` | [rulings_2026_09_27_owner_decisions_l41_l44.md](rulings_2026_09_27_owner_decisions_l41_l44.md) | Owner decisions 2026-09-27 — Letters 41–45: the call spread (SPREAD-1), the orders-db partial (ODB-1), R-1492 as graded (BEX-1), the bus audit subject (BUS-1), no new agents (PACE-2) |
| `spread-1` | [rulings_2026_09_27_owner_decisions_l41_l44.md](rulings_2026_09_27_owner_decisions_l41_l44.md) | SPREAD-1 — a call spread in the language (Letter 41 = (a); #1686) |
| `spread-2` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | Owner decisions 2026-09-27 — Letters 46–50 and the org profile: KIT-4's shape (KIT4-1…3), the #1498 spec gaps (AA-7…9), HOST-4's seed made real (SEED-1), the host act's basis (HOSTB-1), the call spread's readings (SPREAD-2), the org-profile push (ORG-1) |
| `spread-2` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) | SPREAD-2 — the call spread's three readings (L50 = (a), (a), (a)) |
| `sse-1` | [rulings_2026_08_20_sse_downstream.md](rulings_2026_08_20_sse_downstream.md) | Ruling SSE-1 (2026-08-20) — the v1 web binding's SSE downstream: negotiated XSP-envelope carriage (owner "1b") |
| `sup-1` | [rulings_2026_08_20_supervise.md](rulings_2026_08_20_supervise.md) | SUP-1 — graduate the contract AND implement pre-cut |
| `sync-1` | [rulings_2026_09_27_owner_decisions_l55.md](rulings_2026_09_27_owner_decisions_l55.md) | Owner decisions 2026-09-27 (afternoon) — Letter 55: the code phase of the sync module, SYNC-1…SYNC-9 |
| `sync-1` | [rulings_2026_09_27_owner_decisions_l55.md](rulings_2026_09_27_owner_decisions_l55.md) | SYNC-1 — the source is pure CX in the connector package, with a bench bound (L55.1 = (a)) |
| `sync-2` | [rulings_2026_09_27_owner_decisions_l55.md](rulings_2026_09_27_owner_decisions_l55.md) | SYNC-2 — the engine is the spec's pure defs plus one `run` over the kit (L55.2 = (a)) |
| `sync-3` | [rulings_2026_09_27_owner_decisions_l55.md](rulings_2026_09_27_owner_decisions_l55.md) | SYNC-3 — `[capture]` is one core element in feature.cxs (L55.3 = (a)) |
| `sync-3` | [rulings_2026_09_28_integrator_decisions_l64_l70.md](rulings_2026_09_28_integrator_decisions_l64_l70.md) | 1690, #1498, #1434, PIVOT-2, SYNC-3, SYNC-6, KIT4-1, KIT4-2, RS-38, D83a, K10.** |
| `sync-4` | [rulings_2026_09_27_owner_decisions_l55.md](rulings_2026_09_27_owner_decisions_l55.md) | SYNC-4 — the watermark is a per-source journal stream committed by compare-and-swap (L55.4 = (a)) |
| `sync-5` | [rulings_2026_09_27_owner_decisions_l55.md](rulings_2026_09_27_owner_decisions_l55.md) | SYNC-5 — the dedup key is `(source, identity, address)` (L55.5 = (a)) |
| `sync-6` | [rulings_2026_09_27_owner_decisions_l55.md](rulings_2026_09_27_owner_decisions_l55.md) | SYNC-6 — the host arms the cadence from a `[sync]` row (L55.6 = (a)) |
| `sync-6` | [rulings_2026_09_28_integrator_decisions_l64_l70.md](rulings_2026_09_28_integrator_decisions_l64_l70.md) | 1690, #1498, #1434, PIVOT-2, SYNC-3, SYNC-6, KIT4-1, KIT4-2, RS-38, D83a, K10.** |
| `sync-7` | [rulings_2026_09_27_owner_decisions_l55.md](rulings_2026_09_27_owner_decisions_l55.md) | SYNC-7 — log-based capture stays out of this phase (L55.7 = (a)) |
| `sync-8` | [rulings_2026_09_27_owner_decisions_l55.md](rulings_2026_09_27_owner_decisions_l55.md) | SYNC-8 — orders-db-005/006/008 flip to enforced in wave 1 (L55.8 = (a)) |
| `sync-9` | [rulings_2026_09_27_owner_decisions_l55.md](rulings_2026_09_27_owner_decisions_l55.md) | Owner decisions 2026-09-27 (afternoon) — Letter 55: the code phase of the sync module, SYNC-1…SYNC-9 |
| `sync-9` | [rulings_2026_09_27_owner_decisions_l55.md](rulings_2026_09_27_owner_decisions_l55.md) | SYNC-9 — two waves (L55.9 = (a)) |
| `synct-1` | [rulings_2026_09_28_integrator_decisions_l64_l70.md](rulings_2026_09_28_integrator_decisions_l64_l70.md) | SYNCT-1 — SYNC wave 2a's four choices get sentences in their sections (L67 = (a)) |
| `ta-1` | [rulings_2026_08_21_surface_closeout.md](rulings_2026_08_21_surface_closeout.md) | TA-1 — the type annotation is GLUED, and the reader enforces it (#911) |
| `td-1` | [rulings_2026_08_26_playground_tree_detail_1001.md](rulings_2026_08_26_playground_tree_detail_1001.md) | TD-1 — the defect, restated as measured |
| `td-2` | [rulings_2026_08_26_playground_tree_detail_1001.md](rulings_2026_08_26_playground_tree_detail_1001.md) | TD-2 — the fix reads the contract THROUGH the function the tables already use |
| `td-3` | [rulings_2026_08_26_playground_tree_detail_1001.md](rulings_2026_08_26_playground_tree_detail_1001.md) | TD-3 — the trade-off the issue raised is DECLINED, and paid for instead |
| `td-4` | [rulings_2026_08_26_playground_tree_detail_1001.md](rulings_2026_08_26_playground_tree_detail_1001.md) | TD-4 — `Detail` moves back to the View pane header |
| `td-5` | [rulings_2026_08_26_playground_tree_detail_1001.md](rulings_2026_08_26_playground_tree_detail_1001.md) | TD-5 — a value LEAF is one row too |
| `td-6` | [rulings_2026_08_26_playground_tree_detail_1001.md](rulings_2026_08_26_playground_tree_detail_1001.md) | TD-6 — the visual pass is part of the deliverable |
| `td-7` | [rulings_2026_08_26_playground_tree_detail_1001.md](rulings_2026_08_26_playground_tree_detail_1001.md) | TD-7 — what holds it, and what does not |
| `tf-1` | [rulings_2026_08_30_text_format_surface.md](rulings_2026_08_30_text_format_surface.md) | TF-1 — per-format canonical emission and XML C14N (#1110) (RULED: TF-1 = a) |
| `tf-1` | [rulings_2026_08_30_text_format_surface.md](rulings_2026_08_30_text_format_surface.md) | TF-1 — per-format canonical emission and XML C14N (#1110) (RULED: TF-1 = a) |
| `tf-10` | [rulings_2026_08_30_text_format_residuals.md](rulings_2026_08_30_text_format_residuals.md) | TF-10 — the memory multiplier's priority (#1119) (RULED: TF-10 = a) |
| `tf-10` | [rulings_2026_08_30_text_format_residuals.md](rulings_2026_08_30_text_format_residuals.md) | TF-10 — the memory multiplier's priority (#1119) (RULED: TF-10 = a) |
| `tf-2` | [rulings_2026_08_30_text_format_surface.md](rulings_2026_08_30_text_format_surface.md) | TF-2 — YAML ambition (#1111) (RULED: TF-2 = b) |
| `tf-2` | [rulings_2026_08_30_text_format_surface.md](rulings_2026_08_30_text_format_surface.md) | TF-2 — YAML ambition (#1111) (RULED: TF-2 = b) |
| `tf-3` | [rulings_2026_08_30_text_format_surface.md](rulings_2026_08_30_text_format_surface.md) | TF-3 — xml's side of the module split (#1121) (RULED: TF-3 = a) |
| `tf-3` | [rulings_2026_08_30_text_format_surface.md](rulings_2026_08_30_text_format_surface.md) | TF-3 — xml's side of the module split (#1121) (RULED: TF-3 = a) |
| `tf-4` | [rulings_2026_08_30_text_format_surface.md](rulings_2026_08_30_text_format_surface.md) | TF-4 — W-6 mixed-content whitespace carve-out (#1122) (RULED: TF-4 = c) |
| `tf-4` | [rulings_2026_08_30_text_format_surface.md](rulings_2026_08_30_text_format_surface.md) | TF-4 — W-6 mixed-content whitespace carve-out (#1122) (RULED: TF-4 = c) |
| `tf-4` | [rulings_2026_08_30_text_format_surface.md](rulings_2026_08_30_text_format_surface.md) | 1121 + #1115; TF-4 = `xml:space` in the parser + the whitespace opt, |
| `tf-5` | [rulings_2026_08_30_text_format_surface.md](rulings_2026_08_30_text_format_surface.md) | TF-5 — streaming direction (#1119) (RULED: TF-5 = a) |
| `tf-5` | [rulings_2026_08_30_text_format_surface.md](rulings_2026_08_30_text_format_surface.md) | TF-5 — streaming direction (#1119) (RULED: TF-5 = a) |
| `tf-5` | [rulings_2026_09_02_cxdm_representation_1119.md](rulings_2026_09_02_cxdm_representation_1119.md) | RP-0 — the streaming direction is ALREADY RULED; it stands (TF-5 = a) |
| `tf-6` | [rulings_2026_08_30_text_format_surface.md](rulings_2026_08_30_text_format_surface.md) | TF-6 — LATE RECORD (R5.0): the two spec touches that rode the fix commits |
| `tf-7` | [rulings_2026_08_30_text_format_residuals.md](rulings_2026_08_30_text_format_residuals.md) | TF-7 — dot-segment removal in the RFC 3986 lane (#1118) (RULED: TF-7 = a) |
| `tf-7` | [rulings_2026_08_30_text_format_residuals.md](rulings_2026_08_30_text_format_residuals.md) | TF-7 — dot-segment removal in the RFC 3986 lane (#1118) (RULED: TF-7 = a) |
| `tf-8` | [rulings_2026_08_30_text_format_residuals.md](rulings_2026_08_30_text_format_residuals.md) | TF-8 — XML declared encodings (#1117) (RULED: TF-8 = c) — RECOMMENDATION CHANGED |
| `tf-8` | [rulings_2026_08_30_text_format_residuals.md](rulings_2026_08_30_text_format_residuals.md) | TF-8 — XML declared encodings (#1117) (RULED: TF-8 = c) — RECOMMENDATION CHANGED |
| `tf-9` | [rulings_2026_08_30_text_format_residuals.md](rulings_2026_08_30_text_format_residuals.md) | TF-9 — the codec error shape (#1120) (RULED: TF-9 = a, with sequencing) |
| `tf-9` | [rulings_2026_08_30_text_format_residuals.md](rulings_2026_08_30_text_format_residuals.md) | TF-9 — the codec error shape (#1120) (RULED: TF-9 = a, with sequencing) |
| `tg-1` | [rulings_2026_08_26_playground_tree_gate_1049.md](rulings_2026_08_26_playground_tree_gate_1049.md) | TG-1 — the gap, restated as measured |
| `tg-2` | [rulings_2026_08_26_playground_tree_gate_1049.md](rulings_2026_08_26_playground_tree_gate_1049.md) | TG-2 — ONE harness, not a second one |
| `tg-3` | [rulings_2026_08_26_playground_tree_gate_1049.md](rulings_2026_08_26_playground_tree_gate_1049.md) | TG-3 — the gate drives CONTROLS, not functions |
| `tg-4` | [rulings_2026_08_26_playground_tree_gate_1049.md](rulings_2026_08_26_playground_tree_gate_1049.md) | TG-4 — the expectations are PINNED, and that is forced |
| `tg-5` | [rulings_2026_08_26_playground_tree_gate_1049.md](rulings_2026_08_26_playground_tree_gate_1049.md) | TG-5 — the pinned set, and why each case is in it |
| `tg-6` | [rulings_2026_08_26_playground_tree_gate_1049.md](rulings_2026_08_26_playground_tree_gate_1049.md) | TG-6 — the bridge is round-tripped in BOTH directions |
| `tg-7` | [rulings_2026_08_26_playground_tree_gate_1049.md](rulings_2026_08_26_playground_tree_gate_1049.md) | TG-7 — red-proven, three ways |
| `tg-8` | [rulings_2026_08_26_playground_tree_gate_1049.md](rulings_2026_08_26_playground_tree_gate_1049.md) | TG-8 — placement, and what this lane does not claim |
| `thru-1` | [rulings_2026_09_19_owner_decisions_0505z.md](rulings_2026_09_19_owner_decisions_0505z.md) | Owner decisions 2026-09-19 ~05:05Z — the throughput bar: two closures an hour or the project is suspended (THRU-1); READY is the branch's own tree, no head-merge re-set (THRU-2); the batch is the unit of work (THRU-3); the union window holds only load-sensitive steps (THRU-4) |
| `thru-2` | [rulings_2026_09_19_owner_decisions_0505z.md](rulings_2026_09_19_owner_decisions_0505z.md) | Owner decisions 2026-09-19 ~05:05Z — the throughput bar: two closures an hour or the project is suspended (THRU-1); READY is the branch's own tree, no head-merge re-set (THRU-2); the batch is the unit of work (THRU-3); the union window holds only load-sensitive steps (THRU-4) |
| `thru-3` | [rulings_2026_09_19_owner_decisions_0505z.md](rulings_2026_09_19_owner_decisions_0505z.md) | Owner decisions 2026-09-19 ~05:05Z — the throughput bar: two closures an hour or the project is suspended (THRU-1); READY is the branch's own tree, no head-merge re-set (THRU-2); the batch is the unit of work (THRU-3); the union window holds only load-sensitive steps (THRU-4) |
| `thru-4` | [rulings_2026_09_19_owner_decisions_0505z.md](rulings_2026_09_19_owner_decisions_0505z.md) | Owner decisions 2026-09-19 ~05:05Z — the throughput bar: two closures an hour or the project is suspended (THRU-1); READY is the branch's own tree, no head-merge re-set (THRU-2); the batch is the unit of work (THRU-3); the union window holds only load-sensitive steps (THRU-4) |
| `ti-1` | [rulings_2026_08_21_table_image.md](rulings_2026_08_21_table_image.md) | TI-1 — the image carries the table, because the seam already parsed it |
| `tme-1` | [rulings_2026_08_22_typed_map_entry.md](rulings_2026_08_22_typed_map_entry.md) | TME-1 — a map key is a declaration site, so it takes the glued annotation |
| `tme-1` | [rulings_2026_08_22_typed_map_entry.md](rulings_2026_08_22_typed_map_entry.md) | TME-1 is SUPERSEDED — its premise was FALSE (recorded 2026-08-22) |
| `trap-1` | [rulings_2026_09_17_trap_batches.md](rulings_2026_09_17_trap_batches.md) | The traps become fixtures — two batch branches for the CXF-8 defects, and the one ruling they need (RULED: TRAP-1, 1527-a) |
| `triage-1` | [rulings_2026_09_18_owner_decisions_1640z.md](rulings_2026_09_18_owner_decisions_1640z.md) | Owner decisions 2026-09-18 ~16:40Z — "recommendations accepted": twenty-one issues closed by the owner's word on the triage list (TRIAGE-1); the soap version is the string '1.1' (1575-b); unknown Security members are carried (1456-b) |
| `uom-1` | [rulings_2026_08_20_universal_object_model.md](rulings_2026_08_20_universal_object_model.md) | UOM-1 — the universal object/subtree model IS the store contract; execute |
| `ux-1` | [rulings_2026_08_20_ux_spec_precut.md](rulings_2026_08_20_ux_spec_precut.md) | UX-1 — spec pre-cut, then documentation ("big miss but we caught it") |
| `vc-1` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | Ruling 2026-08-24 — the v0.16.1 campaign charter (VC-1..VC-5) |
| `vc-1` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-1 (1a) — #939: CX commits to the fork permanently |
| `vc-10` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 4 (2026-08-24) — VC-10 |
| `vc-10` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-10 (5a + a gating instruction) — #874 CLOSES; the remainder becomes a RELEASE GATE |
| `vc-11` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 5 (2026-08-24) — VC-11 |
| `vc-11` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-11 (6a) — the two undefined `cx:` contracts are DEFINED to match what shipped |
| `vc-12` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 6 (2026-08-24) — VC-12 |
| `vc-12` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-12 (8a) — the three unverified branches are TRACKED, not audited and not deleted |
| `vc-13` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 7 (2026-08-24) — VC-13 |
| `vc-13` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-13 — #961 and #962 PORT INTO v0.17.0 |
| `vc-14` | [dead_ends_700_test_duration.md](dead_ends_700_test_duration.md) | D1 — test-file consolidation, "one binary per module" (VC-14 lever 10a) |
| `vc-14` | [dead_ends_700_test_duration.md](dead_ends_700_test_duration.md) | D2 — VC-14's decline of `-usecache` "on risk" |
| `vc-14` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 8 (2026-08-24) — VC-14..VC-17 |
| `vc-14` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-14 (9a + 10a) — #700's remainder is WAVE 2 on #700, and the lever is ONE TEST BINARY PER MODULE |
| `vc-14` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-21 — VC-14's measured basis is STRUCK; the floor is ~25 CPU-s, not ~700 s |
| `vc-15` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-15 (11a) — the `cx:eval-tree` swallow is FIXED in this campaign |
| `vc-16` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-16 (12a) — the `$to-int` spec-prose contradiction is TRUED |
| `vc-17` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 8 (2026-08-24) — VC-14..VC-17 |
| `vc-17` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-17 ("yes file the others and fix this campaign") — VC-7's two reported findings are FILED **and** FIXED |
| `vc-18` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 9 (2026-08-24) — VC-18 |
| `vc-18` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-18 — #700 wave 2 is IN the v0.17.0 release but OUT of this campaign |
| `vc-19` | [matrix_2026_08_25_path_value_model.md](matrix_2026_08_25_path_value_model.md) | §2. Prior rulings reconciled (in writing, per VC-19) |
| `vc-19` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 10 (2026-08-24) — VC-19 |
| `vc-19` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-19 — the path/value and comment clusters are SETTLED IN v0.17.0, spec-first, by a Fable 5 session |
| `vc-2` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-2 (2a) — #940: the phantom registrations are RETIRED |
| `vc-20` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 11 (2026-08-24) — VC-20 |
| `vc-20` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-20 — #700 wave 2 goes FIRST, on Opus 5; the clusters follow on Fable 5 |
| `vc-21` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 12 (2026-08-24) — VC-21, VC-22 |
| `vc-21` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-21 — VC-14's measured basis is STRUCK; the floor is ~25 CPU-s, not ~700 s |
| `vc-22` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 12 (2026-08-24) — VC-21, VC-22 |
| `vc-22` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-22 — the gate is scoped BY RING; devbox stays |
| `vc-22` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-31 (5a) — VC-22's 10-minute target STANDS as an unmet aspiration, with its cost recorded |
| `vc-23` | [audit_2026_08_24_vcache_key_soundness.md](audit_2026_08_24_vcache_key_soundness.md) | AUDIT — V module-cache key completeness (#700 wave 2 part i, under VC-23) |
| `vc-23` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 13 (2026-08-24) — VC-23 |
| `vc-23` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-23 — #700 wave 2 is REDEFINED: module-cache SOUNDNESS in the V fork, not consolidation |
| `vc-24` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 14 (2026-08-25) — VC-24 |
| `vc-24` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-24 — the gate harness runs on `-gc e`; there is no Boehm lane in CX |
| `vc-25` | [dead_ends_700_test_duration.md](dead_ends_700_test_duration.md) | DEAD ENDS — #700 test-suite duration relief (closed under VC-25) |
| `vc-25` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 15 (2026-08-25) — VC-25 |
| `vc-25` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-25 — #700 CLOSES; every attempted lever is documented so none is re-tried |
| `vc-26` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 16 (2026-08-25) — VC-26 |
| `vc-26` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-26 — #956: implement what the platform supports; REFUSE what it cannot, loudly |
| `vc-27` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 17 (2026-08-25) — VC-27 .. VC-31 |
| `vc-27` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-27 (1a) — the Fable-track clusters stay Fable's; this session takes the unowned docket |
| `vc-28` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-28 (2a) — corpus/rosetta is ADOPTION EVIDENCE: rewrite it, re-derive the audit, then gate it |
| `vc-29` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-29 (3b) — the harness worker-pool lever is AUTHORIZED, and starts now |
| `vc-29` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 18 (2026-08-25) — VC-29 status: step 1 DELIVERED, step 2 BLOCKED by a runtime defect |
| `vc-3` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-3 (3a) — narrowly-named mechanical spec truings are PRE-AUTHORIZED |
| `vc-30` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-30 (4a) — #572 CLOSES on its attribution plus the escape detector |
| `vc-31` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 17 (2026-08-25) — VC-27 .. VC-31 |
| `vc-31` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-31 (5a) — VC-22's 10-minute target STANDS as an unmet aspiration, with its cost recorded |
| `vc-32` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 19 (2026-08-25) — VC-32 |
| `vc-32` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-32 — the gate lever proceeds by PROCESS sharding, not threads |
| `vc-32` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 20 (2026-08-25) — VC-32 DELIVERED, and the acceptance digest is re-derived |
| `vc-32` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | The acceptance digest CHANGED, and why (correction to VC-32) |
| `vc-4` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-4 (4a) — #804 and #834 stay owner-exempt |
| `vc-5` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | Ruling 2026-08-24 — the v0.16.1 campaign charter (VC-1..VC-5) |
| `vc-5` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-5 (5b) — autonomous to "ready to tag"; the cut itself waits for the owner |
| `vc-6` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 2 (2026-08-24) — VC-6, VC-7 |
| `vc-6` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-6 (1a) — #940: the ten unimplemented `cx:` module functions are IMPLEMENTED |
| `vc-7` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 2 (2026-08-24) — VC-6, VC-7 |
| `vc-7` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-7 (2a) — #945: gate 28.5 is REBUILT as two rows |
| `vc-7` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-17 ("yes file the others and fix this campaign") — VC-7's two reported findings are FILED **and** FIXED |
| `vc-8` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 3 (2026-08-24) — VC-8, VC-9 |
| `vc-8` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-8 (3a) — #907: catalogue preflight SPLITS by ownership |
| `vc-9` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | AMENDMENT 3 (2026-08-24) — VC-8, VC-9 |
| `vc-9` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | VC-9 (4a) — #874: editor-tooling distribution STAYS PARKED |
| `vc-9` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) | CORRECTION to VC-9 (same day, measured after the ruling) |
| `vcost-1` | [rulings_2026_09_18_owner_decisions_0440z.md](rulings_2026_09_18_owner_decisions_0440z.md) | Owner decisions 2026-09-18 ~04:40Z — `cx --ast` arbitrates the two readings as `cx lint` does (1536-a); `[?fn]` has no labeled slots (1558-b); the verification-cost lane is written (VCOST-1) |
| `verify-1` | [rulings_2026_09_18_owner_decisions_0235z.md](rulings_2026_09_18_owner_decisions_0235z.md) | Owner decision 2026-09-18 ~02:35Z — the eight-hour target: fifty more resolutions with two agents; batch branches verify through an inner loop, one graded run per merge point (RULED: VERIFY-1) |
| `verify-1a` | [rulings_2026_09_18_owner_decisions_0250z.md](rulings_2026_09_18_owner_decisions_0250z.md) | Owner decision 2026-09-18 ~02:50Z — the eight-hour requirement amended: the order is the most recent issues first, then Ring 0, Ring 1, Ring 2; #1520 and #1515 ride the first batch; the fifty is a HARD REQUIREMENT (RULED: VERIFY-1a) |
| `verify-2` | [rulings_2026_09_18_owner_decisions_1220z.md](rulings_2026_09_18_owner_decisions_1220z.md) | Owner decisions 2026-09-18 ~12:20Z — "all recommendations": the work continues past the clock with umbrella steps for Ring 0 (VERIFY-2); the twelve open letters ruled (1563-a, 1559-a, 1515-a, 1566-c, 1534-a, 1552-a, 1556-a, 1540-a, 1551-b, 1544-b, 1509-a) and the integrator's 1559-d recorded |
| `vf-1` | [rulings_2026_09_04_feature_verb_form_1217.md](rulings_2026_09_04_feature_verb_form_1217.md) | VF-1 — one projection, how many entries — RECOMMENDED: (a) |
| `vg-0` | [rulings_2026_09_04_view_grammar.md](rulings_2026_09_04_view_grammar.md) | VG-0 — the reading (recorded, not a letter) |
| `vg-1` | [rulings_2026_09_04_view_grammar.md](rulings_2026_09_04_view_grammar.md) | VG-1 — where the noun declares what the clauses may do (RULED: VG-1 = a) |
| `vg-1` | [rulings_2026_09_04_view_grammar.md](rulings_2026_09_04_view_grammar.md) | VG-1 — where the noun declares what the clauses may do (RULED: VG-1 = a) |
| `vg-2` | [rulings_2026_09_04_view_grammar.md](rulings_2026_09_04_view_grammar.md) | VG-2 — durable per-viewer view preferences (RULED: VG-2 = a) |
| `vg-2` | [rulings_2026_09_04_view_grammar.md](rulings_2026_09_04_view_grammar.md) | VG-2 — durable per-viewer view preferences (RULED: VG-2 = a) |
| `vg-3` | [rulings_2026_09_15_views_group_vg3_schema_sd1.md](rulings_2026_09_15_views_group_vg3_schema_sd1.md) | Owner letters 2026-09-15 ~01:20Z — the fourth clause of `[views]`, and the schema-as-data feature kind (RULED: VG-3, SD-1) |
| `walk-1` | [rulings_2026_09_27_owner_decisions_l52_l54.md](rulings_2026_09_27_owner_decisions_l52_l54.md) | Owner decisions 2026-09-27 (afternoon) — Letters 52, 53 and 54: XCO's two readings (ACK-1, RT-1), a list verb through the host walks every page (WALK-1), the vendor budget is per process (BUDGET-1) |
| `walk-1` | [rulings_2026_09_27_owner_decisions_l52_l54.md](rulings_2026_09_27_owner_decisions_l52_l54.md) | WALK-1 — a list verb performed by the host walks every page (L53 = (a)) |
| `we-1` | [rulings_2026_08_26_wasm_eval_sweep.md](rulings_2026_08_26_wasm_eval_sweep.md) | WE-1 — the harness must be a real browser; the cheap one is dishonest |
| `we-2` | [rulings_2026_08_26_wasm_eval_sweep.md](rulings_2026_08_26_wasm_eval_sweep.md) | WE-2 — the mechanism, and why the marker set is what it is |
| `we-3` | [rulings_2026_08_26_wasm_eval_sweep.md](rulings_2026_08_26_wasm_eval_sweep.md) | WE-3 — a marker must be JUSTIFIED, in both directions |
| `we-4` | [rulings_2026_08_26_wasm_eval_sweep.md](rulings_2026_08_26_wasm_eval_sweep.md) | WE-4 — the third state: an example with NO stable value |
| `we-5` | [rulings_2026_08_26_wasm_eval_sweep.md](rulings_2026_08_26_wasm_eval_sweep.md) | WE-5 — placement |
| `wf-0` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-0 — home, name, and the cutover of the shipped saga surface (item 1, substrate) — RECOMMENDED: (a) |
| `wf-1` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-1 — the flow document (item 1) — RECOMMENDED: (a) |
| `wf-10` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-10 — dynamic fan-out at scale: `map` into child runs (the bar: massive workflows) — RECOMMENDED: (a) |
| `wf-11` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-11 — the record at scale: transitions as deltas, snapshots, run-per-stream (the bar: performance and long histories) — RECOMMENDED: (a) |
| `wf-12` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-12 — human work management: inbox, claim, roles, SLA, reassignment (the bar: the SaaS/case engines' strength) — RECOMMENDED: (a) |
| `wf-13` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-13 — agents in design and operations; visual authoring; simulation; decisions as data (the bar: ease of design, agents everywhere) — RECOMMENDED: (a) |
| `wf-14` | [bench_flow_first_measurement_2026_09_04.md](bench_flow_first_measurement_2026_09_04.md) | bench/flow — FIRST MEASUREMENT 2026-09-04 (#1265 W1 packet C, RULED: WF-14) |
| `wf-14` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-14 — performance and scale gates: measured, not claimed (the bar: performance and scale) — RECOMMENDED: (a) |
| `wf-15` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-15 — does a flow require a store? the local profile (the bar: simple and quick) — RULED: (a) |
| `wf-16` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-16 — dogfood flows, and the make-style dependency question — RULED: (a) |
| `wf-16` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) | WF-20 — `needs=`: step order as a DAG (WF-16 PARTIAL REVISIT; rung 1) — RULED: (a) |
| `wf-17` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-17 — visualization and the visual / agent-assisted design tool (the bar: ease of design) — RULED: (a) |
| `wf-18` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) | Rulings 2026-09-05 — #789 flow, vocabulary round 2 (WF-18 … WF-26) |
| `wf-18` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) | WF-18 — bounded repetition: `until` (inventory rows 6, 13, 25, 35, 38) — RULED: (a) |
| `wf-19` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) | WF-19 — `cancel` as a public verb (rows 7, 13, 37) — RULED: (a) |
| `wf-2` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-2 — the closed vocabulary; the discipline boundary (item 2, make-or-break) — RECOMMENDED: (a) |
| `wf-20` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) | WF-20 — `needs=`: step order as a DAG (WF-16 PARTIAL REVISIT; rung 1) — RULED: (a) |
| `wf-20` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) | WF-20 consequence, found in implementation (2026-09-06) — `1265-PV-1` |
| `wf-21` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) | WF-21 — `quorum=` on an offered step (row 8) — RULED: (a) |
| `wf-22` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) | WF-22 — sub-flow by content address (row 44; reuse across 1, 16, 23) — RULED: (a) |
| `wf-23` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) | WF-23 — a notify rung on `[escalate]` (row 4) — RULED: (a) |
| `wf-24` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) | WF-24 — `calendar=`: durations in business time (row 11 and every SLA row) — RULED: (a) |
| `wf-25` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) | WF-25 — the operator verbs `pause` / `resume` / `skip` / `retry-now` (rows 41, 42) — RULED: (a) |
| `wf-26` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) | Rulings 2026-09-05 — #789 flow, vocabulary round 2 (WF-18 … WF-26) |
| `wf-26` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) | WF-26 — `attempts=` on a step: bounded re-attempt, `[idempotent]`-gated (row 5; #1314) — RULED: (a) |
| `wf-27` | [rulings_2026_09_06_flow_liveness_and_standalone_runner_789.md](rulings_2026_09_06_flow_liveness_and_standalone_runner_789.md) | Rulings 2026-09-06 — #789/#1313/#728, liveness and the standalone runner (WF-27, WF-28) |
| `wf-27` | [rulings_2026_09_06_flow_liveness_and_standalone_runner_789.md](rulings_2026_09_06_flow_liveness_and_standalone_runner_789.md) | WF-27 — liveness is a property of a RUNNER PROCESS, not of the document — RULED: (a) |
| `wf-28` | [rulings_2026_09_06_flow_binding_vocabulary_789.md](rulings_2026_09_06_flow_binding_vocabulary_789.md) | Rulings 2026-09-06 — #789, the binding vocabulary and the WF-28 amendment (WF-29, WF-28b) |
| `wf-28` | [rulings_2026_09_06_flow_liveness_and_standalone_runner_789.md](rulings_2026_09_06_flow_liveness_and_standalone_runner_789.md) | Rulings 2026-09-06 — #789/#1313/#728, liveness and the standalone runner (WF-27, WF-28) |
| `wf-28` | [rulings_2026_09_06_flow_liveness_and_standalone_runner_789.md](rulings_2026_09_06_flow_liveness_and_standalone_runner_789.md) | WF-28 — the standalone runner `cx flow serve` and the `[runner]` document — RULED: (a) |
| `wf-28a` | [rulings_2026_09_06_flow_binding_vocabulary_789.md](rulings_2026_09_06_flow_binding_vocabulary_789.md) | Why this exists — an error in WF-28a, found by the packet that tried to build it |
| `wf-28a` | [rulings_2026_09_06_flow_binding_vocabulary_789.md](rulings_2026_09_06_flow_binding_vocabulary_789.md) | WF-28b — the amendment to WF-28a — RULED (owner, "1a") |
| `wf-28a` | [rulings_2026_09_08_flow_serve_wf28.md](rulings_2026_09_08_flow_serve_wf28.md) | RULED: WF-28a, WF-28b — `cx flow serve`'s courier cadence and the occurrence invariant |
| `wf-28a` | [rulings_2026_09_08_flow_serve_wf28.md](rulings_2026_09_08_flow_serve_wf28.md) | WF-28a — `[courier every=D]` is `:fixed-delay`, sched's own default |
| `wf-28b` | [rulings_2026_09_06_flow_binding_vocabulary_789.md](rulings_2026_09_06_flow_binding_vocabulary_789.md) | Rulings 2026-09-06 — #789, the binding vocabulary and the WF-28 amendment (WF-29, WF-28b) |
| `wf-28b` | [rulings_2026_09_06_flow_binding_vocabulary_789.md](rulings_2026_09_06_flow_binding_vocabulary_789.md) | WF-28b — the amendment to WF-28a — RULED (owner, "1a") |
| `wf-28b` | [rulings_2026_09_08_flow_serve_wf28.md](rulings_2026_09_08_flow_serve_wf28.md) | RULED: WF-28a, WF-28b — `cx flow serve`'s courier cadence and the occurrence invariant |
| `wf-28b` | [rulings_2026_09_08_flow_serve_wf28.md](rulings_2026_09_08_flow_serve_wf28.md) | WF-28b — the corpus pins the invariant DIRECTLY, and `ticks=` stops posing as a measurement |
| `wf-29` | [rulings_2026_09_06_flow_binding_vocabulary_789.md](rulings_2026_09_06_flow_binding_vocabulary_789.md) | Rulings 2026-09-06 — #789, the binding vocabulary and the WF-28 amendment (WF-29, WF-28b) |
| `wf-29` | [rulings_2026_09_06_flow_binding_vocabulary_789.md](rulings_2026_09_06_flow_binding_vocabulary_789.md) | WF-29 — the binding vocabulary, and the truing of §4.9 — RULED: (a) |
| `wf-3` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-3 — how a flow starts: no triggers in the document (items 1+2; #1185 item 1; #1256) — RECOMMENDED: (a) |
| `wf-30` | [rulings_2026_09_06_flow_binding_start_contract_789.md](rulings_2026_09_06_flow_binding_start_contract_789.md) | Rulings 2026-09-06 — #789, the binding→`start` contract (WF-30 … WF-34) |
| `wf-30` | [rulings_2026_09_06_flow_binding_start_contract_789.md](rulings_2026_09_06_flow_binding_start_contract_789.md) | WF-30 — how `start=<address>` resolves to a document — RULED: (a) |
| `wf-31` | [rulings_2026_09_06_flow_binding_start_contract_789.md](rulings_2026_09_06_flow_binding_start_contract_789.md) | WF-31 — the `start` call's four inputs, per binding kind — RULED: (a) |
| `wf-32` | [rulings_2026_09_06_flow_binding_start_contract_789.md](rulings_2026_09_06_flow_binding_start_contract_789.md) | WF-32 — what the courier ticks — RULED: (a) |
| `wf-33` | [rulings_2026_09_06_flow_binding_start_contract_789.md](rulings_2026_09_06_flow_binding_start_contract_789.md) | WF-33 — the malformed-`[runner]` refusal code — RULED: (a) |
| `wf-34` | [rulings_2026_09_06_flow_binding_start_contract_789.md](rulings_2026_09_06_flow_binding_start_contract_789.md) | Rulings 2026-09-06 — #789, the binding→`start` contract (WF-30 … WF-34) |
| `wf-34` | [rulings_2026_09_06_flow_binding_start_contract_789.md](rulings_2026_09_06_flow_binding_start_contract_789.md) | WF-34 — `stream-prefix=`, and the webhook bind address — RULED: (a) |
| `wf-35` | [rulings_2026_09_06_flow_binding_row_shape_789.md](rulings_2026_09_06_flow_binding_row_shape_789.md) | Rulings 2026-09-06 — #789, the binding row's spelling, the `fold` kind, and the one-law nonce (WF-35 … WF-37) |
| `wf-35` | [rulings_2026_09_06_flow_binding_row_shape_789.md](rulings_2026_09_06_flow_binding_row_shape_789.md) | WF-35 — how the binding row is spelled — RULED: (a) |
| `wf-36` | [rulings_2026_09_06_flow_binding_row_shape_789.md](rulings_2026_09_06_flow_binding_row_shape_789.md) | WF-36 — the `fold` kind in the standalone runner — RULED: (a) |
| `wf-37` | [rulings_2026_09_06_flow_binding_row_shape_789.md](rulings_2026_09_06_flow_binding_row_shape_789.md) | Rulings 2026-09-06 — #789, the binding row's spelling, the `fold` kind, and the one-law nonce (WF-35 … WF-37) |
| `wf-37` | [rulings_2026_09_06_flow_binding_row_shape_789.md](rulings_2026_09_06_flow_binding_row_shape_789.md) | WF-37 — which side moves so the one-law gate is reachable — RULED: (a) |
| `wf-38` | [rulings_2026_09_06_flow_resolver_idempotent_789.md](rulings_2026_09_06_flow_resolver_idempotent_789.md) | Ruling 2026-09-06 — #789, the resolver row carries `idempotent=` (WF-38) |
| `wf-38` | [rulings_2026_09_06_flow_resolver_idempotent_789.md](rulings_2026_09_06_flow_resolver_idempotent_789.md) | WF-38 — how the `[idempotent]` disposition reaches `validate` — RULED: (a) |
| `wf-4` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-4 — the performer axis: principal, agent and peer steps; deadlines; escalation (items 1+2) — RECOMMENDED: (a) |
| `wf-42` | [rulings_2026_09_14_flow_step_data_binding_wf42.md](rulings_2026_09_14_flow_step_data_binding_wf42.md) | Owner letter 2026-09-14 ~16:50Z — a flow step binds its intent from the run record, and a `:runner` transform step maps one connector's result onto another's intent (RULED: WF-42) |
| `wf-5` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-5 — authority: the advancer is a courier; racing advancers (items 2+4; X2) — RECOMMENDED: (a) |
| `wf-6` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-6 — change management: versioning a flow while runs are in flight (item 1; stream 21) — RECOMMENDED: (a) |
| `wf-7` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-7 — fleet observability (item 3) — RECOMMENDED: (a) |
| `wf-8` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-8 — the cross-company profile (item 4) — RECOMMENDED: (a) |
| `wf-9` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) | WF-9 — sequencing; what this track delivers now — RECOMMENDED: (a) |
| `xap-1a` | [rulings_2026_09_26_xap_host_runner_xap1.md](rulings_2026_09_26_xap_host_runner_xap1.md) | XAP-1a, XAP-1b — the xap host embeds the flow runner (owner: Letter 14 = 1a 2b, 2026-09-26) |
| `xap-1a` | [rulings_2026_09_26_xap_host_runner_xap1.md](rulings_2026_09_26_xap_host_runner_xap1.md) | XAP-1a — the deployment face serves schedule, intent and webhook |
| `xap-1b` | [rulings_2026_09_26_xap_host_runner_xap1.md](rulings_2026_09_26_xap_host_runner_xap1.md) | XAP-1a, XAP-1b — the xap host embeds the flow runner (owner: Letter 14 = 1a 2b, 2026-09-26) |
| `xap-1b` | [rulings_2026_09_26_xap_host_runner_xap1.md](rulings_2026_09_26_xap_host_runner_xap1.md) | XAP-1b — the host-side courier is a sched cadence on the boot fiber |
| `xco-1` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | Owner decisions 2026-09-26 — the four designs of Letters 26–29: the connector kit (KIT-1…KIT-6), cross-company (XCO-1…XCO-5), the minimal keystore (SEC-1), the host's four choices (HOST-1…HOST-4) |
| `xco-1` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | XCO-1 — a did:web ack is verified under the key the session resolved at attach |
| `xco-2` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | XCO-2 — a tier-2 ack is a co-signature set over one claim |
| `xco-3` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | XCO-3 — the counterparty half lives in the XAP host |
| `xco-4` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | XCO-4 — the host is the initiator's session holder too |
| `xco-5` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | Owner decisions 2026-09-26 — the four designs of Letters 26–29: the connector kit (KIT-1…KIT-6), cross-company (XCO-1…XCO-5), the minimal keystore (SEC-1), the host's four choices (HOST-1…HOST-4) |
| `xco-5` | [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) | XCO-5 — a host may be did:web |
| `xd-1` | [rulings_2026_08_21_x_tier_docs_and_domain_writes.md](rulings_2026_08_21_x_tier_docs_and_domain_writes.md) | XD-1 — the x/ tier is DOCUMENTED, and marked for what it is (#904) |
| `xd-2` | [rulings_2026_08_21_x_tier_docs_and_domain_writes.md](rulings_2026_08_21_x_tier_docs_and_domain_writes.md) | XD-2 — domain data is journaled, and its authority is its own (#905) |
| `yield-1` | [rulings_2026_09_27_integrator_decisions_l60.md](rulings_2026_09_27_integrator_decisions_l60.md) | Integrator decision 2026-09-27 (evening), under the owner's delegation — Letter 60: each `[yield]` contributes exactly one item (YIELD-1) |
| `yield-1` | [rulings_2026_09_27_integrator_decisions_l60.md](rulings_2026_09_27_integrator_decisions_l60.md) | YIELD-1 — a `[yield]` inside `[?for]` contributes exactly one item, whatever its type (L60 = (a)) |
| `yield-2` | [rulings_2026_09_28_integrator_decisions_l64_l70.md](rulings_2026_09_28_integrator_decisions_l64_l70.md) | YIELD-2 — a yielded pair in an element body is one child (L65 = (a)) |

## Cited only -- named in a page's prose, with no heading of its own

| id | pages that name it |
|---|---|
| `1066-q1a` | [rulings_2026_09_04_diagram_def_namespace_1066.md](rulings_2026_09_04_diagram_def_namespace_1066.md) |
| `107-a` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) |
| `1075-q1a` | [rulings_2026_09_04_pipeline_rows_on_timeout_1075.md](rulings_2026_09_04_pipeline_rows_on_timeout_1075.md) |
| `1085-c-1` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md), [rulings_2026_09_12_net_tls_accept_wrap_1421.md](rulings_2026_09_12_net_tls_accept_wrap_1421.md) |
| `1085-c-2` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md), [rulings_2026_09_12_audit_sink_1422.md](rulings_2026_09_12_audit_sink_1422.md) |
| `1085-c-3` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) |
| `1085-c-4` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) |
| `1085-c-5` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) |
| `1087-a` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) |
| `1088-a` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) |
| `1097-b` | [rulings_2026_09_11_email_world_class_agentic_1085.md](rulings_2026_09_11_email_world_class_agentic_1085.md) |
| `114-set` | [rulings_2026_08_20_fixture_generator_cx.md](rulings_2026_08_20_fixture_generator_cx.md) |
| `1161-q1a` | [rulings_2026_09_03_instance_of_pin_1161.md](rulings_2026_09_03_instance_of_pin_1161.md) |
| `1170-a` | [rulings_2026_09_08_bare_builtin_head_lint_1170.md](rulings_2026_09_08_bare_builtin_head_lint_1170.md), [rulings_2026_09_08_let_cascade_lint_1170.md](rulings_2026_09_08_let_cascade_lint_1170.md), [rulings_2026_09_08_playground_output_pin_1170.md](rulings_2026_09_08_playground_output_pin_1170.md), [rulings_2026_09_08_seq4_pin_page_sync_1170.md](rulings_2026_09_08_seq4_pin_page_sync_1170.md) |
| `1170-b` | [rulings_2026_09_08_bare_builtin_head_lint_1170.md](rulings_2026_09_08_bare_builtin_head_lint_1170.md), [rulings_2026_09_08_let_cascade_lint_1170.md](rulings_2026_09_08_let_cascade_lint_1170.md), [rulings_2026_09_08_seq4_pin_page_sync_1170.md](rulings_2026_09_08_seq4_pin_page_sync_1170.md), [rulings_2026_09_09_playground_expect_check_1170g.md](rulings_2026_09_09_playground_expect_check_1170g.md) |
| `1170-c` | [rulings_2026_09_08_let_cascade_lint_1170.md](rulings_2026_09_08_let_cascade_lint_1170.md), [rulings_2026_09_08_seq4_pin_page_sync_1170.md](rulings_2026_09_08_seq4_pin_page_sync_1170.md), [rulings_2026_09_09_diagram_node_id_ordinals_1349.md](rulings_2026_09_09_diagram_node_id_ordinals_1349.md) |
| `1172-q1a` | [rulings_2026_09_04_head_bind_whole_element_1172.md](rulings_2026_09_04_head_bind_whole_element_1172.md), [rulings_2026_09_05_pattern_attr_rest_1270.md](rulings_2026_09_05_pattern_attr_rest_1270.md) |
| `1173-a` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md), [rulings_2026_09_17_owner_decisions_0345z.md](rulings_2026_09_17_owner_decisions_0345z.md) |
| `1174-a` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md), [rulings_2026_09_17_owner_decisions_0345z.md](rulings_2026_09_17_owner_decisions_0345z.md) |
| `1175-a` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md), [rulings_2026_09_17_owner_decisions_0410z.md](rulings_2026_09_17_owner_decisions_0410z.md) |
| `118-odd` | [rulings_2026_09_08_playground_output_pin_1170.md](rulings_2026_09_08_playground_output_pin_1170.md) |
| `1190-a` | [rulings_2026_09_07_solitary_key_is_a_note_1190.md](rulings_2026_09_07_solitary_key_is_a_note_1190.md) |
| `1190-b` | [rulings_2026_09_07_solitary_key_is_a_note_1190.md](rulings_2026_09_07_solitary_key_is_a_note_1190.md) |
| `1191-a` | [rulings_2026_09_07_feature_name_one_segment_1191.md](rulings_2026_09_07_feature_name_one_segment_1191.md) |
| `1210-hc-1` | [rulings_2026_09_04_host_context_1210.md](rulings_2026_09_04_host_context_1210.md) |
| `1217-q1` | [rulings_2026_09_05_xap_queue.md](rulings_2026_09_05_xap_queue.md) |
| `1217-vf-1` | [rulings_2026_09_04_feature_verb_form_1217.md](rulings_2026_09_04_feature_verb_form_1217.md) |
| `122-one` | [rulings_2026_09_04_feature_verb_form_1217.md](rulings_2026_09_04_feature_verb_form_1217.md) |
| `1228-q1a` | [rulings_2026_09_03_monitor_batch_terminal_1228.md](rulings_2026_09_03_monitor_batch_terminal_1228.md) |
| `1233-q1ab` | [rulings_2026_09_03_alias_amplification_1233.md](rulings_2026_09_03_alias_amplification_1233.md) |
| `1249-q1a` | [rulings_2026_09_04_perf_ratchet_at_cut_1249.md](rulings_2026_09_04_perf_ratchet_at_cut_1249.md), [rulings_2026_09_13_fmt_perf_1433.md](rulings_2026_09_13_fmt_perf_1433.md) |
| `1259-d1` | [rulings_2026_09_09_composed_emits_of_1259.md](rulings_2026_09_09_composed_emits_of_1259.md) |
| `1259-d3` | [rulings_2026_09_09_composed_emits_of_1259.md](rulings_2026_09_09_composed_emits_of_1259.md) |
| `1259-e1` | [rulings_2026_09_09_composed_emits_of_1259.md](rulings_2026_09_09_composed_emits_of_1259.md) |
| `1259-e2` | [rulings_2026_09_09_composed_emits_of_1259.md](rulings_2026_09_09_composed_emits_of_1259.md) |
| `1259-e3` | [rulings_2026_09_09_composed_emits_of_1259.md](rulings_2026_09_09_composed_emits_of_1259.md), [rulings_2026_09_09_lenient_emits_of_1259.md](rulings_2026_09_09_lenient_emits_of_1259.md), [rulings_2026_09_09_section6_agreement_1259.md](rulings_2026_09_09_section6_agreement_1259.md) |
| `1259-f1` | [rulings_2026_09_09_composed_emits_of_1259.md](rulings_2026_09_09_composed_emits_of_1259.md) |
| `1259-f2` | [rulings_2026_09_09_composed_emits_of_1259.md](rulings_2026_09_09_composed_emits_of_1259.md) |
| `1259-f3` | [rulings_2026_09_09_composed_emits_of_1259.md](rulings_2026_09_09_composed_emits_of_1259.md) |
| `1259-g1` | [rulings_2026_09_09_agent_tool_projection_feature_verbs_1352.md](rulings_2026_09_09_agent_tool_projection_feature_verbs_1352.md), [rulings_2026_09_09_lenient_emits_of_1259.md](rulings_2026_09_09_lenient_emits_of_1259.md), [rulings_2026_09_09_section6_agreement_1259.md](rulings_2026_09_09_section6_agreement_1259.md) |
| `1259-g2` | [rulings_2026_09_09_lenient_emits_of_1259.md](rulings_2026_09_09_lenient_emits_of_1259.md) |
| `1259-g3` | [rulings_2026_09_09_lenient_emits_of_1259.md](rulings_2026_09_09_lenient_emits_of_1259.md) |
| `1259-j` | [rulings_2026_09_09_ux_form_subject_noun_1371.md](rulings_2026_09_09_ux_form_subject_noun_1371.md) |
| `1260-ca-1` | [rulings_2026_09_03_canonical_act_form_1260.md](rulings_2026_09_03_canonical_act_form_1260.md) |
| `1260-ca-4` | [rulings_2026_09_03_canonical_act_form_1260.md](rulings_2026_09_03_canonical_act_form_1260.md) |
| `1265-pb-2` | [rulings_2026_09_06_flow_binding_row_shape_789.md](rulings_2026_09_06_flow_binding_row_shape_789.md), [rulings_2026_09_08_local_runner_rearm_1313.md](rulings_2026_09_08_local_runner_rearm_1313.md), [rulings_2026_09_09_serve_completion_bound_1313d.md](rulings_2026_09_09_serve_completion_bound_1313d.md) |
| `1265-pb-3` | [rulings_2026_09_06_flow_binding_start_contract_789.md](rulings_2026_09_06_flow_binding_start_contract_789.md), [rulings_2026_09_08_local_runner_rearm_1313.md](rulings_2026_09_08_local_runner_rearm_1313.md) |
| `1265-pb-5` | [rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md](rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md) |
| `1265-pb-6` | [bench_flow_first_measurement_2026_09_04.md](bench_flow_first_measurement_2026_09_04.md) |
| `1265-pb-8` | [rulings_2026_09_04_flow_w1_runner_seam_1265.md](rulings_2026_09_04_flow_w1_runner_seam_1265.md), [rulings_2026_09_24_flow_waves_v018_fw1.md](rulings_2026_09_24_flow_waves_v018_fw1.md) |
| `1265-pc-2` | [bench_flow_w1e_anchored_reader_2026_09_06.md](bench_flow_w1e_anchored_reader_2026_09_06.md), [rulings_2026_09_06_flow_snapshot_interval_1265.md](rulings_2026_09_06_flow_snapshot_interval_1265.md), [rulings_2026_09_09_flow_activation_seq_1316c1.md](rulings_2026_09_09_flow_activation_seq_1316c1.md) |
| `1265-pc-3` | [rulings_2026_09_04_flow_w1_map_scale_1265.md](rulings_2026_09_04_flow_w1_map_scale_1265.md) |
| `1265-pw-2` | [rulings_2026_09_24_flow_waves_v018_fw1.md](rulings_2026_09_24_flow_waves_v018_fw1.md) |
| `1265-pw-3` | [rulings_2026_09_04_flow_w3_performers_1265.md](rulings_2026_09_04_flow_w3_performers_1265.md), [rulings_2026_09_24_flow_waves_v018_fw1.md](rulings_2026_09_24_flow_waves_v018_fw1.md) |
| `1266-a` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) |
| `1269-q1` | [rulings_2026_09_05_xap_queue.md](rulings_2026_09_05_xap_queue.md) |
| `1272-q1` | [rulings_2026_09_05_xap_queue.md](rulings_2026_09_05_xap_queue.md) |
| `128-bit` | [partition_I5_stream20_erasure.md](partition_I5_stream20_erasure.md), [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md), [rulings_2026_09_04_flow_w1_runner_seam_1265.md](rulings_2026_09_04_flow_w1_runner_seam_1265.md) |
| `128-cbc` | [rulings_2026_09_11_saml_xml_encryption_1400_1401.md](rulings_2026_09_11_saml_xml_encryption_1400_1401.md) |
| `128-gcm` | [rulings_2026_09_11_saml_xml_encryption_1400_1401.md](rulings_2026_09_11_saml_xml_encryption_1400_1401.md) |
| `128-hex` | [partition_I5_stream4_xsp.md](partition_I5_stream4_xsp.md) |
| `128-is-not` | [rulings_2026_09_04_pipeline_rows_on_timeout_1075.md](rulings_2026_09_04_pipeline_rows_on_timeout_1075.md) |
| `1294-a` | [rulings_2026_09_09_xap_on_intent_handlers_1294.md](rulings_2026_09_09_xap_on_intent_handlers_1294.md), [rulings_2026_09_19_cited_ids_without_a_page_1447.md](rulings_2026_09_19_cited_ids_without_a_page_1447.md) |
| `1294-a2` | [rulings_2026_09_09_xap_on_intent_handlers_1294.md](rulings_2026_09_09_xap_on_intent_handlers_1294.md) |
| `1294-b` | [rulings_2026_09_09_xap_on_intent_handlers_1294.md](rulings_2026_09_09_xap_on_intent_handlers_1294.md), [rulings_2026_09_19_cited_ids_without_a_page_1447.md](rulings_2026_09_19_cited_ids_without_a_page_1447.md) |
| `1294-c` | [rulings_2026_09_09_xap_on_intent_handlers_1294.md](rulings_2026_09_09_xap_on_intent_handlers_1294.md) |
| `1294-d` | [rulings_2026_09_09_xap_on_intent_handlers_1294.md](rulings_2026_09_09_xap_on_intent_handlers_1294.md) |
| `1294-e` | [rulings_2026_09_09_xap_on_intent_handlers_1294.md](rulings_2026_09_09_xap_on_intent_handlers_1294.md) |
| `1294-f` | [rulings_2026_09_09_xap_on_intent_handlers_1294.md](rulings_2026_09_09_xap_on_intent_handlers_1294.md), [rulings_2026_09_19_cited_ids_without_a_page_1447.md](rulings_2026_09_19_cited_ids_without_a_page_1447.md) |
| `1294-g` | [rulings_2026_09_09_xap_on_intent_handlers_1294.md](rulings_2026_09_09_xap_on_intent_handlers_1294.md) |
| `1294-h` | [rulings_2026_09_09_xap_on_intent_handlers_1294.md](rulings_2026_09_09_xap_on_intent_handlers_1294.md) |
| `1308-cg-2` | [rulings_2026_09_05_grammar_expression_env.md](rulings_2026_09_05_grammar_expression_env.md) |
| `1308-cg-5` | [rulings_2026_09_05_grammar_expression_env.md](rulings_2026_09_05_grammar_expression_env.md) |
| `1308-cg-n` | [rulings_2026_09_05_constraint_grammar_1308.md](rulings_2026_09_05_constraint_grammar_1308.md) |
| `1310-e` | [rulings_2026_09_09_xap_correction_taxonomy_1310.md](rulings_2026_09_09_xap_correction_taxonomy_1310.md), [rulings_2026_09_19_cited_ids_without_a_page_1447.md](rulings_2026_09_19_cited_ids_without_a_page_1447.md) |
| `1314-c` | [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) |
| `1324-sk-1` | [rulings_2026_09_06_sched_missed_one_shot_1324.md](rulings_2026_09_06_sched_missed_one_shot_1324.md) |
| `1324-sk-2` | [rulings_2026_09_06_sched_missed_one_shot_1324.md](rulings_2026_09_06_sched_missed_one_shot_1324.md) |
| `1329-a` | [rulings_2026_09_16_integrator_decisions.md](rulings_2026_09_16_integrator_decisions.md) |
| `1349-a` | [rulings_2026_09_09_diagram_node_id_ordinals_1349.md](rulings_2026_09_09_diagram_node_id_ordinals_1349.md) |
| `1349-b` | [rulings_2026_09_09_diagram_node_id_ordinals_1349.md](rulings_2026_09_09_diagram_node_id_ordinals_1349.md) |
| `1349-c` | [rulings_2026_09_09_diagram_node_id_ordinals_1349.md](rulings_2026_09_09_diagram_node_id_ordinals_1349.md) |
| `1358-f` | [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) |
| `1359-a` | [rulings_2026_09_16_integrator_decisions.md](rulings_2026_09_16_integrator_decisions.md) |
| `1359-b` | [rulings_2026_09_16_integrator_decisions.md](rulings_2026_09_16_integrator_decisions.md) |
| `1363-a` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) |
| `1383-a` | [rulings_2026_09_10_scim_attribute_projection_1103.md](rulings_2026_09_10_scim_attribute_projection_1103.md) |
| `1386-b` | [rulings_2026_09_18_owner_decisions_1640z.md](rulings_2026_09_18_owner_decisions_1640z.md) |
| `1406-a` | [rulings_2026_09_11_saml_binding_1402b_scim_1406b.md](rulings_2026_09_11_saml_binding_1402b_scim_1406b.md) |
| `1409-a` | [rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md](rulings_2026_09_10_lane_s_sso_1394_1397_1399_1404_1408.md), [rulings_2026_09_11_oidc_hardening_1407.md](rulings_2026_09_11_oidc_hardening_1407.md) |
| `1413-b` | [rulings_2026_09_12_audit_sink_1422.md](rulings_2026_09_12_audit_sink_1422.md), [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) |
| `1422-b-1` | [rulings_2026_09_12_audit_sink_1422.md](rulings_2026_09_12_audit_sink_1422.md) |
| `1422-b-2` | [rulings_2026_09_12_audit_sink_1422.md](rulings_2026_09_12_audit_sink_1422.md) |
| `1422-b-3` | [rulings_2026_09_12_audit_sink_1422.md](rulings_2026_09_12_audit_sink_1422.md) |
| `1427-b` | [rulings_2026_09_12_ring_legible_tree_1427.md](rulings_2026_09_12_ring_legible_tree_1427.md) |
| `1427-c` | [rulings_2026_09_12_ring_legible_tree_1427.md](rulings_2026_09_12_ring_legible_tree_1427.md), [rulings_2026_09_18_owner_decisions_2100z.md](rulings_2026_09_18_owner_decisions_2100z.md) |
| `1427-d` | [rulings_2026_09_12_ring_legible_tree_1427.md](rulings_2026_09_12_ring_legible_tree_1427.md) |
| `1427-e` | [rulings_2026_09_12_ring_legible_tree_1427.md](rulings_2026_09_12_ring_legible_tree_1427.md), [rulings_2026_09_13_incremental_sync_1434.md](rulings_2026_09_13_incremental_sync_1434.md), [rulings_2026_09_18_owner_decisions_1620z.md](rulings_2026_09_18_owner_decisions_1620z.md) |
| `1427-f` | [rulings_2026_09_12_ring_legible_tree_1427.md](rulings_2026_09_12_ring_legible_tree_1427.md) |
| `1427-g` | [rulings_2026_09_12_ring_legible_tree_1427.md](rulings_2026_09_12_ring_legible_tree_1427.md), [rulings_2026_09_15_file_surface_placement_int18.md](rulings_2026_09_15_file_surface_placement_int18.md) |
| `1427-h` | [rulings_2026_09_12_ring_legible_tree_1427.md](rulings_2026_09_12_ring_legible_tree_1427.md) |
| `1427-i` | [rulings_2026_09_12_ring_legible_tree_1427.md](rulings_2026_09_12_ring_legible_tree_1427.md), [rulings_2026_09_21_repo_split_1589.md](rulings_2026_09_21_repo_split_1589.md), [rulings_2026_09_23_x_graduation_d45a.md](rulings_2026_09_23_x_graduation_d45a.md) |
| `1433-a` | [rulings_2026_09_13_fmt_perf_1433.md](rulings_2026_09_13_fmt_perf_1433.md) |
| `1433-b` | [rulings_2026_09_13_fmt_perf_1433.md](rulings_2026_09_13_fmt_perf_1433.md) |
| `1433-c` | [rulings_2026_09_13_fmt_perf_1433.md](rulings_2026_09_13_fmt_perf_1433.md) |
| `1446-b` | [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) |
| `1448-a` | [rulings_2026_09_12_integrator_decisions.md](rulings_2026_09_12_integrator_decisions.md), [rulings_2026_09_15_integrator_decisions_int15.md](rulings_2026_09_15_integrator_decisions_int15.md) |
| `1453-id` | [rulings_2026_09_15_integrator_decisions_int15.md](rulings_2026_09_15_integrator_decisions_int15.md) |
| `1478-a` | [rulings_2026_09_15_int13_downstream_requests.md](rulings_2026_09_15_int13_downstream_requests.md) |
| `1494-a` | [rulings_2026_09_15_int13_downstream_requests.md](rulings_2026_09_15_int13_downstream_requests.md), [rulings_2026_09_17_integrator_decisions.md](rulings_2026_09_17_integrator_decisions.md) |
| `170-cfg` | [rulings_2026_09_09_diagram_node_id_ordinals_1349.md](rulings_2026_09_09_diagram_node_id_ordinals_1349.md) |
| `171-seq-mid` | [rulings_2026_09_08_let_cascade_lint_1170.md](rulings_2026_09_08_let_cascade_lint_1170.md), [rulings_2026_09_08_seq4_pin_page_sync_1170.md](rulings_2026_09_08_seq4_pin_page_sync_1170.md) |
| `172-seq` | [rulings_2026_08_26_wasm_eval_sweep.md](rulings_2026_08_26_wasm_eval_sweep.md), [rulings_2026_09_08_let_cascade_lint_1170.md](rulings_2026_09_08_let_cascade_lint_1170.md), [rulings_2026_09_08_seq4_pin_page_sync_1170.md](rulings_2026_09_08_seq4_pin_page_sync_1170.md) |
| `182-cpu-min` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) |
| `191-map` | [rulings_2026_09_10_doc_top_postfix_ascription_1361.md](rulings_2026_09_10_doc_top_postfix_ascription_1361.md) |
| `192-cbc` | [rulings_2026_09_11_saml_xml_encryption_1400_1401.md](rulings_2026_09_11_saml_xml_encryption_1400_1401.md) |
| `192-map` | [rulings_2026_09_09_diagram_node_id_ordinals_1349.md](rulings_2026_09_09_diagram_node_id_ordinals_1349.md) |
| `2026-mm` | [rulings_2026_09_09_xap_correction_taxonomy_1310.md](rulings_2026_09_09_xap_correction_taxonomy_1310.md) |
| `2026-vs` | [rulings_2026_09_09_flow_activation_seq_1316c1.md](rulings_2026_09_09_flow_activation_seq_1316c1.md) |
| `256-cbc` | [rulings_2026_09_11_saml_xml_encryption_1400_1401.md](rulings_2026_09_11_saml_xml_encryption_1400_1401.md) |
| `256-gcm` | [rulings_2026_09_11_saml_xml_encryption_1400_1401.md](rulings_2026_09_11_saml_xml_encryption_1400_1401.md), [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) |
| `587-era` | [rulings_2026_08_24_0170_campaign.md](rulings_2026_08_24_0170_campaign.md) |
| `703-a` | [partition_I5_stream16_shape.md](partition_I5_stream16_shape.md) |
| `728-ck-1` | [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md), [rulings_2026_09_08_flow_connector_seam_1334.md](rulings_2026_09_08_flow_connector_seam_1334.md) |
| `728-ck-10` | [rulings_2026_09_06_connector_open_items_728.md](rulings_2026_09_06_connector_open_items_728.md) |
| `728-ck-2` | [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md) |
| `728-ck-3` | [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md), [rulings_2026_09_06_flow_resolver_idempotent_789.md](rulings_2026_09_06_flow_resolver_idempotent_789.md) |
| `728-ck-4` | [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md) |
| `728-ck-5` | [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md) |
| `728-ck-6` | [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md) |
| `728-ck-7` | [rulings_2026_09_06_connector_open_items_728.md](rulings_2026_09_06_connector_open_items_728.md) |
| `728-ck-8` | [rulings_2026_09_06_connector_open_items_728.md](rulings_2026_09_06_connector_open_items_728.md), [rulings_2026_09_08_flow_connector_seam_1334.md](rulings_2026_09_08_flow_connector_seam_1334.md), [rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md](rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md) |
| `728-ck-9` | [rulings_2026_09_06_connector_open_items_728.md](rulings_2026_09_06_connector_open_items_728.md) |
| `789-wf-0a` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) |
| `789-wf-14a` | [rulings_2026_09_03_workflow_789.md](rulings_2026_09_03_workflow_789.md) |
| `789-wf-18a` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md), [rulings_2026_09_08_flow_connector_seam_1334.md](rulings_2026_09_08_flow_connector_seam_1334.md), [rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md](rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md) |
| `789-wf-19a` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) |
| `789-wf-20a` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) |
| `789-wf-21a` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) |
| `789-wf-22a` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) |
| `789-wf-23a` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) |
| `789-wf-24a` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md), [rulings_2026_09_08_flow_connector_seam_1334.md](rulings_2026_09_08_flow_connector_seam_1334.md) |
| `789-wf-25a` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md) |
| `789-wf-26a` | [rulings_2026_09_05_flow_vocabulary_round2_789.md](rulings_2026_09_05_flow_vocabulary_round2_789.md), [rulings_2026_09_08_flow_commit_retry_1365.md](rulings_2026_09_08_flow_commit_retry_1365.md), [rulings_2026_09_08_flow_connector_seam_1334.md](rulings_2026_09_08_flow_connector_seam_1334.md), [rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md](rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md) |
| `789-wf-27a` | [rulings_2026_09_06_flow_liveness_and_standalone_runner_789.md](rulings_2026_09_06_flow_liveness_and_standalone_runner_789.md), [rulings_2026_09_06_sched_missed_one_shot_1324.md](rulings_2026_09_06_sched_missed_one_shot_1324.md), [rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md](rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md), [rulings_2026_09_08_flow_serve_wf28.md](rulings_2026_09_08_flow_serve_wf28.md), [rulings_2026_09_08_local_runner_rearm_1313.md](rulings_2026_09_08_local_runner_rearm_1313.md), [rulings_2026_09_08_sched_wall_clock_1358.md](rulings_2026_09_08_sched_wall_clock_1358.md) |
| `789-wf-28` | [rulings_2026_09_08_flow_connector_seam_1334.md](rulings_2026_09_08_flow_connector_seam_1334.md) |
| `789-wf-28a` | [rulings_2026_09_06_flow_liveness_and_standalone_runner_789.md](rulings_2026_09_06_flow_liveness_and_standalone_runner_789.md), [rulings_2026_09_08_flow_serve_wf28.md](rulings_2026_09_08_flow_serve_wf28.md), [rulings_2026_09_08_local_runner_rearm_1313.md](rulings_2026_09_08_local_runner_rearm_1313.md), [rulings_2026_09_09_serve_completion_bound_1313d.md](rulings_2026_09_09_serve_completion_bound_1313d.md) |
| `789-wf-28b` | [rulings_2026_09_06_flow_binding_vocabulary_789.md](rulings_2026_09_06_flow_binding_vocabulary_789.md), [rulings_2026_09_09_serve_completion_bound_1313d.md](rulings_2026_09_09_serve_completion_bound_1313d.md) |
| `789-wf-29a` | [rulings_2026_09_06_flow_binding_vocabulary_789.md](rulings_2026_09_06_flow_binding_vocabulary_789.md) |
| `789-wf-30a` | [rulings_2026_09_06_flow_binding_start_contract_789.md](rulings_2026_09_06_flow_binding_start_contract_789.md) |
| `789-wf-31a` | [rulings_2026_09_06_flow_binding_start_contract_789.md](rulings_2026_09_06_flow_binding_start_contract_789.md) |
| `789-wf-32` | [rulings_2026_09_08_flow_serve_wf28.md](rulings_2026_09_08_flow_serve_wf28.md) |
| `789-wf-32a` | [rulings_2026_09_06_flow_binding_start_contract_789.md](rulings_2026_09_06_flow_binding_start_contract_789.md) |
| `789-wf-33a` | [rulings_2026_09_06_flow_binding_start_contract_789.md](rulings_2026_09_06_flow_binding_start_contract_789.md) |
| `789-wf-34a` | [rulings_2026_09_06_flow_binding_start_contract_789.md](rulings_2026_09_06_flow_binding_start_contract_789.md) |
| `789-wf-35a` | [rulings_2026_09_06_flow_binding_row_shape_789.md](rulings_2026_09_06_flow_binding_row_shape_789.md) |
| `789-wf-36a` | [rulings_2026_09_06_flow_binding_row_shape_789.md](rulings_2026_09_06_flow_binding_row_shape_789.md) |
| `789-wf-37a` | [rulings_2026_09_06_flow_binding_row_shape_789.md](rulings_2026_09_06_flow_binding_row_shape_789.md) |
| `789-wf-38` | [rulings_2026_09_08_flow_connector_seam_1334.md](rulings_2026_09_08_flow_connector_seam_1334.md) |
| `789-wf-38a` | [rulings_2026_09_06_flow_resolver_idempotent_789.md](rulings_2026_09_06_flow_resolver_idempotent_789.md) |
| `abi-14` | [partition_I1_rebless.md](partition_I1_rebless.md) |
| `aes-256` | [rulings_2026_09_11_saml_xml_encryption_1400_1401.md](rulings_2026_09_11_saml_xml_encryption_1400_1401.md), [rulings_2026_09_26_owner_decisions_designs_l26_l29.md](rulings_2026_09_26_owner_decisions_designs_l26_l29.md) |
| `af-1` | [partition_I5_audit.md](partition_I5_audit.md), [partition_I5_exit_review_packet.md](partition_I5_exit_review_packet.md), [partition_I5_stream17_runtime.md](partition_I5_stream17_runtime.md) |
| `af-10` | [partition_I5_audit.md](partition_I5_audit.md), [partition_corpus_audit.md](partition_corpus_audit.md) |
| `af-11` | [partition_I5_audit.md](partition_I5_audit.md), [partition_I5_exit_review_packet.md](partition_I5_exit_review_packet.md) |
| `af-12` | [batch_796_post_gate_defects.md](batch_796_post_gate_defects.md), [partition_I5_audit.md](partition_I5_audit.md) |
| `af-13` | [partition_I5_audit.md](partition_I5_audit.md) |
| `af-14` | [partition_I5_audit.md](partition_I5_audit.md) |
| `af-14c` | [partition_I5_audit.md](partition_I5_audit.md) |
| `af-1a` | [partition_I5_audit.md](partition_I5_audit.md) |
| `af-1b` | [partition_I5_audit.md](partition_I5_audit.md) |
| `af-1c` | [partition_I5_audit.md](partition_I5_audit.md) |
| `af-2` | [partition_I5_audit.md](partition_I5_audit.md), [partition_I5_exit_review_packet.md](partition_I5_exit_review_packet.md), [partition_I5_stream17_runtime.md](partition_I5_stream17_runtime.md) |
| `af-2a` | [partition_I5_audit.md](partition_I5_audit.md), [partition_I5_exit_review_packet.md](partition_I5_exit_review_packet.md) |
| `af-2b` | [partition_I5_audit.md](partition_I5_audit.md) |
| `af-2c` | [partition_I5_audit.md](partition_I5_audit.md) |
| `af-2d` | [partition_I5_audit.md](partition_I5_audit.md) |
| `af-2e` | [partition_I5_audit.md](partition_I5_audit.md) |
| `af-3` | [partition_I5_audit.md](partition_I5_audit.md), [partition_I5_exit_review_packet.md](partition_I5_exit_review_packet.md) |
| `af-4` | [partition_I5_audit.md](partition_I5_audit.md) |
| `af-5` | [partition_I5_audit.md](partition_I5_audit.md) |
| `af-6` | [partition_I5_audit.md](partition_I5_audit.md) |
| `af-7` | [partition_I5_audit.md](partition_I5_audit.md), [partition_I5_exit_review_packet.md](partition_I5_exit_review_packet.md) |
| `af-8` | [partition_I5_audit.md](partition_I5_audit.md) |
| `af-9` | [partition_I5_audit.md](partition_I5_audit.md), [partition_corpus_audit.md](partition_corpus_audit.md) |
| `af-9a` | [partition_I5_audit.md](partition_I5_audit.md) |
| `af-9b` | [partition_I5_audit.md](partition_I5_audit.md) |
| `arch-0916` | [rulings_2026_09_16_integrator_decisions.md](rulings_2026_09_16_integrator_decisions.md), [rulings_2026_09_18_owner_decisions_1640z.md](rulings_2026_09_18_owner_decisions_1640z.md) |
| `bf-1` | [partition_I2_extraction.md](partition_I2_extraction.md), [partition_I5_stream22_cleanroom.md](partition_I5_stream22_cleanroom.md) |
| `choice-1` | [rulings_2026_08_21_array_separator.md](rulings_2026_08_21_array_separator.md), [rulings_2026_09_09_fmt_fingerprint_underscores_1347.md](rulings_2026_09_09_fmt_fingerprint_underscores_1347.md) |
| `ck-4b` | [rulings_2026_09_14_connector_ingest_1430g.md](rulings_2026_09_14_connector_ingest_1430g.md), [rulings_2026_09_19_cited_ids_without_a_page_1447.md](rulings_2026_09_19_cited_ids_without_a_page_1447.md) |
| `client-2` | [rulings_2026_09_15_int13_downstream_requests.md](rulings_2026_09_15_int13_downstream_requests.md) |
| `clock-1` | [rulings_2026_09_24_flow_waves_v018_fw1.md](rulings_2026_09_24_flow_waves_v018_fw1.md) |
| `crc-32` | [rulings_2026_08_20_diagram_renderer.md](rulings_2026_08_20_diagram_renderer.md), [rulings_2026_08_20_diagram_svg_capability.md](rulings_2026_08_20_diagram_svg_capability.md), [rulings_2026_08_29_tar_module_1084.md](rulings_2026_08_29_tar_module_1084.md) |
| `cve-2011` | [rulings_2026_09_12_net_tls_accept_wrap_1421.md](rulings_2026_09_12_net_tls_accept_wrap_1421.md) |
| `cxf-3` | [rulings_2026_09_17_bug_batches_ord2.md](rulings_2026_09_17_bug_batches_ord2.md), [rulings_2026_09_17_cx_first_1522.md](rulings_2026_09_17_cx_first_1522.md), [rulings_2026_09_17_diagnostics_audit_1522.md](rulings_2026_09_17_diagnostics_audit_1522.md), [rulings_2026_09_17_owner_decisions_2202z.md](rulings_2026_09_17_owner_decisions_2202z.md), [rulings_2026_09_17_probe_scoping_1061.md](rulings_2026_09_17_probe_scoping_1061.md), [rulings_2026_09_17_trap_batches.md](rulings_2026_09_17_trap_batches.md), [rulings_2026_09_18_owner_decisions_0200z.md](rulings_2026_09_18_owner_decisions_0200z.md), [rulings_2026_09_18_owner_decisions_0440z.md](rulings_2026_09_18_owner_decisions_0440z.md) |
| `cxf-5` | [rulings_2026_09_17_cx_first_1522.md](rulings_2026_09_17_cx_first_1522.md), [rulings_2026_09_17_owner_decisions_2202z.md](rulings_2026_09_17_owner_decisions_2202z.md), [rulings_2026_09_18_owner_decisions_0155z.md](rulings_2026_09_18_owner_decisions_0155z.md), [rulings_2026_09_18_owner_decisions_0235z.md](rulings_2026_09_18_owner_decisions_0235z.md), [rulings_2026_09_18_owner_decisions_0440z.md](rulings_2026_09_18_owner_decisions_0440z.md) |
| `cxf-6` | [rulings_2026_09_17_bug_batches_ord2.md](rulings_2026_09_17_bug_batches_ord2.md), [rulings_2026_09_17_cx_first_1522.md](rulings_2026_09_17_cx_first_1522.md), [rulings_2026_09_17_probe_scoping_1061.md](rulings_2026_09_17_probe_scoping_1061.md), [rulings_2026_09_18_owner_decisions_0235z.md](rulings_2026_09_18_owner_decisions_0235z.md), [rulings_2026_09_18_owner_decisions_0250z.md](rulings_2026_09_18_owner_decisions_0250z.md) |
| `cxf-7` | [rulings_2026_09_17_bug_batches_ord2.md](rulings_2026_09_17_bug_batches_ord2.md), [rulings_2026_09_17_cx_first_1522.md](rulings_2026_09_17_cx_first_1522.md), [rulings_2026_09_18_owner_decisions_0200z.md](rulings_2026_09_18_owner_decisions_0200z.md), [rulings_2026_09_18_owner_decisions_0250z.md](rulings_2026_09_18_owner_decisions_0250z.md) |
| `dist-1` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) |
| `dist-2` | [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md), [rulings_2026_09_06_connector_is_a_feature_728.md](rulings_2026_09_06_connector_is_a_feature_728.md) |
| `docs-3` | [rulings_2026_09_27_owner_decisions_l46_l50.md](rulings_2026_09_27_owner_decisions_l46_l50.md) |
| `docs-4` | [rulings_2026_09_28_integrator_decisions_l64_l70.md](rulings_2026_09_28_integrator_decisions_l64_l70.md), [rulings_2026_09_28_owner_decisions_l85.md](rulings_2026_09_28_owner_decisions_l85.md) |
| `dr-2` | [rulings_2026_08_20_diagram_renderer.md](rulings_2026_08_20_diagram_renderer.md) |
| `dr-2a` | [rulings_2026_08_20_diagram_renderer.md](rulings_2026_08_20_diagram_renderer.md), [rulings_2026_08_20_diagram_wave3.md](rulings_2026_08_20_diagram_wave3.md) |
| `dr-3` | [rulings_2026_08_20_diagram_renderer.md](rulings_2026_08_20_diagram_renderer.md), [rulings_2026_08_20_diagram_svg_capability.md](rulings_2026_08_20_diagram_svg_capability.md) |
| `dr-4` | [rulings_2026_08_20_diagram_renderer.md](rulings_2026_08_20_diagram_renderer.md) |
| `dr-4a` | [rulings_2026_08_20_diagram_renderer.md](rulings_2026_08_20_diagram_renderer.md), [rulings_2026_08_21_diagram_capabilities.md](rulings_2026_08_21_diagram_capabilities.md), [rulings_2026_08_26_seq_classification.md](rulings_2026_08_26_seq_classification.md) |
| `dr-6` | [rulings_2026_08_20_diagram_renderer.md](rulings_2026_08_20_diagram_renderer.md), [rulings_2026_08_20_diagram_wave3.md](rulings_2026_08_20_diagram_wave3.md) |
| `dr-7` | [rulings_2026_08_20_diagram_renderer.md](rulings_2026_08_20_diagram_renderer.md), [rulings_2026_08_20_diagram_wave3.md](rulings_2026_08_20_diagram_wave3.md), [rulings_2026_08_21_diagram_capabilities.md](rulings_2026_08_21_diagram_capabilities.md) |
| `dr-9` | [rulings_2026_08_20_diagram_renderer.md](rulings_2026_08_20_diagram_renderer.md), [rulings_2026_08_20_diagram_wave3.md](rulings_2026_08_20_diagram_wave3.md) |
| `dr-9a` | [rulings_2026_08_20_diagram_renderer.md](rulings_2026_08_20_diagram_renderer.md) |
| `ds-10` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-12a` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-12b` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-12c` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-12d` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-14` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-15` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-16` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-18a` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-18b` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-18c` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-18d` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-18e` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-18f` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-18g` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-18h` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-19a` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-19b` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-19c` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-19d` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-1a` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-2a` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-3a` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-4` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-4a` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-5` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-5a` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-6` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-6a` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-7` | [rulings_2026_09_04_view_grammar.md](rulings_2026_09_04_view_grammar.md) |
| `ds-7a` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-8a` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `ds-9a` | [rulings_2026_08_20_designer_studio.md](rulings_2026_08_20_designer_studio.md) |
| `edl-1a` | [rulings_2026_08_21_diagram_vector_data.md](rulings_2026_08_21_diagram_vector_data.md), [rulings_2026_08_21_table_image.md](rulings_2026_08_21_table_image.md), [rulings_2026_08_22_gate_hygiene.md](rulings_2026_08_22_gate_hygiene.md) |
| `ga-1a` | [rulings_2026_08_20_guest_attach.md](rulings_2026_08_20_guest_attach.md) |
| `ga-1b` | [rulings_2026_08_20_guest_attach.md](rulings_2026_08_20_guest_attach.md) |
| `gql-1` | [rulings_2026_09_12_integrator_decisions.md](rulings_2026_09_12_integrator_decisions.md), [rulings_2026_09_14_connector_transports_1430c.md](rulings_2026_09_14_connector_transports_1430c.md) |
| `half-1` | [rulings_2026_09_16_integrator_decisions.md](rulings_2026_09_16_integrator_decisions.md) |
| `http-429` | [partition_remediation_register.md](partition_remediation_register.md) |
| `ieee-754` | [partition_I5_stream17_runtime.md](partition_I5_stream17_runtime.md) |
| `imap-1` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) |
| `imap-2` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) |
| `imap-3` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) |
| `imap-4` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) |
| `imap-5` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) |
| `int-10` | [rulings_2026_09_12_integrator_decisions.md](rulings_2026_09_12_integrator_decisions.md), [rulings_2026_09_16_run_selection_run1.md](rulings_2026_09_16_run_selection_run1.md), [rulings_2026_09_28_owner_direction_cicd1.md](rulings_2026_09_28_owner_direction_cicd1.md) |
| `int-11` | [rulings_2026_09_12_integrator_decisions.md](rulings_2026_09_12_integrator_decisions.md) |
| `int-12` | [rulings_2026_09_12_integrator_decisions.md](rulings_2026_09_12_integrator_decisions.md) |
| `int-2` | [rulings_2026_09_12_audit_sink_1422.md](rulings_2026_09_12_audit_sink_1422.md), [rulings_2026_09_12_fmt_1384_1391.md](rulings_2026_09_12_fmt_1384_1391.md), [rulings_2026_09_12_integrator_decisions.md](rulings_2026_09_12_integrator_decisions.md), [rulings_2026_09_12_net_tls_accept_wrap_1421.md](rulings_2026_09_12_net_tls_accept_wrap_1421.md), [rulings_2026_09_13_mail_hosting_deferred_connector_line_1085e.md](rulings_2026_09_13_mail_hosting_deferred_connector_line_1085e.md), [rulings_2026_09_15_default_in_campaign_int17.md](rulings_2026_09_15_default_in_campaign_int17.md), [rulings_2026_09_15_int13_downstream_requests.md](rulings_2026_09_15_int13_downstream_requests.md), [rulings_2026_09_15_owner_decisions_1145z.md](rulings_2026_09_15_owner_decisions_1145z.md) |
| `int-21` | [rulings_2026_09_16_integrator_decisions.md](rulings_2026_09_16_integrator_decisions.md), [rulings_2026_09_19_owner_decisions_0445z.md](rulings_2026_09_19_owner_decisions_0445z.md), [rulings_2026_09_19_owner_decisions_0505z.md](rulings_2026_09_19_owner_decisions_0505z.md) |
| `int-22` | [rulings_2026_09_16_integrator_decisions.md](rulings_2026_09_16_integrator_decisions.md) |
| `int-4` | [rulings_2026_09_12_integrator_decisions.md](rulings_2026_09_12_integrator_decisions.md), [rulings_2026_09_15_owner_decisions_1830z.md](rulings_2026_09_15_owner_decisions_1830z.md) |
| `int-5` | [rulings_2026_09_12_integrator_decisions.md](rulings_2026_09_12_integrator_decisions.md), [rulings_2026_09_13_claude_context_audit.md](rulings_2026_09_13_claude_context_audit.md), [rulings_2026_09_17_bug_batches_ord2.md](rulings_2026_09_17_bug_batches_ord2.md), [rulings_2026_09_19_owner_decisions_0445z.md](rulings_2026_09_19_owner_decisions_0445z.md) |
| `int-6` | [rulings_2026_09_12_integrator_decisions.md](rulings_2026_09_12_integrator_decisions.md), [rulings_2026_09_13_fmt_perf_1433.md](rulings_2026_09_13_fmt_perf_1433.md) |
| `int-7` | [rulings_2026_09_12_integrator_decisions.md](rulings_2026_09_12_integrator_decisions.md) |
| `int-8` | [rulings_2026_09_12_integrator_decisions.md](rulings_2026_09_12_integrator_decisions.md), [rulings_2026_09_16_integrator_decisions.md](rulings_2026_09_16_integrator_decisions.md) |
| `int-9` | [rulings_2026_09_12_integrator_decisions.md](rulings_2026_09_12_integrator_decisions.md), [rulings_2026_09_15_integrator_decisions_int15.md](rulings_2026_09_15_integrator_decisions_int15.md), [rulings_2026_09_16_integrator_decisions.md](rulings_2026_09_16_integrator_decisions.md), [rulings_2026_09_19_owner_decisions_0505z.md](rulings_2026_09_19_owner_decisions_0505z.md) |
| `ir-1` | [rulings_2026_08_19_787_integration.md](rulings_2026_08_19_787_integration.md) |
| `ir-2` | [rulings_2026_08_19_787_integration.md](rulings_2026_08_19_787_integration.md) |
| `ir-3` | [rulings_2026_08_19_787_integration.md](rulings_2026_08_19_787_integration.md) |
| `ir-4` | [rulings_2026_08_19_787_integration.md](rulings_2026_08_19_787_integration.md) |
| `ir-5` | [rulings_2026_08_19_787_integration.md](rulings_2026_08_19_787_integration.md) |
| `ir-6` | [rulings_2026_08_19_787_integration.md](rulings_2026_08_19_787_integration.md) |
| `ir-7` | [rulings_2026_08_19_787_integration.md](rulings_2026_08_19_787_integration.md) |
| `iso-8601` | [partition_I1_rebless.md](partition_I1_rebless.md), [partition_I4_profiles.md](partition_I4_profiles.md), [partition_I5_stream8_bitemporal.md](partition_I5_stream8_bitemporal.md), [rulings_2026_09_11_session_leeway_saml_path_1398.md](rulings_2026_09_11_session_leeway_saml_path_1398.md) |
| `iso-8859` | [audit_2026_08_30_text_format_surface.md](audit_2026_08_30_text_format_surface.md), [rulings_2026_08_30_text_format_residuals.md](rulings_2026_08_30_text_format_residuals.md) |
| `letter-1` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) |
| `letter-2` | [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) |
| `nt-3a` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) |
| `nt-3b` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) |
| `nt-3c` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) |
| `nt-5a` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) |
| `nt-5b` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) |
| `nt-5c` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) |
| `nt-5d` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) |
| `nt-9a` | [rulings_2026_08_26_diagram_arm_escape_1037.md](rulings_2026_08_26_diagram_arm_escape_1037.md), [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) |
| `nt-9b` | [rulings_2026_08_26_diagram_let_node_ids_1036.md](rulings_2026_08_26_diagram_let_node_ids_1036.md), [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) |
| `nt-9c` | [rulings_2026_08_26_diagram_nested_tables_1031.md](rulings_2026_08_26_diagram_nested_tables_1031.md) |
| `ol-1` | [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) |
| `ol-10` | [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) |
| `ol-11` | [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) |
| `ol-12` | [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) |
| `ol-13` | [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) |
| `ol-2` | [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) |
| `ol-3` | [rulings_2026_09_12_integrator_decisions.md](rulings_2026_09_12_integrator_decisions.md), [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) |
| `ol-4` | [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) |
| `ol-5` | [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) |
| `ol-6` | [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) |
| `ol-7` | [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) |
| `ol-8` | [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) |
| `ol-9` | [rulings_2026_09_12_owner_letters_batch.md](rulings_2026_09_12_owner_letters_batch.md) |
| `play-1` | [rulings_2026_09_28_integrator_decisions_l64_l70.md](rulings_2026_09_28_integrator_decisions_l64_l70.md) |
| `pq-1a` | [rulings_2026_08_26_playground_quality_992.md](rulings_2026_08_26_playground_quality_992.md) |
| `pq-1b` | [rulings_2026_08_26_playground_quality_992.md](rulings_2026_08_26_playground_quality_992.md) |
| `pq-4a` | [rulings_2026_08_26_playground_quality_992.md](rulings_2026_08_26_playground_quality_992.md) |
| `pq-5a` | [rulings_2026_08_26_playground_quality_992.md](rulings_2026_08_26_playground_quality_992.md) |
| `pq-9a` | [rulings_2026_08_26_playground_quality_992.md](rulings_2026_08_26_playground_quality_992.md) |
| `rfc-7540` | [rulings_2026_08_20_h2_surface.md](rulings_2026_08_20_h2_surface.md) |
| `ring-1` | [batch_796_post_gate_defects.md](batch_796_post_gate_defects.md), [partition_I3_ring12_split.md](partition_I3_ring12_split.md) |
| `ring-2` | [partition_I3_ring12_split.md](partition_I3_ring12_split.md) |
| `rs-10` | [rulings_2026_09_21_repo_split_1589.md](rulings_2026_09_21_repo_split_1589.md) |
| `rs-11` | [rulings_2026_09_21_repo_split_1589.md](rulings_2026_09_21_repo_split_1589.md), [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) |
| `rs-2` | [rulings_2026_09_21_repo_split_1589.md](rulings_2026_09_21_repo_split_1589.md), [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) |
| `rs-3` | [rulings_2026_09_21_repo_split_1589.md](rulings_2026_09_21_repo_split_1589.md), [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md), [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) |
| `rs-4` | [rulings_2026_09_21_repo_split_1589.md](rulings_2026_09_21_repo_split_1589.md), [rulings_2026_09_23_x_graduation_d45a.md](rulings_2026_09_23_x_graduation_d45a.md) |
| `rs-5` | [rulings_2026_09_21_repo_split_1589.md](rulings_2026_09_21_repo_split_1589.md), [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md), [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) |
| `rs-6` | [rulings_2026_09_21_repo_split_1589.md](rulings_2026_09_21_repo_split_1589.md), [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md) |
| `rs-7` | [rulings_2026_09_21_repo_split_1589.md](rulings_2026_09_21_repo_split_1589.md), [rulings_2026_09_22_repo_split_followups.md](rulings_2026_09_22_repo_split_followups.md), [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) |
| `rs-8` | [rulings_2026_09_21_repo_split_1589.md](rulings_2026_09_21_repo_split_1589.md) |
| `rs-9` | [rulings_2026_09_21_repo_split_1589.md](rulings_2026_09_21_repo_split_1589.md), [rulings_2026_09_23_spec_sentence_letters.md](rulings_2026_09_23_spec_sentence_letters.md) |
| `rsa-2048` | [rulings_2026_09_05_certificate_key_1287.md](rulings_2026_09_05_certificate_key_1287.md) |
| `sea-1a` | [rulings_2026_08_20_schema_evolution_automation.md](rulings_2026_08_20_schema_evolution_automation.md) |
| `sea-1b` | [rulings_2026_08_20_schema_evolution_automation.md](rulings_2026_08_20_schema_evolution_automation.md) |
| `sea-1c` | [rulings_2026_08_20_schema_evolution_automation.md](rulings_2026_08_20_schema_evolution_automation.md) |
| `sea-1d` | [rulings_2026_08_20_schema_evolution_automation.md](rulings_2026_08_20_schema_evolution_automation.md), [rulings_2026_09_01_adoption_campaign.md](rulings_2026_09_01_adoption_campaign.md) |
| `sea-1e` | [rulings_2026_08_20_schema_evolution_automation.md](rulings_2026_08_20_schema_evolution_automation.md) |
| `sea-1f` | [rulings_2026_08_20_schema_evolution_automation.md](rulings_2026_08_20_schema_evolution_automation.md) |
| `sea-1g` | [rulings_2026_08_20_schema_evolution_automation.md](rulings_2026_08_20_schema_evolution_automation.md) |
| `sha-256` | [partition_audit_spec_inventory.md](partition_audit_spec_inventory.md), [rulings_2026_08_29_saml_sp_1091.md](rulings_2026_08_29_saml_sp_1091.md) |
| `sha-384` | [rulings_2026_08_28_jose_completeness_1093.md](rulings_2026_08_28_jose_completeness_1093.md) |
| `sha-512` | [rulings_2026_08_28_jose_completeness_1093.md](rulings_2026_08_28_jose_completeness_1093.md) |
| `silent-1` | [rulings_2026_09_17_diagnostics_audit_1522.md](rulings_2026_09_17_diagnostics_audit_1522.md), [rulings_2026_09_18_owner_decisions_0200z.md](rulings_2026_09_18_owner_decisions_0200z.md) |
| `silent-2` | [rulings_2026_09_17_diagnostics_audit_1522.md](rulings_2026_09_17_diagnostics_audit_1522.md), [rulings_2026_09_18_owner_decisions_0200z.md](rulings_2026_09_18_owner_decisions_0200z.md) |
| `silent-3` | [rulings_2026_09_17_diagnostics_audit_1522.md](rulings_2026_09_17_diagnostics_audit_1522.md), [rulings_2026_09_18_owner_decisions_0200z.md](rulings_2026_09_18_owner_decisions_0200z.md) |
| `silent-4` | [rulings_2026_09_17_diagnostics_audit_1522.md](rulings_2026_09_17_diagnostics_audit_1522.md), [rulings_2026_09_18_owner_decisions_0200z.md](rulings_2026_09_18_owner_decisions_0200z.md) |
| `silent-5` | [rulings_2026_09_17_diagnostics_audit_1522.md](rulings_2026_09_17_diagnostics_audit_1522.md) |
| `smtp-1` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) |
| `smtp-2` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) |
| `smtp-3` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) |
| `smtp-4` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) |
| `smtp-5` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) |
| `spawn-1` | [partition_I5_stream22_cleanroom.md](partition_I5_stream22_cleanroom.md) |
| `spf-2a` | [rulings_2026_08_21_supervise_profile_and_python.md](rulings_2026_08_21_supervise_profile_and_python.md) |
| `st-1` | [rulings_2026_08_20_spec_tree_reshape.md](rulings_2026_08_20_spec_tree_reshape.md), [rulings_2026_08_20_studio.md](rulings_2026_08_20_studio.md) |
| `st-1a` | [rulings_2026_08_20_studio.md](rulings_2026_08_20_studio.md) |
| `st-2a` | [rulings_2026_08_20_studio.md](rulings_2026_08_20_studio.md) |
| `st-3a` | [rulings_2026_08_20_studio.md](rulings_2026_08_20_studio.md) |
| `st-4a` | [rulings_2026_08_20_studio.md](rulings_2026_08_20_studio.md) |
| `st-5a` | [rulings_2026_08_20_studio.md](rulings_2026_08_20_studio.md) |
| `st-6a` | [rulings_2026_08_20_studio.md](rulings_2026_08_20_studio.md) |
| `st-7a` | [rulings_2026_08_20_studio.md](rulings_2026_08_20_studio.md) |
| `st-8` | [rulings_2026_08_20_spec_tree_reshape.md](rulings_2026_08_20_spec_tree_reshape.md), [rulings_2026_08_20_studio.md](rulings_2026_08_20_studio.md) |
| `st-8a` | [rulings_2026_08_20_studio.md](rulings_2026_08_20_studio.md) |
| `stream-4` | [partition_I5_stream4_xsp.md](partition_I5_stream4_xsp.md) |
| `sup-1a` | [rulings_2026_08_20_supervise.md](rulings_2026_08_20_supervise.md) |
| `sup-1b` | [rulings_2026_08_20_supervise.md](rulings_2026_08_20_supervise.md) |
| `sup-1c` | [rulings_2026_08_20_supervise.md](rulings_2026_08_20_supervise.md) |
| `sup-1d` | [rulings_2026_08_20_supervise.md](rulings_2026_08_20_supervise.md) |
| `sup-1e` | [rulings_2026_08_20_supervise.md](rulings_2026_08_20_supervise.md) |
| `sup-1f` | [rulings_2026_08_20_supervise.md](rulings_2026_08_20_supervise.md) |
| `sup-1g` | [rulings_2026_08_20_supervise.md](rulings_2026_08_20_supervise.md) |
| `sup-1h` | [rulings_2026_08_20_supervise.md](rulings_2026_08_20_supervise.md) |
| `td-2a` | [rulings_2026_08_26_playground_tree_detail_1001.md](rulings_2026_08_26_playground_tree_detail_1001.md), [rulings_2026_08_26_playground_tree_gate_1049.md](rulings_2026_08_26_playground_tree_gate_1049.md) |
| `td-2b` | [rulings_2026_08_26_playground_tree_detail_1001.md](rulings_2026_08_26_playground_tree_detail_1001.md), [rulings_2026_08_26_playground_tree_gate_1049.md](rulings_2026_08_26_playground_tree_gate_1049.md) |
| `td-2c` | [rulings_2026_08_26_playground_tree_detail_1001.md](rulings_2026_08_26_playground_tree_detail_1001.md), [rulings_2026_08_26_playground_tree_gate_1049.md](rulings_2026_08_26_playground_tree_gate_1049.md) |
| `td-3a` | [rulings_2026_08_26_playground_tree_detail_1001.md](rulings_2026_08_26_playground_tree_detail_1001.md), [rulings_2026_08_26_playground_tree_gate_1049.md](rulings_2026_08_26_playground_tree_gate_1049.md) |
| `td-4a` | [rulings_2026_08_26_playground_tree_detail_1001.md](rulings_2026_08_26_playground_tree_detail_1001.md) |
| `td-6a` | [rulings_2026_08_26_playground_tree_detail_1001.md](rulings_2026_08_26_playground_tree_detail_1001.md) |
| `td-6b` | [rulings_2026_08_26_playground_tree_detail_1001.md](rulings_2026_08_26_playground_tree_detail_1001.md) |
| `tg-4a` | [rulings_2026_08_26_playground_tree_gate_1049.md](rulings_2026_08_26_playground_tree_gate_1049.md) |
| `tg-5a` | [rulings_2026_08_26_playground_tree_gate_1049.md](rulings_2026_08_26_playground_tree_gate_1049.md) |
| `tg-8a` | [rulings_2026_08_26_playground_tree_gate_1049.md](rulings_2026_08_26_playground_tree_gate_1049.md) |
| `utf-16` | [audit_2026_08_30_text_format_surface.md](audit_2026_08_30_text_format_surface.md), [rulings_2026_08_30_text_format_residuals.md](rulings_2026_08_30_text_format_residuals.md) |
| `utf-7` | [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md) |
| `utf-8` | [audit_2026_08_30_text_format_surface.md](audit_2026_08_30_text_format_surface.md), [partition_I1_rebless.md](partition_I1_rebless.md), [partition_I5_stream17_runtime.md](partition_I5_stream17_runtime.md), [rulings_2026_08_20_diagram_svg_capability.md](rulings_2026_08_20_diagram_svg_capability.md), [rulings_2026_08_28_zip_module_1078.md](rulings_2026_08_28_zip_module_1078.md), [rulings_2026_08_30_text_format_residuals.md](rulings_2026_08_30_text_format_residuals.md), [rulings_2026_09_11_saml_metadata_exchange_1402a.md](rulings_2026_09_11_saml_metadata_exchange_1402a.md), [rulings_2026_09_11_smtp_imap_drafts_1085b.md](rulings_2026_09_11_smtp_imap_drafts_1085b.md), [rulings_2026_09_15_websocket_stream_placement_int19.md](rulings_2026_09_15_websocket_stream_placement_int19.md) |
| `wave-3` | [rulings_2026_08_26_seq_classification.md](rulings_2026_08_26_seq_classification.md) |
| `wf-26a` | [rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md](rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md) |
| `wf-27a` | [rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md](rulings_2026_09_08_flow_retry_wait_timer_kind_1314.md) |
| `xap-1` | [rulings_2026_09_26_xap_host_runner_xap1.md](rulings_2026_09_26_xap_host_runner_xap1.md) |
| `xd-1a` | [rulings_2026_08_21_x_tier_docs_and_domain_writes.md](rulings_2026_08_21_x_tier_docs_and_domain_writes.md) |
| `xd-1b` | [rulings_2026_08_21_x_tier_docs_and_domain_writes.md](rulings_2026_08_21_x_tier_docs_and_domain_writes.md) |
| `xd-2a` | [rulings_2026_08_21_x_tier_docs_and_domain_writes.md](rulings_2026_08_21_x_tier_docs_and_domain_writes.md) |
| `xd-2b` | [rulings_2026_08_21_x_tier_docs_and_domain_writes.md](rulings_2026_08_21_x_tier_docs_and_domain_writes.md) |
| `xd-2c` | [rulings_2026_08_21_x_tier_docs_and_domain_writes.md](rulings_2026_08_21_x_tier_docs_and_domain_writes.md) |
| `xd-2d` | [rulings_2026_08_21_x_tier_docs_and_domain_writes.md](rulings_2026_08_21_x_tier_docs_and_domain_writes.md) |
| `xd-2e` | [rulings_2026_08_21_x_tier_docs_and_domain_writes.md](rulings_2026_08_21_x_tier_docs_and_domain_writes.md) |
| `xsp-1` | [partition_campaign_PLAN.md](partition_campaign_PLAN.md) |
| `xsp-3` | [partition_campaign_PLAN.md](partition_campaign_PLAN.md) |

*348 ledger pages; 773 ids declared, 390 cited only.*
