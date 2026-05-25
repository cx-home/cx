// CX Playground — example library.
//
// Each entry: { label, input, note? }. `input` is the CX source the
// editor shows + the runtime evaluates. `note` is prose appended as
// a trailing `[- … -]` block comment so the example documents itself
// in-pane; the parser strips block comments at eval time so the
// comment is purely cosmetic.
//
// Grouped by `data` (inert structure, round-tripped through the
// CX/JSON/XML projections) and `program` (active directives that
// the runtime evaluates).

(function () {
  'use strict';

  const data = {
    'atom': {
      label: "Atom — element with one attribute",
      input: "[pizza size=large]",
      note:  "The simplest CX shape: one element, one attribute. Switch the Output tab to JSON or XML to see the same value in each projection."
    },
    'nested': {
      label: "Nested — containment tree",
      input: [
        "[order",
        "  [customer name=Alice]",
        "  [item name=pizza qty=2]",
        "  [item name=salad qty=1]]"
      ].join('\n'),
      note:  "Elements nest by containment, like XML. Children appear in document order. JSON projection turns the children list into an object; XML round-trips verbatim."
    },
    'whole-shop': {
      label: "Whole shop — multi-record document",
      input: [
        "[shop name='Slice Society'",
        "  [menu",
        "    [pizza id=1 name=Margherita price=12]",
        "    [pizza id=2 name=Pepperoni  price=14]]",
        "  [staff",
        "    [chef name=Alice]",
        "    [server name=Bob]]]"
      ].join('\n'),
      note:  "A realistic shape — attributes for scalars, nested elements for containment. CX's homoiconic surface means the same syntax later carries directives (programs)."
    },
  };

  const program = {
    'find-attr-eq': {
      label: "CXPath — find by attribute value",
      input: [
        "[users",
        "  [user name=Alice  role=admin]",
        "  [user name=Bob    role=editor]",
        "  [user name=Carol  role=admin]]",
        "[?for $u :in //user[@role='admin']",
        "  :yield [admin name=$u/@name]]"
      ].join('\n'),
      note:  "CXPath predicate filter. `//user[@role='admin']` selects users whose `role` attribute equals `admin`. The `[?for]` comprehension iterates the matches and `:yield`s a new shape per match."
    },
    'for-seq': {
      label: "[?for] — iterate a literal sequence",
      input: [
        "[?for $n :in (1, 2, 3, 4, 5)",
        "  :yield [square :n $n :sq [* $n $n]]]"
      ].join('\n'),
      note:  "Plain comprehension over a literal sequence `(…)`. Each `:yield` emits one record into the result sequence. `[* $n $n]` is the math directive — CX's arithmetic uses the same `[? …]` shape as everything else."
    },
    'for-where': {
      label: "[?for] — :where filter clause",
      input: [
        "[?for $n :in (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)",
        "  :where [> $n 5]",
        "  :yield [big :n $n]]"
      ].join('\n'),
      note:  "`:where` filters the iteration. Only items passing the predicate reach `:yield`. Predicates use the bracket directive form: `[> $n 5]` reads as `$n > 5`."
    },
    'let-arith': {
      label: "[?let] — bind a value, then compute",
      input: [
        "[?let $price = 12 :in",
        " [?let $qty   = 3  :in",
        "  [order :subtotal [* $price $qty]",
        "         :tax      [* [* $price $qty] 0.08]]]]"
      ].join('\n'),
      note:  "`[?let]` introduces a binding scoped to its `:in` body. Nested `[?let]` chains build local scopes — the same shape Lisp lets you do."
    },
    'if-truthy': {
      label: "[?if] — branch on a predicate",
      input: [
        "[?let $score = 87 :in",
        " [?if [>= $score 80]",
        "   :then [grade :letter 'A']",
        "   :else [grade :letter 'B']]]"
      ].join('\n'),
      note:  "`[?if]` evaluates its predicate and runs `:then` or `:else`. Like `[?let]`, the body is a CX expression — no special statement / expression split. Predicates use the bracket form: `[>= $score 80]`."
    },
    'fn-via-map': {
      label: "[?fn] — anonymous function via [?map :using]",
      input: [
        "[?map (1, 2, 3, 4, 5) :using [?fn $x [* $x $x]]]"
      ].join('\n'),
      note:  "`[?fn $x BODY]` is an anonymous function. `[?map xs :using fn]` invokes it on each element of `xs`. This is the working v0.8.0 surface for user-defined behavior — closure-passing into higher-order directives. `[?def]` for named module-level functions is also part of the surface (see ADR 0034) but uses richer syntax not shown here."
    },
    'cxpath-predicate': {
      label: "CXPath — boolean attribute predicate",
      input: [
        "[users",
        "  [user name=Alice  active=true  age=30]",
        "  [user name=Bob    active=false age=25]",
        "  [user name=Carol  active=true  age=22]]",
        "[?for $u :in //user[@active=true]",
        "  :yield [active-user :name $u/@name :age $u/@age]]"
      ].join('\n'),
      note:  "Predicates accept any value — including booleans. `[@active=true]` keeps only users whose `active` attribute is `true`."
    },
    'match-multi': {
      label: "[?match] — multi-arm :case / :else",
      input: [
        "[requests",
        "  [request status=200]",
        "  [request status=404]",
        "  [request status=500]",
        "  [request status=204]]",
        "[?for $r :in //request",
        "  :yield [?match $r/@status",
        "    :case \"200\" :yield [classify :level 'ok']",
        "    :case \"204\" :yield [classify :level 'no-content']",
        "    :case \"404\" :yield [classify :level 'not-found']",
        "    :case \"500\" :yield [classify :level 'server-error']",
        "    :else        :yield [classify :level 'unknown']]]"
      ].join('\n'),
      note:  "Multi-arm `[?match]` per ADR 0029. Each `:case` matches an exact value; `:else` is the fallback. Arms evaluate top-down; the first match wins. Attribute values come through as strings, so the cases quote the numeric codes."
    },
    'sleep-mock': {
      label: "[?sleep] — :mock for instant logical-clock advance",
      input: [
        "[?timeout 100ms",
        "  :body [?let $_ = [?sleep 500ms :mock] :in [ok :value 'never']]]"
      ].join('\n'),
      note:  "Per ADR 0039: `[?sleep DUR :mock]` advances a logical clock instantly — useful for testing `[?timeout]` / `[?retry]` deterministically. The outer `[?timeout 100ms]` fires because the inner mock-sleep advances the clock past 100ms."
    },
    'map-par-mock': {
      label: "[?map :par] — parallel-shape demo (instant via :mock)",
      input: [
        "[?map (1, 2, 3, 4, 5, 6, 7, 8)",
        "  :using [?fn $n [?let $_ = [?sleep 500ms :mock] :in [* $n $n]]]",
        "  :par :ordered]"
      ].join('\n'),
      note:  "Parallel-shape demo that's instant because `:mock` makes the sleep virtual. Add or drop `:ordered` to choose source-order vs unordered output. For real wall-clock parallelism see `map-par-wall`."
    },
    'for-par-wall': {
      label: "[?for :par] — wall-clock parallel comprehension",
      input: [
        "[?for $n :in (1, 2, 3, 4, 5, 6, 7, 8)",
        "      :yield [?let $_ = [?sleep 500ms] :in [item :n $n :sq [* $n $n]]]",
        "      :par]"
      ].join('\n'),
      note:  "Wall-clock parallelism. Under `make guide-http` (pthreads + SharedArrayBuffer) the 8 sleeps overlap on real OS threads — total ~500ms. Under file:// or generic HTTP the wasm runtime is single-threaded, so `:par` is an annotation but execution is sequential — total ~4s. Items appear one at a time as workers complete."
    },
    'async-future-mock': {
      label: "[?async] + [?await-all] — two futures, mock-clocked",
      input: [
        "[?let $fast = [?async [?let $_ = [?sleep 100ms :mock]  :in [ok :value 'a']]] :in",
        " [?let $slow = [?async [?let $_ = [?sleep 400ms :mock] :in [ok :value 'b']]] :in",
        "  [?await-all ($fast, $slow)]]]"
      ].join('\n'),
      note:  "Two `[?async]` futures awaited together. With `:mock` sleeps the futures resolve instantly in logical time. `[?await-all]` returns the per-future results in source order."
    },
    'map-par-wall': {
      label: "[?map :par] — wall-clock sleep (visible streaming)",
      input: [
        "[?map (1, 2, 3, 4)",
        "  :using [?fn $n [?let $_ = [?sleep 500ms] :in [* $n $n]]]",
        "  :par]"
      ].join('\n'),
      note:  "Bare `[?sleep 500ms]` really sleeps. Under `make guide-http` mode the 4 workers overlap on real OS threads — total ~500ms, completion-order output. Under file:// or generic HTTP V's spawn falls back to inline execution — total ~2s, source order. The output streams: each item appears as its worker finishes."
    },
    'modify-delete': {
      label: "[?modify] — pure-functional :delete",
      input: [
        "[?let $doc = [users",
        "               [user id=1 name=Alice  banned=false]",
        "               [user id=2 name=Bob    banned=true]",
        "               [user id=3 name=Carol  banned=false]",
        "               [user id=4 name=Dave   banned=true]] :in",
        "  [?modify $doc //user[@banned=true] :delete]]"
      ].join('\n'),
      note:  "`[?modify]` is pure-functional: it returns a new document; the original `$doc` is unchanged. `//user[@banned=true]` selects banned users; `:delete` removes them. Compose multiple `[?modify]` calls with `[?let]` to chain transformations (per ADR 0030)."
    },
  };

  window.cxPlaygroundExamples = { data, program };
})();
