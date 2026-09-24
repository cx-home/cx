#!/usr/bin/env bash
# check_fixture_shard_manifest.sh (#1448, RULED: 1448-a) — the partition of the
# stdlib corpus across grader shards is COMPLETE and DISJOINT, or the step is
# red.
#
# 1448-a splits `deps/cx-core-code/vcx/tests/code_eval_fixtures_test.v`'s single-threaded walk
# over the module corpus into shard test files the V runner's parallel jobs
# carry. That buys 12–25 minutes off every run and introduces exactly one
# new failure mode: a module file assigned to NO shard is graded by nothing,
# while every step stays green. That is the vacuous-gate class this repo keeps
# paying for (#1127, #1134, #1180, #1209, #1212), and this guard is the answer
# to it — the same shape as `check-serial-retry-rosters`, which exists because
# a roster row naming a deleted file silently disabled its retry class.
#
# Five properties, each red-on-synthetic:
#   1. every corpus file the walk discovers is named by EXACTLY ONE shard. That
#      walk is the UNION #1427-c left behind: conformance/{stdlib,platform,x,
#      xap}/*.cxd, the ring-legible directories the specs sit in plus the `x/`
#      tier and the XAP suites;
#   2. so are the two files that belong to no ring directory — extended.cxd
#      (joined to this walk by #1379) and the Ring-0 codec suite xml_codec.cxd;
#   3. every [file name=…] row resolves to a file that EXISTS under
#      conformance/;
#   4. every [shard … test=…] row names a test file that EXISTS;
#   5. every deps/cx-core-code/vcx/tests/code_eval_fixtures_shard_*_test.v in the tree has a
#      manifest row — a shard file with no row grades nothing and passes.
#
# (macOS bash 3.2: no associative arrays — the sets are sorted text streams.)
set -euo pipefail
cd "$(dirname "$0")/.."

MANIFEST=deps/cx-core-code/vcx/tests/fixtures_grader/fixture_shards.cxd
[ -f "$MANIFEST" ] || { echo "check-fixture-shard-manifest: no $MANIFEST"; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/cx-shard-manifest.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
export LC_ALL=C

# Rows, as plain text. The manifest is CX, but these two shapes are all this
# guard reads, and reading them with grep keeps the guard runnable BEFORE a
# `cx` binary exists in the tree (it is a roster check, not a corpus step).
# The manifest's own [doc [# … #]] block SPELLS these two row shapes while
# explaining them, so the prose is dropped before the rows are read — a guard
# that reads its own documentation as data is a guard with a false row in it.
sed '/\[doc \[#/,/#\]\]/d' "$MANIFEST" > "$tmp/rows"
grep -oE '^[[:space:]]*\[shard[[:space:]]+name=[^][:space:]]+[[:space:]]+test=[^][:space:]]+' "$tmp/rows" \
  | sed -E 's/^[[:space:]]*\[shard[[:space:]]+name=//; s/[[:space:]]+test=/ /' > "$tmp/shards"
grep -oE '^[[:space:]]*\[file[[:space:]]+name=[^][:space:]]+' "$tmp/rows" \
  | sed -E 's/^[[:space:]]*\[file[[:space:]]+name=//' > "$tmp/assigned"

fail=0

# ── shard rows ──────────────────────────────────────────────────────────────
if [ ! -s "$tmp/shards" ]; then
  echo "check-fixture-shard-manifest: $MANIFEST names NO shard — a manifest that"
  echo "  partitions nothing would leave the whole stdlib corpus ungraded."
  exit 1
fi

dupnames=$(cut -d' ' -f1 "$tmp/shards" | sort | uniq -d)
if [ -n "$dupnames" ]; then
  echo "check-fixture-shard-manifest: shard name(s) declared twice —"
  for n in $dupnames; do echo "    $n"; done
  fail=1
fi

while read -r name test; do
  [ -n "$name" ] || continue
  if [ ! -f "$test" ]; then
    echo "check-fixture-shard-manifest: shard '$name' names test file '$test', which does not exist"
    fail=1
  fi
done < "$tmp/shards"

# ── property 5: every shard test file in the tree has a row ─────────────────
cut -d' ' -f2 "$tmp/shards" | sort > "$tmp/claimed_tests"
ls deps/cx-core-code/vcx/tests/code_eval_fixtures_shard_*_test.v 2>/dev/null | sort > "$tmp/tree_tests" || true
orphan_tests=$(comm -13 "$tmp/claimed_tests" "$tmp/tree_tests")
if [ -n "$orphan_tests" ]; then
  echo "check-fixture-shard-manifest: shard test file(s) with NO manifest row —"
  echo "  a shard whose name is not in the manifest grades nothing and passes:"
  for t in $orphan_tests; do echo "    $t"; done
  fail=1
fi

# ── properties 1–3: the assignment is complete, disjoint and resolvable ─────
# The manifest spells a corpus file the way the walk joins it: relative to
# conformance/, so `stdlib/ux.cxd`, `platform/flow.cxd`, and the two loose
# files by their own names.
sort "$tmp/assigned" > "$tmp/assigned_sorted"
dupfiles=$(uniq -d "$tmp/assigned_sorted")
if [ -n "$dupfiles" ]; then
  echo "check-fixture-shard-manifest: corpus file(s) assigned to MORE THAN ONE shard —"
  echo "  a case graded twice is counted twice in the census:"
  for f in $dupfiles; do echo "    $f"; done
  fail=1
fi

missing=""
while read -r f; do
  [ -n "$f" ] || continue
  if [ ! -f "conformance/$f" ]; then missing="$missing $f"; fi
done < "$tmp/assigned"
if [ -n "$missing" ]; then
  echo "check-fixture-shard-manifest: manifest row(s) naming a corpus file that does not exist —"
  for f in $missing; do echo "    conformance/$f"; done
  fail=1
fi

# The corpus the walk actually discovers — derived, never listed, so a NEW
# .cxd in any of these directories is unassigned the moment it lands. Kept in
# step with fixtures_grader's corpus_dirs / corpus_loose.
{
  for d in stdlib platform x xap; do
    for f in conformance/$d/*.cxd; do [ -e "$f" ] && echo "$d/$(basename "$f")"; done
  done
  echo "../deps/cx-core-data/conformance/extended.cxd"   # pinned (RULED: RS-12)
  echo "xml_codec.cxd"
} | sort > "$tmp/corpus"
uniq "$tmp/assigned_sorted" > "$tmp/assigned_uniq"

unassigned=$(comm -23 "$tmp/corpus" "$tmp/assigned_uniq")
if [ -n "$unassigned" ]; then
  echo "check-fixture-shard-manifest: corpus file(s) in NO shard —"
  echo "  a .cxd graded by nothing is a green that guards nothing. Add each to a"
  echo "  shard in $MANIFEST (and re-measure if the shard's budget is spent):"
  for f in $unassigned; do echo "    conformance/$f"; done
  fail=1
fi

[ "$fail" -eq 0 ] || exit 1
nshards=$(wc -l < "$tmp/shards" | tr -d ' ')
nfiles=$(wc -l < "$tmp/corpus" | tr -d ' ')
echo "check-fixture-shard-manifest OK — $nfiles corpus file(s) partitioned across $nshards shard(s), every one assigned exactly once"
