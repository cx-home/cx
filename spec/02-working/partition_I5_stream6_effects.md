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
