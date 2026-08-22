#!/usr/bin/env bash
# tools/release-verify.sh — pre-publish sanity check.
#
# Runs all the §0 prerequisites from the release process as one
# fast script. Exit 0 means "ready to tag." Exit non-zero means stop.
#
# Usage:
# tools/release-verify.sh 0.6.0

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Default to the repo-root VERSION file — the single source of truth.
EXPECTED_VERSION="${1:-$(cat "$ROOT/VERSION")}"

if [ -z "$EXPECTED_VERSION" ]; then
 echo "Usage: $0 [expected-version]   (default: the VERSION file)"
 exit 2
fi

cd "$ROOT"

PASS=0
FAIL=0
section() {
 echo ""
 echo "── $1 ────────────────────────────────────────────────"
}
check() {
 local label="$1" cmd="$2"
 printf " %-60s " "$label"
 if eval "$cmd" > /tmp/release-verify.log 2>&1; then
 echo "OK"
 PASS=$((PASS + 1))
 else
 echo "FAIL"
 FAIL=$((FAIL + 1))
 sed 's/^/ /' /tmp/release-verify.log | head -5
 fi
}

section "Version consistency"
check "VERSION file = $EXPECTED_VERSION" \
 "test \"\$(cat VERSION)\" = \"$EXPECTED_VERSION\""
check "manifests + derived surfaces match VERSION" \
 "python3 scripts/check_version_consistency.py"

section "Working tree state"
check "git working tree clean" \
 "test -z \"\$(git status --porcelain | grep -v '^?? \\.claude/' | grep -v '^?? \\.cache/')\""
check "on a release branch (not detached)" \
 "git symbolic-ref -q HEAD"

section "Doc presence"
check "RELEASE_NOTES_v${EXPECTED_VERSION}.md exists" \
 "test -f RELEASE_NOTES_v${EXPECTED_VERSION}.md"
check "CHANGELOG.md exists" \
 "test -f CHANGELOG.md"
check "docs/internal/RELEASE_PROCESS.md exists" \
 "test -f docs/internal/RELEASE_PROCESS.md"
check "docs/internal/EVALUATION_EXPERIENCE.md exists" \
 "test -f docs/internal/EVALUATION_EXPERIENCE.md"
check "docs/internal/adoption_review_v${EXPECTED_VERSION}.md exists" \
 "test -f docs/internal/adoption_review_v${EXPECTED_VERSION}.md"

section "Test matrix"
check "make test (full matrix)" \
 "make -s test"

section "Experience gate"
check "make verify-examples" \
 "make -s verify-examples"
check "make verify-readme-blocks" \
 "make -s verify-readme-blocks"
check "make verify-doc-blocks" \
 "make -s verify-doc-blocks"
check "make verify-doc-links" \
 "make -s verify-doc-links"

section "Release assets"
# RULED: PGL-1 (#741) — the R2.2 blocking per-profile install gate runs HERE,
# pre-tag, instead of first executing inside the cut itself. Proves item 1 of
# #741; item 2 (installing from the PUBLISHED assets) still needs the cut.
check "R2.2 per-profile install gate (4 tarballs, extract + probe)" \
 "make -s release-profile-gate"

section "Capability rubric"
# The row's target is the readiness rubric FILE. A doc-curation text-replace
# (365923b7) once rewrote the path literal into the prose phrase "the release
# criteria" — grep then errored on three nonexistent files and the leading
# `!` inverted that error into a VACUOUS PASS on every run since. The file
# must exist (test -f) so a future move fails loud instead of vacuously
# passing again; the grep pattern matches only a lone-⚠ status cell, not the
# legend's tier column.
check "no unresolved \"⚠\" in readiness rubric" \
 "test -f spec/03-approved/process/readiness-rubric.md && ! grep -E '^\\| .* \\| *⚠ \\|' spec/03-approved/process/readiness-rubric.md"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " release-verify: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════════════════════════════"

if [ $FAIL -ne 0 ]; then
 echo "Release blocked. Fix the failures above before tagging."
 exit 1
fi
echo "Ready to tag v${EXPECTED_VERSION}."
exit 0
