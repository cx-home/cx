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
# v.mod is tab-indented `version: '...'`. Use POSIX [[:space:]] (BSD/macOS sed
# does NOT understand \s) and capture the leading whitespace to preserve it.
stamp vcx/v.mod                   "s/^\([[:space:]]*version:[[:space:]]*\)'.*'/\1'$NEW'/"
stamp lang/v/v.mod                "s/^\([[:space:]]*version:[[:space:]]*\)'.*'/\1'$NEW'/"
stamp lang/rust/cxlib/Cargo.toml  "s/^version = \".*\"/version = \"$NEW\"/"
# Cargo.lock records the cxlib package's own version too; cargo would otherwise
# regenerate it on the next build and leave a dirty tree (tripping the release
# clean-tree check). Stamp ONLY the cxlib package's version line (match its
# `name = "cxlib"` block, then the following `version =`), never other packages'.
stamp lang/rust/cxlib/Cargo.lock  "/^name = \"cxlib\"\$/{n;s/^version = \".*\"/version = \"$NEW\"/;}"
stamp lang/python/pyproject.toml  "s/^version = \".*\"/version = \"$NEW\"/"
# Narrative docs carry the version in ONE machine-checkable place: the shields
# badge. Per-release prose lives in RELEASE_NOTES_v*.md (per-release by
# construction), NOT in these READMEs — so the badge is the only token that can
# drift, and it is stamped here + gated by check_version_consistency.py.
stamp README.md                   "s|badge/version-v[0-9.]*-blue|badge/version-v$NEW-blue|"
stamp vcx/README.md               "s|badge/version-v[0-9.]*-blue|badge/version-v$NEW-blue|"
# SECURITY.md names the supported minor SERIES (X.Y.x) — derived from VERSION
# here and gated by check_version_consistency.py so it can never drift again
# (it sat at "0.7.x" for five releases before the 2026-07-14 audit caught it).
SERIES="$(printf '%s' "$NEW" | cut -d. -f1-2).x"
stamp SECURITY.md                 "s/\*\*[0-9][0-9]*\.[0-9][0-9]*\.x\*\*/**$SERIES**/"
# VS Code extension version — user-visible in the marketplace. npm needs a
# literal semver, so stamp it (package.json has a single `"version"` key).
stamp tooling/vscode/package.json "s/\"version\": \"[^\"]*\"/\"version\": \"$NEW\"/"
# package-lock mirrors it in TWO spots (top-level + the \"\" self-package node),
# each immediately preceded by `\"name\": \"cx-language\"`. Stamp only those —
# never the dependency versions (which carry no cx-language name line above).
stamp tooling/vscode/package-lock.json "/\"name\": \"cx-language\"/{n;s/\"version\": \"[^\"]*\"/\"version\": \"$NEW\"/;}"

echo
echo "VERSION = $NEW. Code (cabi.v/main.v) derives via the build define — not stamped."
echo "Verify:  make check-version-consistency"
echo "Release: scripts/tag_release.sh v$NEW"
