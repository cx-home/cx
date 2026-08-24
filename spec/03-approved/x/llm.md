# `cx-x/llm` — minimal LLM provider

```cx
[module-meta name=llm tier=x status=experimental]
```

**Status:** Experimental (`x/` tier; cx-private #6 D2/S10; spec'd minimal at stream 18 — L144: hard dependency of the approved [`adjudicate.md`](adjudicate.md), and the first Runnable)

Normative reference for `cx-x/llm` — the first deliverable under the Runnable convention ([`run.md`](run.md)): an LLM call that composes as `local fn ≡ MCP tool ≡ A2A skill ≡ LLM step`.

---

## §1. Provider and contract

Targets the Ollama `/api/chat` protocol (local, keyless): POST `{base}/api/chat` with `{model, messages: [{role, content}], stream: false}`; the assistant turn rides `/message/content`. Pure shaping (`user-message`, `chat-request`, `completion-of`) is split from the effectful `complete ($base $model $prompt)` so the request/response contract is testable without a network. Composition over the real `cx-stdlib/http` client + `json` — no new transport, no V backing.

Run under a **scoped net grant** (`--allow-net=127.0.0.1:11434`), never `--allow-all`.

## §2. Function surface

| Fn | Signature | Purity |
|---|---|---|
| `user-message` | `($content::string)` → map | pure |
| `chat-request` | `($model::string $prompt::string)` → map | pure |
| `completion-of` | `($response)` → string | pure |
| `complete` | `($base::string $model::string $prompt::string)` → string | impure (net) |

## §3. Composition

```cx
[$run:invoke [?fn ($p) [$llm:complete $base $model $p]] "Hi"]
```

The lib-qualified call-site closure is the composition idiom (run.md §4); a returned-closure `chat` factory is buildable post-#45 but not shipped until a consumer needs it.

## §4. Deferred (named, not stubbed)

`stream` (prompt → lazy token sequence): Ollama streams NDJSON, not SSE — it needs a chunked-line reader distinct from `http`'s `sse-events`; its own increment with its first consumer.

## §5. Loading and conformance

Bundled; `[?lib 'cx-x/llm']`; under `bundled_x_names()`. Fixtures: `conformance/stdlib/llm.cxd`; the live mock-server round-trip is `vcx/tests/llm_real_test.v`.

## §6. Cross-references

- [`run.md`](run.md) — the Runnable convention; [`adjudicate.md`](adjudicate.md) — the approved consumer that composes `complete`.
