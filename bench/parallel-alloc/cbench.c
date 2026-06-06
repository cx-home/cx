// Layer-0: does the macOS Boehm allocator (the exact libgc cx links) scale
// across threads, isolated from V/cx? N threads each allocate-and-drop in a
// tight loop. Perfect scaling => wall time ~constant as N grows (per-thread
// work fixed). Serialized => wall time grows with N.
#define GC_THREADS 1
#include <gc.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

static long PER;        // allocations per thread
static int  SZ = 64;    // object size
static int  DO_FREE = 0;// 1 => GC_free each (no heap growth, pure freelist churn)
static volatile unsigned long sink = 0;

static void* worker(void* arg) {
    struct GC_stack_base sb; GC_get_stack_base(&sb); GC_register_my_thread(&sb); // no-op if redirect already did
    unsigned long s = 0;
    for (long i = 0; i < PER; i++) {
        void* p = GC_MALLOC(SZ);
        ((char*)p)[0] = (char)i;
        s += (unsigned long)((char*)p)[0];
        if (DO_FREE) GC_FREE(p);
    }
    sink += s;
    return NULL;
}

static double now_s(void){ struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec + t.tv_nsec/1e9; }

int main(int argc, char** argv) {
    int nth = argc>1 ? atoi(argv[1]) : 1;
    PER     = argc>2 ? atol(argv[2]) : 20000000L;
    DO_FREE = argc>3 ? atoi(argv[3]) : 0;
    GC_set_markers_count(1);
    GC_INIT();
    GC_allow_register_threads();
    pthread_t th[64];
    double t0 = now_s();
    for (int i=0;i<nth;i++) pthread_create(&th[i],NULL,worker,NULL);
    for (int i=0;i<nth;i++) pthread_join(th[i],NULL);
    double el = now_s()-t0;
    long total = (long)nth*PER;
    printf("threads=%d per=%ld free=%d wall=%.3fs total_allocs=%ld agg_M/s=%.1f per_thread_M/s=%.1f gc_no=%lu\n",
        nth, PER, DO_FREE, el, total, total/el/1e6, (total/el/1e6)/nth, (unsigned long)GC_get_gc_no());
    if (sink==0xdeadbeef) printf("x");
    return 0;
}
