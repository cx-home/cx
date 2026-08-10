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
