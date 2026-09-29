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
# ...plus the private flow steps flows/private.mk adds with `TEST_TARGETS +=`
# (RULED: PRIVMK-1), when this tree carries that file. The public tree does
# not, and there neither the steps nor their rows exist.
PRIVATE_MK=flows/private.mk
if [ -f "$PRIVATE_MK" ]; then
	targets="$targets $(sed -n 's/^TEST_TARGETS += //p' "$PRIVATE_MK" | tr '\n' ' ')"
fi
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
# ...plus the `<step>.globs := …` rows flows/private.mk carries for its own
# steps (PRIVMK-1): the same row, kept beside the target it selects.
if [ -f "$PRIVATE_MK" ]; then
	rows="$rows
$(sed -n 's/^\([a-zA-Z0-9][a-zA-Z0-9_-]*\)\.globs := .*/\1/p' "$PRIVATE_MK")"
fi
[ -n "$rows" ] || {
	echo "check-selection-manifest: derived NO rows from $MANIFEST — refusing to vouch" >&2
	exit 1
}

# PRIVMK-1: a step flows/private.mk adds must NOT also sit on the Makefile's
# own `TEST_TARGETS :=` line. That line is the PUBLIC roster: the public tree's
# `make test` runs it, and scripts/gen_docs/contributor_facts.cx projects it into
# docs/llm/contributor-test.md. A private step there is a `make test` step with
# no rule in the public tree, and a roster row whose bytes differ between the
# trees (cx main cb0b22a78's Site run: docs-check DRIFT). A merge that
# resolves the line against an older side re-adds them silently.
if [ -f "$PRIVATE_MK" ]; then
	public_line=$(grep -m1 '^TEST_TARGETS :=' "$MAKEFILE" | sed 's/^TEST_TARGETS := //')
	leaked=""
	for p in $(sed -n 's/^TEST_TARGETS += //p' "$PRIVATE_MK"); do
		case " $public_line " in *" $p "*) leaked="$leaked $p" ;; esac
	done
	if [ -n "$leaked" ]; then
		echo "check-selection-manifest: private step(s) on the Makefile's public TEST_TARGETS := line:$leaked"
		echo "  They belong to flows/private.mk's TEST_TARGETS += alone (RULED: PRIVMK-1)."
		exit 1
	fi
fi

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
