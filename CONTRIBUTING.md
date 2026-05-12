# Contributing to CX

Thanks for your interest in contributing. CX is pre-1.0 — there is
real room to influence the format, the bindings, the tooling, and the
spec. Bug reports, doc fixes, and PRs are all welcome.

This file covers dev setup, the test matrix, the audit-driven coding
rules every PR is held to, and the commit / PR conventions.

For the format itself, start with [`docs/TUTORIAL.md`](docs/TUTORIAL.md).
For the formal contracts, see [`spec/`](spec/).

---

## Dev setup

### Prerequisites

- [V](https://vlang.io) 0.5.1+ — the V toolchain. CX's core is
 implemented in V; everything else links against the compiled
 `libcx`.
- A C compiler (clang on macOS, gcc/clang on Linux).
- For each language binding you intend to test, the corresponding
 toolchain: Python 3.10+, Go 1.21+, Rust 1.75+, Node 18+, JDK 17+,
 Kotlin via Gradle, Swift 5.9+, .NET 8+, Ruby 3.0+.

[devbox](https://www.jetpack.io/devbox) optionally pins all of the
above; `devbox shell` drops you into an environment with the right
versions. It's optional — system installs work fine.

### First build

```sh
git clone https://github.com/cx-home/cx
cd cx
make build # compile V core into libcx + build every binding
make promote-cli # install the `cx` CLI to /usr/local/bin
cx --version
```

`make build` is incremental. Sub-targets:

| target | builds |
| ------ | ------ |
| `make build-vcx` | V core (`libcx`, `cx` CLI) only |
| `make build-rust` | Rust binding (depends on libcx) |
| `make build-typescript` | TypeScript binding |
| `make build-<lang>` | analogous for go / java / kotlin / swift / csharp |

The Python and Ruby bindings have no separate build step — they
load `libcx` at import time.

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
across the 6 supported formats (CX, JSON, YAML, TOML, XML, Markdown).
It runs against the V implementation; bindings inherit conformance
because they are thin wrappers around `libcx`.

If you change the grammar, the conversion logic, or anything format-
adjacent, `make conform` must pass before you push.

---

## Coding rules

CX has a small number of normative rules from the
2026-05 binding audit. Conformance to
them is a release gate. The full text is in
[`spec/governance.md`](spec/governance.md). The most important rule:

### The native-implementation rule (no roundtrips on hot paths)

> No public function in any binding may call another public function
> of the same library and re-parse its string output. Bindings either
> call a C ABI symbol that returns native bytes (binary AST or data)
> and deserialize once, or walk an in-memory structure already held
> by the binding. **String-format roundtrips are forbidden on hot
> paths.**

The audit (CB-1..CB-3) found this pattern in every binding — it was
slow, lossy, and undermined the multi-format guarantees. All five
findings are closed at v0.6.0; please don't reintroduce them.

In practice: when you add a new public function in a binding,

- the implementation goes through one C ABI call returning native
 bytes (binary AST, binary data, or a handle), and
- you decode those bytes once. No second parser, no JSON detour.

The C ABI surface is documented in [`spec/abi.md`](spec/abi.md). If
you need an operation without a binary-bytes symbol yet, the right
move is to add one at the V core, not to chain two text converters
in the binding.

### Other release gates

- **Parity matrix** ([`spec/governance.md` §2](spec/governance.md)) —
 every public function exists with consistent signatures across all
 9 bindings. New API additions touch every binding in the same PR
 series.
- **Strategy declaration** (§3) — each binding's README declares
 which implementation strategy it uses. Updates here travel with
 the code change.
- **Performance SLA** (§6) — `cx_to_data_bin` and friends have
 documented budgets in `spec/governance.md`.

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
 [`spec/abi.md`](spec/abi.md) with input/output framing.

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
