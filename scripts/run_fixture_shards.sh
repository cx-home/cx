#!/bin/sh
# run_fixture_shards.sh (#1448, RULED: 1448-a) — the ONE-COMMAND form of the
# fixture grader, preserved across the shard split.
#
# Before 1448-a a pre-merge pipeline graded the corpus with one line:
#
#     cd vcx && ../third_party/v/v -cc cc -gc e -d cx_db_sqlite -d cx_db_redis \
#         tests/code_eval_fixtures_test.v
#
# and read the census off its stdout. The corpus is now graded by the driver
# plus the shard files named in vcx/tests/fixtures_grader/fixture_shards.cxd, so this script
# is that line: it runs all of them IN PARALLEL under the same flags, prints
# each one's output in manifest order (so a log is deterministic, not
# interleaved), and prints the aggregated census line last. `make fixtures` is
# its make-visible name.
#
# The flags are the pipelines' flags, not the Makefile's: `-d cx_db_sqlite -d
# cx_db_redis` is what keeps db.cxd's cases 010-023 from failing by
# construction. Extra flags (e.g. `-d cx_grader_ids`) are appended from
# $FIXTURE_VFLAGS.
set -u
cd "$(dirname "$0")/.."
ROOT=$(pwd)

V=${V:-$ROOT/third_party/v/v}
FLAGS="-cc cc -gc e -d cx_db_sqlite -d cx_db_redis ${FIXTURE_VFLAGS:-}"
MANIFEST=vcx/tests/fixtures_grader/fixture_shards.cxd
OUT=vcx/target/fixtures

[ -f "$MANIFEST" ] || { echo "make fixtures: no $MANIFEST" >&2; exit 1; }

# A stale census from an earlier run would be summed into this one, so the
# directory is rebuilt here — the same reason `skip-ledger-reset` truncates the
# skip ledger before the writers run. One file per shard, so no writer can lose
# another's line and none can race.
rm -rf "$OUT"
mkdir -p "$OUT"

# The driver first (it grades code.cxd, the packages and the four fast-path
# differs), then every shard the manifest names, in manifest order.
steps="tests/code_eval_fixtures_test.v"
for t in $(sed '/\[doc \[#/,/#\]\]/d' "$MANIFEST" \
             | grep -oE '^[[:space:]]*\[shard[[:space:]]+name=[^][:space:]]+[[:space:]]+test=[^][:space:]]+' \
             | sed -E 's/.*test=//'); do
  steps="$steps ${t#vcx/}"
done

pids=""
for s in $steps; do
  log="$OUT/$(basename "$s" .v).out"
  ( cd vcx && "$V" $FLAGS "$s" ) > "$log" 2>&1 &
  pids="$pids $!:$s"
done

st=0
for p in $pids; do
  pid=${p%%:*}; step=${p#*:}
  if ! wait "$pid"; then
    echo "make fixtures: FAILED $step"
    st=1
  fi
done

for s in $steps; do
  log="$OUT/$(basename "$s" .v).out"
  echo "──── $s ────"
  cat "$log"
done

# The census is the evidence, so it prints even when a shard failed — a run
# that graded 4,000 of 5,000 cases should say which 4,000.
sh scripts/fixtures_census.sh || st=1
exit $st
