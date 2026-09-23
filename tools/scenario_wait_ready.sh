#!/bin/sh
# tools/scenario_wait_ready.sh <url> <server-pid> [bound-seconds] [server-log]
#
# Wait until a platform scenario's server ANSWERS, or say loudly why it never
# did. #1477.
#
# THE DEFECT THIS EXISTS FOR. The sso deployment scenario's `run.sh` waited
# for `/health` in a loop of 100 × 0.2 s and then simply FELL THROUGH — the
# loop had no failure arm. So on the post-merge run of `bc9bfd24c` (2026-09-14,
# 15-minute load average 69, five pre-merge pipelines on two runners beside the
# -j block) the deployment had not bound inside 20 s, the loop ended, and the
# scenario went on to curl a socket nobody was listening on. Every request
# answered `status=000` and the transcript disagreed with `expected.txt` in
# nineteen places. The run reported a broken example; what had actually
# happened was that a wait gave up in silence.
#
# Two things are wrong with that loop and both are fixed here:
#
#   1. NO FAILURE ARM. A readiness wait that times out must FAIL, naming the
#      url, the bound, the load average and the server's own log. A transcript
#      of `status=000` is the least diagnosable output this harness can
#      produce, and it is what a silent give-up guarantees.
#   2. THE BOUND WAS A GUESS AT AN IDLE BOX. 20 s is generous when nothing else
#      is running and is not enough to boot and bind a freshly linked binary on
#      a twelve-core box at load 69. The bound here is 120 s, the same order as
#      the profile gate's own case bound, and it is a variable
#      (CX_SCENARIO_READY_SECONDS) rather than a literal buried in a loop.
#
# It polls every 0.2 s and returns the moment the url answers, so the cost on an
# idle box is unchanged — a bound is not a delay.
#
# It also stops waiting the instant the server DIES, which the old loop did do
# and which is kept: a dead server is answered in milliseconds, not in 120 s.
#
# Exit 0 when the url answers; 1 when the server died at boot or the bound
# passed. On failure it prints the diagnosis and, when given, the server's log.
set -u

URL=${1:?usage: scenario_wait_ready.sh <url> <server-pid> [bound-seconds] [server-log]}
SRV=${2:?usage: scenario_wait_ready.sh <url> <server-pid> [bound-seconds] [server-log]}
BOUND=${3:-${CX_SCENARIO_READY_SECONDS:-120}}
LOG=${4:-}

load_1m() {
	if l=$(sysctl -n vm.loadavg 2>/dev/null) && [ -n "$l" ]; then
		printf '%s\n' "$l" | awk '{ gsub(/[{}]/, ""); print $1 + 0 }'
		return 0
	fi
	[ -r /proc/loadavg ] && awk '{ print $1 + 0 }' /proc/loadavg && return 0
	printf '%s\n' unknown
}

# 0.2 s per turn, so the turn count is five per second of the bound.
turns=$(( BOUND * 5 ))
[ "$turns" -gt 0 ] || turns=1
i=0
while [ "$i" -lt "$turns" ]; do
	if curl -s -m 1 -o /dev/null "$URL"; then
		exit 0
	fi
	if ! kill -0 "$SRV" 2>/dev/null; then
		echo "scenario-wait-ready: the server (pid $SRV) DIED at boot before $URL answered." >&2
		[ -n "$LOG" ] && [ -f "$LOG" ] && { echo "--- server log ---" >&2; cat "$LOG" >&2; }
		exit 1
	fi
	sleep 0.2
	i=$((i + 1))
done

echo "scenario-wait-ready: $URL did not answer within ${BOUND}s (one-minute load $(load_1m)); the server (pid $SRV) is still alive." >&2
echo "  This is the #1477 class: the wait gave up and the scenario would otherwise have gone on to" >&2
echo "  curl a socket nobody is listening on, printing status=000 for every request and reporting a" >&2
echo "  broken example. Raise CX_SCENARIO_READY_SECONDS only with a measurement that says why." >&2
[ -n "$LOG" ] && [ -f "$LOG" ] && { echo "--- server log ---" >&2; cat "$LOG" >&2; }
exit 1
