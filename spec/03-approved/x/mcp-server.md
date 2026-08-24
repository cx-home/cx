# `cx-x/mcp-server` — MCP server helpers

```cx
[module-meta name=mcp-server tier=x status=experimental]
```

**Status:** Experimental (`x/` tier; cx-private #6 Y1; rewritten at stream 18 — L138/L141/L142/L113/L139/L140)

Normative reference for `cx-x/mcp-server` — the server counterpart to [`mcp.md`](mcp.md), at the **2025-06-18** protocol revision (one target, §1 there). Pure request readers + response builders over `cx-stdlib/jsonrpc` + `json`; the transport is the real `http:serve` with a `[?def]` handler.

---

## §1. The differentiator — capability-gated tools

A tool handler is ordinary CX, so its effects are gated by **CX capabilities at the effect point**: a tool that reads a file / opens a socket is denied (`CXER0271`) unless the server process was granted that capability. The language enforces the tool sandbox; the handler maps a denied effect to an `isError` tool result (`tool-error`). Annotations served in `tools/list` are HINTS — the one-way lossy-downward rule (L142): enforcement never depends on what a client believes. (Ties the PEP, cx-private #7.)

## §2. tools/list — derived, never materialized (L141)

`tools-for ($source::string)` → the tools array, derived **at list time** from module source via the [`tools.md`](tools.md) projection — no hand-kept registry exists to drift. `tool-json-of ($d::element)` maps ONE descriptor to the 2025-06-18 entry:

```json
{"name": …, "description": …, "inputSchema": {…}, "outputSchema": {…},
 "annotations": {"readOnlyHint": b, "idempotentHint": b, "destructiveHint": b, "openWorldHint": b},
 "_meta": {"source": "sha2-256:…", "code": "computes-as:…",
            "inputSchemaId": …, "outputSchemaId": …, "returnsType": …?, "requires": ["cap:…"]}}
```

The MCP adapter's lossy ruling: the authority story is **carried, not enforced, by the wire** — `_meta` projects the Tier-1 source address (the trust key an approval binds, L139), the Tier-2 code address, the JSON-emission schema ids, the `cap:` requirements, and the returns-type name for sophisticated clients; enforcement stays at the effect point and the propose boundary. A projection failure **propagates** as its `[err]` — a server must never advertise a silently empty or partial tool set. Named-return-type schema resolution (store-backed, impure — tools.md §4) is the adapter-side follow-up under grants.

## §3. tools/call — the propose-only boundary (L113/L139/L140)

An MCP `tools/call` **never executes a command** — the boundary forces propose mode:

- `propose-call ($id $command::function $args::map)` — construct the proposal (`cx:propose`: the name-keyed args record binds the parameter list; preconditions evaluate; the effect set resolves; **the body never runs**) and shape the reply.
- `propose-result ($id $proposal::element)` — the reply: one text content block carrying the proposal's **canonical CX text** (the identity-bearing bytes — its Tier-1 address recomputes from them) and `structuredContent.address` = the proposal's Tier-1 address (**what an out-of-band approval binds**). `isError: false` — a proposal IS the successful outcome of a propose-only call.

A refused proposal (unknown args, false precondition, non-command) raises its `CXER411x`; the handler maps it to `tool-error`. Approval and commit are `cx-stdlib/authz`'s (`approve` mints the address-bound claim; `commit` verifies fail-closed — address binding, tier signature, propose-only screening, `cap:` re-resolution, the **exact Tier-1 def-text version** (L139), precondition re-check — then executes, debits, journals).

## §4. Function surface

| Fn | Signature | Purity |
|---|---|---|
| `method-of` / `id-of` / `tool-name-of` / `tool-args-of` | request readers | pure |
| `initialize-result` | `($id $name::string $version::string)` → map | pure |
| `tools-list-result` | `($id $tools)` → map | pure |
| `tool-json-of` | `($d::element)` → map | pure |
| `tools-for` | `($source::string)` → any | pure |
| `tool-result` / `tool-error` / `protocol-error` | reply builders | pure |
| `propose-result` | `($id $proposal::element)` → map | pure |
| `propose-call` | `($id $command::function $args::map)` → map | pure |

## §5. The offline lane

`cx tools export MODULE.cx` projects the same tools array without a server (offline registration) by **evaluating this same CX adapter** — one engine, never a V-side reimplementation; module bytes enter verbatim (the Tier-1 basis is never re-serialized). A projection refusal exits 2 with the `[err]` on stderr. Gated byte-for-byte by `make tools-export-gate`.

## §6. Loading and conformance

Bundled; `[?lib 'cx-x/mcp-server']`; under `bundled_x_names()`. Fixtures: `conformance/stdlib/mcp-server.cxd` — the shape cases, THE refund-order `tools/list` golden (`mcp-server-007`), the fail-loud negative (008), the propose-reply golden (009), and the **never-executes discriminator** (010: a real traceable effect body whose `out-effects` trace stays empty across `propose-call`). The live server + capability-denial round-trip is `vcx/tests/mcp_server_real_test.v`.

## §7. Cross-references

- [`tools.md`](tools.md) — the ONE descriptor model; [`mcp.md`](mcp.md) — the client.
- `spec/03-approved/core/commands_effects.md` §5 — propose mode, the args record, approval binding (L139 amended).
- [`spec/03-approved/std-lib/authz.md`](../std-lib/authz.md) — approve/commit.
