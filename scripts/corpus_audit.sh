#!/usr/bin/env bash
# Rosetta corpus cadence audit.
# Iterates corpus/rosetta/NN-*.cx, runs each via `vcx/target/cx <file>` (the
# standing run surface — the legacy `cx eval` alias is never used, AGENTS.md
# rule 4),
# computes a live status, and compares against corpus/rosetta/AUDIT.md.
# Exits 0 if every live status matches recorded; exits 1 on drift.
set -u
CX_BIN=${CX_BIN:-vcx/target/cx}
CORPUS_DIR=${CORPUS_DIR:-corpus/rosetta}
AUDIT_FILE="${CORPUS_DIR}/AUDIT.md"
[ -x "$CX_BIN" ] || { echo "corpus-audit: missing $CX_BIN — run 'make build-vcx' first" >&2; exit 2; }
[ -f "$AUDIT_FILE" ] || { echo "corpus-audit: missing $AUDIT_FILE" >&2; exit 2; }

# Parse AUDIT.md "| slug | hash | status | ..." rows into newline-delimited
# "slug status" pairs (bash 3.2 compatible — no associative arrays).
recorded_pairs=$(awk -F'|' '
  /^\| Program / || /^\|---/ { next }
  /^\|[[:space:]]*[0-9]+-/ {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4)
    if ($2 != "" && $4 != "") print $2, $4
  }
' "$AUDIT_FILE")

lookup_recorded() {
  printf '%s\n' "$recorded_pairs" | awk -v s="$1" '$1==s {for(i=2;i<=NF;i++) printf "%s%s", $i, (i<NF?" ":""); exit}'
}

drift=0
seen=""
printf '%-22s %-18s %-12s %s\n' "PROGRAM-SLUG" "LIVE-STATUS" "RECORDED" "NOTES"
printf '%-22s %-18s %-12s %s\n' "------------" "-----------" "--------" "-----"
for cx in "$CORPUS_DIR"/[0-9]*-*.cx; do
  [ -e "$cx" ] || continue
  base=$(basename "$cx" .cx)
  md="${CORPUS_DIR}/${base}.md"
  seen="$seen $base"
  notes=""
  if [ ! -f "$md" ]; then
    live="missing"; notes="no sibling .md"
  else
    out=$("$CX_BIN" "$cx" 2>&1); rc=$?
    md_status=$(grep -oE '^\*\*Status:\*\* [A-Z]+' "$md" | head -1 | awk '{print tolower($2)}')
    if [ "$rc" -ne 0 ]; then
      live="blocked"; notes="exit=$rc"
    elif printf '%s' "$out" | grep -q '\[err code='; then
      live="workaround"; notes="err-value in stdout"
    elif [ "$md_status" = "workaround" ]; then
      live="workaround"; notes="md records workaround"
    elif [ "$md_status" = "blocked" ]; then
      live="blocked"; notes="md records blocked (ran but wrong output)"
    else
      live="green"; notes="exit=0 + md=green"
    fi
  fi
  rec=$(lookup_recorded "$base")
  if [ -z "$rec" ]; then
    live="missing-from-audit"; drift=1; rec="<absent>"
  elif [ "$rec" != "$live" ]; then
    drift=1
  fi
  printf '%-22s %-18s %-12s %s\n' "$base" "$live" "$rec" "$notes"
done

# Detect AUDIT.md rows with no corresponding .cx file.
printf '%s\n' "$recorded_pairs" | awk '{print $1}' | while IFS= read -r slug; do
  [ -z "$slug" ] && continue
  case " $seen " in
    *" $slug "*) ;;
    *) printf '%-22s %-18s %-12s %s\n' "$slug" "missing-program" "$(lookup_recorded "$slug")" "row has no .cx"
       echo "DRIFT_MARK" >&2 ;;
  esac
done 2> /tmp/.corpus_audit_drift.$$
if [ -s /tmp/.corpus_audit_drift.$$ ]; then drift=1; fi
rm -f /tmp/.corpus_audit_drift.$$

count=$(echo $seen | wc -w | tr -d ' ')
echo
if [ "$drift" -eq 0 ]; then
  echo "AUDIT: ALL ${count} programs match recorded status"
  exit 0
else
  echo "STATUS DRIFT — live status differs from recorded in $AUDIT_FILE"
  echo "Resolution: either fix the program / status detector, or update $AUDIT_FILE."
  exit 1
fi
