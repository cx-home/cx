# Integrator decision 2026-09-30 — Letter 119, taken as delegated: db_access.md's sentences outside §7.1 are trued to the three-engine real-server step

**Status: RULED BY DELEGATION (the owner, 2026-09-29 ~03:5xZ, in session: "I will only review
doc/playground final output. you have your assignment." — every open letter outside the docs and
the playground is the integrator's to take at its recommendation; the letter was posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 01:3xZ 09-30 with DBLANE-1's merge;
the owner may reverse it on reading). DBLANE-1, DBSRV-1, DBNUL-1, RS-38.**

## The owner's words, verbatim

"I will only review doc/playground final output. you have your assignment."

## DBSPEC-1 — the stale sentences of db_access.md §2, §7.2, §9 and §12 are trued, each with the case ids that hold it (L119 = (a), delegated)

DBLANE-1's real-server step grades the whole db corpus on sqlite, postgres and mysql against real servers,
and §7.1 says so with db-036 and db-238; the sentences of §2, §7.2, §9 and §12 still describe
postgres and mysql as compile-checked, unexecuted, or a behaviour as sqlite's alone. Taken: a
small round trues each of those sentences to what the step proves — the exact semantics the
fixtures grade, each sentence carrying its case ids from the postgres and mysql corpus files, no
new word, no sentence beyond the false ones, a claim no case grades left as a flag — so the
release's spec says what its corpus proves. Rejected: leaving them — a release whose spec
contradicts its own real-server step.
