#!/usr/bin/env bash
# Reduce-over-range time + peak-RSS probe for lever (1): streaming generate+fold+drop.
# Materializing a [$range] makes a large reduce memory-bandwidth-bound (4M -> ~4.5GB RSS);
# a streaming fold keeps the live set O(1). This probe surfaces BOTH time and peak RSS so we
# can see the materialization collapse, which the time-only baseline_gc.sh cannot.
#
# Usage:  range_reduce_rss.sh <cx-binary> [N ...]      (default N: 400000 4000000)
# Runs programs with `cx <file>` (default path) — NEVER `cx eval`.
set -u
BIN="${1:?usage: range_reduce_rss.sh <cx-binary> [N ...]}"
shift || true
SIZES=("$@"); [ "${#SIZES[@]}" -eq 0 ] && SIZES=(400000 4000000)
WK=/tmp/cx_range_reduce_rss
mkdir -p "$WK"

# macOS /usr/bin/time -l prints "maximum resident set size" in bytes.
rss_mb() { awk '/maximum resident set size/{printf "%.0f", $1/1048576}'; }

measure() { # <label> <file>  -> best-of-3 ms + peak RSS MB of the best run
  local label="$1" f="$2" b=999999999 bestrss=0 i s e ms rss tf
  for i in 1 2 3; do
    tf="$WK/time.$$"
    s=$(python3 -c 'import time;print(time.time())')
    { /usr/bin/time -l "$BIN" "$f" >/dev/null; } 2>"$tf"
    e=$(python3 -c 'import time;print(time.time())')
    ms=$(python3 -c "print(int(($e-$s)*1000))")
    rss=$(rss_mb <"$tf")
    if [ "$ms" -lt "$b" ]; then b=$ms; bestrss=$rss; fi
  done
  printf '%-22s %9sms  peakRSS %7sMB\n' "$label" "$b" "$bestrss"
}

for N in "${SIZES[@]}"; do
  sum=$(python3 -c "print($N*($N+1)//2)")  # sum 0..N inclusive (note: range is 0..N here)
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
