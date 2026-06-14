**Draft PR: Architecture E — Perceus front line + precise STW tracing backstop for the C backend** (opt-in `-gc e`)

A reuse-in-place RC front line (compiler-emitted drops, decoupled from `-autofree`) + a from-scratch precise stop-the-world `vgc` collector as the backstop. Aimed at alloc-heavy / multicore code where conservative Boehm anti-scales and over-retains.

Claimed — **please verify independently** (measured on our workloads only):
• near-linear multicore alloc scaling (~8× Boehm @ 8 threads); parallel alloc-heavy folds recovered from anti-scaling to ~3.8× their serial; ~3× lower RSS
• 12 concurrency/correctness fixes (3 TSan-confirmed) + a deterministic white-box self-check
• STW by default; concurrent mark opt-in (`-d vgc_concurrent`)

PR: <link>  ·  provider-neutral V-runtime/codegen work; feedback very welcome.
