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
EXPECTED_VERSION="${1:-}"

if [ -z "$EXPECTED_VERSION" ]; then
 echo "Usage: $0 <expected-version>"
 echo "Example: $0 0.6.0"
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
check "all 11 version locations = $EXPECTED_VERSION" \
 "tools/bump-version.sh --check $EXPECTED_VERSION"

section "Working tree state"
check "git working tree clean" \
 "test -z \"\$(git status --porcelain | grep -v '^?? \\\\.claude/' | grep -v '^?? \\\\.cache/')\""
check "on a release branch (not detached)" \
 "git symbolic-ref -q HEAD"

section "Doc presence"
check "RELEASE_NOTES_v${EXPECTED_VERSION}.md exists" \
 "test -f RELEASE_NOTES_v${EXPECTED_VERSION}.md"
check "MIGRATION.md exists" \
 "test -f MIGRATION.md"
check "CHANGELOG.md exists" \
 "test -f CHANGELOG.md"
check "the release process exists" \
 "test -f the release process"
check "the evaluation-experience checklist exists" \
 "test -f the evaluation-experience checklist"
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

section "Capability rubric"
check "no unresolved \"⚠\" in readiness rubric" \
 "! grep -E '^\\| .* \\| *⚠ \\|' the release criteria"

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
