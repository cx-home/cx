# `cx-x/term` — the raw-mode terminal module surface

```cx
[module-meta name=term tier=x status=experimental]
```

**Status:** Experimental (`x/` tier — exempt from the frozen-stability promise;
[README.md](README.md) D3). Specced rather than retired per the owner disposition on
its governance issue: it has a working, exercised surface and a live consumer, and a
surface that works with a live consumer is not retired.

Normative reference for the **`cx-x/term` module** — the `[?lib 'cx-x/term']` wrapper
whose sources are in repo-root `x/term.cx`. The six **native primitives** it rides
(`$term-*`: termios, winsize, the poll shim, the VT/ANSI decoder) are specced
separately and are **frozen-binary stable**; see `std-lib/term.md`. This document
covers only what the module surface adds and promises: the verb table, the raw-mode
lifecycle, and `select`'s readiness contract — including the TLS limit that contract
carries.

The division matters for stability: the primitives are stable, this surface **may
still evolve** until it graduates to `cx-stdlib/term`. Users see the tier in the
path.

---

## §1. The surface

Six public verbs, each a thin wrapper over its like-named primitive:

| Verb | Signature | Meaning |
|---|---|---|
| `is-tty` | `()` → bool | Is fd 0 a terminal? False under a pipe or headless run. **No capability** — it observes, touching nothing. |
| `raw-mode` | `()` → null | Enter raw mode (`cfmakeraw`), saving the prior termios for restoration. |
| `cooked-mode` | `()` → null | Restore the termios saved by the most recent `raw-mode`. Idempotent — a no-op when raw mode was never entered. |
| `size` | `()` → `[size rows=R cols=C]` | Window dimensions (`TIOCGWINSZ`). |
| `read-event` | `(timeout=-1)` → event | Read and decode ONE input event from raw stdin. Blocks by default; `timeout=MS` bounds the wait and yields `[timeout]` on expiry — see the note below. |
| `select` | `($opts)` → event | First-ready of keystrokes ∪ source fds ∪ a timer, over one `poll(2)` (§3). |

**`read-event` blocks by default, and `timeout=` bounds it.** The wrapper
forwards the primitive's optional timeout duration (`std-lib/term.md`): the
default `-1` blocks indefinitely; `timeout=MS` waits at most MS milliseconds and
returns `[timeout]` on expiry (#861, resolved under R7.1 — the earlier zero-arg
wrapper narrowed the primitive and made `[timeout]` unreachable on this surface).
An exhausted stdin (EOF) also yields `[timeout]` — the primitive does not
distinguish "nothing arrived in time" from "nothing can ever arrive". For waiting
on keystrokes and live sources together, `select` remains the primitive.

## §2. Capability posture

Every terminal effect reads or mutates the controlling tty and is gated on **`read`**
— the same posture as stdin `read-line`. `is-tty` is the sole exception and needs
nothing.

All six verbs are declared `impure`. Denials take the standard capability-denial
shape and propagate as err values. On a non-tty, `raw-mode` and `size` raise
`cx-err:CXER3450` (`E_TERM_NOT_A_TTY`) — so guard interactive paths with `is-tty`
rather than catching the refusal.

## §3. `select` — readiness, not reading

```cx
[$term:select {keys: true  sources: ($h1, $h2)  timeout: 250}]
```

Waits for the **first ready** of: a keystroke on stdin (`keys: true`, which requires
raw mode), any listed source handle becoming readable, or the timer. Returns the
decoded `[key …]`, `[ready index=N <handle>]`, or `[timeout]`.

For a source it returns **readiness only** — the caller reads through that source's
own module (e.g. the http module's SSE events). This is deliberate: `term` stays
decoupled from every source's wire framing, and adding a new kind of source needs no
change here. It is the primitive that dissolves the "live-stream OR interactive
input" split: one loop, both signals.

`sources` holds handles, and the module resolves each handle to its descriptor
internally; the number a handle carries is a registry id, not an OS descriptor, and
the descriptor stays inside the runtime.

### §3.1 TLS caveat (normative limit)

**For a secured stream, socket-readable is not the same question as
frame-available.** A TLS implementation can hold already-decrypted plaintext with
nothing left unread on the socket, so a poll on the descriptor **can miss a record
that is already buffered**.

The consequence for a `select` loop:

- a loop with a **`timeout:`** recovers on the next tick — the buffered record is
  read then;
- an **untimed** loop can wait behind a buffered frame.

So: **give any loop that polls TLS sources a `timeout:`.** This is a real limit of
polling a descriptor, not an implementation defect to be fixed behind this surface.
Refusing TLS sources outright would be worse — it would move https SSE from
"occasionally late" to "unsupported" — so the descriptor is polled and the limit is
stated here.

## §4. The decoder and event shapes

Event shapes (`[key name=… mods=(…)]`, `[timeout]`, `[resize …]`) and the VT/ANSI
decoding rules — the arrow/nav cluster, `f1`–`f4`, ctrl/alt chords, and the rule
that an unrecognised CSI/SS3 sequence decodes to `[key name="unknown"]` rather than
wedging the stream — belong to the primitives and are specified in
`std-lib/term.md`. This module passes them through unchanged and adds nothing.

## §5. Loading

Bundled in the binary; resolves via `[?lib 'cx-x/term']` (the resolver string MUST be
quoted). Enumerated under `bundled_x_names()`, **separate** from the frozen
`cx-stdlib/*` surface, so the frozen-surface canary never counts it.

## §6. Non-goals

Not a TUI framework. The XAP surface/panel layer is the widget model and a terminal
is one more renderer of it — a peer of web and agent renderers, not a wrapped widget
toolkit. No terminfo database (VT/ANSI, which cx already emits); POSIX only, no
Windows console; no output-side escape-sequence helpers, since rendering belongs to
the surface layer.

## §7. Conformance

Coverage is in **V test lanes, not a `.cxd` corpus** — and that difference is
deliberate rather than a gap: the corpus runner has no controlling terminal, so the
tty-dependent surface cannot be driven from a fixture the way `run` or `mcp` can.

- `vcx/tests/cli_umbrella_test.v` — the pure VT/ANSI decoder (unit-tested with no
  tty, including the bytes-consumed contract), the `select` multi-source poll shim
  over real pipes headless, and the module verbs under both a tty and a non-tty
  (`is-tty`, `size`, `raw-mode`, `select` with and without `keys`).
- `vcx/tests/http_sse_real_test.v` — `select` waking on a live SSE source over real
  HTTP: the exercised consumer that makes §3 more than a claim.
- `vcx/tests/stdlib_umbrella_test.v` — the x-tier bundling invariants (bundled
  separately from frozen `std`; the resolver table is populated).

## §8. Cross-references

- `std-lib/term.md` — the six native `$term-*` primitives: termios semantics, the
  error table (`CXER3450` / `CXER3451`), and the decoder.
- `std-lib/README.md` D3 — the `x/` tier and its stability exemption.
- [README.md](README.md) — the `x/`-tier module set.
- `core/security.md` — capability denial shape; `core/code.md` — err propagation.

### §8.1 Graduation

Graduating to `cx-stdlib/term` means adopting the frozen-surface promise, so it waits
on the surface settling. The `read-event` timeout gap that §1 used to record was the
known open item; it is resolved (#861, R7.1 — the wrapper forwards the primitive's
optional duration), leaving no recorded surface gap.
Graduation is an owner decision (G3), not a consequence of this document.
