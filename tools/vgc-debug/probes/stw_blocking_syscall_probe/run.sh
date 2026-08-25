#!/usr/bin/env bash
# BOUNDED probe — every case gets a hard wall bound and is killed if it hangs,
# so a deadlock reports as a deadlock instead of stalling the session (the
# lesson from letting the unbounded gate run for an hour).
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V="$D/../../../../third_party/v/v"
BUDGET=25

probe() { # probe <gc> <jobs>
  local gc="$1" jobs="$2"
  local bin="$D/repro-${gc//[^a-z]/}"
  $V -w -gc "$gc" -o "$bin" "$D/main.v" >/dev/null 2>&1 || { echo "gc=$gc jobs=$jobs BUILD FAILED"; return; }
  "$bin" "$jobs" 40 > "$D/out-$gc-$jobs.txt" 2>&1 &
  local pid=$!
  local waited=0
  while kill -0 $pid 2>/dev/null; do
    if [ $waited -ge $BUDGET ]; then
      # capture where it is stuck before killing
      sample $pid 1 -mayDie > "$D/sample-$gc-$jobs.txt" 2>/dev/null
      kill -9 $pid 2>/dev/null
      wait $pid 2>/dev/null
      echo "gc=$gc jobs=$jobs → HUNG (killed at ${BUDGET}s)"
      return
    fi
    sleep 1; waited=$((waited+1))
  done
  wait $pid 2>/dev/null
  echo "gc=$gc jobs=$jobs → $(tail -1 "$D/out-$gc-$jobs.txt")"
}

probe e 1
probe e 4
probe e 8
probe boehm 8
echo "--- where -gc e jobs=8 was stuck (if it hung) ---"
grep -aE "vgc_mark_roots|vgc_gc_start|os__fd_read|ulock_wait|pthread_join" "$D/sample-e-8.txt" 2>/dev/null | sed 's/^ *//' | sort | uniq -c | sort -rn | head -8
