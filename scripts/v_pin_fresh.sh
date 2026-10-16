#!/bin/sh
# scripts/v_pin_fresh.sh [<v-dir>] — rebuild the pinned V compiler when its binary is older
# than the compiler sources it sits beside.
#
# third_party/v/v is a BUILT artifact (untracked) of the third_party/v gitlink. A checkout
# that moves the gitlink (a fork bump merged into release/0.18) updates the SOURCES and
# leaves the binary as it was: every later recipe then compiles with the OLD compiler over
# the NEW vlib, and a fork fix that lives in the compiler (cgen, checker, builder) never
# reaches the build. The loop's checkout ran a 2026-09-24 binary under the fork pin
# 2c38b21acf on 2026-10-08, so cx-home/v#9's cgen fix (map[voidptr] key width on wasm32)
# was in the pinned source and absent from every wasm bundle the loop built: the loop's
# test-playground-mermaid / test-playground-wasm-traps aborted while every stream
# worktree (whose V was rebuilt by hand) was green (#1899).
#
# Staleness is `find -newer`: a compiler source (cmd/v, vlib/v; not _test.v, not
# testdata) newer than the binary. A checkout writes changed files with the checkout's
# mtime, so a gitlink move that touches the compiler is always seen; one that touches
# only other vlib modules needs no rebuild (user programs compile vlib from source). The rebuild is the fork's own `v self` into
# a side file, then an atomic rename over the binary, so a recipe already running keeps
# its inode and one starting mid-rebuild never finds the binary absent. The previous
# binary is kept as v_old. Callers serialize through scripts/tree_lock.cx (v-pin) and
# this script re-checks after the lock, so concurrent steps rebuild once.
#
# No binary, or no compiler sources beside it (a bare PATH v): nothing to do — the cx
# build's own guard (deps/cx-core-code/vcx/Makefile, P4) refuses or warns there.
set -u
VD=${1:-$(cd "$(dirname "$0")/.." && pwd)/third_party/v}
[ -x "$VD/v" ] && [ -d "$VD/cmd/v" ] && [ -d "$VD/vlib/v" ] || exit 0
newer=$(find "$VD/cmd/v" "$VD/vlib/v" -name '*.v' ! -name '*_test.v' ! -path '*/testdata/*' -newer "$VD/v" -print 2>/dev/null | head -1)
[ -n "$newer" ] || exit 0
echo "v-pin-fresh: rebuilding $VD/v (compiler source newer than the binary: ${newer#$VD/})"
cd "$VD" || exit 1
# vnew / v_old: names the fork's .gitignore already ignores (v self's own backup is
# v_old), so the rebuild leaves the submodule's status clean.
LOG=$(mktemp "${TMPDIR:-/tmp}/v-pin-fresh.XXXXXX")
rm -f vnew
if ./v self -o vnew >"$LOG" 2>&1 && [ -x vnew ] && ./vnew version >/dev/null 2>&1; then
  cp -p v v_old 2>/dev/null
  mv -f vnew v
  rm -f "$LOG"
  echo "v-pin-fresh: OK — $(./v version) rebuilt at $(git rev-parse --short=10 HEAD 2>/dev/null || echo '?')"
else
  echo "v-pin-fresh: FAILED — \`./v self\` in $VD did not produce a working compiler; log $LOG:" >&2
  tail -20 "$LOG" >&2
  rm -f vnew
  exit 1
fi
