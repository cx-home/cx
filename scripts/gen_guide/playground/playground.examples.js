// CX Playground — example library (auto-generated from conformance/code.txt).
// 100 examples covering the v0.8.0 surface: data shapes, core directives,
// pattern matching, comprehensions, builtins, resilience, concurrency,
// parallelism. Every entry has been verified against the CLI evaluator
// before deploy.

(function () {
  'use strict';

  const data = {
    'atom': {
      label: "Atom \u2014 element with one attribute",
      input: "[pizza size=large]",
      note:  "The simplest CX shape: one element, one attribute. Switch the Output tab to JSON / XML to see the same value in each projection.",
    },
    'nested': {
      label: "Nested \u2014 containment tree",
      input: "[order\n  [customer name=Alice]\n  [item name=pizza qty=2]\n  [item name=salad qty=1]]",
      note:  "Elements nest by containment. Children appear in document order. CX, JSON, and XML projections all round-trip.",
    },
    'whole-shop': {
      label: "Whole shop \u2014 multi-record document",
      input: "[shop name='Slice Society'\n  [menu\n    [pizza id=1 name=Margherita price=12]\n    [pizza id=2 name=Pepperoni  price=14]]\n  [staff\n    [chef name=Alice]\n    [server name=Bob]]]",
      note:  "A realistic shape \u2014 attributes for scalars, nested elements for containment. The same syntax later carries directives (programs); CX is homoiconic.",
    },
    'attrs-vs-children': {
      label: "Attributes vs child elements",
      input: "[user id=1 active=true\n  [email \"a@x.com\"]\n  [phone \"+1-555\"]]",
      note:  "Attributes (`id`, `active`) live on the open tag; child elements (`[email \u2026]`, `[phone \u2026]`) live inside the body. Both project to JSON / XML cleanly.",
    },
    'sequence': {
      label: "Sequence literal",
      input: "(1, 2, 'three', true, [item x=1])",
      note:  "Heterogeneous sequence. CX sequences hold any mix of scalars, strings, booleans, and elements. JSON projects to an array.",
    },
    'map-literal': {
      label: "Map literal \u2014 string keys",
      input: "{name: 'Alice', age: 30, active: true}",
      note:  "Map literals use `{key: value, \u2026}` with string-typed keys. The CX projection mirrors source; JSON renders as an object.",
    },
  };

  const program = {
    'atom-001-bare-literal-in-code': {
      label: "Atoms \u2014 bare literal in code",
      input: ":ok",
      note:  "Atom literal \u2014 a kebab-case identifier evaluates to itself, the simplest CX value (ADR 0033).",
    },
    'atom-002-returned-from-let': {
      label: "Atoms \u2014 returned from let",
      input: "[?let $status = :ok :in $status]",
      note:  "Atom literal \u2014 a kebab-case identifier evaluates to itself, the simplest CX value (ADR 0033).",
    },
    'cast-string-to-int': {
      label: "Casts \u2014 cast string to int",
      input: "[cast \"42\" :int]",
      note:  "Type cast \u2014 `[cast TYPE VALUE]` converts between scalar types per ADR 0033. CXER0290 is the parse / type-mismatch failure mode.",
    },
    'cast-string-to-float': {
      label: "Casts \u2014 cast string to float",
      input: "[cast \"3.14\" :float]",
      note:  "Type cast \u2014 `[cast TYPE VALUE]` converts between scalar types per ADR 0033. CXER0290 is the parse / type-mismatch failure mode.",
    },
    'cast-string-to-bool': {
      label: "Casts \u2014 cast string to bool",
      input: "[cast \"true\" :bool]",
      note:  "Type cast \u2014 `[cast TYPE VALUE]` converts between scalar types per ADR 0033. CXER0290 is the parse / type-mismatch failure mode.",
    },
    'cast-string-to-atom': {
      label: "Casts \u2014 cast string to atom",
      input: "[cast \"hello\" :atom]",
      note:  "Type cast \u2014 `[cast TYPE VALUE]` converts between scalar types per ADR 0033. CXER0290 is the parse / type-mismatch failure mode.",
    },
    'cast-int-to-float': {
      label: "Casts \u2014 cast int to float",
      input: "[cast 5 :float]",
      note:  "Type cast \u2014 `[cast TYPE VALUE]` converts between scalar types per ADR 0033. CXER0290 is the parse / type-mismatch failure mode.",
    },
    'cast-float-to-int-truncate': {
      label: "Casts \u2014 cast float to int truncate",
      input: "[cast 3.7 :int]",
      note:  "Type cast \u2014 `[cast TYPE VALUE]` converts between scalar types per ADR 0033. CXER0290 is the parse / type-mismatch failure mode.",
    },
    'element-whitespace-form-stays-element': {
      label: "Element construction \u2014 element whitespace form stays element",
      input: "[first \"a\"]",
      note:  "Build an element shape from parts. Paren-form `(name :attr v)` is the call-style construction; the bracket form `[name :attr v]` is the literal.",
    },
    'element-construction-dynamic-attr': {
      label: "Element construction \u2014 element construction dynamic attr",
      input: "[?let $l = \"cx\" :in [code lang=$l \"hello\"]]",
      note:  "Build an element shape from parts. Paren-form `(name :attr v)` is the call-style construction; the bracket form `[name :attr v]` is the literal.",
    },
    'element-construction-multi-attr': {
      label: "Element construction \u2014 element construction multi attr",
      input: "[?let $l = \"cx\" :in [?let $h = \"main\" :in [code lang=$l hl=$h \"body\"]]]",
      note:  "Build an element shape from parts. Paren-form `(name :attr v)` is the call-style construction; the bracket form `[name :attr v]` is the literal.",
    },
    'match-multi-001-element-dispatch': {
      label: "Pattern matching \u2014 match multi 001 element dispatch",
      input: "[?let $n = [prose \"hello\"] :in\n  [?match $n\n    :case [prose $p] :yield [p $p]\n    :case [code $c]  :yield [pre $c]\n    :else            :yield ()]]",
      note:  "`[?match]` evaluates the scrutinee then dispatches to the first matching arm (ADR 0029). `:case` matches literal values, `:when` carries a predicate, `:else` is the fallback.",
    },
    'match-multi-002-scalar-literal': {
      label: "Pattern matching \u2014 match multi 002 scalar literal",
      input: "[?let $s = 200 :in\n  [?match $s\n    :case 200 :yield :ok\n    :case 404 :yield :not-found\n    :else     :yield :err]]",
      note:  "`[?match]` evaluates the scrutinee then dispatches to the first matching arm (ADR 0029). `:case` matches literal values, `:when` carries a predicate, `:else` is the fallback.",
    },
    'match-multi-003-else-arm': {
      label: "Pattern matching \u2014 match multi 003 else arm",
      input: "[?let $s = 500 :in\n  [?match $s\n    :case 200 :yield :ok\n    :case 404 :yield :not-found\n    :else     :yield :err]]",
      note:  "`[?match]` evaluates the scrutinee then dispatches to the first matching arm (ADR 0029). `:case` matches literal values, `:when` carries a predicate, `:else` is the fallback.",
    },
    'match-multi-004-no-else-returns-empty': {
      label: "Pattern matching \u2014 match multi 004 no else returns empty",
      input: "[?let $s = 500 :in\n  [?match $s\n    :case 200 :yield :ok\n    :case 404 :yield :not-found]]",
      note:  "`[?match]` evaluates the scrutinee then dispatches to the first matching arm (ADR 0029). `:case` matches literal values, `:when` carries a predicate, `:else` is the fallback.",
    },
    'match-multi-007-wildcard': {
      label: "Pattern matching \u2014 match multi 007 wildcard",
      input: "[?let $v = \"surprise\" :in\n  [?match $v\n    :case 200    :yield :http-ok\n    :case _      :yield :other]]",
      note:  "`[?match]` evaluates the scrutinee then dispatches to the first matching arm (ADR 0029). `:case` matches literal values, `:when` carries a predicate, `:else` is the fallback.",
    },
    'match-multi-008-scalar-type-strict': {
      label: "Pattern matching \u2014 match multi 008 scalar type strict",
      input: "[?let $v = \"200\" :in\n  [?match $v\n    :case 200   :yield :int-match\n    :case \"200\" :yield :string-match\n    :else       :yield :no-match]]",
      note:  "`[?match]` evaluates the scrutinee then dispatches to the first matching arm (ADR 0029). `:case` matches literal values, `:when` carries a predicate, `:else` is the fallback.",
    },
    'builtin-contains': {
      label: "Builtins \u2014 builtin contains",
      input: "contains(\"hello world\", \"world\")",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    'builtin-contains-empty-sub': {
      label: "Builtins \u2014 builtin contains empty sub",
      input: "contains(\"hello world\", \"\")",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    'builtin-starts-with': {
      label: "Builtins \u2014 builtin starts with",
      input: "starts-with(\"hello world\", \"hello\")",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    'builtin-ends-with': {
      label: "Builtins \u2014 builtin ends with",
      input: "ends-with(\"hello world\", \"world\")",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    'builtin-substring': {
      label: "Builtins \u2014 builtin substring",
      input: "substring(\"hello world\", 7, 5)",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    'builtin-substring-to-end': {
      label: "Builtins \u2014 builtin substring to end",
      input: "substring(\"hello world\", 7)",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    'builtin-string-length': {
      label: "Builtins \u2014 builtin string length",
      input: "string-length(\"hello\")",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    'builtin-normalize-space': {
      label: "Builtins \u2014 builtin normalize space",
      input: "normalize-space(\"  hello   world  \")",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    'builtin-concat': {
      label: "Builtins \u2014 builtin concat",
      input: "concat(\"hello\", \" \", \"world\")",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    'builtin-distinct': {
      label: "Builtins \u2014 builtin distinct",
      input: "distinct((1, 2, 2, 3, 1, 4))",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    'builtin-reverse': {
      label: "Builtins \u2014 builtin reverse",
      input: "reverse((1, 2, 3, 4))",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    'builtin-head': {
      label: "Builtins \u2014 builtin head",
      input: "head((10, 20, 30))",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    'builtin-tail': {
      label: "Builtins \u2014 builtin tail",
      input: "tail((10, 20, 30))",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    'builtin-nth': {
      label: "Builtins \u2014 builtin nth",
      input: "nth((10, 20, 30, 40), 3)",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    'matrix-001-retry-retry': {
      label: "Composition matrix \u2014 retry retry",
      input: "[?retry :max 1 :backoff constant :delay 1ms :jitter none :body [?retry :max 1 :backoff constant :delay 1ms :jitter none :body [?test-always-err]]]",
      note:  "Resilience composition \u2014 outer wraps inner. Failures bubble up the stack until handled; the matrix tests every meaningful pair.",
    },
    'matrix-002-retry-timeout': {
      label: "Composition matrix \u2014 retry timeout",
      input: "[?retry :max 1 :backoff constant :delay 1ms :jitter none :body [?timeout 10ms :body [?let $_ = [?sleep 100ms :mock] :in [ok :value \"x\"]]]]",
      note:  "Resilience composition \u2014 outer wraps inner. Failures bubble up the stack until handled; the matrix tests every meaningful pair.",
    },
    'matrix-003-retry-cb': {
      label: "Composition matrix \u2014 retry cb",
      input: "[?retry :max 1 :backoff constant :delay 1ms :jitter none :body [?test-cb-open]]",
      note:  "Resilience composition \u2014 outer wraps inner. Failures bubble up the stack until handled; the matrix tests every meaningful pair.",
    },
    'matrix-004-retry-fallback': {
      label: "Composition matrix \u2014 retry fallback",
      input: "[?retry :max 1 :backoff constant :delay 1ms :jitter none :body [?fallback :body [err :code \"p\"] :recover-with [err :code \"s\"]]]",
      note:  "Resilience composition \u2014 outer wraps inner. Failures bubble up the stack until handled; the matrix tests every meaningful pair.",
    },
    'compose-001-retry-over-timeout': {
      label: "Composition \u2014 retry over timeout",
      input: "[?retry :max 3 :backoff constant :delay 10ms :jitter none\n   :body [?timeout 100ms\n            :body [?let $_ = [?sleep 500ms :mock] :in [ok :value \"never\"]]]]",
      note:  "Layered composition of integration directives. Read top-down: outer directive wraps inner.",
    },
    'pipe-001-canonical-form': {
      label: "Pipe \u2014 canonical form",
      input: "[?pipe (1, 2, 3, 4) :through [?fn $xs [?for $x :in $xs :where [> $x 2] :yield $x]]\n                    :through count]",
      note:  "Pipeline \u2014 values flow left to right through each stage. Canonical `[?pipe IN :through F :through G]` \u2261 infix `IN | F | G`.",
    },
    'pipe-002-infix-sugar': {
      label: "Pipe \u2014 infix sugar",
      input: "(1, 2, 3, 4) | [?fn $xs [?for $x :in $xs :where [> $x 2] :yield $x]] | count",
      note:  "Pipeline \u2014 values flow left to right through each stage. Canonical `[?pipe IN :through F :through G]` \u2261 infix `IN | F | G`.",
    },
    'retry-001-happy-path': {
      label: "Retry \u2014 happy path",
      input: "[?retry :max 3 :body [ok :value 42]]",
      note:  "`[?retry]` re-evaluates `:body` until success or `:max` attempts. Backoff / jitter configurable per \u00a710.2.1.",
    },
    'retry-002-success-on-third-attempt': {
      label: "Retry \u2014 success on third attempt",
      input: "[?retry :max 5\n        :body [?test-err-then-ok :err-count 2 :ok-value [ok :value \"done\"]]]",
      note:  "`[?retry]` re-evaluates `:body` until success or `:max` attempts. Backoff / jitter configurable per \u00a710.2.1.",
    },
    'retry-003-exhaustion': {
      label: "Retry \u2014 exhaustion",
      input: "[?retry :max 3 :body [?test-always-err]]",
      note:  "`[?retry]` re-evaluates `:body` until success or `:max` attempts. Backoff / jitter configurable per \u00a710.2.1.",
    },
    'retry-004-on-predicate-bails': {
      label: "Retry \u2014 on predicate bails",
      input: "[?retry :max 5\n        :on [?fn $e [?if [= $e@code \"permanent\"] :then false :else true]]\n        :body [err :code \"permanent\" :message \"give up\"]]",
      note:  "`[?retry]` re-evaluates `:body` until success or `:max` attempts. Backoff / jitter configurable per \u00a710.2.1.",
    },
    'retry-005-constant-backoff': {
      label: "Retry \u2014 constant backoff",
      input: "[?retry :max 3 :backoff constant :delay 100ms :jitter none\n        :body [?test-always-err]]",
      note:  "`[?retry]` re-evaluates `:body` until success or `:max` attempts. Backoff / jitter configurable per \u00a710.2.1.",
    },
    'timeout-001-completes-within': {
      label: "Timeout \u2014 completes within",
      input: "[?timeout 1s :body [ok :value \"fast\"]]",
      note:  "`[?timeout DUR :body \u2026]` bounds wall-clock for `:body`. Exceeded \u2192 `[err :code \"cx-err:CXER0141\"]`.",
    },
    'timeout-002-deadline-exceeded': {
      label: "Timeout \u2014 deadline exceeded",
      input: "[?timeout 100ms :body [?let $_ = [?sleep 500ms :mock] :in [ok :value \"never\"]]]",
      note:  "`[?timeout DUR :body \u2026]` bounds wall-clock for `:body`. Exceeded \u2192 `[err :code \"cx-err:CXER0141\"]`.",
    },
    'timeout-003-on-timeout-recovery': {
      label: "Timeout \u2014 on timeout recovery",
      input: "[?timeout 100ms\n   :body [?let $_ = [?sleep 500ms :mock] :in [ok :value \"never\"]]\n   :on-timeout [ok :value \"fallback\"]]",
      note:  "`[?timeout DUR :body \u2026]` bounds wall-clock for `:body`. Exceeded \u2192 `[err :code \"cx-err:CXER0141\"]`.",
    },
    'cb-001-closed-passthrough': {
      label: "Circuit breaker \u2014 closed passthrough",
      input: "[?circuit-breaker :threshold 0.5 :window 60s :reset 30s :min-samples 10\n   :body [ok :value 7]]",
      note:  "`[?circuit-breaker]` opens after `:threshold` failure ratio over `:window`; rejects with CXER0150 until `:reset` elapses.",
    },
    'cb-002-trips-open': {
      label: "Circuit breaker \u2014 trips open",
      input: "[?for $i :in (1, 2, 3, 4, 5)\n      :yield [?circuit-breaker :threshold 0.5 :window 60s :reset 30s\n                               :min-samples 2 :name \"cb-002\"\n              :body [?test-always-err]]]",
      note:  "`[?circuit-breaker]` opens after `:threshold` failure ratio over `:window`; rejects with CXER0150 until `:reset` elapses.",
    },
    'cb-003-half-open-after-reset': {
      label: "Circuit breaker \u2014 half open after reset",
      input: "[?let $a = [?circuit-breaker :threshold 0.0 :window 60s :reset 30s\n                             :min-samples 1 :name \"cb-003\"\n            :body [?test-err-then-ok :err-count 1 :ok-value [ok :value \"probe-ok\"]]]\n :in [?let $_ = [?test-clock :advance 31s]\n      :in [?let $b = [?circuit-breaker :threshold 0.0 :window 60s :reset 30s\n                                       :min-samples 1 :name \"cb-003\"\n                       :body [?test-err-then-ok :err-count 1 :ok-value [ok :value \"probe-ok\"]]]\n           :in ([a $a], [b $b])]]]",
      note:  "`[?circuit-breaker]` opens after `:threshold` failure ratio over `:window`; rejects with CXER0150 until `:reset` elapses.",
    },
    'cb-005-below-min-samples-no-trip': {
      label: "Circuit breaker \u2014 below min samples no trip",
      input: "[?for $i :in (1, 2)\n      :yield [?circuit-breaker :threshold 0.5 :window 60s :reset 30s\n                               :min-samples 10 :name \"cb-005\"\n              :body [?test-always-err]]]",
      note:  "`[?circuit-breaker]` opens after `:threshold` failure ratio over `:window`; rejects with CXER0150 until `:reset` elapses.",
    },
    'ratelimit-001-under-limit': {
      label: "Rate limit \u2014 under limit",
      input: "[?for $i :in (1, 2, 3)\n      :yield [?rate-limit :max 5 :per 1s :name \"rl-001\"\n              :body [ok :value $i]]]",
      note:  "`[?rate-limit :max N :per DUR]` admits up to N invocations per window; saturated \u2192 CXER0151.",
    },
    'ratelimit-002-over-limit': {
      label: "Rate limit \u2014 over limit",
      input: "[?for $i :in (1, 2, 3, 4)\n      :yield [?rate-limit :max 2 :per 1s :name \"rl-002\"\n              :body [ok :value $i]]]",
      note:  "`[?rate-limit :max N :per DUR]` admits up to N invocations per window; saturated \u2192 CXER0151.",
    },
    'ratelimit-003-replenish-after-window': {
      label: "Rate limit \u2014 replenish after window",
      input: "[?let $a = [?rate-limit :max 1 :per 1s :name \"rl-003\" :body [ok :value \"a\"]]\n :in [?let $b = [?rate-limit :max 1 :per 1s :name \"rl-003\" :body [ok :value \"b\"]]\n      :in [?let $_ = [?test-clock :advance 1100ms]\n           :in [?let $c = [?rate-limit :max 1 :per 1s :name \"rl-003\" :body [ok :value \"c\"]]\n                :in ([a $a], [b $b], [c $c])]]]]",
      note:  "`[?rate-limit :max N :per DUR]` admits up to N invocations per window; saturated \u2192 CXER0151.",
    },
    'bulkhead-001-under-cap': {
      label: "Bulkhead \u2014 under cap",
      input: "[?bulkhead :max-concurrent 4 :queue 0 :body [ok :value \"ran\"]]",
      note:  "`[?bulkhead :max-concurrent N]` caps concurrent `:body` invocations. Saturated \u2192 CXER0152, or queues per `:queue N`.",
    },
    'bulkhead-002-saturated-no-queue': {
      label: "Bulkhead \u2014 saturated no queue",
      input: "[?test-concurrent :tasks (\n   [?bulkhead :max-concurrent 1 :queue 0 :name \"bh-002\"\n              :body [?let $_ = [?sleep 500ms :mock] :in [ok :value \"first\"]]],\n   [?bulkhead :max-concurrent 1 :queue 0 :name \"bh-002\"\n              :body [ok :value \"second\"]])]",
      note:  "`[?bulkhead :max-concurrent N]` caps concurrent `:body` invocations. Saturated \u2192 CXER0152, or queues per `:queue N`.",
    },
    'bulkhead-003-queue-fifo': {
      label: "Bulkhead \u2014 queue fifo",
      input: "[?test-concurrent :tasks (\n   [?bulkhead :max-concurrent 1 :queue 2 :name \"bh-003\"\n              :body [?let $_ = [?sleep 100ms :mock] :in [ok :value \"a\"]]],\n   [?bulkhead :max-concurrent 1 :queue 2 :name \"bh-003\"\n              :body [ok :value \"b\"]],\n   [?bulkhead :max-concurrent 1 :queue 2 :name \"bh-003\"\n              :body [ok :value \"c\"]])]",
      note:  "`[?bulkhead :max-concurrent N]` caps concurrent `:body` invocations. Saturated \u2192 CXER0152, or queues per `:queue N`.",
    },
    'fallback-001-primary-success': {
      label: "Fallback \u2014 primary success",
      input: "[?fallback :body [ok :value \"primary\"] :recover-with [ok :value \"secondary\"]]",
      note:  "`[?fallback :body \u2026 :on-err \u2026]` runs `:body`; on err runs `:on-err` with `$err` bound.",
    },
    'fallback-002-primary-err-secondary-ok': {
      label: "Fallback \u2014 primary err secondary ok",
      input: "[?fallback :body [err :code \"down\"] :recover-with [ok :value \"secondary\"]]",
      note:  "`[?fallback :body \u2026 :on-err \u2026]` runs `:body`; on err runs `:on-err` with `$err` bound.",
    },
    'fallback-003-both-err-no-wrap': {
      label: "Fallback \u2014 both err no wrap",
      input: "[?fallback :body [err :code \"down-primary\"] :recover-with [err :code \"down-secondary\"]]",
      note:  "`[?fallback :body \u2026 :on-err \u2026]` runs `:body`; on err runs `:on-err` with `$err` bound.",
    },
    'sleep-001-mock-explicit': {
      label: "Sleep \u2014 mock explicit",
      input: "[?let $_ = [?sleep 500ms :mock] :in [ok :value \"instant\"]]",
      note:  "`[?sleep DUR]` blocks wall-clock by default; `:mock` advances a logical clock instantly without waiting (ADR 0039).",
    },
    'sleep-002-mock-flag-advances-now-ns': {
      label: "Sleep \u2014 mock flag advances now ns",
      input: "[?timeout 100ms :body [?let $_ = [?sleep 500ms :mock] :in [ok :value \"never\"]]]",
      note:  "`[?sleep DUR]` blocks wall-clock by default; `:mock` advances a logical clock instantly without waiting (ADR 0039).",
    },
    'sleep-003-mock-cancellation-immediate': {
      label: "Sleep \u2014 mock cancellation immediate",
      input: "[?let $f = [?async [?sleep 60s :mock]]\n :in [?let $_ = [?cancel $f] :in [?await $f]]]",
      note:  "`[?sleep DUR]` blocks wall-clock by default; `:mock` advances a logical clock instantly without waiting (ADR 0039).",
    },
    'sleep-004-grammar-mock-flag-parses': {
      label: "Sleep \u2014 grammar mock flag parses",
      input: "[?sleep 1ms :mock]",
      note:  "`[?sleep DUR]` blocks wall-clock by default; `:mock` advances a logical clock instantly without waiting (ADR 0039).",
    },
    'conc-001-channel-send-receive-buffered': {
      label: "Channels \u2014 channel send receive buffered",
      input: "[?let $ch = [?channel :name \"c1\" :buffer 1]\n :in [?let $_ = [?send \"hello\" :to $ch]\n      :in [?receive :from $ch]]]",
      note:  "`[?channel :name S :buffer N]` is a typed queue. `[?send]` enqueues, `[?receive]` dequeues, `[?close]` signals end-of-stream.",
    },
    'conc-002-channel-synchronous-rendezvous': {
      label: "Channels \u2014 channel synchronous rendezvous",
      input: "[?let $ch = [?channel :name \"c2\" :buffer 0]\n :in [?test-concurrent :tasks (\n        [?send \"sync\" :to $ch],\n        [?receive :from $ch])]]",
      note:  "`[?channel :name S :buffer N]` is a typed queue. `[?send]` enqueues, `[?receive]` dequeues, `[?close]` signals end-of-stream.",
    },
    'conc-003-send-to-closed': {
      label: "Channels \u2014 send to closed",
      input: "[?let $ch = [?channel :name \"c3\" :buffer 1]\n :in [?let $_ = [?close $ch]\n      :in [?send \"late\" :to $ch]]]",
      note:  "`[?channel :name S :buffer N]` is a typed queue. `[?send]` enqueues, `[?receive]` dequeues, `[?close]` signals end-of-stream.",
    },
    'conc-004-receive-drained-closed': {
      label: "Channels \u2014 receive drained closed",
      input: "[?let $ch = [?channel :name \"c4\" :buffer 2]\n :in [?let $_ = [?send \"a\" :to $ch]\n      :in [?let $_ = [?close $ch]\n           :in [?let $first = [?receive :from $ch]\n                :in [?let $second = [?receive :from $ch]\n                     :in ([first $first], [second $second])]]]]]",
      note:  "`[?channel :name S :buffer N]` is a typed queue. `[?send]` enqueues, `[?receive]` dequeues, `[?close]` signals end-of-stream.",
    },
    'conc-005-try-send-timeout': {
      label: "Channels \u2014 try send timeout",
      input: "[?let $ch = [?channel :name \"c5\" :buffer 1]\n :in [?let $_ = [?send \"first\" :to $ch]\n      :in [?try-send \"second\" :to $ch :timeout 50ms]]]",
      note:  "`[?channel :name S :buffer N]` is a typed queue. `[?send]` enqueues, `[?receive]` dequeues, `[?close]` signals end-of-stream.",
    },
    'conc-006-try-receive-timeout': {
      label: "Channels \u2014 try receive timeout",
      input: "[?let $ch = [?channel :name \"c6\" :buffer 1]\n :in [?try-receive :from $ch :timeout 50ms]]",
      note:  "`[?channel :name S :buffer N]` is a typed queue. `[?send]` enqueues, `[?receive]` dequeues, `[?close]` signals end-of-stream.",
    },
    'conc-009-worker-happy-path': {
      label: "Workers \u2014 worker happy path",
      input: "[?let $w = [?worker :name \"w1\" :body [ok :value 42]]\n :in [?wait-for :worker $w]]",
      note:  "`[?worker]` registers a long-running task with `:body` evaluated under the cooperative `[?test-concurrent]` scheduler.",
    },
    'conc-010-worker-handle-lookup-miss': {
      label: "Workers \u2014 worker handle lookup miss",
      input: "[?worker-handle :name \"does-not-exist\"]",
      note:  "`[?worker]` registers a long-running task with `:body` evaluated under the cooperative `[?test-concurrent]` scheduler.",
    },
    'conc-011-worker-panic': {
      label: "Workers \u2014 worker panic",
      input: "[?let $w = [?worker :name \"w2\" :body [err :code \"kaboom\"]]\n :in [?wait-for :worker $w]]",
      note:  "`[?worker]` registers a long-running task with `:body` evaluated under the cooperative `[?test-concurrent]` scheduler.",
    },
    'conc-013-worker-handle-lookup-hit': {
      label: "Workers \u2014 worker handle lookup hit",
      input: "[?let $_ = [?worker :name \"w4\" :body [ok :value \"lookupable\"]]\n :in [?let $h = [?worker-handle :name \"w4\"]\n      :in [?wait-for :worker $h]]]",
      note:  "`[?worker]` registers a long-running task with `:body` evaluated under the cooperative `[?test-concurrent]` scheduler.",
    },
    'conc-014-select-first-channel': {
      label: "Select \u2014 select first channel",
      input: "[?let $a = [?channel :name \"sa\" :buffer 1]\n :in [?let $b = [?channel :name \"sb\" :buffer 1]\n      :in [?let $_ = [?send \"from-a\" :to $a]\n           :in [?select\n                 :case [:from $a $msg [picked :ch \"a\" :value $msg]]\n                 :case [:from $b $msg [picked :ch \"b\" :value $msg]]]]]]",
      note:  "`[?select :on ((:receive-from $ch1 :yield \u2026), \u2026)]` waits on multiple channel reads; the first ready wins.",
    },
    'conc-015-select-timeout-case': {
      label: "Select \u2014 select timeout case",
      input: "[?let $a = [?channel :name \"sc\" :buffer 1]\n :in [?select\n        :case [:from $a $msg [picked :ch \"a\" :value $msg]]\n        :case [:timeout 50ms [timeout-fired]]]]",
      note:  "`[?select :on ((:receive-from $ch1 :yield \u2026), \u2026)]` waits on multiple channel reads; the first ready wins.",
    },
    'async-001-await-done': {
      label: "Async \u2014 await done",
      input: "[?let $f = [?async [ok :value 42]]\n :in [?await $f]]",
      note:  "`[?async EXPR]` returns a future handle; `[?await $f]` resolves it. Futures are lazy \u2014 body runs on first await.",
    },
    'async-002-await-failed-propagates': {
      label: "Async \u2014 await failed propagates",
      input: "[?let $f = [?async [err :code \"user-fault\" :message \"x\"]]\n :in [?await $f]]",
      note:  "`[?async EXPR]` returns a future handle; `[?await $f]` resolves it. Futures are lazy \u2014 body runs on first await.",
    },
    'async-003-await-timeout': {
      label: "Async \u2014 await timeout",
      input: "[?let $f = [?async [?let $_ = [?sleep 10s :mock] :in [ok :value \"never\"]]]\n :in [?await $f :timeout 50ms]]",
      note:  "`[?async EXPR]` returns a future handle; `[?await $f]` resolves it. Futures are lazy \u2014 body runs on first await.",
    },
    'async-004-await-cancelled': {
      label: "Async \u2014 await cancelled",
      input: "[?let $f = [?async [?let $_ = [?sleep 10s :mock] :in [ok :value \"never\"]]]\n :in [?let $_ = [?cancel $f]\n      :in [?await $f]]]",
      note:  "`[?async EXPR]` returns a future handle; `[?await $f]` resolves it. Futures are lazy \u2014 body runs on first await.",
    },
    'async-015-compose-with-timeout': {
      label: "Async \u2014 compose with timeout",
      input: "[?let $f = [?async [?timeout 50ms :body [?let $_ = [?sleep 10s :mock] :in [ok :value \"never\"]]]]\n :in [?await $f]]",
      note:  "`[?async EXPR]` returns a future handle; `[?await $f]` resolves it. Futures are lazy \u2014 body runs on first await.",
    },
    'async-005-await-all-success': {
      label: "await-all \u2014 await all success",
      input: "[?let $a = [?async [ok :value 1]]\n :in [?let $b = [?async [ok :value 2]]\n      :in [?let $c = [?async [ok :value 3]]\n           :in [?await-all ($a, $b, $c)]]]]",
      note:  "`[?await-all ($f1, $f2, \u2026)]` waits on every future; returns the sequence of results (or an aggregated CXER0240 err).",
    },
    'async-006-await-all-one-failed': {
      label: "await-all \u2014 await all one failed",
      input: "[?let $a = [?async [ok :value 1]]\n :in [?let $b = [?async [err :code \"down\"]]\n      :in [?let $c = [?async [ok :value 3]]\n           :in [?await-all ($a, $b, $c)]]]]",
      note:  "`[?await-all ($f1, $f2, \u2026)]` waits on every future; returns the sequence of results (or an aggregated CXER0240 err).",
    },
    'async-007-await-all-cancelled-counts': {
      label: "await-all \u2014 await all cancelled counts",
      input: "[?let $a = [?async [ok :value 1]]\n :in [?let $b = [?async [?let $_ = [?sleep 10s :mock] :in [ok :value \"never\"]]]\n      :in [?let $_ = [?cancel $b]\n           :in [?await-all ($a, $b)]]]]",
      note:  "`[?await-all ($f1, $f2, \u2026)]` waits on every future; returns the sequence of results (or an aggregated CXER0240 err).",
    },
    'async-008-await-any-first-success': {
      label: "await-any \u2014 await any first success",
      input: "[?let $fast = [?async [ok :value \"fast\"]]\n :in [?let $slow = [?async [?let $_ = [?sleep 10s :mock] :in [ok :value \"slow\"]]]\n      :in [?await-any ($fast, $slow)]]]",
      note:  "`[?await-any (\u2026)]` returns the first successful future; ignores subsequent failures.",
    },
    'async-009-await-any-skips-failed': {
      label: "await-any \u2014 await any skips failed",
      input: "[?let $bad = [?async [err :code \"bad\"]]\n :in [?let $good = [?async [ok :value \"good\"]]\n      :in [?await-any ($bad, $good)]]]",
      note:  "`[?await-any (\u2026)]` returns the first successful future; ignores subsequent failures.",
    },
    'async-010-await-race-first-terminal': {
      label: "await-race \u2014 await race first terminal",
      input: "[?let $err = [?async [err :code \"first-err\"]]\n :in [?let $ok = [?async [?let $_ = [?sleep 10s :mock] :in [ok :value \"slow\"]]]\n      :in [?await-race ($err, $ok)]]]",
      note:  "`[?await-race (\u2026)]` returns the first future to resolve (success or fail), then cancels the losers.",
    },
    'async-011-await-race-cancels-losers': {
      label: "await-race \u2014 await race cancels losers",
      input: "[?let $fast = [?async [ok :value \"fast\"]]\n :in [?let $slow = [?async [?let $_ = [?sleep 10s :mock] :in [ok :value \"slow\"]]]\n      :in [?let $winner = [?await-race ($fast, $slow)]\n           :in [?let $slow-state = [?await $slow]\n                :in [pair :winner $winner :slow-state $slow-state]]]]]",
      note:  "`[?await-race (\u2026)]` returns the first future to resolve (success or fail), then cancels the losers.",
    },
    'async-012-cancel-honored-at-sleep': {
      label: "Cancel \u2014 cancel honored at sleep",
      input: "[?let $f = [?async [?sleep 10s :mock]]\n :in [?let $_ = [?cancel $f]\n      :in [?await $f]]]",
      note:  "`[?cancel $handle]` requests cancellation. Sleep / check-cancel observe via `current_future_id` and raise CXER0260.",
    },
    'map-001-par-ordered-source-order': {
      label: "Map \u2014 par ordered source order",
      input: "[?map (1, 2, 3, 4) :using [?fn $x [* $x 10]] :par :ordered]",
      note:  "`[?map xs :using fn]` applies `fn` to each element. `:par` parallelizes; `:ordered` preserves source order (ADR 0040).",
    },
    'map-002-sequential': {
      label: "Map \u2014 sequential",
      input: "[?map (1, 2, 3, 4) :using [?fn $x [* $x 10]]]",
      note:  "`[?map xs :using fn]` applies `fn` to each element. `:par` parallelizes; `:ordered` preserves source order (ADR 0040).",
    },
    'sleep-008-map-par-with-mock-sleep': {
      label: "Map \u2014 map par with mock sleep",
      input: "[?map (1, 2, 3, 4)\n  :using [?fn $n [?let $_ = [?sleep 10ms :mock] :in [* $n $n]]]\n  :par :ordered]",
      note:  "`[?map xs :using fn]` applies `fn` to each element. `:par` parallelizes; `:ordered` preserves source order (ADR 0040).",
    },
    'reduce-001-par-associative': {
      label: "Reduce \u2014 par associative",
      input: "[?reduce (1, 2, 3, 4, 5, 6, 7, 8) :using [?fn ($a, $b) [+ $a $b]] :init 0 :par]",
      note:  "`[?reduce xs :using fn :init z]` folds the sequence to one value. `:par` enables associative tree-reduce (`fn` must be associative, `z` the identity).",
    },
    'reduce-002-sequential-left-fold': {
      label: "Reduce \u2014 sequential left fold",
      input: "[?reduce (1, 2, 3, 4) :using [?fn ($a, $b) [- $a $b]] :init 10]",
      note:  "`[?reduce xs :using fn :init z]` folds the sequence to one value. `:par` enables associative tree-reduce (`fn` must be associative, `z` the identity).",
    },
    'svc-001-get-happy-path': {
      label: "Services \u2014 get happy path",
      input: "[?test-service-client\n   :service [?service :on http :port 0 :name \"svc-001\"\n              [resource :get \"/hello\"\n                 :body [response :status 200 :body \"world\"]]]\n   :client-call [?let $c = [?http-client :target $test-target]\n                 :in $c | get(\"/hello\")]]",
      note:  "`[?service]` defines an HTTP service shape; `[?test-service-client]` orchestrates spawn + client call + stop in one fixture.",
    },
    'svc-002-post-happy-path': {
      label: "Services \u2014 post happy path",
      input: "[?test-service-client\n   :service [?service :on http :port 0 :name \"svc-002\"\n              [resource :post \"/echo\"\n                 :body [response :status 200 :body $request/body]]]\n   :client-call [?let $c = [?http-client :target $test-target]\n                 :in $c | post(\"/echo\", [payload :value 42])]]",
      note:  "`[?service]` defines an HTTP service shape; `[?test-service-client]` orchestrates spawn + client call + stop in one fixture.",
    },
    'svc-003-put-happy-path': {
      label: "Services \u2014 put happy path",
      input: "[?test-service-client\n   :service [?service :on http :port 0 :name \"svc-003\"\n              [resource :put \"/items/:id\"\n                 :body [response :status 200\n                        :body [stored :id $request/path-params/id\n                                      :value $request/body]]]]\n   :client-call [?let $c = [?http-client :target $test-target]\n                 :in $c | put(\"/items/7\", [item :name \"widget\"])]]",
      note:  "`[?service]` defines an HTTP service shape; `[?test-service-client]` orchestrates spawn + client call + stop in one fixture.",
    },
    'svc-004-delete-happy-path': {
      label: "Services \u2014 delete happy path",
      input: "[?test-service-client\n   :service [?service :on http :port 0 :name \"svc-004\"\n              [resource :delete \"/items/:id\"\n                 :body [response :status 200\n                        :body [deleted :id $request/path-params/id]]]]\n   :client-call [?let $c = [?http-client :target $test-target]\n                 :in $c | delete(\"/items/9\")]]",
      note:  "`[?service]` defines an HTTP service shape; `[?test-service-client]` orchestrates spawn + client call + stop in one fixture.",
    },
    'svc-015-client-connection-refused': {
      label: "HTTP clients \u2014 client connection refused",
      input: "[?let $c = [?http-client :target \"http://localhost:1\"]\n :in $c | get(\"/\")]",
      note:  "`[?http-client]` issues a request against a `:target`. Integrates with `[?retry]` / `[?timeout]` / `[?circuit-breaker]`.",
    },
    'svc-016-client-tls-handshake-failed': {
      label: "HTTP clients \u2014 client tls handshake failed",
      input: "[?test-service-client\n   :service [?service :on http :port 0 :name \"svc-016\"\n              [resource :get \"/\" :body [response :status 200 :body \"plaintext\"]]]\n   :client-call [?let $c = [?http-client :target $test-target :tls [?test-tls-config]]\n                 :in $c | get(\"/\")]]",
      note:  "`[?http-client]` issues a request against a `:target`. Integrates with `[?retry]` / `[?timeout]` / `[?circuit-breaker]`.",
    },
    'svc-017-client-invalid-response': {
      label: "HTTP clients \u2014 client invalid response",
      input: "[?test-service-client\n   :service [?service :on http :port 0 :name \"svc-017\"\n              [resource :get \"/garbled\"\n                 :body [response :status 200\n                        :headers [[header :name \"Content-Type\" :value \"application/cx\"]]\n                        :body [opts :raw-bytes \"}}}not-cx{{{\"]]]]\n   :client-call [?let $c = [?http-client :target $test-target]\n                 :in $c | get(\"/garbled\")]]",
      note:  "`[?http-client]` issues a request against a `:target`. Integrates with `[?retry]` / `[?timeout]` / `[?circuit-breaker]`.",
    },
  };

  window.cxPlaygroundExamples = { data, program };
})();
