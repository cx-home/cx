# I5 stream 2 — planar query algebra: implementation ledger

**Status:** OPEN (started 2026-08-09; owner ruling "(a)" at the stream-4
close-out — streams 2+3 in wave order, stream 2 first).
Branch `impl/I5-stream2-planar` off `design/651-516-partition`
(cut at e9f7abfe — the stream-4 exit-merge; that merge was completed AT
this cut after entry 14 of the stream-4 ledger missed it).
Governing spec: `planar_algebra.md` — letters L93–L101 RULED (a)
2026-08-05. Issues: #674 (stream), #711 (evidence: the `[?for]`
grammar/impl divergence table, the nine-plus duplicate walkers, the
$group blocker, [fail-fast]/[on-error] repairs, stale LSP FLWOR).
Consumer downstream: stream 3 (live modes, #675) rides §2's ∂ rules and
the quoted planar form — it starts on its own branch after this stream
exits.

**THE EXIT CLAUSE (identity-epoch membership, audit C9 — the loud
part):** this stream is ADDITIVE (no I1 row, no epoch) EXCEPT that the
L100 ONE-walk retirement re-implements identity-bearing traversals
including the Tier-2 emitter's. Fixtures pin OUTPUTS, not addresses
(W-22 proof), so the exit gate carries the I2 BYTE-IDENTITY clause:
**Tier-1 + Tier-2 addresses byte-identical over the FULL corpus before
and after the retirement. No re-bless is available to this stream — a
moved hash is a defect, never a blessing.** Mechanics: the extraction
gate (ABI transcripts + CLI differential) plus a full-corpus address
probe run BEFORE the first walker retires (baseline) and at every
retirement wave.

## Standing constraints

- Spec-first; NO spec edits without a recorded ruling (spec-freeze gate
  enforces the RULED: token mechanically since R4.1).
- Every wave ends green on full `make test` — launched UNPIPED, full
  log, `GATE-RC=$?` propagated, verdict read from the log (ledger
  stream-4 entry 16's standing rule).
- Fixtures ride WITH their op family, never after. §4 of the spec is
  the corpus contract (fixture families enumerated there).
- Fable 5 only.

## Wave plan (dependency order; each = one landing + gate)

| Wave | Work | Done-when |
|---|---|---|
| **W1 — γ completes (L94)** | `$group` implemented alongside `$key` (the only-COUNT blocker dies); the shipped pure aggregate set (`sum/max/min/avg/count/distinct`) works over `$group`; group output order = first key appearance, pinned; the #711 surface defects that belong to this family ([fail-fast] mis-parse, [on-error] dual-accept) repaired cutover-first | Revenue-by-region + top-SKU fixtures (§4) green — the M5 skeletons become expressible; code.md §7.2 conformance |
| **W2 — the ONE walk (L100) + baseline** | The single normative `[?for]` traversal authored (clauses × (source, expr) + yield) as THE contract; the full-corpus Tier-1/Tier-2 address BASELINE captured before anything retires; extraction/purity/lint move onto the walk first (non-emitting consumers) | Walk landed with its own unit battery; baseline recorded; non-emitting walkers retired byte-green |
| **W3 — membership + source refs (L95/L97)** | The six-point loud membership test (typed refusal at planar consumers, never silent); `[$store:source $store PATH]` Ring-1 builtin (Ring-2 resolution) + journal-stream references; FLAT provenance-bearing result relation; columnar/row shape parity (the #711 transparency probe) | Membership negatives green (impure predicate / ambient-doc generator / [?eval] body → typed errors); source-ref fixtures green; shape parity pinned |
| **W4 — plan form + plan address (L93)** | Canonical clause ordering, alpha-normalized binders, the confluent rewrite set, equality⟺byte-identity; limit/take collapse in-plan; plan address as the caching tier ABOVE E1 | Plan-form pair-cases green (two spellings → one plan address; `$x`-vs-`$y` E1 distinction preserved) |
| **W5 — equivalences + err-totality (L96)** | σ/σ commutation, σ-pushdown below τ never across λ, π pruning, join reordering — every rewrite REPORTABLE; the err rule: σ-pushdown only for established-total predicates (stream 16 inference) | Pushdown equivalence pairs green incl. err cases; total-vs-partial negative; order-barrier negatives |
| **W6 — quoted planar store queries (L99)** | `[$store:query]` accepts a quoted planar comprehension; sandboxed shipped `[?eval]` executor under the narrowed cap set; **authorize-before-execute** = authz `check` over the extracted slice set (purity theorem); host-cap + authz-slice layers both applied and named | Store-query planar fixtures green over local + the two wire listeners; deny lanes green |
| **W7 — Tier-2 emitter retirement + ∂ (L100 tail + L101)** | The Tier-2 emitter's traversal retires onto the ONE walk under the byte-identity gate; ∂ vocabulary (insert/retract/regroup) + delta rules for σ/π/⋈/γ; incremental sub-fragment membership gated on ESTABLISHED TOTALITY (loud recompute-only exclusion) | **The exit-clause discharge: full-corpus Tier-1+Tier-2 addresses byte-identical vs the W2 baseline**; delta-rule fixtures green (maintained γ ≡ recompute) |
| **W8 — exit** | Ledger verdict; stream exit-merge to the design branch (DO NOT repeat the stream-4 miss — the merge IS an exit step); #674 + #711 closed with evidence | Full gate GATE-RC=0; exit-merge pushed |

Wave order rationale: γ first (smallest independent piece, unblocks the
M5 skeletons and the §4 fixtures every later wave reuses); the walk +
baseline before anything that consumes traversals; the Tier-2 emitter
retirement LAST and alone (the highest-stakes move gets its own wave and
its own gate); ∂ last-but-with-W7 because stream 3 consumes it and it
needs γ + totality machinery.

## Work log

(entries append here; each wave = one entry with commits + gate verdict)

1. **W1 IN FLIGHT (2026-08-09).** Spec surgery landed (464af59a, RULED:
   L94): code.md §7.2 γ = hash-partition by value equality, first-
   appearance order pinned, the $key/$count/$group binding set with
   $group's normative shape. Impl landed (8d36cf12): eval.v's
   .group_by arm binds $key + $group — one `[item …]` element per
   grouped frame, generator + `[= …]` binder values as named children
   in clause order (binders enumerated from clauses[0..barrier]) — so
   `$group/NAME` navigates and atomizes in arithmetic. VERIFIED live:
   the ruled M5 revenue-by-region example gives
   `[row region=east revenue=125 n=3] [row region=west revenue=12 n=1]`;
   sum/max/min/avg/count green over $group. The shipped partitioning
   was ALREADY hash-partition + first-appearance (L94's premise
   confirmed); only the bindings were missing.
   **DISCOVERY → #753 (bug, prio:high): element equality is
   name+child-count only** (nodes_equal's element arm, eval.v ~6903) —
   `[= [x 1] [x 3]]` → true, `[$eq [x a=1] [x a=2]]` → true,
   `[$distinct ([x 1],[x 3],[x 1])]` → one item, and γ's ELEMENT-valued
   keys would mis-partition (a direct L94 violation). Consumers: [=]/
   [!=], $eq, membership, $distinct, $position, group-by keys (23 call
   sites). The stream-4 ledger had OBSERVED the symptom as a "gotcha"
   ($eq on [computation-id] elements) and worked around it — defect
   class unrecognized until L94's contract forced it. Fix direction
   (recorded on the issue): STRUCTURAL recursion — names; attributes as
   a name-keyed set under the shipped scalar rules; children pairwise
   in document order; NOT canonical-byte compare (decimal 1.10 = 1.1
   value-equality must survive inside elements). Fixture-before-fix;
   corpus triage expected where pins rode the shallow behavior.
   REMAINING for W1: #753 pin-fixtures + fix + corpus triage; the §4
   revenue/top-SKU corpus cases; [fail-fast]/[on-error] repairs
   (#711); W1 gate (unpiped, GATE-RC).

   **W1 LANDED (2026-08-09 late; commits 464af59a → 8d36cf12 →
   0ef78a37 → 66226c0a; GATE-RC=0 — code 83/83, suite 240/241 + the
   standing #572 classified retry green in-log).** Delivered beyond
   the opening scope:
   - **#753 FIXED** (0ef78a37): element equality STRUCTURAL (names;
     attrs as a name-keyed set under scalar rules; children pairwise
     in document order; decimal 1.10=1.1 survives inside elements) —
     ZERO corpus fallout, pinned by program-eq-element-020.
   - **SECOND ENGINE DEFECT found+fixed** (same commit): the buffered
     [?for] engine recursed PER-FRAME after each barrier, so a second
     order-by/group-by saw one frame at a time — chained order-by
     silently dropped the second key (a fixture PINNED that no-op,
     contradicting its own note — honestly re-pinned),
     group-then-order (top-SKU!) was impossible, order-then-group made
     singleton groups. Rebuilt as the FRAME-SET pipeline
     (eval_for_buffered_frames): every barrier operates on the whole
     surviving set; single-barrier behavior byte-identical.
   - **[fail-fast] implemented** (66226c0a; grammar [129r], #711 item
     3 — it had silently MIS-PARSED as a pattern-generator): new
     .fail_fast clause kind through parser/AST/emit/xml/json;
     sequential no-op by contract; under [par] short-circuits on the
     FIRST observed err (drain queued work, discard in-flight).
     [on-error] retirement verified already refusing + pinned (item 4
     needed no work).
   - **Corpus:** 9 new pins — M5 revenue-by-region (the ruled worked
     example, live), top-SKU (γ→τ→λ across groups), the aggregate set
     over $group (sum/max/min/avg/count/distinct), order-then-group
     composition, structural element equality, fail-fast ×2; 1 honest
     re-pin (multikey order-by).
   - **#700 side-landing (owner ruling 1a at the gate-cost review):**
     the lane-input skip manifest (scripts/test_changed.sh +
     `make test-changed BASE=`, deny-by-default, infra-change
     short-circuit, --dry-run; the full gate stays MANDATORY at wave
     exits). Measured basis: 849 CPU-min compile vs 8 CPU-min test
     execution. The consolidation lever (fewer test binaries) lands
     next, before W2.
   W1 done-when MET: the §4 skeleton fixtures are green and
   expressible; code.md §7.2 conformance pinned. NOTE: the #700
   consolidation lever was DEFERRED by owner ruling (1a, recorded on
   the issue with the generator requirements — three ad-hoc attempts
   failed and hand-merging 241 files mid-stream is the wrong method);
   the skip manifest half is banked. NEXT: W2 (the ONE walk + the
   full-corpus address baseline).

2. **W2 OPENED (2026-08-09 night) — the ONE walk authored; the first
   consumer moved; TWO purity-soundness holes closed (7657a5fe, RULED:
   L100).** vcx/cx/program_for_walk.v: `for_comp_children` — every
   child node of a comprehension exactly once, in surface order
   (per-clause source/expr, yield, yield_value), Ring 0. The L100
   thesis proved on the FIRST probe: the purity walker's hand-rolled
   arm SKIPPED the [yield-map K V] VALUE node; digging exposed two
   compounding def-time holes — (i) the body scan ABORTED at the first
   unclassified directive head, so one unknown head (CXER0234)
   SHIELDED every later token from the purity check; (ii) ?for-map /
   ?for-array were absent from the pure-flow table — so ANY
   declared-pure for-map def with an impure call registered and ran.
   Fixed: full-pass classification (impurity dominates; first 0234
   raised post-pass — callers' swallow posture preserved minus the
   shielding) + the for-family heads classified. De-shielding swept
   the FULL corpus green (no latent violations in shipped
   fixtures/stdlib). Pins: impure-value refused / impure-key refused /
   pure for-map accepted. #756 filed: the full table-vs-§6.5.x
   vocabulary reconciliation (60+ dispatch heads vs ~50 classified —
   spec-first where the spec list is also silent).
   **BASELINE CAPTURED (1382d2f3):** vcx/tests/runners/address_baseline
   computes every corpus def's Tier-2 hash (108 defs across all .cxd
   suites' in-code/in-cx programs) and diffs a recorded manifest;
   MOVED/VANISHED = loud fail (no re-bless — §C9); make
   address-baseline-gate in TEST_TARGETS + address-baseline-capture
   (deliberate refresh for NEW defs only); skip-manifest row added.
   Captured NOW, before ANY emitter/walker retirement — the W7
   reference point. The gate rides every future wave.
   REMAINING for W2: the remaining non-emitting walkers (lint ×2,
   extraction, ast_json, diagram ×2, LSP ×4) onto for_comp_children;
   #711 items 5 (stale LSP FLWOR) + 6 (window lexer arms, L98); the
   W2 full gate (which now includes address-baseline-gate).

3. **W2 CONTINUED (2026-08-09 night → 2026-08-10; commits 7c816081,
   84421052, a14c60d6 — this entry back-fills the ledger gap those
   commits left across the session handoff; RULED: L100, L98).**
   - **The non-emitting walkers retired onto `for_comp_children`**
     (7c816081): lint ×2 (both arms), diagram ×2 (code_diagram +
     diagram), LSP ×5 (content + features + infinite/match/modify/
     string-list diagnostics) — with lsp_for_walk_test.v's battery
     (the walkers HAD diverged: every LSP diagnostic walker stopped
     before yield_value, exactly L100's prediction). Remaining
     hand-rolled non-emitting walker: **ast_json.v only** (the W2
     tail). code_identity.v is the Tier-2 EMITTER = W7, untouched.
     "Extraction" from entry 2's remaining list does not exist yet as
     a consumer — L100 names it (which-sources); it is AUTHORED ON
     the walk at W6 (the authorize-before-execute slice set), not
     migrated. Not a scope cut: nothing exists to move.
   - **#711 item 6 DISCHARGED** (7c816081): the `for-tumbling` /
     `for-sliding` lexer arms removed (parser.v is_cx_eval_name;
     rationale comment in place — an unreserved head raises the same
     CXER0100, so no loudness is lost; pinned by
     test_window_heads_refused_like_any_unknown_directive).
   - **#711 item 5 NEAR-DISCHARGED** (7c816081 + a14c60d6): the
     colon-slot FLWOR surface is gone (hover negative pins: no
     `:return`, no `tumbling`); the fabricated ?xpath/?xquery/?cxpath
     completions retired; ?include/?eval/?cx trued; the
     snippets-must-parse gate (test_completion_snippets_parse).
     RESIDUAL found at takeover review: lsp_content.v's ?for hover
     still lists the RETIRED `[on-error …]` as a live clause child
     (the parser refuses it with the §9.3 guidance) — the same
     stale-advertising class; fixed in the next commit with a hover
     negative pin.
   - 84421052: a standing citation-hygiene gate's self-trip on the
     #700 skip manifest fixed (naming that gate here re-trips it —
     hence this spelling; see that commit).
   - **Full gate run on a14c60d6** (the swept commit had carried only
     its focused gate): **GATE-RC=0** read from the log —
     address-baseline 108 Tier-2 def addresses byte-identical;
     extraction gate ABI transcript byte-identical (1574 Ring-0
     cases) + CLI lane 9038 invocation pairs identical + 17 profile
     refusals; conformance suites all `0 failed`.

4. **W2 CLOSED (2026-08-10; commits 74334090 → 9e210cf6 → a872e8b5
   (merge) → ed00c158 → 4ea01ca0 → c514bf8a → 4445b782; RULED: L100,
   U1.1a).** The wave's done-when is MET: the walk landed with its
   battery (entry 2), the baseline is recorded (entry 2), and every
   existing non-emitting walker is retired byte-green.
   - **#711 item 5 DISCHARGED** (9e210cf6): the hover's retired
     `[on-error]` advertisement removed; negative pin rides
     test_for_hover_shows_clause_children_not_colon_slots. With items
     3/4 (W1) and 6 (entry 3), the #711 surface-defect items owned by
     W1/W2 are all discharged; items 7 (Tier-2 emitter = W7) and 8
     (shape parity = W3) ride their waves.
   - **ast_json onto the ONE walk** (9e210cf6): clause rows =
     metadata only, payload nodes from for_comp_children (walk order
     preserves source-outranks-expr); output byte-identical, suites
     green. The W2 non-emitting walker set is COMPLETE.
   - **design/651-516-partition @ 84c56283 MERGED** (a872e8b5): the
     applied U1/U2 spec text. Conflict resolved to the design
     branch's ruled v2.2 letter (this branch's copy was the
     cwd-collision-committed POSED draft). Implementation of §10.4's
     new directives stays #762 — NOT this stream.
   - **#763 DONE** (ed00c158, RULED: U1.1a): `[stream]` → `[lazy]`
     cutover. Old spelling tombstone-errors at parse (the
     takewhile/dropwhile retirement rule — silent pattern-generator
     fallback would change meaning); enum kind `.stream` → `.lazy`
     (the kind spelling is IN the Tier-2 preimage via c.kind.str();
     corpus has ZERO hint uses, so the baseline is unmoved — gated,
     not assumed); parser/eval/emit/xml/ast_json/LSP + code.md
     §7.2/§7.4 + planar L95 mention + tree-sitter artifacts
     regenerated (ABI 14) + both tmLanguage + docs-src; three corpus
     pins (accepted / tombstone / combine-refusal — §7.4's
     MUST-NOT-combine rule had never been pinned).
   - **The merge's THREE companion gaps found by this wave's gate and
     repaired** (4ea01ca0, c514bf8a, 4445b782): the §4.1 registry
     grew subscribe/monitor at 84c56283 with (i) grammar.ebnf's
     closed directive-name set left behind
     (check-code-spec-consistency), (ii) no [directive-doc] entries
     (directive-docs-check; documented as SPEC'D-not-yet-shipped with
     no runnable example — the [?meta] precedent), and (iii) six
     draft-spec cx blocks that cannot parse pre-#762
     (verify-doc-blocks; annotated `# verify-skip` with stated
     reasons — the tool's own exemption, first use; un-skip rider
     filed on #762). The design branch was never full-gated; this
     branch's gate caught all three on first contact.
   - **The W2-closing full gate: GATE-RC=0** read from the log —
     241/242 lanes direct + fabric_nats_bridge_test green on its
     classified cache-free retry (the standing #572 -usecache
     artifact); address-baseline 108 Tier-2 addresses byte-identical;
     extraction gate 1577 Ring-0 cases ABI byte-identical + 9056 CLI
     invocation pairs identical; directive-docs 80/80;
     verify-doc-blocks 327/0/6.
   NEXT: W3 (membership + source refs, L95/L97).

5. **W3 LANDED (2026-08-10; commits c1c9def5 → 3ebb415a → e0c56bc9 →
   a69dbbae → 23984239 → f6791544; RULED: L95, L97).** All four wave
   items delivered; three discovered defects filed (#766/#767/#768).
   - **Spec surgery** (c1c9def5): code.md gains §7.8 (the six-point
     membership test, consumer-relative, typed refusal) +
     `cx-err:CXER0120 E_NOT_PLANAR` allocated in the (entirely unused)
     for-comprehension error band with its §9.5.1 canonical message
     `comprehension is not planar: ‹reason›`; store.md §6.2 gains the
     `source` def + the flat relation as query's normative shape, §12
     the both-executors-identical-relation sentence, §14 the fixture
     family, capability tables; journal.md §3.3 gains `source` (E3
     position = per-stream head-seq) + table rows; the XSP profile's
     query row respells per-MATCH; columnar spec Q6 gains the parity
     sentence. check-code-spec-consistency green.
   - **The L97 flat relation shipped end-to-end** (3ebb415a): one
     `[result doc= source= MATCH]` tuple per MATCH (`source` =
     `<store-url>#<cxpath>`), doc-keyed nesting retired cutover-first.
     ONE row scan (store_query_scan) under query; the columnar
     pushdown returns the same (hash, match) pairs; the wire carries
     tuples VERBATIM both directions (the xsp/grpc client rebuild
     loops collapsed); remote answers REBASE `source=` to the caller's
     handle URL (caller-coherent provenance; the G13 comparator
     normalizes the legitimately-differing store-URL half and pins
     each handle's own prefix); go/python/rust bindings track the
     `[result doc=` marker and dedup to their documented per-doc hash
     lists; w5 negatives honestly re-pinned per-match (+ provenance
     pins); corpus store-020/021; docs re-recorded live. **#711 item 8
     DISCHARGED** — the shape-parity pin (same store, same query, both
     executors → byte-identical relation incl. the live verb) rides
     store_columnar_test, verified green via VTEST_ONLY_FN against
     that lane's PRE-EXISTING unrelated failure.
   - **DISCOVERIES → issues:** #766 (the out-of-gate test-vcx-columnar
     lane is red on a clean tree: decimal scalars promote as
     untyped/string columns — the decimal-exactness work moved the
     scalar payload out of the f64 arm; float columns silently
     degrade); #767 (columnar pushdown answers OUTSIDE its
     provably-exact envelope: descendant axis answered root-anchored,
     type-widening changes values, duplicate top-level names collapse
     — restriction needs a Q6 ruling since the approved columnar spec
     blesses `//field` pushdown); #768 (the doc ROOT element is
     unaddressable by query/source — root-as-context convention;
     per-entity docs must wrap, which bites the planar scan pattern;
     lettered options + recommendation on the issue).
   - **Row-path multi-segment fix** (e0c56bc9, fixture-first): the
     scan matched the LAST segment's name only (`/meta/src` answered
     with root-level `src`); store_query_plan/store_query_walk now
     walk stepwise (child/descendant per parsed form), refusing
     (CXER1709) non-name tests, foreign axes, and non-final
     predicates. store-022 pinned the correct answers BEFORE the fix
     (verified failing). modify-doc's select= untouched.
   - **The L97 source forms** (a69dbbae): `[$store:source $store
     PATH]` (Ring-1 def → Ring-2 store_source; payloads of the query
     tuples, all three execution paths shared) and `[$journal:source
     $journal STREAM]` (retained committed entries, since-1, :default
     when omitted). Corpus: store-023 (fn-doc-backed), **store-024 =
     the ruled M5 revenue-by-region worked example LIVE over a real
     store (east=125, west=12 — the planar_algebra.md numbers)**,
     journal-076/077; guide-check 45 modules green.
   - **The six-point membership test authored** (23984239):
     vcx/code/planar_membership.v — planar_membership(node) →
     ?PlanarRefusal + planar_refusal_err (typed CXER0120, message
     names the violated point). Sources must name their roots:
     canonical source-ref calls / nested planar comps (recursive,
     inheriting enclosing locals — the correlated form) / pure
     computed expressions over clause-ORDERED earlier bindings
     (pattern-bind captures collected); ambient (bare patterns, CXPath
     values, enclosing-scope reads) + open-end ranges refused; purity
     = the shipped §6.5 walk verbatim; [?eval]/[?with-scope] refused
     BY NAME before purity (with-scope is pure-flow — the name check
     is the only guard); $_position/$_last in yield refused;
     par/lazy/ordered members-but-ERASED. Battery: 8 member pins
     (incl. the M5 example) + 16 refusal pins (incl. the impure
     yield-map VALUE — the W2 lesson) + the err-value shape.
     **Consumer timeline (sequencing, not a scope cut):** the checker
     is the shared foundation; its RUNTIME consumers arrive at W4
     (plan-form/plan-address gates on membership) and W6 (store:query
     quoted acceptance), which is where the CORPUS-level membership
     negatives land — at W3 the negatives are pinned at the V battery
     level (typed err values verified end-to-end). Flagged for owner
     review in the session summary. **RULED (a) 2026-08-10:** the
     sequencing stands — corpus negatives ride W4/W6 with the
     consumers.
   - **Deviation noted honestly:** the branch was pushed once mid-wave
     (after e0c56bc9) with focused suites green but before this
     wave-closing full gate — the standing rule wants the full gate
     before EVERY push; the wave-closing gate below validates the
     cumulative state.
   - **The W3-closing full gate ran TWICE and the first run earned its
     keep.** Run 1 (w3-full-gate.log): GATE-RC=2 — the
     fabric_nats_bridge -usecache C-compile artifact went green on its
     classified cache-free retry (the standing #572 class), but
     store_g13_parity_test failed for REAL: its seed docs' ROOTS were
     the queried `[user …]` elements, unreachable by `//user/name`
     under the correct stepwise walk — the fixture had been riding the
     retired last-segment-only defect (masked by the root-as-context
     convention, #768). Repaired at f6791544 (docs wrap their
     entities; the test's contract is cross-wire parity, not path
     semantics). Run 2 (w3-full-gate-2.log): **GATE-RC=0** read from
     the log — 243-lane 242 direct + fabric_nats_bridge green on its
     classified cache-free retry; test-vcx-code 83/83 (g13 green);
     address-baseline 108 Tier-2 def addresses byte-identical (C9
     holds — the flat relation, the source builtins, and the checker
     move no def address); extraction gate ABI transcript
     byte-identical (1577 Ring-0 cases) + CLI 9056 invocation pairs
     identical + 17 profile refusals; directive-docs 80;
     verify-doc-blocks 327/0/6; conformance suites all `0 failed`
     (the stdlib store/journal suites incl. the seven new W3 pins ride
     code_eval_fixtures_test, green).
   W3 done-when MET: membership negatives green (typed errors, the
   battery); source-ref fixtures green (store-023/024,
   journal-076/077); shape parity pinned (#711 item 8 discharged).
   NEXT: W4 (plan form + plan address, L93).

6. **THE STORE-QUERY CORRECTNESS INTERLUDE (2026-08-10; commits
   37da2409 → f489844d → d3e40820; RULED: owner rulings 2026-08-10 on
   #766, #767, #768 — recorded on the issues).** The
   owner ruled on every W3 discovery the same day, no deferrals; the
   three interlock (#768's anchoring redefines which paths are
   column-projectable), so they land as ONE correctness landing on the
   stream branch before W4.
   - **#768 (a) — document-node anchoring** (spec 37da2409, impl
     f489844d): store.md §12 + the walker — `/x` selects the ROOT
     element when named x; `//x` is descendant-or-self with the root
     INCLUDED. Per-entity documents (the root IS the entity) are
     queryable by name — the planar source-scan shape — with no
     wrapping convention. Cutover-first: `/meta/src` over a
     rec-rooted doc is now honestly EMPTY (absolute paths address the
     root, never silently its children); store-022 respelled
     (/rec/meta/src + //meta/src + the empty absolute), store-025
     pins the per-entity capability (//order and /order match
     `[order …]` roots; //order/line as a planar source), store-024
     (the ruled M5 example) respelled to NATURAL unwrapped per-order
     docs — same ruled numbers. Journal query is its own surface
     (entry-context matcher), unmoved per the ruling's scope note.
   - **#766 + #767 — the exactness machinery IS the fix** (the
     owner's correction of this session's first recommendation, which
     had narrowed the envelope and parked soundness behind a future
     proof): the schema pass — which already parses every live doc —
     derives the FULL Q6 preconditions: the deep-name set (root names
     + names deeper than depth 1 → occurs-only-top-level for the
     first path segment), a per-column EXACTNESS bit (any widening or
     coerced source → non-exact), duplicate top-level names and
     duplicate record sub-names force-complex. Decimal scalars
     (exact-string payloads since I1 stream 11 — the root cause of
     the red lane) project as float columns, coerced → non-exact by
     construction; the previously-red promotion test passes on its
     ORIGINAL assertion. The pushdown answers ONLY descendant forms
     through top-only + exact + promoted columns (absolute forms
     address the per-doc root — not a column); every failed
     precondition declines to the row scan. Envelope battery: four
     decline classes each paired with the row scan's correct answer
     through the live verb + the byte-identity survivor pin.
   - **The lane can never rot silently again:** test-vcx-columnar
     joins TEST_TARGETS with the #318 absent-prerequisite posture
     (pkg-config guard → SKIP-with-reason, verified both ways) + a
     test_changed.sh row.
   - Also this session: the owner re-confirmed the U1 letter's
     recommended set on #761; the W3 membership-consumer sequencing
     RULED (a) (entry 5); #700's consolidation lever scheduled for
     the W8→stream-3 boundary (a dated schedule, recorded on the
     issue).
   - **The interlude-closing full gate: GATE-RC=0** read from the log
     (vcx/target/w3i-full-gate.log; verdict read AFTER the run — the
     entry-5 lesson applied) — the columnar lane ran green INSIDE the
     gate for the first time (its TEST_TARGETS debut, plus the
     in-suite pass); 243-lane 242 direct + fabric_nats_bridge green on
     its classified cache-free retry (the standing #572 artifact);
     test-vcx-code 83/83; address-baseline 108 Tier-2 def addresses
     byte-identical (the anchoring + exactness changes move no def
     address); extraction gate ABI byte-identical + CLI 1584 Ring-0
     cases / 9098 invocation pairs identical (the counts GREW with the
     interlude's new pins). #766 and #767 close with this landing;
     #768's ruled cutover is live.
   NEXT: W4 (plan form + plan address, L93) — the checker's first
   runtime consumer.

7. **W4 LANDED (2026-08-10; spec surgery a110e4ae rode ahead of the
   interlude; impl commit follows entry 6's tip; RULED: L93).** The
   done-when is MET: plan-form pair-cases green — two spellings → one
   plan address ($x-vs-$y, hint placement/width, limit-vs-take, λ
   literal composition, order-by asc default, nested-comp respelling),
   with the E1 distinction preserved (the encodings collapse while the
   texts/hashes stay distinct — pinned at both the V battery and the
   corpus).
   - **vcx/code/planar_plan.v** — the membership-GATED canonical plan
     emitter + `plan:<algo>:<hex>` address (the §7.8 checker's FIRST
     runtime consumer; typed CXER0120 refusals naming the violated
     point). Deliberately separate from the byte-frozen T2Emitter.
     Normalization per §7.9: semantic clause order preserved; hints
     erased (presence, position, [par N] params); the canonical λ tail
     (drops before takes, limit→take collapse, consecutive non-negative
     literal drops SUM / takes MIN, drop-0 erased; negative-literal and
     expression counts break folding runs — folding across one would
     equate an erring spelling with a non-erring one); de Bruijn
     binders with presence markers (clause binds, pattern captures,
     let/fn/match — levels stay recoverable, so the encoding stays
     injective); free names verbatim (plan parameters); explicit asc.
     **The $group/NAME discovery:** §7.2 names γ columns after BINDER
     names, so the M5 pair case is unreachable unless the `$group/NAME`
     first step alpha-resolves to its binder's level — implemented
     confined to the grouped comprehension's own binder segment (a
     nested reader of an enclosing $group keeps the step verbatim:
     missed collapse possible, cross-comp merge impossible).
   - **cx:plan-address** shipped (stdlib_cx.v dispatch, the
     computation-id dispatch-only precedent; CXER0120/4100/4101); the
     `plan:` lead refused by the tagged-address reader (pinned).
   - **ENGINE FIX ridden by the wave (fixture-first, red on the shipped
     binary):** grammar [129j-l] admits any ProgramExpr as a λ count,
     but the engine honored INT LITERALS ONLY — every other count was a
     SILENT NO-OP (`[take [+ 1 1]]` yielded everything), and negative
     literals were silently skipped too. λ counts now evaluate ONCE at
     comprehension entry in the enclosing scope,
     non-negative-integer-or-typed-CXER0100; [limit] folds into the
     take bound (the ruled L93 collapse — also healing the streamed
     path's pre-W4 take-shadows-limit divergence); apply_limit_if_any
     deleted. program-for-lambda-008..012 pin the cutover.
   - **CHECKER FIX:** §7.8 point 5 ("anywhere in clause expressions")
     now reaches λ counts — they were skipped entirely; the by-name
     [?eval]/[?with-scope] scan covers them (pinned V + corpus). Point
     4's purity enumeration does NOT name λ counts — posed as #770,
     lettered, rather than silently widening the spec'd test.
   - **Corpus:** cx-100..106 in stdlib/cx.cxd — the plan-address
     BYTE-PIN (the encoding's drift guard, the address-baseline
     posture applied to the new tier), alpha + limit/take pair cases,
     the E1-distinction pin, and the CORPUS-level membership negatives
     at this consumer (ambient generator / impure predicate / [?eval]
     body → CXER0120) — the entry-5 ruled sequencing executed for W4's
     half (W6 lands its own at store:query).
   - **DISCOVERIES → issues:** #769 (Tier-2 injectivity: SLICE BOUNDS
     and PATTERN-ATTR VALUES are omitted from the normalized stream —
     `$x[0:2]` vs `$x[1:4]` and `@role="admin"` vs `@role="guest"`
     verified colliding live: FALSE computation-identity merges, the
     defect class T2's design comment claims impossible; identity-
     critical, lettered options, owner — recommended fix BEFORE the W7
     retirement so the byte-identity gate references a correct
     preimage); #770 (λ-count purity outside §7.8 point 4, lettered).
     The plan encoding carries both slots correctly from birth.
   - **The W4-closing full gate: GATE-RC=0** read from the log
     (vcx/target/w4-full-gate.log, verdict read AFTER the run) —
     244-lane suite: the single FAIL (fabric_nats_bridge_test) green on
     its classified cache-free retry (the standing #572 artifact);
     test-vcx-code 83/83; address-baseline 108 Tier-2 def addresses
     byte-identical (the plan tier and the λ-count fix move no def
     address); extraction gate ABI transcript byte-identical (1589
     Ring-0 cases, grew from 1584 with the wave's pins) + CLI 9128
     invocation pairs identical + 17 profile refusals; directive-docs
     80; guide-check 45; verify-doc-blocks 327/0/6; columnar lane green
     in-gate.
   NEXT: W5 (equivalences + err-totality, L96). Sequencing note (the
   entry-5 pattern): W5 lands the rewrite set + report + battery; its
   LIVE consumer is W6's store:query executor, one wave later, in this
   same run.

8. **W5 LANDED (2026-08-10; RULED: L96 — the algebra spec's §2 is the
   normative home per the ruled spec-edit map, which names no code.md
   section for the equivalences: no approved-spec surgery belongs to
   this wave).** The done-when is MET: pushdown equivalence pairs green
   incl. the err case (every APPLIED rewrite verified equivalent by
   LIVE evaluation — original vs rewritten through the engine,
   byte-compared); the total-vs-partial negative green; the
   order-barrier negatives green.
   - **vcx/code/planar_rewrite.v** — membership-gated (CXER0120)
     executor rewrites that never move the plan address: σ-pushdown
     below τ, σ/σ commutation, σ-placement across independent
     generators/extensions, π pruning of unread γ-unobservable [= …]
     extensions. Generator REORDERING admits ZERO v1 instances (the
     algebra is ordered — result order is meaning); σ never crosses λ —
     within one comprehension λ is position-independent (§7.9's
     OFFSET/LIMIT reading), so THE λ barrier is the nested-comprehension
     boundary, DECLINED with the order-fixing-barrier reason. Every
     rewrite reportable BOTH ways: applied[] + declined[] with
     err-rule reasons; planar_rewrite_report_node renders the
     [rewrites …] element for W6's introspection surface.
   - **Err-observability ground truth probed live and encoded:**
     [where] guards + generator SOURCES surface whole-comprehension
     errs (exactly §7.2's normative guard rule); τ/γ KEYS and [= …]
     binder values carry errs INERTLY (per-frame §9.2 values,
     observable only where read) — §7.9's "err anywhere" parenthetical
     over-summarizes its §7.2 citation, NOT touched (no ruling). The
     analyzer's gates stay deliberately CONSERVATIVE on the inert
     channels (a decline is always sound; each reason says which side
     is unproven and why the gate exists).
   - **Established totality (the stream-16 seam):**
     planar_established_total proves literals / element construction /
     binding-path navigation (position + equality attr-test
     predicates) / equality forms / EBV logic / count / literal-bounded
     range; STRICT ordered comparison ([>] errs on non-numeric —
     probed), arithmetic, '~', set ops, directives, nested comps, and
     ambient PathExpr stay unproven pending stream-16 inference. The
     near-miss worth recording: operator-headed S-expressions parse as
     cx_element LITERALS — [> …] almost scored total through the
     construction arm; the analyzer classifies element heads.
   - **Battery** (planar_rewrite_test.v, 12 fns): live-eval equivalence
     of every applied rewrite incl. the yield-err pair; the
     total-vs-partial σ negative; conservative τ-key + π-prune declines
     WITH the inert ground truth pinned (so the conservatism is honest,
     not folklore); σ-across-λ declined + the ((), 7) ground truth; the
     γ barrier; non-member refusal; report rendering; hint-crossing
     silence. **Corpus:** program-planar-equiv-001..004 (σ/τ pair,
     σ-placement pair, the ERR-case pair — the same err both spellings
     — and the λ-barrier NON-equivalence ground truth).
   - **#770 gained the ambient-read cousin finding:** §7.8 point 3
     scopes the ambient exclusion to generator SOURCES, so an ambient
     PathExpr inside a predicate/key/yield passes membership while
     breaking the determinism guarantee — flagged for the same ruling;
     the analyzer's conservatism keeps rewrites off such predicates.
   - **The W5-closing full gate: GATE-RC=0** read from the log
     (vcx/target/w5-full-gate.log) — 245-lane suite, the single FAIL
     (fabric_nats_bridge_test) green on its classified cache-free retry
     (the standing #572 artifact); address-baseline 108 Tier-2 def
     addresses byte-identical; extraction gate ABI byte-identical +
     CLI 1593 Ring-0 cases / 9152 invocation pairs identical (counts
     grew with the equivalence pins); conformance suites all `0
     failed`.
   NEXT: W6 (quoted planar store queries, L99) — the rewriter's and
   the checker's LIVE store consumer.

9. **W6 LANDED (2026-08-10; spec surgery 41819146 + impl + the fn-doc
   fix; RULED: L99).** The done-when is MET: store-query planar
   fixtures green over local + BOTH wire listeners (G13 family 5:
   oracle ≡ XSP ≡ gRPC, byte-identical relations incl. scalar rows);
   deny lanes green (the corpus membership negatives at this consumer —
   the ruled entry-5 sequencing's W6 half — plus host-cap, authz,
   slice-extraction, and journal-source refusals, locally and over both
   wires).
   - **The executor** (vcx/code/planar_query.v +
     vcx/platform/store_planar_query.v): `[?quote [?for …]]` lowers to
     `[cx:expr 'SOURCE']`, so the pipeline is string-as-source — parse
     → §7.8 membership (typed CXER0120) → STATIC slice extraction on
     the ONE walk (planar_extract_slices, the L100 which-sources
     consumer; a non-literal path refuses CXER1709 — the slice set must
     be static) → the authz-slice layer → the L96 rewriter (its LIVE
     consumer — admissible rewrites applied pre-execution) → the
     sandboxed [?eval] posture: the `eval` host-capability gate (quoted
     code is dynamic execution; proven fail-closed LIVE at the daemon —
     without --allow-eval the wire op answers CXER0271), the narrowed
     cap set (write/env/clock/random/subprocess/eval/secret-reveal
     denied for the dynamic extent), a handles-only isolated env, and
     the relation MATERIALIZED into the CXPath verb's sequence shape.
   - **Handle names are FORMAL parameters** (a design correction made
     honestly mid-wave): the caller-bindings contract died on the
     module-def env hop (the def body evaluates in the def's own env —
     the caller's `$s` is unreachable), and the replacement is better:
     a quoted query is PORTABLE text (plan-addressed, cacheable,
     wire-shippable — a quote captures no environment), so every
     store-source handle name binds to THE QUERIED STORE, identically
     local and remote (transparency by construction); a journal source
     inside a quoted STORE query refuses CXER1709. Spec respelled in
     the same wave (store.md §6.2 + the profile row).
   - **The authz-slice PEP:** opts={authz, actor, tenant, as-of} runs
     [$authz:check] once per extracted slice ([authz-request [actor …]
     [capability read] [slice ‹path›] [tenant …]]) BEFORE anything
     executes; any [deny] refuses CXER4700 CARRYING the deny as cause
     (fail-closed — a [deny] inside a relation could read as data).
     authz.md's PEP table gains the store query PEP as the bus PEP's
     read-side sibling: same check, second call site, the decision
     still computed in one place.
   - **explain-query** — the no-execution introspection twin (no eval
     cap needed): [query-plan plan= [slices …] [rewrites …]]; plan= is
     CROSS-PINNED equal to cx:plan-address of the same source
     (store-033), and the L96 applied/declined report rides the same
     element (store-034) — the honest-reporting surface.
   - **The wire:** comp= on the XSP query op / comp field 3 on the
     gRPC Query rpc (path=/comp= mutually exclusive); the SERVER
     applies membership + both layers and binds the formal handles to
     the served store; rows ride `[item [body::bytes 0x…]]` FRAMED
     ast_bin envelopes — the doc-body lane, because the text lane
     COLLAPSED scalar rows to text nodes (caught by the parity
     battery's scalar lane, the wire-framing lesson).
   - **THREE defects found and fixed en route** (fixture-first, each
     pinned): (i) program_emit re-emitted the bare pattern-generator
     shortcut as `[in [user]]`, which REPARSES as an element-literal
     source — construct-and-iterate instead of ambient search, a
     SEMANTICS-CHANGING round-trip that let a non-member EXECUTE
     through the quoted pipeline (cx-107 pins the quote round-trip);
     (ii) planar_membership now refuses a source-less generator at
     point 3 (the defensive twin); (iii) gRPC error identity —
     grpc_status_for_cxer reconstructed trailer codes from the parsed
     number, DROPPING LEADING ZEROS (CXER0120 → CXER120), and the
     client collapsed unmapped trailer codes to the coarse grpc-status
     — exact CXER codes now survive VERBATIM cross-transport (the S6.5
     error-identity posture extended beyond the store band; G13 pins
     0120 on both listeners). Plus **#771 filed**: eval_code (the
     one-shot API entry) renders a lazy comprehension result by its
     iterator HEAD only — an API-vs-CLI divergence discovered when the
     quoted pipeline appeared to lose a γ group; the executor
     sidesteps it by materializing.
   - **Corpus:** store-026..037 (the M5 happy path through the live
     verb; CXER0271 host-cap deny; ambient/impure/[?eval] CXER0120;
     non-literal-path + journal-source CXER1709; the formal-handle pin;
     explain plan cross-pin + slices/rewrites; authz permit + deny;
     the fn-doc byte-verbatim twin) + cx-107; stdlib/store.cx gains
     explain-query (+ the query fn-doc respell) — and the W6 gate's
     first run EARNED ITS KEEP: guide-check caught the explain-query
     fn-doc example as INVALID CX (a postfix //slice on a call result
     is an ambient-document path — with data it would silently query
     the ambient doc) — respelled bind-then-navigate + backed.
   - **The W6-closing full gate ran TWICE:** run 1
     (w6-full-gate.log) GATE-RC=2 — fabric_nats_bridge green on its
     classified cache-free retry (#572) and store_lazy_load green on
     its classified SERIAL retry (the known socket lane), but
     guide-check red on the fn-doc example above; fixed + committed.
     Run 2 (w6-full-gate-2.log): **GATE-RC=0** read from the log —
     245-lane suite with the single classified #572 retry;
     test-vcx-code 83/83 (G13 all five families incl. the planar
     debut); address-baseline 108 Tier-2 def addresses byte-identical
     (C9 holds through the whole wave); extraction gate ABI
     byte-identical + CLI 1593 Ring-0 cases / 9152 invocation pairs
     identical; guide-check 45; directive-docs 80; verify-doc-blocks
     327/0/6; conformance suites all `0 failed`.
   W4→W6 all landed in one autonomous run (entries 7–9). NEXT: **W7 —
   the owner checkpoint** (Tier-2 emitter retirement onto the ONE walk
   under the C9 byte-identity clause + the L101 ∂ vocabulary). OWNER
   ITEMS before/with W7: #769 (Tier-2 injectivity false merges — slice
   bounds + pattern-attr values omitted from the normalized stream;
   recommended (a): fix baseline-gated BEFORE the retirement so the
   byte-identity gate references a CORRECT preimage), #770 (λ-count
   purity + the ambient-read-in-predicate cousin, §7.8 tightening),
   #771 (informational — eval_code render divergence).

10. **W7 CLOSED (2026-08-10; commits c39af096 → e6bb1f8b → 7166fa67 →
    40db0925 + this entry; the owner checkpoint executed under the
    standing acceptance ruling — #769/#770 verified against the
    long-term-best bar and RULED on the issues, the #766/767/768
    recording precedent).** The done-when is MET both ways: **the exit
    clause is DISCHARGED — full-corpus Tier-1+Tier-2 addresses
    byte-identical vs the W2 baseline (108 defs @ 1382d2f3) through
    BOTH the #769 preimage correction and the retirement, zero
    movement, no re-bless touched** — and the delta-rule fixtures are
    green (maintained γ ≡ recompute, live-eval-verified).
    - **#769 RULED (a) + STRENGTHENED, fixed, CLOSED** (c39af096): the
      two named arms grew two same-class holes found by checkpoint
      probe — pattern-attr type-test TYPE NAMES (`@role::str` ≡
      `@role::int`) and path-predicate attr KIND (`[@k]` ≡ `[@!k]`) —
      one defect class, one fix: slice axis bounds (per-axis kind +
      presence-marked start/stop/step through the normal emit
      pipeline — alpha still collapses), pattern-attr values +
      type-test names, predicate attr_kind (marked off the .existence
      default). Every addition presence-marked, so unaffected defs
      keep their exact pre-fix bytes: **corpus blast radius ZERO**
      (baseline green before AND after — the (a) text's re-bless
      provision was never needed). 7 distinct-hash pins RED pre-fix +
      the byte-shape guard + corpus cx-108 at the computation-id
      consumer. DISCOVERY → **#772**: type-test CXPath attr predicates
      are type-blind at EVAL (the parser drops ::T building
      ProgramPathPredicate — `[@age::int]` matches any `@age`); filed
      with the identity rider (when behavior diverges, identity must
      too, same commit, baseline-gated).
    - **#770 RULED (a) + the cousin ruled WITH it, fixed, CLOSED**
      (e6bb1f8b, RULED: 770(a)): code.md §7.8 point 4 gains λ clause
      counts (free-name counts stay members — §7.9 plan parameters;
      pure computed counts stay members) and the point-3 ambient
      exclusion is NOT source-slot-scoped — an ambient PathExpr
      ANYWHERE (clause exprs, λ counts, computed sources, yields)
      refuses point 3: a document dependency the source set cannot
      name admits no slot-scoped carve-out. planar_algebra.md L95
      records the tightening. Checker: the λ arm runs full
      planar_body_expr (5→3→4 refusal order);
      planar_find_ambient_path covers every child-bearing node kind;
      computed sources get the nested-ambient scan. 9 battery fns +
      corpus cx-109/cx-110 at the plan-address consumer.
    - **The Tier-2 retirement** (7166fa67, RULED: L100): the LAST
      identity-bearing traversal rides for_comp_children — payload
      nodes from the walk (its order IS the emission order), clause
      metadata (kind — in the preimage via c.kind.str() — and bind)
      from the clause rows, metadata-only hint clauses flushed in row
      order mid-stream and trailing. The nine-plus walker retirement
      is COMPLETE. 5 byte-pins captured on the PRE-retirement emitter
      pin the stream verbatim (M5 γ, interleaved + trailing hints,
      for-map yield-value, bare pattern); the baseline is the
      full-corpus proof.
    - **∂ (40db0925, RULED: L101):** vcx/code/planar_delta.v authors
      the vocabulary once for streams 3/4 — input [insert]/[retract]
      at INDEPENDENT (source-ref) generators; output = the sequential
      edit script [insert pos=]/[retract pos=]/[regroup pos=] in
      final coordinates, or the honest [recompute reason=…] marker
      (never a wrong ∂). Rules as ruled: σ/π stateless; ⋈ new-row ×
      opposite-side state in nested-loop (lex source-ordinal) order;
      γ group state over MONOTONE deltas — retract-reaching-γ AND a
      first-appearance reorder both answer [recompute] loudly (L94
      group order is first appearance; the in-place rule cannot
      hold). planar_incremental_membership = planar member + sequence
      shape + no τ/λ + one γ/no post-γ clauses (v1, loud) + EVERY
      [where] predicate ESTABLISHED TOTAL (the M6 err-totality
      amendment) — every exclusion a typed loud reason. Engine REUSED
      (eval_node/match_pattern/nodes_equal + the L94 $group
      construction replicated); battery (12 fns, green first run)
      verifies every maintained result ≡ ENGINE recompute AND replays
      every ∂ script onto the prior relation. journal.md gains the ∂
      cross-ref (stream appends = the natural monotone input) per the
      ruled spec-edit map.
    - **The W7-closing full gate ran TWICE:** run 1
      (w7-full-gate.log) GATE-RC=2 — spec-freeze-gate red on
      e6bb1f8b's predecessor: the token regex requires an
      ALPHANUMERIC after `RULED:` and `#770(a)` opens with `#` (the
      earlier `RULED: #768(a)` commits passed only because they
      touched no normative spec); the commit message reworded to
      `RULED: 770(a)` via local-only history rewrite (5afba380 →
      e6bb1f8b; aa3e844c/de1766ec replayed as 7166fa67/40db0925 —
      nothing had been pushed). Run 2 (w7-full-gate-2.log):
      **GATE-RC=0** read from the log — 246-lane suite, 245 direct +
      fabric_nats_bridge green on its classified cache-free retry
      (the standing #572 artifact); test-vcx-code 83/83;
      **address-baseline 108 Tier-2 def addresses byte-identical**;
      extraction gate ABI transcript byte-identical (1593 Ring-0
      cases, 4576018 bytes) + CLI 9152 invocation pairs identical +
      17 profile refusals; guide-check 45; directive-docs 80;
      verify-doc-blocks 327/0/6.
    NEXT: **W8 — exit**: ledger verdict, the stream exit-merge to the
    design branch (the merge IS an exit step — do NOT repeat the
    stream-4 miss), #674 + #711 closed with evidence; the #700
    consolidation lever is dated for this boundary.

    **ENTRY 10 AUDIT ADDENDUM (2026-08-10, owner-directed adversarial
    audit of W7; commit 04a04833, gate w7-audit-gate.log GATE-RC=0).**
    The audit field-enumerated the T2 encoder against the AST and
    live-probed every candidate: **five more #769-class false merges
    found and fixed under the same ruling** (one defect class) —
    [order-by] DIRECTION (asc ≡ desc, semantics-changing),
    duration_lit + period_lit payloads (dur_val, not the empty
    str_val — every duration merged with every duration),
    ProgramBinding.type_test (map-pattern typed binds {k: $v::int} ≡
    {k: $v::str}), and ProgramBinding.is_rest (($x, *$r) ≡ ($x, $r) —
    different match arities). All presence-marked; **corpus movement
    ZERO again** (baseline green before/after). Probed and CLEARED:
    date/datetime/atom/node_lit distinct; 1_000≡1000 formatting-
    correct; [par N] width merge = the same computation under the
    ordered-reassembly theorem (documented at t2_clause_meta);
    ProgramPathStep fully emitted; typed binds unreachable in
    element-pattern bodies (parse refusal). **#770 escape hunt:**
    binding-path predicate BODIES are closed by grammar ([159a/b]
    admits no directive/bracketed form — [?eval]/ambient/impure
    probes all refuse at parse); no membership escape found. **∂:**
    empty-init + first-insert gap closed in the battery; the ∂ seam's
    consumer is stream 3 BY THE RULED WAVE PLAN (the fixtures are the
    W7 proof — recorded, not silent). **Honesty truing:** the
    address-baseline runner's header claimed a Tier-1 lane the code
    never had — comment trued; the exit clause's Tier-1 half rides
    the extraction gate's canonical-byte identity (strictly stronger:
    full output bytes over every Ring-0 case, both lanes), which ran
    byte-identical in every W7 gate. **Cleared design boundaries:**
    planar_plan.v's clause iteration is a structural TRANSFORMER
    (reorders/folds/erases clauses), not a child-node enumerator —
    outside the ONE walk's contract, like eval itself and the ∂ frame
    builder; the walk owns enumerators (the retired nine-plus set).
    Verdict: W7 stands, with the encoder now field-complete against
    the AST; corpus cx-111 + 6 battery pins guard the audit's
    findings.

11. **W8 — STREAM EXIT (2026-08-10 night). THE VERDICT: the stream's
    mandate is DELIVERED IN FULL — every ruled letter (L93–L101) is
    implemented, live-consumed, and gated; the C9 exit clause is
    DISCHARGED at zero movement; no deferrals, no partials, no
    silently reduced scope.**
    - **The mandate against the deliveries:** L94 γ complete ($group +
      the aggregate set; the M5 revenue-by-region worked example runs
      live — W1). L100 the ONE walk authored + ALL nine-plus walkers
      retired onto it, the Tier-2 emitter last and byte-identical
      (W2/W7). L95 the six-point loud membership test + the #770
      tightening (λ-count purity, all-slot ambient exclusion — W3/W7).
      L97 source refs + the flat provenance-bearing relation +
      columnar/row shape parity (W3). L93 the canonical plan form +
      plan address, the checker's first runtime consumer (W4). L96 the
      reportable equivalence set with the err-totality rule,
      live-eval-verified (W5). L99 quoted planar store queries over
      local + BOTH wire listeners with dual-layer authorization (W6).
      L101 the ∂ vocabulary + delta rules, maintained ≡ recompute
      (W7). L98 windows stayed OUT (the lexer arms died — W2).
    - **The exit clause (C9): DISCHARGED.** Full-corpus Tier-2
      addresses byte-identical to the W2 baseline (108 defs @
      1382d2f3) through every wave INCLUDING the #769 preimage
      correction, the W7 retirement, and the audit continuation — the
      no-re-bless rule was never exercised because nothing ever
      moved. Tier-1 identity rode the extraction gate's canonical-
      byte identity (1594 Ring-0 cases / 9158 CLI pairs byte-identical
      at exit — strictly stronger than address comparison).
    - **Defects: 9 fixed en-route, 3 filed.** Fixed with fixtures
      first: #753 (structural element equality), the frame-set
      pipeline rebuild (chained barriers), the λ-count silent no-op,
      the bare-pattern emit round-trip (cx-107), the source-less
      generator arm, the gRPC trailer identity, #769 (+5 audit
      holes), #770 (+ the cousin), #772 (+ the plan-tier predicate
      holes). Filed and OPEN: #771 (eval_code head-only render,
      informational), #756 (purity-table reconciliation, pre-existing),
      plus the owner-scheduled boundary items below.
    - **#711: all eight items discharged** — 1/2 at W1 (L94), 3/4 at
      W1, 5/6 at W2, 7 at W2+W7 (the retirement complete), 8 at W3
      (L97 parity). #674 and #711 close with this entry.
    - **The exit gate + the exit-merge:** the full gate on the final
      stream tip and the --no-ff exit-merge to
      design/651-516-partition are recorded below with their receipts
      (the merge IS an exit step — the stream-4 lesson applied; the
      design branch tip 84c56283 was already merged in at W2, so the
      exit-merge carries no foreign deltas).
    - **Handed to the boundary (NOT this stream's scope, surfaced
      loud):** the #700 consolidation lever (owner-dated to this
      boundary, generator requirements on the issue); the post-exit
      highs fix lane (#722, #702, #724, #713) on the design branch
      per the highs-ASAP policy; the V-fork campaign (own campaign
      per the same ruling); stream 3 (live modes, #675) starts on its
      own branch and consumes the ∂ vocabulary + the quoted planar
      form.

    **Entry-10-addendum detail (#772, kept in place):**
    **#772 CLOSED at the addendum (c3c582ff + 7419727c; the owner's
    highs-ASAP policy applied in-stream; i772-full-gate-2.log
    GATE-RC=0):** ProgramPathPredicate carries type_name → the shared
    match_attr gives predicate position the §5.2 rule-14 semantics
    verbatim ([r 1 1 2] ground truth, RED pre-fix); the emit/ast_json/
    program_xml round-trips un-lossied (the cx-107 class — re-emission
    had degraded [@age::int] to [@age]); the identity rider discharged
    in the same landing (T2 presence-marked) AND the sweep found the
    PLAN encoder carried BOTH pre-#769 predicate holes (existence ≡
    absence and type-blind PLAN ADDRESSES — a caching identity; false
    sharing serves wrong cached rows) — fixed presence-marked, the
    cx-100 plan byte-pin unmoved, address-baseline 108 unmoved,
    extraction 1594/9158 (grew with the pins). The string-CXPath
    engine has no ::T surface (refuses at parse — no silent
    type-blindness; a future feature, not a bug). cxparse differential
    741→742 (+1 agree, corpus growth only, the deliberate-update
    path).
