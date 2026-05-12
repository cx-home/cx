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

---

## 6 — Known unhardened areas

| area | status | reference |
| ---- | ------ | --------- |
| Fuzz-testing harness | absent | v0.6.0 blocker (``) |
| External security audit | absent | v0.6.0 blocker (``) |
| Reproducible libcx builds | partial | v0.6.0 blocker (``) |
| Signed release artifacts | absent | `ROADMAP.md` "Later" |
| Include-resolution formal spec | partial | named in |
| Streaming-write API hardening | API not yet present | v0.6.0 blocker (`§8`) |
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

## 10 — Revision history

| date | version | change |
| ---- | ------- | ------ |
| 2026-05-07 | initial | First version. Establishes scope, deployment models, threat actors, and the §5 hardening table. Names §6 known gaps as roadmap items. |

The next revision lands when v0.6.0 closes the §6 gaps; at that
point the §1 pre-v0.6.0 caveat is updated to reflect the new posture
(stability-boundary release with audit and fuzz in place).
