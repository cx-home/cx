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
anything found en route.

## AMENDMENT (same day, owner ruled "a" on the version question)

The campaign was posed as **v0.16.1**. It is **v0.17.0**, on a new
`release/0.17` line branch. VC-1..VC-5 below are UNCHANGED — they rule
#939, #940, the spec authorization, the exemptions, and the autonomy
boundary, none of which the version touches.

**Owner's question that forced it, verbatim:** *"but then we don't have a
branch of work done that matches a tag. is that the best long term cx
process?"* — and the answer that followed: the docket carries three
genuine features (#874 editor distribution, #891 shared-open protection,
#907 CATALOGUE replay) plus two behavior changes, so a PATCH version
would misdescribe it. Ruled: honest semver — MINOR for features
pre-1.0, PATCH for fixes only.

The branch convention moved with it (owner ruled "a"): a branch tracks a
minor LINE, named `release/<major>.<minor>` — the line branch is what
lets a hotfix land after development moves on, and the old
`release/X.Y.0` spelling read as though the branch were the release.
`release/0.16.0` renamed to `release/0.16`; `release/0.17` cut from
662cf1957. `RELEASE_PROCESS.md` had documented a `release/<X.Y.Z>`
per-patch model the scripts never implemented — that contradiction is
what surfaced the question, and it is trued in the same change.

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

---

# AMENDMENT 2 (2026-08-24) — VC-6, VC-7

**Status:** RULED by the owner — reply verbatim: **"1a 2a"** — against the
two questions posed mid-campaign, after #939 closed and wave 2 integrated.
Recorded BEFORE the work per R6.1/R4.2.

## VC-6 (1a) — #940: the ten unimplemented `cx:` module functions are IMPLEMENTED

The question: *"How do the ten go? (a) Implement them — the spec is the
only truth and it already says these exist; ten missing functions is the
implementation owing the spec, not the reverse. (b) Amend
`modules/cx.md` to describe what exists — truing spec to a shortfall.
(c) Split — implement the six pure ones, leave `cx:eval`/`cx:render` for
a scoped capability pass."* Ruled (a).

This SUPERSEDES the `cx:eval` half of VC-2. VC-2 authorized retiring the
registration on the stated premise that implementing it "would need spec
text first"; the premise is inverted — `spec/03-approved/modules/cx.md`
§2.2 carries the signature and purity, §3 carries four subsections of
sandbox semantics (CXER4113, CXER4114, depth 8), `cx:render` is defined
there as sugar over `cx:eval`, and `core/code.md` §6.4.4 has `[?eval]`
reusing its sandbox and sharing its recursion counter. The `sort-by` half
of VC-2 stands as landed (zero spec footprint, retired @ c8abd87f9).

The ten, measured absent at spec arity and absent from
`vcx/code/stdlib_cx.v`'s dispatch table: `cx:eval`, `cx:render`,
`cx:validate`, `cx:anchors`, `cx:ids`, `cx:references`,
`cx:resolve-includes`, `cx:strip-comments`, `cx:strip-attrs`,
`cx:pretty-print`.

## VC-7 (2a) — #945: gate 28.5 is REBUILT as two rows

The question: *"(a) Rebuild as two rows — `xpath_31_parity.cxd`'s 23
cases currently run nowhere; a CX-side lane is real new signal and needs
no Docker, Saxon cross-check stays manual. Cost: new spec text, which is
why it needs your authorization rather than VC-3. (b) Retire — deletes
the only external-compliance check and 23 fixtures of intent. (c) Leave
as landed."* Ruled (a).

This is the NAMED AUTHORIZATION for the new spec text VC-3 excludes:
`cxpath_alignment.md`, the normative reference gate 28.5 cites and which
does not exist in the tree. The authorization covers authoring that
document and re-deriving the 23 expected outputs against one oracle. It
does NOT carry graduation: G3 approval to place spec text in
`spec/03-approved/` remains owner-only, so the document lands in
`spec/02-working/` and graduation is proposed separately.

Commits under both rulings carry their `RULED: VC-6` / `RULED: VC-7`
token (spec-freeze R4.1).

---

# AMENDMENT 3 (2026-08-24) — VC-8, VC-9

**Status:** RULED by the owner — reply verbatim: **"3a 4a"** — against the
two questions posed after VC-6/VC-7 went to work. Recorded BEFORE the work
per R6.1/R4.2.

## VC-8 (3a) — #907: catalogue preflight SPLITS by ownership

The question: *"(a) Split it — compatibility report for products, replay
for the field registry. It matches the lean recorded in the issue. A price
a merchant set is not a modification of something the vendor shipped, so
replaying it asserts an ownership the vendor does not have; but the field
registry is genuinely vendor-shipped, so registry edits replay like
layout. Cost: two code paths instead of one. (b) Replay everything as
layout-equivalent. (c) Compatibility report for everything, no replay."*
Ruled (a).

This answers the design question #905 raised and #907 carried unresolved:
domain data IS a fourth kind of thing. Tenant-owned catalogue CONTENT
(products, prices, stock, copy, retirement) is not vendor-document
customization, so `/fleet/preflight` owes it a COMPATIBILITY REPORT — which
of this tenant's products reference categories, fields or skus the
candidate no longer defines — and does not replay it. The FIELD REGISTRY is
vendor-shipped, so registry edits replay exactly as layout commands do.

## VC-9 (4a) — #874: editor-tooling distribution STAYS PARKED

The question: *"(a) Leave parked, close nothing — every user builds from
source today, so the copy-from-repo flow is the right trade, and publishing
to Marketplace/OpenVSX is an outward-facing irreversible step besides.
(b) Do items 2 and 3 only (Neovim plugin-root layout, nvim-treesitter
registration) — in-repo and reversible. (c) Do all four including
Marketplace publishing."* Ruled (a).

#874 stays OPEN and PARKED at `prio:high`, not closed and not partially
executed. Its own scope note makes item 4 depend on a binary install
channel that does not exist yet, and CX has no external users, so the
copy-from-repo flow remains the correct trade. Re-confirmed parked in this
campaign so a later session does not re-litigate it.

Commits under VC-8 carry a `RULED: VC-8` token (spec-freeze R4.1). VC-9
authorizes no work.

## CORRECTION to VC-9 (same day, measured after the ruling)

The VC-9 question was posed on a STALE reading of #874 and the recorded
reasoning is partly false. Correcting the record rather than the ruling:
the outcome (stay parked, open, not closed) is unchanged and better
supported, but not for the reason given.

Measured at `8c6f30ad3`: #874's in-repo half **already landed** on
2026-08-20 at `c63b1e2f4`. `tooling/neovim/` is a real plugin root
(`lua/cx/` + `plugin/`, native `vim.lsp.config`, `nvim-lspconfig` dropped,
the copy-file flow retired); `tooling/tree-sitter-cx/REGISTRY.md` carries
the nvim-treesitter and mason payloads verbatim; `scripts/release.sh`
Phase 7 packages and publishes the VS Code extension, skipping loudly
without `VSCE_PAT`/`OVSX_PAT`. So the VC-9 statement that items 2 and 3
"did not land, deliberately" is wrong — item 2 is done and item 3 is
prepared.

What remains on #874 is credential-gated or external-repo work: the
Marketplace/Open VSX publish (owner-minted tokens, fires at the cut), the
nvim-treesitter PR, and the mason entry — the latter two submitting only
after a release publishes the public mirror. None of it is work a campaign
session can perform, which is the honest basis for parking.

The mechanism that produced the error is worth recording because it will
recur: #874's BODY still describes the 08-20 gaps as open and the issue
still carries `prio:high`, so a docket sweep reads a stale body, sees a
high-priority label, and re-parks it. The 2026-08-20 comment on the issue
was accurate and the sweep did not read it. Reading issue COMMENTS, not
only bodies, before posing an owner question is the correction.

---

# AMENDMENT 4 (2026-08-24) — VC-10

**Status:** RULED by the owner — reply verbatim: **"5a just make sure this
is gated with each release"** — against the #874 disposition question posed
after the VC-9 correction. Recorded BEFORE the work per R6.1/R4.2.

## VC-10 (5a + a gating instruction) — #874 CLOSES; the remainder becomes a RELEASE GATE

The question: *"(a) Close #874; track the remainder as a release-checklist
item plus one prio:low issue for the two external PRs — the enhancement it
describes is built. What is left is not an enhancement, it is a publish step
you trigger and two outbound PRs gated on a release. (b) Keep it open,
rewrite the body, drop to prio:low. (c) Leave as-is."* Ruled (a), with the
added instruction that the remainder **is gated with each release**.

So the disposition is three parts:

1. #874 CLOSES. Its engineering scope landed 2026-08-20 at `c63b1e2f4`
   (see the VC-9 correction above).
2. The two external-repo submissions (nvim-treesitter parser registry,
   mason package entry — payloads prepared verbatim in
   `tooling/tree-sitter-cx/REGISTRY.md`) become their own `prio:low` issue.
3. **The remainder is GATED AT EACH RELEASE, not tracked as a checklist
   line.** The owner's instruction is explicit: "just make sure this is
   gated with each release." A loud skip is NOT a gate — `scripts/release.sh`
   Phase 7 already skips loudly when `VSCE_PAT`/`OVSX_PAT` are absent, and
   that is precisely the state that let this obligation go unnoticed for
   four days. The gate must make skipping a DECISION rather than a default:
   the release path fails unless the editor-distribution obligations are
   either satisfied or explicitly acknowledged, with the acknowledgement
   recorded in the release log.

Commits under this carry a `RULED: VC-10` token (spec-freeze R4.1).
