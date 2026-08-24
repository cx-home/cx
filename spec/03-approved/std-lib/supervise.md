# `cx-stdlib/supervise` — restart policies over monitored workers

```cx
[module-meta name=supervise tier=D status=current]
```

**Status:** APPROVED — graduated + implemented 2026-08-20 (issue
#765; RULED: SUP-1, owner "3b" — ledger/rulings_2026_08_20_supervise.md;
design lineage U2.1a–U2.3a in
[`spec/_archived/worker_lifecycle.md`](../../_archived/worker_lifecycle.md)).
Implementation: `stdlib/supervise.cx` (pure CX);
fixtures: `conformance/stdlib/supervise.cxd` +
`vcx/tests/stdlib_supervise_test.v`. First-contact corrections are the
recorded riders SUP-1a…SUP-1h (ledger) and are folded into this text.
Composes shipped/ruled parts only:
`[?worker]`/`[?monitor]`/`[?select]` (code.md §10.4; U2.1a),
fan-out channels (§10.4.1; U1.11a), and `cx-stdlib/sched` timers.
It adds **no new concurrency primitive** — the module is the restart
LOOP written once, with policies as data.

## §0. Normative dependencies

| Dependency | What supervise relies on |
|---|---|
| code.md §10.4.6/§10.4.6a — `[?worker]`, `[?monitor]` | children are ordinary workers; death is observed via the monitor subscription (terminal event delivered even post-mortem — race-free supervision is the substrate, not this module's cleverness) |
| code.md §10.4.7 — `[?select]` over subscriptions (U1.5a) | the supervision loop is ONE wait over child terminals + control ops + `sched` backoff timers — realized as one blocking receive on the supervisor's fan-out inbox (terminal notes, ops, and ticks all arrive there) with `[?select]` as the non-consuming monitor probe during bounded stops |
| code.md §10.5.4/§10.5.7 — cancellation contract + RAII | stop = cancel children; a cancelled child cannot start new I/O (capability-enforced); cancellation is a signal, not a kill — hence the §4.4 abandon rule |
| `sched.md` — timers, mock clock | backoff delays ride `sched`, so restart fixtures are deterministic under the mock clock |
| delivery.md §4 (U1 rulings) | the `events` surface is a standard subscription (fan-out channel, `retention=window`); the supervisor handle is monitorable, so trees compose with zero new machinery |
| code.md §9.1.2 — four-channel model | `stop` on an already-stopped supervisor is a value; an unknown child name is a fault (§8); absence is never `null` |

## §1. Scope

`cx-stdlib/supervise` runs a set of **children** (named workers) under
a declared **policy** (strategy, restart intensity, backoff) and
restarts them when they die, per child **restart type**. It provides
**start**, **stop**, dynamic **start-child**/**stop-child**,
**status** (impure — SUP-1a), and **events** (an observable stream of
its own actions). Supervisors nest by composition: the supervisor runs its
loop in an ordinary worker, so `[?monitor]` on a supervisor handle is
a parent's view of a subtree — **trees need no tree feature**.

Out of scope, with owners: consumer failover across processes
(fabric §19.3 — already shipped); durable per-entity state (journal
streams — state does not live in workers, so there is nothing durable
for a supervisor to save; the ruling record is U2.3a's posture);
force-killing a child (does not exist — cancellation is cooperative,
§10.5.4; the abandon rule is the honest bound).

## §2. Conceptual model

```cx
[supervisor state="running" strategy=:one-for-one children=3
  on-close="supervise/stop"]                    # the handle (closeable, monitorable)

[policy strategy=:one-for-one max-restarts=5 window=1m
  backoff=:exp base=100ms cap=10s]              # policy is DATA

[child name="ingest" restart=:permanent shutdown=5s [fn $start-ingest]]
[; the fn rides as a CHILD element — attributes are scalar-only
   (code.md §6.4.1), so a callable cannot be an attr (SUP-1c) ]
```

- A **child spec** is `(name, fn, restart, shutdown)`: `name` unique
  per supervisor; `fn` an arity-0 callable that is the child's body,
  carried as the `[fn …]` child element (SUP-1c — attrs are
  scalar-only), each (re)start spawning a fresh worker; `restart` ∈
  `:permanent` (restart on any exit) · `:transient` (restart only on
  `panicked`) · `:temporary` (never restarted); `shutdown` a duration
  bounding the stop wait (§4.4), default `5s`.
- **Strategy** ∈ `:one-for-one` (restart the exiting child alone) ·
  `:one-for-all` (an exiting child restarts every child) ·
  `:rest-for-one` (the exiting child and every child started AFTER it,
  in start order).
- **Intensity** is per supervisor (Erlang semantics — it exists to
  stop restart storms, and a storm does not respect child
  boundaries): more than `max-restarts` restarts within `window` →
  the supervisor **gives up** (§4.3).
- **Backoff** is per child attempt:
  `delay = min(cap, base·2^(attempt−1))` for `:exp`; `:none` restarts
  immediately. A child's `attempt` counter resets after it runs
  `window` without exiting.
- The supervisor's own exits: a give-up terminates the loop worker
  with the §8 intensity err — a parent supervisor monitoring this one
  sees `[panicked …]` and applies ITS policy. **Escalation is
  composition, not a feature.**

## §3. Public function surface

```
[?def start       scope=public impure [returns element] ($policy::element $children::[sequence element]) ...]
[?def stop        scope=public impure [returns null]    ($sup::element) ...]
[?def start-child scope=public impure [returns element] ($sup::element $child::element) ...]
[?def stop-child  scope=public impure [returns bool]    ($sup::element $name::string) ...]
[?def status      scope=public impure [returns element] ($sup::element) ...]
[?def events      scope=public impure [returns element] ($sup::element) ...]
```

- `start` validates the policy and every child spec (malformed →
  `CXER5090`; duplicate names → `CXER5091`), spawns the loop worker,
  starts children **in list order**, and returns the `[supervisor]`
  handle. A child that panics immediately is a restart event, not a
  start failure (spawn itself does not fail; the policy governs).
- `stop` cancels children in **reverse start order**, each bounded by
  its `shutdown` (§4.4), then stops the loop. Idempotent; the handle
  satisfies the closeable contract (`on-close="supervise/stop"`).
- `start-child` adds and starts a child under the running policy
  (duplicate name → `CXER5091`); `stop-child` cancels and REMOVES a
  child by name — returns `true` if it was present, `false` if
  unknown (a value; idempotent removal is normal). Ops on a stopped
  supervisor → `CXER5093`.
- `status` (impure — SUP-1a: purity is enforced, `CXER0233`, and every
  read of live supervisor state is channel I/O by construction) answers
  through the control round-trip while the supervisor runs (ordered
  after every exit the caller has already observed) and stays readable
  after stop through the supervisor's status cell:
  `[supervisor-status restarts-in-window=N
    ([child name=… state=(running|restarting|abandoned|stopped) attempts=N] …)]`
  (the child rows nest as one sequence — element construction does not
  splice, SUP-1d).
- `events` returns a **standard subscription** (delivery.md §4; a
  `sharing=independent retention=window keep=256` fan-out channel) of
  the supervisor's own acts — consumable by `[?receive]`/`[?select]`
  like any subscription:

```cx
# verify-skip — schematic lifecycle-event shapes (ellipsis placeholders), not standalone CX
[child-started   name=… attempt=N]
[child-exited    name=… reason=(:done|:panicked|:cancelled) err-code=…?]
[child-restarted name=… attempt=N delay-ms=…]
[child-abandoned name=…]                       # §4.4 — shutdown window expired
[gave-up restarts=N window-ms=…]               # §4.3 — the terminal act
[; SUP-1d: the child's fault rides as err-code= (a constructed element
   with an [err] child would RAISE — the #853 position semantics);
   durations ride as integer-millisecond attrs ]
```

## §4. Semantics & guarantees

### §4.1. The loop (normative behavior, not implementation)

ONE wait over: every child's terminal, the control channel
(`stop`/`start-child`/`stop-child`), and the pending backoff timers
(`sched`). (The shipped realization is one blocking receive on the
supervisor's own fan-out inbox — child-body wrappers post terminal
notes, the public verbs post ops with embedded reply channels, and
`sched` posts ticks, all into that one point; `[?select]` serves as the
non-consuming monitor probe inside bounded stops. Any realization with
the same observable event order conforms.) On a child terminal event: emit
`[child-exited …]`; decide by `restart` type × strategy; count
against intensity (only policy-initiated restarts count — a
supervisor-initiated cancel, e.g. a `:one-for-all` sibling stop or a
`stop-child`, is NEVER a countable exit and never restarts
`:transient` children); apply backoff; respawn; emit
`[child-restarted …]`. Deterministic under the mock clock.

### §4.2. Strategy effects

`:one-for-one` — the exiting child restarts alone. `:one-for-all` —
siblings are cancelled in reverse start order, then ALL children
restart in start order. `:rest-for-one` — the exiting child and all
LATER-started children cancel (reverse order) and restart (start
order). In every case each restart is one intensity count per child
actually restarted BY POLICY (a `:one-for-all` event with 3 children
counts 3? **No — it counts 1**: intensity counts *policy decisions*,
not respawns, or a wide one-for-all tree could never survive a single
flap. Pinned by fixture.)

### §4.3. Give-up

When a policy decision would push restarts-in-window past
`max-restarts`: no restart happens; children are cancelled in reverse
start order (bounded per §4.4); `[gave-up …]` is emitted as the final
event; the loop worker terminates with
`[err code=cx-err:CXER5094]` (E_SUP_RESTART_INTENSITY). A parent
supervisor's monitor sees
`[panicked … [err CXER0220 [cause [err CXER5094 …]]]]` — the worker
panic wraps the body err (code.md §10.4.8; SUP-1g); the give-up rides
the cause chain. Escalation.
An unsupervised (root) supervisor's give-up surfaces wherever its
worker's terminal state is observed — loud, never a silent stall.

### §4.4. Stop and the abandon rule

Stopping a child: `[?cancel]`, then wait up to its `shutdown`
duration. Cancellation is cooperative (§10.5.4) — a child stuck in a
pure loop without cancellation points cannot be killed. After
`shutdown` expires the supervisor **abandons** it: emits
`[child-abandoned …]`, marks it `abandoned` in `status`, and moves on.
The supervisor never hangs on a wedged child, and never pretends the
child stopped — both halves are load-bearing. (The abandoned worker's
caps are already narrowed if it ever crosses a cancellation point —
§10.5.7.2 is the backstop.) **Reference-substrate note (SUP-1f):**
`[?cancel]` stamps the `WORKER_CANCELLED` terminal at REQUEST time (the
§10.5.4 cancel-wins arbitration), so a monitor's terminal always
arrives promptly after a supervisor-initiated cancel and the shutdown
window cannot expire there — abandon is reserved surface, taking over
on any substrate whose terminal is observation-time; the no-hang
guarantee holds either way (the V lane pins it against a
cancellation-point-free child).

### §4.5. What is deliberately NOT here

No force-kill (does not exist in the platform). No durable restart
state (restart counts are ephemeral by design — durable state belongs
to entities, which live in journal streams; a restarted supervisor
starts a fresh window). No cross-process supervision (that is
fabric's group failover). No child ordering DSL beyond start order
(rest-for-one covers the dependency case).

## §5. Capability integration

supervise introduces **no capability**. Spawning workers and reading
monitors are capability-free core operations; backoff timers carry
`sched`'s posture; every effect a CHILD performs is gated at that
child's own effect point, exactly as with hand-started workers. A
denial inside a child is that child's fault event, not a supervisor
code.

## §6. Composition

```cx
# verify-skip — schematic composition ([run-ingest]/[run-render]/ctrl are placeholders); the runnable form is the module's fn-docs + conformance/stdlib/supervise.cxd
[?lib 'cx-stdlib/supervise' :as sup]

[?with-open
  [$sup:start
    [policy strategy=:one-for-one max-restarts=5 window=1m backoff=:exp base=100ms cap=10s]
    ([child name="ingest" restart=:permanent [fn [?fn () [run-ingest]]]],
     [child name="render" restart=:transient shutdown=2s [fn [?fn () [run-render]]]])]
  $s
  [?let [= $ev [$sup:events $s]]
    [?select
      [case [from $ev  $e [$log:info [audit $e]]]]
      [case [from ctrl $c [ok]]]]]]      # stop rides [?with-open] close
```

- **Trees:** run `[$sup:start …]` inside a child `fn` of another
  supervisor (the fn joins the subtree with
  `[?wait-for worker=[?worker-handle name=$s@worker]]`); the parent
  monitors its own child worker; a give-up escalates as `CXER5094` in
  the panic's cause chain. Monitoring a supervisor directly is spelled
  `[?monitor [?worker-handle name=$sup@worker]]` (SUP-1c —
  `[?monitor]` takes worker handles). Zero tree machinery.
- **Consumers:** a child `fn` that opens a fabric group subscription
  and loops `[?receive]` gets BOTH layers honestly — in-process
  restart from supervise, cross-process reassignment + redelivery
  from fabric (§19.3); the two compose because the child's cursor is
  the group offset, not worker memory.

## §7. Applicability matrix (UNIFORM gate)

| Operation | :one-for-one | :one-for-all | :rest-for-one |
|---|:--:|:--:|:--:|
| `start` / `stop` | ✅ | ✅ | ✅ |
| restart on `panicked` (`:permanent`/`:transient`) | ✅ | ✅ | ✅ |
| restart on `done` (`:permanent` only) | ✅ | ✅ | ✅ |
| `:temporary` never restarts | ✅ | ✅ | ✅ |
| intensity give-up (`CXER5094`) | ✅ | ✅ | ✅ |
| `start-child` / `stop-child` (dynamic) | ✅ | ✅ | ✅ ¹ |
| `status` / `events` | ✅ | ✅ | ✅ |
| force-kill / durable restart state / cross-process | ❌ ² | ❌ ² | ❌ ² |

**1** a dynamically started child joins at the END of start order.
**2** deliberately unsupported — §4.5 names each owner.

## §8. Error codes — `CXER5090–5109` band

Registered in [`process/governance.md`](../process/governance.md) §9.6
(next free block above live's `5070–5089`; band-scan confirmed at
graduation, the bus.md pattern).

| Code | Symbol | Raised when |
|---|---|---|
| `cx-err:CXER5090` | `E_SUP_ARG_INVALID` | malformed policy/child spec (unknown strategy or restart atom, `max-restarts < 1`, non-callable `fn`, bad durations) |
| `cx-err:CXER5091` | `E_SUP_DUPLICATE_CHILD` | `start`/`start-child` with a name already present |
| `cx-err:CXER5092` | `E_SUP_UNKNOWN_CHILD` | reserved for verbs that REQUIRE a child (none in v1 — `stop-child` returns `false`, a value) |
| `cx-err:CXER5093` | `E_SUP_CLOSED` | `start-child`/`stop-child`/`events` on a stopped supervisor (`status` stays readable) |
| `cx-err:CXER5094` | `E_SUP_RESTART_INTENSITY` | the give-up terminal err on the loop worker (§4.3) — the escalation carrier |
| `cx-err:CXER5095` | `E_SUP_NO_SCHED` | `start` in a build with the `sched` local-effect pack excluded (§0, §8.1) |

### §8.1 The `sched` dependency is checked at composition (RULED: SPF-1)

`sched` is a NORMATIVE dependency (§0): backoff delays, the intensity
window and per-child attempt-reset are all `sched` posts. A build that
excludes the pack — the §4 `embed` profile, `-d cx_no_pack_sched` —
therefore cannot host a supervisor that honours this spec, and `start`
MUST refuse rather than return one that silently never backs off, never
expires its window and never resets attempts.

The refusal is positioned **after argument validation and before the
mint**. Parsing and validating the policy and the child specs is pure and
profile-independent, so `CXER5090`/`CXER5091` remain the answer to a
malformed policy or spec in *every* build; composition — the supervisor's
identity, its four channels, its loop worker — is where a missing
substrate is the truthful complaint, and where `CXER5095` is raised. The
message names the pack and what it is needed for.

Conformance declares this to the profile gate per case with the general
`packs=` attribute, so the live-supervisor cases are SKIPPED where the
pack is excluded and the pure argument-fault cases keep grading (§10).

Shared/core codes surfaced, not re-coded: a child's own `[err]`
(any code) rides `[child-exited]`; cancellation is `CXER0260`;
a child's capability denial is `CXER0271` at the child's effect point.

## §9. Implementation notes (non-normative)

The loop worker owns: the child table (spec + worker handle + monitor
subscription + attempt count + state), the intensity ring (timestamps
of policy decisions within `window`), and pending backoff timers. All
waits are the ONE `[?select]` (§4.1). Respawn = fresh `[?worker]` +
fresh `[?monitor]`; the old monitor is drained (its terminal event
was the trigger) and closed. `events` is a `[?channel
sharing=independent retention=window keep=256]` the loop `[?send]`s
into — a laggard observer hits `CXER0218` (STREAM_GAP — SUP-1b; the
spec draft said CXER0205, corrected to the code.md §10.4.8 code) and
re-subscribes, per the delivery contract; the supervisor NEVER blocks
on observers. `events` subscriptions replay from the retained floor,
so a subscriber sees the retained history of the supervisor's acts.

**Supervisor identity** (RULED: SPF-1, issue #895). Each supervisor mints
one process-unique id, which names its four channels and its loop worker.
The source is the EVALUATOR's own monotonic handle counter, read as the
`__cx_close_id__` stamped on a `[?subscribe]` handle: `[?channel]`,
`[?subscribe]` and `[?close]` are core directives, present in every §4
profile and carrying no capability — which is what §5 requires. It must
NOT come from a local-effect pack: the first implementation armed a
240-hour `[$sched:after]`, cancelled it, and kept the timer's synthesized
name, which made the id an *optional* pack's private counter and broke the
whole module wherever that pack was excluded. `cx-stdlib/uuid` is not the
alternative either — its `v4`/`v7` generators are capability-gated on
`random`, and §5 grants none.

## §10. Conformance fixtures (to author with the implementation)

Mock-clock deterministic throughout. Positives: `:permanent` child
panics → restarted, `[child-exited]` + `[child-restarted attempt=1]`
in order; `:transient` restarts on panic but NOT on `done`;
`:temporary` never; exp backoff delays 100ms/200ms/400ms observed on
the mock clock; attempt reset after `window` of health;
`:one-for-all` cancels reverse + restarts in order (event sequence
byte-pinned); `:rest-for-one` restarts only the tail; intensity
counts DECISIONS not respawns (the §4.2 one-for-all fixture);
give-up: cancel-all + `[gave-up]` final + loop err `CXER5094`; parent
supervisor sees the give-up as `[panicked]` and restarts the subtree
(the tree fixture); `stop` reverse order, idempotent;
`[?with-open]` auto-stop; wedged child (pure loop, no cancellation
points) → the supervisor proceeds without hanging (the no-hang arm —
rides the V lane per SUP-1f: the reference substrate stamps the cancel
terminal at request, so `.cxd` cannot observe a shutdown-window
expiry); dynamic `start-child` joins start-order tail;
`stop-child` true-then-false; `status` snapshots; `events` laggard →
`CXER0218` re-seed (the standard channel STREAM_GAP contract, pinned by
the core channel lane per SUP-1b — supervise adds no gap logic).
Negatives: bad policy/spec → `CXER5090`;
duplicate → `CXER5091`; op on stopped → `CXER5093`.
**Fixture homes:** `conformance/stdlib/supervise.cxd` (30 cases — 24 behavior/negative + 6 fn-doc-backing) +
`vcx/tests/stdlib_supervise_test.v` (the timing-sensitive no-hang arm).

## §11. Graduation checklist (executor → user G3)

- [x] Governance §9.6: register `CXER5090–5109 | cx-stdlib/supervise`;
      band scan re-run (above live's `5070–5089`).
- [x] README §3 module row + count +1 (44→45); skeleton-test `expected`
      + `'cx-stdlib/supervise'` (the bus.md §12 pattern — a genuine +1).
- [x] Implement `stdlib/supervise.cx` — PURE CX; zero new host
      primitives (one upstream sched defect fixed in passing, SUP-1e).
- [x] #762 shipped (the consumer contract: `[?monitor]`,
      `[?subscribe]`, select-over-subscriptions).
- [x] §10 fixtures authored; wired into the stdlib fixture gate
      (suite default=enforced).
- [x] Moved to `spec/03-approved/std-lib/supervise.md`
      (RULED: SUP-1, owner "3b", 2026-08-20).

## §12. Module-count reconciliation

supervise is an ADDITION (+1) at its own graduation: README §3 count
(44→45), frozen-surface sentence, Tier-D table row, and the skeleton
test (`bundled_stdlib_names()` 44→45 + the `expected` entry) moved
together in the graduation change — order-independent with sibling
additions, per the bus.md §12 discipline. LANDED 2026-08-20 with
SUP-1.

## Identity-epoch membership (audit C9)

ADDITIVE — no I1 manifest row, no epoch. A new stdlib module over
ruled primitives; no wire, no preimage, no address motion.
