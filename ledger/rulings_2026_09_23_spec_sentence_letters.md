# RS-26…RS-31 — five spec-sentence authorizations, the afternoon letters, documentation and CI/CD, the documentation voice and the evening letters (owner, 2026-09-23, in session on dev2)

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

## RS-28 — one site, thin repositories, and cx created by the recipe (owner: D57a, D58a, D59a)

**Status: RULED (owner, 2026-09-23 ~15:2xZ, in session).** The integrator posted a design topic —
documentation restructure with the split, the identity of `github.com/cx-home` and
`cx-home.github.io/cx` (= `cxhome.org`), per-repo docs versus centralized, going public at v0.18 with
only `cx-private` staying private, CI/CD driven by `cx flow` — as letters D57–D60 on
[#1591](https://github.com/cx-home/cx-private/issues/1591). Already ruled and kept: RS-9 (docs follow
the module; the site in `cx` indexes what was published) and RS-11 (public/private per repository).
The owner's word, verbatim: **"d57a d58a d59a d60a"**. This page records D57a, D58a and D59a; D60a is
RS-29 below.

**D57a — one canonical site.** ONE site, `cxhome.org`, served from `cx`'s `docs/` by Pages; the org
profile (`cx-home/.github`) is a one-screen pointer with the repository map, never a copy. Keeping two
identical sites and syncing them by a release step was refused: two copies drift.

**D58a — thin repositories, one narrative site.** Each component repository is thin: a README (what it
is, install, what it pins, a link to its reference), CONTRIBUTING, and the generated docs fragment of
RS-9 — nothing hand-authored beyond that. The narrative — the primer, the guide, the playbooks, the
rendered decision pages — lives in ONE site, in `cx`, indexing every fragment. A Pages site per
repository (20+ sites) was refused.

**D59a — `cx` is created by the recipe; `cx-private` stays private as the orchestration repository.**
This AMENDS RS-11's sentence *"cx-private becomes cx when it is no longer private."* Before this
page, RS-11 read: `cx-private` becomes `cx` — the same repository, renamed public. It now reads: `cx`
is CREATED by the extraction recipe from the allocation's `repo=cx` paths (filtered history, the front
door's builds, pins and site) — the split's own mechanism, not an 8,000-commit history audit of
`cx-private`. `cx-private` STAYS private as the orchestration repository, holding only what the
allocation leaves it: boards, evidence, runner configuration, briefs. The component repositories flip
to public at the v0.18.0 cut, in one pass, each after its own `check-no-consumer-terms` and a secrets
scan over its tree. Renaming `cx-private` itself to `cx` and starting a new private ops repository (a
history audit first) was refused, as was staying private past v0.18.

This opens a documentation-restructure epic after the cut (with RS-29's flow-CI epic).

## RS-29 — CI/CD is cx flow, documentation included (owner: D60a)

**Status: RULED (owner, 2026-09-23 ~15:2xZ, in session, same answer as RS-28).**

**D60a — CI/CD becomes `cx flow`.** Each repository's lanes become `ci/*.flow.cx`, run by `cx flow run`
on the self-hosted runner; GitHub Actions becomes a one-step trigger rather than the orchestrator.
The documentation pipeline — the per-repository fragment at release (RS-9), the site assembly in `cx`
(D57a/D58a) — is itself a flow. The bootstrap is a released `cx` on the runner, which the release lane
already uses. This is IMPLEMENTED AFTER the v0.18.0 cut — nothing before it is re-plumbed. Doing it
before the cut (2–3 agent-days on the critical path) and keeping YAML were refused.

## Not decided here (RS-28, RS-29)

D54, D55 and D56 stay open. Nothing before 2026-09-26 changes because of this page: the `cx`
repository is created at the residue step (item 21 of the split) by the recipe like every other
repository, and both the documentation-restructure epic and the flow-CI epic open only after the cut.

## RS-30 — the documentation voice (owner, 2026-09-23 ~16:4xZ)

**Status: RULED (owner, 2026-09-23 ~16:4xZ, in session).** Recorded here, as the board said it would
be, by the first ledger-touching branch after it was given; the integrator posted it on
[#1591](https://github.com/cx-home/cx-private/issues/1591) the same hour. It governs the voice of the
documentation-restructure epic that RS-28 opened. The owner's words, verbatim:

> in restructuring the documentation, the content and tone is trying to be too much of an agnostic
> consultant when comparing cx data format and cx code to options. We need to spend more time TLDR
> showing why its best to reach for CX, how it's the best option for nearly every data format use
> case and most use cases for a general purpose language. That the CX bar is equal to or better than
> python and we continue to invest and prove that path. Not that our goal is to replace Python but
> that it sets an admirable standard that we want to equal and exceed. We want to get people excited
> about all they can do with CX, not try to position ourselves as a 3rd party, unbiased advisor.

**How the epic applies it (the integrator's reading on the board, recorded with it):** the primer,
the guide, the READMEs and the site lead with a TL;DR of why to reach for CX and what one can do with
it; a comparison states CX's case rather than referees; Python is named as the standard to equal and
exceed, never as a target to replace; and every claim keeps the primer's own discipline — a runnable
corpus example or a measured number beside it — so the excitement is checkable (AGENTS.md rule 10
holds: what is measured is labelled measured). It applies to the documentation epic after the cut;
nothing before 2026-09-26 changes because of it.

## RS-31 — the evening letters of 2026-09-23 (owner: D54c, D55c, D56a, D62a, D63a, D64c, D65d, D66a, D67a, D68a, D69b, D70a1, D71a, D72a)

**Status: RULED (owner, 2026-09-23, in session, letter by letter).** The integrator posted D54–D56 and
D62–D67 on [#1591](https://github.com/cx-home/cx-private/issues/1591) through the afternoon. The owner
answered D63a first (~17:3xZ), then asked for better information on the rest — *"the repos should
allow for independent testing … you are forcing things back together at every chance"* — and the
integrator restated each letter with the independence principle leading (17:36Z). The owner's word,
verbatim, ~17:5xZ: **"d54 c / d55 c / d56 a / d62 a / d64 lets discuss. why not have these in their
own agent repo. more agent packages coming our way for sure. / d65 xsp is a product, at least
internally for usage across all cx platform. and its expected to provide push down across any of its
connections. so what does that change in your recommendation if anything? / D66 a) if thats the best
recommendation but I really don't understand this one / D67 a"**; then, ~18:0xZ, after the
discussion of D64 and the revision of D65: **"d64 c d65 d"**. Each letter below is recorded with its
options as the board states them (the 17:36Z restatement, which is what the owner answered; where an
earlier posting framed the options differently, that is said), the chosen option first. Two more
letters of the same kind — allocation and directory decisions — followed at the next integrator
session's start (posted 21:2xZ) and were answered ~21:4xZ: **D68 = (a)** and **D69 = (b)**; then D70
(#1636), put again with its long-term consequences at the owner's request, was answered ~21:5xZ:
**D70 = (a1)**. The three are recorded last. Three more followed after midnight (2026-09-24, posted on the board and answered there): **D71 = (a)** (~01:0xZ), **D72 = (a)** (~01:2xZ) and a second letter under D56a, on where its grading cores live (~02:1xZ, answered **(a)**); they are recorded after D70a1.

**D54c — `vcx/tests/flow_umbrella_test.v` splits by subject.** The umbrella's 16 functions shell out
to `cx flow run/serve/--help` and read `$flow:status` — they test cx's CLI verbs AND flow's package.
The options: (a) leave (the transitional state); (b) move it to cx; **(c) split by subject — the
package assertions become CX cases/lanes in the flow repository, graded by the released cx alone; the
CLI-shape assertions (`cx flow --help`, exit codes) stay in cx as a small V test.** (The 14:13Z
posting offered (a) leave, (b) a `repo=cx` rule for `vcx/tests/flow_`, (c) split it; the owner
answered the restatement.)

**D55c — `cx corpus` grades diff, lint, fmt and streaming-write.** `cx corpus` refused seven suite
kinds whose graders live in cx's V tests. The options: (a) every grader into the binary (Arrow's C
library then rides in every cx); (b) component repositories list only what `cx corpus` grades; **(c)
= (a) for the `cx diff`, `cx lint`, `cx fmt` and streaming-write runners — each moved into
`vcx/corpus/` the way #1631 moved the document lane — and (b) for Arrow (a C dependency) and the
three CX-program graders (namespace migration, XPath parity, code diagram) that any repository
already runs with `cx <script>`; those stay refused by name.** Authorized spec sentence:
`spec/03-approved/misc/cli.md` §3.11's document-lane paragraph names the four kinds `cx corpus` now
grades and the kinds it still refuses by name; nothing else on the page moves.

**D56a — the data profile gets the document lane.** The data-only cx refused `cx corpus` outright,
although cx-core-data's suites are 28 of 32 document-lane and need no evaluator. The options: **(a)
the data profile gets the document lane, so cx-core-data tests itself with its own build**; (b) keep
the refusal. A program case (an `[in-code …]` program) stays ungradeable there — the data profile
has no evaluator by ruling — and is refused by name, never passed. Authorized spec sentence:
`spec/03-approved/core/cx_partition.md` §4's data-profile verb list (the profile matrix) gains
`corpus`, limited to the document lane; the cannot-execute property is untouched.

**D62a — `env_retention_test.v` asserts absolute retained bytes per env.** The gauge asserted a RATIO
of retained bytes, and on kilobytes a ratio is noise — one trial read 243.6× on +1,488 bytes against
+362 KB, with no per-load growth in the data. The options: **(a) the gauge asserts the ABSOLUTE
retained bytes per env against a stated bound (RS-17's own words: the per-case cost must be flat)
and the ratio arm retires**; (b) keep the ratio arm with a floor on its denominator; (c) leave it.

**D63a — the `x/` experimental tier retires.** The tier has no members left since D45a moved its
eleven modules into the platform group. The options: **(a) retire it — the AGENTS.md sentence,
`spec/03-approved/stdlib/README.md` §3.3, `spec/03-approved/core/code.md` §12.1 and the
directories**; (b) keep it empty for a future graduate; (c) keep the words, move only the
directories. Authorized: §3.3 goes, and with it the README's own sentences that point at it; code.md
§12.1's bundled-namespaces sentence stops naming the tier; the AGENTS.md sentence goes; tooling that
still admits the tier's namespace or directories stops. The `cx-x/<name>` spellings keep refusing by
name (CXER0213, D45a) — retiring the tier does not un-retire a spelling.

**D64c — the agent kit's four real-socket tests become CX lanes in the agent repository.** The four
V tests (`vcx/tests/{mcp_,a2a_,llm_}*`) already live in cx-platform-agent, which has no V toolchain,
so cx runs them from the pin. The options: (a) keep them as they are (transitional); (b) move them
back into cx; **(c) rewrite them as CX lanes in cx-platform-agent, runnable by the released `cx`
alone — the shape every coming agent package uses; cx runs them from the pin until then.** One rule
with D54c: a package repository tests itself in CX, and cx keeps only the tests of its own verbs.
(The 16:40Z posting offered (a) keep, (b) move back, (c) give the package repository a V build; the
owner discussed and answered the restatement.)

**D65d — `cx-platform-xsp` becomes a PRODUCT repository, after the cut.** xsp is a product used
across the platform and is expected to provide push-down over any of its connections (the owner's
information, ~17:5xZ). The options, as restated: (a) the pure XSP-AUTH calculus joins Ring 1
(xsp-auth's `half=`, or folded into `cx-stdlib/xsp`), the impure natives stay identity's — no new
repository, nothing before the cut; (b) xsp-auth whole to store (the wrong owner); (c) a hook the
store declares and identity installs (12 store tests leave, about 15 internals open); **(d)
`cx-platform-xsp` for the whole protocol: the frame codec (`cx-stdlib/xsp`, still Ring 1), the auth
handshake (its pure calculus in Ring 1 code, its impure natives as xsp's own platform module) and the
push-down surface; pins xsp → core-code and net; store, identity and fabric → xsp.** It amends RS-2
(a product, not a per-library repository), RS-3 (one more repository) and RS-15 (the natives are
xsp's, not identity's). Tonight's interim is the store split's, which is option (a)'s shape.

**D66a — two allocation moves confirmed.** The principal mint (`cx store-mint-principal`, offline,
whose only caller is the store verb) moves identity → store, and `consistency_vocab.v` (pure `floor`
/ `pin` checks called by store, fabric and xap) moves to Ring 1 code. The options: **(a) confirm both
— placement by highest verb and by caller, the split's own rule**; (b) keep the mint with identity
behind a hook.

**D67a — a reference-apps repository.** Measured in xap's allocation: `reference/shop` (13 paths),
`reference/acme` (6), `reference/shop-web-client`, `reference/archetypes`, `market/` (4),
`examples/platform/xap/storefront` (9), `sso-flow-xap` and the htmx examples; store carries 18
example paths. The options: **(a) a reference-apps repository — pure CX, pinning every product,
gated by the released cx; xap keeps the host; the apps become the independent end-to-end test bed**
(RS-2's test: one owner, one line, its own cadence); (b) they stay in cx-platform-xap (RS-3); (c)
into `cx` beside the site.

**D68a — core-data's 87 allocated files that cannot leave re-allocate.** The files: `third_party/re2`;
`vcx/code/stdlib_codec.v` and its xml row; 35 `vcx/tests/**` files grading this tree's own inputs;
`include/cx.h`; `scripts/wasm` and `tests/wasm` (32); `bench/repr`;
`conformance/{gates,migrate_namespace,xpath_31_parity,llm/antipatterns}.cxd` and their READMEs;
`fixtures/expected_demo_output.txt`. The options: **(a) re-allocate them in `registry/repos.cxd` to
`cx` / `cx-core-code` with a `why=` each; their dead copies leave `cx-core-data` in a prepared
commit; the row takes `status=extracted` — every file has exactly one home that grades it, and
cx-core-data is the data ring alone**; (b) keep the allocation and do a portability pass
(`@VMODROOT`→`@FILE`, move the integration tests' inputs) before they leave — cx-core-data then
carries whole-tree integration tests and every change touches two repositories; (c) leave as is —
copies nobody grades drift. Applied by the core-data extraction branch, not this page's.

**D69b — the V fork's tracked branch is `cx-patches-0.18`.** `.gitmodules` named
`cx-home/v-cx-patches` (tip `a469af9cf`), and neither the head's pin `d51c31ccb` nor #1605's
`501ce6e5f` descends from it: the pinned line carries every fix of the old line by subject except the
four patches the old line itself removed, so there is no fast-forward. The options: (a) move
`cx-home/v-cx-patches` to `501ce6e5f` by a force update, keeping `a469af9cf` as
`archive/v-cx-patches-2026-09-23`; **(b) a new tracked name, `cx-patches-0.18`, at `501ce6e5f`
(created on `cx-home/v` by the integrator, 21:46Z), with `.gitmodules`' `branch=` and every reader of
the old name moving to it; `cx-home/v-cx-patches` stays untouched**; (c) leave it — the pin resolves
by sha, and a stale `branch=` misleads every future pin bump. Applied on the #1605 branch, not this
page's.

**D70a1 — `cx corpus`'s program lane owns the corpus vocabulary, after the cut; until then it refuses
what it does not read (#1636).** The program lane graded cases whose sections it never reads
(`[cli-argv]`, `[exit-code]`, `[init]`): `conformance/llm/antipatterns.cxd` showed three false FAILs
and twenty exit codes passing unchecked. The options as first posted: (a) the program lane owns
`[cli-argv]` / `[exit-code]` — it spawns the binary when `[cli-argv]` is present and checks the exit;
a corpus-vocabulary spec sentence; the shards' contract and census move (RS-16's condition) — one
grader for the whole vocabulary, every CLI example graded for real; (b) mirror #1631 — the program
lane REFUSES by name a file carrying a section it does not read (`corpus.program.gradeable`),
`antipatterns.cxd` stays graded by `primer_build.cx` — no false pass and no false fail, the CLI lane a
later decision; (c) leave it — false FAILs and silent passes stay. **The owner's answer, (a1): (a) is
the END STATE — the program lane owns every section the corpus vocabulary allows (`[cli-argv]`,
`[exit-code]`, `[init]` …), spawning the binary when `[cli-argv]` is present and checking the exit —
implemented AFTER the cut as its own design item, with its corpus-vocabulary spec sentence, the
shards' contract and census moving then on a still tree (RS-16's condition met); MEANWHILE (b) merges
in the next Ring-1 batch, so the false FAILs and the unchecked exit codes stop this week and
`primer_build.cx` keeps grading that file.** The reason given: the ruling is what agents need today,
and the timing keeps RS-16's contract still during the split. #1636 stays open until (a) merges.

**D71a — the builtin-dispatch registration hook.** Five mail files could not leave with
cx-platform-mail (`vcx/code/stdlib_{imap,imap_server,smtp,smtp_server,sasl}.v`):
`vcx/code/stdlib_dispatch.v` calls their `*_stdlib_builtin()` as plain intra-module V functions (the
pre-RS-18 dispatch, never migrated to the per-family `ring2_register.v` shape), and a V module is one
directory, so a file move cannot compile them outside `code`. The same pattern meets every V product
whose row declares a `half=`. The options, as the board posted them (2026-09-23 ~22:4xZ): **(a) the
registration hook — `code` exposes a builtin-dispatch registry; each product's own `init()` registers
its `*_stdlib_builtin` (the shape every other split product already uses through `ring2_register.v`);
the five files move to `vcx/mail/`, the rows' `half=` becomes `none`; one branch (RS-19's owed
refactor) before the halves of any product leave. Long-term: `code` knows no product by name; every
product registers the same way; a product repository holds ALL of its code**; (b) the five stay in
`vcx/code`, re-allocated to `cx-core-code` with a `why=` each (a `half=` is a Ring-1 half by the
AGENTS.md doctrine; sasl's row is Ring 1 already) — SMTP/IMAP server logic then lives in the core
repository forever, and `code` keeps a by-name call into each product; (c) leave it —
`cx-platform-mail`'s row stays partial, with the stale-copy risk and a lie in `repos.cxd`. The owner
answered (a) (~01:0xZ); the survey of every `half=` row rides the same branch.

**D72a — a `status=planned` row may carry `repo=`.** The net extraction gave the ftp and sftp rows
`status=planned` beside `repo=` — no row had combined the two before, and `registry/modules.cxd`'s own
comment described `repo=` without mentioning `status=planned`; the branch flagged it as a judgment,
not a rule. The answer, as the board records it (~01:2xZ): **(a) a `status=planned` row may carry
`repo=` — the repository where the module lands when it ships; one sentence in the registry README
says so; `deps-present` skips planned rows.** The board recorded the answer only; the letter's other
options were not posted there. Authorized sentence: one, in the registry README, saying the above.

**D56a, its second letter — the Ring-0 grading cores move into cx-core-data (#1624).** Since the
core-data leave, the data cx is built from `deps/cx-core-data/vcx/cmd_data`, which cannot import this
tree's `vcx/corpus/` (allocated to `cx`; which repository owns the grading cores is #1624), and the
ring-import gate's `cmd_data` contract admits `cx code cli cmd_data` only — so D56a above could not be
implemented as written. The options, as the Ring-1 batch posted them (2026-09-24 ~02:0xZ): **(a) move
`vcx/corpus/document`, `difflint` and `streaming` (Ring 0; `fmtlane` stays, it needs the evaluator)
into cx-core-data as modules both `cmd_data` and `cx` import, then give the data cx the verb and
`cx_partition.md` §4 the word — cx-core-data grades 25 of its 26 files with its own build**; (b) keep
the cores in cx; the data cx stays without `cx corpus` and cx-core-data grades itself with the full
cx. The owner answered (a) (~02:1xZ): `cx corpus` means the same in both repositories, and #1624's
ownership question resolves the same way (the data-side cores are cx-core-data's). Its branch follows
the D71a hook.

## Not decided here (RS-30, RS-31)

The order of work is the board's, not this page's: D55c, D56a, D62a and D63a are decision-free fixes
for the next Ring-1 batch; D54c and D64c are the package-lanes work; D65d, D67a and the documentation
epic under RS-30 open after the cut. D66a records placements the store split already made; D68a and
D69b are applied by the branches named with them; D70a1's interim (b) is the next Ring-1 batch's and
its end state (a) a design item after the cut. D71a is its own branch, before any product's `half=` leaves; D72a's README sentence rides the next registry-touching branch; D56a's second letter is a branch after D71a's. The spec sentence (a) needs is not written by this
page. No
sentence of any spec beyond the ones named above is authorized by this page.
