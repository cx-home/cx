# CX Per-binding Parity Matrix

**Status:** Current for v0.8.0

This document records per-binding compliance with the parity rule in
[`spec/process/governance.md`](../process/governance.md). Active
bindings in v0.8.0 scope: **V (native)**, **Python**, **Go**, **Rust**.

---

## 1 — Scope

Two parity questions are tracked:

- **Output parity (load-bearing).** For identical input, every binding
  emits identical canonical-form bytes. Only mechanically verifiable
  definition of "no major gaps."
- **Idiomatic API parity.** Public API shape differs per language
  (Python `parse()`, Go `Parse()`, Rust `parse()?`) but the capability
  set is uniform.

A binding may diverge idiomatically and still pass output parity. What
is not allowed is capability divergence — missing CXPath, or different
canonical bytes for the same input.

---

## 2 — Capability matrix

`✓` = implemented + documented. `(✓)` = implemented; README pending.
`📋` = post-design, pre-implementation. `🚧` = in progress. `—` = N/A.

| Capability | V (native) | Python | Go | Rust |
|---|---|---|---|---|
| Parse CX text | ✓ | ✓ | ✓ | ✓ |
| Parse XML / JSON / YAML / TOML / MD | ✓ | ✓ | ✓ | ✓ |
| Emit canonical CX | ✓ | ✓ | ✓ | ✓ |
| Emit XML / JSON / YAML / TOML / MD | ✓ | ✓ | ✓ | ✓ |
| Document / Element traversal | ✓ | ✓ | ✓ | ✓ |
| Mutation (set_attr / append / …) | ✓ | ✓ | ✓ | ✓ |
| Immutable transform | ✓ | ✓ | ✓ | ✓ |
| CXPath — `select` / `select_all` (route through `cx_code_eval`) | ✓ | ✓ | ✓ | ✓ |
| `diff` (wraps `cx_diff`, `core/abi.md §2.17`) | ✓ | ✓ | ✓ | ✓ |
| `lint` (wraps `cx_lint`, `core/abi.md §2.18`) | ✓ | ✓ | ✓ | ✓ |
| Streaming parse (event iterator) | ✓ | ✓ | ✓ | ✓ |
| `:table` block — read | ✓ | ✓ | ✓ | ✓ |
| `:table` block — write (Table API) | (✓) | (✓) | (✓) | (✓) |
| `data_bin` one-shot loaders/dumpers | ✓ | ✓ | ✓ | ✓ |
| Chunked-table one-shot | ✓ | (✓) | (✓) | (✓) |
| Streaming Table reader / writer | ✓ | (✓) | (✓) | (✓) |
| Schema-driven encoding | ✓ | (✓) | (✓) | (✓) |
| Arrow C-Data interop (`libcx_arrow`) | ✓ | ✓ | ✓ | ✓ |
| `fmt` (lossless canonical) | ✓ | ✓ | ✓ | ✓ |
| `canonical` (strict canonical) | ✓ | ✓ | ✓ | ✓ |
| `hash` (SHA-256 of strict) | ✓ | ✓ | ✓ | ✓ |
| `eq` (data equivalence) | ✓ | ✓ | ✓ | ✓ |
| `version()` accessor | ✓ | ✓ | ✓ | ✓ |
| Native dict/list `loads` / `dumps` | — | ✓ | ✓ | ✓ |
| Atom scalar | ✓ | ✓ | ✓ | ✓ |
| Layer-1 19-method API (see [`misc/bindings.md §2.1`](bindings.md)) | 19/19 | 19/19 | 19/19 | 19/19 |
| Schema validate | ✓ | ✓ | ✓ | 📋 |
| CXPath as value kind | 🚧 | 📋 | 📋 | 📋 |
| `[?match]` multi-arm | 📋 | 📋 | 📋 | 📋 |
| `[?modify]` pure-functional | 📋 | 📋 | 📋 | 📋 |
| `[?def]` module-level functions | 📋 | 📋 | 📋 | 📋 |
| Iterator value kind | ✓ | ✓ | ✓ | 📋 |
| `[?lib]` module loading + `cx.lock` | 📋 | 📋 | 📋 | 📋 |
| `[?const]` module-level constants | 📋 | 📋 | 📋 | 📋 |
| `[expr]` general predicate + `$_` | 📋 | 📋 | 📋 | 📋 |
| Purity modifier algebra (`pure` / `impure`) | 📋 | 📋 | 📋 | 📋 |
| `cx-stdlib` bundled | 📋 | 📋 | 📋 | 📋 |
| Playground views — `cx_code_diagram` + `cx_code_tree` | 📋 | — | — | — |

Playground view rows are `—` for Python/Go/Rust because the C ABI
exports (`cx_code_diagram`, `cx_code_tree`) target the wasm playground
front-end via the V core; per-FFI-binding wrappers are not in v0.8.0
scope.

---

## 3 — Output parity (load-bearing)

For each fixture under [`conformance/`](../../conformance/), every
active binding produces output bytes that compare equal to the V
reference's output, byte-for-byte. CI gates on byte-equality across
all four bindings. There are zero allowed-divergence exceptions; no
fixture is tagged `lang_specific`.

A second class of fixtures verifies V-reference behavior on internal
formats (chunked-table wire form, page-compression wrapper,
schema-driven encoding, Arrow C-Data round-trip). They gate V-side
regressions through `make conform`.

---

## 4 — Capability bits

Every binding reads `cx_features` from `libcx` at load time and refuses
to claim a capability the loaded library does not advertise. The bit
registry is in [`core/abi.md`](../core/abi.md). The bitmask is
**append-only**: a bit, once assigned a meaning, never changes meaning.
Removing a bit requires a major libcx version bump.

---

## 5 — Idiomatic API divergence

The shape of the API differs per language by design; the capability set
is uniform. Examples:

| Concept | Python | Go | Rust | V (native) |
|---|---|---|---|---|
| parse CX → document | `parse(s)` | `Parse(s)` | `parse(s)?` | `cx.parse(s)` |
| document → CX text | `doc.to_cx()` | `doc.ToCx()` | `doc.to_cx()` | `doc.to_cx()` |
| parse + native types | `loads(s)` | `Loads(s)` | `loads(s)` | `cx.loads(s)` |
| canonical hash | `cx.hash(s)` | `cxlib.Hash(s)` | `cx::hash(s)` | `cx.hash(s)` |
| CXPath select all | `doc.select_all(e)` | `doc.SelectAll(e)` | `doc.select_all(e)` | `doc.select_all(e)` |

Each binding follows its language's idiomatic naming (snake_case for
Python/Rust/V; CamelCase for Go) and error handling (exceptions,
`Result`, `error` returns).

Per-binding API references with full method tables live in each
binding's `cxlib/README.md`.

---

## 6 — Implementation-strategy declarations

Every binding declares which `libcx` C ABI symbols its public methods
call. The declaration lives in each binding's README. The declarations
are kept honest by the "no roundtrips" rule per
[`process/governance.md`](../process/governance.md): a public API may
call exactly one core symbol, plus a binary decode.

The current set of declared mechanisms is consistent across all four
bindings:

- Parse paths use `cx_to_ast_bin` — one C call.
- Emit paths use `cx_ast_bin_to_<fmt>` — one C call.
- One-shot conversions use `cx_to_data_bin` / `cx_data_bin_to_<fmt>` —
  one C call.
- CXPath routes through `cx_code_eval` with a path-value expression
  (the standalone `cx_select` / `cx_select_all` C ABI was retired at
  v0.8.0 — see [`core/abi.md §2.7`](../core/abi.md)). Bindings retain
  their `Doc.select()` / `Doc.select_all()` Layer-1 surfaces; only the
  underlying ABI symbol changed.
- Streaming uses the `cx_events_*` family.
- Diff / lint use `cx_diff` / `cx_lint`
  ([`core/abi.md §2.17`](../core/abi.md) and
  [`§2.18`](../core/abi.md)).

No binding routes through a host-language intermediate format.

---

## 7 — V's native binding

The `lang/v/native/` directory imports `vcx.cx` modules directly. It
skips `libcx` entirely; no FFI on hot paths. Native types are the V
core's own types or thin ergonomic wrappers. This is the single fastest
path on the V VM/platform.

---

## 8 — Maintenance and drift detection

The matrix is kept honest by:

- **Parity check (§3).** Output drift fails CI immediately.
- **Bit-mask check (§4).** A binding that advertises capability bit N
  without the implementation behind it fails the binding's startup
  self-check.
- **Symbol-diff check (§6).** A binding whose public API method list
  disagrees with its README's "Implementation strategy" table fails CI.
- **`make conform` after every binding change.** The full fixture set
  is the bottom-line verification.

Every PR that touches `lang/` must keep this matrix accurate. A PR that
adds a capability to one binding without the matching update to the
other three is drift; the PR is not mergeable until the matrix is
restored.

---

## 9 — References

- [`process/governance.md`](../process/governance.md) — the parity
  rule this document implements.
- [`core/abi.md`](../core/abi.md) — C ABI surface and capability-bit
  registry.
- [`misc/bindings.md`](bindings.md) — Layer-1 16-method canonical
  surface.
- [`conformance/`](../../conformance/) — fixture files.
- Each binding's `cxlib/README.md` — per-binding API reference and
  implementation-strategy declaration.
