# Rulings — the Tree pane gets a gate (#1049), 2026-08-26

Authorizing issue: **#1049** ("playground: the Tree pane has no automated
gate — F1 sat inert through the whole #992 quality package because
nothing renders the Tree"), filed from #1001's own close-out, TD-7 in
`ledger/rulings_2026_08_26_playground_tree_detail_1001.md`, which recorded
the gap as open rather than glossing it. Branch
`wave9/1049-tree-gate`, off `release/0.17` @ `08e9097ea`.

TD-1..TD-7 is this gate's SPECIFICATION. Nothing new is decided about
what the Tree draws; what is decided is how that gets held.

---

## TG-1 — the gap, restated as measured

Three lanes ship with the playground and NONE of them renders the Tree:

| lane | what it drives | calls `renderTree`? |
|---|---|---|
| `test-playground-mermaid` | 2,070 diagrams through the page's builder | no |
| `test-playground-wasm-eval` | 182 examples through the shipped engine | no |
| `scripts/test_playground_smoke.sh` | serves the bundle, checks assets | no |

So #1001's element branch — reading `node.attrs` / `node.items`, fields
the `cxlib.tree()` contract does not carry — was dead code that drew the
raw JSON walk at every rung, and `Detail` had no observable effect on the
Tree at all, and it shipped through the entire #992 quality package
without one red light. The defect was not subtle; it was UNWATCHED.

## TG-2 — ONE harness, not a second one

The #1033 rig (real Chromium over CDP against the staged bundle, because
node cannot load the JSPI build the page loads) is what this gate needs
too. Copying its ~200 lines of boot would give the playground two
harnesses that agree today: two Chrome flag sets, two readiness rules, two
opinions on which wasm bundle counts.

**Ruled: the boot is factored into
`scripts/playground-gate/browser_harness.mjs` and BOTH gates import it.**
`test_playground_wasm_eval.mjs` was rewired onto it in the same change —
244 lines deleted, and it reports the identical verdict it documented
before (182 examples, 172 == native, 10 marked, 0 failures), which is the
evidence that the extraction was behavior-preserving rather than the
claim that it was.

The harness decides how to REACH the page and nothing about what to
assert there. There is deliberately no shared notion of pass/fail in it.

## TG-3 — the gate drives CONTROLS, not functions

It does not import `playground.js`, call `renderTree`, or rebuild the
expected HTML. It sets the example picker's value and dispatches the
`change` the page listens for, sets the Detail select and dispatches its
`change`, clicks the Source and Tree tabs — then reads the DOM those
handlers produced. Nothing reaches into the controller's closure.

Consequence, and the reason for the rule: a defect anywhere between the
control and the pixel reddens the gate, including a `Detail` control that
stops being wired at all (TD-4 moved it to the View header; the gate
fails loudly if `#cxp-detail-select` goes missing).

## TG-4 — the expectations are PINNED, and that is forced

#1033 derives its expectation from native `cx`, because it has a second
implementation to ask. **There is no second Tree renderer.** The only
honest reference is a set of numbers a human read and agreed to, so:

- they live in ONE reviewable file,
  `scripts/playground-gate/tree_expectations.json`, carrying its own
  `_README` and a `_fields` gloss naming the TD rung each field holds;
- `node scripts/test_playground_tree.mjs --pin` rewrites it, so a
  deliberate Tree change re-pins in one place and **the diff is the change
  request**;
- the fixture owns the CASE SET too — the gate has no built-in example
  list — so adding a case is a fixture edit and shows up in review as one.

**TG-4a — what a re-pin can NEVER bless.** Two classes of check are held
independently of the fixture and fail even while pinning:

1. **shape, not counts** — `rawWalkLabels` (rows labelled with
   `cxlib.tree()` contract keys) and `arrayRows` (`array(N)` containers)
   must be empty on every example at every rung. That is the #1001 and
   TD-5 defect signature directly, and it is not a number anyone can move.
2. **rung invariants** — a placeholder instead of a tree, zero rows, values
   drawn at `min` (TD-2/TD-3a), an overflow note outside `compact`
   (TD-2b).

Without TG-4a the gate would be defeatable by re-pinning, which is the
same green-by-construction hazard #1033's stale-marker rule exists to
close.

## TG-5 — the pinned set, and why each case is in it

Five examples × three rungs = 15 renders, plus 5 bridge round-trips.

| example | why it is pinned |
|---|---|
| `04-boolean-scalars` | TD-1's own case. Seventeen rows under the dead branch; ONE at every rung now, with `Detail` finally observable on it. |
| `109-rename-via-attr` | `[?element]` with a COMPUTED name inside `[?let]`/`[?for]`/`[yield]` — the #1038 surface, and the `?name` spelling of TD-2c. |
| `130-siblings` | TD-2a in both directions in one tree: three lone text bodies ride up, and `[tags "T1" "T2"]`'s two bodies are a LIST and stay rows. |
| `134-build-index` | TD-2c at depth — an attribute whose VALUE is a nested `[?if]`/`[then]`/`[else]` directive tree. |
| `150-join-by-key` | TD-5's measured case (36 → 24 rows at `compact`), the deepest nesting, and the only `(+K more)` overflow in the set. |

**TG-5a — the pin AGREES with TD-6 and TD-5 to the number**, which is why
it was accepted rather than merely recorded:

- `04` at min / compact / full → **1 row** each, **0 / 2 / 4** chips, and
  `(+2 more attrs)` at compact — TD-6 verbatim.
- `150` at compact → **24 rows** — TD-5 verbatim.
- `150` at compact → three `(+1 more attr)` notes, one per 3-attribute
  `[o …]`, none at `full` — TD-2b's cap of 2, arithmetic checked
  (compact 12 chips, full 15).
- Rows removed between `min` and `compact` equals `inlineScalars` on every
  case (109: 14→13/1, 134: 13→12/1, 150: 25→24/1, 130: 19→15/4) — each
  ridden-up body costs exactly one row, TD-2a's rule, self-consistently.

## TG-6 — the bridge is round-tripped in BOTH directions

TD-3 refused to trade the per-attribute click target away for the chips'
vertical space, and paid for it with `attrSubLocs`. **This gate is the
assertion that the price is still being paid**, on `04` at `full`:

| direction | pinned |
|---|---|
| tree → source | chip 0 `@active` name half → editor selects `active`; its value half → `true`; chip 3 → `blocked` / `false`; exactly ONE target marked each time |
| source → tree | caret inside `verified` in the editor → the Tree marks `@verified`, class `cxt-chip-k` (the chip's NAME half), exactly one |

A chip half that loses its `data-loc` fails by that name — "the TD-3 click
target was traded away" — rather than as a count.

## TG-7 — red-proven, three ways

Not asserted; run. The staged bundle was patched in a scratch copy, the
gate run against it, and the bundle restored.

| injected | gate |
|---|---|
| `isElement` guarded on `Array.isArray(node.attrs)` — the #1001 DEAD-branch shape | **50 failures**, exit 1. `04 @ min`: `RAW JSON WALK … labels: children, kind, name, value`; `rows: expected 1, got 16`; chips gone (`no chip at index 0 (chips: 0)`); reverse bridge marks `·name: "verified"` / `cxt-node` instead of `@verified` / `cxt-chip-k` |
| `parts` read from `node.attrs`/`node.items` instead of `splitElementChildren` — branch fires, attributes vanish | **15 failures**, exit 1. `04 @ compact`: `chips: expected 2, got 0`, `overflow: expected ["(+2 more attrs)"], got []` |
| one expectation moved in the fixture (`150 @ compact` overflow[0]) | **exactly 1 failure**, exit 1, named by example, rung and field |

Restored → **green ×3 consecutive**.

Every failure line names the example and the rung, which is the property
TG-3 is for: the gate says WHERE, not just that something moved.

## TG-8 — placement, and what this lane does not claim

`test-playground-tree`, beside `test-playground-wasm-eval`, and
deliberately **NOT in `TEST_TARGETS`** — the same placement #992 / #1007 /
#1033 chose, because that lane must not require emcc or a browser. Both
preconditions (a staged `dist/playground-preview/`, a Chromium-family
browser) FAIL LOUD with exit 2 rather than skipping, so the lane cannot
report a vacuous pass. Bounded by `TREE_GATE_DEADLINE` (600s default);
server and browser reaped on every exit path.

**What it does not cover, stated.** It asserts what the Tree CONTAINS, not
how it LOOKS: TD-6's measured layout pass (page overflow, pane scroll,
zero-width spans, clipped rows, header height) is not automated here and
remains a manual method. It measures the `source` subject; the `output`
subject and the `Both` mode draw through the same `renderTree` but are not
pinned. And it renders five examples of 182 — chosen for the node kinds
TD-1..TD-5 rule on, not for coverage.

**TG-8a — a stale pointer removed in passing.**
`scripts/test_playground_smoke.sh` told the reader to "run
scripts/test_playground_browser.js once authored (Phase 7)" — a script
that was never authored, in a footer promising exactly "tree, bridge"
verification. It now names the three gates that do exist. A gate lane that
advertises an imaginary lane is the same unwatched-surface problem one
level up.
