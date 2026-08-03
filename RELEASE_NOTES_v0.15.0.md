# CX v0.15.0 — Release Notes

**Date:** 2026-08-03
**Tag:** `v0.15.0`

The **toolchain** release. The vendored V compiler moves from its 0.5.1-era
base to **upstream V 0.5.2**, carrying the cx fork's memory-management
patch series forward — plus two sharp fixes that the upgrade's own
validation battery surfaced. Deliberately thin and shipped fast: a
compiler upgrade is a foundation change worth isolating from feature work.

**No breaking changes.** cx source needed **zero changes** for the new
compiler.

## Headlines

- **V 0.5.2 under the hood** — the fork's 79-patch series rebased onto the
  upstream tag as 76 commits. In-window upstream wins: cgen
  sumtype/generic correctness fixes (the CX element tree is
  sumtype-heavy), `-usecache` repairs, mbedtls TLS-handshake hardening,
  and array micro-optimizations.
- **A collector-soundness find upstream can't see**: two innocuous-looking
  upstream array changes — zeroing vacated delete slots, and letting
  empty arrays carry no buffer — each independently caused
  sweep-while-live use-after-frees under cx's conservative collector at
  high thread counts. Invisible under Boehm (upstream's only GC), caught
  by cx's masking-proof concurrency-soundness gate, and fixed as a
  fork-side **conservative-retention contract** that keeps all of
  upstream's performance work. The gate ladder (5 thread configurations
  on macOS, plus Linux-container parity) runs at zero catches and zero
  crashes.
- **Ingest regression found and erased** — v0.14.0's demand-paged store
  load had quietly routed first-touch object reads through a
  scan-the-world cold path, collapsing embedded journal-bound ingest
  2881 → 91 events/s. An object-location index plus an MRU pack reader
  restore **2861 events/s** — parity — with the lazy-load memory wins
  intact.
- **Authenticated event streams from CX** — `[$http:sse-connect]` now
  sends `opts.headers`, so a proof-bound SSE subscription (the identity
  model's required three-header handshake) finally works from a
  CX-native client.

## Toolchain notes

- The 0.5.2 builder's new C-error telemetry (auto-reports to the upstream
  tracker) is **opt-in** in the cx fork (`V_C_ERROR_BUG_REPORT=1`) — a
  fork must not phone home.
- The vc bootstrap pin is regenerated for the new base and verified by a
  fresh-clone `make`; the concurrency-soundness gates are parameterized
  (`VFORK_ROOT`/`VFORK_SRC`/`VFORK_V`) so a candidate compiler tree is
  arbitrated *before* the submodule pin moves.
- Upstream's closure-lifetime reclamation is enabled — it was the
  upgrade's top predicted risk and was exonerated by the gate once the
  real regressions were isolated.

## Install

Download the release artifact for your platform and extract, or build
from source with `make build`. The hosted one-liner remains blocked on
GitHub Pages certificate issuance (#508).

## Migration

None. v0.15.0 is additive over v0.14.0; the compiler upgrade is invisible
at the CX surface.

## What's next

The **CX partition** (#516) — targeted, per-use-case consumables along
capability rings — is now slated as v0.16.0's headline, design-gated
behind its spec and the architecture review (#37).
