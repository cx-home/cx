# CX v0.9.0 — Release Notes

**Date:** 2026-06-13
**Tag:** `v0.9.0`

The memory-model release. CX adopts a new default memory management
architecture — **`-gc e`**: a Perceus-style reference-counting front
line backed by a precise stop-the-world mark-region collector — built
in CX's V-runtime fork. The language surface is unchanged; this release
is about how CX programs *run*, especially under multiprocessing, plus
a round of editor-tooling maturation (LSP, tree-sitter, `cx fmt`).

## Headline

- **`-gc e` is CX's default memory model.** A Perceus reference-counting
  front line frees most values deterministically at last use (reuse-in-
  place where the compiler proves uniqueness), with a minimal precise
  STW mark-region collector as the cycle/escape backstop. Boehm remains
  selectable (`-gc boehm`) for A/B comparison.
- **Near-linear multicore scaling.** Per-thread heap accounting lands
  the `-gc e` scaling target: ~8× Boehm at 8 threads, near-linear on the
  parallel-allocation workloads — Boehm's single global allocator lock
  was the prior ceiling.
- **Perceus front line, compiler-resident.** Backward liveness / last-
  use analysis over V's real CFG, a conservative uniqueness classifier
  (escape / capture / spawn aware), interprocedural escape inference,
  and sound drop/reuse emission — including deep-free of nested heap
  fields and sound `&Foo` user-reference drops.
- **Copy-on-write closures table per call** — cuts the dominant
  per-call GC pressure on closure-heavy workloads by ~7×; the call
  environment is no longer rebuilt per invocation.
- **Editor tooling matures** — one unified parser drives LSP
  diagnostics (a `.cx` valid under *either* the data or program reading
  is accepted); `cx fmt` is lossless and idempotent; tree-sitter owns
  buffer highlighting (the LSP semantic tokenizer no longer masks the
  base grammar); the `$` sigil is a first-class semantic token.

## Fixes

- Multiple `-gc e` / vgc correctness fixes uncovered while making it the
  default: STW root-scan capturing register + stack roots, `vgc_init`
  ordering after `_vinit`, tiny-allocator free no longer clobbering live
  siblings, a Perceus drop that retired a store-target index before its
  use (map corruption), overflow-thread allocator panic, and a macro-
  arity codegen bug.
- LSP/tree-sitter/`cx fmt`: semantic-tokenizer rewrite (stops masking
  the grammar, #32), two tree-sitter grammar gaps that caused nvim
  highlighting dead spots, neovim ftplugin starts tree-sitter for `.cx`
  buffers.

## Compatibility

No language-surface changes — no parser, spec, or grammar changes. CX
programs that ran under v0.8.0 run unchanged; `-gc e` only alters
runtime memory behavior. Tier-1 bindings (V / Python / Go / Rust) are
unaffected.
