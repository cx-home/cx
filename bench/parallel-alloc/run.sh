#!/usr/bin/env bash
# Reproduces the parallel-allocation scaling findings (see README.md).
# Builds three substrate microbenchmarks against the SAME patched libgc cx
# links, and runs each at 1/2/4/8 threads.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
V="$ROOT/third_party/v"
INC="$V/thirdparty/libgc/include"
LIB="$V/thirdparty/tcc/lib"

cc -O2 -DGC_THREADS=1 -I"$INC" "$HERE/cbench.c" -L"$LIB" -lgc -Wl,-rpath,"$LIB" -o "$HERE/cbench"
cc -O2 -DGC_THREADS=1 -I"$INC" "$HERE/arena.c"  -L"$LIB" -lgc -Wl,-rpath,"$LIB" -o "$HERE/arena"
cc -O2 -fno-builtin-malloc -fno-builtin-free "$HERE/malloc_ctl.c" -o "$HERE/malloc_ctl"

echo "### Boehm GC_MALLOC, allocate-and-free (0 collections — isolates the alloc lock)"
for n in 1 2 4 8; do "$HERE/cbench" $n 20000000 1; done
echo
echo "### System malloc/free (control — does the hardware scale?)"
for n in 1 2 4 8; do "$HERE/malloc_ctl" $n 20000000; done
echo
echo "### Per-thread bump arena over Boehm (the fix — refill 1 big block / ~65k allocs)"
for n in 1 2 4 8; do "$HERE/arena" $n 20000000; done
