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
#   scripts/build-slot.sh make test                   # holds the runner for the whole run
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

# ── THE SHARED SLOT WAITS FOR THE LOOP'S GAP OUTSIDE ITSELF (#1749) ──────────
# `.build-slot-impl` is the ONE shared slot for load-sensitive steps (RULED:
# INT-8, D17a), and those run only in a gap of the post-merge loop: the last
# RUN line of the MAIN checkout's vcx/target/gate-loop.log a RUN-EXIT line,
# re-read immediately before each step (AGENT-STANDING-RULES 2026-09-24 rule
# 5). The wait belongs to the caller, BEFORE the slot is taken. Measured
# 2026-10-01 19:46Z–21:2xZ on dfc9f12f9: `sh scripts/build-slot.sh sh login.sh`
# held this slot while login.sh's first line waited `until … RUN-EXIT` on the
# loop's log; the loop's run needed the box quiet and the waiter slept until
# the run ended — neither could, for 95 minutes. So on the shared slot this
# wrapper REFUSES, exit 2, naming the RUN line and the rule — never a silent
# wait — (a) while that last RUN line is RUN-START, read on arrival and again
# the moment the slot is taken, and (b) for a command that is a shell reading
# the loop's log at all (`sh <file>` whose file names gate-loop.log, or
# `sh -c '<text naming it>'`, at any position of the argv: `devbox run -- sh
# pipeline.sh` is the same shape). Every other slot is untouched: the loop's
# own steps hold `.build-slot`, and an agent's own `.build-slot-<dir>` waits
# for nobody. CX_GATE_LOOP_LOG names the log (scripts/build_slot_selftest.cx
# plants one); by default it is the first row of `git worktree list`'s
# vcx/target/gate-loop.log. With no such file there is no loop to wait for.
shared_slot=0
[ "$(basename "$SLOT")" = ".build-slot-impl" ] && shared_slot=1
loop_log() {
	if [ -n "${CX_GATE_LOOP_LOG:-}" ]; then printf '%s' "$CX_GATE_LOOP_LOG"; return 0; fi
	_main=$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')
	[ -n "$_main" ] && printf '%s/vcx/target/gate-loop.log' "$_main"
}
refuse_1749() { # refuse_1749 <why>
	echo "runner: REFUSED (#1749) — $1" >&2
	echo "runner: the shared slot $SLOT is taken only in a gap of the post-merge loop: wait for RUN-EXIT in YOUR foreground \`until\` loop BEFORE taking it, never inside the slot-held command (AGENT-STANDING-RULES 2026-09-24 rule 5; RULED: INT-8, CXF-1, AGENTS-1)" >&2
	exit 2
}
# loop_running — 0 when the loop's last RUN line is RUN-START; it prints the line.
loop_running() {
	_log=$(loop_log)
	[ -n "$_log" ] && [ -f "$_log" ] || return 1
	_line=$(grep ' RUN-' "$_log" 2>/dev/null | tail -n 1)
	case "$_line" in
		*' RUN-START'*) printf '%s' "$_line"; return 0 ;;
	esac
	return 1
}
# reads_loop_log <argv…> — 0 when a shell in the argv reads the loop's log.
reads_loop_log() {
	_sh=0
	for _a in "$@"; do
		if [ "$_sh" -eq 1 ]; then
			case "$_a" in *gate-loop.log*) return 0 ;; esac
			if [ -f "$_a" ] && grep -q 'gate-loop\.log' "$_a" 2>/dev/null; then return 0; fi
		fi
		case "$(basename -- "$_a")" in
			sh|bash|zsh|dash|ksh) _sh=1 ;;
		esac
	done
	return 1
}
if [ "$shared_slot" -eq 1 ]; then
	if reads_loop_log "$@"; then
		refuse_1749 "the command is a shell that reads the post-merge loop's log ($(loop_log)); a wait for the loop inside the shared slot is the 2026-10-01 deadlock"
	fi
	if run_line=$(loop_running); then
		refuse_1749 "the post-merge loop is running: the last RUN line of $(loop_log) is \`$run_line\`"
	fi
fi

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
# the loop may have started while this waiter queued: read the line again now
# that the slot is held, and give it back rather than run inside a RUN-START.
if [ "$shared_slot" -eq 1 ] && run_line=$(loop_running); then
	rm -rf "$SLOT"
	refuse_1749 "the post-merge loop started while this command queued: the last RUN line of $(loop_log) is \`$run_line\`"
fi
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
