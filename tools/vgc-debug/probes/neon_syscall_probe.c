// GAP-1 probe: does macOS arm64 thread_get_state() return the user GP + NEON
// register file for a thread BLOCKED IN A SYSCALL, the same as for an on-CPU
// thread? If a live pointer parked in a callee-saved reg (x19 / v8) across a
// blocking read() is captured as ZERO/stale, then vgc's suspended-root scan
// (which uses exactly thread_get_state ARM_THREAD_STATE64 + ARM_NEON_STATE64)
// would miss it -> swept while live -> #63 GAP-1 lives.
//
// No vgc/fork edits. Pure libc + mach.
#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <pthread.h>
#include <mach/mach.h>
#include <mach/thread_act.h>

#define SENT_GP   0xDEADBEEF19283746ULL  // goes in callee-saved x19
#define SENT_NEON 0xCAFEF00DBEEF1234ULL  // goes in callee-saved d8 (v8 low lane)

static volatile int target_ready  = 0;
static volatile int control_ready = 0;
static int blk_fd = -1; // read end of a pipe with no data -> read() blocks

// Target: set x19 + d8 to sentinels, then block in a RAW read() svc so the
// thread is frozen in-kernel with those regs holding the sentinels.
static void* target_fn(void* arg) {
    (void)arg;
    char buf[1];
    asm volatile(
        "fmov d8, %[neon]\n"            // callee-saved NEON <- sentinel
        "mov  x19, %[gp]\n"             // callee-saved GP  <- sentinel
        "mov  w9, #1\n"
        "str  w9, [%[rdy_p]]\n"         // publish target_ready=1 (late)
        "mov  x16, %[nrv]\n"            // BSD read syscall number
        "mov  x0, %[fdv]\n"
        "mov  x1, %[bufv]\n"
        "mov  x2, #1\n"
        "svc  #0x80\n"                  // read(fd, buf, 1) -> BLOCKS in-kernel
        :
        : [neon]"r"(SENT_NEON), [gp]"r"(SENT_GP),
          [nrv]"r"((uint64_t)0x2000003ULL), // BSD read = 3
          [fdv]"r"((uint64_t)blk_fd), [bufv]"r"((uint64_t)buf),
          [rdy_p]"r"(&target_ready)
        : "x0", "x1", "x2", "x9", "x16", "x19", "d8", "memory", "cc"
    );
    return 0;
}

// Control: set x19 + d8 to sentinels, then spin tightly (no calls) so the regs
// stay put while ON-CPU. We KNOW on-CPU NEON capture works (shipped fix), so a
// PASS here proves the probe's reader is correct; a FAIL would invalidate the
// whole probe.
static void* control_fn(void* arg) {
    (void)arg;
    asm volatile(
        "fmov d8, %[neon]\n"
        "mov  x19, %[gp]\n"
        "mov  w0, #1\n"
        "str  w0, [%[rdy_p]]\n"
        "1: b 1b\n"                     // spin forever, ON-CPU
        :
        : [neon]"r"(SENT_NEON), [gp]"r"(SENT_GP), [rdy_p]"r"(&control_ready)
        : "x19", "d8", "x0", "memory", "cc"
    );
    return 0;
}

static void inspect(const char* label, thread_act_t t) {
    // Settle: thread_suspend is async; spin until SP+PC stable (same discipline
    // as vgc_suspend_thread).
    thread_suspend(t);
    uintptr_t psp = 0, ppc = 0;
    for (int i = 0; i < 200000; i++) {
        arm_thread_state64_t st;
        mach_msg_type_number_t n = ARM_THREAD_STATE64_COUNT;
        if (thread_get_state(t, ARM_THREAD_STATE64, (thread_state_t)&st, &n) != KERN_SUCCESS) break;
        uintptr_t sp = (uintptr_t)arm_thread_state64_get_sp(st);
        uintptr_t pc = (uintptr_t)arm_thread_state64_get_pc(st);
        if (i > 0 && sp == psp && pc == ppc) break;
        psp = sp; ppc = pc;
    }

    // GP read
    arm_thread_state64_t gs;
    mach_msg_type_number_t gn = ARM_THREAD_STATE64_COUNT;
    kern_return_t gkr = thread_get_state(t, ARM_THREAD_STATE64, (thread_state_t)&gs, &gn);
    int gp_found = 0;
    if (gkr == KERN_SUCCESS) {
        for (int i = 0; i < 29; i++) if ((uint64_t)gs.__x[i] == SENT_GP) gp_found = 1;
    }

    // NEON read
    arm_neon_state64_t ns;
    mach_msg_type_number_t nn = ARM_NEON_STATE64_COUNT;
    kern_return_t nkr = thread_get_state(t, ARM_NEON_STATE64, (thread_state_t)&ns, &nn);
    int neon_found = 0;
    uint64_t v8lane = 0;
    if (nkr == KERN_SUCCESS) {
        const uint64_t* q = (const uint64_t*)&ns.__v[0]; // 32 x 128b = 64 lanes
        v8lane = q[16]; // v8 low lane = index 16 (each v is 2 lanes)
        for (int i = 0; i < 64; i++) if (q[i] == SENT_NEON) neon_found = 1;
    }

    printf("[%s]\n", label);
    printf("  ARM_THREAD_STATE64 kr=%d  GP x19-sentinel found: %s\n",
           gkr, gp_found ? "YES" : "NO");
    printf("  ARM_NEON_STATE64   kr=%d (count=%u)  v8 low lane=0x%016llx  NEON-sentinel found: %s\n",
           nkr, nn, (unsigned long long)v8lane, neon_found ? "YES" : "NO");
    fflush(stdout);
    thread_resume(t);
}

int main(void) {
    int fds[2];
    if (pipe(fds) != 0) { perror("pipe"); return 1; }
    blk_fd = fds[0]; // read end; no one writes -> read() blocks

    pthread_t tt, ct;
    pthread_create(&tt, 0, target_fn, 0);
    pthread_create(&ct, 0, control_fn, 0);

    while (!target_ready)  usleep(1000);
    while (!control_ready) usleep(1000);
    usleep(50000); // ensure target is genuinely parked in-kernel

    printf("=== GAP-1 probe: thread_get_state register capture ===\n");
    printf("SENT_GP=0x%016llx  SENT_NEON=0x%016llx\n\n",
           (unsigned long long)SENT_GP, (unsigned long long)SENT_NEON);

    inspect("CONTROL on-CPU (spinning) - probe self-check", pthread_mach_thread_np(ct));
    printf("\n");
    inspect("TARGET blocked in read() syscall - GAP-1 case", pthread_mach_thread_np(tt));

    fflush(stdout);
    _exit(0); // don't bother joining the infinite-loop control
}
