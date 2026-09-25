#!/usr/bin/env bash
# gates_manifest_gate.sh — validate conformance/gates.cxd (corpus audit G17).
#
# gates.cxd is unvalidated policy that governs whether EVERY other fixture
# blocks its gate; a stale/typo'd row silently downgrades a lane. This gate
# checks, suite-aware:
#   1. it parses (well-formed CX);
#   2. every gate= AND default= value — bare, single- or double-quoted —
#      is in the enum {enforced, advisory, pending, skip};
#   3. every [suite name=S] names a KNOWN suite (code, stdlib, packages,
#      xpath-31-parity); an unknown/typo'd suite name used to skip all
#      module-row validation under it silently (#721, M36);
#   4. every [module name=X] row resolves to a real fixture, per its
#      enclosing [suite name=S] block:
#        S=stdlib          -> conformance/{stdlib,platform,x,xap}/X.cxd — one
#                              gate-policy suite, four directories since
#                              #1427-c put a module's corpus in its ring's
#        S=packages        -> packages/X/X.test.cxd
#        S=code            -> (no module rows; the suite default governs code.cxd)
#        S=xpath-31-parity -> (no module rows; the suite default governs
#                              conformance/xpath_31_parity.cxd — RULED: VC-7, #945)
#   5. the register is DERIVED (D49a, #1633; RULED: RS-27): a suite's gate
#      status lives on its own [test-suite] element, where the grading core
#      reads it, and every [module] row must agree with the element of the
#      suite it names — scripts/gates_register_check.cx refuses a row that
#      disagrees (naming the row and the file), an advisory element with no
#      row, and an element gate= the grader refuses; its corpus,
#      conformance/gates_register.cxd, is graded first with `cx corpus`.
#
# The runtime consumers (vcx/tests/code_eval_fixtures_test.v for code/stdlib/
# packages; scripts/check_xpath_parity_fixtures.cx for xpath-31-parity) are
# deny-by-default, so a typo'd VALUE fails closed there — but a typo'd
# SUITE or MODULE name silently drops policy rows, which only this gate
# can catch.
#
# Exit: 0 = valid; 1 = any violation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATES="$ROOT/conformance/gates.cxd"
CXBIN="${CX_BIN:-$ROOT/deps/cx-core-code/vcx/target/cx}"

KNOWN_SUITES="code stdlib packages xpath-31-parity"

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

# policy_rows — just the [gate-policy]/[suite]/[module] row lines, TRUNCATED at
# `reason=`, so free-text prose can neither hide a value nor false-positive the
# enum check below.
#
# Truncation, not a quoted-string strip, and that is the fix for a measured
# false red (2026-09-08). The strip was `s/reason='[^']*'//g`, whose `[^']*`
# stops at the first `\'` — a CX single-quoted string's OWN escape, and this
# file carries several ("time\'s CXER33xx") — which left the entire rest of
# that reason exposed. A sched-row rewrite then put the phrase
# `(gate=pending).` in the exposed tail and the gate refused the value
# `pending).`: a red about prose, not about policy. Handling the escapes
# correctly needs `(\\.)`-style alternation inside a sed program that already
# has to quote both kinds of quote, which is exactly the fragility that
# produced the bug. Truncating is escape-proof by construction and loses
# nothing: EVERY value this gate reads — `name=`, `gate=`, `default=`,
# `suite=` — is written before `reason=` on all 60 rows (verified by
# extracting them from the truncated rows: 60 name=, 56 gate=, 5 default=,
# the same counts as the full rows). A row that ever puts one after `reason=`
# is a row this gate would not see, so keep writing the prose last.
policy_rows() {
  grep -E '^[[:space:]]*\[(gate-policy|suite|module)[[:space:]]' "$GATES" \
    | sed -E 's/reason=.*$//'
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
    # (4b) A single-file suite (no module rows) governs ONE fixture; that
    # fixture must exist. #945's whole class was a policy/runner reference
    # to a file the tree no longer had under that name.
    case "$cur_suite" in
      code)            sf="deps/cx-core-code/conformance/code.cxd" ;;
      xpath-31-parity) sf="deps/cx-core-code/conformance/xpath_31_parity.cxd" ;;
      *)               sf="" ;;
    esac
    if [ -n "$sf" ] && [ ! -f "$ROOT/$sf" ]; then
      echo "GATE-DANGLING: suite '$cur_suite' governs $sf, which does not exist"
      fail=1
    fi
  fi
  if printf '%s\n' "$line" | grep -qE '\[module name='; then
    mod="$(printf '%s\n' "$line" | sed -E "s/.*\[module name=('[^']*'|\"[^\"]*\"|[A-Za-z0-9_-]+).*/\1/; s/^'(.*)'$/\1/; s/^\"(.*)\"$/\1/")"
    case "$cur_suite" in
      stdlib)   [ -f "$ROOT/deps/cx-core-code/conformance/stdlib/$mod.cxd" ] || [ -f "$ROOT/conformance/stdlib/$mod.cxd" ] || [ -f "$ROOT/conformance/platform/$mod.cxd" ] || [ -f "$ROOT/conformance/x/$mod.cxd" ] || [ -f "$ROOT/conformance/xap/$mod.cxd" ] || { echo "GATE-DANGLING: stdlib module '$mod' has no corpus under deps/cx-core-code/conformance/stdlib/$mod.cxd or conformance/{stdlib,platform,x,xap}/$mod.cxd (RULED: 1427-c, K7a — Ring 1's stdlib corpus now lives in the pinned cx-core-code checkout)"; fail=1; } ;;
      packages) [ -f "$ROOT/packages/$mod/$mod.test.cxd" ] || { echo "GATE-DANGLING: packages module '$mod' has no packages/$mod/$mod.test.cxd"; fail=1; } ;;
      code)     echo "GATE-UNEXPECTED: module row '$mod' under suite 'code' (code.cxd uses the suite default, no module rows)"; fail=1 ;;
      xpath-31-parity) echo "GATE-UNEXPECTED: module row '$mod' under suite 'xpath-31-parity' (xpath_31_parity.cxd uses the suite default, no module rows)"; fail=1 ;;
      "")       echo "GATE-ORPHAN: module row '$mod' with no enclosing [suite]"; fail=1 ;;
      *)        echo "GATE-ORPHAN: module row '$mod' under unknown suite '$cur_suite'"; fail=1 ;;
    esac
  fi
done < "$GATES"

# (5) the derived register: the check's own corpus first (a check whose pinned
# verdicts do not hold proves nothing about the tree), then the tree. Both run
# from the checkout root — the corpus and the check import
# ./scripts/gates_register.cx, which resolves against the working directory
# (#1604).
if ! ( cd "$ROOT" && "$CXBIN" corpus --quiet conformance/gates_register.cxd ); then
  echo "GATE-REGISTER-CORPUS: conformance/gates_register.cxd does not pass — the drift check's pinned verdicts do not hold"
  fail=1
fi
if ! ( cd "$ROOT" && "$CXBIN" --allow-read --allow-write scripts/gates_register_check.cx ); then
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "gates_manifest_gate: FAILED"
  exit 1
fi
echo "gates_manifest_gate: OK — gates.cxd parses, every gate=/default= is in-enum, every suite is known, every single-file suite's fixture exists, every module row resolves to a real fixture, and every row agrees with its suite's [test-suite] element (the register is derived, D49a)."
exit 0
