#!/usr/bin/env bash
# check_selection_manifest.sh (#1516, RULED: RUN-1) — every TEST_TARGETS entry
# has an input-glob row in scripts/test_changed.sh.
#
# WHY IT EXISTS. `test_changed.sh` is DENY-BY-DEFAULT: a step with no row always
# runs. That direction is right and it stays — a false skip costs correctness —
# but it is SILENT. Thirteen steps sat rowless for months and the only thing
# that said so was one line in a run log nobody reads, while every post-merge
# run paid for them. This step is what says so: a step joining TEST_TARGETS
# without a row fails here, so deny-by-default is the fallback for a step in
# FLIGHT and never the resting state of the manifest.
#
# It derives BOTH sides and REFUSES TO VOUCH when either derivation comes up
# empty — the vcx/Makefile:597 idiom that check-build-input-roster (#1065) and
# check-editor-surface-parity (#1171) follow, because a check that silently ran
# over the empty set would pass forever.
#
# A row naming a step that is NOT in TEST_TARGETS is reported as a NOTE, not a
# failure: `test-vcx` is deliberately kept as a row for the human entry point
# the Makefile still defines.
set -u

cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)" || exit 1

MANIFEST=scripts/test_changed.sh
MAKEFILE=Makefile

[ -f "$MANIFEST" ] || { echo "check-selection-manifest: no $MANIFEST" >&2; exit 1; }
[ -f "$MAKEFILE" ] || { echo "check-selection-manifest: no $MAKEFILE" >&2; exit 1; }

# The authoritative step list, the same line test_changed.sh itself reads.
targets=$(grep -m1 '^TEST_TARGETS :=' "$MAKEFILE" | sed 's/^TEST_TARGETS := //')
[ -n "$targets" ] || {
	echo "check-selection-manifest: derived NO targets from $MAKEFILE — refusing to vouch" >&2
	exit 1
}

# The row set: the `case` labels inside step_globs(). A label is a step name at
# the head of a line, followed by `)` and the `echo` that prints its globs. The
# catch-all `*)` is excluded by the character class.
rows=$(sed -n '/^step_globs()/,/^}/p' "$MANIFEST" \
	| grep -oE '^[[:space:]]+[a-zA-Z0-9][a-zA-Z0-9_.-]*\)[[:space:]]+echo' \
	| sed -E 's/^[[:space:]]+//; s/\)[[:space:]]+echo$//')
[ -n "$rows" ] || {
	echo "check-selection-manifest: derived NO rows from $MANIFEST — refusing to vouch" >&2
	exit 1
}

missing=""
for t in $targets; do
	case "
$rows
" in
	*"
$t
"*) ;;
	*) missing="$missing $t" ;;
	esac
done

orphans=""
for r in $rows; do
	case " $targets " in
	*" $r "*) ;;
	*) orphans="$orphans $r" ;;
	esac
done

n_t=$(printf '%s\n' $targets | grep -c .)
n_r=$(printf '%s\n' $rows | grep -c .)

if [ -n "$orphans" ]; then
	echo "check-selection-manifest: NOTE — row(s) for a step TEST_TARGETS does not name:$orphans"
	echo "  (kept on purpose for a human entry point the Makefile still defines;"
	echo "   delete the row when the target goes away.)"
fi

if [ -n "$missing" ]; then
	echo "check-selection-manifest: TEST_TARGETS entr(ies) with NO manifest row —"
	for t in $missing; do echo "    $t"; done
	echo "  A rowless step runs on EVERY head by deny-by-default: correct, but it"
	echo "  is the pace of every post-merge run and nothing announces it. Add a"
	echo "  row to step_globs() in $MANIFEST naming the directories and files the"
	echo "  step actually reads — derive them from the recipe and from the script"
	echo "  it runs, and over-include on doubt. A row that skips a step whose"
	echo "  input changed is the one failure this manifest must not have."
	exit 1
fi

echo "check-selection-manifest OK — $n_t TEST_TARGETS entries, $n_r manifest rows, none missing"
