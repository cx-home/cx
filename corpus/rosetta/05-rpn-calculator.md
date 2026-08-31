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

Run: `vcx/target/cx corpus/rosetta/05-rpn-calculator.cx`

Observed output:

```
[stack [n 35]]
```

**Status:** GREEN (re-derived 2026-08-25 after the Cluster A settlement,
R-A1..R-A6). `3 4 + 5 *` → `[stack [n 35]]`, rc=0, and both former
workarounds are RETIRED by the ruled model, not papered over:

1. The #961 descendant-axis workaround is gone: a node-set in element
   content now splices (`[?splice $acc/*]` is the push), so the stack's
   items are direct children and the CHILD axis reads them (`$acc/n`).
   The silent grouping envelope this program had to see through can no
   longer be constructed — a bare sequence as content refuses loudly,
   naming `[?splice]` (#847-1a, implemented under R-A1).
2. The "no sequence append" limitation is gone for the same reason:
   `[stack [n $tok] [?splice $acc/*]]` IS the push — new head plus every
   existing item, no rebuild, no loss of depth. (The operator arms still
   collapse the stack to the single result, which is adequate for this
   expression's shape; a general evaluator would splice the popped tail
   the same way.)

Also closed earlier by the VC-28 rewrite: the "multi-arg `[?fn]` apply
with a non-trivial body" gap — `[?fn ($acc $tok) …]` inside `[?reduce]`
is exactly that, and it works.

### Post-campaign re-derivation (2026-08-31, ergonomics campaign #1144 W4)

Re-run unchanged against the campaign's binary: `[stack [n 35]]`, rc=0. The
program is **deliberately not refreshed**, and the measurement is the reason
rather than a preference:

1. **No adapter lambda to retire.** `[?fn ($acc $tok) …]` here is a genuine
   two-parameter fold step with a dispatch body, not a one-application
   wrapper standing in front of an operator — so the operator-value form
   (`[+ _ _]`) has nothing to replace. Where an adapter *does* stand in front
   of an operator, the corpus now carries the swap as an anti-pattern pair
   (`ap-adapter-lambda-*` in `conformance/llm/antipatterns.cxd`).
2. **The op-table idiom cannot be keyed by this token stream.** An operator
   table is a map, and an **atom is not an admissible key scalar** (cxdm
   §2.6) — measured: `[$map:put {} :plus [+ _ _]]` refuses with
   "KEY must be an admissible key scalar". The token stream here is atoms
   (`:plus` / `:times`), so an op-table rewrite would have to interpose
   `[cast $tok :string]` on every lookup: one form longer, one concept wider,
   for no gain. A token stream that is already text (`'+'` / `'*'`) is where
   the op table pays, and `program-ophole-006-op-table-end-to-end` in
   `conformance/code.cxd` is that program end to end.
3. **The stack is a document on purpose.** The `[?match]` arms read it through
   the child axis; that inspectable-intermediate-state rationale is this
   program's whole contribution to the corpus, and a sequence-stack variant
   would teach the opposite lesson under the same number.

## Historical (v0.7.x surface, superseded)

Everything below this line describes the **pre-reshape** surface and is kept as
a discovery trail, not as findings. Its blocking item — `$path/child` raising
`CXER0001` instead of reading as absence — is closed by the Cluster A
settlement, as is the "no native stack abstraction" item (`[?splice]` in
element content is the push). `AUDIT.md` carries the retirement list and the
live gap register; this section is history.

### Status at the time

**Status:** BLOCKED. The reduce machinery does start dispatching, but
the first non-operator token `3` enters the `:case $v` arm, which
tries to construct `[stack [n $v] $acc/n]`. With `:init [stack]` the
initial `$acc` has no `n` children, and `$acc/n` raises
`CXER0001 no child element "n" on path` instead of returning an empty
sequence. This is the canonical "empty-path-as-error vs
empty-path-as-empty-sequence" XPath divergence.

### Workarounds attempted

| Attempt | Result |
|---|---|
| Tuple-based stack: `:case $v :yield ($v, $acc)` | Returns nested tuple — `(3, ())` not flat `(3,)` — and the operator arms can't peek into the nested shape because there's no `head`/`tail` on tuples (only on element children) |
| Sequence-based stack: `[?reduce ... :init () :using [?fn ($a,$b) [+ $a $b]]]` simple sum (no RPN) | Works (verified inline) — proves multi-arg `[?fn]` works WHEN the body is a single directive, not when it contains a nested `[?match]` |
| Predicate arithmetic `$acc/n[last()-1]` | Parse error — predicate doesn't allow arithmetic on `last()` |
| `:init [stack [n 0] [n 0]]` (sentinel zeros) | Works mechanically but corrupts the result; sentinel arithmetic ruins it |

### Open gap log

*(2026-08-25: items 1 and 4 below are CLOSED by the Cluster A settlement —
a missing child reads as absence, and `[?splice]` in element content is the
push idiom. Items 2 and 3 are v0.7.x-era observations kept for history;
item 3's arithmetic atomization landed with the comparison-atomization
companion.)*

1. **`$path/child` raises `CXER0001` instead of returning empty sequence when the parent has no such child.** This contradicts the XPath 3.1 model (where `/a/missing-child` is empty, not an error). Filing this would close cleanly via a one-line eval-loop change. **Warrants a spec item or an amendment to `spec/cxpath.md` §6.**

2. **Predicate-context arithmetic on positional builtins.** `last()-1` doesn't parse inside `[...]` predicate. Filing under existing CXPath predicate completeness work. **May close as an extension to that work.**

3. **`[?fn]` two-arg apply with non-trivial bodies — re-confirmed.** Same gap as #01. Two-arg `[?fn]` with body containing `[?match]` arms doesn't substitute parameters cleanly into the match subject; we observed `[* 5 [+ 4 (3, ())]]` as the result — the operator outer was reduced but the inner `[+ 4 (3, ())]` was left because `(3, ())` is a sequence-of-one, not a scalar, and the integer arithmetic builtin doesn't atomize. (Atomization fix may apply here per the precedent in commit `252218bb` which fixed `min`/`max`/`avg` over attribute-shaped Elements.)

4. **No native "stack" abstraction.** This is design-level: CX neither has a list-as-stack with `push`/`pop`/`peek` builtins nor a deque. The XPath sequence is immutable and grow-from-tail-only via concat. Worth noting alongside the `[?reduce]` companions work as a gap in the surface that motivates real stack-based programs.

The fact that #1 *blocks* the program at the first token is a real
finding — the corpus surfaces the gap before any new spec cycle could
discover it.
