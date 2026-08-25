# 05 — RPN calculator

## What it does

Evaluate the postfix expression `3 4 + 5 *` and return the result
(35). Token stream is `(3, 4, :plus, 5, :times)`; the program folds
a stack and applies operators in arity-2 fashion.

## Idiomatic shape in other languages

- **Python**: `from operator import add, mul; ops={"+":add,"*":mul}; reduce(lambda s,t: s[:-2]+[ops[t](s[-2],s[-1])] if t in ops else s+[t], tokens, [])[0]`
- **Clojure**: `(reduce (fn [s t] (case t :plus (conj (pop (pop s)) (+ (peek (pop s)) (peek s))) :times ... :else (conj s t))) [] tokens)`
- **Haskell**: `foldl step [] tokens where step (a:b:xs) "+" = (b+a):xs; step (a:b:xs) "*" = (b*a):xs; step xs n = n:xs`

## Actual run

Program:

```
[?reduce (3, 4, :plus, 5, :times)
  :using [?fn ($acc, $tok)
    [?match $tok
      :case :plus  :yield [stack [n [+ nth($acc/n, 1) nth($acc/n, 2)]]]
      :case :times :yield [stack [n [* nth($acc/n, 1) nth($acc/n, 2)]]]
      :case $v     :yield [stack [n $v] $acc/n]]]
  :init [stack]]
```

Run: `devbox run -- ./vcx/target/cx eval corpus/rosetta/05-rpn-calculator.cx`

Observed output:

```
cx eval: cx-err:CXER0001: no child element "n" on path
```

**Status:** WORKAROUND (re-derived 2026-08-25, RULED: VC-28). The program was
rewritten for the v0.8.0 surface and now **computes the right answer**:
`3 4 + 5 *` → `[stack [n 35]]`, rc=0. Two workarounds are load-bearing, both
measured, so this is not GREEN:

1. The stack is read with the DESCENDANT axis (`$acc//n`), not the child axis.
   A node-set placed in element content nests as a sequence child —
   `[stack [n 4] ([n 3], [n 9])]` — and the child axis does not see through
   that grouping, so `$acc/n` reports one item after two pushes. That is
   **#961** (Cluster A). Switch back to `/n` when it is settled.
2. An operator arm rebuilds the stack as a single `[n …]` rather than popping
   two and pushing one, because there is no sequence append (`$concat` is
   strings only). Correct for this expression; a general RPN evaluator needs a
   real push/pop.

Also closed by the rewrite: the previously-recorded "multi-arg `[?fn]` apply
with a non-trivial body" gap. `[?fn ($acc $tok) …]` inside `[?reduce]` is
exactly that, and it works.

### Historical (v0.7.x surface, superseded)

**Status:** BLOCKED. The reduce machinery does start dispatching, but
the first non-operator token `3` enters the `:case $v` arm, which
tries to construct `[stack [n $v] $acc/n]`. With `:init [stack]` the
initial `$acc` has no `n` children, and `$acc/n` raises
`CXER0001 no child element "n" on path` instead of returning an empty
sequence. This is the canonical "empty-path-as-error vs
empty-path-as-empty-sequence" XPath divergence.

## Workarounds attempted

| Attempt | Result |
|---|---|
| Tuple-based stack: `:case $v :yield ($v, $acc)` | Returns nested tuple — `(3, ())` not flat `(3,)` — and the operator arms can't peek into the nested shape because there's no `head`/`tail` on tuples (only on element children) |
| Sequence-based stack: `[?reduce ... :init () :using [?fn ($a,$b) [+ $a $b]]]` simple sum (no RPN) | Works (verified inline) — proves multi-arg `[?fn]` works WHEN the body is a single directive, not when it contains a nested `[?match]` |
| Predicate arithmetic `$acc/n[last()-1]` | Parse error — predicate doesn't allow arithmetic on `last()` |
| `:init [stack [n 0] [n 0]]` (sentinel zeros) | Works mechanically but corrupts the result; sentinel arithmetic ruins it |

## Open gap log

1. **`$path/child` raises `CXER0001` instead of returning empty sequence when the parent has no such child.** This contradicts the XPath 3.1 model (where `/a/missing-child` is empty, not an error). Filing this would close cleanly via a one-line eval-loop change. **Warrants a spec item or an amendment to `spec/cxpath.md` §6.**

2. **Predicate-context arithmetic on positional builtins.** `last()-1` doesn't parse inside `[...]` predicate. Filing under existing CXPath predicate completeness work. **May close as an extension to that work.**

3. **`[?fn]` two-arg apply with non-trivial bodies — re-confirmed.** Same gap as #01. Two-arg `[?fn]` with body containing `[?match]` arms doesn't substitute parameters cleanly into the match subject; we observed `[* 5 [+ 4 (3, ())]]` as the result — the operator outer was reduced but the inner `[+ 4 (3, ())]` was left because `(3, ())` is a sequence-of-one, not a scalar, and the integer arithmetic builtin doesn't atomize. (Atomization fix may apply here per the precedent in commit `252218bb` which fixed `min`/`max`/`avg` over attribute-shaped Elements.)

4. **No native "stack" abstraction.** This is design-level: CX neither has a list-as-stack with `push`/`pop`/`peek` builtins nor a deque. The XPath sequence is immutable and grow-from-tail-only via concat. Worth noting alongside the `[?reduce]` companions work as a gap in the surface that motivates real stack-based programs.

The fact that #1 *blocks* the program at the first token is a real
finding — the corpus surfaces the gap before any new spec cycle could
discover it.
