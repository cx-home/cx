# CX Threat Model

This document captures CX's threat model: what the project is
hardened against, what it isn't, what the assumed deployment model
is, and where the trust boundaries sit. It is normative for the
project's hardening claims and informative for adopters evaluating
CX for a particular deployment.

The threat model evolves with the format and the implementation. It
is reviewed at every release; changes are recorded by version in §10
below. Vulnerability reports are handled via the process in
[`SECURITY.md`](../SECURITY.md).

---

## 1 — Scope

### In scope

The components covered by this threat model:

- The V reference implementation under `vcx/` (parser, emitters,
 conversion logic, AST, binary format codecs).
- The C ABI surface in `libcx` (every `cx_*` symbol declared in
 `spec/abi.md`).
- All 9 language bindings under `lang/` and the native-V binding at
 `lang/v/native/`.
- The `cx` CLI in `vcx/cmd/`.
- The CXDB v1 binary wire format (`spec/data_bin.md`).

### Out of scope

- **The V toolchain itself.** V is pre-1.0 and is treated as a
 trusted dependency; vulnerabilities in V's stdlib, GC, or codegen
 are out of scope for CX and should be reported upstream at
 [vlang/v](https://github.com/vlang/v).
- **Third-party libraries in language bindings.** JNA (Java/Kotlin),
 koffi (TypeScript), cffi (Python), etc. are trusted dependencies;
 vulnerabilities in them are reported upstream.
- **Operating-system, container, or network-stack vulnerabilities.**
- **Trust in the source distribution.** Verifying that a downloaded
 `libcx.so` or registry artifact matches the official release is
 the consumer's responsibility (and is named as a roadmap item:
 reproducible builds + signed releases).

### Pre-v0.6.0 caveat

CX is pre-v0.6.0 and has not received an external security audit.
The hardening described in §5 is real and tested through the
conformance suite, but the project lacks fuzz infrastructure
(named as a v0.6.0 blocker in [`ROADMAP.md`](../ROADMAP.md)) and a
published external audit. **Use CX for prototypes, internal tools,
and exploratory work; do not point a CX parser at adversarial
input on a public-facing endpoint until v0.6.0 ships and external
review is in place.** v0.6.0 is the API/format-stability boundary
through 1.0, and it is the release at which the audit and fuzz
work close.

---

## 2 — Assumed deployment model

CX assumes one of three deployment shapes. The threat surface is
different in each.

### A — Trusted file inputs (default-safe)

CX reads files written by the same operator who runs the CX
toolchain — config files, internal data exchange, hand-edited
documents. Inputs are from a controlled source. This is the use
case CX is designed for and where its hardening is sufficient
today.

### B — Semi-trusted inputs (acceptable with caveats)

CX reads files from a less-controlled source — pull requests, CI
artifacts, third-party config, vendored data. Inputs may be malformed,
mistakenly oversized, or lightly adversarial. The parser hardening
in §5 is sufficient for this case; the consumer should pin a known
libcx version and apply the resource limits described in
`spec/policies.md`.

### C — Untrusted / adversarial inputs (not recommended pre-v0.6.0)

CX reads files from an attacker-controlled source — public webhook
bodies, file uploads, network payloads. **CX is not yet hardened for
this case.** Specific blockers:

- No fuzz-testing harness, so undiscovered DoS or crash inputs are
 plausible.
- No external security audit.
- The V toolchain CX builds on is pre-1.0; bugs at that layer can
 affect CX's hardening.

For deployment shape C, wait for v0.6.0, which closes the §12
(security) blockers in

---

## 3 — Trust boundaries

CX participates in three trust boundaries:

1. **Input parser boundary.** Bytes from an external source enter
 the CX parser via `cx_to_data_bin`, `cx_parse_*`, the CLI, or a
 binding's `loads` / `parse_*`. The parser converts those bytes
 to in-process AST or data structures.
2. **C ABI boundary.** Every binding crosses the FFI boundary into
 `libcx`. Inputs are passed as `(pointer, length)` byte buffers;
 outputs return as framed `[u32 LE size][payload]` buffers
 (`spec/governance.md §1.2`).
3. **Inclusion boundary.** When a CX document contains
 `[?cx include=path.cx]`, the parser opens and parses an
 additional file. Path resolution is part of this boundary
 (§7).

Each boundary is a place where input validation must happen.
Hardening at one boundary does not automatically protect another.

---

## 4 — Threat actors and scenarios

### T1 — DoS via crafted input

An actor crafts an input designed to consume disproportionate CPU
or memory. Examples:

- Deeply nested elements designed to blow recursion depth.
- A document with billions of small attributes designed to exhaust
 allocator budgets.
- A binary CXDB payload with declared-but-not-present sizes that
 force the decoder to allocate a huge buffer.
- A logfmt input with a single line longer than RAM.

**Mitigation:** §5 (recursion limit, count caps, payload-size
validation, varint validation, allocation budgets per
`spec/policies.md`). All limits are documented and tunable.

### T2 — Memory corruption via FFI

An actor crafts an input or invokes a binding API in a way that
triggers an out-of-bounds read or write across the C ABI boundary
— e.g., a malformed CXDB payload with a length prefix that exceeds
the available buffer.

**Mitigation:** length-prefixed framing on every binary buffer
(§3); each binding deserializes once with explicit bounds checks
(`spec/governance.md §1.2`); V core uses bounds-checked array
access; binding-level codecs use the host language's safe
deserialization primitives (no unsafe pointer arithmetic except
in the audited FFI marshalling shims).

### T3 — Confused-deputy via include-path traversal

An actor crafts a CX document containing
`[?cx include=../../../etc/passwd]` or
`[?cx include=https://evil.example/payload.cx]` to cause the
parser to read a file or URL the operator did not intend.

**Mitigation today:** include resolution is **path-only** (no
URL fetching) and uses the CLI's working directory or a binding-
caller-supplied root. Consumers of `libcx` set the include-search-
root via the C ABI before parsing.

**Open work:** include resolution semantics are partially specified;
the formal spec section is named in
§4 as in-progress (`🚧`). Until that spec lands, treat
`[?cx include=...]` from semi-trusted inputs (deployment B) as
"only enable include resolution if you've set an include-root."

### T4 — Type-confusion across conversion

An actor exploits a CX-to-target-format conversion to coerce a
value (e.g., an attacker-supplied CX document where an integer
is expected, but a string slipped through silently as a result of
the conversion).

**Mitigation:** type fidelity through CXDB v1 is the design north
star (`spec/governance.md §1`). String-format roundtrips are
forbidden on hot paths; the audit-closed binding implementation
guarantees type-bearing values cross format boundaries through
binary AST, not text. Consumer code that re-derives types from
JSON-emitted strings is on the consumer.

### T5 — Hash-collision / canonical-form bypass

An actor crafts two CX documents that hash to the same value
under `cx hash` despite differing in semantically meaningful
content.

**Mitigation:** `cx hash` is SHA-256 of strict canonical bytes
(`spec/canonical.md`). Strict canonical removes comments, normalizes
whitespace per documented rules, sorts attributes
deterministically, and emits binary CXDB. Two semantically
distinct documents producing the same SHA-256 input is an attack
on SHA-256, not on CX. The format contributes no second-preimage
weakness beyond the underlying hash.

**Caveat:** the canonical form is normative (`spec/canonical.md`);
divergence from spec in any binding's canonical-form output is a
bug. This is enforced by cross-binding determinism tests
(`spec/governance.md §2.3`).

### T6 — Supply-chain / artifact tampering

An actor compromises a published libcx binary, a registry-published
binding, or a build-time dependency, replacing it with a
compromised version.

**Mitigation today:** the `dist/SHA256SUMS.txt` published with each
release tag (per the release process) lets a consumer
verify a downloaded libcx artifact. Each binding's package-manager
checksum applies to the binding source; the libcx binary it
downloads at install time is the residual risk.

**Open work:** reproducible libcx builds and published Sigstore
signatures are named in `ROADMAP.md` "Later." Until then, consumers
who require provenance verification should build libcx from source
and pin a tag.

### T7 — Information disclosure via error messages

An actor probes a CX-using service by sending malformed input
designed to elicit error messages that leak file paths, environment
state, or service internals.

**Mitigation:** `libcx` error messages are bounded in length and
include line/column numbers but no file paths or runtime state
(`spec/abi.md`). Bindings format their own errors on top of the
libcx string; binding-level error wrapping should not include
caller-supplied paths in default messages. Consumer applications
that re-export CX errors verbatim to an external surface should
sanitize first.

### T8 — Streaming-API resource exhaustion

An actor uses the events streaming API (`cx_events_open / next /
close`) to hold a long-lived parser handle and starve the host
process of file descriptors or memory.

**Mitigation:** handle lifecycle is documented in
`spec/streaming.md`; consumers set per-handle limits (max events,
max bytes consumed). Each handle owns a bounded internal buffer
(see `spec/streaming.md §v1 internal-buffer caveat`).

### T9 — ReDoS via XPath 4.0 regex functions (v0.7.0)

The v0.7.0 evaluator surface adds `fn:matches`, `fn:tokenize`,
`fn:replace`, and `fn:analyze-string` (CXL bindings `[?matches]`,
`[?tokenize]`, `[?regex-replace]`). An actor supplies a pattern
designed for catastrophic backtracking — the canonical example is
`(a+)+$` against `"aaaaaaaaaa…!"` — which on PCRE/Perl/Python.re
engines runs for minutes and exhausts the request-handler thread.

**Mitigation:** all regex callsites route through the vendored RE2
shim (`vcx/deps/re2_shim/` + `vcx/cx/regex_re2.v`), which uses a
Thompson NFA with the Aho-Corasick optimizer. Matching is
**linear-time in the input length** with no exposure to
backtracking explosion. The same engine backs schema `:pat=`
validation (locked by `spec/schema.md §7`) so cross-binding regex
flavor drift is also eliminated.

Regression test: `test_u2_regex_redos_bounded` in
`vcx/tests/cxl_test.v` runs the `(a+)+$` probe against 30 `a`'s
plus `!` and asserts completion in under one second — failure
mode for a regression is a test-runner timeout.

Per ADR 0022 §D7, the vlib `regex` module is **not** an
acceptable substitute for any cx regex callsite; the cross-binding
contract (RE2 semantics) is normative.

### T10 — Function-recursion DoS via [?fn] / partial-application

An actor crafts a CXL document with a `[?fn]` declaration that
recurses unconditionally, or a partial-application chain that
expands to unbounded call depth at evaluation time, exhausting the
evaluator stack.

**Mitigation:** `CXLEnv.call_depth` is checked at every
`call_fn_emit` / `call_fn_to_value` entry against
`CXLEnv.max_call_depth` (default **256**, configurable per-eval).
Over-cap surfaces structurally as `cx-err:CXER0010` — the host
catches it as a normal evaluator error rather than a process
abort. Regression: `test_u3_recursion_limit_triggers`.

### T11 — Sequence-length DoS via `1 to N` / `range`

The v0.7.0 evaluator gains the XPath `to` operator and
`[?range [from, to]]` directive. An actor crafts an expression
like `1 to 9999999999` to materialize an enormous sequence and
exhaust process memory.

**Mitigation:** `CXLEnv.max_sequence_len` (default **1,000,000**
items) is checked in `eval_op_to` and `filter_range` before any
allocation. Over-cap surfaces as `cx-err:CXER0011`. Remaining
map / closure-capture / nested-collection caps are tracked under
U4 and ship over the v0.7.x window — see `spec/v0_7_0_status.md`
row U4.

### T12 — Streaming-sink DoS

The v0.7.0 streaming evaluator (`cx_eval_cxl_streaming`) takes a
host-supplied callback that the V core invokes once per emitted
chunk. An actor who controls neither the document nor the
template but who controls the network can apply backpressure to
the sink and pin the evaluator (and its allocator state) for an
unbounded duration.

**Mitigation:** the streaming evaluator inherits the T10 + T11
budgets. Per `spec/streaming.md` the sink callback is documented
as synchronous-best-effort; bindings that wrap it (Python ctypes,
Go cgo, Rust extern, TypeScript koffi) document that the
callback's runtime budget is the caller's responsibility — the
core does not enforce a per-chunk timer. Consumers wrapping the
streaming API for untrusted-network sinks MUST apply their own
timeout (e.g., `socket.settimeout`).

### T14 — Schema-validation bypass via dynamic xs: constructors (v0.7.0 fix)

Pre-v0.7.0, an attacker could submit a string that wasn't a
parseable number through an `xs:integer($user_input)` /
`xs:double(...)` chain and have it silently coerced to 0
(integer) or 0.0 (double) instead of raising an error. Code
that downstream treats the result as a "validated number" then
acts on attacker-supplied garbage as if it were valid.

**Mitigation (v0.7.0):** `vcx/cx/cxl.v:xs_strict_parse_f64`
routes every `xs:int*`, `xs:double`, `xs:float`, `xs:decimal`,
`xs:nonNegativeInteger`, `xs:positiveInteger`, and `cast-as`
target through a strict parse path. String / TextNode inputs
that don't parse as a number raise `cx-err:FORG0001` with the
offending value carried in the structured-error payload.
Numeric scalar inputs are passed through unchanged (so
`xs:integer(1.7)` still truncates per XPath §19.1.2). Regression
tests `test_u8_xs_*` in `vcx/tests/cxl_test.v`.

This is a **behavior change** from v0.6.0: callers that
previously relied on the silent-coercion-to-0 fallback now
receive an error and must apply explicit `[?try]` /
`[?castable-as]` guards if they want the lenient behavior.

### T13 — `cx:lang` inherited-scope attribute poisoning

The v0.7.0 evaluator threads `cx:lang` through the element tree
via the inherited-scope walk in `resolve_element_lang`. The
attribute is *declarative* — it tags content with a BCP-47 tag
and affects format-aware fn calls (Z row) but does not select
code paths in the evaluator core.

**Mitigation:** out of scope (no privileged surface). The walk
treats `cx:lang` like any other attribute (UTF-8 validated, length
bounded by the attribute-count cap) and no fn:`format-*` resolves
against caller-supplied locales without going through the same
allocation budgets as any other fn call.

---

## 5 — Hardening currently in place

The following defenses are in place at the V core and inherited by
every binding. Each is testable through the conformance suite and
covered by spec.

| defense | mechanism | reference |
| ------- | --------- | --------- |
| Recursion limit | configurable depth cap (default 64), enforced at parse and at AST traversal | `spec/policies.md` |
| Element count cap | configurable max elements per document | `spec/policies.md` |
| Attribute count cap | configurable max attributes per element | `spec/policies.md` |
| Payload-size cap | per-allocation budget on binary decoders | `spec/data_bin.md` |
| Varint validation | overlong / truncated varints rejected | `spec/data_bin.md` |
| External-entity rejection | DOCTYPE parsed but inert; no entity expansion | `spec/grammar.ebnf §80–101` |
| XXE / billion-laughs immunity | follows from external-entity rejection | (by-construction) |
| Include resolution scoping | path-only, caller-supplied root | `spec/ast.md §25` (formal spec pending) |
| UTF-8 validation | invalid UTF-8 in any input is an error | `spec/abi.md §111–116` |
| Bounds-checked deserialization | every binding's CXDB / AST decoder validates length prefixes before allocation | `spec/governance.md §1.2`; per-binding codec |
| Type-preservation across formats | CXDB v1 binary, no string-format roundtrips on hot paths | `spec/governance.md §1` (closed in 2026-05 audit) |
| Canonical-form determinism | `cx canonical` byte-stable across runs and bindings | `spec/canonical.md`, `spec/governance.md §2.3` |
| Linear-time regex (v0.7.0) | All `fn:matches`/`tokenize`/`replace`/`analyze-string` callsites route through the vendored RE2 shim; ReDoS-class patterns terminate in linear time | `vcx/deps/re2_shim/`, `vcx/cx/regex_re2.v`; regression `test_u2_regex_redos_bounded` |
| Function-recursion budget (v0.7.0) | `CXLEnv.call_depth` enforced against `max_call_depth` (default 256); surfaces as `cx-err:CXER0010` | `vcx/cx/cxl.v` `call_fn_emit` / `call_fn_to_value`; regression `test_u3_recursion_limit_triggers` |
| Sequence-length budget (v0.7.0) | `CXLEnv.max_sequence_len` (default 1M items) on `to` and `[?range]`; surfaces as `cx-err:CXER0011` | `vcx/cx/cxl.v` `eval_op_to` / `filter_range`; regression `test_u4_sequence_length_limit_triggers` |
| Reproducible builds (v0.7.0) | `SOURCE_DATE_EPOCH` + pinned toolchain; double-build CI gate (`.github/workflows/reproducibility.yml`) | `docs/reproducible_builds.md`, BB row of `spec/v0_7_0_status.md` |
| Nightly fuzz coverage (v0.7.0) | 1h/night fuzz run against parser + buffered + streaming + ABI surfaces; crashes uploaded as CI artifacts | `docs/fuzzing.md`, `.github/workflows/fuzz.yml`, CC row of `spec/v0_7_0_status.md` |
| Strict xs: constructors (v0.7.0) | `xs:integer`/`xs:double`/`xs:decimal`/etc. raise `cx-err:FORG0001` on unparseable string inputs (previously silently coerced to 0); applies to direct constructor calls and `cast-as` | `vcx/cx/cxl.v:xs_strict_parse_f64`; regressions `test_u8_xs_*` |

---

## 6 — Known unhardened areas

| area | status | reference |
| ---- | ------ | --------- |
| Fuzz-testing harness | shipped at v0.7.0 — see §5 row | `docs/fuzzing.md` |
| External security audit | absent | `ROADMAP.md` "Later"; targeted post-v0.7.0 |
| Reproducible libcx builds | shipped at v0.7.0 — see §5 row | `docs/reproducible_builds.md` |
| Signed release artifacts | absent | `ROADMAP.md` "Later" |
| Include-resolution formal spec | partial | named in §4 T3 |
| Streaming-write API hardening | partial — `cx_eval_cxl_streaming` lands at v0.7.0 with T10/T11 budgets; per-chunk timer remains caller responsibility (T12) | `spec/streaming.md`, U-row of `spec/v0_7_0_status.md` |
| Partial-application closure-leak audit | partial — U5 of `spec/v0_7_0_status.md` open | tracked at U5 |
| Memory-cap completeness | partial — sequence-length cap shipped (T11); map / nested-collection / closure-capture caps tracked at U4 | tracked at U4 |
| BOM / line-ending policy | undefined | v0.6.0 blockers (`§1`) |
| Unicode normalization policy | undefined | v0.6.0 blocker (`§7`) |

Each row above is tracked in `ROADMAP.md` and will move to the
"hardened" table in §5 as it closes.

---

## 7 — Trust assumptions adopters should verify

An adopter deploying CX makes these assumptions; the threat model is
written assuming each holds. Where an adopter's environment violates
an assumption, additional mitigations are the adopter's
responsibility.

1. **The libcx binary you load is the one published.** Verify
 SHA-256 against `dist/SHA256SUMS.txt` for the release tag, or
 build libcx from a checked-out source tree at a known commit.
2. **Resource limits are tuned for your environment.** Defaults in
 `spec/policies.md` are conservative for general-purpose use;
 high-throughput services should raise them, low-trust services
 should lower them.
3. **Include resolution is restricted to a known root.** If your
 service parses CX documents from semi-trusted sources, set the
 include-root before parsing or disable include resolution
 entirely.
4. **Error messages are not re-exported verbatim** to surfaces
 accessible by attackers.
5. **The host process applies appropriate isolation** — file
 descriptor limits, memory limits, syscall sandboxing — that
 the format itself cannot enforce.

---

## 8 — Reporting a vulnerability

See [`SECURITY.md`](../SECURITY.md). Use GitHub's private
vulnerability reporting at
<https://github.com/cx-home/cx/security/advisories/new>. Coordinated
disclosure with a 7-day window after a fix lands.

---

## 9 — Out-of-scope vulnerability classes

The following are explicitly *not* CX vulnerabilities, even when
reachable through a CX-using application:

- Bugs that require the operator to write a CX file containing
 attacker-controlled content and then load it under elevated
 privilege. (This is a deployment vulnerability, not a parser
 vulnerability.)
- Bugs in third-party tooling that consume CX output (e.g., a
 downstream JSON consumer that mishandles a CX-emitted JSON
 document). Report to the downstream tool.
- Side channels that require co-resident execution and are
 inherent to the host architecture (Spectre-class issues).
- Algorithmic-complexity attacks that the configured resource
 limits in `spec/policies.md` would have prevented if the
 defaults were used.

If a report is unclear which side it falls on, file it; the
maintainers will route appropriately.

---

## 10 — Trust model for `eval_cxl` (v0.7.0)

The v0.7.0 evaluator surface (`cx_eval_cxl`, `cx_eval_cxl_streaming`,
and their per-binding wrappers) takes three caller-supplied inputs:

  1. **A CX data document** (the context).
  2. **A CXL template** (the program).
  3. **An output target** (`text` / `cx` / `html`).

`eval_cxl` is **not** a sandbox between mutually distrusting parties.
A template can read any node in the data document and emit any
value derived from it. Capability separation is the caller's
responsibility — typically expressed as:

  - If the **data document** comes from an untrusted source but
    the **template** is operator-authored, the trust posture is
    "data-untrusted". Untrusted-data DoS scenarios (T1, T9-T11)
    are bounded by the documented hardening — RE2 for regex,
    `max_call_depth` for recursion, `max_sequence_len` for ranges.
    Output sanitization for the chosen target (auto-escape on
    `html`) is enforced.

  - If the **template** itself comes from an untrusted source,
    the caller is operating in an "eval-injection" posture. The
    template can:
      - read every attribute and child node of the data document
        the caller passed in,
      - emit any value derived from those nodes,
      - cause an evaluation error that surfaces to the caller.
    The template **cannot** at v0.7.0:
      - read any file on disk: `[?include]` returns a documented
        "not yet implemented" error before touching the file
        system (regression `test_u1_include_path_traversal_blocked`).
      - reach the network: no `http:`/`file:` modules ship in
        v0.7.0 (BaseX-style modules deferred to v0.8.0).
      - escape its T10 recursion budget, T11 sequence budget, or
        T9 ReDoS protection.
    Callers in this posture MUST still apply per-evaluation
    timeouts and per-evaluation memory caps at the host level —
    the evaluator's budgets bound the worst case but do not
    bound wall-clock for a malicious template that interleaves
    many small expensive operations.

  - **Eval-injection of a template into another template's
    context** (e.g. a CMS that lets an editor write
    `[?=$user_template]` where `$user_template` is itself a
    CXL string) is a deployment vulnerability, not a v0.7.0
    parser/evaluator vulnerability. Don't do it.

This section codifies the U1 row of `spec/v0_7_0_status.md` and
the corresponding §4 T1/T9/T10/T11 mitigations.

---

## 11 — Trust model for `cx:eval` (v0.7.0 self-host)

Per ADR 0023 §D6 and [`spec/modules/cx.md §2`](modules/cx.md). The
`cx:eval(source, context, options?)` self-host function evaluates a
cxl `source` string at runtime against a `context` map. It is
**categorically different** from §10's `eval_cxl` C-ABI entry:
`eval_cxl` runs an operator-authored template against caller data;
`cx:eval` runs a string-supplied program that may itself be
adversary-controlled. The five mitigations in `spec/modules/cx.md §2`
are normative; this section is the threat-model companion.

### 11.1 — Untrusted-input sources

A `cx:eval` call is **in scope** for this section whenever any of
the following is true of its `source` argument:

  - derived from a network request body, query parameter, or header
  - read from a filesystem path supplied by an end user, a configuration
    file under a user-writable directory, or any input channel the
    caller does not co-own with the eval target
  - read from stdin, an environment variable, a database column, or
    a message-queue payload
  - interpolated from any value not authored by the same trust
    domain as the caller binary

A `cx:eval` call is **out of scope** when its `source` argument is a
static string literal in the calling document (semantically
equivalent to a `?def` block — already trusted authoring-time code)
or a string derived deterministically from such a literal by Pure
fn:* / map:* / array:* operations.

### 11.2 — Mitigation summary (M1..M5)

The five mitigations from `spec/modules/cx.md §2` map to specific
threat vectors:

| # | Mitigation | Error code | Defends against |
|---|---|---|---|
| M1 | `cx:eval` invocation requires `[?cx allow-eval=true]` at document head | `cx-err:CXER0041` (eval-not-enabled) | Accidental exposure — a document that statically references `cx:eval` but never reaches the call site cannot be silently weaponized. The flag is a load-bearing operator decision audited at deployment. |
| M2 | `[?cx allow-eval=true]` and `[?cx pure-only]` are mutually exclusive | `cx-err:CXER0042` (eval-incompatible-with-pure-only) | Defense-in-depth — pure-only mode forbids all SideEffect functions, and `cx:eval` is SideEffect. M2 fires at parse time (`apply_program_config!` hoist) AND at dispatch time, so a maliciously-crafted document head cannot escape both. |
| M3 | Sandboxed `CXLEnv` — context-map keys are the only bindings the evaluated fragment sees | (no error code — visibility check) | Information disclosure / capability escalation — caller's `?def` / `?let` / `?with` / `?fn` bindings are **not** visible inside the fragment. The caller must explicitly route values through the `context` map, making the data flow audit-visible. Filesystem-relative paths likewise do not inherit. |
| M4 | Module pass-through is restrictive — fragment cannot widen the caller's `[?cx use-module=...]` set | `cx-err:CXER0043` (eval-module-widening) | Capability escalation through module enumeration — a fragment that activates `hash:` while the caller activated only `fn:` is refused. Bounds the v0.8.0 BaseX-module attack surface (file: / http: / random:) before those modules even ship. The fragment may narrow (fewer modules) but never widen. |
| M5 | Recursion-depth cap — default 8, configurable per-call via `options.max-depth`, per-document via `[?cx max-eval-depth=N]` | `cx-err:CXER0044` (eval-recursion-depth-exceeded) | Stack-exhaustion DoS — adversarial fragment that calls `cx:eval` recursively (directly or via `cx:render`) cannot recurse past the cap. Counter increments across the include chain so mutual recursion is bounded cumulatively. |

### 11.3 — Recommended deployment patterns

For untrusted-eval workloads:

  1. **Process boundary.** Run `cx:eval`-bearing documents in a
     separate OS process with a documented memory cap (cgroups /
     `ulimit -v` / equivalent) and wall-clock timeout. The five
     mitigations bound worst-case-per-call but do not bound
     accumulated wall-clock for a malicious fragment that
     interleaves many cheap operations.
  2. **`pure-only` at the document head where possible.** If the
     enclosing document does not need SideEffect functions,
     `[?cx pure-only]` plus the process boundary gives defense in
     depth: M2 refuses `allow-eval=true` co-presence, so an attacker
     who flips `pure-only` cannot also enable eval.
  3. **Static `[?cx allow-eval=true]` lint.** `cx lint` emits
     `L006-eval-bearing` informational on every document carrying
     the flag. Adopters SHOULD raise this severity to warning or
     error in deployment via `.cxlint.cx` so the flag's presence is
     surfaced at code review and audit time.
  4. **Context-map minimisation.** Pass only the values the
     fragment needs into the `context` map. Do not pass an entire
     document or an entire credentials struct — the fragment sees
     every key. (M3 means only context-map keys are visible, so the
     map literally enumerates the fragment's capability surface.)
  5. **Module-set minimisation.** Activate only the modules the
     fragment requires via `[?cx use-module=...]` at the calling
     document head. M4 means the fragment cannot escalate beyond
     the caller's set, so this directive bounds the attack surface.
     A fragment with no modules activated can still call cx: (always
     present), fn:, map:, array:, math:, log: — these are not
     gateable at v0.7.0. v0.8.0 BaseX modules (file: / http: / hash:
     / random:) WILL be gateable via M4.

### 11.4 — Known limits at v0.7.0

  - **No CPU/memory budget per fragment.** The mitigations bound
    recursion depth and the static enumeration surface; they do not
    bound the total cycles or allocations spent inside a single
    `cx:eval` call. A fragment that consumes 100MB to compute a
    pathological `fn:fold-left` is not refused by M1..M5 alone.
    Process-level limits (recommendation 1) are the load-bearing
    defense.
  - **`cx:eval` outputs are not sanitized.** Result is a cx-value;
    `cx:render` returns a string. Callers using the output in HTML
    contexts MUST route through `[?cx output-target=html]` (the
    auto-escape target) or apply a domain-appropriate sanitizer.
  - **Origin threading is informational, not authoritative.** The
    `options.origin-uri` / `origin-line` / `origin-col` keys
    thread through to the `err-eval-origin` `?try` binding for
    error-reporting purposes. They are **caller-asserted** — a
    fragment cannot rely on them for security decisions.

This section codifies the W26 / DD26 row of `spec/v0_7_0_status.md`
and the M1..M5 mitigations of ADR 0023 §D6.

---

## 12 — Revision history

| date | version | change |
| ---- | ------- | ------ |
| 2026-05-07 | initial | First version. Establishes scope, deployment models, threat actors, and the §5 hardening table. Names §6 known gaps as roadmap items. |
| 2026-05-18 | v0.7.0 | Adds §4 T9 (ReDoS via XPath regex fns / RE2 mitigation), T10 (`?fn` recursion DoS / `max_call_depth`), T11 (sequence-length DoS / `max_sequence_len`), T12 (streaming-sink DoS), T13 (`cx:lang` poisoning, out of scope), T14 (schema-validation bypass via xs: silent coercion — fixed by strict parse). §5 gains rows for linear-time regex, recursion + sequence budgets, reproducible builds, nightly fuzz harness, and strict xs: constructors. §6 marks fuzz harness + reproducible-build rows as shipped and refines the streaming and memory-cap rows to reflect partial coverage. Adds §10 "Trust model for eval_cxl" codifying U1: `eval_cxl` is not a sandbox; data-untrusted vs. eval-injection postures are explicitly distinguished; templates cannot reach the file system (`?include` gated, regression `test_u1_include_path_traversal_blocked`) or the network at v0.7.0. Behavior-change note: T14 strict xs: parse is observable for code that previously relied on silent-coercion-to-0; v0.6.0 → v0.7.0 callers MUST add `[?try]` / `[?castable-as]` guards. |
| 2026-05-18 | v0.7.0 (DD26) | Adds §11 "Trust model for cx:eval" per ADR 0023 §D6 — distinguishes `cx:eval` (runtime callable with adversary-controlled `source` string) from §10 `eval_cxl` (C-ABI entry running operator-authored template against caller data); enumerates untrusted-input sources (network / filesystem / stdin / env / DB / message-queue / cross-trust-domain interpolation); maps M1..M5 mitigations to threat vectors with `cx-err:CXER0041..0044` error codes; codifies five recommended deployment patterns (process boundary, `pure-only` default, `L006-eval-bearing` lint elevation, context-map minimisation, module-set minimisation); names three known limits at v0.7.0 (no per-fragment CPU/memory budget — process-level the load-bearing defense; outputs not sanitised — `[?cx output-target=html]` or domain sanitizer required for HTML contexts; origin keys are caller-asserted, not authoritative). Renumbers Revision history from §11 to §12. |

The next revision lands when v0.6.0 closes the §6 gaps; at that
point the §1 pre-v0.6.0 caveat is updated to reflect the new posture
(stability-boundary release with audit and fuzz in place).
