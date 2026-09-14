#!/usr/bin/env bash
# fixtures_census.sh (#1448, RULED: 1448-a) — the stdlib census line, summed
# across the grader shards and printed ONCE.
#
# #1026 put this line in the tree so the eval lane STATES its coverage instead
# of leaving it inferred: the authz suite's 25 [out-err …] cases were long
# ASSUMED green here because they showed red under a document runner that has
# no evaluator. Every pre-merge RESULTS.md quotes the line, so 1448-a keeps its
# BYTE shape — only the printer moved. Each shard writes
# `vcx/target/fixtures/<shard>.census`; this sums them.
#
# It carries the two refusals the single-threaded walk made globally, and adds
# the one the split makes possible:
#   • zero fixtures ran over a non-empty corpus — the vacuous-pass shape;
#   • no fixture exercised the [out-err …] channel — the negative lane is dead;
#   • a shard the manifest names wrote NO census — that shard did not run, and
#     a total short by one shard is worse than no total, because it is believed.
set -euo pipefail
cd "$(dirname "$0")/.."
export LC_ALL=C

MANIFEST=conformance/fixture_shards.cxd
DIR=vcx/target/fixtures

[ -f "$MANIFEST" ] || { echo "fixtures-census: no $MANIFEST" >&2; exit 1; }

# The manifest documents its own row shape in a [doc [# … #]] block; drop the
# prose before reading the rows (see check_fixture_shard_manifest.sh).
shards=$(sed '/\[doc \[#/,/#\]\]/d' "$MANIFEST" \
  | grep -oE '^[[:space:]]*\[shard[[:space:]]+name=[^][:space:]]+' | sed -E 's/.*name=//')
[ -n "$shards" ] || { echo "fixtures-census: $MANIFEST names no shard" >&2; exit 1; }

missing=""
for s in $shards; do
  [ -f "$DIR/$s.census" ] || missing="$missing $s"
done
if [ -n "$missing" ]; then
  echo "fixtures-census: no census written by shard(s) —$missing" >&2
  echo "  that shard did not run; a total that silently omits a shard's cases is" >&2
  echo "  a census of a corpus nobody graded. Run 'make fixtures' (or the whole" >&2
  echo "  suite) and read that shard's own failure." >&2
  exit 1
fi

set -- $shards
files=0; ran=0; oer=0
for s in "$@"; do
  f=$(awk -F= '$1=="files"{print $2}' "$DIR/$s.census")
  r=$(awk -F= '$1=="ran"{print $2}' "$DIR/$s.census")
  e=$(awk -F= '$1=="out_err_ran"{print $2}' "$DIR/$s.census")
  files=$((files + ${f:-0})); ran=$((ran + ${r:-0})); oer=$((oer + ${e:-0}))
done

# Sorted BY KEY, not by the rendered `key=count` pair: the single-threaded
# walk sorted V string keys, where `xsp` precedes `xsp-auth` because it is a
# prefix, while sorting the pairs puts `xsp-auth=16` first ('-' 0x2D sorts
# before '=' 0x3D). The line is quoted verbatim in every pre-merge RESULTS.md,
# so that one transposition is a byte difference in evidence that is supposed
# to be comparable across the split.
parts=$(for s in "$@"; do grep '^module:' "$DIR/$s.census" || true; done \
  | sed 's/^module://' \
  | awk -F= '{c[$1]+=$2} END {for (k in c) printf "%s\t%s\n", k, c[k]}' \
  | sort -t"$(printf '\t')" -k1,1 \
  | awk -F'\t' '{printf "%s=%s ", $1, $2}')
parts=${parts% }

if [ "$files" -gt 0 ] && [ "$ran" -eq 0 ]; then
  echo "fixtures-census: $files module file(s) assigned but ZERO fixtures ran" >&2
  exit 1
fi
if [ "$ran" -gt 0 ] && [ "$oer" -eq 0 ]; then
  echo "fixtures-census: no fixture exercised the [out-err …] channel — the negative lane is not running" >&2
  exit 1
fi

echo "stdlib corpus: ${ran} fixtures ran across ${files} module file(s); ${oer} exercised the [out-err …] channel — ${parts}"
