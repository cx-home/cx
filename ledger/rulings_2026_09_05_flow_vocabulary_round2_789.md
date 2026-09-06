# Rulings 2026-09-05 — #789 flow, vocabulary round 2 (WF-18 … WF-26)

**Status: RULED (a) on WF-18 … WF-26 under the standing letter-acceptance
rule**, recorded BEFORE any spec text per the #832 process rule. Ruling ids, in full so each greps literally: `789-WF-18a` `789-WF-19a`
`789-WF-20a` `789-WF-21a` `789-WF-22a` `789-WF-23a` `789-WF-24a`
`789-WF-25a` `789-WF-26a`. Branch `design/789-workflow`; nothing here touches
implementation. Every letter is open to an owner veto; WF-20 amends WF-16 and
WF-21/WF-22/WF-19 amend rows of the §2.3 refusals register that WF-2 closed —
those three amendments are called out per letter so the owner can reverse them
individually.

**Why a second round exists.** The first round closed nine words from the list
in #789 and then defended them. The target was never written down first. The
2026-09-05 inventory (`design/789/use_case_inventory_2026_09_05.md`, 44
processes an adopter actually runs) scored the closed vocabulary mechanically:
**4 expressible today, 22 under the waves as ruled, 16 blocked, 2 wrong tool.**
Thirteen of the blocked rows fail on a small repeating set of additions and
none fails on the substrate. This round rules that set. With it, 39 of 44 rows
are reachable; without it, 26.

**What this round costs, stated plainly.** The §2.3 table goes from **nine
words to seventeen**:

| New token | Kind | Rows it unlocks | Letter |
|---|---|---|---|
| `until` | element (the tenth word) | 6 13 25 35 38 | WF-18 |
| `attempts=` | attribute on `step` and `until` | 5 6 13 25 35 38 | WF-18, WF-26 |
| `every=` | attribute on `step` and `until` | 5 25 35 | WF-18, WF-26 |
| `needs=` | attribute on `step` / `branch` / `map` / `until` | the rung-1 build case | WF-20 |
| `quorum=` | attribute on `step` | 8 | WF-21 |
| `flow=` | attribute on `step` (a sub-flow reference) | 44, reuse across 1 16 23 | WF-22 |
| `calendar=` | attribute on `flow` / `step` / `branch` / `map` / `until` / rung | 11 and every SLA row | WF-24 |
| `[notify …]` | rung form inside `[escalate]` | 4 | WF-23 |

and the public verb surface gains five operator verbs (`cancel`, `pause`,
`resume`, `skip`, `retry-now` — WF-19, WF-25). Verbs are commands, so they are
grantable, journaled, projected and refusable like every other verb; they do
not enter the word table.

**The economies taken.** Two candidate pairs were merged rather than added
twice: a bound on `until` iterations and a bound on step re-attempts are ONE
attribute (`attempts=`, WF-18/WF-26), and the cadence between iterations and
between re-attempts is ONE attribute (`every=`). A separate `max=` was
rejected as a second spelling of the same bound.

**The cap, so there is no round three by drift (normative).** A vocabulary
round opens only on a written inventory of target processes showing rows the
current vocabulary blocks, with each proposed token naming the rows it
unlocks. No token enters between rounds. The WF-2 growth rule stands unchanged
and is applied per letter below: (i) no command can express it, AND (ii) it is
choreography — who acts, in what order, over which set, by when, under whose
authority — and not computation.

**Premises verified before ruling (not read off the spec's own sentences).**

| Claim under test | Checked against | Result |
|---|---|---|
| "approval quorum belongs to `authz` grants" (§2.3 register) | `std-lib/authz.md` §2.7, §3.4 | PARTLY TRUE. authz has **T2 co-signed M-of-N**: M of N NAMED principals co-sign ONE approval artifact, verified at the PEP, `CXER4704` when unmet. That is a two-person rule on a capability. It is NOT N independent acts arriving over time from a ROLE whose membership varies per tenant, with the run parked and a deadline running between them, and a partial count visible. WF-21 rules the second thing and leaves the first untouched. |
| "a business calendar exists somewhere" | `std-lib/time.md` §2.1, §3.10; `std-lib/sched.md` | FALSE. `time` has durations, periods, DST rules and RFC 5545 recurrence; `sched` composes `time` and holds no calendar logic. There is no open-hours / holiday / closure value anywhere in the tree. WF-24 therefore places that value in `time`, not in `flow`. |
| "`[idempotent]` is a declarable disposition" | `core/commands_effects.md` §110-111 | TRUE, and opt-in: an undeclared command is NOT idempotent and retry-unsafe. WF-26's gate rests on it. |
| "`map` already fans out into child runs correlated by run id" | `flow.md` §4.12 | TRUE — child id = content address over (parent id, map name, item index); each child's terminal transition is a correlated act into the parent. WF-22 reuses exactly that machinery. |

---

## WF-18 — bounded repetition: `until` (inventory rows 6, 13, 25, 35, 38) — RULED: (a)

- **(a) RULED — `until` enters the table as the tenth word: a BOUNDED
  do-until over a body of steps.**

  ```cx
  [until name="redline" when="$steps/countersign/result/@signed"
         attempts=5 every=3d deadline=30d
    [step name="revise"      by=:agent  [do 'contracts/revise' [doc $args/doc]]]
    [step name="countersign" by=:peer to=peer:acme
                             [do 'contracts/countersign' [doc $args/doc] [signed]]]]
  ```

  Normative semantics: the body runs, THEN the guard is evaluated — iteration
  one always runs, so the guard always reads a recorded result. Guard true →
  the construct is `:done`. Guard false → wait `every=` (a durable timer, none
  by default) and run the body again. `attempts=` is MANDATORY on `until`
  (that is what makes it bounded; absent or malformed → `CXER4952`).
  Exhausting `attempts=` with the guard still false is
  `:failed reason=:attempts-exhausted` and takes §4.8's path — which is
  exactly the canary-rollback shape of row 35. `deadline=` bounds the whole
  construct. Each iteration's step entries are recorded in the PARENT record
  carrying `iteration=N`; `$steps/<name>` resolves to the LATEST iteration and
  `$steps/<name>[iteration=N]` addresses an earlier one. The bound on
  iterations is what makes in-record recording safe — `until` is bounded
  repetition, `map` is unbounded fan-out, and that is the whole reason one
  stays in the parent's stream and the other becomes child runs.
  **What it DELETES:** the §2.3 register row "unbounded loops (`while`),
  recursion" is AMENDED, not removed — `while`, recursion and any repeat
  without a declared maximum stay refused; a repeat with a mandatory
  `attempts=`, a record guard and a deadline is admitted. It also deletes the
  workaround the register pointed at for row 25 — a `:peer` adapter polling
  outside the flow — which removes the polling from the picture, from
  `simulate` and from the record.
  **Growth rule:** (i) a command cannot express it, because three of the five
  rows repeat a body containing an OFFERED step (a human review, a peer
  countersignature) and an offered step parks the RUN — a command cannot park,
  cannot hold a deadline ladder across a park, and cannot be resumed by a
  correlated act. (ii) "how many times, how often, until what is recorded" is
  choreography by the WF-2 definition.
  **Strongest counter:** every loop is a slope toward a programming language in
  a document. **Answer:** the slope is the UNBOUNDED loop and the loop with a
  computed condition. Both stay refused: `attempts=` is a literal, the guard is
  the same CXPath over the record that `when=` already is (§4.4 unchanged), and
  the body is steps — no variables, no accumulator, no arithmetic. A reviewer
  can state the worst case of any `until` by reading two attributes. Two
  consequences of that same argument, ruled here so the spec does not invent
  them: **`until` inside `until` is refused** (`CXER4952` — nested bounds
  multiply into a worst case no reader computes at a glance), and **the
  tree's pivot may sit inside an `until` only when its `attempts=` is 1**
  (`CXER4954` — a repeated irreversible point is two pivots, the §4.7
  argument that refuses a pivot inside a `branch`). An `until` body
  otherwise holds steps, branches and maps like any container.
- **(b) express repetition as an attribute (`repeat-until=`) on `step` and
  `branch`, adding no word.** REFUSED. Rows 6, 13 and 38 repeat a SEQUENCE of
  two or more steps; the vocabulary has no sequence container outside a
  `branch` lane, so (b) forces a one-lane `branch` — a parallel construct with
  no parallelism — as the idiom for every multi-step round. That is a worse
  document and a worse picture than one honest word.
- **(c) refuse; keep the adapter workaround.** REFUSED: five inventory rows,
  and each one leaves the process invisible to the picture, the simulation, the
  record and the operator — the exact failure the register exists to prevent,
  arrived at from the other side.

## WF-19 — `cancel` as a public verb (rows 7, 13, 37) — RULED: (a)

- **(a) RULED — `cancel` is a public verb, an act on the RUN under the
  canceller's OWN authority, refused past the pivot.**
  `[?def cancel scope=public impure [effects [read] [write]] [returns element]
  ($journal::element $id::string $reason::element {} $opts::map {})]`.
  It appends a `:cancelling` transition carrying `actor=`, `authority=` and the
  reason; no further construct activates; a step already `:running` is NOT
  killed — its outcome is recorded when it lands (there is no cross-process
  cancellation here, and `code.md` §10.5.4 keeps that) — and then the run
  enters §4.8's compensation from the current position, ending `:cancelled`.
  Cancelling a run whose pivot is `:done` is REFUSED (`CXER4966`): the pivot's
  entire meaning is that past it there is no unwinding, and a verb that
  pretended otherwise would make the pivot advisory. A terminal run answers its
  record unchanged (the dedup posture of `advance`).
  **What it DELETES:** the §2.3 register row "races / first-of / cancellation
  of siblings" is AMENDED: cancelling a SIBLING STEP stays refused (that is a
  race, and it is a command's concern); cancelling a RUN is an actor's act on
  the run and is a verb, not vocabulary. It also deletes the only alternative
  an operator has today — a second authority path around the model, or editing
  a journal.
  **Growth rule:** it adds no word. As a verb it is grantable, dialable,
  journaled, proposable and projected with no further work (WF-13).
  **Strongest counter:** cancel could be a `resolve`-style resolution, reusing
  an existing verb. **Answer:** `resolve` consumes a `:conflict`; cancel acts on
  a healthy running run. Overloading one verb with two unrelated preconditions
  is the second spelling this project refuses.
- **(b) cancel as an `advance` event (`[cancel …]`) rather than a verb.**
  REFUSED: an `advance` event is admitted against the RUN's basis; cancel must
  be admitted against the CANCELLER's authority (X2). A verb has its own PEP
  decision; an event does not.
- **(c) refuse cancel.** REFUSED: three rows, and "stop this" is the first
  thing an operator asks of any engine in the field.

## WF-20 — `needs=`: step order as a DAG (WF-16 PARTIAL REVISIT; rung 1) — RULED: (a)

- **(a) RULED — `needs=` is an attribute naming PRECEDING SIBLING constructs;
  it RELAXES document order, it never creates one.** `needs="compile-a
  compile-b"` (a space-separated list of construct names, the `to=`
  precedent). Today document order is the total order; with `needs=`, a
  construct activates as soon as every construct it names is terminal
  (`:done` or `:skipped`), and constructs whose needs are met run in parallel.
  A name may only refer to a SIBLING that PRECEDES it in document order —
  which makes a cycle unrepresentable rather than detectable, and makes the
  document's reading order still the reader's order; a forward or non-sibling
  reference refuses `CXER4952`, as does an unknown name.
  **What it DELETES:** nothing from the surface, and nothing from WF-16 —
  `depends-on=`, `inputs=`, `outputs=` and targets stay refused. WF-16's row
  is AMENDED to say what it was actually about: FILE and DATA dependency, and
  staleness. `needs=` carries no file, no content address and no staleness
  rule; it is ORDER over named steps, which is the first half of the WF-2
  definition of choreography. What it deletes in practice is
  over-synchronization: the level-structured nesting of `branch` groups that
  is today's only way to express a build DAG makes every step in a level wait
  for the slowest one, which is precisely the reason make is not
  level-scheduled.
  **The boundary with `branch`, normative:** `branch` GROUPS — one name, one
  guard, one deadline, one join over lanes; `needs=` ORDERS — per construct,
  no group, no join. A `needs=` name may not cross a `branch` boundary. Two
  constructs, one for grouping and one for ordering, are not two spellings of
  parallelism: they are the static-group and per-node forms, exactly as
  `branch` and `map` are the static and dynamic forms of fan-out.
  **Growth rule:** (i) a command cannot express it — the parallelism is
  between OFFERED and durable steps that park; (ii) "in what order" is the
  definition's own words.
  **Strongest counter:** `branch` already gives parallelism, so `needs=` is a
  second way to say the same thing. **Answer:** the DAG that rung 1 needs is
  not level-structured. `package` needing `compile-c` and the two test steps,
  where the tests do not gate `package`'s dependency on `compile-c`, cannot be
  written as nested join-all groups without waits the build does not require.
  The over-synchronization is observable in the dogfood build flow's wall time
  and is a gate row, not an opinion.
- **(b) admit make's `depends-on=` / `inputs=` / `outputs=`.** REFUSED, WF-16
  unchanged: those are data-flow and computation identity; `[idempotent]` over
  input content addresses plus #734's hermetic executor is the sound answer
  where timestamps are not.
- **(c) refuse `needs=`; keep `branch` only.** REFUSED: rung 1's gate is this
  repository's own build and gate flows on `cx flow run`, and a make
  replacement that over-synchronizes is not one.

## WF-21 — `quorum=` on an offered step (row 8) — RULED: (a)

- **(a) RULED — `quorum=N` on a `:principal` step counts DISTINCT admitted
  acts by DISTINCT actors against the step's ONE recorded proposal.**
  `[step by=:principal to=role:regional-manager quorum=2 deadline=2d …]`. The
  step is offered once; each admitted act appends a transition leaving the step
  `:pending` with `quorum-met=K` visible in the record; the Nth act carries the
  step to `:done`, its transition holding the completing act's locator triple
  and a `[concurrence actor= authority= at=]` child per earlier act. A decline
  does not fail the step while the remaining membership can still reach N; when
  it cannot, the step is `:declined reason=:quorum-unreachable` and takes the
  failure path. `validate` refuses `quorum=` > 1 with `to=principal:` (one
  principal is not a quorum), `quorum=` on any `by=` other than `:principal`,
  and `quorum=` > 1 on a step whose `[do …]` leaves a field empty
  (`CXER4952`) — N actors approve ONE recorded proposal, and the human-task
  form (§4.6, RULED: #1260 CA-2) has no proposal to count against.
  Membership is resolved at OFFER time; a quorum larger than the
  resolvable role records `:failed reason=:quorum-unsatisfiable` as a
  transition, not a raise — a refusal that is a value, like a deadline expiry.
  **What it DELETES:** the §2.3 register row "approval quorum, approver lists,
  delegation on a step" is AMENDED to strike **quorum** and keep approver lists
  and delegation with `authz`. Verified above: authz's T2 M-of-N is M NAMED
  principals CO-SIGNING ONE artifact, a two-person rule bound on a grant. It
  cannot express a role of varying membership, N independent acts arriving over
  time, a run parked between them, or a partial count in a record. **The two
  are orthogonal and both apply:** `quorum=` counts APPROVERS of a step; the
  tier counts SIGNERS of each approval. A T2 act inside a `quorum=2` step needs
  its M-of-N co-signature twice.
  **Growth rule:** (i) no command can count completions of an offered step that
  the run is parked on; (ii) "over which set, how many" is the definition's own
  words.
  **Strongest counter:** the register's reason — a second authority vocabulary
  — was right in kind. **Answer:** `quorum=` grants nothing and attenuates
  nothing. Every one of the N acts is admitted at the PEP against its own
  actor's authority exactly as a `quorum=1` step is (§4.5, X2). The step counts;
  it does not authorize.
- **(b) express quorum as N sibling steps under a `branch` with a join.**
  REFUSED: it names the approvers statically, so it cannot express "two of
  whoever holds the role", and it changes the join semantics from N-of-M to
  all-of-N.
- **(c) refuse; send row 8 to authz.** REFUSED on the verified finding above.

## WF-22 — sub-flow by content address (row 44; reuse across 1, 16, 23) — RULED: (a)

- **(a) RULED — `flow=<Tier-1 address>` on a `step` starts a CHILD RUN of the
  referenced document, correlated by run id.** `[step name="approval"
  flow="sha2-256:9e…" [args [amount $args/amount] [order $args/order]]]`. The
  runner `start`s the child, pinned to that address, in the child's own stream;
  child id = content address over (parent id, step name) — the `map`
  derivation, one field narrower. The parent step parks; the child's terminal
  transition is a correlated act into the parent (§4.12's mechanism, unchanged);
  child `:done` → parent step `:done` carrying the child run id; any other
  child terminal → the parent's failure path. A `flow=` step carries no
  `[do …]` (they are alternatives, `CXER4952`) and its `[args …]` is checked
  against the referenced document's declaration at VALIDATE time, because the
  address is pinned. The reference is resolved at validation: an address that
  does not resolve, a reference cycle, or a run tree deeper than 32 refuses
  `CXER4967`. **The pivot rule follows the reference:** §4.7 counts pivots over
  the run TREE, and a referenced document's tree is part of the parent's — so a
  reusable approval sub-flow (no pivot) composes into any parent, and two
  pivots across a reference refuse `CXER4954` at validation. Compensating a
  `:done` sub-flow step compensates the child run in reverse; the pre-pivot
  compensability check therefore reaches through the reference.
  **What it DELETES:** the §2.3 register row "sub-flow as syntax" is AMENDED by
  its own stated reason — "correlation is by run id and locator, never by
  nesting". A REFERENCE correlates by run id; it is not nesting. `[flow]`
  inside `[flow]` stays refused. It also deletes the workaround the register
  named — "a command may `start` a flow" — for the reuse case, because that
  command's child run is invisible to the parent's record, absent from the
  parent's picture, and uncompensated when the parent unwinds.
  **Growth rule:** (i) a command CAN start a flow, and that is why the test is
  applied to what a command cannot do: park the parent on the child, correlate
  the child's terminal into the parent's record, and unwind the child when the
  parent compensates — the same triple that makes `:peer` a step rather than a
  library call; (ii) "who acts, in what order" across a reused sub-process is
  choreography.
  **Strongest counter:** references make the picture unbounded and review
  harder. **Answer:** the reference is a pinned Tier-1 address, so the picture
  is total and computable to any depth (§4.17 draws the child collapsed with
  its address and expands on selection), and the depth bound plus static cycle
  refusal keep it finite. Twelve copies of one approval sub-process, each
  drifting, is the worse review artifact.
- **(b) admit nesting (`[flow]` inside `[flow]`).** REFUSED: a nested document
  has no address of its own, so it cannot be versioned, migrated, pinned or
  reused — which is the entire point of row 44.
- **(c) refuse; copy the sub-process into each flow.** REFUSED: twelve copies
  drift, and `migrate` then has twelve lineage claims to write instead of one.

## WF-23 — a notify rung on `[escalate]` (row 4) — RULED: (a)

- **(a) RULED — `[notify to=… within=…]` is a rung form that TELLS someone
  without moving the offer.** `[escalate [notify to=role:owner within=5d]
  [notify to=principal:did:key:z6Mk… within=2d] [to role:renewals-lead
  within=1d]]`. When a `[notify]` rung's `within=` elapses, the runner appends
  a `:reminded` transition naming the recipient and the step, `offered-to=` is
  UNCHANGED, and the ladder continues to the next rung. A rung carries no
  `[do …]`: the flow says WHO is told and BY WHEN; HOW the reminder is
  delivered is a binding on the `:reminded` transition in the deployment
  document, exactly as WF-3 places every other event's mechanism at the
  binding. A ladder needs at least one rung; the mix and order are the
  author's.
  **What it DELETES:** nothing. §2.3's `escalate` row changes from `[to …]+`
  to a ladder of `[to …]` and `[notify …]` rungs.
  **Growth rule:** (i) no command can express it — the rung fires from the
  step's own deadline clock while the run is parked, and it must not disturb
  the offer; (ii) "who is told, by when" is choreography's own words.
  **Strongest counter:** allowing a rung to emit anything reopens computation
  in the ladder. **Answer:** it emits nothing. It records a transition; the act
  of delivering lives at a binding, and a `[do …]` inside a rung stays refused.
- **(b) spell it `[to … notify=true]` on the existing rung.** REFUSED: a `to=`
  that does not offer to `to=` is a trap for every reader of the document, and
  the picture must draw the two rung kinds differently anyway.
- **(c) refuse; model reminders as extra steps.** REFUSED: a reminder step
  would have to run WHILE the offered step is parked, which the vocabulary has
  no way to say — and saying it would need a concurrency word.

## WF-24 — `calendar=`: durations in business time (row 11 and every SLA row) — RULED: (a)

- **(a) RULED — `calendar=<Tier-1 address>` names a business calendar that
  every duration in its scope is measured against, and the calendar VALUE and
  its arithmetic land in `cx-stdlib/time`, not here.** Verified above: no
  open-hours / holiday / closure value exists anywhere in the tree. Placing it
  in `flow` would put calendar arithmetic inside a choreography module and
  duplicate what `time` owns. Therefore, a NAMED LANDING in `time.md`, beside the clock-free recurrence surface of §3.10: a
  pure `[business-calendar tz= [hours day= from= to=]… [holiday date=…]…
  [closure from= to=]…]` value plus the pure functions that add an open-time
  duration to an instant and report the next open instant — clock-free and
  fixture-reproducible like the rest of §3.10. `flow` carries only the
  attribute: `calendar=` on `flow` (the document default) overridable on
  `step`, `branch`, `map`, `until` and each rung. In its scope, `deadline=`,
  `every=`, `within=` and `stall-after=` are measured in calendar-OPEN time; a
  4h deadline armed at 15:00 Friday under a 09:00–17:00 Mon–Fri calendar
  expires at 11:00 Monday. The instant is computed ONCE at activation from the
  pinned calendar document and recorded in the record, so the resolution is
  deterministic and replays byte-identically. An address that does not resolve
  or is not a `[business-calendar]` refuses `CXER4968` at validation.
  **What it DELETES:** nothing. §2.3's `deadline=` row gains a sentence: wall
  clock by default, calendar-open time when a `calendar=` is in scope.
  **Growth rule:** (i) no command can express it — the durations are the
  runner's own timers; (ii) "by when" is choreography's own words, and a
  business calendar is exactly what "by when" means to every buyer in the
  inventory's service, finance and HR domains.
  **Strongest counter:** a date library inside a workflow document is scope
  creep. **Answer:** which is why the value and every function that touches it
  are ruled INTO `time` and out of `flow`; `flow` gains one attribute that
  names an address.
- **(b) put the calendar value in `flow.md`.** REFUSED: orthogonality — `time`
  owns duration and calendar arithmetic and `sched` already composes it rather
  than reimplementing it.
- **(c) refuse; let authors compute business deadlines in a `:runner` step and
  pass an instant.** REFUSED: `deadline=` takes a duration, not an instant, so
  this does not type; and it would move the SLA out of the picture and out of
  `simulate`.

## WF-25 — the operator verbs `pause` / `resume` / `skip` / `retry-now` (rows 41, 42) — RULED: (a)

- **(a) RULED — four public verbs, each an act on the RUN under the
  OPERATOR's own authority, each a recorded transition.**

  ```
  [?def pause     scope=public impure [effects [read] [write]] [returns element] ($journal::element $id::string $reason::element {} $opts::map {}) ...]
  [?def resume    scope=public impure [effects [read] [write]] [returns element] ($journal::element $id::string $opts::map {}) ...]
  [?def skip      scope=public impure [effects [read] [write]] [returns element] ($journal::element $id::string $step::string $reason::element {} $opts::map {}) ...]
  [?def retry-now scope=public impure [effects [read] [write]] [returns element] ($journal::element $id::string $opts::map {}) ...]
  ```

  `pause` → run `:paused`; no construct activates; an in-flight step's outcome
  is still recorded. **Timers SUSPEND while paused**: each armed deadline's
  REMAINING duration is recorded at pause and re-armed at `resume`, so paused
  time does not count against an SLA — without that rule a pause is useless to
  the operator it exists for. `skip` records the named step
  `:skipped reason=:operator` with the operator's actor and authority and
  activates its successors; it refuses a `:done` step, and it refuses a
  pre-pivot step whose successors include the pivot (`CXER4966`) — skipping a
  step the pivot's compensability argument depends on would silently break
  §4.7. `retry-now` re-attempts the failed or incomplete tail immediately
  rather than at the next courier tick or `every=` interval; it is not the
  empty `advance` tick, which does not re-attempt a `:failed` step.
  **What it DELETES:** the operator's only alternatives today — waiting, or
  reaching around the model. It makes the day-one ops console (#787) a
  projection of five verbs (with `cancel`) rather than a feature.
  **Growth rule:** verbs, not words. `claim` / `release` / `reassign` /
  `resolve` are the precedent: operator acts on a run belong in the function
  surface, where they are grantable, journaled, projected as agent tools and
  refusable by the PEP.
  **Strongest counter:** `skip` lets a human break the process the document
  promised. **Answer:** it is recorded — actor, authority, reason, a
  transition in the run's stream and a mark on the picture — which is more
  than the field's consoles offer and strictly better than the alternative,
  which is a human doing it outside the record.
- **(b) one `operate` verb taking a `[resolution]`-style element.** REFUSED:
  one verb with four preconditions cannot be granted separately, and granting
  `skip` without `cancel` is exactly the distinction an operations dial needs.
- **(c) refuse; restart runs instead.** REFUSED: a restart loses the record and
  re-performs effects.

## WF-26 — `attempts=` on a step: bounded re-attempt, `[idempotent]`-gated (row 5; #1314) — RULED: (a)

- **(a) RULED — `attempts=N` on a `step`, admitted ONLY where the step's
  resolved command declares `[idempotent]`, with `every=` as the cadence.**
  `[step name="charge" attempts=3 every=1w [do 'billing/charge' …]]`. A
  `:failed` act on a step with `attempts=` re-attempts up to N times, waiting
  `every=` (a durable timer, subject to `calendar=`) between attempts; the
  record carries `attempt=K`. Exhaustion is
  `:failed reason=:attempts-exhausted` and takes §4.8's path — compensation
  pre-pivot, the ladder if the step has one, and the fabric DLQ as the failure
  binding. `validate` refuses `attempts=` on a step whose resolved command does
  not declare `[idempotent]` (`CXER4952`, naming the verb): an undeclared
  command is retry-unsafe by construction (`commands_effects.md` — disposition
  is opt-in, deny-by-default), so an ungated `attempts=` would authorize double
  charges from a document.
  **What it DELETES:** the §2.3 register row "retry policy (`retries=`,
  `backoff=`)" is AMENDED: a retry policy with a curve — backoff multipliers,
  jitter, a retry budget — stays refused and stays the command's or the DLQ's;
  a literal count with a literal cadence, gated on a declared disposition, is
  admitted.
  **The boundary with `until`, normative:** `until` repeats a body until a
  RECORDED CONDITION holds, and each iteration SUCCEEDS; `attempts=`
  re-attempts an act that FAILED, before the failure path opens. They are not
  interchangeable — under `until` a failing step enters the failure path and
  there is no second iteration, and making `until` swallow failures would hide
  them. Sharing `attempts=`/`every=` between them is deliberate: one bound, one
  cadence, one thing to learn.
  **Growth rule:** (i) a command can retry itself, but it cannot record the
  attempt in the run's record, show it on the picture, respect the step's
  deadline ladder, or hand the exhaustion to the run's compensation; (ii) "how
  many times, how often" is choreography, and the gate keeps the SAFETY
  question where it belongs — on the command's declared disposition.
  **Strongest counter:** the register was right that retry is command policy.
  **Answer:** and it stays there — the ruling adds no policy the command does
  not already carry. `attempts=` says only how many times the CHOREOGRAPHY
  will call a command that has declared itself safe to call again.
- **(b) `attempts=` ungated, with authors responsible.** REFUSED: it would let
  a document authorize a double charge, against a deny-by-default disposition
  rule.
- **(c) refuse; write dunning as an `until` over a non-failing command.**
  REFUSED: it forces every retryable act to be rewritten to return a value
  instead of an `[err]`, which is the wrong shape for a payment gateway and
  changes the command surface to work around a missing attribute.

---

## Edit map — `spec/03-approved/std-lib/flow.md` (this branch, ruling-gated)

| Section | Edit |
|---|---|
| §2.1 | the document example gains `needs=`, `until`, `quorum=`, `attempts=` in a second illustrative flow (the first stays as the M5 checkout) |
| §2.2 | run status `:paused` · `:cancelling` · `:cancelled`; step status `:cancelled`; `iteration=`, `attempt=`, `quorum-met=`, `[concurrence …]`, `reason=` on `:skipped` |
| §2.3 | the word table 9 → 17 rows; the growth rule gains the round cap; five refusals-register rows amended (loops, sibling cancellation, sub-flow, quorum, retry policy) with the amended text stating what STAYS refused |
| §3 | five verb signatures (`cancel`, `pause`, `resume`, `skip`, `retry-now`) with their four-channel answers |
| §4.3 | `needs=` and the activation rule (WF-20) |
| §4.4 | `$steps/<name>` resolves to the latest iteration; `[iteration=N]` addresses an earlier one |
| §4.6 | `quorum=` on an offered step (WF-21) |
| §4.8 | `attempts=` before the failure path; `until` exhaustion; cancel's entry into compensation |
| §4.10 | `migrate` across a `flow=` reference |
| §4.12b… | new §4.18 `until`, §4.19 `needs=`, §4.20 sub-flows, §4.21 the operator verbs, §4.22 business calendars |
| §4.17 | layout rules for `until` (a back edge with its bound), `needs=` (DAG edges), a sub-flow (a collapsed node carrying the child address), a `[notify]` rung (a bell mark), a paused/cancelled overlay |
| §6 | `time` gains the `[business-calendar]` row |
| §7 | the applicability matrix gains `until` as a column and the seven new attributes as rows |
| §8 | `CXER4966` `E_COORD_OPERATOR_REFUSED`, `CXER4967` `E_COORD_SUBFLOW_INVALID`, `CXER4968` `E_COORD_CALENDAR_INVALID`; `CXER4969` stays reserved |
| §11 | a fixture pair per letter, and a negative fixture per amended register row |
| §12 | the `time.md` `[business-calendar]` landing added to the edit map |

**Codes:** the band's tail is now fully spent but for one. `CXER4969` is the
last reserved code in `CXER4950–4969`; a further coordination code needs a
governance §9.6 band extension, and that is a deliberate brake on round three.
