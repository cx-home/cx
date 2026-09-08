#!/bin/sh
# scripts/build-slot.sh <command…> — the machine-wide BUILD SLOT.
#
# Only one build, test lane or gate may run on this box at a time: a full gate
# is load-sensitive (false reds in the http/pty lanes when anything else
# compiles), test lanes bind fixed ports, and every worktree shares the V object
# cache in /tmp/v_$UID. Editing, reading and diagnosing are free and never
# wait; anything that COMPILES or RUNS TESTS goes through this wrapper:
#
#   scripts/build-slot.sh make test-changed
#   scripts/build-slot.sh devbox run -- make build-vcx-dev
#   scripts/build-slot.sh scripts/gate.sh            # holds the slot for the whole gate
#
# The slot is a directory (mkdir is atomic) shared by every worktree:
# $CX_BUILD_SLOT, default ~/git-repos/cx/.build-slot — the PARENT of all cx
# worktrees, so a worktree's own copy of this script finds the same lock.
# It records the holder's pid, command, cwd and start time. A holder whose pid
# is dead is stale and is broken by the next waiter. Waiting is bounded
# (BUILD_SLOT_TIMEOUT seconds, default 4 h) so a wait can never hang a run;
# on timeout the wrapper exits 75 (EX_TEMPFAIL) without running the command.
set -u
SLOT=${CX_BUILD_SLOT:-"$HOME/git-repos/cx/.build-slot"}
TIMEOUT=${BUILD_SLOT_TIMEOUT:-14400}
[ $# -gt 0 ] || { echo "build-slot: usage: $0 <command…>" >&2; exit 64; }

waited=0
while :; do
	if mkdir "$SLOT" 2>/dev/null; then
		break
	fi
	holder=$(cat "$SLOT/pid" 2>/dev/null || echo "")
	if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
		echo "build-slot: holder $holder is dead — breaking the stale slot" >&2
		rm -rf "$SLOT"
		continue
	fi
	if [ "$waited" -ge "$TIMEOUT" ]; then
		echo "build-slot: waited ${waited}s for $(cat "$SLOT/cmd" 2>/dev/null) (pid ${holder:-?}) — giving up" >&2
		exit 75
	fi
	[ "$waited" -eq 0 ] && echo "build-slot: waiting — held by pid ${holder:-?}: $(cat "$SLOT/cmd" 2>/dev/null | cut -c1-80)" >&2
	sleep 15
	waited=$((waited + 15))
done

echo "$$" > "$SLOT/pid"
printf '%s\n' "$*" > "$SLOT/cmd"
pwd > "$SLOT/cwd"
date -u +%FT%TZ > "$SLOT/since"
release() { rm -rf "$SLOT"; }
trap 'release' EXIT
trap 'release; exit 143' TERM
trap 'release; exit 129' HUP
trap 'release; exit 130' INT

"$@"
exit $?
