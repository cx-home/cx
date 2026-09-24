# AGENTS.md

Instructions for any coding agent working in this repository, vendor-neutral
by convention ([agents.md](https://agents.md)).

**This file is hand-authored and deliberately minimal.** Agents read it raw
from the checkout, before anything is built, so it can carry only what is
stable: what CX is, the rules that do not bend, and where the real
documentation lives. It contains **no code examples** — anything that can
drift lives in the generated layer described below, where a gate catches the
drift.

## What CX is

CX is a **homoiconic data-and-code language**: one bracketed element syntax
serves documents, queries, programs, and the compiler's own AST. It is built
in two rings, data and code, and the platform, bindings and ecosystem groups
above them — and the import contract between them is enforced by the build,
not by convention.

CX post-dates every language model's training data. **Whatever you recall
about a language called "CX" is not this one.** Nothing you assume about its
syntax transfers. Read the primer first.

## Read this before writing any CX

```
cx primer
```

That prints the primer embedded in the installed binary, so it always matches
the toolchain you are actually running. If the version in its header does not
match your binary, trust the binary.

Same content in the checkout, plus the per-area references:

- [`docs/llm/primer.md`](docs/llm/primer.md) — the one file to load. The
  surface taught through runnable examples, a ring decision table, the core
  idioms, and the anti-patterns that Lisp/Clojure/shell priors produce.
- [`docs/llm/playbook-xap.md`](docs/llm/playbook-xap.md) — load this when the
  task is building a feature deployment: composing feature grammars, derived
  nouns and deriver principals, the authority model, the `*.xap.cxd`
  deployment document, identity bootstrap, hosting, and the ux-web surface.
- [`docs/llm/llms.txt`](docs/llm/llms.txt) — the index, with a reference file
  per area (data language, code language, stdlib, CLI, platform). Load one
  only when the task needs it.
- [`docs/llm/llms-full.txt`](docs/llm/llms-full.txt) — all of it, concatenated,
  for a single fetch.

Those files are **generated** from the conformance corpus — see
[`scripts/gen_docs/README.md`](scripts/gen_docs/README.md). Never hand-edit
them.

## The rules that do not bend

1. **The spec is the only truth.** Normative text lives in
   [`spec/03-approved/`](spec/03-approved). There are no ADRs and no design
   docs that override it. Do not edit a spec to match an implementation
   shortfall, and do not edit one at all during an implementation phase
   without explicit authorization.
2. **The conformance corpus is the executable truth.**
   [`conformance/`](conformance/README.md) is where behavior is pinned. Write
   the fixture before the fix. An example anywhere in this repo that is not
   backed by a fixture is a liability.
3. **No stubs, no partial implementations, no stopgaps.** A seam with no live
   consumer is a partial implementation. If something cannot be finished,
   say so and stop — do not ship a placeholder, and never reduce scope
   silently to make a test pass.
4. **Flags bind before the resource.** The run surface is
   `cx [cx-flags] FILE [program-args...]`. Everything after the file belongs
   to the program. Run files with `cx FILE`, not with the legacy `cx eval`
   alias.
5. **The version derives from `VERSION`.** The repo-root `VERSION` file is the
   single source of truth. Never write a second copy of a version string
   anywhere — derive it. A gate enforces this.
6. **Tooling is written in CX.** New scripts are CX programs run with
   `cx <file>`. Choosing another language needs a filed, argued reason: a
   `cx-gap` issue — the task, the cx attempt, the gap by kind — filed BEFORE
   the other language runs, for a probe, a bisect or a scratch script as much
   as for a checked-in tool (RULED: CXF-1, #1522). Eat our own dog food.
7. **Work lands on the current release branch, never on `main`.** Check
   `git branch --show-current` before committing, and branch first if you are
   on the default branch.
8. **Do not push, tag, or publish** unless you were explicitly asked to. The
   public mirror is produced by an allowlist script; it is not a place to put
   things by hand.
9. **Follow-ups belong in the issue tracker**, with a kind label, an `area:*`
   label, and a `prio:*` label — not in code comments and not in a scratch
   file.
10. **Never dress a claim in authority you do not have.** Say what you
    measured and what you inferred, and label which is which. Do not write in
    the project owner's voice, and do not mark something urgent to get it
    prioritized.

## Which file wins — this repo

Several things can tell an agent what to do here, and until 2026-09-13 none of
them said which one governs. This is the order (RULED: CFG-1, #1438):

1. **The owner's live word**, in the session or on the issue.
2. **This file** — the rules that do not bend, above.
3. [`AGENT-STANDING-RULES.md`](AGENT-STANDING-RULES.md) — the standing rules
   every agent working a v0.18 issue reads before its brief: how to stay
   alive, the git and worktree rules, the shared pre-merge runner, the
   pipeline shape, and what `READY` means. It is tracked content, edited
   through a branch like anything else. Where it is *more specific* than this
   file it governs; where it *contradicts* a rule above, this file wins and
   the contradiction is a defect to file, not a choice to make.
4. **The process specs** —
   [`spec/03-approved/process/delivery-grammar.md`](spec/03-approved/process/delivery-grammar.md)
   for the vocabulary (release, epic, issue, decision, spec; branch, worktree,
   integration branch, merge; owner, integrator, agent, session; step,
   pipeline, run, runner, flaky test, artifacts) and the rest of
   [`spec/03-approved/process/`](spec/03-approved/process) for governance,
   readiness and the release process.
5. [`ledger/`](ledger) — the decision store. A decision that has been taken
   is recorded there and is binding; `ledger/README.md` indexes every
   `RULED: <id>` to the file and heading that carries it. The ledger records
   decisions; it does not make them.
6. [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to build, test and submit.
   Operational detail, not authority.

A harness template — any per-tool scaffolding an agent arrives with — sits
below all of these and never overrides one of them.

### The three conflicts this order resolves

- **Pushing.** An agent pushes *its own branch* and nothing else. Never
  `main`, never the integration branch, never a tag, never the public mirror.
  Rule 8 above is the general form; the exception an agent has is exactly one
  branch, its own.
- **Long runs.** A run that outlives a single command goes through
  [`scripts/gate.sh`](scripts/gate.sh) (or the shared pre-merge runner named
  in the standing rules), started as a background job the session can see,
  writing to a log file. Never a detached wrapper whose output is discarded —
  a run with no log and no verdict marker cannot be waited on, and #1333
  found three waiters alive three hours after their run had died.
  There are **two** pre-merge runners and the step decides which one a branch
  queues on (RULED: INT-8): a load-SENSITIVE step — the memory gauges, the
  performance ratchet, the real-socket tests — goes on `.build-slot-impl`,
  where one run at a time is the point; everything else may use
  `.build-slot-impl2`. A branch never queues the same run on both.
  `CONTRIBUTING.md` §Testing has the mechanics.
- **Exit statuses.** Read a command's status **directly**, or from **inside**
  the script devbox runs — never from an inner shell that `devbox run` wraps
  (#1570). Measured on `5a897f485` against a program that exits 7:
  `devbox run -- <cmd>` then `$?` reports 7, and a pipeline's own
  `"$@" > log 2>&1; echo "EXIT=$?"` reports 7; the same status read out of an
  inner shell inside `devbox run` reports **0 — success, for a program that
  failed**. `devbox run` executes its arguments through a generated
  `.devbox/gen/scripts/.cmd.sh` and loses the inner command's status there,
  while a bare `exit N` in that position survives, which is why the trap reads
  as a cx defect rather than a wrapper one: it cost a wrong `prio:high` issue
  (#1569, withdrawn), in which `[$env:exit N]` looked broken and a dozen
  `TEST_TARGETS` gates looked vacuous. Both were fine.
  [`scripts/exit_status_probe_gate.sh`](scripts/exit_status_probe_gate.sh) is
  the step that holds the line; a probe that cannot be trusted is worse than no
  probe, and this one is quiet.
- **Words.** `decision` is the noun for a thing the owner has ruled;
  `RULED:` is the token that carries its id in a commit subject and in the
  ledger. Not "ruling", not "campaign", not "lane", not "gate run".
  `delivery-grammar.md` is the whole vocabulary and it is the only one.

## Where a surface lives — the rings and the platform group

The tree is ring-legible (RULED: 1427-a…j, OL-14/OL-15, RS-1). Ring 0 is the
data format and Ring 1 the language; they are the only rings, and everything
above them is a group. A bundled module is **Ring 1** if it is pure or purely
local, and **Ring 1 in the platform group** if it serves, or reaches a store
or a protocol — *a module lives in the ring of its highest verb, and the group
is what lets it import the platform graph* — and every artifact of it says so
without a reader opening a file:

| Dimension | Ring 1 | Platform group (`ring=1 group=platform`) |
|---|---|---|
| namespace | `[?lib 'cx-stdlib/<name>']` | `[?lib 'cx-platform/<name>']` |
| spec | `spec/03-approved/stdlib/` | `spec/03-approved/platform/` |
| corpus | `conformance/stdlib/` | `conformance/platform/` |
| V code | `vcx/code/` | `vcx/<product>/` — one V module per V product, `vcx/xap/` the one that composes them (RULED: RS-24, D31a; `registry/repos.cxd`'s `vmodule=` names each) |
| catalog | `spec/03-approved/stdlib/README.md` | `spec/03-approved/platform/README.md` |

A surface's ring and group are **DECLARED once**, in
[`registry/modules.cxd`](registry/modules.cxd) — one row per shipped surface,
carrying its ring, group, namespace, spec, corpus, bundled source and code
files — and `make placement-gate` refuses a tree where any of those disagrees
with the row, where an artifact under a ring or platform directory has no
row, or where a row still says `ring=2`. So: **state a new module's ring, its
group and its directories in its DECISION, before any spec or code** (OL-15),
then write the row, then the artifacts.

Two edges worth knowing. A platform module may keep a pure Ring-1 half in
`vcx/code` for profile composition; the half is named in its row's `half=`
column and is not a second surface — and the trigger to promote one into a
module of its own is the first Ring-1 **consumer** of it (that is how
`cx-stdlib/http-client` split out of `cx-platform/http`). And `cx-x/<name>` is
the experimental tier, exempt from the frozen-stability promise, with its
specs in `spec/03-approved/x/` and its corpora in `conformance/x/`.

## Working in this repo

[`CONTRIBUTING.md`](CONTRIBUTING.md) carries the build and test surface: the
targets, the pre-merge development loop (`make test-changed`), how a long run
is started and waited on, and the two rules that catch people out — a new
standalone `*_test.v` costs a whole-graph link on every run, and a change to
a fixture the docs cite must carry its `make docs` regeneration in the same
commit.
