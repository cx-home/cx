# Integrator decision 2026-09-16 ~11:30Z — the fmt-sweep ratchet moves one way, and a decline fixed under it needs no spec sentence (RULED: FMT-1)

Under INT-16 (each of the bug tail is in v0.18, fixture first) and ORD-1 (Ring 0 first). Both fmt declines
(#1389, #1436) were split out of the Ring 0 batch because their fixes move a gate-enforced expectation — the
Makefile's `FMT_SWEEP_MAX_DECLINED`. This row says what moving it means, so the fix carries the measurement
with it instead of asking for a ruling per file.

| Id | Decision |
|---|---|
| **FMT-1** | **(integrator, 2026-09-16 ~11:30Z, under INT-16)** `fmt-sweep-gate`'s ratchet `FMT_SWEEP_MAX_DECLINED` (Makefile) is a CEILING on the files `cx fmt` declines, and it moves in ONE direction: a fix that makes fmt accept a shape LOWERS it to the measured count in the same commit as the fix (the sweep's own count line is the evidence, quoted in the commit body); it never rises except by an owner ruling. A decline fixed under this row needs no spec sentence — fmt's contract (every file the parser accepts, fmt formats) is already the spec's; the Makefile literal is the measurement, not the rule. |

## Batch

Batch — the two fmt declines, branch `impl/cx-F-fmt-declines`, decisions INT-16, ORD-1 and BATCH-1 (each bug its
own `test(N)`/`fix(N)` commit pair, one pipeline, one merge):

| issue | title (short) |
|---|---|
| #1436 | `cx fmt` declines a file whose interior comments the layout cannot place (CXER0301) |
| #1389 | `cx fmt` declines a namespaced call over a parenthesized group |
