# Owner decisions 2026-09-19 ~05:05Z — the throughput bar: two closures an hour or the project is suspended (THRU-1); READY is the branch's own tree, no head-merge re-set (THRU-2); the batch is the unit of work (THRU-3); the union window holds only load-sensitive steps (THRU-4)

Owner, 2026-09-19 05:0xZ (01:0x New York), on the integrator's projection that the ruled order would close about seven issues in twelve
hours: "that's not acceptable. If we have no path with the constraints I gave, to close at least 2 issues per hour, I'm suspending the
project" — then, on the path below, letter (a): "finish the current issues in flight plus the 34 issues and any new ones within the
next 18 hours. Don't waste the work the current agents are doing. let them finish."

Measured before the rows (head `cfc61676a`, 91 open on the release label): 13 small decision-free bugs (the Ring 0 reader classes
1565–1580, 1556, 1551, 1582, 1583, 1570), 9 small tooling and docs items (1436, 1450, 1451, 1362, 1447, 1165, 1251, 1166, 1053),
5 flaky tests with a named root (1499, 1479, 1477, 1473, 1506), 6 near READY on paused branches (c5, f4, a5, e1: 1461, 1088, 1495,
1493, 1545, 1462), 1560 on the run in progress, about 46 multi-hour features and about 13 design rulings. Two agents on batches of
six to eight small same-ring issues, each batch three to four hours, project 22 to 26 closures in twelve hours when the runs pass and
about 18 with two red runs; the agent-hours of 2026-09-18 went mostly to head-merge re-sets, union-window holds and hand-assembled
per-branch pipelines, not to fixes.

| Id | Decision |
|---|---|
| **THRU-1** | **(owner)** The bar for the next eighteen hours (to about 23:00Z / 19:00 New York, 2026-09-19): the issues in flight (c5, a5, e1, f4, the runner branch), the 34 small issues named above and any new ones filed meanwhile close — at least two closures an hour, by passing post-merge runs. The agents in flight finish the item they hold before the order below applies to them; nothing of theirs is discarded. At 07:00 New York the integrator reports the measured rate on issue 1519; under two an hour, the owner decides. The feature and design backlog beyond the 34 is not touched by this row. |
| **THRU-2** | **(owner)** READY means the branch's OWN steps passed on the branch's OWN tree. A branch does not merge the head and does not re-run for a head merge — INT-9 and INT-21's re-set are SUSPENDED for the window of THRU-1; the integrator merges when `git merge-tree --write-tree origin/release/0.18 <branch>` is clean and the SELECTED post-merge run grades the union, with RUN-2's `-k` naming every red class in one run. Only a merge-tree conflict makes a branch merge the head, once, re-running only the steps whose inputs the conflict touched. A red union is claimed by the integrator, its classes named on the merge's issue, and fixed on a short branch by the agent whose change owns the class. |
| **THRU-3** | **(owner)** The batch is the unit of work: one branch carries six to eight small, decision-free issues of one ring, a fixture-first test/fix commit pair per issue, the ring's umbrellas (VERIFY-2) once on the final tree, one RESULTS.md line per issue and one MERGE-READY. An issue whose spec sentence is silent is a LETTER line in the agent's report ((a)/(b) and a recommendation) and is left out of the batch by name — never decided by the agent, never stalling the batch. The batches: Ring 0 (1580, 1579, 1578, 1577, 1576, 1575's engine half, 1567, 1565) on Agent 1 after c5 and before a5; tooling (1570, 1436, 1450, 1451, 1362, 1447, 1165, 1251) and the flaky roots (1499, 1479, 1477, 1473, 1506) on Agent 2 after the runner branch and before e1, f4 and issue 1561. |
| **THRU-4** | **(owner)** The union window (RUN-START to RUN-EXIT) holds ONLY the load-sensitive steps — memory gauges (repr-guard, cmp-005), bench-compare and the perf ratchet, real-socket tests. Builds, lints, fixtures, selftests and umbrellas run beside a post-merge run. AGENTS-1's window sentence is narrowed to this. |

## Sequencing (the integrator's)

Agent 1: c5 (in hand) → the Ring 0 batch `impl/cx-F-batch-r0b` → a5. Agent 2: the runner branch `impl/cx-F-runner-2` (in hand) →
the tooling batch `impl/cx-F-batch-t1` → the flaky roots `impl/cx-F-batch-flaky1` → e1 → f4 → issue 1561. The integrator merges each
READY branch as it comes, one selected run per merge, and posts closures per hour on the board.
