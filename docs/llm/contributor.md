# CX contributor front door — the rules, and what to load

> **GENERATED FILE.** Source: `docs-src/llm/contributor.md.tmpl`, the ledger's
> `RS-n` statements and two conformance fixtures, assembled by
> `scripts/gen_docs/primer_build.cx`. `make docs-check` refuses this file when
> it drifts from them. Edit the template, never this file.
>
> Read `cx primer` first — it teaches the language. This file teaches the
> PROJECT: how CX is built, changed and graded, so a change you make is the
> one a maintainer would have made.

## TL;DR

- CX is built so that a claim can be checked: the spec states it, a corpus
  case pins it, a gate refuses the tree that breaks it. Contribute in that
  order and nothing you write has to be taken on trust.
- Two frozen rings (data, code) and product groups above them, each product
  its own repository, pinned by sha. You change the smallest ring that owns
  the behaviour and nothing above it moves.
- Every rule below cites the decision (`RULED: <id>`) that made it; the
  ledger (`ledger/README.md` indexes every id) is where to read the reason.
- Load ONE area file for the task. The table in §1 is the whole routing.

## 1. The reading order — load the least that answers the task

| Task | Load, in order | Never load |
|---|---|---|
| Write or fix a CX program | `cx primer` → the one `reference-*.md` the primer's §11 names | the spec whole; `llms-full.txt` |
| Add or move a module / surface | this file → `contributor-design.md` → the module's row in `registry/modules.cxd` → its spec's named section | `registry/repos.cxd`'s `why=` prose; other modules' specs |
| Change V code (evaluator, a product) | this file → `contributor-implementation.md` → the one V module directory | `third_party/v/`; `deps/*/` trees other than the pin you change |
| Know where something lives / who pins what | `contributor-architecture.md` | the repositories themselves, one by one |
| Choose and run the tests for a change | `contributor-test.md` → `scripts/test_changed.sh <base> --dry-run` | `make test` (the post-merge union); the Makefile whole |
| Cite or check a decision | `ledger/README.md` (the index) → the one page and heading it names | the ledger directory whole |
| Write documentation | `contributor.md` §3 rule 17 → `scripts/gen_docs/README.md` | hand-copied examples from anywhere |
| Read a failure | the run log's `STEP-START`/`STEP-END` lines and the failing step's own block | the whole interleaved log top to bottom |

Size discipline: the language corpus (`deps/cx-core-code/conformance/code.cxd`)
is the largest corpus file — find a case by id (`grep -n 'id=<id>'`),
never read it. Find a step in the Makefile by `grep -n '^<step>:'`. A spec page
is read by the section its decision names, never whole.

## 2. What CX guarantees, pinned by the corpus

Two properties every contribution preserves. Both are corpus cases, replayed
against the binary each time this file is generated.

**Effects are deny-by-default** — reading a file with no grant is an ordinary
error value naming the flag that would allow it:

<sub>Generated from the corpus case `io-001-read-file-cap-denied` (`cx-core-code`, `conformance/stdlib/io.cxd`), replayed by `make docs` — do not edit here.</sub>

`prog.cx`
```cx
[?lib 'cx-stdlib/io']
[$io:read-file "/var/log/app.log"]
```

```console
$ cx prog.cx
[err code=cx-err:CXER0271 message='E_CAP_DENIED: read capability required for io-read-file; none granted (grant via --allow-read)']
```

**Errors are values** — a captured `[err]` propagates out of any element built
from it, with no `try` and no exception:

<sub>Generated from the corpus case `program-construction-err-004-captured-err-propagates` (`cx-core-code`, `conformance/code.cxd`), replayed by `make docs` — do not edit here.</sub>

`prog.cx`
```cx
[?let [= $e [err code='c' message='m']] [report $e]]
```

```console
$ cx prog.cx
[err code=c message=m]
```

A change that makes either of these false is refused by the corpus, whatever
else it fixes.

## 3. The rules for the best long-term change

Each is a rule, the decision behind it, and the step that refuses a tree that
breaks it. Where the ledger has the rule's own words, §4 prints them.

| # | Rule | Decision | Held by |
|---|---|---|---|
| 1 | **The spec is the only truth.** Normative text is `spec/03-approved/`; no design note overrides it; never edit a spec to match an implementation shortfall. | AGENTS.md rule 1 (RULED: CFG-1) | `spec-freeze-gate`, `check-no-adr-citations` |
| 2 | **A spec edit and its impl edit carry a recorded decision.** The `RULED:` id is on the ledger BEFORE a commit cites it. | the spec-freeze register (RULED: R4.1) | `spec-freeze-gate`, `ledger-index-check` |
| 3 | **The corpus is the executable truth; the fixture comes before the fix.** A behaviour change lands its failing case first, then the code that passes it. | AGENTS.md rule 2 (RULED: CFG-1) | the fixture graders, `check-code-fixtures` |
| 4 | **No stubs, no partial implementations, no silent scope cuts.** A seam with no live consumer is a partial implementation; what cannot be finished is said and stopped. | AGENTS.md rule 3 (RULED: CFG-1) | `check-no-stub-impl` |
| 5 | **Two rings, then groups.** Ring 0 cannot execute; Ring 1 cannot reach a socket, a store or a protocol; everything else is a group with a declared, acyclic import graph. | RULED: RS-1 | `ring-import-gate`, `placement-gate` |
| 6 | **A module lives in the ring of its highest verb**; a pure half a Ring-1 consumer needs becomes its own Ring-1 module. | RULED: OL-14 | `placement-gate` |
| 7 | **Placement before code.** A new surface states its ring, group and directories in its decision, then its `registry/modules.cxd` row, then spec, corpus, code. | RULED: OL-15, 1427-f | `placement-gate`, `stdlib-catalog-gate` |
| 8 | **One repository per product**, split where a person could own, release and explain it in one line. | RULED: RS-2, RS-3 | `repos-allocation-gate` |
| 9 | **Consumers pull, producers never push.** Every repository pins what it builds on by sha in `deps.cxd`; `cx` is a migration lane, never a gate. | RULED: RS-7 | `test-deps-pins`, `make deps-sync` |
| 10 | **The mover fixes what it breaks.** A lower repository keeps its specified surface compatible; an intentional break is a decision naming its consumers. | RULED: RS-8 | the consumer's own gate on the bump |
| 11 | **A V product imports the rings and its pins, nothing else**; one V module per product, explicit `import`s, a `pub` surface per caller. | RULED: RS-24 | `product-import-gate` |
| 12 | **Products register themselves.** A product adds its builtins and its CLI verbs from its own `init()`; the core knows no product by name. | RULED: D71a, D73a | the build of a profile without the product |
| 13 | **The ring decides where code lives, not its only consumer.** A pure Ring-1 V half stays in the core even when one product calls it. | RULED: D76c, D84a | `repos-allocation-gate` |
| 14 | **Tooling is written in CX.** Scripts, probes and bisects are CX programs; another language needs a filed `cx-gap` issue first. | RULED: CXF-1 | review; `reader-parity` holds every reader of the corpus files to one answer (RULED: CXF-5) |
| 15 | **A CX surprise is filed the same hour, with its reproduction.** A small defect in a module you already touch is fixed in your branch, fixture first. | RULED: CXF-8, FIX-1 | the issue tracker |
| 16 | **One vocabulary.** release/epic/issue/decision/spec; branch/worktree/integration branch/merge; step/pipeline/run/runner. | RULED: DG-1 | `spec/03-approved/process/delivery-grammar.md` |
| 17 | **Docs follow the module and are generated.** A reference is projected from its corpus at release; an example no fixture backs is a liability. | RULED: RS-9, RS-28 | `docs-check`, `verify-doc-blocks` |
| 18 | **CX's own voice.** Lead with why to reach for CX; state its case, never referee; a runnable example or a measured number beside every claim. | RULED: RS-30 | `docs-check` (the examples replay) |
| 19 | **The version derives from `VERSION`.** No second copy of a version string anywhere. | AGENTS.md rule 5 (RULED: CFG-1) | `check-version-consistency` |
| 20 | **No AI attribution, anywhere, ever** — no co-author trailer, no generated-by line, in any repository. | RULED: RS-33 | `check-no-ai-attribution` |
| 21 | **No consumer's name in the tree.** Every artifact speaks CX-generic workload terms (users, tracked entities, events, deployments); the tree is published. | the owner's standing decision of 2026-07-24, under RULED: RS-11 | `check-no-consumer-terms` |
| 22 | **Flags bind before the resource.** `cx [cx-flags] FILE [program-args]`. | AGENTS.md rule 4 (RULED: CFG-1) | the antipattern corpus |

When two sources disagree: the owner's live word, then `AGENTS.md`, then the
process specs, then the ledger (RULED: CFG-1). A harness template never
overrides any of them.

## 4. The standing decisions, in the ledger's own words

The `RS-n` series is the repository-split decision set every contributor works
inside. Each statement below is the ledger's bold lead or heading, verbatim;
read the page for the reason and the options refused.

<sub>Generated by `scripts/gen_docs/contributor_facts.cx` from the ledger pages' `RS-n` decision rows and headings, verbatim (36 rows) — do not edit here: change the source, run `make docs`.</sub>

| id | the ledger's statement | page |
|---|---|---|
| `RS-1` | Two rings, then groups. | `ledger/rulings_2026_09_21_repo_split_1589.md` |
| `RS-2` | Split by product, not by dependency graph. | `ledger/rulings_2026_09_21_repo_split_1589.md` |
| `RS-3` | The shape: `cx` (front door and distribution), `cx-core-data` (Ring 0), `cx-core-code` (Ring 1, the stdlib inside it), `cx-platform-{net, mail, identity, store, db, fabric, xap}` (V, compiled into the full `cx`, release with it), `cx-platform-{flow, connector, sso, ux, agent}` (pure CX, registry packages, their own cadence), `cx-binding-{python, go, rust, v}` (active) and `cx-binding-{typescript, java, kotlin, csharp, swift, ruby}` (archived repositories at the ABI they were frozen with), `cx-registry`, `cx-decisions`, `cx-tooling`. | `ledger/rulings_2026_09_21_repo_split_1589.md` |
| `RS-4` | Naming: `cx-<group>-<product>`; the bare `cx` is where a visitor starts. | `ledger/rulings_2026_09_21_repo_split_1589.md` |
| `RS-5` | Stdlib membership moves, by the membership test (cx_partition.md §10) and by consumer. | `ledger/rulings_2026_09_21_repo_split_1589.md` |
| `RS-6` | The store server authenticates through the Ring-1 trust primitives (did/vc verify, the authz decision) and its own `[grants]`, not through session tables. | `ledger/rulings_2026_09_21_repo_split_1589.md` |
| `RS-7` | Consumers pull, producers never push. | `ledger/rulings_2026_09_21_repo_split_1589.md` |
| `RS-8` | Break policy (owner, "1a"): within a release train a lower repository keeps its specified surface compatible; the repository that moved fixes what it breaks or ships the compatibility; an intentional break is a decision naming its consumers. | `ledger/rulings_2026_09_21_repo_split_1589.md` |
| `RS-9` | Docs follow the module. | `ledger/rulings_2026_09_21_repo_split_1589.md` |
| `RS-10` | Daemons stay subcommands of one `cx` (`store-serve`, `fabric-serve`, `flow serve`, the XAP host). | `ledger/rulings_2026_09_21_repo_split_1589.md` |
| `RS-11` | Public or private is a setting per repository. | `ledger/rulings_2026_09_21_repo_split_1589.md` |
| `RS-12` | Sequencing: the split starts now, during the suspension, and v0.18.0 ships from `cx` pinning the new repositories. | `ledger/rulings_2026_09_21_repo_split_1589.md` |
| `RS-13` | `authz` splits along the store-auth design line (owner: D14a) | `ledger/rulings_2026_09_22_repo_split_followups.md` |
| `RS-14` | did/vc's impure remainder gets modules named for what leaves (owner: D15b) | `ledger/rulings_2026_09_22_repo_split_followups.md` |
| `RS-15` | the xsp `auth-*` defs become `cx-platform/xsp-auth` (owner: D16a) | `ledger/rulings_2026_09_22_repo_split_followups.md` |
| `RS-16` | the `cx` binary grades a corpus file (owner: D13a) | `ledger/rulings_2026_09_22_repo_split_followups.md` |
| `RS-17` | the `-gc e` per-case growth is fixed at the root (owner: D3b) | `ledger/rulings_2026_09_22_repo_split_followups.md` |
| `RS-18` | builtin registration splits per family, before the db extracts (owner: D20a) | `ledger/rulings_2026_09_22_repo_split_followups.md` |
| `RS-19` | mail claims its smtp/imap pure halves, as `sasl` already is (owner: D19a) | `ledger/rulings_2026_09_22_repo_split_followups.md` |
| `RS-20` | flow's CLI verbs stay in the front door, and the act seam gets a row (owner: D21a) | `ledger/rulings_2026_09_22_repo_split_followups.md` |
| `RS-21` | a decision's design item may ADD spec text where the edit map is silent (owner: D22b) | `ledger/rulings_2026_09_22_repo_split_followups.md` |
| `RS-22` | `authz-store` and `vc-revocation` stay in `cx-platform-identity` (owner: D24a) | `ledger/rulings_2026_09_22_repo_split_followups.md` |
| `RS-23` | the decision half gets a pure `open` over an in-memory trust store (owner: D25b) | `ledger/rulings_2026_09_22_repo_split_followups.md` |
| `RS-24` | `vcx/platform` splits by product, one V module per V product (owner: D28a) | `ledger/rulings_2026_09_22_repo_split_followups.md` |
| `RS-25` | the mock adapter is declared by the kit's own CX, and the compile-time gate retires (owner: D30d) | `ledger/rulings_2026_09_22_repo_split_followups.md` |
| `RS-26` | RS-26…RS-31 — five spec-sentence authorizations, the afternoon letters, documentation and CI/CD, the documentation voice and the evening letters (owner, 2026-09-23, in session on dev2) | `ledger/rulings_2026_09_23_spec_sentence_letters.md` |
| `RS-27` | the afternoon letters of 2026-09-23 (owner: D49a, D50a, D51d, D52a, D53a) | `ledger/rulings_2026_09_23_spec_sentence_letters.md` |
| `RS-28` | one site, thin repositories, and cx created by the recipe (owner: D57a, D58a, D59a) | `ledger/rulings_2026_09_23_spec_sentence_letters.md` |
| `RS-29` | CI/CD is cx flow, documentation included (owner: D60a) | `ledger/rulings_2026_09_23_spec_sentence_letters.md` |
| `RS-30` | the documentation voice (owner, 2026-09-23 ~16:4xZ) | `ledger/rulings_2026_09_23_spec_sentence_letters.md` |
| `RS-31` | the evening letters of 2026-09-23 (owner: D54c, D55c, D56a, D62a, D63a, D64c, D65d, D66a, D67a, D68a, D69b, D70a1, D71a, D72a, D73a, D74c, D75a, D76c, D77d, D78a) | `ledger/rulings_2026_09_23_spec_sentence_letters.md` |
| `RS-32` | the front-door letters of 2026-09-24 (owner: D79a, D80a, D81a, D82a, D83a, D84a) | `ledger/rulings_2026_09_24_front_door_letters.md` |
| `RS-33` | zero AI attribution anywhere in any repository, ever (owner: D87, D88b) | `ledger/rulings_2026_09_24_no_ai_attribution_rs33.md` |
| `RS-34` | the letters of 2026-09-25 (owner: D89a, D90b) | `ledger/rulings_2026_09_25_llm_front_door_k11a.md` |
| `RS-35` | the V fork under the zero-attribution rule: strip the fork's own range only (owner: Letter 2 = (a), 2026-09-25) | `ledger/rulings_2026_09_25_v_fork_rs35.md` |
| `RS-36` | how a wave in a component repository lands after the split (owner, 2026-09-25, Letter 4 (a)) | `ledger/rulings_2026_09_25_component_waves_rs36.md` |

## 5. The area files

| File | Load it when | Generated parts |
|---|---|---|
| `contributor-architecture.md` | you need the repository map, the pins, the rings and groups, or the registration hooks | the repository map (`registry/repos.cxd`), the pins (`deps.cxd`) |
| `contributor-design.md` | a surface needs a ring, a group, a row, a spec and a corpus before code | the module census and the row's columns (`registry/modules.cxd`) |
| `contributor-implementation.md` | you are writing V: a module, an import, a registration, the front door's build | — (rules only; each cites its decision) |
| `contributor-test.md` | you are choosing, running or reading steps | the step roster (the Makefile's `TEST_TARGETS`), the umbrella files (the pins) |
