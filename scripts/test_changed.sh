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
lane_globs() {
  case "$1" in
    abi-c-test)                    echo 'vcx/* include/* lang/*' ;;
    test-python)                   echo 'vcx/* lang/* include/* conformance/*' ;;
    test-vcx)                      echo 'vcx/* stdlib/* x/* conformance/* third_party/*' ;;
    test-vcx-columnar)             echo 'vcx/platform/store_columnar* vcx/platform/stdlib_store.v vcx/arrow/* third_party/*' ;;
    test-v)                        echo 'vcx/* third_party/*' ;;
    test-rust)                     echo 'vcx/* lang/* include/*' ;;
    test-go)                       echo 'vcx/* lang/* include/*' ;;
    check-prod-build)              echo 'vcx/* stdlib/* x/* third_party/*' ;;
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
