#!/usr/bin/env bash
# scripts/publish_org.sh — sync the cx-home org README from
# docs/internal/CX_HOME_ORG_README.md to the cx-home/.github repo's
# profile/README.md. Best-effort: never aborts a release (see below).
#
# Usage:  make publish-org
#         ORG_GITHUB_ROOT=/path/to/.github make publish-org

set -euo pipefail

PRIVATE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORG_GITHUB_ROOT="${ORG_GITHUB_ROOT:-$HOME/git-repos/cx/.github}"

SRC="${PRIVATE_ROOT}/docs/internal/CX_HOME_ORG_README.md"
DST_DIR="${ORG_GITHUB_ROOT}/profile"
DST="${DST_DIR}/README.md"

# The org-profile README sync is best-effort BRANDING, not a release artifact.
# It must never abort a release: release-all runs tag-public (the real release
# step) BEFORE this, and a missing source or unconfigured .github clone here
# just skips the sync with a note (exit 0) rather than failing the release.
if [ ! -f "$SRC" ]; then
    echo "skip publish-org: org-README source not found ($SRC) — profile sync skipped"
    exit 0
fi

if [ ! -d "${ORG_GITHUB_ROOT}/.git" ]; then
    echo "skip publish-org: cx-home/.github repo not found at $ORG_GITHUB_ROOT"
    echo "  to enable the org-profile sync: git clone git@github.com:cx-home/.github.git $ORG_GITHUB_ROOT"
    echo "  (or set ORG_GITHUB_ROOT=/path/to/.github)"
    exit 0
fi

mkdir -p "$DST_DIR"
cp "$SRC" "$DST"
echo "synced: $SRC → $DST"
echo ""
echo "Next: review the diff, commit, and push:"
echo "  cd $ORG_GITHUB_ROOT"
echo "  git diff profile/README.md"
echo "  git add profile/README.md && git commit -m 'docs: sync org README from cx-private'"
echo "  git push"
