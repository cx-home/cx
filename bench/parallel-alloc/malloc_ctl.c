// Control: does the SYSTEM allocator scale across threads on this hardware?
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
static long PER; static int SZ=64; static volatile unsigned long sink=0;
static void* worker(void* a){ unsigned long s=0; for(long i=0;i<PER;i++){ char*p=malloc(SZ); p[0]=(char)i; s+=(unsigned long)p[0]; free(p);} sink+=s; return 0; }
static double now_s(void){ struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec+t.tv_nsec/1e9; }
int main(int c,char**v){ int n=c>1?atoi(v[1]):1; PER=c>2?atol(v[2]):20000000L; pthread_t th[64]; double t0=now_s();
  for(int i=0;i<n;i++)pthread_create(&th[i],0,worker,0); for(int i=0;i<n;i++)pthread_join(th[i],0);
  double el=now_s()-t0; long tot=(long)n*PER;
  printf("threads=%d wall=%.3fs agg_M/s=%.1f per_thread_M/s=%.1f\n",n,el,tot/el/1e6,(tot/el/1e6)/n);
  if(sink==0xdead)printf("x"); return 0; }
