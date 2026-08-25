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

---

# AMENDMENT 5 (2026-08-24) — VC-11

**Status:** RULED by the owner — reply verbatim: **"6a"** — against the two
spec gaps VC-6's implementation surfaced. Recorded BEFORE the work per
R6.1/R4.2. This is the **G3 authorization** for approved-tier spec text.

## VC-11 (6a) — the two undefined `cx:` contracts are DEFINED to match what shipped

The question: *"(a) Authorize the two sentences now, written to match what
shipped — the implementations are fixtured and the readings are defensible;
the alternative is two approved functions whose behavior is defined only by
their implementation, which is precisely the drift this campaign keeps
finding. Cost: approved-tier spec, so it needs your G3. (b) Leave spec
silent; SPEC-FINDINGS §AR stays the record. (c) Change the implementation
first."* Ruled (a).

Both gaps were recorded in `conformance/stdlib/SPEC-FINDINGS.md` §AR rather
than resolved, because VC-6 authorized implementation only:

1. **`cx:strip-attrs`' "name-pattern" was undefined.** `spec/modules/cx.md`
   §6 assigns `CXER4115` to an "invalid name-pattern"; nothing said what a
   name-pattern is. Shipped as the single-segment name GLOB the engine
   already carries (`stdlib_path.v match_one_seg`, shared with `io:glob` and
   `bus.md` head-name patterns) — deliberately NOT the RE2 `pattern=` that
   schema/validate use. The fork mattered: had spec later said RE2, shipped
   behavior would have changed under anyone who adopted the glob.
2. **`cx:references`' map keys were unnamed.** §2.2 typed the return
   `[sequence map]` and stopped. Shipped as `{attr, kind, path, ref,
   resolved}` in canonical sorted order, `kind` enumerating all four grammar
   reference productions across cxdm.md §4's two disjoint namespaces.

The authorization covers **these two definitions in
`spec/03-approved/modules/cx.md` only**, written to describe the shipped and
fixtured behavior. It is not a licence to edit approved spec more broadly:
anything else still stops and asks.

Commits carry a `RULED: VC-11` token (spec-freeze R4.1).

---

# AMENDMENT 6 (2026-08-24) — VC-12

**Status:** RULED by the owner — reply verbatim: **"8a"** — against the
question of what to do with three stale agent worktrees carrying unverified
ruled work. Recorded BEFORE the work per R6.1/R4.2. This session also took
ownership of all cx-private worktrees by the owner's instruction the same
day.

## VC-12 (8a) — the three unverified branches are TRACKED, not audited and not deleted

The question: *"(a) Leave them; file one tracking issue naming all three
branches + SHAs — cheap, makes them recoverable, defers an expensive audit
out of a cut window, and nothing is decaying. (b) Verify all three now — 11
commits at roughly the cost of the 4d29a8519 check each. (c) Delete them on
the 'it looks landed' signal."* Ruled (a).

(c) was the live hazard, not a straw option: a peer session had already
proposed deleting `worktree-agent-a32908394a6249253` on the signal that "all
25 cd-sq-* defs are already upstream". Verifying it properly took checking
354 files and 115 defs, of which FIVE were absent — two `dbg-` probes and
three defs the tree itself documents as deliberately retired
(`stdlib/diagram.cx:1981`). The conclusion held, but the reasoning that
reached it would not have.

Worktrees pruned under this ownership, all provably landed (commits
cherry-picked onto release/0.17 and verified by the integrated matrix):
`agent-a2c6a7dd0e4a333f2`, `agent-a59f37e3043a67d52`,
`agent-a842c97e3b82a13ec`, `agent-a0cab674d723f0431`,
`agent-a58afa828f64e3734`. Branches kept as provenance.

Worktrees PRESERVED and not to be pruned: `busy-maxwell-6e39ce` (#962) and
`objective-lovelace-b5cd8e` (#961) — live shipped defects whose fixes are
not yet ported.


---

# AMENDMENT 7 (2026-08-24) — VC-13

**Status:** RULED by the owner — reply verbatim: **"961/962 port into this
campaign"** — against the question of whether two adopted stranded fixes ride
v0.17.0 or the next line. Recorded BEFORE the work per R6.1/R4.2.

## VC-13 — #961 and #962 PORT INTO v0.17.0

The question: *"(a) Next campaign — file-only for now. Both are explicitly
UNVERIFIED off a base 1897 commits old, so they are genuine ports needing a
real read; landing them after the verdict invalidates it. (b) Port both now,
re-run the full matrix. (c) Port #962 only."* Ruled: port both, this
campaign — overriding the recommendation.

Both defects are LIVE in shipped v0.16.0 and reproduce on release/0.17
(measured this session):

- **#961** — the child axis is blind to a sequence grouping:
  `$bag/violation` returns **0** where `$bag//violation` returns 2. Violates
  `spec/03-approved/core/code.md:1010`, normative: "a step that works on one
  element works on a sequence of elements."
- **#962** — a raw V struct dump (`cx.Node(cx.CommentNode{…})`) leaks into
  program output where the data lane renders correctly. `ast.md:156` gives
  Comment exactly one CX spelling.

Consequences accepted with the ruling: the integrated matrix is re-run after
the ports land, and the ports are treated as PORTS — the source branches
(`claude/busy-maxwell-6e39ce` @ 84b469dc0, `claude/objective-lovelace-b5cd8e`
@ 1749e529f) are 1897 commits behind and their commits are marked UNVERIFIED,
so each change is read against the current engine rather than replayed.

Two traps carried from the handoff and not to be rediscovered: the node-set
arity half of busy-maxwell is ALREADY upstream as `node_set_query` and must
not be reapplied; and the naive #962 fix is WORSE than the defect, because a
line comment emitted inline swallows the following siblings and the closing
bracket on re-parse — the emitter newline handling travels with the fix.

The two worktrees stay until the ports land and are verified.

---

# AMENDMENT 8 (2026-08-24) — VC-14..VC-17

**Status:** RULED by the owner — reply verbatim: **"9a 10a 11a 12a"** plus
**"yes file the others and fix this campaign"** — against four decisions posed
after the integrated matrix, and the disposition of two findings VC-7
reported rather than fixed. Recorded BEFORE the work per R6.1/R4.2.

## VC-14 (9a + 10a) — #700's remainder is WAVE 2 on #700, and the lever is ONE TEST BINARY PER MODULE

9a: *"(a) Fold into #700 as wave 2 — the floor IS the root cause #700's own
body names, and wave 1 attacked the file count rather than the floor."*
Ruled (a). The remainder stays on #700 rather than becoming new issues.

10a: *"(a) One test binary per module, not per file — it attacks the floor
directly, 29 platform files become ~1 link instead of 29. (b) -usecache /
build-module reuse. (c) Keep consolidating."* Ruled (a).

Measured basis, from the integrated matrix at 5841ae6a0:

| lane | files | compile CPU-s | runtime s | ratio |
|---|---|---|---|---|
| `vcx/platform` | 29 | 16,028 | 40 | **402:1** |
| `vcx/tests` (post wave 1) | 57 | 15,154 | 524 | 29:1 |

Per-file compile is a FLOOR of ~700 s independent of content
(`cxparse_full_corpus_diff_test.v` 692 s compile / 0.4 s run;
`store_columnar_lineage_test.v` 724 s / 0.4 s). Consolidation reduces how
many files pay the floor — wave 1's delivered 4.51× — and cannot lower the
floor itself. (b) was declined on risk: `-usecache` carries this repo's
silent-miscompilation scar history (#151, #520, #855, #864).

`vcx/platform` was never in wave 1's scope (its brief was `vcx/tests/`) and
is now the largest lane.

## VC-15 (11a) — the `cx:eval-tree` swallow is FIXED in this campaign

*"(a) Fix it in this campaign — one line, the fix is already written, it is
the confirmed bounded instance of #955's second mechanism, and it currently
makes a shipped function lie about its own errors."* Ruled (a).

`vcx/code/eval.v:5161` propagates `!` out of a `?cx.Node` function, so a real
raised error collapses to `none` and the caller reports `no callable
"cx:eval-tree"`. VC-6 measured the class and enumerated all nine
option-returning `*_stdlib_builtin_env` hooks plus every `!`-propagation site
in eval.v: this is the ONLY site with the defect, so the fix closes mechanism
2 completely.

## VC-16 (12a) — the `$to-int` spec-prose contradiction is TRUED

*"(a) Authorize the truing; fix both examples to `[cast $v :int]` — it is
mechanical, matches VC-3's character exactly, and right now the spec teaches
a call that answers `no callable`."* Ruled (a).

`spec/03-approved/core/code.md` uses `[$to-int $v]` in two examples (~614,
~3153) while the same file states the `to-int` family "was deliberately not
adopted". Outside VC-3's named list, hence this named authorization. Scope:
those two examples only.

## VC-17 ("yes file the others and fix this campaign") — VC-7's two reported findings are FILED **and** FIXED

Both were reported rather than fixed because they sat outside VC-7's scope:

1. `[$cx:parse]` returns only the FIRST top-level node, so a document whose
   first item is a comment yields the comment and `/*` raises CXER0001 — while
   the V-side `cx.parse` returns `doc.elements` and sees everything.
2. The xpath corpus coverage gap VC-7's own re-tagging opened: cases 030–033
   were the corpus's only reach toward `count` / `string-length` / `contains`,
   and re-tagging them parity → divergence leaves those three unpinned.

Each gets an issue AND a fix in this campaign.

---

# AMENDMENT 9 (2026-08-24) — VC-18

**Status:** RULED by the owner — reply verbatim: **"700 gets completed in
0.17.0 but can be after this campaign."** Recorded BEFORE the work per
R6.1/R4.2.

## VC-18 — #700 wave 2 is IN the v0.17.0 release but OUT of this campaign

The question: *"Should the test-speed restructure happen now, or next
campaign? (a) Next campaign — it changes how every test binary is built, and
v0.17.0 already has ~50 commits plus two engine fixes landing. (b) Now."*
Ruled: neither as posed — **#700 completes in v0.17.0, but may land after
this campaign.**

Two consequences, both binding:

1. **#700 STAYS OPEN and GATES THE v0.17.0 TAG.** The release is not
   tag-ready while wave 2 is outstanding. This overrides the ordinary reading
   of VC-5 ("autonomous to ready-to-tag"): this campaign reaches ready-to-tag
   for its OWN docket, and the release itself still owes #700 wave 2. Any
   later session must not run `scripts/release.sh v0.17.0` with #700 open.
2. **Wave 2 is NOT this campaign's work.** Its scope is recorded on #700
   (VC-14): `vcx/platform` first (29 files, 16,028 compile CPU-s, 402:1),
   then `vcx/tests`, by the ruled lever — one test binary per MODULE, not per
   file.

So this campaign's exit state is: docket complete, record pair green, review
package prepared, and **one named outstanding release blocker** — #700 wave
2 — rather than a clean ready-to-tag.

---

# AMENDMENT 10 (2026-08-24) — VC-19

**Status:** RULED by the owner — reply verbatim: **"all these issues get
solved and sound in 0.17.0 period. I want a new session with fable 5 to
address and continue"** — against the question of what model to use for a
cluster of defects that kept fracturing each other. Recorded BEFORE the work
per R6.1/R4.2.

## VC-19 — the path/value and comment clusters are SETTLED IN v0.17.0, spec-first, by a Fable 5 session

The question posed: *"(a) Two partitions — path/value model, and comment
fidelity — with #961/#964/#966/#965 folding into the first and #962/#967 into
the second; #961 held rather than landed as a point fix. (b) One partition
covering everything including error surfacing. (c) Land the point fixes now
and partition afterward."* And the owner's framing: *"there is a whole set of
related problems that keep fracturing each other and thrashing rather than
settling on a sound spec and implementation. I want this resolved for good
and not pushed down the road or partially implemented."*

**Ruled: ALL of it is solved and sound IN v0.17.0. No deferral, no partial
implementation.** The work continues in a NEW session on **Fable 5**
(consistent with the standing model policy: Fable 5 for identity-critical
work, rulings, audits, and spec authoring — and there is no mid-session
model switching).

### Why the point-fix model failed, recorded so it is not repeated

Every defect in this cluster was found at a symptom site and ruled
individually, but each is a CELL in one unwritten table. The collisions that
followed:

- #961 widens the child axis, flipping a fixture whose own comment read "the
  fix aligns the descendant axis, it does not widen child" (#587-era scope).
- #966's obvious remedy (adding `.child` to `node_set_query`) would break the
  §6.2 field-accessor collapse SETTLED by #582–#587.
- #964, #965 and #961 are three faces of ONE clause, `code.md:1010`.
- #966 proved to be two mechanisms stacked, and the first filed diagnosis of
  it (mine) was wrong.
- `[$first $x/*]` shifts meaning at dozens of sites once a grouping becomes
  transparent.

The model exists only in fragments — `code.md:1010`'s distribution table,
`cxdm.md` §2.1/§2.2, #853's err-position table (DISCOVERED BY PROBING, never
specified), #587's settled-but-narrow decision. So each fix re-derived part of
the model locally and moved adjacent cells without anyone deciding they
should. That is the predictable outcome of specifying a total function
case-by-case.

### The model to use

The pattern that already works in this repo, twice: `similar.md` §3.2 pins the
FULL construct × kind matrix (all 40 cells); #853 produced a position table
with every row verified by a probe. Neither area thrashes.

So: **a total matrix, specified normatively; a conformance grid pinning every
cell; prior rulings reconciled IN WRITING; then one implementation pass; then
frozen — changing a cell later requires a ruling that names the cell.**

### Scope

**Cluster A — the path/value model.** #961, #964, #965, #966; reconcile
#582–#587 and #847 explicitly; the `[$first $x/*]` idiom sweep. Matrix axes:
operand kinds (element, sequence, grouping envelope, array, map, scalar, err,
absence) × operations (`/name`, `//name`, `/@attr`, `/*`, predicate, `count`,
`first`, the field-accessor collapse). Deliberately-opaque cells are cells and
get pinned too.

**Cluster B — comment fidelity across the three lanes.** #962, #967, and the
data-reader/program-reader divergence (unfiled). #967 is active user data
loss: `cx fmt` deletes every comment in every position while `cli.md:107`
calls it the lossless formatter that preserves comments.

**Cluster C — error surfacing.** #955's two mechanisms, and #965's
err-reads-as-truthy. The least specified of the three; the owner's ruling
covers it.

### Consequence for the in-flight work

The VC-13 worktree (`worktree-agent-acc56e4a435712c0a`, four commits on
`1c6a44a63`) is PRESERVED, not landed and not discarded: #962 and #964 are
verified, #961 is verified but is one cell of Cluster A's matrix. Whether
each rides the partition or lands ahead of it is the Fable 5 session's call
against the matrix, not a point decision.

v0.17.0 now has three named tag blockers: #700 wave 2 (VC-18), Cluster A, and
Cluster B/C. `scripts/release.sh v0.17.0` is not run while any is open.

---

# AMENDMENT 11 (2026-08-24) — VC-20

**Status:** RULED by the owner — reply verbatim: **"it occurs to me that we
really need to fix 700 first. we keep burning hours because you didn't get
that fixed in 16 or at the beginning of 17. that work should likely be done
in opus 5."** Recorded BEFORE the work per R6.1/R4.2.

## VC-20 — #700 wave 2 goes FIRST, on Opus 5; the clusters follow on Fable 5

This RESEQUENCES VC-19. VC-19 stands on substance — the path/value and
comment/error clusters are settled spec-first, in v0.17.0, by Fable 5 — but
its ORDER is wrong and #700 wave 2 precedes it.

**The reason is compounding cost.** The per-file compile floor is ~700 s
independent of file content, so every verification cycle in this campaign
cost roughly 25 minutes of wall time. Cluster A alone is a total-matrix
partition whose conformance grid will need many such cycles. Fixing the floor
first makes every subsequent cycle — for Clusters A, B and C, and for the
record pair — cheaper. Doing the clusters first pays the floor on every one
of their cycles and then fixes it afterwards.

**Model assignment:** #700 wave 2 is bulk implementation, so Opus 5 per the
standing policy. The clusters remain Fable 5 (identity-critical, spec
authoring, rulings). Return to Opus 5 after the clusters are solved and
sound.

**Owner's finding, recorded plainly:** this should have been fixed in v0.16.0
or at the start of v0.17.0, and was not. The diagnosis was AVAILABLE ON DAY
ONE of this campaign — the wave-1 brief quoted "96 lanes have compile > 50x
their own runtime" and "call_result_steps_test.v 309 s compile / 0.46 s run",
which is the floor stated outright. The brief scoped wave 1 to consolidating
`vcx/tests/`, and that brief was executed rather than questioned. Wave 1's
measured 4.51x was real but optimized the FILE COUNT while leaving the floor
intact. The failure was not the measurement; it was accepting the framing
that came with it.

**Revised blocker order for v0.17.0** (all three still block the tag):
  1. #700 wave 2 — Opus 5, FIRST
  2. Cluster A — path/value matrix — Fable 5
  3. Cluster B/C — comment fidelity + error surfacing — Fable 5

---

# AMENDMENT 12 (2026-08-24) — VC-21, VC-22

**Status:** RULED by the owner in a fresh audit session. Recorded BEFORE the
work per R6.1/R4.2. The session was opened with an explicit instruction to
audit the #700 wave-2 handoff independently rather than execute it, and the
audit found the handoff's central measurement wrong.

## VC-21 — VC-14's measured basis is STRUCK; the floor is ~25 CPU-s, not ~700 s

VC-14, VC-18 and VC-20 all rest on a per-file compile floor of "~700 s
independent of content". That number is wrong by roughly 25x and every
conclusion sized against it was mis-sized.

**Measured, this session, on the exact file VC-14 names, with the exact gate
flags** (`-cc cc -gc e -d cx_db_sqlite -d cx_db_redis -usecache`,
`vcx/tests/cxparse_full_corpus_diff_test.v`, warm cache, 3 runs each):

| context | per-test-binary wall |
|---|---|
| inside `devbox` (nix `clang-wrapper-21.1.8` + `cctools-binutils-darwin-wrapper`) | 53–54 s |
| outside `devbox` (`/usr/bin/cc`, Apple clang 21.0.0) | 13–14 s |

VC-14's own wave-1 table contradicts its floor table: 2,180,389 ms CPU
comptime over 57 files is 38 CPU-s/file, not 700 s. The `16,028` /
`15,154` "compile CPU-s" lane column is not reproducible in any unit
consistent with either figure.

**What survives:** the floor is real, content-independent, and is the
dominant cost. VC-14's ruled lever — one test binary per module, not per
file — stands on that. **What is struck:** the magnitudes, and every estimate
derived from them.

**Also struck as factually void:** VC-14 declined option (b), `-usecache`,
"on risk". `CX_CACHE ?= -usecache` has been the default for
`test-vcx-suite` / `test-vcx-code` / `test-vcx-cmd` since #129
(`Makefile:1218`), with a dedicated cache-free retry class built around it.
The lever the ruling declined was already in production, and the measured
floor already includes it. Cache-free was then measured SLOWER (71 s vs
53 s), so the default is correct on its merits — the decline was simply
describing a decision already made.

**Recorded as method, not blame:** a second session executed a brief whose
numbers it did not verify, which is the same failure VC-20 named in the
first. Numbers inherited from a handoff are unverified until re-measured.

## VC-22 — the gate is scoped BY RING; devbox stays

**Owner's words, verbatim:** *"keep running in devbox, we can't afford to
screw up our dependency management."* And: *"why do we need all the lanes all
the time. we have 4 rings now. if something didn't touch a ring don't bring
that into the test."* And, on the plan below: *"do it."*

**Consequence 1 — the toolchain is NOT touched.** The 4x devbox/host
compiler gap measured under VC-21 is recorded as a finding and closed as a
lever. `devbox` remains the execution environment for every gate. Dependency
management outranks wall-clock.

**Consequence 2 — lane selection becomes ring-precise.** `make test-changed`
already skips lanes whose declared inputs did not change, but
`scripts/test_changed.sh` declares `vcx/*` as the input of `test-vcx`,
`test-v`, `test-rust`, `test-go`, `test-python`, `abi-c-test` and
`check-prod-build` — so any edit under `vcx/` selects nearly every lane and
the ring boundary is ignored, even though `ring-import-gate` already enforces
that boundary in the tree. The globs are replaced with ring-precise paths,
with `scripts/ring_import_gate.sh`'s machine-checked import contract as the
authority for what each lane can actually depend on.

**Bounded honestly, measured from the build graph:** `libcx` is built from
`platform/` (`vcx/Makefile:222`), the TOP of the ring DAG. So an edit to
`cx`, `code`, `cxstore`, `platform`, `arrow` or `transport` genuinely changes
`libcx`, and the binding lanes must run. Ring-scoping buys: ring-0 and
cxstore lanes skipped on a platform-only edit; nearly everything skipped on a
`cli`/`cmd_data`-only edit. It does NOT skip the bindings for an ordinary
ring-1/ring-2 edit, and must never be sold as doing so. The script's standing
doctrine holds: a false RUN costs minutes, a false SKIP costs correctness —
over-include on doubt.

**Consequence 3 — the four binding lanes stop rebuilding `libcx`
independently.** That is a larger win than selection on the same lanes and is
in scope here.

**Measured baseline this work is judged against**, `make test` at
`b6a130141`, the current tip (which also establishes that the tip is
full-matrix green, previously unknown): **1,428 s wall / 10,924 CPU-s
(user+sys) / 7.6x average parallelism on 12 cores, GATE-RC=0.**

**Target:** full gate under 10 minutes; a ring-scoped dev loop under 5. No
lane is removed from the release gate to buy either number.

---

# AMENDMENT 13 (2026-08-24) — VC-23

**Status:** RULED by the owner, same audit session as VC-21/VC-22, after the
full measurement set landed. Recorded BEFORE the work per R6.1/R4.2.

**Owner's words, verbatim, in sequence:**
- *"maybe we shouldn't have merged at all and just driven testing best on
  the dependency map"*
- *"we don't have time to waste on bad data or temporary measures. what's
  the real problem here, root cause, first principles"*
- and, on the root-cause finding and the effort estimate below: *"record the
  ruling and start the fable session prompt. get it right and make it great
  for us and the v community"*

## VC-23 — #700 wave 2 is REDEFINED: module-cache SOUNDNESS in the V fork, not consolidation

### The measured basis (all lanes green, serial, warm tree, in devbox)

`make test` @ b6a130141: **1,428 s wall / 10,924 CPU-s / 7.6x parallelism /
GATE-RC=0.** All 51 lanes measured individually: **5,052 s serial total**,
of which 13 lanes carry 4,585 s (91%):

| lane | wall s | note |
|---|---|---|
| test-extraction-gate | 806 | ~3 world-builds (-gc boehm x2 + build-data-dev), NO cache |
| test-profile-gate | 662 | ~6 world-builds (4 profile shapes + 2 runners), NO cache |
| test-vcx-suite | 586 | 57 test binaries, -usecache |
| test-vcx-code | 476 | 30 binaries |
| test-vcx-conform | 296 | |
| test-vcx-cxstore | 258 | 20 binaries |
| test-vcx-columnar | 254 | 2 binaries |
| test-vcx-cmd | 248 | **ONE binary** |
| test-v | 233 | |
| test-vcx-cx | 221 | 6 binaries |
| abi-gc-gate / test-code-diagram / test-xpath-parity-cx | 204/173/168 | |
| all 38 other lanes COMBINED | 467 | bindings are cheap: python 13, rust 6, go 1 |

Per-file cost curve on the suite lane (gate flags, warm cache): 1 file = 3 s,
57 files = 235 s — **fixed cost ~200-250 s per LANE, marginal 2-5 s per
FILE**. The same 57 files cost 586 s in the lane sweep (colder cache): the
cache state alone is a measured **2.5x** on the identical workload.

### Ruled consequences

1. **The consolidation lever (VC-14 10a) is RETIRED.** At 2-5 s marginal per
   file, merging all remaining files saves a few hundred seconds ONCE — and
   permanently destroys the per-subject granularity that dependency-driven
   selection needs, which skips 200-586 s lanes on EVERY loop. The owner's
   framing is the ruling: selection on the dependency map should have been
   the lever all along. No further test-file merging without a new ruling.
   (VC-21 struck VC-14's numbers; VC-23 retires its lever. The wave-1
   umbrellas stay as they are — un-merging is not authorized either, the
   subject-level grouping is serviceable for selection.)

2. **The root cause is named: the gate's cost is proportional to
   codebase x configurations, not to the change under test.** V compiles
   whole-program per output binary; the gate builds ~8 full worlds in its
   top two lanes alone, cold every run; the one mechanism that would make
   compilation proportional to change — the module cache — is unsound by
   reputation and used in only 3 lanes behind a cache-free retry crutch.
   The Makefile's own #572 note has named the real fix for months without
   it being done: *"the cache-key root fix is the V-fork follow-up."*
   Every workaround since (#151 #520 #855 #864 retries and avoidances) is
   interest on that unpaid debt. VC-1 committed to the fork permanently,
   so the fix is ours alone.

3. **#700 wave 2 = cache soundness + dependency-driven selection.** It
   still gates the v0.17.0 tag (VC-18 unchanged). Its content is now:
   (i) the V-fork module-cache key made sound and PROVEN by an adversarial
   gate — Fable 5, next session; (ii) rollout of the sound cache to the
   uncached lanes and the suite-level dependency map — Opus 5, after the
   gate is green and red. The fork already carries the #151 content-hash
   architecture in vlib/v/builder/rebuilding.v; this is completion and
   proof, not greenfield.

4. **Model split, ruled on the silent-miscompile risk class:** a wrong
   cache key IS a silent miscompile — the exact scar class. Fable 5 owns
   the key-completeness audit, the soundness invariant, and the red-team
   gate. Opus 5 owns mechanical rollout behind that gate. Estimated ~2
   sessions best case, ~4 if the gate flushes a live residual (#572's
   duplicate-symbol class is still un-root-caused).

5. **For the V community, ruled by the owner's words:** the work is
   structured as an upstreamable series — cx-agnostic (per the standing
   V-fixes-are-V-only rule), self-contained commits, the invariant and gate
   documented in the series itself — and OFFERED upstream even though
   vlang/v closed our prior two patches unmerged. `-usecache` is
   off-by-default upstream because of exactly this unsoundness; a proven
   key is of general value whether or not upstream takes it.

### Also recorded from this session's work (landed)

- 895d685a6 — TEST_TARGETS names the five ring lanes + test-vcx-conform;
  test_changed.sh selects by the ring import contract (VC-22).
- afe134017 — test-changed fans out in parallel; it had run its selected
  lanes SERIALLY since creation (measured 2,347 s vs the 1,428 s full gate).
- **Open correctness item for the campaign, not the cache session:**
  test-profile-gate has NO retry class and reproduces the #951 supervise
  load-race (sup-011) under -j storms — first seen the moment test-changed
  went parallel. It needs a classified retry or the #951 root fix before
  parallel test-changed is trustworthy on trees that select it.

---

# AMENDMENT 14 (2026-08-25) — VC-24

**Status:** RULED by the owner during the #700 wave-2 part-(ii) rollout
session (Opus 5), on a finding raised from the recipes. Recorded BEFORE the
work per R6.1/R4.2.

## VC-24 — the gate harness runs on `-gc e`; there is no Boehm lane in CX

**Owner's words, verbatim, in sequence:** *"what, why are we using '-gc boehm'
that's not what we developed to better support parallelism"* — and, on the
finding and the options below: *"cx could care less about -gc boehm, we do
gc e"*.

### The finding that raised it (code-cited)

Three gate-harness binaries are built with an explicit `-gc boehm`, overriding
`CX_GC ?= -gc e`:

| binary | site |
|---|---|
| extraction-gate `probe` | `Makefile:766` |
| extraction-gate `cli_gate` | `Makefile:767` |
| `abi_gc_gate` | `Makefile:805` |

They entered in `daf3f921b` (2026-08-06, the I2 exit-gate harness) with **no
rationale** — the commit message does not mention GC, and the 45-line comment
block above the recipe explains every other design choice in that gate and is
silent on this one. `-gc e` had been cx's default since `a27d61b6b`
(2026-06-13), so these lines overrode the shipped memory model from the day
they were written. Not a ruling, not a documented exception.

**A real mechanism exists that could have motivated it** (inferred from code,
not measured): each of the three is a V host that `dlopen`s a libcx built
`-gc e`. A `-gc e` host would put TWO statically-linked vgc runtimes in one
process, and vgc keeps process-global and per-image state — a `pthread_once`
signal-handler install (`thirdparty/vgc/vgc_platform.h:1172,1420`), `__thread`
TLS (`:148`), and a thread registry per copy. Two collectors can fight over the
handler and STW-suspend each other's threads.

**Which is exactly why it cannot stay unexamined.** If that is the reason, an
unexamined `-gc e` dlopen-host defect has been sitting behind a silent
workaround since 2026-08-06 — the workaround-instead-of-root-cause class this
campaign exists to close (VC-23 §2).

What it does NOT compromise: the SUBJECT of both gates is the dylib, which is
built `-gc e`; `abi_gc_gate` proves the artifact carries vgc via `nm` and skips
loudly otherwise (`abi_gc_gate.v:65,84`). The harness is the anomaly, not the
subject.

### Ruled

1. **The three harness binaries move to `$(CX_GC)`.** CX has one memory model,
   architecture E, and the gate harness is not exempt from it. No Boehm lane
   remains in the tree's own gates.
2. **If the `-gc e` host comes back RED, that is a measured vgc dlopen-host
   defect** — it is FILED with the reproduction, prio-labeled, and fixed on its
   own landing (per the standing prio:high policy); `-gc boehm` may hold the
   lane in the interim ONLY with a comment naming that issue. A silent Boehm
   override is not available as an outcome in either branch.
3. **Rollout consequence, recorded:** `-gc boehm` is a distinct define set, so
   those three world-builds sit in their own `-usecache` namespace and can share
   no cached object with the rest of the gate. Moving them to `-gc e` collapses
   that namespace into the main one — the ruling pays the cache rollout as well
   as the memory model, but the memory model is the reason.

---

# AMENDMENT 15 (2026-08-25) — VC-25

**Status:** RULED by the owner at the end of the #700 wave-2 part-(ii) session,
after the measured negative result on the cache lever. Recorded per R6.1.

## VC-25 — #700 CLOSES; every attempted lever is documented so none is re-tried

**Owner's words, verbatim:** *"close 700 after so many failed attempts and
document each so we don't reopen and go down bad paths again. Then get back to
work on the open bugs and issues for this campaign. get it done and sound.
choose whats best long term for cx."*

### Ruled

1. **#700 is CLOSED**, and its closure is NOT a claim that VC-22's numeric
   targets were met. They were not: the full gate stands at ~24 min wall /
   182 CPU-min, and the ring-scoped dev loop at ~10-11 min. What is complete
   is the issue's ruled CONTENT — wave 1, wave 2 part (i), and wave 2
   part (ii)'s three deliverables, one of which (the cache rollout) is
   answered with a measured NO.
2. **The dead-ends register is the deliverable that closes it**:
   `ledger/dead_ends_700_test_duration.md`. Every lever attempted across
   #700's life, with the measured reason it failed and the arithmetic that
   bounds it. An issue closed without that register would be reopened and the
   same levers re-attempted — which already happened twice inside this issue
   (VC-14's numbers, then VC-23's cost attribution).
3. **The two unruled levers are NOT carried by #700.** They are recorded in
   the register with their measured bounds and become their own issues if and
   when they are ruled:
   - harness worker pool (bounded: ~5-7 min of wall, removes the serial
     13.4-min floor, does NOT reach 10 min);
   - total-CPU reduction (the ONLY thing that can reach 10 min; no lever
     currently exists — consolidation retired by VC-23, -usecache already
     default on the suite lanes, and VC-22 forbids removing lanes).
4. **VC-22's 10-minute target is therefore unmet and unclaimed.** It is not
   re-ruled here. It stands as an aspiration whose cost is now known: it
   requires halving 182 CPU-min, not rearranging it.
5. **Campaign work resumes on the open docket**, owner's direction: soundness
   over speed, long-term-best. The Fable-track clusters (A: #961 #964 #965
   #966; B/C: #962 #967 #955) remain that track's; this session takes the
   items no other track owns.

---

# AMENDMENT 16 (2026-08-25) — VC-26

**Status:** RULED by the owner ("1a") during the #956 implementation, before the
work, per R6.1.

## VC-26 — #956: implement what the platform supports; REFUSE what it cannot, loudly

`spec/03-approved/std-lib/process.md` §3.1 declares `$capture` with four values
(`:both`/`:stdout`/`:stderr`/`:none`, "Uncaptured streams inherit the parent's")
and `$new-process-group`. Neither is read on the `run` path — the #793
silent-acceptance shape, and the cause of a MEASURED unenforceable bound: a
60,000 ms budget ran 5m07s, sampled at 9m40s (9.7x) before a manual kill,
because a timeout signalled one pid while a surviving grandchild held the
captured pipe open and the post-kill `stdout_slurp()` blocked on it.

**Platform constraint, code-cited:** V's `os.Process` exposes ONE all-or-nothing
`use_stdio_ctl` flag (`third_party/v/vlib/os/process.v:30`) with no per-stream
redirect. So `:stdout` / `:stderr` — capture one stream, inherit the other —
are not expressible without extending the V fork's `os.Process` across both the
nix and windows spawn paths, and windows cannot be measured on this host.

### Ruled

1. **Implement now:** `$new-process-group` on `run` (+ group-signal on timeout,
   so a budget can actually be enforced), `$capture=:both` (current behaviour),
   and `$capture=:none` (never redirect — the child inherits the parent's
   streams per spec, and there is no pipe left for the post-kill slurp to block
   on). `:none` is the value the #947 bounded-gate work needed.
2. **Refuse loudly:** `$capture=:stdout` / `:stderr` raise a named error citing
   the V `os.Process` per-stream gap. A named refusal is strictly better than
   inert acceptance — the silent acceptance IS the defect being fixed. This is
   the CXP-1 precedent (close the surface, named refusal), applied to parameter
   VALUES rather than function names.
3. **The spec is NOT edited to match the shortfall** (standing rule: never
   "true" a spec to a shortfall). `process.md` continues to declare all four
   values; the implementation reports honestly which it cannot yet honour.
4. **The V-fork API gap is FILED as its own issue** — per-stream stdio control
   in `os.Process`, cx-agnostic and upstreamable, requiring a linux AND windows
   measurement rather than a blind darwin-only change.

---

# AMENDMENT 17 (2026-08-25) — VC-27 .. VC-31

**Status:** RULED by the owner, reply verbatim **"1a 2a 3b 4a 5a"**, to the five
open decisions posed at the end of the #700 close-out session. Recorded BEFORE
the work per R6.1/R4.2.

## VC-27 (1a) — the Fable-track clusters stay Fable's; this session takes the unowned docket

With #700 closed, the v0.17.0 tag waits on only Cluster A (#961 #964 #965 #966)
and Cluster B/C (#962 #967 #955). Those stay with the Fable track that VC-19
assigned them to — the spec-first matrix reasoning is identity-critical work,
and a shared checkout with two sessions editing one cluster is how work gets
lost. This session takes what no track owns: **#970** (unknown subcommand
diagnosed as a missing file), **#968** (approved specs still teach the retired
`cx store-token`), **#963** (verify the three stale agent branches).

## VC-28 (2a) — corpus/rosetta is ADOPTION EVIDENCE: rewrite it, re-derive the audit, then gate it

The corpus is 70 lines and all six programs predate the v0.8.0 homoiconic
reshape (infix `to` ranges, `:in`/`:yield` colon forms, `contains(x, y)`
call-parens). Two rows record **green** for programs that do not parse — an
active lie in the one artifact whose job is to show CX does ordinary things.

Ruled: rewrite all six in the current surface; **re-derive `AUDIT.md` against
today's surface** (statuses re-measured; the v0.7.x gap register retired or
archived rather than left to describe a surface that no longer exists); then
wire `corpus-audit` into a lane so it cannot rot again. Wiring comes LAST — the
issue's own reasoning: wiring first would paint the current red into
`make test`. 21-fetch-csv-validate stays legitimately blocked (pre-impl).

## VC-29 (3b) — the harness worker-pool lever is AUTHORIZED, and starts now

91% of the extraction gate is one binary issuing 21,158 process spawns
serially. A bounded worker pool is worth ~5-7 min of gate wall and removes the
serial 13.4-min floor. It does NOT reach 10 minutes (see VC-31).

**Ruled, with the session's own recorded caution as a binding condition:** this
gate certifies `libcx-core == libcx` over the Ring-0 corpus, and its 12-minute
CLI lane has **no recorded transcript hash** — only case counts and rc. So:

1. **Record a deterministic CLI-lane verification instrument FIRST**, before any
   concurrency, and capture its baseline hash. The ABI lane already has one
   (`2d739c8f74dcfae965788c7befd5248e6ff99cb47f4e69ef25d543005c9737a2`).
2. Then the pool, with per-pair scratch isolation (the runner shares one work
   folder today; #883's code-signature kill and #902's `Exec format error` are
   recorded in that file and concurrency re-arms both), index-ordered result
   collection so the transcript stays byte-deterministic, and the existing
   serial divergence re-check kept intact (it distinguishes a real divergence
   from a spawn flake, and one fired in 1,838 under parallel load).
3. Verdict identity is the acceptance test: same transcript hash, same case
   counts, three consecutive runs.

## VC-30 (4a) — #572 CLOSES on its attribution plus the escape detector

The duplicate-symbol class is attributed (mixed-generation cache layers,
reproduced deterministically), the literal `___v_thread_wait` instance is not
resurrectable under the #151 vexe salt, and the cache-free retry that used to
mask a recurrence is now a gate-escape diagnostic that cannot turn one green.
Leaving it open implies an unknown that no longer exists.

## VC-31 (5a) — VC-22's 10-minute target STANDS as an unmet aspiration, with its cost recorded

Not re-ruled to a reachable number, and not commissioned as a CPU-reduction
campaign. It stands, and `ledger/dead_ends_700_test_duration.md` states what it
would take: 182 CPU-min must become ~96-120, since 182 on 12 cores floors the
wall at 15.2 min and parallelism cannot beat that floor. The end-state gate is
1,247 s (20.8 min) / 10,756 CPU-s, GATE-RC=0.
