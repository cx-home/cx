# Commands and effects (stream 6)

**Status:** Approved (G3 graduation, owner ruling exit-1a, 2026-08-14; stream 6, issue #678). Implements L9a: effect
proposals as an OPT-IN evaluation mode at trust boundaries; direct effects
stay the default. Carries the ruled mandates: idempotency semantics on
command defs (keys, dedup window, retry); budget/metering attenuation
(rate/count/spend — semantics here, wire carriage with stream 4); the
`cap:` payload/resolution semantics (stream 13 L56 handoff); the D-C1
coherence rule (quantitative bounds × coarse spatial scope). Normative
once approved.

**Worked example (M5):** `refund-order` — declared `[requires]`/
`[preconditions]`/`[effects]`/`[idempotent]`; an agent holding a
propose-only, budget-bounded sub-delegation proposes a $42 refund; a
principal approves the proposal's ADDRESS with a signed Lane-2 claim;
commit re-checks preconditions, debits the spend meter under the stream's
commit lock, dedups by key, and the journal records actor + authority
chain. The campaign's own narrative arc — "you've hand-approved 30
sub-$50 refunds — auto them?" — is the propose-mode → budget-bounded-
delegation bridge, tying streams 4/6/18 and authz together.

## §1. Findings

1. **No command surface exists** — `[requires]`/`[preconditions]`/
   `[effects]` appear nowhere outside the ruling. The hosts are ready:
   `[152a] DefModifier` is a closed alternation with the `[returns]`/
   `[throws]` clause precedent; authz's `[capability NAME [reads …]
   [emits …]]` already occupies the contract space a command projects
   onto.
2. **Nothing quantitative exists in either capability system:** every
   caps scoping column is spatial; the authz attenuable triple is
   capabilities/slice/window. A budget is a FOURTH attenuation
   dimension — and the only one needing state (a meter).
3. **The purity collision:** authz `check` is normatively PURE over a
   materialized snapshot (what makes dry-run regression-gateable); a
   live meter read would break it. The resolution: the meter is a fold
   over the journal, supplied through the existing `with-context`
   snapshot — purity preserved.
4. **Idempotency prior art is four mechanisms, none sufficient:** CAS
   (conflict, not dedup); store content dedup (with the `stored=false`
   observable); content-hash-keyed snapshot capture; idempotent closes
   returning the absence channel. No idempotency-key pattern exists
   anywhere; fabric has permanently ruled OUT exactly-once.
5. **Propose-shaped flows exist in fragments:** xap `emit dry-run`
   (cascade preview, no proposal value/identity); authz
   dry-run/explain (the pure decision half); adjudicate (agent
   proposes as data, deterministic engine disposes); guardian grants
   (pinned unexecuted `[action …]`). Propose mode is their
   unification, not a new invention.

## §2. The command surface (L109, L110)

- `[152a]` gains `RequiresClause | PreconditionsClause | EffectsClause
  | IdempotentClause | CompensatesClause | RequiresAtClause`. **A command def IS a `[?def]`
  with an `[effects]` clause — that clause is THE normative
  discriminator** (what stream 18 enumerates for tool projection). A
  `[?command]` directive is rejected (registry churn, duplicated
  machinery, contradicts the ruled additive-clauses framing).
  **(`CompensatesClause` ADDED 2026-08-05, audit M27 — stream 10's
  spec-edit map named this edit and it was never executed, unlike
  L139's identical-shape edit: `[compensates NAME]` pairs a command
  with its compensating command, statically checkable, projected into
  stream 18's tool metadata. Tier-2 participation: EXCLUDED — the
  clause falls under the canonical-wart sweep's closed
  participating-field list with excluded-by-default, exactly as
  pre-answered there; pairing is deployment/coordination metadata, not
  call-contract meaning.)** **(`RequiresAtClause` shipped at I5 stream
  10 W1 — `[requires-at stream=… seq=… hash=…]`, the cross-stream
  precondition PIN of `cross_stream_coordination.md` §2: a B3 admission
  read at the commit point (target head at-or-past `seq`, entry at
  `seq` hash-matching, else `CXER4950 E_COORD_PIN_STALE`); Ring 1
  holds no journal, so a pinned command invoked outside a journal-bound
  commit refuses `CXER4951 E_COORD_PIN_UNEVALUATED` fail-closed —
  never a silent skip. Tier-2 participation: EXCLUDED, exactly as
  every command clause.)**
- `pure` + non-empty `[effects]` is a **static contradiction** (typed
  error) by the effect-totality theorem.
- **`[effects]` is CHECKED AND ENFORCED, never advisory** (L110): the
  declared set is verified against the normative closed effect-point
  table (stream 22's EV-EFFECT-SET move into security.md is the hard
  dependency — a clause checkable only against a V file violates the
  clean-room bar), and it acts as a narrowing at runtime
  (`[?with-caps]`-like): an effect point outside the declaration is a
  loud typed error. "Effect conformance is enforced; type conformance
  is advisory" is the house sentence; an advisory `[effects]` would be
  its most quotable contradiction.

## §3. Idempotency (L111)

- **Key:** an explicit caller key wins when present (only the caller
  knows two structurally-identical requests are distinct business
  events — the `[?rate-limit] name=` precedent); the derived default is
  `hash(command Tier-2 address, normalized arg record, tenant)` where
  the arg record is a MAP KEYED BY PARAMETER NAME after defaulting —
  never the raw call expression (positional vs named spelling of the
  same refund must not double-execute; the sharpest trap in the
  stream). Dropped from the key, stated: the cap-set (the same refund
  under a widened grant is the same refund) and the authority basis
  (recorded, not keyed).
- **Commit:** must-not-exist CAS (`expect=""`) on the dedup record —
  the E3-unified primitive, exactly-once-create at the effect boundary.
- **Dedup hit returns a PRESENT value** carrying the original outcome
  plus a `deduped=true` marker — "already done, here's what happened"
  is not the absence channel.
- **Window:** journal-backed; the retention cover rule EXTENDS — a
  dedup record may not be compacted away before its declared window
  expires (compaction reopening the double-execution window is the
  papering-over D-C1 warns against). Dedup records are fold-visible
  facts (replay-stable, stream 21's seam).
- **Disposition is opt-in:** an undeclared command is NOT idempotent
  and retry-unsafe (deny-by-default); `[idempotent]` is the
  precondition that makes `[?retry]` safe around a command. Explicitly
  positioned as effect-boundary dedup — fabric's at-least-once +
  no-exactly-once ruling stands untouched.

## §4. Budgets (L112)

- **Shape:** `[bounds [rate N :per DUR] [count N] [spend
  AMOUNT::decimal :currency :CUR :per DUR]]` on the **delegation**
  (the authz value — attenuation, revocation, journaling, explain, and
  T1/T2 signing for free). A caps-manifest counterpart for non-XAP CX
  is named additive, not built now.
- **Enforcement:** the debit happens at the **commit point** (journal
  append, under the stream's commit lock — linearizable for free); the
  PEP reads the meter as part of the **materialized snapshot**
  (`with-context` — a fold over the journal), so `check` STAYS PURE
  and dry-run stays regression-gateable. Budgets are **scoped to a
  single stream at v1** (a cross-stream meter has no serialization
  point — that is stream 10's gap, cross-bound not papered over).
- **Exhaustion is a VALUE at the PEP:** `[deny [reason
  :budget-exhausted] [retry-after DUR]]` (raised only under
  `raise-on-deny`); `CXER4713` allocated in the authz band.
- **Semantics:** `rate` = token bucket (the `[?rate-limit]` semantics
  verbatim); `count` = monotone, no replenishment; `spend` windows are
  **UTC-Z calendar-aligned** (ruling-20 consistency; no tenant-local
  midnight surprise unstated); **refunds do NOT credit back — budgets
  meter authority exercised, not net economic effect.**
- **Composition:** sub-delegation SHARES the issuer's meter by default
  (a pool never multiplies authority). **Reservation is a named
  additive extension — NORMATIVE (promoted 2026-08-05, audit M27:
  stream 10's escrow allocations build on this sentence, which was
  previously parenthetical): a sub-delegation MAY carry a reserved
  allocation drawn from the parent meter at delegation time, under the
  parent's lock; semantics per stream 10's escrow rules (count/spend
  only; expiry reclaims the reservation without replenishing spent
  budget; window attribution at reservation time; reserved-first,
  shared-overflow precedence).** SHIPPED at I5 stream 10:
  `[$authz:allocate]` (reservation-time parent debit under the parent's
  lock; the deny names the conjunct; rate refused as un-escrowable) +
  allocation draws on `debit {allocation:}` (one draw, one meter) +
  `[$authz:allocation-expire]` (visible reclaim, never replenishment) —
  pin `authz-085`. Envelope intersection = min; **D-C1 discharged:** spatial
  scope and quantitative bound are independent conjuncts — a bound
  never widens scope, a scope never relaxes a bound, denial names the
  failing conjunct, finer per-URL scope is additive and renegotiates
  nothing.
- **Durability prerequisite named:** the authority store must persist
  across restarts before any budget is real (#713) — a meter that
  resets on restart is not a budget.

## §5. Propose mode (L113)

- **The proposal is a CX value** with a Tier-1 address: the command's
  **dual fn address — Tier-1 of the definition text as the TRUST key,
  Tier-2 `code:` riding for cache/equivalence** (AMENDED under stream
  18's L139: Tier-2 is never a trust input, and the S0-ruled Tier-2
  field set leaves `[effects]` out of the hash, so only the Tier-1
  source address prevents an approval replaying against a command whose
  declared effects were widened; the bind-the-exact-version intent
  stands, now correctly keyed), the
  normalized arg record, the RESOLVED effect set (concrete resources —
  distinguished from the def's declared contract), the evaluated
  preconditions, the authority basis (`[via …]` chain), and the
  idempotency key. The arg record is **name-keyed over the whole
  parameter list** (positional and named params alike bind by name;
  defaults fill; an unknown key refuses loud) — the record is the
  proposal's own binding surface, distinct from the general call
  surface's positional binding, and it is exactly what an agent-tool
  `arguments` object carries (stream 18). E1's quoted-tree substrate applies; the I1
  quote-lowering and `*`-head fixes are named dependencies.
- **Approval = a signed Lane-2 claim binding the ADDRESS** — suite slot
  mandatory, verifiers fail closed, T2 M-of-N for two-person rules.
  Approval-by-name-or-args is normatively forbidden (forgeable); a
  re-lowering with a different address is a different proposal.
- **Preconditions re-evaluate at commit; divergence is a loud refusal**
  (the two-times enforcement table precedent: some facts bind at
  propose, live facts re-check at commit).
- **The BOUNDARY decides the mode** (the truest reading of "propose
  mode at trust boundaries"): an MCP/agent-tool edge always proposes;
  additionally, **propose-only is a new grant-side attenuation flag**
  (a delegation that can propose but never commit) — a genuinely
  useful dimension beside budgets.
- **One mechanism:** propose mode IS `emit dry-run` generalized — the
  dry-run spec text is amended to produce the proposal value; there is
  no second preview machinery.
- **Determinism obligation:** propose-predicts-commit is a numbered
  EV rule discharged by a discriminator pair over the `out-effects`
  channel (stream 22's corpus machinery).

## §6. `cap:` payload and resolution (L114)

`cap:sha2-256:<hex>` addresses **any authority-artifact value** —
`[capability …]`, `[delegation …]`, the C4 grant-set document — all
ordinary CX values with Tier-1 addresses; the prefix is the domain
separator for trust inputs (the `code:` precedent). Resolution: the
content store is the substrate; the authority store is the live
registry view (a `cap:` reference in a proposal or a `[requires]`
clause resolves fail-closed). Registered in governance §12.3. The
colliding `cap:resource` grant-spec token in the caps CLI syntax is
renamed (#713) — one spelling, one meaning.

## §7. Corpus handoff (stream 14; M5 substrate)

`refund-order` end-to-end: propose → approve (address-bound; a
tampered-args replay negative) → commit (precondition-divergence
refusal; dedup-hit present-value; double-spend across the budget
boundary denied with the failing conjunct named); positional-vs-named
arg spelling ⇒ ONE idempotency key (the anti-double-refund pair);
budget composition fixtures (sub-delegation shares the meter; envelope
min); `pure`+`[effects]` static-contradiction negative; effect outside
the declaration ⇒ loud error; propose-predicts-commit discriminator
pair over `out-effects`.

## §7.5 The err-at-boundary rule (RULED: CO-2)

An `[err]` element is a first-class VALUE inside a program: collection
literals carry it as a member (measured cells, confirmed by CO-2 — no cell
of the path/value matrix moved), channels transit it (the supervise
`([sup-note …], $err)` pair is load-bearing), bindings hold it, matching
inspects it, pure functions serialize it (rendering an error to log it is
legitimate). The rule is about **leaving**: an externalizing effect refuses
to carry a document containing an `[err]` at any depth out of the program
silently.

- **Guarded families**: store document writes (`put-doc`, `put-doc-stream`,
  `put-doc-text` — which stores a *parsed* document — and `modify-doc`,
  whose action payload is the injection vehicle) and http response emission
  (a handler result, whether a `[response]` envelope, a bare document, or a
  bare `[err]` — the bare-err-as-200 shape is exactly the silent class).
- **The refusal**: `cx-err:CXER0275 E_ERR_AT_BOUNDARY`, naming the first
  contained err's code and its path. On the http family the refusal is a
  loud 500; framework-built error wires do not pass through the guard and
  stay as they are.
- **The permission**: `errs=:permit` on the effect form — ONE spelling
  everywhere: the optional trailing opts map on the store verbs
  (`[$store:put-doc $s $doc {errs: :permit}]`), the attribute on
  `[response]` / `[sse-subscribe]`. Externalizing a refusal is legal; it is
  never accidental.
- **Exempt by construction**: blob and string/bytes writes (bytes carry no
  `[err]` to find; serializing a document to text is a pure act, not a
  refusal point), channels, bindings, matching, formatting, and the
  run-surface print (it is how errors are inspected; a top-level err
  already exits nonzero). The originally-ruled "[out …]" family resolved
  to no effect on the current surface (there is no `[out]` effect form);
  recorded here so the ruling's scope stays honest.

This closes the class where a generator reports success while its output
carries refusals as data (`written=0 errors=25`, exit 0) and where a web
client renders `[err]` into HTML — at the only honest place, the boundary.

## §8. Rulings ledger — RULED

Letters 109–114 **ruled (a) 2026-08-05 under the standing acceptance
ruling**: clause-children on `[?def]`, `[effects]` as THE discriminator,
`[?command]` rejected (109); `[effects]` checked-and-enforced, never
advisory (110); explicit-key-wins + normalized-arg-record derived key,
must-not-exist CAS, present-value dedup hits, retention-extended
windows, opt-in disposition (111); delegation-borne `[bounds]`,
commit-point debit + pure-PEP snapshot meter, per-stream v1,
value-shaped exhaustion, UTC-Z windows, no refund credits, shared-meter
attenuation, D-C1 conjuncts (112); address-bound Lane-2 approvals,
commit re-checks, boundary-decides + propose-only grants, dry-run
unified (113); `cap:` = any authority artifact, fail-closed resolution,
grant-token rename (114). Recorded in the campaign decision log.
Spec-edit map: grammar [152a] + code.md §12.2, security.md §2 (effect
table + enforcement note), authz.md (`[bounds]`, CXER4713, meter-as-
fold — LANDED at I5 stream-4 W4: §2.2 bounds child, §4.2 four-axis
issue-time pin, §8 CXER4713 row), xap.md §3.4 (dry-run → proposal),
journal.md (dedup records + retention extension), governance §12.3
(cap: row), stream-4 handoff (wire carriage of bounds + VC chain
fourth dimension — DISCHARGED, store profile §6.1), stream-18
handoff (the discriminator + proposal schema).
