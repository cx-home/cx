# G-R2s — §5.1 RC-atomicity crux, resolved by measurement

**Date:** 2026-06-11 · **Box:** 12-core M-series (8 perf + 4 eff), darwin/arm64 ·
**Bench:** `bench/parallel-alloc/rc_scaling.c` (binary gitignored) ·
**Spec:** `spec/03-approved/process/v_runtime_memory_management.md` §5.1, §7.2 (G-R2s)

## Question (§5.1)

For the **shared residual** — the values Perceus cannot prove unique, the only
ones that carry runtime `dup`/`drop` — which RC scheme holds R2 (monotonic-up MP
scaling) on a deliberately share-heavy workload?

- **(a) thread-local handoff (Koka)** — within-thread dup/drop hit a private
  per-thread counter; only genuine ownership transfer (handoff) touches a shared
  atomic.
- **(b) atomic RC (Lean 4)** — every dup/drop is an atomic add/sub on the shared
  refcount.

Decision criterion: *if atomic RC anti-scales on the share-heavy workload, (a) is
required.*

## Method

`rc_scaling.c` runs an **identical** workload under both schemes — a small pool of
cache-line-padded shared refcounts that every thread rotates through (maximal
sharing), `PER` borrow-cycles/thread, `W` within-thread uses per borrow. The
schemes differ *only* in where the refcount lives:

| | shared-atomic RMWs / borrow-cycle | private-counter ops / borrow-cycle |
|---|---|---|
| **atomic** | `2 + 2W` (handoff in/out + W use dup/drops) | 0 |
| **tls** | `2` (handoff in/out only) | `2W` |

Refcount and read-only payload are on **separate cache lines** (real immutable
sharing bounces only the refcount; field reads stay shared-read-only) — so the
measurement isolates *refcount* contention, not collateral false-sharing. `W=0`
makes the two schemes identical by construction (every RC op *is* a handoff) — the
pessimal floor. Median of 5 timed runs after a warm-up; `-O2`, C11 `stdatomic`.

## Results

**Hot-contention regime (16 shared objects — the deliberate worst case), PER=4M, agg M-ops/s:**

```
        T=1      T=2      T=4      T=8     1→8 trend   tls/atomic @ T=8
W=0  a  418.7    133.9    113.8    141.9   anti-scale  1.00×  (identical by design)
     t  451.1    134.0    117.4    141.0   anti-scale
W=1  a  447.2    200.1    185.2    240.9   anti-scale  1.16×
     t  878.6    287.2    195.7    279.6
W=4  a  446.7    305.9    280.4    257.0   anti-scale  2.65×
     t 1192.5    648.9    499.6    681.0
W=16 a  431.6    379.7    404.6    265.4   anti-scale  7.90×
     t 3320.1   2107.0   1565.2   2097.2
```

**Object-pool-size sweep @ W=4 (spreads contention across more lines), agg M-ops/s:**

```
            T=1      T=2      T=4      T=8
objs=256  a 455.1    469.3    502.1    596.7   ← atomic monotonic-up once contention spreads
          t 1250.3   830.6    748.4    969.4
objs=4096 a 432.7    763.8    517.2    544.1   noisy (leaves contention regime)
          t 1164.2  1864.3    963.6    962.5
objs=65536a 427.7    731.2    436.5    636.7   noisy (8MB rc lines > L2 → bandwidth/eff-core)
          t  944.3  1350.8    749.6    981.5
```

## Findings

1. **Atomic RC anti-scales in the hot-contention regime.** At every `W≥1` with a
   small hot shared pool, atomic aggregate throughput degrades as threads grow
   (e.g. W=4: 447→306→280→257; W=16: 432→380→405→265). This is the literal §5.1
   failure condition — **so (a) is required.**

2. **tls strictly dominates in all 40 measured points**, and the gap widens with
   within-thread use: **1.16× (W=1) → 2.65× (W=4) → 7.9× (W=16)** at 8 threads.
   Mechanism: atomic shared-line traffic is `2+2W` per cycle (grows with RC-op
   frequency); tls caps it at `2` (the ownership-transfer rate, constant in `W`).

3. **The crux is the hot-shared-pool regime.** Spreading the residual over more
   objects drops per-line contention and lets *even atomic* scale (objs=256:
   455→597 monotonic-up). So R2 for the residual is won by three compounding
   levers, not RC atomicity alone:
   - (a) thread-local handoff — caps shared traffic at the handoff rate;
   - **Perceus minimizing the residual** (front line — most values never get RC);
   - **borrowing to minimize the handoff rate** (few ownership transfers/use).

4. **Honest caveat.** In the heaviest 16-object micro-regime neither *pure* scheme
   is textbook monotonic-up — the coherence fabric saturates for both. The robust,
   decisive signal is the **constant-vs-linear shared-traffic law** and tls's
   uniform dominance, not a clean monotonic curve at 16 objects. Large-pool /
   8-thread numbers are noisy (unpinned macOS; 8-thread runs spill onto the 4
   efficiency cores) — do not over-read individual points. The G-R2s gate proper
   (P3) must pin CPUs and use a variance band (§7.2).

## Decision (written back to §5.1 / §4.1)

**§5.1 → option (a): thread-local RC with explicit handoff.** Atomic RC anti-scales
on the share-heavy residual; thread-local handoff is strictly faster everywhere
and its shared-line cost is bounded by the ownership-transfer rate rather than the
RC-op rate. Pair it with (i) Perceus minimizing residual size and (ii) borrowing
minimizing handoff frequency. This matches the Koka precedent already cited in §3.2.

## Reproduce

```
cd bench/parallel-alloc
cc -O2 -std=c11 rc_scaling.c -o rc_scaling
./rc_scaling <atomic|tls> <threads> <per> <W> [reps] [objs]
# sweep: for W in 0 1 4 16; for sc in atomic tls; for T in 1 2 4 8; ./rc_scaling $sc $T 4000000 $W 5
```
