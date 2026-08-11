# I5 stream 3 — live modes: implementation ledger

**Status:** OPEN (started 2026-08-10 at the W8→stream-3 boundary;
boundary queue executed in full — highs lane closed, #700 lever
delivered, V-fork campaign planned as #775 and kept OUT of this
stream). Branch `impl/I5-stream3-live` off `design/651-516-partition`
(cut at 3760e86b — the boundary tip).
Governing spec: `live_modes.md` — letters L129–L137 RULED (a)
2026-08-05 (wave S3 exit; the campaign decision log carries the
grep-able spelling `122–154`), PLUS the §10 U1 binding (RULED:
U1.1a–U1.15a, #761, applied @ 84c56283 — the observe handle is
authored AS a delivery.md §4 subscription value from day one; no
bespoke handle kind).
Issue: #675. Upstream seams consumed: stream 2's ∂ engine
(`planar_delta.v` — `planar_delta_init`/`planar_delta_apply`/
`planar_incremental_membership`, the L101 vocabulary verbatim) and
the L99 quoted-planar executor (`planar_query.v` —
`planar_query_execute` + `planar_extract_slices`
authorize-before-execute). Downstream: #762 (general
`[?receive]`/`[?select]` over the subscription contract) starts AFTER
this stream's verbs; the store change feed was formally handed to
stream 4 (L136) and locally the FIXED `store:log` (#708) is the feed.

**Identity-epoch membership (audit C9, from the spec's closing
section): ADDITIVE — no I1 manifest row, no epoch.** New verbs over
stream 2's comprehension; materializations, checkpoints, cursors,
adapter contracts are new values and new store surfaces. The
maintained-γ ≡ recompute obligation is OUTPUT parity (an output-level
gate, no identity involved). Where this stream reuses the ONE walk,
address stability is discharged by stream 2's byte-identity exit
clause, not re-proven here.

## Standing constraints

- Spec-first; NO normative-spec edit without a recorded ruling. The
  §9 spec-edit map IS the ruled surgery list for this stream (new
  live.md; journal.md retention extension; store.md feed cross-ref
  w/ #708; fabric.md §14 ladder cross-ref; io.md rung citation) —
  each surgery commit carries `RULED: 122–154` (en-dash! the wave-S3
  exit spelling in partition_campaign_PLAN.md is what greps; bare
  letter ids like L129 live only in live_modes.md and FAIL the gate's
  fragment check).
- Every wave ends green on full `make test` — launched UNPIPED, full
  log, `GATE-RC=$?` propagated, verdict read FROM the log.
- Fixtures ride WITH their wave, never after; live_modes §8 is the
  corpus contract.
- Error band `CXER5070–5089` (the C5-relocated band, registered in
  governance §9.6 2026-08-05 BEFORE first use); individual codes get
  their code.md registry rows as they are first named.
- The V-fork campaign (#775) is SEPARATE — V-runtime defects found
  here are filed + mirrored (`upstream` label), never folded in.
- Model per the 2026-08-09 policy: bulk implementation waves may run
  Opus 5; rulings/audits/identity-critical stay Fable 5; no
  mid-session switching.

## Wave plan (dependency order; each = one landing + gate)

| Wave | Work | Done-when |
|---|---|---|
| **W1 — the pack + `changes-since` (L129, L130/131 stateless legs)** | `cx-stdlib/live` pack scaffold (`stdlib_live.v`, Ring-1 surface / Ring-2 resolution per L97/L99); `[$live:changes-since (QUOTED-COMP) cursor=…] → (∂ set, cursor′)` — stateless, cursor in and out; sources resolved through the L99 slice extraction + authorize-before-execute path; ∂ frames as data elements (`[insert …]`/`[retract …]`/`[regroup …]`) carrying the SAME flat provenance attributes as the recompute relation; the HEAD-SET cursor (map source-ref → position, never a scalar) with round-trip form; query err = fault: delivered loud as the final frame; spec surgery: NEW live.md authored (the pack spec) + first CXER507x registry rows | Equivalence leg 1 pinned (one-time `[?for]` ≡ `changes-since` from the empty cursor); cursor head-set round-trips; ∂/recompute shape-parity (transparency) fixtures green |
| **W2 — `observe` (L130/131/132 + the §10 U1 binding)** | `[$live:observe (QUOTED-COMP) from=…] → handle`; the handle IS a delivery.md §4 subscription value (`rung=` reported always, `sharing=`, `flow=`, `head=`, `cursor=` head-set, `on-close=` → `[?with-open]` composes); client-anchored resume (`from=last+1`; server holds no per-observer state); declaring `:monotonic-reads`/`:gapless` engages stream 7's server-side cursor checks; ∂ subscriptions declare `retention=window\|full` so ∂-never-coalesces is STRUCTURAL (L130 via delivery §6); loud err termination as the final frame; resume below retention = the stream-7 `:gapless`-class honest refusal | `observe` ≡ repeated `changes-since` driven by source advance (equivalence leg 2); the ∂-never-coalesces discriminator (burst of N inserts ⇒ N frames); observe-resume negatives (refusal, not silent re-seed) green |
| **W3 — `materialize` (L130/132/133)** | `[$live:materialize (QUOTED-COMP) name=…] → ref` — named, store-aliased, checkpointed fold; membership gated through `planar_incremental_membership` (established totality; τ/λ and partial predicates = recompute-only, LOUD); per-aggregate policy: `sum/count/avg` retract-incremental via `planar_delta_apply`, `max/min/distinct` force the loud group recompute; the checkpoint IS the durable cursor (value-anchored; put-doc-then-alias ordering; `expect-pos` CAS under CXER1114); derived-state posture: missing/unreadable checkpoint ⇒ full replay, correctness untouched; reads are point-in-time values carrying `{at-seq}` and MAY coalesce (the sanctioned 25ms leading+trailing shape); spec surgery: journal.md retention-cover extension to REGISTERED materializations (history below a registered cursor may not compact away) | Equivalence legs 3+4 pinned (materialize ≡ observe + durable fold + address; maintained ≡ recompute incl. the retract/reinsert group-position pair); per-aggregate retract table fixtures (`sum` decrements exactly; `max` triggers the loud recompute); corrupt-checkpoint ⇒ full-replay-same-result; retention-vs-registered-cursor negative green |
| **W4 — the adapter contract (L134, the owner mandate; L135 v1 floor)** | Adapters as ordinary edge clients (fabric §14 posture); the CLOSED guarantee-ladder vocabulary DECLARED per adapter stream and reported on every subscription (stream 7's ONE declaration mechanism, not a second): `:complete-ordered` / `:coalesced-rescan` / `:snapshot-diff`; consumer requiring a stronger rung than declared = TYPED ERROR at wiring time; v1 floor adapters live: **poll** (`sched` cadence + monotone-key queries + content-address dedup + `store:diff` → declares `:snapshot-diff`) and **watch** (fs; the io.md rung verbatim — overflow means rescan → `:coalesced-rescan`); cursor mapping both directions (ingest: external resume token recoverable CX-side after crash — offsets outside the foreign connection, the NATS-bridge shape; egress: cumulative ack only after a foreign-side barrier); ingest identity: the three-way lowering ladder (JSON → wrapped map; CX-parseable → first element verbatim; else lossless named wrapper — never a drop) + stream-6 idempotency dedup keys (must-not-exist CAS) + the SQL NULL-duality declaration obligation + proven-session-principal attribution; **exclusivity ENFORCED at append** (writer-principal stream refuses other appenders — checked posture); CDC = spec'd top rung, arrives additively (NO `db_access` extension at v1; no time-keyed cursors, #712); spec surgery: fabric.md §14 + io.md cross-refs | Ladder declaration + wiring-time refusal pair; ingest lowering-ladder vectors + re-ingest dedup; exclusivity refusal; egress-ack-after-barrier fixture green |
| **W5 — store feed locally + M5 end-to-end (L136/137; §8 sweep)** | `changes-since` over STORE sources wired to the fixed `store:log` (#708 — per-ref advance order; E3's per-ref lineage is the log); spec surgery: store.md feed cross-ref; the full §8 corpus swept for gaps against the enumerated families; the M5 worked example LIVE end-to-end: revenue-by-region as query / `changes-since` carrying a dashboard cursor→head / `materialize` maintained (γ inserts; retract-incremental vs loud boundary exercised) / `observe` watched by an agent — fed by a CDC-less order DB through the poll adapter declaring `:snapshot-diff` | §8 corpus complete + green; M5 live across all four modes over the declared-`:snapshot-diff` adapter |
| **W6 — exit** | Ledger verdict; exit-merge to the design branch (the merge IS an exit step — the stream-4 miss is not repeated); #675 closed with evidence; the #762 handoff note recorded (verbs shipped, general receive/select next) | Full gate GATE-RC=0 read from the log; exit-merge pushed |

Wave order rationale: `changes-since` first because it is the
stateless core the equivalence quartet defines everything else
against (observe ≡ repeated changes-since; materialize ≡ observe +
fold) and it exercises the pack scaffold + cursor form with no
subscription state; observe before materialize because the handle
contract (delivery §4) is materialize's read/notification substrate
and the U1 binding says author it once, first; the adapter mandate
after the three verbs exist (adapters produce INTO the modes — the
refusal machinery needs declared rungs on real subscriptions);
store-feed + M5 as the integration wave once every part it composes
exists; exit alone, as always.

## Work log

(entries append here; each wave = one entry with commits + gate
verdict)

1. **STREAM OPENED + W1 SPEC-SIDE LANDED (2026-08-10, Fable 5 —
   contract authoring per the model policy; bulk V implementation
   hands to an Opus 5 session).** Branch cut at 3760e86b; ledger
   authored (e68d8925). The pack spec `spec/02-working/live.md`
   AUTHORED (RULED: 122–154 — the §9 spec-edit map's "new live.md";
   02-working pending owner-only G3 at the exit review): concrete
   signatures for the three verbs PLUS the poll-substrate companions
   `[$live:advance]` (the maintenance tick; sched-driven) and
   `[$live:read]` (`[snapshot [head-set …] ROW…]` — {at-seq} for a
   multi-source fold IS a head-set); the L99 pipeline reused verbatim
   with ONE deliberate widening (journal sources admitted alongside
   store sources; `$bind` map — formal names → handles — because live
   queries span source sets, where store:query binds all to the one
   queried store); ∂ frames = the planar_delta output vocabulary
   verbatim incl. the `[recompute reason=…]` honest-marker form, with
   the empty-cursor exception (exact full-relation-as-inserts for
   EVERY comprehension = quartet leg 1); head-set cursor reuses the
   profile §5.1 `[head-set [s source= pos=]…]` spelling (one
   vocabulary); the observe handle = `[live-sub]` conforming to
   delivery §4 with rung= always reported (native sources
   :complete-ordered; mixed sets report the WEAKEST rung); consumption
   seam pinned: stream 3 implements [?receive]/[?select]/[?close]
   arms for live-sub (first live consumer — no-consumer seam
   forbidden), #762 generalizes; error codes CXER5070–5078 assigned
   (5079–5089 reserved), reuse pinned (CXER0120/4700/1114 never
   duplicated). DECISIONS made at pack-spec latitude (within the
   ruled design, recorded here): the advance/read companions exist
   (live_modes §1's poll-shaped substrate demands an explicit tick —
   a maintained fold with no driver is a stub); maintenance=
   "incremental" opt turns the loud recompute into typed CXER5076
   for callers that must not pay recompute; changes-since outside
   the incremental sub-fragment answers the [recompute]+full-relation
   form (honest, strategy-free semantics: result@head ⊖
   result@cursor as an edit script).
   REMAINING for W1 (the Opus session): stdlib/live.cx pack surface +
   stdlib_bundle.v registration + stdlib.md §3 row;
   vcx/platform/stdlib_live.v prims (changes-since first: the L99
   pipeline + $bind resolution + source-delta pull from store:log/
   journal-since + planar_delta feed + head-set round-trip);
   CXER5070/5071/5072 registry rows in code.md as first implemented;
   the W1 fixture families (quartet leg 1; head-set round-trip;
   ∂/recompute shape parity); the W1 gate (unpiped, GATE-RC from the
   log).

2. **W1 LANDED (2026-08-10, Opus 5 — bulk implementation per the model
   policy).** The pack + the stateless core, exactly the entry-1
   handoff:
   - **Surface:** `stdlib/live.cx` ships `changes-since` ONLY (the
     live.md §2 note "surface lands with the W1–W3 implementation" is
     load-bearing — no-stubs means observe/materialize/advance/read
     appear WITH their waves, never ahead); module-doc + fn-doc, the
     example backed verbatim by `conformance/stdlib/live.cxd`
     (guide-check green). Registered in `stdlib_bundle.v`
     (43→44; the frozen-surface canary in stdlib_umbrella_test.v
     updated) + `spec/03-approved/std-lib/README.md` §3 Tier-D row
     (the L129-authorized surgery — §3/§3.2 counts reconciled to 44
     while there: `similar`'s earlier ride-in had left the header
     at 42, off by one BEFORE this row; flagged here for the owner) +
     the thin catalog entry `spec/03-approved/std-lib/live.md`
     (module-meta for the stdlib-catalog-gate — the fabric/xap/sql
     pointer pattern; spec content stays in 02-working/live.md).
   - **Prim:** `vcx/platform/stdlib_live.v` `live-changes-since`,
     env-aware via ring2_register.v. The L99 pipeline verbatim
     (planar_query_source → parse → membership CXER0120 →
     planar_extract_slices → $bind resolution → the store:query
     authz-slice layer reused → planar_rewrite), widened to journal
     sources per the pack spec. Cursor = head-set per FORMAL name;
     store pos = the #708 lineage's DOCS-PLANE advance seq
     (`ms.advances`/`adv_pos` — heads sampled at entry; handles are
     single-owner so reads cannot interleave a writer); journal pos =
     the per-STREAM seq. Three answer paths: EMPTY cursor →
     executor + full-relation-as-inserts (leg 1, exact, no marker);
     outside `planar_incremental_membership` (or a source ref outside
     a generator position — no ∂ entry point) → the honest
     `[recompute reason=…]` + inserts; inside → per-generator relation
     reconstruction at the cursor (store: lineage replay w/ object-root
     content recovery for since-deleted docs; journal: slice 1..cur) +
     source deltas fed through `planar_delta_init/apply`, output script
     verbatim; an engine `[recompute]` mid-window supersedes the frames
     (marker + maintained relation re-stated). BOTH paths behind the
     `eval` capability (cap_guard; registered in effect_alignment.v —
     gated ⇒ impure by construction).
   - **Decisions at implementation latitude (recorded):** (a) a formal
     journal name consumed with TWO distinct streams refuses CXER5072
     (one head-set position cannot represent two per-stream seqs; bind
     each stream through its own formal) — the §4 one-entry-per-formal
     doctrine made concrete; (b) non-objgraph + remote stores refuse
     CXER1709 (mirrors store:log #708 — the wire feed is stream-4/W5);
     a store carrying NAMED WIRE REFS (refs-plane lineage) likewise
     refuses CXER1709 loud until W5 wires the full per-ref advance
     order — the W1 docs-plane cursor must never silently miss a
     ref-advance; (c) unreconstructable history (post-gc/prune object
     loss; blob history, whose F1' inserts record no object root)
     refuses CXER5073 — fail-closed, never re-parsing raw bytes as
     structure; (d) a query err returns as the [err] VALUE (the
     final-frame delivery form is observe's, W2); (e) consumers re-wrap
     the returned cursor (`[?element "head-set" $c/head-set]`) because
     a path binding unwraps a single matched element to its content —
     fixture-pinned spelling, revisit at W2 if the handle carries the
     cursor.
   - **Registry:** the per-code rows LIVE in live.md §9 (the stream-4
     precedent — core code.md carries only the CX-code range and is
     NOT in this stream's ruled §9 edit map; the entry-1 "code.md
     registry rows" phrasing resolved accordingly, live.md §9 wording
     corrected in place); governance §9.6 band row updated per #717:
     5070–5073 shipped at W1. cxer-registry-gate --strict green.
   - **Fixtures:** `conformance/stdlib/live.cxd`, 19 enforced cases
     (gates.cxd row live=enforced): the three W1 families — quartet
     leg 1 (001/002 + the τ empty-cursor exactness pair 009/010),
     head-set round-trip (003 quiescent / 004 inserts-since / 005
     retract), ∂/recompute shape parity (006 σ/π row equality; 007 γ
     [regroup]; 008 γ-retract honest marker + rebuilt relation) — plus
     the journal per-stream cursor (011) and the refusal set
     5070/0120/5071×2/5072×2/0271/5073 (012–019).
   - **Gate repair riding along:** `make check-effect-alignment` had
     been broken since the #700 eval_semantics consolidation (its test
     file merged into the umbrella; the named target was never
     retargeted — the documented #700 retarget class, this one
     missed). Retargeted to eval_semantics_umbrella_test.v; green.
   - **W1 gate:** full `make test` UNPIPED, GATE-RC recorded from the
     log (commit message + below carry the verdict).

3. **W2 LANDED (2026-08-10/11, Fable 5).** `observe` — the live ∂
   subscription — plus the delivery.md §4 consumption arms, exactly the
   entry-2 handoff:
   - **Surface:** `stdlib/live.cx` gains `observe` (module-doc/fn-doc
     updated; the fn-doc example backed VERBATIM by fixture live-020).
     Thin catalog entry + governance §9.6 band row updated in the same
     change (#717 discipline): 5074–5075 shipped at W2.
   - **Prim:** `live-observe` in stdlib_live.v. The W1 pipeline
     REFACTORED into shared pieces — `live_prepare` (parse → membership
     → slices → $bind CXER5071 → authz-slice → L96 rewrites),
     `live_sample_heads`, `live_answer` (the three-path core) — and
     observe's every poll reuses them VERBATIM: observe ≡ repeated
     changes-since IS the implementation, so equivalence leg 2 holds by
     construction (live-021 pins it as LITERAL value equality across an
     insert round, a retract round, and a quiescent round).
   - **The handle:** `[live-sub id= rung= sharing=independent flow=pull
     retention= on-close=live-close [head-set …]]` — live.md §5
     verbatim; rung ALWAYS reported, weakest-of-set (native sources
     declare :complete-ordered; live_rung_rank orders the closed
     ladder; adapter rungs feed in at W4); the [head-set] child = the
     client anchor at creation (delivery §4's head=/cursor= for a
     multi-source set IS a head-set — unrepresentable as a scalar attr;
     the pack's single-child rendering is the conforming form).
   - **Consumption seam (U1.12a/U1.15a arms, FIRST consumer):** NEW
     Ring-1 registry `Ring2SubOps` (ring_registry.v — receive + ready
     probes keyed by handle element name; ring2_register.v registers
     'live-sub'). `[?receive from=]` unbatched = ONE poll = the next
     [changes] batch (empty at quiescence — the honest changes-since
     answer); `max=`/`deadline=` engage the U1.12a batch form (the
     sequence of up to max NON-EMPTY batches within deadline ms;
     quiescent polls are non-deliveries; deadline without max =
     unbounded max). `[?select]` from-cases accept subscriptions AND
     channels mixed (readiness = the non-consuming heads>cursor probe).
     `[?close]` fires the SHARED `__cx_close_id__` close contract
     (bus_stamp_closeable; idempotent silent second close per SAP §5.1
     — channel CXER0203 double-close stays the channel's own posture),
     so [?with-open] and [?close] share one close state. #762
     generalizes these arms across every §4 instance.
   - **Termination/refusals:** CXER5074 closed-and-drained on receive
     after close or after the fault frame; a mid-stream fault (query
     err, source err, retention loss under the cursor) terminates LOUD
     — the err delivered as the FINAL FRAME of a terminal [changes]
     batch whose head-set is the UNADVANCED cursor; at CREATION a
     below-retention $from refuses CXER5073 via eager anchor replay
     (stream 7 F2 engaged always — never a silent re-seed);
     retention=latest on a ∂ stream → CXER5075 (the named structural
     refusal), non-point retention values → CXER5075; $opts `rung=`
     (the delivery one-option-vocabulary guarantee-declaration key)
     accepts exactly {:monotonic-reads, :gapless}, any other token →
     CXER5075 — ladder REQUIREMENTS (CXER5077) are W4 adapter wiring,
     deliberately NOT dead code now.
   - **Decisions at implementation latitude (recorded):** (a) the
     delivery message unit is the [changes] batch — one changes-since
     answer per receive ("frame" = the ∂ entries INSIDE batches; the
     burst discriminator counts [insert] frames: live-022, N inserts ⇒
     N frames, never coalesced); (b) QUIESCENCE EXACTNESS added to
     live.md §3 (RULED: 122–154, pack-spec latitude): cursor==head on
     every source ⇒ ∂ = ∅ BY IDENTITY for EVERY comprehension
     (positions advance on every source event) — W1's changes-since
     answer for non-incremental comps at quiescence (was
     [recompute]+full) refined to the provably-exact empty batch,
     pinned live-037/038; the second universal exactness point beside
     the empty cursor; (c) the subscription registry is PROCESS-GLOBAL
     (fabric parity), never a ring2_env_reset: new_env is ALSO the L99
     sandbox constructor (planar_query_execute builds one per
     execution), so a per-program reset wiped the registry on the first
     receive — found live during W2, the reset removed; (d) polls
     re-guard the `eval` capability (every receive executes the quoted
     comprehension; observe guards at creation too — both registered in
     effect_alignment.v); (e) the error-pipeline order inside
     live_prepare is parse → membership → slices → bind → authz →
     REWRITE for both verbs (rewrite folded into prepare: V cgen cannot
     default-init ProgramForComp, so LiveQuery is heap-built on success
     only — the store_get_open nil convention); no fixture pinned the
     old cap-before-rewrite relative order; (f) verb attribution
     threaded through the replay-substrate messages (a CXER5073 out of
     observe no longer reads "changes-since").
   - **Fixtures:** conformance/stdlib/live.cxd 19 → 39 enforced cases
     (live-020…039): leg-2 equivalence; burst ∂-never-coalesces;
     handle-shape + mixed-source weakest rung; retention/rung policy
     negatives; close/with-open/idempotence; fault-final-frame +
     closed-and-drained pair; select readiness + timeout fallback;
     journal-source observe; batched receive; observe below-retention
     negative; quiescence-exactness pair; observe eval-cap deny.
   - **W2 gate:** full `make test` UNPIPED — GATE-RC=0 read from the
     log (scratchpad w2_gate_make_test.log line 203896; every lane
     0-failed; the standalone eval-fixtures lane also green first,
     LANE-RC=0). W3 pre-survey note: NO expect-pos CAS exists anywhere
     in platform yet (only the remote wire's 409→CXER1114 mapping) —
     W3 builds the CAS alias advance the checkpoint contract needs.

4. **W3 LANDED (2026-08-11, Fable 5).** `materialize` + the
   poll-substrate companions `advance`/`read` — the pack's verb surface
   is COMPLETE. Exactly the entry-1/live.md §7 contract:
   - **Surface:** `stdlib/live.cx` gains materialize/advance/read
     (fn-doc examples backed VERBATIM by live-040/041/042); catalog
     entry + governance §9.6 updated same-change (#717): 5076 shipped
     at W3 (5077–5078 = W4).
   - **The checkpoint IS the durable cursor** (value-anchored):
     `[checkpoint q= [head-set …] ROW…]` doc, put-doc-then-alias, and
     the alias advanced by an EXPECT-POS CAS on its per-name advance
     position (`live_alias_advance_cas` — BUILT at W3, no expect-pos
     CAS existed anywhere; mirrors the set-alias local path under one
     hold of the reentrant op lock; CXER1114 on conflict). `q=` = the
     canonical-text hash of the comprehension → RE-ATTACH: materialize
     on an existing alias resumes iff q matches (live-052); a name held
     by a different value refuses CXER1114 (live-049) — never a silent
     replace. Checkpoint store local-objgraph-only at v1 (CXER1709; the
     wire CAS rides stream 4).
   - **advance** (the sched-driven tick): read checkpoint (its alias
     pos = the CAS expect), sample heads, quiescent → [advanced
     applied=0 recomputed=false] no-write; else compute via the SHARED
     window core (live_apply_window — extracted from live_answer, one
     engine for script + fold consumers), re-checkpoint, CAS. applied =
     source events in the window; recomputed reports the LOUD boundary.
   - **Per-aggregate maintenance (L130):** a γ-retract is ABSORBED
     (recomputed=false) when the yield uses only invertible aggregates
     — live_yield_invertible walks the yield AST: any max/min/distinct
     call, or any $group use outside a sum/avg call, forces the loud
     recompute (recomputed=true; value still exact — the engine state
     rebuilds either way). Pinned: sum decrements exactly
     recomputed=false (live-044, with leg-4 $cx:equal vs fresh
     recompute); max → recomputed=true (live-045).
     maintenance="incremental" → CXER5076 at creation outside the
     sub-fragment (live-046) AND at any advance whose window forces
     recompute — incl. the lost-checkpoint full replay (live-047).
   - **Derived-state posture:** missing/unreadable/q-mismatched
     checkpoint = full replay, correctness untouched — read recomputes
     at head + re-checkpoints (live-048: checkpoint doc deleted, read
     answers the same rows).
   - **read:** `[snapshot [head-set …] ROW…]` from the checkpoint —
     exact in-process (coalescing is MAY; the 25ms shape is the XAP SSE
     edge's, not built here). read is NOT eval-gated on its normal path
     (a doc read); ONLY the derived-state replay branch carries the
     inline eval guard (noted in effect_alignment.v — the conditional
     posture, store modify-doc-closure precedent).
   - **The L133 retention cover extension (the ruled journal.md
     surgery, RULED: 122–154):** a materialization over journal sources
     REGISTERS in each journal's own store (alias
     `cx-live/materialization/<tenant>[/s/<stream>]/<name>` → a
     [live-materialization] doc — the fabric-offset pattern);
     jrn_retain refuses a pruning boundary while a registration exists
     (jrn_registered_materialization; CXER4616 naming the
     materialization). Rationale pinned in journal.md §2.8: a
     journal-source relation is the stream's ENTIRE history = the
     fold's recompute basis; store sources register nothing (a store
     relation is CURRENT state — full replay reads live docs).
     live-051 is the DISCRIMINATING pair: the same snapshot+policy
     retain succeeds before registration, refuses after.
   - **Decisions at implementation latitude (recorded):** (a) the
     checkpoint doc gains q= and splices the fold rows (live.md §7
     refined in place — the '[checkpoint [head-set …] VALUE]' sketch
     made concrete); (b) re-attach semantics as above (no drop verb is
     ruled; the retention pin is lifted by removing the registration
     alias with the store verbs — the refusal message says so); (c)
     registration is journal-side only (store history ≠ recompute
     basis); (d) applied=N counts source events; the forced-recompute
     path reports applied=0 recomputed=true; the empty-anchor seed is
     EXACT (leg 1) → recomputed=false; (e) the invertibility walk reads
     element-construction ATTRS (ProgramLiteral.attrs — slots is
     retired D014; the max-in-attr case was caught live by the a2
     smoke, recomputed=false → fixed before any fixture was blessed);
     (f) the fold layer never edits stream 2's engine — the γ-retract
     marker reason is exported as pub const
     planar_delta_reason_gamma_retract (DRY, no behavior change) and
     classified by the fold layer.
   - **Fixtures:** conformance/stdlib/live.cxd 39 → 53 enforced cases
     (live-040…053): the three fn-doc examples, leg 3 (043: read rows +
     head-set ≡ the observe subscription's delivered state), leg 4 +
     sum-decrement, max-loud, CXER5076 pair, corrupt-checkpoint full
     replay, CXER1114 name conflict, journal fold + quiescent advance,
     the retention-pin discriminating pair, re-attach, materialize
     cap-deny.
   - **W3 gate:** full `make test` UNPIPED — GATE-RC=0 read from the
     log (scratchpad w3_gate_make_test.log line 203892). Two lanes
     (fabric_umbrella, http_umbrella) failed their first C-compile with
     a duplicate-symbol link error and were retried by the harness's
     OWN classified #572 cache-free retry — both green, the log's
     "every failed lane green on its classified retry" line; the
     sanctioned retry, named. The standalone eval-fixtures lane was
     green first (LANE-RC=0, w3_fixture_lane.log).
