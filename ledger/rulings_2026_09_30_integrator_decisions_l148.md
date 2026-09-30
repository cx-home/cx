# Integrator decision 2026-09-30 — Letter 148, taken under DELEG-3: the clock-free half of `time` is available at every profile

**Status: RULED BY DELEGATION (the owner, 2026-09-30 ~04:0xZ, DELEG-3; the letter line is in
`_gate_evidence/pipeline_batchc/RESULTS.md` on bug batch C's graded sha `12a4bfc5a`, posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 12:3xZ with this taking; the owner may
reverse it on reading). SHIP-1, FIX-1, CXF-8, RS-38, DURSC-1, HTTPTO-1, the profile composition of
the four builds (`cx primer` §3).**

## The owner's words, verbatim

"no decisions for at least 8hrs. pause if limits are hit and resume when lifted. make best long term
decisions for cx. no deferring. no partial work. only complete, sound, performant implementation that
follows the expectations"

## TIMEP-1 — `parse-duration` and the pure duration functions are in every profile; only the clock reads stay behind the `clock` capability and the cli/platform builds (L148 = (a); #1586)

Measured on an embed binary: `connector:validate` of a declaration carrying a quoted duration such as
`'30s'` answers CXER6300, because the `parse-duration` reader is absent at the embed profile — the
whole `time` module is composed out with the clock. A duration parser has no effect: it reads text to
the duration scalar (DURSC-1) and nothing else. Taken: `time` splits by effect, as `http` split into
`cx-stdlib/http-client` and `cx-platform/http` — the clock-free half (`parse-duration`, the
`duration-*` constructors and arithmetic, the business-calendar's pure open-time functions of WF-24)
composes into every profile, the clock reads (`now`, `sleep`'s wall clock) stay behind `clock` and
the profiles that carry it; the row in `registry/modules.cxd` names the half (`half=`), the profile
gate's inventory proves each build carries the pure half, fixture first (`connector:validate` with a
duration at the embed profile; `[$time:parse-duration '30s']` at every build). Rejected: (b) leaving
embed without it and documenting the gap — a checker that is pure by contract would depend on the
clock pack for a parse; (c) a second duration parser inside connector — two readers of one literal,
the class SINCE-1 refused. One small opus round on cx-core-code (the profile composition and the
`time` module), queued.
