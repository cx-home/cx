// suspend_world.c — prototype of OS-level stop-the-world for a precise GC
// backstop (spec §5.3). This is the glue BOTH candidate backstops (MMTk binding,
// or a minimal mark-region collector) need, and the piece vgc's cooperative
// alloc-path safepoint could NOT do: stop threads that are blocked in a syscall
// or spinning in a tight NON-allocating loop, then read each thread's SP for a
// conservative stack scan, then resume.
//
// darwin: mach thread_suspend/thread_resume + thread_get_state (no cooperation
//   from the target needed — the kernel stops it).
// linux/bsd (sketch, not built here): install a handler for a dedicated signal,
//   pthread_kill(tid, sig) each thread; the handler captures its own SP and
//   parks until released. Boehm uses exactly these two mechanisms.
//
//   cc -O2 -o suspend_world suspend_world.c && ./suspend_world
//
// PASS = every worker (spinning AND syscall-blocked) is provably frozen while
// suspended (its progress counter does not advance) and we read a plausible SP
// for each; all resume and make progress afterward.

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <pthread.h>
#include <unistd.h>
#include <time.h>

#if defined(__APPLE__)
#include <mach/mach.h>
#include <mach/thread_act.h>

#define NW 6
static mach_port_t tports[NW];
static volatile uint64_t counters[NW];
static volatile int registered[NW];
static volatile int stop_flag = 0;

static void msleep(long ms) {
    struct timespec ts = { ms / 1000, (ms % 1000) * 1000000L };
    nanosleep(&ts, NULL);
}

// Workers 0..3: tight NON-allocating loop (no safepoint poll — vgc could never
// stop these). Worker 4: blocked in a syscall (nanosleep). Worker 5: also spin.
static void* spin_worker(void* arg) {
    long id = (long)arg;
    tports[id] = pthread_mach_thread_np(pthread_self());
    registered[id] = 1;
    while (!stop_flag) {
        counters[id]++;
    }
    return NULL;
}

static void* blocked_worker(void* arg) {
    long id = (long)arg;
    tports[id] = pthread_mach_thread_np(pthread_self());
    registered[id] = 1;
    while (!stop_flag) {
        msleep(40); // blocked in a kernel syscall across the suspend window
        counters[id]++;
    }
    return NULL;
}

static uint64_t read_sp(mach_port_t t) {
#if defined(__arm64__) || defined(__aarch64__)
    arm_thread_state64_t st;
    mach_msg_type_number_t n = ARM_THREAD_STATE64_COUNT;
    if (thread_get_state(t, ARM_THREAD_STATE64, (thread_state_t)&st, &n) != KERN_SUCCESS)
        return 0;
    return (uint64_t)arm_thread_state64_get_sp(st);
#elif defined(__x86_64__)
    x86_thread_state64_t st;
    mach_msg_type_number_t n = x86_THREAD_STATE64_COUNT;
    if (thread_get_state(t, x86_THREAD_STATE64, (thread_state_t)&st, &n) != KERN_SUCCESS)
        return 0;
    return (uint64_t)st.__rsp;
#else
    (void)t; return 0;
#endif
}

int main(void) {
    pthread_t th[NW];
    for (long i = 0; i < NW; i++) {
        if (i == 4) pthread_create(&th[i], NULL, blocked_worker, (void*)i);
        else        pthread_create(&th[i], NULL, spin_worker, (void*)i);
    }
    // wait until all registered their mach port
    for (;;) {
        int all = 1;
        for (int i = 0; i < NW; i++) if (!registered[i]) all = 0;
        if (all) break;
        msleep(5);
    }
    msleep(50); // let them run

    // === SUSPEND THE WORLD ===
    for (int i = 0; i < NW; i++) thread_suspend(tports[i]);

    // snapshot, wait, snapshot again: a suspended thread must NOT advance.
    uint64_t snap[NW];
    for (int i = 0; i < NW; i++) snap[i] = counters[i];
    msleep(120); // longer than the 40ms blocked-worker sleep — if it weren't
                 // frozen, its counter would tick at least twice here.
    int frozen = 1;
    for (int i = 0; i < NW; i++) {
        uint64_t now = counters[i];
        uint64_t sp = read_sp(tports[i]);
        const char* kind = (i == 4) ? "syscall-blocked" : "tight-spin";
        printf("  worker %d (%-15s): counter %s (%llu) sp=0x%llx\n",
               i, kind, (now == snap[i]) ? "FROZEN" : "MOVED!", (unsigned long long)now,
               (unsigned long long)sp);
        if (now != snap[i]) frozen = 0;
        if (sp == 0) frozen = 0;
    }

    // === RESUME THE WORLD ===
    for (int i = 0; i < NW; i++) thread_resume(tports[i]);

    // verify progress resumes
    uint64_t after[NW];
    for (int i = 0; i < NW; i++) after[i] = counters[i];
    msleep(120);
    int progressed = 1;
    for (int i = 0; i < NW; i++) if (counters[i] == after[i]) progressed = 0;

    stop_flag = 1;
    for (int i = 0; i < NW; i++) pthread_join(th[i], NULL);

    if (frozen && progressed) {
        printf("suspend_world PASS: all workers frozen while suspended (incl. "
               "syscall-blocked + tight-spin), SPs read, all resumed.\n");
        return 0;
    }
    printf("suspend_world FAIL: frozen=%d progressed=%d\n", frozen, progressed);
    return 1;
}
#else
int main(void) {
    // linux/bsd path (signal-based) not built in this prototype; see header.
    printf("suspend_world: darwin-only prototype; build on macOS.\n");
    return 0;
}
#endif
