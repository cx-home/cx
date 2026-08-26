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
in four rings — data, code, platform, ecosystem — and the import contract
between them is enforced by the build, not by convention.

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
   `cx <file>`. Choosing another language needs a filed, argued reason. Eat
   our own dog food.
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

## Working in this repo

```
make build-vcx        build the toolchain (the `cx` binary lands in vcx/target/)
make test             the full gate matrix — run this once, at the end
make test-changed     only the lanes whose inputs your change touched
make test-changed-dry the same selection, printed and not run
make docs             regenerate the LLM layer after changing a cited fixture
make docs-check       the drift gate; fails if the layer is stale
make guide            the human-facing documentation site
```

Targeted lanes are the development loop; the full matrix is the exit gate.
[`CONTRIBUTING.md`](CONTRIBUTING.md) has the rest.

### The development loop

`make test-changed` is the loop. It reads the change set, intersects it with a
per-lane input manifest in [`scripts/test_changed.sh`](scripts/test_changed.sh),
and runs only the lanes that can possibly have moved. It is conservative by
construction: a lane with no manifest row always runs (and says so), a touched
`Makefile`/`scripts/`/`VERSION`/`devbox.*` collapses to the full union, and the
globs over-include on doubt — a false "run" costs minutes, a false "skip" costs
correctness.

`BASE` sets the window and defaults to `HEAD`, i.e. the work you have not
committed yet. Widen it when your change is already committed:

```
make test-changed                            # uncommitted work only (default)
make test-changed BASE=origin/release/0.17   # the whole branch
make test-changed-dry BASE=HEAD~3            # show the decision, run nothing
```

**`make test-changed` never substitutes for `make test`.** The release gate is
the full matrix, and it is what a wave or phase exits on.

Test *files*, not test functions, are the unit of compile cost: every
`*_test.v` links its own binary over the whole module graph, so a new standalone
test file costs a whole-graph link on every gate run. Add test functions to the
umbrella that already owns the area — the roster is
[`scripts/consolidation/`](scripts/consolidation)`/<area>.files` and
`scripts/consolidate_tests.sh absorb <area>` folds a stray file in — and
introduce a standalone `*_test.v` only when the lane genuinely needs process
isolation (a real socket, a serial-retry class, an exclusion in
`scripts/publish_v.sh`).

If you change a conformance fixture the primer cites, `make docs` and commit
the regenerated `docs/llm/` **in the same change**. The gate exists so that
never becomes optional.
