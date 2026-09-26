#!/bin/sh
# scripts/release_asset_links_selftest.sh — the fixture-before-fix proof for
# scripts/release_asset_links_gate.cx (#1670).
#
# WHY THIS IS SHELL AND NOT CX (AGENTS.md rule 6; gap filed at
# cx-home/cx-private#1672 before this file was written): the RED half needs
# to download a real historical GitHub release asset (v0.17.0's darwin and
# linux tarballs) and verify its SHA-256 before the gate ever sees it.
# cx-stdlib has no capability-appropriate raw-binary-download primitive for
# this bootstrap context (the platform-group http-client is out of reach of
# a Ring 0/1 self-test, and reaching for it here would be the same "a check
# cannot depend on the thing it repairs" problem scripts/portable_links.sh's
# own header names) — docs/install, the mechanism being exercised, is
# POSIX sh for the identical reason.
#
# What this proves, run against THIS tree:
#   RED   — the gate FAILS on the real v0.17.0 darwin-arm64.tar.gz, naming
#           the exact /nix/store sqlite load path #1670 measured.
#   GREEN — the gate FAILS on nothing else: v0.17.0's linux-arm64 asset (which
#           had no gate to catch it either, and turns out clean — measured,
#           not assumed), and a staging directory built by THIS tree's own
#           (already-fixed, #1102) link step.
#
# Usage:
#   scripts/release_asset_links_selftest.sh [--stage-dir DIR]
#     --stage-dir DIR   a dist/public-shaped staging directory built by this
#                       tree (default: builds one via `make build-vcx
#                       build-profiles` + the same staging release.sh uses,
#                       into dist/_selftest_public/ — never dist/public/,
#                       for the same reason release_profile_gate.sh keeps its
#                       own dist/_precut_public/).
#
# Exit 0 only if BOTH the red and the green proofs land as expected; any
# other outcome (the historical asset now passing, or the fresh build still
# failing) is itself news and exits 1 with which half broke.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

STAGE_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --stage-dir) STAGE_DIR="$2"; shift 2 ;;
    *) echo "release_asset_links_selftest: unknown arg $1" >&2; exit 2 ;;
  esac
done

CX_BIN="${CX_BIN:-deps/cx-core-code/vcx/target/cx}"
[ -x "$CX_BIN" ] || { echo "release_asset_links_selftest: no cx at $CX_BIN — run make build-vcx first (or set CX_BIN)" >&2; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO="cx-home/cx"
HIST_TAG="v0.17.0"
BASE="https://github.com/$REPO/releases/download/$HIST_TAG"

echo "== #1670 self-test: fetching the historical $HIST_TAG assets (docs/install's own resolution, pinned to this tag) =="
curl -sSL -o "$TMP/SHA256SUMS" "$BASE/SHA256SUMS.txt"
for asset in cx-darwin-arm64.tar.gz cx-linux-arm64.tar.gz; do
  echo "   downloading $asset"
  curl -sSL -o "$TMP/$asset" "$BASE/$asset"
  ( cd "$TMP" && grep " $asset\$" SHA256SUMS | shasum -a 256 -c - ) \
    || { echo "release_asset_links_selftest: $asset failed SHA-256 verification against $HIST_TAG's published sums" >&2; exit 1; }
done

echo "== RED proof: the gate must FAIL on the real $HIST_TAG darwin asset =="
if "$CX_BIN" --allow-all scripts/release_asset_links_gate.cx --check-file "$TMP/cx-darwin-arm64.tar.gz" 2>"$TMP/darwin.err"; then
  echo "release_asset_links_selftest: FAILED — the gate passed $HIST_TAG's darwin asset, which is known-broken (#1670). The class regressed, or the gate does." >&2
  exit 1
fi
grep -q '/nix/store/' "$TMP/darwin.err" || { echo "release_asset_links_selftest: the gate failed for the wrong reason (no /nix/store line in its output)" >&2; cat "$TMP/darwin.err" >&2; exit 1; }
echo "   RED confirmed — $(grep -m1 '/nix/store/' "$TMP/darwin.err" | sed 's/^ *//')"

echo "== measurement: the real $HIST_TAG LINUX asset, checked (not assumed) clean =="
if ! "$CX_BIN" --allow-all scripts/release_asset_links_gate.cx --check-file "$TMP/cx-linux-arm64.tar.gz"; then
  echo "release_asset_links_selftest: NEWS — $HIST_TAG's linux asset now fails the gate too (previously measured clean; see RESULTS.md)" >&2
  exit 1
fi
echo "   confirmed clean (no /nix/store dependency on the linux asset)"

echo "== GREEN proof: this tree's OWN staged build must PASS =="
if [ -z "$STAGE_DIR" ]; then
  STAGE_DIR="dist/_selftest_public"
  rm -rf "$STAGE_DIR"; mkdir -p "$STAGE_DIR"
  . scripts/lib/r22_profile_gate.sh
  PLAT="darwin-arm64"
  echo "   building this tree's release artifacts (build-vcx + build-profiles)"
  make build-vcx build-profiles >"$TMP/build.log" 2>&1 || { echo "release_asset_links_selftest: build failed — see $TMP/build.log" >&2; tail -40 "$TMP/build.log" >&2; exit 1; }
  SRC="$STAGE_DIR/_plat"; mkdir -p "$SRC"
  r22_collect_platform_files "$SRC"
  r22_tar_platform "$SRC" "$ROOT/$STAGE_DIR" "$PLAT"
  rm -rf "$SRC"
  r22_stage_profiles "$STAGE_DIR" "$PLAT"
fi
if ! "$CX_BIN" --allow-all scripts/release_asset_links_gate.cx --dir "$STAGE_DIR"; then
  echo "release_asset_links_selftest: FAILED — this tree's own staged build did not pass its own gate" >&2
  exit 1
fi
echo "   GREEN confirmed — $STAGE_DIR's staged assets carry no /nix/store dependency"

echo
echo "release_asset_links_selftest: PASSED — red on $HIST_TAG's darwin asset, measured-clean on its linux asset, green on this tree's own build."
