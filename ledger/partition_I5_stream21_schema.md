# I5 stream 21 — schema & event evolution: implementation ledger

**Status:** OPEN (started 2026-08-12; order-of-march item 5 continuation,
stream #693 per the stream-8 exit handoff).
Branch `impl/I5-stream21-schema` off `design/651-516-partition`
(cut at ff546063 — the #783 consolidation merge atop the stream-8
exit-merge 84306188).
Governing spec: `schema_event_evolution.md` — letters **L146–L154 inside
the S3 batch RULED (a) 2026-08-05 (letters 122–154)**.
RULED-token anchors = the S3 exit row in `partition_campaign_PLAN.md`
(decision log 2026-08-05, "WAVE S3 EXITED — letters 122–154 ruled (a)"),
stream-21 fragment: "payload version vocabulary + caller/Lane-2
upcasters at stream 8's pre-fold seam; fold determinism widens to the
quadruple w/ chain-in-env + fold-id-carrying snapshots + the cover rule
read as current-fold — closing a real data-loss path; migration = the
representational FOURTH relation, never a correction; pure migrations
are stream-5 computations, impure migrations FORCED OUT to stream-6
commands; `[schema-lineage]` Lane-2 claims w/ unique-path enforcement;
the three-valued `compat?` predicate behind stream 16's repairs;
tolerance = discovery-surfaces-only w/ visible skip counts; wholly
post-I1 additive; #716". The spec's own §9 rulings ledger records
146–154 with the spec-edit map as part of the ruled text.
Issues: #693 (stream); #716 rides (the eight-item evidence-sweep
register — hygiene batch L154).

**Epoch posture (audit C1, spec header):** POST-I1 ADDITIVE with the
ONE reserved I1 slot ALREADY EXECUTED — journal.md §4.8 reserves
`fold-id?` inside the `snapshot-canonical` SIGNED preimage from the I1
epoch onward, omitted-while-unset (verified shipped: journal.md:1134
carries the slot in the preimage form; :1161–1166 states the
reservation + why — a trusted mismatch check must not read a forgeable
unsigned field). This stream FILLS the slot; no new signing epoch, no
Tier-1/Tier-2 address moves, no canonical-byte changes. Everything else
is composition over existing hashed artifacts: upcasters are pure
read-side projections; version tags are PAYLOAD vocabulary
(caller-owned Tier-1 data); `[migrated-from]`/`[schema-lineage]` are
Lane-2 claims; error rows are additive in the registered 4640–4649
band.

## Standing constraints

- Spec-first; NO spec edits without a recorded ruling (RULED: tokens on
  spec+impl commits; fragments must grep in `partition_*.md`). The §9
  spec-edit map of `schema_event_evolution.md` IS ruled — each executed
  edit cites its letter: journal.md (upcaster-seam §, fold-id-filled
  snapshots, cover-rule current-fold reading, CXER4640 row), store.md
  (migrate/modify-doc cross-refs), schema.md (compat § + lineage
  cross-ref), governance §9.1 (version-tooling promise honesty),
  xap_feature_distribution_market.md + 13-comparison (VERIFIED ALREADY
  EXECUTED at S3 — verdicts 6/7 below), the PLAN row pointer correction
  (L153), stream-4 handoff (vocabulary negotiation = the feature-token
  model — stream 4 exited; verify the handoff text stands, no edit).
- Every wave ends green on the full gate — `make test` launched UNPIPED,
  full log, `GATE-RC=$?` propagated, verdict read FROM the log, with
  PRE/POST HEAD guards (rev-parse in the gate log) per the
  shared-checkout rule; probe reflog+status before every git mutation;
  explicit-path staging only.
- Wipe `/tmp/v_501` WITH `/tmp/cxc*` before gates whenever fresh
  symbols landed — the #572 stale-layer class can defeat the in-gate
  cache-free retry, and a stash-bisect MISLEADS by re-matching the
  stale cache (stream-8 W5 cost).
- Fixtures ride WITH their machinery wave, never after; fixture-first
  for every defect-shaped change (#716 items each get their fixture
  before their fix).
- Cutover-first, no dual-accept; never true a spec to a shortfall; no
  deferrals without a named landing.
- Fable 5 only; push per landing; exit-merge IS an exit step.
- Triage gate flakes by standalone re-runs BEFORE suspecting the stream
  diff (fabric+http usecache FAILs green on in-gate #572 retries every
  run; net_udp_read_deadline is load-flaky-retry-green; #779
  rotation-vs-fold is load-sensitive and pinned to #692; io temp-dir
  pid-recycling false-reds — clean /tmp/cxc* + /tmp/cx-lazy-page-*
  before suspecting the diff, #781; store_lazy_load classified #781).
- Stream-8 fixture-authoring gotchas in force: brackets inside `[; …]`
  comments are LIVE syntax (interval notation broke a whole file — use
  [# #] raw blocks); `[first $binding]` in a ?let RHS CONSTRUCTS an
  element — select off the bound sequence directly; strings that look
  numeric emit QUOTED in canonical attrs — probe out-texts, never
  draft them; the citation-hygiene gate catches "decision"+"record(s)"
  adjacent AND its own acronym in hyphenated prose ANYWHERE in the
  live tree; guide-check requires fn-doc examples backed VERBATIM by a
  conformance fixture; cxparse_full_corpus_diff baseline moves with
  every [doc]-in-cx fixture — bump in the SAME commit.
- G3 graduation of `schema_event_evolution.md` is OWNER-GATED — never
  attempted here. The working spec stays in `02-working/`; normative
  cross-edits into approved specs execute per the ruled §9 map.

## Pre-open recon verdicts (2026-08-12, probed live this session)

1. **The L146–L154 register VERIFIED.** `schema_event_evolution.md` §9
   carries the full rulings ledger ("ruled (a) 2026-08-05 under the
   standing acceptance ruling") including the spec-edit map; the PLAN
   S3-exit row (2026-08-05) records the stream-21 fragment quoted in
   this ledger's header. #716 (the hygiene batch, L154) is OPEN with
   the eight-item register intact.
2. **The pre-fold seam VERIFIED SHIPPED exactly as consumed.**
   `jrn_temporal_project` (stdlib_journal.v:2685) is the generic pure
   entry-seq → entry-seq stage ahead of the reducer; the code comment
   at :2662 and journal.md §3.8 (:901) both state "stream 21's
   upcasters take the same seam". Composition points live at the fold
   funnel and the read/replay/slice surfaces (:1855, :2899, :4706,
   :4731, :4843, :4882). The ruled order is **upcast ∘ THEN the VT
   projection** (an upcaster may synthesize valid-time vocabulary for
   entries that predate it) — the upcaster stage composes BEFORE
   jrn_temporal_project at each site.
3. **The fold-id reservation VERIFIED EXECUTED AT I1.** journal.md
   §4.8's `snapshot-canonical` preimage carries `fold-id=<string>?`
   (:1134), reserved-from-I1 omitted-while-unset (:1161–1166), with
   the CXER4640 mismatch check named at :1165. The 4640–4649 band is
   REGISTERED to this stream in governance §9.6 (:435, sub-partitioned
   2026-08-05 from stream 20's 4617–4649). The quadruple + snapshot
   work here fills a reserved slot — never a new epoch.
4. **The compat predicate (L149) is SEQUENCED OUT to a named landing
   BY THE RULED TEXT.** `compat?`/`cx schema compat` is "sequenced
   behind stream 16's L65/L66 validator repairs (I5) — a checker over
   a fail-open validator would be theater". Stream 16's impl stream is
   #688, AFTER this stream in the order of march (#693 → #692 → #681
   → #682 → #688 → #690 → #689). The named landing = #688 (or its
   immediate rider); this is ruled sequencing, not a deferral. What
   DOES land here from L149: the `[schema-lineage]` Lane-2 claim shape
   + unique-path-or-reject registry-load enforcement (fail-closed),
   which the predicate later consumes.
5. **#716 item 4 PENDING, located.** `data_bin_schema_driven.v:299`
   compares `ver != schema_dialect_version` (:40, the string '0.8') —
   hard string equality against schema.md's `<semver>`; `0.8.0` would
   S020. Fixture-first semver-aware fix rides the hygiene wave.
6. **#716 items 3+7 spec-side VERIFIED ALREADY EXECUTED at S3.** The
   market spec's citation now points at `schema_event_evolution.md`
   (xap_feature_distribution_market.md:415 — "the former xap.md §14.4"
   phrasing shows the repair); 13-comparison.cxd's evolution cell
   already reads the ruled story ("Identity is schema-independent …
   migration is always additive"). What remains of item 3 is the
   FIXTURE obligation (downgrade-skip WITH visible count vs
   silent-skip negative — the §8 corpus row) at whatever surface the
   skip materializes (the journal tolerance machinery, W4).
7. **#716 item 5 PENDING, located.** governance §9.1 still promises
   "requires migration tooling" for major versions with nothing behind
   it; `[?cx version=X.Y]` consumed nowhere. The ruled repair: the
   promise is made honest by this stream's machinery (the §9 map's
   "version-tooling promise honesty" edit) — pointed at the ruled
   migration story, or amended where the machinery genuinely does not
   reach grammar-major migrations (upcasters/migrations act on VALUES
   and events, not grammar). Authored in W5 against the ruled text.
8. **#716 item 8 / L153 target located.** PLAN decision-log row dated
   2026-08-04 (:195) carries the "inventory NOT-FOUND #6 promoted"
   pointer; the ruled correction: the pointer describes items 2/7
   (store as-of was ratified OUT by stream 8). Corrected in-place with
   a dated bracketed annotation citing L153 (the registry-repair row
   precedent for amend-in-place), W5.
9. **Greenfield check clean.** No `upcast`/`schema-lineage`/
   `migrated-from` recognition anywhere in vcx; journal.md's only
   upcaster text is the §3.8 seam sentence. The vocabulary lands
   clean; no retirement sweep needed.

## Wave plan

- **W1 (L146 + L151): the upcaster seam + coverage honesty.** The
  caller-supplied upcaster chain as a pure entry→entry projection
  composed at every seam site BEFORE the VT projection (upcast ∘ VT);
  payload version vocabulary is read-side recognition only (append
  never parses payloads — §2.3 byte-identical stands); an entry no
  upcaster covers = failure-channel `[err]` at fold time naming seq,
  hash, declared version, chain endpoints — never absence, never a
  skip; the coverage pre-flight as a pure query (declared versions ×
  chain) converting mid-replay aborts into pre-execution diagnostics.
  `verify` stays syntactic; `coherence` owns coverage findings.
  Fixtures: upcast-before-VT order pin; v1-entry synthesis of VT
  vocabulary; uncovered-entry loud err; pre-flight pair.
- **W2 (L147 + #716 items 1/2): fold identity + the snapshot repair.**
  Fold determinism as the quadruple (entries, chain, $fn, $init); the
  chain identified by its Tier-1 source address (Tier-2 rides for
  cache — the stream-5 dual form, no invented chain-hash); the chain
  identity in the ENV quadrant of computation records; snapshots CARRY
  fold-id (fn ⊕ chain ⊕ env as a computation address) filling the
  reserved signed-preimage slot; `fold-from` mismatch = CXER4640 loud
  typed error; the equivalence fixture becomes
  conditional-and-checkable (item 1's blindness fixed fixture-first);
  the retention cover rule reads covered-under-the-CURRENT-fold —
  re-snapshot under v2 before a v1-anchored prefix may be pruned
  (item 2's data-loss path closed, positive + negative fixtures).
- **W3 (L148 + L152): stored-doc migration.** `[migrated-from
  hash=<address>]` as a Lane-2 claim (the [supersedes] hash-linkage
  discipline REUSED — no second linkage vocabulary); migration = the
  representational FOURTH relation — never in the correction taxonomy,
  never alters valid time; the discriminator fixture (folds unchanged
  by a migration entry; changed by a correction); pure migration as a
  stream-5 computation (addressable, cacheable); an impure migration
  is NOT a computation — stream-6 command with [effects]/[idempotent]/
  dedup key (the M5 split family: pure half as computation, impure
  half refused-as-computation + rerouted); journals migrate on READ,
  stores migrate in BATCH (read-time doc projection without a put is
  permitted, never the default); store.md cross-refs per the map.
- **W4 (L149-lineage + L150): lineage claims + tolerance, scoped.**
  `[schema-lineage [from …] [to …] [relation
  :additive|:narrowing|:split|:merge] [upcaster …]]` Lane-2 claims
  (the type-binding shape); unique-path-or-reject at registry load,
  fail-closed (ambiguous-graph rejection fixture); the
  discovery-vs-semantic tolerance rule with the downgrade-skip
  exception carrying VISIBLE skip counts (count + attribution, in the
  value, at the point of omission — the stream-8 redaction-count
  device reused; silent-skip negative fixture). The compat predicate
  itself: NOT here (verdict 4 — ruled sequencing to #688's landing).
- **W5 (L153 + L154 hygiene batch): the #716 residue.** Item 4
  semver-aware schema-version acceptance (fixture: 0.8.0 validates;
  a real major mismatch still refuses loudly); item 5 governance §9.1
  honesty per verdict 7; item 8/L153 the PLAN pointer correction per
  verdict 8; journal.md upcaster-§ + schema.md lineage cross-ref
  completing the ruled edit map.
- **W6: exit.** Exit audit against the §9 map + the §8 corpus-handoff
  register (stream 14's M5 substrate rows each delivered or at a named
  landing); #716 closed with per-item evidence; #693 closed; exit gate
  GATE-RC=0 with HEAD guards; exit-merge to design/651-516-partition;
  memory + handoff notes (stream 14 corpus; #688 compat landing;
  stream 20 #692 shred-generations consume fold-id — next in march).

## Wave record (all executed 2026-08-12)

- **W1 @ fb2826fe** — the upcaster seam ({upcast: $chain} on fold+replay
  via ONE jrn_upcast_stage composition point, upcast-THEN-VT; pure
  `upcast` verb; `schema=` reserved payload vocabulary §2.10 + cxdm
  §2.4; CXER4641/4642; coherence coverage pre-flight w/ :uncovered-entry
  findings — coherence moved to the env funnel). Fixtures
  journal-118..121. Gate s21_w1_gate2.log GATE-RC=0 (first run
  GATE-RC=2: the fixtures' user-domain refusal code was CXER-shaped —
  CXER1000 — and the registry gate flags any unregistered CXER token in
  fixture files; domain codes must be non-CXER strings).
- **W2 @ ab4a3fe4** — fold identity (the quadruple; fold-id fills the
  reserved signed-preimage slot; CXER4640 on declared mismatch OR
  identity-less snapshot; upcast over the fold-from tail; retain's
  covered-under-the-CURRENT-fold reading; SET form refuses fold-id —
  no reserved slot). Fixtures journal-122..124. Gate s21_w2_gate.log
  GATE-RC=0 w/ clean HEAD guards but ADVISORY (W3 fixture edits landed
  mid-gate in runtime-read files); re-validated by the W3+W4 gate.
- **W3 @ 2386a48b** — stored-doc migration on shipped mechanics
  (modify-doc + pure [using FN] = THE migration primitive; batch,
  non-destructive, dedup-free re-migration; [migrated-from] Lane-2
  claim value; the fourth-relation discriminator journal-125 +
  store-mig-001; store.md §6.2 cross-refs; migrate = replication).
- **W4 @ bd6b6785** — lineage claims + `lineage-path` (the fail-closed
  registry load: duplicate edge / cycle / any two-path pair = CXER4643;
  unique path in composition order; no path = CXER4644; DIRECTED).
  Fixture journal-126; schema.md §2 revisions-are-identities cross-ref.
  Binding W3+W4 gate s21_w34_gate.log GATE-RC=0, HEAD guards clean.
- **W5 @ e0d46cb2** — the hygiene batch: #716 item 4 (semver-honest
  dialect acceptance, major.minor identity; sv-059a/b/c fixture-first;
  schema_validate 70/70), item 5 (governance §9.1 promise honest),
  item 8/L153 (the PLAN pointer corrected in place, dated); the
  semantic_value_model §3 E2 lineage cross-ref (last ruled-map residue).

## Exit audit (W6) — every ruled item executed or at a named landing

| Ruled item | Disposition |
|---|---|
| L146 seam + payload vocabulary + upcast∘VT + today's-chain | EXECUTED W1 (journal-118/119; §2.10/§3.9/cxdm §2.4) |
| L147 quadruple + fold-id snapshots + CXER4640 + cover current-fold | EXECUTED W2 (journal-122/123/124; §3.7/§4.8/§4.9/§8). The env-quadrant additivity statement holds through the fold-id's inputs (fn ⊕ chain ⊕ env); a fold-result computation-cache surface (where the chain would ride a cached record's env) is not shipped and was not a ruled edit (computation_identity.md is NOT in the §9 map) |
| L148 migrated-from + fourth relation + pure-as-computation / impure-out | EXECUTED W3 (journal-125, store-mig-001; store.md §6.2); the pure/impure M5 split CORPUS family = stream 14's substrate (§8 handoff, named landing) |
| L149 lineage claims + unique-path load; compat? | Claims + load EXECUTED W4 (journal-126; CXER4643/4644; schema.md §2); `compat?`/`cx schema compat` SEQUENCED OUT BY THE RULED TEXT behind stream 16's L65/L66 validator repairs — named landing #688 (next-but-two in the march) |
| L150 discovery-vs-semantic tolerance + downgrade visible counts | Spec EXECUTED at S3 (market §8-item-3 text verified: visible counts + discovery-only + repaired citation); no downgrade replay impl surface exists — the fixture pair rides the market impl / stream-14 corpus rows (named landing) |
| L151 uncovered = failure-channel err + coverage pre-flight | EXECUTED W1 (journal-120/121; CXER4641; coherence {upcast:}) |
| L152 journals-read / stores-batch + projection-not-migration | EXECUTED W3 (store.md §6.2; the journal read side IS the W1 seam) |
| L153 post-I1 + the plan-row pointer correction | EXECUTED W5 (dated in-place bracket on the 2026-08-04 row) |
| L154 hygiene batch (#716) | items 1+2 W2; 3 S3-verified (+fixture at the named landing above); 4+5+8 W5; 6 = L150 ruling; 7 S3-verified — ALL CLOSED |
| §9 spec-edit map | journal.md (W1/W2/W4) ✓; store.md (W3) ✓; schema.md lineage (W4) + dialect sentence (W5) ✓ (compat § → #688); cxdm (W1) ✓; semantic (W5) ✓; market + 13-comparison (S3, verified) ✓; governance §9.1 (W5) ✓; PLAN row (W5) ✓; stream-4 handoff VERIFIED PRE-EXECUTED (xsp_store_profile §3 transcript-covered negotiation, L164 — stream 4 exited with it) |
| §8 corpus handoff | stream 14's M5 substrate: add-a-field / SPLIT / 10k-replay / compat three-valued / downgrade-skip pair / pre-flight pair / ambiguous-graph / migrated-from discriminator — the machinery for each is SHIPPED here (or at #688 for compat); the families land with stream 14 (named landing) |

Out-of-scope remainders, each at a named landing: `compat?` + export-verdict
(#688 after the L65/L66 repairs); the downgrade replay surface + its
visible-count fixture (market impl / stream 14); the M5 corpus families
(stream 14); fold-result computation-cache integration (additive, unruled —
no landing owed); #782 (query predicate subset — filed by stream 8, open).

Gotchas recorded this stream: fixture user-domain err codes must be
non-CXER strings (the registry gate scans fixture files; CXER-shaped
domain codes fail STRICT); `[$count $binding/path]` over an INLINE path
answers 0 — bind the read first, count the binding (the stream-8
bind-first discipline extended to counts); `?if` takes explicit
[then]/[else] wrappers; a chain fn returns `[entry seq= hash= [event …]]`
ONLY (constructing ts=/prev= off a genesis entry CXER0100s on the empty
prev); NEVER edit runtime-read files (fixtures/specs) while a gate runs —
the W2 gate was demoted to advisory for exactly this.
