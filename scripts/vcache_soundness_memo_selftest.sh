#!/usr/bin/env bash
# vcache_soundness_memo_selftest.sh (cx-private#1903) — the fixture for scripts/vcache_soundness_memo.sh.
# A planted gate stands in for the real one: it counts its runs in a file and prints a verdict
# line. Each assertion reads the count after the call. A hit must not run the gate, and every
# reason to re-prove must run it.
set -u
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M="$SCRIPT_DIR/vcache_soundness_memo.sh"
W=$(mktemp -d "${TMPDIR:-/tmp}/vcache-memo-selftest.XXXXXX"); trap 'rm -rf "$W"' EXIT
export CX_VCACHE_MEMO_DIR="$W/store" CX_VCACHE_MEMO_KEY_EXTRA="selftest-$$-$RANDOM"
CNT="$W/count"; : > "$CNT"; export CNT
green() { bash "$M" memo-selftest sh -c 'echo ran >> "$CNT"; echo "vcache-soundness: sound=12 red=0 mutations=9 elapsed=1s"'; }
red()   { bash "$M" memo-selftest-red sh -c 'echo ran >> "$CNT"; echo "vcache-soundness: sound=11 red=1"; exit 1'; }
runs() { wc -l < "$CNT" | tr -d ' '; }
fails=0
check() { # $1 label  $2 expected runs  $3 expected rc  $4 rc  [$5 output must contain]
  local n; n=$(runs)
  if [ "$n" != "$2" ] || [ "$4" != "$3" ] || { [ -n "${5:-}" ] && ! grep -q -- "$5" "$W/out"; }; then
    echo "  FAIL $1: runs=$n (want $2) rc=$4 (want $3)${5:+, output wants '$5'}"; sed 's/^/        /' "$W/out" | tail -5; fails=$((fails + 1))
  else echo "  ok   $1"; fi
}
green > "$W/out"; check "a first green run runs the gate and records it" 1 0 $?
green > "$W/out"; check "the same inputs again HIT: the gate does not run, the recorded verdict and MEMO print" 1 0 $? 'MEMO'
grep -q '^vcache-soundness: sound=12 red=0' "$W/out" || { echo "  FAIL the hit does not reprint the recorded verdict line"; fails=$((fails + 1)); }
CX_VCACHE_MEMO=0 green > "$W/out"; check "CX_VCACHE_MEMO=0 forces a run" 2 0 $?
CX_VCACHE_MEMO_KEY_EXTRA=other green > "$W/out"; check "a changed key input re-proves" 3 0 $?
VFLAGS="-d planted_by_selftest" green > "$W/out"; check "a changed VFLAGS (V's own environment) re-proves" 4 0 $?
CC=/usr/bin/false green > "$W/out" 2>&1; check "a changed CC re-proves" 5 0 $?
sleep 1; CX_VCACHE_MEMO_MAX_AGE=0 green > "$W/out"; check "a record older than the age bound re-proves" 6 0 $?
red > "$W/out"; check "a red run exits red" 7 1 $?
red > "$W/out"; check "a red is never remembered: the second run runs again and is red again" 8 1 $?
CX_V=/nonexistent/v green > "$W/out"; check "an unkeyed run (no compiler) runs" 9 0 $?
CX_V=/nonexistent/v green > "$W/out"; check "and an unkeyed run never hits" 10 0 $?
if [ "$fails" -gt 0 ]; then echo "vcache-soundness memo self-test: $fails failure(s)"; exit 1; fi
echo "vcache-soundness memo self-test OK — a hit skips the gate, and the gate re-runs on every changed input, on MEMO=0, past the age bound, on red, and when unkeyed (cx-private#1903)"
