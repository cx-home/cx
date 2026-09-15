# Owner decision 2026-09-15 ~12:55Z — every open issue is IN v0.18 unless the owner rules it out (RULED: INT-17)

Owner, on a board that recommended most of 83 undecided issues "stay out as the next release's backlog": *"most all
these should be done in v0.18. we've fallen behind and carry a weight of too many deferred items. It's clear that you
have a default setting that continues to override my settings to not defer, but deal with issues and enhancements
'in-campaign' unless specifically ruled otherwise. that deferral pattern MUST STOP!"*

| Id | Decision |
|---|---|
| **INT-17** | **(owner)** The DEFAULT for an open issue is IN the running campaign. The integrator never recommends deferral; a split it proposes is an ORDER (what first), never membership. Only the owner rules an issue out, by number. Applied to the 83 undecided open issues of the 12:5xZ board: **all in v0.18 except #517** (deferred by the owner). By cluster, the owner's words: (1) design and investigation — in; #1250 "looks like a bad bug that needs to be fixed", #1329 "is a defect", #1359 "is clearly v0.18"; #517 deferred. (2) The connector-kit follow-ons #1464 #1481 #1482 #1483 #1484 #1485 #1491 #1492 and the representation campaign's exit #1207 — "all of these get done in v0.18". (3) Hygiene and gate holes #1447 #1474 #1071 #1251 #1362 #1346 #1165 #1166 #1053 #958 — in v0.18. (4) The programs (analytics, ETL/iPaaS, consumability, clients) — in; "some of these may be superseded or need updating after cx flow and connector kit": each is re-verified against the landed flow and connector kit before its branch, and its decision updated then; #1315, #1417 and #1096 are v0.18 outright. (5) Stdlib and language additions #1173 #1174 #1175 #1222 #1087 #1088 #1266 #1086 #103 #107 #1239 #1241 — "should have been done v0.18 and must be added now". (6) V-runtime limitations and perf #1439 #1442 #1443 #1444 #1386 — in, sequenced AFTER the bug and enhancement backlog ("we need to get to these asap but our backlog of bugs and enhancements comes first"). Also in, from letter (a) of the same board: #1447 #1474 #1071 #1251 #1362 #1491 #1492. Standing rulings that remain OUT: #1418 (INT-2), #1325 (INT-3 addendum 2), the eight of INT-16, the six archived (1085-e). Tracker marker: the label `v0.18` on every campaign issue. |

## Order (integrator, under INT-17)

Bugs first: the surface seven, INT-16's seventeen, #1250, #1329, #1503, #1489, #1478. Then enhancements: the INT-13
batch, clusters 2, 3 and 5, #1359, #1315, #1417, #1096, the transports' code phases and the reference connectors,
cluster 4 after its re-verification; cluster 6 last. Design issues are decision + spec work first (the owner reads).
