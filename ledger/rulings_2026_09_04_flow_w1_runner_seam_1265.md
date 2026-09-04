# Rulings 2026-09-04 — #1265 W1 packet B: the act-performing seam and seven §4 clarifications (PB)

**Status: PB-1 … PB-8 RULED (a) 2026-09-04 under the owner's standing
letter-acceptance rule and the 2026-09-04 directive (run the campaign
through; best long-term decision). Recorded BEFORE the spec sentences they
authorize; implementation-tier rulings inside the WF-9 waves.** Ruling ids
`1265-PB-1 … 1265-PB-8`.

**Inputs read.** `flow.md` §2.2, §3, §4.2, §4.3, §4.5, §4.8, §4.11, §5, §11;
`stdlib/flow.cx` (packet A: the pure law returns `[law [transitions …]
[effect kind=:invoke step=…]]`); the packet-B agent's stop report (probes:
`[125c] NamedArg ::= Name '=' ProgramExpr` — labels are source-static;
`code.command_invoke_labeled` / `command_invoke_named` (`vcx/code/eval.v`) and
`command_pin_admit` / `command_pin_clear` are V-only, used solely by
`vcx/platform/coordination.v`; `cx:propose` binds a runtime record but only
`authz:commit` executes a proposal, behind a signed approval — the W3
`:principal` path, forbidden for automatic steps by §1 "no second approval
mechanism"; `[?eval]` is gated on the `eval` capability §5 forbids widening);
the stdlib module pattern (`sched.cx`, `journal.cx`: thin `[?def]`s over
`<module>-*` builtins dispatched in Ring 2).

## PB-1 — how the runner performs a step's act — RULED (a)

- **(a) RULED — ONE module-internal Ring-2 builtin, the flow's engine seam,
  re-homed from the saga runner:** `[$flow-perform $journal $command
  $do::element $opts::map]` in `vcx/platform/coordination.v`, dispatched as
  `flow_stdlib_builtin` and registered in `ring2_register.v` beside
  `authz-commit` (it needs the env-aware hook). It reads the command's
  `[requires-at]` pin (`code.command_pin_of`), runs the shipped admission
  read `coord_pin_check` against `$journal`, brackets `command_pin_admit` /
  `command_pin_clear` around ONE invocation, derives labels and values from
  `$do`'s child elements (element name = label, content = value; an EMPTY
  child is refused — a hole reached the runner), invokes through
  `code.command_invoke_labeled` — so `[effects]` narrowing, `[idempotent]`
  dedup, the admission and the PEP ride the SHIPPED path by construction —
  and answers the act's value or its `[err]`. `opts.compensate=true` invokes
  the command's `[compensates]` pairing instead (`command_compensator_name` +
  `command_invoke_named`), with the same fields; `opts` may carry nothing
  else. It is NOT a public module verb (no `[?def]` in `flow.cx` exposes
  it; `stdlib-catalog-gate` counts the dispatch as `flow`'s
  implementation). The resolver element's rows may carry the callable as a
  child — `[act name= resolved= compensates=? [fn $cmd]]` — which `validate`
  ignores and the impure verbs read. **DELETES:** nothing yet; packet D's
  saga retirement removes `coord_saga_run` / `coord_saga_status` (≈450 lines
  of V) against ≈80 this adds — the V surface shrinks net. **KEEPS:** every
  pure def of packet A untouched; the module pure CX except this one call;
  the stdlib module pattern (every module already rides `<name>-*`
  builtins). **Strongest counter:** "no new V builtins" was the wave's
  rule. **Answer:** the rule's own clause was "unless something is
  impossible in CX", and this is proven impossible twice over (source-static
  labels; the pin bracket has no CX surface); a general `cx:apply` would
  still not admit a pin, because admission is a journal-bound runner's act
  — and the flow IS that runner once the saga is retired.
- **(b) restrict W1 to unpinned commands and invoke through `cx:propose` +
  a runner-basis commit.** REFUSED: an approval artifact per automatic step
  is the second approval mechanism §1 and §4.6 forbid, and pinned steps
  become unwritable.
- **(c) a PUBLIC journal verb (`journal:perform`).** Rejected: a second
  public invocation surface beside the call form for one consumer; if a
  second runner ever exists it is a second vocabulary anyway (AD-5).
- **(d) ship `status` only; defer the impure verbs.** Rejected: strands the
  wave — `cx flow run` has nothing to call — and needs this same ruling a
  wave later.

## PB-2 — the run id preimage — RULED (a)

- **(a) RULED — §2.2 as written: the content address over (the flow
  document's Tier-1 address, the initiator — `opts.actor`, the ≥128-bit
  nonce).** Args are NOT in the preimage: two starts with the same args are
  two runs; the record carries the args. `opts.nonce` names the nonce
  (fixtures); else CSPRNG (`uuid:v4-bytes`). The packet brief's "document +
  args + nonce" was wrong; the spec is truth.

## PB-3 — the home stream default — RULED (a)

- **(a) RULED — the run id IS `flow:<address>` and the default home stream
  is the run id VERBATIM** (one token, never `flow:flow:…`); `opts.stream`
  places the run in its subject's aggregate stream. §4.11 and §3 are re-
  worded to say "the run id" where they said `flow:<run id>`.

## PB-4 — a deadline expiring with no ladder — RULED (a)

- **(a) RULED — the step transitions to `:failed` with `reason=:deadline`
  and the run takes §4.8's path** (pre-pivot: compensate; post-pivot:
  `:incomplete`). W3 adds the ladder (a rung pending defers the failure).
  §4.3 gains the sentence; §11 already fixtures it.

## PB-5 — the `[timer-fired …]` event shape — RULED (a)

- **(a) RULED — `[timer-fired run=<id> step=<name> at=<instant>]`**, the
  `sched` timer's `$ev`; the timer is named `flow:<id>:<step>` so `sched
  restore` re-arms it after a restart (§6). A `[timer-fired]` naming a step
  no longer `:running`/`:pending` is a no-op (the record decides — §4.2).

## PB-6 — one `advance`, one effect, and its outcome — RULED (a)

- **(a) RULED — the impure `advance` performs the ONE effect the law names
  and applies its outcome on the SAME call:** the act's answer becomes the
  correlated `[act run= step= status=:done|:failed [result …] [effect
  stream= seq= hash=]]` the law applies before the transitions are appended
  (one append under CAS carries the activation and the outcome). This is
  what makes `simulate ≡ advance` hold (§3) and what makes N racing
  advancers one effect (§4.5). §4.2 gains the sentence.

## PB-7 — `resumed=` on the record — RULED (a)

- **(a) RULED — `resumed=N` joins `incomplete=N` in §2.2's `[flow-run …]`
  attribute list**, set by the fold when a post-pivot tail is re-attempted.

## PB-8 — the conflict value's locator — RULED (a)

- **(a) RULED — `[conflict subject=<run id>/<step> kind=:uncompensatable
  policy=:manual-resolution [compensates stream= seq= hash=] [ours <the
  compensator's err>] [theirs <the step's recorded effect>]]`** — the
  `[compensates …]` child names the `:done` effect being reversed (the
  shipped runner's choice, kept), `[ours]` the compensator's failure,
  `[theirs]` the recorded effect the world now holds. §4.8 gains the shape.

## Edit map (this wave, ruling-gated; `RULED: 1265-PB-1` on the commit)

| Where | Edit |
|---|---|
| `flow.md` §2.2 | `resumed=` beside `incomplete=`; the run id preimage sentence stays; "home stream = the run id" |
| §3 `start`/`advance` | "`opts.stream`, default the run id"; `advance`'s one-effect-plus-outcome sentence |
| §4.2 | PB-6 sentence |
| §4.3 | PB-4 sentence (deadline with no ladder) |
| §4.8 | PB-8 conflict shape; `resumed=` |
| §4.11 | PB-3 wording |
| §6 `sched` row | the timer name and the `[timer-fired …]` shape (PB-5) |
| `vcx/platform/coordination.v`, `ring2_register.v`, `vcx/code/stdlib_dispatch.v` | PB-1's builtin |
