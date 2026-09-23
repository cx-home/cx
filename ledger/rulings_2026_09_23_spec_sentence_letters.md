# RS-26 — five spec-sentence authorizations the agents could not make (owner, 2026-09-23, in session on dev2)

**Status: RULED.** On 2026-09-23 the integrator posted five lettered letters on
[#1591](https://github.com/cx-home/cx-private/issues/1591) — D39, D40, D41, D42 and D43, each a
spec sentence that a branch had found stale or missing and that no decision's edit map named, each
with option (a) recommended — and the owner answered the batch with one word, **"A"**. This page
records that answer as option (a) of each of the five, which is how the integrator read it and how
it was posted back on the issue the same hour; if the owner meant otherwise, the correction lands
here and the branch that acted on the wrong reading reverts. Nothing on this page is a new design:
every sentence below says what a decision already ruled, in the page's own voice, which is the
precedent [RS-21](rulings_2026_09_22_repo_split_followups.md) set (a design item may ADD or bring
current the text that states it; it may never move or delete a sentence the map does not name).

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
