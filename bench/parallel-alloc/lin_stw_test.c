// lin_stw_test.c — Linux validation harness for the vgc backstop's two ported
// touchpoints in thirdparty/vgc/vgc_platform.h:
//   (1) signal-based STW suspend + stop-settle/ACK + ucontext register/SP capture
//   (2) ELF data-segment roots (dl_iterate_phdr)
//
// Mirrors the darwin prototypes bench/parallel-alloc/{suspend_world,stw_root_scan}.c
// but exercises the LINUX code paths. Build inside a Linux container:
//   cc -O2 -pthread -I<clone>/thirdparty/vgc lin_stw_test.c -o lin_stw_test && ./lin_stw_test
//
// PASS criteria:
//   - data_segments returns >=1 range, and a known global pointer lies inside one.
//   - every worker is suspended, ACKs (vgc_thread_regs returns >0 + sp!=0),
//     a STACK-resident marker is found in [sp,stack_base], and a REGISTER-pinned
//     marker is found in the captured register file. All workers resumed + joined.

#define _GNU_SOURCE // for REG_RSP/NGREG (x86_64 ucontext) — V's generated C also defines this
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <pthread.h>
#include <unistd.h>

#include "vgc_platform.h"

#define NW 6

// A heap pointer reachable only through a global — exercises vgc_data_segments.
static void* g_global_root;

typedef struct {
    uint32_t   tid;          // worker's gettid "port", published when ready
    uintptr_t  stack_base;   // recorded at registration (vgc_get_stack_bounds)
    uintptr_t  stack_marker; // unique value the worker keeps on its stack
    uintptr_t  reg_marker;   // unique value the worker pins in a callee-saved reg
    volatile int ready;
    volatile int stop;
} Worker;

static Worker ws[NW];

static void* worker_fn(void* arg) {
    Worker* w = (Worker*)arg;
    uint32_t port = vgc_thread_self_port(); // installs handler + unblocks signal
    uintptr_t lo = 0, hi = 0;
    if (vgc_get_stack_bounds(&lo, &hi)) {
        uintptr_t sp = (uintptr_t)vgc_get_sp();
        // pick the bound farthest from sp as the base (matches vgc registration)
        uintptr_t dlo = sp > lo ? sp - lo : lo - sp;
        uintptr_t dhi = hi > sp ? hi - sp : sp - hi;
        w->stack_base = dhi <= dlo ? hi : lo;
    } else {
        w->stack_base = (uintptr_t)vgc_get_sp() + 8u * 1024 * 1024;
    }
    volatile uintptr_t stack_local = w->stack_marker; // keep marker live on the stack
    register uintptr_t reg_local
#if defined(__aarch64__)
        asm("x19")
#elif defined(__x86_64__)
        asm("rbx")
#endif
        = w->reg_marker;                              // pin marker in a callee-saved reg
    __atomic_store_n(&w->tid, port, __ATOMIC_RELEASE);
    __atomic_store_n(&w->ready, 1, __ATOMIC_RELEASE);
    // Spin until released; touch both markers so the compiler cannot drop them.
    while (__atomic_load_n(&w->stop, __ATOMIC_ACQUIRE) == 0) {
        __asm__ __volatile__("" : : "r"(reg_local), "r"(stack_local) : "memory");
        vgc_cpu_pause();
    }
    return (void*)(stack_local ^ reg_local);
}

static int in_range(uintptr_t v, uintptr_t a, uintptr_t b) {
    uintptr_t lo = a < b ? a : b, hi = a < b ? b : a;
    return v >= lo && v < hi;
}

int main(void) {
    int fails = 0;

    // ---- (2) ELF data-segment roots ----
    g_global_root = malloc(64);
    uintptr_t los[8], his[8];
    int nseg = vgc_data_segments(los, his, 8);
    printf("data_segments: %d range(s)\n", nseg);
    int found_global = 0;
    for (int i = 0; i < nseg; i++) {
        printf("  seg[%d] [0x%lx, 0x%lx)\n", i, (unsigned long)los[i], (unsigned long)his[i]);
        if (in_range((uintptr_t)&g_global_root, los[i], his[i])) found_global = 1;
    }
    if (nseg < 1)   { printf("FAIL: no data segments\n"); fails++; }
    if (!found_global) { printf("FAIL: &g_global_root not in any scanned segment\n"); fails++; }
    else printf("OK: global root address is inside a scanned data segment\n");

    // ---- (1) signal STW + ack + register/stack root capture ----
    (void)vgc_thread_self_port(); // main registers too (installs handler)
    pthread_t th[NW];
    for (int i = 0; i < NW; i++) {
        ws[i].stack_marker = 0x5A5A0000ull | (uintptr_t)(0x1000 + i);
        ws[i].reg_marker   = 0xB00B0000ull | (uintptr_t)(0x2000 + i);
        ws[i].ready = 0; ws[i].stop = 0; ws[i].tid = 0;
        pthread_create(&th[i], 0, worker_fn, &ws[i]);
    }
    for (int i = 0; i < NW; i++)
        while (__atomic_load_n(&ws[i].ready, __ATOMIC_ACQUIRE) == 0) vgc_cpu_pause();

    // "collector": suspend ALL, then scan each, then resume ALL (the real driver order).
    for (int i = 0; i < NW; i++) vgc_suspend_thread(ws[i].tid);

    for (int i = 0; i < NW; i++) {
        uintptr_t sp = 0, regs[32];
        int n = vgc_thread_regs(ws[i].tid, &sp, regs, 32);
        if (n <= 0 || sp == 0) { printf("FAIL: worker %d not captured (n=%d sp=0x%lx)\n", i, n, (unsigned long)sp); fails++; continue; }
        int reg_hit = 0;
        for (int k = 0; k < n; k++) if (regs[k] == ws[i].reg_marker) reg_hit = 1;
        int stack_hit = 0;
        for (uintptr_t p = (sp < ws[i].stack_base ? sp : ws[i].stack_base);
             p < (sp < ws[i].stack_base ? ws[i].stack_base : sp); p += sizeof(uintptr_t)) {
            if (*(volatile uintptr_t*)p == ws[i].stack_marker) { stack_hit = 1; break; }
        }
        printf("worker %d: tid=%u n=%d sp=0x%lx reg_hit=%d stack_hit=%d\n",
               i, ws[i].tid, n, (unsigned long)sp, reg_hit, stack_hit);
        if (!reg_hit)   { printf("FAIL: worker %d register marker not captured\n", i); fails++; }
        if (!stack_hit) { printf("FAIL: worker %d stack marker not in [sp,base]\n", i); fails++; }
    }

    for (int i = 0; i < NW; i++) vgc_resume_thread(ws[i].tid);
    for (int i = 0; i < NW; i++) { ws[i].stop = 1; }
    for (int i = 0; i < NW; i++) pthread_join(th[i], 0);

    printf(fails ? "\n=== %d FAILURE(S) ===\n" : "\n=== ALL PASS ===\n", fails);
    return fails ? 1 : 0;
}
