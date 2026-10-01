# Owner decision 2026-10-01 ~14:0xZ — extra usage up to $100 is spent when it keeps a running agent's context from being lost and restarted; the window's allotment stays the default

**Status: RULED (owner, 2026-10-01 ~14:0xZ, in session, on the integrator's answer to "are you following the
plan to pause at window limits and resume when they reset?" — the 5-hour window at 73 % with eight rounds
running and its fill projected near 14:45Z, two hours before the 16:50Z reset; recorded by the integrator the
same hour). DOCS-51's spending rule (`rulings_2026_09_29_owner_direction_docs_5of5.md`), DELEG-3, SHIP-1,
AGENTS-1.**

## The owner's words, verbatim

"are you following the plan to pause at window limits and resume when they reset?" — "we can spend up to
$100 if it keeps us from losing/restarting agent context"

## OVER-1 — a $100 extra-usage allowance, spent only against a stop that would lose running agents' context

The 09-29 rule stands as the default: every launch is paid from the 5-hour window's allotment, nothing
launches past the window's taper, and a fix is never paid from extra usage. What this decision adds: when
the window reaches 100 % with agents mid-round, the integrator does NOT stop them (a stop costs each round a
resume of 130–330k tokens and its in-flight turn); the agents run on into extra usage until the window
resets, and the integrator's own calls with them, under a cap of $100 for the session — the extra-usage
line read with every meter read (every 15 minutes past 70 % of a window), each stretch posted on #1591
with its spend, a stop of everything at $90 projected to cross the cap before the reset. The allowance
buys continuity, not launches: no round launches on extra usage, and a window that is already past its
taper still launches nothing. Measured when ruled: eight rounds (DBVOL-1, TIMEP-1, LINTB-1, ERRAT-1,
READR-1, PLAY-3, WORDS-2, kit 1E) in builds and premerge-flows, none READY, head `e04d8ada8` green.

## The owner's second words, 2026-10-01 ~15:0xZ, verbatim — the allowance is a slush against hard stops, not a budget

"try to avoid spending any credits. the $100 budget was available as a small slush to help avoid hard stops
that result in spending more tokens in total."

Applied from 15:0xZ: zero extra usage is the default; the slush is spent only where a stop would cost more
tokens in total than the minutes it buys (a round minutes from READY, a merge chain mid-landing), never to
carry a fleet to a reset. Measured when clarified: $59.86 spent 14:24Z–15:0xZ under eight then five rounds;
all eight stopped by 15:0xZ (their detached premerge-flows finishing on disk, each log read at the relaunch),
three landings' worth of work kept on pushed branches.
