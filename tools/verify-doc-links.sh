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
 while IFS= read -r f; do TARGETS+=("$f"); done < <(find "$arg" -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/_archive/*")
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
# Fenced code blocks and inline code spans are stripped first — text inside
# them renders literally, so `[text](url)` examples and code like
# `Project[User](doc.Filter(...))` are not links.
#
# Code-span stripping is WHOLE-FILE, not per line (#837). A code span may
# wrap across a newline — CommonMark allows it, and CX prose does it often
# because bracketed element spans are long:
#
#     A **substrate-provided PURE projection** `[sequence entry] → [sequence
#     entry]`, parameterized by `(tx-position, valid-instant)`, composed
#
# Stripped line by line, the first line has an ODD number of backticks, so
# nothing matches there; on the second line the stripper pairs the SPAN'S
# CLOSING backtick with the next opening one and removes the text between
# them — leaving `entry](tx-position, valid-instant)` and inventing a link
# that does not exist in the source. That false positive is expensive:
# scripts/release.sh runs this gate and must refuse to publish on a red one.
#
# Slurping alone is not enough either. A code span is delimited by a RUN of
# backticks and closed by a run of the SAME length (CommonMark), so `code.md`'s
# eight ``double-backtick`` spans — among 9,235 single ones — read as two
# adjacent spans under a naive `[^`]*` and desynchronise every span after
# them. That produced seven MORE invented links, not fewer.
#
# The rule below is the CommonMark one: an opening run that is maximal (no
# backtick either side), then the shortest text up to a closing run of the
# same length, equally maximal. Verified over all 118 approved specs: zero
# broken links, where the previous two spellings reported one and seven
# phantoms respectively.
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
 done < <(awk 'BEGIN{fence=0} /^[[:space:]]*(```|~~~)/{fence=!fence; next} !fence' "$file" \
 | perl -0777 -pe 's/(?<!`)(`+)(?!`)(.*?)(?<!`)\1(?!`)//gs' \
 | grep -oE '\]\(([^)]+)\)' \
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
