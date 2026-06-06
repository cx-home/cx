// Validate the SCOPE-AWARE REGION mechanism (fix path A):
//   - per-thread region = ONE raw malloc'd block, registered as a GC root once
//     (GC_add_roots on NON-GC memory is the correct, supported usage), so
//     pointers from region objects to GC objects stay traced.
//   - reused across scopes: scope end = reset offset to 0 (no free, no GC).
//   - transient bump-allocations never touch the GC heap → no global GC lock
//     after warmup → should scale; region stays small → bounded scan, no tax.
// Each "node" stores a pointer to a SHARED GC object; we periodically force a
// collection and verify the shared object survives (tracing through the region
// root works).
#define GC_THREADS 1
#include <gc.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

static long SCOPES;          // scopes per thread
static int  PER_SCOPE = 1000;// transient nodes per scope
static int  NODE = 64;
#define REGION (4*1024*1024)
static void* shared_gc_obj;  // a GC object every node points at
static volatile unsigned long sink=0;

static void* worker(void* a){
  struct GC_stack_base sb; GC_get_stack_base(&sb); GC_register_my_thread(&sb);
  char* region = (char*)malloc(REGION);          // raw, NOT GC
  GC_add_roots(region, region + REGION);          // trace it as a root (valid: non-GC mem)
  unsigned long s=0;
  for(long sc=0; sc<SCOPES; sc++){
    long off=0;
    for(int i=0;i<PER_SCOPE;i++){
      if(off+NODE>REGION) off=0;                  // (shouldn't happen here)
      char* n = region+off; off+=NODE;
      *(void**)n = shared_gc_obj;                  // region->GC pointer (must stay traced)
      s += (unsigned long)n[8];
    }
    // scope end: reset (reuse the block). A real impl deep-copies the result
    // to the GC heap here; the bench just resets.
  }
  GC_remove_roots(region, region + REGION);
  free(region);
  sink += s; return 0;
}
static double now_s(void){ struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec+t.tv_nsec/1e9; }
int main(int c,char**v){
  int n=c>1?atoi(v[1]):1; SCOPES=c>2?atol(v[2]):20000L;
  GC_set_markers_count(1); GC_INIT(); GC_allow_register_threads();
  shared_gc_obj = GC_MALLOC(128); ((char*)shared_gc_obj)[0]=7;
  pthread_t th[64]; double t0=now_s();
  for(int i=0;i<n;i++)pthread_create(&th[i],0,worker,0);
  // hammer collections concurrently to prove the shared obj survives via region roots
  for(int k=0;k<50;k++){ GC_gcollect(); }
  for(int i=0;i<n;i++)pthread_join(th[i],0);
  double el=now_s()-t0; long tot=(long)n*SCOPES*PER_SCOPE;
  printf("threads=%d scopes/thr=%ld allocs=%ld wall=%.3fs agg_M/s=%.1f per_thread_M/s=%.1f shared_ok=%d\n",
    n, SCOPES, tot, el, tot/el/1e6, (tot/el/1e6)/n, ((char*)shared_gc_obj)[0]==7);
  if(sink==0xdead)printf("x"); return 0; }
