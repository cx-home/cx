# `cx-stdlib/io` — file and stream I/O

```cx
[module-meta name=io tier=B status=current]
```

**Status:** Current

Normative reference for the `cx-stdlib/io` sub-package.

---

## §1. Scope

`cx-stdlib/io` provides file and stream I/O — reads, writes, line iteration, file system queries, directory operations, tempfile helpers. Bridges the streaming events API ([`spec/core/streaming.md`](../core/streaming.md)) and integrates with `cx-stdlib/path` (path syntax) and `cx-stdlib/env` (std-stream handles).

Tier-B runtime — necessarily impure. All operations may raise OS-level errors (permission denied, no space, etc.) mapped to error codes.

## §2. Conceptual model

### §2.1. File handles

A file handle is an opaque element wrapping the OS-level file descriptor:

```cx
[file
  path="/var/log/app.log"
  mode="r"
  fd=5
  encoding="utf-8"]
```

Created by `open` / `open-with-opts`; consumed by stream operations; closed via `close` or auto-closed when the handle goes out of scope.

### §2.2. Open modes

| Mode | Read | Write | Truncate | Create | Append |
|---|---|---|---|---|---|
| `"r"` | ✓ | | | | |
| `"r+"` | ✓ | ✓ | | | |
| `"w"` | | ✓ | ✓ | ✓ | |
| `"w+"` | ✓ | ✓ | ✓ | ✓ | |
| `"a"` | | ✓ | | ✓ | ✓ |
| `"a+"` | ✓ | ✓ | | ✓ | ✓ |
| `"x"` | | ✓ | | (must not exist) | |

### §2.3. Whole-file vs streaming

Whole-file operations (`read-file`, `write-file`) materialize entire content in memory. Streaming operations (`open` + `read-bytes` + `read-line` + lazy iterators) handle arbitrary-size inputs with bounded memory.

## §3. Public function surface

### §3.1. Whole-file convenience

```
[?def read-file        scope=public impure [returns string]            ($path::string) ...]
[?def read-file-bytes  scope=public impure [returns bytes]             ($path::string) ...]
[?def read-file-lines  scope=public impure [returns [sequence string]] ($path::string) ...]
[?def write-file       scope=public impure [returns null]              ($path::string $content::string) ...]
[?def write-file-bytes scope=public impure [returns null]              ($path::string $content::bytes) ...]
[?def write-file-lines scope=public impure [returns null]              ($path::string $lines::[sequence string]) ...]
[?def append-file      scope=public impure [returns null]              ($path::string $content::string) ...]
[?def append-file-bytes scope=public impure [returns null]             ($path::string $content::bytes) ...]
```

`read-file` assumes UTF-8 and raises `CXER3400 E_IO_ENCODING_INVALID` on invalid UTF-8 (use `read-file-bytes` for binary). `write-file` creates or truncates; atomic-via-tempfile-rename on POSIX, best-effort on Windows.

### §3.2. Streaming handles

```
[?def open           scope=public impure [returns element] ($path::string $mode::string) ...]
[?def open-with-opts scope=public impure [returns element] ($path::string $opts::map) ...]
[?def close          scope=public impure [returns null]    ($handle::element) ...]
```

Opts:

| Key | Default | Semantics |
|---|---|---|
| `mode` | `"r"` | Open mode (§2.2) |
| `encoding` | `"utf-8"` | For text-mode reads |
| `buffer-size` | `8192` | Read/write buffer bytes |
| `line-terminator` | `"auto"` | `"auto"` / `"lf"` / `"crlf"` |
| `atomic` | `false` | When `true`, raises `CXER3410 E_IO_ATOMIC_UNSUPPORTED` rather than performing a silent non-atomic overwrite on platforms / filesystems that cannot guarantee atomicity. Default `false` keeps the best-effort policy of §4.2. |

### §3.3. Stream operations

```
[?def read-bytes     scope=public impure [returns bytes]  ($handle::element $n::int) ...]
[?def read-line      scope=public impure [returns string] ($handle::element) ...]
[?def read-all       scope=public impure [returns string] ($handle::element) ...]
[?def read-all-bytes scope=public impure [returns bytes]  ($handle::element) ...]
[?def write-bytes    scope=public impure [returns null]   ($handle::element $b::bytes) ...]
[?def write-string   scope=public impure [returns null]   ($handle::element $s::string) ...]
[?def write-line     scope=public impure [returns null]   ($handle::element $s::string) ...]
[?def flush          scope=public impure [returns null]   ($handle::element) ...]
[?def seek           scope=public impure [returns null]   ($handle::element $offset::int $whence::atom) ...]
[?def tell           scope=public impure [returns int]    ($handle::element) ...]
[?def is-eof         scope=public impure [returns bool]   ($handle::element) ...]
```

`read-line` reads until line terminator; returns empty string at EOF (use `is-eof` to distinguish). `seek`'s `whence` is `:start` / `:current` / `:end`.

### §3.4. Lazy line iteration

```
[?def line-iter scope=public impure [returns [iterator string]] ($handle::element) ...]
```

Returns a lazy iterator over file lines. Memory-bounded regardless of file size. Single-use stream; closes its backing handle on exhaustion (walked to EOF). Does not close on early stop (short-circuiting `[where …]`, `[take …]` prefix, error before EOF) — wrap the handle in `[?with-open]` to guarantee close on every exit path.

```cx
[?with-open [$io:open "/var/log/app.log" "r"] $f
  [?for [in $line [$io:line-iter $f]]
    [where [$strings:contains $line "ERROR"]]
    [yield [$json:parse $line]]]]
```

`[?with-open]` ([`spec/core/code.md`](../core/code.md) §8.10.7) binds an opened resource and guarantees `close` on scope exit — normal return and error-unwind, LIFO across multiple bindings. Because `close` is idempotent, the iterate-to-EOF case is well-defined; the early-exit / error cases are exactly what `[?with-open]` covers that exhaustion does not.

### §3.5. File system queries

```
[?def exists         scope=public impure [returns bool]     ($path::string) ...]
[?def is-file        scope=public impure [returns bool]     ($path::string) ...]
[?def is-directory   scope=public impure [returns bool]     ($path::string) ...]
[?def is-symlink     scope=public impure [returns bool]     ($path::string) ...]
[?def stat           scope=public impure [returns element]  ($path::string) ...]
[?def size           scope=public impure [returns int]      ($path::string) ...]
[?def modified-time  scope=public impure [returns datetime] ($path::string) ...]
[?def created-time   scope=public impure [returns datetime] ($path::string) ...]
```

`stat` returns the full structured element:

```cx
[stat
  path="/var/log/app.log"
  size=12345
  is-file=true
  is-directory=false
  is-symlink=false
  modified="2026-05-26T14:30:00Z"
  created="2026-05-20T08:00:00Z"
  permissions="rw-r--r--"
  owner="alice"
  group="users"]
```

### §3.6. Directory operations

```
[?def list-dir    scope=public impure [returns [sequence string]] ($path::string) ...]
[?def make-dir    scope=public impure [returns null]   ($path::string) ...]
[?def make-dirs   scope=public impure [returns null]   ($path::string) ...]
[?def remove      scope=public impure [returns null]   ($path::string) ...]
[?def remove-dir  scope=public impure [returns null]   ($path::string) ...]
[?def remove-tree scope=public impure [returns null]   ($path::string) ...]
[?def rename      scope=public impure [returns null]   ($from::string $to::string) ...]
[?def copy        scope=public impure [returns null]   ($from::string $to::string) ...]
[?def copy-tree   scope=public impure [returns null]   ($from::string $to::string) ...]
[?def symlink     scope=public impure [returns null]   ($target::string $link::string) ...]
[?def readlink    scope=public impure [returns string] ($path::string) ...]
```

`make-dirs` creates intermediate directories. `remove-tree` is recursive and destructive: it does not follow symlinks (§4.3) and raises `CXER3411 E_IO_REFUSED_ROOT_DELETE` if the resolved path is a filesystem root (§4.6).

### §3.7. Globbing

```
[?def glob      scope=public impure [returns [sequence string]]  ($pattern::string) ...]
[?def glob-iter scope=public impure [returns [iterator string]]  ($pattern::string) ...]
[?def walk      scope=public impure [returns [iterator element]] ($root::string) ...]
```

- `glob` — eager; returns a `[sequence string]` of matching paths.
- `glob-iter` — lazy; yields paths on demand. Single-use stream; closes its backing directory handle on exhaustion; wrap in `[?with-open]` for early-exit close.
- `walk` — lazy; yields one `[dir-entry path=... is-file=... is-directory=... depth=...]` element per filesystem entry in recursive traversal order. `[take …]` / short-circuit `[where …]` stops the walk early. To materialize eagerly, force with `[?to-sequence [$io:walk $root]]`.

### §3.8. Tempfile

```
[?def temp-file       scope=public impure [returns element] ($prefix::string $suffix::string) ...]
[?def temp-dir        scope=public impure [returns string]  ($prefix::string) ...]
[?def system-temp-dir scope=public impure [returns string]  () ...]
```

`temp-file` creates a fresh open temp file handle (auto-deleted on close). `temp-dir` creates a fresh empty temp directory (caller cleans up via `remove-tree`). `system-temp-dir` returns the OS temp path.

### §3.9. File locking

```
[?def lock   scope=public impure [returns element] ($handle::element $kind::atom) ...]
[?def unlock scope=public impure [returns null]    ($handle::element) ...]
```

`kind` is `:shared` (multiple readers) or `:exclusive` (one writer). Advisory on POSIX (`flock`); mandatory on Windows. Best-effort across NFS / FAT / etc.

### §3.10. Continuous filesystem watch

```
[?def watch       scope=public impure [returns element] ($path::string) ...]
[?def watch-next  scope=public impure [returns element] ($handle::element $timeout::int -1) ...]
[?def watch-close scope=public impure [returns null]    ($handle::element) ...]
```

`watch` begins a **recursive** filesystem watch over the directory `path` and returns an opaque watch handle (`[watch handle=N path=…]`). It is a real OS notification primitive — `inotify` on Linux, **FSEvents** on macOS — never a polling loop. `path` must be an existing directory (else `CXER3401` / `CXER3404`).

`watch-next` **blocks** until the next change under the tree and returns a change element:

```
[change path="/abs/path" op=created]      [change path="/abs/path" op=modified]
[change path="/abs/path" op=deleted]       [change op=overflow]
```

- `op` is one of `created`, `modified`, `deleted`, or `overflow`. Paths are absolute.
- The optional `timeout` (milliseconds) bounds the wait: on expiry `watch-next` returns the **absence channel** (the empty sequence — §9.1.2 of `code.md`, caught by `[?else]`), NOT a `null`. This lets a watcher poll an external shutdown flag between waits without busy-spinning. Omitted / negative `timeout` blocks indefinitely.
- **`[change op=overflow]`** is surfaced when the OS event queue overflows (`inotify` `IN_Q_OVERFLOW`) or coalesces under load (FSEvents `kFSEventStreamEventFlagMustScanSubDirs`). It carries no path; its contract is *"events were dropped — rescan the tree"*. A consumer that ignores overflow can silently drift out of sync, so it must respond with a full re-scan.
- A closed watch (see `watch-close`) makes a parked or subsequent `watch-next` return absence.

`watch-close` tears down the OS watch and **unblocks** any `watch-next` currently parked on the handle in another task (self-pipe on Linux; run-loop stop on macOS). It is idempotent — closing an already-closed or unknown handle is a no-op and never raises `CXER3409`.

`op` classification is best-effort and existence-anchored: a path that no longer exists is reported `deleted`, a freshly-appearing path `created`, an in-place change `modified`. Exactly-once `op` precision is not guaranteed (an editor's save may surface as several events); the recipe pattern (`examples/cxstore/dir-sync/watch.cx`) is therefore **idempotent re-ingest per change** plus **full re-scan on overflow**, which is correct under any coalescing.

## §4. Edge cases and policy

### §4.1. Encoding

`read-file` raises on invalid UTF-8. For lossy decode or binary, use `read-file-bytes` and decode explicitly via `cx-stdlib/bytes`.

### §4.2. Atomic writes

Default `write-file` writes to a tempfile + atomic rename on POSIX; falls back to direct overwrite on Windows. With `atomic=true` (an `open-with-opts` opt, §3.2), the operation raises `CXER3410 E_IO_ATOMIC_UNSUPPORTED` if the platform / filesystem cannot guarantee atomicity, rather than silently performing a non-atomic overwrite. The default `atomic=false` never raises `CXER3410`.

### §4.3. Symlink semantics

By default, operations follow symlinks. `stat-no-follow`, `is-symlink`, `readlink` provide explicit non-following access. `remove-tree` does NOT follow symlinks.

### §4.4. Concurrent access

The module does not synchronize concurrent reads/writes to the same file. Use `lock` / `unlock` explicitly. Atomic single-write operations are safe under concurrent attempts; last writer wins.

### §4.5. Path resolution

All path args are resolved per `cx-stdlib/path/absolute` — relative paths resolve against the current working directory at call time.

### §4.6. Destructive-operation guards

`remove-tree` carries one unconditional footgun guard:

- **Root guard.** `remove-tree` resolves its path argument and raises `CXER3411 E_IO_REFUSED_ROOT_DELETE` before deleting anything if the resolved path is a filesystem root (`/` on POSIX; a drive / volume root such as `C:\` or a bare UNC share root on Windows). The same guard fires if the path resolves to the root ancestor of the current working directory's volume. The check is on the resolved path, so `remove-tree("/foo/..")` is caught.
- **Symlink no-follow** (§4.3) — symlinks planted inside the tree cannot redirect the recursive delete outside it.

These guards are not a security boundary; they prevent the single most common catastrophic mistake (an unintended `remove-tree("/")` from a mis-joined path).

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER3400` | `E_IO_ENCODING_INVALID` | `read-file` on invalid UTF-8 |
| `CXER3401` | `E_IO_NOT_FOUND` | Operation on non-existent path |
| `CXER3402` | `E_IO_PERMISSION_DENIED` | OS permission denial |
| `CXER3403` | `E_IO_ALREADY_EXISTS` | `open "x"` mode when file exists |
| `CXER3404` | `E_IO_NOT_A_DIRECTORY` | Directory operation on file |
| `CXER3405` | `E_IO_IS_A_DIRECTORY` | File operation on directory |
| `CXER3406` | `E_IO_BROKEN_PIPE` | Write to closed pipe |
| `CXER3407` | `E_IO_DISK_FULL` | OS reports out-of-space |
| `CXER3408` | `E_IO_NAME_TOO_LONG` | Path exceeds OS max |
| `CXER3409` | `E_IO_HANDLE_CLOSED` | Operation on already-closed handle (NOT raised by idempotent `close` of an already-closed handle) |
| `CXER3410` | `E_IO_ATOMIC_UNSUPPORTED` | `atomic=true` requested but the platform / filesystem cannot guarantee an atomic whole-file replace (§4.2) |
| `CXER3411` | `E_IO_REFUSED_ROOT_DELETE` | `remove-tree` resolved to a filesystem / drive root or the running volume's root ancestor (§4.6) |
| `CXER3412` | `E_IO_UNSUPPORTED` | `watch` on a platform with no filesystem-notification facility (§3.10) |

## §6. Conformance fixtures

Under `conformance/stdlib/io.cxd`:

- Whole-file round-trip: `write-file` then `read-file` returns identical content.
- Atomic write: crash mid-write does not leave partial file on POSIX.
- Atomic opt-in: `atomic=true` succeeds on POSIX; raises `CXER3410` on a platform that cannot guarantee atomicity; `atomic=false` never raises `CXER3410`.
- `read-line` reads lines correctly; distinguishes EOF from empty line.
- `line-iter` laziness: does not read all into memory; closes handle on exhaustion; `[?with-open]` closes on early exit / error (idempotent — no `CXER3409` on double close).
- Glob: patterns match expected file sets.
- Walk: lazy recursive walk visits all entries with correct `depth`; `[take …]` / short-circuit `[where …]` stops early; `[?to-sequence]` materializes eagerly.
- `stat` fields populated.
- `make-dirs("/tmp/a/b/c")` creates all intermediates.
- `remove-tree` recursive delete does not follow symlinks.
- `remove-tree` root guard: `remove-tree("/")`, `remove-tree(C:\)`, and a path resolving to a root (e.g. `"/foo/.."`) raise `CXER3411` before deleting anything.
- `temp-file` returns open handle; auto-deletes on close.
- Read-protected file raises `CXER3402` on open.
- Binary file via `read-file` raises `CXER3400`.
- `watch` / `watch-next` raise `cx-err:CXER0271` under the no-capability runner (`watch-close` propagates the nested `watch`'s denial). The granted, effectful behavior — a real change is reported by `watch-next`; a timeout returns absence; `watch-close` unblocks a parked `watch-next` — is proven behaviorally in `vcx/code/io_watch_test.v` (white-box, gated by `make test-vcx-code`) since it requires live filesystem effects and threads.

## §7. Capabilities

Effectful functions in `cx-stdlib/io` run under deny-by-default capabilities ([`spec/core/security.md`](../core/security.md) §2): the effect point checks the active set and raises `cx-err:CXER0271` (E_CAP_DENIED, naming the missing capability and resource) when the grant is absent. Pure functions (in-memory transforms, parsing, formatting) require no capability.

`open` and `open-with-opts` require the capability matching the requested access: read mode (`"r"`) needs `read`; write or append mode (`"w"`, `"a"`) needs `write`. `close` requires no capability — it only releases an already-granted handle. `watch` and `watch-next` are read-path observers and require `read`; `watch-close` — like `close` — requires no capability.

| Capability | Functions |
|---|---|
| `read` | `open` (read mode), `read-all`, `read-all-bytes`, `read-bytes`, `read-file`, `read-file-bytes`, `read-file-lines`, `read-line`, `line-iter`, `stat`, `exists`, `is-directory`, `is-file`, `is-symlink`, `is-eof`, `list-dir`, `glob`, `glob-iter`, `walk`, `readlink`, `size`, `created-time`, `modified-time`, `tell`, `seek`, `system-temp-dir`, `temp-dir`, `watch`, `watch-next` |
| `write` | `open` (write/append mode), `open-with-opts`, `write-bytes`, `write-file`, `write-file-bytes`, `write-file-lines`, `write-line`, `write-string`, `append-file`, `append-file-bytes`, `make-dir`, `make-dirs`, `remove`, `remove-dir`, `remove-tree`, `rename`, `copy`, `copy-tree`, `symlink`, `lock`, `unlock`, `flush`, `temp-file` |
| (none) | `close`, `watch-close` |

## §8. Cross-references

- [`spec/core/code.md`](../core/code.md) §8.10.7 — `[?with-open]` scoped-resource directive.
- [`spec/core/streaming.md`](../core/streaming.md) — streaming events API this module bridges.
- [`spec/std-lib/path.md`](path.md) — path syntax; all `path` args use that module's resolution.
- [`spec/std-lib/env.md`](env.md) — stdin / stdout / stderr handles.
- [`spec/std-lib/bytes.md`](bytes.md) — byte-level operations on file contents.
