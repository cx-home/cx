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

# Tracked files only (a release cut ships tracked content); skip vendored
# code, archives, and this gate itself (it must name the terms it bans).
hits="$(git grep -inE "$pattern" -- \
	':!third_party' \
	':!_archive*' \
	':!_gate_evidence' \
	':!scripts/check_no_consumer_terms.sh' \
	2>/dev/null || true)"

if [ -n "$hits" ]; then
	echo "check-no-consumer-terms: FAIL — downstream-consumer identity in tracked content:"
	echo "$hits"
	echo "(policy: sanitize to CX-generic workload language; see the gate header)"
	exit 1
fi
echo "check-no-consumer-terms: OK — no consumer-identifying terms in tracked content"
