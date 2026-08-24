# Ruling 2026-08-24 — the v0.16.1 campaign charter (VC-1..VC-5)

**Status:** RULED by the owner — reply verbatim: **"1a 2a 3a 4a 5b"** —
against the five questions posed at the end of the v0.16.0 cut session,
2026-08-24. Recorded BEFORE the work per R6.1/R4.2.

**Owner's framing of the campaign, verbatim:** *"looks like we need a
v0.16.1 campaign to take care of 700, 874, 891, and other issues
(especially bugs) 907 and above, plus any issues that surface during the
campaign. will be done with opus 5 autonomously."*

**Docket as posed and accepted:** #700, #874, #891, #907, #939, #940,
#943, #944, #945, #946, #947, #948, #949, #950, #951, #953, #954, plus
anything found en route. Work continues on `release/0.16.0`; the v0.16.1
tag cuts from it (#666 topology — no new branch).

---

## VC-1 (1a) — #939: CX commits to the fork permanently

The question: *"(a) commit to the fork permanently (retire
check-v-upstream's expectation, document the maintenance posture) or (b)
keep pursuing upstream."* Ruled (a).

vlang/v#27178 and #27179 were closed upstream without merging, so the
patches are permanent. `check-v-upstream` stops treating an unmerged
patch as a pending state to be resolved and becomes what it now is: an
inventory of the fork's deliberate divergence, green while the divergence
is recorded and red only when the fork carries an UNDOCUMENTED patch.
The maintenance posture is written down where a future maintainer meets
it. #939 closes on that landing.

## VC-2 (2a) — #940: the phantom registrations are RETIRED

The question: *"(a) retire the phantom registrations (cx:eval, sort-by)
or (b) implement both."* Ruled (a).

Both are registered and LSP-documented but answer "no callable"; three
separate sessions have now lost debugging time to the absence they
produce (the third, scripts/lang_stats.cx, 2026-08-24). Nothing in the
tree calls either. Retirement removes surface that never existed in fact;
implementing would add real surface — `sort-by` genuine work, `cx:eval`
carrying capability implications that would need spec text first — for a
need no consumer has stated. A registration whose callable does not exist
is the silent-acceptance class (#793) wearing a documentation costume.

## VC-3 (3a) — narrowly-named mechanical spec truings are PRE-AUTHORIZED

The question: *"(a) Pre-authorize narrowly-named mechanical truings in
the charter (Opus may execute, RULED-token discipline) or (b) queue all
spec text for you/Fable."* Ruled (a).

**Scope of the authorization — MECHANICAL truings only, each named:**
stale `.py` filename mentions in approved spec prose
(`xap_feature_distribution_market.md:748`, `xap_identity_model.md:1076`,
`process/readiness-rubric.md:199` + `:230`,
`process/spec-authoring-guide.md:53,63`, `core/code.md:5794`); the
`core/code.md:93` §1.3 fallback prose naming the pre-#926 flag order;
`conformance/gates.cxd:78` prose. A truing REPLACES a name or an ordering
that the shipped engine has already changed. It never adds, removes, or
reinterprets a clause. Anything beyond the named list — including any
clause #951 might need — stops and asks. Every such commit carries its
`RULED: VC-3` token (spec-freeze R4.1).

## VC-4 (4a) — #804 and #834 stay owner-exempt

The question: *"(a) #804/#834 stay owner-exempt as in BC-4, or (b) fold
them in."* Ruled (a). Carried forward unchanged from BC-4: the Gate 15
`[?map]` perf floor and the linux/Go-host vgc signal structural item are
outside this campaign and are not touched.

## VC-5 (5b) — autonomous to "ready to tag"; the cut itself waits for the owner

The question: *"(a) fully autonomous through the v0.16.1 tag incl.
publish, or (b) autonomous to 'ready to tag', you say go on the cut
itself."* Ruled (b).

The campaign runs unattended through the docket, the record pair, and the
review package. `scripts/release.sh v0.16.1` is NOT run without the
owner's word — the cut is the outward-facing step, and the v0.16.0 cut
demonstrated that four of its phases publish irreversibly.

---

## Standing constraints carried into this campaign

Unchanged and not re-litigated here: the four trust-break constraints
(per-file spec/ledger authorization beyond VC-3's named list; no issue
filed without the governing spec text quoted; every claim labeled
measured/inferred/spec-cited; no ledger entry in my own voice — the
owner's ruling verbatim, reasoning in commit messages). CX-only, no
Python for any tooling. Gates never piped. Explicit `model: opus` on
every spawned agent. Worktree agents hard-reset to the branch tip; every
agent's green is re-verified on the integrated tree.
