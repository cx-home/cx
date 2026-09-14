# Ruling 2026-09-14 — #1449: the profile gate's serial tail is built inside the -j block and graded at two compositions concurrently (1449-a)

Recorded by the integrator under the owner's letter of 2026-09-14 accepting the measured pace
changes, as the single row **1449-a**. The decision is the issue's measured phase table plus its
three asks; nothing beyond them is decided here.

## The measurement the decision rests on (quoted from #1449)

Measured on the post-merge run on `44f328b0e` (2026-09-14 02:16:19Z–03:01:48Z, 45.5 min,
`vcx/target/gate-prev-20260914-021619.log`):

| phase | wall time |
|---|---|
| `build-vcx` + the 73 TEST_TARGETS at -j12 (tail: the fixtures grader, 19.5 min — #1448) | 02:16 → 02:43 = **27 min** |
| `test-profile-gate`, serial, after the block drained | 02:43 → 03:01 = **18.5 min** |

Inside the tail: the profile matrix builds (`target/profiles/{data,embed,cli}/cx`, the embed
`libcx`), then `profile_gate[cli]` (4,859 graded through the cli binary, 47 binary-inexpressible)
and `profile_gate[embed]` (4,079 graded, nine packs off) — one after the other.

## What stands, and why

The gate is filtered out of the -j block on purpose (`Makefile` ~1597): it gets "the same quiet
context" the serial retries get, so a load-induced binary-probe failure does not fail it. **That
reason stands for the GRADING and is kept.** It does not extend to the three profile BUILDS, which
are ordinary V compiles, and it does not separate the two compositions from each other: they
contend on nothing but CPU.

## The decision, as one row

| # | Row | Where it lands |
|---|---|---|
| 1449-a | (1) The three profile builds and the embed `libcx` become ordinary targets the -j block runs, depending on `build-vcx` only, each carrying the `build-vcx` relink guard so the serial tail finds them built and does not rebuild. (2) The cli and embed gradings run **concurrently** inside the serial tail — two processes started together, both waited on, both exit codes honored; each composition's output is buffered to its own file and replayed in a fixed order so the interleave stays readable. (3) The census lines `profile_gate[cli] OK — …` / `profile_gate[embed] OK — …` keep their shape byte-for-byte. Nothing changes in what is graded, what is skipped, or the binary-probe semantics. | `Makefile`, `vcx/Makefile` |

**Expected payoff (from the issue):** the tail drops from 18.5 min to the longer of the two
gradings, roughly 8–9 min, every run.

**Not decided here:** any change to the graded or skipped sets, to the binary-probe semantics, or
to the `-prod` profile recipes the release scripts drive. Related: #1448 (the parallel block's own
tail).
