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
#
# ── $FIXTURE_FILES — the pre-merge SELECTION (#1513) ─────────────────────────
#
#     make fixtures FIXTURE_FILES="conformance/xap/xap-on.cxd conformance/platform/connector.cxd"
#
# grades ONLY the named corpus files, each through the shard that owns it,
# under the same flags and the same grader. The whole corpus is 91 module files
# and ~5,800 cases and took 15-35 minutes of every pre-merge run whatever the
# branch touched; a branch's own corpus files take about three.
#
# The rules, all of them mechanised below:
#   * a name is resolved against the manifest, spelled either way
#     (`conformance/platform/connector.cxd` or `platform/connector.cxd`);
#   * `conformance/code.cxd` names the DRIVER (code.cxd, the packages and the
#     four fast-path differs), which is otherwise skipped;
#   * a shard that owns none of the named files is not launched at all;
#   * a named file NO shard owns FAILS this step — never a silent skip, which
#     is the whole failure mode a selection introduces and the reason
#     `check-fixture-shard-manifest` exists one level up;
#   * the `stdlib corpus: …` census line is printed restricted to the graded
#     set, with one `FIXTURE-FILES=<list>` line above it so RESULTS.md states
#     what was graded rather than leaving it inferred (#1026's argument applied
#     to the selection).
#
# With $FIXTURE_FILES unset or empty NOTHING below changes: the driver and
# every shard run, and the census is the whole-corpus line. That is what the
# post-merge run and any branch touching the grader, vcx/code/, stdlib/*.cx or
# the V pin keep doing (INT-5, INT-21).
set -u
cd "$(dirname "$0")/.."
ROOT=$(pwd)

V=${V:-$ROOT/third_party/v/v}
FLAGS="-cc cc -gc e -d cx_db_sqlite -d cx_db_redis ${FIXTURE_VFLAGS:-}"
MANIFEST=vcx/tests/fixtures_grader/fixture_shards.cxd
OUT=vcx/target/fixtures
DRIVER=tests/code_eval_fixtures_test.v
SELECTION=${FIXTURE_FILES:-}

[ -f "$MANIFEST" ] || { echo "make fixtures: no $MANIFEST" >&2; exit 1; }

# The manifest documents its own row shapes inside a [doc [# … #]] block, so
# the prose is dropped before the rows are read — a reader that reads its own
# documentation as data has a false row in it (check_fixture_shard_manifest.sh
# makes the same cut). What comes out is one `<shard> <test> <file>` triple per
# [file] row, in manifest order.
OWNERS=$(sed '/\[doc \[#/,/#\]\]/d' "$MANIFEST" \
  | grep -oE '^[[:space:]]*\[(shard[[:space:]]+name=[^][:space:]]+[[:space:]]+test=[^][:space:]]+|file[[:space:]]+name=[^][:space:]]+)' \
  | sed -E 's/^[[:space:]]*\[//' \
  | awk '$1 == "shard" { sub(/^name=/, "", $2); sname = $2; sub(/^test=/, "", $3); stest = $3; next }
         $1 == "file"  { sub(/^name=/, "", $2); print sname, stest, $2 }')
[ -n "$OWNERS" ] || { echo "make fixtures: $MANIFEST names no shard" >&2; exit 1; }

# ── resolve the selection ───────────────────────────────────────────────────
want_driver=1
shard_tests=$(printf '%s\n' "$OWNERS" | awk '{ print $1, $2 }' | awk '!seen[$0]++ { print $2 }')
canon=""

if [ -n "$SELECTION" ]; then
  want_driver=0
  unowned=""
  for raw in $SELECTION; do
    # spelled either way; the manifest spells a file relative to conformance/
    rel=${raw#conformance/}
    if [ "$rel" = "code.cxd" ]; then
      want_driver=1
      continue
    fi
    if printf '%s\n' "$OWNERS" | awk -v f="$rel" '$3 == f { found = 1 } END { exit !found }'; then
      canon="$canon $rel"
    else
      unowned="$unowned $raw"
    fi
  done
  if [ -n "$unowned" ]; then
    echo "make fixtures: FIXTURE_FILES names corpus file(s) NO shard owns —" >&2
    for f in $unowned; do echo "    $f" >&2; done
    echo "  A name nothing grades must not pass quietly: that is the same vacuous" >&2
    echo "  shape check-fixture-shard-manifest refuses one level up. Spell the file" >&2
    echo "  the way $MANIFEST does (relative to conformance/, e.g." >&2
    echo "  platform/connector.cxd), name conformance/code.cxd for the driver, or" >&2
    echo "  add the file to a shard." >&2
    exit 1
  fi
  canon=${canon# }
  # only the shards that own a named file
  shard_tests=$(printf '%s\n' "$OWNERS" \
    | awk -v sel=" $canon " '{ if (index(sel, " " $3 " ")) print $1, $2 }' \
    | awk '!seen[$0]++ { print $2 }')
fi

# A stale census from an earlier run would be summed into this one, so the
# directory is rebuilt here — the same reason `skip-ledger-reset` truncates the
# skip ledger before the writers run. One file per shard, so no writer can lose
# another's line and none can race.
rm -rf "$OUT"
mkdir -p "$OUT"

# The driver first (it grades code.cxd, the packages and the four fast-path
# differs), then every shard the manifest names, in manifest order.
steps=""
[ "$want_driver" = 1 ] && steps="$DRIVER"
for t in $shard_tests; do
  steps="$steps ${t#vcx/}"
done
steps=${steps# }

if [ -n "$SELECTION" ]; then
  # The shards read their own intersection from here; the wrapper has already
  # refused every name no shard owns, so a shard finding an EMPTY intersection
  # is a disagreement about the partition and panics rather than passing.
  export CX_FIXTURE_FILES="$canon"
  # scripts/fixtures_census.sh sums the shards named here instead of every
  # shard in the manifest: under a selection an unlaunched shard writing no
  # census is the expected case, not the missing-shard refusal.
  printf '%s\n' "$OWNERS" \
    | awk -v sel=" $canon " '{ if (index(sel, " " $3 " ")) print $1 }' \
    | awk '!seen[$0]++' > "$OUT/.selected-shards"
  echo "FIXTURE-FILES=$SELECTION"
  if [ -z "$steps" ]; then
    echo "make fixtures: FIXTURE_FILES resolved to no step at all" >&2
    exit 1
  fi
fi

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
