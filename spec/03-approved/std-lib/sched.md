# cx-stdlib/sched — scheduled events & timers

```cx
[module-meta name=sched tier=D status=current]
```

**Status:** Current

Lifted out of the http SSE/streaming surface ([`http.md`](http.md) §3.6 — the
former `stdlib_http_streaming_amendment.md`, since folded into `http.md`) so http
stays HTTP-only: the timer surface is **not** http-specific (a timer touches no
network), so it is its **own module** rather than a fourth http verb family. It rides
the **same picoev event loop** http's server leg uses (§9), but is a separate
sub-package with its own surface and capability posture.

This is the **timer / scheduled-event** enhancement XAP's runtime requires
([`xap.md`](xap.md) §25.1): incapacity windows (`no-ack-within "10m"`, §10.8),
lifecycle timeouts, and the demo's controllable clock (xap_demos.md). XAP's
`[$xap:after …]` wraps this; `authz` guardian gates consume the fired window event.

## §0. Normative dependencies

| Dependency | What sched relies on |
|---|---|
| `cx-stdlib/time` — `::duration`, `::datetime`, `[recurrence …]` | every relative scheduling verb takes a `::duration`; `at` takes a tz-aware `::datetime`; `recur` consumes a `[recurrence …]` value and re-arms via `[$time:next-occurrence $rule $after]` (COUNT/UNTIL honored); `cron` parses a cron string via `time` into a `[recurrence …]`. The recurrence type + occurrence functions + cron parsing are defined in [`time.md`](time.md) §3.10 (the former `stdlib_time_recurrence_amendment.md`, since folded into `time.md`). sched does **no** date/calendar arithmetic — it composes `time`. |
| `cx-stdlib/journal` — durable timers | the `durable` opt (§3.2) persists timer **intent + schedule** to a caller-supplied `[journal]` (`[$journal:append …]`, [`journal.md`](journal.md) §3.2); `[$sched:restore]` folds the journal to re-arm pending timers on startup. sched composes journal's append/fold — it adds no persistence mechanism of its own. |
| `code.md` §9.1.2 — **four-channel model** | a fired callback's raw effect without a grant rides the **failure channel** (`CXER0271`); a `timer-state` read of a present handle is a **value**; sched never returns `null` for absence. |
| SAP §2 — **`[?try]`/`[catch]` retirement** | timer faults are handled with `[?match]` / `[?else]` only; this spec never uses `[?try]`. Canonical call form is `[$sched:after …]` (`[head …]`), never an infix. |
| SAP §5.1 — **closeable-handle contract** (`on-close="sched/close"`) | a `[timer]` is a **closeable / cancelable** handle satisfying `[?with-open]`; `close` ≡ `cancel`, idempotent, never `CXER0108`. |
| SAP §5.2 — **cancellation = `CXER0260`** + capability backstop `CXER0271` | a `[?timeout]`/`[?cancel]` on a scheduling op surfaces the core `CXER0260`; a raw effect in a fired callback without a live grant hits `CXER0271`. |
| `spec-authoring-guide.md` §3 / SAP §0.2 — **orthogonality guard** | the §7 Applicability Matrix + `UNIFORM` gate are mandatory. |

sched does **not** re-specify the event loop, sockets, or wall-clock primitives —
those are the picoev backend (`cx-stdlib/http` §9, shared) and the V host. It does
**not** re-specify recurrence/cron grammar (that is `time`'s) or persistence/hash-chain
(that is `journal`'s, over `store`). sched is the minimal CX-level surface over the
loop's timer wheel that **composes** those three.

---

## §1. Scope

`cx-stdlib/sched` provides **scheduled events**: arm a timer that fires a callback (or
posts a tick to a channel) on the event loop — **after** a relative duration, **at** an
absolute tz-aware instant, on a **recurring** cadence (fixed-delay or fixed-rate),
against a **`time` recurrence rule** or a **cron string** — cancel it, observe its
state, optionally make it **durable** (persisted to a `journal` so it survives a
process restart, re-armed via `restore`), apply a **catch-up policy** for occurrences
missed while the process was down or the test clock fast-forwarded, and — under a
**manual/test clock** — advance virtual time deterministically. **Out of scope v1**
(and where it lives instead):

| Concern | Owner |
|---|---|
| recurrence-rule / cron **grammar** + occurrence math (RRULE-style, COUNT/UNTIL, cron field parsing) | `cx-stdlib/time` ([`time.md`](time.md) §3.10) — sched *consumes* `[recurrence …]` + `[$time:next-occurrence]`, it does not parse them |
| date / calendar / timezone arithmetic | `cx-stdlib/time` (sched takes its `::duration` / `::datetime`) |
| the persistence backend / hash-chain for durable timers | `cx-stdlib/journal` over `store` ([`journal.md`](journal.md)) — sched *appends intent* to a caller-supplied journal; it adds no store of its own |
| the event loop / sockets / held-open fds | the picoev backend (`cx-stdlib/http` §9) — sched is surface, not runtime |
| SSE / streaming responses | `cx-stdlib/http` SSE/streaming surface ([`http.md`](http.md) §3.6) |

(cron / absolute-calendar schedules and durable / cross-process timers were out of
scope in revision 1; **both are now in scope** — see §3.1 (`at`/`recur`/`cron`) and
§3.2 (`durable`/`restore`). sched still owns no
calendar grammar or persistence mechanism: it *composes* `time` and `journal`.)

**Layering.** sched is a Tier-B module over the shared picoev loop. In its
**non-durable** modes it adds **no new capability** (a timer touches no network, opens
no file — capability-free compute, §5). The **`durable` opt is the sole exception**: it
writes to a caller-supplied `[journal]` handle, so it carries the **journal's
write/store effect**, charged to the capability that opened that journal (§5) — sched
mints no new capability even then. It is consumed by higher layers — `cx-xap`
(`[$xap:after]` wraps `[$sched:after]`), `cx-stdlib/authz` (guardian gates fold the
window-elapsed events sched posts), and the http SSE leg (auto-`keep-alive` heartbeats
are sched timers on the same loop).

`cx-stdlib/sched` is **Tier-B runtime — necessarily impure** for the arming verbs
(they schedule side-effecting callbacks and observe the clock; durable arming also
appends to a journal); state reads are **pure**.

## §2. Conceptual model

### §2.1. A `[timer]` is a VALUE; firing invokes a callback / emits an event

A `[timer]` is a homoiconic CX value that is also a **cancelable handle** (SAP §5.1):

```cx
[timer state="armed" on-close="sched/close"]          # fires after its duration, unless canceled
```

`state` ∈ `"armed" | "fired" | "canceled"` (a recurring `every` timer stays
`"armed"` across fires until canceled, §3). The handle satisfies the closeable
contract (`on-close="sched/close"`, [`code.md`](../core/code.md) §8.10.7): `close` ≡
`cancel` — idempotent; canceling a fired/canceled timer is a **no-op, never
`CXER0108`**; `[?with-open]`-able.

**Firing is one of two effects, chosen by `$ev`'s shape** (SAP — the event is a
value the producer supplies):

- **callback** — `$ev` is a **zero-arg callable** (`[?def [] …]`): on fire it is
  **invoked on the loop**; its return is ignored.
- **channel tick** — `$ev` is a `[?channel]` value: on fire a **tick is posted** to
  it (the "scheduled event" form — the consumer selects on the channel). This is the
  form XAP uses to post a window-elapsed event onto the bus.

A timer is **not multi-owner**: the arming worker owns the handle; transfer via
`[?channel]` like any handle (net §2.1 ownership model). Concurrent non-owner
`cancel` of the same handle is benign (idempotent), but the handle value itself is
single-owner for state mutation.

### §2.2. Recurrence cadence — fixed-delay vs. fixed-rate (`mode` opt)

> **Observability tier (this revision).** The cadence distinction below is only
> *observable* when a callback consumes real time. Under the deterministic
> `:manual` test clock a callback completes in **zero virtual time**, so
> `:fixed-delay` (next = completion + `$dur`) and `:fixed-rate` (next = anchor +
> `$dur`) coincide exactly — the conformance tier cannot distinguish them, and
> the `:wall` clock + its slow-callback drift (and `CXER4970`) are exercised only
> by the deferred live firing loop (status line: "live picoev firing loop
> gate=pending"). The cadence *selection* is implemented and persisted; its
> divergent *timing* is not asserted here.

`every` recurs under one of two cadence modes, selected by the `mode` opt
(`:fixed-delay | :fixed-rate`, **default `:fixed-delay`**):

- **`:fixed-delay`** (default) — the next fire is armed **`$dur` after the callback
  returns**. There is **no coalescing and no backlog**: a callback that runs longer
  than `$dur` simply delays the next arm; the cadence drifts forward by the callback's
  runtime and ticks are **never** queued to "catch up." This is the simplest correct
  behavior and avoids the drift/thundering-herd hazard a naïve fixed-rate raises. It is
  the right default for *jobs* (each run wants a settling gap after the last).

- **`:fixed-rate`** — fires are anchored to a **steady wall-clock cadence**
  `t₀, t₀+$dur, t₀+2·$dur, …` computed from the arm instant `t₀`, **independent of how
  long any callback takes**. The next deadline is the next multiple of `$dur` after
  `t₀` strictly greater than virtual/real-now; the callback's runtime does **not** push
  the cadence forward (it only eats into the gap). This is the right mode for *clocks*
  (heartbeats, sampling) where occurrences must land on a grid.

  **Drift & overrun under `:fixed-rate`.** If a callback overruns its slot (runtime >
  `$dur`), one or more grid points elapse while it runs. What happens to those missed
  grid points is governed by the **`on-missed` policy** (§2.5): `:skip` (default) fires
  only the next future grid point (steady cadence, dropped beats); `:coalesce` fires
  **once immediately** then resumes the grid (catch-up without a burst);
  `:fire-all` fires **once per missed grid point** back-to-back (no dropped beats — the
  classic "backlog" — use only when every occurrence must be observed). A `:fixed-rate`
  timer never lets fires overlap: the next is computed only after the current returns.

### §2.3. Absolute one-shot (`at`) and rule-driven recurrence (`recur` / `cron`)

Beyond the relative `after`/`every`, a timer's schedule may be **absolute** or
**rule-driven**:

- **absolute one-shot (`at`)** — fires **once at a wall-clock instant** (a tz-aware
  `::datetime`). The deadline is the elapsed duration from now to `$datetime` on the
  loop's clock; an instant already in the past fires immediately on the next loop turn
  (or applies `on-missed` if it is durable and was missed across a restart, §2.5).
  Time-zone and DST normalization are `time`'s — sched stores the resolved instant.

- **recurrence rule (`recur`)** — fires on each occurrence of a `time`
  `[recurrence …]` value (RRULE-style: frequency, interval, BY*-parts, COUNT/UNTIL).
  sched **re-arms after each fire** by calling
  `[$time:next-occurrence $rule $last-fire]`; when that yields the absence value (no
  further occurrence — COUNT exhausted or past UNTIL), the timer transitions
  `"armed"→"fired"` (terminal) and does not re-arm. sched holds **no calendar logic** —
  it only asks `time` for the next instant and arms an internal `at` for it.

- **cron convenience (`cron`)** — `[$sched:cron $expr …]` parses the cron string via
  `time` (`[$time:parse-cron $expr]` → `[recurrence …]`) and is then **exactly
  `recur`** over the resulting rule. A malformed expression surfaces `time`'s parse
  fault (not a sched code, §8).

### §2.4. Durable timers — surviving a process restart (`durable` / `restore`)

By default a timer is **in-memory**: process exit drops it (§2.6). The **`durable` opt**
(default off) makes a timer's **intent + resolved schedule survive a restart** by
persisting it to a caller-supplied `[journal]`:

- On arm, sched **appends a `[sched-intent …]` entry** to the journal (kind, fire value
  *descriptor*, resolved schedule, `mode`/`on-missed`/`name`, and — for recurrence —
  the rule + last-fire cursor). On each fire/cancel/terminal it appends a
  **progress/closed entry**, so the fold reflects the live cursor.
- On startup, **`[$sched:restore $journal $registry …]`** folds the journal to the set
  of **still-pending** intents and **re-arms each** against the *current* clock,
  applying the `on-missed` policy (§2.5) for occurrences whose deadline passed while the
  process was down. The fire value is **not** serialized (a callable/channel is not
  data); the caller supplies a `$registry` map `{name → $ev}` binding each persisted
  timer's `name` back to a live callable/channel. A persisted timer with no registry
  entry is **left armed-but-orphaned** and reported in the restore result (not silently
  dropped — §3.3).

**Why durability is a correctness need, not polish.** XAP guardian **incapacity
windows** (`no-ack-within "10m"`, [`xap.md`](xap.md) §22.8, invariant 3
minimum-persistence) MUST keep counting across a **worker recycle**. If the worker
holding an armed `no-ack-within` window is recycled and the window evaporates, the
window can never fire, so guardian authority can never engage — a **silent safety
failure** (the bright-line falsifiable-by-presence guarantee, invariant 4, assumes the
window actually elapses). A durable window re-arms on the replacement worker from the
journal fold with its **remaining** time, so the incapacity window survives the
recycle. This is the load-bearing reason durability moved in-scope.

### §2.5. Catch-up / missed-occurrence policy (`on-missed` opt)

When occurrences fall due while no live timer was watching — the process was **down**
(durable restore, §2.4) **or** the **test clock fast-forwarded past several deadlines**
(§3.3) — the **`on-missed` opt** (`:skip | :fire-all | :coalesce`, **default `:skip`**)
governs catch-up:

| `on-missed` | Behavior when N occurrences are due at once |
|---|---|
| `:skip` (default) | fire **only the next still-future occurrence**; drop the N that elapsed. Safe default — at-most-the-latest, no burst. A one-shot already past simply does not fire. |
| `:coalesce` | fire **exactly once now** (collapsing the N missed into one), then resume the normal schedule from the current instant. "I missed beats; run once to catch up." |
| `:fire-all` | fire **once per missed occurrence**, in deadline order, back-to-back, then resume. No occurrence is dropped (use when every tick must be observed — e.g. a journal-replay counter). |

`on-missed` applies to **`every` (`:fixed-rate`), `recur`, `cron`, and durable-restored
timers**. For a non-durable `:fixed-delay` `every` there is by construction no backlog
(§2.2), so `on-missed` is **inert** unless the test clock advances past multiple
re-arms. Interaction with the test clock is normative: **`[$sched:test-clock-advance $d`
that crosses N deadlines applies `on-missed` exactly as a real fast-forward would** —
`:skip` fires once, `:coalesce` fires once, `:fire-all` fires N times, all
deterministically in deadline order (§4.6). This makes catch-up behavior testable
without a real outage.

### §2.6. Virtual vs. real clock — controllable time

Every timer reads a **clock source** that is either the real monotonic wall clock
(`:wall`, the production default) or a **manual virtual clock** (`:manual`, the test
clock, §3.3). Under `:manual`, timers do **not** fire on wall-clock — they fire only
when `[$sched:test-clock-advance]` (§3.3) moves virtual time past their deadline, **in
deadline order**, deterministically, applying `on-missed` (§2.5) when an advance
crosses several deadlines. This makes a `no-ack-within "10m"` window a one-line advance
in a fixture (no ten-real-minute wait, no flake). The clock mode is process/loop-scoped,
selected by the harness (§3.3); production code never touches it.

## §3. Public function surface

Signature notation matches [`http.md`](http.md) §3. `::duration` /
`::datetime` are `cx-stdlib/time` types; `::recurrence` is a `[recurrence …]` value
([`time.md`](time.md) §3.10); `$ev`
is the callable-or-channel fire value (§2.1); `::element` is a `[timer]` (or, for
`restore`, a `[journal]`) handle.

### §3.1. Scheduling, cancellation, state

```
[?def after          scope=public impure [returns element] ($dur::duration  $ev $opts::map {}) ...]
[?def at             scope=public impure [returns element] ($when::datetime $ev $opts::map {}) ...]
[?def every          scope=public impure [returns element] ($dur::duration  $ev $opts::map {}) ...]
[?def recur          scope=public impure [returns element] ($rule::recurrence $ev $opts::map {}) ...]
[?def cron           scope=public impure [returns element] ($expr::string   $ev $opts::map {}) ...]
[?def cancel         scope=public impure [returns bool]    ($timer::element) ...]
[?def timer-state    scope=public pure   [returns string]  ($timer::element) ...]
```

- **`after`** — schedule `$ev` to fire **once** after relative `$dur` on the event
  loop; returns a `[timer]` cancel handle (§2.1). Firing flips `state`
  `"armed"→"fired"`. The load-bearing primitive for XAP incapacity windows
  (§13.1 / xap.md §22.8).
- **`at`** — **absolute one-shot**: fire `$ev` **once at the tz-aware instant `$when`**
  (§2.3). An instant in the past fires on the next loop turn (`:skip` no-op only when
  durable + missed across a restart, §2.5). tz/DST normalization is `time`'s.
- **`every`** — the **recurring** variant: re-arms after each fire until `cancel`. The
  `mode` opt picks **`:fixed-delay`** (default — re-arm `$dur` after the callback
  returns, no backlog) or **`:fixed-rate`** (anchored grid, §2.2). `state` stays
  `"armed"` across fires; `cancel` stops further fires and sets `"canceled"`.
- **`recur`** — arm against a `time` **`[recurrence …]`** rule (§2.3): re-arm for each
  `[$time:next-occurrence $rule $last-fire]`, honoring the rule's **COUNT/UNTIL** bound.
  When `time` reports no further occurrence the timer goes terminal `"fired"` and stops
  (it does not stay `"armed"`). `state` is `"armed"` between occurrences.
- **`cron`** — convenience: parse the cron string `$expr` via
  `[$time:parse-cron $expr]` → `[recurrence …]`, then behave **exactly as `recur`** over
  it (§2.3). A malformed `$expr` surfaces `time`'s cron-parse fault unchanged (§8).
- **`cancel`** — cancel an armed timer; returns `true` iff it was armed (the fire was
  prevented), `false` if it had already fired (terminal one-shot / exhausted
  recurrence) or been canceled (idempotent). This is what `close` calls. A **durable**
  timer's cancel also appends a closed entry to its journal (§3.3).
- **`timer-state`** — **pure** state read (`"armed" | "fired" | "canceled"`); no
  capability, referentially transparent.

**`opts` (shared by all arming verbs).** The trailing `$opts::map {}` is a **defaulted
positional parameter** (`grammar.ebnf [153b]`, [`http.md`](http.md)
§3.1) — `[$sched:after $dur $ev]` ≡ `[$sched:after $dur $ev {}]`. Keys:

| Key | Type / values | Default | Applies to | Meaning |
|---|---|---|---|---|
| `name` | `string` | (synthesized) | all | label for logging/diagnostics; **required** if `durable` (the registry key on restore, §3.3) |
| `mode` | `:fixed-delay \| :fixed-rate` | `:fixed-delay` | `every` | cadence model (§2.2) |
| `on-missed` | `:skip \| :coalesce \| :fire-all` | `:skip` | `every` (`:fixed-rate`), `recur`, `cron`, `at`/durable | catch-up policy for missed occurrences (§2.5) |
| `durable` | `bool` *or* `[journal]` | `false` | all | persist intent/schedule to the given journal so the timer survives restart (§3.3); a bare `true` requires a journal supplied via the loop config |

`close` (the shared closeable verb, SAP §5.1) ends a timer; there is **no separate
`timer-close`** — `cancel` is the verb and `close` calls it.

### §3.2. Durable timers — persistence & restore

```
[?def restore scope=public impure [returns element] ($journal::element $registry::map $opts::map {}) ...]
```

- **`durable` opt** (§3.1) — when set to a `[journal]` handle, each arming verb
  **appends a `[sched-intent …]` entry** to that journal (`[$journal:append …]`,
  [`journal.md`](journal.md) §3.2) carrying the timer kind, `name`,
  resolved schedule (one-shot instant, duration + cadence `mode`, or the
  `[recurrence …]` rule + last-fire cursor), and `on-missed`. Each fire/cancel/terminal
  appends a **progress / closed** entry, so a fold of the journal yields the exact set
  of still-pending timers and their remaining schedule. The **fire value itself is
  never serialized** (a callable/channel is not data) — only its `name` descriptor.
- **`restore`** — fold `$journal` to its still-pending `[sched-intent …]` set and
  **re-arm each** against the *current* clock, binding the fire value by `name` from
  the `$registry` map `{ <name> → $ev }`. For each re-armed timer whose deadline(s)
  elapsed while the process was down, apply its persisted `on-missed` policy (§2.5).
  Returns a **`[restore-report …]`** value listing `rearmed`, `skipped` (terminal /
  past-UNTIL), and **`orphaned`** (a pending intent whose `name` is absent from
  `$registry` — left armed but unbound, surfaced as a value, **never silently
  dropped**). `restore` is the startup half of the worker-recycle correctness story
  (§2.4 / xap.md §22.8).

### §3.3. The test clock — a controllable / fast-forward hook

```
[?def test-clock-advance scope=public impure [returns null] ($dur::duration) ...]   ; test-only
[?def clock-mode         scope=public pure   [returns string] () ...]                ; ":wall" | ":manual"
```

- **`test-clock-advance`** — advance the **manual** virtual clock by `$dur` and
  **drain all timers whose deadline is now ≤ virtual-now, in deadline order**, firing
  each deterministically. A recurring timer re-arms against virtual time, so a single
  large advance reaches the correct number of occurrences; **how many of those actually
  fire follows the timer's `on-missed` policy** (§2.5): a `:fixed-delay` `every` and
  `:skip` fire once per crossed re-arm boundary in order; `:coalesce` fires once;
  `:fire-all` fires once per crossed occurrence — the advance is the test-clock analogue
  of a real outage/fast-forward (§4.6). Under the production (`:wall`) clock →
  `cx-err:CXER4970 E_SCHED_TEST_CLOCK` (it is **not** a production control).
- **`clock-mode`** — **pure** read of the current loop clock source
  (`":wall" | ":manual"`), so a fixture can assert it is under the test clock.

**Selecting the manual clock.** `:manual` is enabled by the **conformance harness**,
not by production code — via the runtime's test-listener config (the same
`clock: :manual` opt the http server leg honors, [`http.md`](http.md)
§3.5) or the CLI test mode. There is **no public verb to flip a live production loop
to `:manual`** (that would let production code freeze time); the mode is set at loop
construction. This is the controllable clock the XAP demo needs ([`xap.md`](xap.md)
§25.1, xap_demos.md).

## §4. Semantics & guarantees (soundness)

### §4.1. Capability-free compute; firing inherits the handler's effects
Arming, canceling, and advancing the clock **introduce no capability** (a timer
touches no network/fs — §5). **Firing a `$ev` callback runs it with whatever caps
were in scope at scheduling** (SAP capability-capture): a raw effect in `$ev` without
a live grant hits `cx-err:CXER0271` exactly as anywhere else. sched is a scheduling
*mechanism*; it grants nothing.

### §4.2. Deterministic ordering
Whether on the wall clock or the test clock, timers due at the same instant fire in
**deadline order** (ties broken by arm order). Under `:manual` this is fully
deterministic and sleep-free — the property the conformance battery relies on.

### §4.3. Recurrence cadence (normative)
`every :fixed-delay` (default) re-arms `$dur` **after the callback returns** — no
coalescing, no backlog; a long callback delays, never queues, the next fire (§2.2).
`every :fixed-rate` anchors fires to the **grid** `t₀+k·$dur` independent of callback
runtime; grid points elapsed during an overrun are resolved by `on-missed` (§2.5).
`recur`/`cron` re-arm against `[$time:next-occurrence]` and **stop at COUNT/UNTIL**
(terminal `"fired"`). Fires of a single timer never overlap (the next deadline is
computed only after the current callback returns).

### §4.4. Cancellation & lifecycle
`cancel`/`close` is idempotent and total (§2.1); canceling an already-fired one-shot,
an exhausted recurrence, or a canceled timer returns `false` and never raises. A
`[?timeout]`/`[?cancel]` wrapping a scheduling op surfaces the core `cx-err:CXER0260`
(SAP §5.2), independent of any timer the op arms. `[?with-open]` close runs under
restored caps. Canceling a **durable** timer appends a closed entry so `restore`
will not re-arm it.

### §4.5. Durability & restore (normative)
A **non-durable** timer lives only in loop memory: **process exit drops it** (no replay).
A **durable** timer (`durable` opt, §3.2) persists its intent + resolved schedule to the
supplied `[journal]`; after a restart `[$sched:restore]` folds the journal and re-arms
every still-pending timer against the current clock, binding fire values from the
`$registry` and applying each timer's `on-missed` policy for deadlines passed during the
downtime. **Correctness, not polish:** a guardian incapacity window
(`no-ack-within`, xap.md §22.8 invariant 3) made durable **survives a worker recycle** —
the replacement worker re-arms it with its remaining time, so the window still elapses
and guardian authority can engage. sched holds no store of its own — durability is
`journal`-over-`store`; an **`orphaned`** pending intent (no registry binding) is
reported, never silently dropped (§3.2).

### §4.6. Missed-occurrence policy (normative)
When N occurrences come due at once — process down across a durable `restore`, or a test
clock advance crossing N deadlines — `on-missed` (§2.5) resolves them deterministically
in deadline order: **`:skip`** fires only the next still-future occurrence (a one-shot
already past does not fire); **`:coalesce`** fires exactly once then resumes;
**`:fire-all`** fires once per missed occurrence then resumes. The policy is identical
whether the gap was a real outage or a `test-clock-advance`, so a fixture exercises the
exact production catch-up path (§3.3).

## §5. Capability integration

**sched mints no capability of its own.** In its non-durable modes every verb is either
pure (`timer-state`/`clock-mode`) or capability-free impure (`after`/`at`/`every`/
`recur`/`cron`/`cancel`/`test-clock-advance` — they schedule/observe on the loop but
reach no network/fs). The **`durable` opt** is the sole effectful surface: persisting
intent and `restore`'s fold/re-arm perform **journal writes/reads**, charged to **the
capability that opened the supplied `[journal]`** (journal-over-`store`,
[`journal.md`](journal.md) §5) — sched borrows the journal's effect; it
does not add a new one. The other capability that ever appears is whatever the **fired
callback** itself performs, charged to the callback's own effect grant (§4.1).

| Operation | Capability | Resource matched |
|---|---|---|
| `after` / `at` / `every` / `recur` / `cron` / `cancel` (non-durable) | — | none — schedules on the loop; **the callback's effects are charged to the callback** (§4.1) |
| same, with `durable` | the **journal's** write cap | the `[journal]` handle's store backend — the append/fold effect is the journal's, not a new sched cap (§3.2 / §4.5) |
| `restore` | the **journal's** read/write cap | folds + re-arms from the `[journal]`; same capability as the journal it was given |
| `test-clock-advance` | — | test-harness control; production → `CXER4970` (§3.3) |
| `timer-state` / `clock-mode` | — | **pure** (§3) |

A raw effect inside a fired callback without a live grant raises
`cx-err:CXER0271 E_CAP_DENIED` at the callback's effect point (SAP §5.2 / net §5),
naming the missing grant — sched adds nothing to that flow. A `durable` arm against a
journal the caller lacks the cap for fails at the **journal's** effect point with that
same `CXER0271`, naming the journal/store grant.

## §6. Composition with the integration layer

Canonical call form is `[$sched:VERB …]` (`[head …]`); never `[?try]` — handle a
faulted callback by shape (`[?match]` / `[?else]`, SAP §2).

```cx
[?with-open [$sched:after "10m" $on-window-elapsed {name: 'no-ack'}] $t        # arm a 10-minute window
  [?match [$bus:await-ack :escalation]
    [case [ack] [$sched:cancel $t]]                                             # human acked → cancel (false-by-presence)
    [case $_ $_]]]                                                              # window fires; [?with-open] cancels on exit

# durable incapacity window — survives a worker recycle (xap.md §22.8)
[$sched:after "10m" $post-window-elapsed {name: 'no-ack' durable: $jr}]        # intent persisted to journal $jr
# … on the replacement worker, at startup:
[?let [= $rep [$sched:restore $jr {'no-ack': $post-window-elapsed} {}]]      # re-arms with remaining time
  [$report-orphans [meta-of $rep :orphaned]]]                                  # any unbound persisted timers surfaced, not dropped

# nightly compaction at 02:00 local, catching up at most once if the box was asleep
[$sched:cron "0 2 * * *" $compact {name: 'compact' on-missed: :coalesce}]
```

- **`cx-xap`** — `[$xap:after …]` **wraps** `[$sched:after …]`: XAP supplies
  the bus-posting channel as `$ev`, so a fired window posts the window-elapsed event
  in commit order (xap.md §14 serialized cascade). XAP does not reimplement the timer.
- **`cx-stdlib/authz`** — a **guardian gate** ([`xap.md`](xap.md) §22.8) folds the
  window-elapsed events sched posts: `no-ack-within "10m"` is an `after` armed when a
  prompt/escalation issues; an ack **cancels** it, so it stays false while the
  principal is present (**falsifiable-by-presence**, §10.8 invariant 4). For a window
  that **must survive a worker recycle** (invariant 3, minimum-persistence) the gate
  arms it `durable` against the tenant journal and the replacement worker re-arms it via
  `restore` (§2.4 / §4.5). The timer is the *mechanism*; will-independence /
  falsifiability live in `authz`'s signed predicate library, not here.
- **`cx-stdlib/time`** — `at` takes a `time` `::datetime`; `recur` consumes a `time`
  `[recurrence …]`; `cron` calls `[$time:parse-cron]` → `[recurrence …]` then re-arms
  via `[$time:next-occurrence]` honoring COUNT/UNTIL. All calendar/tz/cron grammar is
  `time`'s ([`time.md`](time.md) §3.10).
- **`cx-stdlib/journal`** — the `durable` opt appends `[sched-intent …]` entries via
  `[$journal:append]`; `restore` folds them (`[$journal:fold]`) to re-arm pending
  timers ([`journal.md`](journal.md)). sched composes journal-over-`store`;
  it adds no persistence mechanism.
- **`cx-stdlib/http` SSE leg** — the auto-`keep-alive` heartbeat
  ([`http.md`](http.md) §3.6 — the former `stdlib_http_streaming_amendment.md` §1.2,
  since folded into `http.md`) is
  a low-priority `every` on the same picoev loop.
- **Resilience (§10.2)** — a `[?timeout]` wrapping a scheduling op cancels
  cooperatively → core `CXER0260` (§4.4); `[?with-open]` cancels an armed timer on
  scope exit.

## §7. Applicability matrix (UNIFORM gate — authoring-guide §3 / SAP §0.2)

✅ supported; ❌ deliberately unsupported (rationale); — not applicable.

| Operation | `:wall` clock | `:manual` (test) clock |
|---|:--:|:--:|
| `after` (relative one-shot) | ✅ | ✅ |
| `at` (absolute one-shot) | ✅ | ✅ |
| `every` (recurring) | ✅ | ✅ |
| `recur` (recurrence rule) | ✅ | ✅ |
| `cron` (cron string → rule) | ✅ | ✅ |
| `cancel` / `close` | ✅ | ✅ |
| `restore` (durable re-arm) | ✅ | ✅ |
| `timer-state` | ✅ | ✅ |
| `clock-mode` | ✅ | ✅ |
| `test-clock-advance` | ❌ ¹ | ✅ |

| `every` cadence `mode` | applies |
|---|:--:|
| `:fixed-delay` (default — re-arm after callback returns) | ✅ ² |
| `:fixed-rate` (anchored grid, drift via `on-missed`) | ✅ ³ |

| `on-missed` policy (`every :fixed-rate` / `recur` / `cron` / durable restore) | applies |
|---|:--:|
| `:skip` (default — next future occurrence only) | ✅ ⁴ |
| `:coalesce` (fire once, then resume) | ✅ ⁴ |
| `:fire-all` (fire once per missed occurrence) | ✅ ⁴ |

| Durability | applies |
|---|:--:|
| in-memory timer (default) | ✅ |
| `durable` timer persisted to a `journal` + `restore` | ✅ ⁵ |
| sched-owned persistence backend (own store/replay) | ❌ ⁶ |

Footnotes: **1** `test-clock-advance` under the production `:wall` clock →
`CXER4970` (§3.3) — a test-harness control, pinned by a negative fixture. **2** the
default cadence (§2.2/§4.3): no backlog; a long callback delays the next arm.
**3** anchored to the `t₀+k·$dur` grid (§2.2); occurrences elapsed during an overrun are
resolved by `on-missed`. **4** the catch-up policy is identical for a real outage and a
`test-clock-advance` crossing N deadlines (§2.5/§4.6). **5** durability is
`journal`-over-`store` (§3.2/§4.5) — the load-bearing worker-recycle correctness path
(xap.md §22.8). **6** sched adds **no persistence mechanism of its own** — it composes
the caller's `journal`; building a private store/replay engine is out of scope (that is
`journal`/`store`'s job).

The single remaining asymmetry (no production test clock; no sched-private store) is
justified above and pinned by §10 fixtures — a **documented limit**, not an open cell.
**Revision 2 closes the former fixed-rate / cron-calendar / durable gaps** — all three
are now supported (✅) rather than deliberately-out-of-scope.

## §8. Error codes — `CXER4970–CXER4989` band (proposed allocation)

`CXER4970–CXER4989` is **proposed** for `cx-stdlib/sched` in the governance registry
([`governance.md`](../process/governance.md) §9.6) — confirmed at graduation against
the live registry (the band scan must show no overlap; this range is provisional
until the §11 governance step runs). All values use `cx-err:` notation; symbolic↔wire
is 1:1 (governance invariant). **Cancellation is the core `CXER0260`, not a sched
code** (§4.4).

| Code | Symbol | Raised when |
|---|---|---|
| `cx-err:CXER4970` | `E_SCHED_TEST_CLOCK` | `test-clock-advance` called under the production (`:wall`) clock (§3.3) |
| `cx-err:CXER4971` | `E_SCHED_ARG_INVALID` | a non-positive / non-`::duration` `$dur` (or non-`::datetime` `$when`), or an `$ev` that is neither a zero-arg callable nor a `[?channel]` (§2.1/§3.1) |
| `cx-err:CXER4972` | `E_SCHED_MODE_INVALID` | `mode` not in `{:fixed-delay, :fixed-rate}`, or `on-missed` not in `{:skip, :coalesce, :fire-all}` (§3.1) |
| `cx-err:CXER4973` | `E_SCHED_DURABLE_NO_NAME` | `durable` set without a `name` opt — `name` is the registry key on `restore`, so a durable timer **must** be named (§3.1/§3.2) |
| `cx-err:CXER4974` | `E_SCHED_DURABLE_NO_JOURNAL` | `durable: true` with no journal available (neither an opt `[journal]` nor a loop-config journal), so intent cannot be persisted (§3.2) |
| `cx-err:CXER4975` | `E_SCHED_RESTORE_INTENT` | `restore` found a `[sched-intent …]` entry it cannot interpret (corrupt/unknown kind/version) — surfaced as a fault, not silently skipped (§3.2) |
| `CXER4976–CXER4989` | — | **reserved** for future sched extensions |

`recur`/`cron` do **not** mint a code for a malformed rule/cron string or an exhausted
COUNT/UNTIL: a bad cron string surfaces **`time`'s parse fault** unchanged (§2.3), and
COUNT/UNTIL exhaustion is the **normal terminal `"fired"` transition** (a value, §3.1),
not a fault. An **orphaned** durable intent on `restore` is likewise a **present
finding** in the `[restore-report …]` value (§3.2), not a fault.

**Shared/core codes sched surfaces (not in its band):** `cx-err:CXER0271`
(a raw effect in a fired callback without a grant, **or** a `durable` arm/`restore`
against a journal the caller lacks the cap for — charged at the journal's effect point,
§5); `cx-err:CXER0260` (cancellation of a scheduling op, §4.4); the journal/store
`CXER11xx` faults a `durable`/`restore` op propagates unchanged from `journal`
([`journal.md`](journal.md) §8); `cx-err:CXER0108` **never raised** (the
`[timer]` is closeable, §2.1).

**Governance note (graduation).** Add `CXER4970–CXER4989 | cx-stdlib/sched |
spec/std-lib/sched.md` to the registry and re-run the band scan (confirm no overlap
with neighboring allocations; this band is provisional until then).

## §9. Implementation notes (non-normative)

| sched surface | Building block | Note |
|---|---|---|
| `after` / `at` / `every` / `cancel` | the **picoev timer wheel** already present for read/write deadlines (the patched V fork, `third_party/v/vlib/picoev`; the same loop `cx-stdlib/http` §9 drives) | register a one-shot (`after`/`at`) or re-arming (`every`) timeout that invokes `$ev` / posts a tick onto the loop's ready queue; `at` resolves `$when` to an elapsed deadline; `:fixed-rate` re-arms against the grid `t₀+k·$dur`, `:fixed-delay` against now+`$dur` post-callback; `cancel` removes the wheel entry |
| `recur` / `cron` | the wheel + a `time` callback | re-arm an internal `at` for each `[$time:next-occurrence $rule $last]`; `cron` first `[$time:parse-cron]`s `$expr` to a `[recurrence …]`. sched holds no calendar math |
| `durable` / `restore` | `[$journal:append]` / `[$journal:fold]` over `store` | on arm/fire/cancel append a `[sched-intent …]` / progress / closed entry; `restore` folds to pending intents and re-arms, binding `$ev` by `name` from the registry and applying `on-missed` for missed deadlines. No sched-private store |
| `on-missed` catch-up | a count of grid points / occurrences crossed since the last live deadline | `:skip` arms only the next future point; `:coalesce` fires once then arms next; `:fire-all` enqueues one fire per crossed point in deadline order |
| `timer-state` / `clock-mode` | a small handle struct read | pure, no loop interaction beyond reading the recorded state |
| test clock | a **virtual-time source** the timer wheel reads instead of `monotonic()` when the loop's clock mode is `:manual` | `test-clock-advance` advances it and drains all timers now ≤ virtual-now in deadline order, applying `on-missed` for multi-deadline crossings — deterministic, no `sleep`s; re-arming timers re-compute against virtual time |

sched is a **separate module from `cx-stdlib/http`** but shares http's picoev loop —
there is exactly one loop per process; both register their timers on its wheel. Spec
is implementation-agnostic; only the §3 surface + §4 guarantees are normative. The
existing evaluator timer/lifecycle paths (if any) SHOULD refactor onto this module
once it graduates (no silent dual timer stack).

## §10. Conformance fixtures (to author on graduation)

Hermetic — **all timer fixtures use the `:manual` test clock** (§3.3); durable fixtures
use an in-memory / temp `store://` journal; **no wall-clock sleeps**. **Every §7 matrix
✅ has ≥1 positive fixture; every justified ❌ a negative/skip fixture.**

**Core scheduling / cancellation / state.** `after "10m" $cb` fires the callback
**exactly once** after `test-clock-advance "10m"` (`timer-state` `"armed"→"fired"`);
`after` with a `[?channel]` `$ev` posts **one tick** on fire; `cancel` **before** the
deadline prevents the fire and returns `true` (`state "canceled"`); `cancel` **after**
fire returns `false` (idempotent); `[?with-open]` on a `[timer]` cancels an armed timer
on scope exit; `clock-mode` reads `":manual"` under the harness.

**`at` (absolute one-shot).** `at <future-datetime> $cb` fires once when the test clock
crosses that instant; `at <past-datetime> $cb` (non-durable) fires on the next loop
turn.

**`every` cadence.** `every "1m" $cb` (default `:fixed-delay`) fires **N times** across
an N-minute advance, and a callback whose virtual runtime exceeds `$dur` **delays** (does
**not** queue) the next fire; `every "1m" $cb {mode: :fixed-rate}` fires on the
**steady grid** — a callback that overruns one slot does **not** push later fires off
the grid; `every` keeps `state "armed"` until `cancel`.

**`recur` / `cron`.** `recur` against a `[recurrence …]` with **COUNT 3** fires exactly
3 times then goes terminal `"fired"` (does not re-arm); a recurrence with **UNTIL** stops
at the bound; `cron "0 9 * * 1-5" $cb` fires on each weekday-09:00 the test clock
crosses; a malformed `cron` string surfaces **`time`'s** parse fault (asserted as
`time`'s code, not a sched code).

**Catch-up (`on-missed`).** With a `:fixed-rate every "1m"` (or a `recur`),
`test-clock-advance "5m"` crossing 5 deadlines fires: **once** under `:skip` (default),
**once** under `:coalesce`, **5 times** under `:fire-all` — each deterministic, in
deadline order (§4.6).

**Durable / restore (worker-recycle correctness).** `after "10m" $cb {name:'w'
durable:$jr}` appends a `[sched-intent …]` to journal `$jr`; a **fresh loop**
`restore`d from `$jr` with registry `{'w': $cb}` re-arms the window with its **remaining**
time and it still fires (the §2.4 / xap.md §22.8 path); after the timer fires/cancels,
`restore` does **not** re-arm it; a persisted intent **absent from the registry** is
reported as `orphaned` in the `[restore-report …]` (present value, not dropped); a
durable window crossed past its deadline during downtime applies `on-missed` on restore.

Negatives: `test-clock-advance` under the production (`:wall`) clock → `CXER4970`; a
non-positive / non-`::duration` `$dur` (or non-`::datetime` `$when`) or malformed `$ev`
→ `CXER4971`; a bad `mode`/`on-missed` value → `CXER4972`; `durable` without `name` →
`CXER4973`; `durable: true` with no journal → `CXER4974`; a corrupt `[sched-intent …]`
on `restore` → `CXER4975`; a raw network effect inside a fired callback without a live
grant → `CXER0271`; a `durable` arm against a journal the caller lacks the cap for →
`CXER0271` at the journal effect point; a `[?timeout]` cancellation of a scheduling op →
core `CXER0260`.

## §11. Graduation checklist (executor → user G3)

- [ ] **Governance registry** ([`governance.md`](../process/governance.md) §9.6):
      add `CXER4970–CXER4989 | cx-stdlib/sched | spec/std-lib/sched.md`; re-run the
      band scan (confirm the proposed band has no overlap — finalize the range here).
- [ ] **Module index + count (see §12).** Add a `sched` row to
      [`spec/std-lib/README.md`](../std-lib/README.md) §3 (Tier-B); bump the
      sub-package count by **+1** (on the then-current count); add `'cx-stdlib/sched'`
      to the skeleton test `vcx/tests/stdlib_skeleton_test.v` `expected` list and
      bump its asserted count by +1.
- [ ] **Implement** the §3 surface on the picoev timer wheel (§9):
      `after`/`at`/`every`/`recur`/`cron`/`cancel`/`timer-state`;
      `test-clock-advance`/`clock-mode` over a virtual-time source; both cadence modes
      (`:fixed-delay`/`:fixed-rate`, §2.2) + `on-missed` catch-up (§2.5); the `durable`
      opt + `restore` over a `journal` (§3.2); the `:manual` clock-mode plumbing shared
      with the http server leg.
- [ ] Confirm sched's reliance on the §0 in-review amendments survived their G3
      (four-channel model, `[?try]` retirement, `CXER0260` cancellation, closeable
      contract, orthogonality-guard home).
- [ ] **`cx-stdlib/time` must be available** (hard dependency — `::duration`,
      `::datetime`, `[recurrence …]` + `[$time:next-occurrence]` / `[$time:parse-cron]`):
      graduate sched **after or with** the `time` recurrence surface ([`time.md`](time.md)
      §3.10 — the former `stdlib_time_recurrence_amendment.md`, since folded into
      `time.md`) so `recur`/`cron` resolve. If that surface is not yet graduated,
      `recur`/`cron` are gated out and only `after`/`at`/`every` ship.
- [ ] **`cx-stdlib/journal` must be available** for the `durable`/`restore` surface
      (hard dependency — `[$journal:append]` / `[$journal:fold]`): graduate sched
      **after or with** [`journal.md`](journal.md). If journal is not yet
      graduated, the `durable` opt + `restore` are gated out (the in-memory surface still
      ships).
- [ ] Coordinate with the http SSE amendment: its auto-`keep-alive` heartbeat and its
      §5 fixtures reference sched's test clock — graduate sched **before or with** the
      http SSE amendment so those cross-references resolve.
- [ ] Coordinate with `cx-xap` / `cx-stdlib/authz`: `[$xap:after]` wraps
      `[$sched:after]`; guardian gates fold sched-posted window events (§6).
- [ ] Author §10 fixtures (all under the `:manual` test clock); wire into the gate.
- [ ] Validate repo-relative cross-references render.
- [ ] Move `spec/02-inprogress/xap/sched.md` → `spec/std-lib/sched.md`
      (user-only).

## §12. Module-count reconciliation (normative for the count; no edits made here)

This section states the count delta and the **exact lines** that change at
graduation; per Rule G3 it makes **no edits**.

`cx-stdlib/sched` is a **genuine new module** (a +1), not a reconciliation: it is
**not yet a bundled name** in `vcx/tests/stdlib_skeleton_test.v`
(`test_stdlib_surface_enumerates_bundled_subpackages`) and has no
[`spec/std-lib/README.md`](../std-lib/README.md) §3 row. So unlike `http` (which
reconciled an existing bundled name), sched **adds** a name and **bumps** both the
README count and the skeleton assert by +1.

| Target (by section/symbol) | Current | Becomes (at graduation) |
|---|---|---|
| `README.md` §3 intro sentence | "enumerates **N** sub-packages" | "**N+1**" |
| `README.md` §3.2 frozen-surface sentence | "The **N-module** … frozen surface" | "**(N+1)-module**" |
| `README.md` §3 Tier-B table | (no `sched` row) | add `\| sched \| scheduled events & timers — relative/absolute/recurring/cron + durable, on the event loop \| [sched.md](sched.md) \|` |
| `stdlib_skeleton_test.v` — `test_stdlib_surface_enumerates_bundled_subpackages` | asserts **N**, no `'cx-stdlib/sched'` | assert **N+1**, add `'cx-stdlib/sched'` to `expected` |

**`N` is the then-current count** — sched applies **+1** to whatever the live count is
at its graduation (order-independent vs. the other in-flight drafts: http reconciles
README→30 without moving the skeleton; net/fp each +1; sched +1). **No edits are made
by this draft** (G3) — the table above is for the graduation PR.

---

### Open design questions

1. **`every` recurrence model — RESOLVED (keep `every`; `:fixed-delay` default,
   `:fixed-rate` opt-in).** `every` is the recurring primitive; the `mode` opt picks
   `:fixed-delay` (default — re-arm after the callback returns, no backlog) or
   `:fixed-rate` (anchored grid). `:fixed-delay` is the safe default (no
   drift/thundering-herd); `:fixed-rate` is now offered for clock-like cadences with
   its overrun behavior governed by `on-missed` (§2.2/§2.5/§4.3). Revision 2 promoted
   fixed-rate from out-of-scope to an opt.
2. **Calendar / cron + durability — RESOLVED (in scope, composed).** Revision 2 brings
   `at` (absolute one-shot), `recur` (a `time` `[recurrence …]` rule), `cron` (cron
   string → rule), and `durable`/`restore` (timers persisted to a `journal`, surviving
   a process restart) into scope. sched owns no calendar grammar or persistence
   mechanism — it composes `time` (recurrence/cron) and `journal`-over-`store`
   (durability). Durability is a **correctness need** (guardian incapacity windows must
   survive a worker recycle, §2.4 / xap.md §22.8), not polish.
3. **Error band — `CXER4970–CXER4989` is PROPOSED, pending registry confirmation.**
   Revision 2 allocates `CXER4970–CXER4975` (test-clock, arg, mode/on-missed,
   durable-no-name, durable-no-journal, restore-intent) within the band; `4976–4989`
   stay reserved. Provisional until the §11 governance band scan runs against the live
   [`governance.md`](../process/governance.md) §9.6 registry; if it collides, sched
   takes the next free 20-code block and §8 is renumbered in lock-step.
