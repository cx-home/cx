#!/bin/sh
# scripts/docs_tree_lock.sh <command…> — one writer of docs/guide/ and site/ per checkout.
#
# `make guide` removes and rewrites docs/guide/, and site_assemble.cx removes and
# copies site/. guide-render-gate, site-check, site-index-check (docs-check's
# prerequisite) and the site/guide renders each render the tree and then READ it.
# Inside one `make -j` the shared prerequisite runs once; the post-merge flow runs
# each step as its own make on its own runner (#1817), so on 73a02bbd4 three renders
# overlapped: guide-render-gate (19:13:12Z) found docs/guide/index.html gone after
# its own render exited 0 — site-check's render (19:13:17Z) had removed it.
#
# The lock is a directory (mkdir is atomic) under this checkout's vcx/target/, so
# worktrees never wait on each other. It records the holder's pid; a holder whose
# pid is dead is stale and is broken by the next waiter. Re-entrant: the command
# runs with CX_DOCS_TREE_LOCK set to the lock's path, and a nested call that sees
# its own lock held runs its command at once (site-check -> guide-render-gate ->
# guide). Waiting is bounded (DOCS_TREE_LOCK_TIMEOUT seconds, default 3600); on
# timeout the wrapper exits 75 without running the command, naming the holder.
set -u
[ $# -gt 0 ] || { echo "docs-tree-lock: usage: $0 <command…>" >&2; exit 64; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/vcx/target/docs-tree.lock"

if [ "${CX_DOCS_TREE_LOCK:-}" = "$LOCK" ] && [ -d "$LOCK" ]; then
  "$@"
  exit $?
fi

mkdir -p "$ROOT/vcx/target"
TIMEOUT=${DOCS_TREE_LOCK_TIMEOUT:-3600}
waited=0
said=0
while ! mkdir "$LOCK" 2>/dev/null; do
  holder="$(cat "$LOCK/pid" 2>/dev/null || true)"
  if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
    rm -rf "$LOCK"
    continue
  fi
  if [ -z "$holder" ] && [ "$waited" -ge 10 ]; then
    # a lock dir with no pid file for 10 s: its maker died between mkdir and write
    rm -rf "$LOCK"
    continue
  fi
  if [ "$waited" -ge "$TIMEOUT" ]; then
    echo "docs-tree-lock: waited ${TIMEOUT}s for $LOCK (held by pid ${holder:-?}: $(cat "$LOCK/cmd" 2>/dev/null || echo '?')); not running: $*" >&2
    exit 75
  fi
  if [ "$said" -eq 0 ]; then
    echo "docs-tree-lock: waiting for pid ${holder:-?} ($(cat "$LOCK/cmd" 2>/dev/null || echo '?')) to leave docs/guide/ and site/" >&2
    said=1
  fi
  sleep 1
  waited=$((waited + 1))
done
echo $$ > "$LOCK/pid"
echo "$*" > "$LOCK/cmd"
trap 'rm -rf "$LOCK"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
CX_DOCS_TREE_LOCK="$LOCK" "$@"
rc=$?
exit $rc
