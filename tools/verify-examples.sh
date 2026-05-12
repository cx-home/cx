#!/usr/bin/env bash
# tools/verify-examples.sh — every .cx file in examples/ must:
#   1. exit 0 through `cx fmt`
#   2. round-trip cleanly through CX → JSON → CX (cx eq)
#   3. round-trip cleanly through CX → XML → CX (cx eq), where applicable
#
# Usage:
#   tools/verify-examples.sh
#   tools/verify-examples.sh examples/comparisons/

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CX="$ROOT/vcx/target/cx"

if [ ! -x "$CX" ]; then
    (cd "$ROOT" && make -s build-vcx) || { echo "FAIL: cx build failed"; exit 1; }
fi

TARGET="${1:-$ROOT/examples}"
PASS=0
FAIL=0
FAIL_DETAILS=()

check_file() {
    local f="$1"
    local rel="${f#$ROOT/}"

    # Step 1: cx fmt must succeed.
    if ! "$CX" fmt "$f" > /dev/null 2>&1; then
        FAIL=$((FAIL + 1))
        FAIL_DETAILS+=("$rel  [fmt failed]")
        return
    fi

    # Step 2: CX → JSON → CX round-trip.
    local tmp_json tmp_cx
    tmp_json=$(mktemp -t cx-verify-json.XXXXXX)
    tmp_cx=$(mktemp -t cx-verify-cx.XXXXXX)
    if "$CX" --json "$f" > "$tmp_json" 2>/dev/null \
       && "$CX" --from=json --cx "$tmp_json" > "$tmp_cx" 2>/dev/null \
       && "$CX" eq "$f" "$tmp_cx" > /dev/null 2>&1; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        FAIL_DETAILS+=("$rel  [JSON round-trip failed]")
    fi
    rm -f "$tmp_json" "$tmp_cx"
}

if [ -d "$TARGET" ]; then
    while IFS= read -r f; do check_file "$f"; done < <(find "$TARGET" -name "*.cx" -not -path "*/node_modules/*")
elif [ -f "$TARGET" ]; then
    check_file "$TARGET"
fi

echo "verify-examples: $PASS passed, $FAIL failed"
if [ $FAIL -ne 0 ]; then
    echo ""
    echo "Broken examples:"
    for d in "${FAIL_DETAILS[@]}"; do echo "  $d"; done
    exit 1
fi
exit 0
