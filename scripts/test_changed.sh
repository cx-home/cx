#!/usr/bin/env bash
# test_changed — the step-input skip manifest (#700, owner ruling 1a
# 2026-08-09): run only the TEST_TARGETS steps whose declared INPUT GLOBS
# intersect the change set BASE..HEAD. Conservative by construction:
#   - a step with no manifest row ALWAYS runs (deny-by-default);
#   - globs OVER-include on doubt (a false "run" costs minutes; a false
#     "skip" costs correctness);
#   - the full `make test` union stays MANDATORY at wave/phase exits —
#     this target NEVER substitutes for an exit gate (ledger discipline).
#
# Usage:  scripts/test_changed.sh <base-ref>          (typically origin/<branch> or HEAD~N)
#         make test-changed BASE=<base-ref>
#
# Output: the skip/run decision per step (loud), then runs the selected
# steps via make, propagating the first failure.
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

# Step → input globs (space-separated, bash extended globs via case).
# A CHANGE anywhere else (unlisted paths) matches the special glob '*'
# rows only. Rows deliberately over-include:
#   - vcx/** counts as input to EVERY compiled step;
#   - conformance/** feeds every corpus-consuming step;
#   - spec/** feeds the doc/consistency gates.
# ── The ring DAG, once (RULED: VC-22) ────────────────────────────────────
# Authority: scripts/ring_import_gate.sh, which enforces these edges
# grep-level with zero tolerance. Stated here so a step's input set is
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
# step, so the support/rare dirs (testenv fixtures deps bench fuzz tools +
# v.mod) ride RING_SUP, which every compiled step carries. Over-include on
# doubt: a false RUN costs minutes, a false SKIP costs correctness.
RING0='vcx/cx/*'
RING_STORE='vcx/cxstore/*'
RING1='vcx/code/*'
RING_LEAF='vcx/arrow/* vcx/transport/*'
RING2='vcx/platform/*'
RING_CLI='vcx/cli/* vcx/cmd_data/*'
RING_CMD='vcx/cmd/*'
RING_SUP='vcx/testenv/* vcx/fixtures/* vcx/deps/* vcx/bench/* vcx/fuzz/* vcx/tools/* vcx/v.mod third_party/*'
# The $embed_file estates + the version stamp: these reach the BYTES of every
# built cx binary (vcx/Makefile BUILD_INPUT_DIRS names ../stdlib ../x
# ../docs/llm ../VERSION), so a step that BUILDS OR DRIVES a binary depends on
# them even when no .v file moved. Previously the binary-driving steps carried
# `vcx/*` and picked these up only by accident of also listing stdlib/x.
RING_EMBED='stdlib/* x/* docs/llm/* VERSION'
# libcx is built from platform/ (vcx/Makefile:222) — the TOP of the DAG — so
# every binding/ABI/prod step legitimately depends on the whole closure. This
# is the honest bound on ring selection: it narrows those steps away from
# vcx/tests, vcx/cmd and vcx/cli, and no further.
RING_LIB="$RING0 $RING_STORE $RING1 $RING_LEAF $RING2"

step_globs() {
  case "$1" in
    abi-c-test)                    echo "$RING_LIB $RING_SUP include/* lang/*" ;;
    test-python)                   echo "$RING_LIB $RING_SUP include/* lang/* conformance/*" ;;
    test-rust)                     echo "$RING_LIB $RING_SUP include/* lang/*" ;;
    test-go)                       echo "$RING_LIB $RING_SUP include/* lang/*" ;;
    test-v)                        echo "$RING_LIB $RING_SUP lang/v/*" ;;
    # #1212: -prod REJECTS shapes build-dev accepts (a reference stored into a
    # value slot), and every test-vcx-* step builds -dev — so the ~2 s prod
    # checker runs on EVERY changed set, never gated behind a glob.
    check-prod-build)              echo '*' ;;
    # ── the five ring test steps (VC-22: TEST_TARGETS names them
    # individually now; the old single `test-vcx` row could only ever say
    # "something under vcx/ moved", which selected all five) ──
    # Ring-0 step: vcx/cx/*_test.v + the vcx/fixtures corpus loader. Cannot
    # be reached by a code/ or platform/ edit — cx imports nothing above it.
    test-vcx-cx)                   echo "$RING0 $RING_SUP conformance/*" ;;
    # cxstore imports cx only.
    test-vcx-cxstore)              echo "$RING0 $RING_STORE $RING_SUP" ;;
    # in-module tests for vcx/code + vcx/platform.
    test-vcx-code)                 echo "$RING_LIB $RING_SUP conformance/* stdlib/* x/*" ;;
    # vcx/tests/ is `module main` importing code + platform + cx + fixtures.
    test-vcx-suite)                echo "$RING_LIB vcx/tests/* $RING_SUP conformance/* stdlib/* x/*" ;;
    # #1216: the serial wall-clock step — the binary-driving closure plus its own dir.
    check-conformance-coverage)    echo 'conformance/* scripts/check_conformance_coverage.sh vcx/tests/runners/conformance/*' ;;
    test-vcx-timing)               echo "$RING_LIB $RING_CLI $RING_CMD $RING_SUP $RING_EMBED vcx/timing/*" ;;
    # vcx/cmd compiles with -d cx_platform, so it carries the full closure.
    test-vcx-cmd)                  echo "$RING_LIB $RING_CLI $RING_CMD $RING_SUP conformance/* stdlib/* x/*" ;;
    # the conformance aggregates drive the built cx binary over the corpus.
    test-vcx-conform)              echo "$RING_LIB $RING_CLI $RING_CMD $RING_SUP conformance/* stdlib/* x/*" ;;
    # `test-vcx` is no longer a TEST_TARGETS row (it stays the human entry
    # point). The row is kept so an explicit `test-changed` over a tree whose
    # Makefile still names it cannot fall through to deny-by-default.
    test-vcx)                      echo 'vcx/* stdlib/* x/* conformance/* third_party/*' ;;
    test-vcx-columnar)             echo 'vcx/platform/store_columnar* vcx/platform/stdlib_store.v vcx/arrow/* third_party/*' ;;
    # the sqlite backend step (#989 wired it into TEST_TARGETS): the gated
    # store_sqlite_* suites plus the #220/#891 concurrent-writer + shared-open
    # stress, which drives the daemon dispatch path in stdlib_store.v.
    test-vcx-sqlite)               echo 'vcx/platform/store_sqlite* vcx/platform/store_concurrent_writer_test.v vcx/platform/stdlib_store.v third_party/*' ;;
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
    # #1412 — the RENDERER, not the doc graders. Its inputs are the generator
    # itself, the canonical sources it reads, and the two module tiers whose
    # pages it projects (x/ included: an x/ module gets its own page).
    guide-render-gate)             echo 'scripts/gen_guide/* docs-src/* stdlib/* x/*' ;;
    directive-docs-check)          echo 'vcx/* docs-src/* spec/*' ;;
    verify-doc-blocks)             echo 'docs-src/* spec/* vcx/* stdlib/*' ;;
    # examples/ is graded per landing now, not only at a release cut. The row
    # is wide because a platform scenario RUNS the toolchain: a `cx flow` or
    # `cx xap` change moves a recorded transcript, and so does a stdlib one.
    verify-examples)               echo "examples/* tools/verify-examples.sh stdlib/* $RING_LIB $RING_CLI $RING_CMD $RING_SUP $RING_EMBED" ;;
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
    # ── the expensive binary-driving steps (VC-22 ring-scoping, #700 wave 2
    # part ii) ──────────────────────────────────────────────────────────────
    # These five carried a blanket `vcx/*`, so ANY edit under vcx/ selected all
    # of them — including a vcx/tests-only edit, the most common dev loop of
    # all. Measured 2026-08-25: extraction-gate 768-844 s and profile-gate
    # 660 s, both serial (~0.95x parallelism), so they are not compressible by
    # -j; the only way a dev loop avoids them is not selecting them.
    #
    # Each row is now the step's real input surface: the full ring closure
    # (libcx builds from platform/, the TOP of the DAG, so any ring edit
    # legitimately reaches it — VC-22's honest bound), the support dirs, the
    # embed estate that changes binary bytes, and the step's OWN runner
    # directory. What drops out is vcx/tests/ other than that runner. Nothing
    # else narrows: over-include on doubt, a false RUN costs minutes and a
    # false SKIP costs correctness.
    test-extraction-gate)          echo "$RING_LIB $RING_CLI $RING_CMD $RING_SUP $RING_EMBED vcx/tests/runners/extraction_gate/* conformance/*" ;;
    abi-gc-gate)                   echo "$RING_LIB $RING_SUP $RING_EMBED vcx/tests/runners/abi_gc_gate/*" ;;
    check-v-fork)                  echo 'third_party/* scripts/v_fork_register.cxd scripts/check_v_fork_patches.cx' ;;
    # reads the built library's export surface against include/cx.h.
    libcx-abi-gate)                echo "$RING_LIB $RING_SUP include/* tools/libcx-abi-gate.sh" ;;
    test-profile-gate)             echo "$RING_LIB $RING_CLI $RING_CMD $RING_SUP $RING_EMBED vcx/tests/runners/profile_gate/* conformance/*" ;;
    check-code-spec-consistency)   echo 'spec/* vcx/code/*' ;;
    # ledger-index-check (#1438) regenerates ledger/README.md from the store and
    # compares: its inputs are every ledger page and the generator itself.
    ledger-index-check)            echo 'ledger/* scripts/ledger_index.cx' ;;
    stdlib-catalog-gate)           echo 'stdlib/* vcx/* docs-src/* registry/modules.cxd' ;;
    # the placement declaration and every artifact class it compares against
    # (RULED: 1427-f) — a spec, a corpus, a bundled source or a ring's V
    # directory moving is exactly what this step exists to catch.
    placement-gate)                echo 'registry/modules.cxd scripts/placement_gate.cx spec/* conformance/* stdlib/* x/* vcx/code/* vcx/platform/*' ;;
    # the dogfood documents, the gate that reads them, and everything that can
    # move the vocabulary or the two subcommands it drives them through.
    flow-dogfood-gate)             echo 'flows/* scripts/flow_dogfood_gate.cx stdlib/flow.cx vcx/cmd/* vcx/code/* vcx/cx/* spec/03-approved/std-lib/flow.md' ;;
    address-baseline-gate)         echo "$RING_LIB $RING_SUP vcx/tests/runners/address_baseline/* conformance/*" ;;
    # #700 wave 1 (2026-08-24): five TEST_TARGETS steps had no row and so
    # always ran. Each row is the step's actual input surface, over-including
    # on doubt as the rest do.
    check-code-fixtures)           echo 'conformance/* vcx/* spec/*' ;;
    # the SIGPIPE-PIPE gate reads every shell script in the tree
    check-pipefail-pipes)          echo '*' ;;
    # RULED: 1170-d — the step now also carries the SEQ-4 page-sync guard, so a
    # playground-page edit and a golden-sidecar edit are both inputs to it. The
    # whole point of that guard is that a page edit to 171/172 reds something;
    # without these two globs the dev loop would skip the step that says so.
    test-code-diagram)             echo "conformance/* $RING_LIB $RING_CLI $RING_CMD $RING_SUP $RING_EMBED scripts/check_code_diagram_fixtures.cx scripts/gen_guide/playground/playground.examples.js vcx/tests/testdata/code_diagram_golden/*" ;;
    # the oriel surface step drives spec/03-approved/xap/demos/oriel/
    test-oriel-lane)               echo 'spec/03-approved/xap/demos/* vcx/* stdlib/* x/*' ;;
    # #1403 — the ONLY step that puts the SSO stack on a socket. Its inputs are
    # the two programs it runs, the step script, and every module and native
    # file the relying-party path bottoms out in: a change to oidc's request
    # forming or saml's verification that nothing else catches gets caught here.
    # The http CLIENT joined the row with #1396: the step's proxy and
    # Retry-After rows grade the client's transport map, so a change there
    # that never touches oidc must still re-run this step.
    test-sso-interop-lane)         echo 'scripts/sso_interop/* scripts/sso_interop_lane.sh stdlib/oidc.cx stdlib/saml.cx stdlib/session.cx stdlib/crypto.cx stdlib/http.cx stdlib/net.cx vcx/code/stdlib_oidc.v vcx/code/stdlib_saml*.v vcx/platform/stdlib_session.v vcx/code/stdlib_crypto.v vcx/code/stdlib_http_notd_cx_no_pack_http_client.v vcx/code/net_core_notd_cx_no_pack_http_client.v examples/platform/sso/*' ;;
    tools-export-gate)             echo 'conformance/tools-export/* vcx/* stdlib/*' ;;
    # the roster rows live in the Makefile and name files under vcx/
    check-serial-retry-rosters)    echo 'Makefile vcx/*' ;;
    # #1448: the partition guard reads the manifest, the corpus it partitions
    # and the shard test files it holds to it.
    check-fixture-shard-manifest)  echo 'conformance/fixture_shards.cxd conformance/stdlib/* conformance/extended.cxd vcx/tests/code_eval_fixtures_shard_*_test.v scripts/check_fixture_shard_manifest.sh' ;;
    # #1370: the shim archives' alignment — the rules that write them and the checker.
    check-shim-archives)           echo 'vcx/Makefile scripts/check_archive_alignment.sh vcx/deps/re2_shim/* vcx/arrow/shim/*' ;;
    # pure shell over canned logs — its only inputs are the classifier and the
    # SKIP_UNUSED_ESCAPE_PROBE that consumes it (\#1337).
    check-build-failure-classifier) echo 'Makefile scripts/classify_v_build_failure.sh' ;;
    # 1170-f: every playground diagram parses and has no structural fault. Inputs:
    # the engine (the wasm bundle is built from it), the emitters, the playground
    # page and its example corpus, the gate itself.
    test-playground-mermaid)       echo "$RING_LIB $RING_CLI $RING_CMD $RING_SUP $RING_EMBED stdlib/* scripts/gen_guide/playground/* scripts/test_playground_mermaid.mjs scripts/wasm/*" ;;
    test-xpath-parity-cx)          echo "$RING_LIB $RING_CLI $RING_CMD $RING_SUP $RING_EMBED conformance/* scripts/check_xpath_parity_fixtures.cx" ;;
    # corpus-audit (RULED: VC-28) runs every rosetta program through the built
    # binary and fails on drift from AUDIT.md, so it depends on the corpus AND
    # on anything that changes the binary's behaviour.
    corpus-audit)                  echo "corpus/* $RING_LIB $RING_CLI $RING_CMD $RING_SUP $RING_EMBED scripts/corpus_audit.sh" ;;
    # bench/repr (#1119 W1) compiles the `cx` module as SOURCE and measures the
    # live tree it builds, so it depends on Ring 0 and on nothing above it.
    repr-guard)                    echo 'vcx/cx/* vcx/v.mod third_party/* bench/repr/*' ;;
    # the in-module Ring-0 test roster guard (#1209) reads the Makefile roster
    # and the vcx/cx test files it must account for.
    check-inmodule-test-roster)    echo 'Makefile vcx/cx/*' ;;
    # fmt-sweep-gate (RULED: 1348-c) re-formats every tracked .cx, so ANY .cx
    # anywhere can move a verdict — the row is deliberately the whole tree,
    # plus the formatter, the sweep and its roster.
    fmt-sweep-gate)                echo '*.cx Makefile scripts/fmt_corpus_sweep.cx scripts/fmt_corpus_expected_errors.txt vcx/cx/*' ;;
    *)                             echo '' ;; # unknown step → ALWAYS RUN
  esac
}

# Build-infra changes invalidate EVERY step (the Makefiles define the
# steps; scripts implement the gates; VERSION/devbox shape the toolchain):
# any hit here short-circuits to the full union — correct-first.
# Step fan-out parallelism. `make test` runs its union under
# -j$(TEST_JOBS) --output-sync=target; this script called a BARE `make`, so
# the documented dev loop ran its selected steps ONE AT A TIME. Measured
# 2026-08-24: a vcx/tests-only edit selected 32 of 51 steps and took 2,347 s
# — SLOWER than the full 1,428 s parallel gate. Selecting fewer steps is
# worthless if they then run serially, and the target's whole purpose is to
# be the fast loop. Same defaults as the Makefile (TEST_JOBS is overridable
# there and here).
TEST_JOBS="${TEST_JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 8)}"
MAKEFLAGS_PAR="-j${TEST_JOBS}"
# --output-sync needs GNU make >= 4.0 (Apple ships 3.81), so it is probed, not
# assumed. NOT `make --help | grep -q` — that is the exact SIGPIPE-PIPE class
# check-pipefail-pipes refuses (RULED: SPG-1, #916): grep -q exits on the
# first match, the producer takes SIGPIPE, and `set -o pipefail` promotes it
# to a failure. Capture first, match second.
make_help="$(make --help 2>/dev/null || true)"
case "$make_help" in
  *--output-sync*) MAKEFLAGS_PAR="$MAKEFLAGS_PAR --output-sync=target" ;;
esac

INFRA_HIT=0
while IFS= read -r f; do
  case "$f" in
    Makefile|vcx/Makefile|devbox.json|devbox.lock|VERSION|scripts/*) INFRA_HIT=1; break ;;
  esac
done <<< "$CHANGED"

# The authoritative step list comes from the Makefile so the manifest can
# never silently miss a NEW step (an unlisted step always runs).
STEPS=$(grep -m1 '^TEST_TARGETS :=' Makefile | sed 's/^TEST_TARGETS := //')

# Serial pre-build BEFORE any parallel fan-out — the same guard `make test`
# carries (Makefile's `test` recipe): every step's recursive build then hits
# the vcx Makefile's up-to-date guard and skips the relink. Without it,
# concurrent sub-makes RELINK target/cx while sibling steps are exec'ing it
# — the v0.16.0 cut's 'Exec format error' / empty-output-rc-0 class. Adding
# -j here without this would have reintroduced exactly that. Both artifacts
# are pre-built: `make test` only pre-builds build-vcx, but the steps this
# script selects depend on build-vcx-dev too, and it is free when current.
prebuild() {
  make build-vcx && make build-vcx-dev
}

# ── the SERIAL TAIL, mirrored from `make test` (#1216 / #1227 / #1345) ──
#
# `make test` does NOT run its whole union under -j. Three steps carry
# WALL-CLOCK assertions and are filtered OUT of the storm and run one at a
# time after it drains (the `test:` recipe): test-profile-gate for #1227's
# quiet context, test-vcx-timing for #1216's boot and try-send/try-receive
# budgets, test-code-diagram for #1345's emitter budget. The reasoning is
# recorded there: "an absolute budget that only holds on an idle box is not a
# property of the binary".
#
# This script ran its ENTIRE selection under one -j, so all three went back
# INTO a storm — the fast loop disagreeing with the exit gate about which
# steps are load-sensitive. Measured 2026-09-08: two consecutive
# `make test-changed` runs over one vcx/code edit both exited 2 on
# test-vcx-timing at a sha where the step is green alone. That step's own
# assertion text reads "This step runs serially after the -j storm (#1216),
# so load is not the explanation" — true of `make test`, false here, so a
# false red arrived wearing a message that pointed the reader at the binary.
#
# The order is the Makefile's order, and it is one `make` per tail step so a
# red names its own step.
SERIAL_TAIL='test-profile-gate test-vcx-timing test-code-diagram'

# run_step_set STEP… — the storm for everything but the tail, then the tail,
# serially. Propagates the FIRST failure, like the bare `make` it replaces.
#
# bash 3.2 (what macOS ships, and what runs this script when devbox is not in
# front of it) makes `"${arr[@]}"` on an EMPTY array an unbound-variable error
# under `set -u`, so every expansion below is length-guarded. A docs-only
# selection has no tail step, and that is the common case, not the corner.
run_step_set() {
  local par=() tailed=() l t is_tail
  for l in "$@"; do
    is_tail=0
    for t in $SERIAL_TAIL; do
      [ "$l" = "$t" ] && { is_tail=1; break; }
    done
    if [ $is_tail -eq 1 ]; then tailed+=("$l"); else par+=("$l"); fi
  done
  if [ $DRY -eq 1 ]; then
    # The split is what this function EXISTS for, so --dry-run shows it rather
    # than only the selection — that is what makes the carve-out checkable
    # without spending a step run on it.
    echo "test-changed: --dry-run — parallel (-j): ${par[*]:-none}"
    # Printed in EXECUTION order (SERIAL_TAIL's), not selection order, so the
    # line says what would actually happen.
    local shown=()
    if [ ${#tailed[@]} -gt 0 ]; then
      for t in $SERIAL_TAIL; do
        for l in "${tailed[@]}"; do
          [ "$l" = "$t" ] && shown+=("$t")
        done
      done
    fi
    echo "test-changed: --dry-run — serial tail:  ${shown[*]:-none}"
    return 0
  fi
  if [ ${#par[@]} -gt 0 ]; then
    make $MAKEFLAGS_PAR "${par[@]}" || return $?
  fi
  [ ${#tailed[@]} -eq 0 ] && return 0
  for t in $SERIAL_TAIL; do
    for l in "${tailed[@]}"; do
      if [ "$l" = "$t" ]; then
        echo "test-changed: serial tail (wall-clock step, #1216/#1227/#1345): $t"
        make "$t" || return $?
      fi
    done
  done
  return 0
}

if [ $INFRA_HIT -eq 1 ]; then
  echo "test-changed: build-infra change detected (Makefile/scripts/VERSION/devbox) — running the FULL step union"
  if [ $DRY -eq 1 ]; then
    echo "test-changed: --dry-run — would run: $STEPS"
    run_step_set $STEPS
    exit 0
  fi
  prebuild && run_step_set $STEPS
  exit $?
fi

run_steps=()
skip_steps=()
unlisted_steps=()
for step in $STEPS; do
  globs=$(step_globs "$step")
  if [ -z "$globs" ]; then
    run_steps+=("$step") # deny-by-default: no manifest row → run
    unlisted_steps+=("$step")
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
  if [ $hit -eq 1 ]; then run_steps+=("$step"); else skip_steps+=("$step"); fi
done

echo "test-changed: SKIP (inputs unchanged): ${skip_steps[*]:-none}"
echo "test-changed: RUN: ${run_steps[*]:-none}"
if [ ${#unlisted_steps[@]} -gt 0 ]; then
  echo "test-changed: NO MANIFEST ROW (running by deny-by-default — add a row in this file to make them selectable): ${unlisted_steps[*]}"
fi
if [ ${#run_steps[@]} -eq 0 ]; then
  echo "test-changed: nothing to run"
  exit 0
fi
if [ $DRY -eq 1 ]; then
  run_step_set "${run_steps[@]}"
  echo "test-changed: --dry-run — nothing executed"
  exit 0
fi
prebuild && run_step_set "${run_steps[@]}"
