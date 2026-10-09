#!/usr/bin/env bash
# vcache_soundness_memo.sh (cx-private#1903) — one SOUND verdict of the V module-cache proof per
# set of inputs, not one per run.
#
# WHY. check-vcache-soundness (scripts/vcache_soundness_gate.sh) is an adversarial proof of the V
# COMPILER's -usecache key. It builds its own fixtures in a fresh mktemp root and reads nothing of
# cx: no deps/, no vcx/, no libcx. Its verdict is a function of the compiler binary, the fork's
# vlib, the C toolchain, the environment V reads (VFLAGS, VMODULES, VCACHE, CC), the OS and the
# gate's own script. Yet every union and every landing gate re-proved it from scratch, and its
# self-test ran two more full gates concurrently: 158 s + 2 x 158 s of CPU per run (#1903's
# table on 715d2262a). The gate's own header says the cadence it belongs to is "whenever
# third_party/v changes".
#
# WHAT. `vcache_soundness_memo.sh <name> <command…>` hashes those inputs into a key. When a GREEN
# record for <name> under that key exists and is younger than CX_VCACHE_MEMO_MAX_AGE seconds
# (default 43200, 12 h), it prints the recorded verdict lines, says MEMO, and exits 0. Otherwise
# it runs the command. A green run records its verdict lines under the key. A red run records
# nothing and exits with the command's own code, so a red is re-proved every time, never
# remembered. The age bound re-proves on the clock as well: the one input the key cannot see is
# the state of the shared V cache directory, which is exactly what the gate's probes attack.
#
#   CX_VCACHE_MEMO=0          always run (and still record a green)
#   CX_VCACHE_MEMO_DIR=<dir>  record store (default ~/.cache/cx/vcache-soundness, shared by every
#                             checkout on the box, as the V cache itself is)
#   CX_VCACHE_MEMO_MAX_AGE=N  seconds
#   CX_VCACHE_MEMO_KEY_EXTRA  appended to the key (the memo's self-test uses it)
#
# The fork tree is part of the key through `git rev-parse HEAD` plus a hash of its tracked diff, so
# an edited vlib file misses even before a commit. An unreadable input (no git, no compiler) makes
# the key the literal word `unkeyed`, and an unkeyed run never hits.
set -u
NAME=${1:?usage: vcache_soundness_memo.sh <name> <command...>}; shift
[ $# -gt 0 ] || { echo "vcache_soundness_memo.sh: no command" >&2; exit 2; }
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$SCRIPT_DIR/.." && pwd)
V=${CX_V:-$REPO/third_party/v/v}
DIR=${CX_VCACHE_MEMO_DIR:-${HOME:-/tmp}/.cache/cx/vcache-soundness}
MAX_AGE=${CX_VCACHE_MEMO_MAX_AGE:-43200}

sha() { shasum -a 256 | cut -c1-64; }
filesha() { [ -r "$1" ] && shasum -a 256 < "$1" | cut -c1-64 || echo missing; }

key_inputs() {
  local vroot ccp
  vroot=$(cd "$(dirname "$V")" 2>/dev/null && pwd -P) || return 1
  [ -x "$V" ] || return 1
  echo "name $NAME"
  echo "v-binary $(filesha "$V")"
  echo "v-head $(git -C "$vroot" rev-parse HEAD 2>/dev/null)" ; git -C "$vroot" rev-parse HEAD >/dev/null 2>&1 || return 1
  echo "v-diff $(git -C "$vroot" diff HEAD 2>/dev/null | sha)"
  ccp=$(command -v "${CC:-cc}") || return 1
  echo "cc $ccp $(filesha "$ccp")"
  echo "cc-version $("$ccp" --version 2>&1 | sha)"
  echo "os $(uname -srm)"
  echo "env VFLAGS=${VFLAGS:-} VMODULES=${VMODULES:-} VCACHE=${VCACHE:-} CC=${CC:-} VEXE=${VEXE:-}"
  for f in "$SCRIPT_DIR/vcache_soundness_gate.sh" "$SCRIPT_DIR/vcache_soundness_selftest.sh" "$SCRIPT_DIR/vcache_soundness_memo.sh"; do
    echo "script $(basename "$f") $(filesha "$f")"
  done
  echo "extra ${CX_VCACHE_MEMO_KEY_EXTRA:-}"
  echo "argv $*"
}

if inputs=$(key_inputs "$@"); then KEY=$(printf '%s\n' "$inputs" | sha); else KEY=unkeyed; fi
REC="$DIR/$NAME-$KEY.rec"
now=$(date +%s)

if [ "${CX_VCACHE_MEMO:-1}" != 0 ] && [ "$KEY" != unkeyed ] && [ -r "$REC" ]; then
  at=$(sed -n 's/^at-epoch //p' "$REC" | head -1)
  if [ -n "$at" ] && [ $((now - at)) -le "$MAX_AGE" ]; then
    sed -n 's/^line //p' "$REC"
    echo "$NAME: MEMO — SOUND verdict recorded $(sed -n 's/^at //p' "$REC" | head -1) ($(( (now - at) / 60 )) min ago) for key ${KEY:0:16}: the compiler, the fork's vlib and diff, cc, the OS, V's environment and the gate's scripts are unchanged; re-proved after ${MAX_AGE} s or on any change (CX_VCACHE_MEMO=0 forces a run; cx-private#1903)"
    exit 0
  fi
fi

mkdir -p "$DIR" 2>/dev/null
OUT=$(mktemp "${TMPDIR:-/tmp}/vcache-memo.XXXXXX"); trap 'rm -f "$OUT" "$OUT.rec"' EXIT
"$@" 2>&1 | tee "$OUT"; rc=${PIPESTATUS[0]}
if [ "$rc" -eq 0 ] && [ "$KEY" != unkeyed ]; then
  {
    echo "at-epoch $now"; echo "at $(date -u +%FT%TZ)"; echo "key $KEY"
    grep -E '^PROBE|^vcache-soundness|^  ok |^  C ' "$OUT" | sed 's/^/line /'
    printf '%s\n' "$inputs" | sed 's/^/input /'
  } > "$OUT.rec" && mv -f "$OUT.rec" "$REC"
fi
exit "$rc"
