# `cx-stdlib/process` — subprocess spawn, capture, pipelines, signals

```cx
[module-meta name=process tier=B status=current]
```

**Status:** Current — §3.2's per-stream stdio dispositions and §4.3's pipe-capacity rule added under RULED: CO-13 (`ledger/rulings_2026_08_25_0170_closeout.md`, #1003 → #1014). That ruling filed the mechanism as its own prio:high with a named landing: `spawn` had no safe primitive for a streaming child, and §4.3 said "use `spawn` for unbounded output" without ever warning that an undrained stream is a pipe that fills. §4.3's `pipeline` paragraph then gained the other direction of the same obligation under the same ruling (#1022 → #1027): the inter-stage **feed** is a write the pipeline owes, it cannot be allowed to fill either, and `$timeout-ms` bounds it. §4.3's `run` paragraph carries the same two sentences for `$stdin` (#1030), which was measured to hold both of #1027's defects at its own blocking write — so all three entry points that owe a child a payload now state the obligation, and none of them can be filled.

RULED: CO-16 (same ledger, #1023 / #1034 / #1035) then made the **dispositions** as uniform as the drain obligation already was. §3.1/§3.1.1: `run`'s `$capture` carries §3.2's full per-stream vocabulary — `:pipe` / `:inherit` / `:discard` / a file path — and §4.3's "`run` … has no file target" clause, together with the sentence routing that caller to `spawn`, is **retracted**; the four shipped atoms stay, restated as the pairs of dispositions they always were. §4.4 gains the descriptor-release half of a reaping contract that previously assumed it without saying it. §4.7 states the accepted set as a rule, scopes what `$encoding` governs per entry point, and records that `spawn` validates it and decodes nothing — it captures nothing, so text-versus-bytes stays on each `io` read.

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
| `$stdin` | `null` | `string` or `bytes` fed to the child; EOF after the last byte. `null` is immediate-EOF. Any size: the feed cannot fill the pipe and is bounded by `$timeout-ms` (§4.3). |
| `$timeout-ms` | `null` | Wall-clock budget. On expiry the child is handled per `$kill-on-timeout`. |
| `$kill-on-timeout` | `true` | `true` escalates SIGTERM → SIGKILL (§4.5) and returns `timed-out=true`; `false` raises `CXER4003`. |
| `$capture` | `:both` | Each **output** stream's disposition, in §3.2's vocabulary — `:pipe` (captured), `:inherit`, `:discard`, or a file path. `:both` / `:stdout` / `:stderr` / `:none` abbreviate pairs of those. §3.1.1. |
| `$encoding` | `"utf-8"` | Decode the bytes this call **captured**; `:bytes` returns raw bytes with no decode (§4.7). |
| `$search-path` | `true` | Resolve separator-free `argv[0]` against `PATH` (§4.1). |
| `$new-process-group` | `false` | Spawn as leader of a fresh process group (§3.5). |
| `$check` | `false` | When `true`, a non-zero `exit-code` raises `CXER4012` carrying the `[proc-result …]`. |

`run` reaps the child before returning.

#### §3.1.1. `$capture` — one disposition vocabulary

`$capture` gives each of the child's two **output** streams a disposition, and the values are §3.2's, unchanged. There is one disposition vocabulary in this module and every entry point spells it the same way:

| Value | Semantics on `run` |
|---|---|
| `:pipe` | **Captured** — the bytes are read into the returned `[proc-result …]`. `run` drains while the child runs (§4.3), so this pipe cannot fill. |
| `:inherit` | Not redirected: the child writes to the **parent's own** descriptor. |
| `:discard` | The null device. Spelled `:discard` and not `:null`, for §3.2's reason. |
| a `string` path | A file, created-or-truncated. An unopenable path raises `CXER4001` / `CXER4002` **before** the child is spawned. |

Each stream is named in a map:

```cx
[$run ["./noisy"] capture={stdout: "/tmp/out.log", stderr: :discard} timeout-ms=5000]
```

The overlay is per **key**: a stream the map does not name keeps its default, which is `:pipe`. `capture={stderr: "/tmp/err.log"}` still captures stdout.

The four atoms are **abbreviations** for pairs of dispositions, which is what they have always meant:

| Atom | `stdout` | `stderr` |
|---|---|---|
| `:both` (default) | `:pipe` | `:pipe` |
| `:stdout` | `:pipe` | `:inherit` |
| `:stderr` | `:inherit` | `:pipe` |
| `:none` | `:inherit` | `:inherit` |

`:pipe`, `:inherit` and `:discard` are additionally accepted bare, meaning both output streams; the first two are then synonyms for `:both` and `:none`.

**Only a captured stream reaches the result.** A stream given any other disposition carries **no attribute at all** on the `[proc-result …]` — not an empty one. `stdout=''` would assert "captured, and it was empty", which is a non-fact when the bytes went to a file or to the parent's terminal. This is §3.2's `CXER4013` rule in the form `run` can state it: `spawn` has an accessor to refuse from, `run` has an attribute to omit.

**`stdin` is not a disposition here.** `run`'s `$stdin` is a payload (§3.1), fed non-blockingly under `$timeout-ms` (§4.3); a `stdin` key inside `$capture` raises `CXER0100` naming it and saying where the payload lives. A stdin *disposition* is `spawn`'s (§3.2 / §4.6).

**A bare file path raises `CXER0100`.** It would have to mean both output streams into one file, which is a **merge** — one file offset shared between two independent writers — and §3.2's file disposition is defined per stream. Name the stream instead. Any other value raises `CXER0100` naming it and the accepted set: a misspelled disposition is never silently the default, because the default here is a capture and the caller was asking for something else.

### §3.2. Streaming spawn

```
[?def spawn scope=public impure [returns element]
  ($argv::[sequence string]
   $env=null $env-clear=false $cwd=null
   $encoding="utf-8" $search-path=true $new-process-group=false
   $stdin=:pipe $stdout=:pipe $stderr=:pipe) ...]

[?def stdin         scope=public impure [returns element]       ($handle::element) ...]
[?def stdout        scope=public impure [returns element]       ($handle::element) ...]
[?def stderr        scope=public impure [returns element]       ($handle::element) ...]
[?def pid           scope=public impure [returns int]           ($handle::element) ...]
[?def wait          scope=public impure [returns int]           ($handle::element) ...]
[?def wait-timeout  scope=public impure [returns [or int [sequence int]]] ($handle::element $ms::int) ...]
[?def poll          scope=public impure [returns [or int [sequence int]]] ($handle::element) ...]
[?def close         scope=public impure [returns null]          ($handle::element) ...]
```

Each of the child's three streams carries an independent **disposition**. The three options are named for the streams they govern and take the same value set:

| Value | Semantics |
|---|---|
| `:pipe` | A pipe held by the parent. The **only** disposition with a stdio handle, and the default for all three streams. **A pipe the caller does not drain fills and blocks the child** — see §4.3. |
| `:inherit` | Not redirected: the child writes to (or reads from) the **parent's own** descriptor, exactly as `run`'s uncaptured streams do (§3.1). Cannot fill. |
| `:discard` | The null device. Writes are thrown away; a `:discard` stdin is immediate EOF. Cannot fill. Spelled `:discard` and **not** `:null`, because `:null` is a reserved atom literal ([`spec/core/code.md`](../core/code.md) — the bare `null` scalar owns that spelling). |
| a `string` path | A file. An output stream creates-or-truncates it; `stdin` opens it for reading. Cannot fill, and the bytes are kept. An unopenable path raises `CXER4001` / `CXER4002` **before** the child is spawned. |

Any other value raises `CXER0100` naming the stream and the accepted set — a misspelled disposition is never silently the default, because the default is the deadlock the caller was avoiding.

- `stdin` / `stdout` / `stderr` — return the child's io-style stdio handles. Closing `stdin` (`io/close`) signals EOF. **Only a `:pipe` stream has a handle**: on any other disposition there is no parent-side descriptor, and the accessor raises `CXER4013` naming the disposition the stream was given.
- `wait` — block until exit; return `exit-code`; reap.
- `wait-timeout` — block up to `ms`; return `exit-code`, or **absence** (the empty sequence `()`) if still running (no kill — caller decides). "Still running" is "no result here yet" — the **absence channel** ([`code.md`](../core/code.md) §9.1.2), **never** `null` (the §9.1.2.1 no-conflation guard).
- `poll` — non-blocking; return `exit-code`, or **absence** (the empty sequence `()`) if still running.
- `close` — release the handle: close any open stdio handles and reap the child. Does **not** kill a still-running child (detaches). Idempotent. Makes the handle `[?with-open]`-compatible.

```cx
[; stdout is consumed incrementally; stderr is NOT read, so it must not be a
   pipe — here it goes to the parent's own stderr. ]
[?with-open [$spawn ["tail", "-f", "/var/log/app.log"] stderr=:inherit] $p
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
- `opts` — a per-stage options element carrying **four** keys: the attributes `cwd`, `env-clear` and `search-path`, and the child element `env`. Each overrides its pipeline-level counterpart for that stage alone. The override is decided per KEY: a stage that names only `cwd` still receives the pipeline's `$env`.

`env` is a **child element carrying a map**, not an attribute — an attribute is scalar-only ([`code.md`](../core/code.md) §6.4.1), so a map value has no attribute form:

```cx
[$pipeline [
  [stage [argv "cmd1"] [opts [env {FOO: "1"}]]]
  [stage [argv "cmd2"] [opts [env {BAR: "2"}]]]]]
```

This is POSIX's `FOO=1 cmd1 | BAR=2 cmd2`. The stage's `[env …]` is an **overlay**, applied per KEY in this order, each layer overriding the one before it:

1. **`env-clear`** — §4.2's hermetic switch picks the base: the parent's environment, or nothing. The stage's own `env-clear` overrides the pipeline's, so the base is chosen per stage.
2. **pipeline `$env`** — applied to every stage.
3. **stage `[env {…}]`** — applied last, to that stage alone.

Because every layer is per KEY, a stage that overrides one variable keeps every pipeline variable it did not name. A `null` value deletes a key (§4.2), and `[env {}]` is a layer too — on a hermetic stage it means "no environment at all".

The body must be exactly one map whose values are scalars; anything else — a missing body, a non-map body, a non-scalar value, or a second `[env …]` — raises `CXER0100`.

Every other `run` key is **refused by name** inside `[opts …]` with `CXER0100`, and so is an unrecognized key — a per-stage option is never silently dropped. The refusals are not an implementation shortfall; each names a rule stated elsewhere in this document that a per-stage form would contradict:

| Key | Why it is refused per-stage |
|---|---|
| `$stdin` / `$capture` | The pipeline owns them (this section, above). |
| `$timeout-ms` / `$kill-on-timeout` | §4.3 scopes the budget to the **whole** pipeline — "one deadline for the run", explicitly "not each stage". A per-stage budget has no defined relation to that single deadline. |
| `$new-process-group` | §4.3 states that `pipeline` has no such option, and the timeout escalation depends on it: each stage leader is signalled **directly**. |
| `$encoding` | §4.7 decodes the *pipeline's* captured output, and the last stage's stdout **is** that output — the two would claim the same bytes. |
| `$check` | §3.3 defines `$check` on the pipefail **aggregate**, not on one stage. |
| `env=` (the attribute form) | An attribute is scalar-only ([`code.md`](../core/code.md) §6.4.1), so a map-valued `env=` has no attribute form. Use the `[env {…}]` child element above. |

Pipeline-level options mirror `run` where they apply to the whole pipeline: `$env` / `$env-clear` / `$cwd` are applied to **every** stage (§4.2) — a stage's own `[opts …]` then overrides them for that stage, per key — and `$encoding` decodes everything the pipeline captured (§4.7). The `stages` argument is positional. A per-stage `[opts …]` is a data element, not a function parameter.

Returns a `[pipeline-result …]`:

```cx
[pipeline-result
  [stages
    [proc-result [argv "grep" "..."] exit-code=0 signaled=false timed-out=false stderr=""]
    [proc-result [argv "cut" "..."]  exit-code=0 signaled=false timed-out=false stderr=""]
    [proc-result [argv "sort" "..."] exit-code=0 signaled=false timed-out=false stderr=""]]
  [exit-codes 0 0 0]
  stdout="…last stage's captured stdout…"
  exit-code=0]
```

- `exit-code` is the **pipefail aggregate**: `0` iff every stage exited `0`; otherwise the exit code of the last non-zero stage (`set -o pipefail` semantics). A failing early stage is never masked.
- Each stage row is a §2.3 `[proc-result …]`, so it reports that stage's own `stderr` and `timed-out` — the pipeline owns and drains every stage's streams (§4.3).
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
[?with-open [$spawn ["./serve.sh"] new-process-group=true] $p
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

### §4.3. Capture vs streaming — and the pipe-capacity rule

`run` / `pipeline` buffer **captured** stdout/stderr fully in memory. For unbounded output there are two answers, and which one applies depends on what the caller wants to do with the bytes: to *keep* them without holding them, give the stream a file disposition (`run`, §3.1.1; `spawn`, §3.2) — the call stays bounded and nothing is resident; to *process* them as they arrive, use `spawn` and consume `stdout` incrementally via `io/read-line` / `io/line-iter` / `io/read-bytes`.

**An undrained `:pipe` deadlocks the child.** A pipe is a fixed-size kernel buffer, not a queue that grows. A child writing to a `:pipe` nobody reads blocks — permanently — once that buffer is full, and there is **no timeout on the read path** to turn the block into an error. This is normative, not advisory: it is the defining constraint on how a streaming child may be driven.

- **The capacity is small, and it is not even fixed.** Measured on this implementation (darwin, bisected exactly): a child writing **65536** bytes to an undrained stream completes; **65537** blocks forever. That 64 KiB is what an *idle* machine grants — under pipe-memory pressure the same kernel hands out **512-byte** buffers instead (measured on this platform, #993/#1002), which is why this class of failure presents as "red under a parallel build, green on a clean re-run". Treat the number as a platform variable, never as a budget to design against.
- **The deadlock is mutual.** A caller draining one stream while the other fills cannot recover: it is blocked in a read on the stream it chose, so it never reaches the stream that is full. Draining "afterwards" is not a fix — there is no afterwards.
- **Therefore: every stream a caller will not read must be given a non-`:pipe` disposition (§3.2).** `:inherit`, `:discard`, and a file path all cannot fill. Leaving a stream `:pipe` is a promise to drain it.

**Supported streaming patterns.** These are the shapes the module is specified to support:

| Pattern | Shape |
|---|---|
| One stream consumed, the other passed through | `[$spawn argv stderr=:inherit]`, then read `stdout` incrementally. The child's diagnostics reach the parent's terminal. |
| One stream consumed, the other dropped | `[$spawn argv stderr=:discard]`. Use only when the discarded stream genuinely carries nothing the caller needs — a dropped stderr is a dropped diagnostic. |
| One stream consumed, the other kept for later | `[$spawn argv stderr="/path/to/err.log"]`, then read the file after `wait`. Unbounded in the child's output, bounded in the parent's memory. |
| Neither stream consumed | `[$spawn argv stdout="…" stderr="…"]` (or `:inherit` / `:discard`), then `wait`. No pipe exists, so nothing can fill. |
| Both streams consumed | Read the two handles **alternately and without blocking** (`io/read-bytes` on the ready stream). Reading one to EOF first is the deadlock above. |
| Feeding a child that also talks | `stdin=:pipe`, write, then `io/close` the stdin handle (§4.6), draining output as you go. |

**What `pipeline` does.** A pipeline stage's three streams all belong to `pipeline` — §3.3 gives the caller no per-stage `$stdin` or `$capture` — so there is no caller to hand the drain obligation to, and it is `pipeline`'s on every stage:

- **Both output streams are drained while each stage runs**, so a stage that says more than the pipe holds on **stderr** cannot deadlock the pipeline. Its stdout is the next stage's stdin (the chaining); its stderr is captured and reported on that stage's `[proc-result …]` row (`stderr=`) rather than discarded — a dropped stderr is a dropped diagnostic.
- **The inter-stage feed is `pipeline`'s write, and it cannot fill either.** The obligation is symmetrical: stage N's captured stdout is stage N+1's stdin, and that stdin is a `:pipe` of the pipeline's, so an over-capacity payload would block the *parent* in `write()` exactly as an undrained output blocks the child. So the feed is **written non-blockingly from inside the same per-stage drain loop** — each pass writes what the pipe will take, the offset advances, and the descriptor is closed at end-of-payload to give the stage its EOF (§4.6). A caller never has to size a payload against the pipe buffer; `[$pipeline … stdin=$megabyte]` is an ordinary call.
- **A stage that stops reading ends the feed, and that is not a pipeline failure.** `head -c 10` reads what it wants and exits; the pipeline's remaining write returns `EPIPE`, the feed ends there, and **the stage's own exit status is the verdict** — `0` for `head`, so the pipeline succeeds and reports the ten bytes. There is no separate "feed truncated" flag: it would be a second, weaker account of a fact the exit status already carries, and for `head` a misleading one. A stage that *dies* mid-feed exits non-zero and the pipefail aggregate carries that instead. In neither case may the write kill the calling process: `pipeline` takes `SIGPIPE` off its default disposition for its own duration and restores it on the way out, so the error is a value the implementation acts on rather than a signal it cannot survive. The stages themselves are unaffected — their `SIGPIPE` disposition is the platform default.
- **`$timeout-ms` bounds the whole pipeline, not each stage**: one deadline for the run, so an n-stage pipeline under a 1,000 ms budget finishes inside 1,000 ms and not n × 1,000. Because the feed lives inside the loop the deadline governs, **the budget bounds the feed too** — a stage that reads nothing is killed at the deadline like a stage that never exits, and no shape of payload can put the pipeline outside its budget. The accounting is per stage — whichever stage is alive when the deadline passes is killed by §4.5's escalation and is the one whose row carries `timed-out=true`, and **no later stage starts**, so `stages` and `exit-codes` carry only the stages that actually ran. `$kill-on-timeout=false` raises `CXER4003` naming that stage; the stage is killed either way.
- `pipeline` has no `$new-process-group`, so the escalation signals each stage leader directly. As with `run` on the no-group path, a surviving grandchild cannot extend the pipeline: the post-kill read is bounded, not a read to EOF.
- **The spawn-shaping options are applied per stage, and the capture-shaping options once.** `$env` / `$env-clear` / `$cwd` shape each `exec` and are therefore applied to **every** stage (a stage may narrow the first two and `$cwd` via `[opts …]`, §3.3); a missing `$cwd` raises `CXER4001` **before** any stage spawns, so a pipeline never runs half its stages in the wrong directory and then faults. `$encoding` shapes what the pipeline hands back — the last stage's stdout and every stage's `stderr` row — and is therefore resolved once, at the end (§4.7).

**What `run` does and does not cover.** `run` (§3.1) drains both captured streams **while the child runs**, so a large capture does not deadlock it and `timed-out=true` means the child really did outlive its budget; after a timeout the tail read is itself bounded, so a killed child's surviving grandchild cannot extend the call by holding the write end.

**`$stdin` is `run`'s write, and it cannot fill either.** The obligation is the same one `pipeline` carries above, and it is `run`'s for the same reason: `$stdin` (§3.1) is a payload the call owes a `:pipe` of its own, so an over-capacity payload would block `run` in `write()` — and a `run` blocked in its own `write()` is not draining, so a child that fills its captured stdout while `run` is stuck filling its stdin deadlocks both halves. So the payload is **written non-blockingly from inside the same drain loop**, each pass writing what the pipe will take, and the descriptor is closed at end-of-payload to give the child its EOF (§4.6). A caller never has to size `$stdin` against the pipe buffer; `[$run … stdin=$megabyte]` is an ordinary call. Because the write lives inside the loop the deadline governs, **`$timeout-ms` bounds the feed too** — a child that reads nothing is killed at the deadline exactly like a child that never exits, and no shape of payload can put a `run` outside its budget.

**A child that stops reading ends the feed, and that is not a `run` failure.** `head -c 10` reads what it wants and exits; the remaining write returns `EPIPE`, the feed ends there, and **the child's own exit status is the verdict** — `0` for `head`, so the `run` succeeds and `stdout` reports the ten bytes. There is no separate "stdin truncated" attribute: it would be a second, weaker account of a fact `exit-code` already carries, and for `head` a misleading one. A child that *dies* mid-feed exits non-zero and `exit-code` (with `$check`) carries that instead. In neither case may the write kill the calling process: `run` takes `SIGPIPE` off its default disposition for its own duration and restores it on the way out, so the error is a value the implementation acts on rather than a signal it cannot survive. The child itself is unaffected — its `SIGPIPE` disposition is the platform default.

**`run`'s per-stream choice is the whole disposition vocabulary** (`$capture`, §3.1.1) — the same four values `spawn` takes, per output stream. So a stream `run` does not capture is not merely "inherited": it can be `:discard`ed or sent to a **file**, and only a `:pipe` stream is held in memory at all.

That makes the memory bound a per-stream fact rather than a `run` fact. `[$run … capture={stdout: "/tmp/out.log"} timeout-ms=5000]` runs an arbitrarily loud child under a wall-clock bound with nothing accumulating in the parent, and the bytes are kept. Before this, that shape had no expression here — `run` gave the bound and no file, `spawn` gave the file and no bound — so a caller who needed both had to shell out to `sh -c '… > file'` and lose the budget, which is the harm this amendment closes.

One limit remains, and it is what `spawn` is for:

- **`run` has no incremental consumption.** A caller that wants to *process* output as it arrives needs a stdio handle, and only a `:pipe` on `spawn` yields one (§3.2). `run` returns when the child is done — that is what one-shot means — and a **captured** stream is materialized whole, bounded by available memory.

The obligation is the same in both directions: **a pipe belongs to whoever must read it, and that reader must be running while the child writes.** A drain scheduled for after the child exits is not a drain.

### §4.4. Zombies, reaping, and descriptor release

A finished POSIX child is a zombie until its parent reaps it. `run` and `pipeline` reap before returning; `wait` / `poll` / `wait-timeout` reap on observed exit; `close` reaps unconditionally. Wrap `spawn` handles in [`[?with-open]`](../core/code.md) (core §8.10.7) so `close` (hence reap) runs on every exit path. Windows has no zombies, but `close` is still required to release the handle.

**Reaping is half the obligation; the descriptors are the other half.** A captured stream is a pipe, and the *parent's* end of it is the call's to close. So:

- **Every parent-side capture descriptor is closed on every exit path of the call that opened it.** "Every exit path" is not a synonym for "the success path": a `run` that raises `CXER4003` (`$kill-on-timeout=false`), one that raises `CXER4012` (`$check`), and one that faults on `$encoding` are all still returns from `run`, and each owes the same release as the ordinary one. §4.4's "`run` and `pipeline` reap before returning" is likewise unqualified — it is an obligation of the **call**, not of its success.
- **The order is close-then-reap.** The parent's read ends go first, so anything still holding a write end — a killed child's surviving grandchild (§4.3) — takes an `EPIPE` rather than being able to keep the descriptor alive, and only then is the direct child waited on. That wait is bounded on every path that reaches it: each has either observed the child exit or run §4.5's escalation through SIGKILL, which is uncatchable.
- **A forced kill must not disqualify its own victim from being reaped.** §4.5's escalation exists precisely for a child that ignored SIGTERM, so the killed child is exactly the one that still needs waiting on. Its `exit-code` is the platform's signal-encoded status per §2.3 — POSIX `128 + signum`, so `128 + 9 = 137` for the forced phase — and `signaled=true` accompanies it.
- **A spawn that fails leaves no descriptors either.** The pipes are created before the `fork`, so a failed `exec` still owes their parent ends, even though there is no child to reap.

The releases are idempotent, and that is load-bearing rather than tidy: a second close of a descriptor number the kernel has since recycled is not a leak, it is silent corruption of whatever file now holds that number.

A non-`:pipe` disposition has no parent-side pipe to release, but it does have a descriptor obligation of its own: `:discard` and a file path are installed by replacing the **parent's** descriptor across the `fork` (§4.9), and the parent's own must be restored the moment the fork returns — the window is the fork, never the child's lifetime.

### §4.5. Timeout → kill escalation

When `$timeout-ms` expires with `$kill-on-timeout=true`, the child is terminated by a graceful-then-forced escalation: SIGTERM, then a short fixed grace, then SIGKILL. For `$new-process-group=true`, the escalation targets the whole group. The returned `[proc-result timed-out=true]` reflects the kill.

### §4.6. stdin EOF

A child reading stdin runs until EOF. `run` signals EOF automatically after the `$stdin` payload (or immediately when `$stdin=null`). For `spawn`, the caller closes the stdin handle (`io/close [$stdin $p]`). A child reading to EOF hangs if the caller never closes stdin.

The stdin disposition (§3.2) decides who owes the EOF, and the two non-pipe forms remove the obligation entirely:

- `stdin=:pipe` (default) — the caller owes the child an EOF. Not writing and not closing is a hang, symmetrical with the undrained-output hang of §4.3: an unclosed stdin pipe is a promise never kept.
- `stdin=:discard` — the null device is at EOF immediately; the child sees an empty input and needs nothing from the caller.
- `stdin="/path/to/file"` — the child reads the file and gets EOF from the kernel at its end. This is how a child is fed input larger than the pipe buffer without the caller having to interleave writes with output draining.
- `stdin=:inherit` — the child reads the parent's own stdin. It gets EOF when the parent's stdin does, which for an interactive parent may be never; do not use it for a child that reads to EOF unless that is the intent.

Symmetrically, **a stream that is not a `:pipe` has no handle**: `[$stdin $p]` / `[$stdout $p]` / `[$stderr $p]` on such a stream raises `CXER4013` rather than returning a handle that would read as an empty stream. An empty stream would assert that nothing was written, which is a non-fact when the bytes went to a file or the parent's terminal.

**Bounded-drain caveat.** No read on a child stdio handle carries a timeout. `wait-timeout` bounds the *wait*, not a read already in progress, so a bound on the overall operation has to come from the caller's own structure (`io/read-bytes` on a stream known to be ready, a `$timeout-ms`-bounded `run`, or dispositions that make the fill impossible). A gate or probe that reads a child stream unbounded is not bounded, whatever budget it declares.

### §4.7. Encoding

Captured stdout/stderr are raw bytes. `$encoding="utf-8"` (default) decodes to `string`, raising `CXER4008` on invalid sequences. `$encoding=:bytes` returns raw `bytes` with no decode (mirrors [`spec/std-lib/io.md`](io.md) §4.1's text-vs-bytes split).

**The accepted set is exactly those two.** `"utf-8"` or `:bytes`; any other value raises `CXER0100` naming it and the set, at **every** entry point that declares `$encoding`. A misspelling must not fall back to the default, because the default is a decode and a caller who wrote something else was asking for raw bytes — the same rule, for the same reason, that §3.2 states for a misspelled disposition. The value is read **before** anything is spawned, so a bad encoding leaves no child behind.

**What it governs is scoped per entry point**, because "captured output" means something different at each:

| Entry point | What `$encoding` decodes |
|---|---|
| `run` | The streams this call **captured** — the `:pipe` ones (§3.1.1). A stream given `:inherit`, `:discard`, or a file path was never the call's to decode, so it is unaffected: the bytes went to a descriptor, the null device, or a file, and a file holds them raw. A child whose output is invalid UTF-8 therefore raises `CXER4008` under a capture and does not raise under a file target. |
| `pipeline` | Everything the call captured — the returned `stdout` and every stage row's `stderr` (§4.3) — resolved once, at the end. A binary-carrying pipeline needs `:bytes` once, not per stage. It is not a per-stage key (§3.3). |
| `spawn` / `spawn-pty` | **Nothing.** See below. |

**`spawn` validates `$encoding` and decodes nothing, and that is the whole of its contract.** `spawn` captures nothing: its streams are §2.4 io handles, and [`spec/std-lib/io.md`](io.md) §4.1 puts the text-versus-bytes choice on the **read** — `io/read-line` versus `io/read-bytes`, per call — not on the handle. So there is no byte on that path for `$encoding` to decode, and the option's only effect is to refuse a value this section does not define. That refusal is the half that needs no further ruling and the half that was actively wrong before; making `$encoding` decide a handle's default read kind would be a new contract spanning this document and `io.md`, and is not implied by anything either of them says today.

The `CXER4008` raise is ordered **before** `$check`'s `CXER4012`: a binary-output child should report the encoding fault it actually hit rather than an exit code that happens to be zero.

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
| Stream dispositions (§3.2 / §3.1.1) | All four, on `spawn` and on `run`'s `$capture` alike. `:discard` / a file path are installed on the parent's own descriptor across the `fork`, which the child inherits | `:pipe` / `:inherit` only; the CRT descriptor a `dup2` moves is not the handle `CreateProcess` inherits, so `:discard` and a file path are **not backed** and raise `CXER4000` naming the reason rather than silently piping |

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
| `CXER4013` | `E_PROC_STREAM_NOT_PIPED` | `stdin` / `stdout` / `stderr` on a stream whose disposition is not `:pipe`; names the disposition the stream was given (§3.2 / §4.6) |

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
- **Pipeline options, on the capability-GRANTED path** (a deny-only fixture cannot cover these — it raises `CXER0271` at the guard, so the stage element it names is never reached): `cwd="/"` puts the stage in `/`; a stage `[opts cwd="/usr"]` overrides that for itself while still receiving the pipeline's `$env`; `env={…}` reaches the child; `env-clear=true` yields exactly the declared set, at pipeline level and per stage; `[opts search-path=false]` stops resolving a separator-free `argv[0]` while still running an absolute one; `encoding=:bytes` carries bytes invalid in UTF-8 that the default rejects with `CXER4008`; a missing `$cwd` raises `CXER4001`; and every `[opts …]` key the section does not honor — plus an unknown one — raises `CXER0100` naming that key.
- **Per-stage `[env {…}]`, on the capability-GRANTED path:** two stages with different variables — POSIX's `FOO=1 cmd1 | BAR=2 cmd2` — each child sees its own and not the other's; a stage overriding one pipeline `$env` key still receives every key it did not name; the overlay composes with `env-clear` in both orders (the stage's own `env-clear=true` yields exactly the stage's set, and a hermetic pipeline yields the pipeline's set with the stage's key overridden). A non-map body, a missing body, a non-scalar value, a second `[env …]`, an unrecognized `[opts …]` child element, and the `env=` **attribute** form each raise `CXER0100` naming what was wrong.
- Signal delivery: `[$spawn ["sleep" "30"]]` then `[$terminate $p]`; `[$wait $p]` observes `signaled` by `:term`.
- Process-group kill cleans descendants; `kill-group` on a non-group-leader raises `CXER4011`.
- Executable not found: `[$run ["definitely-not-a-real-binary-xyz"]]` raises `CXER4001`.
- Closed handle: `[$close $p]` then `[$wait $p]` raises `CXER4007`; a second `[$close $p]` is a no-op.
- **Pipe capacity (§4.3), behavioral:** a child writing 100,000 bytes to stderr while the caller drains only stdout **deadlocks** with all three streams `:pipe` (the default), and **completes** under each of `stderr=:inherit`, `stderr=:discard`, and `stderr=<path>`. Same child, same drain, one option changed. Under `stderr=<path>` the file holds exactly the bytes written; under `:inherit` they arrive on the parent's own stderr. Each probe carries its own wall-clock bound — a regression here IS a hang, so an unbounded fixture would take the suite with it instead of failing.
- **`run` `$stdin` feed capacity (§4.3), behavioral:** `[$run ("cat") stdin=<200,000 bytes> timeout-ms=5000]` returns that payload **byte-for-byte** on `stdout` — the child echoes an over-capacity payload back into an over-capacity capture, so both halves would block on a blocking write. `[$run ("head" "-c" "10") stdin=<200,000 bytes>]` returns those ten bytes with `exit-code=0` and **the calling process still running** (the `EPIPE` end-of-feed, not a `SIGPIPE` death), and grows no truncation attribute. `[$run ("sh" "-c" "sleep 3600") stdin=<200,000 bytes> timeout-ms=600]` reports `timed-out=true` at the deadline — the same child with **no** payload was already bounded, so the payload is the whole difference. `capture=:none` with an over-capacity payload and no `$timeout-ms` still delivers every byte. All wall-clock bounded, for the same reason as the probes below.
- **Pipeline feed capacity (§4.3), behavioral:** `printf '%0200000d' 1 | cat | wc -c` expressed as a three-stage `pipeline` returns `stdout` counting **200000** bytes — every byte of an over-capacity payload survives two inter-stage feeds. The same 200,000-byte payload into a `head -c 10` stage returns that stage's ten bytes with `exit-code=0` and the calling process still running (the `EPIPE` end-of-feed, not a `SIGPIPE` death); into a stage that reads nothing (`sh -c 'sleep 3600'`) under `timeout-ms=600` it is killed at the deadline with `timed-out=true` on that stage's row. All three are wall-clock bounded for the same reason as the pipe-capacity probes above.
- Non-`:pipe` accessor: `[$stderr $p]` on a handle spawned `stderr=:discard` raises `CXER4013` naming the disposition; an unknown disposition atom raises `CXER0100` naming the stream and the accepted set.
- **`run` `$capture` dispositions (§3.1.1), on the capability-GRANTED path:** `capture={stdout: <path>}` on a 200,000-byte child under a `$timeout-ms` returns with **no `stdout` attribute at all** and the file holding exactly those bytes — bounded, kept, and never resident. The same shape under a child that outlives its budget reports `timed-out=true signaled=true` with the pre-deadline bytes still in the file. `capture=:discard` captures nothing and leaks nothing to the parent; `capture=:pipe` / `:inherit` behave as `:both` / `:none`; each of the four atoms produces exactly its documented pair. `capture={stderr: <path>}` still captures stdout (the per-key default). `encoding=:bytes` reaches the captured stream while the other stream's file target holds raw bytes, and an invalid-UTF-8 stdout raises `CXER4008` when captured and does **not** when file-targeted. A `$stdin` payload round-trips into a file-targeted stdout. A bare file path, a `stdin` key, an unknown key, an unknown disposition, an unknown whole-capture atom, an empty path, and a non-map value each raise `CXER0100` naming what was wrong; an unopenable target raises `CXER4001` / `CXER4002` **before** the child runs, proven by a side effect the child never performs.
- **Descriptor release across the new dispositions (§4.4):** the parent's open-descriptor count, sampled from inside successive children, does not move across runs that mix file targets, `:discard`, and ordinary captures.
- File-fed stdin: `[$spawn ["cat" "-"] stdin=<path> stdout=<path>]` then `wait` round-trips the file with no caller-side write and no drain.
- `[?with-open]` reaping: a `spawn` handle wrapped in `[?with-open]` is closed and the child reaped on both normal-exit and error-unwind paths.
- PTY round-trip, window size, resize (delivers SIGWINCH), `TERM` round-trip; pty unsupported raises `CXER4009`.

## §7. Capabilities

Effectful functions in `cx-stdlib/process` run under deny-by-default capabilities ([`spec/core/security.md`](../core/security.md) §2): the effect point checks the active set and raises `cx-err:CXER0271` (E_CAP_DENIED, naming the missing capability and resource) when the grant is absent. Pure functions (in-memory transforms, parsing, formatting) require no capability.

Every function in this module operates on a spawned child process and therefore requires the `subprocess` capability — both the spawn-family entry points and the operations that act on an already-spawned child (signalling, waiting, I/O-handle access, window-size control, closing).

| Capability | Functions |
|---|---|
| `subprocess` | `spawn`, `spawn-pty`, `run`, `pipeline`, `pty`, `kill`, `kill-group`, `send-signal`, `terminate`, `wait`, `wait-timeout`, `poll`, `pid`, `stdin`, `stdout`, `stderr`, `set-window-size`, `window-size`, `close` |

## §8. Cross-references

- [`spec/std-lib/io.md`](io.md) — the handle / stream model reused for child stdio; pty master is a single bidirectional io handle. Only a `:pipe` stream (§3.2) yields one, and no read on it carries a timeout (§4.6).
- [`spec/std-lib/env.md`](env.md) — current-process metadata sibling; `$env` is how a program sets a child's environment.
- [`spec/std-lib/path.md`](path.md) — `$cwd` and path-bearing `argv[0]` resolve per this module.
- [`spec/core/code.md`](../core/code.md) §8.10.7 — `[?with-open]`; `spawn` handles are `[?with-open]`-compatible.
