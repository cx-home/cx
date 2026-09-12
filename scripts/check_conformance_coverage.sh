#!/usr/bin/env bash
# check-conformance-coverage (#1212) — every conformance suite is CLAIMED by a
# named `make test` step, or the gate is red.
#
# The document runner (tests/runners/conformance/conformance_run.v) lists the
# suites it drives; it is the DOCUMENT step and refuses [in-code …] fixtures by
# design (#1134), so `test-vcx-conform` never covered conformance/code.cxd —
# the largest corpus — while its name said "conformance". That corpus is graded
# by the EVAL step (test-vcx-suite's code_eval_fixtures_test.v, plus the profile
# gate), and other suites by their own runners. Nothing was uncovered — but the
# map lived in nobody's head, and a NEW .cxd dropped into conformance/ would be
# graded by nothing while every step stayed green (the vacuous-gate class this
# repo keeps paying for: #1127, #1134, #1180, #1209). This guard is that map,
# in the tree, asserted on every gate: a suite with no claim is a red that
#
# THE CLAIM MUST NAME A STEP THAT ACTUALLY RUNS THE FILE. Until 2026-09-08 the
# code.cxd and stdlib/*.cxd rows claimed `test-vcx-code`, which runs
# `v test vcx/code/ vcx/platform/` (Makefile:2088) -- two directories that do
# NOT contain vcx/tests/code_eval_fixtures_test.v. `test-vcx-suite` runs
# `v test vcx/tests/` (Makefile:2024), which does. The rows also named
# test-profile-gate, which runs tests/runners/profile_gate/ against the
# cli/embed profile binaries (vcx/Makefile:950-952) -- a different corpus.
# Nothing was ungraded (test-vcx-suite is in TEST_TARGETS), but a worker who
# trusted this map to pick a verification step ran test-vcx-code, got
# `31 passed, 31 total` with the fixture runner absent from those 31, and
# reported a green that had graded none of the new fixtures. A map that names
# the wrong step is worse than no map, because it is believed.
# names it and says where a claim is written. (macOS bash 3.2: no assoc arrays —
# the claims are a two-column file.)
set -euo pipefail
cd "$(dirname "$0")/.."
runner=vcx/tests/runners/conformance/conformance_run.v
claims="$(mktemp "${TMPDIR:-/tmp}/cx-conf-claims.XXXXXX")"
trap 'rm -f "$claims"' EXIT
# 1. the document step: the runner's own suite list
grep -oE "'\.\./conformance/[A-Za-z0-9_./-]+\.cxd'" "$runner" | sed -E "s#'\.\./##; s#'##" | while IFS= read -r s; do
  printf '%s\t%s\n' "$s" "test-vcx-conform (conform-all: $runner)"
done >> "$claims"
# 2. the eval step (in-code fixtures): code.cxd + every conformance/stdlib/*.cxd
printf '%s\t%s\n' "conformance/code.cxd" "test-vcx-suite (v test vcx/tests/ -> code_eval_fixtures_test.v: parse_all_fixtures); also test-vcx-resilience-matrix, which runs that file by name -- but it reds 14 db.cxd fixtures by construction (no -d cx_db_sqlite/-d cx_db_redis in VFLAGS_VCX), so read its failure LIST, not its exit code" >> "$claims"
for f in conformance/stdlib/*.cxd; do printf '%s\t%s\n' "$f" "test-vcx-suite (v test vcx/tests/ -> code_eval_fixtures_test.v: test_stdlib_module_fixtures); also test-vcx-resilience-matrix, which runs that file by name -- but it reds 14 db.cxd fixtures by construction (no -d cx_db_sqlite/-d cx_db_redis in VFLAGS_VCX), so read its failure LIST, not its exit code"; done >> "$claims"
# 3. dedicated runners / steps
{
  printf '%s\t%s\n' "conformance/diff.cxd" "test-vcx-conform (conform-diff: tests/runners/diff_lint/diff_lint_conform.v)"
  printf '%s\t%s\n' "conformance/lint.cxd" "test-vcx-conform (conform-lint: tests/runners/diff_lint/diff_lint_conform.v)"
  printf '%s\t%s\n' "conformance/fmt.cxd" "test-vcx-conform (conform-fmt)"
  printf '%s\t%s\n' "conformance/data_bin_arrow.cxd" "test-vcx-conform (conform-data-bin-arrow)"
  printf '%s\t%s\n' "conformance/code_diagram.cxd" "test-code-diagram (scripts/check_code_diagram_fixtures.cx)"
  printf '%s\t%s\n' "conformance/xpath_31_parity.cxd" "test-xpath-parity-cx (scripts/check_xpath_parity_fixtures.cx)"
  printf '%s\t%s\n' "conformance/binding_api.cxd" "test-binding-api-parity (scripts/test_binding_api_parity.sh)"
  printf '%s\t%s\n' "conformance/gates.cxd" "POLICY — the enforced/advisory register every runner reads (not a fixture suite)"
} >> "$claims"
for f in conformance/llm/*.cxd; do [ -e "$f" ] && printf '%s\t%s\n' "$f" "docs-check (scripts/gen_docs/primer_build.cx — the LLM primer drift gate re-records every wrong/right pair, #938)"; done >> "$claims" || true
for f in conformance/tools-export/*.cxd; do [ -e "$f" ] && printf '%s\t%s\n' "$f" "tools-export-gate"; done >> "$claims" || true
# 4. sweep every suite file
unclaimed=""
n=0
while IFS= read -r f; do
  n=$((n+1))
  if ! grep -qF "$f	" "$claims"; then unclaimed="$unclaimed $f"; fi
done < <(find conformance -name '*.cxd' | sort)
if [ -n "$unclaimed" ]; then
  echo "check-conformance-coverage: conformance suite(s) that NO step claims —"
  for f in $unclaimed; do echo "    $f"; done
  echo "  A .cxd graded by nothing is a green that guards nothing. Either add the"
  echo "  suite to the document runner's list ($runner), or record which step"
  echo "  grades it in scripts/check_conformance_coverage.sh (#1212)."
  exit 1
fi
echo "check-conformance-coverage OK — $n conformance suites, every one claimed by a named step"
