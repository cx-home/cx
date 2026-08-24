#!/usr/bin/env bash
# gates_manifest_gate.sh — validate conformance/gates.cxd (corpus audit G17).
#
# gates.cxd is unvalidated policy that governs whether EVERY other fixture
# blocks its gate; a stale/typo'd row silently downgrades a lane. This gate
# checks, suite-aware:
#   1. it parses (well-formed CX);
#   2. every gate= AND default= value — bare, single- or double-quoted —
#      is in the enum {enforced, advisory, pending, skip};
#   3. every [suite name=S] names a KNOWN suite (code, stdlib, packages);
#      an unknown/typo'd suite name used to skip all module-row validation
#      under it silently (#721, M36);
#   4. every [module name=X] row resolves to a real fixture, per its
#      enclosing [suite name=S] block:
#        S=stdlib   -> conformance/stdlib/X.cxd
#        S=packages -> packages/X/X.test.cxd
#        S=code     -> (no module rows; the suite default governs code.cxd)
#
# The runtime consumer (vcx/tests/code_eval_fixtures_test.v) is
# deny-by-default, so a typo'd VALUE fails closed there — but a typo'd
# SUITE or MODULE name silently drops policy rows, which only this gate
# can catch.
#
# Exit: 0 = valid; 1 = any violation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATES="$ROOT/conformance/gates.cxd"
CXBIN="${CX_BIN:-$ROOT/vcx/target/cx}"

KNOWN_SUITES="code stdlib packages"

fail=0

# (1) parses — an absent cx binary FAILS LOUD (#721 item 2: a silently
# skipped parse check reads as green; the gate's verdict must never depend
# invisibly on build state).
if [ -x "$CXBIN" ]; then
  "$CXBIN" "$GATES" --to=cx >/dev/null 2>&1 || { echo "gates_manifest_gate: gates.cxd does not parse"; exit 1; }
else
  echo "gates_manifest_gate: FAILED — cx binary absent at $CXBIN (set CX_BIN or build vcx); the parse check cannot run and MUST not be skipped silently"
  exit 1
fi

# policy_rows — just the [gate-policy]/[suite]/[module] row lines, with any
# reason='…' prose attr stripped, so doc-comment prose and free-text reasons
# can neither hide a value nor false-positive the enum check.
policy_rows() {
  grep -E '^[[:space:]]*\[(gate-policy|suite|module)[[:space:]]' "$GATES" \
    | sed -E "s/reason='[^']*'//g; s/reason=\"[^\"]*\"//g"
}

# extract_attr_values ATTR — every value of ATTR= on a policy row, quotes
# stripped. Matches bare tokens, 'single-quoted', and "double-quoted"
# values, so a quoted or capitalized value can no longer hide from the
# enum check (M36: the old grep saw only bare lowercase).
extract_attr_values() {
  policy_rows \
    | grep -oE "$1=('[^']*'|\"[^\"]*\"|[^][:space:]\"']+)" \
    | sed -E "s/^$1=//; s/^'(.*)'$/\1/; s/^\"(.*)\"$/\1/" || true
}

# (2) enum check — gate= and default= share the enum; the value must be the
# exact lowercase token (the runtime consumer is case-sensitive).
for attr in gate default; do
  while IFS= read -r val; do
    case "$val" in
      enforced|advisory|pending|skip) ;;
      *) echo "GATE-BADVALUE: $attr=$val is not in {enforced,advisory,pending,skip}"; fail=1 ;;
    esac
  done < <(extract_attr_values "$attr")
done

# (3)+(4) suite-aware walk: validate every [suite name=S] against the known
# set the moment it appears (unknown suite = hard failure, even with zero
# module rows), then resolve each [module name=X] under it.
cur_suite=""
while IFS= read -r line; do
  if printf '%s\n' "$line" | grep -qE '\[suite name='; then
    cur_suite="$(printf '%s\n' "$line" | sed -E "s/.*\[suite name=('[^']*'|\"[^\"]*\"|[A-Za-z0-9_-]+).*/\1/; s/^'(.*)'$/\1/; s/^\"(.*)\"$/\1/")"
    known=0
    for s in $KNOWN_SUITES; do
      [ "$cur_suite" = "$s" ] && known=1
    done
    if [ "$known" -eq 0 ]; then
      echo "GATE-UNKNOWN-SUITE: [suite name=$cur_suite] is not a known suite {${KNOWN_SUITES// /, }} — every module row under it would be silently unvalidated AND silently unconsumed by the runner"
      fail=1
    fi
  fi
  if printf '%s\n' "$line" | grep -qE '\[module name='; then
    mod="$(printf '%s\n' "$line" | sed -E "s/.*\[module name=('[^']*'|\"[^\"]*\"|[A-Za-z0-9_-]+).*/\1/; s/^'(.*)'$/\1/; s/^\"(.*)\"$/\1/")"
    case "$cur_suite" in
      stdlib)   [ -f "$ROOT/conformance/stdlib/$mod.cxd" ] || { echo "GATE-DANGLING: stdlib module '$mod' has no conformance/stdlib/$mod.cxd"; fail=1; } ;;
      packages) [ -f "$ROOT/packages/$mod/$mod.test.cxd" ] || { echo "GATE-DANGLING: packages module '$mod' has no packages/$mod/$mod.test.cxd"; fail=1; } ;;
      code)     echo "GATE-UNEXPECTED: module row '$mod' under suite 'code' (code.cxd uses the suite default, no module rows)"; fail=1 ;;
      "")       echo "GATE-ORPHAN: module row '$mod' with no enclosing [suite]"; fail=1 ;;
      *)        echo "GATE-ORPHAN: module row '$mod' under unknown suite '$cur_suite'"; fail=1 ;;
    esac
  fi
done < "$GATES"

if [ "$fail" -ne 0 ]; then
  echo "gates_manifest_gate: FAILED"
  exit 1
fi
echo "gates_manifest_gate: OK — gates.cxd parses, every gate=/default= is in-enum, every suite is known, every module row resolves to a real fixture."
exit 0
