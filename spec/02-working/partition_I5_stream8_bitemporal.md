# I5 stream 8 — bitemporal semantics: implementation ledger

**Status:** OPEN (started 2026-08-12; order-of-march item 5 continuation,
stream #680 per the stream-7 exit handoff).
Branch `impl/I5-stream8-bitemporal` off `design/651-516-partition`
(cut at 69bced43 — the stream-7 exit-merge).
Governing spec: `bitemporal.md` — letters **L115–L121 inside the S2 batch
RULED (a) 2026-08-05 (letters 93–121)**.
RULED-token anchors = the S2 exit row in `partition_campaign_PLAN.md`
(decision log 2026-08-05, "WAVE S2 EXITED — letters 93–121 ruled (a)"),
stream-8 fragment: "VT = payload data under normative
`valid-from`/`valid-to`, half-open, absent-open-end, two attrs not a
kind; TX = position-only v1 w/ journal ts FORM fixed at I1
(deterministic UTC-Z synthesis, #712 joins the manifest); hash-linked
`[supersedes]` + the three-relation correction taxonomy; the pure
pre-fold projection w/ `{at-seq, valid-at}` naming (as-of retired from
new surfaces — the three-claimant collision resolved); VT shreddable w/
VISIBLE redaction reporting — stream 20's binding input; authz coherence
rule w/ dual-coordinate decisions".
Issue: #680 (stream). #712 (ts form + keep-after-time) is ALREADY
CLOSED — both halves verified in-tree at recon (verdict 3).

**Epoch posture (spec "Identity-epoch membership", audit C9):** ADDITIVE
— this stream's only I1-manifest row (the journal `ts` FORM, L116) was
executed AT I1 and is closed (#712); nothing remaining here defines,
moves, or re-spells a Tier-1/Tier-2 address, a canonical byte, or a
journal preimage. `valid-from`/`valid-to` are ordinary payload
attributes (Tier-1, caller-owned — L119); `[supersedes]` + the taxonomy
are payload domain vocabulary; the bitemporal read is a PURE read-side
projection; interval builtins, opts, error rows, and spec cross-edits
are all additive.

## Standing constraints

- Spec-first; NO spec edits without a recorded ruling (RULED: tokens on
  spec+impl commits; fragments must grep in `partition_*.md`). The §10
  spec-edit map of `bitemporal.md` IS ruled — each executed edit cites
  its letter: journal.md (vocabulary recognition, projection, opts, ts
  form, retention); cxdm.md §2.4 (reserved attribute vocabulary note);
  authz.md (coherence + recorded coordinates, at its `check` opts
  site); vc.md/session.md (cross-refs naming their windows as
  valid-time instances); stream-20 handoff (L119 binding input);
  stream-9 handoff (VT/TX divergence preserved in sync); stream-7
  naming coordination (at-seq — SHIPPED, verdict 2); stream-21
  fold-seam handoff (this stream authors the seam, #693 consumes it).
- Every wave ends green on the full gate — `make test` launched UNPIPED,
  full log, `GATE-RC=$?` propagated, verdict read FROM the log.
- Fixtures ride WITH their machinery wave, never after; fixture-first
  for every defect-shaped change.
- Cutover-first, no dual-accept; never true a spec to a shortfall.
- Fable 5 only; push per landing; exit-merge IS an exit step.
- Triage gate flakes by standalone re-runs BEFORE suspecting the stream
  diff (fabric+http usecache FAILs green on in-gate #572 retries every
  run — cache-free retry whenever fresh symbols land;
  net_udp_read_deadline is load-flaky-retry-green; #779 rotation-vs-fold
  is load-sensitive and pinned to #692; io temp-dir pid-recycling
  false-reds — clean /tmp/cxc* + /tmp/cx-lazy-page-* before suspecting
  the diff, #781).
- Stream-7 gotchas in force: sequence literals in maps take COMMAS;
  atoms are ScalarNode data_type=atom_type with the BARE name as
  payload; CXPath never parses off a call result (bind first);
  out-err is CONTAINMENT — assert refusals via [?fallback …
  [recover-with …]] + [context] child projections, never message-grep;
  canonical attr emit quotes digit-start hex — probe out-texts first;
  guide-check requires fn-doc examples backed VERBATIM by a conformance
  fixture; cxparse_full_corpus_diff baseline moves with every
  [doc]-in-cx fixture — bump in the SAME commit.
- G3 graduation of `bitemporal.md` is OWNER-GATED — never attempted
  here. The working spec stays in `02-working/`; normative cross-edits
  into approved specs execute per the ruled §10 map.

## Pre-open recon verdicts (2026-08-12, probed live this session)

1. **The L115–L121 register VERIFIED.** `bitemporal.md` §10 carries the
   full rulings ledger; the PLAN decision-log S2-exit row (2026-08-05)
   records "letters 93–121 ruled (a) under the standing ruling" with
   the stream-8 fragment quoted in this ledger's header. The spec-edit
   map in §10 is part of the ruled text.
2. **The stream-7 at-seq/valid-at seam VERIFIED SHIPPED both ways.**
   `at-seq` is the TX-pin spelling across journal opts
   (stdlib_journal.v:4155/4182/4298/4389 — the always-on pin guards
   from s7 W2 ride it) and the snapshot/head-set artifacts;
   consistency_vocab.v:27 already carries the coordination comment
   reserving `valid-at` OUT of the consistency token set as stream 8's
   query parameter. The two axes never fuse: `valid-at` rides
   read/fold/replay opts only, never `consistency=`.
3. **L116's I1 piece VERIFIED PRE-DISCHARGED (#712 CLOSED, both
   halves).** `jrn_ts_for` (stdlib_journal.v:887) emits the real
   ISO-8601 UTC-Z epoch-anchored synthesis (I1 row 10;
   journal_ts_form_test.v pins it); `keep-after-time` implements the
   ts→seq boundary walk (stdlib_journal.v:3298 — CXER4610 on
   non-datetime); the general ts→seq read surface is the SHIPPED
   `seq-at` verb (journal.md:577, RULED U1.14a; stdlib_journal.v:3010).
   No ts work remains in this stream — the §3 spec text is already
   true of the tree.
4. **The stream-21 pre-fold seam is THIS stream's to CREATE.**
   `schema_event_evolution.md` (finalized at S3) consumes "stream 8's
   pre-fold seam" — upcasters are pure entry→entry projections at the
   same composition point ("the exact coin stream 8 spent for
   valid-time, spent the same way"). The seam site is the fold funnel:
   jrn_fold_entries / jrn_fold_state_entries (hydrated, I1 row 11) /
   jrn_fold_value, composing BEFORE apply_fn_value; replay
   (jrn_replay:4135) and read (jrn_read:1733) take the same opts.
   Stream 21 is #693 — next in the march; the seam must be authored
   generically (a pure entry-sequence→entry-sequence projection slot),
   not valid-time-shaped.
5. **VT + correction vocabulary GREENFIELD.** Zero occurrences of
   `valid-from`/`valid-to`/`valid-at`/`[supersedes]` recognition in vcx
   or the approved specs (store's tombstone-supersede comments are
   unrelated); the three near-misses the spec names (authz `[until]`,
   VC issued/expires, session nbf/exp) confirmed per-module and
   unnamed. No retirement sweep needed; the vocabulary lands clean.
6. **Interval-builtin landing sites located.** Dollar-builtin dispatch
   = vcx/code/eval.v (name tables ~:5043/:5130, dispatch ~:5770);
   purity list purity_checker.v:177; parser list parser.v:1198.
   `[$overlaps]` / `[$contains-instant]` land as pure builtins in all
   three tables.
7. **The authz composition surface VERIFIED SHIPPED.** `check`/`
   authorize` opts already take `as-of` (decision instant) +
   `with-context` (state snapshot) — authz.md:487/:513/:515,
   stdlib_authz.v:1380/:1692. authz KEEPS its shipped `as-of` spelling
   with a cross-reference (L118); the L121 coherence rule + the
   dual-coordinate decision value are the additive edits at that site.
8. **cxdm.md landing site = §2.4 Attributes** (attrs strictly scalar —
   the carriers `date`/`datetime`/`::instant` are scalars; the
   reserved-vocabulary note is one additive paragraph).

## Wave plan

- **W1 (this entry):** branch + ledger + recon verdicts committed.
- **W2 — the VT vocabulary + correction core (L115/L117):** journal.md
  vocabulary recognition — `valid-from=`/`valid-to=` as the normative
  reserved payload vocabulary (half-open `[from, to)`; open end =
  ABSENT attribute, never null; carriers date/datetime/::instant under
  stream-11 strict validation); cxdm.md §2.4 reserved-attribute note;
  `[supersedes hash=<entry-address>]` linkage (content address, never
  seq) + the closed relation taxonomy `:assertion`/`:correction`/
  `:amendment`; `verify` stays syntactic — a dangling supersedes is a
  FINDING from a coherence verb, never a chain break. Discriminator
  fixtures ride the wave (boundary half-open probes; absent-vs-null;
  dangling-supersedes finding).
- **W3 — the bitemporal read (L118):** the substrate-provided PURE
  pre-fold projection `[sequence entry] → [sequence entry]`,
  parameterized `(tx-position, valid-instant)`, composed BEFORE
  fold-value — fold contract untouched; the seam authored generically
  (stream 21's upcasters take the same slot). Surfaced through journal
  read/fold/replay opts as `{at-seq: N, valid-at: T}`; the
  four-quadrant table normative (now/now, at-seq/now, now/valid-at,
  at-seq/valid-at); the as-of COLLAPSE (current-fact selection, not
  filtering) driven by the §4 taxonomy — `:correction` supersedes the
  whole extent, `:amendment` closes/opens intervals, `:assertion`
  coexists. The M5 four-quadrant price-correction fixture family with
  the restatement-delta pair as the headline.
- **W4 — CXPath + interval builtins + the erasure constraint
  (L118/L119):** `[$overlaps]` + `[$contains-instant]` as pure builtins
  (eval/purity/parser tables); CXPath predicate filtering over the
  vocabulary fixtured (no grammar change — proven, not assumed); L119
  stated normatively in journal.md (VT in the hashed payload / TX in
  the hashed envelope, one entry hash covers both, no fourth lane); VT
  shreddable with the payload — a VT query over shredded entries
  reports its redaction count VISIBLY (finding-not-fault) and never
  silently under-reports; the redaction-visibility fixture on a real
  shredded entry; the stream-20 handoff recorded (L119 = #692's
  binding input).
- **W5 — authz coherence + cross-refs (L121/L115):** authz.md coherence
  rule at the `check` opts site — the context snapshot records its TX
  position (fold at-seq/head-set); the decision value records BOTH
  coordinates for audit; the bitemporal authorization query ("what
  would we have decided at position P, for instant T") specifiable;
  incoherent pairs constructible only explicitly. vc.md/session.md
  cross-refs naming their windows (issued/expires, nbf/exp) as
  valid-time instances; authz `[until]` likewise. The coherence-rule
  fixture (decision value carries both coordinates).
- **W6 — M5 substrate + exit (spec §9):** corpus completion — the
  offline-replica seed fixture (VT precedes TX — stream 9's consumer
  made concrete, no replica impl here); ts-form re-bless vectors
  verified pre-discharged (I1, verdict 3); exit audit (every ruled §10
  map row executed or verified pre-discharged; every §9 corpus pair
  delivered or at a named landing); exit gate; exit-merge.

**Out-of-scope at named landings (L120 ratified):** store temporal
tables (store as-of, if ever = a projection over E3's ref lineage);
in-place temporal rewrites (never); an interval kind (never — two
attrs); wall-clock TX authority (`seq` stays the order authority);
cross-stream total order (head-sets; coordination = stream 10 #682);
materialized views (stream 3's `[?materialize]`); replica sync
semantics (stream 9 #681); upcaster vocabulary itself (stream 21 #693 —
this stream ships the seam only).

## Wave log

### W1 — entry (2026-08-12)

Branch cut at 69bced43; ledger authored; recon verdicts 1–8 probed live
(register, both named seams, #712 pre-discharge, greenfield sweep,
landing sites). Wave plan derived from the ruled §10 spec-edit map +
the §9 corpus handoff.

### W2 — the VT vocabulary + correction core (2026-08-12)

**Landed (RULED: 93-121 / L115+L117+L119):**

- **Design decisions recorded (in-wave, consistent with the ruled
  sentences):** (1) recognition is READ-SIDE only — append never parses
  the payload (§2.3 holds byte-identically; the strict-validation rule
  binds the carriers where the caller constructs them and where the
  read surfaces consume them); (2) the taxonomy's spelling: `relation=`
  rides the `[supersedes]` element, TYPE-STRICT (the ATOM :correction
  or :amendment — a string spelling is misuse, stream-7 posture);
  `:assertion` is the classification of a VT-bearing entry with NO
  supersedes child, never a linkage spelling; (3) linkage findings are
  three-way honest: `:dangling-supersedes` only when NO chain in the
  tenant has a pruned floor; `:supersedes-unverifiable` when the target
  may lawfully live in pruned history; vocabulary misuse =
  `:temporal-vocab-invalid` with one finding per defect (a malformed
  supersedes is never also resolved); (4) shredded payloads counted
  visibly (`erased=N` when non-zero) — the L119 honest-reporting
  posture reaches the linter too; (5) carrier comparison decodes
  through the ONE datetime core (`decode_datetime`/`instant_ns`) —
  lexicographic comparison is unsound across date/datetime grains and
  fractional seconds.
- **`coherence`** — the new semantic-linter verb (journal.md §3.6;
  `verify` stays syntactic per L117): walks retained entries (scoped
  or default-then-named-sorted), checks §2.9 vocabulary + linkage,
  resolves well-formed targets against the TENANT-wide retained hash
  set (linkage may cross streams). Returns a present `[coherence]`
  findings VALUE, never an error for findings. Impl:
  `jrn_coherence` + `jrn_coh_scan`/`jrn_coh_check_payload`/
  `jrn_vt_instant`/`jrn_attr_lookup` (stdlib_journal.v), dispatch row
  `journal-coherence`, def + fn-doc in stdlib/journal.cx.
- **Spec edits per the ruled §10 map:** journal.md §2.9 authored (the
  reserved payload vocabulary: half-open `[from, to)`,
  absent-open-end never null, carriers under strict validation,
  `[supersedes hash= relation=]` by content address never seq, the
  three-relation taxonomy, VT-in-payload/TX-in-envelope + the L119
  shreddability statement with visible redaction reporting);
  journal.md §3.6 `coherence` authored; cxdm.md §2.4 the
  reserved-attribute-vocabulary note (naming, not a kind).
- **Fixtures journal-104..107** (probed byte-exact, RED-proven: a
  corrupted expectation fails naming journal-104; suite 2811): clean
  chain zero findings; definite dangle; `:supersedes-unverifiable` on
  a REAL compacted segment (the pruned-floor discriminator); the
  four-defect vocabulary probe (non-temporal carrier, empty half-open
  interval, string-spelled relation, missing hash=). fn-doc example =
  journal-105 verbatim; guide-check OK 46 modules.
- CXER4618 reserved for W3 (the projection's typed refusal — the
  raiser lands with its machinery; coherence findings are values, no
  new code needed this wave).

### W3 — the bitemporal read (2026-08-12)

**Landed (RULED: 93-121 / L118 + L115/L117 semantics + the L125 guard
extended):**

- **The pure pre-fold projection** (`jrn_temporal_project`): TX cut on
  `at-seq`; a given `valid-at` ENGAGES the as-of collapse — every
  in-cut `:correction` target excluded across its whole extent (a
  corrector's own later supersession never restores its target;
  restoration = a NEW assertion), every `:amendment` clamps its
  target's valid-to to the amender's OWN valid-from (earliest clamp
  wins; an amendment without its own valid-from = undefined close
  point, CXER4618) — then the half-open [from, to) filter. Entries
  without vocabulary are valid always; NON-ELEMENT payloads likewise;
  shredded (event-less) entries PASS THROUGH VISIBLY (filtering them
  would silently under-report a redaction — the L119 posture decided
  IN the projection, W4 fixtures pin it). Malformed vocabulary under
  an engaged projection = CXER4618 naming the seq (the CHAIN's
  vocabulary); malformed opts = CXER4610 (the CALLER's args). The
  seam is authored generically — a pure entry-seq→entry-seq stage
  ahead of the reducer; stream 21 (#693) composes upcasters at the
  same point.
- **Surfacing per L118:** `fold` gains trailing `$opts::map {}` —
  `at-seq` (the TX pin, with the stream-7 L125 ALWAYS-ON guard exactly
  as replay's: pinned below a pruned floor refuses CXER4991
  resolve-through-snapshot; beyond head CXER4606) + `valid-at`;
  `replay` opts gains `valid-at` (at-seq shipped); `slice`/`since`
  gain trailing opts with `valid-at` (at-seq there is a TEACHING
  refusal CXER4610 — the explicit range IS the TX axis); NEW PURE VERB
  `temporal-slice` (the fold-value twin over materialized entries).
  `fold-slice` deliberately takes no temporal opts — its composition
  is temporal-slice ∘ fold-value (decided, documented, not deferred).
  Undeclared paths byte-identical (no opts → the shipped fold/replay/
  slice code paths).
- **Spec edits:** journal.md §3.8 authored (the projection, the
  surfacing, the NORMATIVE four-quadrant table, the collapse rules,
  the honesty rules, the M5 restatement-delta line); §3.3/§3.4/§3.5
  def-blocks + opts sentences; §8 row CXER4618 (reserved band now
  4619–4649). Governance untouched — 4618 is in-band within journal's
  registered 4600–4649 allocation.
- **Fixtures journal-108..113** (probed byte-exact; suite 2817 green;
  guide-check OK 46): 108 = the M5 four-quadrant table with the
  restatement delta (q4 vs q3; q1 raw-fold last-wins probed 17.99 —
  the draft's 19.99 was wrong, the probe corrected it); 109 = the
  taxonomy fold discriminator triple (amendment survives-before/
  clamps-after; correction drops the whole extent; assertions
  coexist); 110 = half-open boundary probes (IN at from, OUT at to
  exactly); 111 = open ends (absent attr, from-only/to-only/plain);
  112 = the refusal split (chain vocab CXER4618 ×2 incl.
  amendment-without-valid-from vs caller args CXER4610; raw fold of
  the same chain stays green — quadrants 1–2 never parse payloads);
  113 = fold's at-seq pin guard CXER4991 on a real compacted segment
  (requested+floor named). fn-doc temporal-slice = journal-110
  verbatim. GOTCHA (real cost): brackets inside [; …] fixture comments
  are LIVE syntax — `[Aug 1, Aug 5)` in a comment broke the whole
  file's parse (unterminated element body at the file tail); [# #]
  raw blocks are safe.

### W4 — interval verbs + CXPath-over-vocabulary + the erasure constraint (2026-08-12)

**Landed (RULED: 93-121 / L118+L119):**

- **Placement decision (in-wave, long-term-best):** `[$overlaps]` /
  `[$contains-instant]` land as **journal MODULE verbs** (`overlaps`,
  `contains-instant` — pure, backed by env-free prims), NOT §6.5 core
  builtins: the §6.5 tables are CLOSED and identity-bearing (stream 5's
  builtin-set id hashes the two spec tables — extending them for a
  vocabulary helper would move every computation identity for zero
  gain), and the vocabulary's normative home is journal §2.9.
  Half-open adjacency does NOT overlap (the no-double-count
  discriminator); absent ends unbounded; malformed vocabulary on an
  argument = CXER4618, non-element/non-temporal args = CXER4610.
  Shared bounds extraction `jrn_vt_bounds` (the projection's pass-2
  refactored onto it — one carrier-validation authority).
- **L118's no-grammar-change claim PROVEN, not assumed**
  (journal-115): attr-presence, negated presence, and prefix-operator
  comparison predicates all filter the vocabulary on materialized
  entries as-is. **FILED IN PASSING: #782** — the `query` VERB
  silently strips trailing predicates (a deliberate name-step subset
  that over-matches vs §3.3's promise; probed live: predicate query
  answered 3 where 2 match). Pre-existing, out of ruled scope, named
  landing = #782; the fixture pins the read-surface paths and notes
  the exclusion.
- **The L119 redaction-visibility fixture on a REAL shred**
  (journal-116): store delete of the payload doc by its detached
  address; the ENGAGED projection passes the shredded entry through
  VISIBLY (projected=2); coherence counts it (erased=1); the chain
  still VERIFIES (hash covers the address — the erasure mandate).
  Stream 20 (#692) inherits this fixture + §2.9's statement as its
  binding input.
- Spec: journal.md §3.8 interval-verbs block (defs, the module-verbs
  rationale, adjacency rule, the #782 note). Fixtures journal-114..116
  probed byte-exact (suite 2820); fn-docs overlaps + contains-instant
  = journal-114 verbatim; guide-check OK 46.
