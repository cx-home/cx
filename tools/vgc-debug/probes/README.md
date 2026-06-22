# probes — standalone OS/runtime assumption tests (macOS arm64)

Each probe isolates ONE assumption with a tiny self-contained C program (libc + mach,
no fork build). Build with `cc -O0 -o <name> <name>.c` and run directly. They are the
"kill the hypothesis cheaply before building a fork instrument" layer.

## `neon_syscall_probe.c` — GAP-1
Does `thread_get_state(ARM_THREAD_STATE64 + ARM_NEON_STATE64)` return the **full user
GP + NEON register file for a thread blocked in a syscall**, same as on-CPU? Forces a
sentinel into callee-saved `x19`/`d8`, blocks the thread in a raw `read()` svc, suspends
it from another thread, and reads both states. **Result: YES** — so vgc's suspended-root
scan does not miss in-syscall register roots (syscall-blocked threads are a sound
mach-suspend fallback). PASS = both sentinels present for the in-syscall target.

## `single_step_probe.c` — hardware single-step feasibility
Can a controller thread single-step a worker instruction-by-instruction
(`ARM_DEBUG_STATE64` MDSCR_EL1.SS bit), catch each step via a **task-level mach exception
port** (EXC_BREAKPOINT), and read the stepped thread's registers per step? Controller
arms SS via suspend → set debug state → resume; a handler thread services each trap and
re-arms. **Result: YES** (40 clean per-instruction stops, PC +4/step, cross-thread reg
reads return the controlled sentinel). This is the primitive the B-STEP localizer is
built on. Gotcha: arming SS runs libsystem first, so steps begin in library code until
the target is reached — arm while the worker spins in target code, or raise the step cap.

## `anon_walk_probe.c` — mach_vm_region scanner validity
Does a `mach_vm_region` walk (readable+writable, ≤64 MiB) + per-word scan **find a
pointer planted in a malloc'd / anon region**? Validates the holder-find scanner's
mechanism so that a "no holder found" result is a real absence, not a blind scan.
**Result: PASS** (planted holder found). Mirrors `vgc_hf_enumerate_anon` + the per-word
match used in the holder-find patch.

## Build & run all
```
for p in *.c; do cc -O0 -o "${p%.c}" "$p" && "./${p%.c}"; done
```
