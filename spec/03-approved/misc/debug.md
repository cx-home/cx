# CX Debugging (local + remote)

**Status:** Current. The CX debug surface (local + remote). The host
bindings are specified in their owning files: the `cx run --debug…` / `cx dap` /
`cx debug attach`/`replay` subcommands in `cli.md` §2.3/§3.7, and the
debug-capability bit (39) in `abi.md`. Integrations reference the capability
model (`../core/security.md`), the error pipeline (`../core/code.md` §9.6), and
secret redaction (`../core/cxdm.md` §12).

## §1 Overview, opt-in, security

Debugging lets a client **pause** a running CX evaluation, **inspect** its state,
**step**, and **evaluate** expressions in a paused frame — **locally** (same
process / CLI) or **remotely** (attach over a network to a running runtime).

- **Opt-in.** Debug support is a build/run capability, off by default (no
  production overhead). Enabled via `cx run --debug` (local) or
  `cx run --debug-listen=ADDR` (remote). Advertised by an ABI capability bit
  (`abi.md`); a runtime without it rejects debug attach.
- **Security (remote).** Remote debug exposes arbitrary in-process expression
  evaluation — it is a privileged capability. Therefore: **off by default**;
  binds to `127.0.0.1` unless an explicit external `ADDR` is given; **requires a
  token** (`--debug-token=…`, sent by the client); the runtime logs every
  attach. Exposing remote debug without a token is a startup error.

## §2 Local debugging primitives (the core surface)

Independent of transport. A debug session over a paused evaluation supports:

**Breakpoints**
| Kind | Set on |
|---|---|
| location | source file:line (a directive/expression boundary) |
| directive | a directive name (e.g. break on every `[?modify]`) |
| conditional | location + a pure CX predicate over in-scope bindings |
| on-error | any `[err …]` raised (composes with the error pipeline's `raise` stage, `../core/code.md` §9.6) — optionally filtered by code |

**Execution control:** `pause`, `resume`, `step-in`, `step-over`, `step-out`,
`run-to(location)`, `terminate`.

**Introspection (read-only):** `stack` (frames, innermost first), per-frame
`bindings` (`$name → value`), the current `focus`/cursor (CXPath context node),
the in-flight `err` when stopped on-error, and the source `position`.

**Evaluation:** `eval(EXPR, frame)` — evaluate a CX expression in a paused
frame's lexical scope (subject to the same purity/caps as the program). Used for
watch expressions and inspection. Side-effecting eval is gated (see §5).

**Events (runtime → client):** `stopped {reason: breakpoint|step|pause|error|entry, frame}`,
`continued`, `output {sink, value}`, `terminated {value | err}`.

## §3 Debug state is CX values (dogfood)

All inspectable state is expressed as CX values, so the same printers/format
profiles render it:
```
[frame fn=validate-user pos='orders.cx:42'
  [bindings [= $u [user id=991]] [= $threshold 5]]
  [focus //user[@id=991]]]
[stopped reason=breakpoint [frame …] …]
```
A debugger UI, a test harness, or a CX program can consume these directly.

## §4 Remote debugging

The §2 primitives are exposed over the wire two ways:

- **§4.1 DAP adapter (`cx dap`)** — speaks the standard **Debug Adapter
  Protocol** (the editor-standard, e.g. VS Code) over stdio or TCP. Maps DAP
  requests (`setBreakpoints`, `stackTrace`, `scopes`, `variables`, `evaluate`,
  `continue`, `stepIn/Out/Over`) onto §2 primitives. This is the editor-facing
  surface, complementing `cx lsp` (language features) — LSP = static, DAP =
  runtime.
- **§4.2 CX-native protocol** — a CX-document request/response protocol over
  TCP/WebSocket for CX-aware tooling and programmatic attach (parallels
  `misc/cxstore-remote-protocol.md`). Requests and events are CX values (§3);
  framing + auth + version handshake reuse that protocol's conventions. Use when
  the client is CX itself or wants the richer CX-value state without DAP's
  JSON-RPC shape.

Both run against the **same** local session core (§2); remote = local primitives
+ transport + auth (§1). Attach: client connects to `--debug-listen=ADDR`,
presents the token, gets a session; detach resumes the program.

## §5 Capability gating + integration

- **Eval/mutation caps.** `eval` in a frame is read-oriented; expressions that
  would mutate state or perform I/O are gated by the same M1–M5 sandbox caps as
  `cx:eval` (max-steps/alloc/time, syscall-deny), defaulting to read-only in a
  debug session unless the attach grants write.
- **Error pipeline (`../core/code.md` §9.6).** The `on-error` breakpoint is the debug
  view of the error pipeline's `raise` stage — break where a hook would observe.
- **Profiling (`std-lib/prof.md`) / logging (`std-lib/log.md`).** Debug shares
  the structured-context model (`[?with-scope]` request-id/trace fields appear in
  frames); a debug session can subscribe to `log/*` and prof events.
- **Concurrency.** Per-worker/async frames are addressable; the spawn-time
  context snapshot (§ scope inheritance) is visible per frame.

## §6 CLI
| Command | Purpose |
|---|---|
| `cx run --debug FILE` | run with a local debug session (CLI stepper) |
| `cx run --debug-listen=ADDR --debug-token=… FILE` | run + accept remote attach |
| `cx dap` | DAP adapter on stdio (editor integration) |
| `cx debug attach ADDR --token=…` | CLI client: attach to a remote runtime |

## §6a Record-replay (time-travel) — v1 = record + forward replay

CX is unusually suited to deterministic record-replay: a functional core
(immutable values, `[?modify]` returns new docs), nondeterminism confined to
**named directive boundaries** (`[?sleep]`, `[?random]`, channels, async/worker
scheduling, HTTP/IO, env), and an existing mock clock. **v1 scope: record a
deterministic tape + replay it forward** (step forward through the recorded run).

**The tape is a versioned CX document** (dogfood):
```
[cx-trace version=1
  [seed clock=… rng=… env=[…]]
  [event step=1 effect=http-get [result [response status=200 …]]]
  [event step=2 effect=receive  [result 42]] …]
```

**Two forward-compat invariants (so v2 time-travel is additive, not rework):**
1. **Completeness** — the tape records ALL nondeterminism (every boundary
   result + scheduling order + seeds) so replay is bit-exact, even though the v1
   UI only steps forward. An incomplete v1 tape is the only thing that would
   force a v2 rework.
2. **Position-addressable replay** — stable monotonic `step` ids + a
   `run-to(N)` primitive (forward stepping needs this anyway).

**v2 (additive, no tape/semantics change):** reverse-step = `run-to(N-1)`;
jump = `run-to(N)`; checkpoints = periodic state snapshots so jumps replay from
the nearest snapshot (pure perf). Replay never re-executes real effects (it
feeds recorded results) → reverse-step is inherently effect-safe.

**Error→tape→replay loop (design target):** a `report`-stage sink
(`../core/code.md` §9.6) MAY attach the tape; `cx debug replay tape.cx` reproduces the
exact failing run locally — across machines/versions. Tapes are portable,
diffable, and double as deterministic flaky-test repro for conformance.

## §7 Decisions (user rulings 2026-05-30)
- **(G1) Transport priority → DAP adapter first**, CX-native protocol second.
- **(G2) Record-replay → v1 = record + forward replay** (§6a); full time-travel
  (reverse-step/jump) is a v2 *additive* layer, enabled by the §6a completeness +
  position-addressable invariants. Tape is a versioned CX document.
- **(G3) Eval in a paused frame → read-only default + explicit write-grant.**
- **(G4) Home → `spec/misc/debug.md`** (tooling).

