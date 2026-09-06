# Rulings 2026-09-06 — #789, the binding→`start` contract (WF-30 … WF-34)

**Status: RULED (a) on WF-30 … WF-34 under the standing letter-acceptance
rule.** Ids, in full: `789-WF-30a` `789-WF-31a` `789-WF-32a` `789-WF-33a`
`789-WF-34a`. Branch `design/789-workflow`. Open to an owner veto.

**What raised them.** The packet building `cx flow serve` stopped a second
time, before writing code, with five gaps verified against shipped code
rather than spec prose. It was right both times, and two of the five are
defects in my own text:

| Gap | Verified | Whose error |
|---|---|---|
| `[on … start=<Tier-1 address>]` has no document source — nothing turns an address into a document; `[env …]` yields act rows only (`flow_cli_env_scan` returns `directives, acts`) | yes | WF-28a's, mine — the runner cannot start anything |
| the `start` call's `[args …]`, `nonce`, `authority`, `stream` are unruled, and all four are written verbatim into the `:started` transition the one-law gate compares | yes | mine — G2 is not a detail beneath the gate, it is the gate's inputs |
| `stream-prefix="flow:"` contradicts `1265-PB-3`: the run id IS `flow:<address>` and the home stream is that id verbatim, "never `flow:flow:…`" | yes — `stream-prefix` occurs in exactly two places in the tree: my §4.23 example and my own ruling | mine |
| `[courier every=]` cannot enumerate parked runs — `fleet` is the only ruled readout and is NOT implemented | yes — 6 of §3's 17 public verbs ship | the spec's, ahead of its code |
| no bind address for the webhook ingress; the malformed-`[runner]` code is unchosen | yes | mine |

## WF-30 — how `start=<address>` resolves to a document — RULED: (a)

- **(a) RULED — the `[runner]` document names a DOCUMENT SOURCE, and
  `start=` resolves against it with the bytes verified against the address.**
  `[docs url="file://./flows" ]` (a path or a store URL) beside `[journal]`
  and `[env]`. Fetch by address, hash the bytes, compare — a mismatch
  refuses. **What it DELETES:** nothing; it fills a hole. **Why not a
  path:** `start=` stays a content address, which is what makes a binding
  set reviewable, pinnable and portable between faces, and it is the SAME
  mechanism WF-22's sub-flow `flow=` needs — built once, used twice.
  **Strongest counter:** a path is one line and works today. **Answer:** it
  re-introduces the environment-dependence WF-1 exists to prevent, and it
  needs a second spelling when sub-flows land.
- **(b) let `start=` also accept a path,** as `cx flow run` takes `FLOW.cx`.
  REFUSED per above; a second spelling of one thing.
- **(c) resolve from the journal the runner already opens.** REFUSED: a
  journal holds transitions, not documents, so a runner could never start a
  flow it had not already run — which is every flow, on a cold start.

## WF-31 — the `start` call's four inputs, per binding kind — RULED: (a)

- **(a) RULED — ONE rule with five instantiations: the run's nonce is the
  CONTENT ADDRESS OF THE EVENT that started it.** The tension the packet
  found is real and this dissolves it rather than picking a side. §4.9 wants
  `schedule every=1d` to be "one run per period, never a run that never
  ends" — so its nonce must vary per occurrence. §2.2 wants a redelivered
  webhook to dedup — "the record IS the durable step-dedup" — so its nonce
  must be content-derived. Both are the same rule once the nonce is keyed to
  the EVENT's identity:

  | Kind | The event, and therefore the nonce |
  |---|---|
  | `schedule` | the occurrence instant — a new period is a new event, a re-fire of the same occurrence is not |
  | `webhook` | the delivery's content address — a redelivered payload starts no second run |
  | `intent` | the committed intent's `stream` + `seq` |
  | `fold` | the fold position |
  | `file` | the file's content address — the same bytes re-appearing start nothing; changed bytes are a new event |

  **`[args …]` is the EVENT'S PAYLOAD, checked against the flow's `[args …]`
  declaration at start (`CXER4965` when it does not fit). There is no
  mapping language.** A payload that needs reshaping is reshaped by a
  `:runner` step calling a pure transform — which is what §2.3's register
  already requires, since a mapping expression in a binding row would be
  computation inside choreography. **`authority=`** is the basis of the
  `as=` binder, whose own act the start is (§4.9, X2) — the runner
  contributes none (§4.5). **`stream=`** defaults to the run id, per PB-3.
  **What it DELETES:** the possibility of a per-kind nonce convention chosen
  ad hoc, and with it the risk the packet named — a CSPRNG nonce would make
  the one-law gate PERMANENTLY unbuildable, because it could never equal
  `cx flow run`'s derived nonce.
  **Strongest counter:** deriving a nonce from a payload makes two
  semantically different events with identical bytes collide into one run.
  **Answer:** that is the dedup, and it is the behavior §2.2 already
  specifies for redelivery. Where an adopter needs two runs from identical
  bytes, the event carries a delivery id and the address covers it.
- **(b) put a mapping on the row** — `[on … [args …]] nonce-from=`. REFUSED:
  a mapping language inside a binding row is new grammar and a second
  spelling of what a `:runner` step does.
- **(c) defer — empty args, CSPRNG nonce.** REFUSED: a partial
  implementation, and it makes this packet's own gate unbuildable forever.

## WF-32 — what the courier ticks — RULED: (a)

- **(a) RULED — the courier ticks exactly `rearm`'s pending
  `[sched-intent …]` fold plus the runs started in-process this boot.**
  Needs nothing unbuilt, and it ticks exactly the runs a tick can help: a
  run parked on an offered step advances on a CORRELATED ACT, which arrives
  at the ingress, not on a tick. **What it DELETES:** the assumption that
  `cx flow serve` needs `fleet`. It also keeps the runner free of the `live`
  pack — which matters, because ladder rungs 1 and 3 (a make replacement, a
  CI/CD pipeline) must not require it, and `fleet` refuses `CXER4964`
  without it.
- **(b) land `fleet` first and tick from it.** REFUSED for this packet:
  it enlarges it by an unimplemented verb and adds a pack dependency §4.23
  never states. `fleet` remains W4's.
- **(c) scan home streams by a `flow:` prefix.** REFUSED, and incomplete by
  construction: `opts.stream` places a run in its subject's aggregate stream
  (`order:o-5521`), which no `flow:` scan finds.

## WF-33 — the malformed-`[runner]` refusal code — RULED: (a)

- **(a) RULED — `CXER4965` (`E_COORD_ARG_INVALID`).** The `[runner]`
  document is the invocation's input, exactly the class 4965 already names
  ("the caller's fault"), and it spends no code.
- **(b) `CXER4952`.** REFUSED: 4952 is `validate`'s refusal about a FLOW
  document and its mnemonic says so.
- **(c) spend `CXER4969`** via a governance §9.6 extension. REFUSED: the
  band's last code is not spent on a CLI input error. That brake exists for
  a construct that needs one.

## WF-34 — `stream-prefix=`, and the webhook bind address — RULED: (a)

- **(a) RULED — `stream-prefix=` is DELETED from §4.23's example and from
  WF-28a; the home stream is the run id, per `1265-PB-3`, and a run that
  should live elsewhere says so with `opts.stream` as everywhere else.** It
  was my invention, it appears nowhere else in the tree, and prepending
  `flow:` to an id that already begins `flow:` produces the exact
  `flow:flow:…` PB-3 forbids. The webhook ingress takes its bind address
  from the `[runner]`'s own row — `[ingress bind="127.0.0.1:8730"]` — never
  a bare port, so a runner never listens more widely than it was told to.
- **(b) redefine `stream-prefix=` as a scan filter.** REFUSED: it exists to
  serve (c) of WF-32, which is refused.
- **(c) keep it as a prepend.** REFUSED: it contradicts a standing ruling.

## Also found, not ruled here — filed instead

**§3 declares seventeen public verbs; six ship** (`validate`, `simulate`,
`start`, `advance`, `rearm`, `status`). Absent: `fleet`, `migrate`, `claim`,
`release`, `reassign`, `resolve`, `cancel`, `pause`, `resume`, `skip`,
`retry-now`. This is the same class as #1323 — the spec ahead of the code
with nothing red — one surface over. `flow-vocabulary-gate` reads §2.3's
WORD table against the module; it does not read §3's VERB list. Extending it
is the fix, and it is filed rather than folded in here.

## Edit map — `spec/03-approved/std-lib/flow.md`

| Section | Edit |
|---|---|
| §4.23 | `[docs …]` and `[ingress bind=]` in the example; `stream-prefix=` removed; the courier's tick defined (WF-32) |
| new §4.25 | the binding→`start` contract: the event-address nonce rule, its five instantiations, `[args …]` = the payload, `authority=` = the binder's, `stream=` = the run id |
| §8 | `CXER4965`'s row gains the malformed `[runner]` document |
| §11 | a fixture per kind asserting its nonce rule — a redelivered webhook starts ONE run; a second schedule occurrence starts a SECOND |
