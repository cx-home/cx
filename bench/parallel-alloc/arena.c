// Validate the FIX: per-thread bump arena over Boehm. Each thread grabs a
// big GC block rarely and sub-allocates from it lock-free. If this scales,
// arena allocation for cx's transient nodes is the answer.
#define GC_THREADS 1
#include <gc.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
static long PER; static int SZ=64; static volatile unsigned long sink=0;
#define ARENA (4*1024*1024)
static void* worker(void* a){
  unsigned long s=0; char* base=0; long off=ARENA;
  for(long i=0;i<PER;i++){
    if(off+SZ>ARENA){ base=(char*)GC_MALLOC(ARENA); off=0; } // refill arena (rare: 1 per 65536 allocs)
    char* p=base+off; off+=SZ;
    p[0]=(char)i; s+=(unsigned long)p[0];
  }
  sink+=s; return 0;
}
static double now_s(void){ struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec+t.tv_nsec/1e9; }
int main(int c,char**v){ int n=c>1?atoi(v[1]):1; PER=c>2?atol(v[2]):20000000L;
  GC_set_markers_count(1); GC_INIT(); GC_allow_register_threads();
  pthread_t th[64]; double t0=now_s();
  for(int i=0;i<n;i++)pthread_create(&th[i],0,worker,0); for(int i=0;i<n;i++)pthread_join(th[i],0);
  double el=now_s()-t0; long tot=(long)n*PER;
  printf("threads=%d wall=%.3fs agg_M/s=%.1f per_thread_M/s=%.1f gc_no=%lu\n",n,el,tot/el/1e6,(tot/el/1e6)/n,(unsigned long)GC_get_gc_no());
  if(sink==0xdead)printf("x"); return 0; }
