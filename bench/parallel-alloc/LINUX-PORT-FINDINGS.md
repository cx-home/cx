# Linux backstop port (A6) — findings

Post-gate forward-phase step (a): port the vgc backstop's two darwin-only OS
touchpoints to Linux. The allocator and Perceus front line are already
cross-platform; only these two needed porting. Code lives in the upstream-master
clone `/Users/ep/git-repos/cx/vlang-v-latest`, uncommitted, captured as
`bench/parallel-alloc/vgc-collector-linux.patch` (full working-tree diff =
collector correctness fixes + this Linux port; supersedes
`vgc-span-reuse-fix.patch`). All edits are confined to the **non-`__APPLE__`
branches** of `thirdparty/vgc/vgc_platform.h`, so the darwin path is byte-identical.

## What was ported (both in vgc_platform.h)

### 1. STW thread suspension → signal-based, with stop-settle/ACK
Darwin reads a suspended thread's registers synchronously from the collector
(`mach thread_get_state`). Linux cannot — so the target captures its OWN context:

- The collector sends a private RT signal (`SIGRTMIN+6`, Boehm's `GC_SIG_SUSPEND`
  default — avoids clobbering app `SIGUSR1/2`) to each target via
  `tgkill(getpid(), tid, sig)`.
- The handler (`vgc_suspend_handler`, async-signal-safe) finds its per-tid slot,
  copies the interrupted GP registers + SP out of the signal `ucontext`, publishes
  `acked=1`, then parks (spins on `release` with `sched_yield`) inside the handler
  — keeping every non-self mutator frozen for the whole scan window.
- **The ACK is the stop-settle** (the Linux analog of this session's mach
  async-suspend fix): `tgkill` returns before the handler runs, so
  `vgc_suspend_thread` spins on `acked` before the captured SP/regs are trusted.
  Once acked, the thread is provably stopped at a known point and its frame is
  frozen — even tighter than darwin's re-read (no advancing-frame window).
- `vgc_thread_regs` reads the already-captured SP/regs from the slot;
  `vgc_resume_thread` sets `release`, waits for the handler to clear `acked`
  (handshake before slot reuse), frees the slot.
- `vgc_thread_self_port` (called per registration) installs the handler once
  (`pthread_once`), unblocks the signal in the calling thread, and returns the
  kernel `tid` (gettid) — which the `mach_port u32` cache field now carries on
  Linux as both signal target and slot key.

Per-tid slot table (`vgc_lin_slots[128]`, ≥ `caches[64]`) because the driver
suspends ALL non-self mutators before scanning — they are all parked at once.
Slot claiming is single-threaded (one collector under the STW `gc_phase` guard);
the handler reads concurrently, guarded by `__atomic`. Backstops (200k spins) on
both the ack-wait and the resume handshake degrade safely to "skip this thread"
(matching darwin's `thread_get_state` failure path) if a signal is lost / thread dies.

ucontext fields: `__aarch64__` → `uc_mcontext.regs[0..30]` + `.sp`; `__x86_64__`
→ `uc_mcontext.gregs[0..NGREG)` + `gregs[REG_RSP]` (needs `_GNU_SOURCE`, which V's
generated C defines).

Lock-ordering note (already handled by the V driver, inherited unchanged): the
collector acquires ALL allocator locks BEFORE the suspend loop, so no mutator is
ever parked holding an allocator lock, and the async-signal-safe handler never
touches those locks — no deadlock, no signal-in-critical-section hazard.

### 2. Data-segment roots → ELF via dl_iterate_phdr
Darwin uses mach-o `getsegmentdata` over the main image's `__DATA*`. Linux uses
`dl_iterate_phdr`, taking the MAIN program object (first callback) and emitting
each writable (`PF_W`) `PT_LOAD` segment as a root range, using `p_memsz` (not
`p_filesz`) so the range spans `.bss`. Matches darwin's "main image only" scope:
V `__global`s, vgc's own globals, and cx's statically-linked deps (mbedtls) all
land in the main binary; shared-lib `.data` is not scanned (V puts no roots there).

## Validation (native, this session, Docker arm64 + amd64 Linux containers)

Standalone harness `bench/parallel-alloc/lin_stw_test.c` `#include`s the ported
header and drives the actual functions (mirrors the darwin
`suspend_world.c`/`stw_root_scan.c` prototypes):

| Arch | data_segments | suspend+ack | reg capture | stack root | result |
|---|---|---|---|---|---|
| linux/arm64 (native) | 1 range, global ∈ range | 6/6 acked, n=31 regs | reg marker found | stack marker found | **ALL PASS** |
| linux/amd64 (emulated) | 1 range, global ∈ range | 6/6 acked, n=23 gregs | reg marker found | stack marker found | **ALL PASS** |

Each worker pins a unique marker in a callee-saved register (`x19`/`rbx`) and
another on its stack; the "collector" suspends all, and for every worker finds
the register marker in the captured register file AND the stack marker in
`[sp, stack_base]`, then resumes — proving register-resident roots (the ones a
stack-only scan misses) are captured via `ucontext` exactly as darwin gets them
from `thread_get_state`. Build: `cc -O2 -pthread -I<clone>/thirdparty/vgc
lin_stw_test.c`.

## Caveat — what this does NOT yet prove (the integrated Linux gate)
The harness validates the two touchpoints in ISOLATION. It does NOT yet exercise
them inside the full vgc collector under `g_churn -gc vgc` on Linux (build the V
compiler for Linux → build g_churn → run the §7 churn battery). That integrated
gate is the real end-to-end proof and is the natural Linux counterpart of the
darwin "190/190 churn-clean" result; it belongs with the forward-port / full cx
gate (INTEGRATION-SCOPE B14). Risks it would flush out: V-generated-C `_GNU_SOURCE`
presence (expected yes), any RT-signal interaction with V's runtime, and the
tid-as-port semantics under real thread churn.
