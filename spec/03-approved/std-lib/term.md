# `$term-*` — raw-mode terminal primitives

```cx
[module-meta name=term tier=B status=current
  [standard ref='POSIX termios' title='terminal control']]
```

**Status:** Current (owner G3 2026-07-12, #363 item 5(a) — first authored spec for
this dispatch family; the primitives shipped under cx-private #30 and this text is
written from, and conformance-anchored to, that shipped behavior). Tier B — I/O.

Normative reference for the **six `term_stdlib_builtin` native primitives**: raw-mode
terminal input on the program's own controlling tty (fd 0). These natives are part of
the frozen binary's dispatch chain and are stable; the **`cx-x/term` module wrapper**
(`[?lib 'cx-x/term']`, sources in repo-root `x/term.cx`) remains `x/`-tier
experimental per [README.md](README.md) D3 — its *surface* may still evolve, riding
on these primitives, until it graduates to `cx-stdlib/term`.

POSIX only. The termios / winsize / poll machinery lives in the `cx_term.c` shim;
the VT/ANSI key decoder is pure and unit-testable without a tty.

---

## §1. Capability posture

Every terminal effect reads or mutates the controlling tty and is gated on the
**`read`** capability — the same posture as stdin `read-line`
([io.md](io.md) §7). `[$term-is-tty]` alone requires no capability (it observes,
touching nothing).

Denials follow the standard capability-denial shape (security.md §4): the call
returns the denial err-value, which propagates per code.md §9.2.

## §2. Errors

| code | name | raised by |
|---|---|---|
| `cx-err:CXER3450` | `E_TERM_NOT_A_TTY` | `raw-mode` / `size` when fd 0 is not a terminal (pipe, headless run) |
| `cx-err:CXER3451` | `E_TERM_IO` | `tcsetattr` failure entering raw mode; a failed `read(2)` in `read-event` |

Guard interactive paths with `[$term-is-tty]` — false under a pipe or headless run.

## §3. The six primitives

### §3.1 `[$term-is-tty] -> bool`

True iff stdin (fd 0) is a terminal. No capability required.

### §3.2 `[$term-raw-mode] -> null`

Switch the tty to raw mode (`cfmakeraw`: no line buffering, no echo,
byte-at-a-time) and save the prior termios for restoration. Raises
`CXER3450` on a non-tty, `CXER3451` if `tcsetattr` fails. Needs `read`.

### §3.3 `[$term-cooked-mode] -> null`

Restore the termios saved by the most recent `raw-mode`. A no-op (null, no
error) when not in raw mode — restoration is idempotent by construction.
Needs `read`.

### §3.4 `[$term-size] -> [size rows=R cols=C]`

The window dimensions via `TIOCGWINSZ`. Raises `CXER3450` on a non-tty.
Needs `read`.

### §3.5 `[$term-read-event DURATION?] -> event`

Read and decode ONE input event. The optional positional is a timeout
duration (e.g. `100ms`); absent means block indefinitely. Returns:

- `[key name=NAME mods=(MODS…)]` — a decoded keystroke (§4);
- `[timeout]` — the timer elapsed with no input;
- `CXER3451` err-value on a failed read.

Needs `read`.

### §3.6 `[$term-select OPTS] -> event`

Wait for the **first ready** of: a keystroke on stdin, any source handle's fd
becoming readable, or a timer — over one `poll(2)`. `OPTS` is a map:

```cx
{keys: true  sources: ($h1, $h2)  timeout: 250ms}
```

- `keys` (bool, default false) — include stdin keystrokes;
- `sources` — a sequence of fd-bearing handles (`[socket fd=N]`, an exchange,
  an SSE stream handle — anything carrying an `fd=` attribute);
- `timeout` — a duration; absent means block indefinitely.

Returns `[key …]` for a keystroke, `[ready index=N <handle>]` for a readable
source (**readiness only** — the caller reads via the source's own module, so
`term` stays decoupled from each source's wire framing), or `[timeout]`. With
nothing to wait on but the timer, it sleeps the timeout and returns
`[timeout]`. This is the primitive that dissolves the "live-stream OR
interactive-input" split (cx-private #28/#29): one loop, both signals. Needs
`read`.

## §4. The key decoder

`cx_term_decode` (pure) decodes one event from the front of a byte buffer and
reports bytes consumed. It targets **VT/ANSI (xterm-256color)** with no
terminfo DB:

- printable keys; `enter` / `tab` / `backspace` / `escape`;
- `ctrl`-letters (C0 bytes) and `alt-<char>` (ESC-prefixed) as `mods` atoms
  (`:ctrl` / `:alt` / `:shift`);
- the arrow / nav cluster and `f1`–`f4` (CSI and SS3 forms);
- an unrecognised CSI/SS3 sequence decodes to `[key name="unknown"]`,
  consuming the whole recognised prefix — the stream never wedges.

Event shape: `[key name=NAME [mods (MODS…)]]`; window-size changes surface as
`[resize …]` where the platform reports them through the read path.

## §5. Non-goals

Not a TUI framework: the XAP surface/panel layer is the widget model, and a
TUI is one more renderer of it. No terminfo database; no Windows console
support (POSIX only); no output-side escape-sequence helpers — rendering
belongs to the surface layer.
