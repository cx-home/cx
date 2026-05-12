# Migration guides

Each guide covers a single version-to-version transition. New guides
are added per release; old guides remain for users on older versions.

| From → To | Guide | Highlights |
| --------- | ----- | ---------- |
| v0.5.0 → v0.6.0 | [v0.5-to-v0.6.md](v0.5-to-v0.6.md) | Public Table API (ADR 0018); collection literals (ADR 0017); `cx table` CLI (ADR 0019); streaming-write API; schema validator (Tier 1); `select_cols` rename across bindings; CXL 1.0 evaluator; 10-binding parity; v3.4 grammar settled |

## How to use a migration guide

Each guide is structured as:

1. **BREAKING changes** — actions you must take.
2. **Non-breaking changes you may want to opt into** — new capabilities.
3. **Per-binding type-mapping deltas** — exact behavior changes.
4. **Quick checklist** — the punch list for an upgrade PR.

Each section is anchored so a guide can link to a specific change
without forcing you to read the whole document.

## Older versions

Pre-v0.5 was unreleased dev work. v0.5.0 (post-audit) was an internal
milestone; the first publicly tagged release is **v0.6.0**.
