# Owner decision 2026-09-18 ~02:50Z — the eight-hour requirement amended: the order is the most recent issues first, then Ring 0, Ring 1, Ring 2; #1520 and #1515 ride the first batch; the fifty is a HARD REQUIREMENT (RULED: VERIFY-1a)

Owner, 2026-09-18 02:4xZ–02:5xZ, on the integrator's rostering by area: **"no that's not the plan. the order is most recent 25
issues plus any new ones found, then ring 0, then ring 1, then ring 2"**, then **letter (b)** (#1520 and #1515 added to the
first tooling-side batch), and **"it's not a target, it's a hard requirement to avoid suspension"**: all but 125 of the
repository's open issues — 175 open at 02:4xZ, so fifty resolved, plus every new defect found — sound (fixture first) and
verified (a passing post-merge run), within eight hours of the first batch launch, with two Opus agents and no more. The
Claude Code process of session cx-private-88 restarted at ~02:44Z, which ended that session's subagents and watchers (the
launchd runner loop and the union run on `4aeaeee8d` were unaffected); the owner then directed that no further process be
started from that session and that a new Fable session run the eight hours.

| Id | Decision |
|---|---|
| **VERIFY-1a** | **(owner; amends VERIFY-1's rows (3) and (6); everything else on that page stands)** **(6′) The order.** Phase 1: every open issue filed since 2026-09-17 12:00Z — at 02:4xZ #1521 #1523 #1524 #1537 #1546 #1549 (on the union grading), #1553 (merged, awaiting a run), #1539 (fixed on the CXF-6 branch), and the nineteen to work: **Agent A** (readers, lint, diagnostics, Ring 0): #1543 #1536 #1547 #1550 #1538 #1541 #1548 #1533 #1555 #1545; **Agent B** (stdlib, tooling, platform): **#1520 #1515 first (letter (b) — the two run-time fixes)**, then #1535 #1534 #1542 #1551 #1554 #1556 #1540 #1552 #1544; every new defect found joins the finder's batch under FIX-1. Phase 2, Ring 0: A #1509 #1508 #1518 #1239; B #1436 #1241 #1387 #1207. Phase 3, Ring 1: A #1493 #1495 #1173+#1174 #1087; B #1266 #1086 #1088. Phase 4, Ring 2: A #1505 #1506 #1429 #1461 #1462 #1463; B #1510 #1507 #1456 #1457 #1458 #1497 #107. Inside a batch, smallest first; a fix that needs a decision the issue does not carry is a letter on the issue and the agent moves on. **(3′) Merge points.** Each agent's batch merges when READY; Phase 1's two batches are merged together into one tip and one run grades it (~hour 3); each later phase the same; the integrator merges nothing between a phase's two batches unless the other is more than an hour away. A red on the head is the scripted bisect of VERIFY-1 (4). **The count** is the two measured numbers on the board every hour (merged-with-fixtures, closed-by-a-passing-run) against the requirement of fifty plus the new ones; the hour-3 checkpoint states Phase 1's merged count and the tooling fixes' measured saving. |

## Sequencing

Phase 1 (A1 ‖ B1) → Phase 2 (A2 ‖ B2) → Phase 3 (A3 ‖ B3) → Phase 4 (A4 ‖ B4); the CXF-6 branch (#1061 #1059 #1539) merges
as soon as its inner loop is green; the cx-first epic's remaining lanes (CXF-7, lane 8 → #1522 #1525) and the verification-cost
lane (the 20-minute bound, letters open) take a slot only when a phase's batch finishes early.
