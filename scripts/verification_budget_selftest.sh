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
#   1. five QUIET rows (load <= 8) whose median is over the bound → FAILS (exit 1)
#   2. five quiet rows under it, one slow among them → passes, ok
#   3. five LOADED rows over the bound → passes, each "not judged (load N)"
#      (BUDGET-LOAD = (a), owner 2026-10-10: a loaded tick is recorded, never red)
#   4. loaded rows between quiet ones neither judge nor push the quiet ones out
#      of the median: five quiet under the bound among three loaded far over → ok
#   5. a measurement with no `load` at all → passes, "not judged (load ?)"
#   6. four quiet rows judge nothing yet; only the last five quiet count;
#      no measurement at all → NOT MEASURED; the premerge-* family per repository
#   7. with NO override the DEFAULT path is still what is read — the override
#      moves the path and nothing else
#   9. premerge-record over the load bound runs nothing: one "not run (load N)"
#      line per repository, exit 0, no timings row (integrator 2026-10-10 22:06Z)
#
# (3) and (5) are the reason this can be a gate rather than a coin flip: the same
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
  [timing name=fixture-grader seconds=4000 load=0.8 at=2026-10-09T10:00:00Z]
  [timing name=fixture-grader seconds=4000 load=3.4 at=2026-10-09T11:00:00Z]
  [timing name=fixture-grader seconds=4000 load=1.2 at=2026-10-09T12:00:00Z]
  [timing name=fixture-grader seconds=4000 load=8 at=2026-10-09T13:00:00Z]
  [timing name=fixture-grader seconds=4000 load=4.5 at=2026-10-09T14:00:00Z]]'

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

# 1 — the planted over-budget QUIET timing. The bound is 1200 s; the median is over.
# The #1903 rule: the median of a bound's last FIVE rows judges; BUDGET-LOAD = (a):
# only rows at a load at or under 8 (the #1450 bound) are among them.
check 1 "OVER BOUND" "five quiet rows whose median is over the bound FAIL the step" \
'[verification-timings
  [timing name=fixture-grader seconds=4000 load=0.8 at=2026-10-09T10:00:00Z]
  [timing name=fixture-grader seconds=1300 load=7.9 at=2026-10-09T11:00:00Z]
  [timing name=fixture-grader seconds=900 load=3.2 at=2026-10-09T12:00:00Z]
  [timing name=fixture-grader seconds=5000 load=8 at=2026-10-09T13:00:00Z]
  [timing name=fixture-grader seconds=1250 load=4.5 at=2026-10-09T14:00:00Z]]'

check 0 "ok" "five quiet rows whose median is under the bound pass, one slow run among them" \
'[verification-timings
  [timing name=fixture-grader seconds=900 load=3.1 at=2026-10-09T10:00:00Z]
  [timing name=fixture-grader seconds=4000 load=6.0 at=2026-10-09T11:00:00Z]
  [timing name=fixture-grader seconds=1000 load=2.4 at=2026-10-09T12:00:00Z]
  [timing name=fixture-grader seconds=800 load=1.9 at=2026-10-09T13:00:00Z]
  [timing name=fixture-grader seconds=1100 load=5.0 at=2026-10-09T14:00:00Z]]'

# 3 — BUDGET-LOAD = (a): the loaded tick. Five union rows far over the bound, every
# one taken over load 8 (the 2026-10-10 ticks read 6,189 s at load 55-110 beside
# 1,062 s at 1.9): recorded, reported "not judged (load N)", never red.
check 0 "not judged (load 26.92): 37m46s" "five LOADED rows over the bound are recorded, each reported not judged with its load, and never red the step" \
'[verification-timings
  [timing name=union seconds=6189 load=11.2 at=2026-10-10T12:26:10Z]
  [timing name=union seconds=5786 load=18.95 at=2026-10-10T14:04:52Z]
  [timing name=union seconds=2266 load=26.92 at=2026-10-10T14:45:18Z]
  [timing name=union seconds=4000 load=8.01 at=2026-10-10T15:18:55Z]
  [timing name=union seconds=9000 load=110 at=2026-10-10T16:00:00Z]]'

check 0 "median 15m0s of 5 quiet" "loaded rows among quiet ones neither judge nor push the quiet ones out of the median" \
'[verification-timings
  [timing name=union seconds=900 load=1.9 at=2026-10-10T08:00:00Z]
  [timing name=union seconds=9999 load=55 at=2026-10-10T09:00:00Z]
  [timing name=union seconds=1000 load=2.0 at=2026-10-10T10:00:00Z]
  [timing name=union seconds=800 load=3.0 at=2026-10-10T11:00:00Z]
  [timing name=union seconds=9999 load=90 at=2026-10-10T12:00:00Z]
  [timing name=union seconds=1100 load=1.5 at=2026-10-10T13:00:00Z]
  [timing name=union seconds=9999 load=26 at=2026-10-10T14:00:00Z]
  [timing name=union seconds=900 load=1.7 at=2026-10-10T15:00:00Z]]'

check 0 "not judged (load ?)" "a row with no load at all is loaded: reported not judged, never red" \
'[verification-timings
  [timing name=selected-run seconds=9999 at=2026-10-10T10:00:00Z]
  [timing name=selected-run seconds=9999 at=2026-10-10T11:00:00Z]
  [timing name=selected-run seconds=9999 at=2026-10-10T12:00:00Z]
  [timing name=selected-run seconds=9999 at=2026-10-10T13:00:00Z]
  [timing name=selected-run seconds=9999 at=2026-10-10T14:00:00Z]]'

check 0 "MEASURING" "four quiet rows judge nothing yet, however slow" \
'[verification-timings
  [timing name=union seconds=99999 load=1.0 at=2026-10-09T10:00:00Z]
  [timing name=union seconds=99999 load=1.0 at=2026-10-09T11:00:00Z]
  [timing name=union seconds=99999 load=1.0 at=2026-10-09T12:00:00Z]
  [timing name=union seconds=99999 load=1.0 at=2026-10-09T13:00:00Z]]'

check 1 "OVER BOUND" "only the LAST five quiet rows of a name count: old fast rows do not mask five slow ones" \
'[verification-timings
  [timing name=selected-run seconds=100 load=5 at=2026-10-09T10:00:00Z]
  [timing name=selected-run seconds=100 load=5 at=2026-10-09T11:00:00Z]
  [timing name=selected-run seconds=100 load=5 at=2026-10-09T12:00:00Z]
  [timing name=selected-run seconds=4000 load=5 at=2026-10-09T13:00:00Z]
  [timing name=selected-run seconds=4000 load=5 at=2026-10-09T14:00:00Z]
  [timing name=selected-run seconds=4000 load=5 at=2026-10-09T15:00:00Z]
  [timing name=selected-run seconds=4000 load=5 at=2026-10-09T16:00:00Z]
  [timing name=selected-run seconds=4000 load=5 at=2026-10-09T17:00:00Z]]'

check 0 "NOT MEASURED" "a bound with no measurement does not fail the step" ""

check 1 "premerge-cx-slow  bound 20m0s  median 25m0s" "the premerge-* family judges each repository on its own: one slow repository FAILS, its fast sibling reads ok" \
'[verification-timings
  [timing name=premerge-cx-fast seconds=30 load=4.0 at=2026-10-09T10:00:00Z]
  [timing name=premerge-cx-fast seconds=30 load=4.0 at=2026-10-09T11:00:00Z]
  [timing name=premerge-cx-fast seconds=30 load=4.0 at=2026-10-09T12:00:00Z]
  [timing name=premerge-cx-fast seconds=30 load=4.0 at=2026-10-09T13:00:00Z]
  [timing name=premerge-cx-fast seconds=30 load=4.0 at=2026-10-09T14:00:00Z]
  [timing name=premerge-cx-slow seconds=1500 load=4.0 at=2026-10-09T10:00:00Z]
  [timing name=premerge-cx-slow seconds=1500 load=4.0 at=2026-10-09T11:00:00Z]
  [timing name=premerge-cx-slow seconds=1500 load=4.0 at=2026-10-09T12:00:00Z]
  [timing name=premerge-cx-slow seconds=1500 load=4.0 at=2026-10-09T13:00:00Z]
  [timing name=premerge-cx-slow seconds=1500 load=4.0 at=2026-10-09T14:00:00Z]]'

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

# 7 — the WRITERS write where the step READS (#1562). The step reads its
#     TIMINGS-DEFAULT relative to the checkout; the fixture grader
#     (run_fixture_shards.sh's TIMINGS=$ROOT/…) and the post-merge verdict
#     (flows/private-acts.cx's pm-timings, <checkout>/…) must name that same
#     path, or a measurement lands where nothing judges it (the split moved
#     the grader's write under deps/cx-core-code/ and the step never saw it).
want=$(sed -n "s/^\[?const TIMINGS-DEFAULT '\(.*\)'\]$/\1/p" "$ROOT/scripts/check_verification_budget.cx")
grader=$(sed -n 's/^TIMINGS=\$ROOT\/\(.*\)$/\1/p' "$ROOT/scripts/run_fixture_shards.sh")
verdict=$(sed -n "s/.*pm-timings scope=private pure.*\[\$concat \$c '\/\(.*\)'\]\]$/\1/p" "$ROOT/flows/private-acts.cx")
if [ -n "$want" ] && [ "$grader" = "$want" ] && [ "$verdict" = "$want" ]; then
  echo "  ok   the fixture grader and the post-merge verdict write the file the step reads ($want)"
else
  echo "  FAIL the writers and the reader disagree — step reads '$want', the fixture grader writes '$grader', the post-merge verdict writes '$verdict'"
  fails=$((fails + 1))
fi

# 8 — the bounds are the owner's sentence: VCOST-1's fixture grader and
#     selected run <= 20 min, and #1903's (owner 2026-10-09) every pre-merge
#     run <= 20 min — the union is the cx-private one. A row may sit under it;
#     none may sit over it.
over=""
for pair in fixture-grader:1200 selected-run:1200 union:1200; do
  nm=${pair%%:*}; cap=${pair#*:}
  got=$(sed -n "s/.*\[bound name=$nm seconds=\([0-9][0-9]*\).*/\1/p" "$ROOT/scripts/verification_budget.cxd")
  if [ -z "$got" ] || [ "$got" -gt "$cap" ]; then over="$over $nm=${got:-missing}>$cap"; fi
done
if [ -z "$over" ]; then
  echo "  ok   every bound is within the owner's sentence (fixture grader, selected run and union 20 min)"
else
  echo "  FAIL bounds over the owner's sentence:$over"
  fails=$((fails + 1))
fi

# 9 — premerge-record runs nothing over the load bound (integrator 2026-10-10 22:06Z, under
#     BUDGET-LOAD = (a)): a planted load of 42 names each repository "not run (load 42)", exits 0
#     and writes no timings row; a planted quiet load (3.5) does run — a repository that does not
#     exist is cloned and named red — so the skip is the load's doing and nothing else's.
PM=$T/premerge_timings.cxd
out=$(PREMERGE_LOAD=42 PREMERGE_REPOS='cx-core-code cx-no-such-repo' CX_VERIFICATION_TIMINGS="$PM" CX_BIN="$CX" \
      bash "$ROOT/scripts/premerge_record.sh" 2>&1); got=$?
quiet=$(PREMERGE_LOAD=3.5 PREMERGE_REPOS='cx-no-such-repo' CX_VERIFICATION_TIMINGS="$PM" CX_BIN="$CX" \
      bash "$ROOT/scripts/premerge_record.sh" 2>&1)
if [ "$got" = 0 ] && [ ! -e "$PM" ] \
   && case "$out" in *"premerge-cx-core-code  not run (load 42)"*"premerge-cx-no-such-repo  not run (load 42)"*) true ;; *) false ;; esac \
   && case "$quiet" in *"rc=clone-failed"*) true ;; *) false ;; esac; then
  echo "  ok   premerge-record over the load bound runs nothing: each repository 'not run (load 42)', no row written; at load 3.5 it runs"
else
  echo "  FAIL premerge-record's load skip — exit $got (want 0), row file $( [ -e "$PM" ] && echo written || echo absent ), output:"
  printf '%s\n' "$out" "--- at load 3.5:" "$quiet" | sed 's/^/        /'
  fails=$((fails + 1))
fi

if [ "$fails" -gt 0 ]; then
  echo "verification-budget self-test: $fails failure(s)"
  exit 1
fi
echo "verification-budget self-test OK — 14 properties, all planted under $T (never the real timings path)"
