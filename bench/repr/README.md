# bench/repr — the CXDM live-memory multiplier guard

The regression half of **RP-5** (`ledger/rulings_2026_09_02_cxdm_representation_1119.md`;
design §8 of `spec/02-working/cxdm_representation.md`). Wave **W1** of the
#1119 representation campaign, and the instrument every later wave is measured
by.

```
make repr-guard          # or: bench/repr/run.sh
CX_REPR_KEEP=1 bench/repr/run.sh     # keep the generated corpora for inspection
CX_REPR_RECORDS=8000 bench/repr/run.sh
```

In `TEST_TARGETS`, so it runs in every `make test`.

`make repr-guard` depends on `build-vcx`: the driver links the same vendored
RE2 static archive (`third_party/re2/obj/libre2.a`) the CLI does. Calling
`run.sh` directly in a fresh worktree therefore needs that archive and the
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

| lane | measured (2026-09-02) | bound | carrier under test |
|---|---|---|---|
| json | 17.271× | 19.20 | the `__cx_map__` envelope — an `Element` per field (RP-3 still to come) |
| xml | 7.942× | 9.40 | `Element` + `Attribute`; `AttributeMeta` retired by RP-4 |
| cx | 7.576–7.580× | 9.00 | `MapNode` / `MapEntry` |

Bounds are pinned at **measured + 1.0, then +5%** (see "what the instrument can
and cannot see" for what the +1.0 buys). They are a **ratchet**: every wave that
improves a lane re-pins its bound DOWNWARD in `run.sh` in the same commit that
lands the improvement, and records the new number here and on the #1119 wave
row. A bound is never raised without a ruling — the ratchet is not loosened to
accommodate a regression.

Under-shooting a bound by more than 20% prints a re-pin NOTE and does **not**
fail. RP-5 makes exceedance the failure and the downward re-pin a wave-exit
obligation; failing on an improvement would red an unrelated `make test` before
the campaign's own wave could re-pin.

Red-proven at landing: `BOUND_xml=9.00` produces
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
the corpora are reproduced on demand instead of committed, and `run.sh` deletes
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

`-prod` is the build the guard uses, for the reason gates 14/15/16 carry it
(#835): the driver compiles the `cx` module as SOURCE, so a dev build would be
measuring a build CX does not ship — and the campaign's other half (peak RSS ≤
8× input, RP-5(a)(i)) is measured on the shipped `-prod` `cx` binary.

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
