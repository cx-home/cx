# Delivery grammar

**Status:** New (owner, 2026-09-11; RULED: DG-1).

One word per thing. Git and `flow.md` words are used where they exist. Every report, issue
comment, commit message and decision uses these words and no others; a new word is added here
before it is used anywhere. When someone diverges from this vocabulary, the reader points back
to this page.

## §1. The sentence

A release has epics; an epic has issues. An issue gets a decision, then a branch in a worktree,
worked by the integrator or an agent. The pre-merge pipeline runs on the branch; when it passes,
the branch is merged. The post-merge pipeline runs on every new head. Pass closes the issues in
it; fail gets a fix, or a flaky-test issue.

## §2. Work

| Term | Meaning |
|---|---|
| release | one versioned delivery, named by the root `VERSION` file |
| epic | an issue that groups issues (S, M, P, 1; #1354 is the release) |
| issue | one unit of work |
| decision | one recorded choice, made before the work (`ledger/`, cited `RULED: <id>`) |
| spec | the normative text under `spec/03-approved/`; the only truth |
| branch | `impl/<name>`; resolves one issue or a stated part of one |
| worktree | a checkout of a branch outside the main checkout |
| integration branch | `release/X.Y`; its head is its latest commit |
| merge | the `--no-ff` commit taking a branch onto the integration branch; irreversible — a failure after it gets a fix |

## §3. People

| Term | Meaning |
|---|---|
| owner | approves specs; may override any decision |
| integrator | the session that owns an epic: decides, merges, watches the pipelines |
| agent | a background agent given one branch, end to end, in one worktree |
| session | one interactive session; it stops every process it starts |

## §4. Pipeline

| Term | Meaning |
|---|---|
| step | one command with a pass/fail exit (a make target, a test file) |
| pipeline | an ordered set of steps; two exist — **pre-merge** (the branch's subset, in its worktree: `make test-changed BASE=<integration branch>` plus the branch's new steps) and **post-merge** (all of `make test`, on the head) |
| run | one pipeline on one commit; its status is pass, fail or cancelled |
| runner | executes runs, one at a time; one per pipeline |
| flaky test | a step that fails at the same commit with no code change; a known one is retried once |
| artifacts | what a run leaves: logs, `RESULTS.md`, the merge comment on the issue |

## §5. One issue, start to finish

1. decide — the decision in `ledger/` and on the issue
2. work — commits on the branch, subjects ending `(RULED: <id>)`
3. pre-merge — every step and its exit in `_gate_evidence/<branch>/RESULTS.md`
4. merge — the merge commit; a comment on the issue naming it
5. post-merge — the run's start and status in `gate-loop.log`; steps in `gate.log`
6. close — pass: the issues in the run close, citing it; fail: a fix branch when the step is ours, a flaky-test issue when it is not

## §6. Rules

- One post-merge run at a time, started only when the head changes.
- The post-merge runner never executes a pre-merge run.
- A merge never touches the main checkout while a post-merge run holds it.
- A session stops every process it starts before it ends.

## §7. What the tooling still prints

The pipeline tooling's **words** are this page's now (OL-12): it prints
`RUN-START`, `RUN-EXIT=<n> passed|failed|cancelled`, `run:`, `step`, `runner`,
`post-merge run`. What is left below is **names** — files other sessions are
tailing, make targets every caller spells out, and directories live runs carry
in their commands. Each needs a change of its own, because renaming a target
breaks its callers and renaming a runner directory strands the runs holding it.

| Prints | Means | Renamed by |
|---|---|---|
| `scripts/gate.sh`, `gate-loop.sh`, `gate-status.sh`, `build-slot.sh` | the run wrapper, the post-merge runner loop, the run reader, the runner | a file rename |
| `vcx/target/gate.log`, `gate-loop.log`, `gate-prev-*.log`, `gate-loop.rerun` | one run's step output; the post-merge runner's own log; the rotated copies; the re-run flag | a file rename — other sessions tail these right now |
| `GATE-EXIT=`, `GATE-START`, `gate: started` | the pre-OL-12 spelling of `RUN-EXIT=`, `RUN-START`, `run: started`, in logs already on disk; every reader accepts both | nothing — the old logs age out |
| `check-python-test-lane`, `test-oriel-lane`, `test-sso-interop-lane` | make targets that are one step each | a target rename |
| the `*-gate` targets (`spec-freeze-gate`, `test-profile-gate`, `fmt-sweep-gate`, `guide-render-gate`, `abi-gc-gate`, `ring-import-gate`, …) and the Makefile messages that name them | one step each | a target rename |
| `TEST_TARGETS`, `test-changed`, `check-gate-lock`, `gate-lock-status` | the post-merge pipeline's step list; the pre-merge pipeline; the build lock | a target/variable rename |
| `CX_BUILD_SLOT`, `BUILD_SLOT_TIMEOUT` | the runner directory and its wait bound; `CX_RUNNER` is a synonym for the first |  a variable rename |
| `.build-slot` / `.build-slot-impl` | the post-merge runner / the pre-merge runner | a directory rename — live pre-merge runs carry these paths |
| `lanes a/b/c`, `conversion lane`, `async lanes` | fixture rows and code paths, **not** pipeline steps | nothing — a different sense of the word |
| serial retry roster | the known flaky tests | — |
| steward | agent | — |

## §8. `flow.md` mapping

| Here | In `flow.md` |
|---|---|
| step | `step` |
| pipeline | a `flow` document |
| run | a flow run |
| runner | the runner (`cx flow serve`) |
| merge | the `pivot=` step |
| agent / integrator | `by=:agent` / `by=:principal` |
| pass / fail / cancelled | `:done` / `:failed` / `:cancelled` |
| retried once | `attempts=2` |

Each work term is a record: a release names its epics, an epic orders its issues, an issue
carries its decision, branch, pre-merge artifacts and merge commit. §5 is one flow per issue.
