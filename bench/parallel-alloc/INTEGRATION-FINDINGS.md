# Scope-aware region → cx-eval integration — implementation findings

Status: **implemented + corruption-validated; correctness gate now GREEN for all
programs; scaling demonstrated for the intended (bounded) work-unit shape.**
Behind `-d cx_regions`; the default build is unaffected and fully green.

Update (post-decision): Gate 2 resolved by gating the region OFF for
channel-using worker bodies (run_worker_body → body_uses_channels); full eval
fixtures now pass under `-d cx_regions`. Gate 3 reframed: a bounded-footprint
worker body DOES scale (see below); the bulk-body overflow case does not — that
is a workload-shape property, not a defect. Next step: take the win to the HTTP
request-handler path (parse once, reset per request), which also removes the
per-eval parse that caps the bounded-worker bench at ~4 threads.

## What shipped (this pass)

1. **Fork runtime** (`third_party/v/vlib/builtin/cx_region.c.v`)
   - `cx_region_suspend()/resume()` — toggle region routing off for the
     deep-copy (so the copy lands on GC), restore after.
   - `cx_region_stats()`, `cx_region_owns_ptr()` — diagnostics.
   - `CX_REGION_BLOCK` env override of the per-thread block size (the battery
     sets it tiny to force overflow-fallback + reset churn).
   - **Critical compiler fix** (`vlib/v/gen/c/consts_and_globals.v`): this V
     fork's codegen **ignored the `@[thread_local]` attribute** on `__global`,
     so the region state was process-global and shared across threads — any
     concurrent region use corrupted instantly. Now emits `__thread`. This bug
     is independent of the region feature and was latent in the fork.

2. **Deep-copy** (`vcx/code/region_export.v`) — total recursive copy of a
   `cx.Node` onto the GC heap, all 26 Node variants. Strings are noscan→already
   -GC so shared; only scanned structure (node boxes, arrays, `&ElementMeta`,
   `&TableData`, `&IteratorNode`) is rebuilt. Self-guards on
   `cx_region_is_active()` → no-op in the default build. (Limitation:
   MatchNode/ModifyNode + closures-as-results are shallow — documented in-file,
   out of scope for the initial rollout.)

3. **`[?worker]` wiring** (`vcx/code/eval.v`)
   - `run_worker_body`: `cx_region_enter` → body on a **cloned env** (binding
     writes stay thread-confined, §5.4) → `region_export(result)` →
     `cx_region_exit` (deferred). Errors captured as GC strings before reset.
   - `queue_append`: copy-on-send — value deep-copied to GC AND the append runs
     with the region suspended so the channel queue's own `[]cx.Node` backing
     buffer cannot be region-allocated (§5.2/§5.3).
   - All inert in the default build.

4. **Benches** (`vcx/tests/runners/`): `region_corruption_bench.v` (the battery),
   `parallel_worker_scaling_bench.v`, `region_stats_probe.v`.

## Gate 1 — corruption battery: PASS (for pure-compute workers)

`region_corruption_bench.v`: N threads each eval a `[?worker]` returning a heavy
300-row nested tree, M times, with a concurrent `GC_gcollect()` hammer; every
output byte-diffed against a serial reference.

- 8T & 16T + hammer + default block: **0 mismatches**.
- 8T + hammer + `CX_REGION_BLOCK=4096`/`65536` (constant overflow-fallback +
  reset churn): **0 mismatches**.
- Region output byte-identical to the default build.

The `__thread` fix was found here: before it, every multi-thread config
segfaulted; after it, all green. Escape-safety holds for Element/scalar/
collection results.

## Gate 2 — RESOLVED (channel bodies skip the region)

`run_worker_body` now calls `body_uses_channels(body)`: a `[?worker]` body
containing a value-moving channel directive (`send`/`try-send`/`receive`/
`try-receive`/`select`) runs WITHOUT the region (any enclosing scope suspended,
shared env, no export) — exactly the default-build behaviour, which is correct.
The outer scope's `region_export` still rescues the worker's result. Full eval
fixtures (incl. `program-conc-019`) pass under `-d cx_regions`; corruption
battery stays green (channel-free workers still region). The underlying for-comp/
region aliasing bug remains open (documented below) but can no longer produce a
wrong answer. NOTE: other effectful directives in a worker body (services, state
machines, futures, registry writes) are not validated under regions — keep
region-eligible bodies to pure compute until audited.

### Open root cause (deferred, no longer reachable in practice)

Conformance fixture `program-conc-019-producer-consumer-pattern` fails **only**
under `-d cx_regions` (default build: 746/746 green). A `[?worker]` consumer
that does `[?receive]` **inside a `[?for]` comprehension** returns the
comprehension's **loop variable** instead of the dequeued value.

Isolation:
- `[?worker]` + for-comp **without channels** → byte-identical (works).
- channel send/receive across two workers **without** a for-comp → works.
- producer-worker send + **outer** (non-region) receive → works.
- producer-worker for-comp send + **consumer-worker for-comp** receive → the
  consumer reads its own loop values (e.g. producer sends 10,20,30,40; consumer
  loops 1,2,3,4 and yields `[?receive]` → result is 1,2,3,4, not 10,20,30,40).

Verified NOT the cause: the queue buffer is GC-owned (`buf_region_owned=false`),
holds the correct values at send time, and `region_export` allocates 0 region
objects (suspend works). Disabling the env-clone and disabling `region_export`
both leave the bug. The corruption is in the **consumer for-comprehension's
handling of the received value under an active region scope** — the dequeued GC
value is overwritten by / aliased to the loop binding. Root cause is in the
for-comp evaluation path's interaction with region memory, not in the documented
escape channels (result/send), which are closed. Needs deeper investigation in
the for-comp buffered-evaluation machinery.

The battery did not catch this because it has no second region scope reusing the
block *after* an export within one eval, and no channels.

## Gate 3 — scaling DEMONSTRATED for bounded units; bulk bodies don't fit

### Bounded worker body (the intended shape) — SCALES

`parallel_bounded_worker_bench.v` — small body (`range→map→sum`, default 2000)
that fits the block, tiny program (cheap parse), single-int result (cheap
render), so the regioned body compute dominates. `-prod`, 16 MiB block:

| threads | baseline evals/s (per-thr) | regions evals/s (per-thr) |
|--:|--:|--:|
| 1 | 371 (371) | 803 (803) |
| 2 | 270 (135) | 1140 (570) |
| 4 | 193 (48)  | 1203 (301) |
| 8 | 202 (25)  | 939 (117) |

Baseline anti-scales (aggregate 371→193, per-thread collapses 15×). Regions
**scale positively 1→4 threads** (803→1203 aggregate) and beat baseline 2–6×
throughout — the in-process parallelism win, for the shape the model targets.
range=1000 behaves the same (1235→1608 1→4T).

The 8-thread plateau is **residual GC traffic, not block overflow**: a 64 MiB
block does not help 8T (slightly hurts — 8× larger root blocks cost more to
scan per GC). The cap is the per-eval allocation that is NOT regioned — program
parse, result render, result export — which still hits the global lock + GC
stop-the-world. This is precisely what the request-handler model removes (parse
the handler once; only per-request transient work is regioned + reset), so the
fuller win lives there.

### Bulk worker body (wrong shape) — does NOT scale

`parallel_worker_scaling_bench.v` — hot `range→map→sum` over 40 000 elements
inside a `[?worker]`, 1→8 threads, `-prod`:

| threads | baseline evals/s | regions evals/s |
|--:|--:|--:|
| 1 | 21 | 22 |
| 2 | 12 | 14 |
| 4 | 8  | 9  |
| 8 | 7  | 8  |

Regions barely beat baseline; both **degrade**. With GC suppressed
(`GC_INITIAL_HEAP_SIZE=6G`) both still collapse to ~13 at 8T. `region_stats_probe`
explains it: the worker body issues ~520 000 scanned allocations and a low-live
-set, high-churn footprint that **overflows even a 64 MiB block** (hits 294 k /
fallbacks 226 k) — once the block fills, every allocation falls back to
`GC_MALLOC` under the global lock, so it scales exactly like baseline.

**Architectural finding:** the region scales work units whose *total* transient
allocation fits the block and resets between units — the request-handler shape
(parse once, many small bounded units, reset per request). It does **not** help
a single high-churn bulk-compute body: such a body has low live-set but huge
total allocation, and the region cannot reclaim mid-scope (no GC inside a scope),
so it overflows. A bulk loop needs GC reclamation (back to the lock) or a
different strategy. The microbench scaled (≈80× at 8T) precisely because it
retained nothing and reset every 1000 small nodes.

## Status after the decisions (1a, 2b→2a, 3a)

- **Gate 1 (corruption):** green.
- **Gate 2 (correctness):** green — channel-using worker bodies skip the region
  (`body_uses_channels`); full fixtures pass under `-d cx_regions`. The for-comp/
  region aliasing root cause is deferred but unreachable in practice.
- **Gate 3 (scaling):** demonstrated for the intended bounded shape (positive
  1→4T scaling, 2–6× baseline); bulk bodies remain the wrong shape (documented).

## HTTP request-handler wiring (2a) — wired + correct, but NO throughput win

`invoke_handler` (services_listener) now wraps the handler eval in
`cx_region_enter` → eval body → `cx_response_to_wire` → `cx_region_exit`. The
wire serialization fully materializes the response into a `WireResp` of plain
ints/strings/maps, so NO region value outlives the reset — the cleanest possible
work unit (no `region_export` needed). Channel-using handlers skip the region
(`body_uses_channels`), same as workers. Inert in the default build.

Validation (live picoev server, both builds):
- **Correct:** byte-identical responses; 200 concurrent requests across reactor
  threads with zero corruption; heavy 16 KB / 400-row responses byte-identical.
- **No throughput win:** `wrk -t8 -c128`
  - trivial handler: default 25 816 vs regions 25 852 req/s (≈equal).
  - heavy handler:   default 71 vs regions 70 req/s (≈equal).

**Why:** HTTP serving is NOT eval-allocation-bound. A trivial handler is
transport-bound (the project's prior isolation finding: transport ~145 µs/req
vs interpreter ~10 µs/req — `project_http_backend_isolation_finding`). A heavy
handler is bottlenecked on response *rendering* (which allocates GC strings, not
region-scanned nodes) plus GC stop-the-world across reactor threads — neither of
which the region touches. The region optimizes eval-time scanned-node allocation,
which is a small fraction of HTTP request cost.

**Conclusion.** The scope-aware region delivers in-process scaling for bounded
*compute* work units (Gate 3 bounded-worker bench: 2–6× over baseline, positive
1→4T), but NOT for HTTP serving (transport/render-bound) and NOT for high-churn
bulk loops (block overflow). The multi-process story (path C) remains the HTTP
parallelism answer. The handler wiring is kept (correct, inert, gated) and may
matter if/when transport + rendering are optimized, but provides no measured win
today.

### Original next-step note (superseded by the measurement above)

The bounded-worker bench caps at ~4 threads on per-eval parse/render that is not
regioned. The request-handler model removes that ceiling: parse the handler/route
once, then for each request `cx_region_enter` → run handler → serialize response
→ `region_export` anything that outlives the request (or rely on the wire write)
→ `cx_region_exit` (reset). Per-request transient work is the dominant allocator
and is fully regioned + reset, with no per-request parse. This is the §1 item 3
work unit. To wire after the `[?worker]` checkpoint lands.
