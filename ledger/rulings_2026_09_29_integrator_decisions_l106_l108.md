# Integrator decisions 2026-09-29 — Letters 106 to 108, taken as delegated: the loop swap, the killed-run lock, the two acts modules

**Status: RULED BY DELEGATION (the owner, 2026-09-29 ~03:5xZ, in session: "I will only review
doc/playground final output. you have your assignment." then "make it so" — every open letter
outside the docs and the playground is the integrator's to take at its recommendation, as on
2026-09-27; the three letters were posted on [#1591](https://github.com/cx-home/cx-private/issues/1591)
at 01:3xZ with RELFLOW-1 round 2's READY, each with its options and consequences; the owner may
reverse any of them on reading). RFLOW-1, PRIVMK-1, D83a, INT-10, RUN-5, CXF-1.**

## The owner's words, verbatim

"I will only review doc/playground final output. you have your assignment." — "make it so"

## LSWAP-1 — the loop swap happens in one gap, the old loop unloaded first (L106 = (a), delegated)

Merging RELFLOW-1 round 2 deletes `scripts/gate.sh` from under the live launchd loop. Taken: in one
gap the integrator unloads the old loop, merges round 2 through `flows/merge.flow.cx`, installs the
new plist (`make runner-install-flow` — launchd executes `cx flow run --ephemeral
flows/postmerge.flow.cx` every 120 seconds) and reads the first real tick's log whole as the proof
that the ruled RUN lines are written for the merged head; the delivery grammar's line naming
`gate.sh` and `gate-loop.sh` is renamed to the flow document in the same merge, a sentence inside
this ruling. Rejected: merging before the swap (a tick would call a missing script and could write a
stale verdict); two runners on one log.

## RLOCK-1 — the killed-run verdict rests on the runner lock until `io:lock` is real (L107 = (a), delegated)

The ruled io lock is a no-op in this cx (#1711, measured by the agent). Taken: the run act holds
build-slot's runner lock for the run's life and the next tick takes it with zero wait to tell a dead
run from a live one, writing the failed verdict; this is the ruled shape's interim form, and when
#1711 makes `io:lock` real the act moves to it in a small round with the gate's dead-run case
unchanged. Rejected: holding the round on a stdlib fix; dropping the killed-run verdict.

## ACTSM-1 — one public idioms module, one private acts module, the gate engine public (L108 = (a), delegated)

Taken: `flows/ci-acts.cx` is public and holds the shared idioms every document imports plus the
release acts; `flows/private-acts.cx` holds the four private documents' acts; `scripts/ci_flow_gate.cx`
is public because the public release and docs gates need it. The first choice of the CI/CD design
("one acts module") and the private-include ruling's sentence on the engine read this way. Rejected:
one public module carrying the private acts (the merge protocol published); one private module (the
public `make test` unable to run its two gates).
