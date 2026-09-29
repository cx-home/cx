# scripts/verification_timings_lib.sh — the WRITER behind
# vcx/target/verification_timings.cxd (issue 1583, RULED: RUN-5). Sourceable,
# not executable: `. scripts/verification_timings_lib.sh`.
#
# #1562 shipped `check-verification-budget` — the bounds, the idle/loaded rule,
# the refusal — with NOTHING producing its input: every bound read NOT MEASURED
# and the step judged nothing, which is a sentence rather than a measurement
# (issue 1583; the owner's 1562-a keeps #1562 open until this lands). Two
# writers use these two functions:
#
#   * the post-merge runner writes `union` or `selected-run` at RUN-EXIT
#     (flows/postmerge.flow.cx's verdict act, the same row in cx, RULED: RFLOW-1),
#     seconds counted from RUN-START and the load sampled at RUN-START;
#   * scripts/run_fixture_shards.sh writes `fixture-grader` on an UNSELECTED
#     run — a selected run grades a handful of corpus files and its seconds
#     say nothing about the bound, which is the whole-corpus number.
#
# The row replaces the previous row of its own name and keeps every other, so
# the file always carries the LAST measurement of each and the next run's
# budget step judges the last run. That is deliberate: a file that accumulated
# rows would make the step judge whichever row it happened to read first.

# sample_load_1m — the one-minute load average, as a bare number.
#
# It is sampled at the START of a run, not at the end: the budget step's whole
# idle/loaded rule is about the box the measurement was taken on, and a run that
# began on a quiet box is the measurement that judges. An unreadable load prints
# 999, which the step reads as loaded — the fail-safe direction, because a
# number nobody can defend must never red a run.
sample_load_1m() {
	if sl_raw=$(sysctl -n vm.loadavg 2>/dev/null) && [ -n "$sl_raw" ]; then
		printf '%s\n' "$sl_raw" | awk '{ gsub(/[{}]/, ""); print $1 + 0 }'
		return 0
	fi
	if [ -r /proc/loadavg ]; then
		awk '{ print $1 + 0 }' /proc/loadavg
		return 0
	fi
	printf '%s\n' 999
}

# write_timing_row <file> <name> <seconds> <load> <at>
#   Writes `[timing name= seconds= load= at=]` into <file>, REPLACING the
#   previous row of <name> and keeping the others. Creates the document (and
#   its directory) when it is not there yet.
#
#   Rows are read back with a bracket-scan rather than by line, so a file a hand
#   has reflowed still round-trips; the document is rewritten whole through a
#   temporary file and moved into place, so a reader never sees a half-written
#   manifest — check-verification-budget can be running in the same storm.
write_timing_row() {
	wt_file=$1; wt_name=$2; wt_secs=$3; wt_load=$4; wt_at=$5
	wt_dir=$(dirname "$wt_file")
	[ -d "$wt_dir" ] || mkdir -p "$wt_dir" || return 1
	wt_keep=''
	if [ -r "$wt_file" ]; then
		wt_keep=$(grep -oE '\[timing [^]]*\]' "$wt_file" 2>/dev/null \
			| grep -vE "^\[timing[[:space:]]+name=${wt_name}([[:space:]]|\])" || true)
	fi
	wt_tmp=$wt_file.$$.tmp
	{
		printf '[verification-timings\n'
		[ -n "$wt_keep" ] && printf '%s\n' "$wt_keep" | sed 's/^/  /'
		printf '  [timing name=%s seconds=%s load=%s at=%s]]\n' \
			"$wt_name" "$wt_secs" "$wt_load" "$wt_at"
	} > "$wt_tmp" || return 1
	mv -f "$wt_tmp" "$wt_file"
}
