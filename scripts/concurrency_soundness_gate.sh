#!/bin/zsh
# #63/#58 concurrency-soundness gate.
#
# Asserts the collector exhibits ZERO sweep-while-live under the two multi-mutator
# stressors that previously reproduced #63 — multi-reactor HTTP (CX_HTTP_LOOPS=8)
# and concurrent [?worker] threads (CX_WORKER_THREADS=1) — using the passive
# detector ORACLE (tag 0xbf1 = a freed map-key buffer read in map_clone_string),
# plus a crash count. The oracle is masking-proof: a freed-buffer read is caught
# deterministically regardless of timing, so 0 catches means no sweep-while-live
# occurred (not that it was raced away). FAILS (exit 1) on any catch or crash.
#
# The cooperative-safepoint collector is the DEFAULT (-gc e); -d vgc_legacy_stw reverts
# to the old unsound mach-suspend collector. So the default detector build IS safepoint;
# this gate guards against a regression of that default (and proves the legacy path is
# still the unsound one).
#
# Usage:
#   scripts/concurrency_soundness_gate.sh                       # builds + tests the shipping default
#   CX_SOUNDNESS_BIN=vcx/target/cx_legacy_det scripts/...        # test a prebuilt detector binary
#   CX_GC='-gc e -d vgc_legacy_stw' scripts/...                  # exercise the legacy collector (expect FAIL)
#   SOUNDNESS_ROUNDS=20 scripts/...                             # override round count
set -u
ROUNDS=${SOUNDNESS_ROUNDS:-15}
ROOT=${0:A:h:h}
FIX=$ROOT/vcx/tests/soundness
GCMODE=${CX_GC:-"-gc e"}
PORT=9031

BIN=${CX_SOUNDNESS_BIN:-}
if [ -z "$BIN" ]; then
  BIN=$ROOT/vcx/target/cx_soundness_gate
  echo "[gate] building detector binary: $GCMODE -d vgc_passive -d vgc_nosweep"
  ( cd $ROOT/vcx && ../third_party/v/v -n -w -cc cc ${=GCMODE} -d vgc_passive -d vgc_nosweep \
      -o target/cx_soundness_gate cmd/ ) || { echo "[gate] BUILD FAIL"; exit 2; }
fi
[ -x "$BIN" ] || { echo "[gate] no binary: $BIN"; exit 2; }

log=$(mktemp); crashes=0
cleanup() { pkill -9 -f "serve57|workers8|wrk -t12" 2>/dev/null; }
trap cleanup EXIT

# --- multi-reactor HTTP (the #63 reactor stressor) ---
# Needs `wrk` for load. If absent, skip the HTTP stressor (the worker stressor below
# still exercises the multi-mutator UAF) rather than false-fail.
if ! command -v wrk >/dev/null 2>&1; then
  echo "[gate] WARNING: wrk not found — skipping HTTP stressor, running worker stressor only"
  ROUNDS_HTTP=0
else
  ROUNDS_HTTP=$ROUNDS
fi
for r in $(seq 1 $ROUNDS_HTTP); do
  cleanup; sleep 0.3
  CX_HTTP_LOOPS=8 "$BIN" --allow-all $FIX/serve57.cx >/dev/null 2>>$log &
  SRV=$!; bound=0
  for i in $(seq 1 20); do nc -z 127.0.0.1 $PORT 2>/dev/null && { bound=1; break; }; sleep 0.5; done
  if [ $bound -eq 1 ]; then wrk -t12 -c200 -d3s http://127.0.0.1:$PORT/ >/dev/null 2>&1; fi
  sleep 0.3
  kill -0 $SRV 2>/dev/null || crashes=$((crashes+1))
  kill -9 $SRV 2>/dev/null
done

# --- concurrent workers (the #58 worker stressor) ---
for r in $(seq 1 $ROUNDS); do
  CX_WORKER_THREADS=1 VGC_NEXT_GC_MB=4 "$BIN" $FIX/workers8.cx >/dev/null 2>>$log
  [ $? -ne 0 ] && crashes=$((crashes+1))
done

catches=$(grep -c 'tag=0x[0-9a-f]*bf1 ' $log 2>/dev/null)
echo "[gate] concurrency-soundness: rounds=$ROUNDS/stressor  oracle-catches(0xbf1)=$catches  crashes=$crashes"
if [ "$catches" -ne 0 ] || [ "$crashes" -ne 0 ]; then
  echo "[gate] CONCURRENCY-SOUNDNESS: FAIL (sweep-while-live detected — #63/#58 regression)"
  exit 1
fi
echo "[gate] CONCURRENCY-SOUNDNESS: PASS"
exit 0
