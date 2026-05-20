# `cx:` module — CX self-host surface

**Status:** Draft (2026-05-18). v0.7.0 deliverable per
[ADR 0023](../decisions/0023-cx-self-host-module-and-extension-interface.md).

**Authoritative refs:**
- [ADR 0023](../decisions/0023-cx-self-host-module-and-extension-interface.md) — module decision, eval gates, registry framework
- [`spec/v0_7_0_status.md`](../v0_7_0_status.md) §W — implementation queue (W1–W26)
- [`spec/canonical.md`](../canonical.md) — canonical form returned by `cx:canonical`
- [`spec/identity.md`](../identity.md) — anchor/id/hash semantics
- [`spec/include.md`](../include.md) — include resolution `cx:resolve-includes` wraps
- [`spec/threat_model.md`](../threat_model.md) §`cx:eval` — eval-injection threat surface
- [`spec/abi.md §1.5`](../abi.md) — capability-bit assignments

---

## §0. Module metadata

| Field | Value |
|---|---|
| `ns_prefix` | `cx` |
| `version` | `0.7.0` |
| `capability_bit` | Bit 28 (subsumed — per ADR 0023 Amendment #2 R2; bit 28 widens at v0.7.0 to cover the full DD/EE/FF surface collectively) |
| `activation` | `Always` (no `[?cx use-module=cx]` required) |
| `default_purity` | `Pure` (overridden per-function — see §1) |

Always-on rationale: the homoiconic claim demands runtime cx-on-cx
ops be present without opt-in. Compare `file:` / `http:` / `random:`
at v0.8.0 which are `OnDeclaration`.

---

## §1. Function surface

23 functions across three tiers. Tier corresponds to ADR 0023 §D1.
Each row: signature, return, purity, error codes, fixture-ref.

### §1.1 Must — 10 functions

| Fn | Signature | Returns | Purity | Errors | Fixtures |
|---|---|---|---|---|---|
| `cx:parse` | `(text as xs:string)` | `cx-value` | Pure | `cx-err:CXER0020` malformed | `parse-*` |
| `cx:serialize` | `(value as cx-value)` | `xs:string` | Pure | `cx-err:CXER0021` non-serializable | `serialize-*` |
| `cx:canonical` | `(value as cx-value)` | `xs:string` | Pure | — | `canonical-*` |
| `cx:hash` | `(value as cx-value)` | `xs:string` (hex content hash per `identity.md`) | Pure | — | `hash-*` |
| `cx:diff` | `(a as cx-value, b as cx-value)` | `cx-value` (diff doc per ADR 0012) | Pure | — | `diff-*` |
| `cx:patch` | `(value as cx-value, diff as cx-value)` | `cx-value` | Pure | `cx-err:CXER0022` diff-conflict | `patch-*` |
| `cx:to-format` | `(value as cx-value, fmt as xs:string)` | `xs:string` | Pure | `cx-err:CXER0023` unknown-fmt, `cx-err:CXER0024` not-representable | `to-format-*` |
| `cx:from-format` | `(text as xs:string, fmt as xs:string)` | `cx-value` | Pure | `cx-err:CXER0023` unknown-fmt, `cx-err:CXER0025` parse-fail | `from-format-*` |
| `cx:equal` | `(a as cx-value, b as cx-value)` | `xs:boolean` | Pure | — | `equal-*` |
| `cx:select` | `(value as cx-value, path as xs:string)` | `sequence` | Pure | `cx-err:CXER0026` malformed-path | `select-*` |

Format strings accepted by `to-format` / `from-format` (Must set):
`"xml"`, `"json"`, `"yaml"`, `"toml"`, `"md"`, `"csv"`, `"tsv"`,
`"psv"`, `"cx"` (round-trip via `cx:parse` / `cx:serialize`).
Format-string registry lives at `spec/conversions.md`; new formats
added there become callable through `cx:from-format` / `cx:to-format`
without a `cx:` surface change.

`cx:equal` is **distinct from `fn:deep-equal`**:
- `fn:deep-equal` is XQuery 4.0 standard, node-identity-agnostic,
  string-comparison-based for atomic values.
- `cx:equal` is canonical-aware (normalizes both sides through
  `canonical` before comparing), anchor-resolving (alias references
  resolve to anchor targets), and ID-aware (IDREF pairs equate to
  their ID targets per `spec/identity.md`).

`cx:select` accepts a runtime CXPath string. The compile-time `[?=
expr]` interpolation uses the same engine but binds the path at
parse time. `cx:select` enables data-driven query construction:

```
[?for q :in $queries :return [?= cx:select($doc, $q)]]
```

### §1.2 Should — 9 functions

| Fn | Signature | Returns | Purity | Errors | Fixtures |
|---|---|---|---|---|---|
| `cx:eval` | `(source as xs:string, context as map(*), options as map(*)?)` | `cx-value` | SideEffect | `cx-err:CXER0041..0044` (gates per §2) + propagated from evaluated fragment | `eval-*` |
| `cx:render` | `(template as xs:string, context as map(*))` | `xs:string` | SideEffect (inherits from `cx:eval`) | as `cx:eval` | `render-*` |
| `cx:schema-of` | `(value as cx-value)` | `cx-value` (cxs schema) | Pure | — | `schema-of-*` |
| `cx:validate` | `(value as cx-value, schema as cx-value)` | `sequence of diagnostic` | Pure | — | `validate-*` |
| `cx:anchors` | `(value as cx-value)` | `sequence of xs:QName` | Pure | — | `anchors-*` |
| `cx:ids` | `(value as cx-value)` | `sequence of xs:string` | Pure | — | `ids-*` |
| `cx:references` | `(value as cx-value)` | `sequence of map { id, source-path }` | Pure | — | `references-*` |
| `cx:resolve-includes` | `(value as cx-value, root as xs:string)` | `cx-value` | ReadOnly | `cx-err:CXER0027` include-cycle, `cx-err:CXER0028` include-not-found, `cx-err:CXER0029` traversal-rejected | `resolve-includes-*` |

`cx:render(t, ctx)` is sugar for `cx:serialize(cx:eval(t, ctx))`
with one optimization: a `render`-bound evaluator may stream output
directly without materializing the full intermediate cx-value. The
optimization is implementation-defined; semantic output is identical
to the sugar form.

`cx:validate` overlaps with the v0.8.0 `validate:cxs` function. The
`cx:` form is primary (ships at v0.7.0); the `validate:` form at
v0.8.0 is an alias for namespace-consistency with the other v0.8.0
modules.

### §1.3 Nice — 4 functions

| Fn | Signature | Returns | Purity | Errors | Fixtures |
|---|---|---|---|---|---|
| `cx:merge` | `(a as cx-value, b as cx-value, policy as xs:string?)` | `cx-value` | Pure | `cx-err:CXER0030` merge-conflict (under `error-on-conflict` policy) | `merge-*` |
| `cx:strip-comments` | `(value as cx-value)` | `cx-value` | Pure | — | `strip-comments-*` |
| `cx:strip-attrs` | `(value as cx-value, name-pattern as xs:string)` | `cx-value` | Pure | `cx-err:CXER0031` invalid-pattern | `strip-attrs-*` |
| `cx:pretty-print` | `(value as cx-value, options as map(*)?)` | `xs:string` | Pure | — | `pretty-print-*` |

`cx:merge` policies: `"last-wins"` (default — b shadows a where they
collide), `"first-wins"`, `"error-on-conflict"`. Merge semantics
follow anchor-merge per `spec/identity.md` extended to whole-document
merge (anchor collisions resolve by policy; non-anchor attribute
collisions resolve by policy at each element).

`cx:pretty-print` options keys (initial set, extensible):
`"indent"` (xs:int, default 2), `"max-line-length"` (xs:int, default
80), `"sort-attrs"` (xs:boolean, default false), `"strip-comments"`
(xs:boolean, default false).

---

## §2. `cx:eval` — gates (normative)

`cx:eval(source, context)` evaluates `source` as a cxl source string
against `context` (a map binding names to values). The five
mitigations from ADR 0023 §D6 are normative behavior. Each mitigation
gets at least one conformance fixture under `conformance/cx_module.txt`.

### §2.1 M1 — Off by default

A document calling `cx:eval` **must** carry `[?cx allow-eval=true]`
at document head. Absence raises `cx-err:CXER0041 (eval-not-enabled)`
at evaluation time (not parse time — the directive is checked when
`cx:eval` is invoked, allowing static parsing of documents that
reference but never reach the call).

`cx lint` emits `L006-eval-bearing` informational on documents
carrying `[?cx allow-eval=true]`. Severity is opt-in via
`.cxlint.cx` config — default informational, can be raised to
warning or error per deployment policy.

### §2.2 M2 — Refused under `pure-only`

`[?cx pure-only]` and `[?cx allow-eval=true]` in the same document
raise `cx-err:CXER0042 (eval-incompatible-with-pure-only)` at parse
time. The two directives are exclusive — `pure-only` mode forbids
all SideEffect functions, and `cx:eval` is SideEffect per §1.2.

### §2.3 M3 — Sandboxed by context

Inside an evaluated fragment, the only bindings visible are the keys
of the `context` argument. **No ambient capture.** Specifically:

- No `?def` definitions from the caller document are visible
- No `?fn` inline-function bindings from the caller's scope are visible
- No `?for` / `?let` / `?with` bindings from the caller's scope are visible
- No filesystem-relative paths inherit from the caller (an evaluated
  fragment calling `cx:resolve-includes` must pass an explicit root)

To pass a function value into an evaluated fragment, the caller
supplies it as a context map value:

```
[cx:eval :source $src :context { "transform": ?fn ($x) { ... } }]
```

The evaluated fragment then references `$transform` (the context key
becomes a bound variable in the fragment's scope).

### §2.4 M4 — Module pass-through is restrictive

The evaluated fragment inherits the **caller document's** active
module set (as established by the caller's `[?cx use-module=...]`
directive). The fragment **cannot widen**:

- `[?cx use-module=...]` inside the evaluated fragment listing a
  module the caller did not activate raises
  `cx-err:CXER0043 (eval-module-widening)`
- The fragment may narrow (drop modules) by omitting them from its
  own `use-module` directive — but the narrower set is fragment-
  local and does not affect the caller

This bounds the capability surface of evaluated user-supplied
fragments: a document that activates only `cx:` and `fn:` cannot be
escalated to filesystem or network access by an eval'd payload.

### §2.5 M5 — Recursion-depth limit

Default cap **8** (mirrors `max_include_depth` per `spec/include.md`).
Configurable per-call via an optional third argument:

```
cx:eval($src, $ctx, map { "max-depth": 16 })
```

or per-document via `[?cx max-eval-depth=N]`. Exceeding the depth
raises `cx-err:CXER0044 (eval-recursion-depth-exceeded)`.

The depth counter increments on each `cx:eval` invocation, including
indirect invocation through `cx:render`. Mutual recursion through
multiple eval-bearing documents counts cumulatively across the
include chain.

### §2.6 Threat model summary

Per [`spec/threat_model.md`](../threat_model.md) §`cx:eval` (new
section per ADR 0023 §D6):

- **Untrusted-input source:** any `cx:eval` whose `source` argument
  derives from network, filesystem, stdin, or user-supplied data is
  in scope.
- **Trusted-input source:** `cx:eval` whose `source` is a static
  string literal in the calling document is out of scope (equivalent
  to a `?def` block — already trusted authoring-time code).
- **Recommended deployment patterns:** § documented in threat-model
  entry. Summary: untrusted-eval workloads should run in a
  separate process with `pure-only` enforced at the document head;
  the process boundary plus the directive plus M2 gives defense in
  depth.

---

## §3. Conformance

Fixtures live at `conformance/cx_module.txt`. Categories per ADR 0023
§D7:

1. **Round-trip identity** — `cx:serialize(cx:parse(t)) == cx:canonical(t)` for every fixture cx file in `vcx/tests/fixtures/` known to be canonical-form-stable
2. **Cross-binding byte-identity** — every fixture passes on V + Python + Go + Rust + TypeScript
3. **Error path** — each error code in §1 has at least one fixture producing it
4. **Edge cases** — empty value, single-node value, deeply nested (1k+ levels), value with anchors, value with IDs/IDREFs, value with includes (resolved + unresolved)
5. **Purity assertion** — every Pure-tagged function produces byte-identical output across 10 repeated calls on the same input
6. **Gate enforcement** (cx:eval only) — one fixture per §2 mitigation

Total fixture count target: ~120 entries (~5 per function × 23 + 5
gate fixtures + ~10 cross-binding identity entries).

---

## §4. Error codes

All `cx:` module errors live in two namespaces:

- **`cx-err:CXER002x..003x`** — `cx:` function-specific errors (parse fail,
  malformed path, merge conflict, etc.)
- **`cx-err:CXER004x`** — self-host / eval-gate errors (gate violations,
  module widening, recursion depth)

Numbering reserved at v0.7.0 per [`spec/eval.md §E`](../eval.md) and
the v0.7.0 error-namespace ADR (per `v0_7_0_status.md §E`).

| Code | Description | Function(s) |
|---|---|---|
| `cx-err:CXER0020` | Malformed cx source | `cx:parse` |
| `cx-err:CXER0021` | Non-serializable cx value | `cx:serialize` |
| `cx-err:CXER0022` | Diff cannot apply to value (conflict) | `cx:patch` |
| `cx-err:CXER0023` | Unknown format string | `cx:to-format`, `cx:from-format` |
| `cx-err:CXER0024` | Value not representable in target format | `cx:to-format` |
| `cx-err:CXER0025` | Parse failure in source format | `cx:from-format` |
| `cx-err:CXER0026` | Malformed CXPath expression | `cx:select` |
| `cx-err:CXER0027` | Include cycle | `cx:resolve-includes` |
| `cx-err:CXER0028` | Include not found | `cx:resolve-includes` |
| `cx-err:CXER0029` | Include traversal rejected (`..` / scheme) | `cx:resolve-includes` |
| `cx-err:CXER0030` | Merge conflict (under `error-on-conflict` policy) | `cx:merge` |
| `cx-err:CXER0031` | Invalid name-pattern | `cx:strip-attrs` |
| `cx-err:CXER0040` | SideEffect/ReadOnly call under `pure-only` | any non-Pure |
| `cx-err:CXER0041` | `cx:eval` invoked without `allow-eval=true` | `cx:eval` |
| `cx-err:CXER0042` | `allow-eval=true` + `pure-only` collision | parse-time |
| `cx-err:CXER0043` | Evaluated fragment widens module set | `cx:eval` |
| `cx-err:CXER0044` | Recursion depth exceeded | `cx:eval` |

---

## §5. Capability bit

Per ADR 0023 Amendment #2 R2, `cx:` does **not** get a new
`cx_features` bit. Bit 28 (existing — "CXL evaluator" per
[`spec/abi.md §1.5`](../abi.md)) is widened at v0.7.0 by G4 to
mean "full DD/EE/FF surface present." A binding setting bit 28
at v0.7.0 commits to all of the following:

- All 23 functions in §1 are callable
- All five `cx:eval` gates in §2 are enforced
- The error codes in §4 are returned per the documented mapping
- The conformance fixtures in §3 pass byte-identical to the V reference
- The full FF `log:` module surface
- The function-metadata catalog (EE1) and pure-only enforcement (EE4)
- The evaluator-hook signature (EE7)

Bindings that ship without the full DD/EE/FF surface leave bit 28
clear. Per-module presence in user code goes through `inspect:`
(DD13 / EE7) rather than ABI-level negotiation.

---

## §6. Open questions

(Items deliberately not resolved in v0.7.0 — recorded for v0.7.x /
v0.8.0 follow-up.)

1. **`cx:eval` and streaming output** — when the v0.7.0 streaming
   evaluator is invoked over a fragment containing `cx:eval`, does
   the inner eval stream into the outer output stream, or buffer
   first? Open question; default to buffer for v0.7.0; revisit if a
   real consumer surfaces.
2. **`cx:select` and very large values** — should the function
   stream or materialize? v0.7.0 default: materialize. v0.7.x or
   v0.8.0 may add a `cx:select-stream` variant.
3. **`cx:merge` with non-conflicting includes** — when both sides
   reference the same include, is the include resolved once or
   twice? v0.7.0 default: resolved per-side then merged. Open: a
   `"deduplicate-includes": true` option in policy map.
4. **`cx:eval` and infinite generators (v0.8.0)** — XQuery 4.0
   generators per `xquery_40_parity.md §4.13` interact with eval's
   recursion-depth gate in an unobvious way. Defer until generators
   land at v0.7.0 evaluator level.
