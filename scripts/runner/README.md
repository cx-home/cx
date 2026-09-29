# `scripts/runner/` — the post-merge runner on a box

Until 2026-09-21 the runner's launchd unit lived only in one machine's
`~/Library/LaunchAgents`, and the runner directories only in that machine's
`~/git-repos/cx`. Neither was reproducible from a clone. This directory, and
the flow document it points at, are the checked-in copy. So the second box
(and the tenth) joins the same way every time: clone, the first build
(CONTRIBUTING §First build), then `devbox run runner`.

The words are the delivery grammar's
([`spec/03-approved/process/delivery-grammar.md`](../../spec/03-approved/process/delivery-grammar.md)):
a **run** is one pipeline on one commit; a **runner** executes runs one at a
time; there is one runner per pipeline.

## The three runners on a box

| Runner | Directory | Runs | Who starts it |
|---|---|---|---|
| post-merge | the default, `~/git-repos/cx/.build-slot` | all of `make test` (or the RUN-1 selection, or the doc pipeline) on every new head of the integration branch | `ai.cx.postmerge-flow`, a launchd job that runs one tick of `flows/postmerge.flow.cx` every 120 s |
| pre-merge, own | `~/git-repos/cx/.build-slot-<worktree>` | a branch's load-insensitive steps: builds, lints, the fixtures grader, umbrella tests, docs and registry checks (RULED: D17a) | an agent, through `scripts/build-slot.sh` with `CX_BUILD_SLOT` naming it (or `make premerge-flow`) |
| pre-merge, shared | `~/git-repos/cx/.build-slot-impl` | memory gauges (`repr-guard`, cmp-005), the perf ratchet and `bench-compare`, every real-socket test, each only in a gap of the post-merge runner | the same, by the step's class (RULED: INT-8, L98) |

A runner is a directory. `mkdir` is atomic, and the holder records its pid,
command, cwd and start time. A holder whose pid is dead is broken by the next
waiter. [`scripts/build-slot.sh`](../build-slot.sh) is the wrapper, and its
header carries the full contract. The directories sit in the PARENT of every
worktree, so a worktree's own copy of the wrapper finds the same lock.

## The loop (RULED: RFLOW-1 L100, L101)

The post-merge runner is a flow document, `flows/postmerge.flow.cx`. It lives
with the integrator protocol in the orchestration repository (`cx-private`),
beside its acts in `flows/private-acts.cx` and its launchd job
`flows/runner/ai.cx.postmerge-flow.plist`. There is no shell loop. launchd
runs ONE TICK every 120 seconds (`StartInterval`). It execs cx directly with
the environment and file limits in the plist, so there is no `/bin/sh`, and it
never starts a tick while the last one is still running.

A tick is four steps:

1. **tip** fetches the integration branch (the checkout's `VERSION` names it).
   It reads the log: the last sha that ran, the last that passed, the last RUN
   line, and the re-run flag.
2. **classify** picks what the head owes:
   - the doc pipeline, `make test-docs`, when the diff from the last passed
     head is docs-only (`scripts/head_is_docs_only.sh`, INT-10);
   - RUN-1's selection, `make test-changed BASE=<last passed head>`;
   - the full union: once a day, on the re-run flag, or when nothing has
     passed yet;
   - RUN-3's daily union, on an idle runner that holds a passed tip;
   - reaping a killed run;
   - or nothing.
3. **run** is the pivot. It takes the runner at zero wait: a live holder in
   front of a new tip is one `PENDING` line. It checks the tree is clean,
   fast-forwards the checkout, and re-checks the tip if the tick has taken
   longer than one poll. It writes `RUN-START`, then runs make under
   `scripts/build-slot.sh` with both streams in `vcx/target/gate.log`.
4. **verdict** writes `RUN-EXIT=<n> <status>` and the RUN-5 timings row. After
   a pass it refreshes the runner's own copy of cx.

The state is `vcx/target/gate-loop.log`, whose line shapes did not change:
`RUN-START`, `RUN-EXIT=`, `PENDING`, `WAITING`, `SKIP` and `SUPERSEDED`. So
every reader of it keeps working: the merge gap, the load-sensitive steps' gap
check, `scripts/gate-status.sh`, and the boards. A tick that was killed
mid-run leaves a `RUN-START` with no `RUN-EXIT`. The next tick finds the
runner's holder dead, which build-slot.sh's own stale-holder check decides,
and writes `RUN-EXIT=70 failed` for it. `touch vcx/target/gate-loop.rerun`
forces the full union on an unchanged tip, as before.

Each tick reads the document fresh from the checkout. A merge that edits the
loop takes effect on the next tick, with no restart and no reload.
`make postmerge-flow-gate` grades the document, including nine ticks run for
real against scratch clones of the tree.

## Install, status, restart, stop

```sh
devbox run runner          # make runner-install-flow: render the plist, copy cx, swap out ai.cx.gate-loop, bootstrap
devbox run runner-status   # launchctl print: state, pid, last exit; the log's last three lines
devbox run runner-restart  # kickstart -k: a tick now
devbox run runner-stop     # bootout
```

`make runner-install-flow` renders the plist template for the box: this
checkout, `~/git-repos/cx/.build-slot`, the runner's own copy of cx at
`~/git-repos/cx/.runner/cx`, `HOME`, and `VJOBS = hw.ncpu / 2` (#1600). launchd
cannot expand `$HOME` itself, so every path in the rendered plist is literal.
`make runner-render-flow RUNNER_PLIST_OUT=<path>` renders it without
installing it. The tick's stdout and stderr land in
`vcx/target/postmerge-flow.launchd.{out,err}`.

## Why launchd, and why the file limit

Measured 2026-09-15/16:
- A loop started from an agent session dies with the session: three runs were
  cancelled.
- A loop started from a Terminal inherits macOS's 256-file soft limit. Under
  it, `test-profile-gate` fails after a few hundred spawns ("load_suite: failed
  to open file", every embed program empty): two runs on one head.

The plist's two `NumberOfFiles` keys are that fix. `KeepAlive` is false, so a
stopped job is a visible gap in the log rather than a silent respawn.

## What replaces this

This is a one-machine scheme: one queue, lock directories, a scheduled tick.
With several boxes it becomes a scheduler. The plan of record
([cx-home/cx-private#1589](https://github.com/cx-home/cx-private/issues/1589))
replaces it with self-hosted GitHub runners per box, one label per role, and a
per-repo workflow that targets the label. The queueing, logs, retries and
notifications then become GitHub's. `.github/workflows/ci.yml` already says the
gate runs locally "until a self-hosted runner is restored". Until that lands,
this directory is how a box joins.
