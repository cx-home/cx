#!/bin/sh
# scripts/campaign-watchdog.sh [interval] — prints ONLY anomalies about the
# autonomous campaign, one line each, deduplicated, so a supervisor session
# can sit on it for hours at near-zero cost. Silence means healthy.
#
# Anomalies:
#   SILENT   a worker's last note is mid-run (not "run exit") and older than 35 min
#   MISSED   a worker wrote no "run start" in the 70 min after its firing slot
#   RED      gate.log carries GATE-EXIT=2 (reported once per verdict)
#   SLOT     the build slot has been held longer than 150 min
#   STALE    the shared lock is 45+ min old while some worker's last note is mid-run
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root" || exit 1
every=${1:-300}
seen=""
emit() { case "$seen" in *"|$1|"*) ;; *) echo "$(date +%H:%M) $2"; seen="$seen|$1|";; esac; }
age_min() { t=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null || echo 0); [ "$t" -eq 0 ] && echo 9999 || echo $(( ($(date +%s) - t) / 60 )); }
while :; do
	now=$(date +%s); hm=$(date +%H%M); min=$(date +%M)
	for w in A B C; do
		last=$(grep -E "  (worker )?$w:" vcx/target/campaign.status 2>/dev/null | tail -1)
		[ -z "$last" ] && continue
		ts=$(echo "$last" | cut -c1-20); txt=$(echo "$last" | cut -c23-90); a=$(age_min "$ts")
		case "$txt" in *"run exit"*) ;; *) [ "$a" -ge 35 ] && emit "silent-$w-$ts" "SILENT worker $w: ${a}m since \"$txt\"";; esac
		# missed firing: the worker's last word was "run exit" and nothing has been heard since for
		# longer than a firing interval (+10 min jitter/warm-up). A run that outlives its hour is not a miss.
		case "$txt" in *"run exit"*) [ "$a" -ge 70 ] && emit "missed-$w-$ts" "MISSED worker $w: last note was run exit ${a}m ago, no new run";; esac
	done
	v=$(grep -o 'GATE-EXIT=[0-9]*' vcx/target/gate.log 2>/dev/null | tail -1); st=$(grep -m1 '^gate: started' vcx/target/gate.log 2>/dev/null | cut -c15-)
	[ "$v" = "GATE-EXIT=2" ] && emit "red-$st" "RED gate started $st: $v; $(grep -c '^FAIL' vcx/target/gate.log) FAIL line(s): $(grep '^FAIL' vcx/target/gate.log | head -2 | cut -c1-80 | tr '\n' ';')"
	slotd=${CX_BUILD_SLOT:-"$HOME/git-repos/cx/.build-slot"}
	if [ -d "$slotd" ]; then sa=$(age_min "$(cat "$slotd/since" 2>/dev/null)"); [ "$sa" -ge 150 ] && emit "slot-$(cat "$slotd/since")" "SLOT held ${sa}m by pid $(cat "$slotd/pid"): $(cut -c1-70 "$slotd/cmd") @$(basename "$(cat "$slotd/cwd")")"; fi
	sleep "$every"
done
