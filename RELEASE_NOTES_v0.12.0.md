# CX v0.12.0 — Release Notes

**Date:** 2026-06-22
**Tag:** `v0.12.0`

The **reliability** release. Concurrency and memory move from "works with
caveats" to **sound by construction**: tail calls no longer overflow the native
stack, the precise GC's cooperative-safepoint collector becomes the default so
multi-reactor HTTP and concurrent workers are safe, and the reactor / streaming
write paths are bounded against runaway RSS. Alongside that: the block-comment
syntax is unified on `[; … ]` (the one breaking change — see Migration), the
single-source-of-truth versioning model is enforced end to end, the CLI learns
stdin / inline evaluation, and roughly twenty bugs are fixed — several of them
silent-wrong-answer or capability-fails-silently violations of CX's fail-loud
principle.

## Changed (breaking)

- **Block comments are now `[; … ]` only.** `[- … -]` and `[-- … --]` are retired
  as comment forms, and `[- a b]` is **always** subtraction. This removes the
  long-standing `[-`-token ambiguity between a comment and a minus expression.
  See **Migration** below. (Language version → 0.12.0.)

## Reliability — concurrency & memory

- **Tail-call optimization (#60).** Tail self-calls and tail closure-calls now
  run in O(1) native stack via a trampoline in the evaluator, so loop-shaped
  recursion no longer SIGSEGVs at depth (pure tail recursion is exercised
  100,000,000 deep). Semantics-preserving; non-tail and a few non-trampolined
  shapes fall back to ordinary recursion.
- **Cooperative-safepoint STW is now the default GC collector (#63 / #58).**
  The precise `-gc e` collector parks running mutators at cooperative safepoints
  (mach-suspending only stragglers) before a stop-the-world cycle, so
  multi-reactor HTTP (`CX_HTTP_WORKERS>1`) and concurrent `[?worker]` threads are
  **sound by construction** rather than racing the collector. Revert with
  `-d vgc_legacy_stw` if needed. Single-reactor throughput is within noise;
  8-reactor is the tuning follow-up.
- **Reactor heap is bounded by heap growth, not request count (#57).** The HTTP
  reactor collects its per-request transient heap once it has grown by
  `CX_HTTP_GC_MB` MB (default 64) since the last collect — self-tuning across
  light and heavy handlers. A light handler barely allocates so it almost never
  collects (full throughput + multi-reactor scaling); a heavy handler trips it
  every few requests so RSS stays bounded. (The earlier every-N-requests gate,
  default 64, fired a global stop-the-world ~hundreds of times/sec and cut
  throughput ~3× — that regression is fixed here. `CX_HTTP_GC_MB=0` disables it;
  the legacy `CX_HTTP_GC_EVERY` request-count gate is still honored when set.)
- **HTTP serves multi-reactor by default (`min(4, cores)`).** The server fans
  out across a few cores out of the box — sound on the cooperative-safepoint
  collector, and ~4 reactors is the sweet spot before the per-request GC lock
  starts to contend on a many-core box. Tune with `CX_HTTP_WORKERS`: an integer
  (honored as asked — a 64-core test gets 64; above the core count it
  oversubscribes, with a one-line note, and a 256 safety ceiling guards typos),
  `max` for one worker per core, or `1` to opt back into a single reactor.
  (Measured: ~162k req/sec default, ~110k at `=1`, on a 12-core box with a
  trivial handler.)
- **Streaming `data-bin` writes are bounded under `-gc e` (#52).** Large-span
  recycling plus periodic collection cap the live set on the fd-streaming write
  path, so emitting a large document no longer balloons memory.
- **Comprehension memory fix (#62).** `[?for]`’s per-item `env.clone()` no
  longer deep-copies the shared closures table, eliminating a general
  (non-HTTP) memory blow-up on large comprehensions.
- **Concurrent `[?worker]` threads (#58),** behind `CX_WORKER_THREADS`. A
  `[?worker]` body runs on its own thread and coexists with a `{block:true}`
  `serve`, instead of monopolizing the thread so the server never binds. Off by
  default this release.

## Changed

- **`cx <file>` renders every top-level form, not just the last (#16).** A script
  with multiple top-level expressions now prints each result in order.
- **`--allow-net` no longer bypasses the §4.5 SSRF deny-set (#47).** A bare
  `--allow-net` grants outbound reach but still refuses loopback / link-local /
  private / metadata ranges unless an explicit literal-IP or `localhost` grant
  admits them; only `--allow-all` bypasses the deny-set. Tightens the default
  security posture.

## Added

- **`cx-stdlib/strings` string→number parsers (#54).** `to-number` / `to-int` /
  `to-float` — a locale-free bridge that returns a numeric scalar for valid
  input and the **absence channel `()`** for non-numeric input (no silent
  string passthrough), so callers branch with `[?else …]`. Replaces the unsafe
  `[$cx:parse …]` workaround.
- **Concurrent SSE push on the `serve` path (#28).** Topic pub/sub: a handler
  subscribes a connection to a topic and `sse-publish` fans one event out to
  every subscriber.
- **`cx -` and `cx -e EXPR`.** Read a program from stdin (`cx -`) or evaluate an
  inline expression (`cx -e '…'`) — no `cx eval` needed.
- **`tools/vgc-debug/` toolkit (#70).** Durable probes, gated diagnostic patches,
  and methodology for the precise-GC concurrency work — for contributors
  investigating collector behavior.

## Versioning & release hygiene (#67)

- **The repo-root `VERSION` file is the single source of truth, enforced.**
  Every surface either *derives* the version (the CLI / C-ABI via the build
  define, the guide at build time, the wasm build, runtime error messages) or is
  *stamped* from it by `bump_version.sh` (package manifests, README badges, the
  VS Code extension). User-facing error messages no longer cite a frozen release
  (e.g. the `cast` error lists supported kinds instead of "v0.8.0 supports …").
- **`check-version-consistency` now scans `vcx/`, `spec/`, `docs-src/`,
  `stdlib/`, and `tooling/`** and fails the build on any stray `vX.Y.Z` literal
  outside an explicit history allowlist — so a release can no longer ship docs,
  tooling, or a playground that advertise an older version.

## Fixed

Silent-wrong / data-loss (highest priority — fail-loud violations):
- **#38** — `[$idiv]` / `[$mod]` / `[$div]` now **reject** bigint and decimal
  operands (CXER0100) instead of silently returning an i64-wrapped wrong answer.
- **#10** — JSON / YAML emit of a `:table` block now projects its rows instead
  of dropping them to `null`.
- **#21** — `[?for [in $x $m/key]]` over a map member whose value is a
  sequence-of-elements now iterates the members (count and iteration agree).
- **#16** — see Changed (was: all but the last top-level form silently dropped).

Fail-loud / capability-silent:
- **#46** — a `[?def]` body that raises now surfaces the error instead of
  collapsing to a silent data literal.
- **#29** — `net:set-deadline` / `set-opt` on a std-stream handle now reject
  loudly instead of silently no-op'ing.
- **#23** — `accept-iter` surfaces a handler that returns without responding.
- **#56** — `net:read-all` / `read-line` / `line-iter` honor a configured
  read-deadline (dial opt or `set-deadline`), raising `CXER4507` instead of
  hanging forever on a peer that never closes.
- **#55** — a zero-argument user `[?def]` is now callable by its bareword head
  (`[f]`) instead of parsing as a data element.
- **#53** — a bareword-head recursive `[?def]` call with computed arguments now
  dispatches instead of falling through to data construction.
- **#11** — unknown / retired directives stay fail-loud rather than silently
  falling back to a data literal (a pure-data resource still evaluates to
  itself; the fallback no longer over-reaches).

Lossless import:
- **#4 / #5** — YAML and TOML now import losslessly into the native map/array
  value model.

Other:
- **#48** — the HTTP server waits for the full POST body before invoking the
  handler.
- **#27** — `[?select]` sequence diagrams emit arrows with correct labels.
- **#39** — `cx:parse` of a single-root document returns a navigable node.
- **#18** — a `[where]` infix-comparison error points at the prefix form.
- **#17** — docs / examples / scripts use `cx <file>` instead of the redundant
  `cx eval`.
- **#15** — the published `cx-v` package ships `transport/` + `x/` and builds
  with `clang` (`-cc cc`).

## Migration — comment syntax

The only breaking change. Block comments must use `[; … ]`:

```
[; this is a comment ]             ; the old [- … -] / [-- … --] forms are retired
[- 5 2]                            ; this is now subtraction (= 3), never a comment
```

- Replace any `[- … -]` or `[-- … --]` comment with `[; … ]`.
- If you used `[- … -]` to comment out a block, switch it to `[; … ]`.
- Bare `[- a b]` that you intended as subtraction is unchanged and now
  unambiguous.

## Compatibility

Language version advances to **0.12.0**. The comment-syntax unification is the
sole breaking change; every other change is backward-compatible. The
cooperative-safepoint GC default is transparent to programs (revertible with
`-d vgc_legacy_stw`), and the new concurrency knobs (`CX_HTTP_WORKERS`,
`CX_WORKER_THREADS`) are opt-in. The ABI, on-disk format, and bundled-library
version axes are unchanged.
