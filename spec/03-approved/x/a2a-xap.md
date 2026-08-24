# `cx-x/a2a-xap` — A2A over the xap substrate

```cx
[module-meta name=a2a-xap tier=x status=experimental]
```

**Status:** Experimental (`x/` tier; cx-private #6 Y2b; the pending-approval realization added at stream 18 — L140)

Normative reference for `cx-x/a2a-xap` — A2A semantics mapped onto CX's durable substrate rather than a bespoke store. Also the sole in-tree corpus cover for [`did.md`](../std-lib/did.md) / [`vc.md`](../std-lib/vc.md) (G14).

---

## §1. tasks → journal

A task lifecycle records as hash-chained `cx-stdlib/journal` events — **replayable** (`history` + the `lifecycle` projection) and **tamper-evident** (`journal:verify`) for free. `task-event ($id $state $address='')` shapes one transition; the additive `address` carries the Tier-1 address of the value the transition is ABOUT.

## §2. `input-required` — the durable pending-approval slot (L140)

A proposed command parks its task in `input-required` with the **proposal's Tier-1 address journaled on the transition**:

- `propose-task ($jr $id $proposal::element)` — journal the `input-required` transition carrying `cx:hash` of the proposal. The pending approval is durable, replayable, and addressable — never an in-memory pending map.
- Approval happens **out-of-band** (the adjudicate precedent; MCP elicitation is a non-goal — the signing interaction never sits on the agent's client): a principal approves the ADDRESS (`authz:approve`, or a DID-signed credential, §3); `authz:commit` re-checks everything (the exact Tier-1 version, L139); the task then transitions on (`record`).

## §3. auth → did + vc — one delegation language

An agent is a **DID** (`agent-did`); authority between agents is a DID-signed capability delegation carried as a Verifiable Credential (`grant-credential`, verified fail-closed by `grant-status` — no callback to the issuer). **`approval-credential ($issuer-did $issuer-key $subject-did $proposal-address $opts)`** issues a credential whose delegation subject IS the proposal address — the same `[delegation …]` value shape the PEP consumes (#7), so an A2A-carried approval and an authz-store approval speak one language.

## §4. messages → bus

`message-envelope` / `publish-message` fan an A2A message to every `cx-stdlib/bus` subscriber on the `:a2a-message` topic — live pub/sub, the complement to the durable journal.

## §5. Function surface

| Fn | Signature | Purity |
|---|---|---|
| `task-event` | `($id::string $state::string $address::string '')` → element | pure |
| `record` | `($jr $id $state)` → element | impure (journal) |
| `propose-task` | `($jr $id $proposal::element)` → element | impure (journal) |
| `history` | `($jr $from::int $to::int)` → sequence | impure (journal) |
| `lifecycle` | `($entries)` → sequence | pure |
| `message-envelope` / `publish-message` | bus lane | pure / impure |
| `agent-did` | `($public-key::bytes)` → string | pure |
| `grant-credential` / `approval-credential` | VC issuance | pure |
| `grant-status` | `($credential $now::datetime)` → string | pure |

## §6. Loading and conformance

Bundled; `[?lib 'cx-x/a2a-xap']`; under `bundled_x_names()`. Fixtures (hermetic — `mem://` journal, in-process bus, fresh keypair): `conformance/stdlib/a2a-xap.cxd`, including the durable pending-approval case (`a2a-xap-008`: the replayed path shows `input-required` and the proposal address survives replay) and the approval-credential case (`a2a-xap-009`).

## §7. Cross-references

- [`a2a.md`](a2a.md) — the protocol client + skills; [`mcp-server.md`](mcp-server.md) §3 — the propose-only boundary this realizes durably.
- [`spec/03-approved/std-lib/journal.md`](../std-lib/journal.md) / [`bus.md`](../std-lib/bus.md) / [`did.md`](../std-lib/did.md) / [`vc.md`](../std-lib/vc.md) — the substrate.
