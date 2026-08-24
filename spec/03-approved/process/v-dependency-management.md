# CX ⇄ V Dependency Management

**Status:** Current.

This document specifies how CX depends on, patches, tracks, and ultimately
sheds the V compiler/runtime it is built on. It is a **process/governance**
specification, not a CX language specification: it constrains the *toolchain
relationship*, not CX semantics. The operational quick-reference (pin convention,
recovery commands) lives in [`third_party/README.md`](../../../third_party/README.md);
this document is the authoritative *policy and rationale*.

---

## 1 — The layering

- **V** is the language, compiler, runtime, and memory model. CX builds against a
  **fork** (`github.com/cx-home/v`, branch `cx-home/v-cx-patches`), vendored as the
  `third_party/v` submodule. The fork is *temporary*: it carries only patches that
  are bound for upstream `vlang/v` (see §6).
- **CX** is the interpreter for the CX language, written *in* V (`vcx/`). It
  **consumes** V; it does not implement a compiler or memory model. CX owns its own
  transport (`vcx/transport/`), concurrency surface, and everything CX-specific.

## 2 — The one rule (no CX in V)

> **No CX-specific code may live in any V repository — the fork or the upstream
> clone — ever. A patch belongs in the fork only if it would make sense to the
> upstream `vlang/v` project with no mention of CX.**

This is the governing constraint. It is what lets the fork eventually be replaced
by stock upstream V (§6). It was historically violated (a scope-region allocator
and picoev SSE/shared-listener patches lived in the fork); the eviction
(`evict_cx_from_v_PLAN.md`) removed them and is the reason this policy now holds.

### 2.1 The routing test

| You need to… | It goes in… |
|---|---|
| Fix a V compiler/runtime bug CX surfaced | **V** — with a **CX-free** repro and test; develop in the upstream clone, forward-port to the fork. |
| Add/modify CX transport, HTTP, SSE, event-loop | **`vcx/`** (e.g. `vcx/transport/`). Never the fork. |
| Add/modify CX language, eval, concurrency | **`vcx/`**. Uses V's primitives; does not modify them. |

If a V change exists *only* to make CX build or run (a CX-shaped shim), it is a
CX-integration concern and belongs in `vcx/`, not in V.

## 3 — What the fork may carry ("Bucket-1")

The fork's patch series is restricted to **CX-agnostic** runtime/toolchain work
that is actively bound for upstream:

- the vgc / `-gc e` / Perceus memory-management line (the bulk of the series),
- platform/build fixes that are general V concerns (e.g. the macOS hardened-runtime
  `libgc` `-prod` bypass, the wasm32-emcc `vmemcpy` guard),
- general capabilities CX happens to be the first user of (e.g. `net.mbedtls`
  DTLS, the `@[thread_local] __global` cgen feature).

Anything failing the §2.1 test is **forbidden** in the fork.

## 4 — Pinning V

CX records exactly which V it builds against; this is the single source of truth.

- **Submodule gitlink** — the `third_party/v` commit recorded in the superproject
  is the authoritative pin. Bumping it is a normal, reviewed commit on `main`.
- **`cx-patched-v` tag** — an annotated tag that GC-anchors the pinned commit so it
  survives branch force-pushes/rebases (preventing the "fresh clone can't find the
  SHA" failure). It SHOULD track the live pin.
- **Build resolution** — CX's build calls `third_party/v/v` directly; a fresh clone
  obtains it via `git submodule update --init --recursive`.

Mechanics, the canonical branch/tag names, and the remote-dropped-SHA recovery
procedure are in [`third_party/README.md`](../../../third_party/README.md).

## 5 — Keeping current with upstream V

The fork = upstream V (a base) + the Bucket-1 patch series on top. Staying current
means periodically replaying the series onto a newer upstream — **never** an
automatic update.

> **`v up` is disabled on the fork** (`cmd/tools/vup.v` guard): it refuses to
> rebase onto upstream by default, so the patch series can never be silently
> clobbered. Updates are always the deliberate workflow below.

### 5.1 The upgrade workflow

1. Fetch the target upstream revision (the `upstream` remote → `vlang/v`; the
   `vlatest` clone is the workbench for developing/validating patches first).
2. Re-base the Bucket-1 series onto that revision; resolve conflicts.
3. **Rebuild CX and run the full gate** (`make test-vcx`). The gate is the safety
   check — a patch that collides with an upstream change fails here, pinpointed.
4. Move the fork branch, push it, then bump the gitlink pin and the `cx-patched-v`
   tag (§4).

### 5.2 Cadence

Sync on a *trigger*, not a clock: upstream ships a fix/feature CX wants; a CX
release is approaching; or one of our patches lands upstream (re-base onto the V
that now contains it, dropping it from the series). The CX-free, upstream-shaped
patch series is what keeps these re-bases low-conflict — preserving that shape
(§2) is itself part of staying current.

## 6 — Lifecycle: the fork is meant to disappear

The endgame is **not** perpetual fork maintenance. Each Bucket-1 patch is submitted
upstream (the memory-management line is tracked by
[`docs/internal/vlang-perceus-rfc-draft.md`](../../../docs/internal/vlang-perceus-rfc-draft.md)). Every patch
upstream accepts drops out of the series. When the series reaches zero, CX pins
**stock upstream V**, the fork is retired, and §5 maintenance ends entirely. Until
then, minimizing the series (upstreaming aggressively, never adding CX-specific
patches) is the strategy that both reduces re-base cost and brings that day closer.

## 7 — Companion documents

- [`third_party/README.md`](../../../third_party/README.md) — operational pin convention + recovery.
- [`v_runtime_memory_management.md`](../../03-approved/process/v_runtime_memory_management.md) — the Bucket-1 mem-mgmt spec.
- [`docs/internal/vlang-perceus-rfc-draft.md`](../../../docs/internal/vlang-perceus-rfc-draft.md) — the upstreaming RFC to the V core team.
- [`evict_cx_from_v_PLAN.md`](../../_archived/evict_cx_from_v_PLAN.md) — the one-time eviction that established §2.
- [`vcx/Makefile`](../../../vcx/Makefile) — the guard that warns loudly when the patched V is absent and `-prod` is silently dropped (the worktree build trap; see §4/§5).
