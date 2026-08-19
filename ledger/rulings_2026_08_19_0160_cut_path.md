# Rulings 2026-08-19 — the v0.16.0 cut path (owner: "1a 2b, all in Fable 5 through cut")

Context: #787 merged to release/0.16.0 @ 3074002c (pure fast-forward, gated
tree). The owner ruled the remaining path to the v0.16.0 cut.

## R9.1 — the cut does NOT wait for Gate 15 (#804)

Owner: 1a. The gate is honestly red ([?map] 129.2 MB/s vs the 200 floor,
one criterion left, levers named in the issue); it is a perf floor, not a
correctness defect. The cut ships with the gate red and the measured
numbers on record; #804 continues post-cut. Blocking the cut (b) and
time-boxing (c) were REJECTED.

## R9.2 — composition track #865–#867 lands BEFORE the cut

Owner: 2b. The composition track (design ruled R8.1–R8.11) is in the
0.16.0 release: the product.rating deriver exemplar rides #865, the
cohesion instrument rides #867. This also resolves ruling 2b's disjunction
for #869 ("at the cut or with #867") — both arrive together. Per-wave spec
authorization remains with the owner (lettered questions at each wave
boundary, per the standing composition-track ruling).

## R9.3 — one session, Fable 5, through the cut

Owner directive. The remaining cut path executes in a SINGLE dedicated
Fable 5 session on release/0.16.0 (owner-ruled exception to the
Opus-bulk-impl model policy for this leg). Order:

1. **#826** (cut-blocking docs): the seven concept arcs + Choosing-a-ring,
   retire 09-concepts, the 08-tooling split, ORIEL guide nav integration.
2. **#741** (cut-blocking tooling): per-profile installer assets verified
   at the cut.
3. **#865–#867** composition track impl landings under R8.1–R8.11, spec
   auth per-wave.
4. **The cut**: #869 ORIEL promotion to spec/03-approved/xap/demos/ with
   the six instruments as its CI lane; #752 I4 profile tarballs; VERSION
   0.15.0 → 0.16.0 (derive everywhere); full `make test-vcx` GATE-RC=0;
   tag and release mechanics per the v0.14/v0.15 cut records. Public
   mirror exposure of ORIEL stays a SEPARATE owner allowlist decision —
   not part of this session's remit.

Out of scope for the session: #804 (post-cut), #834 (linux, upstream),
anything on main.
