# XQuery 4.0 Feature Parity Inventory

**Status:** Draft (2026-05-17). Targets cx v0.7.0 per
[ADR 0022 §D2](decisions/0022-cx-is-one-language-v0_7_0-scope.md).

**Purpose.** ADR 0022 §D2 claims v0.7.0 ships "Full XQuery-4-equivalent
evaluator surface in one cut." This document catalogs every XQuery
4.0 feature against cx's current and planned surface, so "parity"
becomes measurable rather than aspirational.

**Sources.**
- [XQuery 4.0 W3C Editor's Draft](https://qt4cg.org/specifications/xquery-40/xquery-40.html)
  — section structure and feature names (verified 2026-05-17)
- [XQuery 3.1 Recommendation](https://www.w3.org/TR/xquery-31/) —
  for sub-feature details where 4.0 carries 3.1 semantics unchanged
- [cx CXL spec](cxl.md) — current cx implementation surface
- V reference implementation source (`vcx/cx/cxl.v`, `vcx/cx/parser.v`,
  `vcx/cx/cxpath.v`)

**Status legend.**

| Symbol | Meaning |
|---|---|
| ✅ | shipped — implemented and tested in V reference |
| 🚧 | partial — some sub-features implemented, others pending |
| 📋 | planned for v0.7.0 — design committed, implementation pending |
| ⏭ | deferred to v0.7.x or later — explicit out-of-scope for v0.7.0 |
| ❌ | not in cx scope — deliberate non-feature with rationale |
| ❓ | needs spec verification before implementation |

**Parity claim convention.** A row is at "parity" only when cx
provides the capability in a form a XQuery practitioner would
recognize as equivalent. Cx-native syntax differences are fine;
capability gaps are not.

**Cx-native "exceeds" claim convention.** Features cx provides that
XQuery 4.0 does not get an additional column flag and a separate
section §X "Beyond XQuery 4.0" at the bottom.

---

## Section parity overview

| XQuery 4.0 section | Cx coverage | Notes |
|---|---|---|
| 1 Introduction | — | informational |
| 2 Basics | ✅ | sequence-flat data model per CXDM |
| 3 Types | 🚧 | CXDM type system covers most; SequenceType expressions partial |
| 4 Expressions | 🚧 | core focus — see §4 detail below |
| 5 Modules and Prologs | ⏭ | cx uses include-based modularity; module/prolog system out of v0.7.0 scope |
| 6 Conformance | 📋 | conformance suite needs widening per ADR 0022 §D8 |
| Appendix A Grammar | 📋 | `spec/grammar.ebnf` needs CXL 3.1/4.0 productions added |
| Appendix B Context | ✅ | CXLEnv covers static + dynamic context for cx scope |
| Appendix E Error Conditions | 📋 | cx-native error code namespace pending (currently V error strings) |
| Appendix G Glossary | — | |
| Appendix H Atomic Comparisons | ✅ | implemented in CXPath comparison ops |
| Appendix I Backwards Compat | — | n/a for cx |

---

## §4 Expressions — full parity table

### 4.1 Comments
| Status | Cx surface | Notes |
|---|---|---|
| ✅ | `[- block comment -]` and `# line comment` | Per ADR 0017; passes parser & lint |

### 4.2 Primary Expressions
| Sub-feature | Status | Cx surface | Notes |
|---|---|---|---|
| 4.2.1.1 Numeric literals | ✅ | `42`, `3.14`, `1e10` | CXPath scanner |
| 4.2.1.2 String literals | ✅ | `'...'`, `"..."` | |
| 4.2.1.3 QName literals | 🚧 | bare identifiers, no namespace prefix | needs `prefix:local` form |
| 4.2.1.4 Constants of other types | 🚧 | bool, null supported; date/time pending | per CXDM scalar types |
| 4.2.2 Variable references | ✅ | `$var` (CXPath); `@v` (cx-native) | |
| 4.2.3 Context value references | ✅ | `.` (context); `..` (parent) | |
| 4.2.4 Parenthesized expressions | ✅ | `(expr)` | |
| 4.2.5 Enclosed expressions | 🚧 | `{expr}` inside templates? | needs verification ❓ |

### 4.3 Postfix Expressions
| Status | Cx surface | Notes |
|---|---|---|
| 🚧 | predicates `expr[pred]`, function call `expr(args)` | function-call postfix needs work for inline functions |

### 4.4 Filter Expressions
| Status | Cx surface | Notes |
|---|---|---|
| ✅ | `seq[pred]` via CXPath | |

### 4.5 Functions
| Sub-feature | Status | Cx surface | Notes |
|---|---|---|---|
| 4.5.1 Static function calls | 🚧 | filter directives ✅; CXPath bare-call form ⏭ v0.8.0 | Directive surface (`[?count [//x]]` / `[?local-name [n]]`) and argless predicate form (`*[local-name()='foo']`) both ship at v0.7.0. Bare top-level CXPath form `count(//*)` / `local-name($n)` / `sum(//x/@v)` does NOT parse on v0.7.0-dev — deferred per `spec/v0_7_0_status.md B15` for v0.8.0. `$f(args)` postfix on function-valued variables (B8) is ✅ |
| 4.5.2 Function items | ✗ | — | requires CXLValue extension for function-as-value |
| 4.5.3 Dynamic function calls | ✗ | — | requires function items |
| 4.5.4 Partial function application | ✗ | `f(_, 2, _)` planned | per ADR 0022 §D2 |
| 4.5.5 Named function references | ✗ | `local:f#2` planned | per ADR 0022 §D2 |
| 4.5.6 Inline function expressions | ✗ | `fn($x) { ... }`, `->($x) { ... }` planned | the `?fn` feature — biggest remaining work |
| 4.5.6.1 Focus functions | ✗ | `-> { $_ * 2 }` planned | per ADR 0022 §D2 |
| 4.5.7 Function identity | ❓ | needs design | likely follows XQuery semantics |

**Gap impact:** §4.5 is the single largest gap. Functions-as-values
unlock inline fn, partial application, higher-order, pipelines.
Implementation arc: introduce `CXLFunction` value kind, lexical
closure capture, dynamic-call dispatch, partial-app desugar. Probably
3–5 commits of focused work.

### 4.6 Path Expressions
| Sub-feature | Status | Cx surface | Notes |
|---|---|---|---|
| 4.6.1 Absolute paths (`/`, `//`) | ✅ | CXPath | |
| 4.6.2 Relative paths | ✅ | CXPath | |
| 4.6.3 Path operator `/` | ✅ | CXPath | |
| 4.6.4 Recursive `//` | ✅ | CXPath | |
| 4.6.5 Axis steps | 🚧 | child, descendant, attribute supported; parent/ancestor/sibling per ROADMAP v0.8.0 | |
| 4.6.6 Predicates within steps | ✅ | `path[pred]` | |
| 4.6.7 Unabbreviated syntax | 🚧 | abbreviated forms work; long forms (`child::elem`) verification ❓ | |
| 4.6.8 Abbreviated syntax | ✅ | `@`, `/`, `//`, `.`, `..` | |
| 4.6.9 Comparison with JSONPath | ❌ | n/a as a feature; informational | |

### 4.7 Sequence Expressions
| Sub-feature | Status | Cx surface | Notes |
|---|---|---|---|
| 4.7.1 Sequence concatenation | ✅ | `(a, b, c)` | |
| 4.7.2 Range expressions | 🚧 | `1 to 10` — verification needed ❓ | |
| 4.7.3 Combining GNode sequences | 🚧 | `intersect`, `except`, `union` — verification ❓ | |

### 4.8 Arithmetic Expressions
| Status | Cx surface | Notes |
|---|---|---|
| ✅ | `+ - * div mod` (CXPath) | integer + float arithmetic |

### 4.9 String Expressions
| Sub-feature | Status | Cx surface | Notes |
|---|---|---|---|
| 4.9.1 String concatenation `\|\|` | 🚧 | `[?concat]` filter; verify `\|\|` operator ❓ | |
| 4.9.2 String templates | ✗ | XQuery 4.0 templated strings | new in 4.0; cx form TBD |
| 4.9.3 String constructors | ✗ | | new in 4.0; cx form TBD |

### 4.10 Comparison Expressions
| Sub-feature | Status | Cx surface | Notes |
|---|---|---|---|
| 4.10.1 Value comparisons (`eq`, `ne`, `lt`, `le`, `gt`, `ge`) | 🚧 | `=`, `!=`, `<`, `<=`, `>`, `>=` supported; verb forms ❓ | |
| 4.10.2 General comparisons | ✅ | symbol operators | |
| 4.10.3 GNode comparisons | 🚧 | `is`, `<<`, `>>` for node identity/order — verify ❓ | |

### 4.11 Logical Expressions
| Status | Cx surface | Notes |
|---|---|---|
| ✅ | `and`, `or`, `not()` | CXPath |

### 4.12 Node Constructors
| Sub-feature | Status | Cx surface | Notes |
|---|---|---|---|
| 4.12.1 Direct element constructors | ✅ | cx literal `[elem attr=val [child]]` is homoiconic | **CX EXCEEDS** — element constructors ARE cx literals |
| 4.12.2 Other direct constructors | ✅ | TextNode, CommentNode etc. | |
| 4.12.3 Computed constructors | 🚧 | dynamic element construction via templates; verify completeness ❓ | |
| 4.12.4 In-scope namespaces | 🚧 | namespace handling per ADR 0002 | |

### 4.13 FLWOR Expressions
| Sub-feature | Status | Cx surface | Notes |
|---|---|---|---|
| 4.13.1 Variable bindings | ✅ | `?for v :in xs` | |
| 4.13.2 For clause | ✅ | `?for :in` | |
| 4.13.3 Let clause | ✅ | `?for :let [v, expr]` | parser desugar to nested `?let` |
| 4.13.4 Window clause (tumbling) | ✗ | not planned for v0.7.0 | **DEFER to v0.7.x or v0.8.0** — niche but real XQuery feature |
| 4.13.4 Window clause (sliding) | ✗ | not planned for v0.7.0 | same |
| 4.13.5 Where clause | ✅ | `?for :where` | parser desugar to nested `?if` |
| 4.13.6 While clause | ❓ | new in 4.0; verification needed | likely simple variant of where |
| 4.13.7 Count clause | ✗ | not planned for v0.7.0 | XQuery 3.1 feature — counter binding per iteration |
| 4.13.8 Group By clause | 📋 | per ADR 0022 §D8 — collect-and-sort semantics | substantive evaluator work |
| 4.13.9 Order By clause | 📋 | per ADR 0022 §D8 | substantive evaluator work |
| 4.13.10 Return clause | ✅ | `?for :return` | |

**Gap impact:** Currently 4/10 FLWOR sub-features. Need to add
`order-by`, `group-by`, `count`, `while`, and possibly windows for
honest parity. Windows are likely v0.7.x — they're complex.

### 4.14 Maps and Arrays
| Sub-feature | Status | Cx surface | Notes |
|---|---|---|---|
| 4.14.1.1 Map constructors | ✅ | `{key: value, ...}` per ADR 0017 | |
| 4.14.1.2 Maps as functions | ✗ | `$map($key)` — needs function-item support | depends on §4.5 functions |
| 4.14.2.1 Array constructors | ✅ | `[1, 2, 3]` per ADR 0017 | |
| 4.14.2.2 Arrays as functions | ✗ | `$arr($i)` | depends on §4.5 functions |
| 4.14.3.1 Postfix lookup `?` | 📋 | `$map?key` — per ADR 0022 §D2 | the lookup-operator context-sensitive parsing |
| 4.14.3.2 Unary lookup `?` | 📋 | `?key` (relative to context) | per ADR 0022 §D2 |
| 4.14.3.3 Compare lookup vs path | — | informational | |
| 4.14.3.4 Implausible lookup | — | static type check informational | |
| 4.14.4 Methods and method calls | ❓ | new in 4.0 — needs spec read | |

**Map/array function library** (XQuery 3.1+ `map:`, `array:` namespaces):
| Function | Status |
|---|---|
| `map:get`, `map:put`, `map:keys`, `map:size`, `map:contains`, `map:entry`, `map:merge`, `map:remove`, `map:for-each` | ✗ — none implemented |
| `array:size`, `array:get`, `array:append`, `array:reverse`, `array:filter`, `array:for-each`, `array:fold-left`, `array:fold-right`, `array:flatten`, `array:join`, `array:put`, `array:remove`, `array:insert-before`, `array:head`, `array:tail`, `array:subarray` | ✗ — none implemented |

**Gap impact:** Maps/arrays as values exist in CXDM but the function
library to manipulate them is absent. ~25 functions to add for
XQuery 3.1 parity, more for 4.0 additions.

### 4.15 Ordered and Unordered Expressions
| Status | Cx surface | Notes |
|---|---|---|
| ❓ | ordering mode declarations — verify ❓ | likely simple |

### 4.16 Conditional Expressions
| Status | Cx surface | Notes |
|---|---|---|
| ✅ | `?if` directive + multi-branch | parity ✓ |

### 4.17 Otherwise Expressions
| Status | Cx surface | Notes |
|---|---|---|
| ❓ | `A otherwise B` — new in 4.0, evaluates B if A is empty | likely simple to add; verify ❓ |

### 4.18 Switch Expressions
| Status | Cx surface | Notes |
|---|---|---|
| ✗ | `switch ($v) { case 1 { ... } case 2 { ... } default { ... } }` | merge into `?match` design? per ADR 0022 §D2 |

### 4.19 Quantified Expressions
| Status | Cx surface | Notes |
|---|---|---|
| ✗ | `some $x in seq satisfies p($x)`, `every $x in seq satisfies p($x)` | not in ADR 0022 §D2 — **add to scope** |

### 4.20 Try/Catch Expressions — current parity ~25%
| Sub-feature | Status | Cx surface | Notes |
|---|---|---|---|
| Basic try/catch syntax | ✅ | `[?try [body, catch]]` and labeled form | commit `b9a7c90` |
| Catch-all clause | ✅ | implicit (single catch) | |
| Multiple catch clauses | ✗ | only one slot today | needs ADR + parser/evaluator |
| Code-specific catches (NameTest) | ✗ | — | depends on error code namespace |
| `$err:code` binding | ✗ | — | needs error info plumbing |
| `$err:description` binding | ✗ | — | |
| `$err:value` binding | ✗ | — | |
| `$err:module` binding | ❓ | needs spec read | |
| `$err:line-number`, `$err:column-number` | ❓ | parser provides position; needs plumbing | |
| `$err:additional` | ❓ | impl-defined | |
| `fn:error()` raise | ✗ | — | needs `[?error :code C :description D]` directive or filter |
| Standardized error code namespace | ✗ | cx-native namespace TBD | major design item — see Appendix E parity below |
| Output rollback on partial emission | ✅ | cx-native — XQuery doesn't have this concern |  **CX EXCEEDS** |

**Gap impact:** Today's `?try` is the minimum-viable single-catch
form. Full XQuery 4.0 parity needs ~10 sub-features added. Most
significant: error info plumbing (`$err:*` bindings), multiple
catches with code matching, `fn:error()` raise, cx-native error
code namespace (parallel to W3C's FOAR/FOCA/FORG).

### 4.21 Expressions on SequenceTypes
| Sub-feature | Status | Cx surface | Notes |
|---|---|---|---|
| 4.21.1 Instance of (`instance of`) | ✗ | — | needs type-check operator |
| 4.21.2 Typeswitch | ✗ | merge into `?match`? | |
| 4.21.3 Cast (`cast as`) | ✗ | — | |
| 4.21.4 Castable (`castable as`) | ✗ | — | |
| 4.21.5 Constructor functions | ✗ | — | |
| 4.21.6 Treat (`treat as`) | ✗ | — | |

**Gap impact:** §4.21 is the static-type / runtime-type assertion
surface. Substantial work; may collapse partially into `?match`'s
pattern surface depending on design choices.

### 4.22 Pipeline operator `|>`
| Status | Cx surface | Notes |
|---|---|---|
| 📋 | per ADR 0022 §D2 | depends on §4.5 functions |

### 4.23 Simple map operator `!`
| Status | Cx surface | Notes |
|---|---|---|
| ✗ | `seq ! expr` — applies expr to each item | not in ADR 0022 §D2 — **add to scope** |

### 4.24 Arrow Expressions
| Sub-feature | Status | Cx surface | Notes |
|---|---|---|---|
| 4.24.1 Sequence arrow `=>` | ✗ | dropped per ADR 0022 §D2 in favor of `\|>` only | **revisit:** XQuery 4.0 has BOTH `\|>` and `=>` — they have different semantics (sequence-arrow vs mapping-arrow). Dropping `=>` may be a parity gap. ❓ |
| 4.24.2 Mapping arrow | ✗ | same | |

**Critical finding:** ADR 0022 §D2 said "v0.7.0 ships `|>` only;
drop `=>`." Reading the XQuery 4.0 spec, `=>` and `|>` are not
redundant — they have distinct semantics (arrow expressions apply
the function to the sequence as a whole vs pipelining). Dropping
`=>` is a real parity gap. **Reconsider §D2 decision.**

### 4.25 Validate Expressions
| Status | Cx surface | Notes |
|---|---|---|
| ⏭ | schema validation via cxs | cx-native form differs from XQuery's `validate {expr}` |

### 4.26 Extension Expressions
| Status | Cx surface | Notes |
|---|---|---|
| ❓ | pragmas / impl extensions | needs verification |

---

## §Appendix E — Error Conditions parity

XQuery 4.0 defines a structured error code namespace with categories:
- `FOAR` — arithmetic
- `FOCA` — casting
- `FOCH` — character / encoding
- `FODC` — document / collection
- `FODT` — date/time
- `FOER` — generic / unidentified
- `FOFD` — format
- `FOJS` — JSON
- `FONS` — namespaces
- `FOQM` — query module
- `FORG` — general
- `FORX` — regex
- `FOTY` — type
- `FOUT` — UTF-8 / serialization
- `FOXT` — extension
- `XPDY` — XPath dynamic
- `XPST` — XPath static
- `XPTY` — XPath type
- `XQDY` — XQuery dynamic
- `XQST` — XQuery static
- `XQTY` — XQuery type
- `XUDY` — XQuery Update dynamic (XQuery Update, separate spec)
- `XUST` — XQuery Update static
- `XUTY` — XQuery Update type

**Cx position:** Cx needs an analogous structured error code namespace.
Proposal: `CXER` prefix with category suffix (e.g., `CXER-FOAR0001`
for divide by zero, mapping to XQuery's `err:FOAR0001`). This is a
separate ADR-level design decision.

Status: ✗ — not yet designed. v0.7.0 blocker per the §4.20 try/catch
parity claim.

---

## Beyond XQuery 4.0 — cx-native capabilities

Features cx provides that XQuery 4.0 does not. These define
"or exceed" per the parity claim.

| Feature | Status | Notes |
|---|---|---|
| Homoiconic source — cxl is cx data | ✅ | per ADR 0022 §D1; XQuery has direct element constructors but not full homoiconicity |
| Content-addressed evaluation fragments | ✅ | per `spec/identity.md` |
| Schema-validated directives via cxs | 🚧 | per `spec/schema.md` |
| Byte-identical cross-binding output | ✅ | conformance discipline |
| Output rollback on `?try` partial emission | ✅ | per commit `b9a7c90` |
| `?def` parameterized templates with lexical scope | ✅ | per ADR 0020 |
| `[?cx ...]` config directives in source | ✅ | output target, strict mode |
| Tree-as-value passing (homoiconic slots) | ✅ | `[?def-call modal :body [div ...]]` per ADR 0022 §D3 |

---

## Implementation status matrix

Counts as of 2026-05-17:

| Section | Sub-features | ✅ | 🚧 | 📋 | ✗ | ❓ | Parity % |
|---|---|---|---|---|---|---|---|
| §4.5 Functions | 7 | 1 | 0 | 0 | 6 | 0 | 14% |
| §4.13 FLWOR | 10 | 4 | 0 | 2 | 3 | 1 | 40% |
| §4.14 Maps/Arrays (constructors+lookup) | 9 | 2 | 0 | 2 | 5 | 0 | 22% |
| §4.14 Map function library | ~10 | 0 | 0 | 0 | 10 | 0 | 0% |
| §4.14 Array function library | ~16 | 0 | 0 | 0 | 16 | 0 | 0% |
| §4.20 Try/Catch | 13 | 3 | 0 | 0 | 8 | 2 | 23% |
| §4.21 SequenceType | 6 | 0 | 0 | 0 | 6 | 0 | 0% |
| §4.22 Pipeline | 1 | 0 | 0 | 1 | 0 | 0 | 0% (planned) |
| §4.23 Simple map | 1 | 0 | 0 | 0 | 1 | 0 | 0% |
| §4.24 Arrow expressions | 2 | 0 | 0 | 0 | 2 | 0 | 0% — see critical finding |
| §Appendix E Error codes | 24 | 0 | 0 | 0 | 24 | 0 | 0% |

**Aggregate v0.7.0 trajectory at current scope:** ~25–35% XQuery 4.0
parity, not the "full equivalence" ADR 0022 §D2 claims.

---

## What to do about it

Three options:

**(A) Honest scope reduction.** Amend ADR 0022 §D2 to say "XQuery
3.1 *subset*" with this inventory as the per-feature scoping doc.
Ship what's plausible at v0.7.0; honestly call out the gap. This
preserves the single-cut release model but contradicts "parity or
exceed."

**(B) Full parity scope expansion.** Take this inventory as the
v0.7.0 deliverable list. Implement every ✗ → ✅ before tag. This
honors the original claim but expands v0.7.0 effort by ~2–3×.
Requires:
- §4.5 Functions (the biggest single arc — function-as-value,
  closures, partial app, named refs, inline expressions): ~5–8
  commits
- §4.13 FLWOR remaining clauses (order-by, group-by, count,
  while; windows likely deferred): ~3–5 commits
- §4.14 Map/array function library (~26 functions): ~3–5 commits
- §4.20 Try/Catch full surface (`$err` bindings, error codes,
  fn:error, multiple catches): ~3 commits
- §4.21 SequenceType expressions: ~3 commits
- §Appendix E cx-native error code namespace design: separate ADR
- Plus the originally-scoped pipeline, partial app, etc.

Total: 20–30+ implementation commits over multiple weeks.

**(C) Phased single-cut with honest staging.** v0.7.0 ships the
current trajectory (~30% parity) explicitly as "XQuery 3.1 subset
+ select 4.0 features." v0.7.x and v0.8.0 close the parity gap.

**Decision per user instruction (2026-05-17):** **(B) — full parity
scope expansion.** This document becomes the v0.7.0 deliverable
checklist. Each ✗ row is a v0.7.0 blocker per ADR 0022 §D10 tagging
discipline.

## Verification protocol

Before each XQuery 4.0 feature is marked ✅:

1. Read the relevant section of the W3C draft end-to-end
2. Identify sub-features and edge cases (null behavior, type
   coercion, error conditions)
3. Implement in V reference + add fixtures
4. Verify against XQuery 4.0 test suite or analog
5. Confirm byte-identity across all 5 v0.7.0 bindings
6. Update this document's row to ✅

## Next steps

This inventory becomes the **§D8 implementation queue** for v0.7.0.
Replaces the high-level "implementation order" listed in
ADR 0022 §D8 with concrete per-feature work items.

Recommended sequencing (per dependency order):
1. §4.5.6 Inline function expressions (`?fn`) — unblocks pipelines,
   partial app, higher-order. **Biggest single arc.**
2. §4.5.2-5.5.7 Function items + dynamic calls + partial app +
   named refs
3. §4.14 Map/array function library (independent of §4.5; can
   parallelize)
4. §4.13 FLWOR remaining (order-by, group-by, count, while)
5. §4.20 Try/catch full surface (depends on error codes; needs
   ADR for error code namespace)
6. §4.21 SequenceType expressions (`instance of`, `cast as`, etc.)
7. §4.18 / §4.19 / §4.23 Switch, quantified, simple map
8. §4.22 / §4.24 Pipeline `|>` and Arrow `=>` (both, per critical
   finding above)
9. §4.17 Otherwise (small)
10. §Appendix E error code namespace ADR + implementation
