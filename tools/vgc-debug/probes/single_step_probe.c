// B-STEP feasibility probe: can we hardware single-step a thread on macOS arm64
// (ARM_DEBUG_STATE64 MDSCR_EL1.SS), catch each instruction via a mach exception
// port, and read the stepped thread's registers per step? PASS = many steps with
// advancing PC and the callee-saved sentinel (x19) readable at each step.
// No fork edits. Pure libc + mach.
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <pthread.h>
#include <mach/mach.h>
#include <mach/thread_act.h>
#include <mach/exception_types.h>

#define MAX_STEPS 40
#define SENTINEL 0x55aa55aa12345678ULL

static mach_port_t g_exc_port;
static volatile int g_worker_ready = 0;
static volatile int g_done = 0;
static int g_steps = 0;
static int g_pc_advanced = 0;
static int g_x19_ok = 0;
static uintptr_t g_last_pc = 0;

// Hand-rolled mach exception request/reply (EXCEPTION_DEFAULT | MACH_EXCEPTION_CODES).
#pragma pack(4)
typedef struct {
    mach_msg_header_t Head;
    mach_msg_body_t msgh_body;
    mach_msg_port_descriptor_t thread;
    mach_msg_port_descriptor_t task;
    NDR_record_t NDR;
    exception_type_t exception;
    mach_msg_type_number_t codeCnt;
    int64_t code[2];
    char pad[512];
} exc_req_t;
typedef struct {
    mach_msg_header_t Head;
    NDR_record_t NDR;
    kern_return_t RetCode;
} exc_reply_t;
#pragma pack()

static void rearm_ss(thread_act_t th, int enable) {
    arm_debug_state64_t ds;
    mach_msg_type_number_t c = ARM_DEBUG_STATE64_COUNT;
    if (thread_get_state(th, ARM_DEBUG_STATE64, (thread_state_t)&ds, &c) != KERN_SUCCESS) return;
    if (enable) ds.__mdscr_el1 |= 1ULL; else ds.__mdscr_el1 &= ~1ULL;
    thread_set_state(th, ARM_DEBUG_STATE64, (thread_state_t)&ds, ARM_DEBUG_STATE64_COUNT);
}

static void* handler_fn(void* arg) {
    (void)arg;
    while (!g_done) {
        exc_req_t req; memset(&req, 0, sizeof(req));
        kern_return_t kr = mach_msg(&req.Head, MACH_RCV_MSG, 0, sizeof(req),
                                    g_exc_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        if (kr != KERN_SUCCESS) { if (g_done) break; continue; }
        thread_act_t th = req.thread.name;
        // read the stepped thread's GP state (cross-thread)
        arm_thread_state64_t ts;
        mach_msg_type_number_t tc = ARM_THREAD_STATE64_COUNT;
        uintptr_t pc = 0, x19 = 0;
        if (thread_get_state(th, ARM_THREAD_STATE64, (thread_state_t)&ts, &tc) == KERN_SUCCESS) {
            pc = (uintptr_t)arm_thread_state64_get_pc(ts);
            x19 = (uintptr_t)ts.__x[19];
        }
        g_steps++;
        if (g_steps <= 12)
            printf("  step %2d: exc=%d code0=0x%llx PC=0x%012lx x19=0x%016lx\n",
                   g_steps, req.exception, (unsigned long long)req.code[0], pc, x19);
        if (g_last_pc != 0 && pc != g_last_pc) g_pc_advanced++;
        g_last_pc = pc;
        if (x19 == (uintptr_t)SENTINEL) g_x19_ok++;
        // re-arm SS (or disable after MAX to let the worker run free)
        rearm_ss(th, g_steps < MAX_STEPS ? 1 : 0);
        if (g_steps >= MAX_STEPS) g_done = 1;
        // reply KERN_SUCCESS so the stepped thread resumes
        exc_reply_t rep; memset(&rep, 0, sizeof(rep));
        rep.Head.msgh_bits = MACH_MSGH_BITS(MACH_MSGH_BITS_REMOTE(req.Head.msgh_bits), 0);
        rep.Head.msgh_size = sizeof(rep);
        rep.Head.msgh_remote_port = req.Head.msgh_remote_port;
        rep.Head.msgh_local_port = MACH_PORT_NULL;
        rep.Head.msgh_id = req.Head.msgh_id + 100;
        rep.NDR = req.NDR;
        rep.RetCode = KERN_SUCCESS;
        mach_msg(&rep.Head, MACH_SEND_MSG, sizeof(rep), 0, MACH_PORT_NULL,
                 MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    }
    return 0;
}

static volatile int g_go = 0;

static void* worker_fn(void* arg) {
    (void)arg;
    g_worker_ready = 1;
    // Spin in MY code with the sentinel parked in callee-saved x19 until the
    // controller suspends us, arms SS, and sets g_go. Stepping then lands in this
    // loop + the nops (all my instructions) ⇒ x19==sentinel at each step, proving
    // cross-thread register reads return the value WE control.
    asm volatile(
        "mov x19, %0\n"
        "1:\n"
        "ldr w9, [%1]\n"
        "cbz w9, 1b\n"
        "nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n"
        "nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n"
        :: "r"((uint64_t)SENTINEL), "r"(&g_go) : "x19", "x9", "memory");
    return 0;
}

int main(void) {
    // task-wide exception port for EXC_BREAKPOINT (covers the single-step trap)
    if (mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &g_exc_port) != KERN_SUCCESS) {
        printf("FAIL: mach_port_allocate\n"); return 1;
    }
    mach_port_insert_right(mach_task_self(), g_exc_port, g_exc_port, MACH_MSG_TYPE_MAKE_SEND);
    if (task_set_exception_ports(mach_task_self(), EXC_MASK_BREAKPOINT, g_exc_port,
            EXCEPTION_DEFAULT | MACH_EXCEPTION_CODES, ARM_THREAD_STATE64) != KERN_SUCCESS) {
        printf("FAIL: task_set_exception_ports\n"); return 1;
    }
    pthread_t ht, wt;
    pthread_create(&ht, 0, handler_fn, 0);
    pthread_create(&wt, 0, worker_fn, 0);

    // Controller: wait until the worker is spinning in MY loop, then suspend it,
    // arm single-step, release the spin, and resume — so stepping lands in my code.
    while (!g_worker_ready) { struct timespec ts={0,1000000}; nanosleep(&ts,0); }
    struct timespec s={0,20000000}; nanosleep(&s,0); // ensure it's parked in the spin
    thread_act_t wport = pthread_mach_thread_np(wt);
    thread_suspend(wport);
    rearm_ss(wport, 1);   // arm MDSCR_EL1.SS on the worker
    g_go = 1;             // let the spin exit once it resumes
    thread_resume(wport);

    // bounded wait for stepping to complete
    for (int i = 0; i < 500 && !g_done; i++) { struct timespec ts={0, 5000000}; nanosleep(&ts,0); }
    g_done = 1;
    // unblock the handler if it's parked in mach_msg
    exc_reply_t wake; memset(&wake,0,sizeof(wake));
    pthread_join(wt, 0);

    printf("=== B-STEP single-step feasibility probe ===\n");
    printf("total steps caught : %d\n", g_steps);
    printf("PC advanced steps  : %d\n", g_pc_advanced);
    printf("x19==sentinel steps: %d  (sentinel=0x%016llx)\n", g_x19_ok, (unsigned long long)SENTINEL);
    int pass = (g_steps >= 8 && g_pc_advanced >= 6 && g_x19_ok >= 6);
    printf("VERDICT: %s\n", pass ?
        "PASS — hardware single-step + per-instruction cross-thread register reads work → B-STEP feasible"
      : "FAIL/UNRELIABLE — single-step did not produce clean per-instruction stops → B-STEP infeasible on this box");
    return 0;
}
