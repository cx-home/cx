#!/usr/bin/env bash
# Reproducible-build runner (BB / v0.8.0).
#
# Builds libcx / libcx_arrow / cli from a clean checkout with pinned
# toolchain versions and emits SHA-256 hashes of every release
# artifact. Cf. docs/reproducible_builds.md.
#
# Usage:
#   scripts/reproduce_release.sh [TAG]
#
# When TAG is given, the script checks out that ref before building.
# Without a TAG it builds whatever's currently checked out (useful in
# CI where the workflow already checked out the tag).
#
# Outputs:
#   dist/SHA256SUMS.reproduced.txt   the per-artifact hash table
#
# If dist/SHA256SUMS.txt exists (the published table for the same tag),
# the script diffs the two and exits non-zero on mismatch. CI uses
# this for the BB3 reproducibility gate.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

TAG="${1:-}"
if [[ -n "$TAG" ]]; then
  echo "[reproduce] checking out $TAG"
  git -c advice.detachedHead=false checkout "$TAG"
fi

# Pinned toolchain — every reproducer must match these exact versions
# or the resulting hashes won't agree. The check below records the
# observed versions; CI emits a warning when they drift from the
# pinned set in docs/reproducible_builds.md.
V_VERSION="$(v --version 2>/dev/null | head -1 || echo 'V not installed')"
CC_VERSION="$(cc --version 2>/dev/null | head -1 || echo 'cc not installed')"
echo "[reproduce] toolchain:"
echo "    V        : $V_VERSION"
echo "    cc       : $CC_VERSION"
echo "    SOURCE_DATE_EPOCH: ${SOURCE_DATE_EPOCH:-unset}"

# Force deterministic timestamps. The published dist/SHA256SUMS.txt
# was produced with SOURCE_DATE_EPOCH set to the tag's commit date;
# reproducers should match that. Without it, V's embedded build-time
# constants and any timestamped resources would drift.
if [[ -z "${SOURCE_DATE_EPOCH:-}" ]]; then
  if [[ -n "$TAG" ]]; then
    export SOURCE_DATE_EPOCH="$(git log -1 --format=%ct "$TAG")"
  else
    export SOURCE_DATE_EPOCH="$(git log -1 --format=%ct HEAD)"
  fi
  echo "[reproduce] auto-set SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH"
fi

# Clean tree.
make clean >/dev/null

# Build the three release artifacts.
echo "[reproduce] building libcx + cli + libcx_arrow"
make build-vcx build-lib-arrow >/dev/null

# Hash artifacts. Sorted by path for stable output.
mkdir -p dist
{
  for f in vcx/target/libcx.dylib vcx/target/libcx.so vcx/target/libcx_arrow.dylib vcx/target/libcx_arrow.so vcx/target/cx; do
    if [[ -f "$f" ]]; then
      printf '%s  %s\n' "$(shasum -a 256 "$f" | cut -d' ' -f1)" "$(basename "$f")"
    fi
  done
} | sort > dist/SHA256SUMS.reproduced.txt

echo "[reproduce] artifact hashes (dist/SHA256SUMS.reproduced.txt):"
cat dist/SHA256SUMS.reproduced.txt

# Compare against the published table when present.
if [[ -f dist/SHA256SUMS.txt ]]; then
  if diff -u dist/SHA256SUMS.txt dist/SHA256SUMS.reproduced.txt; then
    echo "[reproduce] match — build is reproducible against published SHA256SUMS.txt"
  else
    echo "[reproduce] MISMATCH — see diff above"
    exit 1
  fi
else
  echo "[reproduce] no published dist/SHA256SUMS.txt to compare against"
fi
