#!/usr/bin/env bash
# tools/verify-doc-blocks.sh — every fenced ```cx ... ``` block in a
# markdown file must parse cleanly through `cx fmt`.
#
# PARSE, not format (RULED: INT-7). Since 1391-a `cx fmt` refuses instead of
# failing open: a block it cannot lay out is DECLINED (cx-err:CXER0301, source
# unchanged) and a block whose canonical form would change the node tree is
# REFUSED (cx-err:CXER0300). Both verdicts are reached AFTER the block parsed —
# the formatter compared trees it had built — so here they are "parsed, not
# formattable": counted, listed, never a failure. The first post-merge run
# after INT-2 (861ca66ec) read 50 such blocks as parse failures; every one of
# the four re-checked parses under `cx lint`. Any other non-zero exit from
# `cx fmt` (a parse error, a crash) still fails this step.
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
CX="${CX_BIN:-$ROOT/vcx/target/cx}"   # CX_BIN: the Makefile's spelling, for a worktree without a build

if [ ! -x "$CX" ]; then
  echo "WARN: cx binary not at $CX — building..."
  (cd "$ROOT" && make -s build-vcx) || { echo "FAIL: cx build failed"; exit 1; }
fi

# Default targets: everywhere ```cx fences live.
#
# corpus/ joined the set (#957): the rosetta write-ups each quote their
# program in a fenced block, and every one of them had drifted to
# pre-reshape syntax while the .cx beside it was current — the block said
# `[?for $n :in 1 to 30 :yield …]` next to a file that says
# `[?for [in $n [$range 1 30]] …]`. Nothing checked them, so the flagship
# teaching material taught a surface that no longer exists.
if [ $# -eq 0 ]; then
  set -- "$ROOT/spec" "$ROOT/docs-src" "$ROOT/docs" "$ROOT/corpus" "$ROOT/README.md"
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
UNFMT=0
FAIL_DETAILS=()
UNFMT_DETAILS=()

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
    # RULED: SPG-1 (#916) — here-string, not `head … | grep -q`: under
    # pipefail, grep -q's early exit SIGPIPEs the producer (141) and fails
    # the guard on input that matched.
    if grep -q '^# verify-skip' <<< "$(head -n 1 "$BLOCK_FILE")"; then
      SKIP=$((SKIP + 1))
      continue
    fi
    # `cx fmt -` does not read stdin; feed it a real file. The verdict is
    # read from the refusal line, not the exit alone: `cx fmt` has ONE
    # non-zero exit for a decline, a refusal and a parse error.
    if FMT_ERR="$("$CX" fmt "$BLOCK_FILE" 2>&1 > /dev/null)"; then
      PASS=$((PASS + 1))
    elif grep -qE 'cx-err:CXER030[01]' <<< "$FMT_ERR"; then
      UNFMT=$((UNFMT + 1))
      UNFMT_DETAILS+=("$file: block #$idx — ${FMT_ERR%%;*}")
    else
      FAIL=$((FAIL + 1))
      FAIL_DETAILS+=("$file: block #$idx — ${FMT_ERR%%$'\n'*}")
    fi
  done
done

TOTAL=$((PASS + FAIL + SKIP + UNFMT))
echo "verify-doc-blocks: $PASS passed, $FAIL failed, $UNFMT parsed but not formattable, $SKIP skipped (${#TARGETS[@]} files scanned)"
if [ "$UNFMT" -ne 0 ]; then
  echo "Parsed, not formattable (the formatter's own census — #1436 and the TREE-REFUSED column; not this step's failures):"
  for d in "${UNFMT_DETAILS[@]}"; do echo "  $d"; done
fi

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
