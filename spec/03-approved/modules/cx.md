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
| `cx:computation-id` | `($def::string)` | `string` (computation-identity claim) | pure |
| `cx:plan-address` | `($comp::string)` | `string` (plan address) | pure |
| `cx:type-binding` | `($value::any $schema::string)` | `element` (`[type-binding …]` claim) | pure |
| `cx:type-binding-verify` | `($claim::element $value::any $schema::string)` | `bool` (`true`, or typed refusal) | pure |
| `cx:version` | `()` | `string` (the full runtime semver) | pure |
| `cx:builtins` | `()` | `map` (the two-tables builtin-set value) | pure |
| `cx:env` | `()` | `map` (the canonical environment record) | pure |
| `cx:propose` | `($command::function $args::map $opts::map {})` | `element` (`[proposal …]` value) | impure |

`cx:canonical` returns the canonical form per [`spec/core/canonical.md`](../core/canonical.md).
`cx:hash` returns the SHA-256 content hash of the node's strict canonical bytes per [`spec/core/canonical.md §1.2`](../core/canonical.md) (text default) / [`spec/core/canonical.md §4`](../core/canonical.md) (binary `cx_to_data_bin`).
Format strings accepted by `cx:to-format` / `cx:from-format`: `xml`, `json`, `yaml`, `toml`, `md`, `csv`, `tsv`, `psv`, `cx`. The registry lives at [`spec/core/conversions.md`](../core/conversions.md).

`cx:equal` is canonical-aware (normalises both sides through `canonical` first), anchor-resolving, and ID-aware per [`spec/core/cxdm.md §4`](../core/cxdm.md) (Identity / ID / IDREF) and [`spec/core/cxdm.md §5`](../core/cxdm.md) (Equality and comparison).

`cx:select` accepts a runtime CXPath string per [`spec/core/code.md`](../core/code.md) §5.5; this enables data-driven query construction without compile-time path binding.

`cx:computation-id` returns the **computation identity** of a `[?def …]`
source — the "same function?" relation of [`spec/core/code-identity.md`](../core/code-identity.md)
§2 (SHA-256 of the normalized program AST; alpha-/name-/comment-/
format-invariant). It is **document identity's orthogonal twin**: document
identity (`cx:hash`, the hash of canonical bytes) answers "same bytes?",
computation identity answers "same computation?". The result is a
**claim**, NEVER an object address — spelled `computes-as:<algo>:<hex>`
(a distinct token the tagged-address reader refuses, so it can never be
mistaken for, or used as, a document address). Computation identity is
only ever a derived index or a recompute-and-refuse verification claim
(RULED F1/A1/A2, 2026-08-08); it is never a storage key of record. A
source that is not a single parseable `[?def …]` raises `CXER0100`; a
non-string / non-serializable argument raises `CXER4101`.

`cx:plan-address` returns the **plan address** of a planar
comprehension — the caching-identity tier above E1 text identity per
[`spec/core/code.md`](../core/code.md) §7.9 (stream-2 ruling L93). The
argument is `[?for]` / `[?for-array]` / `[?for-map]` source text (a
non-string value serializes first, the string-as-source pivot). The
§7.8 six-point membership test gates entry: a non-member returns the
typed error `cx-err:CXER0120 E_NOT_PLANAR` whose message names the
violated point — this function is the membership test's canonical
runtime consumer. The result is the distinct token
`plan:<algo>:<hex>` (default `plan:sha2-256:<hex>`): never a document
address (the tagged-address reader refuses it), never a `computes-as:`
claim. Equivalent spellings share one address (alpha-respellings, hint
placement, `[limit]`-vs-`[take]`, literal λ composition); distinct
plans get distinct addresses. Malformed source raises `CXER4100`; a
non-serializable argument raises `CXER4101`.

`cx:type-binding` constructs the **Lane-2 type-identity claim**
`[type-binding [subject hash=…] [name …] [schema sha2-256:…]]`
(E2/L82–L83, `semantic_value_model` §3; I5 stream 1). The pair
`(element name, schema content-hash)` is recoverable-by-computation —
the name comes from the subject's root element, the address from the
schema text in force — and this function materializes the assertable
form. Anchoring preconditions are enforced **fail-closed**
(`CXER4116`): the schema must load clean and declare **exactly one
type** naming the subject's root element (one-type-per-schema-document
is normative for identity-anchoring schemas — multi-type documents
validate but cannot anchor). The E1 totality refusals propagate
through the `cx:hash` acquisition path (`CXER4101`/`4117`/`4118`): a
value with no Tier-1 address cannot anchor a type identity. The claim
is a plain value — never intrinsic fields on the subject.

`cx:type-binding-verify` verifies a presented claim at a trust
boundary (the #702 fail-closed posture): the claim is recomputed from
the value and the schema in force and compared field by field. Any
malformation or mismatch raises `CXER4119`; anchoring-precondition
failures surface as the `CXER4116` they are. Returns `true` only on a
complete match. Resolution of a schema BY its address
(`CX_SCHEMA_STORE`, `cx schema` verbs) is the shape-inference stream's
surface — this function takes the schema text itself.

`cx:version` / `cx:builtins` / `cx:env` are the **environment
quadrant** of the computation-identity record (stream 5, ruling L103;
`computation_identity.md` §3) — three zero-arg **pure** builtins,
constants of the runtime build (same value on every run, on every
host, for a given build; host-dependence here would be the L7a
conformance bug):

- **`cx:version`** — the FULL runtime semver, derived from the
  repo-root `VERSION` single source (the `cx_version` build define;
  unreleased dev/test builds report `0.0.0-dev`). Full semver by
  ruling: a patch can fix a determinism bug, so a patch MUST
  invalidate computation addresses — correct-by-construction beats
  hit rate.
- **`cx:builtins`** — the canonical CX value listing the two closed,
  governance-amended spec tables: the `code.md` §4.1 program-directive
  registry and the §6.5.x built-in purity classification (bare names
  plus module primitives), as
  `{directives: (<sorted names>), purity: {<name>: 'pure'|'impure'}}`.
  Host-independent by construction — NEVER `cx_features` or a binary
  hash. The **builtin-set id** is the plain Tier-1 address of this
  value, so any party re-derives and verifies it in-language:
  `[$cx:hash [$cx:builtins]]` (the M5 re-hash-to-verify property).
- **`cx:env`** — the canonical environment record itself:
  `{builtins: <Tier-1 of cx:builtins>, runtime: <cx:version>,
  schema-dialect: <the S020-enforced dialect semver>}` (map-shaped =
  self-canonicalizing). The additivity contract: a new environment
  field APPENDS — every computation address changes exactly once; the
  old cache is cold, never wrong, no negotiation. The honest residue
  (a behavioral change to a native primitive with no table change) is
  covered by the runtime-version field.

### §2.2 Eval and analysis

| Fn | Signature | Returns | Purity |
|---|---|---|---|
| `cx:eval` | `($source::string $context::map $opts::map=$nil)` | `any` | impure |
| `cx:eval-tree` | `($tree::any $context::map=$nil $opts::map=$nil)` | `any` | impure |
| `cx:ast` | `($source::string)` | `string` (JSON) | pure |
| `cx:render` | `($template::string $context::map)` | `string` | impure |
| `cx:schema-of` | `($value::any)` | `any` (cxs schema) | pure |
| `cx:validate` | `($value::any $schema::any)` | `[sequence any]` | pure |
| `cx:anchors` | `($value::any)` | `[sequence string]` | pure |
| `cx:ids` | `($value::any)` | `[sequence string]` | pure |
| `cx:references` | `($value::any)` | `[sequence map]` | pure |
| `cx:resolve-includes` | `($value::any $root::string)` | `any` | impure |

`cx:render($t $ctx)` is sugar for `cx:serialize(cx:eval($t $ctx))` with permission to stream output directly.

**`cx:ast` — the declaration-AST projection (agent-tool projection
stream, L146).** Parses `$source`'s module-declaration header — the
same `[?lib]` / `[?def]` / `[?const]` scan the module loader runs at
declaration registration — and returns the
[`spec/core/ast.md`](../core/ast.md) program-AST JSON projection:

```json
{"type": "Program", "libs": [/* LibNode */], "consts": [/* ConstNode */], "defs": [/* DefNode */],
 "docs": ["<verbatim top-level plain-element span>", …]}
```

Arrays are omitted when empty (the ast.md omit-when-absent
convention); a source with no declarations projects as
`{"type":"Program"}`. **`docs`** carries the module's top-level
PLAIN (non-directive) element spans as **verbatim source strings**,
in order — the co-located doc blocks (`[module-doc]` / `[fn-doc]`)
among them. Each span parses cleanly as DATA on its own; consumers
`[$cx:parse]` per span and pair by name. This is the doc lane the
agent-tool projection and the doc-freshness gate ride — a
whole-module data parse is NOT equivalent (program-bearing def
bodies degrade it; the spans lane is immune by construction). Each `DefNode` carries the full `[?def]`
surface including the command clauses (`effects` — emitted on clause
PRESENCE, an empty array is the zero-item clause; `requires`;
`preconditions`; `idempotent` (+ window); `compensates`;
`requires_at`) and structured params (`kind` / `name` / `type` /
`default` presence) — the structured input the agent-tool projection
consumes (a def's head and params are data-layer text runs, not
reachable by CXPath; this is the CX-callable twin of what the module
loader, computation identity, and LSP lanes read). Module BODY
expressions are not part of this projection — the contract is the
declaration header, exactly the set the module system itself
extracts.

The argument is a **source string only**. A directive-as-data value
(e.g. a CXPath-recovered `[?def]` focus) is refused with `CXER0100`:
canonical serialization quotes directive-head text runs, which is not
program-parseable source — project from the module source and pair by
def name. Malformed declarations raise `CXER4100` — loud, never a
silently skipped declaration. Fixtures: `conformance/code.cxd`
`cxast-001`–`cxast-005` (placed with the command-clause `cmd-` family
they exercise).

`cx:validate` is the in-program form; [`spec/std-lib/validate.md`](../std-lib/validate.md) `validate:cxs` is an alias for stdlib namespace consistency.

`cx:resolve-includes` runs the [`spec/core/code.md`](../core/code.md) §13 `[?cx include]` resolution algorithm at runtime against an explicit root.

### §2.3 Transform helpers

| Fn | Signature | Returns | Purity |
|---|---|---|---|
| `cx:merge` | `($a::any $b::any $policy::string="last-wins")` | `any` | pure |
| `cx:strip-comments` | `($value::any)` | `any` | pure |
| `cx:strip-attrs` | `($value::any $pattern::string)` | `any` | pure |
| `cx:pretty-print` | `($value::any $opts::map=$nil)` | `string` | pure |

`cx:merge` policies: `last-wins` (b shadows a — the default), `first-wins`
(a shadows b), `error-on-conflict`. **Semantics (implemented, stream 9 —
#719):** elements of the SAME name merge — attributes union (a value
collision is one policy point at `<path>/@name`), element children pair BY
NAME (first unpaired match) and merge recursively, unpaired children keep
source order (a's, then b's), differing non-element bodies are one policy
point at the element's path; elements of different names, differing
scalars, arrays, and mixed kinds are one policy point each; maps union
per-key with colliding keys recursing. **Conflicts are VALUES** (the
distributed-store alignment): `error-on-conflict` raises `CXER4110` whose
err CARRIES every collision as a typed `[conflict subject=<path>
kind=:merge-value [ours <a-side>] [theirs <b-side>]]` child — the ONE
conflict shape (`distributed_store.md` §4), never a bare message.

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
| `CXER4116` | E_CX_TYPE_ANCHOR_REFUSED — the schema cannot anchor a type identity: it fails to load, declares more or fewer than exactly one type (L83 one-type-per-schema-document, normative for anchoring), or its declared type / header `of` does not name the subject's root element (`cx:type-binding`; I5 stream 1) |
| `CXER4117` | E_CX_ITERATOR_NO_ADDRESS — identity acquisition refuses an iterator: its identity would depend on consumption state, and an infinite source would hang the hash path; materialize deliberately (`[?to-sequence]`) and hash the value (`cx:hash`; I1 E1 totality, audit C4) |
| `CXER4118` | E_CX_SECRET_NO_ADDRESS — a secret-bearing value has no Tier-1 address: hashing the plaintext would make every address a secret-confirmation oracle, hashing the redacted form would give two different secrets one address (`cx:hash`; I1 E1 totality, audit C4) |
| `CXER4119` | E_CX_TYPE_BINDING_INVALID — a presented `[type-binding]` claim fails fail-closed verification: malformed shape, subject-address mismatch, type-name mismatch, or schema-address mismatch against the recomputation (`cx:type-binding-verify`; I5 stream 1) |
| `CXER4111` | E_CX_PROPOSAL_INVALID — `cx:propose` refused: argument 1 is not a command function value (no `[effects …]` clause), the args map does not bind the parameter list, or a precondition source does not parse (`cx:propose`; commands and effects, stream 6 — L113) |
| `CXER4112` | E_CX_PRECONDITION_FAILED — a `[preconditions …]` predicate is false (or faults) at propose: the proposal is refused — nothing coherent to approve; commit-side re-evaluation divergence is the authz commit refusal (`cx:propose`; stream 6 — L113) |

(`CXER4111`/`CXER4112` were the band's two reserved slots — claimed by
`cx:propose` at stream 6.)

### `cx:propose` — the proposal-value constructor (commands and effects, L113)

Constructs the **proposal value** for a command call WITHOUT executing
it — the engine half of propose mode (the BOUNDARY decides the mode;
approval and commit are `cx-stdlib/authz` §3.9). The value:

```
[proposal
  [command tier1=<Tier-1 of the def TEXT> code=<Tier-2 computes-as:>]
  [args {param: value, …}]        ← post-default, param-name-keyed
  [effects [CAP scope*]*]          ← resolved set (v1: == declared)
  [preconditions [ok EXPR]*]       ← each EVALUATED at propose
  [via …]?                         ← authority basis (opts.via)
  [idempotency-key '…']?           ← explicit (opts) or derived
  [tenant '…']]
```

- **Tier-1 of the definition text is the TRUST key** (the stream-18
  L139 amendment): an approval binds the proposal's address, and the
  proposal binds the exact def version — `[effects]` is outside the
  Tier-2 hash, so only the Tier-1 text address prevents an approval
  replaying against a command whose declared effects were widened.
  Tier-2 (`code=`) rides for cache/equivalence only, never a trust
  input.
- A FALSE (or faulting) precondition at propose **refuses the
  proposal** (`CXER4112`) — nothing coherent to approve. Commit
  re-evaluates; divergence refuses there (authz §3.9).
- The proposal is an ORDINARY CX value: `cx:hash` gives its address; a
  re-lowering with different args is a DIFFERENT proposal (tampering
  moves the address — the approval binding catches it).

**Totality (I1, E1):** identity acquisition REFUSES three value classes
with typed errors — closures (`CXER4101`), iterators (`CXER4117`),
secret-bearing values (`CXER4118`) — never a silent fallback or
coercion. A closure captures an environment no canonical text can
carry; the other two rows above state their own rationales.

---

## §7. Cross-references

- [`spec/core/code.md`](../core/code.md) §13 — `[?cx include]` lexical inclusion (companion to `cx:resolve-includes`).
- [`spec/core/code.md`](../core/code.md) §6.5.x — purity classification governing `cx:eval` reachability.
- [`spec/core/canonical.md`](../core/canonical.md) — canonical form returned by `cx:canonical`.
- [`spec/core/cxdm.md`](../core/cxdm.md) §4 (Identity / ID / IDREF) and §5 (Equality and comparison) — semantics underlying `cx:equal`. [`spec/core/canonical.md §§1.2, 4`](../core/canonical.md) — strict canonical bytes that `cx:hash` SHA-256s.
- [`spec/core/conversions.md`](../core/conversions.md) — format registry used by `cx:to-format` / `cx:from-format`.
- [`spec/std-lib/validate.md`](../std-lib/validate.md) — stdlib alias for `cx:validate`.
- [`spec/process/threat-model.md`](../process/threat-model.md) — eval-injection threat surface.
