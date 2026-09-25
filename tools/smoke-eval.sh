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
CX="$ROOT/deps/cx-core-code/vcx/target/cx"

PASS=0
FAIL=0
FAIL_DETAILS=()

# Per-run scratch dir, never fixed /tmp names (#948). Parallel sessions share
# this checkout, so two concurrent runs raced on /tmp/smoke-eval.log and — far
# worse — on /tmp/cx-demo-out.txt, which the T-60-3 row diffs against the
# expected fixture: a colliding write turned a real pass into a spurious fail
# or a real fail into a pass. Same conversion release-verify.sh already made
# for its per-row logs (e47fe55ee); this is the half that was left behind.
SEDIR="$(mktemp -d "${TMPDIR:-/tmp}/smoke-eval.XXXXXX")"
trap 'rm -rf "$SEDIR"' EXIT
ROWLOG="$SEDIR/row.log"
DEMO_OUT="$SEDIR/cx-demo-out.txt"
echo "smoke-eval: scratch dir $SEDIR"

run() {
 local label="$1" cmd="$2"
 printf " %-50s " "$label"
 if eval "$cmd" > "$ROWLOG" 2>&1; then
 echo "OK"
 PASS=$((PASS + 1))
 else
 echo "FAIL"
 FAIL=$((FAIL + 1))
 FAIL_DETAILS+=("$label")
 sed 's/^/ /' "$ROWLOG" | head -3
 fi
}

if [ ! -x "$CX" ]; then
 (cd "$ROOT" && make -s build-vcx) || { echo "FAIL: cx build failed"; exit 1; }
fi

echo "── F1/F9: cx demo within 60s and deterministic ────────────"
# The 60s budget is ENFORCED, not measured (#947). The old row was
#   start=$(date +%s); cx demo > out; end=$(date +%s); test $((end-start)) -lt 60
# which only evaluates once `cx demo` RETURNS: it could fail a slow demo but
# never a hung one, so a hang blocked this gate indefinitely instead of failing
# it — while the row read "completes in < 60s", a bound it never held. Its old
# comment blamed macOS for lacking GNU `timeout`, but the bound was always
# available in the runtime: tools/bounded_run.cx drives the child through
# [$process:run timeout-ms=...], which escalates SIGTERM -> SIGKILL at expiry
# and reports timed-out (process.md §4.5), exiting 124. Same contract as the
# profile-gate hang watchdog (37a160806).
#
# The bound also fixes a second flaw in the old row: its last command was
# `test`, so a FAILED redirect of the demo output was masked and the row
# reported OK. bounded_run.cx writes the capture itself and exits non-zero if
# it cannot.
run "T-60-1: cx demo completes in < 60s (enforced bound)" \
 "BOUNDED_RUN_MS=60000 BOUNDED_RUN_STDOUT=$DEMO_OUT $CX --allow-subprocess --allow-write --allow-env $ROOT/tools/bounded_run.cx $CX demo"
run "T-60-3: cx demo output deterministic" \
 "diff $DEMO_OUT $ROOT/fixtures/expected_demo_output.txt"

echo ""
echo "── F4: documented examples run ───────────────────────────"
run "verify-examples" \
 "$ROOT/tools/verify-examples.sh"

echo ""
echo "── F6: README runnable blocks parse ──────────────────────"
run "verify-readme-blocks" \
 "$ROOT/tools/verify-readme-blocks.sh"

echo ""
echo "── F7: per-binding quickstart blocks — RETIRED (RULED: RS-12, RS-8;"
echo "   #1591 item K3): the four active bindings left whole; see Makefile"

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
