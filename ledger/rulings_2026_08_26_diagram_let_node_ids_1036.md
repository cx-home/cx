# Rulings — the `[?let]` CFG setup-node id (#1036), 2026-08-26

Authorizing issue: **#1036** ("the `[?let]` CFG emitter mints a DUPLICATE
`lt` node id for nested lets"). Branch `wave9/1036-1037-1001-diagram`,
off `release/0.17` @ `4a83b2361`.

Recorded in advance of the #1031 ledger's NT-9b, which measured the
defect against the committed golden at HEAD and named it as a known open
question rather than closing it inside another issue's authorization.

---

## LT-1 — the defect

`stdlib/diagram.cx` §9.5 `cd-emit-let` minted the setup node's id as

```
[= $setup [?if [> [$count $binds] 0] [then [$concat $s.pfx "lt"]] [else ""]]]
```

— `<pfx>lt`, a CONSTANT within a scope. A scope holds more than one
binding site whenever lets nest (`[?let A [?let B …]]`) or sit as
siblings, and `cd-emit-let` recurses into a nested let through
`cd-branching`, so every one of them minted the SAME id. The committed
`pin-cfg-nested-let.compact.golden` at HEAD carries the consequence:

```
  lt["[= $a 1]"]
  lt["[= $b 2]"]
  …
  lt --> i
  lt --> lt
  start --> lt
```

Two node definitions with one id, and a `lt --> lt` self-edge. Mermaid
keeps the LAST definition, so the outer binding is not drawn at all — it
is drawn wearing the inner one's label — and the edge that should carry
the reader from the outer setup to the inner one is a loop on a single
box. On playground example [150] (two nested lets) what disappears since
#1031 is a whole nested value TABLE, which is how the issue was found.

This is PRE-EXISTING; #1031 did not cause it and did not change id
minting. It made the consequence louder.

## LT-2 — the fix is a threaded counter, because the alternatives do not cover siblings

The id is minted from a binding-site counter threaded on the §9.5 CFG
state (`cst.lets`), advanced once per setup node ACTUALLY EMITTED — a
`[?let]` carrying no `[= …]` clause draws no setup node and must not
spend a number it never used. Ids are `<pfx>lt1`, `<pfx>lt2`, … in
emitter order.

**Why a counter and not nesting depth.** Depth distinguishes
`[?let A [?let B …]]` but NOT two sibling lets in one def body, which
collide identically. A monotone per-scope counter covers both; depth
covers one.

**Why threaded and not global.** For the reason every other field of
`cst` is threaded: the emitter is pure and the walk is functional. This
is the fifth counter/register to ride that record and the second COUNTER
(`arms`), so the shape is established, not invented here.

**Why it resets per def subgraph.** `cd-def-subgraph` already opens a
fresh id scope — the `pfx` is the def's initial — and resets `arms` to
0. `lets` resets with it, for the same reason and in the same place.

## LT-3 — the spelling is `lt1`, not a bare `lt` for the first

The numbering starts at 1 and every setup node carries a number,
including the only one in a single-let program. The alternative — bare
`lt` for the first binding site, `lt2`/`lt3` after — would have moved
FOUR fewer golden files, and is rejected:

- it makes the id scheme conditional on a count the reader cannot see,
  so `lt` and `lt2` in one diagram look like two different KINDS of node
  rather than the first and second of a series;
- the module already has a numbered id series, `cd-match-emit`'s
  `a{n}` / `t{n}`, which numbers from 1 with no bare first. Two
  numbering conventions in one emitter is the worse outcome;
- the saving is four files in a corpus that exists precisely so that
  deliberate movement is visible. Minimising movement is not a reason to
  ship a rule that has to be explained.

## LT-4 — the `full` binding bridge follows the id, and its behaviour is unchanged

`cd-resolve-target` anchors the `resolves` edges of §9.5b's
binding-introduction circles on the `[?let]` setup node, and found it by
scanning the emitted text for `"  lt["`. It now scans for `"  lt1["` and
answers `"lt1"`.

This is the SAME node it always answered: `lt1` is the main scope's
FIRST setup node, and the pre-fix `lt` was the id every setup node in
that scope shared, so the anchor's meaning ("the let setup node") is
carried over exactly. Measured on `pin-cfg-nested-let.full`: both
binding circles still resolve to the outer setup node, as they did
before, and the anchor did not silently migrate to the inner one.

## LT-5 — golden movement, adjudicated (DR-8)

`vcx/tests/testdata/code_diagram_golden/` is frozen under DR-8:
regeneration after the wave-3 capture is golden movement, forbidden
except under a mini-ruling recorded here BEFORE the bytes move. **This is
that authorization**, recorded before regeneration.

Movement, MEASURED over the whole committed corpus (282 goldens) with
the new emitter in place and nothing regenerated:

- **UNCHANGED: 276.**
- **MOVED: 6** — every golden in the corpus that contains an `lt` node,
  and no other:

  | golden | change |
  |---|---|
  | `full-code-cfg-binding-bridge.compact` | `lt` → `lt1` (3 lines) |
  | `full-code-cfg-binding-bridge.full` | `lt` → `lt1` (4 lines, incl. the `resolves` edge) |
  | `pin-cfg-nested-let.compact` | `lt`/`lt` → `lt1`/`lt2`; `lt --> lt` becomes `lt1 --> lt2` |
  | `pin-cfg-nested-let.full` | same, plus both `resolves` edges to `lt1` |
  | `pin-patch-abs-path.compact` | `lt` → `lt1` (3 lines) |
  | `pin-patch-abs-path.full` | `lt` → `lt1` (4 lines) |

Every change is an IDENTIFIER change. No label byte, no shape, no edge
COUNT and no line ORDER moves in any of the six — except in
`pin-cfg-nested-let`, where `lt --> lt` becomes `lt1 --> lt2`, which is
the defect being fixed and not incidental movement. Every `min` golden
is byte-identical (`cd-cfg-min` emits one box per top-level def plus
`main` and never reaches a let). Every ERD golden, every SEQ golden and
every subgraph is byte-identical.

## LT-6 — one conformance fixture moves with them

`conformance/code_diagram.cxd`, case `full-code-cfg-binding-bridge`,
carries the same three `lt` lines in its `[expected]` block. The
gate-37.10 runner compares node-SETS and edge-SETS, so an id change is
visible to it; the fixture is updated in the same commit and for the
same reason. It is the only fixture in the tree that names this id — the
whole repo carries no other reference to it outside the six goldens
above.

## LT-7 — red-proof

Reverting `cd-emit-let`'s minting to `[$concat $s.pfx "lt"]` (and
`cd-resolve-target` to `"lt"`) with the re-blessed goldens in place puts
all six goldens RED in the DR-8 byte gate and reddens the
`full-code-cfg-binding-bridge` fixture in `test-code-diagram`. The pins
therefore hold the fix, rather than describing it.
