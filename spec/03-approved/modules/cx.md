# `cx:` module — CX self-host surface

**Status:** Current

Normative reference for the `cx:` module. Always-on, no `[?lib]` required: the homoiconic claim demands runtime cx-on-cx operations be present without opt-in.

---

## §1. Module metadata

| Field | Value |
|---|---|
| `ns_prefix` | `cx` |
| `activation` | Always — no `[?lib]` required |
| Default purity | `pure` (overridden per-function — see §2) |
| Error block | `CXER4100..CXER4119` (§6) |

## §2. Function surface

### §2.1 Core (always available)

| Fn | Signature | Returns | Purity |
|---|---|---|---|
| `cx:parse` | `($text::string)` | `any` | pure |
| `cx:serialize` | `($value::any)` | `string` | pure |
| `cx:canonical` | `($value::any)` | `string` | pure |
| `cx:hash` | `($value::any)` | `string` (hex content hash) | pure |
| `cx:diff` | `($a::any $b::any)` | `any` (diff value) | pure |
| `cx:patch` | `($value::any $diff::any)` | `any` | pure |
| `cx:to-format` | `($value::any $fmt::string)` | `string` | pure |
| `cx:from-format` | `($text::string $fmt::string)` | `any` | pure |
| `cx:equal` | `($a::any $b::any)` | `bool` | pure |
| `cx:select` | `($value::any $path::string)` | `[sequence any]` | pure |

`cx:canonical` returns the canonical form per [`spec/core/canonical.md`](../core/canonical.md).
`cx:hash` returns the SHA-256 content hash of the node's strict canonical bytes per [`spec/core/canonical.md §1.2`](../core/canonical.md) (text default) / [`spec/core/canonical.md §4`](../core/canonical.md) (binary `cx_to_data_bin`).
Format strings accepted by `cx:to-format` / `cx:from-format`: `xml`, `json`, `yaml`, `toml`, `md`, `csv`, `tsv`, `psv`, `cx`. The registry lives at [`spec/core/conversions.md`](../core/conversions.md).

`cx:equal` is canonical-aware (normalises both sides through `canonical` first), anchor-resolving, and ID-aware per [`spec/core/cxdm.md §4`](../core/cxdm.md) (Identity / ID / IDREF) and [`spec/core/cxdm.md §5`](../core/cxdm.md) (Equality and comparison).

`cx:select` accepts a runtime CXPath string per [`spec/core/code.md`](../core/code.md) §5.5; this enables data-driven query construction without compile-time path binding.

### §2.2 Eval and analysis

| Fn | Signature | Returns | Purity |
|---|---|---|---|
| `cx:eval` | `($source::string $context::map $opts::map=$nil)` | `any` | impure |
| `cx:eval-tree` | `($tree::any $context::map=$nil $opts::map=$nil)` | `any` | impure |
| `cx:render` | `($template::string $context::map)` | `string` | impure |
| `cx:schema-of` | `($value::any)` | `any` (cxs schema) | pure |
| `cx:validate` | `($value::any $schema::any)` | `[sequence any]` | pure |
| `cx:anchors` | `($value::any)` | `[sequence string]` | pure |
| `cx:ids` | `($value::any)` | `[sequence string]` | pure |
| `cx:references` | `($value::any)` | `[sequence map]` | pure |
| `cx:resolve-includes` | `($value::any $root::string)` | `any` | impure |

`cx:render($t $ctx)` is sugar for `cx:serialize(cx:eval($t $ctx))` with permission to stream output directly.

`cx:validate` is the in-program form; [`spec/std-lib/validate.md`](../std-lib/validate.md) `validate:cxs` is an alias for stdlib namespace consistency.

`cx:resolve-includes` runs the [`spec/core/code.md`](../core/code.md) §13 `[?cx include]` resolution algorithm at runtime against an explicit root.

### §2.3 Transform helpers

| Fn | Signature | Returns | Purity |
|---|---|---|---|
| `cx:merge` | `($a::any $b::any $policy::string="last-wins")` | `any` | pure |
| `cx:strip-comments` | `($value::any)` | `any` | pure |
| `cx:strip-attrs` | `($value::any $pattern::string)` | `any` | pure |
| `cx:pretty-print` | `($value::any $opts::map=$nil)` | `string` | pure |

`cx:merge` policies: `last-wins` (b shadows a), `first-wins`, `error-on-conflict` (raises `CXER4110`).

`cx:pretty-print` opts: `indent` (int, default 2), `max-line-length` (int, default 80), `sort-attrs` (bool, default false), `strip-comments` (bool, default false).

---

## §3. `cx:eval` — sandbox semantics

`cx:eval($source $context)` evaluates `$source` as a CX source string against `$context` (a map binding names to values). `cx:eval` is `impure`, so the purity classifier (per [`spec/core/code.md`](../core/code.md) §6.5.x) refuses any `pure` `[?def]` body that reaches it (raises `CXER0233`).

### §3.1 Sandboxed by context

Inside the evaluated fragment, the only bindings visible are the keys of `$context`. No ambient capture:

- No `[?def]` definitions from the caller document.
- No inline `[?fn]` bindings from the caller scope.
- No `[?for]` / `[?let]` / `[?with]` bindings from the caller scope.
- No filesystem-relative paths inherit from the caller — `cx:resolve-includes` requires an explicit root.

To pass a function into the evaluated fragment, supply it as a context value:

```
[cx:eval $src {"transform": [?fn ($x) ...]}]
```

The fragment then references `$transform`.

### §3.2 Module pass-through is restrictive

The evaluated fragment inherits the caller's active `[?lib]` set. It MAY narrow (by omitting libs) but MUST NOT widen. A `[?lib]` inside the fragment naming a lib the caller did not load raises `CXER4113`.

### §3.3 Recursion-depth limit

Default cap **8** (mirrors [`spec/core/code.md`](../core/code.md) §13.7 `max_include_depth`). Configurable per-call via the `$opts` map:

```
[cx:eval $src $ctx {"max-depth": 16}]
```

Exceeding the depth raises `CXER4114`. The counter increments on each `cx:eval` invocation including indirect invocation through `cx:render`.

### §3.4 `cx:eval-tree` — tree-eval (no parse step)

`cx:eval-tree($tree $context $opts)` evaluates a **CXDM value** as code,
with **no parse step**. It is the function-form dual of the `[?eval]`
directive ([`spec/core/code.md`](../core/code.md) §6.4.4); `[?eval TREE [context MAP] [opts {…}]]`
desugars to `cx:eval-tree($tree $context $opts)`.

Because there is no source string, `CXER4100` (malformed source) is
structurally unreachable — the syntactic-injection class cannot arise.
`cx:eval-tree` **reuses the `cx:eval` sandbox wholesale**:

- **Context isolation** (§3.1) — only the keys of `$context` are visible;
  no ambient capture. `$context` defaults to `$nil` (an empty context).
- **Module pass-through** (§3.2) — inherits the caller's `[?lib]` set; may
  narrow, must not widen → `CXER4113`.
- **Depth limit** (§3.3) — default **8**, `opts.max-depth` configurable,
  exceed → `CXER4114`. `cx:eval-tree` shares the **same recursion counter**
  as `cx:eval` (one budget across string- and tree-eval, so alternating the
  two cannot bypass the cap).
- **Capability** — `cx:eval-tree` is `impure`; a `pure` `[?def]` reaching it
  raises `CXER0233`. Effects inside the evaluated tree are gated by the
  `eval` capability ([`spec/core/security.md`](../core/security.md)); a denial
  at an effect point raises `CXER0271`.

A node shape that is not evaluable as code in its position (e.g. a standalone
`[?attr]`) raises `CXER0238` ([`spec/core/code.md`](../core/code.md) §6.4.4.1);
an `[err]` produced *by* the evaluated code railway-propagates out unchanged.

---

## §4. AST-vs-wire distinction

`cx:parse` returns CXDM values matching the in-memory shape per [`spec/core/cxdm.md`](../core/cxdm.md); `cx:serialize` produces concrete-syntax bytes accepted by [`spec/core/grammar.ebnf`](../formal/grammar.ebnf). Round-trip identity `cx:serialize(cx:parse($t)) ≡ cx:canonical($t)` holds for any canonical input.

**Result shape (codec.md §7).** A source with a **single** top-level node parses to that node **directly**, so it is navigable as the value — `[?let [= $f [$cx:parse "[feature name=helm]"]] $f@name]` → `'helm'`. A source with **more than one** top-level node (e.g. a leading `[; … ]` comment plus a root element) parses to a transparent multi-root carrier; navigate it with the **descendant axis** (`$f//feature/@name`), since a direct child/attribute step on the multi-root carrier raises `CXER0001`. `[$cx:parse]` is the canonical form; the flat-dispatch alias `[$cx-parse]` is also accepted.

---

## §5. Conformance

Fixtures live at `conformance/stdlib/cx.cxd` (per the fixture `.txt`→`.cxd` cutover; one `.cxd` per module under `conformance/stdlib/`). Categories:

1. Round-trip identity — `cx:serialize(cx:parse($t)) == cx:canonical($t)` for every canonical fixture.
2. Cross-binding byte-identity per [`spec/misc/parity-matrix.md`](../misc/parity-matrix.md).
3. Error path — at least one fixture per code in §6.
4. Edge cases — empty value, single node, deep nesting, anchors, IDs / IDREFs, includes.
5. Purity — every `pure` function byte-identical across 10 repeated calls on identical input.

---

## §6. Error codes

`cx:` claims `CXER4100..CXER4119`:

| Code | Description |
|---|---|
| `CXER4100` | Malformed CX source (`cx:parse`) |
| `CXER4101` | Non-serializable value (`cx:serialize`) |
| `CXER4102` | Diff cannot apply to value (`cx:patch`) |
| `CXER4103` | Unknown format string (`cx:to-format`, `cx:from-format`) |
| `CXER4104` | Value not representable in target format (`cx:to-format`) |
| `CXER4105` | Parse failure in source format (`cx:from-format`) |
| `CXER4106` | Malformed CXPath expression (`cx:select`) |
| `CXER4107` | Include cycle (`cx:resolve-includes`) |
| `CXER4108` | Include not found (`cx:resolve-includes`) |
| `CXER4109` | Include traversal rejected (`cx:resolve-includes`) |
| `CXER4110` | Merge conflict under `error-on-conflict` (`cx:merge`) |
| `CXER4113` | Evaluated fragment widens `[?lib]` set (`cx:eval`) |
| `CXER4114` | Recursion depth exceeded (`cx:eval`) |
| `CXER4115` | Invalid name-pattern (`cx:strip-attrs`) |

`CXER4111`, `CXER4112`, `CXER4116..CXER4119` reserved.

---

## §7. Cross-references

- [`spec/core/code.md`](../core/code.md) §13 — `[?cx include]` lexical inclusion (companion to `cx:resolve-includes`).
- [`spec/core/code.md`](../core/code.md) §6.5.x — purity classification governing `cx:eval` reachability.
- [`spec/core/canonical.md`](../core/canonical.md) — canonical form returned by `cx:canonical`.
- [`spec/core/cxdm.md`](../core/cxdm.md) §4 (Identity / ID / IDREF) and §5 (Equality and comparison) — semantics underlying `cx:equal`. [`spec/core/canonical.md §§1.2, 4`](../core/canonical.md) — strict canonical bytes that `cx:hash` SHA-256s.
- [`spec/core/conversions.md`](../core/conversions.md) — format registry used by `cx:to-format` / `cx:from-format`.
- [`spec/std-lib/validate.md`](../std-lib/validate.md) — stdlib alias for `cx:validate`.
- [`spec/process/threat-model.md`](../process/threat-model.md) — eval-injection threat surface.
