Follow-up to the Perceus thread (#27166), and per @JalonSolov's suggestion to bring this to Alex as a PR.

For our project (CX, a language interpreter written in V), V's current memory management and multi-core scaling weren't going to get us where we needed to go — a big enough gap that we were seriously weighing a move to Rust. We chose to put the effort into V instead. This PR is the proof-of-concept that closes that gap.

It adds a new opt-in memory-management model (`-gc e`) — a reuse-in-place front line backed by a precise tracing collector — together with a sizable set of concurrency/correctness fixes and allocator optimizations. In our testing it makes V's multi-core memory behavior go from a blocker to something that works well for us, and it stays aligned with V's autofree / reuse-in-place direction.

The honest catch: it's all measured on one machine, so the results need independent verification — please don't take our numbers as established. Full details, benchmarks, and how to reproduce are in the PR.

PR: https://github.com/vlang/v/pull/27458

One question up front: should this target v1, or be planned for v2? Feedback and teardowns very welcome.
