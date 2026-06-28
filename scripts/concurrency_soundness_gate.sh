#!/bin/zsh
# #63/#58/#145 concurrency-soundness gate.
#
# Asserts the collector exhibits ZERO sweep-while-live under the multi-mutator
# stressors that reproduced the residual GC UAF — multi-reactor HTTP (CX_HTTP_N>=8)
# and concurrent [?worker] threads (CX_WORKER_THREADS=1) — using the passive
# detector ORACLE (tag 0xbf1 = a freed map-key buffer read in map_clone_string),
# plus a crash count. The oracle is masking-proof: a freed-buffer read is caught
# deterministically at the use site regardless of timing, so 0 catches means no
# sweep-while-live occurred (not that it was raced away). FAILS (exit 1) on any
# catch or crash.
#
# CRITICAL (#145): the ORACLE LIVES IN THE FORK (third_party/v) under -d vgc_passive
# -d vgc_nosweep. If the fork lacks the instrument, V compiles those defines as no-op
# bools and the 0xbf1 grep can NEVER match — a HOLLOW gate that only checks crashes
# (this was the state before #145; prior "0/40 oracle" claims were measured against a
# diagnostic fork branch, not the shipping fork). The build step below ABORTS if the
# detector binary does not actually contain the oracle (canary check), so the gate can
# never silently regress to hollow again.
#
# The #145 churn-cadence stressor (serve_churn_heavy.cx, CX_HTTP_GC_KB) exercises the
# PR #144 production collection cadence (collect on allocation churn, far more frequent
# than the old request-count default) at high reactor count — the configuration that is
# the #145 acceptance criterion. Until the multi-reactor vgc residual is fixed, this
# stressor FAILS on the shipping binary BY DESIGN (it is catching a real, reproduced UAF
# — see memory project_issue145_multireactor_verify.md); single-reactor (CX_HTTP_N=1) is
# verified sound and is the interim production posture.
#
# The cooperative-safepoint collector is the DEFAULT (-gc e); -d vgc_legacy_stw reverts
# to the old mach-suspend collector. BOTH reproduce the #145 residual (it is vgc-common,
# not cooperative-specific); boehm is clean.
#
# Usage:
#   scripts/concurrency_soundness_gate.sh                       # builds + tests the shipping default
#   CX_SOUNDNESS_BIN=vcx/target/cx_legacy_det scripts/...        # test a prebuilt detector binary
#   CX_GC='-gc e -d vgc_legacy_stw' scripts/...                  # exercise the legacy collector
#   SOUNDNESS_ROUNDS=20 scripts/...                             # override round count
#   SOUNDNESS_N=24 scripts/...                                  # override reactor count for churn stressor
set -u
ROUNDS=${SOUNDNESS_ROUNDS:-15}
NREACT=${SOUNDNESS_N:-16}
ROOT=${0:A:h:h}
FIX=$ROOT/vcx/tests/soundness
GCMODE=${CX_GC:-"-gc e"}
PORT=9031

# ANTI-HOLLOW CANARY (#145): the masking-proof oracle lives in the fork. If the fork
# does not actually contain it, the -d vgc_passive define is a no-op and 0xbf1 can never
# fire — the gate would PASS vacuously. Refuse to run in that state.
if ! grep -q 'fn vgc_uaf_check_buf' $ROOT/third_party/v/vlib/builtin/vgc_d_vgc.c.v 2>/dev/null; then
  echo "[gate] ABORT: fork (third_party/v) lacks the passive oracle (vgc_uaf_check_buf)."
  echo "[gate] The -d vgc_passive build would be HOLLOW (0xbf1 can never match). Port the"
  echo "[gate] oracle into the shipping fork first (see #145). Refusing to run a vacuous gate."
  exit 2
fi

BIN=${CX_SOUNDNESS_BIN:-}
if [ -z "$BIN" ]; then
  BIN=$ROOT/vcx/target/cx_soundness_gate
  echo "[gate] building detector binary: $GCMODE -d vgc_passive -d vgc_nosweep"
  ( cd $ROOT/vcx && ../third_party/v/v -n -w -cc cc ${=GCMODE} -d vgc_passive -d vgc_nosweep \
      -o target/cx_soundness_gate cmd/ ) || { echo "[gate] BUILD FAIL"; exit 2; }
fi
[ -x "$BIN" ] || { echo "[gate] no binary: $BIN"; exit 2; }

log=$(mktemp); crashes=0
cleanup() { pkill -9 -f "serve57|serve_churn_heavy|workers8|wrk -t12" 2>/dev/null; }
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
  CX_HTTP_N=8 "$BIN" --allow-all $FIX/serve57.cx >/dev/null 2>>$log &
  SRV=$!; bound=0
  for i in $(seq 1 20); do nc -z 127.0.0.1 $PORT 2>/dev/null && { bound=1; break; }; sleep 0.5; done
  if [ $bound -eq 1 ]; then wrk -t12 -c200 -d3s http://127.0.0.1:$PORT/ >/dev/null 2>&1; fi
  sleep 0.3
  kill -0 $SRV 2>/dev/null || crashes=$((crashes+1))
  kill -9 $SRV 2>/dev/null
done

# --- #145 churn-cadence multi-reactor HTTP (the PR #144 production config) ---
# Clone-heavy handler (many short string-keyed bindings) + CX_HTTP_GC_KB churn cadence
# at high reactor count = the configuration that reproduces the residual sweep-while-live
# at ~80% per-round rate (N=24). This is the #145 ACCEPTANCE TEST: it FAILS on the current
# shipping binary by design (real reproduced UAF) and will PASS only when the vgc residual
# is fixed. Single-reactor (CX_HTTP_N=1) is verified sound (interim production posture).
if command -v wrk >/dev/null 2>&1; then
  for r in $(seq 1 $ROUNDS); do
    cleanup; sleep 0.3
    CX_HTTP_N=$NREACT CX_HTTP_GC_KB=4 "$BIN" --allow-all $FIX/serve_churn_heavy.cx >/dev/null 2>>$log &
    SRV=$!; bound=0
    for i in $(seq 1 30); do nc -z 127.0.0.1 $PORT 2>/dev/null && { bound=1; break; }; sleep 0.5; done
    if [ $bound -eq 1 ]; then wrk -t12 -c200 -d3s http://127.0.0.1:$PORT/ >/dev/null 2>&1; fi
    sleep 0.3
    kill -0 $SRV 2>/dev/null || crashes=$((crashes+1))
    kill -9 $SRV 2>/dev/null
  done
fi

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
