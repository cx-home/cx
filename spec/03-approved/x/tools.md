# `cx-x/tools` — the agent-tool projection

```cx
[module-meta name=tools tier=x status=experimental]
```

**Status:** Experimental (`x/` tier — exempt from the frozen-stability promise; stream 18, cx-private #690; letters L138–L146)

Normative reference for `cx-x/tools` — **ONE tool-descriptor model derived from command definitions at call time**. Both protocol adapters (MCP `tools/list` via [`mcp-server.md`](mcp-server.md), A2A skills via [`a2a.md`](a2a.md)) consume the same descriptors and each rules what it drops (L141). There is **no materialized manifest** — descriptors derive from module source when asked, so they cannot drift from the code.

---

## §1. The projection

`descriptors-of ($source::string)` → a sequence of `[tool …]` descriptor elements, one per **command** in the module source. A command is a `[?def]` whose `[effects]` clause is **present** — clause presence, not item count, is the discriminator (a zero-item `[effects]` still marks a command; commands_effects.md).

Two lanes over the same source bytes:

- **AST lane** — `[$cx:ast $source]` ([`modules/cx.md`](../modules/cx.md) §2.2, L146): the structured defs (params with kind / type / default-presence, effects items, requires, idempotent, returns, purity, and the **verbatim def source** — the Tier-1 address basis).
- **Data lane** — `[$cx:parse $source]`: the `[fn-doc]` blocks, paired by def name — `[summary]` (the description) and `[param-doc name=…]` (per-property descriptions; stdlib_colocated_docs.md).

**Fail-loud (L143):** a command def whose `[fn-doc]` lacks a `[summary]` refuses the WHOLE projection with one `[err code=missing-summary …]` naming every undocumented command — never a partial list. Malformed source propagates the `cx:ast` error — never a silent empty projection.

## §2. The descriptor shape

```cx
# verify-skip — shape template: `<…>` marks caller-supplied values
[tool name=<def name>
  [description <[fn-doc][summary] text>]
  [input-schema  {type: 'object', properties: {…}, required: (…), additionalProperties: <bool>}]
  [output-schema {…}]
  [annotations read-only=<b> idempotent=<b> destructive=<b> open-world=<b>]
  [meta [source <Tier-1 addr>] [code <Tier-2 addr>]
        [input-schema-id <sha2-256:…>] [output-schema-id <sha2-256:…>]
        [returns-type <T>]?
        [requires ([cap <cap:…>] …)]]]
```

## §3. Field rules (L142)

| Field | Source | Rule |
|---|---|---|
| `name` | def name | verbatim |
| `description` | `[fn-doc][summary]` | REQUIRED — fail-loud (§1) |
| `input-schema` properties | params via the stream-16 carrier conventions (`type-schema-of`) | decimal/bigint/temporals/bytes ride **string carriers**; `[param-doc]` text becomes the property `description` |
| `input-schema` required | the **non-defaulted positionals** | default presence read structurally from the AST lane |
| `input-schema` additionalProperties | rest-param presence | a rest param (`*$name`) opens the object and never becomes a property; otherwise CLOSED (a command's args-map binds the parameter list — the `cx:propose` record basis) |
| `output-schema` | `[returns T]` through the carrier mapping | a kind name maps directly; a **named type** projects the open object and carries its name in `[returns-type]` (§4) |
| `read-only` | `pure`, or effects ⊆ {read, env, clock} | the empty (zero-item) clause is trivially inside the set |
| `idempotent` | the `[idempotent]` clause | EXACT; absent ⇒ false |
| `destructive` | `NOT read-only` | MCP's own default; no new clause |
| `open-world` | `net ∈ effects` | ruled explicitly, not inferred |
| `[meta][source]` | `cx:hash` of the verbatim def text | the **Tier-1 trust key** an approval binds (L139) |
| `[meta][code]` | `cx:computation-id` of the def | Tier-2 — cache/equivalence only, never trust |
| schema ids | sha2-256 of each schema's **JSON emission** | the adapter-visible bytes — drift detectable at the protocol surface (the CX canonical lane is #810-blocked for singleton sequences in map values) |
| `[meta][requires]` | the `[requires cap:…]` clause | carried AND enforced regardless (the one-way lossy-downward rule) |

**The one-way lossy-downward rule (L142, normative):** every annotation is a HINT — a courtesy for the client's UI. Enforcement is at the CX effect point (`CXER0271`) and at the boundary (propose mode + PEP), independent of anything a client believes.

## §4. Named return types

Resolving a type NAME to its schema is store-backed and fail-closed (the shape_inference.md L63 registry re-ruling: `CX_SCHEMA_STORE` + `cx.lock` pins) — inherently **impure**, so it can never live in this pure projection. A named `[returns T]` projects the open object schema and carries the name in `[meta][returns-type]` (and the MCP adapter's `_meta.returnsType`) so the unresolved case is visible, never silent. Adapter-side resolution under grants is the named follow-up (see [`mcp-server.md`](mcp-server.md)).

## §5. Function surface

| Fn | Signature | Purity |
|---|---|---|
| `descriptors-of` | `($source::string)` → `[sequence element]` \| `[err …]` | pure |
| `type-schema-of` | `($kind::string)` → `map` | pure |

## §6. Loading and conformance

Bundled; resolves via `[?lib 'cx-x/tools']`; enumerated under `bundled_x_names()`. Fixtures: `conformance/stdlib/tools.cxd` (the refund-order golden descriptor — the M5 worked example; the fail-loud negative; discriminator, rest-param, carrier, requires/idempotent, and malformed-source cases). The offline lane `cx tools export` is gated byte-for-byte by `make tools-export-gate` (`conformance/tools-export/`).

## §7. Cross-references

- [`spec/03-approved/modules/cx.md`](../modules/cx.md) §2.2 — `cx:ast`, the structured-input surface (L146).
- `spec/03-approved/core/commands_effects.md` — the command discriminator, propose mode, the §5 arg record.
- `spec/03-approved/x/agent_tool_projection.md` — the stream's ruled letters (L138–L146).
- [`mcp-server.md`](mcp-server.md) / [`a2a.md`](a2a.md) — the two lossy adapters.
