# I5 stream 9 — distributed store (implementation ledger)

**Branch** `impl/I5-stream9-distributed` off `design/651-516-partition`
(opened 2026-08-12 @ 454aa061, the stream-20 exit merge). **Governing
spec** `distributed_store.md` (letters 173–180 ruled (a) 2026-08-05).
**Issues:** #681 (the stream), #719 (the prerequisite defect batch — 5
items, closes here). **Live consumer:** the M5 offline replica (the §1
worked example: clerk + disconnected tablet). **Inherited joint
requirements:** stream-20 replica shred-reach (the spec's §6 receiving
block + the #681 comment), stream-7 replica declaration profile (§6,
M8), stream-4 object-wire ops (shipped — xsp_store_profile §7a).

## Shipped-state map (evidence sweep 2026-08-12, at 454aa061)

Every primitive ships in isolation; the stream builds the COMPOSITION
layer. SHIPPED: the one-engine transfer porcelain (pc_transfer —
objects + doc-refs, aliases never carried; bare `[<verb>-result
objects= refs=]` counters; `pull ≡ fetch` literally,
store_porcelain.v:365-379); status head-set (the #719-item-1 local
half, store_porcelain.v:501-540 — its own comment defers ahead/behind
to this stream); E3 per-ref lineage w/ dense per-stream positions
(store_objgraph.v:384-439); expect-pos/expect-root CAS CXER1114 +
validate-then-apply all-or-nothing batch on BOTH wires (XSP
sx_refs_set_locked/sx_aliases_set_locked; CSRP twins) + client
set_ref_cas (no non-test caller yet); the five object-wire op families
live both sides (objects-have/get/put, refs(-set), aliases(-set));
the signed head-set advert (store_xsp_advert.v — sx_guarantees is the
ORIGIN token set, its comment names the replica set as this stream's);
journal named streams + per-stream heads + head-fresh + the tenant SET
snapshot (`:at-head-set`); Ring-0 diff/patch w/ the §5 patch law
fixtured (cx.cxd 042-047); the XAP [conflict] + enforcing/reporting
agreement law precedent (stdlib_xap.v:3563/3715/3737); live
changes-since over head-set cursors w/ the loud below-retention
refusal (CXER5073; store twin CXER5020); store_feed_seed at open.
MISSING (the stream's work): journal stream INGESTION (jrn_append
re-hashes by design — no byte-identical re-land verb); any
store/journal [conflict] producer (subject/kind/base/ours/theirs/cas);
the fetch/pull split; status ahead/behind (needs a peer); the signed
seed composition (changes-since AT a signed head-set); cx:merge (spec'd
raise-on-conflict, zero impl, CXER4110 emitted nowhere); the
CXER5050–5069 band (no governance §9.6 row yet — register BEFORE first
use, pure sparse lists per the stream-20 W6.1 gotcha); replica
declaration profile; the shred-reach replica worker; the entire
divergence/sync corpus (the only stream-9-tagged fixture is
journal-117, a read case). #719's five items map onto waves 3/4/5
below.

## Wave plan

- **W1 — replica-local stream ingestion (L173):** the journal
  ingestion verb — a foreign named stream's entries re-land
  BYTE-IDENTICAL (entry hashes preserved, chains verify unchanged;
  tenant state = order-independent composition of per-stream folds);
  re-append-into-origin refused on the record (the three grounds; the
  band's first code); the governance §9.6 row for CXER5050–5069
  (registered before first use); journal.md ingestion § + stream-key
  naming note per the ruled edit map. Fixtures first: ingestion
  byte-identity + tenant-fold order-independence + the re-append
  refusal.
- **W2 — the conflict value + per-ref reconciliation (L175):** the
  Ring-0 `[conflict subject= kind=:diverged-advance [base][ours w/
  diff][theirs w/ diff][cas]]` producer at ref reconciliation; the
  normative common-base rule (greatest position sharing an entry
  hash); the discriminator pair (fast-forward APPLIES / diverged
  returns the conflict and applies NOTHING — partial success reported,
  never mixed silently); the enforcing/reporting agreement law (raise
  iff report ok=false); conflict-value round-trip (parse/canonicalize/
  hash/navigate/patch — a data-profile citizen).
- **W3 — merge-as-an-entry + resolutions (L174; #719 item 3):**
  reconciliation = an ordinary ref advance whose payload records the
  join (both tips + base as locator triples); resolutions re-enter as
  an input table on a later sync (pure, replayable — identical input +
  resolutions ⇒ identical end state); resolution-resume determinism;
  store.md §6.3 amended to the narrower truth; cx:merge implemented
  ALIGNED TO VALUES (conflict → the [conflict] value per policy, never
  a raise; the DAG refusal stays on the record).
- **W4 — the sync surface (L176; #719 items 4+5):** the fetch/pull
  split (fetch = objects + doc-refs only; pull = fetch + per-ref
  reconciliation); sync results become HEAD-SET-BEARING REPORTS
  (cutover-first — the bare-counter fixtures re-pin); bidirectional
  replica↔origin engines (in-process + over the shipped wire ops); the
  seed = changes-since at a SIGNED head-set (tampered-anchor CXER4615
  negative); idempotent re-sync (nothing new, no second conflict); the
  alias-plane asymmetry vs migrate documented (#719 item 5).
- **W5 — status/retention/declaration + shred reach (L177, M8, the
  stream-20 joint):** status ahead/behind as a per-stream HEAD-SET
  against a peer (#719 item 1); register-or-refuse retention (replica
  registration buys the cover-rule hold; client-anchored cursors below
  the compacted boundary get the loud re-seed refusal); the replica
  declaration profile (CAN :prefix-consistent/:at-seq-pinned/
  :monotonic-reads, MUST refuse :read-your-writes/:linearizable-ref —
  wiring-time refusals; the replica guarantee set beside
  sx_guarantees); the shred-reach replica worker (ingesting a
  cx:erasure record / erase act executes the LOCAL walk + emits the
  replica's own balanced report, idempotent under (subject,
  request-token)).
- **W6 — M5 end-to-end + hygiene + exit:** the §1 worked example as an
  end-to-end test (offline replica-local appends w/ valid-from → sync
  → the two-refs-moved conflict → resolution re-entry → the
  VT-precedes-TX read at {at-seq, valid-at}); the mem-expressible
  corpus slices (the full §7 program stays stream 14's handoff);
  edit-map residue sweep (journal.md, store.md, modules/cx.md,
  cross_stream_coordination §4 verified applied, consistency/live/
  bitemporal cross-refs); #719 all-items + #681 closure evidence; exit
  audit + full gate → stream exit merge.

Named landings (ruled, not deferrals): N-way ref reconciliation +
replica↔replica peering = named additive behind demand (L176); the
full corpus program = stream 14 (§7); cross-store coordination =
stream 10; the automatic placement tier = #784.

## Wave record

- **W1 EXECUTED 2026-08-12 — replica-local stream ingestion @ e69b8138.
  Gate `s9_w1_gate.log` GATE-RC=0, PRE/POST HEAD = e69b8138, 0 dirty**
  (first run green; fails = the classified #572 fabric/http pair, green
  on classified retries). `[$journal:ingest-stream]`
  (vcx/platform/journal_ingest.v): byte-identical re-land (head hashes
  probe EQUAL across stores; the destination chain verifies unchanged),
  full-chain pre-verification (nothing partial), clean-prefix-extension
  idempotence (re-ingest → ingested=0; grown source lands the tail).
  The sync band CXER5050–5069 registered in governance §9.6 BEFORE
  first use (dense + reserved tail — no sparse parenthetical, the s20
  W6.1 lesson); 5050 divergent / 5051 invalid-chain / 5052
  reserved-target shipped. Lawfully-gone payloads land their entry with
  `payloads-absent=` visible (L119 posture); the destination's verify
  reports them unattributed-missing LOUD (no evidence replicated —
  pinned by V test). Fixture journal-133 byte-exact; fn-doc verbatim;
  V tests: file:// close/reopen durability + the absent-payload loud
  lane. journal.md §2.1.1 ingestion block + stream-key naming note +
  §3.3 verb row (ruled edit map). **Design decisions (inside ruled
  bounds):** ingest = REGISTRATION + verification (the transfer verbs
  move bytes; ingest recreates exactly what transfer skips — entry
  pointers, head alias, stream index); v1 ingests FULL chains
  (compacted-below-1 source refuses 5051 — retention-anchored seeding
  rides W5); reserved `cx:*` streams refuse 5052 (shred records reach
  replicas on the FEED, the stream-20 handoff — the W5 worker's job,
  never hand-ingestion); dst-ahead-with-matching-prefix answers
  ingested=0 (bidirectional flows meet here).
- **W2 EXECUTED 2026-08-12 — the conflict value + per-ref
  reconciliation (L174/L175/L176 core).**
  `[$store:reconcile-report]` + `[$store:reconcile]`
  (vcx/platform/store_reconcile.v): per-ref reconciliation of the
  branch-class ALIAS plane (derived caches `computation/`/`cx-live/`
  excluded — caches rebuild, they are not the divergence surface; the
  wire-refs plane rides W4 over the shipped object-wire CAS).
  Fast-forward APPLIES (target doc copied when absent via the put-doc
  funnel — custody rules ride free; alias advanced through
  store_alias_set_local + the set-alias funnel's own durable record);
  ours-ahead / identical count visibly; DIVERGED applies nothing for
  that ref and reports the ONE Ring-0 conflict value in the ruled
  shape — `[conflict subject= kind=:diverged-advance [base position=
  hash=] [ours position= hash= [diff …]] [theirs position= hash=
  [diff …]] [cas code=CXER1114 expect-pos= actual-pos=]]` — built from
  the E3 alias lineage (ms.advances; the normative common base =
  greatest ours-position whose target appears in theirs' lineage; NO
  shared target → conflict with `[base]` ABSENT, the absence channel).
  Diffs via the ONE cx engine (cx_mod_diff made pub — no second diff
  dialect); the §5 patch law holds ON the conflict's own payload
  (patch(base, ours-diff) ≡ ours — fixture-pinned [law true]); the
  value canonicalizes + hashes stably (data-profile citizen).
  Agreement law: `reconcile` raises CXER5053 E_SYNC_DIVERGED (carrying
  every [conflict] as err children + the partial-success accounting)
  IFF the report says ok=false — the XAP compose/compose-report
  precedent, one walk two presentations. Partial success reported,
  never mixed silently (clean refs advance even when siblings
  diverge). Balanced report: refs = identical + advanced + ahead +
  conflicts. Fixtures store-reconcile-001 (fast-forward + idempotent
  re-reconcile) + 002 (diverged: full conflict shape byte-pinned,
  patch law, canonical stability, ours-unmoved, enforcing raise)
  probed byte-exact; fn-docs verbatim ×2 (guide-check OK 46); store.md
  §6.3 verb rows + semantics bullet (ruled edit map); governance row
  updated (5053 shipped). Gotcha: a path step by NAME on a value
  (`$conf/ours/diff`) answers the matched element's CONTENT (the
  settled field-read semantics) — select the element itself with
  `/*`. Resolutions-as-input-table + merge-as-an-entry = W3, where
  the recorded join makes a resolution an ordinary advance whose
  payload names both tips + base.
- **W3 EXECUTED 2026-08-12 — merge-as-an-entry + resolutions + cx:merge
  @ a1f0a38e (#719 item 3 discharged).** Resolutions re-enter as the
  input table (`opts {resolutions: [resolve ref= target=]}`): the join
  records FIRST (a stored `[merge]` doc — base/ours/theirs as locator
  triples on the alias lineage + the target), then the lineage ADOPTS
  theirs before advancing to the target — two ordinary advances, linear
  lineage, no merge node — so the next reconcile finds theirs' tip as
  the common base and answers AHEAD (converged; determinism
  fixture-pinned). `resolved=` rides the report only when engaged
  (L119; W2 reports byte-stable). cx:merge implemented ALIGNED TO
  VALUES: defined deep-merge semantics in modules/cx.md §2.3;
  error-on-conflict raises CXER4110 carrying every collision as the
  ONE `[conflict subject= kind=:merge-value [ours][theirs]]` shape.
  store.md §6.3 merge/rebase sentence amended to the ruled narrower
  truth. Fixtures cx-048 + store-reconcile-003 byte-exact; battery
  2847 green; guide-check OK 46; strict registry RC=0. **Design
  decisions (inside ruled bounds):** convergence rides the LINEAGE
  (adopt-theirs intermediate advance), not a join-record index — the
  common-base rule alone makes re-reconcile converge; a resolution
  naming a doc absent at ours refuses CXER1121 loud (resolver lands it
  locally or names a side's tip); resolutions for non-diverged refs
  are ignored deterministically (stale input, no effect).
- **W4 EXECUTED 2026-08-12 — the sync surface @ a279a6f9 (#719 items
  4+5 discharged).** The pull/fetch split (pull = fetch + per-ref
  reconciliation, composed head-set-bearing [pull-result] w/
  opts.resolutions; pull enforcing per the agreement law, CXER5053
  carrying conflicts, the fetch half + clean fast-forwards already
  landed; pull-report = the never-raising twin; a REMOTE pull source
  refuses LOUD naming the W5 wire lane — never a silent degrade);
  clone/push/fetch results head-set-bearing (pc_heads — the status
  shape, one vocabulary); the signed seed (journal-134: signed SET
  snapshot verifies → ingest per stream → replica heads byte-identical
  to the signed anchors; journal-135: fold-from a diverging anchor
  refuses CXER4615 — the §7 corpus rows). The alias-plane asymmetry vs
  migrate documented as design. Fixtures journal-134/135 +
  store-pull-002 byte-exact; battery 2850 green; guide-check OK 46.
  **FINDING (assess at W6):** pc_transfer lands docs without E3 feed
  appends — the docs stream undercounts transferred docs (pinned
  visibly in store-pull-002); the live changes-since consumer over a
  synced store is the affected surface; decide fix-vs-file at the M5
  end-to-end. **Scope decision (inside ruled bounds):** wire-side ref
  reconciliation + status ahead/behind both need the peer's
  lineage/head-set read — ONE design, landing together in W5's
  peer-facing batch (declaration profile + shred worker ride along).
