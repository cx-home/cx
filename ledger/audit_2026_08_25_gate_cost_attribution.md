# AUDIT — where the gate's cost actually is (#700 wave 2 part ii)

**Status:** audit record, produced by the Opus 5 rollout session 2026-08-25 per
VC-23 §3(ii). It states findings and their evidence class; it rules nothing.
The ruling question it raises is posed to the owner, not answered here.

Every row below is **measured** in devbox on this machine (12 cores), serial,
one lane at a time, at `eaf4b4e7f`. Logs in the session scratchpad.

## 1. The baseline reproduces. The *attribution* of it does not.

VC-23 measured the two top lanes correctly and I re-measured them
independently before changing anything:

| lane | VC-23 | re-measured 2026-08-25 |
|---|---|---|
| test-extraction-gate | 806 s | 768 s, then 844 s on an identical rerun |
| test-profile-gate | 662 s | 660 s |
| build-vcx + build-vcx-dev (prewarm) | not costed | **350 s / 359 CPU-s** |

Both lanes run at ~0.95x parallelism: serial chains, so `-j` across lanes
cannot compress them. An identical back-to-back rerun cost MORE, not less —
zero reuse, as expected with no cache.

**What VC-23 got wrong is not the totals — it is what they are made of.** It
characterised these lanes as "~8 full uncached world-builds, cold every run"
and sized the whole cache strategy against that. Phase split of
test-extraction-gate:

| phase | wall | rerun (warm) |
|---|---|---|
| build-data-dev (2 artifacts) | 40 s | 41 s |
| probe build | 15 s | 15 s |
| cli_gate build | 16 s | 15 s |
| probe RUN x2 (1838 cases x 2 artifacts) | 8 s | |
| **cli_gate RUN** | **717 s** | |

**All compilation is 71 s of an ~800 s lane — 9%.** The other 91% is one
binary RUNNING: 10,579 invocation pairs = 21,158 process spawns at ~34 ms
each, issued SERIALLY (`compare()` calls `run_bin(mono)` then `run_bin(data)`;
no worker pool anywhere in extraction_gate_cli.v). A world-build here is
15-40 s, not the ~200 s the per-lane-fixed-cost curve implied.

test-profile-gate splits the other way — it IS build-heavy:

| phase | wall |
|---|---|
| build-profiles-dev (5 builds) | 167 s |
| profile_gate_cli build | 109 s |
| profile_gate_cli RUN | 195 s |
| build-profiles-dev, warm rerun | **163 s** |

## 2. The ruled lever does not pay. Measured, not argued.

`-usecache` was rolled onto every dev world-builder (the two lanes above plus
build-vcx-dev), the fork fix below was needed to make it link at all, and the
result was **slower**:

| | before | after |
|---|---|---|
| extraction run 1 | 768 s | 984 s |
| extraction run 2 (warm) | 844 s | 980 s |
| profile run 1 | 660 s | 923 s |
| prewarm-build | 350 s | 292 s |

All GREEN (RC=0) — verdicts identical, transcripts byte-identical. Only the
time regressed. Isolated per-recipe measurements explain why:

- **`-shared` recipes cache NOTHING.** lib-core-dev: 0 objects cached, 24 s
  cached / 24 s rerun / 23 s no-cache. Five of the profile matrix's builds and
  lib-dev are `-shared`. Measured by counting objects, not by reading timings —
  a timing-only check would have called this a win.
- **Executable recipes reuse fully but save little.** cli-data-dev (cmd_data/,
  20 modules cached): 46 s cold, **17 s warm**, 20 s no-cache. Warm beats
  uncached by 3 s; a cold namespace costs 2.3x.
- **On the real recipe the warm win is inside the noise**: build-profiles-dev
  163 s warm vs 167 s cold.

**The decisive argument is structural, not statistical: an identical rerun is
the cache's BEST case** — any source edit invalidates strictly more — and the
best case measures 15% on the small recipe and ~2% on the real one. The dev
loop can only do worse. The reusable fraction is small because V compiles the
program TU whole-program regardless; only pure module objects are reused.

Net: on the extraction gate a PERFECT cache saves <=71 s of ~800 s (9%
ceiling). On the profile gate the ceiling is larger but unrealised. The
rollout was therefore reverted; the fork fix and the gate probe it produced
were kept, and are independently valuable.

**Unattributed residual — RESOLVED, measured 2026-08-25 end of session.** The
first full gate after the fork fix ran **1,868 s / 16,368 CPU-s** (+31% wall,
+50% CPU vs baseline), which was far too much for anything landed. The
suspicion recorded here was VC-24's `-gc e` harness. **It was wrong.** The
cause is the `v self` the closure fix required: it changes the vexe salt, so
every `-usecache` namespace was cold for the three `v test` lanes, and VC-23
measured cold-vs-warm at 2.5x on identical work.

Settled by re-running the identical gate once those namespaces were warm, with
ALL of the session's changes in place:

| run | wall | CPU | parallelism |
|---|---|---|---|
| baseline `b6a130141` | 1,428 s | 10,924 CPU-s | 7.6x |
| first run after `v self` (cold namespaces) | 1,868 s | 16,368 CPU-s | 8.76x |
| **warm, all changes in, GATE-RC=0** | **1,247 s** | **10,756 CPU-s** | 8.62x |

CPU is back to baseline within 1.5% and wall is 13% BELOW it, so **VC-24's
`-gc e` harness costs nothing measurable** — consistent with its transcript
being byte-identical (`2d739c8f…`). No cache-free GATE ESCAPE fired.

**Standing trap, recorded:** the FIRST `make test` after any compiler rebuild
pays cold namespaces on the -usecache lanes. Do not attribute that cost to the
tree's changes; re-run warm before drawing a conclusion.

## 3. What the rollout DID buy: a defect the cache was hiding

Rolling `-usecache` onto the first NON-TEST binary build broke the link
immediately: `ld: symbol(s) not found` for `builtin__closure__closure_init`.
Three mechanisms each assumed the closure runtime was inside builtin.o while
it was in no object at all, and the defect had stayed invisible because
cgen's header-only path carries a `!g.pref.is_test` escape hatch and every
`-usecache` consumer to date was a `v test` build. Pre-existing upstream, not
a part-(i) regression (the series never touched util.v or the link-set
predicates). Fixed in fork `46f1be51d5`, landed with the pin at `eaf4b4e7f`.

It also exposed an invariant the part-(i) audit never stated:

- **I7 link-set completeness** — every module whose symbols the generated code
  REFERENCES must be inside a linked object or linked itself. I1-I6 say a
  SERVED object matches its inputs; none says anything about an object that is
  never served. Gate probes H11-closure-link-set / H11-no-duplicate-defs,
  red-proven against the pre-fix compiler (14 sound / 2 red), 16/16 after.

## 4. The lever the measurements point at

91% of the biggest lane is a serial spawn loop on a 12-core machine. Bounding
it honestly: 717 s at ~1 core, so a bounded worker pool is worth several
hundred seconds of critical path — roughly an order of magnitude more than a
perfect module cache delivers on the same lane. It is NOT free work: the
runner shares one scratch work folder (`cx_extraction_gate_cli`), and the
`#883` code-signature and `#902` relink hazards recorded in that file are
exactly the class that concurrency re-arms, so it needs per-pair isolation and
its own before/after proof.

That is a new lever, not the one VC-23 ruled. Recorded here for the owner's
decision rather than taken.

## 5. Method note, recorded because it repeated

VC-21 struck VC-14's numbers and named the failure: *"Numbers inherited from a
handoff are unverified until re-measured."* I re-measured the TOTALS before
acting — and then optimised against the handoff's ATTRIBUTION of those totals,
which I did not verify until after the rollout had been applied and measured.
A total is not a cost model. The phase split that overturned the plan took
four minutes and should have been the first measurement of the session, before
any edit.
