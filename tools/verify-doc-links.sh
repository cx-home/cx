#!/usr/bin/env bash
# tools/verify-doc-links.sh — every relative markdown link must
# resolve to an existing file in the repo.
#
# Usage:
# tools/verify-doc-links.sh README.md
# tools/verify-doc-links.sh docs/

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

TARGETS=()
for arg in "$@"; do
 if [ -d "$arg" ]; then
 while IFS= read -r f; do TARGETS+=("$f"); done < <(find "$arg" -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*")
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

# Extract `](RELATIVE)` links. Ignore http(s):// and mailto: and fragment-only.
for file in "${TARGETS[@]}"; do
 file_dir=$(dirname "$file")
 while IFS= read -r link; do
 # Strip any #anchor
 target="${link%%#*}"
 # Skip empty (was pure #anchor)
 if [ -z "$target" ]; then continue; fi
 # Resolve relative to the markdown file's directory
 resolved="$file_dir/$target"
 if [ -e "$resolved" ]; then
 PASS=$((PASS + 1))
 else
 FAIL=$((FAIL + 1))
 FAIL_DETAILS+=("$file → $target (resolved as $resolved)")
 fi
 done < <(grep -oE '\]\(([^)]+)\)' "$file" \
 | sed -E 's/^\]\(//; s/\)$//' \
 | grep -vE '^(https?:|mailto:|#)' \
 | grep -vE '^$')
done

echo "verify-doc-links: $PASS passed, $FAIL failed"
if [ $FAIL -ne 0 ]; then
 echo ""
 echo "Broken links:"
 for d in "${FAIL_DETAILS[@]}"; do echo " $d"; done
 exit 1
fi
exit 0
