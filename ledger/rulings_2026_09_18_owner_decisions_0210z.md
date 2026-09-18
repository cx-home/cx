# Owner decision 2026-09-18 ~02:10Z — find it, fix it: a small same-area defect is fixed in the branch that finds it (RULED: FIX-1)

Owner, on the integrator's letters after "our net progress today has been to add 23 issues" (37 opened, 17 closed since
00:00Z; 21 opened by four agents this session, one issue fixed per branch): **letter (a) — "this is an old acceptable rule
that you have repeatedly ignored."** The rule is the 2026-09-04 standing order ("fully resolving issues, no partial
implementation, no deferments") and the 2026-09-07 one ("stop deferring the hard stuff"): filing a defect one has just
found, for a later batch, is a DEFERRAL. The briefs of 2026-09-17 carried CXF-8's first half ("file it the same hour")
without this second half; six of the day's filings (#1535 #1536 #1543 #1547 #1550 #1553) were small, same-area and
decision-free and would have closed the day they were found.

| Id | Decision |
|---|---|
| **FIX-1** | **(owner, letter (a); every agent branch and the integrator's own)** A defect found while working a branch that is (1) SMALL — about an hour — (2) in a module the branch already touches, and (3) needs no decision, is FILED the same hour (CXF-8) **and FIXED in that branch**: fixture first, its own `test(N)` / `fix(N)` commit pair, the issue named in the merge subject and in RESULTS.md (one line per such fix); it closes on the passing post-merge run of that merge like the branch's own issue. Filing ALONE is reserved for a defect that is large, outside the branch's modules, or needs a ruling — and RESULTS.md says WHICH of the three. The integrator checks the three conditions on every filed-only defect before accepting a branch as READY and sends the agent back for the ones that qualify; every brief carries the sentence; the standing rules carry it under "Learned 2026-09-18". Rejected: (b) filing-only with the batches absorbing the tail (the count rises between batches); (c) not filing minor findings (the private-notes habit CXF-8 ended). |
