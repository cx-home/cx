# Owner decisions 2026-09-27 — Letters 41–44 (from #1467, R-1492 and #1463): the graded orders-db partial merges (ODB-1); L41, L43, L44 pending

**Status: PARTLY RULED (owner, 2026-09-27 ~00:4xZ, in session, on the letters posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 00:2xZ–00:3xZ).** L42 is ruled here;
L41 (the call spread, #1686), L43 (R-1492's flow over the socket, cx-platform-flow#12) and L44
(#1463's audit `subject=`, #1683) were asked back for explanation and are recorded here when answered.

## The owner's word, verbatim

"l41 what's a call spread? need more info on this and how it impacts cx / l42a / l43 whats this /
l44 whats this"

## ODB-1 — the graded orders-db partial merges now; #1467 finishes after L41's fix and #1434's code (Letter 42 = (a))

`impl/cx-F-1467` (the orders-db package spelled per connector.md §3.8.1, fixtures 001–004 and 007
enforced 5/0, 005/006/008 advisory until `cx-platform/sync` has source and `[capture]` is in
feature.cxs — #1434's code phase — and the FIX-1 fix #1687: `connector:validate` answered an `[err]`
for every clean declaration, connector-141) merges as graded; it closes nothing. #1467 closes on the
scenario after #1686's fix (L41) and #1434's code, when 005/006/008 flip to enforced. Rejected: (b)
holding everything; (c) narrowing #1467 to no capture.
