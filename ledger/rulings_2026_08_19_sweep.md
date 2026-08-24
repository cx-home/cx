# Rulings 2026-08-19 — the close-what-we-can sweep (owner, in-session)

Owner answered "1 only 30 min to fix? Why not take care of it? / 2 b / 3 a"
to the three lettered questions posed after the sweep closed #855/#863/#847/
#859 and landed #839 half 1. Recorded here BEFORE execution (R4.2 / #832).

## R7.1 — #861 read-event timeout: fixed NOW, overriding the post-cut lane

The R5.7–R5.11 round had placed the read-event widening in its own post-cut
lane. Owner overrides: fix in this session. Direction is the issue's (a) —
the wrapper widens to forward the optional duration (`($timeout?)` →
`[$term-read-event $timeout]`), making the existing fn-doc TRUE rather than
editing the promise out.

**This carries NAMED spec authorization for `spec/03-approved/x/term.md`,
scoped to:** §1's read-event row (documents the timeout positional and the
`[timeout]` return it makes reachable) and §8.1 (the open item this resolves).
Nothing else in the file.

## R7.2 — #839 half 2: option (b) — serve grows host's session/attribution path

Owner picked **(b)**: `[$xap:serve]` gains the SAME session/attribution
mechanism `[$xap:host]` already carries, so a served POST reaches the
grammar→PEP→record→journal cascade with a real actor and a journal-BOUND
runtime is servable. Not (a) (a bare `actor:` option) and not (c) (docs-only
demo-surface downgrade). Anonymous emit on an UNBOUND runtime stays the
documented back-compat. Spec scope: if `[$xap:serve]`'s normative surface
text needs the option documented, that edit is authorized as part of this
ruling; the PEP semantics themselves do NOT move.

## Also this session (context for the ids above)

R5.13 landed @ 0fb7cd07 (top-level err exits 1); #855 fixed @ fork
ed712669b4 (RULED: R7.1 and RULED: R7.2 are the only NEW tokens this file
introduces).
