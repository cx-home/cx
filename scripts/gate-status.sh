#!/bin/sh
# scripts/gate-status.sh — what is the gate doing right now, and for how long.
#
# A gate is 60-120 minutes of near-silence: `make` buffers, V runs under
# $(VQUIET) (`-n -w`, silent on success), and the -j12 storm's processes live
# 1-18 seconds each, so consecutive `ps` snapshots show almost entirely
# different pids. The honest reading of "CPUs pegged, nothing showing up" is
# that a snapshot is the wrong instrument. This prints the durable facts
# instead: which lane, how long, what has finished, and whether anything is red.
#
# Usage:  scripts/gate-status.sh            # once
#         scripts/gate-status.sh -w         # refresh every 30s until the verdict
set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LOG=${GATE_LOG:-"$ROOT/vcx/target/gate.log"}

show() {
	[ -f "$LOG" ] || { echo "no gate log at $LOG"; return 1; }

	verdict=$(grep -E '^GATE-EXIT=' "$LOG" | tail -1)
	# The WRAPPER only. `pgrep -f gate.sh` is too loose: a test lane's recipe
	# text mentions gate.sh, so the pattern matched a LANE and this script
	# reported the wrong pid (and, with `pgrep -f`, would also match itself —
	# the trap in feedback_background_wait_no_self_matching_pgrep). Match the
	# exact argv of the wrapper and take the ancestor, not a descendant.
	pid=$(ps -eo pid,args | awk '($2=="/bin/sh" || $2=="sh" || $2=="/bin/bash" || $2=="bash") && $3 ~ /gate\.sh$/ {print $1}' | head -1)
	[ -z "$pid" ] && pid=$(ps -eo pid,ppid,args \
		| awk '$4 ~ /gate\.sh$/ && $2==1 {print $1}' | head -1)

	started=$(grep -m1 '^gate: started' "$LOG" | sed 's/gate: started //')
	if [ -n "$started" ]; then
		# -u matters: the stamp is UTC and macOS `date -j -f` would otherwise
		# read it as local time, which is how this printed "-226m".
		s0=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$started" '+%s' 2>/dev/null \
		     || date -u -d "$started" '+%s' 2>/dev/null || echo '')
		[ -n "$s0" ] && elapsed=$(( $(date -u '+%s') - s0 )) || elapsed=''
	fi

	printf '── gate ──────────────────────────────────────────────\n'
	printf 'target   %s\n' "$(grep -m1 '^gate: ' "$LOG" | sed 's/gate: //')"
	if [ -n "$verdict" ]; then
		printf 'state    FINISHED  %s\n' "$verdict"
	elif [ -n "$pid" ]; then
		printf 'state    RUNNING   pid %s\n' "$pid"
	else
		printf 'state    GONE with no marker — the wrapper was SIGKILLed (only SIGKILL escapes the trap)\n'
	fi
	[ -n "${elapsed:-}" ] && printf 'elapsed  %sm %ss   (a full matrix is typically 60-120m)\n' \
		"$(( elapsed / 60 ))" "$(( elapsed % 60 ))"

	printf 'reds     %s FAIL line(s), %s make error(s)\n' \
		"$(grep -cE '^FAIL' "$LOG")" "$(grep -cE '^make: \*\*\*' "$LOG")"
	printf 'log      %s lines, %s\n' "$(grep -c '' "$LOG")" "$LOG"

	printf '\n── finished lanes ────────────────────────────────────\n'
	grep -E 'Summary for all V _test.v|passed, [0-9]+ failed|: [0-9]+ passed' "$LOG" \
		| tail -8 | sed 's/^/  /' | cut -c1-100
	[ -z "$(grep -E 'Summary for all V _test.v' "$LOG")" ] && printf '  (none yet — still building)\n'

	printf '\n── running now ───────────────────────────────────────\n'
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
		grep -qE '^GATE-EXIT=' "$LOG" && exit 0
		sleep 30
	done
fi
show
