#!/usr/bin/env bash
# tools/verify-doc-blocks.sh — every fenced ```cx ... ``` block in a
# markdown file must parse cleanly through `cx fmt`.
#
# Usage:
# tools/verify-doc-blocks.sh README.md
# tools/verify-doc-blocks.sh docs/

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CX="$ROOT/vcx/target/cx"

if [ ! -x "$CX" ]; then
 echo "WARN: cx binary not at $CX — building..."
 (cd "$ROOT" && make -s build-vcx) || { echo "FAIL: cx build failed"; exit 1; }
fi

TARGETS=()
for arg in "$@"; do
 if [ -d "$arg" ]; then
 while IFS= read -r f; do TARGETS+=("$f"); done < <(find "$arg" -name "*.md" -not -path "*/node_modules/*")
 elif [ -f "$arg" ]; then
 TARGETS+=("$arg")
 fi
done

if [ ${#TARGETS[@]} -eq 0 ]; then
 echo "Usage: $0 FILE.md [FILE.md ...]"
 echo " or: $0 DIR/"
 exit 2
fi

PASS=0
FAIL=0
FAIL_DETAILS=()

extract_cx_blocks() {
 # Output: one block per call, newline-delimited, separated by NUL.
 awk '
 /^```cx\b/ { inblock=1; block=""; next }
 /^```$/ { if (inblock) { print block; printf "\0"; inblock=0; block="" } ; next }
 inblock { block = block $0 "\n" }
 ' "$1"
}

for file in "${TARGETS[@]}"; do
 idx=0
 while IFS= read -r -d '' block; do
 idx=$((idx + 1))
 # Skip blocks marked with HTML comment hint that they're not standalone.
 if echo "$block" | grep -q "^# verify-skip\b" 2>/dev/null; then
 continue
 fi
 if echo "$block" | "$CX" fmt - > /dev/null 2>&1; then
 PASS=$((PASS + 1))
 else
 FAIL=$((FAIL + 1))
 FAIL_DETAILS+=("$file: block #$idx")
 fi
 done < <(extract_cx_blocks "$file")
done

echo "verify-doc-blocks: $PASS passed, $FAIL failed"
if [ $FAIL -ne 0 ]; then
 echo ""
 echo "Broken blocks:"
 for d in "${FAIL_DETAILS[@]}"; do echo " $d"; done
 exit 1
fi
exit 0
