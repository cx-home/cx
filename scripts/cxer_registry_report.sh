#!/usr/bin/env bash
# cxer_registry_report.sh — CXER registry completeness report (corpus audit G18).
#
# Cross-checks every numeric CXER code EMITTED or ASSERTED in the tree against
# the ranges registered in governance.md §9.6, and cross-checks band CLAIMS
# across specs for the two-owners-in-one-range class (#723 / audit C5 — the
# original tool answered only "inside some range" and could not see a second
# owner inside an approved band).
#
# Scope (hardened per #723, M38):
#   emissions  — every *.v under ALL of vcx/ (code, cx, cxstore, cmd,
#                transport, arrow, deps, tools, ...), with //-comment text
#                stripped so commented codes don't count; every stdlib/*.cx
#                bundle (#-comment text stripped).
#   assertions — every conformance/**/*.cxd fixture (out-err codes are
#                normative claims and must be registered like emissions).
#   registry   — §9.6 rows, honoring sparse-list parentheticals: a
#                "(NNNN–NNNN excluded)" / "(NNNN excluded)" note SUBTRACTS
#                from the row's coverage instead of widening it.
#   spec bands — every `CXER<lo>–<hi>` RANGE claim anywhere under spec/
#                (single-code references are cross-spec citations, not
#                claims; ranges are allocation-shaped). Intersecting range
#                claims from two different files are reported for review.
#
# Known blind spot (recorded, not solved here): codes composed at runtime
# ("CXER${num}" string interpolation) are invisible to a static scan.
#
# REPORTING tool, not a hard gate: known gaps are tracked (#717) and their
# registry repair is ruled campaign work (audit C5 repair). `--strict` exits 1
# on any emitted-but-unregistered code or any registry-internal row overlap
# (the mechanical certainties; spec-vs-spec intersections stay review items) —
# wire --strict into TEST_TARGETS once the C5 registry-repair PR lands.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GOV="$ROOT/spec/03-approved/process/governance.md"
STRICT="${1:-}"

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/cxer_report.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT
ranges="$tmpdir/ranges.txt"          # lo<TAB>hi   (registry coverage)
excluded="$tmpdir/excluded.txt"      # lo<TAB>hi   (registry sparse-list holes)
emitted="$tmpdir/emitted.txt"
unreg="$tmpdir/unreg.txt"
claims="$tmpdir/claims.txt"          # lo<TAB>hi<TAB>file:line (spec band claims)

# ── Registry rows (§9.6). The code column is everything up to the 2nd `|`.
# Parenthetical "excluded" notes inside the column subtract; everything else
# (ranges first, then standalone codes — catching bare continuations like
# "CXER1500, 1502–1504") adds.
awk '
  function scan(s, dest,   tok, a) {
    # NOTE: the en-dash is multi-byte UTF-8 — it must be matched by
    # alternation, never inside a bracket class (byte-based in POSIX awk).
    while (match(s, /[0-9]{4}(–|-)[0-9]{4}/)) {
      tok=substr(s,RSTART,RLENGTH); split(tok,a,/–|-/); print a[1]"\t"a[2] > dest
      s=substr(s,1,RSTART-1) substr(s,RSTART+RLENGTH)
    }
    while (match(s, /[0-9]{4}/)) {
      tok=substr(s,RSTART,RLENGTH); print tok"\t"tok > dest
      s=substr(s,1,RSTART-1) substr(s,RSTART+RLENGTH)
    }
  }
  /\| `CXER/ {
    # A sparse row registers ONLY its listed codes: the outer range is a
    # band reservation, not dense coverage — "(sparse: 1100, 1101, …)"
    # replaces the row body (#723: 1113–1116 used to pass as registered
    # while unlisted). The sparse list may live in the owner column, so
    # search the whole row for it before narrowing to the code column.
    if (match($0, /\(sparse:[^)]*\)/)) {
      scan(substr($0,RSTART,RLENGTH), "'"$ranges"'")
      next
    }
    n=split($0,parts,"|"); col=parts[2]
    gsub(/CXER/,"",col)
    # peel excluded/reserved parentheticals off into the exclusion set
    while (match(col, /\([^)]*(excluded|reserved)[^)]*\)/)) {
      par=substr(col,RSTART,RLENGTH)
      col=substr(col,1,RSTART-1) substr(col,RSTART+RLENGTH)
      scan(par, "'"$excluded"'")
    }
    scan(col, "'"$ranges"'")
  }
' "$GOV"
touch "$ranges" "$excluded"
sort -n -u "$ranges" -o "$ranges"; sort -n -u "$excluded" -o "$excluded"

# ── Emitted / asserted codes.
#   *.v under all of vcx/ with //-comments stripped (string literals keep
#   their text; a // inside a string is rare enough to accept),
#   stdlib/*.cx + conformance/**/*.cxd with #-comments stripped.
{
  find "$ROOT/vcx" -name '*.v' -not -path "$ROOT/vcx/target/*" -print0 \
    | xargs -0 sed -E 's|//.*$||' 2>/dev/null
  find "$ROOT/stdlib" -name '*.cx' -print0 2>/dev/null \
    | xargs -0 sed -E 's/(^|[[:space:]])#.*$//' 2>/dev/null
  find "$ROOT/conformance" -name '*.cxd' -print0 2>/dev/null \
    | xargs -0 cat 2>/dev/null
} | grep -ohE "CXER[0-9]{4}" \
  | sed 's/CXER//' | sort -n -u | grep -vE "^(0000|9999)$" > "$emitted" || true

# ── Coverage check: registered AND not excluded.
unregistered=0
: > "$unreg"
while IFS= read -r code; do
  c=$((10#$code)); covered=0
  while IFS=$'\t' read -r lo hi; do
    if [ "$c" -ge "$((10#$lo))" ] && [ "$c" -le "$((10#$hi))" ]; then covered=1; break; fi
  done < "$ranges"
  if [ "$covered" -eq 1 ]; then
    while IFS=$'\t' read -r lo hi; do
      if [ "$c" -ge "$((10#$lo))" ] && [ "$c" -le "$((10#$hi))" ]; then covered=0; break; fi
    done < "$excluded"
  fi
  if [ "$covered" -eq 0 ]; then echo "CXER$code" >> "$unreg"; unregistered=$((unregistered+1)); fi
done < "$emitted"

# ── Spec-side band claims: every CXER range under spec/ with provenance.
# governance.md (the registry itself) is excluded — registry rows are
# SUPPOSED to intersect the bands the specs claim; the C5 class is two
# NON-registry files claiming intersecting space. One claim per
# (range, file): repeat citations within a file are collapsed.
grep -rnoE "CXER[0-9]{4}(–|-)(CXER)?[0-9]{4}" "$ROOT/spec" 2>/dev/null \
  | grep -v "process/governance.md:" \
  | sed -E 's/^([^:]+):[0-9]+:CXER([0-9]{4})(–|-)(CXER)?([0-9]{4})$/\2\t\5\t\1/' \
  | sort -u | sort -n > "$claims" || true

# Intersections between claims from DIFFERENT files (the C5 class), and
# registry-internal row overlaps (an append-only violation). Equal ranges
# cited by several files are cross-references (one grouped informational
# line); PARTIAL intersections between different files are the C5-class
# review items (pairwise, e.g. a working spec landing a new band inside
# another spec's approved allocation).
overlaps="$tmpdir/overlaps.txt"
equal_groups="$tmpdir/equal_groups.txt"
awk -F'\t' -v root="$ROOT/" '
  { f=$3; sub(root,"",f); lo[NR]=$1+0; hi[NR]=$2+0; src[NR]=f; n=NR
    key=sprintf("%04d-%04d",$1+0,$2+0)
    if (key in grp) grp[key]=grp[key] ", " f; else grp[key]=f
    cnt[key]++
  }
  END {
    for (k in grp) if (cnt[k]>1) printf "  %s cited by: %s\n", k, grp[k] | "sort"
    close("sort")
    for (i=1;i<=n;i++) for (j=i+1;j<=n;j++) {
      if (lo[j]<=hi[i] && lo[i]<=hi[j] && !(lo[i]==lo[j] && hi[i]==hi[j]) && src[i]!=src[j])
        printf "  %04d-%04d (%s) ∩ %04d-%04d (%s)\n", lo[i],hi[i],src[i],lo[j],hi[j],src[j] > "'"$overlaps"'"
    }
  }
' "$claims" > "$equal_groups" || true
touch "$overlaps"; sort -u "$overlaps" -o "$overlaps"
reg_overlaps="$tmpdir/reg_overlaps.txt"
awk -F'\t' '
  { lo[NR]=$1+0; hi[NR]=$2+0; n=NR }
  END {
    for (i=1;i<=n;i++) for (j=i+1;j<=n;j++)
      if (lo[j]<=hi[i] && lo[i]<=hi[j] && !(lo[i]==lo[j]&&hi[i]==hi[j]))
        printf "  %04d-%04d ∩ %04d-%04d\n", lo[i],hi[i],lo[j],hi[j]
  }
' "$ranges" > "$reg_overlaps" || true

echo "cxer_registry_report: $(wc -l < "$emitted" | tr -d ' ') distinct codes emitted/asserted (all vcx/*.v, stdlib/*.cx, conformance/**/*.cxd; comments stripped); $(wc -l < "$ranges" | tr -d ' ') registered ranges ($(wc -l < "$excluded" | tr -d ' ') sparse-list exclusions honored)."

strict_fail=0
if [ "$unregistered" -ne 0 ]; then
  # Collapse to consecutive runs for readability (runs, NOT ownership bands).
  echo "UNREGISTERED (emitted/asserted but outside every effective §9.6 range) — $unregistered codes, shown as consecutive runs:"
  awk -F'CXER' '{print $2}' "$unreg" | sort -n | awk '
    { c=$1+0
      if (prev=="" ) {lo=c; hi=c}
      else if (c==hi+1) {hi=c}
      else {printf "  CXER%04d-%04d\n", lo, hi; lo=c; hi=c}
      prev=c }
    END{ if(prev!="") printf "  CXER%04d-%04d\n", lo, hi }'
  echo "  → tracked as #717; registry repair is ruled campaign work (audit C5)."
  strict_fail=1
else
  echo "cxer_registry_report: OK — every emitted/asserted code is registered."
fi

if [ -s "$reg_overlaps" ]; then
  echo "REGISTRY-INTERNAL OVERLAP (§9.6 rows intersect — append-only violation):"
  cat "$reg_overlaps"
  strict_fail=1
fi

if [ -s "$overlaps" ]; then
  echo "SPEC BAND-CLAIM PARTIAL INTERSECTIONS (two files claim intersecting-but-unequal ranges — the C5 two-owners class; review each):"
  cat "$overlaps"
fi
if [ -s "$equal_groups" ]; then
  echo "Equal-range cross-citations (informational — several specs citing one band):"
  cat "$equal_groups"
fi

if [ "$STRICT" = "--strict" ] && [ "$strict_fail" -ne 0 ]; then
  echo "cxer_registry_report: STRICT FAIL"
  exit 1
fi
exit 0
