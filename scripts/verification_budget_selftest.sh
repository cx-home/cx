#!/bin/sh
# verification_budget_selftest.sh (#1562, RULED: VCOST-1) — the fixture the
# decision asks for: "a planted over-budget timing that fails the step".
#
# Five properties, each by planting a timings file and reading the step's exit:
#
#   1. an IDLE measurement over its bound            → FAILS (exit 1)
#   2. a LOADED measurement over the same bound      → passes, ADVISORY
#   3. an idle measurement under its bound           → passes, ok
#   4. no measurement at all                         → passes, NOT MEASURED
#   5. a measurement with no `load` at all           → passes, treated as loaded
#
# (2) and (5) are the reason this can be a gate rather than a coin flip: the same
# `make fixtures` read 3,168 s and 2,898 s on one corpus hours apart because
# another agent had a core, so a number taken on a busy box judges nothing and
# must never red a run. (4) is the same discipline one step out — a gate that
# reds because nobody measured punishes the wrong run.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CX=${CX_BIN:-vcx/target/cx}
[ -x "$CX" ] || { echo "verification-budget self-test: no cx binary at $CX — build first"; exit 2; }

T=vcx/target/verification_timings.cxd
SAVED=""
if [ -f "$T" ]; then SAVED=$(mktemp); cp "$T" "$SAVED"; fi
restore() {
  if [ -n "$SAVED" ]; then cp "$SAVED" "$T"; rm -f "$SAVED"; else rm -f "$T"; fi
}
trap restore EXIT
mkdir -p "$(dirname "$T")"

fails=0
check() {
  want_exit="$1"; want_text="$2"; name="$3"; body="$4"
  if [ -z "$body" ]; then rm -f "$T"; else printf '%s\n' "$body" > "$T"; fi
  out=$("$CX" --allow-read --allow-write scripts/check_verification_budget.cx 2>&1)
  got=$?
  ok=1
  [ "$got" = "$want_exit" ] || ok=0
  case "$out" in *"$want_text"*) ;; *) ok=0 ;; esac
  if [ "$ok" = 1 ]; then
    echo "  ok   $name (exit $got, says '$want_text')"
  else
    echo "  FAIL $name — exit $got (want $want_exit), output:"
    printf '%s\n' "$out" | sed 's/^/        /'
    fails=$((fails + 1))
  fi
}

echo "verification-budget self-test (#1562):"

# 1 — the planted over-budget IDLE timing. The bound is 1200 s; 4000 s is over.
check 1 "OVER BOUND" "an idle measurement over its bound FAILS the step" \
'[verification-timings
  [timing name=fixture-grader seconds=4000 load=0.8 at=2026-09-18T11:00:00Z]]'

# 2 — the same number, taken on a loaded box: advisory, never failing.
check 0 "ADVISORY" "the same number on a LOADED box is advisory" \
'[verification-timings
  [timing name=fixture-grader seconds=4000 load=9.4 at=2026-09-18T11:00:00Z]]'

# 3 — within bound on an idle box.
check 0 "ok" "an idle measurement under its bound passes" \
'[verification-timings
  [timing name=fixture-grader seconds=900 load=0.7 at=2026-09-18T11:00:00Z]]'

# 4 — nothing measured.
check 0 "NOT MEASURED" "a bound with no measurement does not fail the step" ""

# 5 — a timing with no load: the fail-safe reading is LOADED.
check 0 "ADVISORY" "a measurement with no load is treated as loaded" \
'[verification-timings
  [timing name=union seconds=99999 at=2026-09-18T11:00:00Z]]'

if [ "$fails" -gt 0 ]; then
  echo "verification-budget self-test: $fails failure(s)"
  exit 1
fi
echo "verification-budget self-test OK — 5 properties"
