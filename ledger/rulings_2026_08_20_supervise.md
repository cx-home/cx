# Rulings — cx-stdlib/supervise graduation + implementation (2026-08-20)

## SUP-1 — graduate the contract AND implement pre-cut

**RULED 2026-08-20 (owner): "3b"** — the supervise contract
(`spec/02-working/supervise.md`, issue #765) graduates to
`spec/03-approved/std-lib/supervise.md` AND the module ships
(`stdlib/supervise.cx`) before the v0.16.0 cut. The module is pure CX
over shipped primitives — `[?worker]`/`[?monitor]`/`[?select]`
(code.md §10.4.6/.6a/.7), fan-out channels (U1.11a), `cx-stdlib/sched`
timers under the mock clock, the §10.5.4/§10.5.7 cancellation
contract. `spec/02-working/worker_lifecycle.md` (design letter U2, all
rulings made 2026-08-10) archives EXECUTED — supervise.md is the
living product. Error band `CXER5090–5109` registered in
`process/governance.md` §9.6 before first use.

Token: `RULED: SUP-1`.

## First-contact riders (recorded, never silent)

Each rider is a spec correction discovered by implementing against the
live engine. The graduated spec text carries these; none reopen a
settled ruling.

**SUP-1a — `status` is impure.** The §3 sketch marked `status` pure
("reads the handle"). Purity is ENFORCED (`CXER0233
E_PURITY_VIOLATION`): every read of live supervisor state is a
`[?subscribe]`/`[?receive]`/`[?send]` — impure directives by the
closed §6.5.0 table — and the handle element is an immutable value, so
a pure `status` could never reflect live state. `status` ships
`scope=public impure`; signature otherwise verbatim. Live: a running
supervisor answers through the control round-trip (ordered after every
note the caller has already observed); a stopped supervisor stays
readable through the status cell (a `keep=1` fan-out window the loop
publishes into; read = subscribe-at-floor + drain), exactly the §8
"`status` stays readable" clause.

**SUP-1b — the events laggard code is `CXER0218`.** §9/§10 said a
laggard observer hits `CXER0205`; the ruled channel contract
(code.md §10.4.8, U1.11a) names STREAM_GAP `CXER0218` (re-subscribe to
re-seed). Trued to `CXER0218`. No supervise-local gap fixture: the
events surface is a standard `keep=256` fan-out subscription and the
gap contract is pinned by the core channel lane
(program-conc-027 family); supervise adds no gap logic of its own.

**SUP-1c — the child `fn` rides as a child element; handle-close and
handle-monitor spellings.** Attributes are scalar-only (code.md
§6.4.1, live-refused), so the §2/§6 sketch `fn=$start-ingest` cannot
exist. A child spec is
`[child name=… restart=… shutdown=… [fn CALLABLE]]`. The
`[supervisor]` handle satisfies the closeable contract through
`[?with-open]` (its close id is the loop's inbox subscription: close →
the parked loop wakes closed-and-drained → the graceful stop path
runs, loop terminal `[stopped]`); bare `[?close $sup]` is not accepted
by the engine's `[?close]` (channel/subscription-specific) — `stop` is
the explicit verb. `[?monitor]` accepts worker handles only, so
monitoring a supervisor is spelled
`[?monitor [?worker-handle name=$sup@worker]]` — the §1 "monitorable
handle" posture, one indirection made explicit.

**SUP-1d — event field spellings trued.** A constructed element with
an `[err]` child RAISES (the #853 position table: dynamic child
propagates), so `[child-exited]` carries the child's fault as
`err-code=` (the code string), not an embedded `[err …]` child;
`[child-restarted]` carries `delay-ms=` (integer milliseconds — a
duration value in attr position round-trips as its literal, but the
millisecond int is the deterministic fixture spelling); `[gave-up]`
carries `restarts=` + `window-ms=`. `[supervisor-status]` children
nest as one sequence value (element construction does not splice).

**SUP-1e — upstream defect found and fixed: sched ticks to fan-out
channels were dead wire.** `sch_invoke`
(vcx/code/stdlib_sched_notd_cx_no_pack_sched.v) posted `[tick …]` via
the group-queue `ch_enqueue` even when `$ev` was a
`sharing=independent` channel — the tick landed where no subscriber
ever looks, so a select/subscription loop could never observe a timer
through a fan-out point (the exact composition code.md §10.4.6a
promises for backoff timers). Fixed: `sharing=independent` posts via
`ch_fan_send` (the same split `eval_select`'s send-case makes). Three
lines of V; no golden movement (no existing fixture armed a timer at a
fan-out channel — that is how it stayed dead). The supervise backoff
fixtures now pin the composition.

**SUP-1f — the abandon rule against request-stamped cancellation.**
`[?cancel]` stamps the `WORKER_CANCELLED` terminal at REQUEST time
(state_locks.v cancel-wins arbitration, §10.5.4) — a monitor's
terminal therefore always arrives promptly after a supervisor-initiated
cancel, even while a cancellation-point-free body is still running
(capability-narrowed, unable to start new I/O — §10.5.7.2 is the
backstop). On this substrate the shutdown wait resolves immediately
and `[child-abandoned]` is unreachable: the no-hang half of §4.4 holds
trivially; the never-pretend half is delegated to the platform's own
terminal semantics (cancellation is the requested outcome). The
`abandoned` state and `[child-abandoned]` event stay in the surface
(the shutdown-bounded wait is implemented and takes over on any
substrate whose terminal is observation-time); the V lane
(vcx/tests/stdlib_supervise_test.v) pins today's behavior: stop of a
wedged (pure-loop) child returns promptly, the supervisor never hangs.
The §10 wedged-child fixture rides that V lane, not the .cxd corpus —
the corpus cannot observe a difference the substrate does not expose.

**SUP-1g — the escalation carrier is the panic CAUSE chain.** A worker
that terminates on an err panics as
`[panicked … [err CXER0220 [cause [err CXER5094 …]]]]` (code.md
§10.4.8 WORKER_PANIC wraps the body err). §4.3's "a parent sees
`[panicked … [err CXER5094 …]]`" is satisfied through the cause chain;
the tree fixture pins the exact shape. A parent supervisor's
child-exited event for a collapsed subtree therefore reads
`err-code=cx-err:CXER0220` with the give-up as its cause — restart
policy is code-independent, so escalation-by-composition is unchanged.

**SUP-1h — policy defaults recorded.** The sketch showed a fully
spelled policy; the shipped surface defaults absent fields:
`strategy=:one-for-one`, `max-restarts=3`, `window=5s`,
`backoff=:none` (immediate restart), `base=100ms`, `cap=10s`,
per-child `restart=:permanent`, `shutdown=5s`. `backoff=:exp` is the
opt-in the §2 sketch showed; `:none` as default keeps the
zero-config supervisor deterministic under the mock clock.

## Implementation record (landed 2026-08-20)

- `stdlib/supervise.cx` — the module, pure CX: one loop worker per
  supervisor parked on a fan-out inbox subscription (terminal notes
  from the child-body wrapper, ops with embedded reply channels, sched
  ticks); policies as data; strategies via one affected-set computation
  (cancel reverse / restart in start order, `:temporary` excluded from
  restart sets); intensity = decision count with sched window-expiry
  ticks; per-child exp backoff + attempt-reset health ticks; bounded
  stop via non-consuming `[?select]` monitor probes; give-up cancels
  all (reverse, bounded), emits `[gave-up]`, returns the `CXER5094`
  err (the loop worker's panic cause). The handle's `__cx_close_id__`
  is the inbox subscription's close id, so `[?with-open]` close wakes
  the parked loop closed-and-drained into the same graceful stop.
  Registered in the binary bundle (`vcx/code/stdlib_bundle.v`, 44→45).
- `conformance/stdlib/supervise.cxd` — 30 cases (24 behavior/negative
  + 6 fn-doc-backing), suite default=enforced, ALL GREEN in
  `vcx/tests/code_eval_fixtures_test.v`. Mock-clock arms use a status
  round-trip as the ARM BARRIER (ops queue behind terminal notes in
  the one inbox, so the reply proves timers are armed before the
  fixture advances the clock).
- `vcx/tests/stdlib_supervise_test.v` — the SUP-1f no-hang arms
  (wedged cancellation-point-free child: stop and stop-child return
  promptly; terminal honesty; sibling untouched). GREEN.
- Upstream fix (SUP-1e): `vcx/code/stdlib_sched_notd_cx_no_pack_sched.v`
  `sch_invoke` fan-out tick delivery. Zero golden movement.
- Cancellation hygiene + classify-parity: supervise is the first frozen
  module whose impure surface includes pure-CX COMPOSITION defs (bodies
  whose only impure reach is other module defs). The engine's purity
  refusal is direct-only (a pure def calling an impure DEF is admitted —
  the #788 slip, live-verified), so the ten composition defs each carry
  a real `[?check-cancel]` cancellation point at entry (§10.5.4 loop
  hygiene AND the direct impure marker the classify-parity gate
  requires). Two loader-seeding test updates ride along (the x/-tier
  precedent, comment carried): `stdlib_umbrella_test.v`
  `test_stdlib_every_subpackage_parses_and_exposes_public_def` and
  `eval_semantics_umbrella_test.v` `test_ring2_impure_registration_parity`
  now resolve each module against the bundled table — frozen modules
  MAY compose frozen modules by `[?lib]` (supervise imports
  sched/time/fp), and an empty table mis-reported that as a load
  failure.
- Graduation mechanics: spec moved + riders folded in; module-meta
  `status=current`; `worker_lifecycle.md` archived ✅ EXECUTED;
  governance §9.6 row `CXER5090–5109`; README §3 44→45 (+ Tier-D row,
  §3.2 bullet); skeleton test 44→45 + name; `conformance/gates.cxd`
  supervise row (enforced); delivery.md mention repointed.
- Lanes at landing: code_eval_fixtures (incl. all 30 supervise cases)
  GREEN; stdlib_supervise_test GREEN; stdlib-catalog-gate OK (52
  current modules); guide-check OK (59 modules); guide rebuild OK;
  verify-doc-blocks 361/0; verify-doc-links spec/03-approved 1425+/0,
  docs-src 230/0 (with the built guide); gates-manifest-gate OK.
  Pre-existing reds, untouched by this landing: cxer-registry --strict
  (CXER4890-4891, xap_dist — tracked #717) and version-consistency
  (spec/02-working/diagram_renderer_cx.md v0.16.0 literals — another
  in-flight spec).
