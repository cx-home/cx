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

## `go_host_suspend_probe/` — cx #743: suspend-signal collision under a Go host
Can vgc's darwin **signal-suspend** machinery stop a registered thread when the host
process is a Go runtime that owns the process's signal handlers? A C dylib
(`vgcsim.c`) mimics `vgc_platform.h`'s signal path exactly (same sigaction flags,
handler self-match, capture+ack+park, re-signal loop) plus a signal-free mach
variant with a kernel-authoritative settle; the Go host registers a locked-thread
"straggler" running Go code and drives suspend/release cycles under preemption +
GC traffic. Build: `cc -O1 -dynamiclib vgcsim.c -o libvgcsim.dylib && go build -o probe .`
Modes: `PROBE_CTOR=urg|xcpu` (install the handler in a dyld constructor — the REAL
libcx order, before Go's runtime init), `PROBE_MODE=signal|mach`, `PROBE_SIG=urg|xcpu`,
`PROBE_N=<iters>`. **Results (Go 1.26.1, darwin arm64):**
- ctor-order SIGURG: **0% acked** — Go installs its handler over ours at init and
  `sigfwdgo` never forwards SI_USER signals; the ack never arrives (the 0x0acd hang).
- ctor-order SIGXCPU: **0% acked** — same; Go ≥1.26 takes EVERY notify-class signal,
  so no signal number fixes the class.
- install-after-Go-init SIGURG: our handler wins, but Go loses async preemption and
  Go's own STW wedges the whole process (sampled: every P spinning, world stuck).
- `PROBE_MODE=mach` (signal-free, `thread_suspend` + `thread_info` run_state settle):
  **200/200 acked**, zero failures, under full preemption + Go-GC storm.
One probe-shape lesson worth keeping: the suspend→resume window must live inside ONE
C call — a collector that returns to Go mid-suspension parks at a Go safepoint while
holding a frozen M and deadlocks against Go's own STW.

`go_host_suspend_probe/libcxforce/` — the same collision forced against REAL libcx:
T1 registers via one cxlib call then lives in Go land (permanent straggler); main
drives N allocation-heavy calls with `VGC_NEXT_GC_MB=1` so nearly every call
collects. Pre-#743-fix: hangs in the 0x0acd spew on the first collection, 100%.
Post-fix: `FORCE-OK n=200`. Run: `go build -o force . && VGC_NEXT_GC_MB=1 ./force`
(the env var must be in the exec environment — vgc_init reads it at dylib load).
