# bench/repr — the CXDM live-memory multiplier guard

The regression half of **RP-5** (`ledger/rulings_2026_09_02_cxdm_representation_1119.md`;
design §8 of `spec/02-working/cxdm_representation.md`). Wave **W1** of the
#1119 representation campaign, and the instrument every later wave is measured
by.

```
make repr-guard          # or, from the repository root: cx --allow-read --allow-write --allow-subprocess --allow-env bench/repr/run.cx
CX_REPR_KEEP=1 make repr-guard           # keep the generated corpora for inspection
CX_REPR_RECORDS=8000 make repr-guard
CX_REPR_LANE_DEADLINE_S=120 make repr-guard   # the per-reading deadline (default 300 s)
make repr-guard-selftest # the driver's verdicts on planted lane drivers (#1766)
```

In `TEST_TARGETS`, so it runs in every `make test`.

`make repr-guard` depends on `build-vcx`: the driver links the same vendored
RE2 static archive (`third_party/re2/obj/libre2.a`) the CLI does. Running
`run.cx` directly in a fresh worktree therefore needs that archive and the
pinned V first — `git submodule update --init third_party/re2 third_party/v`
and a `make -C vcx re2-shim` (or just `make repr-guard`, which does it).

## What it asserts

Per lane, on a ~2 MB corpus of the same logical data in three surfaces:

```
live_ratio = (live bytes after parse − live bytes before parse) ÷ input bytes
```

against a bound. `live bytes` is what vgc **marked** in a forced collection with
the parsed tree still reachable — read from `gc_heap_usage().total_bytes`, which
both collector paths rebase to `vgc_count_marked()` at mark termination, so it
is exact rather than the MB-rounded `VGC_GCTRACE` line. The baseline is taken
with the corpus string already resident, so the input bytes and the runtime's
own live set are subtracted rather than charged to the representation.

**A ratio, never a time and never an absolute byte count.** That is RP-5(a)(ii)
and it is what lets the lane sit in a `make test` that runs under `-j`: the
three numbers came out identical under eight saturating CPU burners and on an
idle machine. RP-5(c) — an RSS-shaped bound — was rejected for the opposite
reason: RSS is pacer- and platform-dependent.

## The ratchet

Re-pinned at W5+W6 (RP-5): the RP-1 flip and RP-4's inline attribute type. From
the pre-campaign baseline of 18.779 / 15.316 / 10.348 that is **-8.0% json,
-48.1% xml, -26.8% cx**.

The table is the LIVE block in `run.cx`, not a snapshot: a wave that improves a
lane edits the bound there and this table in the same commit (RP-5). It read
the W5+W6 numbers — json 17.271× against 19.20 with "RP-3 still to come" — for
three re-pins after RP-3 had landed, which is the record disagreeing with the
tree that issue 1251 filed.

| lane | measured | bound | set by | carrier under test |
|---|---|---|---|---|
| json | 7.569× | 7.95 | `8c8da881c` (#1208, #1247) | the map carrier after RP-1/RP-3; measured +5 % |
| xml | 7.941× | 8.35 | `8c8da881c` (#1208, #1247) | `Element` + `Attribute`; `AttributeMeta` retired by RP-4 |
| cx | 7.577–7.588× | 8.00 | `8c8da881c` (#1208, #1247) | `MapNode` / `MapEntry` |
| cxel | 7.600× | 8.00 | `13bd59056` (#1275) | an element corpus with atom / date / duration attribute columns; the autotyped attribute's type name rides inline, so `attr_meta=0` |

Re-pinned 2026-09-04 (#1208 + #1247): bounds are **measured +5 %** — the `+1.0` for a retained input
copy is gone (see below). json 7.569 → 7.95, xml 7.941 → 8.35, cx 7.577–7.588 → 8.00, and the new
`cxel` lane (an element corpus with atom / date / duration attribute columns) 15.507 → 16.30 — it read
16.325 before the per-parse scalar intern pool; what remained was one `AttributeMeta` record per autotyped
attribute (128k of them). That last one is gone: #1275 (`13bd59056`) routes an autotyped attribute's type
name inline through `set_data_type`'s guard, `attr_meta=0`, and the lane re-pinned 16.30 → 8.00 on a
7.600× reading. The table above carries the live bounds.

Re-pinned 2026-09-04 (#1275): `cxel` 15.507 → **7.600**, bound 8.00. Those 128k `AttributeMeta` records
each held the attribute's type NAME as a string (`atom`, `date`, `duration`, `int`) — one 112-byte
allocation per autotyped attribute, more than half the lane's live set, saying what `Attribute`'s inline
`has_dtype` / `dtype` (RP-4) already say. `new_attribute` now routes every round-tripping name inline
through `set_data_type`'s guard; only a sized numeric (`u16`, `f32`, …) or a namespaced attribute still
pools. The census reads `attr_meta=0`, and the four lanes now sit together at 7.57–7.94×.

Bounds are pinned at **measured + 1.0, then +5%** (see "what the instrument can
and cannot see" for what the +1.0 buys). They are a **ratchet**: every wave that
improves a lane re-pins its bound DOWNWARD in `run.cx` in the same commit that
lands the improvement, and records the new number here and on the #1119 wave
row. A bound is never raised without a ruling — the ratchet is not loosened to
accommodate a regression.

Under-shooting a bound by more than 20% prints a re-pin NOTE and does **not**
fail. RP-5 makes exceedance the failure and the downward re-pin a wave-exit
obligation; failing on an improvement would red an unrelated `make test` before
the campaign's own wave could re-pin.

Red-proven at landing: an xml bound of 9.00 produced
`FAIL — lane xml live multiplier 15.316x exceeds the pinned bound 9.00x`, RC=1,
with the other two lanes still reported.

## Agreement with the ruling's own measurement

The RP ledger's numbers came off the same record SHAPE at 300k records
(19–20 MB corpora) with a `-cflags -O2` harness: JSON **18.1×**, XML **14.6×**,
CX **10.3×**. This lane, at 32k records (~2 MB) and `-prod`, reads **18.78 /
15.32 / 10.35**. Two instruments, two corpus sizes, two builds, the same three
numbers — which is the cross-check that says the small corpus #700's register
buys is measuring the same thing the campaign is about.

## Corpora

32,000 flat records of `id` (int), `name` (string), `active` (bool), `score`
(float) — the RP ledger's shape — in three surfaces:

```
json  [{"id":100001,"name":"user-100001","active":true,"score":100.5}, …]
xml   <recs><rec id="100001" name="user-100001" active="true" score="100.5"/>…</recs>
cx    [{id: 100001, name: user-100001, active: true, score: 1.005e2}, …]
```

The CX lane is byte-for-byte what `cx --from=json --to=cx` emits for the JSON
lane, so the two differ in carrier and in nothing else. Every field is a pure
function of the record index — no clock, no environment, no random source — so
the corpora are reproduced on demand instead of committed, and `run.cx` deletes
them unless `CX_REPR_KEEP=1`.

## What the instrument can and cannot see

Three findings from building it, each of which changed the design:

**1. The keep-alive has to be a real use.** The first driver held the tree with
`if roots.len > 1_000_000_000 { … }`. Under `-prod` the JSON lane then measured
**0.000×** — the Perceus front line drops a value after its last REAL use, and
reading `roots.len` is not a use of the elements, so the whole tree was released
before the collect and the instrument was reporting the cost of a document
nobody was holding. The driver now re-walks the tree AFTER the live-byte read
and compares the two censuses; a disagreement is a fatal exit 3, not a number.

**2. The reading depends on the process's history, so the process shape is
fixed.** The identical binary on the identical corpus reported 18.779× when it
read an existing corpus file and 17.771× when it had just generated one in the
same process — a difference of exactly one input-sized transient. vgc scans
stacks and registers conservatively, and a 2 MB generation is a large slice of
history. Corpus generation is therefore a SEPARATE process (`repr gen …`), so
every measurement runs the same shape. With that fixed, six consecutive clean
runs gave byte-identical json and xml readings; the cx lane alternates between
two values 6,608 B apart (0.03%).

**3. The residual is one conservatively-retained input copy, and that is what
the headroom is for.** The `-prod` and `-cflags -O2` builds disagree on the XML
lane by exactly **1.000×** — 266,047 B on 266,015 B of input, the same ratio at
4k / 8k / 16k / 32k records — i.e. one live root pointing at the parser's copy
of the source. `codec_text_boundary` materialises the whole input as a `[]u8`
twice per parse (`src.bytes()`, then `out.bytes()`), and one of those copies
survives the collect in the `-prod` build. Zeroing 64 KB of dead stack below the
frame did **not** remove it, so it is not a stale stack slot: it is a register
or a spill in a live frame, which nothing portable can scrub. Hence `+1.0` of
absolute headroom on every bound. The transient itself is a parser-side leak of
the RP-4 family and is tracked separately as #1208 for W6 — it is not what this guard
measures, and the guard must not be sensitive to it.

**Update 2026-09-04 — #1208 landed and the disagreement is gone.** With the copies removed
(`validate_utf8_str` over a no-copy view; the BOM sniff indexes the string), the `-prod` and
`-cflags -O2` drivers report the SAME live bytes on json and xml at 32k records (7.569 / 7.941 both)
and differ on cx by 0.011× (one small transient, the 0.03% class above). The `+1.0` therefore no longer
buys anything and the bounds were re-pinned to measured +5 %.

`-prod` is the build the guard uses, for the reason gates 14/15/16 carry it
(#835): the driver compiles the `cx` module as SOURCE, so a dev build would be
measuring a build CX does not ship — and the campaign's other half (peak RSS ≤
8× input, RP-5(a)(i)) is measured on the shipped `-prod` `cx` binary.

## The load average beside every reading (#1431, RULED: 1431-a)

Each row carries a `load1` column — the machine's 1-minute load average sampled
immediately after that lane's driver returns — and the header, the RED/GREEN
line and every failure diagnostic carry all three averages. The ratio is
load-insensitive by construction and measured identical under eight saturating
CPU burners, but not without limit: the post-merge run on `984cd3c99`
(2026-09-12) read xml at 8.941x against the 8.35x bound at a load average of
~300, on a **ledger-only** tree byte-identical to `469ec08e7`, whose run had
passed the same step four hours earlier; the retry on the same head passed.

That reading could only be classified by correlating the runner's log with the
steps running beside it. It is stated in this output now, and `make repr-guard`
carries the matching retry class (`GAUGE_SERIAL_RETRY`, "memory gauge under
load"): a bound exceedance re-measures **once**, serially, and the run fails on
the second reading. Any other failure — no V, a driver exiting non-zero, an
unparsable measurement — is a real failure with no retry. **No bound moves for
a load reading**: re-pinning stays a wave-exit obligation (RP-5).

## Every reading has a deadline (#1766, RULED: RUN-5, CXF-1)

The driver was a shell script until #1766, and it hung the post-merge run
twice — `dfc9f12f9` for 95 minutes, `8b63de0c7` for 5 h 14 m — each ended only
by killing a pid by hand. It captured each reading with `out=$("$BIN" …)`: a
command substitution waits for EOF on its pipe, not for the driver, and under a
load above ~50 the capturing subshell sat asleep at 0.0 % CPU with both ends of
its own pipe open; the recipe's `{ …; } | tee` then waited on it, and so did
`make`, every merge chain waiting for a gap, and every round's shared-slot step.

`run.cx` is the driver now. Every child it runs — the build, a corpus
generation, a reading, a load read — writes its output to a **file** (no pipe
exists, so nothing can hold one), runs under a `timeout-ms` in a process group
of its own (the deadline kills the reading and everything it started), and has
its exit status read directly from the result; the output is read back once the
child is gone, capped at 1 MiB. A reading past `CX_REPR_LANE_DEADLINE_S`
(default 300 s; the build's is `CX_REPR_BUILD_DEADLINE_S`, default 1800 s)
turns the step red **by name**:

```
bench/repr: FAIL — lane xml exceeded its 300 s deadline at load average 62.70; the reading was killed and the step reds by name rather than hang the run (#1766).
```

That is not the bound-exceedance text, so the GAUGE retry does not absorb a
stall. `make repr-guard` writes the output to its log file and prints it back
after the exit is read — no pipe in the recipe either. `make
repr-guard-selftest` (scripts/repr_guard_selftest.cx) proves it on planted lane
drivers (`CX_REPR_BIN`, with a corpus directory of its own via
`CX_REPR_CORPUS_DIR`): a stalled reading reds by name inside the deadline, a
grandchild holding the lane's stdout cannot hold the step (the `8b63de0c7`
shape), and the bound-exceedance, non-zero, unparsable and keep/cleanup answers
are unchanged.

The bounds are exact decimals compared exactly (the shell compared them through
`awk` floats); the build's content hash is the sha256 of `repr.v`, the compiler
and the `cx` module's sources, so the first run after #1766 rebuilds the driver
once.

## The census

Every run prints the per-kind census and the struct sizes under each lane's
verdict line, on the way past and not only on failure:

```
census elements=160001 attrs=0 … empty_attrs=160001 empty_items=0
sizeof Node=16 Element=96 Attribute=48 ScalarNode=24 ScalarValue=16 MapEntry=56
```

That is the accounting the waves act on. Read against RP-1/RP-3/RP-4 it says
where the multiplier is: 160,001 Elements for 32,000 four-field JSON records
(one envelope per record plus one per field, each owning a block for an `attrs`
array it never uses), 96,000 `AttributeMeta` allocations in the XML lane whose
only job is to carry an autotyped kind's NAME, and the CX lane carrying the same
data in 32,000 `MapNode`s at 55% of the JSON lane's live bytes with scalar
boxing held constant (the ledger's 300k corpora put the same comparison at
57%) — the carrier shape alone, measured.
