#!/usr/bin/env bash
# tools/verify-doc-blocks.sh — every fenced ```cx ... ``` block in a
# markdown file must parse cleanly through `cx fmt`.
#
# Usage:
#   tools/verify-doc-blocks.sh                 # default: spec/ docs-src/ docs/ README.md
#   tools/verify-doc-blocks.sh README.md
#   tools/verify-doc-blocks.sh docs/ spec/
#
# A block whose first line is `# verify-skip` is exempt (for deliberately
# partial / illustrative fragments that are not standalone CX).
#
# Exit codes: 0 all blocks pass; 1 at least one block fails to parse;
# 2 usage error or no ```cx blocks found in any target (a fence verifier
# that verifies nothing must be loud, not green).

# Requires bash (arrays, process substitution). Re-exec if run via sh —
# including macOS /bin/sh, which is bash in POSIX mode (BASH_VERSION is set
# but process substitution is a parse error there).
if [ -z "${BASH_VERSION:-}" ] || [ -n "${POSIXLY_CORRECT:-}" ]; then
  if [ -n "${VERIFY_DOC_BLOCKS_REEXEC:-}" ]; then
    echo "FAIL: verify-doc-blocks.sh requires bash outside POSIX mode" >&2
    exit 2
  fi
  VERIFY_DOC_BLOCKS_REEXEC=1 exec /usr/bin/env bash "$0" "$@"
fi

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CX="$ROOT/vcx/target/cx"

if [ ! -x "$CX" ]; then
  echo "WARN: cx binary not at $CX — building..."
  (cd "$ROOT" && make -s build-vcx) || { echo "FAIL: cx build failed"; exit 1; }
fi

# Default targets: everywhere ```cx fences live.
if [ $# -eq 0 ]; then
  set -- "$ROOT/spec" "$ROOT/docs-src" "$ROOT/docs" "$ROOT/README.md"
fi

TARGETS=()
for arg in "$@"; do
  if [ -d "$arg" ]; then
    while IFS= read -r f; do TARGETS+=("$f"); done \
      < <(find "$arg" -name "*.md" -not -path "*/node_modules/*" | sort)
  elif [ -f "$arg" ]; then
    TARGETS+=("$arg")
  else
    echo "WARN: no such file or directory: $arg" >&2
  fi
done

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo "Usage: $0 [FILE.md|DIR ...]   (default: spec/ docs-src/ docs/ README.md)"
  exit 2
fi

PASS=0
FAIL=0
SKIP=0
FAIL_DETAILS=()

TMPDIR_BLOCKS="$(mktemp -d "${TMPDIR:-/tmp}/verify-doc-blocks.XXXXXX")"
trap 'rm -rf "$TMPDIR_BLOCKS"' EXIT

extract_cx_blocks() {
  # Write each ```cx block of $1 to $TMPDIR_BLOCKS/<n>.cx and print the
  # block count. Blocks go to individual files rather than a delimited
  # stream: BSD awk cannot emit NUL bytes (printf "\0" truncates the C
  # format string), and \b in awk EREs is a literal backspace, not a word
  # boundary — both broke earlier stream-based versions of this script.
  awk -v dir="$TMPDIR_BLOCKS" '
    /^```cx[ \t]*$/ { inblock=1; block=""; next }
    /^```[ \t]*$/   { if (inblock) { n++; out=dir "/" n ".cx"
                                     printf "%s", block > out; close(out)
                                     inblock=0 }
                      next }
    inblock         { block = block $0 "\n" }
    END             { print n + 0 }
  ' "$1"
}

for file in "${TARGETS[@]}"; do
  rm -f "$TMPDIR_BLOCKS"/*.cx
  nblocks="$(extract_cx_blocks "$file")"
  idx=0
  while [ "$idx" -lt "$nblocks" ]; do
    idx=$((idx + 1))
    BLOCK_FILE="$TMPDIR_BLOCKS/$idx.cx"
    if head -n 1 "$BLOCK_FILE" | grep -q '^# verify-skip'; then
      SKIP=$((SKIP + 1))
      continue
    fi
    # `cx fmt -` does not read stdin; feed it a real file.
    if "$CX" fmt "$BLOCK_FILE" > /dev/null 2>&1; then
      PASS=$((PASS + 1))
    else
      FAIL=$((FAIL + 1))
      FAIL_DETAILS+=("$file: block #$idx")
    fi
  done
done

TOTAL=$((PASS + FAIL + SKIP))
echo "verify-doc-blocks: $PASS passed, $FAIL failed, $SKIP skipped (${#TARGETS[@]} files scanned)"

if [ "$TOTAL" -eq 0 ]; then
  echo "FAIL: no \`\`\`cx blocks found in any target — nothing was verified" >&2
  exit 2
fi

if [ "$FAIL" -ne 0 ]; then
  echo ""
  echo "Broken blocks (re-run block through: $CX fmt <block.cx>):"
  for d in "${FAIL_DETAILS[@]}"; do echo "  $d"; done
  exit 1
fi
exit 0
