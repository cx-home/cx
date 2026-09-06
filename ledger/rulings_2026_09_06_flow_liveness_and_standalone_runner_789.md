# Rulings 2026-09-06 — #789/#1313/#728, liveness and the standalone runner (WF-27, WF-28)

**Status: RULED (a) on WF-27 and WF-28 under the standing letter-acceptance
rule**, recorded before any spec text per the #832 process rule. Ruling ids,
in full so each greps literally: `789-WF-27a` `789-WF-28a`. Branch
`design/789-workflow`. Open to an owner veto.

**What these answer.** #1313 (the deployment host is the scheduler — timers
fire only in a live process) and item 3 of the scaling ladder
(`design/789/scaling_ladder_2026_09_05.md`): the standalone runner
`cx flow serve`, which the ladder names as one of the two pieces of new
load-bearing work. They are one packet because they are one question — who
guarantees a parked run wakes up — and #1313's filing answers it with one
runner where the ladder needs three.

## What I found by reading the shipped code, not the spec

#1313 describes the gap as a LOCAL-PROFILE gap: no live process after
`cx flow run` exits. That is true and it is the smaller half. Two defects
are in the shipped W1 timer path and they affect the HOSTED case too.

**Defect 1 — an expired one-shot never fires.** `f--after-commit`
(`stdlib/flow.cx`) arms each deadline with
`[$sched:after … {name: … durable: $journal}]` and passes **no `on-missed`
opt**. `sched.md` §2.5: the default is `:skip`, and under `:skip` *"a
one-shot already past simply does not fire."* So a deadline that elapses
while the process is down is dropped at restore, silently. The step stays
`:pending` or `:running` forever, the ladder never runs, and `fleet` shows
a run that is not stalled by the §4.12a predicate because nothing recorded
a thing.

**Defect 2 — after a restart, no flow timer fires at all.** `sched.md` §2.4:
the fire value is not serializable, so `[$sched:restore $journal $registry]`
re-arms only what the caller's `$registry` re-registers by timer name; an
intent with no entry is *"left armed-but-orphaned and reported in the
restore result."* Flow's fire value is a `[?fn () …]` closure over the run
id and step, and **nothing anywhere calls `restore` or builds that
registry** — grep `stdlib/flow.cx` and `vcx/cmd/flow.v` for `restore`. The
`[sched-intent …]` entries the `flow-036` fixture asserts are journaled are
real; nobody re-arms them.

Fixture `flow-036` passes because it advances a MANUAL clock inside one
process, where the closure is still live. It proves the timer arms. It
cannot see either defect, and no fixture crosses a restart.

Filed as a shipped bug against W1, separately from these rulings.

## WF-27 — liveness is a property of a RUNNER PROCESS, not of the document — RULED: (a)

- **(a) RULED — one law, three runners, three STATED liveness postures, and
  a public `rearm` verb that makes the two live ones honest.**

  | Runner | Liveness guarantee | Timers | Bindings |
  |---|---|---|---|
  | `cx flow run` (a checkout) | **NONE, stated** | re-armed on the next invocation of the same command line — the run id is derived from the args (PB-2), so the next `cx flow run` finds the parked run and fires what is due | none: the invocation IS the start |
  | `cx flow serve` (standalone, WF-28) | the process's | `rearm` at boot from the fold, then live | `[on …]` rows in the `[runner]` document |
  | the XAP deployment host | the deployment's | the same `rearm`, embedded | `[on …]` rows in the deployment document |

  **`rearm $journal $opts` becomes a public verb** returning `sched`'s
  `[restore-report …]`: it folds the journal to the pending flow
  `[sched-intent …]` set, builds the registry entry each one needs (the
  fire value is always the same shape — `advance` with
  `[timer-fired run= step= at=]`, PB-5 — so the entry is derivable from the
  timer's own name, `<run id>:<step>`), and calls `[$sched:restore]` with
  it. It is a command like every other verb, so it is grantable, journaled
  and refusable; a runner that does not call it has no timers, which is a
  thing an operator can see rather than a thing they discover in a month.

  **`on-missed` is pinned by kind, never left to the default.** A
  `deadline=` and a rung `within=` are ONE-SHOTS: `:fire-all` (for a
  one-shot, identical to `:coalesce`, and both differ from the `:skip`
  default in exactly the case that matters). An `every=` cadence
  (`until`, `attempts=` — WF-18/WF-26) is `:coalesce`: a runner down for a
  day does not fire forty canary polls on the way up, it fires one and
  resumes.

  **A missed deadline fires with its ORIGINAL instant**, not the boot
  instant: `[timer-fired … at=]` carries the instant the deadline was due,
  so the record says when it was due and the ladder evaluates from the
  original instants — possibly passing several rungs at once. **What this
  DELETES:** the alternative, forgiving downtime, which would make an SLA a
  function of the operator's uptime and make two replays of one journal
  disagree. It is deliberately NOT the `pause` rule (WF-25): a pause is an
  operator's recorded decision, a crash is not.

  **What it DELETES from #1313's filing:** the sentence "the XAP deployment
  host is the scheduler". The host is *a* scheduler. Writing it as *the*
  scheduler would make rungs 1 and 3 of the ladder — a make replacement and
  a CI/CD pipeline, neither of which deploys a XAP — permanently
  second-class, and would put the ladder's second invariant (one law, three
  runners) in the spec's own contradiction.
  **Strongest counter:** three postures is three things to explain, where
  "the host schedules" is one. **Answer:** the one-sentence version is
  false, and an adopter discovers it the first time a deadline does not
  fire in CI. Three rows in a table, each saying plainly what it guarantees,
  is the smaller cost.
- **(b) the host is the only scheduler; the local profile makes no claim.**
  REFUSED: it is #1313 as filed, it leaves defects 1 and 2 in the hosted
  path unfixed (they are not local-profile defects), and it contradicts the
  ladder.
- **(c) flow keeps its own timer wheel.** REFUSED: a second clock, against
  §5's "no new capability of its own", and `sched` already has durable
  timers, `restore` and a catch-up policy — the defect is that flow does
  not USE them, not that they are missing.

## WF-28 — the standalone runner `cx flow serve` and the `[runner]` document — RULED: (a)

- **(a) RULED — `cx flow serve` is a long-running process holding ONE
  journal, driven by a `[runner]` document, running the same `advance` law
  as the other two runners; the XAP host EMBEDS the same loop.**

  ```cx
  [runner name="ci"
    [journal url="file:///var/lib/cx/flow" stream-prefix="flow:"]
    [env 'ci-acts.cx']                                    ; the ONE resolver (§4.1)
    [on webhook path="/gh/push" start="sha2-256:9e…" as=principal:did:key:z6Mk…]
    [on schedule every=1d at="02:00" start="sha2-256:b4…" as=principal:did:key:z6Mk…]
    [on file glob=".cx/inbox/*.json" start="sha2-256:c1…" as=principal:did:key:z6Mk…]
    [courier every=30s]]
  ```

  **The `[on …]` row is the SAME row the deployment document carries**
  (§4.9, RULED: WF-3) — one binding vocabulary across both faces, which is
  what keeps a flow portable from a checkout to a pipeline to a deployment
  without an edit. The runner document adds only what a deployment document
  already says by other means: which journal, which resolver, how often the
  courier ticks.

  **What the runner holds, and what it does not.** It holds the `flow`
  capability to append transitions and nothing else — §4.5's courier rule
  is unchanged, and every step is admitted at the PEP against the RUN's
  recorded basis, never the runner's. It has no tenants, no surfaces, no
  cascade and no composed grammar: acts resolve through `[env …]`'s module
  tree exactly as `cx flow run --env` resolves them today. Its ingress
  accepts two things and no third: binding deliveries its `[on …]` rows
  declare, and correlated acts (`[act run= step= …]`, the shape `advance`
  already takes) — which is what lets a `:principal` or `:peer` step
  complete against a runner with no UX face of its own.

  **The host embeds it, and that is a GATE, not a hope.** The same flow,
  the same binding set and the same acts must produce byte-identical
  transitions under `cx flow serve` and under the deployment host. If the
  two loops can drift they are two products, and the ladder's first
  invariant is gone. The gate is a fixture pair, one per face, comparing
  journals.

  **What it DELETES:** the assumption, load-bearing in the design so far,
  that anything needing liveness needs a XAP deployment. It removes the
  reason a CI/CD pipeline or a make replacement would have to adopt the
  whole XAP model to get a timer.
  **Named landing, not ruled here:** the runner's signing key and any
  connector credential are read through a capability handle, never from the
  document — #728-6's secrets slice. Until it lands, `cx flow serve` runs
  with the capabilities its invocation was granted, like any other `cx`
  command, and the spec says so rather than implying more.
  **Strongest counter:** a `[runner]` document is a new document kind, and
  the §2.3 round cap exists to stop exactly this. **Answer:** the cap
  governs the FLOW vocabulary — what a flow document may say. WF-3 already
  ruled that bindings live outside the flow document, and a deployment
  document already holds them; this gives the same rows a home on the face
  that has no deployment document. No word enters §2.3.
- **(b) run bindings from CLI flags — `cx flow serve --on …`.** REFUSED: a
  binding set is a reviewable, versionable, addressable artifact; a flag
  soup is none of those, and it could not be the same thing the deployment
  document carries.
- **(c) reuse the XAP deployment document with an empty deployment.**
  REFUSED: a deployment document carries tenants, surfaces and cascade. A
  runner is not a degenerate deployment, and pretending it is drags the XAP
  model into rungs 1 and 3, which is the outcome (a) exists to avoid.

## Edit map — `spec/03-approved/std-lib/flow.md` (ruling-gated)

| Section | Edit |
|---|---|
| §3 | `rearm` signature and its four-channel answer |
| §4.9 | the `[on …]` row is the same row on both faces; the runner document named |
| §4.15 | retitled from "the local profile" to the three runners and their liveness postures — WF-27's table, with `cx flow run`'s "no liveness claim" stated in it, not implied |
| new §4.23 | the standalone runner: the `[runner]` document, what it holds, its ingress, the embed gate |
| §6 | the `sched` row gains `on-missed` pinned by timer kind and `rearm` as the restore half |
| §9 | a restart row: N pending timers, a restart, every one re-armed and every expired one fired once |
| §11 | fixtures: expired one-shot across a restart fires once with its ORIGINAL instant; `every=` across a restart coalesces to one; a restart with no `rearm` reports every intent orphaned (the defect, pinned as a negative); the host/serve byte-identical transition pair |
| `misc/cli.md` | `cx flow serve` and its flags |
