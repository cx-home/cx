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

# Timing is CX, not python (#943). The three `python3 -c` calls this replaces —
# two time.time() reads and an int((e-s)*1000) — were utility Python that
# survived the #922 eradication under the awk/sed/shell carve-out. Python is
# banned for all tooling outside the lang/python binding surface. `date` is not
# a substitute here: ms resolution needs GNU `date +%s%N` or bash 5's
# $EPOCHREALTIME, and this script documents being run OUTSIDE devbox (see the
# CX_LDDIR note above), where macOS gives neither. measure.cx uses
# cx-stdlib/time's monotonic-now — nanosecond and monotonic, the correct clock
# for elapsed time, where time.time() was wall-clock and can step.
#
# The driver runs under cx_e, the -gc e build produced above: a full cx binary
# is already in hand, so this adds no dependency on vcx/target/cx.
#
# --allow-write is required even though nothing here touches a file:
# [$io:write-line] is gated on the write capability whatever handle it is given,
# stdout included. Measured — without it every cell of the table below read
# `[err code=cx-err:CXER0271 message='E_CAP_DENIED: write capability required
# for io-write-line...']ms` instead of a number.
best() { MEASURE_RUNS=3 "$WK/cx_e" \
  --allow-subprocess --allow-clock --allow-env --allow-write \
  "$ROOT/bench/parallel-alloc/measure.cx" "$1" "$2"; }

printf '\n%-12s %12s %12s\n' "build" "single" "par(8)"
printf '%-12s %10sms %10sms\n' "-gc e"     "$(best "$WK/cx_e" "$WK/serial.cx")"     "$(best "$WK/cx_e" "$WK/par.cx")"
printf '%-12s %10sms %10sms\n' "-gc boehm" "$(best "$WK/cx_boehm" "$WK/serial.cx")" "$(best "$WK/cx_boehm" "$WK/par.cx")"
echo
echo "(best-of-3 wall-clock; run programs via 'cx <file>', not 'cx eval')"
