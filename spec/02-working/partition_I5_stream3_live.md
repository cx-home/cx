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
