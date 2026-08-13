# Adversarial I5 audit — partition campaign #651+#516

**Status:** audit report (not normative). Ordered by the owner 2026-08-13 at the
W6 pause of stream 17; the march does not resume until these findings are
dispositioned. **As of:** `impl/I5-stream17-runtime` @ 554e9f3f, 2026-08-13.
**Method:** read-only hostile review — no fixes, no spec edits, no re-blessing.
Every finding carries file:line or log evidence plus a reproducing command.
Gate/bench runs performed by the audit were unpiped with GATE-RC and PRE/POST
HEAD guards; logs at the audit session scratchpad `audit_gates/` (paths cited
per finding; the scratchpad is session-local — verdicts live in this report).
Throwaway counterexample probes ran against the built `vcx/target/cx` and
in-tree modules from a scratchpad directory; the repo tree was not touched.

**Hypothesis under test (the owner's symptom):** I5's enforcement
infrastructure (gates, fixtures, parity contracts) has improved faster than
the engine it measures, and exited streams may carry more latent defects of
this class.

**Verdict: CONFIRMED, with one amendment.** The enforcement/engine gap is
real and larger than #803/#804 showed — the audit found two more unrunnable
spec'd gates (7, 8), one red-today unwired gate (4), a never-measured
normative timing table (abi §4), a dead regression channel (bench-compare),
and three shipped "by construction" seams protected only by assertions their
fallback paths satisfy equally. The amendment: **not everything surfaced is
pre-existing.** Stream-17 W5's streamed-input equivalence claim is falsified
by three execution-verified counterexample families (I5-introduced), and
stream-17 W3a's width-preserving lattice introduced a silent u16 value wrap
on the wire (probable regression, replacing a pre-existing type-drift). The
same weak-assertion pattern that hid the engine's old reds also let these
two new ones land green.

---

## §0 Plain summary — what happened, impact, recovery, prevention

**What happened.** The v0.8.0 homoiconic reshape (May 2026) replaced the
pre-reshape engine with a uniformly boxed node representation. Streaming
throughput fell from a measured 353 MB/s (v0.7.6, gate 15 green) to ~2 MB/s.
The gate that would have said so went red immediately — the 2026-05-25 gate
audit recorded it as "likely re-run/regression to bisect, not architectural"
— and was never bisected. The runner then rotted through the syntax
migrations (retired spellings), the gate table was archived out of the tree,
and the master gate-check script disappeared. From late May to 2026-08-13
(v0.8.0 through v0.15.0, eight releases), the 200 MB/s normative budget had
no measuring artifact. Stream-17 W5/W6 repaired the runner, measured
honestly, and filed #804. Gates 7, 8, 4, bench-eval, and bench-compare died
the same way (this audit ran them; §1 AF-5); abi.md §4's timing table never
had a measuring artifact at all (AF-6). The same weak-assertion blindness
let two regressions land green inside I5 itself (AF-1, AF-2a).

**Impact.** No wrong answers — the engine is correct and ~100× slower than
the spec promises on streaming workloads (a 100 MiB data-shaped stream:
~50 s/core instead of ≤0.5 s). code.md §11.4.4 and abi.md §4 over-promised
to adopters for the whole window. `[?modify]` violates its enforced
structural-sharing budget ~1000× (#803). Two I5-introduced divergences
shipped in stream-17 waves (AF-1 wrong-answer class on refused inputs;
AF-2a silent u16 value wrap on the wire).

**Recovery.** Two legs, both already ruled (letters 86-92), neither built:
leg 1 (~2→~30 MB/s) removes the per-item eval cost — #804's decomposition:
frame clone per iteration + yield + render; ceiling is the parser bound.
Leg 2 (~30→200+ MB/s) removes the parser's GC cap (~1.1M boxes/100 MiB) via
lazy materialization, columnar in-flight, and the L88-admitted direct
batch→canonical-bytes emitter (byte-identical, pair-fixture-pinned). The
work lands in the Q1 gate-truth batch + the #804 lane.

**Can 353 MB/s come back?** 353 was streaming-eval throughput on the
semantically thinner pre-reshape engine; treat it as an existence proof that
the workload is not hardware-bound, not as a target. The commitment is the
normative floor: **≥200 MB/s (gate 15), which stands — the spec is never
trued to the shortfall.** For bulk fixed-width data the columnar decode +
direct-emit path is nearly memcpy-shaped, so exceeding 200 there is
plausible; the general node path will land lower. The post-fix ceiling is
unmeasured — establishing it is #804's profiling job, and no number beyond
the 200 floor should be promised before that.

**Prevention.** The root cause is structural: a normative budget whose
measuring artifact can die silently. Four fixes, all inside Q5/Q1:
(1) a living gate register in-tree — every budget → runner → threshold →
wiring; (2) every budget-bearing gate either in the stream-gate matrix or
freshness-checked, where evidence older than a release is itself a red;
(3) syntax migrations sweep gate/bench runners too (gates 7/8/14/15/16/30.5
and bench-eval all rotted because they live outside `make test`);
(4) a gate that goes red files an issue at that moment — the May
"not architectural" note went three months without a bisect or a tracker
entry. For new work: no wave ships a "by construction" claim without a
counterexample-shaped fixture lane (the AF-1 lesson).

---

## §1 Findings, ranked by severity

Severity: **S1** shipped-behavior divergence (execution-verified) · **S2**
enforcement-infrastructure integrity · **S3** test-integrity (false-green
surface) · **S4** process/deferral integrity · **S5** hygiene.
Disposition vocabulary: fix-now (during the pause / folded into W7) ·
batch-N (a named post-gate batch) · stream-14 (corpus absorber) ·
owner-ruling (needs a letter).

### S1 — shipped-behavior divergences

**AF-1 (S1). Stream-17 W5 streamed-input equivalence is FALSIFIED — three
counterexample families, all run-confirmed.** The W5 record claims "an input
the materializing path refuses ALWAYS declines pre-emission and reproduces
the exact refusal" (partition_I5_stream17_runtime.md:271-282). All three
guards leak:

- **AF-1a `@`-reference inputs stream instead of refusing.** The input gate
  `streamed_input_safe` (vcx/code/streamed_input.v:135-146) scans for `&` and
  `#name` bytes but not the `@` reference sigil; `resolve_ids` (which the
  materializing path runs via cx.parse, vcx/cx/parser.v:521/649) is never run
  per-child (streamed_input.v:152-169 resolves namespaces only). Input
  `[data [user x=@nosuch [id 1]] [user [id 2]]]` with the canonical two-step
  `[?for]`: buffered = `CXER0100 unresolved reference '@nosuch'`; streamed =
  emits both users. Same for body `[ref @name]`.
- **AF-1b Non-ASCII `#id` bypasses the byte gate.** The `#name` scan uses
  ASCII `is_name_start_b` (vcx/cx/lexical.v:170-172) while parser names are
  full Unicode (parser.v:3941). Input with two `#émile` ids: buffered =
  `CXER0208 duplicate ID`; streamed = emits both matches.
- **AF-1c Rooted paths in the yield body commit-then-error.** The textual
  `$doc`-spelled-once scan (streamed_input.v:103) does not catch `/x` and
  `//x` rooted paths, and the fast path never binds `doc` (api.v:306-331 vs
  the materializing bind at :332-341). Program `[yield [pair $u /meta]]`:
  buffered succeeds; streamed commits (witness counter increments), emits,
  then errors `CXER0001 … requires $doc` (eval.v:7452) — a success-vs-error
  divergence with a misleading message, past the point of fallback. The
  two-pass validation walk validates inputs, not the yield body's path set.

  Defeated attacks (evidence the rest of W5 holds): take/drop low-emission
  shapes, `$_position` under drop, ns rebind/default-ns/cx:lang/mixed-text
  parity, `$doc` aliasing via strings (the conservative textual scan),
  ASCII `#id`, anchors, multi-doc, reserved-ns.

  **Classification: I5-introduced (W5 wired the path 2026-08-13).** This is
  the one confirmed regression the I5 march has produced — and its own W5
  fixtures could not see it because they assert "both paths refuse" without
  comparing refusal identity and never probe `@ref`/Unicode-id/rooted-path
  inputs (vcx/tests/code_units_umbrella_test.v:3296-3337).
  **Disposition proposal: fix-now inside stream 17 (pre-W7-exit), fixture
  first** — pin AF-1a/b/c as refusal-parity fixtures, then either close the
  three gate gaps (scan `@`, use the Unicode name predicate, validate the
  yield body's paths or decline rooted forms) or narrow the engagement
  predicate; the deferred-commit rule ("decline pre-emission") is the
  acceptance criterion. → Question Q3.

**AF-2 (S1). CXCol wire codec: five render-parity divergence classes, one of
them silent value corruption — mostly unfiled.** Method: `emit_cx(parse(t))`
vs `emit_cx(parse_data_bin(emit_data_bin(parse(t))))`, the same comparison
the lattice fixture family uses (vcx/tests/codecs_formats_umbrella_test.v:
2888-2893). Run-confirmed:

| class | input | direct render | after 0x60 | after 0x63 |
|---|---|---|---|---|
| **AF-2a value wrap** | `u::u16` cell `70000` | `70000` | **`4464`** (mod 65536) | `4464` |
| AF-2b all-null lane split | `n::int`, all cells null | `n::int` | **`n`** (type erased) | **`n::int`** — the two binary lanes disagree |
| AF-2c header drift | `v::f64` / `s::string` | kept | **`v::float`** / **`s`** | same |
| AF-2d datetime offset | `…T23:00:00+02:00` | offset kept | **`…T21:00:00Z`** | same |
| AF-2e f16 quantization | `h::f16` cell `1.0e-1` | `1.0e-1` | **`9.99755859375e-2`** | same |

  AF-2a contradicts the repo's loud-refusal posture (ascribed scalars refuse
  out-of-range at parse). **Probable W3a regression**: the pre-W3a encoder
  widened unsigned→i64 (ledger shipped-state map, stream-17:27-29), which
  preserved the value while drifting the type; W3a's width-keeping flipped
  the failure from type drift to silent value wrap. Bisect at fix time.
  AF-2d is deliberately pinned on the WIRE (ch-007,
  conformance/data_bin_chunked.cxd:155-175) but no fixture asserts RENDER
  parity. Defeated attacks: decimal trailing zeros, bigint at/past i64
  boundary, empty table, bit-packed bool across chunks, dict order across
  chunks, u16 at 65535/0, mixed 0x81, negative-zero values.
  These are exactly the divergences the unauthored §9 W7 transparency pair
  family exists to catch (identical out-cx/out-json/out-hash across
  CX text / 0x60 / 0x63 / Arrow).
  **Disposition proposal: file as one family issue (the wire-render-parity
  family), fix AF-2a as its head (refuse-or-widen ruling needed), land the
  W7 pair family as the pinning fixtures.** → Questions Q4, and Q2 for
  priority.

**AF-3 (S1-small). The normative round-trip identity at
spec/03-approved/modules/cx.md:250 is byte-false for every input.**
`cx:serialize(cx:parse($t)) ≡ cx:canonical($t)` — serialize output lacks the
trailing newline canonical output carries (run-verified; stream-12 ruled
canonical bytes CARRY the trailing LF and the hash covers it). Masked because
`cx:equal` compares values and the stream-20 preimage-parity fixture wraps
serialize in an outer `cx:canonical` (proving the wrapped form, not the
spec'd identity). Canonical text is identity-bearing (#563-565 pins): byte
consumers hashing the two lanes diverge.
**Disposition proposal: fix-now-class one-liner (serialize emits the trailing
LF) + a byte-level fixture; rides whichever batch Q4 lands.**

### S2 — enforcement-infrastructure integrity

**AF-4 (S2). The perf/coverage gate registry is orphaned and its spec'd
apparatus is fictional.** The numbered gate table (1-17, 28.x, 30.5) exists
only in the archived `spec/_archive/v0_8_0_status.md` §11.6 (git 11598573;
deleted from the tree). Makefile:1500/1505 still cite "the master gate-check
(`scripts/gate_check.sh`)" and "Per spec/v0_8_0_status.md §11.6" — neither
exists (nor `scripts/v0_8_0_gate_check.sh`). code.md §11.4.4's written
protocols name `cxl_pattern_compile_bench.v`, `run_bench_json.py --gate`,
`compare_bench.py --threshold`, `scripts/gen_compile_bench_patterns.py`,
`scripts/check_perf_gate.sh` — none exist as named; the real apparatus is
self-asserting `bench-code-*` targets that diverge from the spec'd
measurement conditions: gate 15 synthesizes 100 MB in-memory vs the spec'd
1 GB cold-cache corpus (`bench/data/` missing); gate 16's PASS is an
in-process sequential loop, not the spec'd 3-minute wrk c=64 protocol;
gate 30.5's fresh red was measured on a ~118 KB default doc
(doc-bytes=120404) vs the spec'd 10 MB envelope, with absolute byte budgets
ADVISORY unless `GATE305_ENFORCE_ABSOLUTE=1`. This orphaning is the
structural root of the #803/#804 class: a budget whose measuring artifact
can die silently. **Disposition proposal: owner-ruling (Q5) — re-home the
gate registry as a living artifact with every gate's runner + threshold +
wiring named, then repair or explicitly retire each row.**

**AF-5 (S2). Two more spec'd gates are unrunnable, and one is red today —
the honest-run sweep this audit performed.** All logs in the audit
scratchpad `audit_gates/`, PRE-HEAD 554e9f3f:

| gate | spec'd claim | honest verdict (this audit) | evidence |
|---|---|---|---|
| 7 (24h soak, 30s smoke) | zero deadlocks/leaks (code.md:5093) | **FAIL at iteration 0** — workload carries the retired `[?let … :in]` form (code_concurrency_soak.v:66-68); no gate-7 log has EVER existed | gate_7_smoke.log GATE-RC=2 |
| 8 (10K cancel battery) | zero non-deterministic failures (code.md:5094) | **FAIL — 10,000/10,000 hard eval errors** (retired spelling, code_async_cancel_battery.v:47-49); measures nothing about cancellation. The archived table's "✅ 10000/10000" is contradicted by the on-disk Jun-18 gate_8.log which ends in a build error | gate_8.log GATE-RC=2 |
| 4 (fixture coverage) | every directive×param×CXER covered | **RED**: 6 CXER codes have zero fixtures (CXER0120/0153/0215/0273/0280/4113); 150 I5-era fixtures fail the id-category check (checker registry doesn't know the I5 prefixes); 5 unknown-directive citations. Not in TEST_TARGETS — no stream gate ever ran it | gate_4.log GATE-RC=1; repro `python3 scripts/check_code_fixtures.py` |
| T1 bench-eval | perf.yml regression signal | **PANICS** (retired spellings, eval_features_bench.v:73-122) | t1_bench_eval.log GATE-RC=2 |
| bench-compare | 30%/10% regression thresholds (Makefile:360-367) | **UNRUNNABLE** — `bench/baseline.json` missing; perf.yml manual-only, compare `continue-on-error: true` | census |
| 28.6/28.9 (binding parity) | byte-identical across V/Py/Go/Rust | **GREEN — 51/51** (the May-era 2 divergences were fixed silently; staleness cuts both ways) | gate_28.6_28.9.log GATE-RC=0 |
| 17 (playground smoke) | live playground | **GREEN** vs on-disk dist artifacts; browser-level verification still "pending Phase 7" by its own output | RC=0 |
| 28.11-28.14 ([?def]/[?lib]/[expr]/purity per-ADR assertions) | 🚧 in archived table | **EVAPORATED** — zero references anywhere in tree; behavior has fixtures, the per-ADR acceptance was never asserted | grep |
| 28.5 (Saxon parity) | byte parity | env-dead on this machine (Docker creds hang) | — |

  Context that softens gates 5/6/9/12/28.7/28.8/1/2/3/10/11/13/28.10: they
  run fresh inside every stream gate's full `make` matrix (s17_w6_gate.log,
  130,618 lines, GATE-RC=0) — their Jun-18 `_gate_evidence` logs are stale
  RECORDS of healthy lanes, not unmeasured behavior.
  **Disposition proposal: gates 7/8 runner repairs join the engine-perf
  batch (Q1); gate 4 = repair the checker registry + wire into TEST_TARGETS
  (cheap, fix-now); registry re-home per Q5.**

**AF-6 (S2). abi.md §4's ten-cell timing table has never been measured in
project history, and the first measurement says it is red.** abi.md:1350-1368
budgets (`cx_to_json` <100µs/1KB, <60ms/1MB, <6s/100MB; `cx_to_ast_bin`
<50µs/<30ms/<3s; `cx_events_next` <1µs) cite "the perf-regression suite (see
`architecture.md` §Conformance)" — no spec/architecture.md exists. Audit
first-measurement (CLI wall time, parse+emit conflated — upper bound;
audit_gates/abi_s4_first_measurement.log): 1MB→json 0.27s vs the 60ms
budget; 10MB→json 3.02s ⇒ ~30s extrapolated for the 100MB<6s tier. The
~2-4 MB/s engine-wide per-item ceiling (#804) extends to the ABI conversion
budgets. table-api.md:355-364 (<3s/100MB; "<50% overhead") derives from the
same unmeasured table. **Disposition proposal: join #804's engine-perf lane
(same root cause) + author a minimal driver that times the ABI calls
properly (parse excluded) so the table stops being unfalsifiable.** → Q1.

### S3 — test-integrity (the false-green surface)

**AF-7 (S3). Three shipped W3/W4 deliverables are engagement-unwitnessed —
protected only by parity assertions their fallback paths satisfy equally.**
The pattern W5 got right (`streamed_input_commits` asserted `> before` /
`== before` per shape) is absent exactly where it is most needed:
- **0x62 dictionary encoding (W3b headline):** the only tests assert
  round-trip == direct render (codecs_formats_umbrella_test.v:2941-2963) — a
  plain 0x60 encoding passes both identically; no test or fixture anywhere
  pins the 0x62 byte (grep `tag_table_dict|0x62` over tests: one comment);
  no hex fixture contains an `::atom` column. If `column_wants_dict`
  (vcx/cx/data_bin.v:973-1000) regressed to always-false, every gate stays
  green while the W6 commit's "compactness guaranteed on the WIRE" claim
  silently dies.
- **W4 pushdown verb wiring:** engagement is asserted only on direct
  executor calls (store_columnar_test.v:463-487, 846-914); the live verb
  falls back to `store_query_scan` on `none` with identical answers
  (stdlib_store.v:3988-4001, 4076-4092) and no verb-level test observes
  which path answered. The honest-reporting flag exists and no test reads
  it at the verb level.
- **Dictionary index range check (W3b "range-checked indexes"):** the check
  exists (data_bin.v:1816) with zero negative coverage — deleting it leaves
  every gate green.
  Adjacent: **the whole columnar backend is compile-flag-gated**
  (`-d cxstore_columnar`, test builds only) — the default shipped binary
  never runs the W4 path at all, so "parity in production" is vacuously
  true. **Disposition proposal: witness fixtures join the W7 §9 family
  (engagement counters/flag asserts + a 0x62 hex pin + a corrupt-index
  negative); the flag-gating question goes to the owner with stream-18/#800
  context.** → Q6.

**AF-8 (S3). The out-err acceptance residue (the July-2026 class is fixed;
two narrower gaps remain).** The R3.12 fix is present and self-tested
(code_eval_fixtures_test.v:18-47). Residuals: (a) the rendered lane grades
`rendered.contains(f.out_err)` (:306-310, :556-561, :681-685) — a SUCCESS
value embedding the expected text passes an out-err fixture; (b) the thrown
lane pins only the first CXER code, not stage or message (:23-30, :271-277)
— a same-code wrong-reason error passes; the package runner got the
parse-failure-never-passes hardening (:664-669), the code/stdlib lanes did
not. Concrete weak negatives: journal-057/058 expect the bare phrase
`no callable` (conformance/stdlib/journal.cxd:831-844) — a broken journal
module keeps both green, including 058, the cross-tenant-inexpressible
SECURITY negative. **Disposition proposal: runner hardening + a CXER-code
sweep over no-code out-err fixtures — batch (#796 rider or the Q1 batch).**

**AF-9 (S3). Smaller test-integrity items.** (a) EV-BUDGET: the
implementation constant sits EXACTLY at the spec floor
(eval.v:439 `generator_force_budget = 1_000_000` vs code.md:2024 "MUST
accept ≥ 1,000,000") with zero headroom and the planned floor probe
(clean_room_implementability.md:167) unauthored — a one-off-by-one regression
would be a spec violation no fixture catches. (b) W5 refusal parity asserted
as "both refuse", never "identically" (code_units_umbrella_test.v:3296-3337)
— the gap AF-1 walked through. (c) strict-mode tag honored only in the
code.cxd lane; zero stdlib/package fixtures carry it today (latent).
(d) out-effects grading skipped for thrown-error fixtures; zero fixtures
declare both today (latent). **Disposition: (a)+(b) → W7 scope; (c)+(d) →
stream-14 corpus notes.**

### S4 — process/deferral integrity

**AF-10 (S4). The stream-14 absorber has no receiving manifest.** Eight
streams (s8/s9/s10/s16/s17/s20/s21/s22) each hand their M5/corpus families
to "stream 14" in their own ledger prose; the receiving side is empty at all
four places a stream-14 implementer would look: issue #686 (zero I5-era
comments), partition_corpus_audit.md (no handoff register), PLAN.md (decision
-log mentions only), the march memory. The de-facto recovery procedure is
"grep 8 files" — precisely the tracker-rot the 1a batch ruling exists to
prevent. **Disposition proposal: author the consolidated handoff register
(one section in partition_corpus_audit.md + a pointer comment on #686)
during the pause.** → Q6.

**AF-11 (S4). The "item-6 owner-gated handoff packet" does not exist as an
artifact.** ≥6 streams' G3 graduation decisions plus ≥3 booked owner notes
(e.g. s5 par_reduce chunk width, s6's booked item, s16's two dispositions)
point at "the item-6 packet"; no file, issue, or PLAN row defines or
accumulates it. At review time the owner would have to sweep ≥6 ledgers.
s17-W4's min/max+per-cell disposition and the analytics campaign (#751/#798)
are mutually unlinked though one is the other's live-consumer trigger.
**Disposition proposal: author the packet file during the pause (one page:
G3 candidates, booked notes, dispositions, each with its ledger pointer).**
→ Q6.

**AF-12 (S4). Priority-policy inconsistencies in the filed set** (standing
policy: prio:high fixed ASAP in-line; nothing parked without a named
landing):
- **#803** — prio:medium with NO landing, at ~1000× an ENFORCED invariant
  (32,648 B/match vs the <1 KB budget; and the body's two ADVISORY lanes,
  9.8 MB vs 1 KB single-set, are worse) in a core mutation verb. Comparable
  true reds (#753/#766/#767/#779) were prio:high and fixed in ≤2 days.
  Doubly non-compliant as filed. Note the fresh red was measured at the
  ~118 KB envelope — the spec'd 10 MB doc has no fresh measurement (AF-4).
- **#793** — prio:low for a fail-open (`:timeout` silently ignored →
  unbounded wait); the house floor for fail-open/silent-degradation has been
  medium-to-high (#702, #713).
- **#794** — prio:low inside a ruled ONE family whose siblings #790/#791
  are medium (batch parent #795 calls them one family).
- **#791** — medium, with a live argument for high: silent loss of S002
  schema enforcement through canonicalization is silent-validation-loss for
  every canonical-text consumer (the registry workaround covers one).
- **#781/#782** — predate the 1a batch ruling; unbatched, no landing
  comments, never flagged for mapping the way #802-#804 were.
- **#802-#804** — confirmed unmapped (PLAN.md has zero hits; zero landing
  comments on the issues). Expected — mapping is this audit's Q1.
**Disposition proposal: Q1 (mapping) + Q2 (relabels).**

**AF-13 (S4-accounting). #744 is stale-bodied.** Its filed error
(`store_find_nl` undefined) no longer reproduces — W4 rewrote the file; the
issue's repro line now fails on 11 unrelated arrow flag/global errors
(audit_gates/issue_744_repro.log) while the supported test lane runs green
in the fresh gate. Needs re-triage: close-with-evidence + refile the arrow
build-lane residue, or update in place.

### S5 — hygiene

**AF-14 (S5).** (a) Stale `_gate_evidence` logs record broken runs as
evidence: gate_1/2/3/4 logs are path-broken script failures ("spec/core/
code.md not found"); gate_28.10.log is ZERO bytes; gate_17.log records a FAIL
that today passes. Evidence that records a failure while the table said ✅ is
worse than no evidence. (b) Stale policy headers in conformance/code.cxd:
the program-err-008..014 block header still says "gate=pending … OPEN OWNER
DECISION" (code.cxd:1780-1789) while the question was RULED 2026-07-11
(#348 ruling (a), code.md:2196 "Err-valued guards and predicates propagate
(normative)", commit 7db680a5) and the fixtures are enforced-green against
the ruled semantics — the header is month-stale drift on a policy surface;
same class at code.cxd:10083-10088 (Stage-B "advisory RED frontier" header
over enforced-green cases). (c) #695 does not back-reference #796 (a #695
implementer won't discover the co-scheduled batch). (d) gate 16's Makefile
comment cites the archived spec path (harmless given AF-4 but part of the
same re-home).

---

## §2 Attack-category coverage (what was checked and came back clean)

1. **False greens:** the July-2026 thrown-error auto-pass class is closed
   (R3.12 fix present + self-tested); program-sap-O1-10b is an out-text
   fixture, structurally immune, a real PathNode discriminator; ev-pull-001/
   003 are counter-based discriminators, enforced, matching the flip claim;
   ev-pull-002's engine-agnostic pass is disclosed by design;
   `streamed_input_commits` is a fully honest witness (engage AND decline
   directions); secret-never-columnar is a real structural pin; gates.cxd
   has zero advisory module rows, deny-by-default confirmed, per-case
   pending/skip rows all carry documented reasons; effects traces reset per
   fixture; #803/#804's fresh red logs are genuine and #803's body discloses
   the advisory lanes its ledger summary omits.
2. **Parity claims:** W4 verdict-once HELD under attack (promotion invariant
   real: attrs/empty-element/mixed-shape/dup-name all decline; null ⟺
   path-absent; plan-first CXER1709 order confirmed; the predicate engine's
   Item projection is provably value-blind in both lanes). L97 flat-relation
   parity held. Stream-16 E2 determinism structurally sound (sorted renders,
   order-independent joins). Stream-20 preimage parity holds for the wrapped
   form its gate asserts (the unwrapped spec identity is AF-3). W2 row-shape
   parity is by shared per-row builder (acceptable). W5/W3 fell — AF-1/AF-2.
3. **Perf budgets:** complete census in §1 AF-4/5/6. Fresh-and-honest:
   gates 14 (PASS 0.3ms/1ms), 16 (PASS, weaker protocol), 15 (honest red
   1.9 MB/s — #804), 30.5 (honest red at mini-envelope — #803). Everything
   else was stale, dead, or never measured until this audit's runs.
4. **Deferral integrity:** #795/#796 batches are real, correctly membered,
   PLAN-recorded, with landing comments on all six member issues (one
   one-directional link, AF-14c). The stream-14 and item-6 receiving sides
   are the gaps (AF-10/11).
5. **Issue triage:** AF-12.
6. **Bug-flow accounting:** §3.

---

## §3 Bug-flow accounting (I5, per stream)

Headline: **closed 32, filed 28** across the I5 streams; 8 of the 28 were
closed in-flight (7 by stream 2 same-day under the ASAP policy; #779 filed
by s1, pinned prio:high, closed by s20 next day — the one churn pair, and it
followed the policy). Net open adjacents: 20 — ~0.8 filed-and-open per
roster issue closed. Classification of the 28 (per issue bodies + ledger
language; largely self-reported, spot-verified on #779/#790):

| class | count | notes |
|---|---|---|
| pre-existing, surfaced by I5 fixtures/gates | ~20 | incl. #803/#804 (honest-red gate repairs; #803's "pre-existing" is unfalsifiable — the gate was unrunnable since ~v0.11.0) |
| spec-drift / docs | ~2 | #770, #792-borderline |
| tooling / mask / flake | ~3 | #802, #778, #744-build-rot |
| design filings | ~3 | #784, #786, #751 |
| **regression introduced by I5** | **0 filed — but this audit found 1 confirmed + 1 probable** | AF-1 (W5, confirmed by execution); AF-2a (W3a, probable — pre-W3a widening preserved the value) |

Per-stream: s1 closed 2 / filed 2 (#778, #779); s2 closed 9 (incl. 7 in-line
same-day) / filed 8; s3 2/0; s4 2/~3 (#744/#749/#751); s5 1/0; s6 2/1
(#780); s7 2/1 (#781); s8 1/1 (#782); s9 2/1 (#784); s10 1/1 (#788); s16
2/3 (#790/#791/#792); s17 0 closed (paused) / 4 filed (#794/#802/#803/#804);
s20 3/2 (#785/#786); s21 2/0; s22 2/1 (#793).

**Reading:** the march is not net-generating defects in the engine — it is
net-generating *visibility* of pre-existing defects, at roughly the rate the
repaired enforcement can see them, exactly as the owner's hypothesis
predicted. The two audit-found regressions do not change that arithmetic,
but they show the filing discipline has a blind spot: both landed inside
waves whose OWN acceptance fixtures were too weak to catch them (AF-9b, and
the unauthored W7 pair family), i.e. the enforcement/engine gap applies to
new work too, not just legacy behavior. The corrective is not "stop
marching" but "no wave ships a by-construction claim without a
counterexample-shaped fixture lane" — which is what W5's decline fixtures
did right and its refusal-parity fixtures did not.

---

## §4 Proposed batch mapping and the lettered questions

The march does not resume from this audit; the owner rules. Questions are
numbered; every option is lettered; recommendations are stated.

**Q1. Batch mapping for #802-#804 (+ the unbatched #781/#782).**
- **(a) RECOMMENDED — create the GATE-TRUTH batch (new umbrella issue):**
  members #803 (head) + #804 + gates 7/8 runner repairs + gate-4
  checker/wiring repair + the abi-§4 measurement driver (AF-6) +
  bench-compare baseline (AF-5) + #802 (the mask-agreement gate is the same
  truth-surface theme). Its own lane immediately after the audit
  disposition, before stream 18 — this batch is the enforcement
  infrastructure the whole march leans on, and #803/#804 stay unfixable-
  honestly until the apparatus measures the spec'd envelopes. #781 → #796
  (test-substrate hygiene fits the defect batch); #782 → #796.
- (b) Fold #803/#804/#802 into #796 — keeps batch count down but buries two
  true engine reds inside a hygiene-adjacent batch that "rides the #695
  wave slot", i.e. schedules them behind unrelated protocol work.
- (c) Fix #803 in-line now, batch the rest per (a) — honors the ASAP policy
  if #803 is relabeled high (Q2), but #803's fix likely needs a HAMT/spine
  investigation that would hold the paused march hostage.
  I recommend (a) with (c) as the fallback if Q2 rules #803 high AND the
  investigation scopes small.

**Q2. Relabels.**
- **(a) RECOMMENDED — all four:** #803 medium→**high** (true red, enforced
  invariant, core verb; the policy's comparables were high), #793
  low→**medium** (fail-open class floor), #794 low→**medium** (family
  consistency with #790/#791 under #795), #791 stays medium but its body
  gains the silent-validation-loss argument for the #795 review.
- (b) Only #803 high, rest unchanged — defensible but leaves the fail-open
  and family inconsistencies standing.
- (c) None — inconsistent with the house classification record.

**Q3. AF-1 (W5 streamed-input divergences — the I5-introduced regression).**
- **(a) RECOMMENDED — fix-now inside stream 17, before W7 exit,
  fixture-first:** pin AF-1a/b/c as refusal-parity fixtures (they become the
  refusal-IDENTITY lane AF-9b calls for), close the three gate gaps (`@`
  scan, Unicode name predicate, yield-body path validation or rooted-form
  decline). The wave's own acceptance criterion ("declines pre-emission,
  reproduces the exact refusal") is the bar; W5 is not done until it holds.
- (b) Disengage the fast path (flip the engagement predicate off) and
  re-land post-I5 — safest, but discards a measured 4.4× RSS win and the
  witness machinery, and "wired-or-removed" was RULED (L91): a disengaged
  seam is the dead seam the ruling forbids.
- (c) File and batch — parks a known wrong-answer divergence in a shipped
  public API behind a paused march; violates the ASAP policy for what would
  be a prio:high bug.

**Q4. AF-2 (wire codec divergences) + AF-3 (serialize trailing LF).**
- **(a) RECOMMENDED — file one wire-render-parity family issue now
  (members AF-2a-e + AF-3), fix AF-2a (u16 wrap) and AF-3 during stream-17
  W7** — AF-2a needs a micro-ruling: refuse out-of-range cells loudly
  (matches the loud-refusal posture; recommended) vs widen-with-header-
  drift (the pre-W3a behavior). The rest of the family lands with the W7
  §9 transparency pair fixtures, which are the exact instrument that
  catches all five classes; W7 should not flip advisory→enforced until the
  family is green.
- (b) Everything to a post-I5 batch — leaves silent value corruption on the
  wire through stream 18 and the M5 proof.
- (c) Fold into #795 — wrong family: #795 is the canonical-TEXT lane;
  these are wire-lane render-parity defects.

**Q5. Gate-registry re-home (AF-4).**
- **(a) RECOMMENDED — a living gates register in-tree** (either a
  `spec/02-working/partition_gates.md` table or an extension block in
  conformance/gates.cxd): every numbered gate → runner path → threshold →
  wiring (TEST_TARGETS / manual / env-gated) → last-honest-verdict; Makefile
  comments repointed; the four fictional §11.4.4 script names amended to
  the real apparatus (spec edit — needs the express authorization this
  ruling would grant); gates 28.11-28.14 explicitly retired or re-asserted;
  gate 16's protocol either upgraded to the spec'd wrk form or the spec
  amended to the in-process form (never silently truing — the mismatch is
  recorded either way).
- (b) Minimal: fix the Makefile comments, wire gate 4, leave the table
  archived — cheap, but the next #803 stays structurally possible.
- (c) As-is — rejected by the evidence.

**Q6. Receiving-side artifacts + W7 scope additions.**
- **(a) RECOMMENDED — authorize all three during the pause:** (1) the
  stream-14 consolidated handoff register (section in
  partition_corpus_audit.md + pointer comment on #686 — AF-10); (2) the
  item-6 packet file accumulating G3 dispositions/booked notes (AF-11);
  (3) W7 scope grows by: engagement witnesses for 0x62/pushdown-verb/
  dict-range (AF-7), the refusal-identity lane (AF-9b), the EV-BUDGET floor
  probe (AF-9a), and the AF-2 family fixtures (Q4a). These are
  paperwork+fixtures, not engine work; they close the receiving-side gaps
  while the march is paused anyway.
- (b) Defer (1)+(2) to stream-14/exit-review time — the information decays
  (ledger prose is already the only copy).
- (c) W7 additions only, no process artifacts.

**Q7. Resume ruling (sequencing after dispositions).**
- **(a) RECOMMENDED — resume stream 17 at W7 with Q3(a)+Q4(a)+Q6(a) folded
  in; the Q1 gate-truth batch runs immediately after stream-17 exit, before
  stream 18.** Stream 17 owns both regressions and the fixture instruments
  that pin them; W7 was already the wave where the transparency family and
  the advisory→enforced flip land. The gate-truth batch then hardens the
  apparatus before two more streams trust it.
- (b) Gate-truth batch first, then W7 — defensible ordering, but W7's
  fixture work doesn't depend on the batch, and the two regressions are
  older than the batch's concerns.
- (c) Full stop until #803/#804 are fixed — disproportionate: both are
  pre-existing engine reds with correct answers (#803) or a scoped lane
  (#804), now honestly visible and mapped.

---

## §5 Scorecard

**As of 554e9f3f (audit report landing) — delta since 554e9f3f (W6 ledger
record): the adversarial I5 audit executed and tabled; no engine, spec, or
fixture changes (read-only mandate).**

**L1 — campaign (#651+#516)**

| Unit | % done | Remaining | Next |
|---|---|---|---|
| Part A (S0-S4 spec waves) | 100% | — | — |
| I0-I4 (seams→profiles) | 100% | — | — |
| I5 (streams) | 85% | s17 W7+fixes, s18, s14; audit dispositions | owner rules Q1-Q7 |
| I6 (M5 proof) | 0% | all | after I5 |
| **Campaign overall** | **85%** | | |

**L2 — phase I5**

| Unit | % done | Remaining | Next |
|---|---|---|---|
| Streams 1-10, 16, 20-22 (14 exited) | 100% | AF-2/AF-3/AF-7/AF-8 dispositions touch exited-stream artifacts (fixes land per Q1/Q4/Q6, not by reopening streams) | — |
| Stream 17 (#689+#710) | 80% | W7 (+Q3/Q4/Q6 additions), exit audit+gate | Q3/Q7 ruling |
| Stream 18 (#690+#715) | 0% | all | after s17 |
| Stream 14 (#686 absorber) | 0% | all + AF-10 register | LAST |
| Adversarial audit (this) | 100% | owner dispositions | Q1-Q7 |

**L3 — stream 17 (runtime representation)**

| Unit | % done | Remaining | Next |
|---|---|---|---|
| W1 EV-PULL | 100% | — | — |
| W2 batch [?for] | 100% | — | — |
| W3a-c lattice | 95% | AF-2a ruling (refuse-vs-widen) + family fixtures | Q4 |
| W4 pushdown | 95% | verb-level witness (AF-7) | Q6 |
| W5 parser_streaming | 85% | AF-1a/b/c fix + refusal-identity fixtures | Q3 |
| W6 PathNode+drift | 100% | — | — |
| W7 §9 family + exit | 0% | pair family + witnesses + flips + closure | after rulings |

**Buckets (out of scope here, tracked elsewhere):** engine-perf drawdown
(#803/#804 + gates 7/8 + abi §4 → Q1 gate-truth batch) · canonical-forms
batch #795 · post-gate defect batch #796 (+#781/#782/#802 per Q1) ·
analytics campaign #800 (#751→#798→#797→#786→#799) · V-runtime campaign
#775 · adoption/platform track #728-#735 · #758 owner-gated.

*Weighting: 5%-coarse; L1 weights Part A 30 / I0-I4 30 / I5 30 / I6 10;
L2 weights streams equally with the audit as a stream-equivalent unit;
L3 weights waves equally with W3's three sub-waves as one unit. Exited
streams count 100% at L2 because their residues are dispositioned into
named batches (Q1/Q4/Q6), not reopened.*
