# DEAD ENDS — #700 test-suite duration relief (closed under VC-25)

**Purpose.** #700 is closed. This register exists so no future session
re-attempts a lever that has already been measured and found not to pay. Read
it BEFORE proposing anything about gate duration.

Inside this one issue the same mistake happened twice: VC-14's per-file compile
floor was wrong by ~25x (struck by VC-21), and VC-23's *attribution* of the
lane totals was wrong (struck by the 2026-08-25 audit) — each time a session
executed a brief whose model of the cost it had not verified. The register is
the countermeasure.

**Standing rule this issue paid for, twice:** a TOTAL is not a COST MODEL.
Before optimising a lane, split it by phase and measure the phases. On the
biggest lane in the tree that took four minutes and overturned the whole plan.

---

## The measured cost model (build on this; do not re-derive)

`make test` @ `b6a130141`, all 51 lanes green, 12 cores:
**1,428 s wall / 10,924 CPU-s (182 CPU-min) / 7.6x parallelism.**

Two hard floors follow, and every proposal must clear both:

1. **`test-extraction-gate` is a single serial chain of 13.4 min.** No amount
   of `-j` takes the gate below the longest lane, and the release gate always
   selects it.
2. **182 CPU-min on 12 cores floors the wall at 15.2 min** even at 100%
   efficiency (today's 23.8 min is 63%). **Parallelism cannot beat this floor —
   only removing CPU work can.**

Phase split, `test-extraction-gate` (2026-08-25):

| phase | wall |
|---|---|
| `build-data-dev` (2 artifacts) | 40 s |
| `probe` build | 15 s |
| `cli_gate` build | 16 s |
| `probe` RUN x2 (1838 cases x 2 artifacts) | 8 s |
| **`cli_gate` RUN** (10,579 pairs = 21,158 serial spawns) | **717 s** |

**Compilation is 71 s of ~800 s — 9%.** A world-build here is 15-40 s, NOT the
~200 s the per-lane fixed-cost curve implied.

`test-profile-gate` splits the other way — build-heavy: `build-profiles-dev`
167 s, `profile_gate_cli` build 109 s, RUN 195 s; **warm rerun of those builds
saved 4 s of 167**.

---

## Levers ATTEMPTED and DEAD

### D1 — test-file consolidation, "one binary per module" (VC-14 lever 10a)
**RETIRED by VC-23.** Marginal cost per test FILE is 2-5 s (curve: 1 file =
3 s, 57 files = 235 s warm); per-LANE fixed cost is 200-250 s. Merging every
remaining file saves a few hundred seconds ONCE and permanently destroys the
per-subject granularity dependency-driven selection needs. Wave 1's merges
(246 -> 71 files) stay as they are; **un-merging is equally unauthorized.**
No further merging without a new ruling naming this row.

### D2 — VC-14's decline of `-usecache` "on risk"
**Factually void (VC-21).** `CX_CACHE ?= -usecache` had been the default for
`test-vcx-suite` / `-code` / `-cmd` since #129. The lever being "declined" was
already in production, and cache-free was measured SLOWER (71 s vs 53 s).

### D3 — the devbox/host toolchain swap
**Closed as a lever by VC-22**, owner verbatim: *"keep running in devbox, we
can't afford to screw up our dependency management."* The 4x gap is real
(devbox nix clang 53-54 s vs host Apple clang 13-14 s per test binary) and is
recorded as a finding only. Dependency management outranks wall clock. Do not
re-propose.

### D4 — `-usecache` on the uncached world-builders (2026-08-25, this session)
**APPLIED, MEASURED, REVERTED.** All lanes stayed GREEN with byte-identical
transcripts; only the clock regressed:

| | before | after |
|---|---|---|
| extraction run 1 | 768 s | 984 s |
| extraction run 2 (warm) | 844 s | 980 s |
| profile run 1 | 660 s | 923 s |

Three measured reasons it cannot pay:

- **D4a — `-shared` recipes cache NOTHING.** `lib-core-dev`: **0 objects
  cached**, 24 s cached / 24 s rerun / 23 s uncached. Five of the profile
  matrix's builds plus `lib-dev` are `-shared`. Detected by COUNTING OBJECTS;
  timings alone read as a win. Any future cache proposal must count objects.
- **D4b — executables reuse fully but save little.** `cli-data-dev`: 46 s cold,
  17 s warm, 20 s uncached. Warm beats uncached by 3 s; a cold namespace costs
  2.3x. On the real recipe the warm win is inside the noise (163 vs 167 s).
- **D4c — the ceiling is structural.** An identical rerun is the cache's BEST
  case (any edit invalidates strictly more), and V compiles the program TU
  whole-program regardless, so only pure module objects are reused. Best case
  measured: 15% on the small recipe, ~2% on the real one. On the extraction
  gate a PERFECT cache saves <=71 s of ~800 (9% ceiling).

**Do not re-enable `-usecache` on build recipes to buy time.** It remains
correct and default on the three `v test` lanes (#129), where per-file test
binaries genuinely share module objects.

### D5 — the dev build-stamp split
Existed ONLY to serve D4: `-d cx_build_date=<per-second>` would mint a fresh
cache namespace per invocation once part (i) put define VALUES in the key.
Reverted with D4. **Keep the finding**: that stamp is a gratuitously volatile
build input and has cost this repo twice already (the #902 relink race that
`UPTODATE_GUARD` exists for; the extraction gate's private-copy pinning). If it
is ever revisited, it is for reproducibility, not for cache performance.

### D6 — treating the top lanes as compile-bound
The premise of D4 and of VC-23 §2. **False, measured:** 91% of the extraction
gate is process spawning. Any proposal that speeds up COMPILATION cannot move
that lane more than 71 s.

---

## Levers that WORKED (keep; do not undo)

- **W1 — cache-key soundness** (part i, `42e7ba9aa` + fork `dc5c87ec6a`): nine
  measured silent-miscompile holes closed; `make check-vcache-soundness`,
  16 probes, red-proven. Cadence: every `third_party/v` change, pre-cut,
  before widening `-usecache`.
- **W2 — the closure link-set fix** (`eaf4b4e7f` + fork `46f1be51d5`): found
  ONLY because D4 put the cache on the first non-test binary build. Invariant
  **I7 link-set completeness** + probes `H11-*`, red-proven. D4 was a
  performance dead end and a correctness win.
- **W3 — ring-scoped selection** (`895d685a6`, `7e6271a70`): a `vcx/tests`-only
  edit now skips ~2,000 s of serial lanes; Ring-0/Ring-1 edits still run them
  all (verified both directions). This is the ONLY lever that measurably
  improved the dev loop.
- **W4 — parallel `test-changed`** (`afe134017`): it had run its selected lanes
  SERIALLY since creation (2,347 s vs the 1,428 s full gate).
- **W5 — the cache-free retry became a gate-escape diagnostic**
  (`2f88102a5`): it can no longer turn a cache defect green. W2 is the proof
  that mattered — that retry would have masked it.
- **W6 — VC-24, the harness on `-gc e`**: no Boehm lane remains in the tree's
  own gates.

---

## Levers NOT tried, with their measured bounds

Neither is carried by #700. Each needs its own ruling and issue.

### N1 — bounded worker pool in the gate harnesses
`extraction_gate_cli.v`'s `compare()` runs `run_bin(mono)` then
`run_bin(data)`; there is no worker pool anywhere. 21,158 spawns at ~34 ms on
one core. **Bound: ~5-7 min of gate wall (24 -> ~17-19), removes floor (1),
does NOT reach 10 min** because floor (2) is 15.2 min.
**Not free:** this is the gate that certifies `libcx-core == libcx` over the
Ring-0 corpus. Its own file records three load scars — #883 code-signature
kill on an overwritten inode, #902 `Exec format error` mid-relink, and one
divergence in 1,838 under parallel load. Needs per-pair scratch isolation,
index-ordered result collection (the ABI transcript must stay byte-identical —
recorded hash `2d739c8f74dcfae965788c7befd5248e6ff99cb47f4e69ef25d543005c9737a2`),
and the existing serial divergence re-check kept intact. **The 12-min CLI lane
has NO recorded transcript hash — only case counts and rc — so verification
there is weaker than for the ABI lane; record one first.**

### N2 — reduce total CPU work
**The only lever that can reach VC-22's 10-minute target**: 182 CPU-min must
become ~96-120. No lever currently exists — D1 is retired, `-usecache` is
already default where it pays, and VC-22 forbids removing lanes to buy the
number. Any serious attempt starts by profiling where the 182 CPU-min goes
across the 51 lanes, which has never been done.

### N3 — `UPTODATE_GUARD` on the dev artifacts
`build-data-dev` is rebuilt independently by `test-extraction-gate` AND
`abi-gc-gate` (40 s x 2 per gate run); `lib-dev`/`cli-dev` have no guard at
all, which is most of the 350 s serial prewarm. **Bound: ~1.3 min per gate
run, up to ~6 min on an unchanged tree.** Failure mode is worse in kind than
slowness — it ADDS a skip path, so a missed entry in `BUILD_INPUT_DIRS` (whose
own comment calls that "a STALE-BINARY hazard") means lanes silently test
yesterday's binary. If taken, key it on `$(V)` + `BUILD_INPUT_DIRS` exactly as
the prod guard does.

### N4 — #971, linux `-z muldefs`
Filed, not measurable on darwin. Removing it may break upstream's inherent
generated-helper duplication; needs a linux measurement (gate DUP probe +
3 lanes) rather than a blind change.

**TAKEN 2026-08-26.** The linux measurement was made in an `ubuntu:22.04`
container (the `scripts/release_linux.sh` lane's base image and toolchain:
gcc 11.4, GNU ld 2.38), A/B against the same tree with and without the flag.
The feared inherent duplication does not exist — the flag was pure masking,
and `cmd/v` itself builds `-usecache` cold and warm without it. Removed in
the fork; evidence and the full one-definition table are in the 2026-08-26
addendum to `ledger/audit_2026_08_24_vcache_key_soundness.md`.

---

## POST-CLOSE ADDENDUM (2026-08-25) — N1 was TAKEN, and its bound was over-estimated

`N1` (harness worker pool) was ruled in as **VC-32**, redesigned as PROCESS
sharding after the thread version hit #973, and delivered (`e49cbbb31`).

**Measured, full gate, same machine:**

| | wall |
|---|---|
| baseline `b6a130141` | 1,428 s (23.8 min) |
| warm, pre-sharding | 1,247 s (20.8 min) |
| post-sharding | **1,154 s (19.2 min)**, GATE-RC=0 |

The LANE improved 4.0-4.4x (768-844 s → 191 s; its CLI phase 717 s → 103 s at
an identical verdict digest). **The FULL GATE improved by 93 s.**

**The estimate in N1 — "~5-7 min of gate wall" — was WRONG, and the error is
instructive.** It treated the extraction gate's 13.4-min serial chain as the
binding floor. It was not: under `-j12` that lane already overlapped with
others, and the binding constraint is floor (2), total CPU. At 19.2 min wall
against 182 CPU-min the gate runs ~9.5x parallel, already near the 15.2-min
CPU-bound floor, so removing serial time from ONE lane cannot buy much.

**Corrected rule for sizing any future lane-level lever:** a lane's serial
length bounds the gate only while the gate is LATENCY-bound. Once wall x cores
approaches total CPU-min, the gate is THROUGHPUT-bound and the only lever that
moves it is removing work (N2). Check which regime the gate is in — parallelism
ratio versus core count — before estimating.

**Still worth having, on other grounds:** the lane is 4x faster for anyone
running it alone or via `test-changed`, and the work produced the verdict-digest
instrument plus two correctness finds (a path-dependent digest, and 271
comparisons reading a stale fixture — a green gate testing nothing).
