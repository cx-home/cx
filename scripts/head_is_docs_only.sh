#!/bin/sh
# scripts/head_is_docs_only.sh <last-passed> <tip> — does this head need the
# FULL post-merge pipeline, or only the DOC pipeline? (RULED: INT-10)
#
# The words are the delivery grammar's (spec/03-approved/process/delivery-grammar.md
# §4): a run is one pipeline on one commit, and §4's pipeline row names the doc
# pipeline. THIS FILE is where the path list lives — the spec names the pipeline,
# the runner names the paths, so adding a path is a code change with a test and
# not a spec edit.
#
#   exit 0  — docs-only: the runner may call `gate.sh test-docs`
#   exit 1  — full run
#   exit 2  — usage/infrastructure (a missing commit, a bad argument)
#
# 1 and 2 are BOTH "full run" for the caller. That is deliberate: every answer
# this script cannot establish must cost a full run, never skip one. The only
# way to reach exit 0 is an enumerated, non-empty diff.
#
# The base is the last head that PASSED, never the last head that RAN
# (INT-10, delivery grammar §5.6). A failed head is fixed by a fix branch; if
# the base were "last run", a docs commit landing on top of a red head would be
# graded by the doc pipeline and the red would vanish from the log without
# anyone fixing it.
#
# The allow-list, from the INT-10 decision row:
#
#   ledger/…            the decision store
#   docs/…              the GENERATED site (docs-check regenerates it; the doc
#                       pipeline runs docs-check, so drift is still caught)
#   _gate_evidence/…    run artifacts
#   registry/README.md  prose beside the registry — NOT registry/modules.cxd,
#                       which declares every module's ring and is read by
#                       placement-gate, ring-import-gate and ring-tag-gate
#   *.md                anywhere EXCEPT spec/03-approved/ — an approved spec is
#                       normative, read by spec-freeze-gate,
#                       check-code-spec-consistency and check-no-adr-citations,
#                       so it always costs a full run
#
# Everything else — conformance/, scripts/, the Makefile, vcx/, stdlib/, x/,
# reference/, tools/, corpus/, fixtures/ — is a full run.
set -u

usage() {
	echo "usage: $0 <last-passed-sha> <tip-sha>" >&2
	exit 2
}

[ $# -eq 2 ] || usage
base=$1
tip=$2
[ -n "$base" ] || usage
[ -n "$tip" ] || usage

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

git -C "$ROOT" cat-file -e "$base^{commit}" 2>/dev/null || {
	echo "head_is_docs_only: $base is not a commit in this repo — full run" >&2; exit 2; }
git -C "$ROOT" cat-file -e "$tip^{commit}" 2>/dev/null || {
	echo "head_is_docs_only: $tip is not a commit in this repo — full run" >&2; exit 2; }

# --no-renames: with rename detection on, `--name-only` prints the DESTINATION
# path alone, so moving a compiled test file into docs/ would read as docs-only.
# Both sides of a rename must be judged.
files=$(git -C "$ROOT" diff --no-renames --name-only "$base" "$tip" 2>/dev/null) || {
	echo "head_is_docs_only: git diff $base $tip failed — full run" >&2; exit 2; }

if [ -z "$files" ]; then
	# No diff at all. Reached when the re-run flag forces a re-grade of an
	# unchanged tip — which exists precisely to run the FULL pipeline again
	# after a classified flaky test. A vacuous doc run would answer the
	# wrong question.
	echo "head_is_docs_only: empty diff $base..$tip — full run" >&2
	exit 1
fi

# The offenders are collected through a COMMAND SUBSTITUTION, not a pipeline
# into a variable: a `… | while read` loop runs in a subshell, so a variable it
# sets is lost at the `done` and the verdict would always be "docs".
#
# Every case pattern is written with its LEADING `(`. That spelling is POSIX
# and optional everywhere else in this repo, but bash 3.2 — which is what
# /bin/sh is on this box — cannot parse a bare `pattern)` inside `$( … )`: it
# counts the pattern's `)` as the end of the substitution and dies on the next
# `;;`. Measured, not assumed: the unparenthesized first cut of this file
# failed `sh -n`.
verdict=0
offenders=$(printf '%s\n' "$files" | while IFS= read -r f; do
	[ -n "$f" ] || continue
	case "$f" in
		(ledger/*|docs/*|_gate_evidence/*) continue ;;
		(registry/README.md)               continue ;;
		(spec/03-approved/*)               echo "$f" ;;  # normative, even as .md
		(*.md)                             continue ;;
		(*)                                echo "$f" ;;
	esac
done)

if [ -n "$offenders" ]; then
	printf 'head_is_docs_only: full run — %s path(s) outside the doc allow-list, first: %s\n' \
		"$(printf '%s\n' "$offenders" | grep -c '')" \
		"$(printf '%s\n' "$offenders" | head -1)" >&2
	verdict=1
else
	printf 'head_is_docs_only: docs — %s path(s), all inside the doc allow-list\n' \
		"$(printf '%s\n' "$files" | grep -c '')" >&2
fi
exit "$verdict"
