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
# It failed a SECOND time on 2026-09-07 (#1191), in the DOT spelling:
# `pb.store` shipped in the composition spec, in the `feature.cxs` comment and
# in `conformance/xap/xap-compose.cxd` as the worked publisher-qualified
# example, while `pb-[a-z]` reported clean — the hyphen class does not see a
# dot. A blanket `pb\.[a-z]` class is NOT viable and was measured before being
# rejected: eight tracked files use it innocently (`pb.bytesize`, `pb.len`,
# `pb.count` in the archived Ruby/Swift bindings and in five engine sources),
# so it would cry wolf exactly the way `ae-` did.
#
# What makes `pb.store` a leak and `pb.len` not is that the leak is a NAME —
# it appears QUOTED, as a publisher-qualified identifier or as prose in
# backticks. So the class is anchored on the quote: `'pb.`, `"pb.`, `` `pb. ``.
# Verified against the whole tracked tree: it matched all eight leak sites and
# nothing else, before or after the sanitization.
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
	# CLASS pattern, dotted form (#1191) — a publisher qualification is a
	# NAME, so it is quoted or in backticks; see the header for why the
	# unanchored `pb\.[a-z]` was measured and rejected.
	"['\"\`]pb\.[a-z]"
)

# PROBES — one string per TERM that the term MUST match. Parallel array; the
# self-test below feeds every probe through BOTH engines this gate uses.
#
# #842: the gate builds ONE pattern and hands it to two DIFFERENT engines —
# `git grep -inE` for tracked files, plain `grep -inE` for the --gh-metadata
# lane. They do not agree on `\b`: plain grep honours it, `git grep -E`
# silently ignores it and matches nothing. So a term written with `\b` would be
# LIVE on the metadata lane and DEAD on the tracked lane, and the gate would
# report OK on a tree containing the term while flagging it in the tracker.
# That is the same hollow-gate failure the pathspec note below records,
# reached by a different route, and invisible because the other lane still
# fires. No current term uses `\b`, so this was latent — which is exactly when
# to nail it down.
#
# The self-test is deliberately stronger than a `\b` ban: it proves each term
# matches its own probe under BOTH engines, so ANY future construct the two
# disagree about is caught, not just the one instance that was noticed.
PROBES=(
	'powerband'
	'pbengine'
	'client-acme'
	'account executive'
	'ae-queue'
	'pb-x'
	"'pb.x"
)

if [ "${#TERMS[@]}" -ne "${#PROBES[@]}" ]; then
	echo "check-no-consumer-terms: FAIL — TERMS (${#TERMS[@]}) and PROBES (${#PROBES[@]}) are out of step; every term needs a probe"
	exit 2
fi

selftest_dir="$(mktemp -d)"
trap 'rm -rf "$selftest_dir"' EXIT
selftest_file="$selftest_dir/probe.txt"
selftest_failed=0
for i in "${!TERMS[@]}"; do
	term="${TERMS[$i]}"
	probe="${PROBES[$i]}"
	case "$term" in
		*'\b'*)
			echo "check-no-consumer-terms: FAIL — term '$term' uses \\b, which \`git grep -E\` silently ignores."
			echo "  portable form: (^|[^a-z])term(\$|[^a-z])"
			selftest_failed=1
			;;
	esac
	printf '%s\n' "$probe" > "$selftest_file"
	if ! grep -qiE "$term" "$selftest_file"; then
		echo "check-no-consumer-terms: FAIL — term '$term' does not match its own probe '$probe' under \`grep -E\` (the --gh-metadata lane)"
		selftest_failed=1
	fi
	# Run from INSIDE the temp dir: `git grep --no-index` still refuses a path
	# outside the repository, and the probe deliberately lives outside so it is
	# never itself scanned by the real gate below.
	if ! ( cd "$selftest_dir" && git grep --no-index -qiE "$term" -- probe.txt ); then
		echo "check-no-consumer-terms: FAIL — term '$term' does not match its own probe '$probe' under \`git grep -E\` (the tracked-file lane)"
		echo "  the gate's two lanes disagree about its own vocabulary; neither can be trusted"
		selftest_failed=1
	fi
done
if [ "$selftest_failed" -ne 0 ]; then
	exit 2
fi

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

# ── --tree DIR mode ─────────────────────────────────────────────────────────
# Scans an arbitrary directory on disk rather than this repo's tracked files.
# It exists for `scripts/publish.sh`, whose pre-commit guard was PATH-based
# only: it asserted no forbidden PATH leaked, and could not see a banned term
# sitting INSIDE an allowlisted file. That is not a hypothetical — `pb-ae`
# reached the public repo through exactly that hole and is live there now, in
# vcx/tests/xap_render_test.v, having passed the path guard every publish.
#
# The tracked-file lane below cannot serve this: at guard time the public
# tree is not yet committed, so `git grep` (tracked files) sees nothing. Hence
# a filesystem walk. Excludes .git and the vendored submodule; nothing else,
# because the publish allowlist has already decided what is in the payload —
# a second, differently-worded exclusion set here is how the two gates would
# drift apart and one of them would quietly stop protecting anything.
if [ "${1:-}" = "--tree" ]; then
	tree_root="${2:-}"
	[ -n "$tree_root" ] || { echo "check-no-consumer-terms(tree): FAIL — usage: $0 --tree DIR"; exit 2; }
	[ -d "$tree_root" ] || { echo "check-no-consumer-terms(tree): FAIL — not a directory: $tree_root"; exit 2; }
	hits="$(grep -rInE "$pattern" "$tree_root" \
		--exclude-dir=.git --exclude-dir=third_party 2>&1)"
	grep_status=$?
	# grep exits 1 on "no match" and >1 on a real error. A hard error must
	# never read as clean — the same vacuous-pass rule as every other lane.
	if [ "$grep_status" -gt 1 ]; then
		echo "check-no-consumer-terms(tree): FAIL — grep errored (status $grep_status); refusing a vacuous pass"
		printf '%s\n' "$hits" | head -3
		exit 2
	fi
	if [ -n "$hits" ]; then
		echo "check-no-consumer-terms(tree): FAIL — consumer-identifying terms in $tree_root:"
		printf '%s\n' "$hits"
		echo "(policy: sanitize to CX-generic workload language; see the gate header)"
		exit 1
	fi
	echo "check-no-consumer-terms(tree): OK — no consumer-identifying terms in $tree_root"
	exit 0
fi

# Tracked files only (a release cut ships tracked content); skip vendored code
# and this gate itself (it must name the terms it bans).
#
# ARCHIVES ARE IN SCOPE, deliberately (#842). The exclusion used to read
# `:(exclude)_archive*`, which is TOP-LEVEL-ANCHORED — and there is no
# top-level `_archive*` path in this repo at all, so it excluded NOTHING while
# reading as protection. The three archive directories that do exist are all
# nested (`docs-src/_archive`, `lang/_archived` — 161 files — and
# `spec/_archived`) and were being scanned the whole time.
#
# Rather than widen it to `:(exclude)**/_archive*` and match the old comment's
# intent, the line is gone and the intent is corrected: an archived binding is
# still tracked content that a release cut carries, so it is exactly what this
# gate exists to check. Verified green with all three in scope, so nothing is
# being papered over to make this true.
#
# PATHSPEC FORM IS LOAD-BEARING: `:!_archive*` dies with git's
# "Unimplemented pathspec magic '_'" (short-form magic parsing eats the
# underscore), and the old `2>/dev/null || true` swallowed that fatal —
# leaving the gate structurally HOLLOW: it reported OK on a tree full of
# banned terms. Long-form `:(exclude)` pathspecs + loud error handling.
hits="$(git grep -inE "$pattern" -- \
	':(exclude)third_party' \
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
