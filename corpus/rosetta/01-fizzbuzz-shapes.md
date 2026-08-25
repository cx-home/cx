# 01 — FizzBuzz (element shapes)

## What it does

The classic FizzBuzz, but instead of printing strings the program
yields a sequence of atom shapes — `:fizz`, `:buzz`, `:fizzbuzz`, or
the bare integer — one per element of `1..30`. The shape-yielding
flavour is what makes the program a real CX exercise: control flow +
range comprehension + `[?match]` arms + atom literals + scalar
fall-through all have to compose.

## Idiomatic shape in other languages

- **Python**: `[("fizzbuzz" if n%15==0 else "fizz" if n%3==0 else "buzz" if n%5==0 else n) for n in range(1,31)]`
- **Clojure**: `(for [n (range 1 31)] (cond (zero? (mod n 15)) :fizzbuzz (zero? (mod n 3)) :fizz (zero? (mod n 5)) :buzz :else n))`
- **jq**: `range(1;31) | if . % 15 == 0 then "fizzbuzz" elif . % 3 == 0 then "fizz" elif . % 5 == 0 then "buzz" else . end`

## Actual run

Program (the natural form, per the Rosetta-corpus brief):

```
[?for $n :in 1 to 30 :yield
  [?match true
    :when [and [= [mod $n 3] 0] [= [mod $n 5] 0]] :yield :fizzbuzz
    :when [= [mod $n 3] 0] :yield :fizz
    :when [= [mod $n 5] 0] :yield :buzz
    :else :yield $n]]
```

Run: `devbox run -- ./vcx/target/cx eval corpus/rosetta/01-fizzbuzz-shapes.cx`

Observed output (truncated; 30 lines total):

```
1
2
:fizz
4
:buzz
:fizz
7
8
:fizz
:buzz
11
:fizz
13
14
:fizzbuzz
…
:fizzbuzz
```

**Status:** GREEN (re-derived 2026-08-25, RULED: VC-28). Rewritten for the
v0.8.0 surface — `[?for [in $n [$range 1 30]] …]` replacing the retired infix
`1 to 30`, and `[?match true [when …] [else …]]` replacing the `:when`/`:yield`
colon arms. Runs rc=0 with correct FizzBuzz (`:fizz` at 3, `:buzz` at 5,
`:fizzbuzz` at 15 and 30). No workarounds; nothing outstanding.

### Historical (v0.7.x surface, superseded)

**Status:** GREEN as of the math-operator surface landing. `[mod $n N]`
now dispatches through `dispatch_call('mod', [...])` in all four call
shapes (operator-element / element-paren / XPath-call / directive
multi-arg). The natural shape-yielding FizzBuzz body in §"Actual run"
runs to completion and produces the canonical fizz / buzz / fizzbuzz
sequence — matching the Python / Clojure / jq reference renditions.

## Workarounds attempted

(Historical — kept for the math-operator discovery-process trail.)

| Attempt (pre-math-operator surface) | Result |
|---|---|
| `[mod $n 3]` as a directive | Returns the literal `[mod $n 3]` Element — `mod` is not a registered builtin |
| `($n mod 3)` XPath-style infix | Parser rejects `mod` as an unknown token at the `mod` position |
| `floor($n / 3)` then `[- $n [* floor(...) 3]]` | XPath `$n / 3` rejects `/` between bindings; even with literals `[/ N 3]` returns float, then `[floor X]` in directive position does NOT reduce — `floor`/`ceiling`/`round` are XPath-call-only builtins, never directive-callable. The chain stays unevaluated. |
| Hand-enumerated `:case` arms (`:case 3 :yield :fizz`, `:case 5 :yield :buzz`, etc., up to 30 cases) | Works correctly but defeats the purpose of the exercise |
| `[?def imod (a b) ...]` module-level function | Parse error — `[?def NAME (params) body]` form not implemented yet on `v0.8.0-dev` |
| Multi-arg `[?fn ($a, $b) :body BODY]` | Body never substitutes `$a`/`$b` when called; only single-arg `[?fn ($x) :body ...]` works correctly |

After the math-operator surface landed, items #1 and #2 are closed in
surface-element / XPath-call / directive forms. The infix `$n mod 3` form
remains parse-deferred (out of scope) and continues to
require the operator-element `[mod $n 3]` shape.

The hand-enumerated `:case` workaround does exercise a different
real gap: `:else :yield $n` in a `[?match]` whose subject is `$n`
emits literal `"$n"` (string) rather than the value of `$n` — only
binding a catchall via `:case $x :yield ...` recovers the value.

## Open gap log

Surface-completeness hypothesis confirmations from this program:

1. **Numeric coercion / integer arithmetic edge — `mod` / `div` / `idiv` missing.** Listed in 0045 §"Confidence-ranked gap inventory" row "High — Numeric coercion / promotion edges." Confirmed here: no integer modulo, no integer division, no XPath `mod` / `div` / `idiv` infix tokens. **Warrants a spec item.**

2. **Math builtins are XPath-call-only, not directive-form callable.** Newly surfaced — *not* in 0045's hypothesis register. `floor` / `ceiling` / `round` / `abs` work as `floor(EXPR)` only; `[floor EXPR]` returns the literal directive shape without reducing. **Warrants a spec item or amends `spec/code.md §6.5`.**

3. **Paren-expression `(EXPR OP EXPR)` rejects comparison / arithmetic ops.** `($score >= 90)`, `($x > 4)`, `(1 = 1)`, `($a + $b)` all parse-fail. Only the directive forms `[>= $score 90]` / `[> $x 4]` / `[= 1 1]` / `[+ $a $b]` work. This contradicts the conformance-fixture example at `conformance/code.txt:3495` (`:when ($score >= 90)`), which itself fails on current HEAD. **Warrants a spec item or surfaces an open fixture-status item.**

4. **`[?def NAME (params) body]` module-level function form unimplemented.** Per `spec/code.md §12.2.1` this is the v0.8.0 normative function-declaration form. `[?def add (a b) [+ a b]]` parse-fails on current HEAD. The form is specced; V reference impl is Phase 2 work (per spec/v0_8_0_status.md row 2.12). **Tracked under `[?def]` implementation.**

5. **Multi-arg `[?fn ($a, $b) :body BODY]` body does not substitute parameters on application.** `[?let $f = [?fn ($a, $b) :body [+ $a $b]] :in $f(1, 2)]` returns the literal body. Single-arg form works. **Warrants a spec item.**

The blocking nature of (1) and (2) is striking: FizzBuzz is the
canonical 30-second exercise. The natural form is unwritable. This
is exactly the surface-completeness drift the Rosetta-corpus process was
created to catch — and it caught it on program #1.
