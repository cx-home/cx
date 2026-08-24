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

# #666 topology: the release is cut ON its release branch — the bump becomes
# the branch's FINAL commit and the tag lands on that bump commit, so the tag
# IS the branch tip (and, after release.sh merges to main, reachable from main
# as the merge's second parent). Branch name, tag, VERSION file, and artifact
# all name one commit. vX.Y.Z (any Z) cuts from release/X.Y.0 — patch releases
# ride the same branch.
CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
EXPECT_BRANCH="release/${VERSION%.*}.0"
if [[ $DRY_RUN -eq 0 ]]; then
    if [[ "$CUR_BRANCH" != "$EXPECT_BRANCH" ]]; then
        fail "Not on $EXPECT_BRANCH (currently on $CUR_BRANCH); v$VERSION cuts from its release branch (#666)."
    fi
else
    echo "[dry-run] current branch: $CUR_BRANCH  (real tag requires $EXPECT_BRANCH)"
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
    vcx/target/cx --allow-read --allow-write scripts/check_version_consistency.cx || fail "version inconsistent after bump"
fi

# -- Step 3: commit the bump, THEN rebuild (#666) ---------------------
#
# ORDER IS LOAD-BEARING: the build stamps CX_COMMIT from HEAD and CX_VERSION
# from the VERSION file. Building while the bump sat uncommitted stamped the
# NEW version against the PRE-bump commit — an artifact whose provenance
# claim could not both be true (`cx version` said v0.15.0 @ a commit whose
# VERSION file said 0.14.0), and rev-parse is silent about the dirty tree
# that would have explained it. Committing first makes the stamped commit
# the SAME commit the tag points at: the artifact reproduces from its tag.

if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] would commit version bump, then run: make build-vcx"
else
    note "committing version bump"
    # Stage every file bump_version.sh just stamped. The tree was verified clean
    # at the start of this script, so the only tracked modifications now are the
    # version stamps — `git add -u` captures them all and CANNOT drift out of
    # sync with bump_version.sh the way a hand-maintained file list does (that
    # drift left vscode/package.json at the old version in a tagged commit).
    git add -u 2>/dev/null || true
    git commit -m "chore(release): bump version strings to $VERSION" || true

    note "rebuilding libcx + cli"
    make build-vcx

    # Provenance gate (#666): the binary we just built must self-report
    # exactly this version at exactly this (clean) commit — the check that
    # would have caught the mis-stamp. `cx version` is the contract surface
    # downstream BOMs pin on, so assert on its output, not on build inputs.
    STAMP="$(vcx/target/cx version 2>/dev/null || vcx/target/cx -v)"
    WANT_COMMIT="$(git rev-parse --short HEAD)"
    echo "$STAMP" | grep -q "cx v$VERSION\$" \
        || fail "provenance stamp: binary reports '$(echo "$STAMP" | head -1)', expected 'cx v$VERSION'"
    echo "$STAMP" | grep -qE "commit[[:space:]]+$WANT_COMMIT\$" \
        || fail "provenance stamp: binary's commit is not clean '$WANT_COMMIT' — got: $(echo "$STAMP" | grep commit)"
    note "provenance stamp verified: cx v$VERSION @ $WANT_COMMIT (clean)"
fi

# -- Step 6: tag (skipped on dry-run) ---------------------------------

if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] would create signed tag $TAG"
    echo "[dry-run] would print push instructions"
    echo
    echo "[dry-run] all checks passed — real tag would proceed cleanly."
    exit 0
fi

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
