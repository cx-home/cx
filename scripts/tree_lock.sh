#!/bin/sh
# scripts/tree_lock.sh <name> <what> <command…> — one holder of a shared build tree per checkout.
#
# The post-merge flow runs each step as its own make on its own runner (#1817), so a
# prerequisite two steps share runs once per STEP, not once per run, and two steps that
# rebuild and then read the same tree race. scripts/docs_tree_lock.sh (docs/guide/ and
# site/) and the Makefile's wasm-bundle-fresh (dist/wasm/) take their lock here.
#
# The lock is a directory (mkdir is atomic) at vcx/target/<name>.lock in this checkout,
# so worktrees never wait on each other. It records the holder's pid; a holder whose
# pid is dead is stale and is broken by the next waiter. Re-entrant per lock: the
# command runs with the lock's path added to CX_TREE_LOCKS_HELD, and a nested call
# for a lock already held runs its command at once (site-check -> guide-render-gate ->
# guide). Waiting is bounded (TREE_LOCK_TIMEOUT seconds, default 3600; the docs
# wrapper also reads DOCS_TREE_LOCK_TIMEOUT); on timeout the wrapper exits 75 without
# running the command, naming the holder.
set -u
[ $# -gt 2 ] || { echo "tree-lock: usage: $0 <name> <what> <command…>" >&2; exit 64; }
NAME=$1; WHAT=$2; shift 2
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/vcx/target/$NAME.lock"

case ":${CX_TREE_LOCKS_HELD:-}:" in
  *":$LOCK:"*)
    if [ -d "$LOCK" ]; then "$@"; exit $?; fi ;;
esac

mkdir -p "$ROOT/vcx/target"
TIMEOUT=${TREE_LOCK_TIMEOUT:-3600}
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
    echo "$NAME-lock: waited ${TIMEOUT}s for $LOCK (held by pid ${holder:-?}: $(cat "$LOCK/cmd" 2>/dev/null || echo '?')); not running: $*" >&2
    exit 75
  fi
  if [ "$said" -eq 0 ]; then
    echo "$NAME-lock: waiting for pid ${holder:-?} ($(cat "$LOCK/cmd" 2>/dev/null || echo '?')) to leave $WHAT" >&2
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
CX_TREE_LOCKS_HELD="${CX_TREE_LOCKS_HELD:+$CX_TREE_LOCKS_HELD:}$LOCK" "$@"
rc=$?
exit $rc
