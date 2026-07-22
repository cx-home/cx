# P0 acceptance — immediate #14 relief via Boehm tuning

**Scope.** P0 of the V-runtime memory-management plan
(`spec/03-approved/process/v_runtime_memory_management.md` §6): the *immediate, fork-local*
mitigation for cx-private #14 (`[?map [par]]` slower than serial). P0 is **partial
relief by design** — it tunes the existing Boehm GC; it does not remove the
fundamental alloc-lock. The real alloc-heavy fix is P1 (Perceus) / P3 (precise
backstop).

Date: 2026-06-11. Box: 12-core Apple M-series (`hw.ncpu = 12`), darwin/arm64.
Fork pin: `third_party/v` @ `cx-home/v0.7.0-cx-patches`.

---

## The two Boehm levers — and where each one actually lives

P0 has two levers. **Both were already active in the shipped macOS `cx` binary
at this fork pin** — the on-disk state was better than the plan's stated premise.
A prior note claimed neither had landed; that was a verification gap (it grepped
only `vlib/builtin/`). The corrected, verified state:

### 1. Marker-pin — `GC_set_markers_count(1)` before `GC_INIT()` (macOS)

- **Lives in `vlib/v/gen/c/cmain.v::gen_boehm_gc_init()`** (the cgen *main*
  template), not in `vlib/builtin/`. It emits, macOS-gated, for **every Boehm
  binary** the patched V compiles — so the `cx` eval/CLI binary gets it, not just
  the HTTP leg. Verified by inspecting the generated C: `GC_set_markers_count(1);`
  sits immediately before `GC_INIT();`.
- **Why:** libgc's parallel mark defaults to one helper thread per core; on macOS
  every stop-the-world collection then wakes N−1 helpers that contend
  (mach `thread_suspend`/`resume` + mark-queue spin), starving the application's
  own worker threads. Pinning to a single marker removes that stomp.
- `GC_MARKERS` env still overrides it (read first in `GC_thr_init`), so the
  un-pinned baseline below is reproducible with `GC_MARKERS=12`.

### 2. Thread-local allocation (TLA)

- **The macOS `cx` build links the prebuilt `third_party/v/thirdparty/tcc/lib/libgc.a`**
  (the `dynamic_boehm`-off macOS path in `builtin_d_gcboehm.c.v` forces the
  tcc/lib archive to dodge the hardened-runtime rwx-page abort). That archive is
  built by `thirdparty/build_scripts/thirdparty-macos-arm64_bdwgc.sh`, which does
  **not** pass `--disable-thread-local-alloc`, so TLA defaults to **on** there.
  Confirmed: `nm libgc.a | grep _GC_init_thread_local` resolves. **So every
  measurement below already reflects TLA = on.**
- The bundled **amalgamation** `thirdparty/libgc/gc.c` (used only on the Linux /
  `-prod`-bundled `gc.o` path, **not macOS**) was the genuinely-pessimal one:
  its embedded autoheader config had `/* #undef THREAD_LOCAL_ALLOC */`. P0 flips
  it to `#define THREAD_LOCAL_ALLOC 1` (+ `amalgamation.txt` doc), the canonical
  configure-equivalent of `--enable-thread-local-alloc=yes`. The TLA
  implementation is already present in the amalgamation (guarded by
  `#ifdef THREAD_LOCAL_ALLOC`), so the flip activates real code. It compiles
  cleanly. *Caveat:* full TLA *activation* in a bundled build is exercised by the
  Linux path (gcconfig.h supplies the platform-thread derivation); it cannot be
  end-to-end-validated on this Darwin box, which never compiles the amalgamation.
  The flip is correct-by-construction and brings the bundled config into parity
  with the already-TLA-on macOS prebuilt.

---

## Measurement 1 — marker-pin is a real 2.4–5× win on MARK-bound work

`boehm_mp_bench.v` — N threads, each allocs+drops 128 B scanned objects in a tight
loop, forcing frequent collections (the MARK-bound regime). Built with the patched
V (`-gc boehm -prod`), 2 000 000 iters/thread.

| threads | pinned (markers=1, cx default) | unpinned (`GC_MARKERS=12`) | marker-pin speedup |
|--:|--:|--:|--:|
| 1 | 38.5 M allocs/s | 16.1 M/s | **2.4×** |
| 2 | 26.7 M/s | 13.0 M/s | 2.1× |
| 4 | 17.8 M/s | 6.6 M/s | 2.7× |
| 8 | 15.4 M/s | 3.1 M/s | **5.0×** |

The marker-pin helps at every thread count and is consistent with the HTTP
serve-file precedent (~2.6×, `project_http_multicore_gc_bottleneck`). **But note
both columns still anti-scale** (pinned 38.5 → 15.4 as threads rise): the
collection stomp is removed, the allocation serialization is not.

## Measurement 2 — #14 persists for alloc-heavy `[?map [par]]`

cx-level reproduction. 8 map items, each reducing a 400 000-element range (an
alloc-heavy, allocation-per-eval-step interpreter loop); serial vs `:par`
(8 spawned workers on 12 cores). `cx eval`, wall-clock `/usr/bin/time -p real`,
stable across `-prod` and dev builds:

| workload | wall time |
|---|--:|
| serial `[?map …]` | ~10.3 s |
| parallel `[?map … :par]` | ~13.1–13.6 s |

**`:par` is ~1.3× *slower* than serial** — issue #14, unchanged, *with both P0
levers active*. Every per-eval-step `cx.Node` allocation serializes on the single
`GC_allocate_ml` mutex; TLA batches that to ~1 acquisition per heap block but at
interpreter allocation rates across 8 cores even the batched lock contends
fatally, and the cross-thread coordination adds net overhead on top of the serial
work.

---

## Honest acceptance

- **What P0 fixes:** MARK-bound multi-thread contention. Collection-heavy and
  transport-bound parallel workloads (HTTP serve, GC-pressure loops) get a real
  2.4–5× from the marker-pin. TLA gives a modest single-thread/low-core
  allocation-lock easing. These are shipped and active on macOS today.
- **What P0 does NOT fix:** alloc-heavy `[?map [par]]`. The `GC_allocate_ml`
  alloc-lock is architectural to Boehm; no Boehm *config* removes it (a rebuilt
  bdwgc with TLA on + parallel-mark off + `--enable-large-config` collapses
  identically — see `README.md`). Alloc-heavy parallel work stays at-or-below
  serial.
- **Near-term answer for users hitting #14:** run the workload **serial**, or use
  the per-thread arena (`-d cx_regions`, `project_scope_region_integration`) for
  *bounded-compute* `:par` bodies (validated 2–6× there). Note `cx_regions` does
  **not** help *bulk*-allocating bodies (e.g. reducing a 400 k range) — those
  overflow the per-thread block and fall back to the global lock, so this
  benchmark would not benefit; it is for bounded per-item compute.
- **The real fix is demand-side, not GC-config:** P1 Perceus-disciplined autofree
  (allocate less / reuse in place) + P3 precise per-thread-cache backstop. P0 buys
  headroom while that multi-week compiler work proceeds.

## Reproduce

```sh
# Measurement 1 (marker-pin):
cd bench/parallel-alloc
../../third_party/v/v -gc boehm -prod -o boehm_mp boehm_mp_bench.v
for n in 1 2 4 8; do echo -n "T=$n pinned:   "; ./boehm_mp $n 2000000; done
for n in 1 2 4 8; do echo -n "T=$n unpinned: "; GC_MARKERS=12 ./boehm_mp $n 2000000; done

# Measurement 2 (#14 at cx level):
CX=vcx/target/cx
P='[?to-sequence [?map (1,2,3,4,5,6,7,8) [using [?fn $x [?reduce [$range 0 400000] [using [?fn ($a $b) [+ $a $b]]] [init 0]]]]'
echo "$P]]"      | $CX eval --data=-   # serial   (~10 s)
echo "$P [par]]]" | $CX eval --data=-  # parallel (~13 s, slower — #14)
```
