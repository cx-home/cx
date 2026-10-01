#!/usr/bin/env bash
#
# scripts/release_profile_gate.sh — run the R2.2 BLOCKING per-profile
# install verification WITHOUT cutting a release.
#
# RULED: PGL-1 (#741, ledger/rulings_2026_08_22_profile_gate_lane.md).
# Why this exists: the R2.2 gate lived only inside scripts/release.sh
# phase 2, in the arm that `--dry-run` skips, so its first execution was
# always inside a real cut — a blocking gate nobody had ever run. This
# step stages the same four tarballs a cut stages, from the same -prod
# build targets, and runs the same shared gate function against them.
#
# Deliberately stages into dist/_precut_public/ and NOT dist/public/: a
# pre-cut run must never be mistakable for real staged release assets.
#
# Usage:  scripts/release_profile_gate.sh
#         make release-profile-gate
#
# No arguments, no escape hatches: the point is to gate the bytes a cut
# would ship, so the build targets are the cut's own (-prod) targets. A
# dev-build variant would gate different bytes while reading as green.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

. "$ROOT/scripts/lib/r22_profile_gate.sh"

ARCH="$(uname -m)"; OS_RAW="$(uname -s | tr '[:upper:]' '[:lower:]')"
PUB_PLAT="${OS_RAW}-${ARCH}"   # darwin-arm64 / linux-x86_64 — the release flow's stable public name

PUB="dist/_precut_public"

printf '\n== R2.2 pre-cut profile gate (%s) ==\n' "$PUB_PLAT"

echo "-- building the cut's artifacts (-prod: build-vcx + build-profiles) and the loading probe"
devbox run -- make build-vcx
devbox run -- make build-profiles
devbox run -- make build-extraction-probe

echo "-- staging the four tarballs the cut stages → $PUB/"
rm -rf "$PUB"; mkdir -p "$PUB"
SRC="$PUB/_plat"; mkdir -p "$SRC"
r22_collect_platform_files "$SRC"
r22_tar_platform "$SRC" "$ROOT/$PUB" "$PUB_PLAT"
rm -rf "$SRC"
r22_stage_profiles "$PUB" "$PUB_PLAT"
ls -1 "$PUB"/cx-*.tar.gz | sed 's/^/   /'

# #1670 — same placement as the release flow: ahead of R2.2's install verification,
# which extracts-and-probes but never reads a Mach-O/ELF dependency graph.
echo "-- running the release-asset-links gate (#1670: no /nix/store dependency)"
devbox run -- "$(r22_vcx_target)/cx" --allow-all scripts/release_asset_links_gate.cx --dir "$PUB"

echo "-- running the BLOCKING gate (extract installer-style + profile probe + each library loaded, RLOAD-1)"
r22_profile_gate "$PUB" "$PUB_PLAT" /precut

echo "   release gate (R2.2/precut): per-profile install verification PASSED (platform/data/embed/cli extract + profile probe; each staged library's inventory and cx_features identical to the build's own)"
echo "   NOTE: this proves #741 item 1 only. Item 2 (CX_PROFILE= install from the"
echo "         PUBLISHED assets on macOS + Linux) requires the cut to have happened."
