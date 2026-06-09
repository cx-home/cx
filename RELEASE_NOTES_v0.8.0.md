# CX v0.8.0 — Release Notes

**Date:** 2026-06-09
**Tag:** `v0.8.0` (v0.7.6 was an internal design pass, never released)

The release that locks CX's read + write surface on a unified
selector vocabulary. CXPath is restored as a first-class value kind;
`[?match]` learns heterogeneous arms; `[?modify]` introduces
pure-functional updates with structural sharing. Bindings narrow to a
four-language Tier 1 (V/Python/Go/Rust) under a two-layer contract:
Layer 1 mirrors CX everywhere; Layer 2 packs host idioms (Pythonic
comprehensions, Go filter chains, Rust iterator combinators).

## Headline

- **CXPath as first-class value kind** ([`spec/code.md`](spec/code.md))
  — `//user[@active=true]/@email` is an expression; usable directly
  in `[?for]`, `[?if]`, `[?match]`, `[?modify]`, and binding `select_all`.
  All 12 XPath 3.1 axes; value-comparison semantics on sigils
  `= != < <= > >=`; no keyword-comparison synonyms (sigils only).
- **Multi-arm `[?match]`** ([`spec/code.md`](spec/code.md))
  — `:case PAT :yield E` / `:when PRED :yield E` / `:else :yield E`.
  Scalar literal patterns. `_` wildcard. First-match-wins, top-down.
  CXER0100 still flags the single-arm-with-no-match for back-compat.
- **`[?modify]` directive** ([`spec/code.md`](spec/code.md))
  — pure-functional updates via CXPath focus + action vocabulary.
  Eleven actions: `:set`, `:delete`, `:using`, `:rename`,
  `:set-attr`, `:delete-attr`, `:append`, `:prepend`,
  `:insert-before`, `:insert-after`, `:replace`. Pipeline-composable
  via `|`. Structural sharing — < 1 KB new heap per matched node on
  a 10 MB document.
- **Two-layer bindings** ([`spec/bindings.md`](spec/bindings.md)) —
  Layer 1: 16 canonical methods, identical across V/Python/Go/Rust,
  conformance-validated byte-for-byte. Layer 2: host idiom packs
  (`cxlib.idioms` in Python, `cxlib/idioms` in Go, `cxlib::idioms`
  in Rust) desugaring to Layer 1.
- **Binding set narrowed** to V/Python/Go/Rust ([backlog `d-2026-05-22-03`](docs-src/canonical/backlog.cxd)).
  TypeScript / Java / C# / Ruby / Kotlin / Swift archived to
  `lang/_archived/`. Restoration is opt-in once the Layer-1 surface
  stabilizes.
- **`programs` → `code` rename**
  — `spec/programs.md` → `spec/code.md`, `vcx/programs/` →
  `vcx/code/`, `cx_program_eval` → `cx_code_eval`. Brand-surface
  rename ("CX is data and code") propagated through the internal API.
- **`[?find]` retired** — superseded by `[?for]` (pattern-generator
  form) and CXPath value-kind `//path`.
- **XPath 3.1 parity verified** against Saxon-HE — new conformance
  gate 28.5 with fixtures tagged `xpath31-parity` /
  `xpath31-divergence`. Documented divergences:
  no construct duplication (for / let / if / function stay in CX
  code), value-comparison-only on sigils, CX type vocabulary in
  place of `xs:integer`/`xs:string`/etc, namespace declarations live
  in data not expressions.

## Carried from v0.7.6 (released as part of v0.8.0)

The v0.7.6 design pass landed substantively on `v0.7.6-dev` but was
never tagged ([backlog `d-2026-05-22-04`](docs-src/canonical/backlog.cxd)).
Its deliverables ship in v0.8.0:

- §11 capabilities: services, concurrency primitives, async, visualization.
- Resilience directive family: `[?retry]`, `[?timeout]`,
  `[?circuit-breaker]`, `[?fallback]`, `[?rate-limit]`, `[?bulkhead]`.
- Diagram round-trip — SVG / PNG / Mermaid all reverse-parse to
  structurally equal CX trees (gate 9).
- Streaming evaluator at ≥ 200 MB/s on JSON-shape workloads (gate 15
  measured 353 MB/s on M-series).
- HTTP service substrate at ≥ 10K req/s (gate 16 measured ~87K rps).
- Playground gate 17 — Mermaid source-pane + interactive
  output-pane tree.

## Breaking changes

| What | Migration |
|---|---|
| `[?find]` directive removed | Use `[?for]` (pattern-generator) or `//path` (selection). |
| `cx_program_eval*` C ABI removed | Renamed to `cx_code_eval*`. One substitution per FFI extern decl. |
| `_cx_program_*` wasm exports renamed | All `_cx_program_*` → `_cx_code_*`. |
| `spec/programs.md` filename | Renamed to `spec/code.md`. Update any docs you maintain. |
| `conformance/programs.txt` filename | Renamed to `conformance/code.txt`. |
| `in_cxl:` fixture-format header | Renamed to `in_code:`. |
| TypeScript / Java / C# / Ruby / Kotlin / Swift bindings | Archived to `lang/_archived/`. Stay on v0.7.x or migrate to a Tier-1 binding. |
| Single-arm `[?match]` still accepted | No change to existing code. Multi-arm form is opt-in. |
| Module `vcx/programs/` → `vcx/code/` | V code: `import vcx.programs` → `import vcx.code`; `programs.eval_program` → `code.eval_code`. |

The mechanical renames (`programs → code`, `cxdb → cxcol`) have
been applied across the codebase as part of this release.

## Layer 1 — the 16 canonical methods

Per [`spec/bindings.md §2.1`](spec/bindings.md), every supported
binding (V/Python/Go/Rust) exposes the same 16 methods with identical
semantics:

| Method | Returns |
|---|---|
| `parse(bytes)` | `Document` |
| `bytes(node)` | canonical bytes |
| `hash(node)` | SHA-256 (32 bytes) |
| `equals(a, b)` | bool — value identity |
| `eval(code, doc?)` | result |
| `select_all(path)` | `Sequence<Node>` |
| `select(path)` | first match, or null |
| `modify(focus, action)` | new `Document` |
| `find_all(pattern)` | `Sequence<Node>` |
| `root()` | the root Element |
| `name()` | element name |
| `attr(key)` | attribute value |
| `attrs()` | all attributes |
| `children()` | child sequence |
| `body()` | body text |
| `kind()` | item kind enum |

Layer-1 parity is conformance-validated via
`conformance/binding_api.txt` (new in v0.8.0 — gate 28.6).

## What's NOT in v0.8.0

- **Custom Layer-2 idiom packs beyond the four shipped**. Community
  contributions accepted.
- **TypeScript / Java / C# / Ruby / Kotlin / Swift refresh**. The
  archived snapshots build against the v0.7.6 ABI; they are not
  v0.8.0-compatible. Restoration is post-v0.8.0.
- **Public docs site** at cx.land remains on v0.7.5 content until
  v0.8.0 ships. The v0.8.0 surface is a single canonical guide
  (`make guide`); the prior `make docs` pipeline (per-page `.cx`
  source under `docs-src/content/` rendered to `_docs_staging/`)
  was retired during the v0.8.0-cleanup branch — all unique
  content folded into `docs-src/canonical/sections/*.cxd`.

## Acknowledgements

The v0.8.0 design pass synthesized feedback from the v0.7.6 review
window. Key contributors per the backlog:
[`d-2026-05-22-01`](docs-src/canonical/backlog.cxd) (brand),
[`d-2026-05-22-11`](docs-src/canonical/backlog.cxd) (ADR format),
[`d-2026-05-22-12`](docs-src/canonical/backlog.cxd) (sigils only),
[`d-2026-05-22-13`](docs-src/canonical/backlog.cxd) (ADR length discipline).

## Verification

Every gate in [`spec/v0_8_0_status.md`](spec/v0_8_0_status.md) §11.6
is ✅ at tag time. The gate evidence bundle (`v0.8.0-gate-evidence.tar.gz`)
is attached to the GitHub release.
