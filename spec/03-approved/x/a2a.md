# `cx-x/a2a` — A2A client + skills

```cx
[module-meta name=a2a tier=x status=experimental]
```

**Status:** Experimental (`x/` tier; cx-private #6 Y2a; skills derivation added at stream 18 — L141/L144. The old hardcoded-empty `skills: ()` is **not ratified**: it is dead)

Normative reference for `cx-x/a2a` — a minimal A2A (Agent-to-Agent) protocol client and the **second lossy adapter** over the [`tools.md`](tools.md) descriptor model. A2A is JSON-RPC 2.0 over HTTP; pure composition over `jsonrpc` + `http` + `json`.

---

## §1. Protocol shapes (A2A 0.2.x)

A message is `{role, parts: [{kind: "text", text}], messageId, kind: "message"}`; `message/send` carries `{message}`; the reply is a Message (sync) or a Task `{id, status: {state}, …}` (async). An Agent Card (`/.well-known/agent.json`) describes the peer. Task lifecycle states: `submitted | working | input-required | completed | canceled | failed` — `input-required` is the durable pending-approval slot ([`a2a-xap.md`](a2a-xap.md)).

## §2. Skills — from the SAME projection (L141)

`skills-for ($source::string)` → the Agent Card skills array, derived from the same `cx-x/tools` projection the MCP adapter serves — one model, two lossy adapters. `skill-of ($d::element)` maps ONE descriptor to `{id, name, description, tags}`.

**The A2A lossy ruling:** this adapter **drops the JSON Schemas** (A2A carries modes/tags, not parameter schemas — argument validation happens at the peer's own boundary) and keeps the semantic contract as **tags**: exactly the true annotation hints (`read-only` / `idempotent` / `destructive` / `open-world`). Enforcement is unchanged by whatever a client reads here (the lossy-downward rule, L142). A projection failure propagates as its `[err]` — a card must never advertise a silently empty or partial skill set.

`agent-card ($name $description $url $version $skills)` takes the skills **explicitly** — there is no default: an empty card says `()` out loud.

## §3. Function surface

| Fn | Signature | Purity |
|---|---|---|
| `text-part` / `message` / `user-message` / `send-request` | message shaping | pure |
| `agent-card` | `($name $description $url $version $skills)` → map | pure |
| `skill-of` | `($d::element)` → map | pure |
| `skills-for` | `($source::string)` → any | pure |
| `message-text` / `task-state` | reply extractors | pure |
| `send-message` / `ask` | transport | impure (net) |

## §4. Loading and conformance

Bundled; `[?lib 'cx-x/a2a']`; under `bundled_x_names()`. Fixtures: `conformance/stdlib/a2a.cxd` (shapes; the derived-skills golden `a2a-008`; the fail-loud negative `a2a-009`); the cx↔cx round-trip is `vcx/tests/a2a_real_test.v`.

## §5. Cross-references

- [`tools.md`](tools.md) — the descriptor model; [`a2a-xap.md`](a2a-xap.md) — tasks/messages/auth over the xap substrate.
- [`run.md`](run.md) — an A2A peer composes as a Runnable via `[?fn ($t) [$a2a:ask $endpoint $t]]`.
