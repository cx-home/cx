// stw_root_scan.c — full stop-the-world conservative ROOT SCAN (spec §5.3).
// Extends suspend_world.c: after suspending the world, recover ALL roots —
// including pointers that live ONLY in a register (the case vgc's stack-only
// scan missed -> bug #3) and pointers that live only on the stack.
//
// Method (darwin/mach): suspend each thread; thread_get_state gives the FULL
// register file AND the SP. Scan the registers for heap pointers, then scan
// [SP, stack_base) for heap pointers. A precise collector would instead use
// per-type maps for the heap interior; roots are necessarily conservative for a
// C-compiled runtime, exactly as Boehm does.
//
//   cc -O2 -o stw_root_scan stw_root_scan.c && ./stw_root_scan
//
// PASS = the register-resident planted pointer is found among a thread's
// registers, AND the stack-resident planted pointer is found on its stack.

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <pthread.h>
#include <unistd.h>
#include <time.h>

#if defined(__APPLE__) && (defined(__arm64__) || defined(__aarch64__))
#include <mach/mach.h>
#include <mach/thread_act.h>

#define HEAP_SIZE (64 * 1024)
static uint8_t* HEAP;
static uintptr_t heap_lo, heap_hi;

#define REG_OFF 0x100  // planted pointer offset for the register worker
#define STK_OFF 0x200  // planted pointer offset for the stack worker

static mach_port_t tports[2];
static uintptr_t   stackbase[2];
static volatile uint64_t counters[2];
static volatile int registered[2];
static volatile int stop_flag = 0;

static void msleep(long ms){ struct timespec t={ms/1000,(ms%1000)*1000000L}; nanosleep(&t,NULL); }

static int in_heap(uintptr_t v){ return v >= heap_lo && v < heap_hi; }

// Worker 0: holds a heap pointer ONLY in callee-saved register x19.
static void* reg_worker(void* arg) {
    (void)arg;
    tports[0] = pthread_mach_thread_np(pthread_self());
    stackbase[0] = (uintptr_t)pthread_get_stackaddr_np(pthread_self());
    register uintptr_t p asm("x19");
    p = (uintptr_t)(HEAP + REG_OFF);
    registered[0] = 1;
    while (!stop_flag) {
        __asm__ volatile("" : "+r"(p)); // keep p live in x19 (not spilled)
        counters[0]++;
    }
    if (p == 0) printf("x"); // keep p observable
    return NULL;
}

// Worker 1: holds a heap pointer ONLY on the stack (address escapes -> spilled).
static void* stk_worker(void* arg) {
    (void)arg;
    tports[1] = pthread_mach_thread_np(pthread_self());
    stackbase[1] = (uintptr_t)pthread_get_stackaddr_np(pthread_self());
    volatile uintptr_t slot;
    slot = (uintptr_t)(HEAP + STK_OFF);
    uintptr_t* paddr = (uintptr_t*)&slot;
    __asm__ volatile("" :: "r"(paddr) : "memory"); // force &slot onto the stack
    registered[1] = 1;
    while (!stop_flag) {
        counters[1]++;
        __asm__ volatile("" :: "r"(paddr) : "memory");
    }
    return NULL;
}

// Scan a suspended thread's registers; return 1 if any holds a heap pointer.
static int scan_registers(mach_port_t t, uintptr_t* found) {
    arm_thread_state64_t st;
    mach_msg_type_number_t n = ARM_THREAD_STATE64_COUNT;
    if (thread_get_state(t, ARM_THREAD_STATE64, (thread_state_t)&st, &n) != KERN_SUCCESS)
        return 0;
    for (int i = 0; i < 29; i++) { // x0..x28
        uintptr_t v = (uintptr_t)st.__x[i];
        if (in_heap(v)) { *found = v; return 1; }
    }
    uintptr_t fp = (uintptr_t)arm_thread_state64_get_fp(st);
    uintptr_t lr = (uintptr_t)arm_thread_state64_get_lr(st);
    if (in_heap(fp)) { *found = fp; return 1; }
    if (in_heap(lr)) { *found = lr; return 1; }
    return 0;
}

// Scan [sp, stack_base) for a heap pointer; return 1 if found.
static int scan_stack(mach_port_t t, uintptr_t base, uintptr_t* found) {
    arm_thread_state64_t st;
    mach_msg_type_number_t n = ARM_THREAD_STATE64_COUNT;
    if (thread_get_state(t, ARM_THREAD_STATE64, (thread_state_t)&st, &n) != KERN_SUCCESS)
        return 0;
    uintptr_t sp = (uintptr_t)arm_thread_state64_get_sp(st);
    for (uintptr_t a = sp; a + sizeof(uintptr_t) <= base; a += sizeof(uintptr_t)) {
        uintptr_t v = *(uintptr_t*)a;
        if (in_heap(v)) { *found = v; return 1; }
    }
    return 0;
}

int main(void) {
    HEAP = (uint8_t*)malloc(HEAP_SIZE);
    heap_lo = (uintptr_t)HEAP;
    heap_hi = heap_lo + HEAP_SIZE;

    pthread_t th[2];
    pthread_create(&th[0], NULL, reg_worker, NULL);
    pthread_create(&th[1], NULL, stk_worker, NULL);
    while (!(registered[0] && registered[1])) msleep(5);
    msleep(50);

    // === SUSPEND THE WORLD ===
    thread_suspend(tports[0]);
    thread_suspend(tports[1]);

    uintptr_t rfound = 0, sfound = 0;
    int reg_ok = scan_registers(tports[0], &rfound);
    int stk_ok = scan_stack(tports[1], stackbase[1], &sfound);

    thread_resume(tports[0]);
    thread_resume(tports[1]);
    stop_flag = 1;
    pthread_join(th[0], NULL);
    pthread_join(th[1], NULL);

    uintptr_t want_reg = (uintptr_t)(HEAP + REG_OFF);
    uintptr_t want_stk = (uintptr_t)(HEAP + STK_OFF);
    printf("  register-root: %s (found 0x%llx, planted 0x%llx in x19)\n",
           (reg_ok && rfound == want_reg) ? "FOUND" : "MISSED",
           (unsigned long long)rfound, (unsigned long long)want_reg);
    printf("  stack-root:    %s (found 0x%llx, planted 0x%llx on stack)\n",
           (stk_ok && sfound == want_stk) ? "FOUND" : "MISSED",
           (unsigned long long)sfound, (unsigned long long)want_stk);

    if (reg_ok && rfound == want_reg && stk_ok && sfound == want_stk) {
        printf("stw_root_scan PASS: register AND stack roots both captured under "
               "STW. Register roots come free from thread_get_state -- the exact "
               "root vgc's stack-only safepoint dropped (bug #3).\n");
        return 0;
    }
    printf("stw_root_scan FAIL\n");
    return 1;
}
#else
int main(void){ printf("stw_root_scan: darwin/arm64-only prototype.\n"); return 0; }
#endif
