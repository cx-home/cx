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
# ESCALATION, stated so that "escalated" is ONE measurable word (#1489):
# the selection ESCALATES when a BUILD-INFRA path changed — `Makefile`,
# `vcx/Makefile`, anything under `scripts/`, `VERSION`, or `devbox*`. That is
# the only escalation to the full union; everything else narrows. An escalated
# selection is the POST-MERGE run's (INT-5), and since #1489 this script
# REFUSES to execute one under a pre-merge runner rather than leaving that to
# discipline: it prints the selection, why it escalated, and
# `TEST-CHANGED: escalated → post-merge (INT-5)`, then exits 0 having run
# nothing. `TEST_CHANGED_FORCE_UNION=1` overrides. Note that the narrower
# "the WHOLE suite" answer for `test-vcx-suite` is NOT an escalation in this
# sense — it selects every file of one step, not every step.
#
# Usage:  scripts/test_changed.sh <base-ref>          (typically origin/<branch> or HEAD~N)
#         make test-changed BASE=<base-ref>
#
# Output: the skip/run decision per step (loud), then runs the selected
# steps via make, propagating the first failure.
set -euo pipefail

BASE="${1:?usage: test_changed.sh <base-ref> [--dry-run] [--changed-files <file>]}"
shift
DRY=0
CHANGED_SRC=''
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    # --changed-files <file> (#1516) — take the change set from a file of paths,
    # one per line, instead of from git. It is what lets the selftest prove a
    # selection rule against the REAL Makefile, the REAL manifest rows and the
    # REAL import graph over a change set no commit has to exist for. Only
    # meaningful with --dry-run: a selection derived from a synthetic diff must
    # never be allowed to RUN anything.
    --changed-files)
      shift
      CHANGED_SRC="${1:?--changed-files needs a file}"
      case "$CHANGED_SRC" in
        /*) ;;
        *) CHANGED_SRC="$(CDPATH= cd -- "$(dirname -- "$CHANGED_SRC")" && pwd)/$(basename -- "$CHANGED_SRC")" ;;
      esac ;;
    *) echo "test-changed: unknown argument '$1'" >&2; exit 2 ;;
  esac
  shift
done
cd "$(dirname "$0")/.."

if [ -n "$CHANGED_SRC" ]; then
  [ $DRY -eq 1 ] || { echo "test-changed: --changed-files is a --dry-run flag (a synthetic diff must never RUN a step)" >&2; exit 2; }
  CHANGED=$(cat "$CHANGED_SRC")
else
  CHANGED=$(git diff --name-only "$BASE"...HEAD; git diff --name-only HEAD; git diff --name-only --cached)
fi
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
    # reader-parity (RULED: CXF-5, #1521): the three readers over the corpus
    # FILES — libcx (lang/), the V data parser and the program reader (RING_LIB),
    # the fixture loader (RING_SUP), every `.cxd` and the playground corpus.
    reader-parity)                 echo "$RING_LIB $RING_SUP lang/* conformance/* scripts/gen_guide/playground/*" ;;
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
    test-vcx-suite)                echo "$RING_LIB vcx/tests/* $RING_SUP conformance/* $RING_EMBED" ;;
    # #1216: the serial wall-clock step — the binary-driving closure plus its own dir.
    check-conformance-coverage)    echo 'conformance/* scripts/check_conformance_coverage.sh vcx/tests/runners/conformance/*' ;;
    # ── THE SERIAL TAIL, narrowed (#1516, RULED: RUN-1) ─────────────────────
    # These two run ALONE after the -j storm drains, so their minutes are
    # wall-clock minutes nothing else overlaps: 660 s for the profile gate,
    # and the tail is why the run on b9d79025d took two hours for a head that
    # changed one x/ module's CSS and one corpus case.
    #
    # test-vcx-timing asserts a BOOT BUDGET and the try-send/try-receive
    # budgets — properties of the compiled binary's start-up and channel
    # fast paths, which is vcx/cx (the Ring-0 sink the boot path is) and
    # vcx/code (the evaluator it boots into), plus the V pin that compiles
    # them and its own runner directory. An embedded stdlib module, an x/
    # module, a corpus case or a doc byte cannot move a boot budget: they
    # change what the binary READS, not how long it takes to come up.
    test-vcx-timing)               echo 'vcx/cx/* vcx/code/* vcx/timing/* third_party/*' ;;
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
    # test-profile-gate GRADES: it runs the corpus through each profile and
    # compares. So its inputs are what is graded and what grades — vcx/code and
    # vcx/cx (the parser and the evaluator every profile runs through), the
    # embedded stdlib the profiles pack, conformance/code.cxd, the graded module
    # corpora, the graders themselves and its own runner directory, plus the V
    # pin. RING_LIB rather than the two named directories because the profile
    # binaries compile from the whole libcx closure — a platform module's prims
    # are packed into the profiles this step is comparing. What drops out is the
    # CLI/cmd side, the embed estate beyond stdlib/, and the conformance files
    # no shard grades: a CSS byte in an x/ module and a docs/llm regeneration
    # grade nothing here, and they were selecting an 11-minute serial step.
    test-profile-gate)             echo "$RING_LIB stdlib/* conformance/code.cxd conformance/stdlib/* conformance/platform/* conformance/x/* conformance/xap/* conformance/extended.cxd conformance/xml_codec.cxd vcx/tests/runners/profile_gate/* vcx/tests/fixtures_grader/* third_party/*" ;;
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
    flow-dogfood-gate)             echo 'flows/* scripts/flow_dogfood_gate.cx stdlib/flow.cx vcx/cmd/* vcx/code/* vcx/cx/* spec/03-approved/platform/flow.md' ;;
    address-baseline-gate)         echo "$RING_LIB $RING_SUP vcx/tests/runners/address_baseline/* conformance/*" ;;
    # #700 wave 1 (2026-08-24): five TEST_TARGETS steps had no row and so
    # always ran. Each row is the step's actual input surface, over-including
    # on doubt as the rest do.
    check-code-fixtures)           echo 'conformance/* vcx/* spec/*' ;;
    # the SIGPIPE-PIPE gate reads every shell script in the tree
    check-pipefail-pipes)          echo '*' ;;
    # #1542 (RULED: VERIFY-1): the unscoped bare-`exec` redirect gate scans BOTH
    # Makefiles (where `$(JS_CLOSE)` lives, and every recipe that opens with it)
    # and every shell script under scripts/. That is the same input surface as
    # check-pipefail-pipes, its sibling in this family, so it takes the same
    # over-including glob rather than a narrower list that would silently skip
    # the step when a recipe grows a new `exec`. Its own source is an input too.
    check-exec-redirect)           echo '*' ;;
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
    check-fixture-shard-manifest)  echo 'vcx/tests/fixtures_grader/fixture_shards.cxd conformance/stdlib/* conformance/platform/* conformance/x/* conformance/xap/* conformance/extended.cxd conformance/xml_codec.cxd vcx/tests/code_eval_fixtures_shard_*_test.v scripts/check_fixture_shard_manifest.sh' ;;
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
    # ── #1516 (RULED: RUN-1): the THIRTEEN TEST_TARGETS entries that carried no
    # row and therefore ran on every head by deny-by-default. Measured on
    # b9d79025d (a ux-web CSS + one corpus case): they were a third of the
    # selected set. Each row below is derived from the step's own recipe and
    # from the script that recipe runs — never guessed — and over-includes on
    # doubt, the same direction every row above takes.
    #
    # `check-selection-manifest` is what keeps this list complete from here on:
    # it fails when a TEST_TARGETS entry has no row, so deny-by-default stays
    # the fallback for a step in flight and never the resting state.
    #
    # the adversarial -usecache proof (scripts/vcache_soundness_gate.sh): it
    # REBUILDS the tree from source under mutated inputs and compares behaviour,
    # so its surface is the whole compiled closure plus the gate itself.
    check-selection-manifest)      echo 'Makefile scripts/test_changed.sh scripts/check_selection_manifest.sh scripts/test_changed_selftest.sh vcx/tests/* conformance/*' ;;
    check-vcache-soundness)        echo "$RING_LIB $RING_CLI $RING_CMD $RING_SUP $RING_EMBED scripts/vcache_soundness_gate.sh" ;;
    # #1272: the §1.2 normative body it fingerprints, the generated V constant
    # it compares against, and the gate/generator pair that writes both.
    check-contract-revision)       echo 'spec/* vcx/* scripts/check_contract_revision.sh scripts/gen_contract_revision.sh' ;;
    # reads the BUILT artifacts' link surface (vcx/target/cx, libcx.dylib), so
    # anything that changes what is linked into them is an input.
    check-portable-links)          echo "$RING_LIB $RING_CLI $RING_CMD $RING_SUP $RING_EMBED scripts/check_portable_links.cx" ;;
    # #1012's resurrection guards over the umbrella manifests: the manifests,
    # the driver and its selftest, and the umbrella test files they hold to.
    check-consolidation-manifests) echo 'scripts/consolidation/* scripts/consolidate_tests.sh scripts/consolidate_tests.cx scripts/consolidate_tests_selftest.sh vcx/tests/*' ;;
    # the seam register against the platform + stdlib spec pages it is derived
    # from (scripts/check_composition_seams.cx reads spec/03-approved/{platform,stdlib}).
    check-composition-seams)       echo 'spec/* scripts/check_composition_seams.cx' ;;
    # #1171: the directive registry (vcx/cx/program_tokens.v) on one side and
    # every editor surface + the checked-in register under tooling/ on the other.
    check-editor-surface-parity)   echo 'vcx/cx/* tooling/* scripts/check_editor_surface_parity.cx' ;;
    # INT-11 (#1475): the four document sets the recipe walks — docs-src/,
    # spec/03-approved/, the root prose files, and the generated LLM layer.
    verify-doc-links)              echo 'docs-src/* spec/* docs/llm/* tools/verify-doc-links.sh README.md CONTRIBUTING.md ROADMAP.md SECURITY.md CODE_OF_CONDUCT.md CHANGELOG.md RELEASE_NOTES_v AGENTS.md CLAUDE.md AGENT-STANDING-RULES.md' ;;
    # COMP-1 part 4: the chapter is GENERATED from the two platform spec pages,
    # and the generator runs under the built binary.
    primer-platform-check)         echo "spec/03-approved/platform/composition.md spec/03-approved/platform/deployment-topology.md docs-src/llm/primer-platform.chapter.md scripts/gen_docs/primer_platform.cx $RING_LIB $RING_SUP" ;;
    # #1265: the vocabulary is flow.md's, the surface is stdlib/flow.cx, and the
    # gate runs under the built binary's parser.
    flow-vocabulary-gate)          echo 'spec/03-approved/platform/flow.md stdlib/flow.cx scripts/flow_vocabulary_gate.cx vcx/cx/* vcx/code/*' ;;
    # #1380: a jsdom gate over the SHIPPED playground page and script — no wasm,
    # no binary. Its inputs are that directory, the gate and its node modules.
    test-playground-nav)           echo 'scripts/gen_guide/playground/* scripts/test_playground_nav.mjs scripts/playground-gate/*' ;;
    # #1374: the same playground corpus evaluated in the WASM bundle, and the
    # bundle is built from the ring closure (scripts/wasm/ + build-playground).
    test-playground-wasm-traps)    echo "scripts/gen_guide/playground/* scripts/test_playground_wasm_traps.mjs scripts/wasm/* $RING_LIB $RING_SUP $RING_EMBED" ;;
    # #1180: the binding_api fixture file, the four drivers under lang/, the
    # public header they call through, and libcx's own closure.
    test-binding-api-parity)       echo "conformance/binding_api.txt lang/* include/* scripts/test_binding_api_parity.sh scripts/compile_binding_api_fixtures.cx $RING_LIB $RING_SUP" ;;
    # #1065: the rosters live in vcx/Makefile and are re-derived from the module
    # set each artifact compiles, so any vcx/ module moving is an input.
    check-build-input-roster)      echo 'vcx/Makefile vcx/*' ;;
    *)                             echo '' ;; # unknown step → ALWAYS RUN
  esac
}

# ── PER-FILE SUITE SELECTION (#1516, RULED: RUN-1) ──────────────────────────
#
# `test-vcx-suite` is ONE manifest row over 76 V test files and ~35 minutes at
# -j12, so any head that touched vcx/, conformance/, stdlib/ or x/ bought the
# whole thing. The row still decides whether the STEP runs; this decides which
# FILES it runs when it does. `make test-vcx-suite` on its own is untouched —
# SUITE_FILES defaults to `vcx/tests/` in the Makefile, which is the union.
#
# THE DEPENDENCY MODEL, and where each edge comes from.
#
#  * V IMPORTS. A test file depends on every vcx/ module it imports, transitively
#    — the knowledge check-build-input-roster re-derives with `v -print-v-files`,
#    read here straight from the `import` lines so the fast loop needs neither V
#    nor a build. `tests.fixtures_grader` is the grader package under vcx/tests/;
#    `transport.picoev` and its siblings resolve to vcx/transport.
#
#  * testenv DRIVES THE BUILT BINARY. 55 of the 76 files import `testenv` and run
#    `testenv.cx_bin()` — the shipped `cx`. Import scanning alone would say they
#    depend on nothing but vcx/testenv, which is the one unsound answer available
#    here, so `testenv` carries an explicit edge to every ring directory the
#    binary compiles from.
#
#  * THE CORPUS. A module's cases are graded by the shard that owns its corpus
#    file, and which shard that is already has one authority:
#    scripts/fixture_files_for_branch.sh resolves a module source or a corpus
#    path to conformance/… files (its rules 1-4), and
#    vcx/tests/fixtures_grader/fixture_shards.cxd maps those to shard test files.
#    Both are reused rather than restated — a second copy of that resolution is a
#    second thing to be wrong.
#
#  * NAMES. On top of the shard, any test file whose own source NAMES the module
#    is selected: a module's behaviour reaches a test through the CX program the
#    test embeds, and that program spells the module out.
#
# FAIL-SAFE IN BOTH DIRECTIONS. Anything that shapes the suite rather than being
# tested by it — vcx/tests/ shared helpers, vcx/testenv, vcx/fixtures,
# third_party/, the Makefiles, scripts/, vcx/v.mod, devbox — runs the WHOLE
# suite, and so does any changed path no rule below classifies. Only an explicit
# not-an-input list (spec/, docs-src/, ledger/, docs/ outside the generated LLM
# layer, _gate_evidence/, .github/, root prose) selects nothing.
SUITE_DIR='vcx/tests'
# The vcx/ directories that are V modules a test file can import.
VCX_MODULES='cx code platform cxstore arrow transport cli cmd cmd_data testenv fixtures timing tools bench fuzz'
# The directories the shipped `cx` and libcx compile from — testenv's edge,
# because a test that runs the binary runs all of this.
BINARY_MODULES='cx code platform cxstore arrow transport cli cmd cmd_data'

# vcx_module_of <import-name> — the vcx/ module directory it names, or nothing
# when it is V's own stdlib (os, net, time, encoding.base64, x.json2, …). The V
# pin is not consulted: a third_party/ change runs the whole suite.
vcx_module_of() {
  case "$1" in
    tests.fixtures_grader) echo 'tests/fixtures_grader'; return 0 ;;
    *.*) set -- "${1%%.*}" ;;
  esac
  case " $VCX_MODULES " in *" $1 "*) echo "$1" ;; esac
}

# read_imports <file…> — the vcx-local modules those V files import directly.
read_imports() {
  local imp
  { grep -h '^import ' "$@" 2>/dev/null || true; } \
    | sed 's/^import //; s/ as .*//; s/[[:space:]]*$//' \
    | sort -u \
    | while IFS= read -r imp; do vcx_module_of "$imp"; done
}

# module_direct_imports <module-dir-name> — its .v files' vcx-local imports. A
# directory that does not exist (vcx/fuzz today) and a directory with no import
# line are both the EMPTY answer, never a failure: `set -o pipefail` would
# otherwise turn a missing optional module into an aborted selection.
module_direct_imports() {
  [ -d "vcx/$1" ] || return 0
  read_imports $(find "vcx/$1" -name '*.v' -type f 2>/dev/null)
}

# The per-module direct-import sets, computed ONCE into shell variables (bash 3.2
# has no associative arrays, and recomputing a find+grep over vcx/platform for
# every one of 76 test files is the difference between a second and a minute).
SUITE_GRAPH_READY=0
suite_graph() {
  [ $SUITE_GRAPH_READY -eq 1 ] && return 0
  local m v
  for m in $VCX_MODULES; do
    v=$(module_direct_imports "$m" | tr '\n' ' ' || true)
    [ "$m" = testenv ] && v="$v $BINARY_MODULES"
    eval "SUITE_DI_$m=\$v"
  done
  # the grader package under vcx/tests/ imports the ring the same way
  v=$(read_imports "$SUITE_DIR"/fixtures_grader/*.v | tr '\n' ' ' || true)
  SUITE_DI_tests_fixtures_grader="$v"
  SUITE_GRAPH_READY=1
}

# module_closure <module…> — the transitive vcx-local module set.
module_closure() {
  local seen="" frontier="$*" next m key
  suite_graph
  while [ -n "$frontier" ]; do
    next=""
    for m in $frontier; do
      case " $seen " in *" $m "*) continue ;; esac
      seen="$seen $m"
      key=$(printf '%s' "$m" | tr '/.' '__')
      eval "next=\"\$next \${SUITE_DI_$key:-}\""
    done
    frontier="$next"
  done
  printf '%s\n' $seen
}

# The closure of every test file, computed once: "<path> <module> <module>…".
# ONE grep over the whole directory, not one per file: this runs on every dev
# loop and 76 four-process pipelines is twenty seconds nobody agreed to spend.
SUITE_CLOSURE=''
suite_closure() {
  [ -n "$SUITE_CLOSURE" ] && return 0
  local t cur roots line f imp
  cur=''
  roots=''
  while IFS= read -r line; do
    f=${line%%:*}
    imp=${line#*:import }
    imp=${imp%% as *}
    if [ "$f" != "$cur" ]; then
      [ -n "$cur" ] && SUITE_CLOSURE="$SUITE_CLOSURE
$cur $(module_closure $roots | tr '\n' ' ')"
      cur=$f
      roots=''
    fi
    roots="$roots $(vcx_module_of "$imp")"
  done <<EOF
$({ grep -H '^import ' "$SUITE_DIR"/*_test.v 2>/dev/null || true; } | sed 's/[[:space:]]*$//')
EOF
  [ -n "$cur" ] && SUITE_CLOSURE="$SUITE_CLOSURE
$cur $(module_closure $roots | tr '\n' ' ')"
  # a test file with no import line at all still has to be listed, or the awk
  # below could never name it — it is selected by its own path, nothing else.
  for t in "$SUITE_DIR"/*_test.v; do
    [ -e "$t" ] || continue
    case "$SUITE_CLOSURE" in
      *"
$t "*|*"
$t") ;;
      *) SUITE_CLOSURE="$SUITE_CLOSURE
$t" ;;
    esac
  done
  return 0
}

# tests_by_module <module-dir-name> — every test file whose closure holds it.
tests_by_module() {
  suite_closure
  printf '%s\n' "$SUITE_CLOSURE" | awk -v want="$1" '
    NF > 0 { for (i = 2; i <= NF; i++) if ($i == want) { print $1; break } }'
}

# tests_importing <path-relative-to-vcx> — the module rule for a changed vcx/ file.
tests_importing() {
  local d=${1%%/*}
  case " $VCX_MODULES " in *" $d "*) ;; *) return 0 ;; esac
  tests_by_module "$d"
}

# shard_test_for <conformance-path…> — the vcx/tests/ file that grades each, read
# from the shard manifest scripts/run_fixture_shards.sh reads, with the same cut
# of its own [doc] block.
shard_test_for() {
  local manifest="$SUITE_DIR/fixtures_grader/fixture_shards.cxd" owners c rel hit
  [ -f "$manifest" ] || { echo ALL; return 0; }
  owners=$(sed '/\[doc \[#/,/#\]\]/d' "$manifest" \
    | { grep -oE '^[[:space:]]*\[(shard[[:space:]]+name=[^][:space:]]+[[:space:]]+test=[^][:space:]]+|file[[:space:]]+name=[^][:space:]]+)' \
    | sed -E 's/^[[:space:]]*\[//' \
    | awk '$1 == "shard" { sub(/^test=/, "", $3); stest = $3; next }
           $1 == "file"  { sub(/^name=/, "", $2); print stest, $2 }' || true; })
  [ -n "$owners" ] || { echo ALL; return 0; }
  for c in "$@"; do
    rel=${c#conformance/}
    if [ "$rel" = code.cxd ]; then
      # the DRIVER's own corpus: the driver grades it, and two more files pin the
      # parser census and the parse fixtures against it (INT-15's page).
      echo "$SUITE_DIR/code_eval_fixtures_test.v"
      echo "$SUITE_DIR/code_parse_fixtures_test.v"
      echo "$SUITE_DIR/cxparse_full_corpus_diff_test.v"
      continue
    fi
    # `test=` in the manifest already spells the path from the repo root.
    hit=$(printf '%s\n' "$owners" | awk -v r="$rel" '$2 == r { print $1 }')
    # A corpus file no shard owns is check-fixture-shard-manifest's failure, not
    # this script's to guess around: grade everything.
    [ -n "$hit" ] || { echo ALL; return 0; }
    printf '%s\n' "$hit"
  done
}

# suite_files — prints ALL, or the selected vcx/tests/*_test.v paths, or nothing.
suite_files() {
  local sel='' f m cs corpus t names
  # (a) the escalations — what shapes the suite rather than being tested by it.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in
      "$SUITE_DIR"/*_test.v) continue ;;
      "$SUITE_DIR"/*|vcx/testenv/*|vcx/fixtures/*|third_party/*|Makefile|vcx/Makefile|vcx/v.mod|devbox.json|devbox.lock|scripts/*)
        echo ALL; return 0 ;;
    esac
  done <<< "$CHANGED"
  # The import graph and the per-file closure are built HERE, in this shell:
  # every use of them below sits inside a command substitution, and a subshell's
  # cache dies with it — priming them per test file cost 18 seconds of the first
  # cut for a table that does not change.
  suite_graph
  suite_closure
  # (b) the corpus side, through the one resolver that owns it.
  cs=$(mktemp) || { echo ALL; return 0; }
  printf '%s\n' "$CHANGED" > "$cs"
  corpus=$(sh scripts/fixture_files_for_branch.sh --changed-files "$cs" 2>/dev/null)
  rm -f "$cs"
  case "$corpus" in
    ALL) echo ALL; return 0 ;;
    '') ;;
    *) t=$(shard_test_for $corpus)
       case " $(printf '%s' "$t" | tr '\n' ' ') " in *" ALL "*) echo ALL; return 0 ;; esac
       sel="$sel $(printf '%s' "$t" | tr '\n' ' ')" ;;
  esac
  # (c) the per-path rules.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in
      "$SUITE_DIR"/*_test.v)
        sel="$sel $f" ;;
      stdlib/*.cx|x/*.cx|vcx/platform/stdlib_*.v|vcx/code/stdlib_*.v)
        # the corpus side is already in `sel`; this is the NAME clause on top,
        # plus the ring rule for the two V spellings.
        case "$f" in
          stdlib/*.cx|x/*.cx) m=${f##*/}; m=${m%.cx} ;;
          *) m=${f##*/stdlib_}; m=${m%.v}; m=${m%.c}; m=$(printf '%s' "$m" | tr '_' '-') ;;
        esac
        names=$(grep -lF -- "$m" "$SUITE_DIR"/*_test.v 2>/dev/null | tr '\n' ' ' || true)
        # NO ring edge here, deliberately. A `stdlib_<m>.v` is a LEAF of its
        # module directory — one module's prims — and the whole of vcx/platform
        # is not its blast radius; its cases are graded by the shard above and
        # its behaviour reaches a test through the program that names it. The
        # engine files beside it (the parser, the evaluator, the runtime) take
        # the `vcx/*` rule below and do carry the ring edge. A module source
        # that resolves to NO corpus file is shared infrastructure, and the
        # resolver already answered ALL for it.
        sel="$sel $names" ;;
      vcx/*)
        sel="$sel $(tests_importing "${f#vcx/}" | tr '\n' ' ')" ;;
      conformance/*)
        # in-walk corpus files are resolved in (b); anything else under
        # conformance/ is read through the `fixtures` corpus loader.
        sel="$sel $(tests_by_module fixtures | tr '\n' ' ')" ;;
      docs/llm/*|VERSION)
        # embedded in the binary, read only by its own doc/help surface.
        sel="$sel $SUITE_DIR/cli_umbrella_test.v $SUITE_DIR/cli_default_eval_test.v" ;;
      spec/*|docs-src/*|docs/*|ledger/*|_gate_evidence/*|.github/*|*.md|.gitignore|.editorconfig|LICENSE)
        ;;
      *)
        echo ALL; return 0 ;;
    esac
  done <<< "$CHANGED"
  [ -n "${sel# }" ] || return 0
  printf '%s\n' $sel | sort -u
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

# The per-file narrowing of test-vcx-suite, filled in below when that step is
# selected. Empty = the union, which is what the full-union path wants.
SUITE_SEL=''

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
    # SUITE_SEL is the per-file narrowing of test-vcx-suite (#1516). Empty means
    # the union — the Makefile's own default — so the full-union path below and
    # `make test-vcx-suite` by hand both behave exactly as they did.
    if [ -n "$SUITE_SEL" ]; then
      make $MAKEFLAGS_PAR SUITE_FILES="$SUITE_SEL" "${par[@]}" || return $?
    else
      make $MAKEFLAGS_PAR "${par[@]}" || return $?
    fi
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
  # ── INT-5, made mechanical (#1489) ────────────────────────────────────────
  # An ESCALATED selection is the post-merge run's and is never queued
  # pre-merge. That was a rule, and a rule is not a mechanism: on 2026-09-14
  # 17:12–17:33Z this script escalated silently on a branch, ran
  # `make -j12 … 54 targets` on `.build-slot-impl2` while the post-merge run
  # closing five issues was in its serial profile-gate tail, and took the
  # 12-core box from 1-min load 154 to 218. The integrator killed the tree by
  # hand — SIGTERM was ignored by make and bash, and the runners were
  # re-parented to launchd and kept spawning compiles until killed by pid.
  #
  # WHO IS PRE-MERGE is INT-1's key, unchanged and deliberately the same one
  # check-gate-lock reads: the runner directory the caller holds. `.build-slot`
  # is the post-merge runner; anything else is a pre-merge one. A caller
  # holding NO runner is a person at a keyboard and is not refused — this
  # guards the shared box, not the operator.
  #
  # Exit 0, not 1: the escalation is the ANSWER, not a failure. The line below
  # is what a branch's RESULTS.md records, and a pipeline that treated it as a
  # red would have agents editing pipelines to route around it.
  runner_dir="${CX_BUILD_SLOT:-${CX_RUNNER:-}}"
  if [ -n "$runner_dir" ] && [ "$(basename "$runner_dir")" != ".build-slot" ] \
     && [ -z "${TEST_CHANGED_FORCE_UNION:-}" ]; then
    echo "test-changed: the selection ESCALATED to the full union of $(printf '%s\n' $STEPS | grep -c .) steps:"
    printf '%s\n' $STEPS | sed 's/^/  /'
    echo "test-changed: escalated because a build-infra path changed — one of Makefile, scripts/, VERSION, devbox:"
    printf '%s\n' "$CHANGED" | grep -E '^(Makefile|vcx/Makefile|scripts/|VERSION|devbox)' | sed 's/^/  /' || true
    echo "test-changed: runner $runner_dir is a PRE-MERGE runner (INT-1's key: anything but .build-slot)"
    echo "TEST-CHANGED: escalated → post-merge (INT-5)"
    echo "test-changed: nothing executed. Record the line above in RESULTS.md; the post-merge run grades the union."
    echo "test-changed: TEST_CHANGED_FORCE_UNION=1 runs it anyway (it will contend with whatever else holds the box)."
    exit 0
  fi
  prebuild && run_step_set $STEPS
  exit $?
fi

# PATHNAME EXPANSION OFF for the matching loop (#1516). `for g in $globs` was
# GLOBBING the manifest's own patterns against the tree: `vcx/code/*` expanded
# to the files that exist, so a row matched a path only while that path was on
# disk. A DELETED input therefore matched nothing and its step was SKIPPED —
# the one failure direction this manifest must not have. `case` does the
# matching; the shell must not do it first.
set -f
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
set +f

# ── the per-file narrowing of test-vcx-suite (#1516, RULED: RUN-1) ──────────
# The row above has already decided whether the STEP runs. This decides which
# of its 76 files run, and drops the step entirely when the answer is none.
suite_selected=0
for s in "${run_steps[@]:-}"; do
  [ "$s" = test-vcx-suite ] && suite_selected=1
done
if [ $suite_selected -eq 1 ]; then
  sf=$(suite_files | tr '\n' ' ')
  sf=${sf% }
  if [ -z "$sf" ]; then
    echo "test-changed: test-vcx-suite: NO test file reads what changed — dropping the step"
    narrowed=()
    for s2 in "${run_steps[@]}"; do
      [ -n "$s2" ] || continue
      if [ "$s2" = test-vcx-suite ]; then skip_steps+=("$s2"); continue; fi
      narrowed+=("$s2")
    done
    if [ ${#narrowed[@]} -gt 0 ]; then run_steps=("${narrowed[@]}"); else run_steps=(); fi
  else
    case " $sf " in
      *" ALL "*)
        echo "test-changed: test-vcx-suite: the WHOLE suite — a shared helper, the V pin, a Makefile, scripts/ or an unclassified path changed" ;;
      *)
        SUITE_SEL="$sf"
        echo "test-changed: test-vcx-suite: $(printf '%s\n' $sf | grep -c . || true) of $(ls "$SUITE_DIR"/*_test.v 2>/dev/null | grep -c . || true) test files: $sf" ;;
    esac
  fi
fi

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
