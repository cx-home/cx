#!/usr/bin/env bash
# tools/smoke-eval.sh — runs the experience-gate hard-fail checks
# from the evaluation-experience checklist.
#
# Most checks run on the local host. Cross-platform install-time
# tests (F1, F2, F5) are best run in CI containers via the matrix
# in .github/workflows/ci.yml — this script asserts the local
# build's `cx demo` works in the time budget.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CX="$ROOT/vcx/target/cx"

PASS=0
FAIL=0
FAIL_DETAILS=()

run() {
 local label="$1" cmd="$2"
 printf " %-50s " "$label"
 if eval "$cmd" > /tmp/smoke-eval.log 2>&1; then
 echo "OK"
 PASS=$((PASS + 1))
 else
 echo "FAIL"
 FAIL=$((FAIL + 1))
 FAIL_DETAILS+=("$label")
 sed 's/^/ /' /tmp/smoke-eval.log | head -3
 fi
}

if [ ! -x "$CX" ]; then
 (cd "$ROOT" && make -s build-vcx) || { echo "FAIL: cx build failed"; exit 1; }
fi

echo "── F1/F9: cx demo within 60s and deterministic ────────────"
# Portable timer: macOS lacks GNU `timeout`. Measure wall-clock.
run "T-60-1: cx demo completes in < 60s" \
 "start=\$(date +%s); $CX demo > /tmp/cx-demo-out.txt; end=\$(date +%s); test \$((end - start)) -lt 60"
run "T-60-3: cx demo output deterministic" \
 "diff /tmp/cx-demo-out.txt $ROOT/fixtures/expected_demo_output.txt"

echo ""
echo "── F4: documented examples run ───────────────────────────"
run "verify-examples" \
 "$ROOT/tools/verify-examples.sh"

echo ""
echo "── F6: README runnable blocks parse ──────────────────────"
run "verify-readme-blocks" \
 "$ROOT/tools/verify-readme-blocks.sh"

echo ""
echo "── F7: per-binding quickstart blocks present ─────────────"
run "verify-binding-quickstarts" \
 "$ROOT/tools/verify-binding-quickstarts.sh"

echo ""
echo "── Documentation hygiene ─────────────────────────────────"
run "verify-doc-blocks docs/" \
 "$ROOT/tools/verify-doc-blocks.sh $ROOT/docs/"
run "verify-doc-links docs/" \
 "$ROOT/tools/verify-doc-links.sh $ROOT/docs/"
run "verify-doc-links README.md" \
 "$ROOT/tools/verify-doc-links.sh $ROOT/README.md"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " smoke-eval: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════════════════════════"
if [ $FAIL -ne 0 ]; then
 echo ""
 echo "Hard-fail conditions tripped — release blocked."
 echo "Details above. See the evaluation-experience checklist for recovery."
 exit 1
fi
echo ""
echo "All experience-gate checks passed."
exit 0
