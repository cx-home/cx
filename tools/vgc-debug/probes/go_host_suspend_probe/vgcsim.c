// vgcsim.c — standalone mimic of vgc's darwin STW suspension machinery, for
// probing signal-choice collisions with a foreign host runtime (Go). cx #743.
//
// Mirrors thirdparty/vgc/vgc_platform.h (darwin, signal path) byte-for-byte in
// the parts that matter: sigaction(SA_SIGINFO|SA_RESTART, sigfillset mask),
// handler self-match on pthread, capture + ack + park-until-release, collector
// signal + unbounded ack wait with periodic re-signal. Adds instrumentation the
// real collector doesn't need: spurious-hit counter (a foreign runtime's own
// signals landing in OUR handler), handler-ownership readback (did the host
// runtime re-install its handler over ours?), and a wall-clock ack timeout so
// the probe reports instead of hanging.
//
// Modes:
//   vgcsim_install(sig)                — install the vgc-style handler for `sig`
//   vgcsim_register()                  — unblock sig on this thread, return mach port
//   vgcsim_suspend_signal(port, ns)    — vgc signal-suspend; 1=acked, 0=timeout
//   vgcsim_suspend_mach(port)          — signal-free thread_suspend + kernel settle
//   vgcsim_release(port)               — release the parked/suspended target
//   vgcsim_spurious()                  — handler entries with no matching slot
//   vgcsim_handler_is_ours()           — sigaction readback: 1 if still ours
//   vgcsim_resignals()                 — re-signal attempts during ack waits
#include <errno.h>
#include <mach/mach.h>
#include <mach/thread_act.h>
#include <pthread.h>
#include <sched.h>
#include <signal.h>
#include <stdint.h>
#include <string.h>
#include <sys/ucontext.h>
#include <time.h>

#define MAXREG 96

typedef struct {
    volatile uint32_t port;
    pthread_t pt;
    volatile uint32_t acked;
    volatile uint32_t release;
    volatile uintptr_t sp;
    uintptr_t regs[MAXREG];
    volatile int nregs;
    semaphore_t sem;
    volatile uint32_t sem_init;
    volatile uint32_t mach_mode; // 1 = suspended via thread_suspend (no park)
} slot_t;

static slot_t g_slot; // one target at a time is enough for the probe
static int g_sig = SIGURG;
static volatile uint64_t g_spurious = 0;
static volatile uint64_t g_resignals = 0;

static uint64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

// ---- handler: identical shape to vgc_suspend_handler ------------------------
static void sim_handler(int sig, siginfo_t* si, void* uctx) {
    (void)sig; (void)si;
    pthread_t self = pthread_self();
    slot_t* s = 0;
    if (__atomic_load_n(&g_slot.port, __ATOMIC_ACQUIRE) != 0 && pthread_equal(self, g_slot.pt))
        s = &g_slot;
    if (s == 0) { __atomic_add_fetch(&g_spurious, 1, __ATOMIC_RELAXED); return; }
    ucontext_t* uc = (ucontext_t*)uctx;
    int c = 0;
#if defined(__arm64__) || defined(__aarch64__)
    for (int i = 0; i < 29 && c < MAXREG; i++) s->regs[c++] = (uintptr_t)uc->uc_mcontext->__ss.__x[i];
    if (c < MAXREG) s->regs[c++] = (uintptr_t)uc->uc_mcontext->__ss.__fp;
    if (c < MAXREG) s->regs[c++] = (uintptr_t)uc->uc_mcontext->__ss.__lr;
    s->sp = (uintptr_t)uc->uc_mcontext->__ss.__sp;
#elif defined(__x86_64__)
    s->sp = (uintptr_t)uc->uc_mcontext->__ss.__rsp;
#endif
    s->nregs = c;
    __atomic_store_n(&s->acked, 1, __ATOMIC_RELEASE);
    for (int i = 0; i < 256 && __atomic_load_n(&s->release, __ATOMIC_ACQUIRE) == 0; i++) { }
    while (__atomic_load_n(&s->release, __ATOMIC_ACQUIRE) == 0) {
        semaphore_wait(s->sem);
    }
    __atomic_store_n(&s->acked, 0, __ATOMIC_RELEASE);
}

void vgcsim_install(int sig) {
    g_sig = sig;
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = sim_handler;
    sa.sa_flags = SA_SIGINFO | SA_RESTART;
    sigfillset(&sa.sa_mask);
    sigaction(g_sig, &sa, 0);
}

// Real-lane install order: libcx's dyld load constructor runs vgc_init ->
// vgc_register_thread -> vgc_thread_self_port -> pthread_once(sigaction)
// BEFORE the Go runtime initializes its signal handlers. PROBE_CTOR=1/urg/xcpu
// reproduces that order; Go's initsig() then decides whether to stack its own
// handler on top (it does for the preemption signal, unconditionally).
#include <stdlib.h>
__attribute__((constructor)) static void vgcsim_ctor(void) {
    const char* c = getenv("PROBE_CTOR");
    if (c == 0) return;
    if (strcmp(c, "xcpu") == 0) vgcsim_install(SIGXCPU);
    else if (strcmp(c, "1") == 0 || strcmp(c, "urg") == 0) vgcsim_install(SIGURG);
}

int vgcsim_handler_is_ours(void) {
    struct sigaction cur;
    if (sigaction(g_sig, 0, &cur) != 0) return -1;
    return cur.sa_sigaction == sim_handler ? 1 : 0;
}

uint64_t vgcsim_spurious(void) { return g_spurious; }
uint64_t vgcsim_resignals(void) { return g_resignals; }

uint32_t vgcsim_register(void) {
    sigset_t set; sigemptyset(&set); sigaddset(&set, g_sig);
    pthread_sigmask(SIG_UNBLOCK, &set, 0);
    return (uint32_t)pthread_mach_thread_np(pthread_self());
}

// ---- signal-suspend: vgc_suspend_thread with a wall-clock probe timeout ------
int vgcsim_suspend_signal(uint32_t port, uint64_t timeout_ns) {
    pthread_t pt = pthread_from_mach_thread_np((mach_port_t)port);
    if (pt == 0) return -1;
    slot_t* s = &g_slot;
    if (s->sem_init == 0) {
        semaphore_t sem_new;
        if (semaphore_create(mach_task_self(), &sem_new, SYNC_POLICY_FIFO, 0) != KERN_SUCCESS) return -2;
        s->sem = sem_new;
        s->sem_init = 1;
    }
    s->acked = 0; s->release = 0; s->sp = 0; s->nregs = 0; s->pt = pt; s->mach_mode = 0;
    __atomic_store_n(&s->port, port, __ATOMIC_RELEASE);
    if (pthread_kill(pt, g_sig) != 0) {
        __atomic_store_n(&s->port, 0, __ATOMIC_RELEASE);
        return -3;
    }
    uint64_t t0 = now_ns();
    for (uint64_t spins = 1;; spins++) {
        if (__atomic_load_n(&s->acked, __ATOMIC_ACQUIRE) != 0) return 1;
        if (now_ns() - t0 > timeout_ns) return 0; // probe-only: report, don't hang
        if ((spins & 0xffff) == 0) {
            (void)pthread_kill(pt, g_sig); // vgc re-signals a lost/consumed delivery
            __atomic_add_fetch(&g_resignals, 1, __ATOMIC_RELAXED);
        }
        sched_yield();
    }
}

// ---- mach-suspend: signal-free; kernel-authoritative settle ------------------
// thread_suspend halts dispatch; poll thread_info until run_state leaves
// TH_STATE_RUNNING so thread_get_state reads a frozen register file (kernel
// settle, not the SP/PC-stability heuristic — a 1-instruction spin loop defeats
// that heuristic while still running).
int vgcsim_suspend_mach(uint32_t port) {
    if (thread_suspend((thread_act_t)port) != KERN_SUCCESS) return -1;
    for (int i = 0; i < 5000000; i++) {
        struct thread_basic_info info;
        mach_msg_type_number_t cnt = THREAD_BASIC_INFO_COUNT;
        if (thread_info((thread_act_t)port, THREAD_BASIC_INFO, (thread_info_t)&info, &cnt) != KERN_SUCCESS)
            return -2; // thread gone
        if (info.run_state != TH_STATE_RUNNING) break;
        sched_yield();
    }
#if defined(__arm64__) || defined(__aarch64__)
    arm_thread_state64_t st;
    mach_msg_type_number_t n = ARM_THREAD_STATE64_COUNT;
    if (thread_get_state((thread_act_t)port, ARM_THREAD_STATE64, (thread_state_t)&st, &n) != KERN_SUCCESS) {
        thread_resume((thread_act_t)port);
        return -3;
    }
#endif
    g_slot.mach_mode = 1;
    __atomic_store_n(&g_slot.port, port, __ATOMIC_RELEASE);
    return 1;
}

// ---- one-shot cycles: suspend -> hold -> release, entirely inside ONE C call.
// This mirrors the real vgc shape: the collector runs the whole STW inside a
// single cgo call and never yields to the host runtime while a target is
// suspended. (A first probe version returned to Go between suspend and
// release; Go's own GC STW then deadlocked against the held suspension —
// itself a finding: any fix must keep the full suspend..resume window inside
// foreign code, which vgc does.)
void vgcsim_release(uint32_t port);
static void hold_ns(uint64_t ns) {
    uint64_t t0 = now_ns();
    while (now_ns() - t0 < ns) sched_yield();
}
int vgcsim_cycle_signal(uint32_t port, uint64_t timeout_ns, uint64_t hold_us) {
    int r = vgcsim_suspend_signal(port, timeout_ns);
    if (r == 1) hold_ns(hold_us * 1000ull);
    vgcsim_release(port); // timeout path: clear the slot too
    return r;
}
int vgcsim_cycle_mach(uint32_t port, uint64_t hold_us) {
    int r = vgcsim_suspend_mach(port);
    if (r == 1) {
        hold_ns(hold_us * 1000ull);
        vgcsim_release(port);
    }
    return r;
}

void vgcsim_release(uint32_t port) {
    slot_t* s = &g_slot;
    if (__atomic_load_n(&s->port, __ATOMIC_ACQUIRE) != port) return;
    if (s->mach_mode) {
        thread_resume((thread_act_t)port);
        __atomic_store_n(&s->port, 0, __ATOMIC_RELEASE);
        return;
    }
    __atomic_store_n(&s->release, 1, __ATOMIC_RELEASE);
    semaphore_signal(s->sem);
    for (int i = 0; i < 200000; i++) {
        if (__atomic_load_n(&s->acked, __ATOMIC_ACQUIRE) == 0) break;
        sched_yield();
    }
    __atomic_store_n(&s->port, 0, __ATOMIC_RELEASE);
}
