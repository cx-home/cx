# CX v0.11.0 — Release Notes

**Date:** 2026-06-18
**Tag:** `v0.11.0`

The **agentic substrate** release. CX gains a new `cx-x/` tier (MCP, A2A,
LLM, the Runnable convention), four new stdlib modules (`did`, `vc`,
`jsonrpc`, `jsonschema`), substantial XAP advances, and two correctness
fixes to lexical scoping. Internally, CX is now decoupled from the V fork:
it owns its HTTP/SSE transport and the fork carries no CX-specific code.
All changes are backward-compatible.

## Added

### `cx-x/` — the agentic tier

A new tier of CX programs that compose the stdlib substrate into
agent-facing protocols. Each is a CX program, not engine code.

- **`cx-x/run`** — the **Runnable** convention + a combinator library: a
  uniform call/compose contract that the LLM/MCP/A2A pieces all implement.
- **`cx-x/llm`** — a minimal LLM provider (the first Runnable).
- **`cx-x/mcp`** + **`cx-x/mcp-server`** — Model Context Protocol client and
  server, with a cx↔cx round-trip and a behavioral capability-denial demo
  (capabilities gate MCP tools).
- **`cx-x/a2a`** + **`cx-x/a2a-xap`** — Agent-to-Agent: a minimal protocol
  client, tasks over the XAP substrate (tasks→journal), pub/sub fan-out
  (messages→bus), and DID/VC-backed auth — completing the over-XAP trio.

### New stdlib modules

- **`cx-stdlib/did`** — decentralized identifiers: `did:key` (offline) and
  `did:web`, on a new base58btc codec.
- **`cx-stdlib/vc`** — verifiable credentials; plus `session/attach-did`
  (establish sessions by DID proof-of-control).
- **`cx-stdlib/jsonrpc`** — JSON-RPC 2.0 message model (the frozen substrate
  under MCP/A2A).
- **`cx-stdlib/jsonschema`** — JSON Schema 2020-12 (the MCP subset).

### XAP

- **Real authz-backed PEP** in the bundled cx-xap runtime (replaces the
  prior no-op/hardcoded emit/dial/why-allowed).
- **Feature augmentation / overlay composition** + a **coordination
  channel** (Tier 2).
- **XSP (XAP Stream Protocol)** — transport-agnostic frame codec.
- **DID/VC identity** anchored from principals to all actors (XAP, client,
  capability); JWT (centralized) + DID/VC (decentralized) identity model.
- Model + spec advances: "a XAP is a pool of vocabularies; a surface is a
  chosen blend"; emit routes by intent verb to the declaring component;
  the session + load-balancing model; a stories→requirements taxonomy.

## Changed

- **Uniform lexical scoping (#19 / #22).** Callables now resolve free names
  in their **defining** scope. Imported (`[?lib]`) module siblings can call
  each other, and a `[?const]` referenced inside a `[?def]` body is
  dereferenced (previously read as a bareword).
- **CX is decoupled from the V fork.** CX's event-loop HTTP/SSE/XAP
  transport is vendored into `vcx/transport/` (picoev + picohttpparser +
  the SSE/shared-listener patch); the dormant scope-region path is retired.
  The patched-V fork now carries **no CX-specific code** — only the
  CX-agnostic vgc/`-gc e` mem-mgmt work bound for upstream. See the new
  [`spec/03-approved/process/v-dependency-management.md`](spec/03-approved/process/v-dependency-management.md)
  and [`third_party/README.md`](third_party/README.md). No runtime-behavior
  change (full gate identical).

## Fixed

- **#45 — escaping closures keep their environment.** A `[?fn]`/partial
  returned from a zero-arg `[?def]`, from a module `[?def]` (now resolving
  its module's siblings + consts), or re-captured into another closure
  (nested combinators / pipe-of-pipe) now resolves correctly — previously
  the environment was lost or the program crashed.
- **#20** — the module loader no longer scans `[?lib]`/`[?def]` directives
  out of `#` comment lines on import.
- **#42** — `cx fmt` accepts valid operator-head expressions
  (`[* 2 3]`) instead of rejecting them; pass-through, no fmt/eval divergence.
- **#39 / codec** — namespaced `[$<codec>:parse]` / `:emit` forms are
  accepted.
- **XAP** — `emit` routes by intent verb to the declaring component (no
  longer always the first bound component); a component view built inside
  `[?for]` captures its view-closure at build so the deferred render
  survives the loop scope.

## Internal

- **Build guard** — `vcx/Makefile` warns loudly when the patched V is absent
  and `-prod` is silently dropped (the worktree build trap), so the ~5×
  degraded build is never mistaken for a regression.
- New process spec: **CX ⇄ V dependency management**
  ([`spec/03-approved/process/v-dependency-management.md`](spec/03-approved/process/v-dependency-management.md))
  — the layering, the "no CX in V" rule, the keep-current workflow, and the
  upstream→drop-fork lifecycle.

## Compatibility

Backward-compatible feature release. CX programs and Tier-1 bindings (V /
Python / Go / Rust) that ran under v0.10.1 run unchanged. The scoping fixes
(#19 / #22 / #45) change previously-broken behavior to correct: programs
that depended on those bugs (returned closures failing to resolve, module
siblings being unreachable) now work as specified.
