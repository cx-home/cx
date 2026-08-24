# `cx-x/*` — the experimental (`x/`) tier

**Status:** Experimental tier (cx-private #6 D3; per-module specs completed at stream 18, #690 — the G15 spec-all disposition, L144)

The `x/` tier holds the fast-moving **agentic protocol shims**. Per cx-private #6 (decision D3), it is **in-tree** (one repo, one toolchain, one gate) but **explicitly exempt from the frozen-stability promise**: a module may change in a semver-breaking way while its protocol settles. Resolvers name `cx-x/<name>`; sources live under the repo-root `x/` directory; modules are enumerated by `bundled_x_names()`, separate from the frozen `cx-stdlib/*` surface (the frozen-surface canary never counts them). Ring/pack placement: `cx_partition.md` §4 (run/mcp/a2a/llm/tools/adjudicate = Ring 1 packs; mcp-server/a2a-xap = Ring 2).

**Design thesis.** The churny agentic protocols (MCP, A2A) decompose into a **stable substrate** + **thin shims**. The substrate is frozen `cx-stdlib` — `jsonrpc` (the JSON-RPC wire), `jsonschema` (tool-schema validation), the `http` client/server, `json`, plus the trust/coordination primitives (`did`/`vc`/`journal`/`bus`/`authz`). Every shim is **pure CX composition over that substrate — no new transport, no V backing**. A shim graduates to the frozen surface only once its protocol is stable.

**The agent-tool spine (stream 18).** [`tools.md`](tools.md) defines ONE tool-descriptor model derived from command defs at call time; [`mcp-server.md`](mcp-server.md) and [`a2a.md`](a2a.md) are its two lossy adapters; the `tools/call` boundary is **propose-only** (a command never executes on an agent's call — approval is out-of-band, commit re-checks the exact Tier-1 version); [`a2a-xap.md`](a2a-xap.md) realizes the pending approval durably as the `input-required` task state.

## Module specs

| Module | Spec | One line |
|---|---|---|
| `cx-x/run` | [`run.md`](run.md) | the Runnable convention + combinator library (the foundation) |
| `cx-x/llm` | [`llm.md`](llm.md) | minimal LLM provider (Ollama `/api/chat`) — the first Runnable |
| `cx-x/tools` | [`tools.md`](tools.md) | the agent-tool projection: command defs → ONE descriptor model |
| `cx-x/mcp` | [`mcp.md`](mcp.md) | MCP client at the 2025-06-18 revision (one target) |
| `cx-x/mcp-server` | [`mcp-server.md`](mcp-server.md) | MCP server: capability-gated tools; derived tools/list; propose-only tools/call |
| `cx-x/a2a` | [`a2a.md`](a2a.md) | A2A client + skills derived from the same projection |
| `cx-x/a2a-xap` | [`a2a-xap.md`](a2a-xap.md) | tasks→journal, messages→bus, auth→did/vc; durable pending approval |
| `cx-x/adjudicate` | [`adjudicate.md`](adjudicate.md) | agent adjudicator for the `similar` review band (#376) |
| `cx-x/term` | [`term.md`](term.md) | raw-mode terminal input; `select` unifies keystrokes and live sources in one loop |

## Cross-references

- [`spec/03-approved/std-lib/README.md`](../std-lib/README.md) §3.3 — the tier's placement in the surface.
- [`spec/03-approved/std-lib/jsonrpc.md`](../std-lib/jsonrpc.md) / [`jsonschema.md`](../std-lib/jsonschema.md) — the frozen substrate the shims consume.
- `spec/03-approved/x/agent_tool_projection.md` — stream 18's ruled letters (L138–L146).
