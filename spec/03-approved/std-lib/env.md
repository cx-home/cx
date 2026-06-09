# `cx-stdlib/env` — environment variables, args, process metadata

```cx
[module-meta name=env tier=B status=current]
```

**Status:** Current for v0.8.0

Normative reference for the `cx-stdlib/env` sub-package.

---

## §1. Scope

`cx-stdlib/env` exposes process-level metadata to CX code:

- Environment variables — read / list / typed-defaults.
- Command-line arguments — raw `argv` and parsed flags + positional (argparse-equivalent).
- Process metadata — PID, executable path, cwd, hostname, OS / arch.
- Standard streams — stdin / stdout / stderr handles (I/O lives in [`cx-stdlib/io`](io.md)).
- Process termination — `exit(code)`.

Tier B runtime surface — necessarily impure.

## §2. Conceptual model

The environment is **process-global and read-only from CX code**: there are no setters. Mutating global process env is deferred — `setenv(3)` is not thread-safe. Subprocess env overrides go through the `:env` map on [`cx-stdlib/process`](process.md)'s `[$process:run]` / `[$process:spawn]`.

Command-line arguments are parsed once at process start; subsequent calls return cached values. Parsed flags use a declarative shape:

```cx
[?const ARG_SPEC [argspec
  [flag name="verbose" short="v" type=bool]
  [flag name="limit"   short="n" type=int    default=100]
  [flag name="output"  short="o" type=string required=true]
  [positional name="input-file" type=string required=true]]]

[?let [= $args [$env:parse-args ARG_SPEC]]
  [$env:flag $args "verbose"]]
```

## §3. Public function surface

### §3.1. Environment variables

```
[?def var      scope=public impure [returns [or string [sequence string]]] ($name::string) ...]
[?def vars     scope=public impure [returns map]              () ...]
[?def has-var  scope=public impure [returns bool]             ($name::string) ...]
```

- `var(name)` — value of env var, or **absence** (the empty sequence `()`) if unset. A var set to `""` returns `""` (distinct from unset → absence). Per the value-channel model ([`code.md`](../core/code.md) §9.1.2), an unset optional read signals "nothing here" via the **absence channel**, **never** `null` (the §9.1.2.1 no-conflation guard); extract with `[?else]` (`getOrElse`) or use `var-required` for a fault on miss.
- `has-var(name)` — true iff the var is set (distinguishes "set to empty string" from "unset").

#### §3.1.1. Typed defaults

```
[?def var-or-default scope=public impure [returns string] ($name::string $default::string) ...]
[?def var-int        scope=public impure [returns int]    ($name::string $default::int) ...]
[?def var-float      scope=public impure [returns float]  ($name::string $default::float) ...]
[?def var-bool       scope=public impure [returns bool]   ($name::string $default::bool) ...]
[?def var-required   scope=public impure [returns string] ($name::string) ...]
```

- `var-int` / `var-float` / `var-bool` return `default` **only** when the var is unset. When the var is set but unparseable, raise `CXER2504 E_ENV_PARSE_FAILED` (a malformed config value is an error, not a silent fall-back).
- `var-bool` accepts exactly `true` / `false` / `1` / `0` / `yes` / `no` / `on` / `off` (case-insensitive); the accepted set is pinned. Any other set value raises `CXER2504`.
- `var-required` raises `CXER2500 E_ENV_REQUIRED_MISSING` if unset.

### §3.2. Command-line arguments

```
[?def argv        scope=public impure [returns [sequence string]] () ...]
[?def parse-args  scope=public impure [returns element]           ($spec::element) ...]
[?def flag        scope=public pure   [returns any]               ($args::element $name::string) ...]
[?def positional  scope=public pure   [returns string]            ($args::element $name::string) ...]
[?def remaining   scope=public pure   [returns [sequence string]] ($args::element) ...]
[?def usage       scope=public pure   [returns string]            ($spec::element) ...]
```

- `argv()[0]` is the executable path.
- `parse-args(spec)` returns `[args [flags ...] [positional [sequence ...]] [unparsed [sequence ...]]]`.
- `usage(spec)` returns a human-readable usage string. Programs typically call this on `--help` or parse failure.

### §3.3. Process metadata

```
[?def pid             scope=public impure [returns int]    () ...]
[?def ppid            scope=public impure [returns int]    () ...]
[?def executable-path scope=public impure [returns string] () ...]
[?def cwd             scope=public impure [returns string] () ...]
[?def hostname        scope=public impure [returns string] () ...]
[?def username        scope=public impure [returns string] () ...]
[?def os-name         scope=public pure   [returns string] () ...]
[?def os-arch         scope=public pure   [returns string] () ...]
[?def cpu-count       scope=public impure [returns int]    () ...]
```

`os-name` / `os-arch` are pure (constant for the process lifetime). `os-name` ∈ `{"linux","darwin","windows","freebsd",…}`; `os-arch` ∈ `{"amd64","arm64","x86",…}`. `cpu-count` is the logical CPU count (includes hyperthreads).

### §3.4. Standard streams

```
[?def stdin   scope=public impure [returns element] () ...]
[?def stdout  scope=public impure [returns element] () ...]
[?def stderr  scope=public impure [returns element] () ...]
```

Return handle elements; pass them to [`cx-stdlib/io`](io.md) for actual I/O.

### §3.5. Process termination

```
[?def exit   scope=public impure [returns null] ($code::int) ...]
[?def abort  scope=public impure [returns null] () ...]
```

- `exit(code)` — flush pending I/O, run finalizers, terminate with `code`. If `[?async]` workers are active, waits up to a short grace period (default 5 s; configurable via `[?async shutdown-grace-ms=N]`).
- `abort()` — immediate termination without flushing. Use only for unrecoverable corruption.

## §4. Edge cases

- **Encoding.** Env vars are bytes on Unix (CX assumes UTF-8; invalid sequences surface as escape-prefixed strings) and UTF-16 on Windows (transcoded to UTF-8).
- **Args parsing.** `--flag=value` and `--flag value` both supported. `-vn 10` clusters as `-v -n 10`. `--` terminates flag parsing. Unknown flags raise `CXER2501 E_ENV_UNKNOWN_FLAG` unless `[argspec allow-unknown=true]`.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER2500` | `E_ENV_REQUIRED_MISSING` | `var-required` on unset var |
| `CXER2501` | `E_ENV_UNKNOWN_FLAG` | `parse-args` on unrecognised flag (unless `allow-unknown`) |
| `CXER2502` | `E_ENV_FLAG_TYPE_MISMATCH` | `parse-args` on un-parseable typed flag value |
| `CXER2503` | `E_ENV_POSITIONAL_MISSING` | `parse-args` on missing required positional |
| `CXER2504` | `E_ENV_PARSE_FAILED` | `var-int` / `var-float` / `var-bool` when set-but-unparseable |

## §6. Conformance fixtures

Under `conformance/stdlib/env.cxd`:

- `var("HOME")` returns the env value; `var("NONEXISTENT")` returns **absence** (the empty sequence `()`); a var set to `""` returns `""`.
- `has-var` distinguishes unset from set-to-empty.
- `var-int("PORT", 8080)` returns 8080 when unset; with `PORT=abc` raises `CXER2504` (no fall-back).
- `var-bool` accepts all of `true/false/1/0/yes/no/on/off` (case-insensitive); `BOOL=maybe` raises `CXER2504`.
- `var-required` on missing var raises `CXER2500`.
- `argv()[0]` matches `executable-path`. This identity holds under **native execution only** — when the program is the process image. Under an embedded or script-eval runner (e.g. evaluating a `.cx` source), `argv()[0]` is the script path rather than the `cx` executable, so the literal equality does not hold; a conformance harness asserts it only when launching the program as a native process.
- `parse-args` handles `--verbose`, `-v`, `--limit=10`, `-n 10`, declared positionals, extras into `remaining`, post-`--` positionals, unknown-flag → `CXER2501` unless `allow-unknown=true`.
- `os-name` / `os-arch` return non-empty strings consistent with the build target.

## §7. Capabilities

Effectful functions in `cx-stdlib/env` run under deny-by-default capabilities ([`spec/core/security.md`](../core/security.md) §2): the effect point checks the active set and raises `cx-err:CXER0271` (E_CAP_DENIED, naming the missing capability and resource) when the grant is absent. Pure functions (in-memory transforms, parsing, formatting) require no capability.

Environment-variable reads require `env`; `hostname` and `username` are host/identity disclosure in the same spirit and also require `env`. `cwd` and `executable-path` disclose filesystem layout and require `read`. The ambient process basics (standard streams, process identity, argument vector, CPU count, and process exit) require no capability: they are intrinsic to the running process and are never gated.

| Capability | Functions |
|---|---|
| `env` | `var`, `var-bool`, `var-float`, `var-int`, `var-or-default`, `var-required`, `vars`, `has-var`, `hostname`, `username` |
| `read` | `cwd`, `executable-path` |
| (none) | `stdin`, `stdout`, `stderr`, `pid`, `ppid`, `argv`, `cpu-count`, `exit`, `abort` |

## §8. Cross-references

- [`spec/std-lib/io.md`](io.md) — stdin/stdout/stderr handle consumers.
- [`spec/std-lib/path.md`](path.md) — `executable-path` and `cwd` are filesystem paths.
- [`spec/std-lib/process.md`](process.md) — subprocess environment via the `:env` map on `[$process:run]` / `[$process:spawn]`.
