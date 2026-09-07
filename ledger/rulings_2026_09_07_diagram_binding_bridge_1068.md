# Ruling record — #1068: the `resolves` bridge resolves per binding (2026-09-07)

DR-8 mini-ruling, recorded BEFORE the golden bytes move, as
`vcx/tools/regen_code_diagram_golden/main.v` requires. Decided under the
standing rule of 2026-09-07 (no mid-campaign stops; decide on long-term-best
and record).

## The defect is worse than #1068 filed it

#1068 reports the bridge pointing at the wrong table since #1036's
unification, and calls it decorative. Measured over all 182 playground
examples at `--level=full`, **58 render a wrong bridge**, in three kinds:

- **55 point at a real-but-wrong node.** Playground [150]: `b_orders`,
  `b_users` and `b_o` all resolve to `lt1`, though `$users` is set at `lt2`
  and `$o` is bound by the for-comp head `lh`.
- **1 dangles at a phantom node.** `cd-resolve-target`'s `lb`/`b` scans are
  UNANCHORED and return the LITERAL string `"lb"` rather than the id matched,
  so example [170] emits `b_i -. "resolves" .-> lb` where the only such node
  is `d2_processlb`. Mermaid silently auto-declares an empty box named `lb`.
- **2 orphan the circle entirely.** When no arm matches the target is `""` and
  the circle is emitted with NO edge — already frozen into a committed golden
  (`cfg-006-for-containing-if.full` ends on a bare
  `b_u((("$u"))):::binding`).

`test-playground-mermaid` proves diagrams PARSE, and a duplicate-id or
dangling-target diagram parses fine, which is why this shipped. That gate's
vacuity for this class is the finding worth keeping.

## Mechanism — there was never any per-binding resolution

`cd-binding-intros` returns a flat, globally-deduped list of NAMES with no site
information. `cd-resolve-target` returns ONE global anchor string for the whole
diagram, found by text-scanning the emitted compact text (`"  lt1["` -> `lt1`,
else `"lb["` -> `lb`, else `"  b["` -> `b`, else the first def's entry id).
`cd-binding-lines` then applies that one string to every circle.

So #1036/#1066 did not break this. They made a vacuously-correct hardwired
anchor visibly wrong. LT-4's "behaviour unchanged" is true of the anchor and
false of the meaning — exactly as #1068 argues.

## RULED 1068-A — the binding registry, and the for-comp anchor is `lh`

`cst` gains a threaded `bnds` field: a name -> node-id registry, first-site-wins
to match `cd-name-add`'s existing dedupe. `cd-emit-let` registers each
`[= $x V]` clause against the setup node it actually minted; `cd-emit-for`
registers the loop binding against the loop HEAD `lh`. `cd-binding-lines`
prefers the registry and falls back to the old global anchor.

**`lh`, not `lb`, and this is a choice rather than a derivation.**
`spec/03-approved/std-lib/diagram.md` says nothing normative about the
`resolves` bridge at all — it exists only as the code's §9.5b comment. `lh` is
chosen because it is the node that already carries the `binds $x` edge, so the
bridge and the bind edge agree on one node. Choosing `lb` would drop 7 of the 9
golden movements; it is the cheaper answer and the less coherent one.

## RULED 1068-B — golden movement authorized, 8 renders and 2 conformance rows

Movement is measured, one line each, all at the `.full` rung:

    auto-002-pure-code, cfg-001-bare-for, cfg-010-mixed-def-and-main,
    full-code-cfg-terminals, full-code-cfg-yield-enumeration, min-code-cfg,
    pin-cfg-computed-name-element        b_* : lb  -> lh
    cfg-006-for-containing-if            b_u : GAINS the missing resolves edge
    pin-cfg-nested-let                   b_b : lt1 -> lt2

Everything else byte-identical: all 98 `min` and `compact` renders, every ERD,
every SEQ, every subgraph; `effect-graph` md5-identical. `cd-binding-intros` is
untouched so SEQ's `cd-seq-binds` is unaffected.

Plus 2 rows in `conformance/code_diagram.cxd` — `full-code-cfg-terminals` and
`full-code-cfg-yield-enumeration`, both `-> lb` becoming `-> lh`.
`full-code-cfg-binding-bridge` (`-> lt1`) does NOT move.

**MEASURED AFTER REGENERATION: 8 goldens moved, not 9.** The diagnosis
predicted `pin-cfg-computed-name-element.full` would move `lb -> lh`; it did
not. Actual movement is 7 x `lb -> lh` (5 `b_u`, 2 `b_x`), 1 x `lt1 -> lt2`
(`pin-cfg-nested-let`), plus `cfg-006-for-containing-if` gaining its missing
edge (2 added / 1 removed). Recorded as measured rather than as predicted —
the authorization is for the smaller set.

`cfg-006` gaining an edge is the one movement that ADDS output, and it is the
orphan-circle bug being fixed: that golden had frozen a circle with no edge.

## Declared limits, not omissions

- **`cd-name-add` dedupes binding circles by NAME globally**, so two sites
  binding `$a` can only ever get ONE circle; the registry gives it to the
  first site. Per-SITE circles (`b_a__d1_f`) would be a surface change and
  need their own ruling.
- **A binding whose site the CFG never draws** (a for-comp inside a let-bound
  value, labeled `[= $p [?for]]`) has no correct node id; the fallback to the
  enclosing setup node is the honest answer and is a choice.
- **`lh`/`lb` are minted as a constant per scope**, so nested for-comps collide
  on one id — the `lt --> lt` pathology #1036 fixed, one construct over. Filed
  as #1349. It bounds this fix rather than blocking it: with the registry, two
  nested loop bindings resolve to `lh` correctly, to a colliding id.
- **No golden covers a def-scoped `lt` node**, which is why the def case
  shipped broken. New pins are wanted for it and for the nested-for-comp shape.

## Verification

Per-binding resolution checked on every repro shape: nested lets -> `lt1`/`lt2`;
sibling flat -> `lt1`,`lt1`,`lt2`; a five-deep let nest inside a def ->
`d1_flt1`…`d1_flt5` (was all five on the def entry, or on the main block node
in a different subgraph when a main block exists); playground [150] ->
`lt1`,`lt2`,`lh`; the two-def dangling case -> `d1_flh`/`d2_glt1`; example
[170] -> `d2_processlh`.
