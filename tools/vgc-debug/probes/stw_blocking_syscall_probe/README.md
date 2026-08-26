# stw_blocking_syscall_probe — vgc STW vs fork/loader locks (#973)

Filed as "a thread blocked in a syscall never reaches a safepoint" — the
blocked readers turned out to be BYSTANDERS. The committed samples showed two
distinct deadlock modes, both from mach-suspending stragglers at ARBITRARY
PCs while other code holds process-wide system locks:

- **(a) collector-side** (sample-e-8): `vgc_mark_roots` re-derived the
  data-segment root ranges inside the STW window via the platform loader
  (`_dyld_get_image_header`/`dladdr`), which takes dyld's loaders lock — while
  a straggler sat frozen mid-`fork` inside `libSystem_atfork_parent`, holding
  that lock forever. The collector suspended the lock holder, then asked dyld
  for the lock.
- **(b) child-side** (sample-e-4: NO collector running, readers parked for
  good): a child forked while any thread sat mach-suspended holding a
  libSystem lock inherits that lock permanently locked (its holder does not
  exist in the child), hangs before `exec`, never writes, never exits — and
  every parent reading the dead child's pipe blocks in `read()` forever. That
  is the "blocking syscall" surface symptom.

## The fix (fork `a2898599f3`, cx-private#973)

- **F1**: the segment ranges are cached once at `vgc_init` (single-threaded,
  load-constructor context); mark reads the cache. The collector performs no
  loader call under STW on any platform (the linux `dl_iterate_phdr` path had
  the same hazard, rationalized in a comment).
- **F2**: `pthread_atfork` handlers bracket every fork with
  `vgc_heap.cache_lock` — held by the collector across its ENTIRE cycle — so
  no STW can overlap any fork window and no thread is ever frozen mid-atfork.
  The child handler re-initializes every vgc lock word.
- `-d vgc_no_atfork` disables F2 only, keeping mode (b) demonstrable.

## Measured (darwin arm64, fork `a2898599f3`, 2026-08-25)

| build | jobs=1 | jobs=4 | jobs=8 | boehm jobs=8 |
|---|---|---|---|---|
| pre-fix (`46f1be51d5`) | 103 ms | **HUNG** | **HUNG** | 264 ms |
| F1 only (`-d vgc_no_atfork`) | — | **HUNG 30/30** | **HUNG** (mode (b) only: no collector/dyld frame in any sample) | — |
| F1+F2 | 87 ms | ok (0/15 hangs) | ok (0/15 hangs) | 301 ms |

The F1-only column is the attribution proof: with the loader-lock fix alone,
mode (a) vanishes from every sample and mode (b) still deadlocks — both fixes
carry weight.

## Running it

```sh
devbox run -- bash run.sh
```

`run.sh` bounds every case (25 s) and `sample`s the pid before killing, so a
deadlock reports as a deadlock. **Bound your probes.** The finding was first
hit by an unbounded run that sat for an hour producing no output and no
diagnostic; the bounded probe produced the entire diagnosis in one pass.

Manually:

```sh
v -gc e -o repro main.v && ./repro 8 40     # must complete
v -gc boehm -o repro main.v && ./repro 8 40 # completes
```

Args: `<threads> <iterations-per-thread>`.

## Why it is kept

Smallest known reproduction of #973, deterministic pre-fix, and the
acceptance test for the fix: all `-gc e` rows must complete. Distinct from
#834 (linux, signal-owning host, shared library) and #743 (dylib inside a Go
host) — this needs no host runtime and no dylib, just two threads, a fork,
and a blocking read.
