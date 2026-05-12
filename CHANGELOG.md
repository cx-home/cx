# Changelog

All notable changes to CX are recorded here. Per-release deep-dives
live in [`docs/releases/`](docs/releases/); migration instructions
live in [`docs/migrations/`](docs/migrations/).

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
plus the additional [`spec/governance.md §9` versioning rules](spec/governance.md#9-versioning)
for the multi-axis CX project (language version, ABI version, format
version, library version).

## [Unreleased]

(empty)

## [0.6.0] — 2026-05 (planned)

The **API/format-stability boundary**. From 0.6.0 onward through
1.0, no breaking changes to the public surface (C ABI, binding APIs,
wire formats, spec-normative grammar).

### Added
- **17-member Public Table API** — shipping in all 10 bindings (V native, V-cffi, Python, Go, Rust, Java, TypeScript, C#, Kotlin, Swift, Ruby).
- **Collection literals** — first-class `seq[T]`, `arr[T]`, `map[K, V]` with cross-emitter parity.
- **`cx table` CLI subcommand** ( §D1) — `info` / `dump` / `load` verbs.
- **`cx demo` subcommand** — self-contained 60s-tier showcase per the evaluation-experience checklist.
- **`cx scaffold <kind>` subcommand** — typed, commented skeletons for config / data / doc / log / table.
- **CSV / TSV / PSV via `--csv` / `--tsv` / `--psv` CLI flags** — delimited conversion now CLI-accessible (was C-ABI-only).
- **Streaming-write event API** (capability bit 27) — Tier 1 + Tier 2 + CX/XML emits.
- **Schema validator** — 20/20 spec rules complete on Tier 1 (V core + Python + Go).
- **CXL 1.0 evaluator** (V reference; per-binding native rollout deferred to v0.7.0).
- **Parameterized templates** — `?def name :params [a b] :body ...`.
- **`the evaluation-experience checklist`** — friction-budget gate with 10 hard-fail conditions and 10 time-horizon checkpoints (10s → 1yr+).
- **CI matrix** (`.github/workflows/ci.yml`) — macOS-14 + ubuntu-22.04/24.04 × 10 bindings.
- **Release tooling** in `tools/` — bump-version, release-verify, smoke-eval, verify-* scripts.

### Changed
- **`columns` → `cols` rename** across the Table API surface.
- **`select` → `select_cols`** rename across bindings (avoids LINQ / Enumerable conflicts in .NET / Ruby; uniform for consistency).
- Migration docs restructured: per-version under [`docs/migrations/`](docs/migrations/) with an index README.
- Private docs (`CONTEXT.md`, `community/`) moved to [`docs/internal/`](docs/internal/); simplifies `.publishignore`.
- Internal grammar revisions during this cycle (v3.3 → v3.4 → v3.5 → v3.6) are now hidden from user-facing docs; users observe only the v0.5 → v0.6.0 transition.

### Fixed
- All five 2026-05 binding-audit findings (CB-1..CB-5) closed at V core and across all 9 FFI bindings; see the 2026-05 binding audit.
- Rust binding SIGABRT under Boehm GC threading — `cx_init` / `cx_thread_register` / `cx_thread_unregister` C ABI symbols added (cap bit 26).
- Parser quote+bracket fix — body-text tokenizer is now quote- and bracket-aware; closes the last two carried parser limits.

### Migration
- See [`docs/migrations/v0.5-to-v0.6.md`](docs/migrations/v0.5-to-v0.6.md) for the full upgrade guide.
- BREAKING: leading-zero integers are now strings (`02134` is a string, not int 2134).
- BREAKING: binding `loads()` / `dumps()` preserve integer/float distinction via CXDB v1 (was JSON-coerced in v0.5).

[Unreleased]: https://github.com/cx-home/cx/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/cx-home/cx/releases/tag/v0.6.0
