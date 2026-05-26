// CX Playground — 100 progressive eval examples.
// Single ordered list. Groups (simple → complex, related together):
//   1-15   pure data  ·  16-25  bindings/arith  ·  26-35  control flow
//   36-45  comprehensions  ·  46-60  map/reduce (incl. :par)
//   61-70  modify/pipe/cxpath  ·  71-80  builtins
//   81-90  concurrency  ·  91-100 resilience
// Generator: /tmp/gen_examples_v4.py — every entry CLI-audited.

(function () {
  'use strict';

  const program = {
    "01-atom-element": {
      label: "[01] Element \u2014 one attribute",
      input: "[pizza size=large]",
      note:  "**Introduces:** the simplest CX shape \u2014 one element with one attribute. Eval returns the value unchanged. Switch the Output tab to JSON / XML to see the same value across projections.",
    },
    "02-string-scalar": {
      label: "[02] String \u2014 bare scalar",
      input: "\"hello, world\"",
      note:  "**Introduces:** scalar literals. Strings (`\"\u2026\"`) are first-class values; everything in CX is a value, including bare scalars at the top level.",
    },
    "03-number-scalars": {
      label: "[03] Numbers \u2014 int / float / negative",
      input: "[stats min=-5 mid=0 max=99.5 ratio=0.001]",
      note:  "**Introduces:** numeric attribute values. Positive / negative / int / float / sub-unit \u2014 all round-trip through projections.",
    },
    "04-boolean-scalars": {
      label: "[04] Booleans \u2014 feature flags",
      input: "[user active=true verified=false admin=true blocked=false]",
      note:  "**Introduces:** boolean attributes. `true` / `false` are typed scalars (not strings); JSON projects them as booleans.",
    },
    "05-atom-values": {
      label: "[05] Atoms \u2014 `:kebab-case`",
      input: "[response status=:ok]",
      note:  "**Introduces:** atoms \u2014 `:kebab-case` identifiers that evaluate to themselves. Use atoms for enum-like markers without quoting (ADR 0033).",
    },
    "06-string-quoting": {
      label: "[06] Strings \u2014 quoting variants",
      input: "[note\n  single='single quotes'\n  double=\"double quotes\"\n  apostrophe=\"can't\"]",
      note:  "**Introduces:** string quoting \u2014 both `'\u2026'` and `\"\u2026\"`. Pick whichever avoids the most escapes.",
    },
    "07-triple-quoted": {
      label: "[07] Strings \u2014 triple-quoted (multiline)",
      input: "[doc\n  body='''line 1\nline 2\nline 3''']",
      note:  "**Introduces:** triple-quoted strings `'''\u2026'''`. Multi-line content with embedded newlines, useful for prose or code blocks.",
    },
    "08-nested-elements": {
      label: "[08] Nested elements \u2014 containment",
      input: "[order\n  [customer name=Alice]\n  [item name=pizza qty=2]\n  [item name=salad qty=1]]",
      note:  "**Introduces:** nesting by containment. Children appear in document order. JSON projects child-element lists as arrays; XML round-trips verbatim.",
    },
    "09-attrs-vs-children": {
      label: "[09] Attributes vs child elements",
      input: "[user id=1 active=true\n  [email \"a@x.com\"]\n  [phone \"+1-555\"]]",
      note:  "**Introduces:** the attribute-vs-child distinction. Attributes (`id`, `active`) live on the open tag; child elements (`[email \u2026]`) live inside the body. Both project cleanly.",
    },
    "10-mixed-content": {
      label: "[10] Element \u2014 attrs AND text body",
      input: "[link href=\"https://cx-home.github.io\" \"CX Guide\"]",
      note:  "**Introduces:** an element carrying both attributes AND a body in the same tag \u2014 common for link / button shapes.",
    },
    "11-sequence": {
      label: "[11] Sequence \u2014 ordered values",
      input: "(1, 2, 3, 4, 5)",
      note:  "**Introduces:** sequence literal `(a, b, c)`. Ordered, heterogeneous, evaluated to themselves. JSON projects as an array.",
    },
    "12-sequence-mixed": {
      label: "[12] Sequence \u2014 mixed scalar types",
      input: "(1, 2.5, \"three\", true, :four)",
      note:  "**Introduces:** heterogeneous sequences \u2014 CX holds any scalar mix in one container.",
    },
    "13-map-literal": {
      label: "[13] Map \u2014 string keys",
      input: "{name: 'Alice', age: 30, active: true}",
      note:  "**Introduces:** map literal `{key: value, \u2026}`. String-typed keys; JSON projects as an object.",
    },
    "14-durations": {
      label: "[14] Durations \u2014 first-class scalars",
      input: "[timing short=50ms medium=2s long=15m very-long=2h]",
      note:  "**Introduces:** duration scalars `Nms` / `Ns` / `Nm` / `Nh`. Recognized by `[?sleep]`, `[?timeout]`, etc. (ADR 0039).",
    },
    "15-hyphenated-names": {
      label: "[15] Hyphenated names \u2014 kebab identifiers",
      input: "[user-profile is-active=true\n  [contact-info\n    [phone-number kind=mobile value=\"+1-555\"]]]",
      note:  "**Introduces:** kebab-case identifiers. Element and attribute names can carry hyphens (`user-profile`, `is-active`).",
    },
    "16-let-basic": {
      label: "[16] [?let] \u2014 bind a value, then use it",
      input: "[?let $name = 'Alice' :in [greeting hello=$name]]",
      note:  "**Introduces:** `[?let $var = VALUE :in BODY]` \u2014 lexical binding. `$name` substitutes its value inside BODY. Attribute form `hello=$name` reads the binding.",
    },
    "17-let-nested": {
      label: "[17] [?let] \u2014 nested bindings",
      input: "[?let $price = 12 :in\n [?let $qty   = 3  :in\n  [order subtotal=[* $price $qty]\n         tax=[* [* $price $qty] 0.08]]]]",
      note:  "**Introduces:** nested `[?let]` chains build local scopes. `[* $price $qty]` is the multiplication directive \u2014 CX's arithmetic uses the same `[? \u2026]` bracket shape as every other op.",
    },
    "18-arith-add": {
      label: "[18] Arithmetic \u2014 add",
      input: "[+ 1 2 3 4 5]",
      note:  "**Introduces:** the `[+ a b c \u2026]` builtin \u2014 prefix-form addition over any number of arguments.",
    },
    "19-arith-mixed": {
      label: "[19] Arithmetic \u2014 sub / mul / div",
      input: "[?let $x = 10 :in [?let $y = 3 :in [stats sum=[+ $x $y] diff=[- $x $y] prod=[* $x $y]]]]",
      note:  "**Introduces:** `[-]` (subtract) and `[*]` (multiply). All arithmetic is prefix-form.",
    },
    "20-string-concat": {
      label: "[20] Strings \u2014 concat builtin",
      input: "[concat \"hello\" \", \" \"world\"]",
      note:  "**Introduces:** `[concat str\u2081 str\u2082 \u2026]` \u2014 string concatenation.",
    },
    "21-string-length": {
      label: "[21] Strings \u2014 length",
      input: "[string-length \"hello\"]",
      note:  "**Introduces:** `[string-length s]` \u2014 character count of a string.",
    },
    "22-string-contains": {
      label: "[22] Strings \u2014 contains",
      input: "[contains \"foobar\" \"oob\"]",
      note:  "**Introduces:** `[contains haystack needle]` \u2014 boolean test for substring presence.",
    },
    "23-comparison-eq": {
      label: "[23] Comparison \u2014 equality",
      input: "[?let $x = 7 :in [= $x 7]]",
      note:  "**Introduces:** `[= a b]` \u2014 equality predicate. Returns `true` / `false`.",
    },
    "24-comparison-gt": {
      label: "[24] Comparison \u2014 `>` / `<` / `>=`",
      input: "[?let $n = 42 :in [stats gt=[> $n 10] lt=[< $n 100] ge=[>= $n 42]]]",
      note:  "**Introduces:** numeric comparisons `[> a b]`, `[< a b]`, `[>= a b]`, `[<= a b]`. Each returns a boolean.",
    },
    "25-logical": {
      label: "[25] Logical \u2014 and / or / not",
      input: "[?let $on = true :in [and $on [or false true] [not false]]]",
      note:  "**Introduces:** `[and \u2026]` / `[or \u2026]` / `[not x]` \u2014 boolean operators with short-circuit semantics.",
    },
    "26-if-basic": {
      label: "[26] [?if] \u2014 branch on a predicate",
      input: "[?let $score = 87 :in\n [?if [>= $score 80] :then [grade letter='A']\n                    :else [grade letter='B']]]",
      note:  "**Introduces:** `[?if PRED :then EXPR :else EXPR]`. Predicate is any expression; truthy values pick `:then`, falsy pick `:else`.",
    },
    "27-if-chained": {
      label: "[27] [?if] \u2014 chained branches",
      input: "[?let $n = 25 :in\n [?if [< $n 10]  :then :small\n :else [?if [< $n 50] :then :medium :else :large]]]",
      note:  "**Introduces:** chaining `[?if]` via nested `:else`. The inner `[?if]` itself returns a value, so it's a valid `:else` body.",
    },
    "28-match-scalar": {
      label: "[28] [?match] \u2014 multi-arm on a scalar",
      input: "[?let $s = 200 :in\n [?match $s\n   :case 200 :yield :ok\n   :case 404 :yield :not-found\n   :else     :yield :err]]",
      note:  "**Introduces:** `[?match scrutinee :case V :yield E \u2026]`. First matching `:case` wins; `:else` is the fallback (ADR 0029).",
    },
    "29-match-else-fallback": {
      label: "[29] [?match] \u2014 :else fires",
      input: "[?let $s = 500 :in\n [?match $s\n   :case 200 :yield :ok\n   :case 404 :yield :not-found\n   :else     :yield :err]]",
      note:  "**Introduces:** the `:else` fallback. When no `:case` matches, `:else` fires.",
    },
    "30-match-no-else": {
      label: "[30] [?match] \u2014 no :else returns ()",
      input: "[?let $s = 500 :in\n [?match $s\n   :case 200 :yield :ok\n   :case 404 :yield :not-found]]",
      note:  "**Introduces:** missing `:else` semantics. With no fallback, an unmatched scrutinee yields the empty sequence `()` (ADR 0029 D9).",
    },
    "31-match-wildcard": {
      label: "[31] [?match] \u2014 wildcard `_`",
      input: "[?let $v = \"surprise\" :in\n [?match $v\n   :case 200    :yield :http-ok\n   :case _      :yield :other]]",
      note:  "**Introduces:** the wildcard `_` pattern. Matches any value \u2014 equivalent to `:else` but lets you bind via richer patterns.",
    },
    "32-match-element-shape": {
      label: "[32] [?match] \u2014 element shape dispatch",
      input: "[?let $n = [prose \"hello\"] :in\n [?match $n\n   :case [prose $p] :yield [p body=$p]\n   :case [code $c]  :yield [pre body=$c]\n   :else            :yield ()]]",
      note:  "**Introduces:** matching on element shape with binding. `[prose $p]` matches any `prose` element and binds its body to `$p` for use in `:yield`.",
    },
    "33-match-type-strict": {
      label: "[33] [?match] \u2014 type-strict scalar",
      input: "[?let $v = 200 :in\n [?match $v\n   :case \"200\" :yield :string-match\n   :case 200   :yield :int-match\n   :else       :yield :other]]",
      note:  "**Introduces:** type-strict scalar matching. `200` (int) \u2260 `\"200\"` (string).",
    },
    "34-cast-string-int": {
      label: "[34] [cast] \u2014 string to int",
      input: "[cast \"42\" :int]",
      note:  "**Introduces:** `[cast VALUE :TYPE]` \u2014 explicit scalar conversion per ADR 0033. `CXER0290` on invalid.",
    },
    "35-cast-float-int": {
      label: "[35] [cast] \u2014 float to int (truncate)",
      input: "[cast 3.7 :int]",
      note:  "**Introduces:** float \u2192 int truncation via `[cast]`. Result is `3`, not rounded.",
    },
    "36-for-sequence": {
      label: "[36] [?for] \u2014 iterate a literal sequence",
      input: "[?for $n :in (1, 2, 3, 4, 5)\n  :yield [square n=$n sq=[* $n $n]]]",
      note:  "**Introduces:** the comprehension `[?for $var :in source :yield EXPR]`. Iterates `source`, evaluates `EXPR` per item, collects results.",
    },
    "37-for-where": {
      label: "[37] [?for] \u2014 :where filter",
      input: "[?for $n :in (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)\n  :where [> $n 5]\n  :yield [big n=$n]]",
      note:  "**Introduces:** the `:where` clause. Filters items before `:yield`. Predicates use the bracket form: `[> $n 5]`.",
    },
    "38-for-yield-cond": {
      label: "[38] [?for] \u2014 conditional :yield body",
      input: "[?for $n :in (1, 2, 3, 4, 5, 6, 7, 8)\n  :yield [?if [> $n 5] :then [big n=$n] :else [small n=$n]]]",
      note:  "**Introduces:** conditional inside `:yield`. Every iteration yields one element; the branch decides which shape.",
    },
    "39-for-nested": {
      label: "[39] [?for] \u2014 nested iteration",
      input: "[?for $i :in (1, 2, 3)\n  :yield [?for $j :in (1, 2, 3)\n    :yield [pair i=$i j=$j]]]",
      note:  "**Introduces:** nested comprehensions. The outer `:yield` body is itself a comprehension. Produces a 2D shape.",
    },
    "40-for-multi-source": {
      label: "[40] [?for] \u2014 multiple sources",
      input: "[?for $a :in (1, 2, 3)\n      $b :in (10, 20, 30)\n  :yield [pair a=$a b=$b]]",
      note:  "**Introduces:** multiple `$var :in source` clauses. Outer source iterates outer loop, inner source iterates inner (Cartesian product).",
    },
    "41-for-let": {
      label: "[41] [?for] \u2014 :let clause for derived values",
      input: "[?for $n :in (1, 2, 3, 4, 5)\n  :let  $sq = [* $n $n]\n  :yield [pair n=$n sq=$sq]]",
      note:  "**Introduces:** `:let` clause \u2014 bind a derived value once per iteration, reuse in subsequent clauses.",
    },
    "42-for-yield-par": {
      label: "[42] [?for :par] \u2014 wall-clock parallel comprehension",
      input: "[?for $n :in (1, 2, 3, 4, 5, 6, 7, 8)\n      :yield [?let $_ = [?sleep 500ms] :in [item n=$n sq=[* $n $n]]]\n      :par]",
      note:  "**Introduces:** `[?for :par]` parallelizes the outermost generator. Under `make guide-http` mode the 8 sleeps overlap on real OS threads (~500ms). Under file:// the wasm runtime is single-threaded (~4s). Items stream in source order.",
    },
    "43-for-yield-par-mock": {
      label: "[43] [?for :par] \u2014 :mock sleep (instant)",
      input: "[?for $n :in (1, 2, 3, 4, 5, 6, 7, 8)\n      :yield [?let $_ = [?sleep 500ms :mock] :in [item n=$n sq=[* $n $n]]]\n      :par]",
      note:  "**Introduces:** `[?for :par]` with `:mock` sleep \u2014 instant in wall-clock. Useful for testing parallel composition semantics without real delays.",
    },
    "44-for-yield-stream": {
      label: "[44] [?for] \u2014 yield streams as items complete",
      input: "[?for $n :in (1, 2, 3, 4)\n  :yield [?let $_ = [?sleep 300ms] :in [tick n=$n]]]",
      note:  "**Introduces:** `[?for]` streaming. Each `:yield` flushes one chunk to the output pane; you see items appear one at a time at the sleep cadence.",
    },
    "45-for-empty": {
      label: "[45] [?for] \u2014 empty source",
      input: "[?for $n :in () :yield [item n=$n]]",
      note:  "**Introduces:** comprehension over an empty source. Yields zero elements \u2014 result is the empty sequence `()`.",
    },
    "46-fn-via-map": {
      label: "[46] [?fn] \u2014 anonymous function via [?map]",
      input: "[?map (1, 2, 3, 4, 5) :using [?fn $x [* $x $x]]]",
      note:  "**Introduces:** `[?fn $param BODY]` \u2014 anonymous closure. `[?map xs :using fn]` invokes it on each element of `xs` (ADR 0040).",
    },
    "47-map-cube": {
      label: "[47] [?map] \u2014 composition with builtins",
      input: "[?map (1, 2, 3, 4) :using [?fn $n [* $n [* $n $n]]]]",
      note:  "**Introduces:** composed builtins inside `[?fn]`. `[* $n [* $n $n]]` is `$n \u00d7 $n \u00d7 $n` \u2014 cube.",
    },
    "48-map-with-let": {
      label: "[48] [?map] \u2014 closure with internal [?let]",
      input: "[?map (1, 2, 3, 4) :using [?fn $n [?let $sq = [* $n $n] :in [point x=$n y=$sq]]]]",
      note:  "**Introduces:** rich-shape per-item output. The closure builds a `[point]` element per input, using `[?let]` to name an intermediate.",
    },
    "49-map-par-mock": {
      label: "[49] [?map :par] \u2014 instant via :mock",
      input: "[?map (1, 2, 3, 4, 5, 6, 7, 8)\n  :using [?fn $n [?let $_ = [?sleep 500ms :mock] :in [* $n $n]]]\n  :par :ordered]",
      note:  "**Introduces:** `[?map :par]` parallel map. With `:mock` sleep this is instant (virtual time). `:ordered` preserves source order; drop it for completion-order output.",
    },
    "50-map-par-wall": {
      label: "[50] [?map :par] \u2014 wall-clock streaming",
      input: "[?map (1, 2, 3, 4)\n  :using [?fn $n [?let $_ = [?sleep 500ms] :in [* $n $n]]]\n  :par]",
      note:  "**Introduces:** wall-clock `[?map :par]`. Under `make guide-http` mode the 4 workers run on real OS threads (~500ms). Under file:// the wasm runtime is single-threaded (~2s). Items stream as each worker completes.",
    },
    "51-map-par-ordered": {
      label: "[51] [?map :par :ordered] \u2014 order-preserving",
      input: "[?map (1, 2, 3, 4)\n  :using [?fn $n [?let $_ = [?sleep 500ms] :in [* $n $n]]]\n  :par :ordered]",
      note:  "**Introduces:** `:ordered` reassembles results in source order regardless of completion timing. Trade-off: a completion-tracking buffer.",
    },
    "52-fn-passed": {
      label: "[52] [?fn] \u2014 define once, pass to [?map]",
      input: "[?let $sqr = [?fn $n [* $n $n]] :in\n  [?map (1, 2, 3, 4, 5, 6, 7, 8) :using $sqr :par :ordered]]",
      note:  "**Introduces:** closure-passing. Define `$sqr` once with `[?let]`, pass it as `:using` \u2014 decouples definition from use.",
    },
    "53-reduce-sum": {
      label: "[53] [?reduce] \u2014 fold to one value (sum)",
      input: "[?reduce (1, 2, 3, 4, 5) :using [?fn ($a, $b) [+ $a $b]] :init 0]",
      note:  "**Introduces:** `[?reduce xs :using fn :init z]` \u2014 strict left-fold. `fn(z, x\u2081)` \u2192 `fn(prev, x\u2082)` \u2192 \u2026 Returns the final accumulator.",
    },
    "54-reduce-product": {
      label: "[54] [?reduce] \u2014 fold to a product",
      input: "[?reduce (1, 2, 3, 4, 5) :using [?fn ($a, $b) [* $a $b]] :init 1]",
      note:  "**Introduces:** another `[?reduce]` shape \u2014 product (5! = 120). `:init 1` is the multiplicative identity.",
    },
    "55-reduce-par": {
      label: "[55] [?reduce :par] \u2014 associative tree-reduce",
      input: "[?reduce (1, 2, 3, 4, 5, 6, 7, 8) :using [?fn ($a, $b) [+ $a $b]] :init 0 :par]",
      note:  "**Introduces:** `[?reduce :par]` \u2014 tree-split reduce. `:using` MUST be associative; `:init` MUST be the identity. Returns 36 either way.",
    },
    "56-map-then-reduce": {
      label: "[56] Map \u2192 reduce composition",
      input: "[?reduce [?map (1, 2, 3, 4, 5) :using [?fn $n [* $n $n]]]\n  :using [?fn ($a, $b) [+ $a $b]] :init 0]",
      note:  "**Introduces:** common map-then-reduce idiom. Square each, then sum the squares (= 55).",
    },
    "57-map-par-bulkhead": {
      label: "[57] [?map :par] \u2014 bounded with [?bulkhead]",
      input: "[?map (1, 2, 3, 4, 5, 6, 7, 8)\n  :using [?fn $n [?bulkhead :max-concurrent 2 :body [?let $_ = [?sleep 100ms :mock] :in [* $n $n]]]]\n  :par]",
      note:  "**Introduces:** the canonical bounded-parallelism idiom. Default `:par` is unbounded; wrap the `:using` body in `[?bulkhead]` to cap fan-out. `cx lsp` emits CXLS005 if you forget the wrap (ADR 0040 D14).",
    },
    "58-par-shared-cb": {
      label: "[58] [?map :par] \u2014 shared [?circuit-breaker]",
      input: "[?map (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)\n  :using [?fn $n [?circuit-breaker :threshold 0.5 :window 1s :reset 10s :name \"shared\"\n                    :body [* $n $n]]]\n  :par]",
      note:  "**Introduces:** state-sharing under `:par`. The named `[?circuit-breaker]` shares state across parallel workers per spec/code.md \u00a710.2.7 \u2014 same source-text directive = one shared breaker.",
    },
    "59-par-rich-shape": {
      label: "[59] [?map :par] \u2014 emit rich shapes",
      input: "[?map (1, 2, 3, 4)\n  :using [?fn $n [?let $_ = [?sleep 250ms] :in [point x=$n y=[* $n 2] z=[* $n $n]]]]\n  :par]",
      note:  "**Introduces:** rich per-item output. Each worker emits a `[point]` with three computed slots. The streaming pane fills in as workers complete.",
    },
    "60-par-with-composition": {
      label: "[60] [?map :par] \u2014 composed with everything",
      input: "[?map (1, 2, 3, 4)\n  :using [?fn $n [?retry :max 3 :body\n                  [?timeout 200ms :body\n                    [?let $_ = [?sleep 50ms] :in [computed n=$n sq=[* $n $n]]]]]]\n  :par :ordered]",
      note:  "**Introduces:** the full composition \u2014 `[?map :par]` over a `:using` closure that nests `[?retry]` + `[?timeout]` + `[?sleep]`. Parallel workers compose freely with resilience directives.",
    },
    "61-modify-delete": {
      label: "[61] [?modify] \u2014 pure-functional :delete",
      input: "[?let $doc = [users\n  [user id=1 name=Alice  banned=false]\n  [user id=2 name=Bob    banned=true]\n  [user id=3 name=Carol banned=false]\n  [user id=4 name=Dave   banned=true]] :in\n  [?modify $doc //user[@banned=true] :delete]]",
      note:  "**Introduces:** `[?modify DOC PATH :ACTION]` (ADR 0030). Pure-functional \u2014 returns a new document; the original `$doc` is unchanged. `//user[@banned=true]` is a CXPath predicate filter; `:delete` removes the matches.",
    },
    "62-modify-set-attr": {
      label: "[62] [?modify] \u2014 :set-attr on every match",
      input: "[?let $doc = [users\n  [user id=1 [name Alice]]\n  [user id=2 [name Bob]]] :in\n  [?modify $doc //user :set-attr status \"active\"]]",
      note:  "**Introduces:** `:set-attr NAME VALUE` \u2014 writes an attribute on every matched node. Adds `status=active` to every user.",
    },
    "63-modify-chain": {
      label: "[63] [?modify] \u2014 chained transforms via [?let]",
      input: "[?let $doc = [users\n  [user id=1 name=Alice banned=false]\n  [user id=2 name=Bob   banned=true]\n  [user id=3 name=Carol banned=false]] :in\n  [?let $clean = [?modify $doc //user[@banned=true] :delete] :in\n    [?modify $clean //user :set-attr role \"member\"]]]",
      note:  "**Introduces:** composing multiple `[?modify]` steps with `[?let]`. First delete banned users, then set `role=member` on the survivors.",
    },
    "64-cxpath-axes": {
      label: "[64] CXPath \u2014 child + attribute axes",
      input: "[?let $doc = [order [item qty=2] [item qty=3] [item qty=5]] :in\n  [?for $i :in $doc/item :yield $i/@qty]]",
      note:  "**Introduces:** CXPath axes \u2014 `/item` selects direct children named `item`; `/@qty` selects the `qty` attribute.",
    },
    "65-cxpath-where": {
      label: "[65] CXPath \u2014 filter via :where",
      input: "[?let $doc = [users\n  [user name=Alice active=true age=30]\n  [user name=Bob   active=false age=25]\n  [user name=Carol active=true age=22]] :in\n  [?for $u :in $doc/user\n   :where [= $u/@active true]\n   :yield [active-user name=$u/@name age=$u/@age]]]",
      note:  "**Introduces:** filtering a CXPath result via `:where`. `$doc/user` selects direct children named `user`; `:where [= $u/@active true]` filters them.",
    },
    "66-pipe-canonical": {
      label: "[66] [?pipe] \u2014 canonical pipeline",
      input: "[?pipe (1, 2, 3, 4) :through [?fn $xs [?for $x :in $xs :where [> $x 2] :yield $x]] :through count]",
      note:  "**Introduces:** `[?pipe IN :through STAGE :through STAGE]` \u2014 value flows through each stage. `count` is the sequence-length builtin.",
    },
    "67-pipe-infix": {
      label: "[67] [?pipe] \u2014 infix `|` sugar",
      input: "(1, 2, 3, 4) | [?fn $xs [?for $x :in $xs :where [> $x 2] :yield $x]] | count",
      note:  "**Introduces:** infix `|` sugar for `[?pipe]`. Identical semantics, more compact.",
    },
    "68-pipe-modify": {
      label: "[68] [?pipe] \u2014 chained [?modify]",
      input: "[?let $doc = [users [user [name Alice]] [user [name Bob]]] :in\n  $doc | [?modify //user :set-attr verified true]]",
      note:  "**Introduces:** pipe + `[?modify]` \u2014 common pattern for read-then-transform. The doc flows into modify; result is the transformed doc.",
    },
    "69-fallback-recover": {
      label: "[69] [?fallback] \u2014 on err, recover",
      input: "[?fallback :body [err code=\"down-primary\"] :recover-with [err code=\"down-secondary\"]]",
      note:  "**Introduces:** `[?fallback :body \u2026 :recover-with \u2026]`. If `:body` is an err, evaluate `:recover-with` and return that. Otherwise return the body's value.",
    },
    "70-fallback-success": {
      label: "[70] [?fallback] \u2014 body succeeds, no recover",
      input: "[?fallback :body [ok value=\"healthy\"] :recover-with [ok value=\"never\"]]",
      note:  "**Introduces:** `[?fallback]` happy path. When `:body` returns a non-err value, that value is returned and `:recover-with` is never evaluated.",
    },
    "71-builtin-head-tail": {
      label: "[71] Sequence \u2014 head + tail",
      input: "[?let $xs = (10, 20, 30, 40) :in [list first=[head $xs] rest=[tail $xs]]]",
      note:  "**Introduces:** `[head xs]` (first element) + `[tail xs]` (everything after the first).",
    },
    "72-builtin-nth": {
      label: "[72] Sequence \u2014 nth (0-indexed)",
      input: "[nth (10, 20, 30, 40) 2]",
      note:  "**Introduces:** `[nth xs i]` \u2014 zero-indexed element access. Returns `30`.",
    },
    "73-builtin-distinct": {
      label: "[73] Sequence \u2014 distinct",
      input: "[distinct (1, 2, 1, 3, 2, 4, 1)]",
      note:  "**Introduces:** `[distinct xs]` \u2014 preserves first occurrence, drops duplicates.",
    },
    "74-builtin-reverse": {
      label: "[74] Sequence \u2014 reverse",
      input: "[reverse (1, 2, 3, 4, 5)]",
      note:  "**Introduces:** `[reverse xs]` \u2014 flips order.",
    },
    "75-builtin-position": {
      label: "[75] Sequence \u2014 position",
      input: "[position (10, 20, 30, 20, 40) 20]",
      note:  "**Introduces:** `[position xs needle]` \u2014 index of first occurrence (0-based), or -1.",
    },
    "76-numeric-abs": {
      label: "[76] Numeric \u2014 abs",
      input: "[abs -42]",
      note:  "**Introduces:** `[abs n]` \u2014 absolute value.",
    },
    "77-numeric-round": {
      label: "[77] Numeric \u2014 round / floor / ceiling",
      input: "[stats r=[round 3.7] f=[floor 3.7] c=[ceiling 3.2]]",
      note:  "**Introduces:** `[round f]` / `[floor f]` / `[ceiling f]` \u2014 float-to-int with three rounding modes.",
    },
    "78-string-substring": {
      label: "[78] Strings \u2014 substring",
      input: "[substring \"hello world\" 6 11]",
      note:  "**Introduces:** `[substring s start end]` \u2014 half-open substring slice.",
    },
    "79-string-starts-ends": {
      label: "[79] Strings \u2014 starts-with / ends-with",
      input: "[checks starts=[starts-with \"hello world\" \"hello\"] ends=[ends-with \"hello world\" \"world\"]]",
      note:  "**Introduces:** `[starts-with s prefix]` + `[ends-with s suffix]` \u2014 boolean tests.",
    },
    "80-string-normalize": {
      label: "[80] Strings \u2014 normalize-space",
      input: "[normalize-space \"  hello   world  \"]",
      note:  "**Introduces:** `[normalize-space s]` \u2014 collapses runs of whitespace, trims edges.",
    },
    "81-sleep-mock-timeout": {
      label: "[81] [?sleep :mock] inside [?timeout]",
      input: "[?timeout 100ms\n  :body [?let $_ = [?sleep 500ms :mock] :in [ok value='never']]]",
      note:  "**Introduces:** `[?sleep DUR :mock]` \u2014 virtual time, instant in wall-clock (ADR 0039). The outer `[?timeout 100ms]` fires because the mock-sleep advances the logical clock past 100ms.",
    },
    "82-sleep-wall": {
      label: "[82] [?sleep DUR] \u2014 real wall-clock",
      input: "[?let $_ = [?sleep 500ms] :in [ok value='woke-up']]",
      note:  "**Introduces:** bare `[?sleep DUR]` \u2014 really sleeps. In the playground the async wasm yields cooperatively so the UI stays responsive.",
    },
    "83-async-await": {
      label: "[83] [?async] + [?await] \u2014 minimal future",
      input: "[?let $f = [?async [ok value=42]] :in [?await $f]]",
      note:  "**Introduces:** `[?async EXPR]` returns a future handle. `[?await $f]` resolves it. Futures are lazy: the body runs on first await.",
    },
    "84-async-mock-sleep": {
      label: "[84] [?async] \u2014 mock sleep then resolve",
      input: "[?let $f = [?async [?let $_ = [?sleep 100ms :mock] :in [ok value='done']]] :in [?await $f]]",
      note:  "**Introduces:** futures with internal mock-sleep. The future resolves in logical time.",
    },
    "85-await-all": {
      label: "[85] [?await-all] \u2014 wait on every future",
      input: "[?let $fast = [?async [?let $_ = [?sleep 100ms :mock] :in [ok value='a']]] :in\n [?let $slow = [?async [?let $_ = [?sleep 400ms :mock] :in [ok value='b']]] :in\n  [?await-all ($fast, $slow)]]]",
      note:  "**Introduces:** `[?await-all (futures\u2026)]`. Waits on every future; returns the sequence of results (or aggregated CXER0240 err).",
    },
    "86-await-any": {
      label: "[86] [?await-any] \u2014 first success wins",
      input: "[?let $broken = [?async [err code=\"down\"]] :in\n [?let $good   = [?async [ok value='survivor']] :in\n  [?await-any ($broken, $good)]]]",
      note:  "**Introduces:** `[?await-any]`. Returns the first successful future; ignores subsequent failures.",
    },
    "87-await-race": {
      label: "[87] [?await-race] \u2014 first to resolve wins",
      input: "[?let $fast = [?async [?let $_ = [?sleep 100ms :mock] :in [ok value='fast']]] :in\n [?let $slow = [?async [?let $_ = [?sleep 500ms :mock] :in [ok value='slow']]] :in\n  [?await-race ($fast, $slow)]]]",
      note:  "**Introduces:** `[?await-race]`. Returns the first future to resolve (success OR fail); cancels the losers.",
    },
    "88-channel-basic": {
      label: "[88] [?channel] \u2014 buffered send / receive",
      input: "[?let $ch = [?channel :name \"c\" :buffer 4] :in\n [?let $_  = [?send 42 :to $ch] :in\n  [?receive :from $ch]]]",
      note:  "**Introduces:** `[?channel :name S :buffer N]` is a typed FIFO queue. `[?send V :to $ch]` enqueues; `[?receive :from $ch]` dequeues. (Note: directives use `:slot value` syntax; the `name=value` attribute form is for element construction.)",
    },
    "89-worker-basic": {
      label: "[89] [?worker] \u2014 long-running task",
      input: "[?worker :name \"w\" :body [ok value='worked']]",
      note:  "**Introduces:** `[?worker :name S :body EXPR]` \u2014 registers a worker. In the sequential substrate the body runs to completion synchronously.",
    },
    "90-cancel": {
      label: "[90] [?cancel] \u2014 abort a future",
      input: "[?let $f = [?async [?let $_ = [?sleep 1s :mock] :in [ok value='never']]] :in\n [?let $_ = [?cancel $f] :in [?await $f]]]",
      note:  "**Introduces:** `[?cancel $handle]`. Requests cancellation; future resolves to `[err :code \"cx-err:CXER0260\"]`.",
    },
    "91-retry-happy": {
      label: "[91] [?retry] \u2014 first try wins",
      input: "[?retry :max 3 :body [ok value='first-try']]",
      note:  "**Introduces:** `[?retry :max N :body EXPR]`. Re-runs `:body` until it returns a non-err value or `:max` is hit. Here it succeeds on attempt 1.",
    },
    "92-retry-eventually": {
      label: "[92] [?retry] \u2014 succeeds after some failures",
      input: "[?retry :max 5\n  :body [?test-err-then-ok :err-count 2 :ok-value [ok value='recovered']]]",
      note:  "**Introduces:** `[?test-err-then-ok]` \u2014 fixture helper that returns err N times then OK. Combined with `[?retry]` shows the retry succeeding after 2 transient failures.",
    },
    "93-retry-exhaustion": {
      label: "[93] [?retry] \u2014 exhausted \u2192 CXER0140",
      input: "[?retry :max 3 :body [?test-always-err]]",
      note:  "**Introduces:** `[?retry]` exhaustion. When `:max` is hit and `:body` still errs, returns `[err :code \"cx-err:CXER0140\" \u2026]`.",
    },
    "94-timeout-fires": {
      label: "[94] [?timeout] \u2014 fires after mock sleep",
      input: "[?timeout 50ms\n  :body [?let $_ = [?sleep 200ms :mock] :in [ok value='too-slow']]]",
      note:  "**Introduces:** `[?timeout DUR :body EXPR]`. If `:body` takes longer than `DUR`, returns CXER0141.",
    },
    "95-circuit-breaker-trips": {
      label: "[95] [?circuit-breaker] \u2014 trips after failures",
      input: "[?for $i :in (1, 2, 3, 4)\n  :yield [?circuit-breaker :threshold 0.5 :window 1s :reset 10s :min-samples 2\n            :body [?test-always-err]]]",
      note:  "**Introduces:** `[?circuit-breaker]`. After `:min-samples` samples and `:threshold` failure ratio, opens for `:reset` time and rejects without invoking `:body`.",
    },
    "96-rate-limit-allow": {
      label: "[96] [?rate-limit] \u2014 under the limit",
      input: "[?for $i :in (1, 2, 3)\n  :yield [?rate-limit :max 10 :per 1s :body [ok i=$i]]]",
      note:  "**Introduces:** `[?rate-limit :max N :per DUR]`. Admits up to N invocations per window. Within the limit, just passes through.",
    },
    "97-rate-limit-over": {
      label: "[97] [?rate-limit] \u2014 exceeds the limit",
      input: "[?for $i :in (1, 2, 3, 4, 5)\n  :yield [?rate-limit :max 2 :per 1s :body [ok i=$i]]]",
      note:  "**Introduces:** over-limit behaviour. After `:max` admits, further calls return `[err :code \"cx-err:CXER0151\" :retry-after DUR]`.",
    },
    "98-bulkhead-pass": {
      label: "[98] [?bulkhead] \u2014 under cap",
      input: "[?bulkhead :max-concurrent 4 :queue 0 :body [ok value=\"in-flight\"]]",
      note:  "**Introduces:** `[?bulkhead :max-concurrent N]`. Sequential evaluator: passes when current concurrent count < N. Saturated \u2192 CXER0152.",
    },
    "99-composition-stack": {
      label: "[99] Composition \u2014 retry + timeout + circuit-breaker",
      input: "[?retry :max 3 :body\n  [?timeout 100ms :body\n    [?circuit-breaker :threshold 0.5 :window 1s :reset 10s\n      :body [ok value=\"layered\"]]]]",
      note:  "**Introduces:** layered resilience composition. Outer `[?retry]` wraps inner `[?timeout]` wraps inner `[?circuit-breaker]`. Each err bubbles up the stack.",
    },
    "100-composition-everything": {
      label: "[100] Composition \u2014 every resilience directive",
      input: "[?retry :max 2 :body\n  [?fallback :body\n    [?timeout 200ms :body\n      [?circuit-breaker :threshold 0.5 :window 1s :reset 10s\n        :body [?rate-limit :max 100 :per 1s\n          :body [?bulkhead :max-concurrent 4\n            :body [ok value=\"full-stack\"]]]]]\n    :recover-with [ok value=\"fallback-fire\"]]]",
      note:  "**Introduces:** the full resilience stack \u2014 `[?retry]` \u2192 `[?fallback]` \u2192 `[?timeout]` \u2192 `[?circuit-breaker]` \u2192 `[?rate-limit]` \u2192 `[?bulkhead]`. Demonstrates that all resilience directives compose.",
    },
  };

  window.cxPlaygroundExamples = { program };
})();
