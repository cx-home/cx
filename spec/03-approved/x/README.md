# `cx-x/*` — the experimental (`x/`) tier

**Status:** Experimental tier (cx-private #6 D3)

The `x/` tier holds the fast-moving **agentic protocol shims**. Per cx-private #6 (decision D3), it is **in-tree** (one repo, one toolchain, one gate) but **explicitly exempt from the frozen-stability promise**: a module may change in a semver-breaking way while its protocol settles. The experimental status is marked in each module header and here; resolvers name `cx-x/<name>`; sources live under the repo-root `x/` directory. Modules are enumerated by `bundled_x_names()`, separate from the frozen `cx-stdlib/*` surface (the frozen-surface canary never counts them).

**Design thesis.** The churny agentic protocols (MCP, A2A) decompose into a **stable substrate** + **thin shims**. The substrate is frozen `cx-stdlib` — `jsonrpc` (the JSON-RPC wire), `jsonschema` (tool-schema validation), the `http` client/server, `json`, plus the trust/coordination primitives (`did`/`vc`/`journal`/`bus`/`authz`). Every shim below is therefore **pure CX composition over that substrate — no new transport, no V backing**. A shim graduates to the frozen surface only once its protocol is stable.

The foundational convention, [`cx-x/run`](run.md) (the Runnable), has its own spec. The protocol shims are documented here.

---

## `cx-x/llm` — minimal LLM provider (the first Runnable)

Targets the Ollama `/api/chat` protocol (local, keyless). Pure shaping (`chat-request`, `completion-of`, `user-message`) is split from the effectful `complete` (POST one prompt → completion text), which composes `http:post` + `json`. Compose it as a Runnable via the call-site idiom: `[$run:invoke [?fn ($p) [$llm:complete $base $model $p]] "Hi"]`. Run under a scoped net grant (`--allow-net=127.0.0.1:11434`), never `--allow-all`. `stream` (NDJSON token sequence) is deferred. Fixtures: `conformance/stdlib/llm.cxd` + a live mock-server round-trip (`vcx/tests/llm_real_test.v`).

## `cx-x/mcp` — MCP (Model Context Protocol) client

MCP is JSON-RPC 2.0 over HTTP, so the client is composition over `jsonrpc` + `http` + `json` + `jsonschema`. Pure builders (`initialize-request`, `list-tools-request`, `call-tool-request`) + extractors (`tools-of`, `result-text`) + **`validate-args`** — checks an arguments object against a tool's JSON-Schema `inputSchema` (`[ok]`/`[invalid …]`) before calling (the `jsonschema`/S7 payoff). Effectful transport: `rpc-call`, `list-tools`, `call-tool` (Streamable HTTP). A remote tool composes as a Runnable via `[?fn ($a) [$mcp:call-tool $endpoint $name $a]]`. Fixtures: `conformance/stdlib/mcp.cxd` + a mock-server round-trip.

## `cx-x/mcp-server` — MCP server helpers

The server counterpart: pure request readers (`method-of`, `id-of`, `tool-name-of`, `tool-args-of`) + JSON-RPC response builders (`initialize-result`, `tools-list-result`, `tool-result`, `tool-error`, `protocol-error`). The transport is the real `http:serve`; a `[?def]` handler reads the request, dispatches on the method, runs the tool, and returns a `[response]`.

**The differentiator (ties [`spec/03-approved/xap/xap.md`](../xap/xap.md)'s PEP / #7).** A tool handler is ordinary CX, so its effects are gated by **CX capabilities** at the effect point — a tool that reads a file / opens a socket is **denied** (`CXER0271`) unless the server was granted that capability, which the handler maps to an `isError` tool result via `tool-error`. The language enforces the tool sandbox. Proven end-to-end (server + denial) in `vcx/tests/mcp_server_real_test.v`; pure helpers in `conformance/stdlib/mcp-server.cxd`. A *generic* tool registry (closures-in-data dispatched by name) awaits #45; direct `[?if]` dispatch works today.

## `cx-x/a2a` — A2A (Agent-to-Agent) client

A2A is also JSON-RPC over HTTP. Pure shaping (`text-part`, `message`, `user-message`, `send-request`, `agent-card`) + extractors (`message-text`, `task-state`) + the effectful `send-message` / `ask`. An A2A peer composes as a Runnable via `[?fn ($t) [$a2a:ask $endpoint $t]]`. Fixtures: `conformance/stdlib/a2a.cxd` + a cx↔cx round-trip (`vcx/tests/a2a_real_test.v`).

## `cx-x/a2a-xap` — A2A over the xap substrate

The distinctive positioning: A2A semantics mapped onto CX's durable substrate, not a bespoke store.

- **tasks → `journal`**: a task lifecycle (`submitted → working → completed | failed | canceled`) is recorded as hash-chained `journal` events — **replayable** (`history` + `lifecycle` projection) and **tamper-evident** (`journal:verify`). `task-event` / `record` / `history` / `lifecycle`.
- **messages → `bus`**: `publish-message` fans an A2A message out to every `bus` subscriber (live pub/sub, the complement to the durable journal). `message-envelope` / `publish-message`.
- **auth → `did` + `vc`**: an agent is a **DID**, and authority is a DID-signed capability **delegation** carried as a Verifiable Credential (§22.2) — the same `[delegation …]` claim that is the input to the PEP, so A2A trust and the capability model are one mechanism. `agent-did` / `grant-credential` / `grant-status`.

Fixtures (hermetic, via `mem://` journal + in-process bus + a fresh keypair): `conformance/stdlib/a2a-xap.cxd`.

---

## Cross-references

- [`cx-x/run`](run.md) — the Runnable convention every shim composes through.
- [`spec/03-approved/std-lib/README.md`](../std-lib/README.md) §3.3 — the tier's placement in the surface.
- [`spec/03-approved/std-lib/jsonrpc.md`](../std-lib/jsonrpc.md) / [`jsonschema.md`](../std-lib/jsonschema.md) — the frozen substrate the shims consume.
