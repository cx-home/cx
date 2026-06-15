# CX v0.10.1 — Release Notes

**Date:** 2026-06-15
**Tag:** `v0.10.1`

A version-hygiene patch. No language-surface, API, or runtime-behavior
changes — it fixes a version-reporting bug and makes version drift
structurally impossible going forward.

## Fixes

- **C-ABI `cx_version()` reported the wrong version.** In v0.10.0 the
  C-ABI version string was a hardcoded `'0.8.0'` while the CLI
  `cx --version` (derived from the build) said `0.10.0` — the same
  binary gave two answers. Both now derive from a single source, so
  `cx_version()` and `cx --version` agree (`0.10.1`).

## Internal — single source of truth for the version

- A repo-root **`VERSION`** file is now the one declared source of
  truth. Code surfaces (`cabi.v`, the CLI) **derive** the version from
  the build define; the static package manifests (`cx.pc.in`, `v.mod`,
  `Cargo.toml`, `pyproject.toml`) are **stamped** from `VERSION` by
  `scripts/bump_version.sh` and **verified** by a new
  `check-version-consistency` gate wired into the test suite — any
  future drift is now a failed build, not a silent mismatch three
  releases later.
- The cx and cx-v repositories derive their version from the same
  `VERSION` file.

## Compatibility

No language-surface changes. CX programs and Tier-1 bindings (V /
Python / Go / Rust) that ran under v0.10.0 run unchanged.
