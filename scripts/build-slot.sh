#!/bin/sh
# scripts/build-slot.sh <command…> — the machine-wide RUNNER.
#
# Only one build, test step or pipeline run may execute on this box at a time: a
# full post-merge run is load-sensitive (false reds in the http/pty steps when
# anything else compiles), test steps bind fixed ports, and every worktree
# shares the V object cache in /tmp/v_$UID. Editing, reading and diagnosing are
# free and never wait; anything that COMPILES or RUNS TESTS goes through this
# wrapper:
#
#   scripts/build-slot.sh make test-changed
#   scripts/build-slot.sh devbox run -- make build-vcx-dev
#   scripts/build-slot.sh scripts/gate.sh            # holds the runner for the whole run
#
# The runner is a directory (mkdir is atomic) shared by every worktree:
# $CX_RUNNER (or its older spelling $CX_BUILD_SLOT), default
# ~/git-repos/cx/.build-slot — the PARENT of all cx worktrees, so a worktree's
# own copy of this script finds the same lock. The two variable names are
# synonyms; the directory names keep their old spelling until the rename step,
# because live pre-merge runs carry them in their commands.
# It records the holder's pid, command, cwd and start time. A holder whose pid
# is dead is stale and is broken by the next waiter. Waiting is bounded
# (BUILD_SLOT_TIMEOUT seconds, default 4 h) so a wait can never hang a run;
# on timeout the wrapper exits 75 (EX_TEMPFAIL) without running the command.
set -u
SLOT=${CX_RUNNER:-${CX_BUILD_SLOT:-"$HOME/git-repos/cx/.build-slot"}}
TIMEOUT=${BUILD_SLOT_TIMEOUT:-14400}
[ $# -gt 0 ] || { echo "runner: usage: $0 <command…>" >&2; exit 64; }

# FIFO: every waiter files a ticket; only the OLDEST live ticket may take the
# runner. Without this, waiters raced on mkdir every 15 s and one starved for an
# hour behind newer arrivals (measured 2026-09-08 02:29).
Q="$SLOT.queue"; mkdir -p "$Q"
ticket="$Q/$(date +%s).$$"; : > "$ticket"
trap 'rm -f "$ticket"' EXIT
waited=0
while :; do
	# drop tickets whose holder died
	for t in "$Q"/*; do
		[ -e "$t" ] || continue
		tp=${t##*.}; kill -0 "$tp" 2>/dev/null || rm -f "$t"
	done
	oldest=$(ls "$Q" 2>/dev/null | sort -t. -k1,1n -k2,2n | head -1)
	if [ "$Q/$oldest" = "$ticket" ] && mkdir "$SLOT" 2>/dev/null; then
		break
	fi
	holder=$(cat "$SLOT/pid" 2>/dev/null || echo "")
	if [ -d "$SLOT" ] && [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
		echo "runner: holder $holder is dead — breaking the stale lock" >&2
		rm -rf "$SLOT"
		continue
	fi
	if [ "$waited" -ge "$TIMEOUT" ]; then
		echo "runner: waited ${waited}s for $(cat "$SLOT/cmd" 2>/dev/null) (pid ${holder:-?}) — giving up" >&2
		exit 75
	fi
	[ "$waited" -eq 0 ] && echo "runner: waiting (queue position $(ls "$Q" | sort -t. -k1,1n -k2,2n | grep -n "^$(basename "$ticket")$" | cut -d: -f1)) — held by pid ${holder:-?}: $(cat "$SLOT/cmd" 2>/dev/null | cut -c1-80)" >&2
	sleep 15
	waited=$((waited + 15))
done
rm -f "$ticket"
echo "$$" > "$SLOT/pid"
printf '%s\n' "$*" > "$SLOT/cmd"
pwd > "$SLOT/cwd"
date -u +%FT%TZ > "$SLOT/since"
release() { rm -rf "$SLOT"; rm -f "$ticket"; }
trap 'release' EXIT
trap 'release; exit 143' TERM
trap 'release; exit 129' HUP
trap 'release; exit 130' INT

"$@"
exit $?
