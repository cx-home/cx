# CX v0.10.0 — Release Notes

**Date:** 2026-06-14
**Tag:** `v0.10.0`

The `-gc e` hardening + performance release. v0.9.0 introduced the
Perceus + precise-backstop memory model; v0.10.0 makes it solid under
concurrency (a sweep of vgc / multiprocessing use-after-free fixes) and
puts the new front line to work — large `[?reduce]` over a range now
streams instead of materialising. No language-surface changes.

## Headline

- **Streaming reduce-over-range.** `[?reduce]` over a bounded integer
  `[$range lo hi step?]` now folds by generating each element inline
  (generate → fold → drop), keeping the live set O(1) instead of
  materialising the whole range — both the serial and the `:par` paths.
  A 4-million-element reduce drops from **~4.3 GB → ~561 MB peak RSS
  (7.6× less)** and **13.3 s → 8.1 s** serial; parallel scaling is
  restored from ~1.5× to **~3.9×** at 4M, and a direct parallel
  range-reduce no longer materialises (the domain is chunked and each
  worker streams its sub-range). Feeds the Perceus front line: the
  transient per-step values are reclaimed at last use.
- **Per-call frame pooling** — closure calls borrow their binding-frame
  map from a per-thread pool instead of allocating one per call (B19,
  #36), and the reduce fold reuses a single args buffer. Tight
  arithmetic folds stop churning short-lived maps.
- **vgc / multiprocessing hardening.** A sequence of `-gc e` collector
  fixes lands the concurrent path: vgc self-root captured at the real
  stack pointer, `gc_cycle` accounting under STW, narenas
  release/acquire ordering, three MP concurrency fixes, two allocator
  NULL-return fixes, the B18 alloc-lock fixes, option-pointer and
  `[]?T` option-element free, and a lock-free free path with atomic
  `live_threads`.
- **`cx --version` overhaul** — now reports the commit, build time,
  active GC model, and the pinned V-fork hash alongside the version,
  e.g. `cx v0.10.0 / gc e — Perceus RC front line + precise STW vgc
  backstop / V fork c69fd59b2f`.
- **Upstream contribution** — the V-runtime memory-management work is
  proposed upstream as [vlang/v#27458](https://github.com/vlang/v/pull/27458),
  framed as closing a real V memory-management / multiprocessing gap.

## Compatibility

No language-surface changes — no parser, spec, or grammar changes;
verified that the diff from v0.9.0 touches only the V-runtime fork,
`vcx/code`, `vcx/cmd`, the build, and benches. CX programs that ran
under v0.9.0 run unchanged. Tier-1 bindings (V / Python / Go / Rust)
are unaffected; their version strings move to 0.10.0.
