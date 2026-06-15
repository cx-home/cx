#!/usr/bin/env bash
# Baseline CX memory-management perf: single-thread vs parallel, -gc e vs -gc boehm.
# Runs programs with `cx <file>` (the default execution path) — NEVER `cx eval`.
#
# Usage:  bench/parallel-alloc/baseline_gc.sh
# Env:    CX_CC=/path/to/clang  (default /usr/bin/cc — Apple clang)
#         CX_LDDIR=/dir         (default /usr/bin — dir holding the linker; passed as
#                                clang -B so Apple's ld is used. In a devbox/nix shell
#                                the nix cctools ld is on PATH and ABORTS under -prod
#                                (exit 134); -B/usr/bin forces Apple's ld instead.)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
V="$ROOT/third_party/v/v"
CC="${CX_CC:-/usr/bin/cc}"
LDDIR="${CX_LDDIR:-/usr/bin}"
WK=/tmp/cx_gcbaseline
mkdir -p "$WK"

# #14 reduce-over-range workload: 8 independent folds. serial vs [par].
printf '[?to-sequence [?map (1,2,3,4,5,6,7,8) [using [?fn $x [?reduce [$range 0 400000] [using [?fn ($a $b) [+ $a $b]]] [init 0]]]]]]\n' > "$WK/serial.cx"
printf '[?to-sequence [?map (1,2,3,4,5,6,7,8) [using [?fn $x [?reduce [$range 0 400000] [using [?fn ($a $b) [+ $a $b]]] [init 0]]]] [par]]]\n' > "$WK/par.cx"

echo "building cx_e (-gc e) + cx_boehm (-gc boehm), prod, cc=$CC, ld dir=$LDDIR ..."
( cd "$ROOT/vcx" \
  && "$V" -n -w -cc "$CC" -cflags "-B$LDDIR" -prod -gc e     -o "$WK/cx_e"     cmd/ \
  && "$V" -n -w -cc "$CC" -cflags "-B$LDDIR" -prod -gc boehm -o "$WK/cx_boehm" cmd/ ) \
  || { echo "BUILD FAILED. If ld aborted (exit 134), the nix linker is still being used —"; \
       echo "  try a plain terminal (outside 'devbox shell'), or set CX_LDDIR to a dir with Apple's ld."; exit 1; }

# correctness: both builds, both workloads must print 80000200000 x8
ok=1
for bin in cx_e cx_boehm; do for f in serial par; do
  out=$("$WK/$bin" "$WK/$f.cx" 2>&1)
  case "$out" in *"80000200000, 80000200000, 80000200000, 80000200000, 80000200000, 80000200000, 80000200000, 80000200000"*) :;; *) echo "WRONG OUTPUT: $bin $f -> ${out:0:60}"; ok=0;; esac
done; done
[ "$ok" = 1 ] && echo "correctness: OK (80000200000 x8 everywhere)" || echo "correctness: FAILED"

best() { local b=999999 i s e ms; for i in 1 2 3; do
  s=$(python3 -c 'import time;print(time.time())'); "$1" "$2" >/dev/null 2>&1; e=$(python3 -c 'import time;print(time.time())')
  ms=$(python3 -c "print(int(($e-$s)*1000))"); [ "$ms" -lt "$b" ] && b=$ms; done; echo "$b"; }

printf '\n%-12s %12s %12s\n' "build" "single" "par(8)"
printf '%-12s %10sms %10sms\n' "-gc e"     "$(best "$WK/cx_e" "$WK/serial.cx")"     "$(best "$WK/cx_e" "$WK/par.cx")"
printf '%-12s %10sms %10sms\n' "-gc boehm" "$(best "$WK/cx_boehm" "$WK/serial.cx")" "$(best "$WK/cx_boehm" "$WK/par.cx")"
echo
echo "(best-of-3 wall-clock; run programs via 'cx <file>', not 'cx eval')"
