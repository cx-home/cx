#!/usr/bin/env bash
# tools/libcx-abi-gate.sh — the libcx ABI surface gate (#888).
#
# WHAT CHANGED AND WHY (2026-08-20, UOM-1 rider r4):
# The gate used to diff the FULL `nm` export list against a pinned baseline —
# 714 symbols, of which only 171 were CX's. The other 543 were vendored
# statics: 356 C++-mangled re2/abseil symbols and 187 zstd ones. Those move
# with the C++ toolchain vintage and with any dependency rebuild, so the gate
# would go red with NO change to any CX surface. A gate that cries wolf on
# toolchain churn trains its readers to re-bless the baseline reflexively,
# which is exactly how a REAL ABI break slips through.
#
# The gate now checks the two things that are actually contracts:
#
#   1. THE CX EXPORT SURFACE — symbols named `cx_*` (the documented C ABI,
#      include/cx.h) plus `vgc_*` (the runtime's GC entry points, which the
#      embedding contract exposes). Diffed against a pinned, platform-neutral
#      baseline; ANY addition, removal or rename is a hard failure.
#   2. HEADER/BINARY AGREEMENT — every function declared in include/cx.h is
#      actually exported by the built library. This catches the failure the
#      old gate never could: a declared entry point silently dropped from the
#      build. Comments are stripped before extraction, so a retired symbol
#      discussed in prose (e.g. cx_node_id) is not mistaken for a decl.
#
# Vendored symbols are COUNTED and printed as an advisory line, never
# asserted — drift there is visible in logs without being able to fail a
# release.
#
# Platform: symbol names are normalized by stripping the Mach-O leading
# underscore, so ONE baseline serves Darwin and Linux. The old gate skipped
# Linux entirely for want of a second baseline; it no longer has to.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="${1:-}"
BASELINE="$ROOT/vcx/tests/runners/abi_gate/libcx_abi_surface.txt"
HEADER="$ROOT/include/cx.h"

if [ -z "$LIB" ] || [ ! -f "$LIB" ]; then
  echo "libcx-abi-gate FAILED — library artifact not found: ${LIB:-<none given>}"
  exit 1
fi
if [ ! -f "$BASELINE" ]; then
  echo "libcx-abi-gate FAILED — missing baseline $BASELINE"
  exit 1
fi

# ── extract the defined, global export list ────────────────────────────────
case "$(uname -s)" in
  Darwin) RAW="$(nm -gU "$LIB" | awk '{print $3}')" ;;
  *)      RAW="$(nm -D --defined-only "$LIB" | awk '{print $3}')" ;;
esac

NORM="$(printf '%s\n' "$RAW" | sed 's/^_//' | grep -v '^$' | sort -u)"
SURFACE="$(printf '%s\n' "$NORM" | grep -E '^(cx_|vgc_)' | sort)"
VENDORED_COUNT="$(printf '%s\n' "$NORM" | grep -cvE '^(cx_|vgc_)')"

CUR="$(mktemp)"; trap 'rm -f "$CUR" "$HDR"' EXIT
printf '%s\n' "$SURFACE" > "$CUR"

FAIL=0

# ── 1. the CX export surface is pinned ─────────────────────────────────────
if diff -u "$BASELINE" "$CUR" > /tmp/libcx_abi_diff.$$ 2>&1; then
  echo "libcx-abi-gate: CX export surface identical to baseline ($(wc -l < "$CUR" | tr -d ' ') symbols)"
else
  echo "libcx-abi-gate FAILED — the CX export surface changed:"
  cat /tmp/libcx_abi_diff.$$
  echo "  (baseline: vcx/tests/runners/abi_gate/libcx_abi_surface.txt — re-bless ONLY with a"
  echo "   deliberate ABI change, recorded per the governance versioning rules)"
  FAIL=1
fi
rm -f /tmp/libcx_abi_diff.$$

# ── 2. every declared entry point is exported ──────────────────────────────
HDR="$(mktemp)"
if [ -f "$HEADER" ]; then
  perl -0777 -pe 's{/\*.*?\*/}{}gs; s{//[^\n]*}{}g' "$HEADER" \
    | grep -oE '\bcx_[a-z0-9_]+[[:space:]]*\(' \
    | sed -E 's/[[:space:]]*\($//' | sort -u > "$HDR"
  MISSING="$(comm -23 "$HDR" "$CUR")"
  if [ -n "$MISSING" ]; then
    echo "libcx-abi-gate FAILED — declared in include/cx.h but NOT exported:"
    printf '  %s\n' $MISSING
    FAIL=1
  else
    echo "libcx-abi-gate: header agreement OK ($(wc -l < "$HDR" | tr -d ' ') declared entry points, all exported)"
  fi
else
  echo "libcx-abi-gate: no include/cx.h — header cross-check skipped"
fi

# ── 3. vendored statics: advisory only ─────────────────────────────────────
echo "libcx-abi-gate: ${VENDORED_COUNT} vendored/toolchain symbols present (advisory — not asserted; see #888)"

exit $FAIL
