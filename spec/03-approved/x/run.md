# `cx-x/run` — the Runnable convention + combinator library

```cx
[module-meta name=run tier=x status=experimental]
```

**Status:** Experimental (`x/` tier — exempt from the frozen-stability promise; cx-private #6 D2/M2)

Normative reference for `cx-x/run` — the **Runnable convention** and its combinator library. This is the foundational `x/`-tier module: the agentic shims (`cx-x/llm`, `cx-x/mcp`, `cx-x/a2a`) compose through it.

---

## §1. The Runnable convention

A **Runnable** is a *structural convention*, not a language trait or protocol type (cx-private #6 decision D2, option **b** — chosen over a language trait system, which would contradict #37's dynamic/structural core). **Any callable value is a Runnable** — a `[?def]`, a `[?fn]`, a `$`-bound closure, or a transport proxy built as a closure over its transport. This unifies *local fn ≡ MCP tool ≡ A2A skill ≡ pipeline step* with no type system.

The convention is **pure and fully homoiconic** — zero core change. It relies only on:
1. **Uniform lexical scoping** (#19/#22, [`spec/core/code.md`](../core/code.md)) — a callable resolves its free names in its **defining** scope, so a Runnable composes correctly wherever it runs.
2. Applying a bound callable as a call head — `[$r $input]`.

## §2. Convention verbs

| Verb | Signature | Meaning |
|---|---|---|
| `invoke` | `($r::any $input::any)` → any | one → one: apply the Runnable to one input (`[$r $input]`) |
| `batch` | `($r::any $inputs::any)` → any | many → many: apply over a sequence, returning a **first-class sequence** (via the frozen `fp:map` functor — not a yield-stream) |

**`stream`** (one → lazy token sequence) is **deferred** to its first consumer (the LLM/MCP/A2A streaming work): it threads the M1a client read path ([`spec/core/streaming.md`](../core/streaming.md)) and, for Ollama, an NDJSON line reader. It is **not** defined yet — not stubbed. `with-config` (rebind dynamic context + caps) is deferred with it.

## §3. Combinators

Each produces or returns a value that is itself a Runnable (an LCEL-style algebra):

| Combinator | Signature | Meaning |
|---|---|---|
| `pipe` | `($f::any $g::any)` → Runnable | left-to-right: a closure feeding input through `f` then `g` |
| `compose` | `($f::any $g::any)` → Runnable | right-to-left (mathematical): `f` after `g` |
| `fan-out` | `($rs::any $input::any)` → sequence | apply each Runnable in `rs` to the **same** input, collecting results in order (the structural form of parallel; concurrency is an optimization a future scheduler may add, semantics stay deterministic) |

## §4. Composition idiom (the supported pattern)

A transport-backed Runnable is written as a **lib-qualified call-site closure**:

```cx
[$run:invoke [?fn ($a) [$mcp:call-tool $endpoint "get_weather" $a]] {city: "NYC"}]
[$run:pipe preprocess [?fn ($p) [$llm:complete $base $model $p]]]
```

A captured **parameter** and a **lib-qualified** call both survive cross-module application, which is why this idiom works and backs `cx-x/llm` / `cx-x/mcp` / `cx-x/a2a`.

### §4.1. Closures-in-data registries (#45, resolved)

A *dedicated* factory that **returns** a closure calling unqualified module siblings — a generic tool/skill **registry** of closures-in-data — works. A returned `[?fn]` resolves its **defining module's** siblings + consts wherever applied (not the caller's), and `pipe`/`compose` **nest to any depth** (a pipe result re-captured by another pipe keeps its own environment). This was the closure-escape representation bug **#45**, fixed by embedding the closure ON its function-value sentinel so an escaping closure travels WITH the value (no scope-table registry). The call-site idiom (§4) remains the simplest pattern, but a closure registry is no longer ruled out.

## §5. Loading semantics

Bundled in the binary; resolves via `[?lib 'cx-x/run']` (the resolver string MUST be quoted). Enumerated under `bundled_x_names()`, **separate** from the frozen `cx-stdlib/*` surface, so the frozen-surface canary never counts it.

## §6. Conformance fixtures

`conformance/stdlib/run.cxd` — 7 behavioral cases: invoke, batch (sequence result), pipe (two-stage), compose, fan-out, "a Runnable is any callable" (invoking a `[?fn]` literal), and nested pipe (a pipe result re-fed into another pipe, >2 stages — #45 fixed).

## §7. Cross-references

- [`spec/03-approved/std-lib/README.md`](../std-lib/README.md) §3.3 — the `x/` tier.
- [`spec/03-approved/std-lib/fp.md`](../std-lib/fp.md) — the functor `map` `batch` builds on.
- [`x/README.md`](README.md) — the agentic shims that compose this convention.
