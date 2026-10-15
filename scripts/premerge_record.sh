#!/bin/bash
# premerge_record.sh (cx-private#1903) — every pinned repository's PRE-MERGE run, measured: for
# each deps/<repo> whose Makefile has a `check:` target, a fresh clone at its pin (origin = its
# GitHub URL, so its own deps-sync derives its pins' URLs as a stream clone does), then
# `make deps` + `make check CX_BIN=<this tree's cx>`, timed together. A GREEN run writes a
# `premerge-<repo>` row (seconds, load, at) to the timings file check-verification-budget judges
# (its `premerge-*` family bound: the median of each repository's last five). A red run writes
# nothing and is named: the repository's stream owns that red, and a wall cut short by a failure
# is not the run's wall.
#
#   bash scripts/premerge_record.sh          (or: make premerge-record)
#   PREMERGE_REPOS='cx-platform-net cx-core-code' PREMERGE_JOBS=4 bash scripts/premerge_record.sh
#   PREMERGE_ANY_LOAD=1 bash scripts/premerge_record.sh   (run over the load bound too)
#
# Exit 0 when it measured (whatever it found); 2 when it cannot run at all.
set -u
exec </dev/null # nothing here reads the caller's stdin; a stray read must not wait on the runner's
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT" || exit 2
. "$ROOT/scripts/verification_timings_lib.sh"
CX=${CX_BIN:-$ROOT/deps/cx-core-code/vcx/target/cx}
[ -x "$CX" ] || { echo "premerge-record: no cx at $CX — build first" >&2; exit 2; }
TIMINGS=${CX_VERIFICATION_TIMINGS:-$ROOT/vcx/target/verification_timings.cxd}
JOBS=${PREMERGE_JOBS:-4}
W=$(mktemp -d "${TMPDIR:-/tmp}/cx-premerge.XXXXXX"); trap 'rm -rf "$W"' EXIT
repos=${PREMERGE_REPOS:-$(for d in deps/*/; do d=${d%/}; grep -q '^check:' "$d/Makefile" 2>/dev/null && basename "$d"; done)}
# cx-private#1917: longest first — the JOBS slots pack best when the slowest repositories start
# first; order by each one's last recorded seconds (no row = 0, plan order kept among equals).
# On f834bf117 the step took 2,086 s and store alone ~413 s of it. PREMERGE_REPOS keeps its order.
if [ -z "${PREMERGE_REPOS:-}" ] && [ -r "$TIMINGS" ]; then
  repos=$(for r in $repos; do
    s=$(grep -oE "\[timing name=premerge-$r seconds=[0-9]+" "$TIMINGS" | tail -n 1 | sed 's/.*seconds=//')
    echo "${s:-0} $r"
  done | sort -s -k1,1nr | awk '{print $2}')
fi
# The load is sampled ONCE, at the record's start, and every row carries it (BUDGET-LOAD = (a),
# owner 2026-10-10: a row judges only at a load at or under 8). Sampled per repository it read
# the record's own JOBS slots: on 2026-10-10 08:10Z the first four repositories carried 3.92 and
# every later one 22-31 from its siblings alone, so the same quiet box judged four rows and
# refused thirteen. The union's row is sampled at RUN-START for the same reason.
RUN_LOAD=${PREMERGE_LOAD:-$(sample_load_1m)} # PREMERGE_LOAD: the self-test's planted load
# Over the load bound (CX_BENCH_MAX_LOAD, else 8) NOTHING runs (integrator, 2026-10-10 22:06Z, under
# BUDGET-LOAD = (a)): a row taken there is "not judged" by check-verification-budget anyway, and the
# runs were the loaded tick's wall (2,008 s on f25781f53 at load 82; 6,416 s with the 3c2523d22 stall).
# One line per repository says so and no timings row is written, so the quiet rows the budget judges
# stay as they were. Quiet ticks are unchanged. PREMERGE_ANY_LOAD=1 runs at any load (by hand).
if [ "${PREMERGE_ANY_LOAD:-0}" != 1 ] && ! awk -v l="$RUN_LOAD" -v b="${CX_BENCH_MAX_LOAD:-8}" \
     'BEGIN { exit !(l ~ /^[0-9.]+$/ && l + 0 <= b + 0) }'; then
  for r in $repos; do echo "  premerge-$r  not run (load $RUN_LOAD)"; done
  echo "premerge-record: not run (load $RUN_LOAD over the bound ${CX_BENCH_MAX_LOAD:-8}): 0 row(s) to $TIMINGS"
  exit 0
fi
# cx-private#1933: each repository gets the environment its own stream's pre-merge run has, so a
# red here is the repository's and never this script's: cx-core-data links cx's built RE2
# (RE2_DIR), the bindings load this tree's libcx (LIBCX_PATH, LIBCX_LIB_DIR), and cx-platform-db's
# `real` cases run on the cx built WITH the postgres/mysql engines (DB_REAL_CX, `make
# test-db-real`'s binary) when this tree has one — a plain cx carries no engines. On 9b5a5a9b9 these
# three were red inside the step and wrote no row.
RE2_DIR=${RE2_DIR:-$ROOT/third_party/re2}
LIBCX_LIB_DIR=${LIBCX_LIB_DIR:-$ROOT/deps/cx-core-code/vcx/target}
LIBCX_PATH=${LIBCX_PATH:-$(ls "$LIBCX_LIB_DIR"/libcx.dylib "$LIBCX_LIB_DIR"/libcx.so 2>/dev/null | head -n 1)}
DB_REAL_CX=${DB_REAL_CX:-$ROOT/deps/cx-core-code/vcx/target/cx-db-real}
cx_for() { # cx_for <repo> — the cx that repository's check runs on
  if [ "$1" = cx-platform-db ] && [ -x "$DB_REAL_CX" ]; then echo "$DB_REAL_CX"; else echo "$CX"; fi
}
one() { # one <repo> — prints `<repo> <rc> <seconds> <load>`
  r=$1; c="$W/$r"; x=$(cx_for "$r")
  git clone -q "$ROOT/deps/$r" "$c" 2>/dev/null && git -C "$c" remote set-url origin "https://github.com/cx-home/$r.git" \
    || { echo "$r clone-failed 0 0"; return; }
  l=$RUN_LOAD; s=$(date +%s)
  ( cd "$c" && make deps CX_BIN="$x" && make check CX_BIN="$x" RE2_DIR="$RE2_DIR" \
      LIBCX_PATH="$LIBCX_PATH" LIBCX_LIB_DIR="$LIBCX_LIB_DIR" ) > "$W/$r.log" 2>&1; rc=$?
  echo "$r $rc $(( $(date +%s) - s )) $l"
}
export -f one cx_for sample_load_1m; export W ROOT CX RUN_LOAD RE2_DIR LIBCX_PATH LIBCX_LIB_DIR DB_REAL_CX
results=$(printf '%s\n' $repos | xargs -P "$JOBS" -I{} bash -c 'one "$@"' _ {})
at=$(date -u +%FT%TZ); rec=0; red=''
# No here-string (cx-private#1917): on the loop's 3c2523d22 tick (2026-10-10 ~20:00Z) bash could not
# create the here-string's pipe ("cannot create temp file for here-document: No space left on
# device") after 76 min of checks; the step then printed nothing and used no CPU until the #1787
# stall kill 30 min later, and every row was lost. Splitting the variable needs no descriptor.
old_ifs=$IFS; IFS=$'\n'; set -f; lines=($results); IFS=$old_ifs; set +f
for line in "${lines[@]}"; do
  set -f; set -- $line; set +f; r=${1:-}; rc=${2:-}; secs=${3:-}; load=${4:-}
  [ -n "$r" ] || continue
  if [ "$rc" = 0 ]; then write_timing_row "$TIMINGS" "premerge-$r" "$secs" "$load" "$at"; rec=$((rec + 1)); echo "  premerge-$r  ${secs}s  load $load  recorded"
  else red="$red $r"; echo "  premerge-$r  ${secs}s  rc=$rc  NOT recorded (its check is red: tail below)"; tail -3 "$W/$r.log" 2>/dev/null | sed 's/^/      /'; fi
done
echo "premerge-record: $rec row(s) to $TIMINGS${red:+; red, not recorded:$red}"
