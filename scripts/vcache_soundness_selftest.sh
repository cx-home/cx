#!/bin/sh
# vcache_soundness_selftest.sh (#1675, RULED: RUN-1, AGENTS-1, CXF-8) — the
# fixture the decision asks for: two concurrent check-vcache-soundness runs
# must not collide.
#
# WHY IT EXISTS. scripts/vcache_soundness_gate.sh used to take WORK from a
# FIXED root, /tmp/cx-vcache-gate, shared by every invocation on the box.
# Measured on release/0.18 e29b5d153 (2026-09-26 14:38Z): the post-merge
# run's check-vcache-soundness collided with an agent's own selection running
# concurrently and had its h7 fixture rewritten mid-probe — `FATAL - mutate:
# no such file: /tmp/cx-vcache-gate/h7/mymod/extra.h` — turning a head that
# touched no build input red. Reproduced here (fixture before fix, #1675
# RESULTS.md): two gates started with `&` + `wait` against the OLD script,
# same fixed root, both ended in a FATAL collision, not a probe verdict.
#
# The fix gives WORK a per-run `mktemp -d` root, removed by an EXIT trap; this
# self-test is the fixture that proves it holds: it starts TWO full gates
# concurrently, each to its own log, and asserts BOTH end with the gate's own
# SOUND summary line and NEITHER log carries the collision's signature,
# `no such file`. Beside check-verification-budget-selftest's shape: every
# assertion is behavioural (the gate's own verdict line, read after the run),
# never a claim about which mechanism produced it.
#
# This runs the REAL gate twice — the full V-fork rebuild-and-probe battery,
# not a stub — so it is load-insensitive but not cheap; it belongs on the
# step's own build slot beside check-vcache-soundness, never the shared one.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LOG_A=$(mktemp "${TMPDIR:-/tmp}/vcache-selftest-a.XXXXXX")
LOG_B=$(mktemp "${TMPDIR:-/tmp}/vcache-selftest-b.XXXXXX")
trap 'rm -f "$LOG_A" "$LOG_B"' EXIT

echo "vcache-soundness self-test (#1675): two concurrent gates, each on its own per-run root"

bash scripts/vcache_soundness_gate.sh >"$LOG_A" 2>&1 &
PID_A=$!
bash scripts/vcache_soundness_gate.sh >"$LOG_B" 2>&1 &
PID_B=$!

wait "$PID_A"; RC_A=$?
wait "$PID_B"; RC_B=$?

fails=0

check_log() { # $1 label  $2 rc  $3 log
  label=$1; rc=$2; log=$3
  summary=$(grep '^vcache-soundness: sound=' "$log" || true)
  if [ "$rc" -ne 0 ] || [ -z "$summary" ]; then
    echo "  FAIL $label: exit $rc, summary='$summary'"
    tail -20 "$log" | sed 's/^/        /'
    fails=$((fails + 1))
    return
  fi
  case "$summary" in
    *" red=0 "*)
      echo "  ok   $label: SOUND ($summary)" ;;
    *)
      echo "  FAIL $label: not all-SOUND ($summary)"
      fails=$((fails + 1)) ;;
  esac
  if grep -q 'no such file' "$log"; then
    echo "  FAIL $label: log carries 'no such file' — the #1675 collision signature"
    fails=$((fails + 1))
  fi
}

check_log "gate A" "$RC_A" "$LOG_A"
check_log "gate B" "$RC_B" "$LOG_B"

# C — a failed probe build names its cause (#1660). The daily union on
# a300db043 red one probe, `po build1 FAILED` then `PROBE POISON: RED …
# observed='BUILD-REFUSED'`, and the log could not say why: every probe build
# ran `"$V" … >/dev/null 2>&1`, so the compiler's own refusal was discarded. A
# planted compiler that refuses every build with a known diagnostic must have
# that diagnostic in the gate's log, under the probe that failed.
echo "  C    a failed probe build keeps the compiler's own output (#1660)"
FAKE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/vcache-selftest-fakev.XXXXXX")
LOG_C=$(mktemp "${TMPDIR:-/tmp}/vcache-selftest-c.XXXXXX")
trap 'rm -f "$LOG_A" "$LOG_B" "$LOG_C"; rm -rf "$FAKE_DIR"' EXIT
printf '#!/bin/sh\necho "planted-v: refused this build (args: $*) - selftest C diagnostic" >&2\nexit 1\n' > "$FAKE_DIR/v"
chmod +x "$FAKE_DIR/v"
CX_V="$FAKE_DIR/v" bash scripts/vcache_soundness_gate.sh >"$LOG_C" 2>&1
if grep -q 'base build1 FAILED' "$LOG_C" && grep -q 'planted-v: refused this build' "$LOG_C"; then
  echo "  ok   C: the planted compiler's refusal is in the log beside 'base build1 FAILED'"
else
  echo "  FAIL C: the failed build's compiler output is not in the gate's log"
  grep -n 'FAILED' "$LOG_C" | head -5 | sed 's/^/        /'
  fails=$((fails + 1))
fi

if [ "$fails" -gt 0 ]; then
  echo "vcache-soundness self-test: $fails failure(s)"
  exit 1
fi
echo "vcache-soundness self-test OK — two concurrent runs, both SOUND, neither collided; a failed probe build keeps its compiler output (#1660)"
