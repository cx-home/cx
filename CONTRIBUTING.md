# Contributing to CX

Thanks for your interest in contributing. CX is pre-1.0 — there is
real room to influence the format, the bindings, the tooling, and the
spec. Bug reports, doc fixes, and PRs are all welcome.

This file covers dev setup, the test matrix, the pre-merge development
loop and how a long run is started and waited on, the audit-driven
coding rules every PR is held to, and the commit / PR conventions. The
rules that do not bend — and which file wins when two of them disagree —
are in [`AGENTS.md`](AGENTS.md).

For the format itself, start with the docs site
([cx-home.github.io/cx](https://cx-home.github.io/cx/) online; locally,
run `make guide` and open `docs/guide/index.html` — the guide is
generated build output). For the formal contracts, see
[`spec/03-approved/`](spec/03-approved/).

---

## Dev setup

### Prerequisites

- A C compiler (clang on macOS, gcc/clang on Linux) and `make`.
- The **patched V toolchain**, vendored as the `third_party/v` git
 submodule — clone with `--recursive` (or run
 `git submodule update --init --recursive` in an existing checkout)
 and build it once with `make -C third_party/v`. CX's core is
 implemented in V, and the vendored fork carries patches the build
 relies on (macOS hardened-runtime / `-prod` fixes, the picoev
 shared-listener support the HTTP multi-reactor needs). Every `make`
 recipe prefers `third_party/v/v`; a system V from
 [vlang.io](https://vlang.io) is only a degraded fallback (`-prod`
 is silently dropped and GC patches are absent).
- For each language binding you intend to test, the corresponding
 toolchain. v0.8.0 Tier-1 bindings: Python 3.10+, Go 1.21+,
 Rust 1.75+. (TypeScript / Java / C# / Kotlin / Swift / Ruby are
 archived under `lang/_archived/` for v0.8.0; restoration is
 post-tag.)

[devbox](https://www.jetify.com/devbox) optionally pins all of the
above; `devbox shell` drops you into an environment with the right
versions. It's optional — system installs work fine.

### First build

```sh
git clone --recursive https://github.com/cx-home/cx
cd cx
make -C third_party/v # one-time: build the vendored patched V toolchain
make build # compile V core into libcx + build every binding
make promote-cli # install the `cx` CLI to /usr/local/bin
cx --version
```

**The pins come first (#1643).** The build embeds the bundled sources of the
repositories `deps.cxd` pins, so it needs `deps/`, and `make deps-sync` fetches
it with a cx: `CX_BIN=` when given, else this tree's `vcx/target/cx`, the main
checkout's (the first row of `git worktree list`, which is what a new worktree
has), a `cx` on `PATH`, then `~/.local/bin/cx` — and it says which it used. A
box with none of them installs a released cx, or passes `CX_BIN=<path to one>`.

`make build` is incremental. Sub-targets:

| target | builds |
| ------ | ------ |
| `make build-vcx` | V core (`libcx`, `cx` CLI) only |
| `make build-rust` | Rust binding (depends on libcx) |
| `make build-go` | Go binding (depends on libcx) |

The Python binding has no separate build step — it loads `libcx` at
import time.

With devbox the whole first build is one verb, and so is the proof that a new
box is sound:

```sh
devbox run setup      # submodules, the patched V, make build-vcx, make check-v-fork, cx --version
devbox run baseline   # the whole post-merge pipeline once; prints the verdict and the elapsed minutes
devbox run runner     # join as the post-merge runner (scripts/runner/README.md)
```

`setup` is idempotent. `baseline` is the row a new machine records on the
split board (#1591) before it runs anything else.

---

## Testing

### Run the full matrix

```sh
make test # every binding's test suite + the V core
make conform # conformance suite against vcx
```

Both must be green before any PR is merged.

### Run a single binding

```sh
make test-python
make test-go
make test-rust
# … one per binding
```

Fast loop when you're modifying one binding — typically 5–30 seconds.

### Conformance

The conformance suite is a corpus of CX inputs and expected outputs
across the supported conversion surfaces: the 5 data formats (CX,
XML, JSON, YAML, TOML), the delimited family (CSV / TSV / PSV /
arbitrary single-char), and the Markdown codec.
It runs against the V implementation; bindings inherit conformance
because they are thin wrappers around `libcx`.

If you change the grammar, the conversion logic, or anything format-
adjacent, `make conform` must pass before you push.

### Bare / out-of-tree checkouts and lane skips

Many `vcx/tests/` lanes (the http/net/xap/store service lanes) exec the
built CLI. They resolve it through `testenv.cx_bin()`, which prefers the
dev artifact `vcx/target/cx-dev` and falls back to the shipped
`vcx/target/cx` — two paths since #1312, because `make test` runs dev and
prod lanes in one `-j` storm and a single shared path let them clobber
each other. The one setup step a fresh checkout needs before invoking
`v test` directly is:

```sh
make build-vcx-dev
```

`make test-vcx-suite` performs that build for you. A lane whose
environment prerequisite is absent — the unbuilt binary, an opt-in
external service such as `CX_TEST_S3_ENDPOINT`/`CX_TEST_FTP_URL`/
`CX_TEST_SFTP_URL`, or a missing host tool like `openssl` — **self-skips
with a named reason instead of failing**, so a bare checkout never reads
as a wall of phantom regressions. Whole-lane skips are recorded in
`vcx/target/test-skips.d/` — one file per skipping lane, so concurrent
lanes under `make -j` cannot overwrite each other's entry — and `make
test-vcx-suite` merges them into the skipped-with-reason digest it prints
after the run (they are counted separately,
never as failures). Plain `v test` suppresses the output of passing
lanes; use `v -stats test …` to see `SKIP` lines inline. The binary
path is resolved relative to the source tree, so lanes behave the same
from any invocation directory.

### The development loop — `make test-changed`

The delivery grammar's words are used throughout this section and
[`spec/03-approved/process/delivery-grammar.md`](spec/03-approved/process/delivery-grammar.md)
defines them. A **step** is one command with a pass/fail exit (a make target, a
test file). A **pipeline** is an ordered set of steps, and two exist: the
**pre-merge** pipeline (your branch's subset, in your worktree — `make
test-changed BASE=<integration branch>` plus any step your branch adds) and the
**post-merge** pipeline (all of `make test`, on the integration branch's head).
A **run** is one pipeline on one commit; its status is passed, failed or
cancelled. A **runner** executes runs one at a time, and there is one per
pipeline.

The pre-merge pipeline is the development loop; the post-merge pipeline is what
a branch is merged into.

```sh
make build-vcx        build the toolchain (the `cx` binary lands in vcx/target/)
make test             the whole post-merge pipeline — run this once, at the end
make test-changed     only the steps whose inputs your change touched
make test-changed-dry the same selection, printed and not run
make docs             regenerate the LLM layer after changing a cited fixture
make docs-check       the drift gate; fails if the layer is stale
make guide            the human-facing documentation site
scripts/gate.sh       run a pipeline and ALWAYS write a verdict marker
```

`make test-changed` reads the change set, intersects it with a per-step input
manifest in [`scripts/test_changed.sh`](scripts/test_changed.sh), and runs only
the steps that can possibly have moved. It is conservative by construction: a
step with no manifest row always runs (and says so), a touched
`Makefile`/`scripts/`/`VERSION`/`devbox.*` collapses to the full union, and the
globs over-include on doubt — a false "run" costs minutes, a false "skip" costs
correctness.

`BASE` sets the window and defaults to `HEAD`, i.e. the work you have not
committed yet. Widen it when your change is already committed:

```sh
make test-changed                            # uncommitted work only (default)
make test-changed BASE=origin/release/0.18   # the whole branch
make test-changed-dry BASE=HEAD~3            # show the decision, run nothing
```

**`make test-changed` never substitutes for `make test`.** The post-merge
pipeline is the whole union, and it is what a release exits on.

### Starting and waiting on a long run

A run that outlives a single command goes through
[`scripts/gate.sh`](scripts/gate.sh), started as a background job your session
can see, with its output going to a log file you can read. `gate.sh` writes its
verdict marker from a `trap ... EXIT`, so the marker is unconditional, and it
signals make's whole process group on the way out instead of orphaning the run.

The idiom to avoid is a detached wrapper whose output is discarded —
`nohup sh -c 'make test' > /dev/null 2>&1 &` and its relatives. It writes no
marker if the wrapper is killed, so an `until grep -q RUN-EXIT= ...` waiter
polls forever; #1333 found three such waiters alive three hours after their run
had died, and a piped run loses the per-step summaries besides. Read the
verdict **from the log**:

```sh
until grep -q 'RUN-EXIT=' vcx/target/gate.log; do sleep 30; done
```

The marker carries the exit code AND the status word: `RUN-EXIT=0 passed`,
`RUN-EXIT=2 failed` (a real failure), `RUN-EXIT=130|143|129 cancelled`
(interrupted / terminated / hung up), `RUN-EXIT=70 failed` (the wrapper died
before make returned). Logs written before this change say `GATE-EXIT=`
instead, and every reader in the tree still accepts that spelling; the file
names (`gate.sh`, `gate.log`, `gate-loop.log`) have not moved either.

`scripts/gate-status.sh` reads that log and prints the run in the same words:
state `running`/`passed`/`failed`/`cancelled`, how many steps are failing, which
steps have finished, and what is running now.

### The post-merge runner on a box

The loop that runs the post-merge pipeline on every new head lives under launchd
as `ai.cx.gate-loop`, and its unit, the three runner directories and the
install / status / restart / stop verbs are in
[`scripts/runner/`](scripts/runner/README.md). A new box joins with
`devbox run runner` after `devbox run setup` and a green `devbox run baseline`
(§First build above); a landed `scripts/gate-loop.sh`
takes effect only after `devbox run runner-restart`, between runs.

### Adding a test file costs more than adding a test function

Test *files*, not test functions, are the unit of compile cost: every
`*_test.v` links its own binary over the whole module graph, so a new standalone
test file costs a whole-graph link on every run. Add test functions to the
umbrella that already owns the area — the roster is
[`scripts/consolidation/`](scripts/consolidation)`/<area>.files` and
`scripts/consolidate_tests.sh absorb <area>` folds a stray file in — and
introduce a standalone `*_test.v` only when the step genuinely needs process
isolation (a real socket, a serial-retry class, an exclusion in
`scripts/publish_v.sh`).

### A cited fixture carries its docs regeneration

If you change a conformance fixture the primer cites, run `make docs` and commit
the regenerated `docs/llm/` **in the same change**. The `docs-check` gate exists
so that never becomes optional.

**A cited fixture is not the only docs-layer input.** `docs/llm/reference-cli.md`
is generated by **running `cx --help`**, so adding, renaming or re-wording a
flag or subcommand drifts it — and `llms-full.txt` with it, since that
concatenates every document. `docs-check`'s step-input row in
[`scripts/test_changed.sh`](scripts/test_changed.sh) is accordingly wide
(`docs-src/* docs/llm/* scripts/gen_docs/* conformance/* spec/* stdlib/* x/*
vcx/* VERSION`): **any** `vcx/` change selects it. So if you touch the CLI
surface, `make docs` belongs in the same change for the same reason.

Measured 2026-09-08: a new `--manual-clock` flag landed without a regeneration
and failed the full matrix on `docs-check` alone, with two DRIFT lines and
nothing else wrong in the tree.

---

## Coding rules

CX has a small number of normative rules from the
2026-05 binding audit. Conformance to
them is a release gate. The full text is in
[`spec/03-approved/process/governance.md`](spec/03-approved/process/governance.md). The most important rule:

### The native-implementation rule (no roundtrips on hot paths)

> No public function in any binding may call another public function
> of the same library and re-parse its string output. Bindings either
> call a C ABI symbol that returns native bytes (binary AST or data)
> and deserialize once, or walk an in-memory structure already held
> by the binding. **String-format roundtrips are forbidden on hot
> paths.**

The audit (CB-1..CB-3) found this pattern in every binding — it was
slow, lossy, and undermined the multi-format guarantees. All five
findings closed in the v0.6.0 cycle; please don't reintroduce them.

In practice: when you add a new public function in a binding,

- the implementation goes through one C ABI call returning native
 bytes (binary AST, binary data, or a handle), and
- you decode those bytes once. No second parser, no JSON detour.

The C ABI surface is documented in [`spec/03-approved/core/abi.md`](https://github.com/cx-home/cx-core-data/blob/main/spec/03-approved/core/abi.md). If
you need an operation without a binary-bytes symbol yet, the right
move is to add one at the V core, not to chain two text converters
in the binding.

### Other release gates

- **Parity matrix** ([`spec/03-approved/process/governance.md` §2](spec/03-approved/process/governance.md)) —
 every public function exists with consistent signatures across all
 Tier-1 bindings (V / Python / Go / Rust as of v0.8.0). New API
 additions touch every Tier-1 binding in the same PR series; see
 [`spec/03-approved/misc/bindings.md`](spec/03-approved/misc/bindings.md) for the two-layer contract.
- **Strategy declaration** (§3) — each binding's README declares
 which implementation strategy it uses. Updates here travel with
 the code change.
- **Performance SLA** (§6) — `cx_to_data_bin` and friends have
 documented budgets in `spec/03-approved/process/governance.md`.

---

## Commit and PR style

### Commit messages

Subject line: `<scope>: <change> (Phase X.Y if applicable)`. Examples
from recent history:

```
core: add cx_select_all_paths C ABI (Phase 4 / CB-5 enabler)
python: thunk CXPath via cx_select_all_paths (Phase 4.1) — closes CB-5
docs: add CHEATSHEET.md — one-page CX syntax reference (Phase 7.2)
```

Body: what + why, in a short paragraph. If the commit closes an audit
finding or implements a spec section, name it.

### PR scope

- One conceptual change per PR. A binding-only refactor is one PR; a
 spec change is another.
- For changes that touch every binding, batch by phase: a "Phase 5.1
 Python" PR, a "Phase 5.2 Go" PR, … each self-contained and testable
 on its own.
- Doc-only PRs are welcome standalone.

### Before you push

- `make test && make conform` is green locally.
- Your binding-specific suite is green: `make test-<binding>`.
- If you added a new public function: every binding has it, with the
 strategy declared.
- If you added a new C ABI symbol: it's documented in
 [`spec/03-approved/core/abi.md`](https://github.com/cx-home/cx-core-data/blob/main/spec/03-approved/core/abi.md) with input/output framing.

---

## Reporting bugs

File issues at [github.com/cx-home/cx/issues](https://github.com/cx-home/cx/issues).
A useful bug report includes:

- The CX input that triggered the issue (or a minimal reduction).
- The binding (V / Python / Go / …) and version.
- What you expected vs what you got.
- Output of `cx --version` and your platform (macOS arm64 / Linux
 x86_64 / …).

For security reports, see [`SECURITY.md`](SECURITY.md).

---

## Where to ask questions

- Issue tracker for bugs and design questions.
- GitHub Discussions on the same repo for longer-form conversation.

CX is small enough that maintainers respond directly on the tracker.
That will eventually change; the discussion forum is the durable
fallback.
