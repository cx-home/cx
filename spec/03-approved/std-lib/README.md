# `cx-stdlib` — bundled standard library

**Status:** Current for v0.8.0

Normative reference for the `cx-stdlib/*` namespace addressable via `[?lib]`. Each module's function-level surface is the subject of its own spec under `spec/std-lib/`.

---

## §1. Scope

`cx-stdlib` ships **bundled with the CX binary**. Its modules are addressable via the `cx-stdlib/` prefix:

```cx
[?lib 'cx-stdlib/strings']
[?lib 'cx-stdlib/json']
[?lib 'cx-stdlib/store']
```

Loading semantics are defined by [`spec/core/code.md`](../core/code.md) §12.1.

## §2. Bundling rule

`cx-stdlib`'s bytes are part of the CX binary. The lockfile entry follows the `bundled:` shape:

```cx
[module name="cx-stdlib" resolved="bundled:0.8.0"]
```

`<version>` matches the CX binary's version. No separate fetch, no integrity hash, no version pin needed in `cx.lock` beyond the `bundled:` tag — see [`spec/core/lockfile.md`](../core/lockfile.md).

**Stdlib version follows the CX binary.** Upgrading the binary upgrades the stdlib in lockstep. There is no independent stdlib version pin.

## §3. Module index (v0.8.0)

The v0.8.0 stdlib enumerated **37 sub-packages** in four informative tiers; **5 post-v0.8.0 additions** (`did`, `vc`, `xsp`, `jsonrpc`, `jsonschema` — §3.2) bring the current frozen surface to **42**. A separate **`x/` experimental tier** (§3.3) sits alongside the frozen surface — in-tree and gated, but **exempt** from the frozen-stability promise. Tier is not addressable in the resolver; `[?lib]` always names `cx-stdlib/<name>` (frozen) or `cx-x/<name>` (experimental).

### Tier A — Value-shape & encoding

| Module | Purpose | Spec |
|---|---|---|
| `strings` | String inspection, search, transform | [strings.md](strings.md) |
| `math` | Numeric utilities, statistical helpers | [math.md](math.md) |
| `bytes` | Byte-level ops, hex/base64, struct pack/unpack, compression | [bytes.md](bytes.md) |
| `time` | Date / datetime / duration; mockable time sources | [time.md](time.md) |
| `re` | RE2-backed regex | [re.md](re.md) |
| `hash` | Content-addressable hashing (SHA-256/384/512, BLAKE3) | [hash.md](hash.md) |
| `json` | JSON parse / emit; CXDM round-trip | [json.md](json.md) |
| `csv` | CSV / TSV parse / emit; dialect handling | [csv.md](csv.md) |
| `format` | Canonical-form emission, pretty-print | [format.md](format.md) |
| `validate` | Runtime schema validation (data-record validator) | [validate.md](validate.md) |
| `jsonschema` | JSON Schema 2020-12 validation (the MCP tool-schema subset) | [jsonschema.md](jsonschema.md) |
| `url` | URL parse / build / encode / decode | [url.md](url.md) |
| `mime` | MIME types, content-type parsing, multipart helpers | [mime.md](mime.md) |
| `locale` | Locale-aware collation, number/date/currency formatting, case mapping | [locale.md](locale.md) |
| `i18n` | Message catalogs, locale-fallback, ICU MessageFormat with CLDR plural rules | [i18n.md](i18n.md) |
| `geo` | Coordinate primitives, Haversine, WKT/GeoJSON round-trip | [geo.md](geo.md) |
| `ft` | Fulltext search — inverted index, TF-IDF/BM25, phrase queries | [ft.md](ft.md) |
| `email` | RFC 5322 + MIME multipart parse / emit | [email.md](email.md) |
| `crypto` | Security primitives — HMAC, keyed-BLAKE3, HKDF, constant-time verify | [crypto.md](crypto.md) |
| `html` | HTML5 parse / sanitize / serialize / extract-text | [html.md](html.md) |
| `fp` | Functor/monad protocol — `map`/`flat-map`/`pure`/`traverse`/`sequence`/`fold` over tagged containers (sequence=Maybe+List, `result`, user) | [fp.md](fp.md) |

### Tier B — Runtime & environment

| Module | Purpose | Spec |
|---|---|---|
| `io` | File and stream I/O; bridges streaming events | [io.md](io.md) |
| `net` | L4 networking — TCP/UDP/Unix/TLS/DTLS dial, listen, accept-iter, stream + datagram I/O | [net.md](net.md) |
| `path` | Filesystem path manipulation | [path.md](path.md) |
| `env` | Environment variables, CLI args, process metadata | [env.md](env.md) |
| `log` | Structured logging | [log.md](log.md) |
| `uuid` | UUID v4 + v7 | [uuid.md](uuid.md) |
| `random` | PRNG (seeded, reproducible) + crypto-random | [random.md](random.md) |
| `store` | Content-addressed object store with URL-dispatched backends | [store.md](store.md) |
| `process` | Subprocess control — run / spawn / pipelines / signals / process groups | [process.md](process.md) |

### Tier C — Test & development

| Module | Purpose | Spec |
|---|---|---|
| `test` | Assertions, fixtures, throws-checking | [test.md](test.md) |
| `prof` | In-program profiling — `time-fn`, `mem-snapshot`, `counter`, `trace` | [prof.md](prof.md) |

### Tier D — Web, coordination & trust (the XAP stack)

The in-review web/coordination stack, graduated together: an L7 server atop `net`, plus the event-sourced coordination + trust primitives the XAP experience layer composes (see the forthcoming `cx-xap` orchestrator).

| Module | Purpose | Spec |
|---|---|---|
| `http` | L7 HTTP/1.1 client + server + SSE/streaming, atop `net` | [http.md](http.md) |
| `bus` | In-process pub/sub with synchronous ordered dispatch | [bus.md](bus.md) |
| `journal` | Append-only, hash-chained, per-aggregate-stream event log + fold→state + replay/verify/snapshot | [journal.md](journal.md) |
| `authz` | Authorization / trust model — capabilities, attenuating delegations, guardian grants, the PEP decision function | [authz.md](authz.md) |
| `session` | `(principal, tenant)` sessions — attach (JWT bearer **or** DID proof-of-control), token verify, mirrored-attach | [session.md](session.md) |
| `sched` | Scheduled events & cancelable timers; durable via `journal` | [sched.md](sched.md) |
| `did` | Decentralized identifiers — `did:key` (offline) + `did:web`; create / parse / resolve / proof-of-control (R9 identity) | [did.md](did.md) |
| `vc` | Verifiable credentials — issue / verify / present / revoke a portable, signed, attenuating §22.2 delegation (R9 authority) | [vc.md](vc.md) |
| `jsonrpc` | JSON-RPC 2.0 message model — build / classify / validate (the wire under MCP + LSP) | [jsonrpc.md](jsonrpc.md) |
| `xsp` | XAP Stream Protocol — frame codec (length-prefixed binary frames) | [../xap/xsp.md](../xap/xsp.md) |

### §3.1. Anti-duplication principle

A proposed sub-package does **not** belong in stdlib if it (1) controls evaluation order or scope, (2) navigates or selects within data, (3) produces a structurally-transformed value of the input, or (4) composes resilience / concurrency / I/O policy. Those live in directives + CXPath + `[?modify]` respectively.

**Carve-out — `cx-stdlib/fp`.** The `fp` protocol (functor/monad over tagged containers) is admissible under this principle: its combinators are **value→value functions** (`map`/`flat-map`/`pure`/`traverse`/`sequence`/`fold`), not document-structure transforms in the prohibited sense (4), and it does **not** control evaluation order or scope (1) — it *dispatches via the core `[?match]`* (§8.2) on the container's head tag, and its err-inspecting combinators inherit the core `[?match]` §9.2-exempt boundary rather than introducing a new evaluation rule. It is pure-library composition over already-admitted surface (the one core touch is a *use* of `[?match]`, not new core). See [fp.md](fp.md) §1.

### §3.2. Frozen-surface discipline

The 37-module Tier A–D set is the **v0.8.0 frozen surface**. Adding a new sub-package post-v0.8.0 requires the same gating discipline that applies to the directive registry. Removing a sub-package is breaking at the binary's major-version boundary.

**Post-v0.8.0 additions.** Five sub-packages have been added under this discipline, bringing the frozen surface to **42**:

- `did`, `vc` (Tier D, issue #26) — concrete foundational libraries realizing the DID/VC authority-basis transport that [xap.md](../xap/xap.md) R9 framed and §28.3 D5 deferred. They add **no new trust primitive** (the PEP / N-TRUST-1 are unchanged); they make decentralized identity (`did`) + delegation (`vc`) real alongside the existing `crypto`/`session`/`authz`.
- `xsp` (Tier D, issue #31) — the XAP Stream Protocol frame codec ([../xap/xsp.md](../xap/xsp.md)).
- `jsonrpc`, `jsonschema` (issue #6 S1/S7) — the **agentic substrate**: the JSON-RPC 2.0 message model (the wire under MCP + LSP) and JSON Schema 2020-12 validation (MCP tool `inputSchema`s). They add no new core; they are pure message-model / validation libraries the agentic shims in the `x/` tier (§3.3) compose.

### §3.3. The `x/` experimental tier

The fast-moving agentic protocol shims live in a separate **`x/` experimental tier**, resolved as `cx-x/<name>` (e.g. `[?lib 'cx-x/run']`), with sources under the repo-root `x/` directory (parallel to `stdlib/`). Per cx-private #6 (decision D3), the tier is **in-tree** — one repo, one toolchain, one gate — but **explicitly exempt from the frozen-stability promise**: semver-breaking change is allowed while a protocol settles, and the experimental status is marked in each module header. The tier is enumerated separately (`bundled_x_names()`); the frozen-surface canary never counts it.

Current `x/` modules:

| Module | Purpose | Spec |
|---|---|---|
| `cx-x/run` | The **Runnable convention** + combinator library — invoke / batch / pipe / compose / fan-out over any callable (local fn ≡ MCP tool ≡ A2A skill ≡ pipeline step) | [../x/run.md](../x/run.md) |
| `cx-x/llm` | Minimal LLM provider (Ollama `/api/chat`), the first Runnable | [../x/README.md](../x/README.md) |
| `cx-x/mcp` | MCP (Model Context Protocol) **client** — JSON-RPC over HTTP; validates tool args via `jsonschema` | [../x/README.md](../x/README.md) |
| `cx-x/mcp-server` | MCP **server** helpers — cap-gated tools (a tool's effects are gated by CX capabilities) | [../x/README.md](../x/README.md) |
| `cx-x/a2a` | A2A (Agent-to-Agent) protocol client | [../x/README.md](../x/README.md) |
| `cx-x/a2a-xap` | A2A over the xap substrate — tasks→`journal`, messages→`bus`, auth→`did`+`vc` | [../x/README.md](../x/README.md) |

A module graduates from `x/` to the frozen surface only once its protocol is stable, by the same gating discipline as any frozen addition.

## §4. Loading semantics

Bundled stdlib modules participate in the same two-pass module load as any other `[?lib]` target ([`spec/core/code.md`](../core/code.md) §12.5). Special-cased behaviour:

1. **No HTTPS fetch.** Bytes are resident in the binary; the loader's HTTPS path is bypassed.
2. **No SRI verification.** `cx.lock` records `resolved="bundled:<version>"` with no `sri=`.
3. **No transitive lockfile gate.** Bundled-to-bundled internal edges don't require lockfile entries.

User-authored modules importing `cx-stdlib/*` still need a `cx.lock` entry naming `cx-stdlib` (or the specific sub-path).

## §5. Cross-references

- [`spec/core/code.md`](../core/code.md) §12 — module system surface; `[?lib]`, packages, sub-paths, manifest gating.
- [`spec/core/lockfile.md`](../core/lockfile.md) — `cx.lock` shape and `bundled:` `resolved=` form.
- [`spec/core/abi.md`](../core/abi.md) — capability bit 35 gates `[?lib]` reachability as a single switch. A binding without bit 35 cannot import any `cx-stdlib/*` module. Per-module gating is not used at v0.8.0; all stdlib modules are reachable when bit 35 is set.
- [`spec/misc/bindings.md`](../misc/bindings.md) — Layer-1 16-method API that `cx-stdlib/store` builds atop.
- [`spec/misc/parity-matrix.md`](../misc/parity-matrix.md) — per-binding stdlib coverage tracking.
