# Rulings 2026-09-03 — #789 general workflow on the saga substrate (WF)

**Status: RULED (a) on WF-0..WF-14 BY OWNER 2026-09-03 ("all a — draft the
spec"); WF-15..WF-16 RULED (a) BY OWNER 2026-09-03 ("all a") on the
store-requirement and dogfood questions raised after the draft.** Recorded BEFORE any spec text per the #832 process rule; the spec
draft `spec/02-working/flow.md` is authored under these rulings and carries
`RULED: WF-n` tokens; graduation stays owner-only (G3). Branch
`design/789-workflow`; nothing here touches `release/0.18`. Ruling ids
`789-WF-0a … 789-WF-14a`.

**The bar (owner, 2026-09-03, this session).** *A world-class workflow engine
that matches and exceeds the engines of the major application and SaaS
vendors — in capability, performance, scale, ease of design, change
management and implementation. Agents may be used in every aspect: design,
operations, execution. It scales, as the cx store does, from the simple and
quick to massive, complicated workflows.* Every letter below is written
against that bar, and the matrix in the next section says, capability by
capability, where the design equals the field, where it exceeds it by
construction, and where it must still earn the claim.

**Inputs read.** #789 (the design filing + the AD-5 cross-reference), #728
(the ETL/iPaaS track — component 1 "durable orchestration" is this design),
#787 (the UX framework whose approval widget, studio and ops console are this
feature's faces), #1185 (the XAP-facing half, RULED AD-5 (a), CLOSED with the
`xap.md` §13 truing X1–X4), the stream-10 spec
`spec/_archived/cross_stream_coordination.md` (L155–L162, graduated into
`xap.md` §14.2 + governance §9.6) and its implementation ledger
`ledger/partition_I5_stream10_coordination.md`, `journal.md` (the two saga
signatures), the shipped runner `vcx/platform/coordination.v`, fixtures
`journal-139/140/141`, `authz-084/085`. Filed this week and bearing on the
design: **#1256** (2026-09-03 — names "the workflow engine now in progress"
and asks for the deriver-vs-workflow-step line), **#1260** (one act, two
spellings), **#1217** (projection reaches `[?def]` commands, not feature
verbs), **#1210** (the host hands a feature no journal), **#1231** (a bareword
command in a def body fails its `[requires-at]` admission).

**Standing constraints this packet respects.** Orthogonality — no second
vocabulary for anything that has one (AD-5 (a) stands: #1185 IS this design's
XAP face, and a second rule engine inside XAP is in the refusals register);
the stream-10 derivation stands (cross-stream atomic commit REJECTED; no
fourth serialization point; the runner is stateless); no stubs, no partial
implementations, cutover-first (no dual-accept); every new position
positive- AND negative-fixtured; each letter states what it DELETES and
argues the strongest case against its own pick.

---

## The field, and where this design stands against it

The comparators, by class: **durable-execution engines** (Temporal-class:
code-as-workflow, replayed history, activities with retries, signals and
queries, child workflows, timers and schedules, patch-based versioning,
visibility search, task queues and worker fleets); **BPMN/DMN engines**
(Camunda-class: visual models, user tasks and forms, message correlation,
boundary events, compensation, multi-instance, decision tables, versioned
deployments with running-instance migration, an operate/tasklist/optimize
console); **cloud state machines** (Step Functions-class: a closed state
language — choice, parallel, map with distributed fan-out and tolerated
failure, wait, callback tokens — express and standard modes, redrive); and
**SaaS low-code / case engines** (Salesforce Flow, ServiceNow Flow Designer,
Pega, Appian, Workday class: record triggers, screens, approvals, subflows,
work queues, assignment and SLA, versioned activation). Every one of them
requires a privileged engine somebody owns; none carries provable authority
per step, none crosses a company line without a shared coordinator, and in
all of them the process definition is a vendor artifact, not a value.

| Capability | The field | This design | Letter |
|---|---|---|---|
| Definition as reviewable, diffable, deployable data | vendor artifact (JSON/BPMN XML/code) | a content-addressed CX document; `store put` deploys it; every face projects it | WF-1 |
| Durable execution, crash-free resume, exactly-once effects | engine + history replay | the journaled run record IS the durable state; the stateless `advance` law; idempotent steps; pins | WF-1, WF-5 |
| No privileged engine; racing workers safe | engine required | courier advancers + per-stream CAS; **exceeds** | WF-5 |
| Parallel / conditional / wait / timers | all | `branch`, `when=`, offered steps, `deadline=` (durable timers) | WF-2, WF-4 |
| Dynamic fan-out at scale, tolerated failure | Step Functions distributed map; Camunda multi-instance; Temporal child workflows | `map` into child runs in their own streams, `max-parallel=`, `tolerate=` | WF-10 |
| Human tasks, approvals, forms | user tasks, approval widgets, screens | `by=:principal` offered steps over propose/approve; the #787 widget; forms projected from the act | WF-4 |
| Work management: inbox, claim, roles, SLA, reassignment | Pega/ServiceNow strength | inbox = a readout of offered steps by role; claim/release/reassign = acts; SLA = `deadline=` + ladder | WF-12 |
| Agents as executors under bounded authority | absent or bolted on | `by=:agent` under attenuated `[delegation]` + `[bounds]`; hand-back with a brief; **exceeds** | WF-4 |
| External events / callbacks / message correlation | signals, task tokens, message events | offered steps completed by a correlated act (`by=:peer`); the run id is the token | WF-4, WF-8 |
| Cross-company flows with no shared coordinator | none | delegated intents + signed step acknowledgments; each journal holds its half; **exceeds** | WF-8 |
| Provable per-step authority, attribution, hash-chained history | audit logs | X2 at every layer; every transition attributed and chained; `why-allowed`; **exceeds** | WF-5 |
| Versioning with running-instance migration + fleet preflight | Camunda migration plans; Temporal patches | pin-at-start; `migrate` with a lineage claim; dry-run classifies every run first | WF-6 |
| Long / infinite histories | continue-as-new; history limits | transitions as deltas over snapshots; child runs shard; schedule-bound runs replace infinite ones | WF-11 |
| Fleet visibility, stall detection, search | consoles, search attributes | a derived, per-party `fleet` readout; stall as a pure predicate; CXPath over records; the #787 console | WF-7 |
| Visual design + AI authoring | modelers; nascent copilots | flows render to `diagram` for free; the studio edits the document; agents author, validate and simulate; **exceeds** | WF-13 |
| Simulation / testing of a definition | limited | `simulate` — the pure runner law over a supplied result table; fixtures for user flows | WF-13 |
| Decision tables (DMN) | Camunda DMN | a decision table is a document evaluated by a PURE function — a command, never flow syntax; named landing | WF-13 |
| Connectors to external systems | integration catalogs | #728 component 2 (the connector SDK); a connector call is a command step | WF-9 (dependency) |
| Throughput / latency at scale | engine-bound | per-stream commit lock ⇒ parallel across streams; measured gates, not claims | WF-14 |

Where the design equals the field it does so with fewer moving parts; where
it exceeds, it does so by construction, not by feature count. Where it must
still earn the claim (fan-out, history growth, work management, performance)
the letter names the mechanism AND the gate that proves it.

---

## Measured evidence recorded before the letters

**E-1 — the shipped saga surface is a program value, not a document.** On
`cx v0.17.0` the definition is
`[saga-def id=… [step name=… pivot=true? [fn $command] [args {…}]]…]`, run
by `[$journal:saga-run $j $def {stream actor authority}]`, read by
`[$journal:saga-status $j id {stream}]`, recorded as
`[saga id= status= [step name= status= pivot=]…]` in the home stream
(current state = the last record with that id). `[fn $command]` is a
CLOSURE VALUE: the definition cannot be `store put`, content-addressed,
diffed, reviewed, or projected — the exact properties #789 item 1 asks for.
What the runner ships (523 lines, `coordination.v`): ordered command steps,
per-step transitions journaled, the record as the durable step-dedup (a
completed run answers `[deduped …]`), one-pivot validation, the pre-pivot
compensability check (today `E_JOURNAL_ARG_INVALID`), reverse compensation
via the def's `[compensates]` pairing, forward-only past the pivot with a
visible `incomplete=` and tail-only resume, the ONE
`[conflict kind=:uncompensatable policy=:manual-resolution]` value. What it
does NOT have: branches, guards, deadlines, escalation, principal or agent
steps, fan-out, any fleet read (`saga-status` reads one id in one stream),
any versioning of the definition, any cross-party carriage. **And every
transition appends the WHOLE record** (`coord_saga_append` re-emits all
steps): bytes per run grow quadratically in step count — fine for a
three-step checkout, disqualifying for the bar (WF-11).

**E-2 — the normative home is thin.** `journal.md` carries the two
signatures and no prose; the vocabulary's normative text is one paragraph in
`xap.md` §14.2 plus the governance band row `CXER4950–4969` ("the band's
remaining tail stays reserved for the coordination surface"; two codes
shipped). The archived stream-10 spec is the rationale record.

**E-3 — the substrate every letter composes is already shipped.** Propose /
approve / commit with address-bound signed Lane-2 approvals
(`commands_effects.md` §5, `authz.md` §3.10); `[requires-at]` admission pins
(B3 reads, `CXER4950/4951`); escrow allocations; durable `sched` timers
(`[sched-intent]` + `restore`); the fabric DLQ precedent; `authz`'s
incapacity-predicate library already carrying `no-ack-within` and
`escalation-exhausted`, and the `xap.md` §21.1 handoff brief; stream 18's
tool projection with `[requires]` in `_meta` and enforcement at the PEP;
live's checkpointed `materialize`; journal snapshots and per-stream folds;
`:at-head-set` as the multi-stream READ cut; XSP §5.0 transcript-covered
semantic-feature tokens; the federation seam (`xap.md` §22.6.1: a cross-XAP
effect is a delegated intent; no XAP reads another's journal);
`[schema-lineage]` claims (stream 21); the `diagram` module; the #787
studio's selection-as-context protocol and the `ux.md` §18.5 fleet model
(`adopt-base` dry-run classification).

**E-4 — the XAP layer's four properties are RULED and recorded** (`xap.md`
§13, AD-5 (a)): X1 actions may name only verbs in the composed grammar; X2
authority is the constituents' — an action is admitted only where the actor
could have emitted that verb directly at the same PEP (N-COMPOSE-2); X3
`dial=` governs execution, irreversible actions floored at approval; X4 a
definition naming a vanished verb refuses at VALIDATION in the
`[!compose-conflict]` shape. These are properties of resolution and
admission, not new words; every letter below is checked against them.

---

## WF-0 — home, name, and the cutover of the shipped saga surface (item 1, substrate) — RECOMMENDED: (a)

- **(a) RECOMMENDED — a new Ring-2 stdlib module `cx-stdlib/flow` with its own
  spec, owning the document `[flow …]`, the instance record `[flow-run …]`,
  and the verbs `validate` / `start` / `advance` / `status` / `fleet` /
  `migrate` / `simulate` / `claim` / `release` / `reassign` / `resolve`.** The
  journal's `saga-run` / `saga-status` and the `[saga-def]` / `[saga]` heads
  are RETIRED cutover-first: a linear flow with one pivot IS the saga, and the
  word survives in prose as the name of the pattern. Error codes take the
  reserved tail of the coordination band (`CXER4952–4969`, prefix
  `E_COORD_*`, registered before first use) — governance reserved that tail
  for exactly this surface; if the tail proves short at spec time the draft
  claims the next free hundred block instead and says so. Spec home:
  `spec/03-approved/std-lib/flow.md` at graduation, drafted at
  `spec/02-working/flow.md`; `xap.md` §13/§14.2 and `journal.md` retarget by
  section title. **What it DELETES:** the `saga-*` verb names and the
  `saga-def` / `saga` heads — fixtures `journal-139/140/141` re-pin, the two
  `journal.md` signature lines move, one `xap.md` §14.2 sentence retargets,
  the docs-src saga sentence follows. **What it KEEPS:** every runner
  semantic in E-1, `[compensates]` and `[requires-at]` as def clauses,
  escrow, the conflict value, the band. **Strongest counter:** a rename of a
  shipped, fixture-pinned surface for a word. **Answer:** CX has no external
  users; the rename is cheap now and permanent later; a "saga" that contains
  a human approval step misnames what it is (a saga is a sequence of
  compensable transactions, and a flow is a superset); and `xap.md` §13
  already says, normatively, "#789's flow-as-document vocabulary".
- **(b) extend `saga-def` in place under `journal`, no rename.** Rejected:
  the journal is the log; principal and agent orchestration, deadlines,
  escalation, work management and fleet reads are not log concerns, and the
  misnomer stands forever.
- **(c) both names.** REFUSED — dual-accept.

## WF-1 — the flow document (item 1) — RECOMMENDED: (a)

- **(a) RECOMMENDED — `[flow …]` is an ordinary content-addressed CX document;
  a step names its act by QUALIFIED NAME and never by closure.** Shape (the
  spec fixes syntax; the ruling fixes what is in it): `[flow name= [args …]?
  (step | branch | map)* ]`; `[step name= do=<qualified act> [args …]?
  pivot=true? by=… when=… deadline=… [escalate …]?]`; `[branch …]` and
  `[map …]` per WF-2/WF-10. Resolution of `do=` happens at VALIDATION
  (`validate`, and again at `start`) against the executing environment's ONE
  resolver — the module tree in a program, ρ over the composed grammar in a
  XAP (X1) — and an unknown or unservable act refuses as a value before any
  step runs (X4; the `:unservable-verb` class of AD-10 is the precedent). The
  act's fields ride in the canonical act form **#1260 rules** — this spec
  ADOPTS that form and mints no third spelling. Pairing stays where
  L156/L157 put it: `[compensates]` on the command def; the flow places the
  PIVOT and orders the steps, it never declares compensators. **The runner
  law, normative:** `advance` is a PURE function of (flow document, run
  record, one event) → (the transitions to append, at most one side effect
  to perform); any process holding the capability may call it; there is no
  engine process, and crashing one costs nothing. That purity is what makes
  `simulate` (WF-13) and the racing-advancer guarantee (WF-5) fall out
  rather than be built. The record `[flow-run id= flow=<Tier-1 address>
  status= …]` PINS the flow document's address at start (WF-6). **What it
  DELETES:** `[fn $closure]` in a step. **What it KEEPS:** `[args {…}]`,
  `pivot=`, the one-pivot rule, the pre-pivot compensability check (moving
  from `E_JOURNAL_ARG_INVALID` to a flow validation code), every transition
  shape. **Strongest counter:** by-name resolution reintroduces #1231's
  class (a bareword resolved in one frame keyed differently in another).
  **Answer:** the runner already resolves compensators by name
  (`command_compensator_name`); `do=` resolves through the same path the
  `$cmd`-as-value form takes, and #1231 is fixed on its own merits — a
  defect to avoid, not a reason to keep closures.
- **(b) allow both closure and name.** REFUSED: two ways to say one thing,
  and the closure form can never be a document.
- **(c) let the flow declare a compensator per step.** Rejected: the
  authority to reverse an act belongs with the act's definition — its author
  knows the inverse — and a second declaration site lets a flow pair a
  command with a compensator its author never sanctioned. A
  context-dependent inverse is a SECOND command with its own pairing,
  chosen by the flow as a guarded step, not a pairing override.

## WF-2 — the closed vocabulary; the discipline boundary (item 2, make-or-break) — RECOMMENDED: (a)

- **(a) RECOMMENDED — the vocabulary is CLOSED at exactly nine words, and a
  growth rule guards the door.** The words: `flow`; `step`; `branch`
  (STATIC parallel fan-out of step sequences, JOIN-ALL — a branch completes
  when every sequence has; a failed sequence fails the branch and the run
  takes the ordinary failure path); `map` (DYNAMIC fan-out over a set in the
  run record into CHILD RUNS, WF-10); `pivot=` (one per flow, stream 10's
  rule); `when=` (a GUARD: a CXPath evaluated by EBV over the RUN RECORD
  ONLY — the flow's args and the prior steps' recorded results; false ⇒ the
  step is `:skipped`, a recorded transition, never an omission);
  `deadline=` (a duration from the step's activation, armed as a DURABLE
  sched timer); `escalate` (an ordered ladder of rungs
  `[to principal|role within=DUR]`, WF-4); `by=` (the performer axis,
  WF-4). **Everything else is a COMMAND** — real typed code with `[effects]`,
  idempotency, budgets and attribution: computation, external reads, retries
  beyond `[idempotent]` forward retry, unbounded loops (`while`), races /
  first-of (cancellation is a command's concern), sub-flows as syntax (a
  command may `start` a flow; `map` is the sanctioned fan-out; correlation
  is by run id and locator), variables and assignment, arithmetic, string
  templates, any expression beyond a CXPath guard, event triggers (WF-3),
  decision tables (a pure function over a document, WF-13). **The growth
  rule, normative:** a new word enters only by an owner ruling that shows
  (i) no command can express it AND (ii) it is CHOREOGRAPHY — who acts, in
  what order, by when, under whose authority, over which set — and not
  COMPUTATION (what the value is). `map` is admitted under that rule in this
  packet (WF-10 carries the proof). The XAP layer adds NO words: X1–X4 are
  properties of resolution and admission. The refusals register lives in the
  spec with one reason per row, and the AD-5(b) reopen trigger is restated
  there: only evidence from THIS vocabulary failing to express in-XAP
  automation may reopen a second one — never convenience. **The design's
  exit test:** the M5 checkout with an approval step and an agent step,
  #1185's three trigger kinds (as WF-3 bindings), #1256's fourth row ("a
  change to another feature's state = a verb of that feature, invoked by a
  workflow"), a 100k-item batch with tolerated failures (WF-10), and a
  cross-company order (WF-8) are all expressible in these nine words; a
  BPMN exclusive gateway with a default path is guards; a BPMN loop is
  DELIBERATELY not. **What it DELETES:** nothing shipped. **Strongest
  counter:** a path language in the flow is Step Functions' Choice-rule
  creep — the mini-DSL everyone regrets. **Answer:** CXPath is THE existing
  read language (lenses, readouts, queries), not a new one; what stops creep
  is not the language but the DOMAIN: a guard reads the run record and
  nothing else, so anything needing an external read or a computation is a
  step whose recorded result the guard then reads.
- **(b) no guards — a condition is a pure command returning the branch
  name.** Rejected: a comparison over data already in the record would need
  a `[?def]` per comparison, and it moves the choreography decision (WHICH
  branch) into code, where it cannot be projected, diffed or audited as a
  flow decision.
- **(c) a richer expression form in the flow (arithmetic, templates,
  loops).** REFUSED: the BPMN failure mode the issue names.

## WF-3 — how a flow starts: no triggers in the document (items 1+2; #1185 item 1; #1256) — RECOMMENDED: (a)

- **(a) RECOMMENDED — a flow starts ONLY by the `start` command, and the
  flow document carries no trigger.** `start` is an ordinary command:
  grantable, dialable (X3), journaled, propose-able. #1185's three trigger
  kinds are BINDINGS living where each event already lives: a schedule is a
  durable `sched` timer whose callback is `start` (an "infinite" flow — a
  monthly billing cycle — is a schedule binding starting one run per
  period, never one run that never ends); a committed intent is a fabric
  subscription (or journal consumer) calling `start`; a fold transition is a
  live `observe` adapter calling `start`. At the XAP layer the binding is
  ONE declarative row in the deployment document (`*.xap.cxd`, beside the
  `[deriver]` rows — the precedent for binding an actor in the wiring
  layer), naming the event and the flow address; the binder is the actor of
  the start and the PEP admits it as the binder's own act (X2). #1256's
  sentence becomes the spec's boundary statement, verbatim: *there are no
  triggers; every cross-feature effect is a named deriver or a visible act*
  — and the deriver/step line is drawn once: a derived FACT produced
  continuously is a deriver; an ACT by an actor on someone's decision is a
  flow step. **What it DELETES:** nothing. **Strongest counter:** #1185
  asked for the trigger IN the definition, and AD-5 said #789's vocabulary
  covers #1185. **Answer:** AD-5 ruled one VOCABULARY, and the three trigger
  kinds are covered — by bindings, not words. A flow with its trigger inside
  is an event-condition-action RULE, the rule-engine shape; and the same
  choreography could not be started by hand, by schedule and by event
  without three documents.
- **(b) triggers inside the flow document.** Rejected for the reason above.
- **(c) a separate `[rule]` document kind for triggers.** Rejected: a second
  document kind for what is one wiring row.

## WF-4 — the performer axis: principal, agent and peer steps; deadlines; escalation (items 1+2) — RECOMMENDED: (a)

- **(a) RECOMMENDED — `by=` says WHO emits the act; the runner RUNS it or
  OFFERS it; one existing mechanism per value, zero new ones.** An OFFERED
  step is the one wait mechanism in the design: the runner journals a
  `:pending` transition (and, when the args are fully given, the
  address-bound `cx:propose` proposal) and parks; the step completes when an
  ADMITTED act carrying the run correlation (run id + step name) lands —
  whoever emits it, under THEIR authority. The four values:
  `by=:runner` (default): the advancing process invokes the act under the
  run's recorded authority basis (WF-5).
  `by=:principal` (`to=` a named actor or role): a human emits — a signed
  Lane-2 approval of the proposal (the approval case) or the act itself with
  args the principal supplies (the human-task case); a decline is a recorded
  `:declined` transition that takes the failure path (reverse compensation
  pre-pivot) unless a ladder says otherwise. The #787 approval widget is the
  face, unchanged; pending steps with proposed args render as approve /
  reject, without them as the act's projected form (the #1217 gap applies
  to feature verbs and is noted, not ruled here). Every irreversible
  `:principal` act is floored at approval (X3).
  `by=:agent`: the runner OFFERS the step as a stream-18 tool scoped to this
  run, executable only under a `[delegation]` attenuated from the run's
  authority basis with `[bounds]`; the agent's invocation IS the step; an
  agent that cannot proceed returns `[err]` (the failure path) or an
  explicit hand-back, which enters the step's ladder with the §21.1 handoff
  brief.
  `by=:peer`: another system emits — a federated XAP or company through the
  delegated-intent seam (WF-8), or a non-CX system through an adapter
  (http/fabric) that presents the correlation; this is the callback token /
  message-correlation case, and the run id IS the token.
  `deadline=` arms a DURABLE sched timer at activation; expiry with no
  ladder = the step fails (the shipped semantics); with a ladder = the next
  rung is offered to its principal or role with its own `within=`;
  exhaustion parks the run `:stalled` — a visible, recorded state, never a
  hang — and authz's `escalation-exhausted` predicate MAY fire a pre-issued
  guardian grant (existing machinery). **What it DELETES:** nothing.
  **Strongest counter:** four performer values are vocabulary (WF-2 says
  small). **Answer:** one attribute, four values, ONE mechanism (the offered
  step) — and a flow with no `by=` reads exactly like today's saga.
- **(b) distinct step kinds `[approval]`, `[agent-task]`, `[human-task]`,
  `[wait-for-message]`.** Rejected: four constructs for one mechanism, and
  an approval "kind" invites its own attributes (approvers, quorum) that
  `authz` already expresses as grants — a second authority vocabulary.
- **(c) retry policy in the flow (`retries=`, `backoff=`).** REFUSED: retry
  beyond `[idempotent]` forward retry is policy that belongs on the command
  or on the fabric DLQ precedent, never in choreography.

## WF-5 — authority: the advancer is a courier; racing advancers (items 2+4; X2) — RECOMMENDED: (a)

- **(a) RECOMMENDED — the advancing process contributes NO authority to any
  step.** It holds the `flow` capability to append transitions and nothing
  more. Every step is admitted at the PEP against the run's RECORDED
  authority basis — the initiator's delegation for `:runner` steps,
  attenuated further for `:agent` steps, the emitting party's own for
  `:principal` and `:peer` steps — so X2 holds at every layer: a step is
  admitted only where that actor could have emitted the act directly. Two
  advancers racing on one run are safe by the home stream's CAS
  (`expect-pos`): one transition appends, the other refuses `CXER1114`,
  re-reads, and finds the work recorded (the durable step-dedup) — this
  becomes a normative fixture pair (racing advancers ⇒ one effect), and it
  is what lets the advancer FLEET scale horizontally with no leader election,
  no task queue and no lock service. `[requires-at]` pins and
  `[idempotent]` apply to a step exactly as to a direct invocation. #1231
  (the bareword pin defect in def bodies) is recorded as a defect the
  by-name resolution must not trip. **What it DELETES:** nothing.
- **(b) the advancer's identity is the actor.** REFUSED: "the workflow did
  it" becomes a privilege path — the exact thing X2 exists to forbid.

## WF-6 — change management: versioning a flow while runs are in flight (item 1; stream 21) — RECOMMENDED: (a)

- **(a) RECOMMENDED — a run PINS its flow document's Tier-1 address at start
  and follows it to the end; a new flow version starts new runs only; moving
  in-flight runs is an explicit, preflighted, journaled act.** `migrate` is
  a command (propose-able) that requires a Lane-2
  `[flow-lineage [from …] [to …] [relation …]]` claim mapping the completed
  steps of the old document onto steps of the new (the stream-21
  `[schema-lineage]` pattern, reused not re-minted); a completed step with
  no image refuses the migration as a value. **The fleet preflight is the
  `ux.md` §18.5 `adopt-base` pattern applied to runs:** `migrate` dry-run
  replays every in-flight run of the old version against the new document
  and classifies each — clean (maps), drifted (maps, but the pending step's
  neighborhood changed — reported), refused (a completed step has no image)
  — BEFORE anything commits; a refused run is presented to its owner as a
  decision, never migrated by guessing. **What it DELETES:** nothing.
  **Strongest counter:** a lineage claim per version bump is heavy.
  **Answer:** it is needed only to MOVE running instances; letting runs
  finish on their pinned version is free and is the common case — and the
  field's engines that lack a preflight (patch-in-code versioning) are the
  ones whose migrations fail at 3am.
- **(b) latest-wins — running runs pick up the new document.** REFUSED: the
  choreography of a recorded run changes under it; replay and `why-allowed`
  explanations stop being derivable from the record.
- **(c) no migration.** Rejected: quarter-long flows exist by design.

## WF-7 — fleet observability (item 3) — RECOMMENDED: (a)

- **(a) RECOMMENDED — the fleet view is a DERIVED READOUT, never a second
  write.** `fleet` is a live `materialize` — checkpointed, incremental,
  rebuildable from the journals — over run records across the streams the
  caller may read: an order-independent JOIN at an `:at-head-set` cut,
  exactly the replay rule's reporting join, and PER PARTY (no journal is
  read across a tenant or company boundary). It answers counts by status,
  runs per flow version, `:stalled` runs, `:uncompensatable` conflicts,
  post-pivot `incomplete=` totals, child-run completion per `map`, age
  since last transition, and any CXPath over run records and their args
  (the field's "search attributes" with no schema to declare). **Stall is a
  PURE PREDICATE** over (record, now): the newest transition is older than
  the active step's deadline (or the flow's `stall-after=` default) and no
  durable timer is pending — never a heartbeat, never a second process.
  Compensation-failure escalation = the existing
  `[conflict kind=:uncompensatable policy=:manual-resolution]` value
  surfaced as a fleet row and routed through the flow's ladder; `resolve`
  is the operator's (or ops agent's) act on it. The ops console is a #787
  surface projecting this readout (`[$ux:table]` + an SSE feed) — zero view
  code. In a build without the `live` pack, `fleet` refuses at composition
  naming the pack (the `CXER5095` precedent). **What it DELETES:** nothing.
  **Strongest counter:** a materialization over thousands of streams is
  expensive. **Answer:** it is checkpointed and incremental (live §7); the
  alternative that is cheap to read is (b), and (b) is the one that costs a
  write per transition and breaks the derivation.
- **(b) a dedicated fleet stream the runner appends a summary to on every
  transition.** REFUSED: a second writer per transition across two streams
  is the two-writer commit the stream-10 derivation forbids, and a second
  source of truth.
- **(c) an on-demand scan.** Rejected at fleet scale; it is (a) without the
  checkpoint.

## WF-8 — the cross-company profile (item 4) — RECOMMENDED: (a)

- **(a) RECOMMENDED — a cross-party step is a `by=:peer` step whose act is a
  DELEGATED INTENT over the federation seam, and the counterparty's answer
  is a SIGNED STEP ACKNOWLEDGMENT: a Lane-2 claim, the approval's shape
  reused.** The initiator's runner invokes the counterparty's act through
  its own authenticated XSP session (`xap.md` §22.6.1); the counterparty
  executes it in ITS journal under ITS PEP and returns the acknowledgment
  signed under its DID, binding (run id, step name, the counterparty's
  locator triple, status, the initiator's locator triple it acted on).
  Correlation: the run id is chosen by the initiator and unique by
  construction — a content address over (flow address, initiator DID, a
  ≥128-bit CSPRNG nonce) — and rides every cross-party intent and ack.
  **Normative on the wire:** the ack claim shape and the correlation
  attributes ONLY, negotiated as an XSP semantic-feature token (`flow`) that
  is transcript-covered (§5.0) — additive: a peer that did not confirm the
  token cannot be the target of a flow step, and that refuses at VALIDATION
  (X4), never mid-run. Each party's journal holds its half; there is no
  shared record and no shared engine; the counterparty's own flows may
  start from the delegated intent (WF-3) and are its business. Compensation
  across the line is another delegated intent to the counterparty's paired
  compensator, acknowledged the same way. Disputes settle by comparing the
  two chains at the locators the acks name — each party holds the other's
  signed statement of what it did. Sequenced behind the stream-4 wire
  maturity the issue names (the transcript-covered token carriage and its
  label bump). **What it DELETES:** nothing. **Strongest counter:** the
  counterparty must trust the initiator's run id. **Answer:** it trusts
  nothing — it signs what IT did, at ITS locator; the id is a correlation
  key, never an authority input.
- **(b) a shared coordination record or service both parties write.**
  REFUSED: the anti-2PC derivation, and the thing two companies will not
  agree to.
- **(c) acknowledgments as XSP per-request `auth-proof` signatures only.**
  Rejected: channel-bound proofs are not durable standalone evidence, and a
  dispute is settled offline, years later.

## WF-9 — sequencing; what this track delivers now — RECOMMENDED: (a)

- **(a) RECOMMENDED — design only now; the runner generalization is its own
  campaign.** This record; then, once ruled, the `spec/02-working/flow.md`
  draft (the closed vocabulary with its applicability matrix, the runner
  law, the record and transition shapes, the refusals register, the
  competitive matrix as the readiness bar, the performance gates, the corpus
  program, the band rows) — nothing graduates (G3). Implementation is a
  later release as a campaign with an umbrella issue, sequenced behind
  **#1260** (the canonical act form the step adopts) and **#1210** (the host
  must hand the runner the tenant's journal for XAP-layer flows); **#1217**
  is the same two-declaration-systems gap on the UX face and is noted, not
  ruled here; **#1231** is a defect the runner must not trip; **#728**
  component 2 (the connector SDK) is the dependency for external-system
  steps and is not this design. Implementation waves: W1 vocabulary +
  cutover + `validate` + the delta record (WF-11); W2 the runner
  generalization (branches, guards, deadlines, `map` into child runs); W3
  principal, agent and peer steps + escalation + work management (WF-12);
  W4 `fleet` + the console surface + `simulate` + diagram rendering (WF-13);
  W5 `migrate` with preflight (WF-6); W6 the cross-company profile (gated on
  the XSP token); W7 the performance gates (WF-14) + exit on `make test`.
  Acceptance fixtures: the M5 checkout with an approval step and an agent
  step, run twice (dedup), raced (WF-5), migrated (WF-6), each stream
  replayed in isolation byte-identical; the 100k-item batch (WF-10); the
  cross-company order (WF-8).
- **(b) rule and implement in v0.18.** Rejected: AD-7 already ruled this
  design-only for v0.18 — forcing the runner generalization into a release
  is how the BPMN failure mode gets in.

## WF-10 — dynamic fan-out at scale: `map` into child runs (the bar: massive workflows) — RECOMMENDED: (a)

- **(a) RECOMMENDED — admit `map` as the ninth word: `[map over=<cxpath into
  the run record> max-parallel=N tolerate=N|N% [step …]+]` runs its body
  ONCE PER ITEM as a CHILD RUN in the child's OWN stream, and joins.** The
  parent records ONE fan-out transition (the item count, the child-run ids
  by content address — `(parent run id, map name, item index)` — and running
  counts), never a step record per item; each child is an ordinary
  `[flow-run …]` whose terminal transition is a correlated act into the
  parent (the offered-step mechanism, WF-4). `max-parallel=` bounds
  in-flight children (the advancers pull the next item from the parent's
  recorded cursor under its CAS — no queue service); `tolerate=` says how
  many item failures the SET absorbs before the map fails and the run takes
  the ordinary failure path (a failed child compensates itself; the parent's
  compensation of an already-complete map is a `:runner` step the author
  places, because "undo a batch" is a business act). The body's steps may
  carry `pivot=` only if the parent has none (one irreversible point per
  run, counted across the tree — validation refuses otherwise). **Why this
  passes the WF-2 growth rule:** (i) a command that starts N child runs can
  fan OUT but cannot express the JOIN, the per-item visibility in the parent
  record, the cursor, or the tolerance without inventing all four privately;
  (ii) it is choreography — who acts, over which set, how many at once,
  when the set is done. **Why it scales like the store:** the parent stream
  carries O(1) records per map, the children shard across their own streams
  and commit in parallel under their own locks (the §14.2 partitioning
  argument), the fleet readout aggregates per parent, and a 100k-item batch
  costs the same per-stream work as 100k independent flows — which is what
  it is. **What it DELETES:** nothing shipped; it CLOSES the register's
  "loops / multi-instance" row with the sanctioned form. **Strongest
  counter:** `map` is the first word admitted after the list was drawn, and
  the door is now open. **Answer:** the door was never shut, it has a rule
  on it; `map` is the ONE construct every engine in the field converged on
  independently (Distributed Map, multi-instance, child workflows), the
  register still refuses `while`, and refusing `map` would send every
  adopter to build fan-out privately — the exact variance #1185 exists to
  remove.
- **(b) no `map` — a command starts child runs, and a `:peer` step with a
  count waits for them.** Rejected: fan-out without a join is not fan-out;
  the count, the cursor and the tolerance get rebuilt per adopter with no
  fixture and no projection.
- **(c) `map` inline — an item step record per item in the parent
  stream.** REFUSED: the parent record becomes a 100k-row document
  re-emitted per transition (E-1's quadratic growth, squared); it forfeits
  the per-stream parallelism the whole substrate is built on.

## WF-11 — the record at scale: transitions as deltas, snapshots, run-per-stream (the bar: performance and long histories) — RECOMMENDED: (a)

- **(a) RECOMMENDED — a transition is a DELTA entry; the run record is a
  FOLD; snapshots ride the journal's own machinery.** The runner appends
  `[flow-transition run= step= status= … ]` entries (one per step or
  fan-out event, plus start / terminal / migrate / claim entries) and the
  `[flow-run …]` record is the per-stream fold over them — the same
  fold-over-entries discipline every other journal-backed state uses
  (readouts, meters, holds). Reading a run = the journal's fold with its
  snapshot anchors, so a run with a million transitions is read from the
  last snapshot, not from entry one; the fold identity is pinned (stream
  21's quadruple) so replay is byte-identical. Default home stream:
  `flow:<run id>` — one run, one stream, one commit lock — with the
  caller's aggregate stream (`order:o-5521`) as the opt-in when the run
  should live with its subject (the shipped saga posture, kept). Retention
  of terminal runs rides the journal's retention and erasure vocabulary
  unchanged (a run about a subject is subject-sealed like anything else).
  **What it DELETES:** the whole-record-per-transition append the shipped
  runner does today (E-1) — `journal-139/140/141` re-pin on the fold's
  answer, which is the same document. **What it KEEPS:** "current state =
  the record", `[deduped …]`, every status word. **Strongest counter:** a
  fold per read is slower than reading the last record. **Answer:** with
  snapshots it is a bounded read, and the field's engines paid for exactly
  this lesson (history limits, continue-as-new); the alternative is a
  record that grows with the square of the step count.
- **(b) keep whole-record appends and cap step count.** REFUSED: a cap is
  the field's workaround, not a design; and it fails the bar by
  construction.
- **(c) whole-record appends with a separate compaction job.** Rejected: a
  second writer and a second process, for what the journal already does.

## WF-12 — human work management: inbox, claim, roles, SLA, reassignment (the bar: the SaaS/case engines' strength) — RECOMMENDED: (a)

- **(a) RECOMMENDED — the inbox is a READOUT and every work-management verb
  is an ACT; no new state.** A principal's inbox = the offered `:principal`
  steps whose `to=` names a role the actor holds (authz's grant set at read
  time) or the actor itself — a lensed readout over run records, projected
  by #787 like any other (`[$ux:table]` of pending steps, each with its
  approve/reject or form). `claim` (exclusive assignment to the claimer —
  recorded as a transition on the run under the home stream's CAS, so two
  claimers race safely and one wins), `release`, and `reassign` (a
  principal or role with authority over the step moves it; out-of-office is
  a standing `reassign` delegation, not a feature) are ordinary commands on
  the run: grantable, journaled, propose-able. SLA = `deadline=` + the
  ladder (WF-4), and the fleet readout's stall predicate reports breaches;
  skills-based routing is `to=` a role whose membership authz already
  computes. Case management ("a case with many flows over its life") is the
  aggregate stream: runs about one subject live in its stream (WF-11's
  opt-in) and the subject's readout lists them. **What it DELETES:**
  nothing. **Strongest counter:** the case engines' work queues are a
  product in themselves; a readout will feel thin. **Answer:** their queues
  are a second store with its own consistency problems; here the queue IS
  the journal and every assignment is attributed, chained and explainable
  — and the studio can shape the inbox surface per tenant like any other
  surface.
- **(b) a dedicated work-queue store / module.** REFUSED: a second source of
  truth for who holds what, disconnected from the run's authority basis.
- **(c) defer work management to adopters.** Rejected: it is where every
  adopter would rebuild the same thing, and the bar names it.

## WF-13 — agents in design and operations; visual authoring; simulation; decisions as data (the bar: ease of design, agents everywhere) — RECOMMENDED: (a)

- **(a) RECOMMENDED — because a flow is a document and `advance` is pure,
  authoring, rendering, simulating and operating it are projections, not
  features.** DESIGN: an agent authors a `[flow]` from a prose brief and the
  composed grammar (X1 tells it exactly which acts exist), `validate`
  refuses what does not resolve (X4), and `simulate` runs the pure runner
  law over a SUPPLIED RESULT TABLE (the distributed-store "resolutions
  re-enter as an input table" pattern) — a deterministic, replayable dry
  run of every path, which is also how a user's flow becomes a conformance
  fixture. RENDERING: a flow renders to the `diagram` module for free (a
  closed vocabulary has a fixed picture); the #787 studio edits the
  document under selection-as-context — click a step, say "needs approval
  above 10k" — and both hands emit the same journaled commands on the flow
  document (propose/approve on the flow itself is the design-review gate).
  OPERATIONS: every verb in WF-0 is a command, so stream 18 projects
  `status`, `fleet`, `advance`, `resolve`, `migrate`, `reassign` as ops
  tools automatically; an ops agent runs under the dial (X3) — irreversible
  ops acts floored at approval — with `why-allowed` explaining every
  decision. DECISIONS: a decision table is a CX DOCUMENT evaluated by a PURE
  stdlib function (the DMN counterpart), used by a flow as a `:runner` step
  whose recorded result the next `when=` reads — never flow syntax (WF-2);
  it files as its own named landing, not this design. **What it DELETES:**
  nothing. **Strongest counter:** "for free" is the overclaim every
  predecessor made (the #787 R6 lesson). **Answer:** the same discipline
  applies — the diagram, studio and simulate claims each get an acceptance
  gate at spec time (a flow the studio cannot round-trip, or a path
  `simulate` cannot reach, is a defect), and the claims are "projections
  exist", not "defaults are beautiful".
- **(b) a dedicated visual modeler.** REFUSED: a second editor for a
  document the studio already edits; R1 of #787 (text-first, the studio
  adds pointing, not capability) applies verbatim.
- **(c) an in-flow expression language for decisions.** REFUSED (WF-2 (c)).

## WF-14 — performance and scale gates: measured, not claimed (the bar: performance and scale) — RECOMMENDED: (a)

- **(a) RECOMMENDED — the spec carries a `bench/flow` lane with ratcheted
  floors, ruled at spec time from measurements, and the design exits on
  them.** The lane measures, on the mem store and on sqlite: transitions
  per second on ONE stream (the commit-lock ceiling); transitions per second
  across N streams (must scale with N until the store's own ceiling — the
  §14.2 partitioning claim, proved for flows); start-to-first-effect
  latency; `advance` latency at run lengths 10 / 10³ / 10⁶ transitions
  (must be flat past the snapshot interval — WF-11's proof); `map` fan-out
  of 10⁵ items with `max-parallel` 10³ (wall time, parent-stream bytes —
  must be O(1) per map — and fleet-readout freshness); racing advancers at
  8 and 64 processes (one effect, no lost transitions); `fleet` over 10⁵
  runs (materialize refresh cost). Numbers are FLOORS in the spec
  ("implementations MUST sustain ≥ …", the EV-BUDGET pattern), set from the
  first measurement and ratcheted like `bench/repr`; the competitive
  comparison is a measured table against the published limits of the
  comparators, recorded in the ledger, never a sentence. **What it
  DELETES:** nothing. **Strongest counter:** floors set from a first
  measurement enshrine whatever the first implementation does. **Answer:**
  that is what a ratchet is for — it may only tighten; and a floor is a
  contract where a bare number is an anecdote.
- **(b) performance as a non-normative note.** REFUSED: the bar names
  performance and scale; an unmeasured claim is authority dressing.
- **(c) hard targets set now, before measurement.** Rejected: numbers
  without a measurement behind them are the thing rule 10 forbids.

## WF-15 — does a flow require a store? the local profile (the bar: simple and quick) — RULED: (a)

**Owner question (2026-09-03):** does a flow always require a cx store? Are
there simple flows — Makefile-like, the release/publish process, the XAP
design-and-implement process?

- **(a) RULED — a JOURNAL is required, a served store is not.** The record is
  the state (WF-11), so something must hold it; but the store is a LIBRARY
  with `mem://`, `file://`, sqlite and remote backends, and nothing in the
  design needs a daemon. The spec gains a **local profile**: `cx flow run
  FILE [args…]` defaults to a `file://.cx/flow/` journal in the working
  directory (resume after an interrupt for free — a property make lacks),
  `--ephemeral` uses `mem://` (process-lifetime, for one-shot scripts and
  tests), `--journal URL` points a run at a fleet store. The CLI is a thin
  wrapper over `start` / `advance` / `status`; it adds no semantics.
  `validate` and `simulate` need no journal at all. **What it DELETES:**
  nothing. **Strongest counter:** a local journal directory is one more
  artifact in a repo. **Answer:** it is the run's audit trail, gitignored
  like a build directory, and it is what makes an interrupted release lane
  resumable at the step it stopped.
- **(b) a store-less mode holding the record in memory outside the journal
  API.** REFUSED: a second state mechanism; `mem://` already gives the
  ephemeral case through the one mechanism.
- **(c) require a served store.** Rejected: kills the simple end of the
  scale story the bar names.

## WF-16 — dogfood flows, and the make-style dependency question — RULED: (a)

- **(a) RULED — three dogfood flows are the implementation campaign's first
  fixtures, and the vocabulary does NOT grow for make.** The flows: (1) the
  **release/publish lane** (`release-process.md`, `scripts/publish.sh`) —
  build → full gate → cut approval (`:principal`) → tag (the pivot) →
  publish mirrors (forward-only, idempotent) → announce; this is #734's
  CI/CD profile as a flow. (2) the **XAP authoring process**
  (`xap_authoring_process.md`) — brief → grammar draft (`:agent`) → compose
  gate → fixtures (`:agent`) → implement → `check-surface` → review
  (`:principal`) → publish; the whole performer axis dogfooded. (3) a **repo
  build/gate flow** — the Makefile-shaped case, `map` over lanes with
  `max-parallel=`, guards on lane results. Make's DAG is DATA-flow (a target
  depends on inputs); ordering, guards and `map` cover the choreography, and
  "skip if unchanged" is a COMMAND property — `[idempotent]` with a key
  derived over the inputs' content addresses (sound, where mtime is not) —
  whose named landing is #734's hermetic step executor (enforced
  input/output manifests, identity-keyed step caching). **What it DELETES:**
  nothing. **Strongest counter:** a build flow without `inputs=`/`outputs=`
  will feel weaker than make. **Answer:** the words would duplicate
  computation identity inside choreography — the growth rule's second test
  fails — and the executor gives sound caching that make's timestamps cannot.
- **(b) add `depends-on=` / `inputs=` / `outputs=` words.** REFUSED under the
  WF-2 growth rule: a command expresses it, and it is computation identity,
  not choreography.
- **(c) no dogfood flows.** Rejected: eat our own dog food; and the three
  named flows exercise every letter above on real work.

---

## Open dependencies (not ruled here)

| issue | what it decides for this design | posture |
|---|---|---|
| #1260 | the canonical act form a step's `do=` + args take | adopt whatever it rules; the flow prefers the child form the wire already journals and mints no third spelling |
| #1210 | how a XAP-layer runner receives the tenant's journal | the flow module needs option 1 there (a journal handle beside the store) for W3+ |
| #1217 | projecting a feature verb (the `:principal` human-task form) | the approval case needs nothing; the form case rides its fix |
| #1231 | bareword command admission inside def bodies | fix before W1; by-name resolution must take the `$cmd`-as-value path |
| #728 component 2 | the connector SDK — external-system steps | a connector call is a command step; not this design |
| decision tables | a pure evaluator over a table document (the DMN counterpart) | files as its own issue at spec time (WF-13) |

## Execution notes (for the spec draft, once ruled)

- One document shape, one transition shape, one record fold, one runner
  law, stated once each; every word in WF-2 carries an applicability matrix
  row (spec-authoring guide §3) — `when=` on `branch` / `map` (✅ guards the
  whole construct), `deadline=` on `flow` (✅ = `stall-after=`), on `map` (✅
  the set's deadline), `pivot=` inside `branch` (❌ — a pivot is a point in a
  total order; a parallel pivot is two irreversible points, refused with
  reason), `pivot=` inside `map` (✅ iff the parent has none — counted across
  the tree), `by=` on `branch` / `map` (— a construct has no performer),
  `tolerate=` on `branch` (❌ — a static branch's sequences are named, not a
  set; a failed one is a named failure).
- The competitive matrix above moves into the draft as the readiness bar,
  with each row's gate named; rows marked **exceeds** must carry the fixture
  that proves the property, not the sentence.
- Refer to other specs by section title, never §N.
- Fixture first: every refusal in the register has a negative fixture; every
  ✅ cell a positive one; the racing-advancer pair; the delta-fold
  equivalence (fold ≡ the shipped whole-record answer); the migrate
  dry-run classification triple + the lineage-missing refusal; the `map`
  tolerance pair; the claim race; the cross-party ack + the un-negotiated-
  peer refusal; the `simulate` ≡ `advance` equivalence over a result table.
