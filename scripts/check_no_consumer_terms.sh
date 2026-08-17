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
# ENUMERATION IS THE WEAK POINT, and it failed once. `pb-ae` sat in shipped
# engine source and a test for three weeks (from #567, 2026-07-21) while
# this gate reported clean, because the list carried `pb-engine`, `pb-xap`,
# `pb-hq`, `x-pb-` … and not that particular spelling — even though
# `ae-queue` and `account executive` were already banned, so it was exactly
# the vocabulary the list exists to stop, in a spelling nobody thought to
# add. Guessing every suffix is not a strategy.
#
# So `pb-<word>` is matched as a CLASS — any suffix, present or future.
# Verified against the whole tracked tree: zero legitimate uses, so the
# false-positive surface the comment above worries about does not exist for
# the hyphenated form (a lone "pb" is still excluded, and still should be).
#
# `ae-<word>` was tried as a class too and REVERTED, which is worth
# recording so nobody repeats it. It fires on `mem://ae-origin` /
# `mem://ae-rep` / `shred-ae-N` in the journal erasure examples, where `ae`
# abbreviates apply-erasures — an innocent, unrelated use, and one whose ids
# appear in expected fixture output. A gate that cries wolf gets ignored or
# gets exclusions bolted on, and either way stops protecting anything. `ae`
# is too short and too common to class-match; the specific consumer spelling
# stays enumerated below.
#
# Exit 0 when clean; exit 1 listing every offending file:line.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TERMS=(
	'powerband'
	'pbengine'
	'client-acme'
	'account executive'
	'ae-queue'
	# CLASS pattern — any suffix, so a new spelling cannot slip through the
	# way `pb-ae` did. Subsumes pb-engine / pb-xap / pb-hq / pb-roadmap /
	# x-pb-, which are no longer listed individually.
	'pb-[a-z]'
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
