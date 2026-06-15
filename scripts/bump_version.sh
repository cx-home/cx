#!/usr/bin/env bash
# scripts/bump_version.sh — set the CX release version in ONE step.
#
# The repo-root VERSION file is the single source of truth. This script writes
# it and stamps the static package manifests that must carry a literal version
# at rest (package managers can't derive it). The code surfaces (vcx/cx/cabi.v,
# vcx/cmd/main.v) DERIVE the version from the `cx_version` build define and are
# NOT touched here. The git tag is created from VERSION by scripts/tag_release.sh.
#
# After running, `make check-version-consistency` must pass (CI enforces it).
#
# Usage:
#   scripts/bump_version.sh 0.11.0      # set version to 0.11.0
#   scripts/bump_version.sh             # re-stamp manifests from current VERSION
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

NEW="${1:-$(cat VERSION)}"
if ! [[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
    echo "bad version: $NEW (want X.Y.Z[-pre])" >&2
    exit 2
fi

printf '%s\n' "$NEW" > VERSION

stamp() { # <file> <sed-expr>
    [ -f "$1" ] || { echo "  skip (absent): $1"; return; }
    sed -i.bak "$2" "$1" && rm -f "$1.bak"
    echo "  stamped: $1"
}
echo "Stamping static manifests to $NEW (VERSION is the source of truth):"
stamp cx.pc.in                    "s/^Version: .*/Version: $NEW/"
stamp vcx/v.mod                   "s/^\(\s*version:\s*\)'.*'/\1'$NEW'/"
stamp lang/v/v.mod                "s/^\(\s*version:\s*\)'.*'/\1'$NEW'/"
stamp lang/rust/cxlib/Cargo.toml  "s/^version = \".*\"/version = \"$NEW\"/"
stamp lang/python/pyproject.toml  "s/^version = \".*\"/version = \"$NEW\"/"

echo
echo "VERSION = $NEW. Code (cabi.v/main.v) derives via the build define — not stamped."
echo "Verify:  make check-version-consistency"
echo "Release: scripts/tag_release.sh v$NEW"
