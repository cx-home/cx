# Ruling 2026-08-20 — the ux capability gets a spec + guide docs PRE-CUT (owner)

Context: during the v0.16.0 docs review the owner asked where the ux
capability is discussed. Sweep finding: nowhere public — zero `ux`
mentions across all guide sections and reference sources, and none in the
approved XAP spec prose (xap.md / fabric.md / xsp.md). Its only homes are
the 787 design tree (design/787/787-phase0-spec.md + wave packets) and
the promoted ORIEL reference estate (spec/03-approved/xap/demos/oriel/,
code not prose, private per RW-CUT.2).

## UX-1 — spec pre-cut, then documentation ("big miss but we caught it")

Owner, verbatim intent: "yes we should have a spec pre-cut and
documentation." Option (b)+(a) combined and accelerated: the ux
capability graduates to `spec/03-approved/xap/ux.md` BEFORE the v0.16.0
cut, distilled from design/787/787-phase0-spec.md and the W23–W25 verb
registry; the guide then gains a Ring 2 concept arc DERIVED from that
spec. Sequencing note the owner corrected: the ux verb surface is landed
and stable (14/14 ACT verbs at W25, zero golden movement), and the
composition-track additions (R8.1–R8.11) also land pre-cut per R9.2 — so
nothing the spec pins is still moving.

Constraints carried:
- G3 stands: the spec text graduates only on explicit owner approval of
  the draft. The draft lands on release-cut/v0.16.0 for review with the
  rest of the cut batch.
- RW-CUT.2 stands: ORIEL stays private. The spec and the guide arc stand
  on generic examples; neither depends on ORIEL exposure, and the public
  mirror allowlist decision is untouched.
- The guide arc derives from the spec (spec is the only truth); the arc
  is written after the spec draft, not alongside it.
