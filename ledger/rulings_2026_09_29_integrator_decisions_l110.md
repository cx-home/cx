# Integrator decision 2026-09-29 — Letter 110, taken as delegated: DBLANE-1's servers come from devbox, not from a container runtime

**Status: RULED BY DELEGATION (the owner, 2026-09-29 ~03:5xZ, in session: "I will only review
doc/playground final output. you have your assignment." — every open letter outside the docs and
the playground is the integrator's to take at its recommendation; the letter was posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 21:3xZ with its options and
consequences; the owner may reverse it on reading). DBLANE-1, DBNUL-1, CXF-1, RS-36, D17a, RUN-5.**

## The owner's words, verbatim

"I will only review doc/playground final output. you have your assignment."

## DBSRV-1 — the real-server lane starts postgres and mysql from devbox's packages (L110 = (a), delegated)

DBLANE-1 rules a real-server lane "postgres and mysql in containers, on the shared slot and on a
runner", and dev2 — the box of the shared slot and of cx-platform-db's self-hosted runner — has no
container runtime (docker, podman, colima and nerdctl all absent, measured 2026-09-29 21:4xZ).
Taken: the lane starts the servers from devbox's nix packages (`postgresql`, and `mysql`, or
`mariadb` where nixpkgs carries no mysql server for the box's platform — the round records which),
each on an ephemeral port under a temporary data directory removed on exit, inside the devbox shell
every step already runs in; the driver is a cx program; the packages are pinned in `devbox.json`
like the rest of the toolchain; the ruling's "containers" is read as isolated throwaway servers,
which is what it asked for. Rejected: a container runtime installed on dev2 (a system install per
box, a socket the loop's clean environment must find, the lane tied to the box that got it); a
GitHub-hosted `services:` job with no local lane (the shared slot and the union would never grade
the two engines, against the ruling's own words).
