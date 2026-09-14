#!/bin/sh
# scripts/gate-status.sh — what the post-merge run is doing right now, and for
# how long. The words are the delivery grammar's
# (spec/03-approved/process/delivery-grammar.md §4): run, step, passed, failed,
# cancelled. The file name stays gate-status.sh until the rename step.
#
# A post-merge run is 60-120 minutes of near-silence: `make` buffers, V runs
# under $(VQUIET) (`-n -w`, silent on success), and the -j12 storm's processes
# live 1-18 seconds each, so consecutive `ps` snapshots show almost entirely
# different pids. The honest reading of "CPUs pegged, nothing showing up" is
# that a snapshot is the wrong instrument. This prints the durable facts
# instead: which step, how long, what has finished, and whether anything failed.
#
# Both marker spellings are read: RUN-EXIT= is what gate.sh writes now,
# GATE-EXIT= is what the logs already on disk carry.
#
# Usage:  scripts/gate-status.sh            # once
#         scripts/gate-status.sh -w         # refresh every 30s until the status
set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LOG=${GATE_LOG:-"$ROOT/vcx/target/gate.log"}

show() {
	[ -f "$LOG" ] || { echo "no run log at $LOG"; return 1; }

	marker=$(grep -E '^(RUN|GATE)-EXIT=' "$LOG" | tail -1)
	# the exit code alone, so the status word can be derived for a log written
	# before gate.sh printed one.
	code=$(printf '%s' "$marker" | sed -E 's/^(RUN|GATE)-EXIT=([0-9]+).*/\2/')
	case "$code" in
		'')            state='' ;;
		0)             state=passed ;;
		129|130|143)   state=cancelled ;;
		*)             state=failed ;;
	esac

	# The WRAPPER only. `pgrep -f gate.sh` is too loose: a test step's recipe
	# text mentions gate.sh, so the pattern matched a STEP and this script
	# reported the wrong pid (and, with `pgrep -f`, would also match itself —
	# the trap in feedback_background_wait_no_self_matching_pgrep). Match the
	# exact argv of the wrapper and take the ancestor, not a descendant.
	pid=$(ps -eo pid,args | awk '($2=="/bin/sh" || $2=="sh" || $2=="/bin/bash" || $2=="bash") && $3 ~ /gate\.sh$/ {print $1}' | head -1)
	[ -z "$pid" ] && pid=$(ps -eo pid,ppid,args \
		| awk '$4 ~ /gate\.sh$/ && $2==1 {print $1}' | head -1)

	started=$(grep -m1 -E '^(run|gate): started' "$LOG" | sed -E 's/^(run|gate): started //')
	if [ -n "$started" ]; then
		# -u matters: the stamp is UTC and macOS `date -j -f` would otherwise
		# read it as local time, which is how this printed "-226m".
		s0=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$started" '+%s' 2>/dev/null \
		     || date -u -d "$started" '+%s' 2>/dev/null || echo '')
		[ -n "$s0" ] && elapsed=$(( $(date -u '+%s') - s0 )) || elapsed=''
	fi

	printf '── post-merge run ────────────────────────────────────\n'
	printf 'target   %s\n' "$(grep -m1 -E '^(run|gate): ' "$LOG" | sed -E 's/^(run|gate): //')"
	if [ -n "$state" ]; then
		printf 'state    %s   marker %s\n' "$state" "$marker"
	elif [ -n "$pid" ]; then
		printf 'state    running   pid %s\n' "$pid"
	else
		printf 'state    gone with no marker — the wrapper was SIGKILLed (only SIGKILL escapes the trap)\n'
	fi
	[ -n "${elapsed:-}" ] && printf 'elapsed  %sm %ss   (a full post-merge run is typically 60-120m)\n' \
		"$(( elapsed / 60 ))" "$(( elapsed % 60 ))"

	printf 'log      %s lines, %s\n' "$(grep -c '' "$LOG")" "$LOG"

	printf '\n── failing steps ─────────────────────────────────────\n'
	# `make: *** [<target>] Error N` names the STEP. Deduplicated, because a
	# serial retry reports the same step twice.
	failing=$(grep -oE '^make(\[[0-9]+\])?: \*\*\* \[[^]]+\]' "$LOG" \
		| sed -E 's/.*\[//; s/\]$//' | sort -u)
	if [ -n "$failing" ]; then
		printf '%s\n' "$failing" | sed 's/^/  /'
	else
		printf '  (none)\n'
	fi
	printf '  %s FAIL line(s), %s make error(s) in the log\n' \
		"$(grep -cE '^FAIL' "$LOG")" "$(grep -cE '^make(\[[0-9]+\])?: \*\*\*' "$LOG")"

	printf '\n── finished steps ────────────────────────────────────\n'
	# The fallback keys on THIS pattern, not on the V-test summary alone: a DOC
	# run (`make test-docs`, RULED: INT-10) compiles no V test, so keying on
	# 'Summary for all V _test.v' printed "still building" under a doc run that
	# had already finished all seven of its steps.
	SUMMARIES='Summary for all V _test.v|passed, [0-9]+ failed|: [0-9]+ passed'
	grep -E "$SUMMARIES" "$LOG" | tail -8 | sed 's/^/  /' | cut -c1-100
	[ -z "$(grep -E "$SUMMARIES" "$LOG")" ] && printf '  (none yet — still building)\n'

	printf '\n── steps running now ─────────────────────────────────\n'
	n=$(ps -eo args | grep -cE 'third_party/v/v |clang|/cc |[a-z_]+_test$')
	printf '  %s compiler/test processes alive; load %s\n' \
		"$n" "$(uptime | sed 's/.*averages*:* *//')"
	ps -eo etime,args | grep -E '[/]third_party/v/v ' | sort | tail -3 \
		| sed 's/^/  /' | cut -c1-100
	printf '\n'
}

if [ "${1:-}" = "-w" ]; then
	while :; do
		clear 2>/dev/null || true
		show || exit 1
		grep -qE '^(RUN|GATE)-EXIT=' "$LOG" && exit 0
		sleep 30
	done
fi
show
