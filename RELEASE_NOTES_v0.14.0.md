# CX v0.14.0 — Release Notes

**Date:** 2026-08-02
**Tag:** `v0.14.0`

The **eventing + endurance** release. v0.13.0 made CX consumable; v0.14.0
makes a CX deployment survive its own success.

Two arcs dominate. **cx fabric** graduates from a design note to a served
platform tier: durable and transient event planes over XSP, with consumer
groups, failover, dead-letter policy, request–reply, backpressure, and a
NATS bridge — where a durable stream *is* a journal stream, so ordering and
verification come from the journal contract rather than a second
implementation. And the **journal and store grow a lifecycle**: rotation,
tiered retention with cold archive and chain anchors, and demand-paged
loading — so a long-lived deployment's cost tracks its *working set*
instead of its lifetime volume.

Between them sits a sustained performance campaign that moved remote
journal-bound ingest from **~16 events/s to ~660**, and a fail-loud sweep
that closed a family of silent-wrong-answer defects in the evaluator.

**No breaking changes.**

## Headlines

- **cx fabric, served** — `cx fabric-serve` with durable + transient
  planes, consumer groups with sticky-exclusive assignment and liveness
  failover, DLQ + redelivery policy, request–reply, XSP §5 heartbeat /
  credit flow control / reconnect-resume, and a NATS subject bridge.
- **The journal has a lifecycle** — `[rotate keep-n=N]` seals every stream
  at its own boundary and moves the hot window to a fresh store; a
  **segment index** keeps sealed history walkable from the newest store
  alone. `[retention …]` policy sweeps it automatically with per-stream
  hot windows, cold archive, **chain anchors retained whether a segment is
  archived or dropped**, and a legal hold that suspends both.
- **The store pages on demand** — opening an object-graph store populates
  only the refs layer; objects resolve on first touch through a
  self-verifying getter, so corruption still refuses *loudly at first
  touch* while resident memory tracks the working set. The whole-graph
  check becomes the explicit `[$store:verify]`.
- **~40× remote ingest** — ~16 → ~660 events/s through pipelined appends,
  render caching, fold checkpoints, and finally moving the delivery pump's
  read+render off the sequencer lock (663/s measured at K=2000).
- **Per-principal read surfaces** — `readout($store, $t, $actor)` receives
  the request's resolved principal, so a confidentiality boundary folds
  server-side instead of shipping a full read-model to every client.
- **Self-hosting all the way down** — a fabric mount can ride a served
  `cx-store://` store, with alias remoting (explicit presence, optional
  CAS) closing the last gap.

## Language & stdlib

- **`[?loop]` with `[break]`/`[continue]`, and `[?do]`** — the
  condition-driven loop and evaluate-for-effect sequencing, with
  all-explicit exits: a branch that forgets its exit word is a diagnostic,
  never a silent wrong answer.
- **`%` as modulo**, joining `+ - * /`.
- **Per-thread PRNG streams** and instantiable generators (`[$random:new]`)
  — `[?worker]` threads no longer race a process-global RNG.
- **`CX-L007`** flags aggregation over a simple field accessor, catching
  the count-composition trap mechanically.

## Fail-loud hardening

A deliberate sweep against silent wrong answers, each closed at the root:

- `$first` returned the whole collection for `$filter` results; err values
  vanished in unobserved `[?let]` bindings; absence in call position
  misdiagnosed as `no callable`; `[?for] [where]` calls never matched;
  `[?element]` as a call argument arrived as absence; `[?async]` never ran
  without `[?await]` despite the spec requiring eager spawn.
- `$cx:emit` emitted unescaped quotes that broke re-parse; CXPath over an
  `[err …]` yielded zero matches, turning parse failures into empty
  results; a parsed MapNode was unnavigable.
- **Module-imported code now evaluates identically to program-context
  code** — derived evaluation frames dropped their lexical position, so
  closures created inside imported defs resolved against the *importing*
  scope. One root cause behind three distinct reported symptoms.

## Durability

- **Crash consistency**: the journal store corrupted on unclean shutdown
  and then SIGBUS'd on reopen. Two-pass replay with a structural
  torn-tail discard; **0/40 corrupt** across a kill-at-any-point harness.
- Two writable in-process opens of one store root shared segment
  numbering; they now share the live handle or refuse loudly.

## Toolchain & packaging

- The public mirror builds from a clean clone again (V bootstrap and fork
  makefiles no longer float on remote HEADs).
- The darwin artifact is **self-contained** — RE2 vendored and statically
  linked, dropping the Homebrew/abseil dylib chain.
- WSL2 source builds work via the recursive-clone path.
- Bindings: the retired `:table[` opener purged from Go/Rust/Python; Rust
  `arrow`/`parquet` features compile; previously-unwired Python tests now
  run in the gate.

## Install

Download the release artifact for your platform and extract, or build from
source with `make build`. The hosted `https://cxhome.org/install` one-liner
remains blocked on GitHub Pages certificate issuance (#508) and is **not**
advertised for this release.

## Migration

None required — v0.14.0 is additive over v0.13.0. Two optional surfaces are
worth adopting deliberately:

- **Retention is opt-in.** Without a `[retention …]` block a fabric mount
  keeps its full history exactly as before. Sizing guidance for the `hot=`
  window is in `bench/xap/SIZING.md` §1.
- **Store loading is now demand-paged by default.** Per-object integrity is
  unchanged (every paged read self-verifies), but the exhaustive
  whole-graph reconstruction that used to run at every open is now the
  explicit `[$store:verify]`. Pass `[opts eager="true"]` to restore the
  inline check.

## What's next

The **CX partition** (#516) — breaking CX into targeted, per-use-case
consumables along capability rings — is the next release's headline,
deliberately design-gated behind its spec and the architecture review.
