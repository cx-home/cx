#!/usr/bin/env bash
# consolidate_tests.sh — the #700 test-binary consolidation DRIVER
# (owner ruling 1a, 2026-08-09; generator requirements recorded on #700).
#
# The heavy lifting (parse / merge / dedupe / refusals) lives in CX:
# scripts/consolidate_tests.cx (dog-food). This wrapper owns the
# orchestration and the INDEPENDENT equivalence gate:
#
#   gen <area>     generate the umbrella OUTSIDE the input directory
#                  (scratch), re-verify the test-fn count with grep
#                  (independent of the generator's own claim), and
#                  prove idempotency (second run byte-identical).
#   apply <area>   gen + move the umbrella into the lane directory +
#                  compile-and-run it green + `git rm` the originals.
#                  The caller reviews and commits — ONE COMMIT PER AREA.
#   verify <area>  the gen-time checks only (no move, no git).
#
# Manifests: scripts/consolidation/<area>.files — explicit, committed,
# one input path per line (# comments allowed). Exclusions (serial-retry
# rosters, #737 name-excluded, env-gated files) are simply never listed.
#
# Every check failure is a hard exit; nothing is deleted before the
# umbrella has compiled and run green in place.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CX_BIN="${CX_BIN:-$ROOT/vcx/target/cx}"
V_FLAGS=(-cc cc -gc e -d cx_db_sqlite -d cx_db_redis -usecache)

usage() { echo "usage: $0 {gen|verify|apply} <area>   (manifest: scripts/consolidation/<area>.files)"; exit 2; }

[ $# -eq 2 ] || usage
mode="$1"; area="$2"
manifest="scripts/consolidation/${area}.files"
[ -f "$manifest" ] || { echo "consolidate_tests: no manifest $manifest"; exit 2; }

# input roster (blank + # lines ignored). macOS bash 3.2: no mapfile.
inputs=()
while IFS= read -r line; do
  inputs+=("$line")
done < <(grep -vE '^[[:space:]]*(#|$)' "$manifest")
[ "${#inputs[@]}" -ge 2 ] || { echo "consolidate_tests: area '$area' has <2 inputs — nothing to merge"; exit 2; }
for f in "${inputs[@]}"; do
  [ -f "$f" ] || { echo "consolidate_tests: manifest names missing file: $f"; exit 2; }
done

# every input must share one directory — the umbrella's home
lane_dir="$(dirname "${inputs[0]}")"
for f in "${inputs[@]}"; do
  [ "$(dirname "$f")" = "$lane_dir" ] || { echo "consolidate_tests: inputs span directories ($lane_dir vs $(dirname "$f")) — one area, one lane dir"; exit 2; }
done

umbrella="${lane_dir}/${area}_umbrella_test.v"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/consolidate_${area}.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
out1="$scratch/${area}_umbrella_test.v"
out2="$scratch/${area}_umbrella_2_test.v"

run_gen() { # $1 = out path
  MANIFEST="$manifest" OUT="$1" AREA="$area" \
    "$CX_BIN" scripts/consolidate_tests.cx --allow-read --allow-write --allow-env
}

echo "── consolidate[$area]: generate (${#inputs[@]} inputs → $out1)"
run_gen "$out1"

# ── independent equivalence gate ──────────────────────────────────────
tfns_in=$(cat "${inputs[@]}" | grep -c '^fn test_' || true)
tfns_out=$(grep -c '^fn test_' "$out1" || true)
if [ "$tfns_in" -ne "$tfns_out" ]; then
  echo "consolidate_tests: EQUIVALENCE FAIL — test fns in=$tfns_in out=$tfns_out"
  exit 1
fi
echo "── consolidate[$area]: test-fn equivalence OK ($tfns_in == $tfns_out; grep, independent of the generator)"

run_gen "$out2" >/dev/null
cmp -s "$out1" "$out2" || { echo "consolidate_tests: IDEMPOTENCY FAIL — two runs differ"; exit 1; }
echo "── consolidate[$area]: idempotent (second run byte-identical)"

case "$mode" in
  gen|verify)
    echo "── consolidate[$area]: $mode complete (no move; umbrella at $out1)"
    exit 0 ;;
  apply) : ;;
  *) usage ;;
esac

# ── apply: move in, prove green, then remove the originals ────────────
[ -e "$umbrella" ] && { echo "consolidate_tests: $umbrella already exists — regenerating over a live umbrella needs its originals; refuse"; exit 2; }
cp "$out1" "$umbrella"
echo "── consolidate[$area]: umbrella in place ($umbrella); compile+run"
log="vcx/target/consolidate_${area}.log"
if ! v "${V_FLAGS[@]}" test "$umbrella" >"$log" 2>&1; then
  # #572 classified retry: a stale -usecache layer can inject a duplicate
  # or missing C symbol; a C compile/link failure gets ONE cache-free
  # retry (cache-free green proves the artifact). Anything else is real.
  if grep -aqE 'C compilation error|linker command failed|symbol\(s\) not found|duplicate symbol' "$log"; then
    echo "── consolidate[$area]: C compile/link failure — cache-free retry (#572 class)"
    nocache_flags=()
    for fl in "${V_FLAGS[@]}"; do [ "$fl" = "-usecache" ] || nocache_flags+=("$fl"); done
    if ! v "${nocache_flags[@]}" test "$umbrella" >"$log" 2>&1; then
      echo "consolidate_tests: umbrella RED (also cache-free) — originals untouched; log: $log"
      tail -20 "$log"
      rm "$umbrella"
      exit 1
    fi
  else
    echo "consolidate_tests: umbrella RED — originals untouched; log: $log"
    tail -20 "$log"
    rm "$umbrella"
    exit 1
  fi
fi
echo "── consolidate[$area]: umbrella GREEN ($(grep -c '^fn test_' "$umbrella") test fns); removing ${#inputs[@]} originals"
git rm -q -- "${inputs[@]}"
echo "── consolidate[$area]: done — review + commit (one commit per area). Log: $log"
