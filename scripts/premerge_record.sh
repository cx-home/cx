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
#
# Exit 0 when it measured (whatever it found); 2 when it cannot run at all.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT" || exit 2
. "$ROOT/scripts/verification_timings_lib.sh"
CX=${CX_BIN:-$ROOT/deps/cx-core-code/vcx/target/cx}
[ -x "$CX" ] || { echo "premerge-record: no cx at $CX — build first" >&2; exit 2; }
TIMINGS=${CX_VERIFICATION_TIMINGS:-$ROOT/vcx/target/verification_timings.cxd}
JOBS=${PREMERGE_JOBS:-4}
W=$(mktemp -d "${TMPDIR:-/tmp}/cx-premerge.XXXXXX"); trap 'rm -rf "$W"' EXIT
repos=${PREMERGE_REPOS:-$(for d in deps/*/; do d=${d%/}; grep -q '^check:' "$d/Makefile" 2>/dev/null && basename "$d"; done)}
one() { # one <repo> — prints `<repo> <rc> <seconds> <load>`
  r=$1; c="$W/$r"
  git clone -q "$ROOT/deps/$r" "$c" 2>/dev/null && git -C "$c" remote set-url origin "https://github.com/cx-home/$r.git" \
    || { echo "$r clone-failed 0 0"; return; }
  l=$(sample_load_1m); s=$(date +%s)
  ( cd "$c" && make deps CX_BIN="$CX" && make check CX_BIN="$CX" ) > "$W/$r.log" 2>&1; rc=$?
  echo "$r $rc $(( $(date +%s) - s )) $l"
}
export -f one sample_load_1m; export W ROOT CX
results=$(printf '%s\n' $repos | xargs -P "$JOBS" -I{} bash -c 'one "$@"' _ {})
at=$(date -u +%FT%TZ); rec=0; red=''
while read -r r rc secs load; do
  [ -n "$r" ] || continue
  if [ "$rc" = 0 ]; then write_timing_row "$TIMINGS" "premerge-$r" "$secs" "$load" "$at"; rec=$((rec + 1)); echo "  premerge-$r  ${secs}s  load $load  recorded"
  else red="$red $r"; echo "  premerge-$r  ${secs}s  rc=$rc  NOT recorded (its check is red: tail below)"; tail -3 "$W/$r.log" | sed 's/^/      /'; fi
done <<< "$results"
echo "premerge-record: $rec row(s) to $TIMINGS${red:+; red, not recorded:$red}"
