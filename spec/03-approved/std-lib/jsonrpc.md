# `cx-stdlib/jsonrpc` — JSON-RPC 2.0 message model

```cx
[module-meta name=jsonrpc tier=D status=current
  [standard ref='JSON-RPC 2.0' title='JSON-RPC 2.0 Specification']]
```

**Status:** Current (post-v0.8.0 frozen addition; cx-private #6 S1)

Normative reference for the `cx-stdlib/jsonrpc` sub-package — the **JSON-RPC 2.0 message model**: it builds, classifies, and validates JSON-RPC values as ordinary CX maps. It is the stable wire shared by MCP and the LSP, and the substrate the agentic shims (`cx-x/mcp`, `cx-x/mcp-server`, `cx-x/a2a`) compose.

---

## §1. Scope

`cx-stdlib/jsonrpc` is the **message model only**: pure construction + classification + validation of JSON-RPC 2.0 values. It is **transport-agnostic** and **codec-agnostic** — the wire codec is [`cx-stdlib/json`](json.md) (`[$json:emit]` / `[$json:parse]`) at the transport boundary, and the transport is the caller's (`cx-stdlib/http`, stdio, …). Every function is **pure**; the module charges no capability.

A JSON-RPC value is an ordinary CX map, so it composes with `json`, `jsonschema`, and CXPath with no bespoke types.

## §2. Conceptual model

Per JSON-RPC 2.0, a message is one of:

- **request** — `{jsonrpc:"2.0", id, method, params?}` (expects a response).
- **notification** — `{jsonrpc:"2.0", method, params?}` (a request with **no** `id`; no response expected).
- **success response** — `{jsonrpc:"2.0", id, result}`.
- **error response** — `{jsonrpc:"2.0", id, error:{code, message, data?}}`.
- **batch** — a non-empty **sequence** of the above.

`params` and `data` are **omitted when empty** — JSON-RPC distinguishes an absent member from a present-but-empty one, and the builders honor that (an empty `params`/`data` argument produces a message without the member).

### §2.1. Reserved error codes (JSON-RPC 2.0 §5.1)

| Kind | Code |
|---|---|
| `parse-error` | −32700 |
| `invalid-request` | −32600 |
| `method-not-found` | −32601 |
| `invalid-params` | −32602 |
| `internal-error` | −32603 |

An unknown kind maps to `internal-error` (−32603).

## §3. Public function surface

### §3.1. Builders

| Function | Signature | Result |
|---|---|---|
| `request` | `($id::any $method::string $params::any {})` → map | `{jsonrpc:"2.0", id, method, params?}` |
| `notification` | `($method::string $params::any {})` → map | `{jsonrpc:"2.0", method, params?}` |
| `success` | `($id::any $result::any)` → map | `{jsonrpc:"2.0", id, result}` |
| `error` | `($id::any $code::int $message::string $data::any {})` → map | `{jsonrpc:"2.0", id, error:{code, message, data?}}` |
| `error-for` | `($id::any $kind::string)` → map | standard error response for a named kind |

### §3.2. Reserved codes

| Function | Signature | Result |
|---|---|---|
| `code` | `($kind::string)` → int | the reserved code for a named kind (§2.1); unknown → −32603 |
| `message-for` | `($kind::string)` → string | the canonical message string for a named kind |

### §3.3. Classification + validation

| Function | Signature | Result |
|---|---|---|
| `classify` | `($msg::any)` → string | `request` \| `notification` \| `success` \| `error` \| `invalid` (by shape) |
| `is-valid` | `($msg::any)` → bool | true when `jsonrpc` is exactly `"2.0"` **and** the shape classifies (≠ `invalid`) |
| `is-batch` | `($msg::any)` → bool | true when the value is a non-empty sequence of JSON-RPC messages |

`is-batch` exploits that a `/jsonrpc` path distributes over a sequence: a batch of N messages yields N `jsonrpc` members (equal to its item count), whereas a single message **map** has only one `jsonrpc` member, so the counts differ.

## §4. Loading semantics

Bundled in the binary; resolves via `[?lib 'cx-stdlib/jsonrpc']` (the resolver string MUST be quoted). No filesystem or network access; no `cx.lock` entry beyond the `bundled:<version>` tag.

## §5. Conformance fixtures

`conformance/stdlib/jsonrpc.cxd` — 17 behavioral cases covering build (request/notification/success/error, params/data omission), `error-for` + reserved codes, `classify` (incl. a parsed-wire round-trip via `[$json:parse]`), `is-valid`, and `is-batch`. A built message is grounded through `[$json:emit …]` to its canonical (key-sorted) JSON string.

## §6. Cross-references

- [`cx-stdlib/json`](json.md) — the wire codec (`emit`/`parse`) at the transport boundary.
- [`cx-stdlib/jsonschema`](jsonschema.md) — validates JSON-RPC payloads (e.g. MCP tool args) against a JSON Schema.
- The agentic shims that compose this wire live in the **`x/` experimental tier** — see [README §3.3](README.md#33-the-x-experimental-tier).
