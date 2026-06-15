Follow-up to the Perceus thread (#27166) and my earlier note — and per @JalonSolov's suggestion to put it in front of Alex as a PR.

We set out to validate whether V could meet our memory-management + multi-core needs *instead of* reaching for Rust, staying aligned with V's autofree / reuse-in-place direction. It went well enough to share. **Built as a POC with Claude (Anthropic's coding agent); the results look very positive but they need independent verification — please don't take our numbers as established.**

PR: https://github.com/vlang/v/pull/27458

What it adds (opt-in, `-gc e`): a Perceus-style reuse-in-place front line + a precise stop-the-world tracing collector as the backstop, for the C backend. Plus the concurrency/correctness fixes and allocator optimizations that made it sound and fast under heavy multi-threaded allocation.

Claims to verify (measured on one machine — Apple M2 Max + an arm64 Linux container; x86 / native Linux untested):
• near-linear multicore alloc scaling (scalar-alloc ~45→326 Mops/s, 1→8 threads; ~5.5× Boehm at 8T)
• a real alloc-heavy parallel workload recovered from anti-scaling to ~3.8× its serial; ~3× lower RSS
• 15 concurrency/correctness fixes — 3 TSan-confirmed, plus a deterministic white-box self-check and a concurrent-HTTP churn reproducer (all included)
• STW by default; concurrent mark is opt-in

One question up front: **should this target v1 (where it's built + tested) or be planned for v2?** If v2 reworks the backend we're glad to advise on a port. Feedback / teardowns very welcome — the verification is the point.
