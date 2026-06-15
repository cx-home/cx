Follow-up to the Perceus thread (#27166), and per @JalonSolov's suggestion to put it in front of Alex as a PR.

We built a proof-of-concept (with Claude) to see whether V could meet our memory-management and multi-core needs instead of switching to Rust — staying aligned with V's autofree / reuse-in-place direction. The results look very positive, but they're from one machine and need independent verification, so please don't take our numbers as established.

It's an opt-in GC mode (`-gc e`): a reuse-in-place front line backed by a precise stop-the-world tracing collector, plus the fixes and optimizations that made it sound and fast. Full details, benchmarks, and how to reproduce are in the PR.

PR: https://github.com/vlang/v/pull/27458

One question up front: should this target v1, or be planned for v2? Feedback and teardowns very welcome.
