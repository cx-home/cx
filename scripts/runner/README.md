# `scripts/runner/` — the post-merge runner on a box

Until 2026-09-21 the runner's launchd unit lived only in one machine's
`~/Library/LaunchAgents`, and the runner directories only in that machine's
`~/git-repos/cx`. Neither was reproducible from a clone. This directory is the
checked-in copy, so the second box (and the tenth) is: clone, the first build
(CONTRIBUTING §First build), `devbox run runner`.

The words are the delivery grammar's
([`spec/03-approved/process/delivery-grammar.md`](../../spec/03-approved/process/delivery-grammar.md)):
a **run** is one pipeline on one commit; a **runner** executes runs one at a
time; there is one runner per pipeline.

## The three runners on a box

| Runner | Directory | Runs | Who starts it |
|---|---|---|---|
| post-merge | the default, `~/git-repos/cx/.build-slot` | all of `make test` (or the RUN-1 selection) on every new head of the integration branch | `ai.cx.gate-loop`, this directory's plist, via `scripts/gate-loop.sh` |
| pre-merge, load-insensitive | `~/git-repos/cx/.build-slot-impl2` | builds, lints, the fixtures grader, umbrella tests, docs and doc-block checks, spec/catalog/registry checks, a non-escalated `test-changed` | an agent, through `scripts/build-slot.sh` with `CX_BUILD_SLOT` naming it |
| pre-merge, load-sensitive | `~/git-repos/cx/.build-slot-impl` | memory gauges (`repr-guard`, cmp-005), the perf ratchet and `bench-compare`, every real-socket test | the same, by the step's class (RULED: INT-8) |

A runner is a directory: `mkdir` is atomic, the holder records its pid, command,
cwd and start time, and a holder whose pid is dead is broken by the next waiter.
[`scripts/build-slot.sh`](../build-slot.sh) is the wrapper and carries the full
contract in its header. The directories sit in the PARENT of every worktree so
that a worktree's own copy of the wrapper finds the same lock.

## The loop

[`scripts/gate-loop.sh`](../gate-loop.sh) polls the integration branch, fast-forwards
the main checkout when the tip moves, and runs `build-slot.sh gate.sh` under the
default runner, writing `<utc> <sha> RUN-START` / `RUN-EXIT=<n> <status>` to
`vcx/target/gate-loop.log`. Every non-docs head runs the RUN-1 selection
(`make test-changed BASE=<last passed head>`); the full union runs once a day,
on the rerun flag, and at every tag. Its header carries the line shapes and the
rules.

## Install, status, restart, stop

```sh
devbox run runner          # cp the plist into ~/Library/LaunchAgents and bootstrap it
devbox run runner-status   # launchctl print: state and pid
devbox run runner-restart  # kickstart -k — ONLY between runs; a running sh never reloads a landed gate-loop.sh
devbox run runner-stop     # bootout
```

The plist derives every path from `$HOME` inside its one `sh -c` string, so it
installs unchanged on every box that keeps the checkout at
`~/git-repos/cx/cx-private`. Its stdout and stderr land in
`vcx/target/gate-loop.launchd.{out,err}`.

## Why launchd, and why the file limit

Measured 2026-09-15/16. A loop started from an agent session dies with the
session: three runs cancelled. A loop started from a Terminal inherits macOS's
256-file soft limit, under which `test-profile-gate` fails after a few hundred
spawns ("load_suite: failed to open file", every embed program empty): two runs
on one head. The plist's two `NumberOfFiles` keys and the `ulimit -n 65536` are
that fix; `KeepAlive` is false so a dead loop is a visible gap in the log rather
than a silent respawn.

## What replaces this

This is a one-machine scheme: one queue, lock directories, a watchdog. With
several boxes it becomes a scheduler, and the plan of record
([cx-home/cx-private#1589](https://github.com/cx-home/cx-private/issues/1589))
replaces it with self-hosted GitHub runners per box, one label per role, and a
per-repo workflow that targets the label — the queueing, logs, retries and
notifications become GitHub's. `.github/workflows/ci.yml` already says the gate
runs locally "until a self-hosted runner is restored". Until that lands, this
directory is how a box joins.
