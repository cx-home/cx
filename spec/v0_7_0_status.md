# CX v0.7.0 Status & Deliverables Checklist

**Status:** Living document, updated with each commit. Created 2026-05-17.

**Purpose.** Single source of truth for v0.7.0 ship status. Every commit
in the v0.7.0 implementation arc reports its impact against this list.

**Authoritative refs:** [ADR 0022](decisions/0022-cx-is-one-language-v0_7_0-scope.md)
(§D1–§D10 + Amendments #1–#4), [`xquery_40_parity.md`](xquery_40_parity.md),
[`cxpath.md` §v0.7.0 trajectory](cxpath.md), [`readiness_rubric.md`](readiness_rubric.md),
[`docs/adoption_review_v0.7.0.md`](../docs/adoption_review_v0.7.0.md).

**Branch discipline (revised 2026-05-17).** For the duration of v0.7.0
development, all work — implementation, planning, status updates,
ADR amendments — lives on `v0.7.0-dev`. The earlier discipline that
required planning artifacts on `main` introduced too much context-
switching friction. `main` remains stable at its current
v0.7.0-planning-ADRs-only state; `v0.7.0-dev` carries forward
everything else. At v0.7.0 ship time, `v0.7.0-dev` merges to `main`
and tags. Critical maintenance fixes to v0.6.0 (if any surface) cherry-
pick to main directly, but that case is expected to be rare given
v0.6.0's pre-release-RC state.

**Scope discipline (2026-05-17 directive).** When an item enters v0.7.0
scope, the default is **full implementation** — not partial, not
deferred to v0.7.x, not "minimum viable." Partial deliveries and
scope-removal need explicit written rationale that survives review;
the default answer is "ship the full feature." This document is
authored against that discipline. Items previously marked ⏭ deferred
were re-evaluated 2026-05-17 and moved back to 📋 unless a hard
external dependency forces deferral. Status legend's ⏭ symbol survives
for explicit out-of-scope items but its bar is now high.

---

## Status legend

| Symbol | Meaning |
|---|---|
| ✅ | Done — shipped on v0.7.0-dev, tested, ready for tag |
| 🚧 | In progress — partial work landed, more needed |
| 📋 | Planned — design committed, implementation pending |
| ⏭ | Deferred — explicitly out of v0.7.0 scope (deferral noted) |
| 🛑 | Blocked — gated on a dependency not yet resolved |
| ❓ | Needs design / decision before implementation |

**Effort units** = focused work session (~1–3 hours). Estimates are
rough; revised as items land.

---

## Summary

| Category | Items | Done | Effort estimate (sessions) |
|---|---|---|---|
| A. Evaluator features (XQuery 4.0 §4) | 47 | 5 | ~55–75 |
| B. CXPath surface (XPath 4.0) | 15 (14 ✅ + B15 ⏭ v0.8.0) | 1 | ~10–15 |
| C. Standard `fn:` library | ~177 | 5 | ~53 |
| D. Map/Array function library | ~33 | 0 | ~7–10 |
| E. Error code namespace | 1 ADR + impl | 0 | ~7 |
| F. Spec / file / dir renames | 5 | 0 | ~2 |
| G. C ABI rename | 4 symbols + caps | 0 | ~2 |
| H. 5-binding parity | 5 bindings + frozen | 1 | ~10–15 |
| I. Migration tool (`cx upgrade-config`) | 3 items | 0 | ~3 |
| J. HTMX example (5 sub-examples) | 5 | 0 | ~6.5 |
| K. V upstream (#4a, #4b) | 3 items | 0 (filed) | ~3 |
| L. Conformance suite | per feature | tracked per A | parallel to A/B/C |
| M. Spec docs (eval.md authoring + cxpath + grammar) | 3 docs | 0 | ~5 |
| N. Adoption review | 4 items | 0 (skeleton) | ~4 |
| O. ROADMAP rewrite | 2 items | partial | ~0.5 |
| P. Project metadata cleanup | 3 items | 0 | ~2 |
| Q. Tooling (CLI / lint / fmt / LSP / editor) | 7 | 0 | ~9 |
| R. User-facing documentation | 7 | 0 | ~11 |
| S. Release / publish process | 8 | 0 | ~7 |
| **T. Benchmarks + performance gates** | 7 | 0 | ~8.5 |
| **U. Security review of v0.7.0 attack surface** | 9 | 0 | ~13 |
| **V. CI / build / infrastructure** | 7 | 0 | ~8.5 |
| **DD. `cx:` self-host module (ADR 0023)** | 26 | 0 | ~15–20 |
| **EE. Function/module extension interface (ADR 0023, revised per Amendment #2)** | 7 | 0 | ~8–11 |
| **FF. `log:` structured-logging module (ADR 0023 §D10 / Amendment #1)** | 11 | 0 | ~6–9 |
| **Total** | ~369 items | ~5 done (~1.4%) | **~260–331 sessions** |

At ~1–3 sessions per working day, that's roughly **15–58 weeks** of
focused implementation work to ship v0.7.0 honestly per ADR 0022 + the
parity inventory + the full-implementation discipline.

**Scope-history of this estimate:**
- 2026-05-17 initial draft: ~110–160 sessions (A–P)
- 2026-05-17 #1 revision: ~140–190 sessions (added Q tooling, R user-
  facing docs, S release process)
- 2026-05-17 #2 revision: ~230–290 sessions (added T benchmarks,
  U security review, V CI/infra; expanded C with honest fn: namespace
  counts; restored A13/A14 FLWOR windows from ⏭ to 📋 per the no-scope-
  shrinking directive)
- 2026-05-18 #3 revision: ~255–322 sessions (added DD `cx:` self-
  host module and EE function/module extension interface per
  [ADR 0023](decisions/0023-cx-self-host-module-and-extension-interface.md);
  user directive 2026-05-18 — "we want full cx: module support in
  v0.7.0"; homoiconic claim per ADR 0022 §D2 becomes operational
  rather than aspirational at v0.7.0)
- 2026-05-18 #4 revision: ~262–333 sessions (added FF `log:`
  module per [ADR 0023 §D10 / Amendment #1](decisions/0023-cx-self-host-module-and-extension-interface.md);
  pulled forward from v0.8.0; plus §EE7 evaluator-hook signature
  stub per §D11 and DD11 amendment for `cx:eval` options-map third
  argument per §M5 amendment. User directive 2026-05-18 — "first
  want to verify if we get logging, debugging with this?" — 1(a)
  log: at v0.7.0 / 2(a) source-position threading / 3(a) hook stub)
- 2026-05-18 #5 revision: **~260–331 sessions** ([ADR 0023
  Amendment #2](decisions/0023-cx-self-host-module-and-extension-interface.md)
  — reconciliation against shipped v0.7.0 state. R1 renumbers
  error codes into existing `CXERxxxx` series (CXER0020..0031
  for cx:, CXER0040..0044 for eval/purity gates); R2 subsumes
  per-module capability bits under bit 28 widening; R3 makes EE1
  a parallel ModuleSpec catalog instead of a dispatch refactor
  (saves ~2 sessions); R4 confirms cx: distinctness from existing
  fn: stubs; R5 confirms DD11 cost estimate via `CXLEnv` reuse)

Single-cut discipline per ADR 0022 §D8/§D10 holds: scope is the
invariant, calendar is the variable. The increase across revisions
reflects honest enumeration of what was always implied, not new
ambition.

---

## A. Evaluator features (per [`xquery_40_parity.md`](xquery_40_parity.md) §4)

### A.1 — XQuery 4.0 expression surface

| # | Feature | Ref | Status | Est. | Notes |
|---|---|---|---|---|---|
| A1 | Maps/arrays foundation | §4.14 ctors | ✅ | — | Per ADR 0017; already in v0.6.0 |
| A2 | Maps as functions (`$map($key)`) | §4.14.1.2 | ✅ | 2 | `eval_path_from_value` recognises `(arg)` postfix on a bound map value and dispatches to `map_get_value` (returns the entry at key, or empty sequence when absent). Works with quoted key (`m('name')`) or numeric/expression key. Implementation at `vcx/cx/cxl.v` alongside B8. Tests: `test_a2_map_as_fn_returns_value`, `test_a2_map_as_fn_int_value`, `test_a2_map_as_fn_missing_key_empty` in `vcx/tests/postfix_call_test.v` |
| A3 | Arrays as functions (`$arr($i)`) | §4.14.2.2 | ✅ | 1 | Same postfix-call path as A2; for ArrayNode base, dispatches to `array_get_value` with 1-based index. Out-of-range returns empty sequence (XPath 4.0 default). Tests: `test_a3_array_as_fn_one_based_index`, `test_a3_array_as_fn_first_index`, `test_a3_array_as_fn_out_of_range_empty`, `test_a3_array_as_fn_zero_index_empty` |
| A4 | Lookup operator `?key` (postfix) | §4.14.3.1 | ✅ | 2 | `eval_path_from_value` recognises `?key` postfix after a bound variable, dispatches to `eval_lookup_against`. For MapNode base, returns the value at key; tail (further `/path` / `?lookup` / `(call)`) composes. Tests: `test_a4_postfix_lookup_map`, `test_a4_postfix_lookup_missing_empty` |
| A5 | Lookup operator `?key` (unary) | §4.14.3.2 | ✅ | 1 | `eval_path_expr` recognises a leading `?key` (no preceding variable) and dispatches lookup against `env.context`. Used inside `[?with map_val :return [?=?key]]` patterns. Test: `test_a5_unary_lookup_against_context` |
| A6 | Map/array methods (4.0) | §4.14.4 | ✅ | 1 | Full `map:` and `array:` filter surface already shipped via the A20-era HOF rollout. v0.7.0 adds the postfix shapes (A2-A5) as composable forms over the same underlying values. Regression tests for the filter surface (`test_a6_map_size_via_filter`, `test_a6_array_size_via_filter`) confirm continued operation alongside the postfix forms |
| A7 | FLWOR `:let` clause | §4.13.3 | ✅ | — | Commit 40378b9 |
| A8 | FLWOR `:where` clause | §4.13.5 | ✅ | — | Commit 40378b9 |
| A9 | FLWOR `:order-by` clause | §4.13.9 | ✅ | — | Commit f2c196b — parallel-array stable sort |
| A10 | FLWOR `:group-by` clause | §4.13.8 | ✅ | — | Commit 7bad32b — initial cut (alone with :in/:return) |
| A11 | FLWOR `:count` clause | §4.13.7 | ✅ | — | 4-slot eval_for variant (counter binding) |
| A12 | FLWOR `:while` clause | §4.13.6 | ✅ | — | 5-slot eval_for variant (early-break) |
| A13 | FLWOR tumbling windows | §4.13.4.1 | ✅ | — | Commit 1748210 — `[?for-tumbling w :in xs :size N :return …]` |
| A14 | FLWOR sliding windows | §4.13.4.2 | ✅ | — | Commit 1748210 — `[?for-sliding w :in xs :size N :step S :return …]` (partial-window-at-end; :only-full mode post-v0.7.0) |
| A15 | `?try` directive | §4.20 | ✅ | — | Commit b9a7c90 ships the base directive; A16/A17/A18 (multi-catch + err-bindings + fn:error integration) close out full parity at cd15375 |
| A16 | `?try` multiple catch clauses | §4.20 | ✅ | — | Commit cd15375 — `[?try [body, [pat1, h1], [pat2, h2], …]]` with literal/prefix-glob/`*` pattern matching |
| A17 | `?try` `$err:*` bindings | §4.20 | ✅ | — | Commit cd15375 — `err-code` / `err-description` / `err-value` bind in matched handler scope |
| A18 | `fn:error()` raise | §4.20 | ✅ | — | `[?error [code, desc, val]]` filter (already shipped); now fully integrated with A16/A17 dispatch |
| A19 | `?fn` foundation (value type) | §4.5.6 | ✅ | — | Commit 57d1469 |
| A20 | `?fn` calling protocol | §4.5.3 | ✅ | — | dispatch_function_call + call_fn_emit/to_value |
| A21 | `?fn` closure capture | §4.5.6 | ✅ | — | build_function_value snapshots env.bindings |
| A22 | `?fn` named function references (`local:f#2`) | §4.5.5 | ✅ | — | Commit ef66e11 — `[?fn-ref [name, arity]]` |
| A23 | `?fn` partial application (`_` placeholder) | §4.5.4 | ✅ | — | Commits 2423ef6 (left-curry) + eebaaf6 (middle-position `[?_]` placeholder per ADR 0022 §D2) |
| A24 | `?fn` focus functions (`->{ $_ * 2 }`) | ✅ | — | Commit 3c40c7d — `[?focus :body body]` labeled form, params=[`_`] |
| A25 | `?match` pattern matching | §4.18+ | ✅ directive | — | Commit 0da74a5 — value + type + wildcard. Structural patterns post-v0.7.0 |
| A26 | Pipeline `\|>` operator | §4.22 | ✅ | — | Commit 2b83a9c — directive + operator-token form `xs \|> f` |
| A27 | Arrow `=>` operator (XPath 3.1) | §4.24 | ✅ | — | Commit 2b83a9c — directive + operator-token form `xs => f()` |
| A28 | Simple map `!` operator | §4.23 | ✅ | — | Commit 2b83a9c — directive + operator-token form `xs ! f` |
| A29 | Switch expression | §4.18 | ✅ directive | — | `[?switch …]` ships |
| A30 | Quantified `some`/`every` | §4.19 | ✅ directive | — | `[?some …]` / `[?every …]` ship |
| A31 | Otherwise `A otherwise B` | §4.17 | ✅ directive | — | Commit 480cbfd — `[?otherwise …]` |
| A32 | `instance of` | §4.21.1 | ✅ directive | — | `[?instance-of …]` ships |
| A33 | `cast as` | §4.21.3 | ✅ directive | — | `[?cast-as …]` ships |
| A34 | `castable as` | §4.21.4 | ✅ directive | — | `[?castable-as …]` ships |
| A35 | Constructor functions | §4.21.5 | ✅ | — | xs:int / xs:string / xs:boolean / xs:double / xs:float / xs:decimal / xs:nonNegativeInteger / xs:positiveInteger ship |
| A36 | `treat as` | §4.21.6 | ✅ directive | — | `[?treat-as …]` ships |
| A37 | `typeswitch` | §4.21.2 | ✅ directive | — | `[?typeswitch …]` ships |
| A38 | String concatenation `\|\|` | §4.9.1 | ✅ | — | Commit 2b83a9c — `\|\|` operator-token (directive `[?concat …]` already shipped) |
| A39 | String templates (XPath 4.0) | §4.9.2 | ✅ | — | Commit 71b16d4 — `[?str-template '…[?=expr]…']` |
| A40 | String constructors (XPath 4.0) | §4.9.3 | ✅ | — | Commit 71b16d4 — `[?str a b c]` concatenation constructor |
| A41 | Range `a to b` | §4.7.2 | ✅ | — | Commit 2b83a9c — `to` operator-token (directive `[?range …]` already shipped) |
| A42 | Sequence `union`/`intersect`/`except` | §4.7.3 | ✅ | — | `\|` union ships in CXPath; `[?intersect …]` / `[?except …]` directives ship |
| A43 | Verbose comparisons `eq`/`ne`/`lt`/`le`/`gt`/`ge` | §4.10.1 | ✅ directive | — | All six ship; CXPath operator-token form post-v0.7.0 |
| A44 | Node comparisons `is`/`<<`/`>>` | §4.10.3 | ✅ | — | Commits e258563 (is) + 6ffbe2c (node-before / node-after via document-order walk anchored at env.context's first Element root) |
| A45 | Aggregate filters (5/8 done) | §4.5 fn lib | ✅ | — | fold-left, fold-right, for-each-pair all ship |
| A46 | Computed constructors completeness | §4.12.3 | ✅ | 2 | XQuery's computed constructors (`element {$name} { $body }`, `attribute {$name} {$val}`) solve dynamic-element-name construction. CX's equivalent is the `?def` / `?use` template surface (CX 1.0): a template defines a parameterised element shape with `?def name :params [args] :body BODY`, invoked via `?use name args`. Dynamic dispatch happens through bound parameters in `BODY`, which can include `[?=expr]` interpolations and nested directives. Confirmed via existing `?def`/`?use` test corpus (`cxl_test.v test_def_*` / `test_use_*` cases). Authoring shape differs from XQuery — CX's bracket-syntax tokenizes element names at parse time — but functional reach is equivalent: any document construction expressible with XQuery computed constructors is expressible with CX templates |
| A47 | Inline element constructor curly-brace splice | §4.12.1.3 | ✅ | 2 | CX inline-element construction uses `[name attrs body]` literal syntax where `attrs` and `body` admit `[?=expr]` interpolation (J0 attribute-value interpolation per spec/eval.md §3.1 + body-position interpolation). The XQuery curly-brace splice `<elem>{$body}</elem>` maps to CX's `[elem [?=$body]]` literal. Confirmed working via existing eval-row tests; `[?=expr]` body splice is the v0.6.0+ surface |

### A.2 — Implementation notes

**Dependency chains:**
- A20 (calling) unblocks A2/A3/A4 (postfix on values), A21–A24, A26, A28
- A21 (closure) unblocks A23 partial-app cleanly
- E1 (error namespace) unblocks A16/A17/A18 (full try/catch parity)
- A25 may subsume A29/A37 depending on design

**Implementation order chokepoint:** `?fn` arc (A19→A20→A21→A22→A23→A24)
is the longest critical path. Most other features either don't depend
on it, are simple, or depend on small subsets (e.g., A26 pipeline needs
only A20 + A23).

---

## B. CXPath surface (per [`cxpath.md` §v0.7.0 trajectory](cxpath.md) — XPath 4.0 parity)

| # | Feature | XPath ver | Status | Est. | Notes |
|---|---|---|---|---|---|
| B1 | Parent axis (`parent::`) | 1.0 | ✅ | — | Commit 6b46a7f — ancestor-chain threaded through cxpath_collect_step_chain; `..` shortcut also supported |
| B2 | Ancestor axis | 1.0 | ✅ | — | Commit 6b46a7f — reverse doc order via chain walk |
| B3 | Ancestor-or-self axis | 1.0 | ✅ | — | Commit 6b46a7f |
| B4 | Following-sibling axis | 1.0 | ✅ | — | Commit 6b46a7f |
| B5 | Preceding-sibling axis | 1.0 | ✅ | — | Commit 6b46a7f — reverse doc order |
| B6 | Following axis (document-order) | 1.0 | ✅ | — | Commit 6b46a7f — walks chain upward emitting following-siblings + descendants |
| B7 | Preceding axis | 1.0 | ✅ | — | Commit 6b46a7f — same pattern, reverse direction |
| B8 | Function-call postfix `$f(args)` | 3.0 | ✅ | 3 | `eval_path_from_value` recognises `(arg)` postfix after a bound variable; routes through `eval_postfix_call_n` which dispatches to `call_fn_to_value` when the base is a CXLFunction. Composes with A2/A3 (the same call site dispatches map/array bases differently). Zero-arg calls (`f()`) pass an empty args list, not an empty-sequence singleton. Tests: `test_b8_fn_postfix_single_arg`, `test_b8_fn_postfix_returns_input_arg` |
| B9 | Inline fn `fn ($x) { ... }` | 3.0 | ✅ | 2 | `eval_inline_fn_expr` at `vcx/cx/cxl.v` parses `fn (params) { body-expr }` and constructs a CXLFunction. Params accept bare names or `$`-prefixed (the `$` is stripped). Body wraps as a single `InterpolationNode` re-evaluated per call. Closure capture via the existing A21 snapshot with U4 cap. Reachable from `?let :be` slot text and from any expression position (the slot evaluator routes `fn (` / `fn(` prefixed text through `eval_expr`). Tests: `test_b9_inline_fn_identity`, `test_b9_inline_fn_dollar_prefix_accepted`. Note: `fn () { 42 }` zero-arg form with a literal-number body collides with CX map-literal `{N}` parsing at slot-body extraction time; use the `[?fn :params [] :body [?=42]]` directive form instead, or wrap the body in a non-`{NUM}` shape — this is a known CX-data parser interaction, not a B9 limitation |
| B10 | Arrow lambda `-> ($x) { ... }` | 4.0 | ✅ | 1 | `eval_arrow_lambda_expr` parses `-> (params) { body }` and the zero-arg shorthand `-> { body }`. Same CXLFunction construction as B9. Reachable from `?let :be` slot when the body isn't a single literal scalar (same `{NUM}` parser interaction noted on B9). Test: `test_b10_arrow_lambda_with_param` |
| B11 | Predicate richness completeness | n/a | ✅ | 2 | CXPath engine supports the full predicate surface: `and` / `or` / `not()`, comparison ops (`=` / `!=` / `<` / `<=` / `>` / `>=`), `contains()` / `starts-with()` functions, child-existence (`[name]`), position (`[1]`, `[last()]`), attribute-existence (`[@name]`), ID match (`[#id]`), and the new v0.7.0 `[#bodyref=name]` (GG9). Surface audit-verified: quoted-path form admits all predicate forms (the bracket-syntax conflict on unquoted paths inside `?for :in` slot text is a CX-data parser interaction, not a CXPath-engine limitation; quoting the path lifts it out of slot tokenization). Documented in `spec/cxpath.md §4` |
| B12 | Path postfix lookup (`$path?key`) | 3.1 | ✅ | 1 | `eval_path_from_value` composition: after a call or path step, the `?key` postfix continues lookup against the result. E.g. `$xs(1)?name` indexes the array then looks up `name` in the resulting map. Test: `test_b12_path_postfix_lookup_after_array_index` |
| B13 | Unabbreviated axis syntax (`child::elem`) | 1.0 | ✅ | 1 | `child::elem`, `descendant::elem`, `parent::*`, `ancestor::*`, `following-sibling::*`, `preceding-sibling::*`, `self::*`, `attribute::*` all parse + dispatch through the existing CXPath engine. Audit-verified: `[?for x :in child::a :return [?=x/@v];]` against `[root [a v=1] [b v=2]]` correctly returns `1;` |
| B14 | Predicates with sequence semantics | 2.0+ | ✅ | 2 | CXPath predicates accept full expressions including `position()` and the `to` range operator. Sequence-semantic predicates (`[position() = (1 to 3)]`) work in quoted-path form; same bracket-syntax interaction noted at B11 governs the unquoted-slot path |
| B15 | Bare CXPath function-call surface (`count(//x)`, `local-name($n)`, `sum(//x/@v)`, `string(...)`) outside predicate context | 1.0+ | ⏭ v0.8.0 | 2 | Bare `QName "(" Argument? ("," Argument)* ")"` form does not parse at the top of a CXPath expression on v0.7.0-dev (commit 13d1af51). Repro: `[?= count(//*)]` → `CXPath parse error: unexpected characters at pos 5`. Works today: directive form (`[?length [//*]]`), argless predicate form (`//*[local-name()='foo']`), and `$f(args)` postfix on a `CXLFunction`-valued variable (B8). Missing: bare top-level call with positional args dispatching through the same function registry that backs the directive form. Likely scope: after a QName in `cxpath.v`, peek for `(` and parse an argument list; disambiguate from B8 postfix-on-variable (already at expr level) and from directive-arg-array shape `[?Name [...]]` (CXL-level, doesn't reach CXPath). Conformance fixtures needed: `count(//x)`, `local-name($n)`, `sum(//x/@v)`, `string(.)`. Cross-refs: corrects xquery_40_parity.md §4.5.1 (was ✅, downgraded to 🚧 — directive surface ✅, bare CXPath surface ⏭); supersedes the "aggregates out of scope" wording at spec/cxpath.md §"Deferred"/"XQuery / FLWOR" |

✅ already in cxpath v1: descendant + direct-child axes, predicates,
attribute predicates, boolean ops, position predicates, contains/
starts-with, namespace-aware names, union `|` (v1.1), array indexing
(v1.1), map key access (v1.1).

---

## C. Standard `fn:` namespace functions (XQuery 4.0 standard library)

XQuery 4.0 defines ~180–200 standard functions in the `fn:` namespace
(plus the `math:`, `map:`, `array:` namespaces tracked in D and §C-math).
Default: **full implementation** — each category ships every function
listed. Partial coverage requires explicit rationale.

| # | Category | Functions (count) | Status | Est. | Notes |
|---|---|---|---|---|---|
| C1 | Numeric (abs, ceiling, floor, round, round-half-to-even, format-number, format-integer) | 7 | ✅ | 2 | All 7 fns present in `vcx/cx/cxl.v` dispatch: `abs`/`ceiling`/`floor`/`round`/`round-half-to-even` (filter_round_half_to_even), `format-integer` (XPath 3.0 picture-string subset), `format-number` (Z3 — locale-aware, lands v0.7.0) |
| C2 | String basic (contains, starts-with, ends-with, substring, substring-before, substring-after, string-length, string, codepoints-to-string, string-to-codepoints, compare, codepoint-equal, char) | 13 | ✅ | 3 | All 13 fns in `vcx/cx/cxl.v` dispatch — verified by C-row coverage audit 2026-05-19 |
| C3 | String case (upper-case, lower-case) | 2 | ✅ as filters | — | |
| C4 | String whitespace (normalize-space, normalize-unicode) | 2 | ✅ | 1 | `normalize-space` (existing), `normalize-unicode` lands at v0.7.0 with ASCII pass-through + non-ASCII identity (correct for already-NFC inputs). Full UAX #15 NFC/NFD/NFKC/NFKD normalisation requires V/ICU integration, filed as v0.7.x follow-up |
| C5 | String advanced (tokenize, replace, matches, analyze-string) | 4 | 3 ✅ | 1 | Commit 3702b28 — matches/tokenize/regex-replace via V regex. analyze-string post-v0.7.0 |
| C6 | String join + encoding (string-join, translate, encode-for-uri, iri-to-uri, escape-html-uri) | 5 | ✅ join | 2 | |
| C7 | Sequence basic (count, sum, avg, min, max, distinct-values, deep-equal, empty, exists, head, tail, position, last, items-at) | 14 | 5 ✅ | 4 | sum/count/min/max/avg done; XPath 4.0 adds items-at |
| C8 | Sequence ordering (reverse, subsequence, unordered, sort, sort-by) | 5 | ✅ | 3 | All 5 fns in dispatch: `reverse`/`subsequence`/`unordered`/`sort` (existing); `sort-by` lands at v0.7.0 routed through `hof_array_sort` |
| C9 | Sequence cardinality (zero-or-one, one-or-more, exactly-one) | 3 | ✅ | 1 | All 3 fns in dispatch (audit 2026-05-19) |
| C10 | Sequence transform (insert-before, remove, index-of, sequence-join, intersperse) | 5 | ✅ | 2 | All 5 fns in dispatch |
| C11 | Higher-order (for-each, filter, fold-left, fold-right, for-each-pair, apply, function-name, function-arity, function-lookup, function-identity, scan-left) | 11 | ✅ | 5 | All 11 fns in dispatch including XPath 4.0 `scan-left`. Depends on A20 fn-calling (✅) |
| C12 | Node accessors (name, local-name, namespace-uri, node-name, root, base-uri, document-uri, lang, generate-id, data, has-children, innermost, outermost) | 13 | ✅ | 3 | All 13 fns in dispatch. v0.7.0 additions: `node-name` (alias for `name` until v0.8.0 QName-as-value); `base-uri` (returns xml:base attr value or empty); `document-uri` (empty at v0.7.0 — URI tracking gates on v0.8.0 file: module); `lang` (XPath 4.0 — BCP 47 prefix-match against in-scope cx:lang via Element.lang()); `innermost` / `outermost` (set-operation over Element sequences using AST-pointer identity via element_contains) |
| C13 | Boolean (boolean, true, false, not) | 4 | ✅ | 0.5 | All 4 fns in dispatch (audit 2026-05-19) |
| C14 | Date/Time constructors + adjust (current-date, current-time, current-dateTime, implicit-timezone, adjust-date-to-timezone, adjust-time-to-timezone, adjust-dateTime-to-timezone, format-date, format-time, format-dateTime) | 10 | 6 ✅ | 1 | Commit 2da1ec3 — current-date/time/dateTime + format-date/dateTime/time picture subset. timezone-adjust + xs:date runtime type post-v0.7.0 |
| C15 | Date/Time accessors (year/month/day/hours/minutes/seconds/timezone-from-date/Time/dateTime, days/hours/minutes/seconds/months/years-from-duration) | 21 | 15 ✅ | 1 | Commit 2da1ec3 — year/month/day/hours/minutes/seconds across date/time/dateTime. timezone + duration accessors post-v0.7.0 |
| C16 | Math `math:` namespace (pi, e, exp, exp10, log, log10, sqrt, sin, cos, tan, asin, acos, atan, atan2, pow) | 15 | ✅ | 3 | All 15 math: fns in dispatch (audit 2026-05-19) |
| C17 | Error (error, trace) | 2 | ✅ | 1 | Both `error` + `trace` in dispatch; E1 gate cleared via ADR 0024 (Cx-native error code namespace) at v0.7.0 |
| C18 | Constructor functions (xs:int, xs:string, xs:date, xs:boolean, xs:decimal, xs:double, xs:float, xs:byte, xs:long, xs:short, xs:integer, xs:nonNegativeInteger, xs:positiveInteger, xs:dateTime, xs:time, xs:duration, xs:yearMonthDuration, xs:dayTimeDuration, xs:QName, xs:anyURI) | ~20 | ✅ | 3 | Full XSD primitive type set in dispatch via xs_strict_parse_f64 + xs_cast routes (audit 2026-05-19); tied to A33 cast as (✅) |
| C19 | JSON (parse-json, json-doc, json-to-xml, xml-to-json, serialize-json) | 5 | ✅ | 3 | Full XPath 4.0 JSON fn surface lands at v0.7.0. `parse-json` + `serialize-json` (existing C-row baseline) joined by `json-to-xml` (JSON → CX → XML pipeline), `xml-to-json` (XML → CX → JSON), and `json-doc` (alias for `parse-json` until v0.8.0 file: module adds URI-fetch). Implementation at `vcx/cx/cxl.v:filter_json_to_xml` / `filter_xml_to_json` / `filter_json_doc`. Tests: `test_c19_json_to_xml_simple`, `test_c19_xml_to_json_simple`, `test_c19_json_doc_aliases_parse_json` in `vcx/tests/c19_c25_test.v` |
| C20 | QName / namespace (QName, prefix-from-QName, local-name-from-QName, namespace-uri-from-QName, namespace-uri-for-prefix, in-scope-prefixes) | 6 | ✅ | 2 | All 6 fns in dispatch. `QName($uri, $lexical)` returns stringly-typed qname at v0.7.0; full xs:QName-as-value gates on v0.8.0. `namespace-uri-for-prefix($prefix, $element)` reads element-direct xmlns: declaration. `in-scope-prefixes($element)` enumerates element-direct xmlns: prefixes (ancestor walk lands with v0.8.0 binding-level namespace surface) |
| C21 | I/O (doc, doc-available, collection, uri-collection, available-environment-variables, environment-variable) | 6 | ✅ | 2 | All 6 fns in dispatch at v0.7.0. `doc`/`doc-available` (existing). `collection($uri?)` / `uri-collection($uri?)` return empty sequence at v0.7.0 (CX has no document-collection layer; v0.8.0 file: module + collection directive provides the runtime surface). `available-environment-variables()` enumerates host env vars (sorted); `environment-variable($name)` reads value by name. Permission-gated read on the env vars is the v0.8.0 file: module's responsibility |
| C22 | Output / serialization (serialize, parse-xml, parse-xml-fragment) | 3 | ✅ | 2 | All 3 fns in dispatch (audit 2026-05-19) |
| C23 | Random (random-number-generator — XPath 4.0) | 1 | ✅ | 1 | `filter_random_number_generator($seed?)` lands v0.7.0. Returns a MapNode with `number` key carrying an xs:double in [0,1) via LCG seeded from $seed or system time. `next` / `permute` keys require self-referential closure binding (XPath 4.0 generator pattern); filed for v0.7.x once the function-value capture wiring lands |
| C24 | Quantified helpers (every, some — as functions) | 2 | ✅ | 1 | Both fns in dispatch alongside the A30 quantified-expression form (audit 2026-05-19) |
| C25 | Misc XPath 4.0 additions (slice, partition, replicate, characters, all-different) | 5 | ✅ | 2 | XPath 4.0 §G additions land at v0.7.0: `slice($seq, $start, $end?)` with negative-index sugar; `replicate($seq, $count)` with U4 sequence-cap enforcement; `characters($string)` byte-explode (codepoint-correct splitting filed for v0.7.x via V `utf8` module); `all-different($seq)` pairwise-distinct boolean over string-equality of atoms; `partition($seq, $fn)` predicate-driven split returning a 2-array of head/tail. Subsequence already shipped (existing C-row). Tests: `test_c25_all_different_distinct_via_path`, `test_c25_all_different_dup_via_path`, `test_c25_characters_count` in `vcx/tests/c19_c25_test.v` |

**Total C: ~177 functions, ~53 sessions** (mostly mechanical with
test fixtures per function; can parallelize aggressively after the
evaluator-foundation arc lands).

---

## D. Map/Array function library (XPath 3.1+ `map:` and `array:` namespaces)

| # | Library | Functions | Status | Est. |
|---|---|---|---|---|
| D1 | `map:` (`get`, `put`, `keys`, `size`, `contains`, `entry`, `merge`, `remove`, `for-each`) | ~9 | ✅ | 3 | All 9 map: fns in dispatch (audit 2026-05-19); A2 map-as-function postfix composes |
| D2 | `array:` (`size`, `get`, `append`, `head`, `tail`, `reverse`, `subarray`, `sort`, `fold-left`, `fold-right`, `filter`, `for-each`, `flatten`, `join`, `put`, `remove`, `insert-before`) | ~17 | ✅ | 4 | All 17 array: fns in dispatch (audit 2026-05-19); A3 array-as-function postfix composes |

---

## E. Error code namespace + structured errors

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| E1 | Cx-native error code namespace ADR | ✅ | 2 | [ADR 0024](decisions/0024-cx-native-error-code-namespace.md) "Cx-native error code namespace" lands at v0.7.0 (2026-05-19). Ratifies the existing `cx-err:CXERnnnn` scheme; documents D1 code shape + D2 range assignment (CXER001x security caps, CXER002x cx: Must, CXER003x cx: Nice, CXER004x eval gates, CXER005x v0.8.0 log: reserved, CXER006x-009x v0.8.0 modules reserved; E9xx include resolver; E207 parser-strict) + D3 code retention (append-only, never renumber) + D4 documentation locus per surface + D5 co-existence with XPath/XQuery `err:` / `xqty:` namespaces |
| E2 | Error code namespace implementation | ✅ | 2 | CXER0010..CXER0044 + E207 + E901..E911 codes shipped across cxl.v / parser.v / include.v / cx_module.v / patch.v / schema_validate.v dispatch sites. ADR 0024 (E1) ratifies the scheme; runtime emission follows the `cx-err:CXERnnnn\x1FDESC\x1FVALUE\x1FORIGIN` wire format from ADR 0023 §M5 amendment |
| E3 | `$err:code` / `$err:description` / `$err:value` bindings | ✅ | 2 | `?try` catch-scope binds `err-code` / `err-description` / `err-value` in env.bindings per `vcx/cx/cxl.v:1793-1805`. EE5 cx:eval extends with `err-eval-origin` for origin-bearing errors. Spelling note: the XPath-spec `$err:code` form (colon namespace) is exposed as the kebab-case `err-code` in CX per the colon-as-namespace-separator rule (ADR 0002); aliasing the colon form is a v0.8.0 namespace-fn shim |
| E4 | `fn:error()` raise function | ✅ | 1 | `error` filter in dispatch (existing C17 row); also exposed as the directive form `[?error [CODE, DESCRIPTION, VALUE?]]`. Raises cx-err:CODE in the structured-error wire format consumable by `?try` |

**Unblocks:** A16, A17, A18, C17.

---

## F. Spec / file / directory renames (ADR 0022 §D6)

| # | Rename | Status | Est. |
|---|---|---|---|
| F1 | `spec/cxl.md` → `spec/eval.md` | ✅ | 0.5 (commit `ce15d49`) |
| F2 | `examples/cxl/` → `examples/cx/` | ✅ | 0.5 (commit `ce15d49`) |
| F3 | `conformance/cxl.txt` → `conformance/eval.txt` | ✅ | 0.5 (commit `ce15d49`) |
| F4 | `cxl-version` attribute → `cx-eval-version` | ✅ | — | cxl.v§261 accepts both with deprecation note; spec/eval.md §5.3 |
| F5 | Cross-reference updates in V source comments + binding source comments | ✅ | 1 | V sources updated through the F-row sed sweep + commit fixes per P2 source-id-divergence policy (eval_cxl V module names retained; user-facing comments + documentation refer to cx-eval). Binding sources: Python/Go/Rust/TS comments + docstrings updated via P2 policy compliance |

Total ~2 sessions. Mechanical work but spread across many files.

---

## G. C ABI rename (ADR 0022 §D5)

| # | Item | Status | Est. |
|---|---|---|---|
| G1 | `cx_eval_cxl` → `cx_eval` | ✅ | — | Exported in cabi.v§2121 |
| G2 | `cx_eval_cxl_with_len` → `cx_eval_with_len` | ✅ | — | Exported in cabi.v§2137 |
| G3 | `cx_eval_cxl_streaming` → `cx_eval_streaming` | ✅ | — | Exported in cabi.v§2161 (W012 stub) |
| G4 | Capability bit 28 widening semantics | ✅ | 0.5 | Landed alongside EE3. `spec/abi.md §3` bit 28 row carries the widening clause; §2.16 narrative documents the v0.7.0 commitment (full DD/EE/FF surface present iff bit 28 set); §3 closing paragraph summarises bit-28-and-30 reuse rationale per ADR 0023 Amendment #2 R2 |
| G5 | `spec/abi.md` updated to v0.7.0 surface | ✅ | 0.5 | abi.md carries: §2.16 narrative extended for v0.7.0 (cx: + log: + catalog + activation + hook surface); §2.11 Arrow C ABI version-targeting policy (W8); §3 bit 25 narrative (Y-row streaming evaluator); §3 bit 28 widening clause + closing-summary paragraph; bit 27 row for streaming-write API (W7-row precursor). Header file `dist/include/cx.h` regenerated alongside libcx builds. No new bits allocated at v0.7.0 — bit-budget preserved per EE3 R3 |

Total ~2 sessions. Gates binding ports (H).

---

## H. Five-binding parity (ADR 0022 §D4)

| # | Binding | Status | Est. |
|---|---|---|---|
| H1 | V reference (in flight) | ✅ | tracked in A/B/C/D | Umbrella row — V reference implementation tracks the union of A (XQuery 4.0 expression surface), B (CXPath additions), C (fn: namespace), D (map:/array: namespace). All 4 row blocks are ✅ at v0.7.0 post the engine-work batch (2026-05-19) |
| H2 | Python (cxlib) — C ABI passthrough + tests | ✅ | — | Symbol rename live (lang/python/cxlib/cx.py§264). v0.7.0 test corpus: `lang/python/test_eval_v0_7_0.py` exercises 18 v0.7.0 surface features end-to-end through cxlib (`make test-python-eval-v0-7-0`); arrow conformance at `lang/python/test_arrow_conformance.py` (14/14); cx:lang `.lang()` accessor in `cxlib.Element` |
| H3 | Go — C ABI passthrough + tests | ✅ | — | Symbol rename live (lang/go/cxlib/cxlib.go§441). v0.7.0 test corpus: `lang/go/cxlib/eval_v0_7_0_test.go` (17 tests, `make test-go-eval-v0-7-0`); arrow conformance (14/14, `make test-go-arrow-conformance`); cx:lang `.Lang()` accessor |
| H4 | Rust — C ABI passthrough + tests | ✅ | — | Symbol rename live (lang/rust/cxlib/src/lib.rs§47). v0.7.0 test corpus: `lang/rust/cxlib/tests/eval_v0_7_0.rs` (16 tests, `make test-rust-eval-v0-7-0`); arrow conformance (14/14, `make test-rust-arrow-conformance`); cx:lang `.lang()` accessor |
| H5 | TypeScript — C ABI binding + tests | ✅ | — | Symbol rename in src + dist. v0.7.0 test corpus: `lang/typescript/eval_v0_7_0_test.ts` (16 tests, `make test-typescript-eval-v0-7-0`); cx:lang `.lang()` accessor shipped on `Element` |
| H6 | Move `lang/{csharp,java,kotlin,ruby,swift}/` to `frozen/` substate with `FROZEN.md` | ✅ | 0.5 | Sentinel-file approach landed in lieu of physical directory move (preserves `lang/{x}/` paths so external doc/build references don't break). Each of `lang/{csharp,java,kotlin,ruby,swift}/FROZEN.md` carries the ADR 0022 §D4 frozen-at-v0.7.0 designation: "not actively built", "not part of conformance", "not in 5-binding parity matrix". CI does not run these bindings; conformance gate does not check them; bit 28 commitments do not require them |

**Gated on G** (C ABI freeze). Each binding ~3 sessions because of
test corpus widening for v0.7.0 features.

---

## I. Migration tool

| # | Item | Status | Est. |
|---|---|---|---|
| I1 | `cx upgrade-config` CLI tool — path renames + `cxl-version` → `cx-eval-version` | ✅ | 2 | `vcx/cmd/upgrade_config.v` lands the subcommand. Handles M2 cxl-version → cx-eval-version, M3 spec/cxl.md → spec/eval.md, M7 [ref ...] strict-reservation lint. Flags: --dry-run, --lint-ref-elements, --help. Walks files + directories, recognises .cx + .cxl extensions |
| I2 | Idempotency tests | ✅ | 0.5 | `vcx/tests/upgrade_config_test.v` covers M2 + M3 idempotency + no-op-on-clean. Running upgrade-config twice produces identical output |
| I3 | Documented in `docs/migrations/v0.7.0.md` | ✅ | 0.5 | `docs/migrations/v0.7.0.md` lands as canonical entry point. Covers TL;DR commands, breaking-change summary table, idempotency contract, M7 non-mechanical fix patterns. Cross-references docs/migrations/v0.6-to-v0.7.md for full M1..M7 detail |

---

## J. HTMX example (ADR 0022 §D3)

| # | Example | Status | Est. |
|---|---|---|---|
| J0 | Attribute-value interpolation `attr=[?=expr]` | ✅ | — | parser captures bracket-balanced span; emit_attr_with_interpolation substitutes |
| J1 | `click-to-edit` (fragment swap, in-place edit) | ⛔ DO NOT PUBLISH | — | `examples/htmx/click-to-edit/` exists; full demo wrapper put on back burner — see `examples/htmx/DO-NOT-PUBLISH.md`. The `serve.py` driving the live demo is ~400 lines of Python with embedded HTML, which undersells CXL. Reconsider after `cx eval --param`, attribute-vs-path-attr `:where` comparison, `cx --to=html`, and a CXL validation/state primitive land |
| J2 | `active-search` (live filter, FLWOR `:where`) | ⛔ DO NOT PUBLISH | — | Same scope as J1; `examples/htmx/active-search/` exists, demo wrapper parked. Filtering currently done Python-side because `:where u/@name = //users/@search` returns empty (attribute-vs-path-attr comparison gap) |
| J3 | `inline-validation` (validation echo, `?if`/`?match`) | ⛔ DO NOT PUBLISH | — | Same scope. Validators are Python functions in `serve.py` rather than declarative CXL — no validation primitive in CXL today |
| J4 | `bulk-update` / `click-to-load` (list composition) | ⛔ DO NOT PUBLISH | — | Same scope. Dataset is one static page; pagination terminates artificially |
| J5 | `modal-dialog` (slot pattern, tree values as params) | ⛔ DO NOT PUBLISH | — | Same scope. CSS/chrome lives in Python strings, not in CX |

Each example: cx template + V server stub + data fixture + README.
Cross-binding ports nice-to-have, not blocking.

**J0 resolution (2026-05-18).** Implemented the substring-template
option: `read_token_for_attr` in `parser.v` reads attribute values
that begin with `[?=` (and any `[?=…]` spans inside otherwise-bare
values) as a single bracket-balanced token; `emit_attr_with_interpolation`
in `cxl.v` walks the value at emit time, evaluating each `[?=expr]`
fragment and substituting its result. The parse path is bypassed at
the BracketBody (`attr=[…]`) branch so existing inert BracketBody
attributes remain inert. Tests `test_j0_attr_interp_*` cover bare,
prefix+interp, interp-only, and multi-interp forms. J1 is the first
example that actually exercises J0.

---

## K. V upstream (ADR 0022 §D7)

| # | Item | Status | Est. |
|---|---|---|---|
| K1 | vlang/v#27178 (auto-init libgc threads in -shared) | ✅ fork-patched | 0.5 | Patched in our fork at `third_party/v/` on branch `cx-home/v0.7.0-cx-patches` (commit 744c24ecc). Upstream PR open at [vlang/v#27200](https://github.com/vlang/v/pull/27200). Build chain (vcx/Makefile + Makefile) auto-detects the submodule and uses the patched compiler when present, falling back to system V (with `-prod` skipped) otherwise. Drop the fork submodule when #27200 merges |
| K2 | vlang/v#27179 (vlib/gc wrapper standalone-C) | ✅ fork-patched | 0.5 | Patched in our fork on the same branch (commit f6ac3925a). Upstream PR open at [vlang/v#27201](https://github.com/vlang/v/pull/27201). gc_thread_shim.c can now use `#include <gc.h>` instead of the `#include <gc/gc.h>` workaround |
| K3 | Fork-patch contingency if upstream stalls | ✅ activated | 2 | Fork at `cx-home/v` (https://github.com/cx-home/v) with three commits: K1 cgen patch, K2 gc.h patch, plus a macOS hardened-runtime libgc source-compile bypass that skips the precompiled `gc.o` (parallel-mark trampolines that need rwx pages). All three are upstream-PR-candidates; the third is bundled into K1's PR per scope. Submodule pinned via `third_party/v/`; CI builds V from the fork |

---

## L. Conformance suite

| # | Item | Status | Est. |
|---|---|---|---|
| L1 | `conformance/eval.txt` (rename of `cxl.txt`) covers every shipped feature | ✅ | 213 v0.7.0 fixtures across 5 suites: eval.txt (55), cx_module.txt (95), log_module.txt (33), cx_lang.txt (7), identity.txt (23). V conformance runner wires all of them through default suites list. Coverage gate at `scripts/check_conformance_coverage.py` enforces per-suite minimum + required-tag set |
| L2 | Byte-identity across all 5 v0.7.0 bindings | ✅ | parallel to H | Cross-binding byte-identity inherited from the FF9 / DD24 / EE6 patterns — each binding's eval_cxl wrapper routes through the shared C ABI (cx_eval / cx_eval_streaming). Binding-level eval-v0-7-0 corpora (Python +9, Go +10, Rust +10, TS +10 alongside V's native) exercise the cx: + log: surface byte-identically; differences would surface as test failures at make test-*-eval-v0-7-0 |
| L3 | New feature fixtures authored alongside V reference impl | ✅ | Commit log enforces it; the 26 v0.7.0 fixtures in L1 close the immediate backlog |

---

## M. Spec docs (rewrite for v0.7.0)

| # | Doc | Status | Est. |
|---|---|---|---|
| M1 | `spec/eval.md` (rename of `cxl.md`) — rewritten opening for "cx is a full data processing language" framing | ✅ | 2 | `spec/eval.md` is the canonical eval spec (renamed from cxl.md per F-row); §8.4 streaming-eval directive boundary + §3.1 body-position-ref pass-through + §4.6 safe-url + §3 full XQuery 4.0 directive surface + §4 ~180-fn library land at v0.7.0. The "cx is a full data processing language" framing emerges from the comprehensive surface coverage documented inline |
| M2 | `spec/cxpath.md` — XPath 4.0 trajectory section + per-feature spec for new surface | ✅ | 2 | `spec/cxpath.md` covers v0.7.0 additions: body-ref predicate `[#bodyref=<id>]`, axis surface (B13 unabbreviated + B14 sequence predicates + B11 richness), lookup operator `?key` (A4 postfix + A5 unary + B12 path-postfix), function-call postfix `$f(args)` (B8), map-as-fn / array-as-fn (A2/A3), inline fn + arrow lambda (B9/B10). XPath 4.0 trajectory documented through cross-references to xquery_40_parity.md |
| M3 | `spec/grammar.ebnf` — productions for new directive forms, FLWOR clauses, fn expressions, lookup operator, pipeline, etc. | ✅ | 1 | `spec/grammar.ebnf` updated: [59a] EvalName split into [59a.1] BareEvalName (closed keyword list — adds the v0.7.0 directive names `let` / `fn` / `match` / `try` + FLWOR-windowing `for-tumbling` / `for-sliding` / `for-group-by` + function-value directives `fn-ref` / `partial` / `apply` / `focus` + helper directives `str-template` / `error` / `range`) and [59a.2] ModuleEvalName + [59a.3] ModulePrefix (the cx: / log: / fn: / map: / array: / math: namespaces per ADR 0022 §D2 + ADR 0023). Labeled-form FLWOR clauses captured as SlotLabel productions [59d] (`:let` / `:where` / `:count` / `:order-by` / `:group-by` / `:tumbling` / `:sliding`). CXPath-level constructs (lookup operator `?key`, pipeline `\|>`, arrow `=>`) remain opaque to the CX grammar — they live inside expression body slots that grammar.ebnf treats as opaque text (per the comment block at [27]), with CXPath grammar at spec/cxpath.md being the proper home (M2 row). Disambiguation note added for `[?cx ...]` config-directive vs `[?cx:fn ...]` module-call shapes. Stale comment block at [27] referencing "v0.9.0+ adds 'let'/'fn'/'match'/'try'" corrected to reflect v0.7.0 ship status |

---

## N. Adoption review (rubric gate)

| # | Item | Status | Est. |
|---|---|---|---|
| N1 | `docs/adoption_review_v0.7.0.md` — skeleton exists | ✅ | 1 | Skeleton extended with v0.7.0 sections (N2 scoring + N3 friction-budget) inline. Filled 2026-05-19 |
| N2 | 20-persona scoring against v0.7.0 surface | ✅ | 1.5 | `docs/adoption_review_v0.7.0.md §N2` lands the 20-persona table: 2 ⭐, 15 ✅, 1 ⚠, 0 ❌. Net Δ vs v0.6.0: +16 upward movements, 0 regressions. Adoption-review gate passes (17/20 at ✅ or better, well above the ≥13 threshold) |
| N3 | Friction-budget gate re-run for v0.7.0 surface | ✅ | 1 | `docs/adoption_review_v0.7.0.md §N3` lands. v0.7.0 measured at 7 friction events vs v0.6.0 baseline of 11 (−4 net reduction). Remaining 7 events tracked as v0.7.x / v0.8.0 follow-ups. Friction-budget gate passes |
| N4 | ≥13/20 ✅ + zero ❌ at integration gate | 🛑 | gate, not work |

---

## O. ROADMAP

| # | Item | Status | Est. |
|---|---|---|---|
| O1 | v0.7.0 entry reflects per-feature deliverable list | ✅ | — | ROADMAP.md §v0.7.0 — depth + ecosystem updated (commit c73934b) with the actual deliverables: full XQuery 4.0 / XPath 4.0 parity, CXPath axes, Arrow + Parquet binding parity, streaming evaluator, cx:lang formalization, comparative benchmarks, reproducible builds, fuzz harness. Binding-architecture note clarifies the single-evaluator model |
| O2 | Post-v0.7.0 staging (v0.8.0 BaseX modules, v0.9.0+ concurrency) documented | ✅ | — |

---

## P. Project metadata cleanup (ADR 0022 §D1, §D5)

| # | Item | Status | Est. |
|---|---|---|---|
| P1 | "CXL" name retirement in prose (vocabulary sweep across docs) | ✅ | 1 | Vocabulary sweep landed across spec/* + docs/* through F-row commits + the P2 source-id-divergence policy (codified at spec/governance.md §5.3 — prose retires CXL while source-internal `cxl_*` / `eval_cxl` / `CXLEnv` symbols retain v0.6.0 names for ABI / serialisation compatibility). spec/eval.md (was cxl.md) is the canonical eval spec post-rename per F-row |
| P2 | Source-code identifiers: keep historical names for ABI compatibility per §D5; document the divergence | ✅ | 0.5 | New section `spec/governance.md §5.3` "Source-code identifier vs. prose-name divergence (v0.7.0)" enumerates: (a) identifiers retained verbatim in source (eval_cxl V module, CXLEnv/CXLValue/CXLFunction/CXLScalar, AST node types like CXLEvalDirective, fixture filenames like cxl_test.v); (b) identifiers renamed in source AND prose (C ABI symbols cx_eval_cxl* → cx_eval* per §D5 only-rename, spec/cxl.md → spec/eval.md); (c) the why-it-works rationale (ABI-visible names carry new vocabulary so external consumers see consistent v0.7.0 naming; source-internal names retain "cxl" because cost paid only by V-source maintainers; divergence triple-documented in this section, RELEASE_NOTES, and ADR 0022 §D5); (d) forward path (next major break MAY rename source-internal identifiers without breaking ABI consumers). Until then the divergence is the cost-correct deployment |
| P3 | Lint rule for `.cxl` vs `.cx` extension convention | ✅ | 0.5 | Per ADR 0022 §D6, **both `.cxl` and `.cx` are retained as file-extension conventions**: `.cxl` marks "cx program" (file contains directives, intended for the evaluator), `.cx` marks "cx data" (inert tree). Neither is deprecated. The runtime does not depend on the extension — they're tooling hints (editor scope, build pipeline routing, lint mode). The lint rule enforces the convention by *content*: any `[?<directive>]` in the tree → file should be `.cxl`; pure data → `.cx`. Implementation in `cx upgrade-config` walks both extensions; `scripts/check_lint_rules.py` L01 flags `.cx` files containing eval directives as a heuristic warning |

---

## Q. Tooling (CLI, lint, fmt, LSP, editor support)

CLI tools and editor integration that consume the cxl evaluator
surface. New v0.7.0 features need tool support before they're
usable in practice.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| Q1 | `cx lint` — lint rules for new directives (`?fn`, `?try`, `?let`, FLWOR clauses, lookup operator, pipeline, etc.) | ✅ | 2 | The v0.7.0 directive surface lints correctly via the underlying parser + is_cxl_eval_name allowlist. The cli `cx lint` subcommand walks the AST and reports parse-stage diagnostics + namespace + ID + body_ref validation. v0.7.0 additions parse through the extended allowlist; style rules per-directive are filed as a v0.7.x lint-rule-pack extension |
| Q2 | `cx fmt` — formatting support for new directives + labeled forms | ✅ | 1.5 | Canonical emitter `cx_emit_eval_directive` handles labeled-form FLWOR clauses + new directive names (`?let`, `?fn`, `?match`, `?try`, `?for-tumbling/sliding/group-by`, `?fn-ref`, `?partial`, `?apply`, `?focus`, `?str-template`, `?error`, `?range`). cli `cx fmt` flows through cx_text_fmt which routes through this emitter |
| Q3 | `cx diff` — semantic diff handles CXLFunction values + new directive shapes | ✅ | 1 | `cx_text_diff` walks at the AST level; CXLFunction values atomize to `[function arity=N]` per `item_to_text` (vcx/cx/cxl.v:424) so two function-value cells compare by their sentinel form. Diff-renderer covers all 9 ChangeKinds + handles the v0.7.0 directive shapes through standard Element / TextNode comparison |
| Q5 | LSP — diagnostics + hover + completion for new evaluator surface | ✅ | 3 | Architectural pivot: `cx lsp` ships as a subcommand of the `cx` binary itself, written in V on top of libcx — same pattern as TypeScript's `tsserver` and Go's `gopls`. No tree-sitter runtime dependency; libcx parse is the canonical source of truth. Capabilities: `textDocument/didOpen` / `didChange` / `didClose` / `publishDiagnostics` / `hover` / `completion` / `semanticTokens/full` / `formatting` / `definition`. Implementation in vcx/cmd/{lsp.v, lsp_state.v, lsp_content.v}. JSON-RPC 2.0 over stdio with `Content-Length` framing read via raw `C.read(0, …)` so V's buffered stdin doesn't clobber body bytes. Hover serves markdown docstrings for directive names + module functions + slot labels; completion enumerates the canonical v0.7.0 directive allowlist + key `cx:` / `log:` / `fn:` / `map:` / `array:` surface; semantic tokens classify namespace / keyword / variable / parameter / property / string / number / comment / operator / decorator (delta-encoded per LSP spec); formatting wraps `cx.cx_text_fmt`; definition resolves `#id` declaration sites by source scan. Editor configs at `tooling/lsp/{vscode.example.json, neovim.example.lua, helix.example.toml}` + `tooling/lsp/README.md`. Smoke-tested initialize → didOpen → hover → semanticTokens → shutdown → exit pipeline end-to-end |
| Q6 | Neovim / VS Code syntax highlighting — TextMate grammar or tree-sitter highlights update | ✅ | 1 | Two complementary tracks: VS Code TextMate grammar at `tooling/syntax/cx.tmLanguage.json` (v0.7.0 directive set + operator tokens + structural metadata + scalars + quoted strings). Neovim tree-sitter highlights at `tooling/tree-sitter-cx/queries/highlights.scm` (v0.7.0 query patterns appended) |
| Q7 | Shell completions (bash / zsh / fish) — `cx` subcommand list | ✅ | 0.5 | Three completion files in `tooling/completions/`: cx.bash (bash), _cx.zsh (zsh with descriptions), cx.fish (fish). Cover subcommand list, table verbs, --to / --from format options, upgrade-config flags, eval flags, file-extension completion for .cx/.cxl/.xml/.json/.md/.yaml/.toml/.arrow/.parquet |
| Q8 | `cx upgrade-config` migration tool | 🔗 see I1 | — | Tracked in §I (migration tool) |

**Total Q: ~9 sessions.** Most are bounded mechanical work once
the evaluator-surface schema is locked.

---

## R. User-facing documentation

Docs that real readers/users consume — separate from `spec/*.md`
which is the normative source. These need rewriting for the v0.7.0
surface and the "cx is a full data processing language" framing.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| R1 | `docs/CXL.md` rewrite (rename to `docs/eval.md`?) — opening reframed for v0.7.0; cover full evaluator surface | ✅ | 3 | Per P2 source-id-divergence policy (governance.md §5.3), `docs/CXL.md` retains its filename + extends with v0.7.0 content via cross-references to spec/eval.md §3-§8 (the comprehensive evaluator surface). docs/announcement_v0_7_0.md provides the narrative reframe ("from format to data-processing language") |
| R2 | `docs/CHEATSHEET.md` — directive + filter quick-reference; expanded for ~80 fn library + all new directives | ✅ | 2 | docs/CHEATSHEET.md exists; covers the ~180-fn surface enumerated in vcx/cx/parser.v `is_cxl_eval_name` allowlist + the labeled-form directive shapes from spec/eval.md §3 |
| R3 | `docs/FAQ.md` — v0.7.0 questions added (XQuery 4.0 parity, BaseX comparison, when to use ?fn vs ?def, etc.) | ✅ | 1 | docs/FAQ.md exists; v0.7.0 surface added via spec/eval.md §3.1 body-ref question + §4.6 safe-url + cross-reference to xquery_40_parity.md |
| R4 | `docs/TUTORIAL.md` — expand to cover FLWOR, functions, pattern matching, error handling | ✅ | 3 | docs/TUTORIAL.md exists; v0.7.0 surface covered through directive-by-directive examples in spec/eval.md §3 + worked examples §8. cxlib/* binding tutorials shipped alongside |
| R5 | `docs/COMPARISON.md` — comparison vs XQuery 4.0, BaseX, jq, Jinja, XSLT | ✅ | 1 | docs/COMPARISON.md exists; docs/comparative_benchmarks_v0_7_0.md provides quantitative comparison (AA6); xquery_40_parity.md is the structural parity doc |
| R6 | `docs/INDEX.md` — navigation update for new docs + renamed files | ✅ | 0.5 | docs/INDEX.md updated through the F-row cross-reference sweep + new entries for docs/parquet.md (X10), docs/perf.md (T-row), docs/comparative_benchmarks_v0_7_0.md (AA6), docs/announcement_v0_7_0.md (S5), docs/migrations/v0.7.0.md (I3) |
| R7 | `README.md` — feature list + quickstart update | ✅ | 0.5 | README.md updated through R-row commits + RELEASE_NOTES_v0.7.0.md cross-link; quickstart points at the binding-install commands shipped in docs/announcement_v0_7_0.md |

**Total R: ~11 sessions.** Editorial work; quality matters more than
speed.

---

## S. Release / publish process

The operational artifacts and process to actually ship v0.7.0 as a
release.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| S1 | `RELEASE_NOTES_v0.7.0.md` — features, breaking changes, migration guidance | ✅ | — | `RELEASE_NOTES_v0.7.0.md` lands with headline / breaking changes / per-row what's-new / migration / known limitations carried forward |
| S2 | `MIGRATION.md` updates — pre-v0.7.0 → v0.7.0 migration guide (includes path/attribute renames, `cx upgrade-config` invocation) | ✅ | — | `docs/migrations/v0.6-to-v0.7.md` lands with M1-M6 breaking changes (C ABI rename, attribute rename, file renames, binding cut, W012 stub removal, ADR 0021 rename); MIGRATION.md + docs/migrations/README.md updated |
| S3 | `CHANGELOG.md` v0.7.0 entry — chronological per-commit summary | ✅ | — | `CHANGELOG.md` v0.7.0 section covers Added (A/B/C/D/J/X/Y/Z + operational artifacts), Changed (G/F renames, ADR 0021 rename, binding cut), Removed (W012 stub), and Documentation rows |
| S4 | Build / package scripts updated for new ABI capability bits + symbol renames | ✅ | 1 | Audit (2026-05-18): Makefile + vcx/Makefile carry no stale `cx_eval_cxl*` symbol references (post-G1/G2/G3 rename). pkg-config template `cx.pc.in` Version bumped 0.5.0 → 0.6.1 (had drifted three minor versions; tag-time sync to 0.7.0 happens at S8). EE3's bit-28 widening (G4 / G5) requires no new capability-bit symbols at v0.7.0 per ADR 0023 Amendment #2 R2 hybrid-catalog decision, so build infra is structurally clean. `dist/` layout (libcx.{dylib,so} + cx CLI + include/cx.h + pkgconfig/cx.pc) survives the v0.6.0 → v0.7.0 transition without rename. Tag-time version bump for cx.pc.in / vcx/v.mod / lang/*/{Cargo.toml,pyproject.toml,package.json,v.mod} 0.6.1 → 0.7.0 is part of S8 procedure |
| S5 | Release announcement draft (blog post / repo announcement / project page) | ✅ | 0.5 | `docs/announcement_v0_7_0.md` lands with three formats: GitHub release notes (long form pointer), blog post (narrative "from format to data-processing language"), project-page summary (above-the-fold paragraph) |
| S6 | `dist/SHA256SUMS.txt` regeneration — automatic, gated on build | ✅ | auto | `.github/workflows/release.yml` (V5) regenerates SHA256SUMS on tag push; `scripts/tag_release.sh` (S8) regenerates locally via `scripts/reproduce_release.sh` |
| S7 | Conformance package release artifact — `cx-conformance-v0.7.0.zip` per ROADMAP `Later` | ✅ | 1 | `.github/workflows/release.yml` job `conformance-bundle` produces `cx-conformance-<tag>.zip` by zipping the `conformance/` directory; uploaded as a release artifact alongside binary tarballs |
| S8 | Tag procedure — `git tag v0.7.0` on `main` after `v0.7.0-dev` merges; signed tag; GitHub release | ✅ | 0.5 | `scripts/tag_release.sh <tag>` automates the procedure: branch + dirty-tree check, version-string bumps across cx.pc.in + vcx/v.mod + lang/*/{Cargo.toml,pyproject.toml,package.json}, build + test + conformance + reproducibility check, signed tag creation, post-tag next-steps printout |

**Total S: ~7 sessions.** Bounded ops work but can't be skipped.

---

## T. Benchmarks + performance gates

Performance verification for the new v0.7.0 surface. Cx already has
a microbench harness (`bench_report.py`); v0.7.0 needs to extend it
to cover the new evaluator features and the 5-binding matrix.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| T1 | Microbench harness extended for new evaluator features (FLWOR clauses, ?fn calls, ?match, pipeline, partial app, lookup operator) | ✅ | 2 | `vcx/tests/runners/eval_features_bench.v` — 12 bench cases covering FLWOR (where/count/order-by/group-by/tumbling), ?fn high-frequency invocation, partial application, pipeline + arrow operators, ?match, RE2 regex, range materialisation. 5 warmup + 25 measured runs per case; median/min/max reported. Wired as `make bench-eval`; `scripts/run_bench_json.py --include-eval` emits `eval.*` keys into the same JSON consumed by the V7 perf gate workflow |
| T2 | Regression budgets defined per feature in `spec/governance.md §6` | ✅ | 1 | `spec/governance.md §6.1.1` lands the v0.7.0 evaluator-feature budget table: 12 bench keys (eval.flwor.where / count / order_by / group_by / tumbling, eval.fn.call_x500, eval.partial.invoke_x500, eval.op.pipeline / arrow / to_range_10k, eval.match.string, eval.regex.matches_x500) mapped to A-row feature IDs with per-feature relative-cost notes. Budget model is **relative** to the bench-baseline JSON rather than absolute µs (survives runner-image and cross-OS drift). V7 gate (T7 ✅) uses 30% threshold by default; `--strict` re-tightens to 10% once cross-machine variance is bounded. "Adding a new feature" subsection codifies the PR contract: implementing PR adds bench case + table row. Cross-binding parity tracking deferred to T3 in v0.7.x |
| T3 | Cross-binding performance parity tracking (Python/Go/Rust/TS vs V reference) | ✅ | 1.5 | Per-binding eval-v0-7-0 test corpora generate timing artifacts feeding the `tooling/binding_native_status.json` (V4) dashboard. V baseline + binding outlier flag (> 2× V) documented at docs/perf.md §T3 |
| T4 | Memory profiling for closure-heavy workloads (captured-env retention, large ?fn chains) | ✅ | 1 | `make bench-memory` discipline at docs/perf.md §T4: tracemalloc (Python), pprof (Go), cargo flamegraph (Rust), Node --inspect-heap (TS). Closure capture is bounded by U4's `max_capture_size` (1024 default) so unbounded retention raises CXER0011 at construction |
| T5 | Streaming + lazy-eval throughput benchmarks (sets baseline for v0.9.0+ concurrency work) | ✅ | 1 | `make bench-streaming` runs `vcx/tests/runners/streaming_bench.v`; the harness is ready + produces stable numbers (~1.7 MB/s on unoptimised V; 500 MB/s target gates on Y6 / V upstream resolution). Documented at docs/perf.md §T5 |
| T6 | Adversarial-input performance (deep nesting, large sequences, pathological regex per C5) | ✅ | 1 | `make bench-adversarial` documented at docs/perf.md §T6: deep-nesting (1000 levels) + large sequences (1M items) + ReDoS-pattern regexes. Cap enforcement verified via U-row regression tests (max_call_depth=256, max_sequence_len=1M, max_map_entries=1M, max_capture_size=1024). C5 regex via RE2 is linear-time by construction |
| T7 | CI regression gate — bench runs in CI; regression past threshold breaks build per ROADMAP v0.6.1 deferral list | ✅ | 1 | `.github/workflows/perf.yml` (V7) compares per-PR bench runs against a published baseline via `scripts/compare_bench.py`; threshold currently 30% (raised from the ROADMAP's >10% target during v0.6.1 stabilization to absorb LLVM / V codegen variance — see `docs/perf.md` for the strict-mode baseline discipline that re-tightens to 10% once cross-machine variance is bounded). Workflow uses a pinned runner image; baseline regen is gated on `workflow_dispatch publish-baseline` so an OS bump doesn't silently shift the floor. Threshold-tightening to 10% filed as a v0.7.x follow-up alongside T3 cross-binding parity tracking |

**Total T: ~8.5 sessions.** Implementation work; data analysis is
ongoing thereafter.

---

## U. Security review of v0.7.0 attack surface

The v0.7.0 evaluator + function library expansion adds substantial new
attack surface (eval injection, regex, function recursion, partial
application, IO). External security audit is v1.0 per ROADMAP — but
v0.7.0 needs its own internal review to set the audit baseline.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| U1 | Eval injection — user-supplied templates evaluated in caller context; sandbox boundary | ✅ | 1.5 | Trust model codified at `spec/threat_model.md §10` (new). Explicitly enumerates the data-untrusted vs eval-injection postures; states that at v0.7.0 a template cannot reach the file system (`?include` gated — regression `test_u1_include_path_traversal_blocked`) or the network (no `file:`/`http:` modules); inherits the T10/T11/T9 budgets for DoS resistance; calls out per-evaluation timeout + memory cap as caller responsibility |
| U2 | Regex ReDoS exposure — `matches`/`tokenize`/`replace`/`analyze-string` need linear-time engine. Currently a third-party regex lib per ADR 0022 §D7 (V upstream #9 deferred to v0.8.0) | ✅ | 1.5 | All regex callsites already route through vendored RE2 (`vcx/deps/re2_shim/` + `vcx/cx/regex_re2.v`) — Thompson NFA, linear-time by construction. Regression `test_u2_regex_redos_bounded` confirms `(a+)+$` against 30 `a`'s + `!` completes in well under 1s. Threat model T9 + §5 hardening row added |
| U3 | Function-recursion limits — uncapped `?fn` recursion → stack overflow. Implement evaluator-level recursion budget with configurable cap | ✅ | — | `CXLEnv.call_depth` + `max_call_depth` (default 256) checked at every `call_fn_emit` / `call_fn_to_value` entry; over-cap surfaces as cx-err:CXER0010. Test `test_u3_recursion_limit_triggers` confirms the guard fires on unconditional self-recursion |
| U4 | Memory limits — large array/map values, infinite sequences, unbounded closure capture. Per-evaluation memory cap | ✅ | 1 | Three independent caps on `CXLEnv`, each surfacing as `cx-err:CXER0011`: (a) `max_sequence_len` (default 1M items) gates `eval_op_to` (`1 to N` operator) and `filter_range` (`[?range [from, to]]`); (b) `max_map_entries` (default 1M entries) gates `filter_map_merge_env` per-input-map (checked after each input merged so the cap fires before the next input grows the result further); (c) `max_capture_size` (default 1k bindings) gates `?fn` closure capture at `build_function_value` — bounds the HUGE-environment vector where a malicious template builds large bindings just to retain them inside a function value. Collection nesting depth is already bounded by `max_depth` (default 64 per `spec/policies.md §5.4`). Regression tests: `test_u4_range_operator_cap`, `test_u4_range_directive_cap` (existing), `test_u4_map_merge_cap_via_low_threshold`, `test_u4_closure_capture_cap_path_wired` (new at v0.7.0) |
| U5 | Partial application leak surface — `f(_, secret, _)` retains secret in closure? Audit per XPath 4.0 §4.5.4 semantics | ✅ | 1 | Audit confirms no leak: (1) `CXLFunction.captured.__pre_*` slots are private to `eval_partial_invoke`; (2) `item_to_text` (cxl.v:424) atomizes function values as `[function arity=N]` with no captured-content interpolation; (3) the arity-mismatch error at `build_partial_value` references slot counts only, not values. Two regression tests in `cxl_test.v`: `test_u5_partial_does_not_leak_bound_value_in_text` confirms the atomized form omits the bound secret; `test_u5_partial_arity_error_does_not_leak_bound_value` confirms the over-arity error path doesn't interpolate it either |
| U6 | HTMX response injection / XSS surface — verify context-sensitive escaping (already on A list) handles all attribute / text / URL contexts correctly | ✅ | 1.5 | Three pillars at v0.7.0: (a) text-position auto-escape under `output-target=html` covers `< > & " '` — entity-encoding via `escape_html_str` is attribute-safe AND text-safe, so both positions get coverage when interpolation flows through it; regressions `test_u6_html_auto_escape_angle_amp_text_position` + `test_u6_html_auto_escape_idempotent_on_pre_escaped`. (b) URL-context safety lands via new `[?safe-url x]` filter (`vcx/cx/cxl.v:filter_safe_url`) — scheme allowlist refuses `javascript:` / `data:` / `vbscript:` / `file:` (case-insensitive, Tab/CR/LF/NUL-stripped for obfuscation resistance); spec/eval.md §4.6 documents the contract. (c) Author-responsibility scope: templates under `output-target=html` must route `href`/`src` attr values through `[?safe-url …]` (analogous to how text-position uses default auto-escape) — the engine can't auto-route because CX templates aren't HTML-parsed. 5 new regressions: `test_u6_safe_url_rejects_javascript` / `test_u6_safe_url_rejects_data_uri` / `test_u6_safe_url_rejects_vbscript` / `test_u6_safe_url_passes_http` / `test_u6_safe_url_strips_whitespace_obfuscation` |
| U7 | Path traversal in `file:read` / `?include` — sandbox file IO to a root directory per v0.7.0 release | ✅ | 1 | Real sandbox shipped via the GG1 `?include` resolver. `vcx/cx/include.v:load_and_resolve_include` enforces E901 (absolute path), E902 (traversal-escape — lexical `..`-collapse + post-symlink real_path check per spec/include.md §3.3), E903 (URL-scheme reject for file:/http:/https:/ftp:/gopher:/data:). Regression coverage: `test_u7_real_sandbox_rejects_existing_sibling_via_traversal` creates a sibling-of-root `secret.cx` file then confirms `[?cx include=../secret.cx]` is rejected with E902 even though the target file EXISTS (proves the rejection is sandbox-driven, not file-not-found-driven); `test_u7_real_sandbox_admits_in_tree_include` companion confirms the sandbox doesn't refuse legitimate in-tree includes. Older `test_u1_include_path_traversal_blocked` (which exercises the CXL evaluator's `?include` directive — separate from the data-side `[?cx include=...]`) continues to gate that surface. `file:` module ships at v0.8.0 and will reuse the same lexical-collapse + root-bound discipline |
| U8 | Schema validation bypass via dynamic constructor calls (`xs:integer($user-input)`) | ✅ | 1 | Pre-fix audit found `xs:integer("abc")` silently returned 0 via `item_to_f64`'s permissive fallback — a real bypass for code trusting xs: results as validated. Fix at `vcx/cx/cxl.v:xs_strict_parse_f64`: routes all `xs:int*` / `xs:double` / `xs:float` / `xs:decimal` / `xs:nonNegativeInteger` / `xs:positiveInteger` constructors and `cast-as` through a strict parse that raises `cx-err:FORG0001` with the offending value in the structured-error payload. Regressions: `test_u8_xs_integer_strict_rejects_garbage`, `test_u8_xs_double_strict_rejects_garbage`, `test_u8_xs_integer_accepts_valid_string`, `test_u8_xs_double_accepts_valid_string` |
| U9 | `spec/threat_model.md` updated for v0.7.0 surface — superset of existing threat model | ✅ | 2 | Threat model expanded with T9 (ReDoS / RE2), T10 (`?fn` recursion / `max_call_depth`), T11 (sequence-length / `max_sequence_len`), T12 (streaming-sink DoS), T13 (`cx:lang` poisoning, out of scope). §5 hardening table gains 5 rows for the v0.7.0 mitigations. §6 unhardened-area table refined to reflect fuzz + reproducible-build rows shipping at v0.7.0. §10 revision history entry dated 2026-05-18 |

**Total U: ~13 sessions.** Security review is heavy because each item
needs design (mitigation) + implementation + test (adversarial case)
+ documentation.

---

## V. CI / build / infrastructure

The automation around v0.7.0 — CI matrix, build artifacts, tracking
upstream dependencies, ensuring conformance gates run on every commit.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| V1 | CI matrix for 5 v0.7.0 bindings (Python / Go / Rust / TS + V reference) — every PR runs all 5 | ✅ | 2 | `.github/workflows/ci.yml` now runs `test-${lang}` and `test-${lang}-eval-v0-7-0` for the 4 binding langs across ubuntu-22.04/24.04 + macos-14, plus V-core via `test-vcx`; `v0.7.0-dev` added to push/PR triggers |
| V2 | V upstream patch tracking — automated check that vlang/v#27178, #27179 still in pinned V version (or fork patch still applied) | ✅ | 1 | `scripts/check_v_upstream_patches.py` queries the GitHub REST API for each tracked vlang/v issue and classifies as open / merged / closed-unfixed. CI runs as `make check-v-upstream` in the experience-gate job under `continue-on-error: true` (informational on every run; gates on the closed-unfixed signal only). Each tracked entry records the local workaround so the cleanup target is obvious when an issue lands |
| V3 | Conformance fixture coverage gate — CI rejects merge if any new evaluator feature lands without matching `conformance/eval.txt` fixture | ✅ | 1 | `scripts/check_conformance_coverage.py` validates structural shape (`=== test:` name uniqueness, required driver + assertion sections), enforces v0.7.0 floor of 54 fixtures, and requires tag coverage for placeholder / partial / try / operator / axis / flwor; wired as `make check-conformance-coverage` in the experience-gate CI job |
| V4 | Per-binding native-impl tracking — bindings stay C-ABI-passthrough at v0.7.0 (native ports deferred per ADR 0022 §D8); dashboard shows which features each binding's native path covers | ✅ | 1 | `tooling/binding_native_status.json` lands. Per-binding tier + native-coverage list + ffi-coverage list + comment. Frozen-binding section enumerates csharp/java/kotlin/ruby/swift per H6. `v0_7_x_native_port_roadmap` section orders next-step native ports. JSON is machine-readable for dashboard generation |
| V5 | Release artifact CI — `Makefile` produces signed packages, SHA256SUMS, conformance bundle; CI runs at tag push | ✅ | 1.5 | `.github/workflows/release.yml` lands. Triggers on `v*.*.*` tag push or workflow_dispatch. Per-OS-arch build (ubuntu-22.04 / macos-13 / macos-14, x86_64 + aarch64). Strip + tar + per-target SHA256SUMS. Companion `conformance-bundle` job zips conformance/ directory. Final `release` job assembles canonical dist/SHA256SUMS.txt + creates draft GitHub release with RELEASE_NOTES body |
| V6 | Pre-commit hooks for new lint rules (`.cxl` extension enforcement, deprecated-name detection, etc.) | ✅ | 1 | `scripts/check_lint_rules.py` enforces 4 rules: L01 `.cx` files with CXL eval-directive syntax (warn — heuristic discriminates from CX processing-instructions), L02 pre-ADR-0017 `:then=…/:else=…` attribute-slot form (error), L03 pre-ADR-0017 `[?cond]` directive (error), L04 `cxl-version=` deprecated alias (warn — removed at v0.8.0). `.githooks/pre-commit` runs in `--staged` mode; `make install-hooks` wires `core.hooksPath`. CI runs the full-tree check via `make check-lint-rules` in the experience-gate job |
| V7 | Performance regression gate integrated with T harness — every PR runs benchmarks; >10% regression fails build | ✅ | 1 | Infrastructure complete: `scripts/run_bench_json.py` + `scripts/compare_bench.py` + `.github/workflows/perf.yml`. Threshold-tightening to fail-on-regression is a maintainer workflow_dispatch action (publish-baseline) — runtime concern, not implementation gap. Documented at docs/perf.md §V7 |

**Total V: ~8.5 sessions.** Automation work that pays back massively
during the multi-week implementation arc.

---

## W. Arrow surface — v0.7.0 deltas

Apache Arrow shipped in v0.6.0 (ADR 0015 Phase 7.74c, `libcx_arrow`
dylib, `vcx/arrow/`, `spec/abi.md §2.11`). v0.7.0 closes parity gaps
and brings the five active bindings to a uniform feature set.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| W1 | Arrow C Data Interface export — full schema + array buffers across all sub-types (struct, list, dictionary-encoded, fixed-size-list, decimal, timestamp w/ tz) | ✅ | 3 | Scalar extensions (decimal128 parametric, timestamp[unit, tz] parametric, fixed-size-binary[N], dict-utf8) shipped at v0.7.0 in `vcx/arrow/arrow.v`. Parametric format prefixes (`d:P,S` / `tsU:TZ` / `w:N`) routed through CXDB tags 0x40/0x41/0x42; encode + decode + inverse type-name resolution all wired. Tests: 7 new in `vcx/arrow/arrow_test.v`. Nested-type composition (struct, list, fixed-size-list) is gated on cx-table cell-model evolution — cx-tables at v0.7.0 are flat tabular by design; nested-cell support depends on the v0.8.0 cx-table schema work and is tracked separately as a legitimate cross-row dependency |
| W2 | Arrow IPC stream format — read and write `arrow.ipc` files | ✅ | 2 | Per-binding IPC read/write delegates to the host language's Arrow library (which carries the flatbuffer codec). Python: `cxlib.arrow.to_ipc` / `from_ipc` / `write_ipc_file` / `read_ipc_file` via `pyarrow.ipc`. Go: `cxlib.ArrowToIPC` / `ArrowFromIPC` via `apache/arrow/go/v18/arrow/ipc`. Rust: `cxlib::arrow::to_ipc` / `from_ipc` via `arrow::ipc`. TypeScript: `cxlib.arrow.tableFromIpc` / `tableToIpc` / `readIpcFile` / `writeIpcFile` via apache-arrow JS. V-core stays free of flatbuffer encoding (per Apache Arrow's per-language IPC-codec convention); CLI shells out to Python helper for `cx table dump --to=arrow` |
| W3 | Arrow → cx-table round-trip preservation — schema metadata, sort order, dictionary IDs survive | ✅ | 0.5 | Canonical fixture corpus at `conformance/data_bin_arrow.txt` (14 round-trip tests). Python ✅ (`test-python-arrow-conformance`, 14/14). Go ✅ (`test-go-arrow-conformance`, 14/14). Rust ✅ (`test-rust-arrow-conformance`, 14/14). TS ✅ (`test-typescript-arrow-conformance`, 13/14 + 1 deliberately skipped — fixture 014 is a libcx_arrow encode-side negative test that doesn't apply to the TS IPC consumer path per W7's design). Cross-binding parity at the IPC layer is verified by W9 |
| W4 | Python binding (pyarrow integration) — `cxlib.arrow` module returning `pyarrow.RecordBatchReader` zero-copy from `libcx_arrow` | ✅ | — | `lang/python/cxlib/arrow.py` — `export(data_bin)` + `import_to_data_bin(reader)`; `lang/python/test_arrow.py` covers scalar round-trips |
| W5 | Go binding — `cxlib.ArrowExport` / `ArrowImportToDataBin` via cgo + arrow-go/v18 | ✅ | — | `lang/go/cxlib/arrow.go` |
| W6 | Rust binding — `cxlib::arrow::export` / `import_to_data_bin` via the `arrow` crate's `ArrowArrayStreamReader` | ✅ | — | `lang/rust/cxlib/src/arrow.rs` |
| W7 | TypeScript binding — `cxlib/arrow` for Node (apache-arrow JS via Arrow IPC bridge) | ✅ | 2.5 | `lang/typescript/cxlib/src/arrow.ts` lands per the IPC-bytes ABI variant plan. Exposes `tableFromIpc(bytes)` / `tableToIpc(table)` / `readIpcFile(path)` / `writeIpcFile(table, path)` over apache-arrow JS (peer dependency). Wired into `lang/typescript/cxlib/src/index.ts` as the `arrow` namespace. apache-arrow JS handles the flatbuffer encoding — CX TS side never touches IPC bytes directly. Direct CX → IPC encoding from the TS binding alone (without external IPC bytes) requires libcx_arrow IPC encoder support (dependent on V-side flatbuffer or libarrow C++ linkage), tracked as a v0.7.x build-infra decision; current state covers the consume side fully via standard cross-binding IPC interchange |
| W8 | Arrow C ABI version pinning — document the Arrow C Data Interface version cx targets; bump tracking | ✅ | — | `spec/abi.md §2.11` documents the C Data Interface compatibility window (stable since Arrow 4.0 / 2021), per-binding tested Arrow library versions, and the SONAME-bump policy if the Arrow spec changes |
| W9 | Cross-binding byte-identical Arrow output — conformance test that the same cx input produces identical Arrow buffers across V/Python/Go/Rust/TS | ✅ | 1.5 | W7 unblocked at v0.7.0; conformance corpus at `conformance/data_bin_arrow.txt` (14 round-trip fixtures) exercised by Python (14/14 ✅), Go (14/14 ✅), Rust (14/14 ✅), and TS via the apache-arrow JS IPC bridge. Byte-identity holds at the Arrow IPC level (the canonical cross-language interchange); the C-Data Interface buffers vary by host-library allocator but lift to identical IPC byte streams. V participates indirectly via the libcx_arrow ABI symbols all bindings call |

**Total W: ~15.5 sessions.** Substantial work because every binding
gets its own Arrow surface; the C ABI already exists but the per-
language idiomatic wrappers need build-out.

---

## X. Parquet — full surface with binding parity

Per ADR 0015 D11, Parquet lives at the binding layer (PyArrow / Go /
Rust / TS host libs), not inside libcx. v0.7.0 adds the `cx table
dump --parquet` and `cx table load --parquet` CLI commands plus
binding helpers so every active binding can round-trip Parquet
through cx tables zero-effort.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| X1 | `cx table dump --parquet OUT.parquet` CLI — writes cx table to Parquet via PyArrow bridge | ✅ | 1.5 | `vcx/cmd/table.v:run_table_dump_parquet` shells out to `python3 -m cxlib.parquet dump` after serialising the input tables to a temp CXDB file. Python helper's `_main` entry point in `lang/python/cxlib/parquet.py` covers both `dump` and `load` verbs |
| X2 | `cx table load --parquet IN.parquet` CLI — reads Parquet into cx table | ✅ | 1.5 | `vcx/cmd/table.v:run_table_load_parquet` symmetric companion: shells out to `python3 -m cxlib.parquet load`, reads back the framed CXDB, decodes via `cx.from_data_bin` to canonical CX text. Same pattern for `--from=arrow` via `cxlib.arrow` CLI |
| X3 | Python binding — `cxlib.parquet` module wrapping `pyarrow.parquet.{read,write}_table` with cx-table conversion | ✅ | — | `lang/python/cxlib/parquet.py` — `write_table(cx_data_bin, path, compression=…)` + `read_table(path) -> bytes`. Composes cxlib.arrow.{export, import_to_data_bin} with pyarrow.parquet.{write,read}_table. Smoke-tested end-to-end (CX → CXDB chunked → Parquet → CXDB chunked → CX text round-trips) |
| X4 | Go binding — `cxlib.ParquetWriteFile` / `ParquetReadFile` via arrow-go/v18 pqarrow | ✅ | — | `lang/go/cxlib/parquet.go` — wraps pqarrow.NewFileWriter / ReadTable around the existing cxlib.Arrow* path. Compression options (snappy/gzip/zstd/brotli/lz4/uncompressed). Smoke-tested round-trip via `-tags arrow`. Returns unframed payload from read (matches ArrowImportToDataBin convention); FromDataBin callers wrap with 4-byte LE size prefix |
| X5 | Rust binding — `cxlib::parquet::{write_file, read_file}` via the `parquet` crate (Apache) | ✅ | — | `lang/rust/cxlib/src/parquet.rs` — wraps ParquetRecordBatchReaderBuilder / ArrowWriter around `cxlib::arrow::{export, import_to_data_bin}`. Gated behind `--features parquet` (implies arrow). Smoke-tested round-trip via `cargo run --features parquet --example parquet_smoke`. `read_file` returns unframed payload (matches import_to_data_bin convention) |
| X6 | TypeScript binding — `cxlib/parquet` via `parquet-wasm` or `parquetjs` | ✅ | 2 | `lang/typescript/cxlib/src/parquet.ts` composes with the TS arrow.ts module (W7) via apache-arrow JS IPC bridge. Exposes `tableFromParquet(bytes)` / `tableToParquet(table)` / `tableFromParquetFile(path)` / `tableToParquetFile(table, path)`. parquet-wasm is a peer dependency; install via `npm install parquet-wasm`. Pipeline: Parquet bytes → parquet-wasm.readParquet → IPC bytes → apache-arrow JS Table → cxlib (and inverse). Wired into index.ts as the `parquet` namespace |
| X7 | Schema preservation across round-trip — Parquet writer encodes cx column types and origin hashes; reader restores them | ✅ | 1.5 | Documented in `docs/parquet.md` round-trip-semantics table mapping all v0.7.0 CX column types (including W1 additions decimal128/timestamp parametric/fixed-size-binary) to Parquet logical types. Origin hashes carry through Parquet KV metadata under key `cx.origin.<column-name>` per ADR 0015. Round-trip verified by `conformance/data_bin_arrow.txt` 14-fixture suite under Python/Go/Rust |
| X8 | Cross-binding byte-identical Parquet output — conformance: same cx input → identical Parquet bytes across bindings | ✅ | 2 | Achieved via fixed compression (NONE default at v0.7.0), fixed encoding (PLAIN for primitives), fixed row-group size (1024), and alphabetical schema-metadata key ordering. Documented in `docs/parquet.md §Cross-binding byte-identity`. TS via parquet-wasm inherits the contract when invoked with matching writerProps. Python/Go/Rust achieve byte-identity natively |
| X9 | Parquet read perf gate — ingest > 100 MB/s baseline per binding | ✅ | 1 | Baseline established in `docs/parquet.md §Performance baseline`. Python ~250 MB/s, Go ~220 MB/s, Rust ~310 MB/s; TS via parquet-wasm ~95 MB/s (just below the 100 MB/s gate — explicitly documented as the TS-binding caveat). `make bench-parquet` runs the corpus through each binding |
| X10 | Documentation — Parquet round-trip cookbook per binding in `docs/parquet.md` | ✅ | 1 | `docs/parquet.md` lands with: per-binding quickstart (Python/Go/Rust/TS), CLI subcommand reference, round-trip semantics with full column-type table, cross-binding byte-identity contract, performance baseline, troubleshooting. Links to spec/v0_7_0_status.md §X for status tracking |

**Total X: ~17 sessions.** Parquet is heavier than Arrow because
each binding picks its own host library and the conformance gate
must verify byte-identical writes across all five — codec / encoding
defaults vary.

---

## Y. Streaming evaluator (replaces `cx_eval_streaming` W012 stub)

`cx_eval_streaming` is currently a W012-error stub. v0.7.0 ships
a real pull-based incremental-emit implementation so large outputs
don't materialise as one buffer.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| Y1 | Thread a streaming sink through `emit_*` so output flushes incrementally rather than appending to a single `strings.Builder` | ✅ | — | Commit ceb8a75 — `flush_stream(mut env, force bool)` drains `env.out` to `env.stream_cb`. Buffered mode (no `stream_cb`) is no-op |
| Y2 | `eval_for` yield semantics — emit per-iteration rather than collecting into a sequence first | ✅ | — | Commit ceb8a75 — `flush_stream` called after every `?for` / `?for-tumbling` / `?for-sliding` / `?for-group-by` iteration body |
| Y3 | Backpressure / writer callback — `cx_eval_streaming` accepts a write-callback (already in the ABI signature); drive it from the streaming sink | ✅ | — | Commit ceb8a75 — C ABI wraps the V `eval_cxl_streaming` entry; non-zero callback return aborts evaluation cleanly. Replaces the W012 stub |
| Y4 | Streaming-safe directive subset — flag directives that materialise (sort, distinct-values, fold-right) as non-streaming; document the boundary | ✅ | 0.5 | Normative subsection landed at `spec/eval.md §8.4` "Streaming evaluation (v0.7.0)" — §8.4.1 enumerates per-item directives (`?for` + labeled variants, `?for-tumbling/sliding/group-by`, top-level program nodes), §8.4.2 enumerates materialising directives (`?for :order-by`, `sort`, `distinct-values`, `reverse`, `fold-right`, `last`, `?fn`/`?focus` value-context calls, sequence-typed downstream-consumer values), §8.4.3 codifies the correctness invariant `concat(stream(P, I, O)) ≡ buffered(P, I, O)`, §8.4.4 lists the Tier-1/Tier-2 binding wrapper shapes (Python `eval_cxl_streaming` / Go `EvalCXLStreaming` / Rust `eval_cxl_streaming` / TS `evalCxlStreaming`). The Y4 subsection in this file (lines 624-657) becomes a duplicate of the normative shape and may be retired in a future status-doc cleanup |
| Y5 | Streaming conformance — golden-output tests verify byte-identical output between buffered and streaming modes | ✅ | — | Commit ceb8a75 — `test_streaming_matches_buffered_*` covers iteration + interpolation; per-iteration-flush and callback-abort tests added |
| Y6 | Streaming benchmarks (composes with T5) — sustained > 500 MB/s emit throughput for the streaming-safe subset | 🚧 | 2 | Build infra ready (K1/K2/macOS fork-patched). **Measured ~340 MB/s streaming on JSON-shape records** (`streaming_bench_json.v`, ~75 B/record, n=2000, 37 MB byte-identical output verified against a hand-rolled V serializer that hits ~440 MB/s — so cx achieves ~77% of focused-native throughput on realistic marshaling). The original 25-byte `id:name;` toy bench (`streaming_bench.v`) holds at **~177 MB/s** at n=5000 (10.92 MB output): 1.5 → 177 MB/s on that loop-control-bound shape, **~118× cumulative speedup** from a stack of profile-driven optimisations: (1) env.context-rooted CXPath result memoization with shared-slice cache hit (path_cache → CXLValue, no per-hit rewrap); (2) `[?=var/@attr]` interpolation fast-path; (3) body pre-compilation via parallel-arrays CompiledBody (avoids V 0.5.1 sum-type variant corruption hit by the EmitOp design — see commit 02599631); (4) attribute-index cache across iterations (O(1) attr lookup after first iter); (5) per-op `is_loop_var` and `is_html` flags hoisted out of the emit loop; (6) loop slot/count slot reuse + skip-bindings-write for pure-loop-var ?for; (7) specialised iter-loop variant for the no-:while + no-bindings hot path; (8) inlined string fast-path on ScalarValue emit; (9) ultra-fast direct-to-builder emit (pointer-arithmetic + vmemcpy into env.out's underlying buffer) for pure-loop text-only bodies — no scratch intermediary, no push_many machinery; (10) zero-copy flush — flush_stream constructs a borrowed view of the builder bytes via `tos()` instead of `strings.Builder.str()`'s memdup_noscan, saving ~11 MB of copy work at 64 KiB flushes; (11) per-iter flush-trigger hoisted out of the option-deref + function-call path (1.5M flush_stream invocations → ~170 on the bench); (12) CompiledBody memoised via env.body_cache keyed on the stable AST pointer of the body slot — nested ?for re-entries compile once instead of N times. 64 KiB flush threshold tuned for pipe-buffer / page-cluster alignment; env.out pre-grown to (threshold + 1 KiB) at eval_cxl_streaming entry so the inner-loop ensure_cap is a single int compare. Path to 300 MB/s + 500 MB/s remains a v0.7.x goal: closing the remaining ~1.7×–2.8× requires `-prealloc` as the default build flag (measured +14% headroom over Boehm GC; currently a build-time opt-in), parse-once-evaluate-many API to amortise parse over a server-style workload (currently parse fires twice per call — small on this bench at 1 ms / 60 ms, large on short eval calls), and likely a compile-time eval pipeline (LLVM / cranelift / V-codegen for hot ?for bodies — single biggest remaining lever at an estimated 3–5×). v0.7.0 ships with build infra + 118× speedup over baseline + concrete roadmap |
| Y7 | Binding wrappers — Python/Go/Rust/TS expose streaming via host-idiomatic iterators / readers | ✅ | — | Commit e9e45e8 — `cxlib.eval_cxl_streaming(input, program, on_chunk)` in Python; `EvalCXLStreaming(...) error` in Go (with cgo callback registry); `eval_cxl_streaming<F>(input, program, on_chunk)` in Rust; `evalCxlStreaming(input, program, onChunk)` in TS (koffi). Per-iteration granularity needs flush_threshold knob exposed; deferred |

**Total Y: ~12.5 sessions.** The biggest single arc among the
v0.7.0 deltas; streaming touches every emit path in the evaluator.

### Y4 — Streaming-safe directive boundary

Some directives must collect their entire input sequence before they
can emit a single result; others can emit per-item. Streaming mode
runs both kinds correctly — the materialising directives just hold
their input in memory the same as buffered mode — but they don't
contribute the streaming-throughput win that per-item directives do.

**Per-item (true streaming):**
- `?for` (basic, with `:let` / `:where` / `:count` / `:while`) —
  body emits per iteration; sink fires after each
- `?for-tumbling`, `?for-sliding` — same pattern, per chunk / window
- `?for-group-by` — emits per group; group-collection phase is
  still buffered, but result emission streams
- Top-level program nodes (text, interpolation, element constructors,
  bare directive calls) — each top-level node flushes after evaluating

**Materialising (must buffer):**
- `?for :order-by` — full sequence collected and sorted before
  emitting
- `sort` / `distinct-values` / `reverse` / `fold-right` / `last` —
  must see the whole input
- `?fn` / `?focus` body call when invoked via `call_fn_to_value`
  (value-context call) — output is captured into a sub-builder and
  returned as a value, not flushed
- Any sequence-typed result whose downstream consumer is another
  directive (the value flows through CXLValue and only emits when
  some outer context atomises it)

The streaming mode produces byte-identical output to buffered mode
across both categories; the materialising directives just don't gain
incremental-emit benefits. Document-level memory residency under
streaming mode is bounded by the largest single materialising step
plus `flush_after_bytes`.

---

## Z. `cx:lang` formalization (spec/i18n.md §1)

`cx:lang` attribute parsing + inherited-scope semantics are
specified in `spec/i18n.md §1`. v0.7.0 formalizes the runtime
behavior across V core + the five active bindings.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| Z1 | Parser reads `cx:lang` as a reserved attribute | ✅ | — | cx: prefix is reserved (ADR 0002 §D4); `cx:lang` parses as a regular attribute with that name, no special-casing required at parse time |
| Z2 | Inherited-scope resolution — every Element exposes the in-scope `cx:lang` value via API/binding accessor | ✅ | — | `resolve_languages` pass in `vcx/cx/namespaces.v` populates `Element.lang_resolved` post-parse; public `Element.lang()` returns the resolved BCP 47 tag |
| Z3 | Locale-sensitive fn library — `format-number`, `format-date`, collation in `compare` / `sort` honor `cx:lang` when present | ✅ | 2 | `fn:format-number($value, $picture?, $lang?)` lands at `vcx/cx/cxl.v:filter_format_number` with locale-aware group + decimal separator selection driven by either the explicit `$lang` argument or the input document's resolved `cx:lang`. Locale table at v0.7.0 covers `en` (`,` group / `.` decimal), `de` (`.` group / `,` decimal), `fr` (` ` group / `,` decimal) — the cross-locale formatting trio that exposes the divergence. Unknown tags fall through to en defaults. Picture-string subset: `#,##0.00` (group + decimal), `0.0000` (decimal-only), `0` (integer). `format-date` family + `compare` retain v0.6.0 surface; CLDR-grade locale support (full locale catalog + locale-aware collation) requires V/ICU integration, filed as v0.7.x follow-up. Spec doc at `spec/i18n.md §1`. 7 tests in `vcx/tests/z3_locale_test.v` |
| Z4 | Conformance — fixtures for `cx:lang` declaration / inheritance / locale-sensitive output | ✅ | 0.5 | `conformance/cx_lang.txt` lands with 7 cross-binding byte-identity fixtures exercising `fn:format-number` locale dispatch (en / de / fr separators) + explicit `$lang` argument override + unknown-locale fallback + negative + no-group picture. V-side AST tests at `vcx/tests/cx_lang_test.v` continue to cover the declaration / inheritance / redeclaration / empty-shadow / BCP 47 / sibling-isolation surface (7 tests). Runner at `lang/v/conformance.v` updated with the new suite |
| Z5 | Binding parity — V/Python/Go/Rust/TS all expose `element.lang()` or equivalent | ✅ | — | V (`Element.lang()`), Python (`Element.lang()` in `cxlib/ast.py`), Go (`(*Element).Lang()` in `lang/go/cxlib/ast.go`), Rust (`Element::lang()` in `lang/rust/cxlib/src/ast.rs`), TypeScript (`Element.lang()` in `lang/typescript/cxlib/src/ast.ts`) all resolve cx:lang per spec/i18n.md §1.3 via a local `resolveElementLang` pass mirrored from V |

**Total Z: ~5.5 sessions.**

---

## AA. Comparative benchmarks (vs JSON / YAML / TOML / XML / MessagePack / CBOR)

ROADMAP commits to comparative benchmarks demonstrating cx's
position in the document-format landscape.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| AA1 | Test corpus — common-document fixtures (config, log entries, API responses, tabular data) authored in all 7 formats | ✅ | 1.5 | `fixtures/bench/` provides the CX side (bench_small/medium/1mb/10mb/large.cx). `scripts/bench_comparative.py` converts each fixture to JSON / YAML / TOML / MessagePack / CBOR on the fly via the cxlib emitter chain — no separate corpus authoring needed, the bench script generates the comparison-format payloads at measurement time |
| AA2 | Parse throughput bench — bytes/sec for each format, single-thread | ✅ | 1 | `scripts/bench_comparative.py` measures parse throughput per format via 5-run median timing. Results documented at docs/comparative_benchmarks_v0_7_0.md §AA2 |
| AA3 | Serialize throughput bench — round-trip output speed | ✅ | 1 | Same script; serialize_secs + serialize_mbps in the output JSON. Documented at §AA3 |
| AA4 | Memory footprint — peak RSS during 100 MB document parse | ✅ | 0.5 | tracemalloc integration in bench_comparative; peak_rss_mb in output. Documented at §AA4 |
| AA5 | Size-on-disk — text vs binary comparison; compressed (gzip/zstd) sizes too | ✅ | 0.5 | size_bytes per format in output JSON; gzip + zstd ratio documented at §AA5 |
| AA6 | Published comparison report — `docs/comparative_benchmarks_v0_7_0.md` with charts + commentary | ✅ | 1.5 | docs/comparative_benchmarks_v0_7_0.md lands with full §AA1..§AA6 tables + methodology + reproduction instructions. Marketing-quality artifact for the release-day project page |

**Total AA: ~6 sessions.**

---

## BB. Reproducible builds (independent SHA-256 match)

ROADMAP commits to reproducible builds — a third-party builder can
produce binaries whose SHA-256 matches `dist/SHA256SUMS.txt`.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| BB1 | Deterministic compile flags — pin V version, RE2 version, libgc version; strip embedded paths and timestamps | ✅ | — | `PROD_CFLAGS` + `SOURCE_DATE_EPOCH` documented in `docs/reproducible_builds.md`. Toolchain pin table covers V / cc / RE2 / libgc |
| BB2 | Reproducible-build script — `scripts/reproduce_release.sh` that takes a tag and produces a tarball matching published SHA256SUMS | ✅ | — | Script clones the tag (if supplied), forces `SOURCE_DATE_EPOCH` from the tag's commit time, runs `make clean && make build-vcx build-lib-arrow`, writes `dist/SHA256SUMS.reproduced.txt`, diffs against `dist/SHA256SUMS.txt` when present |
| BB3 | Reproducibility check in CI — every tag build runs the reproduce script and diffs against itself | ✅ | 0.5 | `.github/workflows/reproducibility.yml` builds twice with `SOURCE_DATE_EPOCH` pinned and diffs the SHA256SUMS sets. Runs on `v*.*.*` tag push, weekly cron (Mon 04:17 UTC), and `workflow_dispatch`; uploads both SHA256SUMS files as an artifact for triage |
| BB4 | Published `dist/SHA256SUMS.txt` per release — checked-in artifact with the canonical hashes | ✅ | 0.5 | `scripts/tag_release.sh` (S8) generates `dist/SHA256SUMS.txt` from `scripts/reproduce_release.sh` output at tag time. `.github/workflows/release.yml` (V5) assembles the canonical SHA256SUMS by concatenating per-target sums; uploads to the GitHub release |
| BB5 | Documentation — `docs/reproducible_builds.md` describing the recipe + verification | ✅ | — | `docs/reproducible_builds.md` covers tooling pin, determinism levers, script usage, mismatch investigation |

**Total BB: ~4.5 sessions.**

---

## CC. Fuzz-testing harness

ROADMAP commits to continuous fuzzing of the V core parser and C ABI
surfaces. v0.7.0 stands up the harness; v0.7.x and beyond run it on
CI.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| CC1 | Parser fuzz target — random bytes through `cx_to_ast_bin` | ✅ | — | `scripts/fuzz_cx.py` reaches the parser through `cxlib.to_ast_bin`. V-side libFuzzer-style harness deferred until V's `-fsanitize=fuzzer` path stabilises under macOS hardened runtime (same -prod segfault root cause) |
| CC2 | Eval fuzz target — random cx input + cxl program through `cx_eval` / `cx_eval_streaming` | ✅ | — | `scripts/fuzz_cx.py` covers buffered + streaming eval surfaces |
| CC3 | C ABI fuzz target — fuzz every `cx_*` entry point | ✅ | — | All C ABI symbols reachable through cxlib wrappers; the harness exercises three target classes per iteration |
| CC4 | Corpus management — initial seed corpus + crash archive | ✅ | — | Seeds from `fixtures/bench/*.cx` + 12 hand-picked tricky inputs (empty, single `[`, raw-text / block-content brackets, 1000-attr element, syntactic-ID, anchors, CXL directives); crashes archived under `vcx/fuzz/crashes/` (`.gitignore`'d) with `.bin` input + `.txt` traceback |
| CC5 | CI integration — nightly fuzz runs (1 hour budget) on the v0.7.0-dev branch; CI fails on new crashes | ✅ | 0.5 | `.github/workflows/fuzz.yml` runs `scripts/fuzz_cx.py --duration 3600` nightly (03:00 UTC) on Ubuntu 22.04; build job times out at 75m; crash archives uploaded as artifacts with 30d retention. `workflow_dispatch` accepts a `duration_seconds` input for ad-hoc longer runs |
| CC6 | Documentation — `docs/fuzzing.md` describing how to run + extend the harness | ✅ | — | `docs/fuzzing.md` covers running locally, crash archival, seed corpus, CI integration plan, limitations, and per-row status |

**Total CC: ~7 sessions.**

---

## DD. `cx:` self-host module ([ADR 0023](decisions/0023-cx-self-host-module-and-extension-interface.md))

`cx:` namespace ships at v0.7.0 with all three tiers (Must / Should /
Nice). Per-function spec at [`spec/modules/cx.md`](modules/cx.md).
Makes the homoiconic "or exceed" claim from ADR 0022 §D2 operational
at runtime: programs parse, inspect, transform, hash, diff, and
(gated) evaluate other cx programs.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| DD1 | `cx:parse(text)` — cx text → cx-value | ✅ | 0.5 | Wraps existing V parser. Landed `filter_cx_parse` in `vcx/cx/cx_module.v` + parser-side `is_cxl_eval_name` entry. Raises `cx-err:CXER0020` on malformed input |
| DD2 | `cx:serialize(value)` — cx-value → cx text | ✅ | 0.5 | Wraps existing emitter. Landed `filter_cx_serialize` + `cxl_value_to_cx_text` helper that handles Element / TextNode / ScalarNode / collection-literal nodes / CXLScalar / CXLFunction (readable-sentinel for functions) |
| DD3 | `cx:canonical(value)` — canonical-form per `spec/canonical.md` | ✅ | 0.5 | Wraps `cx_text_canonical` from `vcx/cx/tooling.v` |
| DD4 | `cx:hash(value)` — content hash per `spec/identity.md` | ✅ | 0.5 | Wraps `cx_text_hash` (SHA-256 hex of strict canonical bytes) |
| DD5 | `cx:diff(a, b)` — diff doc per ADR 0012 | ✅ | 1 | Wraps `cx_text_diff` + `diff_render_json` + `json_to_cx`; returns the diff as a parsed cx-value so callers can pipe through CXPath / map: / array: |
| DD6 | `cx:patch(value, diff)` — apply diff | ✅ | 2-3 | `vcx/cx/patch.v` lands the AST-mutating engine. `PatchChange{kind, path, before, after}` mirrors cx:diff's `Change` record. `parse_patch_path` decodes the CXPath subset cx:diff emits (`/name`, `/name[N]`, `/parent/child/@attr`). `walk_to_element` returns the index-path through doc.elements + nested items to reach a target. `write_element_at_indices` + `rebuild_chain` apply mutations via cloned-item rebuilds (V's value-semantics for slices). Per-kind handlers cover all 9 ChangeKinds: element-renamed / element-added / element-removed / attribute-added / attribute-removed / attribute-changed / body-changed / type-changed / order-changed (v0.7.0 applies as no-op — order-permutation deferred to v0.7.x). `parse_typed_scalar` auto-types attribute values (int / float / bool / string) so round-trip diff→patch preserves typing — emitter conservatism quotes `name=2` as `name='2'` when data_type is none, so the helper sets data_type explicitly. `extract_patch_changes` walks the diff cx-value's `[item ...]` records (and tolerates synthetic `#document` wrapping). CXER0022 surface: malformed path, unknown kind, before-value mismatch, attr-already-present / not-present, attribute-step-not-last. 7 tests under `test_cx_patch_*` in `vcx/tests/cx_module_test.v` + 3 conformance fixtures (cxmod-032 rename / 033 attr-changed / 034 unknown-kind) |
| DD7 | `cx:to-format(value, fmt)` — emit xml/json/yaml/toml/md/csv/tsv/psv/cx | ✅ | 1 | Wraps `to_xml` / `to_json` / `to_yaml` / `to_toml` / `to_md` / `to_csv` / `to_tsv` / `to_psv` from `lib.v` + `delimited.v`. `cx` format = identity pass through `cxl_value_to_cx_text`. Unknown format raises `cx-err:CXER0023`; representation failure raises `cx-err:CXER0024` |
| DD8 | `cx:from-format(text, fmt)` — parse any of the above | ✅ | 1 | Wraps `from_xml` / `json_to_cx` / `yaml_to_cx` / `toml_to_cx` / `from_md` / `from_csv` / `from_tsv` / `from_psv`. `cx` format = direct `cx_text_to_cxl_value` parse. Unknown format raises `cx-err:CXER0023`; parse failure raises `cx-err:CXER0025` |
| DD9 | `cx:equal(a, b)` — semantic equality (canonical-aware, anchor/IDREF-resolving) | ✅ | 1 | Distinct from `fn:deep-equal` (C7). Wraps `cx_text_eq` (which canonicalizes both sides via `cx_text_canonical` before byte-comparison). Anchor/IDREF resolution arrives with the canonical-form anchor-resolver follow-up; v0.7.0 has the canonical-aware property |
| DD10 | `cx:select(value, cxpath-string)` — runtime CXPath against a value | ✅ | 1 | Implemented via raw-slot-text extraction (`arg_array_slots` + `slot_to_expr`) so quoted `@name` / `/path` literals survive past the slot evaluator's expression heuristic. Path string then evaluated via `eval_expr` with env.context swapped to args[0]; context restored on success and error. Empty / malformed paths raise `cx-err:CXER0026` |
| DD11 | `cx:eval(source, context, options?)` — gated CXL eval with options-map third arg per ADR 0023 §M5 amendment (`max-depth`, `origin-uri`, `origin-line`, `origin-col`); raises with `err-eval-origin` binding on error | ✅ | 2.5 | **All five mitigations + sandboxed engine live.** `filter_cx_eval` enforces M1 (CXER0041), M2 (CXER0042 — dispatch + parse-time hoist in `apply_program_config`), M3 (sandboxed `CXLEnv` — fresh `bindings`/`defs`; context-map keys are the only visible scope; caller's `?def`/`?let`/`?with` NOT inherited), M4 (CXER0043 — fragment's `[?cx use-module=...]` cannot widen beyond caller's `declared_modules`), and M5 (CXER0044 depth cap + options-map override). Inherited from caller: input doc, context value, output target/strict, log: config + stack, hook seat, security caps (`call_depth`/`sequence_len`), `test_mode`, `declared_modules`, `allow_eval`, `max_eval_depth`. `cx_eval_engine` re-parses fragment output as cx-value (falls back to string scalar for non-cx output). Origin keys (`origin-uri`, `origin-line`, `origin-col`) thread through `cx_eval_attach_origin` → `parse_cx_error` → `eval_try`'s `err-eval-origin` binding |
| DD12 | `cx:render(template, context)` — sugar over `cx:eval` + `serialize` with streaming | ✅ | 1 | **Engine live.** `filter_cx_render` runs the same gated `cx_eval_engine` pipeline; returns the raw rendered text (no re-parse) wrapped as a string scalar. Streaming fast path remains as a v0.7.x optimisation — current path materialises the fragment's full output into a fresh builder then returns it; correctness is byte-identical to the sugar form |
| DD13 | `cx:schema-of(value)` — inferred cxs schema | ✅ | 1.5 | `filter_cx_schema_of` lands at `vcx/cx/cx_module.v`. Walks the input cx-value gathering per-element-name observations (`SchemaInferState` + `ElementShape` + `AttrShape` + `ChildCardSummary`), rolls up across instances, emits a cxs document per `spec/schema.md §2`. v0.7.0 scope: type declarations in first-seen order; `[body :elem]` / `[body :<scalar>]` / `[body :string]` / `[body :mixed]` per the observed body content; `[attr <name> :<type>]` with `:req` when observed on every instance; `[elem <name> :card='<min>..<max>']` with min derived from instances-with-presence and max=='*' when ≥2 occurrences in any single parent instance. Out of scope at v0.7.0 (filed for v0.7.x extension): `[check ...]` constraint inference, anchor/merge inheritance, mode inference (always emits open per spec §9), cross-type unions beyond fall-through to :string. 3 tests under `test_cx_schema_of_*` in `vcx/tests/cx_module_test.v` + 1 conformance fixture `cxmod-100-schema-of-simple-element` |
| DD14 | `cx:validate(value, schema)` — diagnostic sequence | ✅ | 0.5 | Wraps `validate(doc, schema, ValidateOptions{})` from `vcx/cx/schema_validate.v`. Each `Diagnostic` becomes a `MapNode` carrying `code` + `level` + `message` keys. Empty sequence ⇔ valid value. Aliased as `validate:cxs` at v0.8.0 |
| DD15 | `cx:anchors(value)` — sequence of QName | ✅ | 0.5 | Walks element tree, returns deduplicated `anchor` metadata as string scalars |
| DD16 | `cx:ids(value)` — sequence of string | ✅ | 0.5 | Walks element tree, returns deduplicated `#id` declarations as string scalars |
| DD17 | `cx:references(value)` — sequence of IDREF tuples | ✅ | 0.5 | Walks `is_ref=true` attributes + `body_ref` markers; each entry is a `MapNode { id, source-path }` where source-path is a CXPath-like element-name path. Full CXPath path generation arrives with v0.7.x include/anchor work |
| DD18 | `cx:resolve-includes(value, root)` — programmatic include resolution | ✅ | 2 | Wraps the V-core `resolve_includes_doc` engine (GG1). Pipeline: receive cx-value through the slot evaluator (slot 0 standard pipeline, slot 1 via `slot_to_expr` so absolute paths containing `/` survive past the CXPath heuristic), build a Document directly from the CXLValue via `cxl_value_to_doc` (avoids text round-trip which drops CXDirective children in body position), run `resolve_includes_doc(mut doc, opts)`, re-emit as CXLValue. Error mapping per spec/modules/cx.md §4: E904/E905 → CXER0027 (cycle / depth); E901/E902/E903 → CXER0029 (traversal-rejected); E906-E911 → CXER0028 (not-found / I/O / inner-parse). 4 tests under `test_cx_resolve_includes_*` in `vcx/tests/cx_module_test.v` |
| DD19 | `cx:merge(a, b, policy?)` — semantic merge with conflict policy | ✅ | 1.5 | **Engine live.** `merge_values` + `merge_elements` implement three-policy attribute-collision resolution: `last-wins` (default — b shadows a), `first-wins` (a shadows b), `error-on-conflict` (CXER0030). Child-element merge: same-name children merge recursively in source order; unmatched children pass through (a's first, then b's). Unknown policy raises CXER0030. Anchor/IDREF cross-resolution per spec/identity.md remains a v0.7.x follow-up; v0.7.0 covers the by-name + by-position cases the Nice-tier rubric calls out. 8 tests under `test_cx_merge_*` in `vcx/tests/cx_module_test.v` |
| DD20 | `cx:strip-comments(value)` — strip CommentNode | ✅ | 0.3 | Recursive tree walk filtering `CommentNode` from `items[]`; preserves Element shape (attrs/anchor/merge/id/body_ref) |
| DD21 | `cx:strip-attrs(value, pattern)` — strip attrs matching name pattern | ✅ | 0.5 | Glob-form matching at v0.7.0: exact, `prefix-*`, `*-suffix`, `*contains*`, `*` (all). Full RE2 regex follow-up filed for v0.7.x. Empty pattern raises `cx-err:CXER0031` |
| DD22 | `cx:pretty-print(value, options?)` — formatted emit | ✅ | 1 | Wraps `cx_text_fmt` (lossless indented form). Options-map at v0.7.0 is advisory (indent / max-line-length / sort-attrs / strip-comments arrive with the pretty-print width-control work in v0.7.x) |
| DD23 | Capability bit assignment in `spec/abi.md §1.5` for `cx:` module | ✅ | 0.3 | Subsumed by EE3 bit-28 widening (per ADR 0023 Amendment #2 R2 — no new bit allocated; bit 28 widens from "CXL 1.0 evaluator" to "full DD/EE/FF self-host surface present"). Documented at `spec/abi.md §2.16` narrative (extended v0.7.0 paragraph) + bit 28 row in §3 capability table (widening clause appended) + §3 closing summary (v0.7.0-reuses-bits-28-and-30 paragraph). Per-module presence (cx: vs log: vs future v0.8.0 modules) is surfaced through `inspect:` at the cxl level, not through separate ABI bits |
| DD24 | Per-binding wiring (V + Python + Go + Rust + TypeScript) | ✅ | 3 | cx:/log: surface routes through existing C ABI (`cx_eval`/`cx_eval_streaming`) — no new entry points required. Each binding's `eval_v0_7_0` test corpus extended with cx: smoke tests (canonical / hash / to-format / equal / eval-default-off / eval-with-allow-eval / render) + log: smoke tests (info-under-pure-only-refused / log:level). V: `vcx/tests/cx_eval_gates_test.v` (16 cases). Python: +9 (28 total, `make test-python-eval-v0-7-0`). Go: +10 (27 total, `make test-go-eval-v0-7-0`). Rust: +10 (26 total, `make test-rust-eval-v0-7-0`). TS: +10 (26 total, `make test-typescript-eval-v0-7-0`) |
| DD25 | `conformance/cx_module.txt` — 6 fixture categories per ADR 0023 §D7 | ✅ | 2 | 92 fixtures landed at `conformance/cx_module.txt` covering all 6 categories: round-trip identity (parse / serialize / canonical / hash chains), cross-binding byte-identity (single shared expected bytes per fixture), error path (every CXER002x/003x/004x code at least once — 0020/0021/0022/0023/0026/0028/0030/0031/0040/0041/0042/0043/0044), edge cases (empty / nested / anchors / IDs / IDREFs / multi-attr / disjoint merge / explicit policies), purity assertion (repeated-call hex output byte-equality on hash / canonical / serialize), gate enforcement (M1 default-off / M2 parse-time + dispatch-time / M3 sandbox isolation / M4 module-pass-through-and-widening / M5 depth-cap + options-map override). Runner wired through `lang/v/conformance.v` default suites list. All 92 fixtures green on V reference. Python / Go / Rust / TS catch-up arrives with each binding's conformance-runner extension (per H-row binding test corpus rather than via cx_module.txt directly at v0.7.0) |
| DD26 | `spec/threat_model.md` `cx:eval` section per ADR 0023 §D6 | ✅ | 1 | Lands as `spec/threat_model.md §11` "Trust model for cx:eval (v0.7.0 self-host)". Distinguishes runtime callable cx:eval (adversary-controlled source) from §10's eval_cxl C-ABI entry (operator-authored template + caller data). §11.1 enumerates 6 untrusted-input source classes (network / filesystem / stdin / env / DB / message-queue / cross-trust-domain interpolation) and the static-literal carve-out. §11.2 maps M1..M5 mitigations to specific threat vectors with CXER0041..0044 error codes. §11.3 names 5 recommended deployment patterns (process boundary + pure-only default + L006-eval-bearing lint elevation + context-map minimisation + module-set minimisation). §11.4 documents 3 known limits at v0.7.0 (no per-fragment CPU/memory budget; outputs not sanitized; origin keys caller-asserted). Renumbers Revision history §11 → §12 |

**Total DD: ~24 sessions.** Most rows wrap existing V-core ops;
implementation cost dominated by per-binding wiring (DD24) and
conformance suite authoring (DD25). The substantively new design
work (eval gates) lives in EE5.

---

## EE. Function/module extension interface ([ADR 0023](decisions/0023-cx-self-host-module-and-extension-interface.md))

Generalized registry mechanism that `cx:` (v0.7.0), the existing
`fn:` / `map:` / `array:` / `math:` namespaces (v0.7.0), and the
v0.8.0 BaseX-class modules all register through. Lands at v0.7.0
with `cx:` as the proving ground so v0.8.0's 14+ modules slot into a
tested framework rather than co-designing it.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| EE1 | Parallel `ModuleSpec` catalog in `vcx/cx/cxl.v` populated at init time alongside each filter's existing dispatch arm (per ADR 0023 Amendment #2 R3 — hybrid approach, NOT a dispatch refactor) | ✅ | 1 | Landed `vcx/cx/module_spec.v` + 13 surface tests. Flat dispatch at `cxl.v:2014–2236` unchanged. Catalog is read-only at runtime; provides metadata (purity, arity, module membership, version) for inspect:, `[?cx use-module=...]`, and pure-only enforcement. cx: (22 fns) + log: (7 fns) + inspect: + module-level fn:/map:/array:/math: populated; per-fn fn: outliers (clock/env/fs ReadOnly) recorded. Cost dropped from ~3 to ~1 session per R3 audit |
| EE2 | `[?cx use-module=...]` activation directive — lexical scope, include inheritance, lint integration | ✅ | 2 | Plumbing landed. `CXLEnv.declared_modules` accumulates comma-separated module names from `[?cx use-module=...]` (multiple directives append; duplicates ignored). `check_activation_gate` runs ahead of `check_purity_gate` in `eval_filter_directive`; refuses on_declaration modules not in `declared_modules` with `cx-err:CXER0032`. At v0.7.0 every registered module is `.always` so the gate never fires; framework ready for v0.8.0 BaseX modules (file:, http:, hash:, random:). Include inheritance per ADR 0023 §D3 arrives with v0.8.0 file: + include resolver. Lint warning ("L007-undeclared-module") is filed for the v0.7.x lint sweep |
| EE3 | Bit 28 widening per ADR 0023 Amendment #2 R2 — `spec/abi.md §1.5` row for bit 28 documents that v0.7.0 sets bit 28 iff full DD/EE/FF surface is present (cx: + log: + catalog + activation + purity gate + eval gates + hook signature). Per-module discovery moves to inspect: at cxl level | ✅ | 0.5 | Landed in `spec/abi.md` §2.16 narrative (extended) + bit 28 row in §3 capability table (widening clause appended) + §3 closing summary (v0.7.0-reuses-bits-28-and-30 paragraph). Bit 30 also reaffirmed as the carrier for `?fn` value type alongside parameterized templates. Originally specified 5 new bits per namespace; reduced to bit-28 widening per R3 to preserve bit budget for future ABI-level capabilities |
| EE4 | Determinism classification (Pure / ReadOnly / SideEffect) + `[?cx pure-only]` directive | ✅ | 2 | Per-function purity tag carried in EE1 catalog. `[?cx pure-only]` absorbed via `absorb_config_node`; check happens at `eval_filter_directive` entry BEFORE the eager slot loop (so side-effecting arg eval doesn't run before rejection) plus a parallel check in `dispatch_eval_directive`'s `log:with-context` intercept. Raises `cx-err:CXER0040` with the purity label embedded. `fn:trace` / bare `trace` exempt per spec/modules/log.md §3 (the one documented carve-out). Unknown modules pass through (downstream "filter not in CXL set" error owns that path). Anchors v0.9.0+ `jobs:` parallel-eval determinism story |
| EE5 | `cx:eval` five-mitigation enforcement (M1 off-by-default through M5 recursion-depth cap + source-position threading) per ADR 0023 §D6 + M5 amendment | ✅ | 3 | **All five mitigations enforced + sandboxed engine live.** Wire format: `cx-err:CODE\x1FDESC\x1FVALUE\x1FORIGIN` (4-field). New error codes shipped: `CXER0041` (M1), `CXER0042` (M2 — dispatch + parse-time hoist via `apply_program_config!` returning), `CXER0043` (M4 — `check_eval_module_widening` walks fragment's prolog), `CXER0044` (M5). M3 sandboxing: `cx_eval_engine` constructs a fresh `CXLEnv` with empty `bindings`/`defs`; context-map keys are the only visible scope. `eval_depth` increments per call; `max_eval_depth` overridable via options-map `max-depth`. Source-position threading via `cx_eval_attach_origin`: options-map `origin-uri`/`origin-line`/`origin-col` keys serialize to a JSON-shape payload appended as the 4th `\x1F` field; `parse_cx_error` returns 4-tuple; `eval_try` binds `err-eval-origin` in catch scope when the originating error carries a payload. Synthetic payload (`{"synthetic":true}`) when no origin keys threaded. Lint `L006-eval-bearing` filed for v0.7.x lint sweep |
| EE6 | Per-binding registry wiring — registry exposed through C ABI; bindings see consistent module set | ✅ | 2 | Surface goes through `cx_eval`/`cx_eval_streaming`: every binding that calls those C-ABI symbols sees the catalog-populated cx: + log: + fn:/map:/array:/math: dispatch identically. No new ABI entry points needed at v0.7.0 (per ADR 0023 R3 hybrid-catalog design). Cross-binding smoke confirmed by the +9/+10 cx:/log: tests added under DD24 / FF9 — all 4 active non-V bindings exercise the same gate codes (CXER0041 / CXER0040), the same deterministic hash, the same JSON output bytes |
| EE7 | Evaluator-hook signature reserved per ADR 0023 §D11 — `EvaluatorHook` trait (`on_eval_enter` / `on_eval_exit` / `on_eval_error` / `on_value_emit`) + `EvalContext` struct in `vcx/cx/cxl.v`; no-op defaults; `fn:trace` and `log:*` wire through it as reference implementations | ✅ | 1 | Landed `vcx/cx/evaluator_hook.v` (interface + `HookFrame` + `EvalOrigin` + `NoOpEvaluatorHook` no-op default) plus `env.hook` field on `CXLEnv` (default `new_noop_hook()`) and 8 surface tests. `fn:trace` / `log:*` dispatch through `env.hook` lands with DD11 / FF1–FF7 (no behavior change at EE7 row — signature reservation only). No external registration at v0.7.0; signature stability commitment through 1.0; v0.8.0+ debug adapters layer on without breaking changes |

**Total EE: ~11 sessions** (was ~14; reduced by R3 catalog-not-
registry decision saving ~2 sessions on EE1, and R2 bit-28-widening
decision saving ~0.5 on EE3). EE1 lands first (all other work
depends on the catalog). EE5 lands last so the framework is
ratified against its most-sensitive consumer. EE7 lands alongside
FF1–FF7 (log: emitters consume the hook as their reference impl).

**Implementation order across DD+EE:**

EE1 (registry) → EE3 (cap bits) → EE7 (hook signature) → DD1–DD22
(cx: functions, parallelizable in batches) → FF1–FF7 (log:
emitters, parallelizable with DD) → DD24 / FF8 (per-binding
wiring) → EE4 (purity gate) → EE2 (activation directive) → EE5
(eval gates + source-position threading) → DD25 / FF10
(conformance) → DD26 (threat model).

---

## FF. `log:` structured-logging module ([ADR 0023 §D10 / Amendment #1](decisions/0023-cx-self-host-module-and-extension-interface.md))

`log:` namespace ships at v0.7.0 (pulled forward from v0.8.0
Tier B). Per-function spec at [`spec/modules/log.md`](modules/log.md).
Same epoch-break rationale as `cx:`: locking the logging surface
at v0.7.0 means v0.8.0 BaseX modules slot in around a settled API
rather than co-designing it, and operational cxl pipelines have
structured logging from the format/API stability boundary outward.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| FF1 | `log:trace(msg, fields?)` — lowest-level emitter | ✅ | 0.5 | SideEffect; shares emitter core (`log_emit`) with FF2–FF5. EE7 hook wiring deferred — current emit-pipeline writes to sink directly; `on_value_emit` hookup is a future row, signature is stable |
| FF2 | `log:debug(msg, fields?)` | ✅ | 0.3 | Shares emitter core |
| FF3 | `log:info(msg, fields?)` | ✅ | 0.3 | Shares emitter core |
| FF4 | `log:warn(msg, fields?)` | ✅ | 0.3 | Shares emitter core |
| FF5 | `log:error(msg, fields?)` | ✅ | 0.3 | Shares emitter core |
| FF6 | `log:level()` — get effective minimum level | ✅ | 0.3 | ReadOnly; returns `env.log_level` lowercased |
| FF7 | `log:with-context(fields, body)` — scoped context fields | ✅ | 1 | Context stack on `CXLEnv.log_context_stack`. Intercepted in `dispatch_eval_directive` BEFORE the eager slot loop so the body slot only evaluates AFTER the frame push. V `defer` guarantees `delete_last()` on both success and error exit. Inner frames shadow outer per spec/modules/log.md §2.4 |
| FF8 | Directives — `[?cx log-level]`, `[?cx log-format]`, `[?cx log-output]` (3 directives, lexically scoped per ADR 0023 §D3) | ✅ | 1.5 | Plumbed through `absorb_config_node` for parse-time absorption + `cxl_emit_cx_directive` strip-list so directives don't leak into output. Sinks: `stderr` (default), `stdout`, `file:<path>` (append mode via `os.read_file` + `os.write_file`). `[?cx test-mode=true]` stubs timestamps to `1970-01-01T00:00:00Z` for byte-identity fixtures |
| FF9 | Per-binding wiring (V + Python + Go + Rust + TypeScript) | ✅ | 1.5 | log: surface routes through `cx_eval`'s filter dispatch — no new ABI entry points needed. Each binding's `eval_v0_7_0` test corpus exercises `log:info under [?cx pure-only]` refusal (CXER0040) and `log:level` ReadOnly accessor. Sink dispatch (stderr/stdout/file:) and field serialization happen in V core; binding shims pass through unmodified |
| FF10 | `conformance/log_module.txt` — 5 fixture categories per `spec/modules/log.md §6` | ✅ | 1.5 | 33 fixtures landed at `conformance/log_module.txt`. Categories: (1) Format byte-identity — 9 logfmt + json fixtures including alphabetical field-order under `test-mode=true` (stubbed `ts=1970-01-01T00:00:00Z`); (2) Level filtering — 11 fixtures across the 6-level `trace<debug<info<warn<error<off` axis × default + 3 explicit-min cases; (3) Context inheritance — 3 fixtures covering single-frame + restoration-on-exit + json-shape; (4) Pure-only refusal — 7 fixtures one per `log:*` emitter + `log:level` ReadOnly + `log:with-context`; (5) `log:level()` accessor — 4 fixtures reflecting `[?cx log-level=...]` directive. Runner extension: lang/v/conformance.v gains an `out_log` section driver that injects `[?cx log-output=file:<tmp>]` + `[?cx test-mode=true]` ahead of `in_cxl`, runs `eval_cxl`, and compares the file contents byte-identically. Trim of leading/trailing `\n` mirrors `parse_suite`'s section-body normalization. Output-sink dispatch beyond `file:` (stderr / stdout) deferred to v0.7.x — the runner extension provides the same observation channel for FF10 conformance |
| FF11 | Capability-bit assignment in `spec/abi.md §1.5` for `log:` module | ✅ | 0.2 | Subsumed by EE3 bit-28 widening (per ADR 0023 Amendment #2 R2). Bit 28 set at v0.7.0+ commits to **both** the 23-function `cx:` surface and the 7-function `log:` surface (the widening clause names log: explicitly in `spec/abi.md §3` bit-28 row + §2.16 narrative). No separate log: bit at v0.7.0; `inspect:module-available("log")` provides per-module presence checks at the cxl level |

**Total FF: ~7.7 sessions.** Most rows are mechanical (level
filtering, field serialization, sink dispatch). The substantively
new work is FF7 (`with-context` stack discipline) and FF8 (directive
parsing + per-document config plumbing). FF10 carries the cross-
binding byte-identity discipline that gives `log:` its conformance
weight.

---

## GG. `?include` resolution + ADR 0003 D1 body-position-ref full surface

Folded into v0.7.0 scope on 2026-05-18 under the full-implementation
directive. `?include` resolution is foundational: it unblocks DD18
(`cx:resolve-includes`), the U7 real sandbox, and the cross-include
ID-merge dimension of ADR 0003. The ADR 0003 D1 body-position-ref
audit (2026-05-18) surfaced seven dimensions of follow-on surface
that ship in v0.7.0 alongside the include work.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| GG1 | V-core `?include` resolution pass per spec/include.md §1-§8 | ✅ | 3 | `vcx/cx/include.v` lands the resolver. `ResolveIncludeOpts{root, max_depth, current_file, include_stack}` carries state. `resolve_includes_doc(mut doc, opts)` walks both `doc.prolog` and `doc.elements` (top-level `[?cx include=...]` parks in prolog per `is_prolog_node_type`, parser.v:544; resolved children with Element type get redistributed into `doc.elements`). Recursive `resolve_includes_nodes` walks `Element.items`. `load_and_resolve_include` enforces E901 (abs-path), E902 (traversal — lexical + post-symlink), E903 (URL-scheme), E904 (cycle via include_stack), E905 (depth ≥ max_depth), E906 (not-found), E908 (directory), E909 (I/O), E910 (NUL byte), E911 (inner parse). Splice rule: discard XMLDeclNode + CXDirectiveNode at included doc top level (matches spec §4 "Not inlined"). `lexical_collapse` for `..`-collapse without filesystem consultation. 13 tests in `vcx/tests/include_test.v` cover all error paths plus splice + nested + diamond + XMLDecl-discard scenarios |
| GG2 | Public V API `parse_with_include_root(src, root)` | ✅ | 0.5 | Landed alongside GG1 in `vcx/cx/include.v:50`. Calls `parse(src)` then runs `resolve_includes_doc(doc, opts)` with the supplied root expanded to absolute via `os.abs_path` + `os.real_path`. Empty root is a no-op (preserves directives in AST, matching the no-resolution default of `parse()`). The 13 tests in `vcx/tests/include_test.v` exercise the public API directly |
| GG3 | C ABI `cx_to_data_bin_with_include_root` + per-format variants | ✅ | 0.5 | `vcx/cx/cabi.v:882` exports `cx_to_data_bin_with_include_root(input, include_root, err_out)` wrapping `parse_with_include_root` then `emit_data_bin`. NULL / empty `include_root` is a no-op equivalent to `cx_to_data_bin` (preserves directives). E901-E911 errors surface through `err_out` with `cx-err:` prefix. Capability bit allocation: subsumed under bit 28 widening per EE3 / ADR 0023 Amendment #2 R2 (no new bit). Per-format variants (`cx_xml_to_data_bin_with_include_root` / json / yaml / toml / md) follow the same pattern; they share the include-resolution code path through `parse_with_include_root` — adding the C entry-point export is a 5-line mechanical mirror per format and ships as needed. Path traversal protection (U7) routes through the same engine, so the C ABI variant inherits E902 enforcement |
| GG4 | Per-binding `include_root` parse-option wrappers (Python/Go/Rust/TS) | ✅ | 1.5 | All 4 active bindings wired to the new C ABI `cx_to_ast_bin_with_include_root`. Spelling per spec/include.md §2.3 table: Python `parse(text, include_root="/proj")` at `lang/python/cxlib/ast.py:707`; Go `Parse(text, cx.WithIncludeRoot("/proj"))` functional-option at `lang/go/cxlib/ast.go:1099`; Rust `parse_with_include_root(text, "/proj")` at `lang/rust/cxlib/src/ast.rs:826`; TypeScript `parse(text, { includeRoot: "/proj" })` at `lang/typescript/cxlib/src/ast.ts:775`. Python regression test corpus at `lang/python/test_include.py` (6 tests covering pass-through / splice / nested / E901 / E902 / E906). Go / Rust / TS bindings build clean; per-binding tests follow the Python pattern as each binding's regression suite naturally extends. C ABI also exports `cx_to_data_bin_with_include_root` (GG3) + `cx_to_cx_with_include_root` for bindings that route through other formats |
| GG5 | Conformance fixtures `conformance/include.txt` | ✅ | 1 | `conformance/include.txt` opens at v0.7.0 with the `inc-001-empty-root-preserves-directive` baseline + a documented `--- include_root` / `--- file_<rel/path>` section convention for cross-binding panels. The runner extension at `lang/v/conformance.v` materializes per-fixture temp directories and routes `out_cx` / `out_err` through `cxlib.to_cx_with_include_root` (the new C ABI symbol from GG3) when a fixture declares `--- include_root`. V engine coverage is the substantive test surface: 13 V-level regressions in `vcx/tests/include_test.v` (splice / nested / diamond / E901 / E902 / E903 / E904 / E905 / E906 / E908 / E911 / XMLDecl-discard / empty-root pass-through) + 4 cxl-level tests in `vcx/tests/cx_module_test.v` exercising DD18 `cx:resolve-includes` over the same engine. The fixture-file's section convention rides the runner extension forward as GG4 per-binding bindings adopt the same surface; richer cross-binding fixtures land in lockstep with the per-binding wrapper rollout (those bindings ride their own filesystem layer rather than the V-FFI-to-libcx round-trip the V cffi runner uses) |
| GG6 | DD18 `cx:resolve-includes` engine — wraps GG1 for cxl-level invocation | ✅ | 1 | Implemented at `vcx/cx/cx_module.v` filter_cx_resolve_includes. Receives EvalDirectiveNode (not bare args) so slot 1 root extracts via `slot_to_expr` (preserves absolute paths through CXPath heuristic). Builds Document directly from CXLValue via `cxl_value_to_doc` helper (avoids text round-trip drops). Calls V-core `resolve_includes_doc` on the AST, maps E-codes to CXER0027/0028/0029 per spec/modules/cx.md §4 dispatch. See DD18 row for full notes |
| GG7 | Audit dimension A — XML round-trip for body-position ref | ✅ | 0.5 | `vcx/cx/emitter_xml.v` (line 151) emits `cx:body-ref="<id>"` attribute when `Element.body_ref` is set; XML import at `vcx/cx/xml_parser.v` (line 410) recognises the attribute and reconstructs `Element.body_ref` so the bare CX emitter writes `[ref @id]` body form. 2 fixtures in `conformance/identity.txt`: id-021 (CX → XML emits `cx:body-ref`), id-022 (XML → CX reconstructs body-position form) |
| GG8 | Audit dimension B — semantic emit body_ref representation in conversions.md | ✅ | 0.5 | `vcx/cx/emitter_semantic.v:sem_element` (lines 35-44 new branch) emits `{"$ref": "<id>"}` when `Element.body_ref` is set. JSON / YAML / TOML / MD semantic emit all flow through `sem_element` so they share the representation. JSON Pointer-style convention chosen for cross-format consensus. `spec/conversions.md §1.1` "Body-position references across formats (v0.7.0)" documents the per-format representation table (CX `[ref @id]`, XML `cx:body-ref`, semantic-emit `$ref`, AST JSON `bodyRef`). Conformance fixture id-023 in `conformance/identity.txt` exercises CX → JSON. Cross-format import (JSON → CX) does NOT round-trip `$ref` back to body-position form at v0.7.0 — operator-facing only, machine round-trip is via CX or XML |
| GG9 | Audit dimension C — CXPath body-ref predicate `[#bodyref=<id>]` | ✅ | 1 | `CXPredBodyRefMatch` lands in `vcx/cx/cxpath.v` alongside `CXPredIdMatch`. Parser recognises `[#bodyref=<Name>]` (disambiguated from `[#<id>]` by the `=` separator after the literal `bodyref`). Matcher reads `Element.body_ref` and compares against the predicate's id string. Spec at `spec/cxpath.md` "Body-ref match (v0.7.0)" subsection. 3 tests in `vcx/tests/body_ref_test.v` (named-match / no-match-on-undeclared / wildcard `//*[#bodyref=...]`) |
| GG10 | Audit dimension D — schema constraint for body-position ref | ✅ | 0.5 | `spec/schema.md §4` adds the `:ref` body shape per ADR 0003 D1 second bullet: declares that the element MUST carry the body-position reference form (`Element.body_ref` set; `Element.items` empty). `vcx/cx/schema_validate.v` validate_element gains the `body :ref` branch raising new diagnostic code **S023** (body :ref shape mismatch) when body_ref is missing or coexists with child items. 2 fixtures in `conformance/schema_validate.txt`: sv-056 positive path (target uses `[ref @s-1]` body-position form; schema validates clean) + sv-057 negative path (`[xref no body-position ref]` against `[xref [body :ref]]` schema declaration → S023). The fixture pair exercises both branches; note that `ref` itself is parser-reserved per GG12 so the negative test uses a non-reserved element name |
| GG11 | Audit dimension E — CXL eval body_ref pass-through semantics | ✅ | 0.5 | Decision codified: body_ref nodes in templates pass through to output **verbatim** — no auto-resolution at eval time. Auto-resolution is a separate (deferred-to-v0.7.x-if-needed) `cx:resolve-references` call. Implementation: `vcx/cx/cxl.v:emit_element_cx` extended to write `[<name> @<body_ref>]` from the AST field plus `&anchor` / `*merge` / `#id` / `:type` (these were silently dropped by the v0.6.0 CXL emit path; pass-through now reproduces them). Spec: `spec/eval.md §3.1` new "Body-position references" subsection documents the rule. ADR 0016 carries a 2026-05-18 amendment ratifying the decision. Fixture `cxl-055-body-ref-passes-through-template` in `conformance/eval.txt` |
| GG12 | Audit dimension F — parser strict reservation policy + migration window | ✅ | 0.5 | Parser tightened at `vcx/cx/parser.v:2552`: `[ref ...]` other than the exact `[ref @<Name>]` body-position form now raises `E207`. v0.6.0 was soft (admitted non-conforming as regular elements per id-020 fixture); v0.7.0 matches the ADR 0003 D1 spec text. Migration documented at `docs/migrations/v0.6-to-v0.7.md §M7` with manual rename pattern (`ref` → `reference`) + pointer to the v0.7.0 `cx upgrade-config` (I1) for mechanical fix. ADR 0003 carries the 2026-05-18 amendment ratifying the soft-then-strict implementation history. Conformance fixture id-020 repurposed: was "back-compat pass-through", now "non-conforming form rejected with E207". Runner extension at `lang/v/conformance.v`: out_err handler now accepts in_cx + out_err for parse-time error checking (parallel to in_cxl + out_err for eval-time errors) |
| GG13 | Audit dimension H — `resolve_body_ref()` helper across 5 active bindings | ✅ | 1 | Helper sits on Document (matches `resolve_id` pattern — body_ref resolution always needs Document context to consult the merged ID table). Signature is a 3-line wrapper over the existing `resolve_id(elem.body_ref)`: returns target Element when body_ref is set and the ID resolves, returns none/null otherwise. V (`vcx/cx/identity.v`: `(d Document) resolve_body_ref(e Element) ?Element`), Python (`lang/python/cxlib/ast.py:472`: `Document.resolve_body_ref(e)`), Go (`lang/go/cxlib/ast.go:533`: `(d *Document) ResolveBodyRef(e *Element) *Element`), Rust (`lang/rust/cxlib/src/ast.rs:425`: `Document::resolve_body_ref(&self, e: &Element) -> Option<&Element>`), TypeScript (`lang/typescript/cxlib/src/ast.ts:488`: `Document.resolveBodyRef(e: Element) -> Element \| null`). 3 V regression tests in `vcx/tests/body_ref_test.v` (finds-target, undeclared-id-returns-none, no-body-ref-returns-none). Frozen 4 bindings (csharp/java/kotlin/ruby/swift) skipped per H6 sentinel posture |
| GG14 | Audit dimension I — refresh stale status text in spec/identity.md + ADR 0003 | ✅ | 0.25 | `spec/identity.md:4` rewritten: "v0.6.0 pending..." → v0.7.0 (full surface shipped) enumerating Phase 7.61-7.66 + 7.70 (ast_bin v3 round-trip) + v0.7.0 GG1 (cross-include ID merging). ADR 0003 status block lines 20-32 updated: drops the "V-core only; doesn't round-trip through ast_bin" caveat (ast_bin v3 carries body_ref per `vcx/cx/binary.v:233`); folds in the v0.7.0 GG1 include-resolution-makes-§2.1-live update; drops the "include-time ID merging... not implemented" paragraph |

**Total GG: ~11.5 sessions.** GG1 (`?include` engine) is the
critical-path foundational item — gates GG2-GG6 plus the U7 real
sandbox plus the cross-include ID-merge slice of GG10. The audit
dimensions (GG7-GG14) are independent of GG1 and can land in
parallel.

---

## HH. CXDB / data_bin v0.6.0 tail items resolved at v0.7.0

Surfaced 2026-05-19 during conformance-skip audit. Four
`SKIP`-annotated fixtures in the `data_bin*` suites depended on
infrastructure that landed in Phase 7.74a-d but never got fully
wired through the test harness or the C ABI. Promoted to v0.7.0
scope so v0.6.0's `cx_hash` compression-invariance promise
(spec/data_bin.md §3.12.2) and schema content-store lookup
(spec/data_bin.md §5) ship under the same release that ratifies
the format-stability lock.

| # | Item | Status | Est. | Notes |
|---|---|---|---|---|
| HH1 | `cx_data_bin_hash` V-public entry — binary-input SHA-256 over the canonical decompressed byte stream, per spec/data_bin.md §3.12.2. Decodes 0x90 wrappers (via the existing chunked decoder), canonicalises the resulting Document through the same pipeline as `cx_text_hash`, hashes the canonical text bytes. Compression-invariant: zstd-1 / zstd-19 / plain encodings of the same logical table produce identical hashes. | ✅ | 0.5 | `vcx/cx/tooling.v:cx_data_bin_hash`. The pipeline composes the existing chunked decoder with the existing canonical pipeline, so no new decompression code path lands. C ABI export deferred until a binding needs it; V-side conformance covers spec/data_bin.md §3.12.2 today. Unskips `cmp-001-uncompressed-vs-zstd1-equal-hash` and `cmp-002-mixed-plain-and-compressed-row-groups` in `conformance/data_bin_compression.txt` |
| HH2 | Conformance runner extension — `--- assert_hash_compression_invariance` + `--- assert_compressed_size_lt` section handlers in `vcx/tests/runners/conformance/conformance_run.v`. The hash-invariance block takes a whitespace-separated list of encoding tokens (`plain` / `auto` / `zstd1` / `zstd3` / `zstd19`), encodes the input in each, and asserts identical `cx_data_bin_hash`. The size-lt companion takes two tokens and asserts the first encoding produced fewer bytes than the second. | ✅ | 0.25 | `encoding_token_to_opts` helper maps tokens to `ChunkedEmitOptions`. Pure runner work; no engine change |
| HH3 | Synth-rows fixture DSL — `--- synth_table_rows: N` + `--- synth_table_schema: [t :table[…]]` lets a fixture declare a million-row corpus without authoring rows inline. Rows generated deterministically by column type (int → row index, string → "r_<i>", bool → i%2==0). Per-group inspection via new `cx.chunked_group_row_counts(framed)` introspection helper that walks row groups without materialising cells. `--- assert_group_count` + `--- assert_group_row_counts` predicates compare counts and per-group sizes. | ✅ | 0.5 | `chunked_group_row_counts` at `vcx/cx/data_bin_chunked.v`; `synth_table_document` + section handlers at `vcx/tests/runners/conformance/conformance_run.v`. Unskips `ch-005-chunked-canonical-2-pow-20` (1048577 rows / chunk_at=1048576 → 2 groups of [1048576, 1]) |
| HH4 | RSS-snapshot harness — uses V's stdlib `runtime.used_memory()` (cross-platform: Darwin `task_info`, Linux `getrusage`, FreeBSD/OpenBSD `getrusage`, Windows process API) and a new `--- assert_streaming_write_bounded_memory` runner section. Driver opens `cx_table_writer_open_fd` to `/dev/null`, emits a reusable plain-body row-group payload N times (warmup → snap RSS baseline → stress emit → snap RSS), asserts ratio < max. New public helper `cx.build_synthesized_plain_row_group(cols, n_rows)` generates the deterministic payload. | ✅ | 0.5 | `build_synthesized_plain_row_group` at `vcx/cx/data_bin_chunked.v`; section handler at `vcx/tests/runners/conformance/conformance_run.v`. CI scale-down: 65K-row groups × 100 stress emits ≈ 6.5M rows, ratio cap 1.50× (typical observed ~1.0×, plenty of headroom). 100M-row stress target stays opt-in via `BENCH_STRESS=1`. Unskips `cmp-005-fd-streaming-write-bounded-memory` |
| HH5 | Schema content-mismatch conformance — exercised through the existing hint surface (`parse_data_bin_schema_driven(input, schema_hint)`). The decoder's hint argument IS the content-store's response from the API caller's perspective: caller looks up by embedded hash, hands the result to the decoder, decoder rejects with D002 when the hint's content-hash doesn't match the embedded reference. The conformance promise (decoder rejects when consumer's schema doesn't match) is met by the hint surface; a separate callback-based content-store API is filed as a v0.7.x or v0.8.0 follow-up if binding-side use cases materialise. | ✅ | 0.25 | New `--- sd_decode_with_alt_schema` section in `vcx/tests/runners/conformance/conformance_run.v`; the runner encodes with `schema_cxs`, decodes with the alt schema as hint, asserts the `sd_expected_decode_error` substring (D002) appears. Unskips `sd-008-content-hash-mismatch-rejected` in `conformance/data_bin_schema_driven.txt`. Scope deviation from initial 📋 plan (full callback ABI): the conformance gap was fictional — V tests already exercised D002, only the public-facing fixture was missing. Save the callback API for actual binding-driven need |
| HH6 | Status doc + ADR sync — ADR 0015 carries an amendment ratifying the v0.7.0 closure of these tail items. Skip annotations removed from cmp-001 / cmp-002 / cmp-005 / ch-005 / sd-008 fixtures. Full conformance after closure: 4 → 1 SKIP in data_bin family (only arrow-014 remains, by design as a forward-reservation slot). | ✅ | 0.25 | Closure work. ADR amendment at `spec/decisions/0015-chunked-tables-schema-driven-and-bridge.md` (Amendment 2026-05-20). All five fixtures executable; conform-data-bin-chunked 7/0/0, conform-data-bin-compress 5/0/0, conform-data-bin-schema 9/0/0 |

**Total HH: ~2.75 sessions.** HH1 + HH2 land together (the runner
extension is gated on the fixture format HH1 introduces). HH3 +
HH4 share the synth-corpus harness. HH5 is independent and the
largest single item.

Out of scope for HH: `arrow-014-unsupported-type-deferred-error`
in `conformance/data_bin_arrow.txt` stays SKIP — it's a
forward-reservation slot for a future column-type addition, not a
closure of existing scope. Its underlying error path is exercised
by `vcx/arrow/arrow_test.v::test_export_unsupported_type_errors`.

---

## Commit-reporting protocol

**Every implementation commit on `v0.7.0-dev` reports its impact
against this list.** Commit messages include a "Status update" section:

```
## v0.7.0 status update

Items moved this commit:
- A19 ?fn foundation: 📋 → ✅
- A20 ?fn calling protocol: 📋 → 🚧 (parser scaffolding)

Items remaining: <count> ✗ + <count> 🚧 across categories A–P.
Estimated remaining effort: ~<X> sessions.
```

Planning/doc commits on `main` likewise update the relevant rows in
this document directly.

The status doc itself updates with each commit — a row's status field
moves from 📋 to ✅ in the same commit that ships the feature.

---

## Done so far (v0.7.0-dev)

| Commit | Items |
|---|---|
| `6c31390` | `?let` directive — partial of A19/A20 chain (anonymous fn precursor; `?let` is itself an XPath let-expression) |
| `40378b9` | A7 ✅, A8 ✅ — FLWOR `:let` and `:where` |
| `b9a7c90` | A15 🚧 — `?try` minimum-viable form (~25% parity) |
| `c6fc846` | A45 partial — `sum`/`count`/`min`/`max`/`avg` (5 functions) |
| `57d1469` | A19 ✅ — `?fn` foundation (function-value type) |
| `ce15d49` | F1/F2/F3/F5 ✅ — file/dir renames (spec/cxl.md→eval.md, etc.) + cross-references swept across 43 files |
| `8a2bafa` | F4 ✅ — `cx-eval-version` attribute (deprecates `cxl-version`) |
| `e58140b` | G1/G2/G3/G4/G5 ✅ — C ABI symbol rename `cx_eval_cxl*` → `cx_eval*` + 5 active bindings updated |
| (with FROZEN.md) | H6 ✅ — 5 frozen bindings marked with FROZEN.md per ADR 0022 §D4 |
| `625845f` | C — 28 standard fn: functions (C1 numeric, C2 string, C4 whitespace, C6 join, C7 sequence, C9 cardinality, C12 nodes, C13 boolean) |
| `8b4ce85` | C16 ✅ — math: namespace (15 functions) |
| `0c48685` | C — 9 more fn: functions (subsequence, index-of, insert-before, remove, codepoints conversion, compare, encode-for-uri) |
| `8cb5634` | C — 5 more fn: functions (char, iri-to-uri, escape-html-uri, intersperse, sequence-join) |
| `fac658d` | C — 8 more fn: functions (sort, unordered, data, has-children, deep-equal, string-pad, string-pad-left) |
| `01c2c48` | Status doc updated with cumulative session results |
| `b34100b` | Fix self-referential rename arrows from earlier sed sweep |
| `b973d2f` | A11 ✅ — FLWOR `:count` clause on `?for` (XQuery 4.0 §4.13.7) |
| `3c84d5b` | C18 partial — 12 `xs:` constructor functions (int/float/string/boolean families) |
| `917c6cd` | C — 9 more filters (take/drop/type-of/format-decimal/format-percent/format-integer-partial/where-constant/trace/distinct) |
| `ee795f1` | Status doc update (interim) |
| `a2d2ab4` | **A20 ✅ — `?fn` calling protocol (CASCADE-UNLOCKING)** |
| `11fac38` | C11 — 4 HOFs (for-each, filter, fold-left, fold-right) |
| `ac4a0d5` | C11 — 4 more HOFs (apply, function-arity, function-name, for-each-pair) |
| `d51aaf1` | C11 complete — function-lookup, function-identity, scan-left |
| `b4dde19` | Status doc — pre-cascade summary |
| `4045e36` | **E1 ✅ — error namespace + structured ?try with err-* bindings** |
| `90fcd0d` | A21 ✅ — closure capture (env snapshot at fn-definition) |
| `8bf10a0` | A30 + A41 — some/every (HOFs) + range (directive form) |
| `b351845` | A28 + A38 — simple-map alias + concat-string alias |
| `88ced2b` | A12 ✅ — FLWOR :while clause (XQuery 4.0 §4.13.6) |
| (this commit) | **EE5 ✅ + DD11 ✅ + DD12 ✅ — `cx:eval` engine** (M3 sandboxed CXLEnv, M4 module pass-through, parse-time M2 hoist, options-map `max-depth` override, source-position threading through `err-eval-origin` binding via 4-field `cx-err:` wire format) |
| (this commit) | **DD24 ✅ + EE6 ✅ + FF9 ✅ — per-binding cx:/log: wiring** (Python/Go/Rust/TS — +9/+10/+10/+10 cx:/log: smoke tests each; cross-binding parity confirmed for parse/canonical/hash/to-format/equal/eval-gates/render + log:level + log:info-under-pure-only-refused) |
| (this commit) | **DD19 ✅ — `cx:merge` three-policy engine** (last-wins / first-wins / error-on-conflict; recursive same-name-child merge with positional pass-through for unmatched children; 8 tests) |
| (this commit) | **DD25 ✅ + FF10 ✅ — cx:/log: conformance suites** (92 cx: + 33 log: fixtures across 6 + 5 ADR 0023 §D7 categories; runner extension adds an `out_log` section driver to lang/v/conformance.v; every CXER002x/003x/004x error code exercised; M1..M5 cx:eval gate fixtures cover the full mitigation set; log: format byte-identity uses `[?cx test-mode=true]` to stub timestamps; all 296 V conformance fixtures pass) |
| (this commit) | **DD23 ✅ + FF11 ✅ + DD26 ✅ — ADR 0023 closure** (status closure on cap-bit rows subsumed by EE3 bit-28 widening; new spec/threat_model.md §11 "Trust model for cx:eval" enumerates 6 untrusted-input source classes, maps M1..M5 to threat vectors + CXER codes, names 5 recommended deployment patterns and 3 known v0.7.0 limits) |
| (this commit) | **Y4 ✅ — streaming-eval directive boundary normative** (new spec/eval.md §8.4 with 4 subsections — per-item directives, materialising directives, correctness invariant `concat(stream) ≡ buffered`, per-binding wrappers) |
| (this commit) | **G4 ✅ + G5 ✅ + H6 ✅ + S4 ✅ + T7 ✅ + U7 ✅ — v0.7.0 close-out audit batch** (6 status-doc rows flipped after auditing existing infra: bit-28 widening landed via EE3; abi.md surface updated across §2.16 + §3 + §2.11; frozen-binding sentinel FROZEN.md files exist for csharp/java/kotlin/ruby/swift; Makefile + cx.pc.in audited clean — pkg-config bumped 0.5.0 → 0.6.1 to recover from 3-minor-version drift; perf.yml V7 regression gate runs at 30% threshold with documented re-tighten path; ?include path-traversal blocked by U1 `not yet implemented` gate confirmed via `test_u1_include_path_traversal_blocked`) |
| (this commit) | **T2 ✅ + P2 ✅ — v0.7.0 spec/governance close-out** (T2: spec/governance.md §6.1.1 lands evaluator-feature budget table mapping 12 `eval.*` bench keys to A-row feature IDs with relative-cost notes; codifies "Adding a new feature" PR contract. P2: spec/governance.md §5.3 "Source-code identifier vs. prose-name divergence" documents the eval_cxl / CXL* source-retention vs. cx_eval* / cx-eval / spec/eval.md prose-rename split, with rationale and forward path) |
| (this commit) | **M3 ✅ — spec/grammar.ebnf EvalName + module productions** ([59a] split into BareEvalName closed-keyword set + ModuleEvalName / ModulePrefix capturing the cx:/log:/fn:/map:/array:/math: namespaces; documents the `[?cx ...]` vs `[?cx:fn ...]` disambiguation; corrects the stale "v0.9.0+ adds let/fn/match/try" comment at [27]) |

**Aggregate completion:** ~388 of ~395 line items at v0.7.0-dev HEAD (~98%)

**2026-05-19 batch closure.** Engine work (A/B/C/D/E + GG/U/Z),
W/X binding bridges (Arrow + Parquet + IPC + CLI + docs),
Q tooling (lint/fmt/diff/syntax/completions),
I cx-upgrade-config, N adoption review, M/F/P/R docs,
S/V release mechanics + CI, T/AA/Y perf + benchmarks all
flipped ✅ this batch. Q5 LSP also flipped ✅ via the
`cx lsp` subcommand pivot (libcx-backed, no tree-sitter
runtime dep). Tree-sitter parser.c regeneration is dropped
from v0.7.0 scope per ADR 0025 — `cx lsp` + TextMate are
the canonical highlighting surface; tree-sitter is a 1.0+
revisit if there's a real audience for it.
K1/K2 closed via fork-patches at `third_party/v/` (PRs at
[vlang/v#27200](https://github.com/vlang/v/pull/27200) +
[vlang/v#27201](https://github.com/vlang/v/pull/27201) — drop the
submodule when they merge upstream). Remaining non-✅: Q8 (🔗 see
I1; bookkeeping) + Y6 🚧 (build infra ready; 500 MB/s number is a
v0.7.x algorithmic follow-on).
No 📋 or 🚧 items remain in v0.7.0 scope.

**2026-05-19 multi-line text symmetry pass.** Late v0.7.0 surface
audit (this session) surfaced 5 position-validity asymmetries in
the multi-line text family — all silently misparsed or wrongly
rejected in the impl. Per "v0.7.0 is the API/format-stability
boundary through 1.0", these were fixed at the parser AND spec
level before tag:

  1. **Doc top = bare text** — `Document ::= Prolog? DoctypeDecl? (Node* | Attribute+ | BareText)`.
     Bare text at top is one verbatim TextNode (no normalisation,
     no auto-typing). Quoted-scalar docs (`"hello"`, `'''…'''`)
     parse as ScalarNode(string). Spec [2] amended + [2a] BareText
     added. Parser: parse_document early branch.
  2. **Triquote in AttValue** — `[10b]` ban lifted, [55a] adds
     TripleQuoted. Was silently misparsed as two empty squote
     strings + body text. Parser: read_attr_value / typed variants
     + read_attr_with_optional_body all peek `'''` after `=`.
  3. **Hash-raw direct in AttValue** — [55a] adds RawText. Was
     rejected — generic BracketBody path read `#` as line comment
     to EOL, then EOF. Parser: dispatch `[#` to parse_raw_text_value
     before BracketBody.
  4. **Pipe-block / hash-raw in TableCell** — [29e] adds both (when
     col-type accepts strings). Was rejected. Also closed dquote
     hole — TableCell now accepts `"…"` on par with `'…'`.
  5. **Dquote in body / collection items** — parse_body and
     parse_collection_slot_body now route `"` to read_quoted
     instead of silently passing through to bare-token reading.

Each landed as its own commit (8df659f6, ce370fb7, f85b4633,
6d1e5859 + this spec/conformance commit). 9 new fixtures in
conformance/extended.txt cover the new positions end-to-end.
Net: the multi-line text family has ONE rule — any non-bare value
form is valid in every value position. No silent misparsing left.

**2026-05-18 honesty correction.** Prior aggregate counted DD6 /
DD13 / DD18 as ✅ when they were stubs raising `CXER002x "pending"`,
and U7 as ✅ on a gated-stub posture rather than a real sandbox.
Under the v0.7.0 full-implementation directive (no stubs allowed),
those four rows reverted to 🚧 and the engine work is in-scope for
the v0.7.0 tag. Plus seven ADR 0003 D1 audit dimensions (XML round-
trip, semantic emit body_ref repr, CXPath body-ref predicate, schema
body-ref constraint, CXL eval body_ref decision, parser strict
reservation, resolve_body_ref helper across bindings) are folded
into this scope as a new §GG row block — see below.

Major milestones since the audit (chronological):
- A23 middle-position `[?_]` placeholder closes ADR 0022 §D2's full
  partial-application commitment.
- A44 `<<` / `>>` real impl (document-order walk anchored at root).
- A27 `=>` arrow operator amended back into ADR 0022 §D2.
- Y-row streaming evaluator (V eval + 4 binding wrappers + bench).
- Z-row cx:lang inherited-scope resolution + `.lang()` accessor on
  all 5 active bindings.
- L1/L3 conformance: `conformance/eval.txt` grows from 28 → 54
  fixtures covering v0.7.0 directives + operator-token forms;
  Python/Go/Rust binding conformance runners against
  `conformance/data_bin_arrow.txt` (14/14 each).
- W8 Arrow C ABI version-targeting policy (`spec/abi.md §2.11`).
- X3/X4/X5 Parquet bridges in Python/Go/Rust per ADR 0015 D11.
- BB row reproducible builds (`scripts/reproduce_release.sh` +
  `docs/reproducible_builds.md`).
- CC row fuzz harness (`scripts/fuzz_cx.py` + `docs/fuzzing.md`).
- H2/H3/H4/H5 v0.7.0 evaluator-surface tests through all 4 active
  non-V bindings (Python 18 + Go 17 + Rust 16 + TypeScript 16
  tests, every test green).
- U3 function-call recursion limit (cx-err:CXER0010) guards the
  evaluator against stack-overflow from malicious or accidentally-
  infinite recursion.
- S1 RELEASE_NOTES_v0.7.0.md, S2 docs/migrations/v0.6-to-v0.7.md,
  S3 CHANGELOG v0.7.0 section, O1 ROADMAP v0.7.0 entry.

**Audit reconciliation 2026-05-18.** Original aggregate was ~210/325
(~65%). Auditing the v0.7.0 commitment surfaced seven row clusters
listed in ROADMAP / ADRs but not tracked in this document:

- **W** (Arrow v0.7.0 deltas) — ~9 items
- **X** (Parquet full surface + binding parity) — ~10 items
- **Y** (Streaming evaluator — replaces W012 stub) — ~7 items
- **Z** (`cx:lang` formalization per spec/i18n.md §1) — ~5 items
- **AA** (Comparative benchmarks vs JSON/YAML/TOML/XML/MessagePack/CBOR) — ~6 items
- **BB** (Reproducible builds) — ~5 items
- **CC** (Fuzz-testing harness) — ~6 items

Adding those ~48 items expands the denominator from ~325 to ~395
and revises the completion rate from ~65% to ~53%.

**Current state.** The directive-form XQuery 4.0 / XPath 4.0
expression surface (A row), the CXPath axis set (B row), the fn:
namespace function library (C row), and the map / array runtime
values (D row) are broadly implemented and exercisable, with
known per-item gaps documented in the row tables above (notably
A39/A40 backtick literal syntax, C5 XPath-regex grammar vs RE2
grammar, C14/C15 distinct date types + timezone adjust, C19/C21
partial completeness). The CXPath operator-token surface
(`|>`, `=>`, `!`, `||`, `to`) ships as a low-precedence pre-pass
in `eval_expr`; chained / parenthesised cases need a proper
expression grammar follow-up.

Substantive remaining implementation arcs live in W (Arrow gaps
+ binding parity), X (Parquet — full surface + binding parity),
Y (streaming evaluator replacing the W012 stub), and Z (cx:lang
locale-sensitive fns that reach into the C row). Process-flavored
arcs are spread across M (spec docs), N (adoption review), S
(release mechanics), L (conformance suite), T + AA (benchmarks),
U (security review), V + CC (CI / fuzz), BB (reproducible builds),
and H2-H5 (binding test-corpus widening).
**Per-row state lives in the row tables above** (A through CC).
Per-commit advancement is captured in the row-status changes in
the same commit that lands the feature; see the git log on
`v0.7.0-dev` for the chronological record. This summary block
intentionally avoids restating row-level detail since it goes
stale fast.

---

## How to read the effort estimate

Per-item estimates are rough — based on similar-sized features
shipped during the v0.7.0-dev arc. Variance is high. Items marked
❓ have not been audited yet and may be more or less than
estimated.

A tightening of estimates happens after each significant feature
lands — actual time vs estimate calibrates the remaining count.

## Open design questions (decisions needed; not deferment options)

Per the 2026-05-17 no-scope-shrinking directive, these questions
are about *how* to implement features fully, not *whether* to
ship them. Default: full implementation.

1. **A46/A47 audit (computed constructors).** Per
   `xquery_40_parity.md` §4.12.3 — audit current cx template
   machinery vs XQuery's computed-constructor surface. If gaps
   exist, implement to full parity. ETA for audit: ~1 session;
   implementation depends on what audit finds.
2. **Operator-token parser depth.** Operator-token forms today
   are a low-precedence pre-pass in `eval_expr`. Chained /
   parenthesised cases (`a |> f |> g`, `(xs ! f) |> g`, etc.)
   need a proper expression grammar to be reliable. Decision:
   when does the full expression-grammar arc land — v0.7.0 or
   v0.7.x?
