# `cx-x/mcp` — MCP client

```cx
[module-meta name=mcp tier=x status=experimental]
```

**Status:** Experimental (`x/` tier; cx-private #6 S9; protocol target re-ruled at stream 18, L138)

Normative reference for `cx-x/mcp` — a minimal MCP (Model Context Protocol) **client**. MCP is JSON-RPC 2.0 over a transport; the client is pure composition over the frozen substrate (`cx-stdlib/jsonrpc`, `jsonschema`, the real `http` client, `json`) — no new transport, no V backing.

---

## §1. Protocol target (L138)

**The 2025-06-18 MCP revision, and only it** — the revision that carries `outputSchema`, `annotations`, `structuredContent`, and `_meta`. There is **no revision-conditional emission** anywhere: one target, pinned by the `initialize-request` golden (`mcp-007`). The prior 2024-11-05 pin is retired (cutover, no dual-accept).

## §2. Function surface

| Fn | Signature | Purity |
|---|---|---|
| `initialize-request` | `($id $client-name::string $client-version::string)` → map | pure |
| `list-tools-request` | `($id)` → map | pure |
| `call-tool-request` | `($id $name::string $arguments)` → map | pure |
| `tools-of` | `($response)` → any | pure |
| `result-text` | `($response)` → string | pure |
| `validate-args` | `($tool $arguments)` → element | pure |
| `rpc-call` | `($endpoint::string $request)` → any | impure (net) |
| `list-tools` | `($endpoint::string)` → any | impure (net) |
| `call-tool` | `($endpoint::string $name::string $arguments)` → string | impure (net) |

`validate-args` checks an arguments object against a tool's JSON-Schema `inputSchema` (`[ok]` / `[invalid [violation …]]` via `cx-stdlib/jsonschema`) — call it before `call-tool` to enforce the tool contract client-side. Transport is Streamable HTTP (POST the request; the reply is the JSON-RPC response); stdio transport is a later increment.

## §3. Composition

A remote tool composes as a Runnable ([`run.md`](run.md)) via the call-site closure idiom:

```cx
[$run:invoke [?fn ($a) [$mcp:call-tool $endpoint "get_weather" $a]] {city: "NYC"}]
```

## §4. The propose-only expectation

When the peer is a CX command server ([`mcp-server.md`](mcp-server.md)), a `tools/call` reply is a **proposal**, not an execution result: the content block carries the proposal's canonical CX text and `structuredContent.address` its Tier-1 address. Approval is out-of-band (L140 — MCP **elicitation is an explicit non-goal** for approvals: it would place the signing interaction on the agent's client, inverting the trust model; the agent holds only a propose-only sub-delegation).

## §5. Loading and conformance

Bundled; `[?lib 'cx-x/mcp']`; under `bundled_x_names()`. Fixtures: `conformance/stdlib/mcp.cxd` (request/extractor/validation shapes + the protocol pin `mcp-007`); the live client↔server round-trip is `vcx/tests/mcp_real_test.v`.

## §6. Cross-references

- [`mcp-server.md`](mcp-server.md) — the server counterpart; [`tools.md`](tools.md) — the descriptor model its `tools/list` serves.
- [`spec/03-approved/std-lib/jsonrpc.md`](../std-lib/jsonrpc.md) / [`jsonschema.md`](../std-lib/jsonschema.md) — the frozen substrate.
