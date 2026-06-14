# B19 — #36 per-call frame pooling: eliminating the closure call-frame
# `map[string]cx.Node` allocation in the cx interpreter

Goal (option (c), then 1a+2a): after B18 moved the V allocator out of the hot path,
profiling the shipped config showed the dominant remaining cost is the cx interpreter's
per-closure-call frame allocation (#36). This is a **CX-side** optimization (vcx/), not
a V-runtime change — the "no CX in any V repo" rule governs V mem-mgmt fixes (B18); the
interpreter's call-frame representation legitimately lives in the cx evaluator.

## TL;DR
- `invoke_closure_l` allocated a fresh `map[string]cx.Node{}` per closure call. On the
  #14 reduce that's ~32M maps (4M elements × 8 workers) — the top post-B18 cost.
- **Fix: a per-thread `FramePool` free-list of frame binding maps** (borrow on call
  entry, clear+return on exit). Reached via a `&FramePool` on the env, set FRESH per
  thread (new_env + each spawned worker) and propagated only within one thread's call
  chain — never shared across threads, so no lock.
- **Result (best-of-5, -prod -gc e, 12-core, all `80000200000 ×8`):** serial
  **1486→1024 ms (1.45×)**, par (default+PACE) **518→313 ms (1.65×)**. Combined with
  B18, par is ~4.7× the pre-session baseline; par is now 3.3× its own serial.

## Soundness — escape-safety is the crux, validated by a poison detector
Pooling a frame is unsound if any live alias of the frame's bindings outlives the call
(V maps are reference types — a missed alias = silent use-after-return, the residual-#4
failure mode). Audit: every retention path COPIES — `snapshot_bindings` (closures),
`.clone()` (error hooks, scheduler), async/worker snapshots — so no live alias exists.

To *prove* it rather than trust the audit, a `-d cx_frame_poison` build makes
`return_frame_map` CLEAR the frame and NOT pool it: any escaped live alias then reads an
empty frame → missing bindings → test failure. **Full gate under poison (via the make
harness, poison binary): 125/125 PASS** — including the iterator / scheduler / async /
process / xap integration features. No frame escapes. (A direct `v test tests/` shows 16
"failures" — a harness artifact: those integration tests exec `vcx/target/cx` by relative
path and only resolve under `make`; they fail identically *without* poison.)

## Full soundness gate (all GREEN)
- **Escape detector** (`-d cx_frame_poison`, make harness): V-impl **125/125**.
- **Reuse correctness** (`devbox run -- make test`, pooling active): V-impl 125/125,
  conformance core35/ext53/xml20/md22/ns16/include1 (0 failed), Rust/Go bindings 0
  failed, `MAKE_EXIT=0`.
- **Local [par] pool stress**: 40/40 across triggers, 0 corruption.
- **Container HTTP churn** (`wrk -t8 -c256 -d10s -H "Connection: close"` ×12): SURVIVED,
  niltrace=0.

## Implementation
- `code/matcher.v`: `FramePool{ free []map[string]cx.Node }` + `frame_pool &FramePool`
  on `MatchEnv` (default nil = no pooling, safe); `new_env` sets a fresh pool.
- `code/eval.v`: `borrow_frame_map` / `return_frame_map` (+ `frame_pool_cap=256`);
  `invoke_closure_l` borrows the frame map, tracks it as `borrowed` (separate from
  `call_env.bindings` so a body that reassigns bindings never pools a foreign map),
  returns it via `defer`, and propagates `frame_pool` to the call env.
- `code/par_eval.v` (both par workers) + `code/scheduler.v` (run_task_thread): set a
  FRESH `&FramePool{}` per spawned worker → thread-local, no cross-thread sharing.
- HTTP per-request envs deliberately leave `frame_pool` nil (no pooling, no cross-reactor
  race; HTTP is transport-bound so the per-request frame alloc is negligible).

## Why thread-locality holds
A pool pointer only propagates via `frame_pool: enclosing.frame_pool` inside
`invoke_closure_l` (one thread's call chain). Every `spawn` site builds a FRESH env
(par workers clone bindings/closures, async snapshots) and gets its own fresh pool, so a
pool pointer never crosses a thread boundary → the free-list needs no synchronization.

## Escape hatch
`-d cx_frame_poison` disables pooling (clear-on-return) and doubles as the escape
detector — re-run the gate under it after any change touching env capture/lifetime.

## Residual / next
Profile at this point is `invoke_closure_l` self + arithmetic + the per-step args array
(`[acc, item]`) — still allocated per reduce step. Next candidates: pool/reuse the args
array in the combinator loops (reduce/map/filter), and the broader #37 representation
(unboxed values / columnar data-in-flight) for the interpreter tree-walk itself.
