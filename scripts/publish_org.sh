#!/usr/bin/env bash
# scripts/publish_org.sh — sync the cx-home org README from
# docs/CX_HOME_ORG_README.md to the cx-home/.github repo's
# profile/README.md.
#
# Usage:  make publish-org
#         ORG_GITHUB_ROOT=/path/to/.github make publish-org

set -euo pipefail

PRIVATE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORG_GITHUB_ROOT="${ORG_GITHUB_ROOT:-$HOME/git-repos/cx/.github}"

SRC="${PRIVATE_ROOT}/docs/CX_HOME_ORG_README.md"
DST_DIR="${ORG_GITHUB_ROOT}/profile"
DST="${DST_DIR}/README.md"

if [ ! -f "$SRC" ]; then
    echo "error: source not found: $SRC"
    exit 1
fi

if [ ! -d "${ORG_GITHUB_ROOT}/.git" ]; then
    echo "error: cx-home/.github repo not found at $ORG_GITHUB_ROOT"
    echo ""
    echo "Clone the repo first:"
    echo "  git clone git@github.com:cx-home/.github.git $ORG_GITHUB_ROOT"
    echo ""
    echo "Or override the path:"
    echo "  ORG_GITHUB_ROOT=/path/to/.github make publish-org"
    exit 1
fi

mkdir -p "$DST_DIR"
cp "$SRC" "$DST"
echo "synced: $SRC → $DST"
echo ""
echo "Next: review the diff, commit, and push:"
echo "  cd $ORG_GITHUB_ROOT"
echo "  git diff profile/README.md"
echo "  git add profile/README.md && git commit -m 'docs: sync org README from cx-private v0.8.0'"
echo "  git push"
