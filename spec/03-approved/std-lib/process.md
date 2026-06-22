# `cx-stdlib/process` — subprocess spawn, capture, pipelines, signals

```cx
[module-meta name=process tier=B status=current]
```

**Status:** Current

Normative reference for the `cx-stdlib/process` sub-package.

---

## §1. Scope

`cx-stdlib/process` runs child processes: spawning, capturing output, streaming stdio, connecting processes into pipelines, delivering signals, managing process groups, and pseudo-terminal (interactive) control. Sibling of [`spec/std-lib/env.md`](env.md) (current-process metadata) and reuses [`spec/std-lib/io.md`](io.md)'s handle model for child stdio.

This is impure Tier-B runtime. Every operation may raise OS-level errors mapped to the `CXER4000` range (§5).

### §1.1. Security stance — argv-array ONLY

**This module has exactly one command-construction API: an argv array of strings.** `run` / `spawn` / each pipeline stage takes `argv::[sequence string]` — `argv[0]` is the executable and `argv[1..]` are its literal arguments. **There is no shell-string form anywhere in this module.** The OS `exec`-family call receives the argv vector verbatim; no shell ever interprets it unless the program *is* a shell that the caller named explicitly.

This is the structural command-injection defense: because there is no string-to-argv splitting step, there is no metacharacter (`;`, `|`, `$(…)`, backticks, `&&`, glob `*`, `~`) for an attacker-controlled argument to smuggle a second command through. `[$run ["echo" $user_input]]` passes `$user_input` to `echo` as a single literal argument no matter what bytes it contains.

A program that needs shell features invokes a shell explicitly:

```cx
[$run ["sh" "-c" "echo $HOME && ls *.log"]]
```

The risk is then owned by the caller and visible at the call site.

## §2. Conceptual model

### §2.1. The argv-array invariant

Every command is an `argv::[sequence string]`:

- `argv[0]` — the executable name or path. Resolved against `PATH` when it contains no path separator (`$search-path=true` default, §4.1).
- `argv[1..]` — the child's literal arguments, passed verbatim to `exec`. No word-splitting, glob expansion, or metacharacter interpretation.
- An empty argv (`[]`) raises `CXER4006`.

### §2.2. The proc handle element

`spawn` returns an opaque proc handle:

```cx
[proc
  pid=48213
  [argv "grep" "-n" "ERROR"]
  [stdin  [file role=child-stdin]]
  [stdout [file role=child-stdout]]
  [stderr [file role=child-stderr]]
  process-group=48213
  state=:running]
```

The handle is opaque — programs reach its stdio via the `stdin` / `stdout` / `stderr` accessors (§3.2) and pass it to `wait` / `poll` / `pid` / `send-signal` / `close`. It carries a `close` contract and composes with [`[?with-open]`](../core/code.md) (core §8.10.7).

### §2.3. The proc-result element

`run` returns a fully-materialized result:

```cx
[proc-result
  stdout="…captured stdout…"
  stderr="…captured stderr…"
  exit-code=0
  signaled=false
  signal=null
  timed-out=false]
```

When `signaled` is true, `exit-code` carries the platform's signal-encoded status (POSIX `128 + signum`) and `signal` names the delivering signal.

### §2.4. Relationship to io and env

A child's stdio handles are io-style handles ([`spec/std-lib/io.md`](io.md) §2.1): `stdout` / `stderr` return readable handles; `stdin` returns a writable handle. Closing the child's stdin signals EOF. [`spec/std-lib/env.md`](env.md) is the current-process sibling; the `$env` opt is how a program sets a child's environment (so `env` has no global `setenv`).

## §3. Public function surface

### §3.1. One-shot run

```
[?def run scope=public impure [returns element]
  ($argv::[sequence string]
   $env=null $env-clear=false $cwd=null $stdin=null
   $timeout-ms=null $kill-on-timeout=true $capture=:both
   $encoding="utf-8" $search-path=true $new-process-group=false
   $check=false) ...]
```

Spawn `argv`, optionally feed stdin, run to completion, capture stdout/stderr, and return a `[proc-result …]`. Bounded by available memory; use `spawn` (§3.2) for unbounded output.

| Key | Default | Semantics |
|---|---|---|
| `$env` | `null` | Map overlaid on the inherited parent environment (augment by default). A `null` value removes a variable. |
| `$env-clear` | `false` | When `true`, the child starts from an empty environment and `$env` is the complete set (hermetic). |
| `$cwd` | inherit | Working directory; relative paths resolve per [`spec/std-lib/path.md`](path.md). Missing directory raises `CXER4001`. |
| `$stdin` | `null` | `string` or `bytes` fed to the child; EOF after the last byte. `null` is immediate-EOF. |
| `$timeout-ms` | `null` | Wall-clock budget. On expiry the child is handled per `$kill-on-timeout`. |
| `$kill-on-timeout` | `true` | `true` escalates SIGTERM → SIGKILL (§4.5) and returns `timed-out=true`; `false` raises `CXER4003`. |
| `$capture` | `:both` | `:both` / `:stdout` / `:stderr` / `:none`. Uncaptured streams inherit the parent's. |
| `$encoding` | `"utf-8"` | Decode captured bytes; `:bytes` returns raw bytes with no decode. |
| `$search-path` | `true` | Resolve separator-free `argv[0]` against `PATH` (§4.1). |
| `$new-process-group` | `false` | Spawn as leader of a fresh process group (§3.5). |
| `$check` | `false` | When `true`, a non-zero `exit-code` raises `CXER4012` carrying the `[proc-result …]`. |

`run` reaps the child before returning.

### §3.2. Streaming spawn

```
[?def spawn scope=public impure [returns element]
  ($argv::[sequence string]
   $env=null $env-clear=false $cwd=null
   $encoding="utf-8" $search-path=true $new-process-group=false) ...]

[?def stdin         scope=public impure [returns element]       ($handle::element) ...]
[?def stdout        scope=public impure [returns element]       ($handle::element) ...]
[?def stderr        scope=public impure [returns element]       ($handle::element) ...]
[?def pid           scope=public impure [returns int]           ($handle::element) ...]
[?def wait          scope=public impure [returns int]           ($handle::element) ...]
[?def wait-timeout  scope=public impure [returns [or int [sequence int]]] ($handle::element $ms::int) ...]
[?def poll          scope=public impure [returns [or int [sequence int]]] ($handle::element) ...]
[?def close         scope=public impure [returns null]          ($handle::element) ...]
```

- `stdin` / `stdout` / `stderr` — return the child's io-style stdio handles. Closing `stdin` (`io/close`) signals EOF.
- `wait` — block until exit; return `exit-code`; reap.
- `wait-timeout` — block up to `ms`; return `exit-code`, or **absence** (the empty sequence `()`) if still running (no kill — caller decides). "Still running" is "no result here yet" — the **absence channel** ([`code.md`](../core/code.md) §9.1.2), **never** `null` (the §9.1.2.1 no-conflation guard).
- `poll` — non-blocking; return `exit-code`, or **absence** (the empty sequence `()`) if still running.
- `close` — release the handle: close any open stdio handles and reap the child. Does **not** kill a still-running child (detaches). Idempotent. Makes the handle `[?with-open]`-compatible.

```cx
[?with-open [$spawn ["tail" "-f" "/var/log/app.log"]] $p
  [?for [in $line [$line-iter [$stdout $p]]]
    [where [$contains $line "ERROR"]]
    [yield $line]]]
```

### §3.3. Pipelines

```
[?def pipeline scope=public impure [returns element]
  ($stages::[sequence element]
   $stdin=null $timeout-ms=null $kill-on-timeout=true
   $encoding="utf-8" $env=null $env-clear=false $cwd=null
   $check=false) ...]
```

Connect stages end-to-end (`a | b | c`, expressed safely). Each stage is a `[stage …]` element:

```cx
[$pipeline [
  [stage [argv "grep" "-h" "ERROR"]]
  [stage [argv "cut" "-d" " " "-f" "1"]]
  [stage [argv "sort" "-u"] [opts cwd="/tmp"]]]
  stdin=$log_text]
```

- `argv` — the stage's argv (the §2.1 invariant; empty argv raises `CXER4006`).
- `opts` — a per-stage options element; same keys as `run` except `$stdin`/`$capture`, which the pipeline owns (only the first stage reads pipeline `$stdin`; only the last stage's stdout is captured).

Pipeline-level options mirror `run` where they apply to the whole pipeline. The `stages` argument is positional. A per-stage `[opts …]` is a data element, not a function parameter.

Returns a `[pipeline-result …]`:

```cx
[pipeline-result
  [stages
    [proc-result [argv "grep" "..."] exit-code=0 signaled=false]
    [proc-result [argv "cut" "..."]  exit-code=0]
    [proc-result [argv "sort" "..."] exit-code=0]]
  [exit-codes 0 0 0]
  stdout="…last stage's captured stdout…"
  exit-code=0]
```

- `exit-code` is the **pipefail aggregate**: `0` iff every stage exited `0`; otherwise the exit code of the last non-zero stage (`set -o pipefail` semantics). A failing early stage is never masked.
- A one-stage `pipeline` is observationally equivalent to `run`.

### §3.4. Signals

```
[?def send-signal  scope=public impure [returns null] ($handle::element $sig::atom) ...]
[?def terminate    scope=public impure [returns null] ($handle::element) ...]
[?def kill         scope=public impure [returns null] ($handle::element) ...]
```

- `send-signal` — deliver `sig` (an atom; table below) to the child.
- `terminate` — deliver `:term` (SIGTERM).
- `kill` — deliver `:kill` (SIGKILL).

Portable signal atoms:

| Atom | POSIX | Meaning |
|---|---|---|
| `:term` | `SIGTERM` | Polite termination (catchable). |
| `:kill` | `SIGKILL` | Forced termination. |
| `:int` | `SIGINT` | Interrupt (Ctrl-C). |
| `:hup` | `SIGHUP` | Hang-up; conventionally "reload". |
| `:usr1` | `SIGUSR1` | User-defined 1. |
| `:usr2` | `SIGUSR2` | User-defined 2. |
| `:stop` | `SIGSTOP` | Suspend (uncatchable). |
| `:cont` | `SIGCONT` | Resume. |

**Windows mapping.** `:term` and `:kill` map to `TerminateProcess`. `:int` is best-effort via `CTRL_BREAK_EVENT` / `CTRL_C_EVENT` to the child's console group; without a console group it raises `CXER4004`. `:hup` / `:usr1` / `:usr2` / `:stop` / `:cont` have no Windows equivalent and raise `CXER4004`. The module never silently no-ops an unsupported signal.

Delivering a signal to an already-exited child is a no-op. Delivering to a closed handle raises `CXER4007`.

### §3.5. Process groups

```
[?def kill-group  scope=public impure [returns null] ($handle::element $sig::atom) ...]
```

Pass `$new-process-group=true` to `run` / `spawn` / a pipeline stage to make the child the leader of a fresh process group. The child and every descendant share one process-group id and can be signaled as a unit:

```cx
[?with-open ($p [$spawn ["./serve.sh"] new-process-group=true])
  [$kill-group $p :term]]
```

- `kill-group` reaches every process in the group (child + descendants).
- `kill-group` on a handle that was not spawned `$new-process-group=true` raises `CXER4011`.

POSIX backing: `setpgid` + `killpg`. Windows backing: a Job Object; `kill-group` calls `TerminateJobObject` for `:term` / `:kill`. Non-terminating signals on a Windows Job Object raise `CXER4004`.

### §3.6. Pseudo-terminal (interactive)

```
[?def spawn-pty scope=public impure [returns element]
  ($argv::[sequence string]
   $env=null $env-clear=false $cwd=null
   $encoding="utf-8" $search-path=true $new-process-group=false
   $rows=24 $cols=80 $term="xterm-256color") ...]

[?def pty             scope=public impure [returns element] ($handle::element) ...]
[?def window-size     scope=public impure [returns element] ($handle::element) ...]
[?def set-window-size scope=public impure [returns null]    ($handle::element $rows::int $cols::int) ...]
```

`spawn-pty` allocates a fresh pseudo-terminal and attaches the child's stdin/stdout/stderr to the tty slave, so the child sees a real tty (programs gating on `isatty` behave correctly). The argv-array invariant (§1.1) is unchanged.

The returned proc handle exposes a single bidirectional master via `pty`:

```cx
[proc
  pid=51022
  [argv "vi" "notes.txt"]
  [pty [file role=pty-master]]
  process-group=51022
  state=:running]
```

The `pty` accessor returns one io-style handle that is both readable (the child's combined stdout+stderr) and writable (the child's stdin). It is read/written via the ordinary [`spec/std-lib/io.md`](io.md) handle operations; there is no second pty-stream API.

| Key | Default | Semantics |
|---|---|---|
| `$rows` | `24` | Initial window-size rows. |
| `$cols` | `80` | Initial window-size columns. |
| `$term` | `"xterm-256color"` | Value of the child's `TERM` env var (overlaid on `$env`). |

- `window-size` returns `[size rows=R cols=C]`.
- `set-window-size` resizes the pty's window and delivers SIGWINCH (POSIX `TIOCSWINSZ`; Windows `ResizePseudoConsole`).

The same lifecycle as `spawn`: `pid` / `wait` / `wait-timeout` / `poll` / `send-signal` / `terminate` / `kill` / `kill-group` / `close` apply unchanged. When the child exits, the master reaches EOF on reads. A freshly-allocated pty runs in the OS default cooked mode.

## §4. Edge cases

### §4.1. argv[0] resolution

When `argv[0]` contains no path separator and `$search-path=true` (default), it is resolved against `PATH` (the child's when `$env` overrides it, else the parent's). When `argv[0]` contains a separator it is a path literal (relative paths resolve per `$cwd`). With `$search-path=false`, `argv[0]` is always a path literal. Unresolvable executable raises `CXER4001`; found-but-non-executable raises `CXER4002`.

### §4.2. Environment

Default is **augment**: child inherits the parent's environment, then `$env` overlays (set / replace; a `null` value deletes a key). `$env-clear=true` starts from an empty environment so `$env` is the complete declared set. They compose: `$env-clear=true` + `$env={"PATH" "/usr/bin"}` yields exactly that one variable.

### §4.3. Capture vs streaming

`run` / `pipeline` buffer captured stdout/stderr fully in memory. For unbounded output, use `spawn` and consume `stdout` incrementally via `io/read-line` / `io/line-iter` / `io/read-bytes`.

### §4.4. Zombies and reaping

A finished POSIX child is a zombie until its parent reaps it. `run` and `pipeline` reap before returning; `wait` / `poll` / `wait-timeout` reap on observed exit; `close` reaps unconditionally. Wrap `spawn` handles in [`[?with-open]`](../core/code.md) (core §8.10.7) so `close` (hence reap) runs on every exit path. Windows has no zombies, but `close` is still required to release the handle.

### §4.5. Timeout → kill escalation

When `$timeout-ms` expires with `$kill-on-timeout=true`, the child is terminated by a graceful-then-forced escalation: SIGTERM, then a short fixed grace, then SIGKILL. For `$new-process-group=true`, the escalation targets the whole group. The returned `[proc-result timed-out=true]` reflects the kill.

### §4.6. stdin EOF

A child reading stdin runs until EOF. `run` signals EOF automatically after the `$stdin` payload (or immediately when `$stdin=null`). For `spawn`, the caller closes the stdin handle (`io/close [$stdin $p]`). A child reading to EOF hangs if the caller never closes stdin.

### §4.7. Encoding

Captured stdout/stderr are raw bytes. `$encoding="utf-8"` (default) decodes to `string`, raising `CXER4008` on invalid sequences. `$encoding=:bytes` returns raw `bytes` with no decode (mirrors [`spec/std-lib/io.md`](io.md) §4.1's text-vs-bytes split).

### §4.8. PTY edge cases

- **Allocation can fail.** Resource exhaustion (RLIMIT_NOFILE, exhausted pty slots) raises `CXER4010`. A platform/OS with no pty facility raises `CXER4009`.
- **Kernel line discipline.** The master handle is line-disciplined by the tty layer; in cooked mode the kernel releases lines after the line terminator and may echo bytes the master writes. `io/read-line` reflects tty cooking, not raw pipe bytes.
- **Window size after exit.** After the child exits, `set-window-size` is a no-op (no SIGWINCH); `window-size` reports the last-set dimensions until close.
- **Ctrl-C on a pty.** The interrupt character written to the master triggers a kernel-generated SIGINT to the pty's foreground process group, distinct from `send-signal`/`terminate` targeting the child pid.

### §4.9. Windows vs POSIX

| Aspect | POSIX | Windows |
|---|---|---|
| Signals | Full atom set via `kill(2)` | `:term`/`:kill` → `TerminateProcess`; `:int` best-effort console event; others raise `CXER4004` |
| Process groups | `setpgid` + `killpg` | Job Objects + `TerminateJobObject`; non-terminating group signals raise `CXER4004` |
| Zombies | Explicit reap required | No zombies; `close` releases the handle |
| PTY | `openpty` / `forkpty`; `set-window-size` → `TIOCSWINSZ` + SIGWINCH | ConPTY (`CreatePseudoConsole`); requires Windows 10 1809+ (older raises `CXER4009`); resize → `ResizePseudoConsole` |
| argv quoting | `exec` takes the vector verbatim | The MS C runtime re-quotes; the caller still passes an argv array (§1.1 invariant preserved) |
| PATH search | `PATH`, `:` separator | `PATH` + `PATHEXT`, `;` separator |

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER4000` | `E_PROC_SPAWN_FAILED` | OS `fork`/`exec`/`CreateProcess` fails for a reason other than the specific codes below |
| `CXER4001` | `E_PROC_NOT_FOUND` | `argv[0]` unresolvable, or `$cwd` missing (§4.1) |
| `CXER4002` | `E_PROC_PERMISSION_DENIED` | `argv[0]` found but not executable, or OS denies the spawn/signal (§4.1) |
| `CXER4003` | `E_PROC_TIMED_OUT` | `$timeout-ms` elapsed with `$kill-on-timeout=false` (§4.5) |
| `CXER4004` | `E_PROC_SIGNAL_UNSUPPORTED` | Signal atom with no platform equivalent, or `kill-group` non-terminating signal on a Windows Job Object (§3.4 / §3.5) |
| `CXER4005` | `E_PROC_PIPELINE_STAGE_FAILED` | A pipeline stage failed to **spawn** (distinct from a stage that ran and exited non-zero — that is reported via `exit-codes`) (§3.3) |
| `CXER4006` | `E_PROC_INVALID_ARGV` | Empty `argv` (`[]`) (§2.1) |
| `CXER4007` | `E_PROC_HANDLE_CLOSED` | Operation on an already-`close`d handle. **Not** raised by an idempotent `close` (§3.2) |
| `CXER4008` | `E_PROC_ENCODING_INVALID` | Captured output invalid in `$encoding` (use `:bytes` for binary) (§4.7) |
| `CXER4009` | `E_PROC_PTY_UNSUPPORTED` | `spawn-pty` / `set-window-size` on a platform without pty / ConPTY (§3.6 / §4.9) |
| `CXER4010` | `E_PROC_PTY_ALLOC_FAILED` | `spawn-pty` ran out of kernel pty resources (§3.6 / §4.8) |
| `CXER4011` | `E_PROC_NOT_GROUP_LEADER` | `kill-group` on a handle not spawned `$new-process-group=true` (§3.5) |
| `CXER4012` | `E_PROC_EXIT_NONZERO` | `run` / `pipeline` with `$check=true` and a non-zero exit / pipefail aggregate; carries the result element (§3.1 / §3.3) |

## §6. Conformance fixtures

Under `conformance/stdlib/process.cxd`:

- Run capture: `[$run ["echo" "hello"]]` returns `exit-code=0`, `stdout="hello\n"`.
- Non-zero exit (default): `[$run ["false"]]` returns `exit-code=3` without raising.
- `$check=true`: `[$run ["false"] check=true]` raises `CXER4012` carrying the `[proc-result …]`.
- stdin feed: `[$run ["cat"] stdin="piped input"]` → `stdout="piped input"`.
- Env augment: `[$run […print $FOO…] env={FOO="bar"}]` sees `FOO=bar` *and* inherits `PATH`.
- Env clear: `[$run […dump env…] env-clear=true env={ONLY="x"}]` sees exactly `ONLY=x`.
- cwd: `[$run ["pwd"] cwd="/tmp"]` returns `/tmp`; missing `$cwd` raises `CXER4001`.
- Timeout → kill: `[$run ["sleep" "10"] timeout-ms=100 kill-on-timeout=true]` returns `timed-out=true signaled=true` within ~100 ms; `kill-on-timeout=false` raises `CXER4003`.
- **Argv-array prevents injection:** `[$run ["echo" "a; rm b"]]` returns `stdout="a; rm b\n"` — the `; rm b` is a literal argument to `echo`, no `rm` runs, a pre-created file `b` still exists after the call.
- Pipeline + pipefail: `[$pipeline [[stage [argv "printf" "a\nb\nERR\n"]] [stage [argv "grep" "ERR"]]]]` returns `stdout="ERR\n"`, `exit-codes=[0 0]`, `exit-code=0`. A pipeline whose first stage exits non-zero while the last exits zero returns the non-zero pipefail `exit-code`.
- Signal delivery: `[$spawn ["sleep" "30"]]` then `[$terminate $p]`; `[$wait $p]` observes `signaled` by `:term`.
- Process-group kill cleans descendants; `kill-group` on a non-group-leader raises `CXER4011`.
- Executable not found: `[$run ["definitely-not-a-real-binary-xyz"]]` raises `CXER4001`.
- Closed handle: `[$close $p]` then `[$wait $p]` raises `CXER4007`; a second `[$close $p]` is a no-op.
- `[?with-open]` reaping: a `spawn` handle wrapped in `[?with-open]` is closed and the child reaped on both normal-exit and error-unwind paths.
- PTY round-trip, window size, resize (delivers SIGWINCH), `TERM` round-trip; pty unsupported raises `CXER4009`.

## §7. Capabilities

Effectful functions in `cx-stdlib/process` run under deny-by-default capabilities ([`spec/core/security.md`](../core/security.md) §2): the effect point checks the active set and raises `cx-err:CXER0271` (E_CAP_DENIED, naming the missing capability and resource) when the grant is absent. Pure functions (in-memory transforms, parsing, formatting) require no capability.

Every function in this module operates on a spawned child process and therefore requires the `subprocess` capability — both the spawn-family entry points and the operations that act on an already-spawned child (signalling, waiting, I/O-handle access, window-size control, closing).

| Capability | Functions |
|---|---|
| `subprocess` | `spawn`, `spawn-pty`, `run`, `pipeline`, `pty`, `kill`, `kill-group`, `send-signal`, `terminate`, `wait`, `wait-timeout`, `poll`, `pid`, `stdin`, `stdout`, `stderr`, `set-window-size`, `window-size`, `close` |

## §8. Cross-references

- [`spec/std-lib/io.md`](io.md) — the handle / stream model reused for child stdio; pty master is a single bidirectional io handle.
- [`spec/std-lib/env.md`](env.md) — current-process metadata sibling; `$env` is how a program sets a child's environment.
- [`spec/std-lib/path.md`](path.md) — `$cwd` and path-bearing `argv[0]` resolve per this module.
- [`spec/core/code.md`](../core/code.md) §8.10.7 — `[?with-open]`; `spawn` handles are `[?with-open]`-compatible.
