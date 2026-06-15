Follow-up to the Perceus thread (#27166), and per @JalonSolov's suggestion to bring this to Alex as a PR.

For our project (CX, a language interpreter written in V), V's current memory management and multi-core scaling weren't going to get us where we needed to go — a big enough gap that we were seriously weighing a move to Rust. We put the effort into V instead. This PR is the proof-of-concept that closes that gap for us.

It adds a new opt-in memory-management model (`-gc e`) — a reuse-in-place front line backed by a precise tracing collector — plus a sizable set of concurrency/correctness fixes and allocator optimizations. In our testing it takes V's multi-core memory behavior from a blocker to a real strength, and it stays aligned with V's autofree / reuse-in-place direction.

We think V can reach — and beat — Go on memory management and concurrency. This is a step toward that, with no illusions about the maturity gap V still has to close.

These results are measured on a single machine and need independent verification — please don't take them as established. Full details, benchmarks, and reproduction steps are in the PR.

PR: https://github.com/vlang/v/pull/27458

One question up front: should this target v1, or be planned for v2? Feedback and teardowns welcome.
