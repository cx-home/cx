# I5 stream 7 — consistency vocabulary: implementation ledger

**Status:** OPEN (started 2026-08-11; order-of-march item 5 continuation,
stream #679 per the stream-6 exit handoff).
Branch `impl/I5-stream7-consistency` off `design/651-516-partition`
(cut at ecae77aa — the stream-6 exit-merge).
Governing spec: `consistency_vocabulary.md` — letters **L122–L128 inside
the S3 batch RULED (a) 2026-08-05 (letters 122–154)**, with the one
recorded strengthening applied at recording: the error band moved from
the sweep's proposed XAP-occupied 4850+ to the verified-free
**CXER4990–4999**.
RULED-token anchors = the S3 exit row in `partition_campaign_PLAN.md`
(decision log 2026-08-05, "WAVE S3 EXITED — letters 122–154 ruled (a)"),
stream-7 fragment: "closed atom lattice —
prefix-consistent/at-seq-pinned/at-head-set-as-the-honest-CUT/
linearizable-ref/read-your-writes/monotonic+gapless/at-least-once;
`:exactly-once` permanently refused NAMING [idempotent]; `:serializable`
refused NAMING stream 10; two attachment points w/ generation-bound
pre-flight, NO def clause; conjunct lattice not a level ladder; F1–F8
register #714 — sharpest: journal `head` is a pure read of a
handle-cached position; replica profile handed to stream 9".
Issues: #679 (stream); **#714 (the F1–F8 silent-degradation register)
LANDS HERE** — its six numbered items map onto F1–F8 and close with this
stream's evidence (item 5, the docs-src `Transactional`/ACID amendment,
is ALREADY EXECUTED in the tree — verified pre-discharged at recon).

**Epoch posture (spec "Identity-epoch membership", audit C9):** ADDITIVE
— this stream owns no I1 manifest row and joins no epoch. Guarantee
tokens, declarations, adverts, and refusals are config/wire data and new
error rows; verification reads existing E3 positions and head-sets.
Nothing here defines, moves, or re-spells a Tier-1/Tier-2 address, a
canonical byte, or a journal preimage.

## Standing constraints

- Spec-first; NO spec edits without a recorded ruling (RULED: tokens on
  spec+impl commits; fragments must grep in `partition_*.md`). The §10
  spec-edit map of `consistency_vocabulary.md` IS ruled — each executed
  edit cites its letter: journal.md §4.4 (tokens + fresh-head verb +
  fold annotation); store.md §5/§6 (advert + refusals); fabric.md
  (plane tokens + drop counts — landed at the semantically right
  sections, specs-loosely-coupled); xap/xsp.md §5.3 (resume guards);
  governance §9.6 (the 4990 band row); docs-src cxstore architecture
  (amendment — PRE-DISCHARGED, verified in tree); stream-3 surfaces
  (observe/materialize/changes-since declare through the same opts —
  coordinated in-wave).
- Every wave ends green on the full gate — `make test` launched UNPIPED,
  full log, `GATE-RC=$?` propagated, verdict read FROM the log.
- Fixtures ride WITH their machinery wave, never after; fixture-first
  for every defect-shaped change (#714 items get their discriminator
  pair RED before the fix).
- Cutover-first, no dual-accept; never true a spec to a shortfall.
- Fable 5 only; push per landing; exit-merge IS an exit step.
- Triage gate flakes by standalone re-runs BEFORE suspecting the stream
  diff (fabric+http usecache FAILs green on in-gate #572 retries every
  run; net_udp_read_deadline is load-flaky-retry-green; #779
  rotation-vs-fold is load-sensitive and pinned to #692).
- Stream-6 gotchas in force: cxparse_full_corpus_diff baseline moves
  with every [doc]-in-cx fixture — bump in the SAME commit (baseline at
  stream entry: 769/604); the profile gate grades code.cxd in the EMBED
  profile (io pack OFF) — core fixtures use profile-invariant prims;
  guide-check requires [fn-doc] on every new public stdlib def; authz
  fixtures use [?fallback EXPR [recover-with V]] / [?test-clock
  advance=]; canonical attr emit does not quote hyphenated ids; V has
  no if-expr in `for x in …` position and loop-struct fields need
  `mut:`.
- G3 graduation of `consistency_vocabulary.md` is OWNER-GATED — item-6
  handoff packet, never attempted here. The working spec stays in
  `02-working/`; normative cross-edits into approved specs execute per
  the ruled §10 map.

## Pre-open recon verdicts (2026-08-11, probed live this session)

1. **#714 F1–F8 register state: OPEN, six numbered items, fixes
   assigned here.** Item 1 = F1 (pure cached `journal head` —
   journal.md:531 + §4.6:846 confirm `head` is pure over the
   handle-cached head; the defect is REAL in the shipped text). Item 2
   = F2 (observe-mode resume unguarded — xap/xsp.md §5.3 Reconnect-
   resume is the landing; observe subs are the "pre-§5 replay contract"
   unbounded path). Item 3 = F3 (CSRP capability profile cached across
   config-reload — cxstore-remote-protocol.md; adverts must bind the
   config generation). Item 4 = F5 (expect-less alias writes silently
   LWW — store.md:427 `CXER1114` exists for the CAS path; the
   declared-handle refusal is new). Item 5 = F1's docs twin, **ALREADY
   AMENDED**: docs-src/canonical/cxstore/architecture.md:33 + :59 carry
   the "AMENDED (stream 7 L127, #714)" strikethrough text — this
   spec-edit map row is pre-discharged; the #714 close comment cites it.
   Item 6 = F7+F8 (transient-plane drop counts; tenant-wide fold
   annotated not-a-cut).
2. **The `[idempotent]` cross-reference is SHIPPED and nameable.**
   code.md §12.2.7 (grammar [152a], stream 6) defines
   `[idempotent ([window DUR])?]`; the `:exactly-once` teaching refusal
   names it. The `:serializable` refusal names stream 10 (#682) —
   fabric.md §16 already carries the "No exactly-once" posture line, so
   the refusal text agrees with the shipped corpus.
3. **Journal head purity confirmed at both spec sites.** journal.md
   §4.6 ("`head` and `fold-value` are pure — operate on the handle's
   cached head") and §2 (:531 "pure — reads the cached head off"). The
   L126 resolution: the purity is KEPT and STATED (head satisfies
   neither read-your-writes nor freshness declarations); the
   declared-fresh head is a DISTINCT impure verb spec'd with this
   stream. §4.4 (Read consistency under concurrent append, :813) is
   the token-vocabulary landing site.
4. **CXER4990–4999 verified FREE in governance §9.6** (registry's
   highest 49xx rows: 4900–4901 similar, 4920–4949 fabric, 4970–4989
   sched; nothing at 4990+). The two codes: `CXER4990
   E_CONSISTENCY_UNSATISFIABLE` (declared token + surface + the
   surface's actual guarantee set), `CXER4991
   E_CONSISTENCY_PIN_UNCOVERABLE` (pin no longer resolvable AFTER the
   resolve-through-covering-snapshot rule — mirrors the CXER4606/4615
   impossible-vs-diverged split).
5. **Isolation vocabulary is GREENFIELD in the corpus** (the spec §1
   finding holds at recon: no `prefix-consistent`/`linearizable`/
   `read-your-writes` tokens anywhere in vcx or the approved specs
   outside the ruled working spec) — no retirement sweep needed; the
   closed set lands clean.

## Wave plan

- **W1 (this entry):** branch + ledger + recon verdicts committed.
- **W2 — the vocabulary core (L122/L124/L125):** the closed token set
  as ONE authority (parse/validate; unknown token = typed error);
  CXER4990/4991 + governance §9.6 band row; journal.md §4.4 token
  vocabulary + journal handle-floor declaration (open/attach
  `consistency=` opts checked ONCE at declaration against the surface's
  guarantee set) + per-read pins (`at-seq`, head-set, cursor);
  refusal shape = D-C1 (failing STAGE + failing TOKEN);
  `:exactly-once` → refusal naming `[idempotent]`; `:serializable` →
  refusal naming stream 10. Discriminator pairs per journal-satisfiable
  token ride the wave.
- **W3 — the journal findings (L126: F1, F8):** the declared-fresh
  head verb (distinct, impure); F8 tenant-wide fold annotated
  not-a-cut at the verb; the stale-`head` discriminator pair (F1);
  journal.md §4.4/§4.6 edits.
- **W4 — store + CSRP (L126: F3, F4, F5; L123 floor):** store open-opts
  advert + refusals (store.md §5/§6); declared `:linearizable-ref` ⇒
  expect-less alias writes + `branch-force` error on the declaring
  handle (F5); ref-caching refusal under declared
  `read-your-writes`/`linearizable-ref` (F4 — spec'd now, layer
  unbuilt); adverts bind the config-reload generation (F3, CSRP
  pre-flight); `:read-your-writes` writer-scoped inside the CXER1116
  self-heal window (F6 — the one normative sentence).
- **W5 — fabric + XSP + stream-3 surfaces (L126: F2, F7; L123):**
  fabric subscribe plane tokens (`:at-least-once` durable /
  transient refuses it) + per-subscription drop COUNTS reported (F7);
  XSP observe-resume guards — `:monotonic-reads`/`:gapless` checked
  server-side against the requested cursor + retained tail,
  retention-pruned `from=` refuses (F2, xap/xsp.md §5.3); stream-3
  observe/materialize/changes-since declare through the same opts.
- **W6 — M5 substrate + exit (spec §9):** the corpus handoff pairs
  end-to-end — the multi-stream no-cut vs `:at-head-set` pair (the M5
  invoice+inventory join); pin-below-retention
  resolve-through-snapshot-then-refuse; the stream-9 replica
  declaration profile handed off as vocabulary (spec §8 — no replica
  impl here, stream 9 is #681); exit audit (every ruled §10 map row
  executed or verified pre-discharged); #714 close comment w/
  evidence; exit gate; exit-merge.

**Out-of-scope at named landings:** serializable cross-stream
coordination → stream 10 (#682); replica reads / conflict values →
stream 9 (#681); `valid-at` is stream 8's query parameter (the two axes
never fuse); `?cache=` layer construction (F4 rules the refusal only).

## Wave log

### W1 — entry (2026-08-11)

Branch cut at ecae77aa; recon verdicts above; #714 item-5 (docs
amendment) verified pre-discharged in tree.

### W2 — the vocabulary core (2026-08-11)

**Landed (RULED: 122-154 / L122+L123+L125):**

- `vcx/platform/consistency_vocab.v` — THE one token authority (a second
  token list or refusal shape anywhere is a drift hole): the L122 closed
  set (ten atoms; `snapshot-isolation`/`causal`/`eventual` OUT entirely,
  `valid-at` never a consistency token); `cst_read_declared` (the
  `consistency` opts key, one atom or a `(…, …)` sequence, TYPE-STRICT —
  a string spelling of a valid token refuses at stage `vocabulary`, so a
  quoted near-miss can never silently declare); `cst_check_floor`
  (scrutiny order per token: closed-set membership → the two teaching
  refusals → the advert); refusal constructors carrying the D-C1 naming
  as structured `[context …]` children (stage/token/surface/guarantees/
  answer for CXER4990; stage/token/surface/requested/floor/
  resolve-through for CXER4991) so fixtures assert the naming as DATA,
  not by message-grep.
- Journal floor (L123): `open`/`attach` validate the declared tokens
  ONCE against `jrn_guarantee_advert` (prefix-consistent, at-seq-pinned,
  at-head-set, monotonic-reads, gapless; + read-your-writes over
  mem/file backends only — the store-advert refinement is W4's); the
  handle element echoes the floor (`consistency=` attr; undeclared
  handles byte-identical). A `compact` target is an OPEN — compact opts
  carry the same `consistency` key as the segment handle's floor.
- Per-read guards (L122/L125): the `replay`/`snapshot` at-seq pin is
  ALWAYS-ON (a pin IS a declaration) — on a retention-pruned chain it
  refuses CXER4991 naming requested + floor + the resolve-through path,
  never a silent fold from the seam; under a declared `:gapless` floor
  an explicit-`from` read (`slice`/`since`/`replay from=`) below the
  retained floor refuses the same way (`source` reads the retained
  suffix BY CONTRACT and is not an explicit-from read — spec-worded).
- Teaching refusals (L122): `:exactly-once` → CXER4990 with
  `[answer '[idempotent]']` (the shipped code.md §12.2.7 clause named);
  `:serializable` → `[answer 'cross-stream coordination (stream 10)']`.
- Spec edits per the ruled §10 map: journal.md §4.4 (the two attachment
  points + the closed-set discipline + the pin/gapless guards);
  governance §9.6 row `CXER4990–CXER4999 | cx-core/consistency`
  (registered before first use, per invariant).
- Fixtures journal-089..097 (discriminator-pair style; header id-range
  block extended). `scripts/cxer_registry_report.sh --strict` RC=0
  (s7_w2_cxer_report.log); no cxparse baseline movement (all new
  fixtures are `[empty]`-in-cx); no new public defs (guide-check
  unaffected).

**The RED proof (fixture-first, impl stashed and suite re-run on the
pre-change tree — 9/9 new fixtures fail with the SILENT behaviors the
vocabulary exists to close):**

- journal-090..094: opens SUCCEED SILENTLY under an unadvertised /
  unknown / string-spelled declaration (the `consistency` key was
  ignored wholesale — the F-class in the flesh).
- journal-095: `[pair pinned-at2=2 1]` — the pinned replay on the
  compacted segment answered **1** where the true state at seq 2 is
  **2**: the silent wrong answer, exactly as booked.
- journal-096: a **SIGNED snapshot of a wrong state** — `[state 2]`
  (folded from the seam) where the chain's true state at seq 3 is 3,
  signed sig-algo=none as a real artifact.
- journal-097: the undeclared segment silently clamps (n=2), preserved
  as the legacy arm of the pair.

GREEN after restore: code.cxd + stdlib fixture suite 2794 pass /
0 enforced failures. Full gate: s7_w2_gate.log GATE-RC=0.

### W3 — the journal findings: F1 fresh-head + F8 not-a-cut (2026-08-11)

**Landed (RULED: 122-154 / L126; #714 items 1 + 6):**

- **F1, both halves.** `head` KEEPS its declared purity and gains the
  honest statement (journal.md §3.3 + §4.6 restated): it answers the
  handle's CACHED view — coherent within one process (shared-root
  sibling advances fold in forward-only, the #628 rule) — and makes NO
  freshness claim; under a second writer it MAY report a stale position
  with no signal; it satisfies neither `:read-your-writes` freshness
  nor a declared-fresh need. **`head-fresh`** is the distinct, IMPURE
  verb (§3.3 + `[?def]` + fn-doc): it re-resolves the durable head
  through the SUBSTRATE — mem:// answers the live instance;
  remote-active backings already read the daemon's table per op; a
  read-only LOCAL handle (the private-snapshot views, exactly where the
  silent-stale class lives — the supported cross-process shape is one
  writer + N read-only) re-TAKES its view from disk through the normal
  capability-gated open path (`store-open-opts` scratch reopen +
  `store_swap_read_view`, both directions, scratch closed through the
  ordinary path so the OLD view's resources release normally; a cap
  denial or integrity refusal propagates loudly). Read-through then
  serves the new entries.
- **F8 at the verb.** fold/streams fn-docs + journal.md §3.4 carry the
  not-a-cut annotation: per-stream heads snapshot independently, no
  cross-stream linearization is claimed — the verifiable multi-stream
  READ coordinate is `:at-head-set` (the §3.7 signed head-set);
  committing across streams is stream 10's entirely.
- **W2 advert repair (found by this wave's recon):** a bare `file://`
  journal store resolves to the cxpack backend (subtree default), so
  the W2 `['mem','file']` locality list OVER-REFUSED
  `:read-your-writes` on the real file substrate —
  `jrn_guarantee_advert` now reads mem/file/cxobj/cxpack (and never a
  remote-active handle). Pinned by the V test.
- Tests: `journal_head_fresh_test.v` — the F1 stale/fresh discriminator
  PAIR over a real file (cxpack) substrate: writer appends past a
  read-only sibling's snapshot; `head` on the reader asserts the STALE
  seq (the stated degradation, documented not hidden); `head-fresh`
  asserts the durable head AND the refreshed view serves the new entry;
  plus the cxpack `:read-your-writes` floor-accept pin. Fixture
  journal-098 (mem contract; cached==fresh on the live instance),
  backing the fn-doc example verbatim (guide-check OK, 46 modules —
  s7_w3_guidecheck2.log).
- Gotchas found live: paths do not parse off a call result (`[$f
  $x]/@seq` is CXER0100 — bind first); `[first EXPR]` in body position
  CONSTRUCTS an element named `first` (attrs must use the bare
  attr-position path, scalar-only); V multi-assign cannot swap maps
  (`.move()` + mut temps); io.cxd temp-dir fixtures can collide with
  stale `/tmp` dirs across repeated local runs (pid recycling) — clean
  before suspecting the diff.

Full gate: s7_w3_gate.log GATE-RC=0.

### W4 — store + CSRP: floor, F5, F4/F6, F3 (2026-08-11)

**Landed (RULED: 122-154 / L122+L123; #714 items 3 + 4):**

- **Store handle floor (L123):** `open-opts` `consistency` key through the
  ONE authority; advert = `:linearizable-ref` + `:monotonic-reads` +
  `:read-your-writes` (local backings and SERVICE-TIER remotes — every
  read routes to the daemon per op; byte-source remotes refuse it);
  handle element echoes the floor; refused opens close the scratch
  handle. store.md §5.2 authored (the floor + advert + F4 + F6).
- **F5 (#714 item 4):** a declared `:linearizable-ref` makes expect-less
  ref writes ERRORS on that handle — `set-alias` (local AND objwire
  arms), `delete-alias` (no expect-bearing form exists), `branch-force`
  (unconditional advance) each refuse CXER4990 at stage `write` naming
  the token and the sanctioned forms; plain `branch` stays available
  (its fast-forward guard IS the CAS discipline). Undeclared handles
  byte-identical (the LWW pair pinned in-fixture).
- **F4:** ref-caching refusal RULED IN PLACE (store.md §5.2):
  immutable-objects-forever / refs-revalidate; a `?cache=` layer caching
  REFS under a declared `:read-your-writes`/`:linearizable-ref` refuses
  at open — today the `?cache=` URI parameter is already rejected as
  accepted-but-unimplemented (verified, store_open_impl §3 guard); the
  rule binds any future implementation.
- **F6:** the one normative sentence (store.md §5.2):
  `:read-your-writes` is writer-scoped inside the CXER1116 self-heal
  window — after a write-failed raise the open handle's in-process
  state stays authoritative until the next successful persist.
- **F3 (#714 item 3):** the capability advert BINDS the config-reload
  generation — `[config-generation N]` rides BOTH capability adverts
  (server-level + per-store; svc_config_generation_advert reads the
  live cfgbox, so the daemon can never serve a stale advert) and CSRP
  §3.1 states the client rule: a cached advert is valid only for its
  generation; a cached advert across `config-reload` is a cached lie;
  re-fetch on any generation change. `config-reload` (§3.13) already
  answers the same counter. Pinned:
  `test_capabilities_advert_binds_config_generation` (gen 0 on both
  forms → applied reload → gen 1). NOTE recorded: the CSRP client
  (RemoteBackend.caps_*) never actually fetches capabilities today —
  the #234.2 discovery comment is aspirational; the caching-lie class
  is closed at the advert + the normative client rule, and any future
  client-side pre-flight inherits the binding.
- Fixtures store-cst-001..004 (floor accept+echo; the F5
  LWW-vs-declared discriminator pair w/ branch-name positive +
  branch-force refusal; delete-alias refusal; the SHARED teaching
  refusal — one authority proven across surfaces). Suite 2799 green;
  store_service/store_g13_parity/store_wire_wave4/store_config_reload
  green standalone.

Full gate: the FIRST run (s7_w4_gate.log) was GATE-RC=2 on two
failures both triaged ENVIRONMENTAL by standalone re-runs (the standing
rule): io-083[bin] in the profile gate and store_lazy_load_test — both
the `/tmp` leftover-reuse class (io:temp-dir names `<prefix><pid>-<n>`;
pids recycle across process generations and nothing cleans, so a later
run reuses a stale dir and reads its contents). Green standalone after
cleanup; profile gate PG-RC=0 standalone
(s7_w4_profilegate_rerun.log). Root cause FILED as #781
(mkdir-fresh-or-retry is the fix direction). Clean full gate:
s7_w4_gate2.log GATE-RC=0 (only the two known usecache retry
artifacts).
