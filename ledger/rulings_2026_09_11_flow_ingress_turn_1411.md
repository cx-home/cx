# RULED: 1411-a — a `serial` serve gives its handlers the program's evaluator TURN; `cx flow serve` is serial

Fable, 2026-09-11 ~14:00Z, under the owner's delegation of 2026-09-09 05:50 ET. The owner may
override on #1354. Issue: #1411.

## What was measured before ruling (never claimed from memory)

- The one-test binary (`flow_umbrella_test.v` `four_kinds`, body-naming assertion `603699eee`)
  against the `c4ac6e471`-era `cx-dev`, 40 runs under gate load: 1 failure,
  `b1: [err code=cx-err:CXER1140 E_STORE_HANDLE_RACE …]`.
- After the fold-worker fix (`d11717c11`: the store's own background fold cleared `fold_running`
  BEFORE unlocking), 80 runs: **3 failures** — two `CXER1140`, one
  `CXER0271 E_CAP_DENIED: read capability required for store journal-append …; none granted`
  under `--allow-all`. The fold-worker window is a real defect (kept), but not this one.
- Every `$journal-*` builtin funnels through the journal's own mutex (#642), so the two threads
  never contend INSIDE a journal op. They contend on what the evaluator keeps per PROCESS:
  `g_active_caps` (the served flow's acts declare `[effects [write]]`; the courier thread's act
  admission narrows the process set to that while the act runs, so the ingress thread's append
  finds no `read` — the 0271), and the Store handle's owner/depth bookkeeping + head cache (the
  1140). Five gates on 2026-09-11 (`dae4965e3`, `d753172aa`, `c4ac6e471`, `24094cc18`,
  `f4546f2a1`) carried this red.

## The fork

A CX program is single-threaded until `[$http:serve …]` returns without `block` and the program
continues — from then on handler closures run on executor threads concurrently with the main
thread, over per-process evaluator state. `cx flow serve` is the first program that does
substantial CX work (journal appends, act invocations under narrowed caps) on BOTH sides.

**(a) — RULED. The evaluator TURN.** `[$http:serve url handler {serial: true}]`: the serving
program takes the process's evaluator turn when it enables it; a handler of that serve runs only
while it holds the turn; the program gives the turn up ONLY inside `[?sleep]` (the one place a
courier loop blocks by design) and takes it back when the sleep ends. `cx flow serve` passes
`serial: true`. The invariant is "one CX evaluation at a time in this process" — exactly what
every program had before serve. Latency: a delivery is answered during the runner's sleep, i.e.
immediately in the common case, and after the current tick's work otherwise (ms). Nothing to
configure per global; the http lanes' concurrent engine is untouched for every serve that does
not ask. DELETES: concurrency between a serial serve's handlers and the program that started
it — which was never sound.

**(b) `listen` + `accept-iter` drained on the tick thread — refused.** `accept-iter` is a
blocking single-use stream; draining it between ticks needs an accept deadline the http module
does not have (a runtime change of the same size), and it caps ingress latency at the courier
period (`every=1s` ⇒ 1 s to answer a webhook), which changes the runner's observable behavior
for a problem that is the evaluator's.

**(c) make every per-process evaluator global thread-safe (caps per thread, atomic store
bookkeeping, per-thread journal caches) — refused for v0.18.** Open-ended: the capability set
is process-wide by design (`[?with-caps]` narrows a process, the CLI grants a process), and a
per-thread set would change what `[?with-caps]` means. The class is real and is recorded as the
trigger that reopens this: the first program that NEEDS a concurrent serve AND a working main
thread (none exists; the XAP host blocks).

**(d) retry the ingress `start` on `CXER1140`/`CXER0271` — refused.** Papering over a race with
a retry leaves the courier's own starts silently refused (a tick's `[err]` is `$count`ed), and
WF-31's "redelivery ⇒ one effect" must hold without luck.

## Riders

1. `[?sleep]` is the ONLY yield point. A handler that must run while the main thread is inside
   a long act waits; that is the contract, stated in `http.md`'s opts table.
2. `serial: true` with `block: true` is `CXER4525`-class argument invalid: a blocked program has
   no main-thread evaluation to serialize against.
3. The fold-worker clear-after-unlock fix (`d11717c11`) stays: a single-owner refusal must
   never fire on the store's own worker, serial serve or not.
4. Spec text, delegated G3 (flagged for the owner): `http.md` serve opts table gains the
   `serial` row; `flow.md` §4.23 states the runner's ingress is serialized with the courier.
5. Graders: `vcx/code/eval_turn_test.v` (the turn's contract, deterministic), and the flow
   runner's `four_kinds` case run 80× under load with the body-naming assertion — zero `400`.
