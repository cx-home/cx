# Ruling record — #1241 accumulate-in-a-loop is O(n²): the sibling array is copied whole per append (2026-09-04)

Issue: #1241 (enhancement, area:cx-lang, prio:medium, perf). Carrier: `vcx/cx/map_carrier.v` (RULED: RP-3),
Element / Sequence / Array `items` (`vcx/cx/ast.v`). Spec: array.md / map.md / bytes.md ("every constructor
returns a NEW value"), api.md (the O(depth) copy guarantee is for the SPINE).

## What was checked (2026-09-04)

- Every append / set is a whole-array copy: `map_set` clones `entries`; `[?modify] append` clones `items`
  then pushes (eval.v ~13456); `materialize_to_items` clones at every builtin boundary (eval.v ~14146); the
  path-modify spine copies clone the parent's `items` (~13022 / ~13044). A fold that builds a collection is
  O(n²) in time and allocation.
- The issue's route 1 — "uniqueness in-place under the Perceus RC front line" — has NO runtime to stand on:
  CX ships on vgc "E" (a tracing collector; the only refcount-shaped thing in the tree is the re2 handle
  cache), and V's `-autofree`/Perceus is not what `-gc e` builds run. There is no `is_unique` a constructor
  could ask, so an in-place append is unsound: two live references to one array would both see the write.
  Route 1 is therefore not "the cheap 80 %"; it is not available.

## Question 1241-Q1 — the asymptotic fix (OPEN, owner ruling — it changes a RULED carrier)

- **(a) recommended — a persistent chunked vector for `items` / `entries` ABOVE a threshold (≈ 32 items):
  32-way branching, O(log₃₂ n) append and set with structural sharing; below the threshold the flat array
  stays (every JSON record in the audit corpora is small, so `bench/repr` is byte-identical).** Immutability
  is kept by construction; `nodes_equal`, canonical bytes and iteration order are unchanged; `[?modify]` spine
  copies share the untouched chunks. Cost: one more representation in Ring-0 (RP-3 said ONE map carrier —
  this is the same carrier with a chunked `entries`, not a second carrier), and every `items` reader that
  indexes goes through an accessor (RP-4 already routed most through `map_entries()` / `materialize_to_items`).
- (b) a transient/builder escape hatch: `[?reduce … [init []]]` and `[?loop]`-append recognized by the
  evaluator and accumulated into a private mutable buffer that is frozen once on exit. Zero carrier change,
  the exact pattern users write becomes O(n) — but only that pattern; a fold that ALSO reads the partial
  collection each step stays quadratic, and the recognizer is a second semantics for one surface.
- (c) leave it: document the O(n) append; the `bench/rowset` method already pins scaling ratios elsewhere.

Not ruled here: (a) reshapes the RP-3 carrier and is the owner's call. Exit for whichever is ruled: a
100k-iteration accumulate fixture scaling linearly (in-run ratio guard, the `bench/rowset` method);
canonical bytes and `nodes_equal` unchanged; `bench/repr` byte-identical.
