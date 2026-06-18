#!/usr/bin/env bash
#
# CX release-tag procedure (version-agnostic).
#
# Runs on the maintainer's local machine when the release branch is merged to
# main and the gate is green. Performs:
#   1. Sanity: on main, working tree clean, tag does not exist
#   2. Bump version strings (VERSION + manifests via bump_version.sh)
#   3. Build libcx + cli
#   4. Run `make test`  (the authoritative gate — all TEST_TARGETS)
#   5. Run `make verify-doc-links`
#   6. Create git tag
#   7. Print push instructions (does NOT push automatically)
#
# With --dry-run: exercises step 1 (sanity), confirms steps 4/5 targets
# exist (without running them — heavy + may flake on dev branches),
# reports what 2/3/6 would do; skips any state-changing operation. No
# git commits, no tags, no pushes. Useful as a CI sanity gate ahead of an
# actual tag commit. The real tag run still executes make test and make
# verify-doc-links in full.
#
# Usage:
#   scripts/tag_release.sh vX.Y.Z            # full tag procedure
#   scripts/tag_release.sh --dry-run vX.Y.Z  # exercise checks only
#   scripts/tag_release.sh --dry-run         # defaults to v$(cat VERSION)
#
# Prerequisites:
#   - On branch `main` (or `<tag>-dev` for dry-run)
#   - GPG signing key configured (optional; unsigned annotated tag otherwise)
#   - `make test` and `make verify-doc-links` pass locally

set -uo pipefail

DRY_RUN=0
TAG=""

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            sed -n '2,30p' "$0"
            exit 0
            ;;
        v[0-9]*) TAG="$arg" ;;
        *) echo "Unknown arg: $arg" >&2; exit 2 ;;
    esac
done

if [[ -z "$TAG" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
        TAG="v$(cat "$(dirname "$0")/../VERSION" 2>/dev/null | tr -d '[:space:]')"  # default for dry-run: current VERSION
    else
        echo "Usage: $0 [--dry-run] <tag>  (e.g. v$(cat "$(dirname "$0")/../VERSION" 2>/dev/null | tr -d '[:space:]'))" >&2
        exit 2
    fi
fi

VERSION="${TAG#v}"
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-.+)?$ ]]; then
    echo "Bad version: $VERSION" >&2
    exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

note() {
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '[dry-run] %s\n' "$*"
    else
        printf '== %s ==\n' "$*"
    fi
}

fail() { echo "FAIL: $*" >&2; exit 1; }

# -- Step 1: sanity ---------------------------------------------------

CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ $DRY_RUN -eq 0 ]]; then
    if [[ "$CUR_BRANCH" != "main" ]]; then
        fail "Not on main (currently on $CUR_BRANCH); refusing real tag."
    fi
else
    echo "[dry-run] current branch: $CUR_BRANCH  (real tag requires main)"
fi

if ! git diff-index --quiet HEAD; then
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "[dry-run] working tree dirty (real tag would refuse here)"
    else
        fail "Working tree dirty; commit or stash first."
    fi
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
    fail "Tag $TAG already exists."
fi

note "sanity OK (branch=$CUR_BRANCH, tree clean, $TAG not yet taken)"

# -- Step 4: make test ------------------------------------------------

have_target() {
    # Check that the Makefile declares a target named $1. macOS ships
    # BSD make which doesn't speak some GNU options, so we grep the
    # Makefile directly rather than invoking `make -n`.
    grep -qE "^${1}:" Makefile
}

note "running 'make test'"
if [[ $DRY_RUN -eq 1 ]]; then
    if have_target test; then
        echo "[dry-run] target 'make test' declared in Makefile; skipping execution"
    else
        fail "make test target missing"
    fi
else
    make test 2>&1 | tail -10
    [[ ${PIPESTATUS[0]} -eq 0 ]] || fail "make test failed"
fi

# -- Step 5: doc-link verification ------------------------------------

note "running 'make verify-doc-links'"
if [[ $DRY_RUN -eq 1 ]]; then
    if have_target verify-doc-links; then
        echo "[dry-run] target 'make verify-doc-links' declared in Makefile; skipping execution"
    else
        fail "make verify-doc-links target missing"
    fi
else
    make verify-doc-links 2>&1 | tail -10
    [[ ${PIPESTATUS[0]} -eq 0 ]] || fail "make verify-doc-links failed"
fi

# -- Step 2: version bump (skipped on dry-run) ------------------------

if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] would bump version strings to $VERSION in:"
    echo "          cx.pc.in"
    echo "          vcx/v.mod, lang/v/v.mod"
    echo "          lang/rust/cxlib/Cargo.toml"
    echo "          lang/python/pyproject.toml"
else
    note "stamping version to $VERSION (VERSION file + manifests via bump_version.sh)"
    scripts/bump_version.sh "$VERSION"
    note "verifying version consistency"
    python3 scripts/check_version_consistency.py || fail "version inconsistent after bump"
fi

# -- Step 3: rebuild --------------------------------------------------

if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] would run: make build-vcx"
else
    note "rebuilding libcx + cli"
    make build-vcx
fi

# -- Step 6: tag (skipped on dry-run) ---------------------------------

if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] would commit version bump + create signed tag $TAG"
    echo "[dry-run] would print push instructions"
    echo
    echo "[dry-run] all checks passed — real tag would proceed cleanly."
    exit 0
fi

note "committing version bump"
git add VERSION cx.pc.in vcx/v.mod lang/v/v.mod \
        lang/rust/cxlib/Cargo.toml \
        lang/python/pyproject.toml 2>/dev/null || true
git commit -m "chore(release): bump version strings to $VERSION" || true

TAG_MSG="CX $TAG release. See RELEASE_NOTES_${TAG//\./_}.md for full release notes."
if git config --get user.signingkey >/dev/null 2>&1 && gpg --list-secret-keys >/dev/null 2>&1; then
    note "creating signed tag"
    git tag -s "$TAG" -m "$TAG_MSG"
else
    note "no GPG signing key configured — creating an annotated (unsigned) tag (matches the prior CX tags, e.g. v0.8.0/v0.10.0)"
    git tag -a "$TAG" -m "$TAG_MSG"
fi

echo
echo "== ready to push =="
echo "Next steps:"
echo "  1. Review the commit + tag: git show $TAG"
echo "  2. Push:                    git push origin main && git push origin $TAG"
echo "  3. Wait for .github/workflows/release.yml to publish the draft release"
echo "  4. Edit the draft release body to reference RELEASE_NOTES_${TAG//\./_}.md"
echo "  5. Publish the GitHub release"
