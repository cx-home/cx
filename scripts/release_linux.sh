#!/usr/bin/env bash
#
# scripts/release_linux.sh — build the LINUX release tarball(s) from this
# checkout via Docker (#520: the GitHub org cannot allocate Actions runners,
# so releases are cut locally on macOS — which left the public mirror with
# only cx-darwin-arm64.tar.gz; downstream deployments need cx-linux-arm64
# for containerized/appliance deployment and CI-on-Linux).
#
# Produces, per platform:
#   dist/public/cx-linux-<arch>.tar.gz     (flat: cx, cx.h, libcx.so — the
#                                           stable public name the quickstart
#                                           curl resolves)
#   dist/cx-<tag>-linux-<arch>.tar.gz      (nested internal artifact)
#
# The build runs in ubuntu-22.04 (the same base as .github/workflows/
# release.yml) with the same dep set: build-essential + libsqlite3-dev (the
# CX_ENGINES default carries -d cx_db_sqlite, which links -lsqlite3). RE2
# is vendored (third_party/re2, #573) and builds in-tree. The checkout is
# bind-mounted read-only and copied inside, so the artifact is built from
# exactly this tree (submodules included) without dirtying the host's
# vcx/target.
#
# Usage:
#   scripts/release_linux.sh vX.Y.Z            # linux-arm64 (native on Apple Silicon)
#   scripts/release_linux.sh --amd64 vX.Y.Z    # + linux-x86_64 (qemu emulation; slow)
#   scripts/release_linux.sh --dev vX.Y.Z      # dev-shape build (fast; lane validation only)
#
# Docker-on-this-machine note: pulls hang behind the credsStore=desktop
# helper; this script exports the documented bypass (anonymous auths config
# + explicit Desktop socket) automatically when the default config would
# hang. Read-only docker calls are unaffected.

set -euo pipefail

AMD64=0
DEV=0
TAG=""
for arg in "$@"; do
  case "$arg" in
    --amd64) AMD64=1 ;;
    --dev)   DEV=1 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    v[0-9]*) TAG="$arg" ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[ -z "$TAG" ] && TAG="v$(tr -d '[:space:]' < VERSION)"

# credsStore=desktop hangs every pull on this machine — use the anonymous
# bypass config when the user config would invoke the helper.
if grep -q '"credsStore"' "$HOME/.docker/config.json" 2>/dev/null; then
  export DOCKER_HOST="${DOCKER_HOST:-unix://$HOME/.docker/run/docker.sock}"
  export DOCKER_CONFIG="${DOCKER_CONFIG:-/tmp/cx-docker-anon}"
  mkdir -p "$DOCKER_CONFIG"
  [ -f "$DOCKER_CONFIG/config.json" ] || printf '{"auths":{"https://index.docker.io/v1/":{}}}\n' > "$DOCKER_CONFIG/config.json"
fi

# Pre-flight: local=1 below builds V from the VENDORED vc bootstrap tree,
# which is gitignored and therefore absent in a fresh submodule checkout
# (the in-container tree has no network identity to pin a fetch to, and the
# default network refresh path is broken on the copied detached-HEAD trees).
# Fail here with the remediation instead of 4 minutes into the container.
if [ ! -f third_party/v/vc/v.c ]; then
  echo "release_linux.sh: third_party/v/vc/v.c is missing — the vendored V" >&2
  echo "bootstrap tree is gitignored and this checkout never fetched it." >&2
  echo "Seed it from a sibling checkout of the fork, e.g.:" >&2
  echo "  cp -R ../cx-private/third_party/v/vc third_party/v/vc" >&2
  echo "or fetch it: git clone --depth=1 https://github.com/vlang/vc third_party/v/vc" >&2
  echo "(a vc revision proven against this fork pin is preferred; latest vc" >&2
  echo "tracks vlang master and may not bootstrap an older fork)." >&2
  exit 2
fi

BUILD_TARGET=$([ "$DEV" = 1 ] && echo build-vcx-dev || echo build-vcx)
PROFILES_TARGET=$([ "$DEV" = 1 ] && echo build-profiles-dev || echo build-profiles)
SDE="$(git log -1 --format=%ct)"
# Version stamps: the container copy carries no .git (lean copy), so derive
# the commit + V-fork pins on the host and hand them to make (command-line
# make vars override the := shell derivations and propagate to sub-makes).
CX_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
CX_VFORK="$(git -C third_party/v rev-parse --short HEAD 2>/dev/null || echo unknown)"
# Release provenance (#979, RULED: CO-4) travels the same road, and for the
# same reason: in the container `git describe` has nothing to describe, so an
# un-passed CX_RELEASE would stamp every linux artifact `-dev+` even at the
# tag. The value is READ FROM the Makefile rather than re-derived here — one
# implementation of the rule (`make -C vcx print-CX_RELEASE`), evaluated on the
# host, where the tag and the working tree actually are. This script is invoked
# by release.sh BEFORE its merge-to-main step, so the host HEAD is the tagged
# commit at this point.
# --no-print-directory: `make -C` otherwise brackets the value with
# Entering/Leaving lines. Only the two known states are accepted — a probe that
# picked up noise must not silently decide a release artifact's provenance.
CX_RELEASE="$(make -s --no-print-directory -C vcx print-CX_RELEASE 2>/dev/null | tail -1 | tr -d '[:space:]')"
case "$CX_RELEASE" in release|dev) ;; *) CX_RELEASE="" ;; esac
if [ -z "$CX_RELEASE" ]; then
  CX_RELEASE=dev
  echo "release_linux.sh: WARNING — could not read CX_RELEASE from vcx/Makefile;" >&2
  echo "the linux artifacts will stamp themselves as a pre-release (-dev+)." >&2
  echo "At a real cut the R2.2 gate below rejects that, which is the intent." >&2
fi

build_one() {
  local platform="$1" arch="$2"
  local pub="cx-linux-${arch}.tar.gz"
  local nested="cx-${TAG}-linux-${arch}.tar.gz"
  echo "== linux-${arch} (${platform}, ${BUILD_TARGET}) =="
  mkdir -p dist/public
  docker run --rm --platform "$platform" \
    -v "$ROOT:/src:ro" -v "$ROOT/dist:/out" \
    -e SOURCE_DATE_EPOCH="$SDE" \
    -e R22_EXPECT_HEADLINE="${R22_EXPECT_HEADLINE:-}" \
    ubuntu:22.04 bash -euc '
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      apt-get install -y -qq build-essential libsqlite3-dev git make >/dev/null
      # Lean copy: only what the build consumes (the full checkout is ~13 GB
      # with .git/bindings/build outputs — copying it fills the Docker VM).
      # stdlib/ and x/ are $embed_file-ed into the binary; third_party/v is
      # the patched fork the build contract requires.
      mkdir -p /build && cd /src
      tar cf - \
        --exclude=vcx/target \
        --exclude=third_party/v/v \
        --exclude=third_party/re2/obj \
        Makefile VERSION cx.pc.in include vcx stdlib x docs/llm third_party scripts \
        | tar xf - -C /build
      cd /build
      git config --global --add safe.directory "*"
      # local=1: build V from the vendored vc/tcc checkouts as-is — the
      # copied tcc tree is on a detached HEAD, so the default network
      # refresh (git pull --rebase) would fail; the fork pins both anyway.
      make -C third_party/v local=1
      make '"$BUILD_TARGET"' CX_COMMIT='"$CX_COMMIT"' CX_VFORK='"$CX_VFORK"' CX_RELEASE='"$CX_RELEASE"'
      T=linux-'"$arch"'
      mkdir -p "/tmp/$T"
      cp vcx/target/cx vcx/target/libcx.so include/cx.h "/tmp/$T/"
      cp third_party/re2/LICENSE "/tmp/$T/LICENSE-re2.txt"
      ( cd /tmp && tar czf "/out/cx-'"$TAG"'-$T.tar.gz" "$T/" )
      ( cd "/tmp/$T" && tar czf "/out/public/cx-$T.tar.gz" cx cx.h libcx.so LICENSE-re2.txt )
      # I4 (#651/#516): the §4 profile tarballs (see release.sh phase 2 for
      # the composition rationale) — cx-<profile>-linux-<arch>.tar.gz.
      make -C vcx '"$PROFILES_TARGET"' CX_COMMIT='"$CX_COMMIT"' CX_VFORK='"$CX_VFORK"' CX_RELEASE='"$CX_RELEASE"'
      for prof in data embed cli; do
        P="/tmp/prof-$prof"; mkdir -p "$P"
        cp "vcx/target/profiles/$prof/cx" "$P/"
        cp third_party/re2/LICENSE "$P/LICENSE-re2.txt"
        case "$prof" in
          data)  cp include/cx.h "$P/"; cp vcx/target/libcx-core.so "$P/" ;;
          embed) cp include/cx.h "$P/"; cp vcx/target/profiles/embed/libcx.so "$P/" ;;
        esac
        ( cd "$P" && tar czf "/out/public/cx-$prof-$T.tar.gz" ./* )
      done
      echo "-- engines probe:"; "/tmp/$T/cx" -v || true
      # R2.2 (#651/#516 remediation register, ruled (a) 2026-08-09): BLOCKING
      # per-profile install verification, linux lane — the same contract as
      # release.sh phase 2: every staged tarball must extract the way the
      # installer extracts it and its binary must report the expected profile
      # line, or the cut dies here (this script failing fails release.sh).
      # RULED: PGL-1 (#741) — ONE implementation, shared with release.sh and
      # with the standalone pre-cut lane. The lean container copy above
      # includes scripts/, so the file is here at /build; cwd is /build.
      . scripts/lib/r22_profile_gate.sh
      r22_profile_gate /out/public "$T" /linux
      echo "-- release gate (R2.2/linux): per-profile install verification PASSED ($T platform/data/embed/cli)"
    '
  ( cd dist/public && shasum -a 256 "$pub" ) || true
  echo "   → dist/public/${pub} + dist/${nested}"
}

build_one linux/arm64 arm64
if [ "$AMD64" = 1 ]; then
  build_one linux/amd64 x86_64
fi

echo
echo "Done. Upload with the release: gh release upload $TAG dist/public/cx-*linux*.tar.gz --clobber"
echo "(and refresh dist/SHA256SUMS.txt — scripts/release.sh write_sums — to include the linux tarballs before uploading it)"
