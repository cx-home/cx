# Owner decision 2026-09-15 ~12:20Z — the v0.18 bug tail: 17 open bugs pulled in, 8 stay out (RULED: INT-16)

Owner, on the board of ~12:10Z ("we're missing numerous bugs to be closed this campaign … we shouldn't have more than
5 or 10 bugs left open at the end"): **letter (a)**.

| Id | Decision |
|---|---|
| **INT-16** | **(owner, letter (a))** Of the 25 open bugs that carried no v0.18 decision, SEVENTEEN enter v0.18 as fix branches, fixture first, in the code slots after #1503 and #1502, small fixes first: #1500 (cast sentinel comparison), #1501 (`1e400` → `+inf.0`), #1079 (planar/live aggregates under `-gc boehm`), #1389 (fmt declines a namespaced call over a parenthesized group), #1436 (fmt declines interior comments), #1493 (audit.md §11 connector row), #1495 (the connector → db_access seam row and the check that passes without it), #1488 (the purity gate skips module:member tokens), #1446 (`apply_blesses.cx` calls a function that does not exist), #1450 (perf-ratchet isolation guard), #1476 (`make -n test` executes recipes), #1363 (code-diagram of a homoiconic answer), #1387 (wasm32 flow timers never fire), and the four flaky tests fixed at the root, never by roster: #1473, #1477, #1479, #1499. EIGHT stay out, each with its reason: #834, #1008, #1011 (upstream V on platforms this box cannot run — linux, FreeBSD, Windows), #1440, #1441 (V language limitations — a semantics change in the fork, not a fix), #1125 (the classified, rostered flake the load-class retry covers), #804 and #1321 (perf work of the representation campaign, #1119). The campaign's bug set is therefore 30 open bugs to close (13 already in + 17), with 8 expected open at the end. Each pulled-in issue is labeled `prio:high` and carries this row. |

Why: the board of 12:10Z counted 39 open bugs with only 13 in the campaign; the owner's bar for the end of a
close-out campaign is at most 5–10 bugs left open.
