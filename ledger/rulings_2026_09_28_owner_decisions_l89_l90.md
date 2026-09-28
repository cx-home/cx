# Owner decisions 2026-09-28 (afternoon) — Letters 89 and 90: the database backends every fixture must reach, and an absent sync watermark is NULL

**Status: RULED (owner, 2026-09-28 ~15:5xZ, in session, "l89 a / l90 a do it today", on the letters
posted on [#1591](https://github.com/cx-home/cx-private/issues/1591) at 15:3xZ with DBNUL-1's READY,
after the integrator explained both plainly). DBNUL-1, SYNC-4, SYNC-5, RS-36, RS-38, CXF-8.**

## The owner's word, verbatim

"l89 a" — "l90 a do it today"

## DBLANE-1 — DBNUL-1 merges on sqlite's proof; a real-server lane grades every db case on postgres and mysql (L89 = (a))

cx-platform-db ships three backends and only sqlite has a server on the development box and in
CI, so every db fixture, before and after DBNUL-1, runs on sqlite alone; postgres and mysql are
compile-checked only. DBNUL-1's postgres path refuses `[param null=true]` by name (CXER0100) rather
than claim a binding no fixture runs. Ruled: DBNUL-1 merges as is, the release notes state "sqlite
proven; postgres and mysql compile-checked"; the next session opens a prio:high round — a
real-server lane (postgres and mysql in containers, on the shared slot and on a runner) under which
the whole db corpus grades all three engines and the NULL binding lands for postgres and mysql under
fixtures. Rejected: (b) holding DBNUL-1 until the lane exists — the same gap, one closed issue fewer;
(c) an unexecuted postgres binding claiming a behaviour — the class AGENTS.md rule 3 forbids.

## SINCE-1 — an absent `:since` on a baseline sync run binds NULL, and it lands today (L90 = (a), today)

On a baseline run the sync kit bound `''` for the absent watermark, and the reference statement
`WHERE updated_at >= coalesce(:since, '')` answered every row only because `>= ''` is true under
string comparison — a convention, not SQL's absence. Ruled: an absent `:since` is bound as NULL,
exactly as DBNUL-1 binds an absent cursor on page one — one absence semantics across the kit — with
a fixture-backed sentence in sync.md's baseline section (RS-38), done today inside DBNUL-1's round on
the owner's word. Rejected: (b) keeping `''` as sync's convention — two conventions for one thing;
(c) as a separate later round — the owner chose today.
