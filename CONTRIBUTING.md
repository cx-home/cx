# Contributing to CX

Thanks for your interest in contributing. CX is pre-1.0 — there is
real room to influence the format, the bindings, the tooling, and the
spec. Bug reports, doc fixes, and PRs are all welcome.

This file covers dev setup, the test matrix, the audit-driven coding
rules every PR is held to, and the commit / PR conventions.

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

`make build` is incremental. Sub-targets:

| target | builds |
| ------ | ------ |
| `make build-vcx` | V core (`libcx`, `cx` CLI) only |
| `make build-rust` | Rust binding (depends on libcx) |
| `make build-go` | Go binding (depends on libcx) |

The Python binding has no separate build step — it loads `libcx` at
import time.

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
built CLI at `vcx/target/cx`. The one setup step a fresh checkout needs
before invoking `v test` directly is:

```sh
make build-vcx-dev
```

`make test-vcx-suite` performs that build for you. A lane whose
environment prerequisite is absent — the unbuilt binary, an opt-in
external service such as `CX_TEST_S3_ENDPOINT`/`CX_TEST_FTP_URL`/
`CX_TEST_SFTP_URL`, or a missing host tool like `openssl` — **self-skips
with a named reason instead of failing**, so a bare checkout never reads
as a wall of phantom regressions. Whole-lane skips are recorded in
`vcx/target/test-skips.log` and `make test-vcx-suite` prints the
skipped-with-reason digest after the run (they are counted separately,
never as failures). Plain `v test` suppresses the output of passing
lanes; use `v -stats test …` to see `SKIP` lines inline. The binary
path is resolved relative to the source tree, so lanes behave the same
from any invocation directory.

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

The C ABI surface is documented in [`spec/03-approved/core/abi.md`](spec/03-approved/core/abi.md). If
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
 [`spec/03-approved/core/abi.md`](spec/03-approved/core/abi.md) with input/output framing.

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
