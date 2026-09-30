# Owner decision 2026-09-30 ~15:2xZ — the v0.18 milestone is the whole actionable backlog: every open issue a round can land carries the label, and only 5 to 20 non-actionable ones stay out, each with its reason

**Status: RULED (owner, 2026-09-30 ~15:2xZ, in session, on the integrator's count — 63 open under the
label, 108 open in cx-private without it (64 bugs, 18 design, 32 enhancements, 8 cx-gap), 41 open in
the component repositories). SHIP-1, DELEG-3, FW-1, INT-17, #1354 rule 8.**

## The owner's words, verbatim

"are you adding new issues to the v0.18 label? v0.18 should knock out all but 5-20 actionable issues."

## SHIP-2 — the label is applied to every actionable open issue; the cut waits for them as Letter 121 ruled

SHIP-1 ruled that v0.18.0 ships every issue in the milestone and that an issue leaves only on the
owner's word; this ruling sets the milestone's membership: every open issue of cx-private that a
round can land — a bug that reproduces at the head, a design question a letter can rule, an
enhancement whose spec or ruling exists — carries the `v0.18` label, and in a component repository
(whose LABELS.md carries no release label) the title prefix `v0.18 `, as FW-1's issues do; an issue
already fixed at the head closes on the measurement with the green run quoted (#1354 rule 6); an issue
whose paths or premises predate the split gets a comment naming what changed and stays open under the
label. Out of the milestone, listed by name with the reason: an issue bound to a trigger by a ruling
(KEYV-1's #1199), one blocked outside the tree (#107's Linux-only half, #958's external-repository
PRs), a question with no work behind it, a duplicate — 5 to 20 in all. The audit that applies this
(an opus agent launched 15:2xZ) closes only what it measured FIXED, labels the rest, and lists the
exclusions for the owner on #1591.

## The audit's measurement (an opus agent, 15:2xZ–16:1xZ, on `cc14beee6` green 14:59Z)
cx-private without the label (108): 8 fixed and closed on the measurement (#1717, #1715, #1662, #1663, #1654, #1696, #1682, #1614), 12 stale and commented (#1664, #1581, #1624, #1622, #1650, #1648, #696, #746, #747, #987, #1441, #1442), 2 duplicates, 86 still true — 83 labelled. The
component repositories (41): 10 fixed and closed (core-code#3, flow#14, xap#3, connector#3 #4 #7 #10, db#1 #3, identity#1), 1 stale (flow#2), 2 duplicates, 28 titled `v0.18 `. The milestone: 146
open. Left out, by name: the trackers #1591, #1519, #1589; blocked outside the tree #954, #1444, #1443, #834, #1011, #517, #1724; bound by a trigger or ruling #784, #801, #521, #1622 (D35a),
cx-platform-xap#9 (HKEY-1); no work possible #1673; duplicates #1697 (core-code#2), #1679
(connector#13), xap#6 and xap#8 (xap#4). This ruling supersedes BACKLOG-1 (2026-09-18) for the
design-backlog issues it took off the label; #804, #1125, #1321 and #1008 carry the label and
keep their v0.19 milestone until the owner reads this page. The defects in what ships, most
urgent first, are the next bug batch: #1677 (a program reads a secret without `secret-reveal`), #1678 (env secrets read with no env grant), #1608 (a denied effect bound to an unread binding
vanishes at exit 0), #1702, #1713 (`and` does not short-circuit), #1711 (`io:lock` a no-op), #1665, #1604, #1709, #1698, connector#5, connector#6, store#4, core-code#1.


The audit table, issue by issue: `ledger/issue_audit_2026_09_30_ship2.md`.
