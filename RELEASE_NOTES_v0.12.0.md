# CX v0.12.0 — Release Notes

**Date:** 2026-06-19
**Tag:** `v0.12.0`

The **correctness-and-ergonomics** release. The block-comment syntax is unified
on `[; … ]` (the one breaking change — see Migration), CX gains a locale-free
string→number stdlib bridge and concurrent server-sent-event push, the CLI
learns stdin / inline evaluation, and roughly fifteen bugs are fixed — several
of them silent-wrong-answer or capability-fails-silently violations of CX's
fail-loud principle.

## Changed (breaking)

- **Block comments are now `[; … ]` only.** `[- … -]` and `[-- … --]` are retired
  as comment forms, and `[- a b]` is **always** subtraction. This removes the
  long-standing `[-`-token ambiguity between a comment and a minus expression.
  See **Migration** below. (Language version → 0.12.0.)

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

Lossless import:
- **#4 / #5** — YAML and TOML now import losslessly into the native map/array
  value model.

Other:
- **#11** — a pure-data resource evaluates to itself (data fallback for prose).
- **#48** — the HTTP server waits for the full POST body before invoking the
  handler.
- **#27** — `[?select]` sequence diagrams emit arrows with correct labels.
- **#39** — `cx:parse` of a single-root document returns a navigable node.
- **#18** — a `[where]` infix-comparison error points at the prefix form.
- **#15** — the published `cx-v` package ships `transport/` + `x/` and builds
  with `clang` (`-cc cc`).

## Migration — comment syntax

The only breaking change. Block comments must use `[; … ]`:

```
[; this is a comment ;]            ; old [- … -] / [-- … --] forms are retired
[- 5 2]                            ; this is now subtraction (= 3), never a comment
```

- Replace any `[- … -]` or `[-- … --]` comment with `[; … ]`.
- If you used `[- … -]` to comment out a block, switch it to `[; … ]`.
- Bare `[- a b]` that you intended as subtraction is unchanged and now
  unambiguous.

## Compatibility

Language version advances to **0.12.0**. The comment-syntax unification is the
sole breaking change; every other change is backward-compatible. The ABI,
format, and library version axes are unchanged.
