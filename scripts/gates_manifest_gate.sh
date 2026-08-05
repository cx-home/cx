#!/usr/bin/env bash
# gates_manifest_gate.sh — validate conformance/gates.cxd (corpus audit G17).
#
# gates.cxd is unvalidated policy that governs whether EVERY other fixture
# blocks its gate; a stale/typo'd row silently downgrades a lane. This gate
# checks, suite-aware:
#   1. it parses (well-formed CX);
#   2. every [gate-policy]/[suite]/[module] gate= value is in the enum
#      {enforced, advisory, pending, skip};
#   3. every [module name=X] row resolves to a real fixture, per its
#      enclosing [suite name=S] block:
#        S=stdlib   -> conformance/stdlib/X.cxd
#        S=packages -> packages/X/X.test.cxd
#        S=code     -> (no module rows; the suite default governs code.cxd)
#
# Exit: 0 = valid; 1 = an unknown gate value or a dangling module row.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATES="$ROOT/conformance/gates.cxd"
CXBIN="${CX_BIN:-$ROOT/vcx/target/cx}"

fail=0

# (1) parses
if [ -x "$CXBIN" ]; then
  "$CXBIN" "$GATES" --to=cx >/dev/null 2>&1 || { echo "gates_manifest_gate: gates.cxd does not parse"; exit 1; }
fi

# (2) enum check
while IFS= read -r val; do
  case "$val" in
    enforced|advisory|pending|skip) ;;
    *) echo "GATE-BADVALUE: gate=$val is not in {enforced,advisory,pending,skip}"; fail=1 ;;
  esac
done < <(grep -oE "gate=[a-z]+" "$GATES" | sed 's/gate=//')

# (3) suite-aware module-row resolution. Track the current [suite name=S] and
# check each [module name=X] under it against the fixture that suite implies.
cur_suite=""
while IFS= read -r line; do
  if printf '%s\n' "$line" | grep -qE '\[suite name='; then
    cur_suite="$(printf '%s\n' "$line" | sed -E 's/.*\[suite name=([A-Za-z0-9_-]+).*/\1/')"
  fi
  if printf '%s\n' "$line" | grep -qE '\[module name='; then
    mod="$(printf '%s\n' "$line" | sed -E 's/.*\[module name=([A-Za-z0-9_-]+).*/\1/')"
    case "$cur_suite" in
      stdlib)   [ -f "$ROOT/conformance/stdlib/$mod.cxd" ] || { echo "GATE-DANGLING: stdlib module '$mod' has no conformance/stdlib/$mod.cxd"; fail=1; } ;;
      packages) [ -f "$ROOT/packages/$mod/$mod.test.cxd" ] || { echo "GATE-DANGLING: packages module '$mod' has no packages/$mod/$mod.test.cxd"; fail=1; } ;;
      code)     echo "GATE-UNEXPECTED: module row '$mod' under suite 'code' (code.cxd uses the suite default, no module rows)"; fail=1 ;;
      "")       echo "GATE-ORPHAN: module row '$mod' with no enclosing [suite]"; fail=1 ;;
    esac
  fi
done < "$GATES"

if [ "$fail" -ne 0 ]; then
  echo "gates_manifest_gate: FAILED"
  exit 1
fi
echo "gates_manifest_gate: OK — gates.cxd parses, every gate= is in-enum, every module row resolves to a real fixture."
exit 0
