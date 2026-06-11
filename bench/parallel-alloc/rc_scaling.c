// G-R2s — the §5.1 RC-atomicity crux detector (spec/02-working/
// v_runtime_memory_management.md §5.1, §7.2). Measures how the dup/drop RC
// scheme on the SHARED RESIDUAL scales across cores on a deliberately
// share-heavy workload. The residual is exactly the set of values Perceus
// cannot prove unique — by construction those are the cross-thread-shared
// ones, so a small pool of shared objects whose refcounts every thread touches
// is the faithful worst case (and the only gate that catches refcount
// cache-line bouncing — §7.2 G-R2s).
//
// Two schemes, IDENTICAL workload (same objects, same access pattern, same
// total RC work); they differ ONLY in where the refcount lives:
//
//   atomic (Lean 4): every dup/drop is an atomic add/sub on the object's
//     shared rc  ->  2 + 2*W atomics per borrow, all on a contended line.
//   tls (Koka thread-local handoff): only the genuine ownership transfer
//     (acquire/release = handoff in/out) touches the shared atomic; the W
//     within-thread uses dup/drop a PRIVATE per-thread counter  ->  exactly
//     2 atomics per borrow regardless of W.
//
// W = within-thread uses per handoff (sharing granularity). W=0 makes the two
// schemes identical (every RC op IS a handoff); as W grows the atomic scheme's
// shared-line traffic grows while tls stays flat. Real residual code has W>=1
// (a borrowed value is used at least once between ownership transfers), so we
// sweep W and read the decision off the curve rather than asserting it.
//
// Decision criterion (§5.1): on this share-heavy workload the chosen scheme
// must hold R2 (agg throughput monotonic-up 1->8 threads). If atomic anti-
// scales here, option (a) thread-local-handoff is required.
//
// Build:  cc -O2 -std=c11 rc_scaling.c -o rc_scaling
// Usage:  rc_scaling <atomic|tls> <threads> <per> <W> [reps] [objs]

#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define CLINE 128            // Apple-silicon cache line; isolate each rc

// refcount and payload live on SEPARATE lines: in real immutable sharing only
// the refcount is mutated (bounces); field reads stay shared-read-only (no
// bounce). Co-locating them would make the handoff RMW dirty the line the
// within-thread reads use — a false-sharing confound that wrongly penalizes
// tls's "use" reads. Separating them isolates *refcount* contention, which is
// exactly what §5.1 is about.
typedef struct {
    _Atomic long rc;
    char pad[CLINE - sizeof(_Atomic long)];
} Rc;                        // one contended refcount per cache line

enum { ATOMIC, TLS };

static int    SCHEME;
static int    NTH;
static long   PER;           // borrow-cycles per thread
static long   W;             // within-thread uses per borrow
static int    OBJS;
static Rc    *rcs;           // mutated (bounces under contention)
static long  *payloads;      // read-only after init (shared, no bounce)

typedef struct {
    int tid;
    long *local_rc;          // TLS scheme: private per-object counters
    unsigned long sink;
    char pad[CLINE];
} Targ;

// rotating, coprime stride so every thread sweeps every object (max sharing)
static inline int pick(int tid, long i) {
    return (int)(((unsigned long)tid * 2654435761u + (unsigned long)i * 40503u) % (unsigned long)OBJS);
}

static void *worker(void *a) {
    Targ *t = (Targ *)a;
    unsigned long s = 0;
    if (SCHEME == ATOMIC) {
        for (long i = 0; i < PER; i++) {
            int j = pick(t->tid, i);
            atomic_fetch_add_explicit(&rcs[j].rc, 1, memory_order_relaxed);   // handoff in (dup)
            for (long w = 0; w < W; w++) {
                atomic_fetch_add_explicit(&rcs[j].rc, 1, memory_order_relaxed); // dup (use)
                s += (unsigned long)payloads[j];
                if (atomic_fetch_sub_explicit(&rcs[j].rc, 1, memory_order_acq_rel) == 1)
                    s++;                                                       // would-free branch (never taken: rooted)
            }
            if (atomic_fetch_sub_explicit(&rcs[j].rc, 1, memory_order_acq_rel) == 1) // handoff out (drop)
                s++;
        }
    } else { // TLS: handoff touches shared atomic; uses touch private counter
        long *lrc = t->local_rc;
        for (long i = 0; i < PER; i++) {
            int j = pick(t->tid, i);
            atomic_fetch_add_explicit(&rcs[j].rc, 1, memory_order_relaxed);   // handoff in (shared)
            for (long w = 0; w < W; w++) {
                lrc[j]++;                                                      // dup (thread-local)
                s += (unsigned long)payloads[j];
                lrc[j]--;                                                      // drop (thread-local)
            }
            if (atomic_fetch_sub_explicit(&rcs[j].rc, 1, memory_order_acq_rel) == 1) // handoff out (shared)
                s++;
        }
    }
    t->sink = s;
    return NULL;
}

static double now_s(void) {
    struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}

static int cmp_d(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}

static double one_run(void) {
    pthread_t th[256];
    Targ targ[256];
    for (int i = 0; i < NTH; i++) {
        targ[i].tid = i;
        targ[i].sink = 0;
        targ[i].local_rc = NULL;
        if (SCHEME == TLS) {
            targ[i].local_rc = calloc((size_t)OBJS, sizeof(long)); // private, never shared
            if (!targ[i].local_rc) { perror("calloc"); exit(1); }
        }
    }
    for (int i = 0; i < OBJS; i++) {
        atomic_store_explicit(&rcs[i].rc, 1, memory_order_relaxed); // rooted owner -> never hits 0
        payloads[i] = i + 1;
    }
    double t0 = now_s();
    for (int i = 0; i < NTH; i++) pthread_create(&th[i], NULL, worker, &targ[i]);
    for (int i = 0; i < NTH; i++) pthread_join(th[i], NULL);
    double el = now_s() - t0;
    unsigned long acc = 0;
    for (int i = 0; i < NTH; i++) { acc += targ[i].sink; free(targ[i].local_rc); }
    if (acc == 0xdeadbeefUL) fputs("x", stderr); // keep sink live
    return el;
}

int main(int argc, char **argv) {
    if (argc < 5) {
        fprintf(stderr, "usage: %s <atomic|tls> <threads> <per> <W> [reps] [objs]\n", argv[0]);
        return 2;
    }
    SCHEME = strcmp(argv[1], "tls") == 0 ? TLS : ATOMIC;
    NTH    = atoi(argv[2]);
    PER    = atol(argv[3]);
    W      = atol(argv[4]);
    int reps = argc > 5 ? atoi(argv[5]) : 5;
    OBJS   = argc > 6 ? atoi(argv[6]) : 16;
    if (NTH < 1 || NTH > 256) { fprintf(stderr, "threads 1..256\n"); return 2; }

    rcs = aligned_alloc(CLINE, (size_t)OBJS * sizeof(Rc));
    payloads = calloc((size_t)OBJS, sizeof(long));
    if (!rcs || !payloads) { perror("alloc"); return 1; }

    one_run(); // warmup (discarded)

    double el[64];
    if (reps > 64) reps = 64;
    for (int r = 0; r < reps; r++) el[r] = one_run();
    qsort(el, reps, sizeof(double), cmp_d);
    double med = el[reps / 2];

    // RC ops per borrow-cycle: atomic touches the shared line 2+2W times; tls
    // does 2 shared + 2W local. "rc_ops" counts total dup/drop work (same for
    // both) so M-ops/s is comparable across schemes.
    long rc_ops_per_cycle = 2 + 2 * W;
    double total_ops = (double)NTH * (double)PER * (double)rc_ops_per_cycle;
    double agg = total_ops / med / 1e6;
    printf("scheme=%-6s threads=%d per=%ld W=%ld objs=%d reps=%d  med_wall=%.4fs  agg_Mops/s=%8.1f  per_thread_Mops/s=%7.1f\n",
           SCHEME == TLS ? "tls" : "atomic", NTH, PER, W, OBJS, reps, med, agg, agg / NTH);
    free(rcs);
    free(payloads);
    return 0;
}
