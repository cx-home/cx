#!/bin/sh
# verification_budget_selftest.sh (#1562, RULED: VCOST-1; issue 1582, RULED:
# RUN-5) — the fixture the decision asks for: "a planted over-budget timing that
# fails the step".
#
# ── WHERE IT PLANTS (issue 1582) ─────────────────────────────────────────────
#
# It used to plant its cases at vcx/target/verification_timings.cxd — the REAL
# path — while `check-verification-budget` ran beside it in the same -j storm.
# An over-bound idle row planted by this self-test and read by the step next to
# it reds a union on a measurement nobody took, and a test that writes what
# another step is reading is a test of neither. Now:
#
#   * every case is planted under one `mktemp -d`;
#   * the step runs in a MIRROR directory (a real vcx/target/ and a symlink to
#     the repo's scripts/), so even the cases that exercise the DEFAULT path
#     write inside the temporary tree and never in the checkout;
#   * the path is chosen with $CX_VERIFICATION_TIMINGS, which is why the step
#     takes `--allow-env`.
#
# ── THE PROPERTIES ───────────────────────────────────────────────────────────
#
#   0. an over-bound file at the DEFAULT path is NOT read when the override
#      names an empty file                          → passes, NOT MEASURED
#   1. an IDLE measurement over its bound            → FAILS (exit 1)
#   2. a LOADED measurement over the same bound      → passes, ADVISORY
#   3. an idle measurement under its bound           → passes, ok
#   4. no measurement at all                         → passes, NOT MEASURED
#   5. a measurement with no `load` at all           → passes, treated as loaded
#   6. with NO override the DEFAULT path is still what is read — the override
#      moves the path and nothing else
#
# (2) and (5) are the reason this can be a gate rather than a coin flip: the same
# `make fixtures` read 3,168 s and 2,898 s on one corpus hours apart because
# another agent had a core, so a number taken on a busy box judges nothing and
# must never red a run. (4) is the same discipline one step out — a gate that
# reds because nobody measured punishes the wrong run.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CX=${CX_BIN:-deps/cx-core-code/vcx/target/cx}
[ -x "$CX" ] || { echo "verification-budget self-test: no cx binary at $CX — build first"; exit 2; }
CX="$(cd "$(dirname "$CX")" && pwd)/$(basename "$CX")"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# The mirror: the step's two relative inputs resolve here, so the DEFAULT
# timings path is $M/vcx/target/verification_timings.cxd and the bounds are the
# repo's own file through the symlink.
M=$T/mirror
mkdir -p "$M/vcx/target"
ln -s "$ROOT/scripts" "$M/scripts"
DEFAULT_PATH=$M/vcx/target/verification_timings.cxd

OVER_BOUND='[verification-timings
  [timing name=fixture-grader seconds=4000 load=0.8 at=2026-09-18T11:00:00Z]]'

fails=0

run_step() { # $1 = CX_VERIFICATION_TIMINGS, or '' to leave it unset
  if [ -n "$1" ]; then
    ( cd "$M" && CX_VERIFICATION_TIMINGS="$1" \
        "$CX" --allow-read --allow-write --allow-env scripts/check_verification_budget.cx ) 2>&1
  else
    ( cd "$M" && "$CX" --allow-read --allow-write --allow-env scripts/check_verification_budget.cx ) 2>&1
  fi
}

n=0
check() { # want_exit want_text name body  — body planted at the OVERRIDE path
  want_exit="$1"; want_text="$2"; name="$3"; body="$4"
  n=$((n + 1))
  P=$T/timings_$n.cxd
  if [ -z "$body" ]; then rm -f "$P"; else printf '%s\n' "$body" > "$P"; fi
  out=$(run_step "$P")
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

echo "verification-budget self-test (#1562, issue 1582):"

# The over-bound row sits at the DEFAULT path for EVERY case below. If the
# override were ignored — which is what issue 1582 is about — case 0 and cases
# 2-5 would all read it and fail.
printf '%s\n' "$OVER_BOUND" > "$DEFAULT_PATH"

# 0 — the fixture for issue 1582: the override wins over the default path.
: > "$T/empty.cxd"
out=$(run_step "$T/empty.cxd"); got=$?
if [ "$got" = 0 ] && case "$out" in *"NOT MEASURED"*) true ;; *) false ;; esac; then
  echo "  ok   an over-bound file at the DEFAULT path is not read when the override names an empty file (exit 0, NOT MEASURED)"
else
  echo "  FAIL the override did not displace the default path — exit $got (want 0), output:"
  printf '%s\n' "$out" | sed 's/^/        /'
  fails=$((fails + 1))
fi

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

# 6 — with the override UNSET the default path is read exactly as before, so the
#     row still sitting there fails the step. The override moves the path and
#     changes no verdict.
out=$(run_step ''); got=$?
if [ "$got" = 1 ] && case "$out" in *"OVER BOUND"*) true ;; *) false ;; esac; then
  echo "  ok   with no override the DEFAULT path is still what is read (exit 1, OVER BOUND)"
else
  echo "  FAIL the default path was not read with the override unset — exit $got (want 1), output:"
  printf '%s\n' "$out" | sed 's/^/        /'
  fails=$((fails + 1))
fi

if [ "$fails" -gt 0 ]; then
  echo "verification-budget self-test: $fails failure(s)"
  exit 1
fi
echo "verification-budget self-test OK — 7 properties, all planted under $T (never the real timings path)"
