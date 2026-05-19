#!/usr/bin/env bash
# S8 v0.7.0: tag procedure for cx releases.
#
# Runs on maintainer's local machine when v0.7.0-dev is ready to
# tag onto main. Performs:
#   1. Bump version strings in cx.pc.in + vcx/v.mod + lang/*/{Cargo.toml,
#      pyproject.toml, package.json, v.mod}
#   2. Build all bindings to confirm green
#   3. Run conformance suite
#   4. Create signed git tag
#   5. Push tag (triggers .github/workflows/release.yml)
#
# Usage:
#   scripts/tag_release.sh v0.7.0
#
# Prerequisites:
#   - On branch `main` with v0.7.0-dev merged
#   - GPG signing key configured
#   - All conformance passes locally

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <tag>  (e.g. v0.7.0)" >&2
    exit 2
fi
TAG="$1"
VERSION="${TAG#v}"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-.+)?$ ]]; then
    echo "Bad version: $VERSION" >&2
    exit 2
fi

CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CUR_BRANCH" != "main" ]]; then
    echo "Not on main (currently on $CUR_BRANCH); refusing." >&2
    exit 1
fi

if ! git diff-index --quiet HEAD; then
    echo "Working tree dirty; commit or stash first." >&2
    exit 1
fi

echo "== bumping version strings to $VERSION =="
sed -i.bak "s/^Version: .*/Version: $VERSION/" cx.pc.in
sed -i.bak "s/^	version: '.*'/	version: '$VERSION'/" vcx/v.mod lang/v/v.mod 2>/dev/null || true
sed -i.bak "s/^version = \".*\"/version = \"$VERSION\"/" lang/rust/cxlib/Cargo.toml
sed -i.bak "s/^version = \".*\"/version = \"$VERSION\"/" lang/python/pyproject.toml
sed -i.bak "s/\"version\": \".*\"/\"version\": \"$VERSION\"/" lang/typescript/cxlib/package.json
find . -name "*.bak" -delete

echo "== rebuilding libcx + cli =="
make build-vcx

echo "== running test suite =="
make test-vcx 2>&1 | tail -5

echo "== running conformance =="
make check-conformance-coverage

echo "== running reproducibility check =="
if [[ -x scripts/reproduce_release.sh ]]; then
    scripts/reproduce_release.sh "$TAG"
fi

echo "== generating canonical SHA256SUMS =="
mkdir -p dist
if [[ -f dist/SHA256SUMS.reproduced.txt ]]; then
    cp dist/SHA256SUMS.reproduced.txt dist/SHA256SUMS.txt
fi

echo "== committing version bump =="
git add cx.pc.in vcx/v.mod lang/v/v.mod lang/rust/cxlib/Cargo.toml \
        lang/python/pyproject.toml lang/typescript/cxlib/package.json \
        dist/SHA256SUMS.txt 2>/dev/null || true
git commit -m "chore(release): bump version strings to $VERSION + SHA256SUMS" || true

echo "== creating signed tag =="
git tag -s "$TAG" -m "CX $TAG release. See RELEASE_NOTES_${TAG//\./_}.md for full release notes."

echo "== ready to push =="
echo "Next steps:"
echo "  1. Review the commit: git show HEAD"
echo "  2. Push: git push origin main && git push origin $TAG"
echo "  3. Wait for .github/workflows/release.yml to publish the draft release"
echo "  4. Edit the draft release to surface announcement (docs/announcement_v0_7_0.md)"
echo "  5. Publish the GitHub release"
