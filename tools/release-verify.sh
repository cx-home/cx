#!/usr/bin/env bash
# tools/release-verify.sh — pre-publish sanity check.
#
# Runs all the §0 prerequisites from the release process as one
# fast script. Exit 0 means "ready to tag." Exit non-zero means stop.
#
# Usage:
# tools/release-verify.sh 0.6.0

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Default to the repo-root VERSION file — the single source of truth.
EXPECTED_VERSION="${1:-$(cat "$ROOT/VERSION")}"

if [ -z "$EXPECTED_VERSION" ]; then
 echo "Usage: $0 [expected-version]   (default: the VERSION file)"
 exit 2
fi

cd "$ROOT"

PASS=0
FAIL=0
ROW=0
# Per-ROW log files, kept for the whole run. The old single
# /tmp/release-verify.log was OVERWRITTEN by every subsequent row, so a
# mid-run failure's full output was destroyed by the rows after it — the
# `make test` row failed twice across releases with its evidence already
# clobbered by the time anyone looked (2026-08-22 and 2026-08-23).
RVLOG_DIR="$(mktemp -d /tmp/release-verify.XXXXXX)"
echo "release-verify: per-row logs in $RVLOG_DIR"
section() {
 echo ""
 echo "── $1 ────────────────────────────────────────────────"
}
check() {
 local label="$1" cmd="$2"
 ROW=$((ROW + 1))
 local slug
 slug="$(printf '%02d-%s' "$ROW" "$(echo "$label" | tr -cs 'a-zA-Z0-9' '-' | cut -c1-48)")"
 local rowlog="$RVLOG_DIR/$slug.log"
 printf " %-60s " "$label"
 if eval "$cmd" > "$rowlog" 2>&1; then
 echo "OK"
 PASS=$((PASS + 1))
 else
 echo "FAIL"
 FAIL=$((FAIL + 1))
 sed 's/^/ /' "$rowlog" | tail -15
 echo "   full row log: $rowlog"
 fi
}

section "Version consistency"
check "VERSION file = $EXPECTED_VERSION" \
 "test \"\$(cat VERSION)\" = \"$EXPECTED_VERSION\""
check "manifests + derived surfaces match VERSION" \
 "deps/cx-core-code/vcx/target/cx --allow-read --allow-write scripts/check_version_consistency.cx"

section "Working tree state"
check "git working tree clean" \
 "test -z \"\$(git status --porcelain | grep -v '^?? \\.claude/' | grep -v '^?? \\.cache/')\""
check "on a release branch (not detached)" \
 "git symbolic-ref -q HEAD"

section "Doc presence"
check "RELEASE_NOTES_v${EXPECTED_VERSION}.md exists" \
 "test -f RELEASE_NOTES_v${EXPECTED_VERSION}.md"
check "CHANGELOG.md exists" \
 "test -f CHANGELOG.md"
check "docs/internal/RELEASE_PROCESS.md exists" \
 "test -f docs/internal/RELEASE_PROCESS.md"
check "docs/internal/EVALUATION_EXPERIENCE.md exists" \
 "test -f docs/internal/EVALUATION_EXPERIENCE.md"
check "docs/internal/adoption_review_v${EXPECTED_VERSION}.md exists" \
 "test -f docs/internal/adoption_review_v${EXPECTED_VERSION}.md"

section "Test matrix"
check "make test (full matrix)" \
 "make -s test"

section "Experience gate"
check "make verify-examples" \
 "make -s verify-examples"
check "make verify-readme-blocks" \
 "make -s verify-readme-blocks"
check "make verify-doc-blocks" \
 "make -s verify-doc-blocks"
check "make verify-doc-links" \
 "make -s verify-doc-links"

section "Identity-provider interop (#1403)"
# TWO ROWS, AND THE SECOND IS THE ONE THAT BITES. The lane proves the SSO
# stack works against an identity provider we wrote; the matrix check proves
# a verdict has been earned against the ones a customer actually runs. A
# release that passes the first and fails the second has verified itself
# against itself, which is exactly the gap #1403 exists to close — so the
# matrix check is NOT advisory and must not be softened into one. It names
# the providers still unverified; drive each with
# tools/sso_interop_real.sh <provider> and record the verdict.
check "make -s test-sso-interop-lane" \
 "make -s test-sso-interop-lane"
check "every named identity provider carries a verdict" \
 "bash tools/sso_matrix_check.sh"

section "Guide generator (#989)"
# THE OTHER DOC GENERATOR. `make docs-check` below covers docs/llm/; NOTHING
# covered docs/guide/, and the asymmetry is not because the guide is cheap to
# get wrong — it is the published site. `make guide` was wired into no gate at
# all, which is how the generator sat RED for a full day after the R-A1
# [?splice] cutover (fixed at e40596614: an [?if]-returned sequence of fn
# sections landed in element content, a shape the settled semantics refuse). It
# hid because it only fires for a module with 2+ fn-docs and because every
# "green" guide run in between happened on a stale pre-settlement worktree base.
#
# Cost, measured (the #700 dead-ends register wants a number, not an adjective):
# 27.3-27.8 s wall / 26.5 CPU-s, single-process, warm — twice, at HEAD. That is
# noise inside a release gate that already runs `make test`. It is NOT wired
# into TEST_TARGETS: adding a serial ~27 s renderer to the ring is its own
# gate-duration decision, and the register requires such decisions be taken
# deliberately rather than as a side effect. Here is also where the row MUST be
# on the merits — the guide is otherwise first rendered by
# `make publish` at step 9 of the release process, i.e. AFTER the tag. A red
# generator discovered there has already shipped a tag it cannot publish from.
#
# NOT a smoke of a stub: this renders all 106 pages of the real site from
# docs-src/canonical/, so every module page (the 2+ fn-doc ones included) is
# exercised — red-proofed by reintroducing the e40596614 shape, which fails the
# row. GUIDE_SKIP_CX_BUILD=1 is deliberate: without it the guide's own
# rebuild-if-a-.v-moved rule can drop a DEV binary onto vcx/target/cx in the
# middle of a release gate, under the later rows that probe the shipped one.
# The row tests the GENERATOR against the binary already under test.
# docs/guide/ is gitignored, so the render cannot dirty the tree the
# "working tree clean" row above just checked.
check "make guide (generator renders; not red before the tag)" \
 "make -s guide GUIDE_SKIP_CX_BUILD=1"

section "LLM onboarding layer (#938)"
# THE DRIFT GATE. `make docs-check` regenerates docs/llm/ in memory and fails
# if either half moved:
#   (a) any primer example's LIVE output no longer matches the conformance
#       fixture it is drawn from — an example whose output changed without its
#       fixture changing is exactly the "stale primer" this row exists to
#       block, and it is caught by REPLAYING all ~100 cited fixtures, not by
#       reading them;
#   (b) the committed bytes differ from a fresh generation (prose, registry
#       projection, module catalog, or `cx --help` moved).
# A wrong example in an LLM primer poisons in-context learning, so the cut must
# not be able to ship one. Fix by running `make docs` and committing the result.
check "make docs-check (primer example freshness + no drift)" \
 "make -s docs-check"
# The `cx primer` door is only useful if the SHIPPED BINARY carries the current
# text. docs-check proves the FILE is fresh; this proves the EMBED is, by
# diffing the subcommand's stdout against the file it was embedded from. (The
# stdout is byte-exact by design precisely so this row can exist.) Catches the
# `make docs` without a following `make build-vcx`, which no other gate sees.
# The primer dump goes in the per-run RVLOG_DIR, not a fixed /tmp name:
# parallel sessions share this checkout, and two concurrent runs racing on one
# `/tmp/release-verify-primer.md` can make the diff read a half-written or a
# foreign primer — flipping this row either way (#948, the unfinished half of
# e47fe55ee, which converted RVLOG_DIR above but not this path).
check "cx primer == docs/llm/primer.md (embed is fresh)" \
 "deps/cx-core-code/vcx/target/cx primer > $RVLOG_DIR/primer-embed.md && diff -q $RVLOG_DIR/primer-embed.md docs/llm/primer.md"
# Presence of the published doors. Negative guards cannot see a REQUIRED file
# going missing, and the whole value of these is that a fixed path answers.
check "llms.txt + llms-full.txt + AGENTS.md present and non-empty" \
 "test -s docs/llm/llms.txt && test -s docs/llm/llms-full.txt && test -s AGENTS.md && test -s CLAUDE.md"
# The site assembly step (RULED: RS-27, RS-11, D51d): `publish.sh` used to
# copy these to the site root as part of the allowlist mirror it built; RS-11
# retired that mirror and nothing replaced the copy. `docs/` is the site root
# itself (CNAME lives there), so this is that copy — the llmstxt.org
# convention served from the domain root — done here, at release-verify time,
# UNTRACKED (gitignored: a committed duplicate would drift on every
# regeneration). This row both assembles and checks: docs/llms.txt and
# docs/llms-full.txt do not exist until release-verify runs.
check "llms.txt + llms-full.txt copied to the site root (untracked)" \
 "cp docs/llm/llms.txt docs/llms.txt && cp docs/llm/llms-full.txt docs/llms-full.txt && test -s docs/llms.txt && test -s docs/llms-full.txt"

section "The pins (RULED: RS-7, #1589 item 23)"
# "A release cut ships whatever is pinned." These rows are what makes that
# sentence checkable BEFORE the tag rather than discoverable after it.
#
# deps-check: every deps/<repo> is at the sha deps.cxd names, and every bundled
# CX module has exactly one source — its own tracked file, or the pinned
# checkout its registry row names (scripts/bundle_check.cx). It writes
# nothing, touches no network, and REFUSES — a stale pin, a drifted checkout, a
# pinned checkout missing its source, a row naming an unpinned repository, a
# pinned source committed here. None is a warning.
check "the pins are in sync and every bundled CX module has one source" \
 "make -s deps-check"
# The four §4 builds, from that pinned tree. `build-profiles-dev` is the dev
# matrix — the -prod matrix is phase 3's, and this row exists so a profile that
# cannot be built at all fails BEFORE the tag instead of inside the cut.
check "the four profiles build from the pinned tree" \
 "make -s build-profiles-dev"

section "Release assets"
# RULED: PGL-1 (#741) — the R2.2 blocking per-profile install gate runs HERE,
# pre-tag, instead of first executing inside the cut itself. Proves item 1 of
# #741; item 2 (installing from the PUBLISHED assets) still needs the cut.
check "R2.2 per-profile install gate (4 tarballs, extract + probe)" \
 "make -s release-profile-gate"

section "Capability rubric"
# The row's target is the readiness rubric FILE. A doc-curation text-replace
# (365923b7) once rewrote the path literal into the prose phrase "the release
# criteria" — grep then errored on three nonexistent files and the leading
# `!` inverted that error into a VACUOUS PASS on every run since. The file
# must exist (test -f) so a future move fails loud instead of vacuously
# passing again; the grep pattern matches only a lone-⚠ status cell, not the
# legend's tier column.
check "no unresolved \"⚠\" in readiness rubric" \
 "test -f spec/03-approved/process/readiness-rubric.md && ! grep -E '^\\| .* \\| *⚠ \\|' spec/03-approved/process/readiness-rubric.md"

# RULED: VC-10 (#874) — editor distribution is GATED at each release, not
# skipped loudly. #874's engineering landed 2026-08-20; what had no mechanism
# was the remainder — two external-repo PRs whose payloads sat prepared and
# unmentioned for four days because nothing recorded that they were owed. This
# row makes each release state where they stand: submitted for THIS version, or
# deferred with a reason. Deferral is legitimate (both PRs resolve assets that
# only exist once the release publishes) — the gate refuses SILENCE, not delay.
check "editor distribution: external submissions accounted for" \
 "deps/cx-core-code/vcx/target/cx --allow-read --allow-write scripts/check_editor_distribution.cx"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " release-verify: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════════════════════════════"

if [ $FAIL -ne 0 ]; then
 echo "Release blocked. Fix the failures above before tagging."
 exit 1
fi
echo "Ready to tag v${EXPECTED_VERSION}."
exit 0
