# stw_blocking_syscall_probe — vgc STW vs a thread parked in a syscall (#973)

Isolates ONE assumption of vgc's coop-safepoint STW: *every thread reaches a
safepoint promptly*. A thread blocked in a syscall violates it by construction.

**Measured 2026-08-25, darwin arm64, fork `46f1be51d5`:**

| `-gc` | threads | result |
|---|---|---|
| `e` | 1 | completed, 103 ms |
| `e` | 4 | **HUNG** |
| `e` | 8 | **HUNG** |
| `boehm` | 8 | completed, 264 ms |

The cycle, from `sample` on the hung pid:

```
main       _pthread_join → __ulock_wait
worker A   vgc_realloc → vgc_maybe_gc → vgc_gc_start → vgc_mark_roots → __ulock_wait2
worker B..N  os__fd_read → read
```

Worker A is collecting and waits for the others to reach a safepoint; the others
are parked in `read()` waiting for a child's output, which is only drained after
the collection finishes. Nothing breaks it.

## Running it

```sh
devbox run -- bash run.sh
```

`run.sh` bounds every case (25 s) and `sample`s the pid before killing, so a
deadlock reports as a deadlock. **Bound your probes.** The finding was first hit
by an unbounded run that sat for an hour producing no output and no diagnostic;
the bounded probe produced the entire diagnosis in one pass.

Manually:

```sh
v -gc e -o repro main.v && ./repro 8 40     # hangs
v -gc boehm -o repro main.v && ./repro 8 40 # completes
```

Args: `<threads> <iterations-per-thread>`.

## Why it is kept

It is the smallest known reproduction of #973, it is deterministic, and it is
the acceptance test for any fix: a safepoint handoff around blocking calls must
make the `-gc e` rows complete. Distinct from #834 (linux, signal-owning host,
shared library) and #743 (dylib inside a Go host) — this needs no host runtime
and no dylib, just two threads and a blocking read.
