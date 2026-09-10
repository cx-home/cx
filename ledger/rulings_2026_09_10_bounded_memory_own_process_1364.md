# RULED: 1364-a — the cmp-005 bounded-memory gauge runs in a process of its OWN

**Fable, 2026-09-10 08:50Z, under the owner's delegation.** Letter (a) of the
three posted on #1364; (b) Makefile-level isolation and (c) a white-box
retained-bytes gauge rejected there.

## What was wrong

`assert_streaming_write_bounded_memory` (conformance_run.v) snapped
`runtime.used_memory()` — PROCESS-wide — after `gc_collect()` before and after
its stress loop and graded their ratio. The runner's default (the #795 batch)
runs every document suite in one process, so the denominator was whatever
~100 suites had left on the heap: 24.7 MB alone, 422.5 MB inside the gate,
and the same code answered FAIL (1.603), PASS, PASS on three gates. The loop
itself is bounded (~1.0 over 100 extra 65536-row groups) — the verdict was not
a function of the code under test.

## What changed

- The loop moved verbatim into `bounded_memory_probe`; the runner re-executes
  itself (`os.executable()`, alive for a `v run`) with
  `--bounded-memory-probe <schema-file> <n_rows> <rows_per_group> <warmup>
  <stress>`; the child prints `baseline stress`, the parent divides, prints
  the #1358-g measurement line every run (now with the child's baseline and
  the words "own process"), and grades the fixture's cap.
- The fixture `cmp-005-fd-streaming-write-bounded-memory`, its four tokens and
  its 1.50 cap are UNCHANGED — the gauge measured 0.977–1.072 alone over ten
  runs and 1.078 in the first own-process run (baseline 23.2 MB).
- No spec edit. `conformance/*.cxd` untouched.

## Why (a)

The fixture's claim is black-box — a 100M-row streaming write in bounded
PROCESS memory — so the honest measurement is a process that runs only that
loop. (b) would put the property in target wiring, where the next inline
union target silently reintroduces the defect. (c) measures the mechanism,
not the claim, and passes a writer whose retention hides in a callee; fine as
an extra assertion, wrong as the gauge.
