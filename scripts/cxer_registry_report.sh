#!/usr/bin/env bash
# cxer_registry_report.sh — CXER registry completeness report (corpus audit G18).
#
# Cross-checks every numeric CXER code EMITTED in vcx/{code,cx} against the
# ranges registered in governance.md §9.6. Reports emitted-but-unregistered
# codes — the #717 finding (similar/xap/fabric bands used but never registered),
# which caused two streams to mis-claim a band.
#
# REPORTING tool, not a hard gate: the known gaps are tracked (#717) and their
# registry repair is ruled campaign work (stream 10 §5). It becomes a
# TEST_TARGETS gate once the registry is repaired. Exit is always 0; the report
# is the product. `--strict` makes it exit 1 if any unregistered code is found
# (for use after the repair lands).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GOV="$ROOT/spec/03-approved/process/governance.md"
STRICT="${1:-}"

# Registered ranges from §9.6: parse `CXER<lo>–CXER<hi>`, `CXER<lo>–<hi>`, and
# bare `CXER<n>` inside the code-registry table rows (lines containing `cx-` or
# a spec path, to avoid prose).
# For each registry row, read the code column (up to the 2nd `|`) and extract
# every NNNN–NNNN range and every standalone NNNN — catching bare continuations
# like "CXER1500, 1502–1504" where the CXER prefix isn't repeated.
awk '
  /\| `CXER/ {
    n=split($0,parts,"|"); col=parts[2]  # the code column
    gsub(/CXER/,"",col)
    s=col
    # ranges first
    while (match(s, /[0-9]{4}–[0-9]{4}/)) {
      tok=substr(s,RSTART,RLENGTH); split(tok,a,"–"); print a[1]"\t"a[2]
      s=substr(s,1,RSTART-1) substr(s,RSTART+RLENGTH)
    }
    # then standalone 4-digit codes
    while (match(s, /[0-9]{4}/)) {
      tok=substr(s,RSTART,RLENGTH); print tok"\t"tok
      s=substr(s,1,RSTART-1) substr(s,RSTART+RLENGTH)
    }
  }
' "$GOV" | sort -n -u > /tmp/cxer_ranges.txt

# Emitted codes (numeric), excluding the 0000 placeholder and 9999 test sentinel.
# --include=*.v skips build artifacts (the cx.dylib debris) + binary matches.
grep -rhoE --include='*.v' "CXER[0-9]{4}" "$ROOT/vcx/code" "$ROOT/vcx/cx" 2>/dev/null \
  | sed 's/CXER//' | grep -E "^[0-9]{4}$" | sort -n -u | grep -vE "^(0000|9999)$" > /tmp/cxer_emitted.txt

unregistered=0
: > /tmp/cxer_unreg.txt
while IFS= read -r code; do
  covered=0
  while IFS=$'\t' read -r lo hi; do
    if [ "$((10#$code))" -ge "$((10#$lo))" ] && [ "$((10#$code))" -le "$((10#$hi))" ]; then covered=1; break; fi
  done < /tmp/cxer_ranges.txt
  if [ "$covered" -eq 0 ]; then echo "CXER$code" >> /tmp/cxer_unreg.txt; unregistered=$((unregistered+1)); fi
done < /tmp/cxer_emitted.txt

echo "cxer_registry_report: $(wc -l < /tmp/cxer_emitted.txt) distinct codes emitted; $(wc -l < /tmp/cxer_ranges.txt) registered ranges."
if [ "$unregistered" -ne 0 ]; then
  echo "UNREGISTERED (emitted but outside every §9.6 range) — $unregistered codes:"
  # Collapse to bands for readability.
  awk -F'CXER' '{print $2}' /tmp/cxer_unreg.txt | sort -n | awk '
    { c=$1+0
      if (prev=="" ) {lo=c; hi=c}
      else if (c==hi+1) {hi=c}
      else {printf "  CXER%04d-%04d\n", lo, hi; lo=c; hi=c}
      prev=c }
    END{ if(prev!="") printf "  CXER%04d-%04d\n", lo, hi }'
  echo "  → tracked as #717; registry repair is ruled campaign work."
  [ "$STRICT" = "--strict" ] && { echo "cxer_registry_report: STRICT FAIL"; exit 1; }
else
  echo "cxer_registry_report: OK — every emitted code is registered."
fi
exit 0
