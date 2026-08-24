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

### R9.3 SUPERSEDED (owner, 2026-08-21): Opus 5 through release

Owner directive, replacing R9.3's model provision verbatim: **"we'll use
Opus 5 through release unless there's a good reason not to."** The remaining
cut path — every item 1–4 above, plus #914 (TI-1) and anything else landing
before the tag — runs in **Opus 5**. The single-dedicated-session and
ordering provisions of R9.3 are unaffected; only the model changes.

Recorded because R9.3 was an explicit owner-ruled exception to the
Opus-bulk-impl policy, so setting it aside needs to be equally explicit and
equally findable. Provenance for this session, stated plainly: ASP-3 (#909),
DGF-1 (#912), TA-1 (#911), D913-1 + D913-1a and the EDL-1 gate (#913) all
landed under **Fable 5**; the TI-1 ruling (#914,
`ledger/rulings_2026_08_21_table_image.md`) and everything after it are
**Opus 5** — the switch happened mid-session, which the standing policy
otherwise forbids, and is on the record here rather than left implicit.

"Unless there's a good reason not to" named one standing carve-out — the
**vgc / GC-soundness deep-debugging lineage** (#57/#58/#63/#145), Fable-5-only
on recorded evidence. Owner, same day: **the vgc work is DEFERRED past
v0.16.0.** So the carve-out is DORMANT for this release, not competing with
the directive: no vgc item is on the cut path, and **Opus 5 is unconditional
through the tag**. The Fable-5 evidence for that lineage is not withdrawn — it
simply has nothing to apply to before v0.16.0, and revives whenever the vgc
work is scheduled (a leg wanting Fable back asks for it by name, then).

Out of scope for the session: #804 (post-cut), #834 (linux, upstream),
anything on main.

## Cut-boundary rulings (owner "1a 2a 3a", 2026-08-19, in-session)

RULED: RW-CUT.1 — darwin-only cut (1a): v0.16.0 ships the darwin artifacts
exactly as v0.14/v0.15 did; the #520 dockerized Linux lane stays unmerged
and #741's Linux post-publish half re-scopes to the #520 landing (noted on
both issues). RULED: RW-CUT.2 — ORIEL stays PRIVATE at this cut (2a): the
publish.sh exclusion + forbidden-path guard stand; exposure remains a later
owner allowlist ruling. RULED: RW-CUT.3 — the ruled process verbatim (3a):
Phase 1 on release-cut/v0.16.0 + the cut PR for owner review; Phase 2 (tag,
mirror publish, GitHub release, post-publish verification) only after the
merge, with its own owner go.
