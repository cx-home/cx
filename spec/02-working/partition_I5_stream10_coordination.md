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
- **W2 EXECUTED 2026-08-12 — the saga record + runner.** The
  ordinary-value record (home stream; last-record-wins state; the
  authority basis mandatory), the runner (real command invocations —
  effects/idempotent/pin admission all apply; command_invoke_labeled =
  the engine entry), the durable step-dedup (record-borne; completed
  sagas answer [deduped]; resume skips :done), one-pivot validation,
  the failed-step record. Fixture journal-139 (the M5 checkout)
  byte-exact; battery 2859; guide-check OK 46. **Gotcha:** a
  [compensates] target must be DEFINED BEFORE the command that names
  it (registration-time sibling check) — compensators first. W2 gate
  next.
- **W3 EXECUTED 2026-08-12 — compensation flows.** Reverse pre-pivot
  compensation via the [compensates] pairing (CommandMeta-resolved,
  full invoke path); forward-only post-pivot w/ visible incomplete= +
  tail-only resume; the :uncompensatable conflict (locator-triple link
  to the un-reversible :done transition + the failing err as [ours]);
  the fail-closed pre-pivot compensability check; terminal-state dedup.
  Two runner bugs fixed in-wave (invoke errors read as success; the
  scope-blind closure lookup). Fixtures journal-140/141 byte-exact;
  battery 2861; guide-check OK 46. W3 gate next.
- **W4 EXECUTED 2026-08-12 — escrow allocations.** allocate (parent
  debited at reservation under its lock; the deny names the conjunct;
  rate refused; window pinned at reservation) + allocation-expire
  (visible reclaim; never replenishment — fold synthesis: parent
  consumption = reserved-while-active, exactly-drawn-once-expired) +
  allocation draws on debit (one draw, one meter; the allocation's own
  conjuncts in denials). authz_collect_raw single walk +
  parent-visible synthesis; existing meter fixtures byte-stable.
  Fixture authz-085 byte-exact; battery 2862; guide-check OK 46.
  W4 gate next.
- **W5 EXECUTED 2026-08-12 — hygiene + corpus completion.** The
  :serializable retarget to the shipped pattern (journal-092 re-pinned);
  journal-142 (replay isolation + the anti-2PC negative) — which FOUND a
  real cross-ring defect: unclassified Ring-2 callees defaulted to pure,
  so the 2PC-shaped fold read DEADLOCKED on the pack jmu instead of
  refusing CXER4611; fixed via the new I3-seam purity registration
  (journal + store lists landed; #788 = the remaining packs + parity
  gate). Edit map executed: journal.md saga rows + locator note;
  commands_effects reservation bullet names the shipped verbs; xap
  §14.2 cross-ref; consistency/bitemporal verified. Battery 2863;
  guide-check OK 46; registry RC=0. W5 gate next; W6 = exit.
- **W5 gate record:** gates 1–3 `s10_w5_gate(.2/.3).log` RC=2 — the ONE
  failing lane every time = the fabric credited-transient-push read's 5s
  wall-clock deadline in the cache-free retry (green standalone at HEAD
  under exact flags every time; the same panic archived in the s8_w5 +
  s20_w1 gate logs — a marginal constant under full-gate load, not a
  product defect). **W5.1** = the targeted deadline fix (5s→30s on that
  one read; siblings untouched; content asserts unchanged). Gate 4
  `s10_w5_gate4.log` GATE-RC=0, PRE/POST HEAD = d5506677, 0 dirty
  (fabric/http = the #572 compile pair, both green on retries — the
  fabric retry now RUNS green).
- **W6 EXIT AUDIT — every §7 edit-map row disposed:** commands_effects
  (clause list W1; allocations/reservation bullet W5),
  consistency_vocabulary :serializable pointer (W5 retarget, re-pinned),
  bitemporal cross-ref (S3, verified), journal.md locator-triple note +
  saga verb rows (W5), governance §9.6 band rows (W1 4950–4969; the
  repair note verified), live_modes band (applied at ruling, verified),
  xap.md §14.2 vocabulary cross-ref (W5), stream-9 conflict-shape
  handoff (shipped by stream 9, adopted here — :uncompensatable emits
  the ONE shape), docs-src promotion (verified consistent). **Every §6
  corpus row has a shipped pin:** both-ways headline (journal-092 +
  authz-084), replay-isolation (journal-142 + 139), compensation triple
  (journal-140), idempotent-step (139/140 resumed=), escrow pair
  (authz-085; expiry-via-timer = the sched composition noted in the
  fn-doc), stale-pin negative (authz-084; CXER1114-as-value =
  journal-042, row 15), budget-boundary under allocations (authz-085
  denials), head-set completeness read (saga-status + stream 7's
  machinery), [conflict] shape (141, shared), anti-2PC negatives
  (journal-142: fold-reads-another-stream ⇒ CXER4611; no verb spans a
  commit — by construction, §1). The full M5 corpus program = stream 14
  (named landing). Adjacent filed: #788 (the Ring-2 purity-registration
  completeness sweep + parity gate). Exit gate next.
