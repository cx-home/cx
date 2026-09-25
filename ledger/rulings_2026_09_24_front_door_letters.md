# RS-32 — the front-door letters of 2026-09-24 (owner: D79a, D80a, D81a, D82a, D83a, D84a)

**Status: RULED (owner, 2026-09-24 ~21:0xZ, in session, on
[#1591](https://github.com/cx-home/cx-private/issues/1591)).** The integrator posted six lettered
letters — D79 (`cx-core-code`), D80 (the existing `cx-home/cx` mirror), D81 (`cx-home/cx-v`), D82
(what the public `cx` takes from `repo=cx`), D83 (the switch-over) and D84 (ft's V half) — each with
a recommended option. The owner's word, verbatim: **"d79a d80a d81a d82a d83a d84a if each of these
is truly the best long term for cx"**. The integrator's confirmation, on the record the same comment:
**"each of the six is the best long-term option as I judge it against #1589 (the two frozen cores,
acyclic pins), D58a (thin repositories), D59a (`cx` by the recipe, cx-private stays the orchestration
repository) and D76c (the ring decides where a module lives)."** This page records that answer: the
six lettered options below, in the board's order, each with the option text as posted and the
consequence the owner accepted by choosing it.

## The six, and what each authorizes

**D79a — `cx-core-code` is created now, as the last V leave.** The options: **(a) create it NOW by
the recipe as the last V leave, before `cx` and the cut: the repository boundary becomes the ring
boundary for Ring 1 as it is for Ring 0, products pin the two cores and `cx` is the thin front door
D58a describes**; (b) fold the 77 rows into `cx` for good — the cheapest cut, but products then pin
`cx` while `cx` pins them (a cycle #1589 forbids), Ring 1's boundary stays an in-tree gate only, and
#1589's table is amended, a re-litigation; (c) cut first with the language inside `cx`, then extract
`cx-core-code` out of `cx` after the cut by the same recipe — the end state is (a)'s, but the release
publishes a shape the next one undoes, ~6 product repos move their pins twice, and it is a deferment.
The consequence accepted with (a): the biggest leave so far (one opus, ~2–3 M tokens, 1–2 windows),
and the cut moves to ~09-26/27.

**D80a — the existing `cx-home/cx` mirror's `main` is replaced in place.** The options: **(a) replace
`main` in place with the recipe's filtered history, one forced push, once: tags, releases, assets,
stars, the fork and the URL stay; Pages redeploys from the new tree's `docs/` (D57a); the mirror's
history stays reachable under its tags**; (b) merge the filtered history onto the mirror's with
unrelated histories — a continuous graph, but every file carries two lineages forever (blame and
`--follow` muddied); (c) rename the mirror to `cx-mirror-0.17` and create `cx` fresh — stars, fork,
releases and asset URLs leave `cx`, and the new repo overrides GitHub's rename redirect. The
consequence accepted with (a): one forced push, once, keeping tags/releases/assets/stars/fork/Pages.

**D81a — `cx-home/cx-v` is archived at the cut.** The options: **(a) archive it at the cut with a
README pointer at `cx-home/v`: one fork, one pin, no second copy to drift**; (b) keep publishing it —
a mirror script to maintain for a repository nothing pins. The consequence accepted with (a):
`cx-home/cx-v` stops publishing at the cut; `cx-home/v`'s `cx-patches-0.18` branch (D69b) is the one
tracked line from then on.

**D82a — the public `cx` takes every `repo=cx` path except the orchestration set.** The options: **(a)
everything except the orchestration set — `_gate_evidence/`, `.claude/`,
`AGENT-STANDING-RULES.md`, `CLAUDE.md` stay in cx-private (D59a: boards, evidence, runner
configuration, briefs); `ledger/` and `spec/03-approved/process/` go public with `cx`, because
`spec-freeze-gate` and `cxer-registry-gate` read them at HEAD in `cx`'s own gate and the decisions are
the project's governance (cx-decisions goes public at the cut anyway)**; (b) the ledger and the
process specs stay private too — `cx`'s gate loses `spec-freeze-gate` or needs a new asset-only pin
shape for a non-module repository; (c) all of `repo=cx` public, evidence and `.claude/` included —
RESULTS.md files carry box-local paths and briefs. The consequence carried, not a change (stated in
the same comment): under (a) the standing rules stay private, so after D83a's switch the `cx`
worktrees read `AGENT-STANDING-RULES.md` through CFG-1's symlink from cx-private, not from their own
root.

**D83a — cx-private stays the working tree through the cut.** The options: **(a) K7 creates `cx` from
this head and pushes; cx-private stays the working tree through the cut and `cx` is refreshed from
each green head by the same filter (deterministic on an unchanged path list → a fast-forward; a
changed allocation forces once); at the cut the tag is made in `cx`, THEN the leave: cx-private drops
the moved files and the loop, the worktrees and the briefs move to `cx`**; (b) switch immediately —
the leave merges with K7 and every path in the standing rules, the loop's plist, the slots and the
running briefs changes before the cut, a window of breakage in front of the release. The consequence
accepted with (a): a two-tree period (cx-private live, `cx` a refreshed mirror) that ends only at the
cut's tag.

**D84a — ft's V half stays in `vcx/code`, re-allocated to `cx-core-code`.** Posed after D71a's dispatch
survey missed `vcx/code/stdlib_similar.v`'s same-module calls into `stdlib_ft.v`'s tokenizer (`ft`'s
row, `modules.cxd` row 216, already reads `ring=1 ns=cx-stdlib`). The options: **(a) ft stays in
`vcx/code`, re-allocated to cx-core-code with a `why=` (D76c's rule: the ring decides where a module
lives); the store row takes `status=extracted` (no store-owned file remains in this tree); no env hook
is built, since nothing would register through it; the profiles and `similar` are unchanged; ft's
spec/corpus/source stay where they are (cx-platform-store's pin) — a two-repo module like sasl**; (b)
split the file — the ~560-line tokenizer stays in `vcx/code` as shared core code, the index/search half
leaves through the env hook as briefed — ft then refuses in cli, embed, libcx and wasm, and one module's
code lives in two repositories; (c) move it whole and copy the tokenizer into `code` for `similar` —
two copies of the same code, the drift the split exists to remove. The consequence accepted with (a):
K9's env-aware hook branch is not built; the hook work folds into this branch as the ft rule and the
store row instead (K9 stopped with the letter, replaced by this item).

## D86b — cxhome.org may go dark when `cx`'s `main` is replaced; the docs epic brings it back

**Status: RULED (owner, 2026-09-24 ~23:0xZ, in session, on
[#1591](https://github.com/cx-home/cx-private/issues/1591)); recorded here late, by the docs epic's
first branch, which cites it.** D86 was one of two letters from the front-door branch's flags, posted
the same evening as the six above, because it gated the one forced update of D80a. It rode the board
until now: the board recorded the answer ("Recorded: D86 = (b)") and every later comment cites D86b,
but no ledger page carried it.

**The letter, as posted** (the board, comment of 2026-09-24 21:12Z; one version number replaced by its bracketed description, since a version literal is refused in tracked text): "cxhome.org when `cx`'s `main` is
replaced. 127 of the 153 published `docs/` files (`index.html`, the guide, the playground) are
generated and not tracked in cx-private; `docs/install` and `CNAME` are. (a) before the push, preserve
the site: the published `main`'s tree goes to a `site` branch of `cx-home/cx`, Pages is pointed at
`site` (one settings change), `main` is replaced; the docs epic (RS-28/RS-30, after K11) moves Pages
back to `main` when the generated site is tracked or built by a Pages workflow — no downtime, the old
site frozen at [the previous release] until then. (b) push and let the site 404 until the docs epic —
the front door dark for days. (c) hold the push until the site generator is ported into `cx` —
couples the split to the docs epic. Recommend (a)."

**The owner's word, verbatim:** "d86 not a problem for the side to go dark if that saves time".

**What (b) authorized, and what it leaves.** The forced update of `cx-home/cx` `main` went ahead
without preserving the site (2026-09-25 ~11:3xZ; Pages rebuilt from the new `main:/docs` with no index
page, so cxhome.org went dark, as accepted). It leaves the docs epic (RS-28's D57a/D58a, RS-30's
voice, after K11 per D89a) to bring the site back from `cx`'s own tree — generated, or built by a
Pages workflow — which is the same end state (a) would have reached, without the interim `site`
branch.

## Not decided here

The cut's date is not fixed by this page: D79a's leave alone moves it to ~09-26/27, and the actual date
follows the leave's and the front door's own completion, not a ruling here. K11 (the LLM front-door
document set) is a design item still awaiting the owner's confirmation of what "(a)" meant for its
home and regeneration (`docs/llm/` in `cx`, the corpora-backed parts regenerated by `cx`'s own gate) —
this page records none of it. `cx-core-code`'s own gate shape — which steps its `make test` runs, how
the census/rebless/address trio applies to a Ring-1-only repository — is K7a's (the leave) and K7b's
(the front door) to measure and is not stated here. No ring, directory or allocation beyond D82a's and
D84a's own rules moves on this page.
