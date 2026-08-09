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
