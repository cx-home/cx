# 06 — BFS over adjacency-list graph

## What it does

Given a directed graph with edges A→B, A→C, B→D, C→D, D→E, find a
path from A to E by breadth-first search and emit the path. The
intended output is `[path :A :B :D :E]` (or any equivalent length-3
BFS-shortest path).

This program intentionally probes three things at once: graph
traversal, mutable-set-of-visited state, and recursive comprehension.

## Idiomatic shape in other languages

- **Python**: `def bfs(g, s, e):\n  q = deque([(s, [s])])\n  v = {s}\n  while q:\n    n, p = q.popleft()\n    if n == e: return p\n    for x in g[n]:\n      if x not in v: v.add(x); q.append((x, p + [x]))`
- **Clojure**: `(loop [q (conj clojure.lang.PersistentQueue/EMPTY [start [start]]) visited #{start}] (when-let [[node path] (peek q)] (if (= node end) path (recur ...))))`

## Actual run

Program (an honest reduction — *enumerate the edges*, since BFS itself is unwriteable in current CX surface):

```
[?let $graph = [g
  [edges from=A to=B] [edges from=A to=C]
  [edges from=B to=D] [edges from=C to=D]
  [edges from=D to=E]] :in
  [?for [edges @from=$f @to=$t] :in $graph//edges :yield [edge $f $t]]]
```

Run: `devbox run -- ./vcx/target/cx eval corpus/rosetta/06-bfs.cx`

Observed output:

```
[edge "A" "B"]
[edge "A" "C"]
[edge "B" "D"]
[edge "C" "D"]
[edge "D" "E"]
```

**Status:** WORKAROUND (reduced scope). The program parses and runs,
but the original BFS goal is unreachable: it returns the edge list,
not a path from A to E. Multiple gaps compose to block the real BFS.

## Workarounds used

| Idiomatic | Used | Reason |
|---|---|---|
| `$graph/edges` to iterate children | `$graph//edges` (descendant axis) | Confirmed gap: `$bind/child` returns only the *first* match, not all matches |
| Queue + visited-set + loop | (none — abandoned) | No mutable state surface; no `[?loop]` / `[?recur]`; recursion-via-`[?def]` blocked by the not-yet-implemented `[?def]` parse-form |
| `[?def bfs (g s e) ...]` recursive helper | (impossible) | `[?def]` module-level function parse-form unimplemented (confirmed in program #01) |
| `[?reduce]` over a worklist | (impossible) | Two-arg `[?fn]` with non-trivial body doesn't work (confirmed in program #05) |
| Set difference `visited - to-visit` | (impossible) | No set-difference builtin; "set operations" hypothesis listed Medium |

## Open gap log

Surface-completeness hypothesis confirmations:

1. **CXPath `$bind/child` single-match (CONFIRMED, already in the gap register).** Re-confirmed: `$graph/edges` returns 1 of 5 `edges` children; `$graph//edges` returns all 5. The descendant-axis workaround is fine for this shape but trips on cross-binding predicates per the other confirmed gap (`[@a=$o/@x]` RHS not evaluated against binding env).

2. **No looping / fixed-point combinator.** `[?reduce]` is the closest surface; `[?for]` is the closest comprehension. Neither models BFS's "until queue empty" condition. Filing this is structural — fits the "Concurrency primitives beyond `[?channel]`" hypothesis only loosely. Probably **motivates a new `[?recur]` / `[?loop]` / Y-combinator surface.**

3. **No mutable state / accumulator outside `[?reduce]`.** Confirms an implicit assumption — CX is purely functional in the corpus-program surface today. That's a design choice (memory `feedback_v0_6_0_design_philosophy` aligns with this) but worth documenting as a *deliberate* gap rather than an oversight.

4. **No set / map literal with set operations.** Hypothesis-register row "Map iteration" partially covers this. Confirmed: there's no way to express a `visited` set without faking it as a sequence + `distinct()`, which doesn't have efficient membership-test.

5. **Pattern destructure of attributes via `:from $f :to $t` keyword-style fails.** `[edges @from=$f @to=$t]` works; `[edges :from $f :to $t]` parses as `pattern body item` and rejects `:` between attrs. The `:foo` keyword-modifier shape only works in directive heads, not in match patterns over element shapes. Worth a one-line spec note in `spec/code.md §5.2`.

The cascading nature of these gaps (#2 + #3 + #4 together block the
real algorithm; #1 is a single-line fix) is the kind of finding the 0045 gap inventory anticipated. BFS is *the* canonical "do I have enough surface
to write a real program" probe; today CX doesn't.
