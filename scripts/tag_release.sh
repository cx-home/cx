#!/usr/bin/env bash
#
# CX release-tag procedure (version-agnostic).
#
# Runs on the maintainer's local machine when the release branch is merged to
# main and the gate is green. Performs:
#   1. Sanity: on the release branch, working tree clean, tag does not exist
#   4. Run `make test`  (the authoritative gate — all TEST_TARGETS)
#   5. Run `make verify-doc-links`
#   2. Bump version strings (VERSION + manifests via bump_version.sh)
#   3. Commit the bump, CREATE THE ANNOTATED TAG on it, then build libcx + cli
#      and verify the artifact's provenance stamp (#666, #979/CO-4 — the tag
#      must exist BEFORE the build, because the build derives release-ness
#      from HEAD-at-the-tag; a failure after tagging deletes the tag)
#   7. Print push instructions (does NOT push automatically)
#
# (The step NUMBERS are historical — the list above is the execution order.)
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
# #666 topology as renamed 2026-08-24: the branch tracks a minor LINE
# (release/0.17), not one release — matching release.sh's own derivation.
# The old release/X.Y.0 spelling here would hard-fail every cut from the
# renamed line while release.sh passed its own check (found by CO-4's
# release-ordering audit, #979).
# The LINE is X.Y whatever follows: vX.Y.Z and a pre-release vX.Y.Z-pre.N both
# cut from release/X.Y — the same derivation release.sh uses. `${VERSION%.*}`
# stripped only the last dotted field and asked for release/0.18.0-pre on the
# first pre-release tag (v0.18.0-pre.1, measured 2026-09-13), so the cut
# refused a branch that was right.
EXPECT_BRANCH="release/$(echo "$VERSION" | sed -E 's/^([0-9]+\.[0-9]+)\..*$/\1/')"
if [[ $DRY_RUN -eq 0 ]]; then
    if [[ "$CUR_BRANCH" != "$EXPECT_BRANCH" ]]; then
        fail "Not on $EXPECT_BRANCH (currently on $CUR_BRANCH); v$VERSION cuts from its release branch (#666)."
    fi
else
    if [[ "$CUR_BRANCH" != "$EXPECT_BRANCH" ]]; then
        echo "[dry-run] WARNING: the real tag would REFUSE here — on $CUR_BRANCH, $TAG requires $EXPECT_BRANCH"
    else
        echo "[dry-run] current branch: $CUR_BRANCH  (matches what the real tag requires)"
    fi
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
    # Full log KEPT, never piped through tail (the gates-never-piped rule):
    # the v0.16.0 cut failed here twice with the failing target's output
    # already discarded — tail -10 kept the passing test-vcx summary and
    # threw away everything else, so the actual red was unidentifiable
    # from the run that found it. Digest on failure: the make error lines
    # plus a pointer to the full log.
    # BSD mktemp only expands TRAILING Xs — a suffixed template is taken
    # literally, so a second run collides on the literal name. Trailing Xs
    # work on both BSD and GNU.
    TAG_TEST_LOG="$(mktemp /tmp/tag-release-make-test.log.XXXXXX)"
    note "full 'make test' log: $TAG_TEST_LOG"
    if ! make test > "$TAG_TEST_LOG" 2>&1; then
        grep -E "make(\[[0-9]+\])?: \*\*\*|FAIL|Error" "$TAG_TEST_LOG" | tail -20
        fail "make test failed — full log: $TAG_TEST_LOG"
    fi
    tail -3 "$TAG_TEST_LOG"
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

# -- Step 4b: perf ratchet (#1249, RULED: 1249-Q1a) --------------------
#
# Measure, then compare against the committed floor at the STRICT 10%
# threshold. A regression aborts the cut exactly like a red gate. On green the
# fresh measurement becomes the new floor: bench/current.json is copied over
# bench/baseline.json (tracked), which the bump's `git add -u` then carries
# into the bump commit — every cut re-pins the ratchet to its own number.

note "running 'make perf-ratchet'"
if [[ $DRY_RUN -eq 1 ]]; then
    if have_target perf-ratchet; then
        echo "[dry-run] target 'make perf-ratchet' declared in Makefile; skipping execution"
    else
        fail "make perf-ratchet target missing"
    fi
else
    # #1450 — WAIT for a quiet box, do not abort on a busy one. The ratchet
    # refuses (exit 3) rather than failing when the one-minute load is over
    # CX_BENCH_MAX_LOAD, because a reading taken while other work compiles is
    # not a reading: with the runner held and six pipelines beside it,
    # tooling.fmt_8k_ms read 1902 ms against a hot 1304 and four unrelated rows
    # regressed 36-457 % (impl/cx-A-1433 run 4). Promoting THAT to
    # bench/baseline.json would re-pin the floor to a number that was never
    # real, which is the ratchet running backwards — the one direction 1249-Q1a
    # exists to prevent. So a refusal retries; only a real regression aborts.
    ratchet_tries=${CX_RATCHET_TRIES:-12}
    ratchet_wait=${CX_RATCHET_WAIT:-300}
    ratchet_rc=3
    for (( attempt = 1; attempt <= ratchet_tries; attempt++ )); do
        make perf-ratchet 2>&1 | tail -30
        ratchet_rc=${PIPESTATUS[0]}
        [[ $ratchet_rc -ne 3 ]] && break
        if (( attempt < ratchet_tries )); then
            note "perf ratchet REFUSED to measure on a loaded box (#1450) — attempt $attempt of $ratchet_tries; waiting ${ratchet_wait}s for the box"
            sleep "$ratchet_wait"
        fi
    done
    if [[ $ratchet_rc -eq 3 ]]; then
        fail "make perf-ratchet refused on every one of $ratchet_tries attempts — the box never went quiet (one-minute load over CX_BENCH_MAX_LOAD). Cut on an idle machine; never raise the bound to get a number."
    fi
    [[ $ratchet_rc -eq 0 ]] || fail "make perf-ratchet failed — a benchmark regressed past 10% of the previous cut (bench/baseline.json); fix or rule before cutting"
    cp bench/current.json bench/baseline.json
    note "perf ratchet green — bench/baseline.json re-pinned to this cut's measurement"
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
    # the contract-revision stamp bump_version.sh regenerates must agree too (#1435)
    make check-contract-revision || fail "contract-revision stamp disagrees with VERSION after the bump (#1435)"
    make docs-check || fail "generated docs drifted from the bumped VERSION (#1435)"
fi

# -- Step 3: commit the bump, TAG it, THEN rebuild (#666, #979) -------
#
# ORDER IS LOAD-BEARING, in two steps.
#
# (#666) The build stamps CX_COMMIT from HEAD and CX_VERSION from the VERSION
# file. Building while the bump sat uncommitted stamped the NEW version against
# the PRE-bump commit — an artifact whose provenance claim could not both be
# true (`cx version` said v0.15.0 @ a commit whose VERSION file said 0.14.0),
# and rev-parse is silent about the dirty tree that would have explained it.
# Committing first makes the stamped commit the SAME commit the tag points at:
# the artifact reproduces from its tag.
#
# (#979, RULED: CO-4) The build now also stamps RELEASE-NESS, derived from
# whether HEAD sits at the annotated tag matching VERSION with a clean tree. So
# the tag must EXIST BEFORE THE BUILD, or the release artifacts stamp
# themselves `-dev+<commit>` — correctly, since at that moment they were not
# built from a tagged commit. The tag therefore moves ahead of the build, and
# the provenance gate below (which now demands the bare `cx vX.Y.Z` headline)
# is what proves the derivation fired. A failure after tagging deletes the tag:
# it is local until release.sh's push phase, so the cut stays re-runnable.

if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] would commit version bump, create the annotated tag $TAG on it, then run: make build-vcx"
else
    note "committing version bump"
    # Stage every file bump_version.sh just stamped. The tree was verified clean
    # at the start of this script, so the only tracked modifications now are the
    # version stamps — `git add -u` captures them all and CANNOT drift out of
    # sync with bump_version.sh the way a hand-maintained file list does (that
    # drift left vscode/package.json at the old version in a tagged commit).
    git add -u 2>/dev/null || true
    git commit -m "chore(release): bump version strings to $VERSION" || true

    # -- Step 3b: tag the bump commit, BEFORE the build (#979/CO-4) ----
    #
    # Both tag shapes are ANNOTATED (`-s` is annotated + signed); the CO-4
    # derivation probes with `git describe --exact-match`, which consults
    # annotated tags only, so a lightweight tag here would silently produce
    # `-dev+` release artifacts.
    TAG_MSG="CX $TAG release. See RELEASE_NOTES_${TAG//\./_}.md for full release notes."
    if git config --get user.signingkey >/dev/null 2>&1 && gpg --list-secret-keys >/dev/null 2>&1; then
        note "creating signed tag $TAG on the bump commit (before the build — CO-4)"
        git tag -s "$TAG" -m "$TAG_MSG" || fail "could not create tag $TAG"
    else
        note "no GPG signing key configured — creating an annotated (unsigned) tag $TAG on the bump commit (matches the prior CX tags)"
        git tag -a "$TAG" -m "$TAG_MSG" || fail "could not create tag $TAG"
    fi
    # From here on, any failure must not leave a tag pointing at an
    # unreleasable tree: the tag is local until release.sh pushes it, so
    # dropping it keeps the cut re-runnable from a clean state.
    untag_and_fail() { git tag -d "$TAG" >/dev/null 2>&1 || true; fail "$@"; }

    note "rebuilding libcx + cli (at the tag — the artifacts stamp as the release)"
    make build-vcx || untag_and_fail "make build-vcx failed"

    # Provenance gate (#666, extended by #979/CO-4): the binary we just built
    # must self-report exactly this version at exactly this (clean) commit —
    # the check that would have caught the mis-stamp. `cx version` is the
    # contract surface downstream BOMs pin on, so assert on its output, not on
    # build inputs.
    #
    # Under CO-4 this stopped being a formality: the bare `cx vX.Y.Z` headline
    # is now REACHABLE ONLY from a clean checkout of the tagged commit, so a
    # `-dev+` here is a real finding (tag missing, tree dirty, stale binary,
    # tag/VERSION mismatch) rather than a cosmetic one. Naming the actual
    # headline in the failure text is what makes it diagnosable.
    STAMP="$(vcx/target/cx version 2>/dev/null || vcx/target/cx -v)"
    HEADLINE="$(echo "$STAMP" | head -1)"
    WANT_COMMIT="$(git rev-parse --short HEAD)"
    [[ "$HEADLINE" == "cx v$VERSION" ]] \
        || untag_and_fail "provenance stamp: binary reports '$HEADLINE', expected exactly 'cx v$VERSION' (a '-dev+' headline means the build did not see HEAD at an annotated $TAG with a clean tree — RULED: CO-4)"
    echo "$STAMP" | grep -qE "commit[[:space:]]+$WANT_COMMIT\$" \
        || untag_and_fail "provenance stamp: binary's commit is not clean '$WANT_COMMIT' — got: $(echo "$STAMP" | grep commit)"
    note "provenance stamp verified: cx v$VERSION @ $WANT_COMMIT (clean, at $TAG)"
fi

# -- Step 6: report (the tag was created in step 3b) ------------------

if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] would print push instructions"
    echo
    echo "[dry-run] all checks passed — real tag would proceed cleanly."
    exit 0
fi

echo
echo "== ready to push =="
echo "Next steps:"
echo "  1. Review the commit + tag: git show $TAG"
echo "  2. Push:                    git push origin main && git push origin $TAG"
echo "  3. Wait for .github/workflows/release.yml to publish the draft release"
echo "  4. Edit the draft release body to reference RELEASE_NOTES_${TAG//\./_}.md"
echo "  5. Publish the GitHub release"
