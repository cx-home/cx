# Ruling LIM-2 (2026-08-20) — no blanket caps; amplification is a gated property (#876 second half, owner "2a")

RULED: the engine adds NO attribute-count / body-size / parse-time /
canonical-size caps. Rationale ratified: after the structural guards
(LIM-1 table), no amplification vector remains — every residual cost is
linear in input bytes the caller already holds. Two additions land with
the ruling instead of caps:

1. **The amplification gate** — vcx/tests/parse_amplification_test.v
   pins the linearity claim forever: median-of-5 timing at N vs 4N bytes
   across six adversarial shapes (bound 12x where linear=4x and
   quadratic>=16x; calibrated 2026-08-20 — -gc none measured 1.9-2.3x
   per byte-doubling, i.e. linear, while single -gc e samples swing 2x)
   plus a hard node-amplification bound. A future superlinear regression
   goes red where a fixed cap would have stayed silent.
2. **ParseLimits.max_input_bytes** — the one embedding-side option
   (parse_limited; constant default 0 = unbounded; never an environment
   variable): a typed refusal instead of an OOM for embedders who want
   the engine to hold their boundary bound. First finding of the gate's
   calibration run: an apparent 9x superlinearity that -gc none probing
   attributed to sampling noise — the min-of-3 statistic was the defect,
   not the parser; the gate ships median-of-5.

#876 closes: LIM-1 (spec home) + LIM-2 (this ruling) cover both halves.
