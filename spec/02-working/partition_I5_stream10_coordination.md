# I5 stream 10 — cross-stream coordination (implementation ledger)

**Branch** `impl/I5-stream10-coordination` off `design/651-516-partition`
(opened 2026-08-12 @ 59f9bb08, the stream-9 exit merge). **Governing
spec** `cross_stream_coordination.md` (letters 155–162 ruled (a)
2026-08-05). **Issue:** #682. **Posture:** the mechanism IS the
normative saga/escrow vocabulary — cross-stream atomic commit stays
REJECTED on the §1 derivation; nothing here fabricates a fourth
serialization point.

## Shipped-state map (evidence sweep 2026-08-12, at 59f9bb08)

SHIPPED (stream 6 + neighbors): the `[compensates NAME]` clause parses,
validates (unknown/non-command target refused), and registers
(def_parser.v L218–288 clause set; command_contract.v
command_compensates_check; cmd-006/007/008 fixtures) — the clause work
this stream was told would "ride the stream-6 grammar work" HAS RIDDEN;
`[effects]` checked-and-enforced (caps narrowed for the body's dynamic
extent); idempotency (explicit `idempotency-key=` + the derived
normalized-arg key; in-process IdemRecord registry; `[deduped …]`
wrapper); budgets end-to-end (authz [bounds] → pure-PEP snapshot meter →
CXER4713 → commit-point debit journaling `[authz-debited]` on the
`authz` stream; refunds-never-credit as arg validation);
propose/approve/commit (cx:propose value w/ dual addresses; Lane-2
approval; commit re-hash + tier verify + propose-only screening +
`command_commit_execute` version binding); sched durable timers
(`[sched-intent]` persistence + restore, CXER4970-89); the fabric DLQ
policy ({max-deliveries, dlq}, `[dead-letter]` envelopes, CXER4931);
the ONE `[conflict]` value shipped by stream 9 (shape + agreement law).
MISSING (this stream's work): `[requires-at]` (no parser arm, no eval,
no fixture; CXER4950 unregistered — the 4950–4969 band row lands with
the first code, per the invariant); ANY saga runner/record code (zero
hits); escrow allocations (zero reservation code in authz — normative
in spec only); `kind=:uncompensatable` emitted nowhere; the §6 corpus
program. Durable must-not-exist CAS dedup + retention-extended dedup
windows remain un-landed stream-6 residue — the v1 runner does NOT
need them: the JOURNALED SAGA RECORD is the durable step-dedup (a step
recorded :done never re-executes on resume — the erase-subject
precedent), which is exactly the §2 replay rule.

## Wave plan

- **W1 — the `[requires-at]` pin (the §2 M26 mechanism):** the clause
  (parser arm + DefNode + both registration sites + contract check:
  locator triple + seq, malformed refused); evaluation as a B3
  ADMISSION read at the command's commit point (the authz commit path
  + direct invocation): the target stream's head AT-OR-PAST seq AND
  the entry at seq hash-matching, else `CXER4950 E_COORD_PIN_STALE`;
  the pin rides the envelope for audit, NEVER a fold input. The
  governance §9.6 band row (4950–4969, registered before first use,
  dense + reserved tail). The corpus stale-pin negative + the
  satisfied-pin positive; the §5 refusal-retarget fixture pair
  (`:serializable` refused naming the stream-10 pattern / the same
  intent as reserve-then-confirm succeeding).
- **W2 — the saga record + the Ring-2 runner core (§2):** the
  ordinary-value saga record in its home stream (saga-id, steps[],
  per-step status, authority basis; Tier-1 address; Lane-2 approvals
  ride the stream-6 machinery unchanged); the runner
  (env-dispatched — steps invoke COMMANDS): run steps in order, journal
  per-step status transitions to the home stream, resume from the
  record (a step recorded :done never re-executes — the durable
  step-dedup), `[idempotent]` retry within a step; the replay rule
  pinned (participants fold their own entries only; the saga document
  = an order-independent reporting JOIN).
- **W3 — compensation flows (§2):** failure before the pivot
  compensates in REVERSE via the `[compensates]` pairing (compensation
  entries = `:assertion`s carrying the `[compensates stream= seq=
  hash=]` locator-triple link — never a fifth relation); the PIVOT
  (a step with no compensator marks it); failure after the pivot =
  forward-only idempotent retry w/ visible incomplete counts; a saga
  that cannot compensate yields the `[conflict … kind=:uncompensatable
  policy=:manual-resolution]` value (the stream-9 shape); timeout
  posture rides sched durable timers, poison rides the DLQ precedent
  (posture text + fixture); the erasure step-class stated (the
  apply-erasures machinery IS the forward-only reach — cross-ref, no
  new machinery).
- **W4 — escrow allocations (§3):** reserve/draw/expire on the authz
  meter model — an allocation lives in ONE stream and meters under its
  own commit lock; the global cap enforced at allocation time under
  the parent's lock; count/spend ONLY (rate meters locally,
  un-escrowed); expiry reclaims the RESERVATION (never replenishment);
  window attribution pinned at reservation time; reserved-first,
  shared-overflow, the denial naming the failing conjunct; expiry via
  sched durable timers. The escrow corpus pair.
- **W5 — hygiene + corpus completion:** the §7 edit map
  (commands_effects.md clause list + the allocations-normative bullet;
  consistency_vocabulary `:serializable` pointer text; bitemporal
  cross-ref; journal.md locator-triple note; xap.md §14.2 cross-ref;
  the docs-src saga sentence PROMOTED); the remaining §6 rows
  (replay-isolation family, compensation triple, idempotent-step pair,
  head-set completeness read + no-cut refusal, anti-2PC negatives —
  fold-reading-another-stream ⇒ CXER4611).
- **W6 — exit:** audit + full gate + #682 closure + merge.

Named landings (ruled, not deferrals): the full M5 corpus program =
stream 14 (§6); durable must-not-exist CAS + retention-extended dedup
windows = stream-6 residue consumed by nothing here (the saga record
is the durable dedup) — tracked on the stream-6 edit map, landing
named there.

## Wave record

- **W1 EXECUTED 2026-08-12 — the [requires-at] pin.** The clause
  ([152i]; attr-pair reader; all-three-mandatory refusal), CommandMeta
  carriage (outside Tier-2), the B3 admission read at the authz commit
  point (CXER4950 stale — no debit, no body), the fail-closed
  direct-invocation refusal (CXER4951 at invoke; the pin_admitted
  bracket wraps exactly the engine execute pass — leak-proof, pinned
  both sides of a successful commit), the 4950–4969 band row (before
  first use), coordination.v opened as the stream's platform home.
  Fixtures cmd-023/024 + authz-084 byte-exact; battery 2858; guide-check
  OK 46; strict registry RC=0. **Design decisions (inside ruled
  bounds):** ONE pin per def v1 (multi-pin additive later); the
  admission evaluates on the authz-commit path + (W2) the saga runner —
  the engine's rule is refuse-unless-admitted, since Ring 1 cannot read
  a journal. W1 gate next.
