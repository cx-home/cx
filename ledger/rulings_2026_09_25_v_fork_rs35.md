# RS-35 — the V fork under the zero-attribution rule: strip the fork's own range only (owner: Letter 2 = (a), 2026-09-25)

**Status: RULED (owner, 2026-09-25 ~12:4xZ, in session, on
[#1591](https://github.com/cx-home/cx-private/issues/1591)).** It applies RS-33
([rulings_2026_09_24_no_ai_attribution_rs33.md](rulings_2026_09_24_no_ai_attribution_rs33.md))
to the one repository whose history is mostly not ours: the permanent V fork, `cx-home/v`, branch
`cx-patches-0.18`.

## The owner's word, verbatim

"a" — Letter 2 = (a). The option, verbatim:

> strip the fork's own commits only (the range from the upstream merge-base to the branch tip); the
> attribution gate reads the fork with that merge-base as its base; upstream's messages stay
> upstream's. Long-term: cx-home/v stays sha-compatible with vlang/v (upstream syncs fast-forward,
> the patches rebase cleanly); RS-33 is complete for everything we wrote; text we did not write
> remains in a repository GitHub already labels as a fork. The `v-fork=` rows, the gitlinks and the
> register's patch shas move once.

## The measurement (the integrator's, 2026-09-25; cited as measured, not inferred)

- `cx-home/v`'s own `master` is STALE; the upstream is the real `https://github.com/vlang/v.git`
  `master`.
- The merge-base of vlang/v `master` and `cx-home/v` `cx-patches-0.18` is
  `7647ce1c6fad63b5578bc07883139906de74b2f8` (2026-07-13, upstream; the `upstream-base=` of
  `scripts/v_fork_register.cxd`).
- The fork's own range, `7647ce1c6..cx-patches-0.18`, is 99 linear commits, 0 merges, 31 attribution
  hits. The branch's other 72 hits are in upstream vlang/v commits below the merge-base, and they stay.

## The rule

1. The fork's history is rewritten over `<upstream merge-base>..cx-patches-0.18` and nowhere else
   (`git filter-repo --refs <base>..cx-patches-0.18`, message text only — `scripts/strip_attribution.cx`
   with `refs:v=<base>..cx-patches-0.18`). An upstream commit is never rewritten: after the strip the
   merge-base is still `7647ce1c6`, and every upstream sha the fork carries is still upstream's.
2. The fork's attribution gate reads the fork with that merge-base as its base (`BASE=<merge-base>`),
   never the branch's whole history.
3. `master` and every other ref of `cx-home/v` are left as they are; only `cx-patches-0.18` is
   force-pushed (with a lease on its pre-strip tip).
4. The pins that name the fork move ONCE, in the same pass: every `v-fork=` row, every `third_party/v`
   gitlink, and the register's patch shas (each mapped through the strip's `.map`). A later
   re-sync onto newer upstream rebases the patches as `scripts/v_fork_register.cxd` already describes.
