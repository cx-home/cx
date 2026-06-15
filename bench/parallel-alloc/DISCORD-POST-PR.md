New V Lang Memory Management and Multicore (-gc e) POC

It's promising, with two key metrics (needs verifying):

```
Before                                →  with -gc e
---------------------------------------------------
single-thread baseline (no scaling)   →  3.5×
nearly flat across multiple cores     →  7× across 8 cores
```

Plus 15 concurrency/correctness bugs found and fixed.

For our project, V's current memory management and multi-core scaling were a big enough gap that we were seriously weighing a move from V. But we see V having big potential and put the effort into a POC — a new opt-in memory-management model (`-gc e`): a reuse-in-place front line backed by a precise tracing collector, plus a sizable set of concurrency/correctness fixes and allocator optimizations. In our limited testing it takes V's multi-core memory behavior from a blocker to a real strength, and it stays aligned with V's autofree / reuse-in-place direction.

We think V can reach — and beat — Go on memory management and concurrency, as well as in many other areas. This is a step toward that, with no illusions about the maturity gap V still has to close.

These results are measured on a single machine and need independent verification — please don't take them as established. Full details, benchmarks, and reproduction steps are in the PR.

PR: https://github.com/vlang/v/pull/27458
