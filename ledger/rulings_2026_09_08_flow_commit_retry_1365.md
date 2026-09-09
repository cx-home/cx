# Rulings — `f--commit` retries the journal's stale tail, and nothing else (#1365)

2026-09-08, release/0.18. Tracker #1354, HIGH tier (flow commit path). Ruled by
owner + Fable in three passes: `1365-a`/`1365-b` at 19:20 ET, `1365-c` at 21:05
ET after an implementer letter measured a fork in `1365-a`'s last clause.
Commits carry `RULED: 1365-a, 1365-b, 1365-c`.

## The defect, measured

`f--commit` (`stdlib/flow.cx`) treated **any** error from the commit append as
a lost CAS: it re-read the record, re-evaluated the law, and re-performed the
step's act until its fuel ran out, then answered `f--cas-exhausted` —
`CXER1114`. An append can also fail *permanently*: the journal's adapter-stream
declared-writer check refuses an append by the wrong principal with `CXER5078
E_LIVE_EXCLUSIVE_WRITER` (`vcx/platform/stdlib_journal.v:2165-2172`), durably
and cross-process. Measured at `aa0219a01`, one program, two option sets:

```
without opts.expect-pos:   [probe [a1 'running'] [aY 'cx-err:CXER1114'] [ticks-after-Y 49]]
with    opts.expect-pos:   [probe [a1 'running'] [aY 'cx-err:CXER5078'] [ticks-after-Y 1]]
```

49 un-deduplicated invocations of an effectful command that declared no
`[idempotent]` (flow only demands it where a step carries `attempts=`, RULED:
789-WF-26a), and the operator reads a code that names the wrong cause.

## 1365-a — the retry class is EXACTLY the journal's stale tail

`f--commit` retries EXACTLY ONE append error: the journal's head-moved refusal
`E_JOURNAL_STALE_TAIL` (`vcx/platform/stdlib_journal.v:2204-2209`, raised when
`expect-pos` ≠ the target stream's `head-seq`). On it: re-read, re-evaluate,
re-perform, fuel-bounded, `CXER1114` only when the fuel is exhausted — as
before. **EVERY other append error propagates unchanged as the step's own
refusal, recorded on the run, and the act is NOT re-performed.**

**Refused (b): a retry list in flow.** A list of retryable codes maintained on
the flow side is a second copy of a journal fact, and it drifts.

**Refused (c): retry nothing.** That turns two-advancer contention into a
refusal, against the runner law (§4.5: N advancers, one effect).

## 1365-b — the normative sentence belongs to the JOURNAL

`journal.md` §3.2 (optimistic append) states normatively that stale-tail is the
ONLY contention code and every other append error is a refusal. Flow's
predicate **cites that sentence**, and every optimistic appender inherits the
rule — flow's commit path, XAP's fold, `sched`.

Fixture-first, both directions:

- `flow-064` — the measured scenario (declared-writer refusal under the wrong
  principal) → exactly ONE act invocation and `CXER5078` surfaced as itself.
- `flow-065` — a genuine head-moved race → retried and committed once.

## 1365-c — the `opts.expect-pos` branch is KEPT, narrowed to stale-tail

`1365-a` closed with *"the `opts.expect-pos` special case in `f--commit`
(return any error verbatim) becomes redundant and is removed."* **That clause
is WITHDRAWN.** The redundancy claim was wrong, and the miss was Fable's.

`f--advance-once` (`stdlib/flow.cx`) re-derives `$pos` from the caller's pin on
**every** re-entry, and `f--commit`'s retry re-enters through
`f--advance-once` with the **same `$opts`**. So a caller-pinned stale
`expect-pos` would retry a **dead pin**: same position, same state, same
stale-tail, fuel-bounded — ~50 iterations, ~50 invocations of the step's act,
answered `CXER1114` from `f--cas-exhausted`. That is #1365's headline shape on
a second trigger.

It is production-reachable, not only a fixture: `f--take-anchor` appends
`[flow-snapshot …]` to the **same home stream**, so another courier's *park*
moves the head with the step **not recorded** — and `flow.md` §4.5's normative
safety argument (*the runner re-reads the record and re-evaluates — and finds
the work recorded, so it appends nothing and performs no second effect*) does
not cover that case: the re-read finds the work **not** recorded, so the law
re-derives the step and the act is re-performed on every iteration.

**Ruled shape of `f--commit`'s error arm — exactly three cases:**

1. an append error whose code is **not** `cx-err:CXER1114` → return it
   **verbatim** (1365-a, unchanged: one act invocation, the step's own refusal);
2. `CXER1114` **and** `opts.expect-pos` was the **CALLER's** → return the
   journal's stale-tail **verbatim** (one act invocation; `flow.md`'s *"only
   when `opts.expect-pos` was supplied by the caller"* stays true);
3. `CXER1114` **and** flow derived the position itself → re-read, re-evaluate,
   re-perform, fuel-bounded, `f--cas-exhausted` when the fuel is out (1365-a,
   unchanged).

**Refused (b): literal removal of the branch** — stale-tail always retried,
pin or no pin. It ships up to `fuel` un-deduplicated act invocations on the
caller-pinned path and would need a new §4.5 sentence admitting them, plus a
fixture pinning the count (`flow-034`'s `stale-performed-its-own-act` is a `>`
comparison and absorbs 1 or 50 silently).

**Refused (c): `fuel=0` on a caller pin** — one attempt, then
`f--cas-exhausted`. It makes the operator's message (*"lost the home stream's
CAS on every re-read"*) a false account of a single attempt: the right code
with the wrong story, against 1365's stated property that the error an operator
reads names what actually refused.

**Refused reading, recorded:** a retry that *dropped* the pin and re-derived
the head. That would let the stale courier win and append, breaking
`flow-034`'s `gate=enforced` `stale-appended-nothing true`. "Re-read" therefore
cannot mean "re-derive the position" on a caller-pinned advance.

## The predicate tests the CODE, never a message prefix

Recorded because it is the one implementation choice the ruling names
explicitly. `1365-b` names stale-tail as *the ONLY contention code*, and
`vcx/platform/stdlib_journal.v:73` unifies every optimistic-concurrency
conflict on that one code —

```
const jrn_err_stale_tail = 'cx-err:CXER1114' // E_STORE_REF_CONFLICT (I1 row 15 / audit M21: CXER4604 RETIRED …)
```

— so a **store-layer ref conflict beneath the append is retried by design**. A
predicate written against the `E_JOURNAL_STALE_TAIL:` message prefix would
refuse to retry that conflict, and would break the moment the journal reworded
its own message. `f--stale-tail` compares `@code` to `cx-err:CXER1114`.

## What landed

- `stdlib/flow.cx` — `f--stale-tail` (the predicate, citing journal.md §3.2)
  and `f--commit`'s three-case error arm.
- `spec/03-approved/std-lib/journal.md` §3.2 — the normative sentence of
  1365-b.
- `spec/03-approved/std-lib/flow.md` §4.5 — the flow-visible half: a
  non-contention append refusal is the step's own refusal with the act
  performed once, and a caller-supplied stale pin is answered, not retried.
- `conformance/stdlib/flow.cxd` — `flow-064`, `flow-065` (both
  `gate=enforced`).

Nothing else in 1365-a/1365-b moves. `flow.md`'s *"CXER1114 … only when
`opts.expect-pos` was supplied by the caller"* and `flow-034`'s pins are
untouched, and were re-read against the tip before the fix landed.
