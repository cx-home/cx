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
#   scripts/release_linux.sh --dev vX.Y.Z      # dev-shape build (fast; build validation only:
#                                               # stages and gates nothing)
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

# Pre-flight (#1674): the tree since RS-12's extraction. vcx/, the bundled
# stdlib and cx.h live in the pinned checkouts under deps/<repo>/ that
# `make deps-sync` populates (deps.cxd names them); the container has no cx to
# run deps-sync with, so it builds from the host's pins exactly as a fresh
# clone builds from its own -- deps-present inside the container is the same
# refusal, but four minutes and an apt-get later. Fail here instead.
if [ ! -d deps/cx-core-code/vcx ] || ! make -s --no-print-directory deps-present >/dev/null 2>&1; then
  echo "release_linux.sh: deps/ does not hold the pinned checkouts deps.cxd names" >&2
  echo "(make deps-present refuses). Run \`make deps-sync\` first: the container" >&2
  echo "copies deps/ from this tree and has no cx of its own to fetch them with." >&2
  exit 2
fi
# The vendored V bootstrap (third_party/v/vc) is gitignored and absent in most
# checkouts, the main one included. When it is present the container builds V
# from it as-is (local=1); when it is not, the fork's own GNUmakefile fetches
# vc and tccbin at the commits it pins (VC_COMMIT, TCCBIN_COMMIT -- cx #491,
# #504), so the bootstrap is reproducible either way and needs no seeding.
V_LOCAL=$([ -f third_party/v/vc/v.c ] && echo 1 || echo 0)
# A worktree may carry third_party/<x> as a SYMLINK to the main checkout's
# submodule (the agent worktree layout). The container sees only /src, where
# such a link dangles, so each linked directory's real path is mounted beside
# it and copied in from there.
TP_MOUNTS=()
for tp in v re2; do
  if [ -L "third_party/$tp" ]; then
    TP_MOUNTS+=(-v "$(cd "third_party/$tp" && pwd -P):/src-tp/$tp:ro")
  fi
done

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
# implementation of the rule (`make -C deps/cx-core-code/vcx print-CX_RELEASE`), evaluated on the
# host, where the tag and the working tree actually are. This script is invoked
# by the release flow BEFORE its merge-to-main step, so the host HEAD is the tagged
# commit at this point.
# --no-print-directory: `make -C` otherwise brackets the value with
# Entering/Leaving lines. Only the two known states are accepted — a probe that
# picked up noise must not silently decide a release artifact's provenance.
CX_RELEASE="$(make -s --no-print-directory -C deps/cx-core-code/vcx CX_STAMP_ROOT="$ROOT" print-CX_RELEASE 2>/dev/null | tail -1 | tr -d '[:space:]')"
case "$CX_RELEASE" in release|dev) ;; *) CX_RELEASE="" ;; esac
if [ -z "$CX_RELEASE" ]; then
  CX_RELEASE=dev
  echo "release_linux.sh: WARNING — could not read CX_RELEASE from deps/cx-core-code/vcx/Makefile;" >&2
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
    -v "$ROOT:/src:ro" ${TP_MOUNTS[@]+"${TP_MOUNTS[@]}"} -v "$ROOT/dist:/out" \
    -e SOURCE_DATE_EPOCH="$SDE" \
    -e R22_EXPECT_HEADLINE="${R22_EXPECT_HEADLINE:-}" \
    ubuntu:22.04 bash -euc '
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      apt-get install -y -qq build-essential libsqlite3-dev git make >/dev/null
      # Lean copy: only what the build consumes (the full checkout is ~13 GB
      # with .git/bindings/build outputs — copying it fills the Docker VM).
      # Since RS-12 (#1674) that is the front door`s build files — Makefile,
      # VERSION, deps.cxd, registry/ (deps-present derives the bundled
      # sources from modules.cxd), vcx/ (the module-main stay-files the build
      # links into the cx-core-code pin), scripts/, conformance/ and docs/llm —
      # and deps/: every pinned checkout, WITH its .git (deps-present asks git
      # for each V pin`s tracked modules and the core line of the version
      # stamp is the pin`s own HEAD), without its build output. A symlink with
      # an absolute target is a link into the HOST tree (sync-cmd-split`s
      # stay-file links, the nested deps/ farm) and dangles here, so it is
      # dropped and the build recreates it; third_party/v is the patched fork
      # the build contract requires.
      mkdir -p /build && cd /src
      tar cf - \
        --exclude="deps/*/vcx/target" \
        --exclude=third_party/v/v \
        --exclude=third_party/re2/obj \
        Makefile VERSION deps.cxd registry vcx scripts conformance docs/llm deps third_party \
        | tar xf - -C /build
      find /build/deps -type l -lname "/*" -delete
      for tp in v re2; do
        if [ -d "/src-tp/$tp" ]; then
          rm -rf "/build/third_party/$tp"; mkdir -p "/build/third_party/$tp"
          ( cd "/src-tp/$tp" && tar cf - --exclude=./v --exclude=./obj --exclude=./.git . ) | tar xf - -C "/build/third_party/$tp"
        fi
      done
      cd /build
      git config --global --add safe.directory "*"
      # local=1: build V from the vendored vc/tcc checkouts as-is when the
      # host carried them (the copied tcc tree is on a detached HEAD, so the
      # default refresh would fail on it); otherwise the fork fetches both at
      # its pinned commits.
      if [ '"$V_LOCAL"' = 1 ]; then make -C third_party/v local=1; else make -C third_party/v; fi
      make '"$BUILD_TARGET"' CX_COMMIT='"$CX_COMMIT"' CX_VFORK='"$CX_VFORK"' CX_RELEASE='"$CX_RELEASE"'
      # I4 (#651/#516): the §4 profile builds, through the front door`s own
      # target (vcx/ has no Makefile since RS-12; the sub-make is the pin`s).
      make '"$PROFILES_TARGET"' CX_COMMIT='"$CX_COMMIT"' CX_VFORK='"$CX_VFORK"' CX_RELEASE='"$CX_RELEASE"'
      if [ '"$DEV"' = 1 ]; then
        echo "-- dev build: the -dev artifacts built; nothing staged, R2.2 not run (build validation only)"
        exit 0
      fi
      # Staging is the shared implementation (RULED: PGL-1, #741): the same
      # r22_* functions the release flow`s package act stages the darwin
      # assets with, which read the artifacts where the split build lands
      # them (r22_vcx_target, r22_include_dir — #1670).
      . scripts/lib/r22_profile_gate.sh
      T=linux-'"$arch"'
      mkdir -p "/tmp/$T"
      r22_collect_platform_files "/tmp/$T"
      ( cd /tmp && tar czf "/out/cx-'"$TAG"'-$T.tar.gz" "$T/" )
      r22_tar_platform "/tmp/$T" /out/public "$T"
      # I4: the profile tarballs — cx-<profile>-linux-<arch>.tar.gz.
      r22_stage_profiles /out/public "$T"
      echo "-- engines probe:"; "/tmp/$T/cx" -v || true
      # R2.2 (#651/#516 remediation register, ruled (a) 2026-08-09): BLOCKING
      # per-profile install verification, linux build — the same contract as
      # the package act of the release flow: every staged tarball must extract the way the
      # installer extracts it and its binary must report the expected profile
      # line, or the cut dies here (this script failing fails the release flow).
      # RULED: PGL-1 (#741) — ONE implementation, shared with the release flow and
      # with the standalone pre-cut step. RLOAD-1 (#1131): R2.2 loads every
      # staged library through the extraction probe, built here from the pin.
      make build-extraction-probe
      r22_profile_gate /out/public "$T" /linux
      echo "-- release gate (R2.2/linux): per-profile install verification PASSED ($T platform/data/embed/cli)"
    '
  if [ "$DEV" = 1 ]; then
    echo "   → dev build validated; nothing staged"
    return 0
  fi
  ( cd dist/public && shasum -a 256 "$pub" ) || true
  echo "   → dist/public/${pub} + dist/${nested}"
}

build_one linux/arm64 arm64
if [ "$AMD64" = 1 ]; then
  build_one linux/amd64 x86_64
fi

echo
echo "Done. Upload with the release: gh release upload $TAG dist/public/cx-*linux*.tar.gz --clobber"
echo "(and refresh dist/SHA256SUMS.txt — the release flow's package act does — to include the linux tarballs before uploading it)"
