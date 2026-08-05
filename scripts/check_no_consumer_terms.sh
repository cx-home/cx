#!/usr/bin/env bash
#
# NO-CONSUMER-TERMS gate — downstream-consumer identity must never appear in
# the repo tree, because the public release repos are CUT from this one and
# anything here flows into them. The standing policy (2026-07-24 owner
# ruling): CX addresses platform concerns independent of specific users;
# every artifact speaks in CX-generic workload terms (users, tracked
# entities, events, streams, deployments) — never a consumer's name,
# product, org, or business-domain vocabulary.
#
# The denylist is deliberately literal and case-insensitive. Extend it when
# a new consumer engagement begins — the term goes in HERE the same day.
# Bare short tokens with false-positive surface (e.g. a lone "pb") are
# intentionally excluded; the multi-char forms below catch real leaks.
#
# Exit 0 when clean; exit 1 listing every offending file:line.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TERMS=(
	'powerband'
	'pb-engine'
	'pbengine'
	'pb-xap'
	'pb-hq'
	'pb-roadmap'
	'client-acme'
	'ae-queue'
	'x-pb-'
	'account executive'
)

pattern="$(IFS='|'; echo "${TERMS[*]}")"

# ── --gh-metadata mode (audit C10; owner-authorized 2026-08-05) ──────────────
# The tracked-file gate is structurally blind to GitHub METADATA — labels,
# issue/PR bodies, and comments — which a future export tool might carry (the
# same public-mirror reasoning as the tree gate). This mode scans all of it
# via the bulk REST endpoints. It needs `gh` + network, so it is SCHEDULED /
# on-demand, never wired into per-commit TEST_TARGETS:
#
#   scripts/check_no_consumer_terms.sh --gh-metadata
#
# Scope: every label name+description, every issue and PR body+title (the
# /issues listing includes PRs), every issue comment, every PR review comment.
if [ "${1:-}" = "--gh-metadata" ]; then
	command -v gh >/dev/null || { echo "check-no-consumer-terms(gh): FAIL — gh CLI not available"; exit 2; }
	repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)" || { echo "check-no-consumer-terms(gh): FAIL — cannot resolve repo"; exit 2; }
	fail=0
	scan() { # $1=lane-name  $2=jq-projection  $3=endpoint
		local out status
		out="$(gh api "$3" --paginate -q "$2" 2>&1)"
		status=$?
		if [ $status -ne 0 ]; then
			echo "check-no-consumer-terms(gh): FAIL — $1 fetch errored; refusing a vacuous pass"
			echo "$out" | head -3
			fail=2
			return
		fi
		local hits
		hits="$(printf '%s\n' "$out" | grep -inE "$pattern")"
		if [ -n "$hits" ]; then
			echo "check-no-consumer-terms(gh): FAIL — consumer-identifying terms in $1:"
			echo "$hits" | head -20
			fail=1
		fi
	}
	scan "labels"             '.[] | "label \(.name) :: \(.description // "")"'                       "repos/$repo/labels"
	scan "issue/PR bodies"    '.[] | "#\(.number) \(.title) :: \(.body // "" | gsub("\n"; " "))"'      "repos/$repo/issues?state=all"
	scan "issue comments"     '.[] | "comment \(.id) (\(.html_url)) :: \(.body // "" | gsub("\n"; " "))"' "repos/$repo/issues/comments"
	scan "PR review comments" '.[] | "review-comment \(.id) (\(.html_url)) :: \(.body // "" | gsub("\n"; " "))"' "repos/$repo/pulls/comments"
	if [ "$fail" -ne 0 ]; then
		echo "(policy: sanitize to CX-generic wording; edit the offending metadata in place)"
		exit "$fail"
	fi
	echo "check-no-consumer-terms(gh): OK — no consumer-identifying terms in labels, issue/PR bodies, or comments"
	exit 0
fi

# Tracked files only (a release cut ships tracked content); skip vendored
# code, archives, and this gate itself (it must name the terms it bans).
#
# PATHSPEC FORM IS LOAD-BEARING: `:!_archive*` dies with git's
# "Unimplemented pathspec magic '_'" (short-form magic parsing eats the
# underscore), and the old `2>/dev/null || true` swallowed that fatal —
# leaving the gate structurally HOLLOW: it reported OK on a tree full of
# banned terms. Long-form `:(exclude)` pathspecs + loud error handling.
hits="$(git grep -inE "$pattern" -- \
	':(exclude)third_party' \
	':(exclude)_archive*' \
	':(exclude)_gate_evidence' \
	':(exclude)scripts/check_no_consumer_terms.sh')"
grep_status=$?
if [ "$grep_status" -gt 1 ]; then
	echo "check-no-consumer-terms: FAIL — git grep errored (status $grep_status); refusing a vacuous pass"
	exit 2
fi

if [ -n "$hits" ]; then
	echo "check-no-consumer-terms: FAIL — downstream-consumer identity in tracked content:"
	echo "$hits"
	echo "(policy: sanitize to CX-generic workload language; see the gate header)"
	exit 1
fi
echo "check-no-consumer-terms: OK — no consumer-identifying terms in tracked content"
