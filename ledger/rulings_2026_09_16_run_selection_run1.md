# Owner decision 2026-09-16 ~05:05Z — the post-merge run tests what changed and what reads it (RULED: RUN-1)

Owner, on the 04:5xZ board: *"stop testing everything with every little change. test what's changed and dependents"* —
and, on the options posted: **letter (a)**; "this was the stated plan days ago".

| Id | Decision |
|---|---|
| **RUN-1** | **(owner, letter (a))** The post-merge runner runs the **selected pipeline** — `make test-changed BASE=<the last head that PASSED>` (the sha `gate-loop.log`'s last `RUN-EXIT=0 passed` line names, the base INT-10's classifier already reads) — instead of all of `make test`. `scripts/test_changed.sh` selects the steps that read what the head changed and escalates to the FULL union itself when `scripts/*`, the Makefile, the V pin, an umbrella input or the grader moved. The full union ALSO runs once a day (the first run after 00:00Z with no full pass logged that day — `full_union_due` in `scripts/gate_loop_lib.sh`), on the re-run flag, and at every tag (release-process.md's cut). INT-10's doc pipeline stays the docs-only case, checked first. Both log lines carry ` selected`. Amends DG-1's §4 pipeline row (one sentence, written with this page). |

## Edit map

| path | edit | state |
|---|---|---|
| `scripts/gate-loop.sh` | the `selected` branch after the docs-only check | landed |
| `scripts/gate_loop_lib.sh`, `scripts/gate_loop_lib_selftest.sh` | `full_union_due` + cases I–L | landed |
| `spec/03-approved/process/delivery-grammar.md` §4 | the pipeline row's sentence | landed |
| `scripts/gate-loop.sh` running instance | restarted from a Terminal after the landing (a running `sh` does not reload) — superseded: the loop moved under launchd on 2026-09-16 and became `flows/postmerge.flow.cx` under `ai.cx.postmerge-flow` (RFLOW-1, LSWAP-1); no running `sh` remains | landed |

Why: measured 2026-09-15/16 — a full run is 66–70 min (a 36-min `-j12` storm of 72 V test files + 39 doc/conformance
steps, then a ~30-min serial tail of graders and gauges) on EVERY head, whatever it touched; closes arrive once an hour.
A one-module head selects 2–6 test files (8–12 min); a module + corpus head adds the graders (20–25 min).
