#!/usr/bin/env bash
# Reduce-over-range time + peak-RSS probe for lever (1): streaming generate+fold+drop.
# Materializing a [$range] makes a large reduce memory-bandwidth-bound (4M -> ~4.5GB RSS);
# a streaming fold keeps the live set O(1). This probe surfaces BOTH time and peak RSS so we
# can see the materialization collapse, which the time-only baseline_gc.sh cannot.
#
# Usage:  range_reduce_rss.sh <cx-binary> [N ...]      (default N: 400000 4000000)
# Runs programs with `cx <file>` (default path) — NEVER `cx eval`.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="${1:?usage: range_reduce_rss.sh <cx-binary> [N ...]}"
shift || true
SIZES=("$@"); [ "${#SIZES[@]}" -eq 0 ] && SIZES=(400000 4000000)
WK=/tmp/cx_range_reduce_rss
mkdir -p "$WK"

# macOS /usr/bin/time -l prints "maximum resident set size" in bytes.
rss_mb() { awk '/maximum resident set size/{printf "%.0f", $1/1048576}'; }

# Timing is CX, not python (#943): the three `python3 -c` calls this replaces —
# two time.time() reads and an int((e-s)*1000) — were utility Python that
# survived the #922 eradication under the awk/sed/shell carve-out, and Python is
# banned for all tooling outside the lang/python binding surface. `date` cannot
# stand in: ms resolution needs GNU `date +%s%N` or bash 5's $EPOCHREALTIME, and
# macOS outside devbox has neither. measure.cx times with cx-stdlib/time's
# monotonic-now (nanosecond, monotonic — the right clock, where time.time() was
# wall-clock and can step). It also owns the best-of-3 selection, so the RSS
# reported is the RSS OF THE RUN WHOSE TIME IS REPORTED: it writes that run's
# stderr — the `/usr/bin/time -l` report — to MEASURE_STDERR, and rss_mb (awk,
# not python) reads it from there. The driver is $BIN itself, already a cx
# binary, so this adds no new dependency.
measure() { # <label> <file>  -> best-of-3 ms + peak RSS MB of the best run
  local label="$1" f="$2" tf ms
  tf="$WK/time.$$"
  ms=$(MEASURE_RUNS=3 MEASURE_STDERR="$tf" "$BIN" \
        --allow-subprocess --allow-clock --allow-env --allow-write \
        "$ROOT/bench/parallel-alloc/measure.cx" /usr/bin/time -l "$BIN" "$f")
  printf '%-22s %9sms  peakRSS %7sMB\n' "$label" "$ms" "$(rss_mb <"$tf")"
}

for N in "${SIZES[@]}"; do
  # sum 0..N inclusive (note: range is 0..N here). Shell arithmetic, not python
  # (#943): bash arithmetic is 64-bit (intmax_t), and the largest value this
  # probe produces is N=4000000 -> 8000002000000, six orders of magnitude inside
  # that. `(N+1)` is always even for even N, and `N*(N+1)` for odd N, so the
  # halving is exact — no truncation to hide, which is why python's `//` had
  # nothing to add.
  sum=$(( N * (N + 1) / 2 ))
  printf '[?to-sequence [?map (1,2,3,4,5,6,7,8) [using [?fn $x [?reduce [$range 0 %s] [using [?fn ($a $b) [+ $a $b]]] [init 0]]]]]]\n' "$N" > "$WK/serial_$N.cx"
  printf '[?to-sequence [?map (1,2,3,4,5,6,7,8) [using [?fn $x [?reduce [$range 0 %s] [using [?fn ($a $b) [+ $a $b]]] [init 0]]]] [par]]]\n' "$N" > "$WK/par_$N.cx"
  # correctness (single fold value, repeated x8)
  out=$("$BIN" "$WK/serial_$N.cx" 2>&1)
  case "$out" in *"$sum, $sum, $sum, $sum, $sum, $sum, $sum, $sum"*) ck="OK ($sum x8)";; *) ck="WRONG -> ${out:0:70}";; esac
  echo "== N=$N  correctness: $ck =="
  measure "N=$N serial"  "$WK/serial_$N.cx"
  measure "N=$N par(8)"  "$WK/par_$N.cx"
  echo
done
echo "(best-of-3 wall-clock + peak RSS of that run; run via 'cx <file>', not 'cx eval')"
