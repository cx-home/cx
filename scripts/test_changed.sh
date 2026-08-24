#!/usr/bin/env bash
# test_changed — the lane-input skip manifest (#700, owner ruling 1a
# 2026-08-09): run only the TEST_TARGETS lanes whose declared INPUT GLOBS
# intersect the change set BASE..HEAD. Conservative by construction:
#   - a lane with no manifest row ALWAYS runs (deny-by-default);
#   - globs OVER-include on doubt (a false "run" costs minutes; a false
#     "skip" costs correctness);
#   - the full `make test` union stays MANDATORY at wave/phase exits —
#     this target NEVER substitutes for an exit gate (ledger discipline).
#
# Usage:  scripts/test_changed.sh <base-ref>          (typically origin/<branch> or HEAD~N)
#         make test-changed BASE=<base-ref>
#
# Output: the skip/run decision per lane (loud), then runs the selected
# lanes via make, propagating the first failure.
set -euo pipefail

BASE="${1:?usage: test_changed.sh <base-ref> [--dry-run]}"
DRY=0
[ "${2:-}" = "--dry-run" ] && DRY=1
cd "$(dirname "$0")/.."

CHANGED=$(git diff --name-only "$BASE"...HEAD; git diff --name-only HEAD; git diff --name-only --cached)
CHANGED=$(printf '%s\n' "$CHANGED" | sort -u | grep -v '^$' || true)
if [ -z "$CHANGED" ]; then
  echo "test-changed: no changes vs $BASE — nothing to run (the full gate still applies at wave exits)"
  exit 0
fi
echo "test-changed: ${BASE}..HEAD(+worktree) changes:"
printf '%s\n' "$CHANGED" | sed 's/^/  /'

# Lane → input globs (space-separated, bash extended globs via case).
# A CHANGE anywhere else (unlisted paths) matches the special glob '*'
# rows only. Rows deliberately over-include:
#   - vcx/** counts as input to EVERY compiled lane;
#   - conformance/** feeds every corpus-consuming lane;
#   - spec/** feeds the doc/consistency gates.
# ── The ring DAG, once (RULED: VC-22) ────────────────────────────────────
# Authority: scripts/ring_import_gate.sh, which enforces these edges
# grep-level with zero tolerance. Stated here so a lane's input set is
# derived from the import contract rather than re-guessed per row.
#
#   vcx/cx        Ring-0, strict sink (imports nothing above it)
#   vcx/cxstore   <- cx
#   vcx/code      Ring-1 <- cx
#   vcx/arrow     <- cx        vcx/transport <- cx
#   vcx/platform  Ring-2 <- cx code cxstore arrow transport
#   vcx/cli, vcx/cmd_data      platform-free <- cx code cli cmd_data
#   vcx/cmd       <- cli code cx platform
#
# Every vcx/ subdir must be named by at least one row below. Narrowing the
# old blanket `vcx/*` rows means a path named by NO row would skip every
# lane, so the support/rare dirs (testenv fixtures deps bench fuzz tools +
# v.mod) ride RING_SUP, which every compiled lane carries. Over-include on
# doubt: a false RUN costs minutes, a false SKIP costs correctness.
RING0='vcx/cx/*'
RING_STORE='vcx/cxstore/*'
RING1='vcx/code/*'
RING_LEAF='vcx/arrow/* vcx/transport/*'
RING2='vcx/platform/*'
RING_CLI='vcx/cli/* vcx/cmd_data/*'
RING_CMD='vcx/cmd/*'
RING_SUP='vcx/testenv/* vcx/fixtures/* vcx/deps/* vcx/bench/* vcx/fuzz/* vcx/tools/* vcx/v.mod third_party/*'
# libcx is built from platform/ (vcx/Makefile:222) — the TOP of the DAG — so
# every binding/ABI/prod lane legitimately depends on the whole closure. This
# is the honest bound on ring selection: it narrows those lanes away from
# vcx/tests, vcx/cmd and vcx/cli, and no further.
RING_LIB="$RING0 $RING_STORE $RING1 $RING_LEAF $RING2"

lane_globs() {
  case "$1" in
    abi-c-test)                    echo "$RING_LIB $RING_SUP include/* lang/*" ;;
    test-python)                   echo "$RING_LIB $RING_SUP include/* lang/* conformance/*" ;;
    test-rust)                     echo "$RING_LIB $RING_SUP include/* lang/*" ;;
    test-go)                       echo "$RING_LIB $RING_SUP include/* lang/*" ;;
    test-v)                        echo "$RING_LIB $RING_SUP lang/v/*" ;;
    check-prod-build)              echo "$RING_LIB $RING_SUP stdlib/* x/*" ;;
    # ── the five ring test lanes (VC-22: TEST_TARGETS names them
    # individually now; the old single `test-vcx` row could only ever say
    # "something under vcx/ moved", which selected all five) ──
    # Ring-0 lane: vcx/cx/*_test.v + the vcx/fixtures corpus loader. Cannot
    # be reached by a code/ or platform/ edit — cx imports nothing above it.
    test-vcx-cx)                   echo "$RING0 $RING_SUP conformance/*" ;;
    # cxstore imports cx only.
    test-vcx-cxstore)              echo "$RING0 $RING_STORE $RING_SUP" ;;
    # in-module tests for vcx/code + vcx/platform.
    test-vcx-code)                 echo "$RING_LIB $RING_SUP conformance/* stdlib/* x/*" ;;
    # vcx/tests/ is `module main` importing code + platform + cx + fixtures.
    test-vcx-suite)                echo "$RING_LIB vcx/tests/* $RING_SUP conformance/* stdlib/* x/*" ;;
    # vcx/cmd compiles with -d cx_platform, so it carries the full closure.
    test-vcx-cmd)                  echo "$RING_LIB $RING_CLI $RING_CMD $RING_SUP conformance/* stdlib/* x/*" ;;
    # the conformance aggregates drive the built cx binary over the corpus.
    test-vcx-conform)              echo "$RING_LIB $RING_CLI $RING_CMD $RING_SUP conformance/* stdlib/* x/*" ;;
    # `test-vcx` is no longer a TEST_TARGETS row (it stays the human entry
    # point). The row is kept so an explicit `test-changed` over a tree whose
    # Makefile still names it cannot fall through to deny-by-default.
    test-vcx)                      echo 'vcx/* stdlib/* x/* conformance/* third_party/*' ;;
    test-vcx-columnar)             echo 'vcx/platform/store_columnar* vcx/platform/stdlib_store.v vcx/arrow/* third_party/*' ;;
    check-no-legacy-try)           echo 'vcx/* conformance/* stdlib/* docs-src/*' ;;
    check-no-infix-range)          echo 'conformance/* stdlib/* docs-src/* examples/*' ;;
    check-no-cxl-token)            echo '*' ;;
    check-no-consumer-terms)       echo '*' ;;
    check-version-consistency)     echo '*' ;;
    check-effect-alignment)        echo 'vcx/* spec/*' ;;
    check-null-absence-conflation) echo 'vcx/*' ;;
    check-docs-tier1-guardrail)    echo 'docs-src/* docs/* spec/*' ;;
    check-no-adr-citations)        echo '*' ;;
    check-no-stub-impl)            echo 'vcx/*' ;;
    check-xap-dist-absences)       echo 'vcx/* x/*' ;;
    check-completions-drift)       echo 'vcx/* tooling/*' ;;
    check-tmlanguage-sync)         echo 'tooling/*' ;;
    guide-check)                   echo 'docs-src/* vcx/* stdlib/*' ;;
    directive-docs-check)          echo 'vcx/* docs-src/* spec/*' ;;
    verify-doc-blocks)             echo 'docs-src/* spec/* vcx/* stdlib/*' ;;
    verify-playground-examples)    echo 'docs-src/* examples/* vcx/*' ;;
    # docs-check (#938) regenerates the LLM layer from the templates, the
    # conformance corpus, the spec's directive registry, the stdlib bundle's
    # [module-doc]s and the binary's own --help — so any of those moving can
    # move its output. VERSION too: the primer's heading derives from it.
    docs-check)                    echo 'docs-src/* docs/llm/* scripts/gen_docs/* conformance/* spec/* stdlib/* x/* vcx/* VERSION' ;;
    ring-import-gate)              echo 'vcx/* scripts/ring_import_gate*' ;;
    gates-manifest-gate)           echo 'conformance/* scripts/gates_manifest_gate*' ;;
    ring-tag-gate)                 echo 'conformance/* scripts/*' ;;
    cxer-registry-gate)            echo 'vcx/* spec/* scripts/cxer_registry*' ;;
    spec-freeze-gate)              echo '*' ;;
    test-extraction-gate)          echo 'vcx/* conformance/* stdlib/* third_party/*' ;;
    abi-gc-gate)                   echo 'vcx/* third_party/*' ;;
    check-v-fork)                  echo 'third_party/* scripts/v_fork_register.cxd scripts/check_v_fork_patches.cx' ;;
    libcx-abi-gate)                echo 'vcx/* third_party/*' ;;
    test-profile-gate)             echo 'vcx/* conformance/* stdlib/* third_party/*' ;;
    check-code-spec-consistency)   echo 'spec/* vcx/code/*' ;;
    stdlib-catalog-gate)           echo 'stdlib/* vcx/* docs-src/*' ;;
    address-baseline-gate)         echo 'vcx/* conformance/*' ;;
    # #700 wave 1 (2026-08-24): five TEST_TARGETS lanes had no row and so
    # always ran. Each row is the lane's actual input surface, over-including
    # on doubt as the rest do.
    check-code-fixtures)           echo 'conformance/* vcx/* spec/*' ;;
    # the SIGPIPE-PIPE gate reads every shell script in the tree
    check-pipefail-pipes)          echo '*' ;;
    test-code-diagram)             echo 'conformance/* vcx/* stdlib/*' ;;
    # the oriel surface lane drives spec/03-approved/xap/demos/oriel/
    test-oriel-lane)               echo 'spec/03-approved/xap/demos/* vcx/* stdlib/* x/*' ;;
    tools-export-gate)             echo 'conformance/tools-export/* vcx/* stdlib/*' ;;
    # the roster rows live in the Makefile and name files under vcx/
    check-serial-retry-rosters)    echo 'Makefile vcx/*' ;;
    test-xpath-parity-cx)          echo 'vcx/* conformance/* scripts/check_xpath_parity_fixtures.cx' ;;
    *)                             echo '' ;; # unknown lane → ALWAYS RUN
  esac
}

# Build-infra changes invalidate EVERY lane (the Makefiles define the
# lanes; scripts implement the gates; VERSION/devbox shape the toolchain):
# any hit here short-circuits to the full union — correct-first.
INFRA_HIT=0
while IFS= read -r f; do
  case "$f" in
    Makefile|vcx/Makefile|devbox.json|devbox.lock|VERSION|scripts/*) INFRA_HIT=1; break ;;
  esac
done <<< "$CHANGED"

# The authoritative lane list comes from the Makefile so the manifest can
# never silently miss a NEW lane (an unlisted lane always runs).
LANES=$(grep -m1 '^TEST_TARGETS :=' Makefile | sed 's/^TEST_TARGETS := //')

if [ $INFRA_HIT -eq 1 ]; then
  echo "test-changed: build-infra change detected (Makefile/scripts/VERSION/devbox) — running the FULL lane union"
  if [ $DRY -eq 1 ]; then
    echo "test-changed: --dry-run — would run: $LANES"
    exit 0
  fi
  make $LANES
  exit $?
fi

run_lanes=()
skip_lanes=()
unlisted_lanes=()
for lane in $LANES; do
  globs=$(lane_globs "$lane")
  if [ -z "$globs" ]; then
    run_lanes+=("$lane") # deny-by-default: no manifest row → run
    unlisted_lanes+=("$lane")
    continue
  fi
  hit=0
  for g in $globs; do
    if [ "$g" = '*' ]; then hit=1; break; fi
    while IFS= read -r f; do
      case "$f" in
        ${g}*|$g) hit=1; break ;;
      esac
    done <<< "$CHANGED"
    [ $hit -eq 1 ] && break
  done
  if [ $hit -eq 1 ]; then run_lanes+=("$lane"); else skip_lanes+=("$lane"); fi
done

echo "test-changed: SKIP (inputs unchanged): ${skip_lanes[*]:-none}"
echo "test-changed: RUN: ${run_lanes[*]:-none}"
if [ ${#unlisted_lanes[@]} -gt 0 ]; then
  echo "test-changed: NO MANIFEST ROW (running by deny-by-default — add a row in this file to make them selectable): ${unlisted_lanes[*]}"
fi
if [ ${#run_lanes[@]} -eq 0 ]; then
  echo "test-changed: nothing to run"
  exit 0
fi
if [ $DRY -eq 1 ]; then
  echo "test-changed: --dry-run — nothing executed"
  exit 0
fi
make "${run_lanes[@]}"
