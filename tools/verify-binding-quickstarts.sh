#!/usr/bin/env bash
# tools/verify-binding-quickstarts.sh — every LIVE binding README must carry a
# well-formed "30-second quickstart" block.
#
# F7 from the evaluation-experience checklist.
#
# WHAT THIS CHECKS, exactly (#944 — the header used to claim the quickstart
# "runs without error", which this script has never done):
#   1. the README exists;
#   2. it has exactly ONE <!-- quickstart-begin: <lang> --> marker and exactly
#      ONE <!-- quickstart-end --> marker, in that order;
#   3. the begin marker names THIS binding;
#   4. a fenced code block opens inside the markers, tagged with the
#      binding's language;
#   5. the block body is non-empty.
# It does NOT execute the quickstart. Execution is owned by the per-binding
# suites — `make test-python` / `test-go` / `test-rust` / `test-v`, all four in
# TEST_TARGETS — which run against the real toolchains. Adding a second
# execution path here would make this row depend on four toolchains for no new
# signal.
#
# WHY THE BINDING SET IS A TABLE (#944 — the second defect):
# the loop used to iterate `python go rust typescript java kotlin csharp swift
# ruby` and take a SKIP branch when `lang/$lang/cxlib/README.md` was absent.
# Six of those nine were archived out of release scope at v0.8.0
# (lang/_archived/), so six of nine inputs COULD NOT FAIL and the gate reported
# "3 passed, 0 failed, 6 skipped" and read green over two-thirds unreachable
# scope. Worse, the hardcoded `cxlib/` path segment meant the V binding — one of
# the four LIVE ones — was never in scope at all: its README is at
# lang/v/README.md.
#
# So the set is now an explicit "<lang> <readme-path> <fence-tag>" table of the
# four live bindings (per lang/_archived/README.md: V/Python/Go/Rust cover the
# static/dynamic x compiled/interpreted spectrum), and there is NO SKIP BRANCH.
# A missing README is a FAILURE. Restoring an archived binding means adding its
# row here, which is the same commit that wires its test target.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# lang  readme-path (relative to ROOT)   fenced-block language tag
LIVE_BINDINGS="
v      lang/v/README.md            v
python lang/python/cxlib/README.md python
go     lang/go/cxlib/README.md     go
rust   lang/rust/cxlib/README.md   rust
"

PASS=0
FAIL=0
FAIL_DETAILS=()

fail() {
  FAIL=$((FAIL + 1))
  FAIL_DETAILS+=("$1")
}

while read -r lang readme fence; do
  [ -z "${lang:-}" ] && continue
  path="$ROOT/$readme"

  # 1. present. NOT a skip — an absent README for a live binding is the
  #    failure this gate exists to catch.
  if [ ! -f "$path" ]; then
    fail "$lang: no README at $readme (live binding — if it moved, update the LIVE_BINDINGS table; if it was archived, remove its row in the same commit that unwires its test target)"
    continue
  fi

  begin_count=$(grep -c 'quickstart-begin' "$path" || true)
  end_count=$(grep -c 'quickstart-end' "$path" || true)

  # 2. exactly one pair.
  if [ "$begin_count" -ne 1 ] || [ "$end_count" -ne 1 ]; then
    fail "$lang: expected exactly 1 quickstart-begin and 1 quickstart-end in $readme, found $begin_count and $end_count"
    continue
  fi

  begin_line=$(grep -n 'quickstart-begin' "$path" | head -1 | cut -d: -f1)
  end_line=$(grep -n 'quickstart-end' "$path" | head -1 | cut -d: -f1)

  if [ "$end_line" -le "$begin_line" ]; then
    fail "$lang: quickstart-end (line $end_line) precedes quickstart-begin (line $begin_line) in $readme"
    continue
  fi

  # 3. the begin marker names this binding.
  if ! grep -q "quickstart-begin: $lang" "$path"; then
    fail "$lang: begin marker in $readme does not name this binding (want '<!-- quickstart-begin: $lang -->')"
    continue
  fi

  # 4 + 5. inside the markers: a fence tagged for this language, and a
  #        non-empty body between the fences.
  body=$(sed -n "$((begin_line + 1)),$((end_line - 1))p" "$path")
  if ! printf '%s\n' "$body" | grep -q "^\`\`\`$fence\$"; then
    fail "$lang: no \`\`\`$fence fenced block inside the quickstart markers in $readme"
    continue
  fi
  code=$(printf '%s\n' "$body" | sed -n "/^\`\`\`$fence\$/,/^\`\`\`\$/p" | sed '1d;$d')
  code_lines=$(printf '%s\n' "$code" | grep -cv '^[[:space:]]*$' || true)
  if [ "$code_lines" -lt 3 ]; then
    fail "$lang: quickstart code block in $readme has $code_lines non-blank line(s) — a 30-second quickstart needs at least 3"
    continue
  fi

  PASS=$((PASS + 1))
done <<EOF
$LIVE_BINDINGS
EOF

echo "verify-binding-quickstarts: $PASS passed, $FAIL failed (4 live bindings; no skip branch — see header)"
if [ "$FAIL" -ne 0 ]; then
  echo ""
  echo "Broken quickstarts:"
  for d in "${FAIL_DETAILS[@]}"; do echo "  $d"; done
  exit 1
fi
exit 0
