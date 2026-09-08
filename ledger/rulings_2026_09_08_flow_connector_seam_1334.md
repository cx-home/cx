# Ruling 2026-09-08 — the flow ↔ connector seam (`1334-SEAM-a`)

**Status: RULED by the project owner on 2026-09-08, posted on #1265 and
#1334.** Ruling id, so it greps literally: `1334-SEAM-a`. Recorded here
because `ledger/` is the ruling store (#832) and the ruling was made in the
tracker; nothing in this file is the recorder's own judgment. The
implementation half it gates in v0.18 is #1314 (`attempts=` / `every=`), and
the derivation for that item is stated at the end and marked as such.

## What was ruled

Flow ships in **v0.18**; connectors (#1334) open **v0.19** as its first
campaign; the two are ONE design. #1334 was scoped for v0.18 beside flow, and
with zero connector code landed it goes second — but flow's v0.18
implementation is bound by these six seam rules NOW, and the connector waves
implement the verb-side halves against them later.

1. **Flow reaches a fulfilment only through kit verbs.** A flow step calls a
   feature verb; a connector is a feature (`728-CK-1`) whose verbs are
   outbound calls. No step ever names a connector, an endpoint, or a
   credential. Rebinding a fulfilment must not change a flow document.
2. **One err shape for backoff.** A connector verb answers 429/503 with
   `[err … retry-after=]` (`728-CK-8`). Flow's bounded `attempts=` (#1314)
   MUST honor `retry-after=` from the verb's err before its own backoff — the
   same field, not a flow-side twin.
3. **Idempotency is the verb's declaration.** `idempotent=` on a verb
   (`xap_schemas/feature.cxs`, `789-WF-38`'s spelling) is what permits flow
   retries; flow never infers it. A connector verb without `idempotent=` gets
   ONE attempt.
4. **Compensation is the verb's declaration.** `compensates=` on a verb is
   what flow's saga uses to unwind; connectors declare their reversing verb
   there; flow never synthesizes one.
5. **Inbound events are streams, not callbacks.** Connector CDC lands on an
   adapter stream; flow's `[on …]` rows subscribe to streams (`789-WF-28`'s
   runner rows). No connector-specific trigger kind in flow.
6. **Timers live in the host.** Polled ingestion cadence and flow deadlines
   both come from the host-as-scheduler (#1313); neither the connector nor the
   runner owns a clock.

Worker assignment in the ruling: flow's `cx flow serve`, `attempts=`, `until`
and the rung-1 gate are implemented against rules 1–6, and where a rule forces
a choice not yet ruled on #1265 it is drafted as a letter rather than answered
flow-locally. Connector waves C3/C5/C8 implement the verb-side halves of 2–5.

## Rule 2 applied to #1314 — a derivation, not a new choice

Rule 2 requires flow's `attempts=` to honor `retry-after=`, and it forbids a
flow-side twin of the field. It does not restate the arithmetic, because the
arithmetic is already ruled: `728-CK-8` (recorded in
`rulings_2026_09_06_connector_open_items_728.md`) and the spec text it landed
at `core/code.md` §10.2.1 / §10.2.1.1 say, of `[?retry]`:

> the delay before the next attempt is the LARGER of the backoff-computed
> delay and `retry-after=` (a duration, or an absolute instant relative to
> `now`) … `retry-after=` raises the wait, never lowers it … the wait
> actually taken is `max(D(N), retry-after)`.

Flow's re-attempt cadence is `every=` (`789-WF-26a`, `789-WF-18a`: one bound
and one cadence, shared with `until`). Substituting flow's cadence for
`[?retry]`'s computed `D(N)` — the ONE thing that differs between the two
loops — gives the flow-side rule with nothing invented:

> The wait before attempt K+1 is `max(every=, retry-after)`, where
> `retry-after=` is read from the `[err …]` the failed attempt answered with:
> a duration, or an absolute instant taken relative to `now`. An err with no
> `retry-after=` waits `every=`; an `attempts=` step with no `every=`
> re-attempts on the next courier tick, as `789-WF-26a` states. Under a
> `calendar=` both are measured in calendar-open time (`789-WF-24a`), because
> `calendar=` is declared to scope `every=`.

Two consequences worth stating because they are the ones an implementation can
get wrong:

- **`retry-after=` cannot SHORTEN a declared cadence.** `max`, not the err's
  value: a server that says "retry in 1s" does not overrule a document that
  says `every=1w`. The field raises the wait so a rate-limited server is
  obeyed; it is not a channel by which a called system sets a flow's pace.
- **Flow reads the field and never writes it.** Rule 2's "not a flow-side
  twin" means no `retry-after=` attribute enters flow's word table (§2.3) and
  no flow refusal invents one; the value arrives on the verb's err and dies
  with the attempt that read it, recorded on the transition as the wait
  actually taken.

The `[?retry]` half of `728-CK-8` remains unimplemented and rides #1334
(`code.md` §10.2.1's own honest status note). That is a different loop in a
different ring: flow's `attempts=` does not call `[?retry]` and does not wait
on it.
