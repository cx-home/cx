#!/usr/bin/env bash
# Retired-surface scan for guide sources (companion to the snippet gate).
#
# The snippet gate proves examples PARSE — but several retired forms parse
# successfully as something else (`:table[` becomes an atom + strings,
# `[port :u16 8080]` becomes an atom child), so a parse-only gate cannot
# catch them. This scan rejects the known parseable-but-wrong families in
# docs-src/canonical/sections/. Lines that must show a retired form on
# purpose (migration panels) carry the marker `retired-ok` on the same
# line to be waived.
set -euo pipefail
cd "$(dirname "$0")/../.."

SECTIONS=docs-src/canonical/sections
fail=0

scan() {
  local label="$1" pattern="$2"
  local hits
  hits=$(grep -rnE "$pattern" "$SECTIONS" | grep -v 'retired-ok' || true)
  if [ -n "$hits" ]; then
    echo "check-retired-surface: FAIL — $label:"
    echo "$hits"
    fail=1
  fi
}

# Retired :table[ block form (current: [table[col::type …]] block child).
scan "retired ':table[' form" ':table\['
# Retired spaced single-colon type annotation in body position
# (current: glued ::T on the name). Excludes the doubled ::T ascription.
scan "retired spaced ':T' body annotation" '\[[A-Za-z_-]+ :(u8|u16|u32|u64|i8|i16|i32|i64|int|float|f32|f64|decimal|bigint|date|time|datetime|bool|str|string|bytes)\[?\]? '
# Retired single-colon typed-array annotation (current: ::T[] / ::[]).
scan "retired ':T[]' array annotation" '\[[A-Za-z_-]+ :\[\]| :(int|str|string|float|bool)\[\]'

if [ "$fail" -eq 0 ]; then
  echo "check-retired-surface: OK — no retired parseable-but-wrong forms in $SECTIONS"
fi
exit "$fail"
