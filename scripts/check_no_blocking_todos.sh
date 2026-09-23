#!/usr/bin/env bash
#
# Gate 10 helper — fail if any BLOCKING-tagged TODO/FIXME/XXX remains
# in the V reference implementation tree (vcx/code/ and adjacent).
#
# A "blocking" marker is one of:
#   - TODO(BLOCKING):
#   - FIXME(BLOCKING):
#   - XXX(BLOCKING):
#   - TODO(v0.8.0):
#   - FIXME(v0.8.0):
#
# Non-blocking markers (TODO(v0.8.x), TODO(post-v0.8.0), DEFERRED:,
# INFO:, etc.) are allowed and informational only.
#
# Exit 0 if no blocking markers; exit 1 otherwise.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Scan only the v0.8.0 reference implementation tree.
TARGETS=(
    "$ROOT/vcx/code"
    "$ROOT/vcx/platform"
)
# RS-24: every split V product directory registry/repos.cxd declares (vmodule=).
for _m in $( { grep -oE "vmodule=[a-z_][a-z0-9_]*" "$ROOT/registry/repos.cxd" 2>/dev/null || true; } | cut -d= -f2 | { grep -vx platform || true; }); do
    TARGETS+=("$ROOT/vcx/$_m")
done
TARGETS+=(
    "$ROOT/deps/cx-core-data/vcx/cx/cabi.v"   # cx-core-data, pinned (RULED: RS-12)
    "$ROOT/vcx/cmd"
    "$ROOT/include/cx.h"
)

# Legacy fallback for the old layout (vcx/programs/ → vcx/code/);
# kept as a defensive guard when running on archived worktrees.
[[ ! -d "$ROOT/vcx/code" ]] && [[ -d "$ROOT/vcx/programs" ]] && \
    TARGETS=("$ROOT/vcx/programs" "$ROOT/vcx/cx/cabi.v" "$ROOT/vcx/cmd" "$ROOT/include/cx.h")

PATTERN='(TODO|FIXME|XXX)\((BLOCKING|v0\.8\.0)\)'

hits=$(grep -rEn "$PATTERN" "${TARGETS[@]}" 2>/dev/null || true)

if [[ -z "$hits" ]]; then
    echo "Gate 10: no blocking TODOs in V reference impl."
    exit 0
fi

echo "Gate 10 FAIL — blocking TODOs found:"
echo
echo "$hits"
echo
echo "Resolve or downgrade these markers before tagging v0.8.0."
exit 1
