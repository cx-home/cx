# Owner decisions 2026-09-19 ~04:45Z — a failed run reports every red class (RUN-2); the daily full union runs on an idle runner (RUN-3); an escalated branch runs the computed selection pre-merge (RUN-4); the run log carries step timing and the timings file (RUN-5); the two agents and their order (AGENTS-1); the budget step stays open until it measures (1562-a)

Owner, 2026-09-19 04:4xZ (00:4x New York), on the six questions of the 00:40 board on issue 1519: "all recommendations, proceed".
The owner's opening word that session (04:20Z): several post-merge runs failed and the last took three hours — not acceptable; find
a better way before proceeding; two agents at most; pause gracefully at a usage limit and resume when it lifts; keep improving the
process so it is sound, faithful, fast and frugal with tokens and credits.

Measured before the rows (head `22175ebaf`, from `vcx/target/gate-loop.log` and the run logs): on 2026-09-15 a full union took 50–60
minutes and twelve passed in a day; by 09-17 a selected run took two to three hours and the full union 2 h 54 (the 04:01Z pass on
`84825d79f`: the -j storm 01:08→02:37Z, the serial tail 02:37→04:01Z with the unselected profile gate about 70 minutes of it — timed
by file modification times, because the run log carries no timestamps). Three causes by size: four to six agents' pre-merge
pipelines on the same twelve-core box during the run (load 21 to 218); the unselected profile tail; the union's growth (issue 1561:
80 standalone V test files, 648 CPU-minutes of compile per run). On 09-18 no run passed all day, so RUN-1's daily net was "due" for
every head and every run was the full union; `make` stops at the first red ("Waiting for unfinished jobs"), so ten failed runs at
about 1.5 h each found seventeen classes — under two per run. Those classes were mostly steps a branch's hand-assembled pipeline had
never run (umbrellas, `check-code-fixtures`, `reader-parity`, the oriel lane, `fmt-sweep-gate`, the selection manifest), on branches
whose `scripts/` change escalated the selection so the computed `test-changed` step ran nothing pre-merge (INT-5). Found the same
hour in vcost1 before its merge: the verification-budget step of issue 1562 has no writer (every bound reads NOT MEASURED — issue
1583) and its selftest plants at the real timings path inside the same storm as the step (issue 1582).

| Id | Decision |
|---|---|
| **RUN-2** | **(owner, Q1 letter (a); `make test`)** The -j storm of `make test` runs with `-k` (keep going), so ONE failed run names EVERY red step; the serial tail (`test-profile-gate`, `test-vcx-timing`, `test-code-diagram`) runs only after a green storm, exactly as today. A red run still exits 2 through `make`'s own status and RUN-EXIT reads it unchanged; the fix branch for a red head carries every class the log names before the next tip, instead of one class per hour. Not (b) — a shorter red run that finds under two classes costs ten runs for seventeen; not (c) — the tail on a red storm buys little while the tail is long. |
| **RUN-3** | **(owner, Q2 letter (a); `scripts/gate-loop.sh`)** RUN-1's daily full union never runs in front of a merge: when the net is due (`full_union_due`) and the runner has been IDLE for at least ten minutes on a graded tip with no new tip pending, the loop runs the full union on the current head (both lines plain, no kind suffix, as RUN-1's net is written today); a tip pushed meanwhile waits for it and is then graded selected against that pass. Nothing else about RUN-1 moves: the rerun flag and a tag still force the full union; a selected run still escalates on a build-infra change. `scripts/gate_loop_lib.sh` carries the "idle and due" answer with a row in its selftest; the loop restarts with `launchctl kickstart -k` between runs. |
| **RUN-4** | **(owner, Q3 letter (a); the standing rules, the pipeline shape)** A branch whose selection ESCALATES (Makefile, `vcx/Makefile`, `scripts/`, `VERSION`, `devbox*` moved) still runs a COMPUTED pre-merge selection: its pipeline takes the branch diff MINUS the build-infra paths as a change-set file, asks `sh scripts/test_changed.sh origin/release/0.18 --dry-run --changed-files <file>` for the steps and the `test-vcx-suite` files that change-set selects, and executes each of them as its own step beside the branch's own steps and RESULTS.md rows; the post-merge union still nets the infra change itself (INT-5 unchanged: the escalated union is never queued pre-merge). The standing rules carry the exact block. Narrowing the escalation trigger itself stays issue 1489's follow-up (letter (c)), filed under this row rather than chosen instead of it. |
| **RUN-5** | **(owner, Q6 letter (a); issues 1583 and 1582)** The run log and the timings file carry the measurements VCOST-1 asks for: `make test`'s top-level recipe lines print `STEP-START <utc> <name>` and `STEP-END <utc> <name> exit=<n>`; `scripts/gate-loop.sh` writes the `union` or `selected-run` row of `vcx/target/verification_timings.cxd` at RUN-EXIT (seconds from RUN-START, the one-minute load sampled at RUN-START, `at=`), replacing the previous row of that name, so the NEXT run's `check-verification-budget` judges the last run; `scripts/run_fixture_shards.sh` writes the `fixture-grader` row on an unselected run; the selftest of issue 1582 plants under its own temporary path through an override the step reads, never at the real path — fixture before fix on both. |
| **AGENTS-1** | **(owner, Q4 letter (a))** Two agents, no more, Opus: Agent 1 takes `impl/cx-F-batch-c5` (the INT-21 re-set on the merged tree) then `impl/cx-F-batch-a5`; Agent 2 takes issue 1561 (the test-file consolidation — the storm's largest single cost) then `impl/cx-F-batch-e1` then `impl/cx-F-batch-f4`. Under the union window (RUN-START to RUN-EXIT in `vcx/target/gate-loop.log`) an agent builds, lints and edits; its test steps and graders queue for RUN-EXIT. A stopped agent is resumed by message on its own transcript, never replaced. |
| **1562-a** | **(owner, Q5 letter (a); issues 1562 and 1583)** Issue 1562 stays OPEN until the writer of issue 1583 lands: the run on `22175ebaf` closes issue 1560 only. Closing the budget step on a run in which it measured nothing would close the sentence, not the measurement. |

## Sequencing (the integrator's, under AGENTS-1)

The runner rows RUN-2, RUN-3 and RUN-5 (with issues 1582 and 1583) are tooling code and go FIRST on Agent 2's slot as one branch,
`impl/cx-F-runner-2`, ahead of issue 1561: they shorten every later run, and issue 1561's measured before/after needs RUN-5's
timestamps to be read from the log rather than from file times. RUN-4 is a standing-rules block on this page's own branch (a
documentation head) and binds every pipeline written after it merges. Agent 1 starts on c5 at once. The page merges as a doc run
behind the full union grading `22175ebaf`; the loop restarts between runs once the runner branch merges.
