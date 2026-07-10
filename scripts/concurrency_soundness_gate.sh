#!/bin/zsh
# #63/#58/#145 concurrency-soundness gate.
#
# Asserts the collector exhibits ZERO sweep-while-live under the multi-mutator
# stressors that reproduced the residual GC UAF — multi-reactor HTTP (CX_HTTP_N>=8)
# and concurrent [?worker] threads (the §10.4.6 DEFAULT; env pinned empty) — using the passive
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

# TWO builds, TWO independent signals — they must NOT be conflated (2026-07-01):
#   BIN  = -d vgc_passive -d vgc_nosweep detector → the bf1 ORACLE (masking-proof
#          sweep-while-live). CRASHES on this build are NOT counted: with sweep
#          disabled the reactor's per-request transients are never reclaimed, so the
#          big-string churn handler balloons RSS to multi-GB and OOMs — a DETECTOR
#          ARTIFACT that is memory-pressure-variable and has nothing to do with a UAF.
#          (This exact confound produced a false "#145 regressed" verdict on 06-30:
#          bf1=0 but crash=1..5 = pure nosweep-OOM.) Only 0xbf1 counts on BIN.
#   CRASHBIN = the REAL-SWEEP shipping collector (${GCMODE}, no nosweep). Real sweep +
#          the #131 churn-collect bound RSS, so a crash here is a GENUINE fault (UAF
#          segfault or a real OOM), not a nosweep artifact. Crashes counted on CRASHBIN.
BIN=${CX_SOUNDNESS_BIN:-}
if [ -z "$BIN" ]; then
  BIN=$ROOT/vcx/target/cx_soundness_gate
  echo "[gate] building bf1 detector: $GCMODE -d vgc_passive -d vgc_nosweep"
  ( cd $ROOT/vcx && ../third_party/v/v -n -w -cc cc ${=GCMODE} -d vgc_passive -d vgc_nosweep \
      -o target/cx_soundness_gate cmd/ ) || { echo "[gate] BUILD FAIL (detector)"; exit 2; }
fi
[ -x "$BIN" ] || { echo "[gate] no detector binary: $BIN"; exit 2; }

CRASHBIN=${CX_CRASH_BIN:-}
if [ -z "$CRASHBIN" ]; then
  CRASHBIN=$ROOT/vcx/target/cx_crash_gate
  echo "[gate] building real-sweep crash binary: $GCMODE (no nosweep)"
  ( cd $ROOT/vcx && ../third_party/v/v -n -w -cc cc ${=GCMODE} \
      -o target/cx_crash_gate cmd/ ) || { echo "[gate] BUILD FAIL (crash bin)"; exit 2; }
fi
[ -x "$CRASHBIN" ] || { echo "[gate] no crash binary: $CRASHBIN"; exit 2; }

# PER-STRESSOR logs (2026-07-01): a single shared log conflated the HTTP and
# worker stressors' bf1 counts — every catch was attributable to any of them, which
# mis-directed a whole investigation cycle (#145 "regressed" verdicts that were
# actually the #58 worker path). Each stressor now gets its own log + verdict line.
log_http=$(mktemp); log_churn=$(mktemp); log_workers=$(mktemp); log_mainloop=$(mktemp)
crash_http=0; crash_churn=0; crash_workers=0; crash_mainloop=0
cleanup() { pkill -9 -f "serve57|serve_churn_heavy|serve_mainloop|workers8|wrk -t12" 2>/dev/null; }
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
  CX_HTTP_N=8 "$BIN" --allow-all $FIX/serve57.cx >/dev/null 2>>$log_http &
  SRV=$!; bound=0
  for i in $(seq 1 20); do nc -z 127.0.0.1 $PORT 2>/dev/null && { bound=1; break; }; sleep 0.5; done
  if [ $bound -eq 1 ]; then wrk -t12 -c200 -d3s http://127.0.0.1:$PORT/ >/dev/null 2>&1; fi
  sleep 0.3
  kill -9 $SRV 2>/dev/null # crash NOT counted on the nosweep detector (OOM artifact) — see crash pass
done

# --- #145 churn-cadence multi-reactor HTTP (the PR #144 production config) ---
# Clone-heavy handler (many short string-keyed bindings) + CX_HTTP_GC_KB churn cadence at
# high reactor count — the configuration that historically reproduced the residual
# sweep-while-live. bf1 is the arbiter here; under -d vgc_nosweep this handler's big
# per-request strings are never reclaimed, so RSS balloons and it may OOM mid-round — that
# OOM is NOT counted (crash detection is the separate real-sweep pass below).
if command -v wrk >/dev/null 2>&1; then
  for r in $(seq 1 $ROUNDS); do
    cleanup; sleep 0.3
    CX_HTTP_N=$NREACT CX_HTTP_GC_KB=4 "$BIN" --allow-all $FIX/serve_churn_heavy.cx >/dev/null 2>>$log_churn &
    SRV=$!; bound=0
    for i in $(seq 1 30); do nc -z 127.0.0.1 $PORT 2>/dev/null && { bound=1; break; }; sleep 0.5; done
    if [ $bound -eq 1 ]; then wrk -t12 -c200 -d3s http://127.0.0.1:$PORT/ >/dev/null 2>&1; fi
    sleep 0.3
    kill -9 $SRV 2>/dev/null # crash NOT counted (nosweep-OOM) — see crash pass
  done
fi

# --- concurrent workers (the #58 worker stressor) — bf1 detection only ---
# Runs in the DEFAULT env (CX_WORKER_THREADS pinned empty = concurrent, the §10.4.6
# semantics — graduated once the #58-lineage UAF was fixed).
# workers8 = the high-power amplifier; workers4_20k asserts the default-adjacent
# concurrency level explicitly (soundness must hold at EVERY worker count —
# rarity at low N is detection power, not safety).
for r in $(seq 1 $ROUNDS); do
  CX_WORKER_THREADS= VGC_NEXT_GC_MB=4 VGC_PACE_MB=0 "$BIN" $FIX/workers8.cx >/dev/null 2>>$log_workers
  CX_WORKER_THREADS= VGC_NEXT_GC_MB=1 VGC_PACE_MB=0 "$BIN" $FIX/workers4_20k.cx >/dev/null 2>>$log_workers
done

# --- #57 FIELD SHAPE: DEFAULT-env multi-reactor serve + busy ALLOCATING MAIN thread ---
# No CX_HTTP_N / CX_WORKER_THREADS overrides: this is the stock posture the field
# workload (xap-marine) runs — reactors at the default fan-out plus the main thread
# evaluating an allocation-heavy loop. Multi-mutator by default; previously uncovered.
if command -v wrk >/dev/null 2>&1; then
  for r in $(seq 1 $ROUNDS); do
    cleanup; sleep 0.3
    VGC_NEXT_GC_MB=4 VGC_PACE_MB=0 "$BIN" --allow-all $FIX/serve_mainloop.cx >/dev/null 2>>$log_mainloop &
    SRV=$!; bound=0
    for i in $(seq 1 20); do nc -z 127.0.0.1 $PORT 2>/dev/null && { bound=1; break; }; sleep 0.5; done
    if [ $bound -eq 1 ]; then wrk -t12 -c200 -d3s http://127.0.0.1:$PORT/ >/dev/null 2>&1; fi
    sleep 0.3
    kill -9 $SRV 2>/dev/null # crash NOT counted on the nosweep detector — see crash pass
  done
fi

# ============================================================================
# CRASH-DETECTION PASS — on the REAL-SWEEP collector (CRASHBIN), where memory IS
# reclaimed, so a process death is a GENUINE fault (UAF segfault / real OOM), not the
# nosweep artifact above. bf1 output from this pass (if any) also counts (grep is over
# the shared $log). This pass is what makes crash>0 trustworthy.
# ============================================================================
crashlog_http=$(mktemp); crashlog_churn=$(mktemp); crashlog_mainloop=$(mktemp); crashlog_workers=$(mktemp)
run_serve_crash_rounds() { # fixf, n (empty = default fan-out), env_extra, crashlog; echoes crash count
  local fixf=$1 n=$2 env_extra=$3 clog=$4 cnt=0
  for r in $(seq 1 $ROUNDS); do
    cleanup; sleep 0.3
    env ${n:+CX_HTTP_N=$n} ${env_extra:+${=env_extra}} "$CRASHBIN" --allow-all $FIX/$fixf >/dev/null 2>>$clog &
    local SRV=$! bound=0
    for i in $(seq 1 30); do nc -z 127.0.0.1 $PORT 2>/dev/null && { bound=1; break; }; sleep 0.5; done
    [ $bound -eq 1 ] && wrk -t12 -c200 -d3s http://127.0.0.1:$PORT/ >/dev/null 2>&1
    sleep 0.3
    kill -0 $SRV 2>/dev/null || cnt=$((cnt+1))
    kill -9 $SRV 2>/dev/null
  done
  echo $cnt
}
if command -v wrk >/dev/null 2>&1; then
  crash_http=$(run_serve_crash_rounds serve57.cx 8 "" $crashlog_http)
  crash_churn=$(run_serve_crash_rounds serve_churn_heavy.cx $NREACT "CX_HTTP_GC_KB=4" $crashlog_churn)
  crash_mainloop=$(run_serve_crash_rounds serve_mainloop.cx "" "" $crashlog_mainloop)
fi
for r in $(seq 1 $ROUNDS); do
  CX_WORKER_THREADS= VGC_NEXT_GC_MB=4 VGC_PACE_MB=0 "$CRASHBIN" $FIX/workers8.cx >/dev/null 2>>$crashlog_workers
  [ $? -ne 0 ] && crash_workers=$((crash_workers+1))
  CX_WORKER_THREADS= VGC_NEXT_GC_MB=1 VGC_PACE_MB=0 "$CRASHBIN" $FIX/workers4_20k.cx >/dev/null 2>>$crashlog_workers
  [ $? -ne 0 ] && crash_workers=$((crash_workers+1))
done

# --- V-thread RETURN-BOX integrity (v4 addendum, STW-HARDENING-2026-07.md §8) ---
# A checksummed multi-worker allocate/discard loop at a forced high collection
# cadence. VALUE-INTEGRITY oracle: the exit->join return-box UAF recycles the
# swept box before the waiter reads it, so by read time the slot is usually
# REALLOCATED (alloc bit set, someone else's live data) — the bf1 detector,
# which watches freed-buffer reads, is structurally blind to it. Only the
# checksum sees the corruption (pre-fix: 6/6 rounds corrupt at this cadence on
# the pacer tree; 1/6 frequency-matched on the pre-pacer tree).
echo "[gate] building vthread-ret checksum stressor (plain ${GCMODE})"
RETBIN=$(mktemp -d)/hot_ret
VNOBUGREPORT=1 $ROOT/third_party/v/v ${=GCMODE} -o $RETBIN $ROOT/third_party/v/bench/parallel-alloc/hot_loop_rss/hot_loop_rss.v >/dev/null 2>&1 \
  || { echo "[gate] ABORT: vthread-ret stressor build failed"; exit 2; }
RET_EXPECT=298074064 # acc for 4 workers x 2,000,000 iterations (deterministic)
ret_corrupt=0
for r in $(seq 1 $ROUNDS); do
  out=$(VGC_NEXT_GC_MB=8 $RETBIN 4 2000000 2>/dev/null)
  case "$out" in
    *"acc=${RET_EXPECT} "*) ;;
    *) ret_corrupt=$((ret_corrupt+1)) ;;
  esac
done

# PER-STRESSOR verdicts: bf1 catches from the detector pass AND the real-sweep pass.
fail=0
echo "[gate] stressor=vthread-ret rounds=$ROUNDS checksum-corruptions=$ret_corrupt"
[ "$ret_corrupt" -ne 0 ] && { echo "[gate]   -> FAIL: thread-return-box result corruption (exit->join UAF; STW-HARDENING-2026-07.md §8)"; fail=1; }
for s in http churn mainloop workers; do
  eval "dlog=\$log_$s; clog=\$crashlog_$s; scrash=\$crash_$s"
  scatch=$(cat $dlog $clog 2>/dev/null | grep -c 'tag=0x[0-9a-f]*bf1 ')
  echo "[gate] stressor=$s rounds=$ROUNDS oracle-catches(0xbf1)=$scatch real-sweep-crashes=$scrash"
  [ "$scatch" -ne 0 ] && { echo "[gate]   -> FAIL: sweep-while-live UAF on the $s stressor (#63/#58/#145)"; fail=1; }
  [ "$scrash" -ne 0 ] && { echo "[gate]   -> FAIL: real-sweep crash on the $s stressor (genuine fault, not nosweep-OOM)"; fail=1; }
done
if [ $fail -ne 0 ]; then
  echo "[gate] CONCURRENCY-SOUNDNESS: FAIL"
  exit 1
fi
echo "[gate] CONCURRENCY-SOUNDNESS: PASS"
exit 0
