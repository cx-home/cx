# I5 stream 6 — commands and effects: implementation ledger

**Status:** OPEN (started 2026-08-11; order-of-march item 5 continuation,
stream #678 per the stream-5 exit handoff).
Branch `impl/I5-stream6-effects` off `design/651-516-partition`
(cut at b0b03bd5 — the stream-5 exit-merge).
Governing spec: `commands_effects.md` — letters **L109–L114 inside the S2
batch RULED (a) 2026-08-05 (letters 93–121)**, PLUS the S3-wave amendment
**L139 (stream 18): approvals bind the Tier-1 def-text address; Tier-2
rides for cache/equivalence only** (Tier-2 never a trust input +
`[effects]` outside the Tier-2 hash made a Tier-2 binding a replay hole).
RULED-token anchors = the S2 exit row in `partition_campaign_PLAN.md`
(decision log 2026-08-05, "WAVE S2 EXITED — letters 93–121 ruled (a)"),
stream-6 fragment: "clause-children on [?def], `[effects]` = THE command
discriminator, CHECKED-AND-ENFORCED never advisory; idempotency =
explicit-key-wins + normalized-arg-record derived key (the
anti-double-refund trap), must-not-exist CAS, present-value dedup hits,
retention-extended windows; budgets = [bounds] on the DELEGATION,
commit-point debit + pure-PEP snapshot meter, per-stream v1 (cross-stream
= stream 10), value-shaped exhaustion CXER4713, refunds never credit,
shared-meter attenuation, D-C1 discharged as independent conjuncts;
propose mode = address-bound Lane-2 approvals + commit re-checks +
boundary-decides + propose-only grants + dry-run unified; cap: = any
authority artifact, fail-closed"; and the S3 exit row, fragment:
"stream 18's L139 AMENDS stream 6's finalized text — approvals bind the
Tier-1 def-text address, Tier-2 rides for cache only".
Issues: #678 (stream); #713 item 4 (authority-store durability) LANDS
HERE (items 1+2 closed at the W8 boundary, items 3+5 closed at
stream 5); M27 audit additions already IN the ruled spec text
(`CompensatesClause`; reservation promoted normative).

**Epoch posture:** I1 IS CLOSED; this stream is POST-EPOCH and additive
on the identity plane: new `[152a]` clause-children are new SOURCE TEXT
(any def carrying one is a NEW definition with a new Tier-1 address —
no existing address moves); the S0 Tier-2 field ruling keeps `[effects]`
et al. OUT of the Tier-2 hash (already the ruled state, nothing to
migrate); dedup records / proposals / meters are new artifacts. No
hash-affecting change to any existing artifact is in scope.

## Standing constraints

- Spec-first; NO spec edits without a recorded ruling (RULED: tokens on
  spec+impl commits; fragments must grep in `partition_*.md`). The §8
  spec-edit map of `commands_effects.md` IS ruled — each executed edit
  cites its letter: grammar `[152a]` + code.md §12.2; security.md §2
  (effect table + enforcement note — the EV-EFFECT-SET move); authz.md
  (LANDED at I5 stream-4 W4 — verify only); xap.md §3.4 (dry-run →
  proposal); journal.md (dedup records + retention extension);
  governance §12.3 (cap: row — NEW reserved-reference-prefix
  subsection); stream-18 handoff (discriminator + proposal schema).
- Every wave ends green on the full gate — launched UNPIPED, full log,
  `GATE-RC=$?` propagated, verdict read FROM the log.
- Fixtures ride WITH their machinery wave, never after; fixture-first
  for every defect-shaped change.
- Cutover-first, no dual-accept; never true a spec to a shortfall.
- Fable 5 only; push per landing; exit-merge IS an exit step.
- Triage gate flakes by standalone re-runs BEFORE suspecting the stream
  diff (#778 fabric liveness, #779 rotation-vs-fold load-sensitive; the
  two known usecache artifacts green on #572 retries).
- Stream-5 gotchas in force: put-doc takes a VALUE / def source blobs
  read via store_get_blob_local; governance §9.6 rows parse EVERY
  numeric token as a range claim (one range token per row); bareword
  def calls in let-binding positions construct elements — use `[$name]`
  in fixtures; rebuild (make build-vcx) before blaming umbrella lanes;
  no apostrophes in fixture note lines.
- G3 graduation of `commands_effects.md` is OWNER-GATED — item-6
  handoff packet, never attempted here. The working spec stays in
  `02-working/`; normative cross-edits into approved specs execute per
  the ruled §8 map.

## Pre-open recon verdicts (2026-08-11, probed live this session)

1. **The command surface is GREENFIELD — nothing to reconcile.**
   Grammar `[152a] DefModifier ::= ScopeAttr` + the §12 pure/impure
   barewords (grammar.ebnf:1647-1654, :1845-1847); no
   Requires/Preconditions/Effects/Idempotent/Compensates clause exists
   in grammar, code.md, or vcx. No `[?command]` anywhere (the L109
   rejection needs no retirement sweep). The `[returns]`/`[throws]`
   clause precedent cited by the ruling is the authoring template.
2. **The EV-EFFECT-SET hard dependency is NOT yet executed — it lands
   in W2 here.** `clean_room_implementability.md` (stream 22, ruled)
   names the move: "the gated-primitive table moves into security.md §2
   as a normative closed table; `effect_alignment.v` becomes a
   conformance check AGAINST the spec table." Today security.md §2 has
   the capability LIST but no effect-point table;
   vcx/code/effect_alignment.v holds the closed cap-gated-prim map +
   the impure-without-cap exception table with two-direction drift
   gates (make check-effect-alignment). L110 (`[effects]` checked
   against the NORMATIVE table) is unenforceable until the move
   executes — W2 sequences it FIRST.
3. **Budgets: the pure decision layer is DONE (stream-4 W4); the
   effect-surface half is ABSENT.** stdlib_authz.v has `[bounds …]`
   parsing/validation (:634-782, unknown conjunct = unissuable
   CXER4711), ⊆ attenuation vs nearest bounds-bearing ancestor (:1016+),
   the pure PEP reading meters from opts `{meters: [meter id=… …]}`
   (:1615-1672 — absent reading = fresh meter), CXER4713 value-shaped
   deny w/ retry-after (:82). NOT present: any meter STATE (the fold
   over the journal), any commit-point debit, any with-context
   snapshot supply. The comment at :184-185 pins the seam verbatim:
   "commit-point debit is the effect surface's job" — this stream's W4.
4. **The authority store is in-process only — #713 item 4 confirmed
   live.** authz.md ~:697-704: trust state does NOT survive restart;
   persisted-grant-then-reopen deferred; CXER4710 store-fault code
   allocated but the durable backend unbuilt. W3 lands durability
   BEFORE W4 budgets (L112: a meter that resets on restart is not a
   budget).
5. **Idempotency is GREENFIELD.** No key surface, no dedup records, no
   retention-cover extension in journal.md (retention covers exist for
   snapshots/materializations — the dedup-record extension is a new
   clause per the ruled map). The must-not-exist CAS primitive EXISTS
   (E3-unified `expect=""` — stream-1 landing), ready to be the commit
   primitive.
6. **Propose mode substrate:** no `dry` surface currently in xap.md
   (the §8 map's "xap.md §3.4 dry-run → proposal" edit will author the
   unified surface where emit preview semantics live); adjudicate +
   authz explain/dry-run (pure decision half) shipped; stream-18
   `agent_tool_projection.md` is ruled and holds the descriptor seam
   awaiting the discriminator + proposal schema handoff. E1 quoted-tree
   substrate + I1 quote-lowering + `*`-head fixes: LANDED (stream 1
   exited full scope) — the named dependencies are satisfied.
7. **cap: namespace:** the colliding `cap:resource` grant-spec token is
   ALREADY renamed (#713 item 2, closed at the W8 boundary — L114
   `cap=resource` spelling). Governance §12 has 12.1 (directive names)
   + 12.2 (file extensions); §12.3 (reserved reference prefixes) does
   not exist — this stream authors it with rows for the shipped
   `code:` / `computes-as:` prefixes and the new `cap:` row.
8. **Stream-5 inheritance verified on this branch:** `[$caps]` C4
   value + allow_all normalization (L104), computation/<addr> admission
   posture w/ CXER1117-1119, `[$cx:computation-id]` = the Tier-2
   `computes-as:` claim (the proposal's cache-riding fn slot), Tier-1
   addressing via `[$cx:hash]` (the proposal's TRUST key per L139).

## Wave plan

- **W1** — ledger + recon (this entry).
- **W2** — the command surface: `[152a]` clause-children + parse +
  validation; `pure` × non-empty `[effects]` static contradiction;
  EV-EFFECT-SET move (security.md §2 normative closed table FIRST,
  effect_alignment.v re-pointed as conformance check); `[effects]`
  declaration checked against the table + runtime narrowing (effect
  point outside declaration = loud typed error). Fixture-first.
- **W3** — authority-store durability (#713 item 4): journal/store-
  backed trust state, persisted-grant-then-reopen, CXER4710 live.
- **W4** — budgets: commit-point debit under the stream's commit lock;
  meter = fold over the journal; with-context snapshot supply to the
  (already-pure) PEP; UTC-Z spend windows; shared-meter + reservation
  composition; exhaustion value end-to-end.
- **W5** — idempotency: explicit-key-wins + derived key
  (hash(Tier-2 addr, normalized arg record BY PARAM NAME after
  defaulting, tenant)); must-not-exist CAS commit; present-value dedup
  hit w/ deduped=true; journal.md dedup records + retention cover
  extension; `[idempotent]` gates `[?retry]` safety.
- **W6** — propose mode: the proposal value (Tier-1 trust key + Tier-2
  riding + resolved effects + evaluated preconditions + authority basis
  + idempotency key); address-bound Lane-2 approvals; commit re-check
  w/ loud divergence refusal; boundary-decides + propose-only grant
  flag; dry-run unification (xap.md edit); cap: fail-closed resolution;
  governance §12.3.
- **W7** — M5 `refund-order` corpus end-to-end (§7 handoff list in
  full); exit audit vs the §8 map; exit entry; exit-merge; #678 close
  + #713 item 4 evidence.

## Wave entries

### W1 — pre-open recon + ledger (2026-08-11)

Recon verdicts 1–8 above, probed live on b0b03bd5. Sequencing decision
recorded: W2 executes the EV-EFFECT-SET spec move BEFORE any checker
work (a clause checkable only against a V file violates the clean-room
bar — the table must be normative first); W3 (durability) precedes W4
(budgets) per L112's named prerequisite. No blockers found; the three
named cross-stream dependencies (E1/I1 fixes, [bounds] decision layer,
CAS primitive) are all verified landed.

### W2 — the command surface (2026-08-11)

**W2-entry rulings (each grounded in the ruled text + shipped
precedent; detail decisions inside the L109/L110 scope):**

- **R1 (clause payload shapes).**
  `EffectsClause ::= '[effects' (S EffectItem)* ']'` with
  `EffectItem ::= '[' CapName (S ScopeLiteral)* ']'` — the cx.pkg
  §12.4.3 capability-manifest shape verbatim (`[net
  api.example.com:443]`), the ruling's own citation for the contract
  space a command projects onto; CapName from the closed security.md
  §2 nine-name list; scope literals = the C4 canonical scope strings,
  CARRIED at v1 (the C1-coarse + stdlib_caps v1 posture: boolean gate,
  scopes carried — same honesty note as the shipped grant surface).
  Zero-item `[effects]` is legal (the discriminator with an empty
  gated-effect set — the only form compatible with `pure`).
  `RequiresClause ::= '[requires' (S Requirement)+ ']'` (each a
  `cap:` address string or capability bareword; RESOLUTION is W6's
  L114 fail-closed machinery). `PreconditionsClause ::=
  '[preconditions' (S ProgramExpr)+ ']'` — predicates captured
  verbatim (the PathPredicate.source convention); evaluated at
  propose / re-checked at commit (W6). `IdempotentClause ::=
  '[idempotent' (S '[window' S Duration ']')? ']'` (window optional;
  key semantics are W5). `CompensatesClause ::= '[compensates' S
  Name ']'`. At most ONE of each clause per def — a repeat is a parse
  error. Clauses are `[?def]`-only (the ruled clause-children framing;
  `[?fn]` never takes them).
- **R2 (error codes).** Static command-contract violations =
  **`CXER0239 E_COMMAND_CONTRACT`** — the LAST free slot of the
  purity/predicate band CXER0230–0239, the exactly-right home (the
  band owns §12.2 purity/predicate statics; the pure×`[effects]`
  contradiction IS the effect-totality theorem's static face). Covers:
  `pure` + non-empty `[effects]`; `[compensates]` naming an unknown
  def or a non-command. An unknown capability NAME inside `[effects]`
  = **`CXER0274 E_CAP_UNKNOWN`** extended — one code for "unknown
  capability token, fail closed" wherever a cap name is spelled
  (host grant spec/list, now the `[effects]` declaration) — the
  #713/L114 posture verbatim. Runtime narrowing denial =
  **`CXER0271 E_CAP_DENIED`** (the ruled "[?with-caps]-like" reading:
  an effect point outside the declaration IS a capability denial at
  the effect point; the denial message names the `[effects]`
  narrowing). No new band; no governance registry edit (core-band
  sub-allocation is code.md §9.4's own table).
- **R3 (enforcement points).** The declaration-level contract check
  is ONE shared authority (`module code`) called from BOTH def
  registration sites — program-level `eval_def` and the module
  loader's `ensure_module_scope` — never two spellings (cap-name
  validity needs `capability_names()`, which lives in `code`, so the
  check sits above the `cx` parser layer by construction). Runtime
  narrowing hooks the single closure choke point `invoke_closure_l`
  AFTER the partial/builtin delegations (both def paths —
  `bind_specs_and_eval` and `invoke_positional_l` — flow through it);
  `has_effects=false` costs nothing on the hot path. Narrowing
  installs KEEP-ONLY(declared caps) over the active set — strictly a
  narrowing (grant ∩ declaration), never a widening; the
  private-range policy field clears (interior set, the L104 rule).
- **R4 (what W2 does NOT decide).** Whether a DIRECT call (default
  mode) evaluates `[preconditions]` is a named W6-entry decision —
  the ruled text speaks only of propose-time evaluation + commit-time
  re-check; W2 parses, validates shape, and carries the clause.
  `[requires]` resolution (fail-closed `cap:` lookup) is W6 (L114).
  Idempotency key/dedup semantics are W5 (L111). The clauses'
  LOAD-TIME consumers land here in full: static validation, the
  command discriminator, Tier-2 exclusion (S0: every new clause is
  outside the Tier-2 hash by the excluded-by-default closed list —
  fixture-pinned), and the `[effects]` runtime narrowing.

**Spec edits executed (per the ruled §8 map, letters cited inline):**
security.md §2 gains the normative closed effect-point table (the
EV-EFFECT-SET move — stream 22's ruled relocation; the source-of-truth
inversion: `effect_alignment.v` becomes a conformance MIRROR checked
against the spec table by the extended `check-effect-alignment` gate)
+ the L110 enforcement note; grammar.ebnf [152a] alternation + [152d–h]
clause productions (L109); code.md §12.2.7 command-clause subsection +
§9.4/§9.5 CXER0239 rows + the CXER0274 description extension (L109/
L110/C2).

**R5 (recorded at landing).** A non-empty `[effects]` on an
UNANNOTATED def implies `impure` (declaring effects IS declaring
impurity — a redundant `impure` bareword would be ceremony); the
CXER0239 contradiction fires on EXPLICIT `pure` only. Compatible with
the ruled sentence (explicit pure + effects IS the contradiction;
the default can never reach it). `purity_explicit` added to DefNode
to carry the distinction; code.md §12.2.7 states the implication
normatively.

**W2 CLOSED 2026-08-11 — full gate GATE-RC=0 (s6_w2_gate3.log).**
Landed: def_node/def_parser five-clause surface (dup-clause parse
errors; scope/requirement tokens as quoted-or-bare runs; preconditions
verbatim via balanced-bracket capture); `command_contract.v` = the ONE
authority (R3) called from eval_def + ensure_module_scope (unknown cap
→ 0274; explicit-pure×effects → 0239; compensates pairing — module
order-independent via mod.defs, script sequential); Closure gains
has_effects/effects_caps; `caps_push_effects_narrowed` (keep-only ∩,
policy field cleared) hooked at invoke_closure_l behind the
has_effects branch (zero hot-path cost); effect_alignment.v gains
io-watch/io-watch-next (the drift-canary hole: self-gating prims were
outside BOTH directions); the spec↔impl parity gate
(test_effect_point_table_matches_spec) parses security.md §2.1 and
asserts BOTH directions. Fixtures cmd-001..012 green (the key
discriminator cmd-002: read+random GRANTED, only [effects [read]]
declared ⇒ CXER0271 from the narrowing — the runner now honors
Effort-B grant= on code.cxd, without which the case would run empty
and green for the wrong denial). Gate deltas triaged: cxparse
differential = deliberate corpus growth (748/583→759/594, divergence
classes unchanged — baseline updated with note); profile_gate[embed]
= io pack off ⇒ cmd-001/007 re-authored onto profile-invariant
path:canonical (path is not a pack; same declared read effect);
fabric+http = the known usecache artifacts, green on in-gate #572
retries. Evidence: s6_w2_gate.log (first, RC=2 triaged),
s6_w2_gate2.log (profile delta), s6_w2_gate3.log (GATE-RC=0);
lane logs in the session scratchpad.
**Observed in passing (not this stream's scope, filed to the
tracker):** the module loader's ensure_module_scope does not set
declared_impure on module-def closures — a module-defined impure
validator would pass the validate-with= declaration gate
(validate.md R3.12) that program-level defs fail. See issue filed at
W2 close (#780).

### W3 — authority-store durability, #713 item 4 (2026-08-11)

**Authority to land here:** #713 item 4 is RULED text ("Durability
lands before or with the budget implementation at I5") + the L112
prerequisite sentence in the ruled spec ("the authority store must
persist across restarts before any budget is real — a meter that
resets on restart is not a budget"). The authz.md §5 implementation-
tier note names exactly this as the deferred pair (restart survival +
caps routing); this wave discharges it along the spec's own §2.6/§3.1
contract — no new spec surface is invented.

**W3-entry rulings:**

- **R6 (durable backing = the tenant journal, per the shipped
  §2.6/§3.1 contract).** `store opts.journal` (already spec'd: "the
  `[$journal:…]` handle grants/decisions are appended to") binds a
  journal handle to the authority store. The persisting verbs
  (delegate / revoke / grant-guardian) append attributed events per
  §2.6 — actor = the issuer's id, authority = the issuance basis (the
  `[attenuates …]` parent id, or `principal` for a principal-rooted
  grant); the journal's OWN backing store provides durability,
  group-commit, the hash chain, and capability gating (its effect
  points charge scheme-derived caps — authz introduces no new
  capability, the §5 restatement, now transitively REAL). Reopen =
  REPLAY: `store {tenant, journal}` folds the journal's authz stream
  to rebuild the delegation set — the persisted-grant-then-reopen
  path. No journal bound = the in-process tier stands unchanged (the
  mem-tier posture; existing programs and fixtures are untouched).
- **R7 (journal-first, fail-closed).** The append happens BEFORE the
  in-process mutation; an append fault is `CXER4710
  E_AUTHZ_STORE_FAULT` (cause carried) and the mutation does NOT
  apply — live trust state never runs ahead of its log. Replay
  applies events WITHOUT re-running issue-time validation (the log is
  the authority; attenuation/gate checks ran at issue — re-checking
  at fold would make replay order-fragile for no security gain).
- **R8 (event vocabulary).** Named stream `authz` on the bound
  journal; two events: `[authz-issued <canonicalized delegation>]`
  (guardian grants ride the same event — the guardian shape is IN the
  value) and `[authz-revoked id=…]`. A cascade revoke appends ONE
  event per affected id (§2.6 "every authority transition"; replay
  stays a trivial fold, audit stays exact), each applied to live
  state immediately after ITS append succeeds — on a mid-cascade
  fault, both log and live state hold the same prefix (consistency at
  every prefix; the remainder re-runs idempotently).

**W3 CLOSED 2026-08-11 — full gate GATE-RC=0 (s6_w3_gate.log; the
fabric+http usecache pair + one load-sensitive udp-deadline lane, all
green on in-gate retries).** Landed: AuthzStore journal binding
(opts.journal → jrn_get_open, fault at open = CXER4710 w/ cause);
authz_replay_journal (fold over the named `authz` stream; cross-tenant
skip; corrupt-event fault; window inheritance re-run, issue-time
validation NOT re-run per R7); authz_journal_append (journal-FIRST,
attribution {actor: issuer, authority: basis, stream: authz}); hooks in
delegate / grant-guardian / revoke (+ per-id cascade events, R8).
authz.md §5 note rewritten to the landed two-tier contract — every
claim verified: authz-063..067 fixture-first RED→green
(s6_w3_pre/post logs); the FOUR-env restart test
(test_authz_durability_survives_env_restart: issue →
permit-after-restart → revoke → deny-after-second-restart over
file://); the denied-backend probe (4710 wrapping the 0271 cause,
mutation not applied — re-verified on a REBUILT binary after the
stale-CLI gotcha fired again). #713 item 4 evidence complete.

### W4 — budgets: commit-point debit + meter-as-fold, L112 (2026-08-11)

**W4-entry rulings:**

- **R9 (a debit is a §2.6 transition event).** `[authz-debited
  id=<granting delegation> (count=N)? (spend=AMT currency=CUR)?]` on
  the SAME named `authz` stream — one trust log; the journal's
  per-stream group-commit lock IS "the stream's commit lock" (L112:
  linearizable for free; per-stream v1 scoping falls out — a
  cross-stream meter has no serialization point, stream 10's gap).
  The event records the GRANTING delegation id; the fold attributes
  usage up the `[attenuates …]` chain to every bounds-bearing
  ancestor (shared meters deplete for the whole subtree — replay-
  stable, since the chain is in the same log). Verb: `debit(store,
  id, opts {count, spend, currency, now})` — impure, journal-backed
  tier only (an unbound store has no commit point: CXER4710).
  Refunds never credit: a non-positive count/spend is CXER4711
  (unissuable, the L112 "budgets meter authority exercised" rule).
- **R10 (meter-as-fold + the `meters` verb).** `meters(store, opts
  {now})` folds the stream's authz-debited events over the live
  delegation set into the EXACT element the shipped PEP reads —
  `[meters [meter id=… tokens=… count-used=… spend-used=…]…]`, one
  meter per bounds-bearing delegation. rate = token-bucket replay
  over event timestamps (start full, −1 per debit, refill n/per ×
  elapsed, clamp at capacity, final refill to `now`); count = event
  count (monotone); spend = sum of spend events inside the CURRENT
  UTC-Z window. **Window alignment: epoch-aligned in UTC**
  (floor(now/per)·per) — the deterministic implementation of the
  ruled "UTC-Z calendar-aligned" rule (ruling-20 consistency; equals
  calendar alignment for day-divisor windows, never tenant-local).
  Time coordinate = the journal entry ts (#712's deterministic UTC-Z
  form); `now` supplied via opts (the controllable-clock pattern) —
  default = the newest debit's ts (data-derived, fold stays
  deterministic with no ambient clock read). check STAYS PURE: the
  caller folds-then-checks (`{meters: [$authz:meters $az]}` — the
  with-context materialized-snapshot posture).
- **R11 (commit re-checks under the lock; PEP completes the conjunct
  triple).** `debit` re-folds INSIDE the append path before writing:
  exhausted at commit → the same CXER4713-carrying `[deny [reason
  :budget-exhausted] [conjunct …] ([retry-after …])?]` VALUE and NO
  event (the two-times enforcement table — the PEP decided on a
  snapshot; live facts re-check at commit). AuthzMeterReading gains
  the spend axis and authz_budget_check the spend conjunct, so a
  PEP-side denial can name ANY failing conjunct (D-C1) once a fold
  reading is supplied — completing what stream-4 W4 deliberately left
  to the effect surface. **Reservation** (the promoted-normative
  extension) lands WITH ITS SUBSTRATE at stream 10 (#682) — the ruled
  sentence itself binds its semantics to "stream 10's escrow rules";
  named landing, not a deferral.

**W4 CLOSED 2026-08-11 — full gate GATE-RC=0 (s6_w4_gate2.log; first
run s6_w4_gate.log RC=2 = guide-check wanting fn-docs for the new
public defs — added; fabric/http/udp lanes = the known retry-green
set).** Landed: authz-debited events on the authz stream (R9);
authz_meters_impl + authz_meter_fold (R10: bucket replay / monotone
count / epoch-aligned UTC-Z spend windows; now via opts, default =
newest debit ts); authz_debit_impl (R11: re-fold under the commit
path, CXER4713-as-data deny naming conjunct + meter owner, no event on
refusal; count>=1 / spend>0 / declared-currency validation); PEP
reading + budget check gain the spend axis/conjunct (D-C1 complete);
stdlib/authz.cx meters+debit defs + fn-docs; authz.md §3.8 authored
per the ruled meter-as-fold map row. **Latent stream-4 defect fixed en
route (fixture-first):** the [spend AMOUNT] bounds arm raw-matched
f64/i64 and silently rejected every literal spend amount (the arm was
fixture-untested at stream-4; authz-072/073 now pin the
authz_node_f64 read). Fixtures authz-068..077 green; stdlib umbrella
green. Gotcha booked: canonical attr emit does NOT quote hyphenated
ids (meter id=d-1, not id='d-1') — out-text must match the emitter,
not the input spelling.

### W5 — idempotency: keys, effect-boundary dedup, window, L111 (2026-08-11)

**W5-entry rulings:**

- **R12 (key derivation + explicit-key spelling).** Derived default =
  Tier-1 hash of the canonical record `{args: <param-name → value map
  AFTER defaulting>, fn: <Tier-2 command address>, tenant: <tenant>}`
  — the arg record is keyed BY PARAMETER NAME after defaulting, never
  the raw call expression (positional vs named spelling of the same
  refund is ONE key — the anti-double-refund trap; the canonical map
  key-sort makes spelling-invariance structural). Explicit caller key
  WINS when present: the reserved call-site named argument
  `idempotency-key=` (the `[?rate-limit] name=` precedent — a CALLER
  key, not a def clause; it never binds a parameter and is stripped
  from the arg record; on a NON-idempotent command it is the natural
  unknown-argument error — undeclared is retry-unsafe by design).
  Dropped from the key, stated: cap-set + authority basis (recorded,
  not keyed — the ruled sentence). Tenant at the direct-call boundary
  = '' (no ambient tenant in the engine); the session/commit boundary
  supplies the real tenant (W6).
- **R13 (success-only recording; present-value hits).** Only a
  SUCCESSFUL outcome creates a dedup record: a failed attempt leaves
  no record, so `[?retry]` re-executes — exactly the at-least-once +
  effect-boundary-dedup composition the ruling names ([idempotent] is
  what makes [?retry] SAFE; recording failures would make the first
  crash permanent). A dedup hit returns the PRESENT wrapper
  `[deduped <original outcome>]` — "already done, here's what
  happened", never the absence channel.
- **R14 (two dedup tiers, one vocabulary).** The effect boundary of a
  DIRECT call is the per-ProgramState registry (the [?retry] scope —
  the same cap-free clock/counter-observation posture as the
  resilience combinators, §6.5.1 exception family; window expiry
  reads the SAME engine clock [?test-clock] advances). The DURABLE
  boundary (W6 commit) is the E3 must-not-exist CAS (set-alias
  expect='' on `idem/<tenant>/<key>`, CXER1114 conflict = dedup hit)
  + the journaled transition event (fold-visible fact); journal.md
  §4.9 gains the ruled retention extension NOW (a dedup record may
  not be compacted away before its declared window expires —
  compaction reopening the double-execution window is the
  papering-over D-C1 warns against). Absent `[window]` = no expiry
  (the caller declared unbounded idempotency; declare a window on
  server-resident commands — documented in code.md §12.2.7).

**W5 CLOSED 2026-08-11 — full gate GATE-RC=0 (s6_w5_gate2.log; first
run RC=2 = the deliberate cxparse corpus growth +6, baseline updated
759/594→765/600; usecache pair retry-green).** Landed: Closure
is_idempotent/idem_window_ns/tier2_addr via command_idem_fields (both
registration sites; malformed [window] = CXER0239); per-ProgramState
idem_records registry; bind_specs_and_eval_k reads the DERIVED key out
of the post-default call frame (one spelling of the binding rules);
idem_strip_explicit_key handles the reserved idempotency-key= caller
arg before binding; success-only recording; [deduped <outcome>] hits;
window expiry on clock_now(). Fixtures cmd-013..018 green (cmd-014 =
the anti-double-refund trap; cmd-016 = the failure-not-recorded
discriminator via swallowed-first-failure-then-out-err; cmd-017 window
expiry on [?test-clock]). code.md §12.2.7 idempotent bullet completed;
journal.md §4.9 dedup-record retention extension authored per the
ruled map. Durable commit-boundary CAS = W6 (g).

### W6 — propose mode + cap: resolution, L113/L114

**W6-entry rulings:**

- **R15 (surface split: engine proposes, authz disposes).** The
  proposal CONSTRUCTOR is the engine's (`[$cx:propose <command-fn>
  <args-map> <opts>]`, modules/cx.md — beside cx:hash/computation-id:
  identity work belongs to the identity module); approval + commit are
  AUTHORITY operations and live on cx-stdlib/authz (§3.9: `approve`,
  `commit`, `resolve-cap`) — no new module, no [?command]-style
  registry churn, and the M5 flow composes shipped pieces (PEP,
  meters, debit, journal, the E3 CAS on the journal's backing store).
- **R16 (the proposal value).** `[proposal [command tier1=<Tier-1 of
  def text> code=<Tier-2 computes-as:>] [args <param-name → value map,
  post-default>] [effects <declared set, scopes canonicalized —
  v1 resolved==declared, the honest note>] [preconditions <each
  recorded with its propose-time result>] [via …opts-supplied basis…]
  [idempotency-key <explicit or derived>] [tenant …]]`. Tier-1 of the
  def TEXT is the trust key (the L139 amendment); Tier-2 rides for
  cache/equivalence only. A FALSE precondition at propose REFUSES the
  proposal (nothing coherent to approve); commit re-evaluates and any
  divergence (recorded-true now-false) is the loud refusal.
- **R17 (approval + commit).** `approve` constructs the Lane-2 claim
  `[approval [subject hash=<Tier-1 of the proposal>] [by …] [tier …]
  [signature …]]` binding the ADDRESS (approval-by-name-or-args is
  forbidden — forgeable); signature verification follows the SHIPPED
  authz tier posture (verify-tier: T1 single, T2 M-of-N quorum —
  nominal-shape today, crypto composes in deployment; the proposal
  machinery inherits whatever that posture is, one authority).
  `commit` verifies fail-closed, in order: (a) the proposal re-hashes
  to the approval's subject (a tampered/re-lowered proposal is a
  DIFFERENT address); (b) the presented command-fn's def-text Tier-1
  == the proposal's trust key (commit runs the EXACT approved
  version); (c) approval tier verifies; (d) propose-only screening —
  no via-chain link carrying [propose-only] can ground a commit; (e)
  preconditions re-evaluate, divergence refuses; (f) PEP check over
  the folded meters; (g) idempotency: the durable E3 must-not-exist
  CAS (`idem/<tenant>/<key>` alias on the journal's backing store,
  expect='' — CXER1114 conflict = dedup hit returning [deduped
  <recorded outcome>]); (h) debit under the stream's commit lock;
  (i) EXECUTE the body (code.invoke_closure — the platform→code
  composition stdlib_live already uses); (j) journal the committed
  transition (actor + authority chain) on the authz stream. Every
  refusal is typed; CXER4714 E_AUTHZ_PROPOSAL_INVALID allocated for
  the address/version/tier/divergence refusals (band-internal row,
  authz.md §8); CXER4715 E_AUTHZ_PROPOSE_ONLY for (d).
- **R18 (propose-only + cap:).** `[propose-only]` is a delegation
  child (grant-side attenuation flag): a delegation carrying it can
  ground proposals but NEVER a commit (screened at (d); attenuation
  rule — a child of a propose-only parent is propose-only by
  inheritance, narrowing-only). `resolve-cap(store, 'cap:sha2-256:…')`
  resolves an authority-artifact ADDRESS against the LIVE registry
  view (scan + Tier-1 hash compare): absent / revoked / expired →
  fail-closed CXER4716 E_AUTHZ_CAP_UNRESOLVED (a trust input that
  cannot be proven live is refused loudly, L114). A `[requires
  'cap:…']` clause resolves at propose AND commit through the same
  verb. governance §12.3 (NEW): the reserved reference-prefix
  registry — code:, computes-as:, cap: rows (domain separators for
  trust inputs; cx-err: stays §9.6's). xap.md §3.4: the dry-run
  sentence amended per the ruled one-mechanism unification (dry-run's
  return IS the proposal-value shape; dry-run is spec'd-not-yet-
  implemented in stdlib_xap, so this is a text-level cutover with no
  fixture movement — verified).

Sub-sequencing: W6a = cx:propose + Closure cmd_meta (requires/
preconditions/src_addr behind ONE pointer — the #45 closure-copy
perf rule) + governance §12.3 + xap.md text + fixtures; W6b = authz
approve/commit/resolve-cap + propose-only + durable idem CAS +
fixtures. Both landed in ONE wave (the split proved unnecessary —
the engine and authz halves compose through two pub seams:
code.value_tier1_address + code.command_commit_execute).

**W6 landing notes (pre-gate; standalone lanes green):** cx:propose
(CXER4111/4112 — the band's two reserved slots claimed);
CommandMeta behind one Closure pointer; approve/commit/resolve-cap on
authz §3.10 (CXER4714/4715/4716); [propose-only] child + chain
screening; commit = the full R17 chain with the engine half in
code.command_commit_execute (version binding via the def-text Tier-1
== the F1′ raw-byte tagged address; precondition divergence via
re-eval — authz-082 discriminates with a test-counter that was TRUE
at propose and FALSE at commit); [requires 'cap:…'] re-resolution
fail-closed; governance §12.3 authored (code:/computes-as:/cap:
rows); modules/cx.md cx:propose section + rows; xap.md §3.4 dry-run
= proposal-value text cutover (dry-run is spec'd-not-implemented in
stdlib_xap — verified, no fixture movement); authz.md §2.2
propose-only + §3.10 + §8 rows. Fixtures: cmd-019..022 (proposal
shape w/ pinned addresses; precondition-false refusal; the
address-binding pair — arg-spelling-invariant SAME address, tampered
args DIFFERENT; non-command refusal) + authz-078..082 (roundtrip;
tampered-proposal 4714; propose-only 4715; resolve-cap live→revoked
4716 fail-closed; precondition divergence 4714). cxparse baseline
765/600→769/604 (deliberate, +4 agree). DURABLE idem CAS note: the
commit flow rides the ordinary invoke path, so the per-program dedup
applies; the cross-process store-alias CAS (idem/<tenant>/<key>
expect='') needs an expect-addr arm on set-alias that the store
surface does not yet expose — composed when that E3 arm lands
(named landing: the store CAS vocabulary, #708-family); the commit
journal event + fold-visible dedup facts are in place. The
in-process dedup at commit IS live (the invoke path's).

**W6 CLOSED 2026-08-11 — full gate GATE-RC=0 (s6_w6_gate.log; the
usecache pair retry-green).**

### W7 — M5 end-to-end + exit (2026-08-11)

**Ordering defect found by DRAFTING the M5 fixture (fixture-first pays
again):** authz_commit_impl executed the body BEFORE the debit — an
over-budget commit would run its effect and only then be refused. The
ruled order (M5: "commit re-checks preconditions, debits the spend
meter under the stream's commit lock, dedups by key") is verification →
preconditions → DEBIT → execute: a refused commit exercises no
authority (no debit on refusal), and a debited crash is correct
("budgets meter authority EXERCISED, not net economic effect"). Fix:
command_commit_execute gains (run_preconditions, do_execute) so the
verify pass evaluates preconditions exactly ONCE and the execute pass
runs the body after the debit clears. authz-083 (the M5 arc) pins the
order: overspend deny arrives WITHOUT the body running and WITHOUT a
dedup record for the refused order.


### Stream exit entry (2026-08-11) — VERDICT: L109–L114 (+L139) discharged at full ruled scope

**W7 landed:** the M5 `refund-order` end-to-end fixture (authz-083 —
propose under a propose-only budget-bounded sub-delegation → principal
approves the ADDRESS → commit verifies/debits/executes/journals →
identical replay dedups as a PRESENT value → the over-budget refund
denies naming :spend on the meter owner, with the body NEVER run and
no dedup record: the exec-counter pins the ordering). The
commit-ordering defect the fixture-drafting found (execute-before-
debit) fixed via the two-pass engine protocol (verify: version +
preconditions ONCE; then debit under the commit lock; then execute).

**Exit audit vs the ruled §8 spec-edit map:**
- grammar `[152a]` + `[152d–h]` — EXECUTED (W2).
- code.md §12.2 (+§12.2.7, §9.4/§9.5 rows, §6.5.1 interplay) — EXECUTED
  (W2, completed W5).
- security.md §2 effect table + enforcement note (EV-EFFECT-SET) —
  EXECUTED (W2; spec↔impl parity gate live; io-watch hole closed).
- authz.md — [bounds] rows verified (stream-4 W4); §5 durable-tier note
  (W3), §3.8 budgets (W4), §2.2 propose-only + §3.10 + §8 rows
  4714–4716 (W6) — EXECUTED.
- xap.md §3.4 dry-run → proposal — EXECUTED (W6; text cutover on a
  spec'd-not-implemented surface, verified no fixture movement).
- journal.md dedup records + retention extension — EXECUTED (W5, §4.9).
- governance §12.3 cap: row (new reserved-reference-prefix registry) —
  EXECUTED (W6).
- stream-4 handoff (wire carriage) — was already DISCHARGED (store
  profile §6.1, per the ruled map's own note).
- stream-18 handoff (discriminator + proposal schema) — READY: the
  `[effects]` discriminator is normative + enforced (code.md §12.2.7);
  the proposal schema ships (modules/cx.md cx:propose + authz §3.10);
  #690's MCP projection consumes both as specified in
  agent_tool_projection.md.

**§7 corpus handoff audit:** propose→approve→commit arc (authz-078,
-083); tampered-args replay negative (authz-079, cmd-021);
precondition-divergence refusal (authz-082); dedup-hit present-value
(cmd-013, authz-083); double-spend across the budget boundary denied
naming the conjunct (authz-073, -083); positional-vs-named ⇒ ONE key
(cmd-014, cmd-021); budget composition (authz-075 shared meter,
authz-028 envelope clamp — pre-existing); pure+[effects] static
negative (cmd-003); effect outside declaration ⇒ loud (cmd-002);
propose-predicts-commit over out-effects — the CHANNEL is reserved,
not yet implemented (conformance README: stream 22); the pair lands
WITH that channel (named landing). The semantic property holds by
construction meanwhile: commit executes under (grant ∩ declared) —
exactly the set the proposal records — so commit can never exercise an
effect the proposal did not show (cmd-002 enforces the narrowing).

**Out-of-scope remainders, each at a named landing:** reservation
(escrow semantics) → stream 10 #682 (the ruled sentence's own
binding); cross-process durable idem CAS (set-alias expect-addr arm)
→ the E3 store CAS vocabulary (#708-family); the out-effects
discriminator pair → stream 22's channel; direct-call [preconditions]
evaluation — commit evaluates them; the DIRECT path deliberately does
not (the ruled text speaks only of propose/commit; the question is
BOOKED for the owner at the item-6 review, not silently decided);
tenant at the direct-call idempotency boundary ('' — the session
boundary supplies it where sessions exist).

**Defects filed in passing:** #780 (module-loader declared_impure
drift). **#713 item 4:** evidence complete (W3).

**Item-6 packet notes:** G3 graduation of commands_effects.md is
owner-gated; the working spec's §1–§8 are now fully implemented, so
the graduation review can run against live behavior; the direct-call
preconditions question above is the one lettered decision the review
should take.

**Handoff (order of march):** next is #679 (stream 7, consistency
vocabulary — spec finalized at S3; the [idempotent]-naming
`:exactly-once` refusal and the CAS attachment points compose with
this stream's landings).
