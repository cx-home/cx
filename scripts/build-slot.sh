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
#
# ── READING AN EXIT STATUS THROUGH THIS WRAPPER (#1570) ──────────────────────
# Read it DIRECTLY from the command word, or from INSIDE the script devbox runs:
#
#   scripts/build-slot.sh devbox run -- vcx/target/cx p.cx   # then $? is real
#   run() { "$@" > "$log" 2>&1; echo "EXIT=$?"; }            # inside pipeline.sh
#
# NEVER from an inner shell that `devbox run` wraps. Measured on 5a897f485
# against a program that exits 7: the direct read and the in-script capture both
# report 7; the inner-shell probe reports 0 — success, for a program that
# failed. `devbox run` executes its arguments through a generated
# .devbox/gen/scripts/.cmd.sh and the inner command's status is lost there,
# while a bare `exit N` in the same position survives, which is what made the
# trap so hard to see. It cost a wrong prio:high issue (#1569, withdrawn).
# scripts/exit_status_probe_gate.sh is the step that holds this line.
set -u
SLOT=${CX_RUNNER:-${CX_BUILD_SLOT:-"$HOME/git-repos/cx/.build-slot"}}
# The command we run must be able to see WHICH runner it is holding: the
# Makefile's check-gate-lock exempts a step held by a pre-merge runner
# (RULED: INT-1). Export the resolved directory under the CX_BUILD_SLOT
# spelling whichever spelling the caller used. CX_RUNNER is deliberately NOT
# exported — the Makefile already uses that name for the cx binary that
# test-code-diagram drives.
export CX_BUILD_SLOT="$SLOT"
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
