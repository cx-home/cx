#!/bin/sh
# run_fixture_shards_selftest — proves the #1513 FIXTURE_FILES resolution on a
# SYNTHETIC repo (mktemp; never the live tree — the rule
# head_is_docs_only_selftest.sh and the spec-freeze-gate selftest follow). The
# selection's whole value is that it SHRINKS the fixtures step, so the cases
# that must be proved are the ones where it must not shrink it wrongly: a name
# no shard owns, and a shard that owns none of the named files.
#
# The synthetic repo carries a copy of the wrapper and the census script, a
# three-file manifest whose [doc [# … #]] block contains DECOY rows, and a fake
# `v` that records which steps were launched and writes the census a real shard
# would write. Nothing is compiled: what is under test is the resolution, the
# refusal and the census restriction, all of which happen before the first
# process starts.
#
#   A  no FIXTURE_FILES        → the driver and EVERY shard; the whole-corpus
#                                census; no FIXTURE-FILES= line (unchanged)
#   B  one file                → only the shard that owns it, no driver
#   C  files in two shards     → both shards, no driver
#   D  conformance/code.cxd    → the driver ALONE, no shard
#   E  a file no shard owns    → EXIT 1, the name on stderr, nothing launched
#   F  one owned + one unowned → EXIT 1 (one bad name fails the step)
#   G  spelled without the `conformance/` prefix → same answer as with it
#   H  the shard process sees CX_FIXTURE_FILES in the MANIFEST spelling
#   I  the census is restricted to the shards that ran
#   J  the manifest's own documentation is not read as rows (decoy)
#
# Exit 0 and the count line only when every case matches.
set -u

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
for f in run_fixture_shards.sh fixtures_census.sh; do
	[ -f "$HERE/$f" ] || { echo "SELFTEST FAILED: no $f beside this script" >&2; exit 1; }
done

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fails=0

mkdir -p "$T/scripts" "$T/vcx/tests/fixtures_grader" "$T/vcx/target" \
	"$T/conformance/platform" "$T/conformance/stdlib" "$T/conformance/xap"
cp "$HERE/run_fixture_shards.sh" "$HERE/fixtures_census.sh" "$T/scripts/"

# A manifest in the real row shape, with DECOYS inside the prose block: a
# reader that reads its own documentation as data grades a shard that does not
# exist (case J).
cat > "$T/vcx/tests/fixtures_grader/fixture_shards.cxd" <<'MANIFEST'
[fixture-shards
  [doc [#
A row is written `[shard name=s-decoy test=vcx/tests/decoy_test.v measured-ms=0 cases=0]`
and a file row `[file name=platform/decoy.cxd measured-ms=0 cases=0]`. Neither is real.
#]]

 [shard name=s-1 test=vcx/tests/code_eval_fixtures_shard_1_test.v measured-ms=10 cases=2
  [file name=platform/alpha.cxd measured-ms=6 cases=1]
  [file name=stdlib/beta.cxd measured-ms=4 cases=1]
 ]

 [shard name=s-2 test=vcx/tests/code_eval_fixtures_shard_2_test.v measured-ms=5 cases=1
  [file name=xap/gamma.cxd measured-ms=5 cases=1]
 ]
]
MANIFEST

for f in conformance/platform/alpha.cxd conformance/stdlib/beta.cxd conformance/xap/gamma.cxd; do
	printf '[test-suite ring=1]\n' > "$T/$f"
done
touch "$T/vcx/tests/code_eval_fixtures_test.v" \
	"$T/vcx/tests/code_eval_fixtures_shard_1_test.v" \
	"$T/vcx/tests/code_eval_fixtures_shard_2_test.v"

# The fake `v`: run from vcx/ with the step as its last argument. It records the
# launch and writes the census a real shard writes, so the census script has
# something true to sum.
cat > "$T/fake-v" <<'FAKEV'
#!/bin/sh
step=""
for a in "$@"; do step=$a; done
root=$(cd "$(dirname "$0")" && pwd)
echo "LAUNCHED $step CX_FIXTURE_FILES=[${CX_FIXTURE_FILES-<unset>}]" >> "$root/launched"
case "$step" in
*shard_1_test.v) s=s-1 ;;
*shard_2_test.v) s=s-2 ;;
*) exit 0 ;;
esac
printf 'shard=%s\nfiles=1\nran=7\nout_err_ran=3\nmodule:%s=3\n' "$s" "$s" \
	> "$root/vcx/target/fixtures/$s.census"
FAKEV
chmod +x "$T/fake-v"

# expect <name> <want-exit> <selection> — then the caller greps $T/out / $T/err
# / $T/launched for what the case is actually about.
run_case() {
	: > "$T/launched"
	if [ -z "${2-}" ]; then
		(cd "$T" && V="$T/fake-v" sh scripts/run_fixture_shards.sh) > "$T/out" 2> "$T/err"
	else
		(cd "$T" && V="$T/fake-v" FIXTURE_FILES="$2" sh scripts/run_fixture_shards.sh) > "$T/out" 2> "$T/err"
	fi
	got=$?
	[ "$got" = "$1" ] || {
		printf '  %-3s SELFTEST FAILED: exit %s, wanted %s\n' "$CASE" "$got" "$1" >&2
		fails=$((fails + 1))
		return 1
	}
	return 0
}

want() { # want <case> <description> <condition-already-evaluated:0|1>
	if [ "$3" -eq 0 ]; then
		printf '  %-3s ok   %s\n' "$1" "$2"
	else
		printf '  %-3s SELFTEST FAILED: %s\n' "$1" "$2" >&2
		echo "        stdout: $(tr '\n' '|' < "$T/out")" >&2
		echo "        stderr: $(tr '\n' '|' < "$T/err")" >&2
		echo "        launched: $(tr '\n' '|' < "$T/launched")" >&2
		fails=$((fails + 1))
	fi
}

# `grep -c` PRINTS 0 and EXITS 1 on no match, so the count is the substitution
# and never a fallback `echo` appended to it (a `|| echo 0` here made "0\n0").
launched_count() { c=$(grep -c '^LAUNCHED' "$T/launched" 2>/dev/null); echo "${c:-0}"; }

echo "run_fixture_shards selftest:"

# A — no selection: the driver and every shard, the whole-corpus census, and NO
#     FIXTURE-FILES= line. This is the property the post-merge run depends on.
CASE=A
if run_case 0 ""; then
	n=$(launched_count)
	grep -q 'code_eval_fixtures_test.v' "$T/launched" &&
		grep -q 'shard_1_test.v' "$T/launched" &&
		grep -q 'shard_2_test.v' "$T/launched" &&
		[ "$n" -eq 3 ] &&
		grep -q 'stdlib corpus: 14 fixtures ran across 2 module file(s)' "$T/out" &&
		! grep -q 'FIXTURE-FILES=' "$T/out"
	want A "unselected: driver + both shards, census 14, no FIXTURE-FILES line" $?
	# J rides on A: a decoy row would have launched a fourth step
	grep -q 'decoy' "$T/launched"
	[ $? -ne 0 ]
	want J "the manifest's [doc [# … #]] rows are not read as data" $?
fi

# B — one file: only its shard, and no driver
CASE=B
if run_case 0 "conformance/xap/gamma.cxd"; then
	n=$(launched_count)
	grep -q 'shard_2_test.v' "$T/launched" && [ "$n" -eq 1 ] &&
		grep -q '^FIXTURE-FILES=conformance/xap/gamma.cxd$' "$T/out"
	want B "one named file launches its shard alone, under a FIXTURE-FILES line" $?
	# H rides on B: the shard is handed the MANIFEST spelling, not the caller's
	grep -q 'CX_FIXTURE_FILES=\[xap/gamma.cxd\]' "$T/launched"
	want H "the shard process sees CX_FIXTURE_FILES in the manifest spelling" $?
	# I rides on B: the census counts the one shard that ran, not the manifest's two
	grep -q 'stdlib corpus: 7 fixtures ran across 1 module file(s)' "$T/out"
	want I "the census is restricted to the shards that ran" $?
fi

# C — files owned by two different shards
CASE=C
if run_case 0 "conformance/platform/alpha.cxd conformance/xap/gamma.cxd"; then
	n=$(launched_count)
	grep -q 'shard_1_test.v' "$T/launched" && grep -q 'shard_2_test.v' "$T/launched" &&
		[ "$n" -eq 2 ]
	want C "two shards, no driver" $?
fi

# D — the driver's own corpus
CASE=D
if run_case 0 "conformance/code.cxd"; then
	n=$(launched_count)
	grep -q 'code_eval_fixtures_test.v' "$T/launched" && [ "$n" -eq 1 ]
	want D "conformance/code.cxd launches the driver alone" $?
fi

# E — a name NO shard owns FAILS; nothing is launched. A silent skip here is the
#     whole failure mode a selection introduces.
CASE=E
if run_case 1 "conformance/llm/prompts.cxd"; then
	n=$(launched_count)
	grep -q 'conformance/llm/prompts.cxd' "$T/err" && [ "$n" -eq 0 ]
	want E "an unowned name fails the step and launches nothing" $?
fi

# F — one good name does not rescue a bad one
CASE=F
if run_case 1 "conformance/xap/gamma.cxd conformance/nope.cxd"; then
	n=$(launched_count)
	grep -q 'conformance/nope.cxd' "$T/err" && [ "$n" -eq 0 ]
	want F "one unowned name among owned ones still fails the step" $?
fi

# G — the manifest spelling is accepted directly
CASE=G
if run_case 0 "xap/gamma.cxd"; then
	n=$(launched_count)
	grep -q 'shard_2_test.v' "$T/launched" && [ "$n" -eq 1 ] &&
		grep -q 'CX_FIXTURE_FILES=\[xap/gamma.cxd\]' "$T/launched"
	want G "a name spelled without the conformance/ prefix resolves the same" $?
fi

if [ "$fails" -ne 0 ]; then
	echo "run_fixture_shards selftest: $fails case(s) FAILED" >&2
	exit 1
fi
echo "run_fixture_shards selftest: 10/10 (A/J unselected; B/C/D/G/H/I selected; E/F refused)"
