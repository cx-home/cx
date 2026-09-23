# RS-26…RS-27 — five spec-sentence authorizations, then the afternoon letters (owner, 2026-09-23, in session on dev2)

**Status: RULED (owner, 2026-09-23, confirmed letter by letter).** On 2026-09-23 the integrator posted
five lettered letters on [#1591](https://github.com/cx-home/cx-private/issues/1591) — D39, D40, D41,
D42 and D43, each a spec sentence that a branch had found stale or missing and that no decision's
edit map named, each with option (a) recommended. The owner first answered "A" (which the integrator
read as (a) of each and said so), then said that word had answered something else, asked to see the
five again with their recommendations, and answered, verbatim: **"Ok yes all (a)"**. This page
records that answer: option (a) of each of the five. Nothing on this page is a new design: every
sentence below says what a decision already ruled, in the page's own voice, which is the precedent
[RS-21](rulings_2026_09_22_repo_split_followups.md) set (a design item may ADD or bring current the
text that states it; it may never move or delete a sentence the map does not name).

## The five, and what each authorizes

**D39a — the pins page agrees with itself (under RS-7, #1617).** `spec/03-approved/process/repository-dependency-pins.md`
§3's bullet "present and not at `sha`" now says a clean checkout is moved to the pin and a dirty one
is refused (`checkout-drift`), while the §3.1 table's `checkout-drift` row still reads "not at
`sha`". The row is brought to the bullet's meaning in one commit. Nothing else on the page moves.

**D40a — `connector.md` describes a kit with no V half (under RS-25).** After the mock adapter's
compile-time gate retired, two paragraphs of `spec/03-approved/platform/connector.md` still describe
`connector-test-build` and a `vcx/platform/stdlib_connector.v`: §10.1's "Advisory today" paragraph
and the rest of the placement paragraph. Both are brought current with what the RS-25 landing
already states — the mock is present wherever the kit is, the kit has no V code of its own. Every
other sentence of the page stays.

**D41a — the seven capability classes are spellable (#1607).** `vcx/platform/store_service.v`'s
`xsp_grant_caps` lists five classes while `spec/03-approved/xap/xsp_store_profile.md` §6.1 names
seven; `compute` and `snapshot-sign` are live in the enforcement path but cannot be written in the
operator's `[grants]` table. The const, the `store-mint-principal` help row in
`vcx/cmd/platform_verbs_d_cx_platform.v` and the parenthetical in `spec/03-approved/misc/cli.md`
(§ "store-mint-principal", the sentence "the daemon config enforces (`read write delete admin
peer`)") change together, fixture first; the cli.md sentence may either name the seven or point at
§6.1 as the one list, and the branch says which it chose and why.

**D42a — the soap `version=` attribute is a string (#1595).** `connector.md`'s soap rows spell
`version=:1.1`, which the atom grammar refuses (`:identifier` only), so 22 cases of
`conformance/platform/connector.cxd` die at parse and grade nothing. The spec's spelling becomes
the STRING `version='1.1'` (and `'1.2'`) in every row that carries it, and the 22 cases follow. A
version is text, which the primer's own rule already says of anything that must survive as text;
Ring 0's grammar and canonical identity are untouched. The decimal `1.1` and a grammar change
admitting `:1.1` were the letter's (b) and (c) and are refused.

**D43a — a vanished pipeline stage has ONE answer (#1611).** `[$process:pipeline]` answered `''`,
`null`, `CXER4005`, `CXER3401` or `CXER3403` for the same condition — a stage's program removed
between PATH resolution and exec. The process module's spec names one answer: a REFUSAL, carried as
the existing spawn-failure code whose registered sentence fits the condition (the branch names it in
RESULTS.md and in the case that pins it), never an empty or null stdout. A fixture with a
deliberately vanished stub pins it before the runtime changes.

## Not decided here

Whether the soap adapter's cases stay advisory is the connector kit's own question, not this page's.
The choice between naming the seven classes in `cli.md` and pointing at §6.1 is the branch's, stated
in its report. No ring, directory or allocation moves on this page.

## RS-27 — the afternoon letters of 2026-09-23 (owner: D49a, D50a, D51d, D52a, D53a)

**Status: RULED (owner, 2026-09-23 ~15:0xZ, in session).** The integrator posted five more lettered
letters on [#1591](https://github.com/cx-home/cx-private/issues/1591) — D49, D50, D51, D52 and D53 —
each with option (a) recommended except D51, whose recommended option was (d). The owner's word,
verbatim: **"d49a d50a d51d d52a d53a"**. This page records that answer, in the letters' own order.

**D49a — a suite's `gate=advisory` status lives on the suite element.** Once a suite leaves
`cx-private` for its own component repository, its advisory status travels on the element itself
(`[test-suite … gate=advisory reason=…]`), read by `cx corpus`; `conformance/gates.cxd` becomes a
DERIVED cx-wide register checked for drift rather than the one place the status is declared. A
per-repository `gates.cxd` fragment (b) and hand-marked advisory suites in each repository's Makefile
(c) were refused: both add a second place to drift. Implemented on a separate branch,
`impl/cx-F-1633-gate-on-suite` (#1633); nothing on this branch moves `conformance/gates.cxd`.

**D50a — `xsp_store_profile.md` §6.2's stale sentence is brought current.** The sentence saying the
shipped parser's `caps=` list "holds five of the seven" and that store-auth-015 "measures exactly
that gap" was true before `4b8da199c` (#1607, RULED: RS-26/D41a) and false after: the `[grants]`
parser, the `store-mint-principal` help row and the mint verb all read §6.1's seven capability
classes now. One sentence changes; nothing else on the page. Filing alone (b) was refused — this is
the one-line bring-current RS-21's reading of a design item already licenses.

**D51d — the site assembly step copies the LLM text files into `docs/`, untracked.**
`scripts/publish.sh` used to copy `llms.txt`/`llms-full.txt` to the site root — the llmstxt.org
convention of serving them from the domain root — as part of assembling the allowlist mirror's public
tree; RS-11 retired that mirror and nothing replaced the copy. Generating a second TRACKED pair under
`docs/` (a) was refused as a 360 KB duplicate on every regeneration; relinking `AGENTS.md` and
`release-verify` to a repo-root copy (b) was refused because the site root is `docs/`, where `CNAME`
already lives, so a repo-root copy would serve nothing; dropping the root copy outright (c) was
refused. The convention is kept the cheap way: the site assembly step copies `docs/llm/llms.txt` and
`docs/llm/llms-full.txt` to `docs/llms.txt` and `docs/llms-full.txt` at release time, UNTRACKED — one
source, no committed duplicate.

**D52a — RS-1's leftover vocabulary is swept to group wording.** RS-1 ruled that "Ring 2" and "Ring 3"
leave the vocabulary, and its own edit map named the sentences a branch would bring current — but it
did not name every sentence. Measured by the integrator: 148 "Ring 2"/"Ring 3" mentions across 46
files still outside the edit map (the rest of `cx_partition.md` §1 and its §3 bullets and §4's
"Rings 0–2", the guide's "Ring 2 — Platform" label and its four-rings figure), plus 25 platform spec
headers still carrying `ring=2`. One mechanical sweep branch (this one, sonnet) brings the prose and
the 25 spec headers to group wording under RS-1, writing its own design text per
[RS-21](rulings_2026_09_22_repo_split_followups.md)'s reading that a design item may state what a
ruling already ruled. The `ring2_*` V identifiers are left for xap's turn (RS-24's split); leaving the
whole sweep as unedited history (b) was refused — RS-1 says the words leave the vocabulary, and a tree
that says both is exactly the drift the gates exist to end.

**D53a — `vcx/cxnet/` and `vcx/cxdb/` are the two exceptions where vlib owns the name.** vlib already
owns the top-level modules `net` and `db`, so a bare `vcx/net/` or `vcx/db/` would shadow them for
every `import net` in the tree; the platform-modules branch used `vcx/cxnet/` (`module cxnet`) and
`vcx/cxdb/` (`module cxdb`) instead. That is accepted as the two exceptions the V collision forces;
every other product keeps its bare directory name (`vcx/mail`, `vcx/store`, `vcx/identity`,
`vcx/fabric`, `vcx/xap`) — RS-24's layout, record only, since it names no directory this page's edit
map did not already cover. A uniform `cx<product>` prefix on all seven (b) was refused: the collision
is V's alone, and `vcx/cxstore` already names the store ENGINE's own module, so `store` would need yet
another name under that option.

## Not decided here (RS-27)

Whether the seven kinds `cx corpus` still refuses (D55) and whether the DATA profile gets the document
lane (D56) are open letters, not this page's. `vcx/tests/flow_umbrella_test.v`'s ownership (D54) is
open. Nothing on this page moves a directory, a ring or an allocation beyond D53a's record of RS-24's
already-ruled layout.
