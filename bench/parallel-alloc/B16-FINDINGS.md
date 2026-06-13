# B16 — per-thread GC pacing + dynamic span capacity: recovering `[par]`
# scaling under `-gc e` (follow-up to B13)

Goal (carried from B13): make cx `[par]` under `-gc e` SCALE instead of
anti-scale. B13 measured E `[par]` at **1.72-1.76× SLOWER than E serial** and
concluded a static trigger bump "does NOT fix it" (1GB → 1.80× anti-scale; 4GB →
abort on the 262144 span cap). This session re-investigated that conclusion with
a corrected measurement method and two V-runtime changes. **All work is V-only /
CX-agnostic** (clone `vlang-v-latest` canonical; fork `third_party/v` for the cx
measurement). cx is only the microscope.

## TL;DR
1. **B13's "static bump doesn't help" was WRONG** — it was a time-to-ABORT
   artifact (the prior session even retracted a "4GB near-parity" reading for the
   same reason). With the span-cap abort removed, a **fixed 1GB trigger floor
   recovers `[par]` scaling**: cx par 8386ms → **3377ms** = **1.41× FASTER than E
   serial** (was 1.76× slower), and **2.8× faster than boehm par** (9564ms).
2. The recovery is **PARTIAL** (1.41×, not the hoped 4-8×) and **RSS-costly**
   (5.5GB vs 1.7GB). Root: in `[par]` ALL 8 reduces are in-flight at once, so
   every full-STW collection marks the COMBINED live set (~4× a serial
   collection — measured). Raising the trigger cuts collection *frequency* but
   not per-collection *mark cost*, and ballooning the heap eventually loses to
   memory pressure (2GB floor → 5563ms/11.8GB; PACE → worse). **Full near-linear
   `[par]` payoff still needs CONCURRENT MARK** (Phase-2 (2c), deferred,
   highest-risk) — B13's bottom-line stands; only its "trigger bump is useless"
   detail was wrong.
3. **The SERIAL 2.18× win remains the headline shippable result**, unchanged.

## The decisive measurement (why B13 was wrong)
Instrumented the collector (env-gated `VGC_GC_LOG`, since stripped) to print
per-collection cycle# + bytes-marked. cx `[?map (1..8) [reduce [$range 0 400000]
+]]`:

| workload | collections | bytes marked / collection |
|----------|-------------|---------------------------|
| serial   | 70          | constant ~52 MB           |
| par      | 66          | **52-205 MB** (up to ~4×)  |

Collection COUNT is the same serial vs par — **frequency is NOT the problem**.
Per-collection MARK COST is (par marks multiple in-flight reduces' live sets at
once). So a trigger bump helps by cutting the *count* of those expensive
collections, but can't cut their individual cost — which is why the win is
partial and why over-raising the trigger (PACE) just trades GC time for RSS/paging.

## Final clean numbers (cx, fork build `-prod -cc cc -gc e`, best-of-3, M-series 12-core)
| config                    | par time | RSS    | vs E serial |
|---------------------------|----------|--------|-------------|
| E serial                  | 4756 ms  | 1.5 GB | —           |
| **par default (256MB)**   | 8386 ms  | 1.7 GB | 1.76× SLOWER (anti-scale, = B13) |
| **par 1GB floor**         | **3377 ms** | 5.5 GB | **1.41× FASTER** ✅ |
| par 2GB floor             | 5563 ms  | 11.8GB | 1.17× faster (memory pressure) |
| par PACE (×live_threads)  | 4287 ms  | 11.8GB | 1.11× faster (overshoots) |

boehm refs: serial 10968 ms, par 9564 ms. So **par 1GB floor (3377ms) is 3.2×
faster than boehm serial and 2.8× faster than boehm par.** All outputs verified
`(80000200000 ×8)` — none are time-to-abort.

**The fixed floor beats PACE.** PACE multiplies the *already-ratcheted*
`next_gc = marked×2` goal by the live-thread count, so once the live set is
non-trivial it overshoots into multi-GB heaps regardless of the base floor →
memory pressure dominates. A fixed ~1GB floor hits the sweet spot; beyond ~1.5GB
everything slows. PACE is kept as an (inferior) env-gated option, not recommended.

## The two V changes (CX-free; standalone patch `par-pacing-dynamic-spans.patch`)
Both in `vlib/builtin/vgc_d_vgc.c.v` + `vgc_gc_d_vgc.c.v`. **Default build (no env
set) is byte-identical to before** except the allspans storage (see soundness).

1. **Dynamic span capacity (always-on, sound robustness fix).** `allspans` was a
   fixed inline `[262144]&VGC_Span`; raising the trigger past ~1.5GB exhausted it
   → the loud `vgc_say(0xDEAD)` abort (this is what B13 mis-timed as "fast"). Now
   `allspans` is an mmap-backed pointer (`vgc_os_alloc`, 16M-entry default = 128MB
   of address space, lazily committed by the OS, ~0 physical until filled),
   allocated **once on the first `vgc_span_alloc` under `vgc_heap.lock`** (NOT in
   vgc_init — spans are allocated during `_vinit`, before vgc_init runs). The
   pointer never moves, so the collector's lock-free allspans walks (incl. lazy
   sweep outside STW) never observe a relocated/freed buffer — this sidesteps the
   realloc race that runtime doubling would introduce. The loud abort is kept as
   a backstop, now only reachable at a genuinely enormous heap (16M spans).
   Env override `VGC_ALLSPANS_CAP` (entries).

2. **Pacing knobs (env-gated, default OFF).** `VGC_NEXT_GC_MB=<MB>` raises the
   GC trigger floor (used in vgc_init + the `vgc_update_trigger` floor).
   `VGC_PACE=1` scales the live trigger by `live_threads` in `vgc_maybe_gc`
   (inferior, see above). Globals `vgc_base_floor` / `vgc_pace_by_threads`.

## Soundness gate (clone v2, all GREEN)
- **g_churn battery** `[100 1 30]`/`[200 1 50]`/`[100 2 40]` under `-gc e`,
  **default AND `VGC_PACE=1`**: PASS, 0 corruptions every config.
- **corpora none==e byte-identical**: perceus_corpus, deep_free_hazard_corpus,
  uref_corpus, p2_reuse_corpus — all IDENTICAL, rc 0.
- **map_test -gc e**: OK. **array_test -gc e**: OK.
- **v2 self-hosts** (`./v2 -o v3 cmd/v`) clean; v3 runs.
- **No serial regression**: orig cx_e serial 4706ms ≈ modified 4670ms.
- **Zero stderr leak**: trivial `-gc e` prog, cx serial, cx par 1GB all emit 0
  stderr bytes (the "leaked probe" B13 saw was the span-cap abort firing during
  its 4GB test — now unreachable for normal heaps).

## CX-free repros (in the clone)
- `par_live.v` — faithful repro: N workers each build a large LIVE node-list
  (mirrors materialized `[$range]`) then fold it. `serial|par <jobs> <n>`. With
  pad=256/n=400000: serial 390ms, par 1238ms (3.17× anti-scale); par 1GB 901ms;
  par PACE 857ms — partial recovery, same shape as cx (large concurrent live set
  = intrinsic mark cost only concurrent mark removes). This is the gate repro.
- `par_reclaim.v` — control: flat alloc-heavy (bounded live set). Already SCALES
  under e (par 3.5× faster than serial-equiv) — confirms the R2 per-thread
  allocator-accounting fix; isolates B16 as a MARK-cost (not alloc-cost) problem.

## State / what's NOT done (held for user)
- Changes are UNCOMMITTED in both clone (canonical) + fork (`third_party/v`,
  was clean at a95aff916b so its `git diff` = exactly this delta = the patch).
  Both repos have identical edits (13 markers each). Patch applies clean.
- NOT committed/pushed (push discipline is user-gated per the topic file).
- DECISION for user: (a) ship dynamic-span-cap only (sound robustness, default
  unchanged) + keep pacing as env opt-in; (b) also flip a default trigger floor;
  (c) go to concurrent mark for the full payoff. See session report.
