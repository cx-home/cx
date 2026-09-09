# Ruling — every emitted CFG node id carries its role's ordinal, and the whole id family moves in one landing (#1349)

**Ruling ids:** 1349-a, 1349-b, 1349-c
**Date:** 2026-09-08 (Fable pass, 14:40 ET, on #1349)
**Ruled by:** Fable session, on campaign worker C's drafted letter set.
**Status:** RULED before the work. Recorded here by campaign worker B, which
implements it and rules nothing in it.
**Class:** DR-8 mini-ruling — GOLDEN MOVEMENT. `vcx/tests/diagram_umbrella_test.v`
(the absorbed body of `code_diagram_golden_test.v`) states that regeneration of
`vcx/tests/testdata/code_diagram_golden/` after the wave-3 cutover is forbidden
"except under a DR-8 mini-ruling recorded in the ledger BEFORE the bytes move".
This file is that record, and it is committed in the same landing as the moved
bytes.
**Follows:** `ledger/rulings_2026_08_26_diagram_let_node_ids_1036.md` (#1036,
which threaded the counter through `lt` and left its siblings on the constant),
`ledger/rulings_2026_09_04_diagram_def_namespace_1066.md` (#1066, ordinal ids
are an established spelling in this emitter),
`ledger/rulings_2026_09_07_diagram_binding_bridge_1068.md` (#1068, whose
binding registry made the collision visible as a self-edge), and
`ledger/rulings_2026_08_20_diagram_wave3.md` (DRW3-1, the golden-movement rule).

## The ruling, as ruled

**1349-a.** Number every occurrence from the first: `lh1`, `lb1`, `b1`, …,
exactly as #1036 numbers `lt`. One id family, one rule. Refused: numbering from
the second (`lt` from 1, its siblings from 2) permanently encodes two spellings
for one concept, which is the asymmetry that produced the defect; and splitting
the family across two mechanisms to save one threaded `int` diverges from #1036
for the sibling of the very id #1036 fixed.

**1349-b.** All three roles — `lh`, `lb`, `b` — in ONE landing. The `b` shape
was found by the same gate in the same run; landing the loop ids alone leaves
the gate red and #1170's `1170-c` precondition unmet. Splitting it is a
deferral.

**1349-c.** Two new goldens — a nested for-comprehension, and two blocks in one
scope — beside the strengthened mermaid gate as the second grader. The corpus
had neither shape; adding one leaves the other exactly as unguarded as it was.

**Implementation rules stated with the ruling.** Write this record BEFORE running
`regen_code_diagram_golden`, then diff every re-recorded golden and READ it: the
only change permitted is `lh`→`lh1`, `lb`→`lb1`, `b`→`b1` (and higher ordinals
where a source has several) in node declarations and edge endpoints; any other
byte moving is a defect, not churn. Register the two new pin ids in the tool's
`pin_sources` (the #1350 manifest) first. Blast radius HIGH.

## What was measured before the work, at `1e1552c49`

`cd-emit-for` minted the loop head as `[$concat $s.pfx "lh"]` and
`cd-block-node` minted the body/block as `[$concat $s.pfx <role>]`, with no
counter on either, while `[?let]` carried #1036's `lets`. Census of
`vcx/tests/testdata/code_diagram_golden/` (429 goldens, 107 sources): 16
goldens declare an `lh{{` node, 14 an `lb[`, 2 a bare `b[` — 18 files, and
ZERO goldens hold two of any one role. No collision shape was covered anywhere,
which is why the byte gate never saw this.

Worker C's measurement on the playground corpus, reproduced natively:
`39-for-nested` duplicates `lh` at `compact` and `full`; `186-random-stream`
and `192-map-module` duplicate bare `b` at both rungs (the `[?lib]` node and
the top-level body node), and mermaid keeps the LAST declaration, so four edges
through `b` collapse into a cycle the program does not contain.

## Two further sites the same constant reached, fixed in this landing

Neither is new scope: both are references TO the ids 1349-a renumbers, and
leaving either would make 1349-a's own goldens dangle.

1. **The `full` rung's yield sentinels.** `cd-yield-emit` wrote the literal
   `  lh --> y<k>`, correct only while every loop head in a document shared one
   id — and already a DANGLING target for a loop head inside a def subgraph,
   where the declaration is prefixed. It now finds the head by the LABEL that
   head was drawn with (`cd-node-id-with-label` reads the id off the
   declaration in the emitted text), and emits the sentinel with no edge when
   the for-comprehension drew no head. `cd-for-gen` / `cd-for-bind` /
   `cd-for-header` were split out of `cd-emit-for` so both writers compute that
   label from one place.

2. **The `resolves` fallback anchor.** `cd-resolve-target` probed the emitted
   text for `lb[` UNANCHORED, which matches the `plb[` of a loop body inside a
   def subgraph, and then answered with the un-prefixed `lb` — a node nothing
   declares. Measured by worker C on `170-cfg-large-def-match-process · full`:
   `DANGLING edge target lb`. Every probe is now anchored to the two-space
   indent of a main-scope declaration (`  lt1[`, `  lb1[`, `  b1[`), so the
   answer is always an id that scope actually declared, and the fallback moves
   on to the first def's entry when it is not.

## What this ruling does NOT authorize

`cd-emit-modify` mints `[$concat $s.pfx "u"]`, a fourth constant of the same
family. It is NOT renumbered here: 1349-b names three roles, and the
implementation rule permits only `lh`/`lb`/`b` bytes to move. One golden pair
(`cfg-009-modify-three-actions`) declares a `u[` node and no source in the
corpus holds two `modify` statements in one scope, so the collision is latent,
not measured. Carried to #1349 as a drafted question rather than taken
silently or filed away as a new issue.
